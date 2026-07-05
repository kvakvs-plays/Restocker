--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsEventsModule
local eventsModule = RsModule.eventsModule

local bagModule = RsModule.bagModule ---@type RsBagModule
local bankModule = RsModule.bankModule ---@type RsBankModule
local buyiModule = RsModule.buyIngredientsModule ---@type RsBuyIngredientsModule
local merchantModule = RsModule.merchantModule ---@type RsMerchantModule
local restockerModule = RsModule.restockerModule ---@type RsRestockerModule

RS.loaded = false
RS.addItemWait = {}

function eventsModule.OnEnteringWorld(login, reloadui)
end

function eventsModule.OnMerchantShow()
  -- prevents double init but sometimes does not init when entering world too soon?
  buyiModule:SetupAutobuyIngredients()

  RS.buying = true

  if IsShiftKeyDown() then
    return
  end -- If shiftkey is down return

  merchantModule.merchantIsOpen = true
  merchantModule:Restock() -- each item can be individually enabled to restock from merchant
end

function eventsModule.OnMerchantClose()
  merchantModule.merchantIsOpen = false
  RS:Hide()
end

function eventsModule.OnBankOpen()
  local settings = restockerModule.settings

  if IsShiftKeyDown()
      or settings.profiles[settings.currentProfile] == nil then
    return
  end

  if settings.autoOpenAtBank then
    RS:Show()
  end

  bankModule.bankIsOpen = true
  bankModule:RestartRestocking()
end

function eventsModule.OnBankClose()
  bankModule.bankIsOpen = false
  bankModule.currentlyRestocking = false
  RS:Hide()
end

---@param itemID number
---@param success boolean
function eventsModule.OnItemInfoReceived(itemID, success)
  if success == nil then
    return
  end

  -- If this was an autobuy item setup item request
  if #buyiModule.buyIngredientsWait > 0 then
    buyiModule:RetryWaitRecipes()
  end

  -- If this was an item add request for an unknown item
  if RS.addItemWait[itemID] then
    RS.addItemWait[itemID] = nil
    RS:addItem(itemID)
  end
end

function eventsModule.OnLogout()
  local settings = restockerModule.settings

  if settings.framePos == nil then
    settings.framePos = {}
  end

  RS:Show()
  RS:Hide()

  local point, relativeTo, relativePoint, xOfs, yOfs = RS.MainFrame:GetPoint(RS.MainFrame:GetNumPoints())

  settings.framePos.point = point
  settings.framePos.relativePoint = relativePoint
  settings.framePos.xOfs = xOfs
  settings.framePos.yOfs = yOfs

  -- Pack items into the compact one-line-per-item form for the SavedVariables file.
  -- Must be last here, since RS:Show()/Update() above iterate items as tables.
  RS:DeflateForSave()
end

function eventsModule.OnUiErrorMessage(id, message)
  if id == 2 or id == 3 then
    -- "Inventory is full" / "Bank is full". Do NOT hard-stop restocking here: this error
    -- can fire on a transient race, and silently killing the whole run is what left later
    -- items untouched. The restock loop re-scans every step and stops itself with a clear
    -- message when it's genuinely out of room (see RunRestockLogic / StuckMessage). Buying,
    -- which has no such self-check, still stops.
    RS.buying = false
  end
end

function eventsModule:InitEvents()
  --RS:RegisterEvent("ADDON_LOADED", self.OnAddonLoaded);
  RS:RegisterEvent("MERCHANT_SHOW", self.OnMerchantShow);
  RS:RegisterEvent("MERCHANT_CLOSED", self.OnMerchantClose);
  RS:RegisterEvent("BANKFRAME_OPENED", self.OnBankOpen);
  RS:RegisterEvent("BANKFRAME_CLOSED", self.OnBankClose);
  RS:RegisterEvent("GET_ITEM_INFO_RECEIVED", self.OnItemInfoReceived);
  RS:RegisterEvent("PLAYER_LOGOUT", self.OnLogout);
  RS:RegisterEvent("PLAYER_ENTERING_WORLD", self.OnEnteringWorld);
  RS:RegisterEvent("UI_ERROR_MESSAGE", self.OnUiErrorMessage);
end
