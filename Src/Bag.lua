--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsBagModule
---@field PLAYER_BAGS RsBagDef[] Indexes of player bags
---@field PLAYER_BAGS_REVERSED RsBagDef[]
---@field BANK_BAGS RsBagDef[]
---@field BANK_BAGS_REVERSED RsBagDef[]

local bagModule = RsModule.bagModule ---@type RsBagModule
local itemModule = RsModule.itemModule ---@type RsItemModule
local envModule = KvModuleManager.envModule
local inventoryModule = RsModule.inventoryModule ---@type RsInventoryModule
local restockerModule = RsModule.restockerModule ---@type RsRestockerModule

bagModule.PLAYER_BAGS = {}
bagModule.PLAYER_BAGS_REVERSED = {}

---@alias RsBagId number

---@alias RsContainerLocation "bank" | "guildbank" | "bag" | "backpack"

---@class RsBagDef
---@field location RsContainerLocation
---@field bagId RsBagId The bag id
---@field containerSlotId number The container slot id for PutItemInBag calls
local bagDefClass = {}
bagDefClass.__index = bagDefClass

bagModule.BANK_BAGS = --[[---@type RsBagDef[] ]] {}          -- set up in RS.SetupBankConstants
bagModule.BANK_BAGS_REVERSED = --[[---@type RsBagDef[] ]] {} -- set up in RS.SetupBankConstants

---Converts bag indexes 1..4 (bags after the backpack) to inventory slot indexes
---(example retail Dragonflight 31..34)
local function bagSlotFromBag(bag)
  RS:Debug("bagSlotFromBag bag=BAG" .. (bag - 1) .. "SLOT")
  local bagSlot, _icon, _ = GetInventorySlotInfo("BAG" .. (bag - 1) .. "SLOT")
  return bagSlot
end

---@return RsBagDef
function bagModule:NewBagDef(location, bagId, containerSlotId)
  local result = --[[---@type RsBagDef]] {}
  result.location = location
  result.bagId = bagId
  result.containerSlotId = containerSlotId
  setmetatable(result, bagDefClass)
  return result
end

local function createBackpack()
  return bagModule:NewBagDef("backpack", BACKPACK_CONTAINER, nil)
end

local function createBag(bag)
  return bagModule:NewBagDef("bag", bag, bagSlotFromBag(bag))
end

---@return RsBagDef
local function createBankMainBag()
  return bagModule:NewBagDef("bank", BANK_CONTAINER, nil)
end

local function createBankBag(bag)
  -- bank bags go from 5 to 11, but BankButtonIDToInvSlotID parameter is 0.. (we use 1.. range because 0 is default bank)
  local bagId = bag + NUM_BAG_SLOTS
  return bagModule:NewBagDef("bag", bagId, C_Container.ContainerIDToInventoryID(bagId))
end

local function onInit_playerBankBags()
  -- In Midnight the bank bags are 6-11 for character bank and 12-16 for account bank (offset by NUM_BAG_SLOTS=4)
  if envModule.isMidnight then
    bagModule.BANK_BAGS = { createBankMainBag(), createBankBag(2), createBankBag(3), createBankBag(4),
      createBankBag(5), createBankBag(6), createBankBag(7), createBankBag(8), createBankBag(9), createBankBag(10),
      createBankBag(11), createBankBag(12) }
  else
    bagModule.BANK_BAGS = { createBankMainBag(), createBankBag(1), createBankBag(2), createBankBag(3),
      createBankBag(4), createBankBag(5), createBankBag(6), createBankBag(7) }
  end
end

local function onInit_playerBankBagsReversed()
  bagModule.BANK_BAGS_REVERSED = { createBankBag(7), createBankBag(6), createBankBag(5),
    createBankBag(4), createBankBag(3), createBankBag(2), createBankBag(1),
    createBankMainBag() }
end

local function onInit_playerBags()
  if envModule.isMidnight then
    -- Bags are numbered 0 to 3
    bagModule.PLAYER_BAGS = { createBackpack(), createBag(0), createBag(1), createBag(2), createBag(3) }
  else
    bagModule.PLAYER_BAGS = { createBackpack(), createBag(1), createBag(2), createBag(3), createBag(4) }
  end
end

local function onInit_playerBagsReversed()
  bagModule.PLAYER_BAGS_REVERSED = {}
  if envModule.isMidnight then
    table.insert(bagModule.PLAYER_BAGS_REVERSED, createBag(5)) -- Reagent Bag in Wow Midnight is 5
  end
  table.insert(bagModule.PLAYER_BAGS_REVERSED, createBag(4))
  table.insert(bagModule.PLAYER_BAGS_REVERSED, createBag(3))
  table.insert(bagModule.PLAYER_BAGS_REVERSED, createBag(2))
  table.insert(bagModule.PLAYER_BAGS_REVERSED, createBag(1))
  table.insert(bagModule.PLAYER_BAGS_REVERSED, createBackpack())
end

function bagModule.OnModuleInit()
  onInit_playerBankBags()
  onInit_playerBankBagsReversed()
  onInit_playerBags()
  onInit_playerBagsReversed()
end

function bagDefClass:NumSlots()
  return restockerModule:GetContainerNumSlots(self.bagId)
end

---@return boolean
function bagDefClass:HasSpace()
  local numberOfFreeSlots, _bagType = restockerModule:GetContainerNumFreeSlots(self.bagId)
  return numberOfFreeSlots > 0
end

---Can't fail, assumes that free space was checked by the caller
function bagDefClass:PutCursorItem()
  RS:Debug("PutCursorItem(" .. self.location .. ") bag=" .. self.bagId .. " invslot=" .. tostring(self.containerSlotId))

  if self.location == "backpack" then
    PutItemInBackpack()
  end
  if self.location == "bank" then
    -- Find a free slot in the bank
    for slot = 1, restockerModule:GetContainerNumSlots(self.bagId) do
      local link = C_Container.GetContainerItemLink(self.bagId, slot)
      if not link then
        -- available!
        if not C_Container.PickupContainerItem(self.bagId, slot) then
          ClearCursor()
        end
        return
      end
    end
  else
    -- Drop in the bag provided that HasSpace() is true (checked by the caller)
    PutItemInBag(self.containerSlotId)
  end
end

function bagModule:GetBankBags(reversed)
  if reversed then
    return self.BANK_BAGS_REVERSED
  end
  return self.BANK_BAGS
end

function bagModule:GetPlayerBags(reversed)
  if reversed then
    return self.PLAYER_BAGS_REVERSED
  end
  return self.PLAYER_BAGS
end

function bagModule:IsSomethingLocked()
  for _, bag in ipairs(self.PLAYER_BAGS) do
    for slot = 1, restockerModule:GetContainerNumSlots(bag.bagId) do
      local itemInfo = restockerModule:GetContainerItemInfo(bag.bagId, slot)

      if itemInfo and itemInfo.isLocked then
        return true
      end
    end
  end

  for _, bag in ipairs(self.BANK_BAGS_REVERSED) do
    for slot = 1, restockerModule:GetContainerNumSlots(bag.bagId) do
      local itemInfo = restockerModule:GetContainerItemInfo(bag.bagId, slot)

      if itemInfo and itemInfo.isLocked then
        return true
      end
    end
  end

  return false
end

---@param predicate fun(s: string): boolean|nil
---@return RsInventory
function bagModule:GetItemsInBags(predicate)
  local result = inventoryModule:NewInventory()

  for _, bag in ipairs(self.PLAYER_BAGS) do
    for slot = 1, restockerModule:GetContainerNumSlots(bag.bagId) do
      local itemInfo = restockerModule:GetContainerItemInfo(bag.bagId, slot)

      if itemInfo and itemInfo.itemID and itemInfo.hyperlink then
        local itemName = --[[---@type string]] (string.match(itemInfo.hyperlink, "%[(.*)%]"))

        -- Allow filtering by predicate
        if predicate == nil or predicate(itemName) == true then
          result.summary[itemName] = (result.summary[itemName] and result.summary[itemName] + itemInfo.stackCount)
              or itemInfo.stackCount

          result.slots[itemName] = result.slots[itemName] or {}

          local newSlot = inventoryModule:NewSlot(bag.bagId, slot, itemInfo.stackCount)
          table.insert(result.slots[itemName], newSlot)
        end
      end
    end
  end

  result:SortSlots()
  return result
end

---@param handler fun(bag: number, slot: number, itemName: string, itemID: number, itemCount: number)
function bagModule:ForEachBagItem(handler)
  local result = --[[---@type RsInventoryCountByItemName]] {}
  for _, bag in ipairs(self.PLAYER_BAGS) do
    for slot = 1, restockerModule:GetContainerNumSlots(bag.bagId) do
      --local _, itemCount, locked, _, _, _, itemLink, _, _, itemID =
      local itemInfo = restockerModule:GetContainerItemInfo(bag.bagId, slot)

      if itemInfo and itemInfo.itemID and itemInfo.hyperlink then
        local itemName = --[[---@type string]] (string.match(itemInfo.hyperlink, "%[(.*)%]"))
        handler(bag.bagId, slot, itemName, itemInfo.itemID, itemInfo.stackCount)
      end
    end
  end
  return result
end

---@param predicate fun(s: string): boolean|nil
---@return RsInventory
function bagModule:GetItemsInBank(predicate)
  local result = inventoryModule:NewInventory()

  for _, bag in ipairs(self.BANK_BAGS_REVERSED) do
    if bag.bagId then
      for slot = 1, restockerModule:GetContainerNumSlots(bag.bagId) do
        --local _, itemCount, locked, _, _, _, itemLink, _, _, itemID =
        local itemInfo = restockerModule:GetContainerItemInfo(bag.bagId, slot)
        if itemInfo and itemInfo.itemID then
          local itemName = --[[---@type string]] string.match(itemInfo.hyperlink, "%[(.*)%]")

          -- Allow filtering by predicate
          if predicate == nil or predicate(itemName) == true then
            result.summary[itemName] = (result.summary[itemName] and result.summary[itemName] + itemInfo.stackCount)
                or itemInfo.stackCount

            result.slots[itemName] = result.slots[itemName] or {}

            local newSlot = inventoryModule:NewSlot(bag.bagId, slot, itemInfo.stackCount)
            table.insert(result.slots[itemName], newSlot)
          end
        end -- end if itemInfo and itemInfo.itemID
      end   -- end for every slot
    end     -- if bag.bagId
  end

  result:SortSlots()
  return result
end

---Takes cursor item. Drops it into one of the bank bags.
---@param bankInventory RsInventory
---@param itemInfo GIICacheItem
---@param amount number
---@return boolean Success
function bagModule:PutItemInBank(bankInventory, itemInfo, amount)
  if not CursorHasItem() then
    return false
  end
  --C_NewItems.ClearAll() -- don't show item is new?

  -- Find an incomplete existing stack best fit
  local bestFit = bankInventory:FindBestFit(itemInfo, amount, self.BANK_BAGS)
  if bestFit then
    C_Container.PickupContainerItem(
      ( --[[---@not nil]] bestFit).bag, ( --[[---@not nil]] bestFit).slot)
    return true
  end

  -- Doesn't matter, drop in any available
  for _, bag in ipairs(self.BANK_BAGS) do
    if bag:HasSpace() then
      bag:PutCursorItem()
      return true
    end
  end

  RS:Debug("PutItemInBank: Could not drop item to bank for some reason")
  ClearCursor()
  return false
end

---Takes cursor item. Drops it into one of the bank bags.
---@param playerInventory RsInventory
---@param itemInfo GIICacheItem
---@return boolean Success
---@param amount number
function bagModule:PutItemInPlayerBag(playerInventory, itemInfo, amount)
  if not CursorHasItem() then
    return false
  end
  --C_NewItems.ClearAll() -- don't show item is new?

  -- Find an incomplete existing stack best fit
  local bestFit = playerInventory:FindBestFit(itemInfo, amount, self.PLAYER_BAGS)
  if bestFit then
    C_Container.PickupContainerItem(( --[[---@not nil]] bestFit).bag, ( --[[---@not nil]] bestFit).slot)
    return true
  end

  -- Doesn't matter, drop in any available
  for _, bag in ipairs(self.PLAYER_BAGS) do
    if bag:HasSpace() then
      bag:PutCursorItem()
      return true
    end
  end

  RS:Debug("PutItemInPlayerBag: Could not drop item to bag for some reason")
  return false
end

---@param bags RsBagDef[]
function bagModule:CheckSpace(bags)
  for _, bag in ipairs(bags) do
    local numberOfFreeSlots, _bagType = restockerModule:GetContainerNumFreeSlots(bag.bagId)
    if numberOfFreeSlots > 0 then
      return true
    end
  end
  return false
end

---From bags list, retrieve items which are not locked and match predicate
---@param bags RsBagDef[] List of bags from bagModule.* constants
---@param predicate fun(itemInfo: RsGetContainerItemInfoResult): boolean
---@return RsGetContainerItemInfoResult[]
function bagModule:ScanBagsFor(bags, predicate)
  local itemCandidates = {} ---@type RsGetContainerItemInfoResult[]

  for _, bag in ipairs(bags) do
    for slot = 1, restockerModule:GetContainerNumSlots(bag.bagId), 1 do
      local containerItemInfo = restockerModule:GetContainerItemInfo(bag.bagId, slot)
      if containerItemInfo then
        if ( --[[---@not nil]] containerItemInfo).isLocked then
          return {} -- can't do nothing now, something is locked, try in 0.1 sec
        end

        if predicate(containerItemInfo) then
          table.insert(itemCandidates, --[[---@not nil]] containerItemInfo)
        end
      end -- if item in that slot
    end   -- for all slots
  end     -- for all bags

  return itemCandidates
end

-- TODO: Drop old algorithm below, use RsInventory.slots to pick smallest stack of specific item
---Filter function for ScanBagsFor, which matches the name
--- @return fun(itemInfo: RsGetContainerItemInfoResult): boolean
local function rsContainerItemInfoMatchName(name)
  return function(itemInfo)
    return itemInfo.name == name
  end
end

---Filter function for ScanBagsFor, which matches the name, but also must be
---smaller than stacksize and also smaller than the moveAmount
local function rsContainerItemInfoMatchNameAndSmall(name, moveAmount)
  return function(itemInfo)
    return itemInfo.name == name and itemInfo.count < moveAmount
  end
end

---Filter function for ScanBagsFor, which matches the name, but also must be
---1 item precisely
local function rsContainerItemInfoMatchNameAndIs1Item(name, moveAmount)
  return function(itemInfo)
    return itemInfo.name == name and itemInfo.count == 1
  end
end

---@param playerInventory RsInventory
---@param task RsMoveItemTask
---@param candidates RsContainerItemInfo[]
---@param moveAmount number
function bagModule:MoveFromBankToPlayer_1(playerInventory, task, candidates, moveAmount)
  for _index, moveCandidate in ipairs(candidates) do
    -- Move if entire stack found which fits
    if moveCandidate.count <= moveAmount then
      RS:Debug("Use " .. moveCandidate.name .. " from bank, bag=" .. moveCandidate.bag .. ", slot=" .. moveCandidate
        .slot)
      C_Container.UseContainerItem(moveCandidate.bag, moveCandidate.slot, nil, nil)
      task[moveCandidate.name] = task[moveCandidate.name] - moveCandidate.count -- deduct
      return true                                                               -- DONE one step
    end

    if moveCandidate.count > moveAmount then
      -- Can't be nil we know item exists
      local itemInfo = --[[---@not nil]] RS.GetItemInfo(moveCandidate.itemId)
      RS:Debug("Split " ..
        moveCandidate.name .. " from bank, bag=" .. moveCandidate.bag .. ", slot=" .. moveCandidate.slot)

      -- Split and take
      C_Container.SplitContainerItem(moveCandidate.bag, moveCandidate.slot, moveAmount)
      --coroutine.yield()

      bagModule:PutItemInPlayerBag(playerInventory, itemInfo, moveAmount)

      task[moveCandidate.name] = task[moveCandidate.name] - moveAmount -- deduct
      return true                                                      -- DONE one step
    end
  end

  return false
end

---@param playerInventory RsInventory
---@param task RsMoveItemTask
---@param moveName string
---@param moveAmount number Negative for take from bag, positive for take from bank
function bagModule:MoveFromBankToPlayer(playerInventory, task, moveName, moveAmount)
  local bankBagsReverse = self:GetBankBags(true)

  -------------------------------------------
  -- Try move from all bank bags in reverse
  -------------------------------------------
  for _index0, bag in ipairs(bankBagsReverse) do
    -- TODO: Drop old algorithm below, use RsInventory.slots
    -- Build list of move candidates. Sort them to contain smallest stacks first.
    local moveCandidates = self:ScanBagsFor({ bag }, rsContainerItemInfoMatchName(moveName))
    -- Possibly nil, and try again?
    if moveCandidates == nil then
      return false
    end

    table.sort(moveCandidates, itemModule.CompareByStacksizeAscending)

    if self:MoveFromBankToPlayer_1(playerInventory, task, moveCandidates, moveAmount) then
      return true
    end
  end          -- for bank bags in reverse order

  return false -- did not move
end

---@param bankInventory RsInventory
---@param candidates RsContainerItemInfo[] Sorted by stack size move candidates in different bag slots
function bagModule:MoveFromPlayerToBank_1(bankInventory, task, candidates, moveAmount)
  for _index, containerItemInfo in ipairs(candidates) do
    -- Found something to move and its smaller than what we need to move
    if containerItemInfo.count <= moveAmount then
      C_Container.UseContainerItem(containerItemInfo.bag, containerItemInfo.slot, nil, nil)
      task[containerItemInfo.name] = task[containerItemInfo.name] + containerItemInfo.count -- deduct
      return true                                                                           -- moved one
    end

    -- Found something to move, but its bigger than how many we need to move
    if containerItemInfo.count > moveAmount then
      -- No checking for nil as the item exists
      local itemInfo = RS.GetItemInfo(containerItemInfo.itemId)

      C_Container.SplitContainerItem(containerItemInfo.bag, containerItemInfo.slot, moveAmount)
      --coroutine.yield()

      bagModule:PutItemInBank(bankInventory, --[[---@not nil]] itemInfo, moveAmount)

      task[containerItemInfo.name] = task[containerItemInfo.name] + moveAmount -- add
      return true                                                              -- DONE one step
    end
  end

  return false
end

---@param bankInventory RsInventory
---@param task table<string, number> How many items should arrive or depart to player bags
---@param moveName string
---@param moveAmount number Negative for take from bag, positive for take from bank
function bagModule:MoveFromPlayerToBank(bankInventory, task, moveName, moveAmount)
  local playerBags = self:GetPlayerBags(false)

  -------------------------------------------
  -- Try move from all player bags
  -- Build list of candidates, slots where this item is located
  -- Sort the candidates by stack size to move smallest first
  -------------------------------------------
  for _index0, bag in ipairs(playerBags) do
    -- TODO: Drop old algorithm below, use RsInventory.slots
    -- Build list of move candidates. Sort them to contain smallest stacks first.
    local moveCandidates = self:ScanBagsFor(
      { bag }, rsContainerItemInfoMatchName(moveName))

    -- Possibly nil, and try again?
    if moveCandidates == nil then
      RS:Debug("No move candidates found for playerToBank?")
      return false
    end

    table.sort(moveCandidates, itemModule.CompareByStacksizeAscending)

    if self:MoveFromPlayerToBank_1(bankInventory, task, moveCandidates, moveAmount) then
      return true
    end
  end          -- for all player bags starting from main bag

  return false -- did not move
end

---@return string "ok", "bank" - bank is full, "bag" - bag is full, "both" - both bank and bag are full
function bagModule:CheckBankBagSpace()
  local bankFree = self:CheckSpace(bagModule.BANK_BAGS)
  local bagFree = self:CheckSpace(bagModule.PLAYER_BAGS)

  if bagFree then
    if bankFree then
      return "ok"
    else
      return "bank"
    end
  else
    if bankFree then
      return "bag"
    else
      return "both"
    end
  end
end