--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
--local RS = RS_ADDON ---@type RestockerAddon

---@class RsItemModule
local itemModule = RsModule.itemModule

---@class RsItem
---@field id number
---@field englishName string Name as it appears in English
---@field localizedName string Name in current client language

local itemClass = {}
itemClass.__index = itemClass

---@param id number
---@param englishName string
---@return RsItem
function itemModule:Create(id, englishName)
  local fields = --[[---@type RsItem]] {}
  fields.id = id
  fields.englishName = englishName

  setmetatable(fields, itemClass)

  return fields
end

---@param gii GIICacheItem
---@return RsItem
function itemModule:FromCachedItem(gii)
  local fields = --[[---@type RsItem]] {}
  fields.id = gii.itemId
  fields.englishName = gii.itemName

  setmetatable(fields, itemClass)

  return fields
end

-- ---@class RsContainerItemInfo
-- ---@field bag number Bag number where the item is found
-- ---@field slot number Slot number in the bag
-- ---@field icon WowIconId
-- ---@field count number
-- ---@field itemId number
-- ---@field locked boolean
-- ---@field link string
-- ---@field name string Extracted from item link, localized name

-- ---@return RsContainerItemInfo|nil
-- function itemModule:GetContainerItemInfo(bagId, slot)
--   --local icon, slotCount, slotLocked, _, _, _, slotItemLink, _, _, slotItemId =
--   local itemInfo = C_Container.GetContainerItemInfo(bagId, slot)
--   if not itemInfo then
--     return nil
--   end
--   local itemName = string.match(itemInfo.hyperlink, "%[(.*)%]")

--   local i = --[[---@type RsContainerItemInfo]] {}
--   i.bag = bagId
--   i.slot = slot
--   i.icon = itemInfo.iconFileID
--   i.count = itemInfo.stackCount
--   i.locked = itemInfo.isLocked
--   i.link = itemInfo.hyperlink
--   i.itemId = itemInfo.itemID
--   i.name = --[[---@type string]] itemName
--   return i
-- end

---Compare whether a is less than b
---For use in table.sort(table, itemModule.CompareByStacksizeAscending) to sort by stack size
function itemModule.CompareByStacksizeAscending(a, b)
  return a.count < b.count
end
