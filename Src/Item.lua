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
