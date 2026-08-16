local RS = RS_ADDON ---@type RestockerAddon

---@class RsBankContainerModule
local bankContainerModule = RsModule.bankContainerModule

---@class RsBankSlot
---@field bag number
---@field slot number
---@field itemID number
---@field count number
---@field isLocked boolean
---@field hyperlink string|nil
---@field storage string

---@class RsBankEmptySlot
---@field bag number
---@field slot number
---@field bagFamily number
---@field storage string

---@class RsBankInventoryGroup
---@field summary table<number, number>
---@field slots table<number, RsBankSlot[]>
---@field emptySlots RsBankEmptySlot[]
---@field containers number[]

---@class RsBankSnapshot
---@field player RsBankInventoryGroup
---@field character RsBankInventoryGroup|nil
---@field account RsBankInventoryGroup|nil

---@class RsBankTransferAction
---@field key string
---@field itemID number
---@field itemName string
---@field direction RsBankTransferDirection
---@field amount number
---@field source RsBankSlot
---@field destination RsBankSlot|RsBankEmptySlot

local containerApi = _G["C_Container"]
local itemApi = _G["C_Item"]

local function getContainerNumSlots(bag)
  if containerApi and containerApi.GetContainerNumSlots then
    return containerApi.GetContainerNumSlots(bag)
  end
  return GetContainerNumSlots(bag)
end

local function getContainerNumFreeSlots(bag)
  if containerApi and containerApi.GetContainerNumFreeSlots then
    return containerApi.GetContainerNumFreeSlots(bag)
  end
  return GetContainerNumFreeSlots(bag)
end

local function getContainerItemInfo(bag, slot)
  if containerApi and containerApi.GetContainerItemInfo then
    return containerApi.GetContainerItemInfo(bag, slot)
  end

  local icon, count, locked, quality, readable, lootable, link, filtered, noValue, itemID, isBound =
      GetContainerItemInfo(bag, slot)
  if not link then
    return nil
  end
  itemID = itemID or tonumber(string.match(link, "item:(%d+)"))
  return {
    iconFileID = icon,
    stackCount = count,
    isLocked = locked,
    quality = quality,
    isReadable = readable,
    hasLoot = lootable,
    hyperlink = link,
    isFiltered = filtered,
    hasNoValue = noValue,
    itemID = itemID,
    isBound = isBound,
  }
end

local function pickupContainerItem(bag, slot)
  if containerApi and containerApi.PickupContainerItem then
    return containerApi.PickupContainerItem(bag, slot)
  end
  return PickupContainerItem(bag, slot)
end

local function splitContainerItem(bag, slot, amount)
  if containerApi and containerApi.SplitContainerItem then
    return containerApi.SplitContainerItem(bag, slot, amount)
  end
  return SplitContainerItem(bag, slot, amount)
end

local function safeNumSlots(bag)
  local success, slots = pcall(getContainerNumSlots, bag)
  if not success then
    return 0
  end
  return tonumber(slots) or 0
end

local function safeBagFamily(bag)
  local success, _freeSlots, bagFamily = pcall(getContainerNumFreeSlots, bag)
  if not success then
    return 0
  end
  return tonumber(bagFamily) or 0
end

local function addUnique(result, seen, bag)
  if bag ~= nil and not seen[bag] and safeNumSlots(bag) > 0 then
    seen[bag] = true
    table.insert(result, bag)
  end
end

---@return boolean
function bankContainerModule:SupportsAccountBank()
  return WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
      and Enum and Enum.BagIndex and Enum.BagIndex.AccountBankTab_1 ~= nil
      and Enum.BagIndex.AccountBankTab_5 ~= nil
end

---@param kind "player"|"character"|"account"
---@return number[]
function bankContainerModule:GetContainerIds(kind)
  local result = {}
  local seen = {}

  if kind == "player" then
    addUnique(result, seen, BACKPACK_CONTAINER or 0)
    for bag = 1, tonumber(NUM_BAG_SLOTS) or 4 do
      addUnique(result, seen, bag)
    end
    if Enum and Enum.BagIndex then
      addUnique(result, seen, Enum.BagIndex.ReagentBag)
    end
    return result
  end

  if kind == "character" then
    local mainBank = BANK_CONTAINER
        or Enum and Enum.BagIndex and Enum.BagIndex.Bank
        or -1
    addUnique(result, seen, mainBank)

    if Enum and Enum.BagIndex and Enum.BagIndex.BankBag_1 and Enum.BagIndex.BankBag_7 then
      for bag = Enum.BagIndex.BankBag_1, Enum.BagIndex.BankBag_7 do
        addUnique(result, seen, bag)
      end
    else
      local firstBankBag = (tonumber(NUM_BAG_SLOTS) or 4) + 1
      for bag = firstBankBag, firstBankBag + (tonumber(NUM_BANKBAGSLOTS) or 7) - 1 do
        addUnique(result, seen, bag)
      end
    end
    return result
  end

  if kind == "account" and self:SupportsAccountBank() then
    for bag = Enum.BagIndex.AccountBankTab_1, Enum.BagIndex.AccountBankTab_5 do
      addUnique(result, seen, bag)
    end
  end
  return result
end

---@param kind "player"|"character"|"account"
---@return RsBankInventoryGroup
function bankContainerModule:ScanGroup(kind)
  local group = {
    summary = {},
    slots = {},
    emptySlots = {},
    containers = self:GetContainerIds(kind),
  } ---@type RsBankInventoryGroup

  for _, bag in ipairs(group.containers) do
    local bagFamily = safeBagFamily(bag)
    for slot = 1, safeNumSlots(bag) do
      local itemInfo = getContainerItemInfo(bag, slot)
      if itemInfo and itemInfo.itemID and itemInfo.stackCount then
        local itemID = tonumber(itemInfo.itemID)
        if itemID then
          local bankSlot = {
            bag = bag,
            slot = slot,
            itemID = itemID,
            count = itemInfo.stackCount,
            isLocked = itemInfo.isLocked and true or false,
            hyperlink = itemInfo.hyperlink,
            storage = kind,
          } ---@type RsBankSlot
          group.summary[itemID] = (group.summary[itemID] or 0) + bankSlot.count
          group.slots[itemID] = group.slots[itemID] or {}
          table.insert(group.slots[itemID], bankSlot)
        end
      elseif not itemInfo then
        table.insert(group.emptySlots, {
          bag = bag,
          slot = slot,
          bagFamily = bagFamily,
          storage = kind,
        })
      end
    end
  end
  return group
end

---@param policy RsBankStoragePolicy
---@return RsBankSnapshot|nil, string|nil
function bankContainerModule:CreateSnapshot(policy)
  local snapshot = {
    player = self:ScanGroup("player"),
  } ---@type RsBankSnapshot

  if policy == "character" or policy == "both" then
    snapshot.character = self:ScanGroup("character")
    if #snapshot.character.containers == 0 then
      return nil, "Character bank is not accessible"
    end
  end

  if policy == "account" or policy == "both" then
    if not self:SupportsAccountBank() then
      return nil, "Account bank is not supported by this client"
    end
    snapshot.account = self:ScanGroup("account")
    if #snapshot.account.containers == 0 then
      return nil, "Account bank is not accessible"
    end
  end

  return snapshot, nil
end

local function selectSource(slots, amount)
  local exact
  local under
  local over
  local haveLocked = false

  for _, slot in ipairs(slots or {}) do
    if slot.isLocked then
      haveLocked = true
    elseif slot.count == amount and not exact then
      exact = slot
    elseif slot.count < amount and (not under or slot.count > under.count) then
      under = slot
    elseif slot.count > amount and (not over or slot.count < over.count) then
      over = slot
    end
  end
  return exact or under or over, haveLocked
end

local function itemFitsBag(itemID, bagFamily)
  if not bagFamily or bagFamily == 0 then
    return true
  end
  local getItemFamily = itemApi and itemApi.GetItemFamily or GetItemFamily
  if not getItemFamily then
    return false
  end
  local itemFamily = getItemFamily(itemID) or 0
  return itemFamily ~= 0 and bit and bit.band(itemFamily, bagFamily) ~= 0
end

function bankContainerModule:GetMaxStack(itemID)
  local itemInfo = RS.GetItemInfo(itemID)
  local maxStack = itemInfo and tonumber(itemInfo.itemStackCount) or nil
  return maxStack and math.max(1, maxStack) or nil
end

local function findDestination(group, itemID, maxTransfer, maxStack)
  local bestFit
  local bestFitCapacity
  local partial
  local partialCapacity = 0
  local haveLocked = false

  for _, slot in ipairs(group.slots[itemID] or {}) do
    local capacity = maxStack - slot.count
    if slot.isLocked then
      haveLocked = true
    elseif capacity >= maxTransfer and (not bestFitCapacity or capacity < bestFitCapacity) then
      bestFit = slot
      bestFitCapacity = capacity
    elseif capacity > partialCapacity then
      partial = slot
      partialCapacity = capacity
    end
  end

  if bestFit then
    return bestFit, maxTransfer, haveLocked
  elseif partial and partialCapacity > 0 then
    return partial, math.min(maxTransfer, partialCapacity), haveLocked
  end

  for _, emptySlot in ipairs(group.emptySlots) do
    if itemFitsBag(itemID, emptySlot.bagFamily) then
      return emptySlot, maxTransfer, haveLocked
    end
  end
  return nil, 0, haveLocked
end

---@param task RsBankTransferTask
---@param snapshot RsBankSnapshot
---@return RsBankTransferAction|nil, string|nil
function bankContainerModule:FindAction(task, snapshot)
  local source
  local sourceLocked = false
  local sourceKinds = task.direction == "deposit" and { "player" } or task.storageKinds

  for _, kind in ipairs(sourceKinds) do
    local group = snapshot[kind]
    local candidate
    local haveLocked = false
    if group then
      candidate, haveLocked = selectSource(group.slots[task.itemID], task.amount)
    end
    sourceLocked = sourceLocked or haveLocked
    if candidate then
      source = candidate
      break
    end
  end

  if not source then
    return nil, sourceLocked and "Source item is locked" or "Source item is unavailable"
  end

  local maxStack = self:GetMaxStack(task.itemID)
  if not maxStack then
    return nil, "Item information is not available"
  end

  local maxTransfer = math.min(task.amount, source.count, maxStack)
  local destinationKinds = task.direction == "deposit" and task.storageKinds or { "player" }
  local destinationLocked = false
  for _, kind in ipairs(destinationKinds) do
    local group = snapshot[kind]
    if group then
      local destination, amount, haveLocked = findDestination(group, task.itemID, maxTransfer, maxStack)
      destinationLocked = destinationLocked or haveLocked
      if destination and amount > 0 then
        return {
          key = task.key,
          itemID = task.itemID,
          itemName = task.itemName,
          direction = task.direction,
          amount = amount,
          source = source,
          destination = destination,
        }, nil
      end
    end
  end

  return nil, destinationLocked and "Destination item is locked" or "No compatible destination space"
end

local function cursorHasItem()
  return CursorHasItem and CursorHasItem()
end

---@param action RsBankTransferAction
---@return boolean, string|nil
function bankContainerModule:ExecuteAction(action)
  if cursorHasItem() then
    return false, "Cursor is occupied"
  end

  local sourceInfo = getContainerItemInfo(action.source.bag, action.source.slot)
  if not sourceInfo or sourceInfo.itemID ~= action.itemID or sourceInfo.isLocked
      or sourceInfo.stackCount < action.amount then
    return false, "Source changed before transfer"
  end

  local destinationInfo = getContainerItemInfo(action.destination.bag, action.destination.slot)
  if destinationInfo and (destinationInfo.itemID ~= action.itemID or destinationInfo.isLocked) then
    return false, "Destination changed before transfer"
  end

  local success
  if sourceInfo.stackCount == action.amount then
    success = pcall(pickupContainerItem, action.source.bag, action.source.slot)
  else
    success = pcall(splitContainerItem, action.source.bag, action.source.slot, action.amount)
  end
  if not success or not cursorHasItem() then
    return false, "Could not pick up source item"
  end

  success = pcall(pickupContainerItem, action.destination.bag, action.destination.slot)
  if success and not cursorHasItem() then
    return true, nil
  end

  -- The cursor was empty before this action, so anything still held belongs to this transfer.
  pcall(pickupContainerItem, action.source.bag, action.source.slot)
  if cursorHasItem() and ClearCursor then
    ClearCursor()
  end
  return false, "Could not place item in destination"
end
