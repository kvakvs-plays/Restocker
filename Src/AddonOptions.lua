local TOCNAME, _ADDONPRIVATE = ... ---@type string, RestockerAddon

---@class RsAddonOptionsModule
---@field language {[string]:string} TODO: Move this to languages module
---@field createProfileName string Input value from the create profile input
---@field deleteProfileName string Input value from the delete profile select
local addonOptionsModule = RsModule.addonOptionsModule
addonOptionsModule.createProfileName = ""

local RS = RS_ADDON ---@type RestockerAddon
local restockerModule = RsModule.restockerModule
local kvOptionsModule = KvModuleManager.optionsModule
local settingsModule = RsModule.settingsModule

addonOptionsModule.language = --[[---@type {[string]:string} ]] {
  ["options.category.General"] = "General",
  ["options.category.Profiles"] = "Profiles",

  ["options.short.loginMessage"] = "Display login message",
  ["options.long.loginMessage"] =
  "Print a message in chat when Restocker is loaded and activated. Disable this to reduce chat noise",

  ["options.short.debugMessages"] = "Development debug messages (noisy!)",
  ["options.long.debugMessages"] = "Noisy output used for addon development, do not use",

  ["options.short.autoOpenAtMerchant"] = "Open Restocker at merchant",
  ["options.long.autoOpenAtMerchant"] = "When visiting a merchant, Restocker window will open",

  ["options.short.autoOpenAtBank"] = "Open Restocker at bank",
  ["options.long.autoOpenAtBank"] = "When visiting a banker, Restocker window will open",

  ["options.short.profileName"] = "Create a new profile",
  ["options.long.profileName"] = "Type a profile name then click Okay to create",
  ["options.short.deleteProfileName"] = "Delete a profile",
  ["options.long.deleteProfileName"] = "Select a profile and click the button to the right",
  ["options.short.deleteProfileButton"] = "Delete",
  ["options.long.deleteProfileButton"] = "Deletes the selected profile",

  ["options.short.sortList"] = "Sort items list",
  ["options.long.sortList"] = "Choose whether item list will be sorted by item name or by item id (numeric)",
  ["options.sortList.alphabetic"] = "Alphabetically (by name)",
  ["options.sortList.numeric"] = "Numerically (by item id)",

  ["options.short.slashCommand"] = "Slash command. Requires re-logging in.",
  ["options.long.slashCommand"] =
      "Choose which slash command to use. Use '/restocker' if '/rs' conflicts with another addon. " ..
      "Requires re-logging in for changes to take effect.",
  ["options.slashCommand.rs"] = "/rs (conflicts with some addons)",
  ["options.slashCommand.restocker"] = "/restocker only",
  ["options.slashCommand.both"] = "Both /rs and /restocker",

  --["options.category.Restocking"] = "Restocking",
  --
  --["options.short.restockFromMerchant"] = "Restock from merchants",
  --["options.long.restockFromMerchant"] = "When visiting a merchant, attempt to buy missing items (given the reputation standing with the vendor is good enough)",
  --
  --["options.short.restockSell"] = "Sell extra to merchants",
  --["options.long.restockSell"] = "When visiting a merchant and the player has too many of that item, extras will be sold. Use 0 as quantity to always sell all.",
  --
  --["options.short.restockToBank"] = "Stash extra to bank",
  --["options.long.restockToBank"] = "When visiting a bank, extra items will be sent to the bank bags. Use 0 as quantity to stash all.",
  --
  --["options.short.restockFromBank"] = "Restock from bank",
  --["options.long.restockFromBank"] = "When visiting a bank, take items from bank attempting to maintain the necessary quantity in bags",
}

---@param key string
---@return string
local function _t(key)
  return addonOptionsModule.language[key] or "→" .. key
end

---@param name string
---@param dict table|nil
---@param key string|nil
---@param notify function|nil Call this with (key, value) on option change
function addonOptionsModule:TemplateCheckbox(name, dict, key, notify)
  return kvOptionsModule:TemplateCheckbox(name, dict or restockerModule.settings, key or name, notify, _t)
end

---@param name string
---@param onClick function Call this when button is pressed
function addonOptionsModule:TemplateButton(name, onClick)
  return kvOptionsModule:TemplateButton(name, onClick, _t)
end

---@param values table|function Key is sent to the setter, value is the string displayed
---@param dict table|nil
---@param key string|nil
---@param notifyFn function|nil Call this with (key, value) on option change
function addonOptionsModule:TemplateMultiselect(name, values, dict, notifyFn, setFn, getFn)
  return kvOptionsModule:TemplateMultiselect(name, values, dict or restockerModule.settings, notifyFn, setFn, getFn, _t)
end

---@param values table|function Key is sent to the setter, value is the string displayed
---@param dict table|nil
---@param style string|nil "dropdown" or "radio"
---@param notifyFn function|nil Call this with (key, value) on option change
function addonOptionsModule:TemplateSelect(name, values, style, dict, notifyFn, setFn, getFn)
  return kvOptionsModule:TemplateSelect(name, values, style, dict or restockerModule.settings, notifyFn, setFn, getFn, _t)
end

---@param dict table|nil
---@param key string|nil
---@param notify function|nil Call this with (key, value) on option change
function addonOptionsModule:TemplateInput(type, name, dict, key, notify)
  return kvOptionsModule:TemplateInput(type, name, dict or restockerModule.settings, key or name, notify, _t)
end

---@param dict table|nil
---@param key string|nil
---@param notify function|nil Call this with (key, value) on option change
function addonOptionsModule:TemplateRange(name, rangeFrom, rangeTo, step, dict, key, notify)
  return kvOptionsModule:TemplateRange(name, rangeFrom, rangeTo, step, dict or restockerModule.settings, key or name,
    notify, _t)
end

function addonOptionsModule:CreateGeneralOptions()
  return {
    type = "group",
    name = _t("options.category.General"),
    args = {
      displayLoginMessage = self:TemplateCheckbox("loginMessage", nil, nil, nil),
      autoOpenMerchant = self:TemplateCheckbox("autoOpenAtMerchant", nil, nil, nil),
      autoOpenBank = self:TemplateCheckbox("autoOpenAtBank", nil, nil, nil),
      sortList = self:TemplateSelect("sortList", {
          ["alphabetic"] = _t("options.sortList.alphabetic"),
          ["numeric"] = _t("options.sortList.numeric"),
        }, "radio", nil, nil,
        function(info, value)
          RS.sortListAlphabetically = value == "alphabetic"
          RS.sortListNumerically = value ~= "alphabetic"
          RS:Update()
        end,
        function(info)
          if RS.sortListAlphabetically then
            return "alphabetic"
          end
          return "numeric"
        end),
      slashCommand = self:TemplateSelect("slashCommand", {
          ["rs"] = _t("options.slashCommand.rs"),
          ["restocker"] = _t("options.slashCommand.restocker"),
          ["both"] = _t("options.slashCommand.both"),
        }, "radio", nil, nil,
        function(info, value)
          restockerModule.settings.slashCommand = value
          RS:RegisterSlashCommands()
          RS:Print("Slash command changed. Use " ..
            (value == "both" and "/rs or /restocker" or value == "rs" and "/rs" or "/restocker") ..
            " to access Restocker. Log out and log back in.")
        end,
        function(info)
          return restockerModule.settings.slashCommand or "both"
        end),
      debugMessages = self:TemplateCheckbox("debugMessages", nil, nil, nil),
    }
  }
end

function addonOptionsModule:CreateProfilesOptions()
  local getProfileNames = function()
    return settingsModule:GetProfileNames()
  end
  return {
    type = "group",
    name = _t("options.category.Profiles"),
    args = {
      createProfileName = self:TemplateInput("string", "profileName", addonOptionsModule, "createProfileName",
        function(_key, value)
          if settingsModule:AddProfile(value) then
            --LibStub("AceConfigDialog-3.0"):NotifyChange(TOCNAME)
          else
            RS:Print("Did not create profile \"" .. tostring(value) .. "\"")
          end
        end),
      --createProfileButton = self:TemplateButton("profileCreate", function(_key, value)
      --  if settingsModule:AddProfile(value) then
      --    LibStub("AceConfigDialog-3.0"):NotifyChange(TOCNAME)
      --  else
      --    RS:Print("Did not create profile \"" .. tostring(value) .. "\"")
      --  end
      --end),
      deleteProfileList = self:TemplateSelect("deleteProfileName", getProfileNames,
        "dropdown", addonOptionsModule, nil, nil, nil),
      deleteProfileButton = self:TemplateButton("deleteProfileButton", function()
        settingsModule:DeleteProfile(addonOptionsModule.deleteProfileName)
        --LibStub("AceConfigDialog-3.0"):NotifyChange(TOCNAME)
      end),
    }
  }
end

function addonOptionsModule:CreateOptionsTable()
  kvOptionsModule.optionsOrder = 0

  return {
    type = "group",
    args = {
      generalOptions = self:CreateGeneralOptions(),
      profilesOptions = self:CreateProfilesOptions(),
    } -- end args
  }   -- end
end

---Called from options' Default button
function addonOptionsModule:ResetDefaultOptions()
  restockerModule.settings.loginMessage = true
  restockerModule.settings.autoOpenAtMerchant = false
  restockerModule.settings.autoOpenAtBank = false
  restockerModule.settings.slashCommand = "both"
  RS:RegisterSlashCommands()
  --restockerModule.settings.restockFromBank = true
  --restockerModule.settings.restockToBank = false
  --restockerModule.settings.restockFromMerchant = true
  --restockerModule.settings.restockSell = false
end