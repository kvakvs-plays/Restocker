--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsBankModule
---@field bankIsOpen boolean
---@field currentlyRestocking boolean
---@field updateTimer number
---@field state BankRestockState
local bankModule = RsModule.bankModule
bankModule.bankIsOpen = false
bankModule.updateTimer = 0

local restockerModule = RsModule.restockerModule ---@type RsRestockerModule
local bagModule = RsModule.bagModule ---@type RsBagModule

bankModule.didBankStuff = false

---@class BankRestockState
---@field playerInventory RsInventory How many items in character bags, summary and per slot
---@field bankInventory RsInventory How many items in bank, summary and per slot
---@field currentProfile RsTradeCommand[]
---@field task RsMoveItemTask What item, and how many to move (negative = move to bank)
---@field moveCount number
local stateClass = {}
stateClass.__index = stateClass

function bankModule:NewState()
  local state = --[[---@type BankRestockState]] {}
  local settings = restockerModule.settings
  local currentProfile = --[[---@not nil]] settings.profiles[settings.currentProfile]

  state.currentProfile = currentProfile
  state.task = --[[---@type RsMoveItemTask]] {}
  state.moveCount = 0

  setmetatable(state, stateClass)

  state:UpdateInventory()
  state:CountItemsTooMany() -- to store extras to bank
  state:CountItemsTooFew() -- to restock from bank

  return state
end

---Called once on Addon creation. Sets up constants for bank bags
function bankModule.OnModuleInit()
end

---Try move full stacks in or out of bank, if not possible, then try move 1 item at a time.
function bankModule.StashToBank()
  local state = bankModule.state

  for moveName, moveAmount in pairs(state.task) do
    -- Negative for take from bag, positive for take from bank
    if moveAmount < 0 then
      if bagModule:MoveFromPlayerToBank(state.bankInventory, state.task, moveName, math.abs(moveAmount)) then
        return -- DONE one step, yield is done above in the caller coro
      end
    end
  end
end

---Try move full stacks out of bank, if not possible, then try move 1 item at a time.
function bankModule.RestockFromBank()
  local state = bankModule.state

  for moveName, moveAmount in pairs(state.task) do
    -- Negative for take from bag, positive for take from bank
    if moveAmount > 0 then
      if bagModule:MoveFromBankToPlayer(state.playerInventory, state.task, moveName, moveAmount) then
        return -- DONE one step, yield is done above in the caller coro
      end
    end
  end
end

function stateClass:UpdateInventory()
  local settings = restockerModule.settings
  local currentProfile = --[[---@not nil]] settings.profiles[settings.currentProfile]

  -- Function to check that the bag or bank item is interesting for our restocking needs
  local itemExistsFn = ---@param itemname string
  function(itemname)
    for _i, eachItem in pairs(currentProfile) do
      if eachItem.itemName == itemname then
        return true
      end
    end
    return false
  end

  self.playerInventory = bagModule:GetItemsInBags(itemExistsFn)
  self.bankInventory = bagModule:GetItemsInBank(itemExistsFn)
end

---Go through the bags and see what's too much in our bag and must be sent to bank
function stateClass:CountItemsTooMany()
  -- TODO: Calculate optimal stack size and block those stacks from moving
  for i, eachItem in pairs(self.currentProfile) do
    local haveInBackpack = self.playerInventory.summary[eachItem.itemName] or 0

    --If have more than in restocker config, move excess to bank
    if eachItem.amount < haveInBackpack
        and eachItem.stashTobank
    then
      RS:Debug(string.format("Too many %s in bag (%d need %d)",
          eachItem.itemName, haveInBackpack, eachItem.amount))

      -- Negative for take from bag, positive for take from bank
      self.task[eachItem.itemName] = eachItem.amount - haveInBackpack
      self.moveCount = self.moveCount + math.abs(self.task[eachItem.itemName])
    end
  end -- for all items in restock list
end

---Go through the bags and see what's too few in our bag and must be restocked from bank
function stateClass:CountItemsTooFew()
  -- TODO: Calculate optimal stack size and block those stacks from moving
  for i, eachItem in pairs(self.currentProfile) do
    local haveInBackpack = self.playerInventory.summary[eachItem.itemName] or 0
    local haveInBank = self.bankInventory.summary[eachItem.itemName] or 0

    if eachItem.amount > haveInBackpack
        and haveInBank > 0
        and eachItem.restockFromBank
    then
      RS:Debug(string.format("Too few %s in bag (%d need %d)",
          eachItem.itemName, haveInBackpack, eachItem.amount))
      -- Negative for take from bag, positive for take from bank
      self.task[eachItem.itemName] = math.min(
          eachItem.amount - haveInBackpack, -- don't move more than we need
          haveInBank) -- but not more than have in bank
      self.moveCount = self.moveCount + math.abs(self.task[eachItem.itemName])
    end
  end -- for all items in restock list
end

---Coroutine function to unload extra goods into bank and load goods from bank
---@return boolean True if finished
function bankModule:RunRestockLogic()
  local state = bankModule.state

  if not bankModule.bankIsOpen then
    bankModule.currentlyRestocking = false
    RS:Print("Bank is not open")
    return true
  end

  if state.moveCount < 1 then
    bankModule.currentlyRestocking = false
    RS:Print("Finished restocking. Hold Shift to skip next time.")
    return true
  end

  local bagCheck = bagModule:CheckBankBagSpace()

  if bagCheck == "both" then
    bankModule.currentlyRestocking = false
    RS:Print("Both bag and bank are full, need 1 free slot to begin")
    return true

  elseif bagCheck == "bank" then
    bankModule.currentlyRestocking = false
    RS:Print("Bank is full, need 1 free slot to begin")
    return true

  elseif bagCheck == "bag" then
    bankModule.currentlyRestocking = false
    RS:Print("Bag is full, need 1 free slot to begin")
    return true
  end

  bankModule.StashToBank()
  bankModule.RestockFromBank()

  return false -- not finished
end

local function restockCoro()
  --bankModule.state = bankModule:NewState()
  while bankModule.bankIsOpen do
    local success, result = pcall(bankModule.RunRestockLogic)
    if not success then
      RS:Debug("Restock failed with: " .. restockerModule:Dump(result))
      theCoroutineObject = nil
      return
    end
    coroutine.yield()
  end
end

local theCoroutineObject = coroutine.create(restockCoro)

function bankModule:MaintainAndResumeCoro()
  if theCoroutineObject == nil then
    RS:Debug("Maintain: create coro")
    theCoroutineObject = coroutine.create(restockCoro)
  end

  if coroutine.status(theCoroutineObject) == "running" then
    RS:Debug("Maintain: coro running")
    return
  end

  local resume = coroutine.resume(theCoroutineObject)

  if resume == false then
    RS:Debug("Maintain: coro ended/failed?")
    theCoroutineObject = nil
  end
end

function bankModule.BankUpdateFn(self, elapsed)
  if bankModule.bankIsOpen == false then
    RS.onUpdateFrame:Hide() -- stop the periodic timer in the update frame
    return -- nope
  end

  bankModule.updateTimer = bankModule.updateTimer + elapsed

  -- Ping x 3 defines the click frequency. But never go faster than 140 ms
  local _down, _up, pingHome, pingWorld = GetNetStats()
  local maxPing = math.max(pingHome, pingWorld)
  local updateInterval = math.max(0.140, (maxPing * 3) / 1000)

  if bankModule.updateTimer >= updateInterval then
    bankModule.updateTimer = 0

    if bankModule.currentlyRestocking then
      --if bagModule:IsSomethingLocked() then
      --  return -- skip a cycle while something is locked
      --end

      bankModule:MaintainAndResumeCoro()
    end
  end
end

function bankModule:RestartRestocking()
  self.state = self:NewState()
  self.currentlyRestocking = true
  RS.onUpdateFrame:Show() -- start the periodic timer in the update frame
end

RS.onUpdateFrame = CreateFrame("Frame")
RS.onUpdateFrame:SetScript("OnUpdate", bankModule.BankUpdateFn)

--- For debugging restocking coroutine do the scriptErrors once, then run xxx() like so
--- /console scriptErrors 1
--- /run RS_ADDON.Test()
function RS.Test()
  bankModule.bankIsOpen = true
  bankModule:RestartRestocking()
  for i = 1, 10 do
    if bankModule:RunRestockLogic() == true then
      return
    end
  end
end
