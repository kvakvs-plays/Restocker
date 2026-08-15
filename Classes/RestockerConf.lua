--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
--local RS = RS_ADDON ---@type RestockerAddon

-- TODO: Remove this; move fields to RestockerAddon
---@class RestockerConf
---@field profiles table<string, table<string, number>>
---@field currentProfile string
---@field autoBuy boolean
---@field restockFromBank boolean Dormant bank preference retained for a future rewrite
---@field autoOpenAtBank boolean Dormant bank preference retained for a future rewrite
---@field autoOpenAtMerchant boolean
---@field loginMessage boolean

local rsConfClass         = {}
rsConfClass.__index = rsConfClass

-- -@return RsItem
--function rsConfClass.Create(fields)
--  fields = fields or {}
--  setmetatable(fields, rsConfClass)
--  return fields
--end
