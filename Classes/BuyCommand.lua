--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
--local RS = RS_ADDON ---@type RestockerAddon

---@class RsBuyCommandModule
local buyCommandModule = RsModule.buyCommandModule

---Per-item vendor restock command with dormant bank preferences retained in saved data
---@class RsTradeCommand
---@field amount number
---@field itemName string
---@field itemLink string
---@field itemID number
---@field reaction number UnitReaction required to buy from vendor (4 neutral, 5 friendly, ... 8 exalted)
---@field buyFromMerchant boolean|nil Nil default true
---@field stashTobank boolean|nil Nil defaults to false
---@field restockFromBank boolean|nil Nil defaults to false

local buyItemClass = {}
buyItemClass.__index = buyItemClass

---@param amount number
---@param itemName string
---@param itemID number|nil
---@return RsTradeCommand
---@param itemLink string|nil
function buyCommandModule:Create(amount, itemName, itemID, itemLink)
  local fields = --[[---@type RsTradeCommand]] {}
  fields.amount = amount
  fields.itemName = itemName
  fields.itemID = itemID or 0
  fields.itemLink = itemLink or ""
  setmetatable(fields, buyItemClass)
  return fields
end
