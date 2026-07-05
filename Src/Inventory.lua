--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsInventoryModule
local inventoryModule = RsModule.inventoryModule

---@class RsInventorySlotNumber
---@field bag number
---@field slot number
local slotNumberClass = {}
slotNumberClass.__index = slotNumberClass

---@class RsSlot
---@field bag number
---@field slot number
---@field count number
local slotClass = {}
slotClass.__index = slotClass

---@alias RsInventoryCountByItemId {[number]: number} Stack totals keyed by itemID
---@alias RsInventorySlotByItemId {[number]: RsSlot[]} Bag slots keyed by itemID
---@alias RsMoveItemTask table<number, number> itemID is key, amount to move is value

---Collection of items in the inventory or bank with their precise slot locations and counts, and summaries
---@class RsInventory
---@field summary RsInventoryCountByItemId
---@field slots RsInventorySlotByItemId
local inventoryClass = {} ---@type RsInventory
inventoryClass.__index = inventoryClass

---@param bag number
---@param slot number
---@param itemCount number
---@return RsSlot
function inventoryModule:NewSlot(bag, slot, itemCount)
  local slotObj = --[[---@type RsSlot]] {
    bag = bag,
    slot = slot,
    count = itemCount,
  }
  setmetatable(slotObj, slotClass)
  return slotObj
end

---@param bag number
---@param slot number
---@return RsInventorySlotNumber
function inventoryModule:NewSlotNumber(bag, slot)
  local slNum = --[[---@type RsInventorySlotNumber]] {
    bag = bag,
    slot = slot,
  }
  setmetatable(slNum, slotNumberClass)
  return slNum
end

---@return RsInventory
function inventoryModule:NewInventory()
  local inv = --[[---@type RsInventory]] {
    summary = {},
    slots = {},
  }
  setmetatable(inv, inventoryClass)
  return inv
end

---Sorts bag slots for each item, with smallest stacks first
function inventoryClass:SortSlots()
  local sortFn = function(a, b)
    return a.count < b.count
  end
  for _key, eachItemSlots in pairs(self.slots) do
    table.sort(eachItemSlots, sortFn)
  end
end

---@param cachedItem GIICacheItem
---@param amount number
---@param bags RsBagDef[]
---@return RsInventorySlotNumber|nil
function inventoryClass:FindBestFit(cachedItem, amount, bags)
  local containingSlots = self.slots[cachedItem.itemId]
  if not containingSlots then
    RS:Debug("BestFit: no existing stacks for merging %s x%s", cachedItem.itemName, amount)
    return nil
  end

  local mergeDestinations = --[[---@type RsSlot[] ]] {}

  for i, invSlot in ipairs(containingSlots) do
    local remainingAfterMerge = cachedItem.itemStackCount - (invSlot.count + amount)

    -- If can merge into this slot
    if remainingAfterMerge >= 0 then
      local candidate = inventoryModule:NewSlot(invSlot.bag, invSlot.slot, remainingAfterMerge)
      table.insert(mergeDestinations, candidate)
    end
  end

  if #mergeDestinations == 0 then
    RS:Debug("BestFit: found stacks but no candidates for merging %s x%s", cachedItem.itemName, amount)
    return nil
  end

  -- Pick smallest remaining
  table.sort(mergeDestinations,
      ---@param a RsSlot
      ---@param b RsSlot
      function(a, b)
        return a.count < b.count
      end)

  -- First element should be lowest, i.e. closest to the perfection of a full stack
  local bestDestination = mergeDestinations[1]
  RS:Debug("BestFit: candidate for merging %s x%s is %s:%s",
      cachedItem.itemName, amount, bestDestination.bag, bestDestination.slot)
  return inventoryModule:NewSlotNumber(bestDestination.bag, bestDestination.slot)
end
