local RS = RS_ADDON ---@type RestockerAddon

---@class RsBankModule
---@field bankIsOpen boolean
---@field currentlyRestocking boolean
---@field skipSession boolean
---@field openedWindow boolean
---@field session number
---@field pending RsBankPendingTransfer|nil
---@field blockedTasks table<string, string>
---@field retryCounts table<string, number>
---@field movedCount number
---@field status string
local bankModule = RsModule.bankModule

---@class RsBankPendingTransfer
---@field action RsBankTransferAction
---@field playerCountBefore number
---@field session number

local bankContainerModule = RsModule.bankContainerModule ---@type RsBankContainerModule
local bankPlannerModule = RsModule.bankPlannerModule ---@type RsBankPlannerModule
local restockerModule = RsModule.restockerModule ---@type RsRestockerModule
local settingsModule = RsModule.settingsModule ---@type RsSettingsModule
local aceMainFrameModule = RsModule.aceMainFrameModule ---@type RsAceMainFrameModule

local CONFIRM_TIMEOUT = 3
local MAX_RETRIES = 3

local function cancelTimer(timer)
  if timer and RS.CancelTimer then
    pcall(RS.CancelTimer, RS, timer, true)
  end
end

local function playerCount(snapshot, itemID)
  return snapshot.player.summary[itemID] or 0
end

function bankModule.OnModuleInit()
  bankModule.bankIsOpen = false
  bankModule.currentlyRestocking = false
  bankModule.skipSession = false
  bankModule.openedWindow = false
  bankModule.session = 0
  bankModule.blockedTasks = {}
  bankModule.retryCounts = {}
  bankModule.movedCount = 0
  bankModule.status = ""
end

---@param message string
---@param printMessage boolean|nil
function bankModule:SetStatus(message, printMessage)
  self.status = message
  if aceMainFrameModule.SetStatus then
    aceMainFrameModule:SetStatus(message)
  end
  if printMessage and self.lastPrintedStatus ~= message then
    self.lastPrintedStatus = message
    RS:Print(message)
  end
end

function bankModule:CancelTimers()
  cancelTimer(self.workTimer)
  cancelTimer(self.timeoutTimer)
  self.workTimer = nil
  self.timeoutTimer = nil
end

---@param callback function
---@param delay number
function bankModule:ScheduleWork(callback, delay)
  cancelTimer(self.workTimer)
  local session = self.session
  self.workTimer = RS:ScheduleTimer(function()
    self.workTimer = nil
    if self.bankIsOpen and self.session == session then
      callback(self)
    end
  end, delay)
end

---@param message string
---@param printMessage boolean|nil
function bankModule:Stop(message, printMessage)
  self.currentlyRestocking = false
  self.pending = nil
  self:CancelTimers()
  self:SetStatus(message, printMessage)
end

function bankModule:Open()
  self.bankIsOpen = true
  self.skipSession = IsShiftKeyDown and IsShiftKeyDown() or false
  self.openedWindow = false

  if self.skipSession then
    self:SetStatus("Bank restocking skipped while Shift is held")
    return
  end

  if restockerModule.settings.autoOpenAtBank then
    RS:Show()
    self.openedWindow = true
  end
  self:Restart()
end

function bankModule:Close()
  self.bankIsOpen = false
  self.currentlyRestocking = false
  self.session = self.session + 1
  self.pending = nil
  self:CancelTimers()
  if self.openedWindow then
    RS:Hide()
  end
  self.openedWindow = false
end

function bankModule:Restart()
  if not self.bankIsOpen or self.skipSession then
    return
  end

  self.session = self.session + 1
  self:CancelTimers()
  self.pending = nil
  self.blockedTasks = {}
  self.retryCounts = {}
  self.movedCount = 0
  self.currentlyRestocking = true
  self.lastPrintedStatus = nil
  self:SetStatus("Planning bank restock...")
  self:ProcessNext()
end

function bankModule:GetCurrentProfile()
  local settings = restockerModule.settings
  return settings.profiles and settings.profiles[settings.currentProfile]
end

function bankModule:GetStoragePolicy()
  return settingsModule:GetBankStorage(restockerModule.settings.currentProfile)
end

---@param action RsBankTransferAction
---@param snapshot RsBankSnapshot
function bankModule:StartAction(action, snapshot)
  local success, reason = bankContainerModule:ExecuteAction(action)
  if not success then
    if reason == "Cursor is occupied" then
      self:SetStatus("Waiting for the cursor to be cleared")
      self:ScheduleWork(self.ProcessNext, 0.5)
      return
    elseif reason == "Source changed before transfer" or reason == "Destination changed before transfer" then
      self:ScheduleWork(self.ProcessNext, 0.05)
      return
    end

    local attempts = (self.retryCounts[action.key] or 0) + 1
    self.retryCounts[action.key] = attempts
    if attempts >= MAX_RETRIES then
      self.blockedTasks[action.key] = reason or "Transfer failed"
      self:SetStatus("Skipping " .. action.itemName .. ": " .. self.blockedTasks[action.key], true)
    end
    self:ScheduleWork(self.ProcessNext, 0.1)
    return
  end

  self.pending = {
    action = action,
    playerCountBefore = playerCount(snapshot, action.itemID),
    session = self.session,
  }
  self:SetStatus((action.direction == "deposit" and "Depositing " or "Withdrawing ")
      .. action.itemName .. " x" .. action.amount)

  cancelTimer(self.timeoutTimer)
  local session = self.session
  self.timeoutTimer = RS:ScheduleTimer(function()
    self.timeoutTimer = nil
    if self.bankIsOpen and self.session == session then
      self:ConfirmPending(true)
    end
  end, CONFIRM_TIMEOUT)
end

function bankModule:ProcessNext()
  if not self.bankIsOpen or not self.currentlyRestocking or self.pending then
    return
  end

  if CursorHasItem and CursorHasItem() then
    self:SetStatus("Waiting for the cursor to be cleared")
    self:ScheduleWork(self.ProcessNext, 0.5)
    return
  end

  local profile = self:GetCurrentProfile()
  if not profile then
    self:Stop("No active profile", true)
    return
  end

  local policy = self:GetStoragePolicy()
  local snapshot, snapshotError = bankContainerModule:CreateSnapshot(policy)
  if not snapshot then
    self:Stop(snapshotError or "Selected bank storage is unavailable", true)
    return
  end

  local tasks = bankPlannerModule:BuildTasks(profile, snapshot, policy, self.blockedTasks)
  if #tasks == 0 then
    if next(self.blockedTasks) then
      self:Stop("Bank restocking stopped with skipped items", true)
    elseif self.movedCount > 0 then
      self:Stop("Finished bank restocking (" .. self.movedCount .. " items moved)", true)
    else
      self:Stop("Bank quantities already satisfied")
    end
    return
  end

  local waitingForLocks = false
  local waitingForItemInfo = false
  local firstFailure
  for _, task in ipairs(tasks) do
    local action, reason = bankContainerModule:FindAction(task, snapshot)
    if action then
      self:StartAction(action, snapshot)
      return
    end
    firstFailure = firstFailure or (task.itemName .. ": " .. (reason or "Transfer unavailable"))
    if reason and string.find(reason, "locked", 1, true) then
      waitingForLocks = true
    elseif reason == "Item information is not available" then
      waitingForItemInfo = true
    end
  end

  if waitingForLocks or waitingForItemInfo then
    if waitingForItemInfo then
      self:SetStatus("Waiting for item information")
    else
      self:SetStatus("Waiting for locked bank items")
    end
    self:ScheduleWork(self.ProcessNext, 0.2)
  else
    self:Stop("Bank restocking paused: " .. (firstFailure or "No feasible transfer"), true)
  end
end

---@param timedOut boolean|nil
function bankModule:ConfirmPending(timedOut)
  local pending = self.pending
  if not pending or pending.session ~= self.session then
    return
  end

  local snapshot, snapshotError = bankContainerModule:CreateSnapshot(self:GetStoragePolicy())
  if not snapshot then
    self:Stop(snapshotError or "Selected bank storage became unavailable", true)
    return
  end

  local currentCount = playerCount(snapshot, pending.action.itemID)
  local expectedCount = pending.playerCountBefore
      + (pending.action.direction == "deposit" and -pending.action.amount or pending.action.amount)

  if currentCount == expectedCount then
    cancelTimer(self.timeoutTimer)
    self.timeoutTimer = nil
    self.pending = nil
    self.retryCounts[pending.action.key] = nil
    self.movedCount = self.movedCount + pending.action.amount
    self:ScheduleWork(self.ProcessNext, 0.05)
    return
  end

  if currentCount ~= pending.playerCountBefore then
    -- The player changed inventory while a transfer was pending. Trust a fresh plan.
    cancelTimer(self.timeoutTimer)
    self.timeoutTimer = nil
    self.pending = nil
    self:ScheduleWork(self.ProcessNext, 0.05)
    return
  end

  if not timedOut then
    return
  end

  self.pending = nil
  local attempts = (self.retryCounts[pending.action.key] or 0) + 1
  self.retryCounts[pending.action.key] = attempts
  if attempts >= MAX_RETRIES then
    self.blockedTasks[pending.action.key] = "Transfer was not confirmed"
    self:SetStatus("Skipping " .. pending.action.itemName .. ": transfer was not confirmed", true)
  else
    self:SetStatus("Retrying " .. pending.action.itemName .. " (" .. attempts .. "/" .. MAX_RETRIES .. ")")
  end
  self:ScheduleWork(self.ProcessNext, 0.1)
end

function bankModule:OnInventoryChanged()
  if not self.bankIsOpen or self.skipSession or not self.currentlyRestocking then
    return
  end
  if self.pending then
    self:ScheduleWork(function(module)
      module:ConfirmPending(false)
    end, 0.05)
  else
    self:ScheduleWork(self.ProcessNext, 0.05)
  end
end

---@param message string|nil
function bankModule:OnUiError(message)
  if not self.bankIsOpen or not self.currentlyRestocking then
    return
  end

  if self.pending then
    local action = self.pending.action
    self.blockedTasks[action.key] = message or "Inventory operation failed"
    self.pending = nil
    cancelTimer(self.timeoutTimer)
    self.timeoutTimer = nil
    self:SetStatus("Skipping " .. action.itemName .. ": " .. self.blockedTasks[action.key], true)
    self:ScheduleWork(self.ProcessNext, 0.1)
  end
end
