local TOCNAME, _ADDONPRIVATE = ... ---@type string, RestockerAddon

---@class RsRestockerModule
---@field settings RsSettings
local restockerModule = RsModule.restockerModule
restockerModule.settings = --[[---@type RsSettings]] {}

local restockItemList = {} ---@type RsTradeCommand[]

local aceMainFrameModule = RsModule.aceMainFrameModule
local bankModule = RsModule.bankModule
local eventsModule = RsModule.eventsModule
local merchantModule = RsModule.merchantModule
local addonOptionsModule = RsModule.addonOptionsModule
local envModule = KvModuleManager.envModule

local RS = --[[---@type RestockerAddon]] LibStub("AceAddon-3.0"):NewAddon(
  "Restocker", "AceConsole-3.0", "AceEvent-3.0")
RS_ADDON = RS ---@type RestockerAddon

RS.defaults = {
  prefix = "|cff8d63ffRestocker|r ",
  color = "8d63ff",
  slash = "|cff8d63ff/rs|r "
}

RS.BAG_ICON = "Interface\\ICONS\\INV_Misc_Bag_10_Green" -- bag icon for add tooltip

--function RS.Print(...)
--  DEFAULT_CHAT_FRAME:AddMessage(RS.addonName .. "- " .. tostringall(...))
--end

RS.slashPrefix = "|cff8d63ff/restocker|r "
RS.addonName = "|cff8d63ffRestocker|r "

function RS:Show()
  if RS.loaded then
    aceMainFrameModule:Show()
    return RS:Update()
  end
end

function RS:Hide()
  if RS.loaded then
    aceMainFrameModule:Hide()
  end
end

function RS:Toggle()
  if RS.loaded then
    if aceMainFrameModule:Toggle() then
      return RS:Update()
    end
  end
end

RS.commands = {
  show = RS.defaults.slash .. "show - Show the addon",
  profile = --[[---@type {[string]: string}]] {
    add = RS.defaults.slash .. "profile add [name] - Adds a profile with [name]",
    delete = RS.defaults.slash .. "profile delete [name] - Deletes profile with [name]",
    rename = RS.defaults.slash .. "profile rename [name] - Renames current profile to [name]",
    copy = RS.defaults.slash .. "profile copy [name] - Copies profile [name] into current profile.",
    use = RS.defaults.slash .. "profile use [name] - Switches active profile to [name].",
    config = RS.defaults.slash .. "config - Opens the interface options menu."
  }
}

--[[
  SLASH COMMANDS
]]
function RS:SlashCommand(args)
  local command, rest = strsplit(" ", args, 2)
  command = command:lower()

  if command == "show" then
    RS:Show()
  elseif command == "profile" then
    if rest == "" or rest == nil then
      for _, v in pairs(RS.commands.profile) do
        RS:Print(v)
      end
      return
    end

    local subcommand, name = strsplit(" ", rest, 2)

    if subcommand == "add" then
      RS:AddProfile(name)
    elseif subcommand == "delete" then
      RS:DeleteProfile(name)
    elseif subcommand == "rename" then
      RS:RenameCurrentProfile(name)
    elseif subcommand == "use" then
      RS:ChangeProfile(name)
    elseif subcommand == "copy" then
      RS:CopyProfile(name)
    end
  elseif command == "help" then
    for _, eachCommand in pairs(RS.commands) do
      if type(eachCommand) == "table" then
        for _, eachSubcommand in pairs( --[[---@type table]] eachCommand) do
          RS:Print(eachSubcommand)
        end
      else
        RS:Print(eachCommand)
      end
    end
    return
  elseif command == "config" then
    LibStub("AceConfigDialog-3.0"):Open(TOCNAME)
    return
  else
    RS:Toggle()
  end
  RS:Update()
end

--[[
  UPDATE
]]
function RS:Update()
  local settings = restockerModule.settings
  local currentProfile = --[[---@not nil]] settings.profiles[settings.currentProfile]
  wipe(restockItemList)

  for i, v in ipairs(currentProfile) do
    table.insert(restockItemList, v)
  end

  if RS.sortListAlphabetically then
    table.sort(restockItemList, function(a, b)
      return a.itemName < b.itemName
    end)
  elseif RS.sortListNumerically then
    table.sort(restockItemList, function(a, b)
      return a.amount > b.amount
    end)
  end

  aceMainFrameModule:Refresh(restockItemList)
end

--[[
  ADD PROFILE
]]
---@param newProfile string
function RS:AddProfile(newProfile)
  local settings = restockerModule.settings
  settings.currentProfile = newProfile ---@type string
  settings.profiles[newProfile] = {} ---@type RsTradeCommand

  aceMainFrameModule:Show()
  RS:Update()
end

--[[
  DELETE PROFILE
]]
---@param profile string
function RS:DeleteProfile(profile)
  local settings = restockerModule.settings
  local currentProfile = settings.currentProfile
  local profileCount = 0

  for _profileName, _ in pairs(settings.profiles) do
    profileCount = profileCount + 1
  end

  if currentProfile == profile then
    if profileCount > 1 then
      settings.profiles[currentProfile] = nil
      local firstKey, _ = next(settings.profiles)
      settings.currentProfile = --[[---@not nil]] firstKey
    else
      settings.profiles[currentProfile] = nil
      settings.currentProfile = "default"
      settings.profiles.default = {}
    end
  else
    settings.profiles[profile] = nil
  end

  if RS.optionsPanel and RS.optionsPanel.deleteProfileMenu then
    UIDropDownMenu_SetText(RS.optionsPanel.deleteProfileMenu, "")
  end

  RS.profileSelectedForDeletion = ""
  RS:Update()
end

--[[
  RENAME PROFILE
]]
---@param newName string
function RS:RenameCurrentProfile(newName)
  local settings = restockerModule.settings
  local currentProfile = settings.currentProfile

  settings.profiles[newName] = settings.profiles[currentProfile]
  settings.profiles[currentProfile] = nil

  settings.currentProfile = newName
  RS:Update()
end

--[[
  CHANGE PROFILE
]]
function RS:ChangeProfile(newProfile)
  local settings = restockerModule.settings
  settings.currentProfile = newProfile

  RS:Update()
  RS:Print("Current profile: " .. newProfile)

  if bankModule.bankIsOpen then
    eventsModule.OnBankOpen(true)
  end

  if merchantModule.merchantIsOpen then
    eventsModule.OnMerchantShow()
  end
end

--[[
  COPY PROFILE
]]
---@param profileToCopy string
function RS:CopyProfile(profileToCopy)
  local settings = restockerModule.settings

  local copyProfile = CopyTable(settings.profiles[profileToCopy])
  settings.profiles[settings.currentProfile] = copyProfile

  RS:Update()
end

---@param text string|number
function RS:addItem(text)
  local settings = restockerModule.settings
  local currentProfile = settings.profiles[settings.currentProfile]

  if not currentProfile then
    return
  end

  if tonumber(text) then
    text = --[[---@not nil]] tonumber(text)
  end

  local itemInfo = RS.GetItemInfo(text)
  if itemInfo == nil then
    RS.addItemWait[text] = true
    return
  else
    for _, item in ipairs(currentProfile) do
      if item.itemName:lower() == ( --[[---@not nil]] itemInfo).itemName:lower() then
        return
      end
    end
  end

  local buyItem = --[[---@type RsTradeCommand]] {}

  buyItem.itemName = ( --[[---@not nil]] itemInfo).itemName
  buyItem.itemLink = ( --[[---@not nil]] itemInfo).itemLink
  buyItem.itemID = ( --[[---@not nil]] itemInfo).itemId
  buyItem.amount = 1

  table.insert(settings.profiles[settings.currentProfile], buyItem)

  RS:Update()
end

function RS:loadSettings()
  local settings = restockerModule.settings
  settings.profiles = settings.profiles or --[[---@type RsProfileCollection]] {}

  if settings.profiles.default == nil then
    ---@type table<string, RsTradeCommand>
    settings.profiles.default = {}
  end

  settings.currentProfile = settings.currentProfile or "default"
  settings.aceFrameStatus = settings.aceFrameStatus or { width = 700, height = 500 }
  settings.autoOpenAtBank = settings.autoOpenAtBank or false
  settings.autoOpenAtMerchant = settings.autoOpenAtMerchant or false

  if settings.loginMessage == nil then
    settings.loginMessage = true
  end

  -- slashCommand can be "rs", "restocker", or "both" (default "both" for backwards compatibility)
  if settings.slashCommand == nil then
    settings.slashCommand = "both"
  end
end

--[[
  REGISTER SLASH COMMANDS
  Registers slash commands based on the setting: "rs", "restocker", or "both"
]]
function RS:RegisterSlashCommands()
  local settings = restockerModule.settings
  local slashCommand = settings.slashCommand or "both"

  -- Unregister existing commands first
  SLASH_RESTOCKER1 = nil
  SLASH_RESTOCKER2 = nil
  SlashCmdList.RESTOCKER = nil

  -- Register commands based on setting
  if slashCommand == "rs" then
    SLASH_RESTOCKER1 = "/rs"
    RS.defaults.slash = "|cff8d63ff/rs|r "
  elseif slashCommand == "restocker" then
    SLASH_RESTOCKER1 = "/restocker"
    RS.defaults.slash = "|cff8d63ff/restocker|r "
  else -- "both" or any other value defaults to both
    SLASH_RESTOCKER1 = "/restocker"
    SLASH_RESTOCKER2 = "/rs"
    RS.defaults.slash = "|cff8d63ff/rs|r " -- Default display for help messages
  end

  SlashCmdList.RESTOCKER = function(msg)
    RS:SlashCommand(msg)
  end

  -- Update command help text
  RS.commands.show = RS.defaults.slash .. "show - Show the addon"
  RS.commands.profile = {
    add = RS.defaults.slash .. "profile add [name] - Adds a profile with [name]",
    delete = RS.defaults.slash .. "profile delete [name] - Deletes profile with [name]",
    rename = RS.defaults.slash .. "profile rename [name] - Renames current profile to [name]",
    copy = RS.defaults.slash .. "profile copy [name] - Copies profile [name] into current profile.",
    use = RS.defaults.slash .. "profile use [name] - Switches active profile to [name].",
    config = RS.defaults.slash .. "config - Opens the interface options menu."
  }
end

function RS:Debug(t)
  if restockerModule.settings.debugMessages then
    DEFAULT_CHAT_FRAME:AddMessage("|cffbb3333RS|r: " .. t)
  end
end

RS.ICON_FORMAT = "|T%s:0:0:0:0:64:64:4:60:4:60|t"

---Creates a string which will display a picture in a FontString
---@param texture string - path to UI texture file (for example can come from
---  GetContainerItemInfo(bag, slot) or spell info etc
function RS.FormatTexture(texture)
  return string.format(RS.ICON_FORMAT, texture)
end

---AceAddon handler
function RS:OnInitialize()
  -- do init tasks here, like loading the Saved Variables,
  -- or setting up slash commands.
  self.loaded = false
  envModule:DetectVersions()
end

---AceAddon handler
function RS:OnEnable()
  -- Saved variables; Migrate from old 'Restocker' to new 'RestockerSettings'
  --RestockerSettings = (Restocker or RestockerSettings) or {} ---@type RsSettings
  --if Restocker then
  --  Restocker = nil
  --end
  RestockerSettings = RestockerSettings or {}
  restockerModule.settings = RestockerSettings

  self.restockedItems = false
  self:loadSettings()

  -- Do more initialization here, that really enables the use of your addon.
  -- Register Events, Hook functions, Create Frames, Get information from
  -- the game that wasn't available in OnInitialize
  for profileKey, _ in pairs(restockerModule.settings.profiles) do
    local profile = restockerModule.settings.profiles[profileKey]

    for _, item in ipairs( --[[---@not nil]] profile) do
      item.itemID = --[[---@not nil]] tonumber(item.itemID)
    end
  end

  local f = InterfaceOptionsFrame
  if f then
    f:SetMovable(true);
    f:EnableMouse(true);
    f:SetUserPlaced(true);
    f:SetScript("OnMouseDown", f.StartMoving);
    f:SetScript("OnMouseUp", f.StopMovingOrSizing);
  end

  RS:RegisterSlashCommands()

  -- Options tabs
  --RS:CreateOptionsMenu(TOCNAME)

  eventsModule:InitEvents()

  RsModule:CallInEachModule("OnModuleInit", nil)

  self:OptionsInit()
  RS.loaded = true

  if restockerModule.settings.loginMessage then
    RS:Print("Initialized")
  end
end

function RS:OptionsInit()
  local AceConfig = LibStub("AceConfig-3.0")
  AceConfig:RegisterOptionsTable(TOCNAME, addonOptionsModule:CreateOptionsTable(), {})
  self.optionsFrames = {
    general = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
      TOCNAME, TOCNAME, nil)
  }
  self.optionsFrames.general.default = function()
    addonOptionsModule:ResetDefaultOptions()
  end
end

---AceAddon handler
function RS:OnDisable()
end

function restockerModule:Color(hex, text)
  return "|cff" .. hex .. text .. "|r"
end

--- Compatibility layer for function deprecated in 10.0
function restockerModule:GetContainerNumSlots(containerId)
  if C_Container then
    return C_Container.GetContainerNumSlots(containerId)
  else
    return GetContainerNumSlots(containerId)
  end
end

--- @return number, number "freeSlots, bagFamily"
function restockerModule:GetContainerNumFreeSlots(containerId)
  if C_Container then
    return C_Container.GetContainerNumFreeSlots(containerId)
  else
    return GetContainerNumFreeSlots(containerId)
  end
end

---@class RsMerchantItemInfoResult
---@field name string? 	
---@field texture number|string	
---@field price number 	
---@field stackCount number 	
---@field numAvailable number 	
---@field isPurchasable boolean 	
---@field isUsable boolean 	
---@field hasExtendedCost? boolean 	
---@field currencyID number? 	
---@field spellID number? 	
---@field isQuestStartItem boolean 	

--- Compatibility layer for function deprecated in 11.0
function restockerModule:GetMerchantItemInfo(index)
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
    return C_MerchantFrame.GetItemInfo(index)
  else
    local name, texture, price, quantity, numAvailable, isPurchasable, isUsable, extendedCost, currencyID, spellID =
        GetMerchantItemInfo(index)
    return { --- @type RsMerchantItemInfoResult
      name = name,
      texture = texture,
      price = price,
      stackCount = quantity,
      numAvailable = numAvailable,
      isPurchasable = isPurchasable,
      isUsable = isUsable ~= 0 and isUsable ~= false,
      hasExtendedCost = extendedCost,
      currencyID = currencyID,
      spellID = spellID,
      isQuestStartItem = isQuestStartItem,
    }
  end
end

---@class RsGetContainerItemInfoResult
---@field iconFileID 	number 	
---@field stackCount 	number 	
---@field isLocked 	boolean 	
---@field quality 	Enum.ItemQuality? 	
---@field isReadable 	boolean 	
---@field hasLoot 	boolean 	
---@field hyperlink 	string 	Hyperlink
---@field isFiltered 	boolean 	
---@field hasNoValue 	boolean 	
---@field itemID 	number 	
---@field isBound 	boolean 	

function restockerModule:GetContainerItemInfo(bagId, slot)
  if C_Container then
    return C_Container.GetContainerItemInfo(bagId, slot)
  else
    -- icon, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID, isBound = GetContainerItemInfo(bagID, slot)
    local icon, itemCount, locked, quality, readable, lootable, itemLink, isFiltered,
    noValue, itemID, isBound = GetContainerItemInfo(bagId, slot)
    return { --- @type RsGetContainerItemInfoResult
      iconFileID = icon,
      stackCount = itemCount,
      isLocked = locked,
      quality = quality,
      isReadable = readable,
      hasLoot = lootable,
      hyperlink = itemLink,
    }
  end
end

--- Need this function early for SafeCall logging to work
--- @param value table|integer|number|string|boolean|nil
--- @return string
function restockerModule:Dump(value, ...)
  local extras = { ... }
  if #extras > 0 then
      local result = "("
      for _, tabValue in pairs({ value, ... }) do
          result = result .. Dump(tabValue) .. ", "
      end
      return result .. ")"
  end
  if type(value) == "table"
      or type(value) == "userdata" and type(value["insert"]) == "function" -- try to dump C++ containers too
  then
      local result = "{"
      for tabKey, tabValue in pairs(value --[[@as table]]) do
          result = result .. Dump(tabKey) .. "=" .. Dump(tabValue) .. ", "
      end
      return result .. "}"
  elseif type(value) == "string" then
      return '"' .. value .. '"'
  end
  return tostring(value)
end
