--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
--local RS = RS_ADDON ---@type RestockerAddon

---@class RsBuyCommandModule
local buyCommandModule = RsModule.buyCommandModule

---Order to bank-get, bank-put, buy or sell items depending on context.
---When saved in a profile, these are keyed by itemID and only itemName, itemID,
---amount and the flags below are persisted. itemLink is NOT saved any more (it is
---rebuilt on demand from itemID); it is only populated on transient merchant orders.
---@class RsTradeCommand
---@field amount number
---@field itemName string Saved for human readability and merchant/bank name matching
---@field itemType string|nil Human-readable class from GetItemInfo ("Consumable", ...); a sort label only
---@field itemLink string Transient only (merchant orders); not stored in saved data
---@field itemID number The profile key; uniquely identifies the item
---@field reaction number UnitReaction required to buy from vendor (4 neutral, 5 friendly, ... 8 exalted)
---@field buyFromMerchant boolean|nil Nil default true
---@field stashTobank boolean|nil Nil default false
---@field restockFromBank boolean|nil Nil default false

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