--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsBagModule
---@field PLAYER_BAGS RsBagDef[] Indexes of player bags
---@field PLAYER_BAGS_REVERSED RsBagDef[]
---@field BANK_BAGS RsBagDef[]
---@field BANK_BAGS_REVERSED RsBagDef[]

local bagModule = RsModule.bagModule ---@type RsBagModule
local itemModule = RsModule.itemModule ---@type RsItemModule
local kvEnvModule = KvModuleManager.envModule
local inventoryModule = RsModule.inventoryModule ---@type RsInventoryModule

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

bagModule.BANK_BAGS = --[[---@type RsBagDef[] ]] {} -- set up in RS.SetupBankConstants
bagModule.BANK_BAGS_REVERSED = --[[---@type RsBagDef[] ]] {} -- set up in RS.SetupBankConstants

---Converts bag indexes 1..4 (bags after the backpack) to inventory slot indexes
---(example retail Dragonflight 31..34)
local function bagSlotFromBag(bag)
  RS:Debug("bagSlotFromBag bag=%s", bag)
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
  -- location "bank", NOT "bag": bank bags must be filled by dropping into a specific empty
  -- slot (PickupContainerItem), like the main bank container. PutItemInBag(invslot) clears
  -- the cursor immediately and lets the SERVER pick the slot -- when the server then refuses
  -- the drop, the item silently bounces back to the player bag and the addon believes the
  -- move landed, which looped the stash watchdog until it gave up.
  return bagModule:NewBagDef("bank", bagId, C_Container.ContainerIDToInventoryID(bagId))
end

function bagModule.OnModuleInit()
  bagModule.BANK_BAGS = { createBankMainBag(), createBankBag(1), createBankBag(2), createBankBag(3),
                          createBankBag(4), createBankBag(5), createBankBag(6), createBankBag(7) }
  bagModule.BANK_BAGS_REVERSED = { createBankBag(7), createBankBag(6), createBankBag(5),
                                   createBankBag(4), createBankBag(3), createBankBag(2), createBankBag(1),
                                   createBankMainBag() }

  bagModule.PLAYER_BAGS = { createBackpack(),
                            createBag(1), createBag(2), createBag(3), createBag(4) }
  bagModule.PLAYER_BAGS_REVERSED = { createBag(4), createBag(3), createBag(2), createBag(1),
                                     createBackpack() }
end

function bagDefClass:NumSlots()
  return C_Container.GetContainerNumSlots(self.bagId)
end

  ---@return boolean
function bagDefClass:HasSpace()
  local numberOfFreeSlots, _bagType = C_Container.GetContainerNumFreeSlots(self.bagId)
  return numberOfFreeSlots > 0
end

---True if this container has a free slot AND is allowed to hold the given item. A free-slot
---count alone is not enough: a specialty bag (quiver, soul/herb/enchanting bag) reports free
---slots that a regular item can never occupy, so "has space" placement into it is refused --
---which, via PutItemInBag, silently bounced the item back to the player bags.
---@param itemInfo GIICacheItem|nil nil (item not cached) allows only regular bags
---@return boolean
function bagDefClass:CanAcceptItem(itemInfo)
  local numberOfFreeSlots, bagType = C_Container.GetContainerNumFreeSlots(self.bagId)
  if numberOfFreeSlots <= 0 then
    return false
  end
  if not bagType or bagType == 0 then
    return true -- regular container takes anything
  end
  if not itemInfo then
    return false -- unknown item: only trust regular containers
  end
  if itemInfo.itemEquipLoc == "INVTYPE_BAG" then
    return false -- equippable bags can only be stored in regular containers
  end
  local itemFamily = GetItemFamily(itemInfo.itemId)
  return itemFamily ~= nil and itemFamily ~= 0 and bit.band(itemFamily, bagType) ~= 0
end

---Attempt to drop the cursor item into this container. May leave the item on the cursor if
---the container has no usable slot (the caller checks CursorHasItem() and moves on) -- it
---must NOT clear the cursor itself, or the item would be lost before another bag is tried.
function bagDefClass:PutCursorItem()
  RS:Debug("PutCursorItem(%s) bag=%s invslot=%s", self.location, self.bagId, tostring(self.containerSlotId))

  if self.location == "backpack" then
    PutItemInBackpack()
  elseif self.location == "bank" then
    -- Drop into the first genuinely-empty slot of this bank container. Detect empty
    -- with GetContainerItemInfo -- it returns nil ONLY when the slot is truly empty, whereas
    -- GetContainerItemLink is also nil for a not-yet-cached item, which made us "place" onto
    -- an occupied slot and strand the item. Don't ClearCursor on miss: leave it for the
    -- caller to try the next bank bag.
    for slot = 1, C_Container.GetContainerNumSlots(self.bagId) do
      if not C_Container.GetContainerItemInfo(self.bagId, slot) then
        C_Container.PickupContainerItem(self.bagId, slot)
        return
      end
    end
  else
    -- Drop in the bag; a no-op that leaves the item on the cursor if the bag is full
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

---True if any slot we care about is still mid-move (locked). A locked slot means the last
---move hasn't settled on the server yet -- issuing the next one now is exactly what gets a
---split rejected with "Couldn't split those items".
---@param profile table<number, RsTradeCommand>|nil When given, only locks on items in the
---profile count. An unrelated locked item (something the player is equipping, a pending
---trade) must NOT stall the whole restock forever, which the old blanket check allowed.
---@return boolean
function bagModule:IsSomethingLocked(profile)
  local function anyLocked(bags)
    for _, bag in ipairs(bags) do
      for slot = 1, C_Container.GetContainerNumSlots(bag.bagId) do
        local itemInfo = C_Container.GetContainerItemInfo(bag.bagId, slot)
        if itemInfo and itemInfo.isLocked
            and (profile == nil or (itemInfo.itemID and profile[itemInfo.itemID] ~= nil)) then
          return true
        end
      end
    end
    return false
  end

  return anyLocked(self.PLAYER_BAGS) or anyLocked(self.BANK_BAGS_REVERSED)
end

---@param predicate fun(id: number): boolean|nil
---@return RsInventory
function bagModule:GetItemsInBags(predicate)
  local result = inventoryModule:NewInventory()

  for _, bag in ipairs(self.PLAYER_BAGS) do
    for slot = 1, C_Container.GetContainerNumSlots(bag.bagId) do
      local itemInfo = C_Container.GetContainerItemInfo(bag.bagId, slot)

      -- Keyed by itemID: unambiguous, locale-proof, and matches the profile's keys
      if itemInfo and itemInfo.itemID then
        local id = itemInfo.itemID

        -- Allow filtering by predicate
        if predicate == nil or predicate(id) == true then
          result.summary[id] = (result.summary[id] or 0) + itemInfo.stackCount

          result.slots[id] = result.slots[id] or {}
          table.insert(result.slots[id], inventoryModule:NewSlot(bag.bagId, slot, itemInfo.stackCount))
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
    for slot = 1, C_Container.GetContainerNumSlots(bag.bagId) do
      --local _, itemCount, locked, _, _, _, itemLink, _, _, itemID =
      local itemInfo = C_Container.GetContainerItemInfo(bag.bagId, slot)

      if itemInfo and itemInfo.itemID and itemInfo.hyperlink then
        local itemName = --[[---@type string]] (string.match(itemInfo.hyperlink, "%[(.*)%]"))
        handler(bag.bagId, slot, itemName, itemInfo.itemID, itemInfo.stackCount)
      end
    end
  end
  return result
end

---@param predicate fun(id: number): boolean|nil
---@return RsInventory
function bagModule:GetItemsInBank(predicate)
  local result = inventoryModule:NewInventory()

  for _, bag in ipairs(self.BANK_BAGS_REVERSED) do
    for slot = 1, C_Container.GetContainerNumSlots(bag.bagId) do
      --local _, itemCount, locked, _, _, _, itemLink, _, _, itemID =
      local itemInfo = C_Container.GetContainerItemInfo(bag.bagId, slot)
      -- Keyed by itemID (no hyperlink/name parsing needed)
      if itemInfo and itemInfo.itemID then
        local id = itemInfo.itemID

        -- Allow filtering by predicate
        if predicate == nil or predicate(id) == true then
          result.summary[id] = (result.summary[id] or 0) + itemInfo.stackCount

          result.slots[id] = result.slots[id] or {}
          table.insert(result.slots[id], inventoryModule:NewSlot(bag.bagId, slot, itemInfo.stackCount))
        end
      end
    end
  end

  result:SortSlots()
  return result
end

---Takes cursor item. Drops it into the bank, preferring a free slot.
---@param bankInventory RsInventory
---@param itemInfo GIICacheItem|nil used only for the last-resort merge; nil if uncached
---@param amount number
---@return boolean Success
function bagModule:PutItemInBank(bankInventory, itemInfo, amount)
  if not CursorHasItem() then
    return false
  end

  -- Drop into a FREE slot first -- that is the reliable move. Only stop once it has ACTUALLY
  -- landed: a container's free-slot COUNT can disagree with its per-slot contents
  -- -- notably the main bank container reports free slots the slot scan can't find -- so a
  -- bag may claim room yet fail to take the item. Keep trying the rest, don't give up after
  -- the first (which stranded the item on the cursor).
  for _, bag in ipairs(self.BANK_BAGS) do
    if bag:CanAcceptItem(itemInfo) then
      bag:PutCursorItem()
      if not CursorHasItem() then
        break -- landed
      end
    end
  end

  -- No free slot took it (bank effectively full). LAST resort: merge into the best partial
  -- stack. We AVOID doing this first because merging a just-split cursor item onto an
  -- occupied same-item slot can be rejected and BOUNCE the item back to its source, emptying
  -- the cursor without it ever landing (that's what left "9 need 10" stuck). When the bank
  -- is full it's the only chance to land the item; if it still bounces, the next re-scan and
  -- the watchdog report it honestly.
  if CursorHasItem() and itemInfo then
    local bestFit = bankInventory:FindBestFit(itemInfo, amount, self.BANK_BAGS)
    if bestFit then
      C_Container.PickupContainerItem(bestFit.bag, bestFit.slot)
    end
  end

  -- CRITICAL: never leave an item stranded on the cursor. A stranded item is what makes
  -- the NEXT SplitContainerItem throw "Couldn't split those items".
  if CursorHasItem() then
    RS:Debug("PutItemInBank: no room to drop, clearing cursor")
    ClearCursor()
    return false
  end

  return true
end

---Takes cursor item. Drops it into the player bags, preferring a free slot.
---@param playerInventory RsInventory
---@param itemInfo GIICacheItem|nil used only for the last-resort merge; nil if uncached
---@param amount number
---@return boolean Success
function bagModule:PutItemInPlayerBag(playerInventory, itemInfo, amount)
  if not CursorHasItem() then
    return false
  end

  -- Drop into a FREE slot first -- reliable. Keep trying bags until it actually lands
  -- (a bag can claim room it won't grant this item), don't give up after the first.
  for _, bag in ipairs(self.PLAYER_BAGS) do
    if bag:CanAcceptItem(itemInfo) then
      bag:PutCursorItem()
      if not CursorHasItem() then
        break -- landed
      end
    end
  end

  -- No free slot took it (bags effectively full). LAST resort: merge into the best partial
  -- stack. We AVOID doing this first because merging a just-split cursor item onto an
  -- occupied same-item slot can be rejected and BOUNCE the item back to the bank, emptying
  -- the cursor without it ever landing -- exactly what left the final unit stuck at "9 need
  -- 10". When bags are full it's the only way to top off a stack; a bounce is caught by the
  -- next re-scan and the watchdog.
  if CursorHasItem() and itemInfo then
    local bestFit = playerInventory:FindBestFit(itemInfo, amount, self.PLAYER_BAGS)
    if bestFit then
      C_Container.PickupContainerItem(bestFit.bag, bestFit.slot)
    end
  end

  -- CRITICAL: never leave an item stranded on the cursor. A stranded item is what makes
  -- the NEXT SplitContainerItem throw "Couldn't split those items".
  if CursorHasItem() then
    RS:Debug("PutItemInPlayerBag: no room to drop, clearing cursor")
    ClearCursor()
    return false
  end

  return true
end

---@param bags RsBagDef[]
function bagModule:CheckSpace(bags)
  for _, bag in ipairs(bags) do
    local numberOfFreeSlots, _bagType = C_Container.GetContainerNumFreeSlots(bag.bagId)
    if numberOfFreeSlots > 0 then
      return true
    end
  end
  return false
end

---From bags list, retrieve items which are not locked and match predicate
---@param bags RsBagDef[] List of bags from bagModule.* constants
---@param predicate function
---@return RsContainerItemInfo[]
function bagModule:ScanBagsFor(bags, predicate)
  local itemCandidates = --[[---@type RsContainerItemInfo[] ]] {}

  for _, bag in ipairs(bags) do
    for slot = 1, C_Container.GetContainerNumSlots(bag.bagId), 1 do
      local containerItemInfo = itemModule:GetContainerItemInfo(bag.bagId, slot)
      if containerItemInfo then
        if (--[[---@not nil]] containerItemInfo).locked then
          return {} -- can't do nothing now, something is locked, try in 0.1 sec
        end

        if predicate(containerItemInfo) then
          table.insert(itemCandidates, --[[---@not nil]] containerItemInfo)
        end
      end -- if item in that slot
    end -- for all slots
  end -- for all bags

  return itemCandidates
end

---Filter function for ScanBagsFor, matching a specific itemID (locale-proof, and never
---confuses two different items that share a localized name).
---@param id number
local function rsContainerItemInfoMatchId(id)
  return function(itemInfo)
    return itemInfo.itemId == id
  end
end

---Issue at most one bank->bag move from the given candidates. No plan bookkeeping is
---deducted here on purpose: the caller re-scans real inventory next step, so a move that
---the server rejected or only partially placed simply shows up as "still short" and is
---retried -- rather than being counted as done (which silently left items short).
---@param playerInventory RsInventory Freshly re-scanned this step, so best-fit merge is real
---@param candidates RsContainerItemInfo[]
---@param moveAmount number How many we still need in bags (> 0)
---@param overshoot boolean Last step made no progress, i.e. the exact split is being bounced
---by the server ("Couldn't split those items") -- pull a WHOLE stack instead and go over
---target. UseContainerItem is the one move the server never bounces; overshooting past the
---target is what guarantees it gets reached, and the stash-back pass returns the excess for
---items that stash to bank. Going a little over beats stopping short.
---@return boolean True if a physical move was issued
function bagModule:MoveFromBankToPlayer_1(playerInventory, candidates, moveAmount, overshoot)
  for _index, moveCandidate in ipairs(candidates) do

    -- A whole stack that fits within what we still need
    if moveCandidate.count <= moveAmount then
      RS:Debug("Use %s from bank, bag=%s, slot=%s", moveCandidate.name, moveCandidate.bag, moveCandidate.slot)
      C_Container.UseContainerItem(moveCandidate.bag, moveCandidate.slot, nil, nil)
      return true -- issued one move; next step re-scans and continues
    end

    -- Stack is bigger than the remainder: split off exactly what's left to do
    if moveCandidate.count > moveAmount then
      if overshoot then
        RS:Debug("Overshoot %s from bank (split not landing), bag=%s, slot=%s",
            moveCandidate.name, moveCandidate.bag, moveCandidate.slot)
        C_Container.UseContainerItem(moveCandidate.bag, moveCandidate.slot, nil, nil)
        return true -- issued one move; next step re-scans and continues
      end

      local itemInfo = RS.GetItemInfo(moveCandidate.itemId)
      RS:Debug("Split %s from bank, bag=%s, slot=%s", moveCandidate.name, moveCandidate.bag, moveCandidate.slot)
      C_Container.SplitContainerItem(moveCandidate.bag, moveCandidate.slot, moveAmount)
      bagModule:PutItemInPlayerBag(playerInventory, itemInfo, moveAmount)
      return true -- issued one move; next step re-scans and continues
    end
  end

  return false
end

---@param playerInventory RsInventory
---@param moveId number itemID to move
---@param moveAmount number How many we still need in bags (> 0)
---@param overshoot boolean Fall back to whole-stack pulls, see MoveFromBankToPlayer_1
function bagModule:MoveFromBankToPlayer(playerInventory, moveId, moveAmount, overshoot)
  local bankBagsReverse = self:GetBankBags(true)

  -------------------------------------------
  -- Try move from all bank bags in reverse
  -------------------------------------------
  for _index0, bag in ipairs(bankBagsReverse) do
    -- Build list of move candidates (matched by itemID), smallest stacks first
    local moveCandidates = self:ScanBagsFor({ bag }, rsContainerItemInfoMatchId(moveId))
    -- Possibly nil, and try again?
    if moveCandidates == nil then
      return false
    end

    table.sort(moveCandidates, itemModule.CompareByStacksizeAscending)

    if self:MoveFromBankToPlayer_1(playerInventory, moveCandidates, moveAmount, overshoot) then
      return true
    end
  end -- for bank bags in reverse order

  return false -- did not move
end

---Issue at most one bag->bank move. As with MoveFromBankToPlayer_1, nothing is deducted --
---the next step's re-scan reflects what actually moved.
---@param bankInventory RsInventory Freshly re-scanned this step
---@param candidates RsContainerItemInfo[] Sorted by stack size move candidates in different bag slots
---@param moveAmount number How much excess we still need to stash (> 0)
---@return boolean True if a physical move was issued
function bagModule:MoveFromPlayerToBank_1(bankInventory, candidates, moveAmount)
  for _index, containerItemInfo in ipairs(candidates) do
    -- Found something to move and its smaller than what we need to move
    if containerItemInfo.count <= moveAmount then
      C_Container.UseContainerItem(containerItemInfo.bag, containerItemInfo.slot, nil, nil)
      return true -- issued one move; next step re-scans and continues
    end

    -- Found something to move, but its bigger than how many we need to move
    if containerItemInfo.count > moveAmount then
      -- May be nil if the item isn't cached; PutItemInBank then drops it in a free slot
      local itemInfo = RS.GetItemInfo(containerItemInfo.itemId)

      C_Container.SplitContainerItem(containerItemInfo.bag, containerItemInfo.slot, moveAmount)
      bagModule:PutItemInBank(bankInventory, itemInfo, moveAmount)
      return true -- issued one move; next step re-scans and continues
    end
  end

  return false
end

---@param bankInventory RsInventory
---@param moveId number itemID to move
---@param moveAmount number How much excess to stash into the bank (> 0)
function bagModule:MoveFromPlayerToBank(bankInventory, moveId, moveAmount)
  -- Candidates come from ALL player bags at once, sorted smallest stack first GLOBALLY.
  -- Scanning bag-by-bag made an early bag's big stack get SPLIT (the flaky cursor move)
  -- even when a later bag held a loose stack of exactly the excess that a whole-stack
  -- UseContainerItem -- the reliable, server-side deposit -- could have moved instead.
  local moveCandidates = self:ScanBagsFor(self:GetPlayerBags(false), rsContainerItemInfoMatchId(moveId))

  table.sort(moveCandidates, itemModule.CompareByStacksizeAscending)

  return self:MoveFromPlayerToBank_1(bankInventory, moveCandidates, moveAmount)
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
