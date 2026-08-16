--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
--local RS = RS_ADDON ---@type RestockerAddon

-- TODO: Remove this; move fields to RestockerAddon
---@class RestockerConf
---@field profiles table<string, table<string, number>>
---@field currentProfile string
---@field autoBuy boolean
---@field restockFromBank boolean
---@field autoOpenAtBank boolean
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
