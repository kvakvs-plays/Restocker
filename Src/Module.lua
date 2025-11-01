---@class RsModuleModule
---@field addonOptionsModule RsAddonOptionsModule
---@field bagModule RsBagModule
---@field bankModule RsBankModule
---@field buyCommandModule RsBuyCommandModule
---@field buyIngredientsModule RsBuyIngredientsModule
---@field eventsModule RsEventsModule
---@field inventoryModule RsInventoryModule
---@field itemModule RsItemModule
---@field mainFrameModule RsMainFrameModule
---@field merchantModule RsMerchantModule
---@field recipeModule RsRecipeModule
---@field restockerModule RsRestockerModule
---@field settingsModule RsSettingsModule
local rsModule = {
  addonOptionsModule = {},
  bagModule = {},
  bankModule = {},
  buyCommandModule = {},
  buyIngredientsModule = {},
  eventsModule = {},
  itemModule = {},
  inventoryModule = {},
  mainFrameModule = {},
  merchantModule = {},
  recipeModule = {},
  restockerModule = {},
  settingsModule = {},
}
RsModule = rsModule

---For each known module call function by fnName and optional context will be
---passed as 1st argument, can be ignored (defaults to nil)
---module:EarlyModuleInit (called early on startup)
---module:LateModuleInit (called late on startup, after entered world)
function RsModule:CallInEachModule(fnName, context)
  for _name, module in pairs( --[[---@type table]] rsModule) do
    -- Only interested in table fields, skip functions
    if module and type(module) == "table" and module[fnName] then
      module[fnName](context)
    end
  end
end