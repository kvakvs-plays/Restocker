local TOCNAME, _ADDONPRIVATE = ... ---@type string, RestockerAddon

---@class RsRestockerModule
---@field settings RsSettings
local restockerModule = RsModule.restockerModule
restockerModule.settings = --[[---@type RsSettings]] {}

local restockItemList = {} ---@type RsTradeCommand[]

local mainFrameModule = RsModule.mainFrameModule
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
    local menu = RS.MainFrame or mainFrameModule:CreateMenu();
    menu:Show()
    return RS:Update()
  end
end

function RS:Hide()
  if RS.loaded then
    local menu = RS.MainFrame or mainFrameModule:CreateMenu();
    return menu:Hide()
  end
end

function RS:Toggle()
  if RS.loaded then
    local menu = RS.MainFrame or mainFrameModule:CreateMenu();
    return menu:SetShown(not menu:IsShown()) or false
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

  -- Gather items (profile is keyed by itemID, so walk it with pairs)
  wipe(restockItemList)
  for _, v in pairs(currentProfile) do
    table.insert(restockItemList, v)
  end

  -- Sort and group into a render list -- a mix of section-header entries and item
  -- entries (headers only when sorting by type). See ListFrame.lua:BuildRenderList.
  local renderList = self:BuildRenderList(restockItemList)

  -- Release every pooled item row and header row back to the hidden frame
  for _, f in ipairs(RS.framepool) do
    f.isInUse = false
    f:SetParent(RS.hiddenFrame)
    f:Hide()
  end
  for _, h in ipairs(RS.headerpool) do
    h.isInUse = false
    h:SetParent(RS.hiddenFrame)
    h:Hide()
  end

  -- Position each entry by absolute row index so headers and items can interleave
  local scrollChild = RS.MainFrame.scrollChild
  for i, entry in ipairs(renderList) do
    local y = -(i - 1) * RS.ROW_HEIGHT
    local f = entry.header and self:GetHeaderRow() or self:GetFirstEmpty(entry.item)
    f.isInUse = true
    f:SetParent(scrollChild)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
    f:SetSize(scrollChild:GetWidth(), RS.ROW_HEIGHT)
    if entry.header then
      f.text:SetText(entry.header)
    else
      self:UpdateRestockListRow(f, entry.item)
    end
    f:Show()
  end

  scrollChild:SetHeight(math.max(1, #renderList) * RS.ROW_HEIGHT)
end

--[[
  GET FIRST UNUSED SCROLLCHILD FRAME
]]
---@param item RsTradeCommand
---@return RsRestockingListRow
function RS:GetFirstEmpty(item)
  for i, frame in ipairs(RS.framepool) do
    if not frame.isInUse then
      return frame
    end
  end
  return self:CreateRestockListRow(item)
end

--[[
  ADD PROFILE
]]
---@param newProfile string
function RS:AddProfile(newProfile)
  local settings = restockerModule.settings
  settings.profiles[newProfile] = {} ---@type RsTradeCommand
  RS:UseProfile(newProfile)

  local menu = RS.MainFrame or mainFrameModule:CreateMenu()
  menu:Show()
  RS:Update()

  UIDropDownMenu_SetText(RS.MainFrame.profileDropDownMenu, settings.currentProfile)
end

--[[
  DELETE PROFILE
]]
---@param profile string
function RS:DeleteProfile(profile)
  local settings = restockerModule.settings
  local currentProfile = settings.currentProfile

  if currentProfile == profile then
    settings.profiles[currentProfile] = nil
    local firstKey = next(settings.profiles)
    if firstKey then
      RS:UseProfile( --[[---@not nil]] firstKey)
    else
      -- Nothing left: fall back to this character's own (empty) list
      local charKey = RS:GetCharKey()
      settings.profiles[charKey] = {}
      RS:UseProfile(charKey)
    end
  else
    settings.profiles[profile] = nil
  end

  UIDropDownMenu_SetText(RS.optionsPanel.deleteProfileMenu, "")

  local menu = RS.MainFrame or mainFrameModule:CreateMenu()
  RS.profileSelectedForDeletion = ""
  UIDropDownMenu_SetText(RS.MainFrame.profileDropDownMenu, settings.currentProfile)
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

  RS:UseProfile(newName)

  UIDropDownMenu_SetText(RS.MainFrame.profileDropDownMenu, settings.currentProfile)
end

--[[
  CHANGE PROFILE
]]
function RS:ChangeProfile(newProfile)
  local settings = restockerModule.settings
  RS:UseProfile(newProfile)

  UIDropDownMenu_SetText(RS.MainFrame.profileDropDownMenu, settings.currentProfile)
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

-- Bump this when the saved data layout changes. v5 = profiles keyed by itemID, each
-- item saved on ONE line as a compact string "type, name, amount, stash, fromBank,
-- buy [, reaction]" (1/0 for booleans). The itemID lives only in the table key;
-- itemLink is never stored (rebuilt from itemID). Older lines without the type, or
-- with a repeated id, are still read correctly and rewritten in the new form on save.
local RS_DATA_VERSION = 5

---Strip a saved item down to the clean format and keep its itemID synced to its key.
---Drops the bulky itemLink (we can always rebuild it from the itemID).
---@param item RsTradeCommand
---@param itemID number
local function rsCleanItem(item, itemID)
  item.itemID = itemID
  item.itemLink = nil
  return item
end

-- ----------------------------------------------------------------------------
-- One-line saved format. Each item is stored as a single comma-separated string
-- so the SavedVariables file has exactly one physical line per item (a real Lua
-- table would be expanded across many lines by WoW's serializer).
-- Field order: itemType, itemName, amount, stashTobank, restockFromBank,
--              buyFromMerchant [, reaction].  Booleans are 1 (true) / 0 (false).
-- itemType is the human-readable class from GetItemInfo (e.g. "Consumable",
-- "Quest", "Trade Goods") and leads so the file sorts into groups. It is purely a
-- convenience label (re-derived from the itemID); only the name is used at runtime.
-- The itemID is NOT stored -- the table key IS the itemID (single source of truth).
-- Neither itemType nor itemName may contain a comma (no WoW values do).
-- ----------------------------------------------------------------------------

---Resolve an item's human-readable type, preferring the live game data and falling
---back to whatever was saved (so it survives even when the item isn't cached yet).
---@param item RsTradeCommand
---@return string|nil
local function rsItemType(item)
  local info = RS.GetItemInfo(item.itemID)
  if info and info.itemType and info.itemType ~= "" then
    return info.itemType
  end
  return item.itemType
end

---@param item RsTradeCommand
---@return string
local function rsItemToString(item)
  local parts = {}
  local itemType = rsItemType(item)
  if itemType and itemType ~= "" then
    parts[#parts + 1] = itemType
  end
  parts[#parts + 1] = item.itemName or ""
  parts[#parts + 1] = item.amount or 0
  parts[#parts + 1] = item.stashTobank and 1 or 0
  parts[#parts + 1] = item.restockFromBank and 1 or 0
  -- buyFromMerchant defaults to true (nil), so only false is "off"
  parts[#parts + 1] = (item.buyFromMerchant == false) and 0 or 1
  if item.reaction and item.reaction > 0 then
    parts[#parts + 1] = item.reaction
  end
  return table.concat(parts, ", ")
end

---@param s string The saved one-line string
---@param key number|string The table key (authoritative itemID)
---@return RsTradeCommand
local function rsItemFromString(s, key)
  local itemID = tonumber(key)
  local f = {}
  for _, part in ipairs({ strsplit(",", s) }) do
    f[#f + 1] = strtrim(part)
  end

  -- The label (type and/or name) is the leading run of non-numeric fields; the
  -- numeric data (amount, flags, [reaction]) follows. This makes the parser tolerant
  -- of every format we've used: "type, name, ...", "name, ...", and the old
  -- "name, id, ..." (the repeated id is handled just below).
  local dataStart
  for j = 1, #f do
    if tonumber(f[j]) ~= nil then dataStart = j; break end
  end
  dataStart = dataStart or (#f + 1)
  local labelEnd = dataStart - 1

  -- Legacy form repeated the id right after the name ("name, id, amount, +3 flags").
  -- Detect it (first numeric equals this item's id, with enough trailing fields) and
  -- skip it. The >=4 guard distinguishes it from an amount that happens to equal the id.
  if tonumber(f[dataStart]) == itemID and (#f - dataStart) >= 4 then
    dataStart = dataStart + 1
  end

  local amount = tonumber(f[dataStart]) or 0
  local stash = tonumber(f[dataStart + 1])
  local fromBank = tonumber(f[dataStart + 2])
  local buy = tonumber(f[dataStart + 3])
  local rxn = tonumber(f[dataStart + 4]) or 0

  -- Name is the last label field; an optional type leads it.
  local itemName = (labelEnd >= 1) and f[labelEnd] or ""
  local itemType = (labelEnd >= 2) and f[1] or nil

  -- buyFromMerchant defaults to true (stored as nil); only an explicit 0 means off.
  -- Note: don't fold this into "x and false or nil" -- false is falsy in Lua, so that
  -- idiom would always yield nil and we could never store the "off" state.
  local buyFromMerchant = nil
  if buy == 0 then
    buyFromMerchant = false
  end

  return --[[---@type RsTradeCommand]] {
    itemName = itemName,
    itemType = itemType,
    itemID = itemID,
    amount = amount,
    stashTobank = (stash == 1) or nil,
    restockFromBank = (fromBank == 1) or nil,
    buyFromMerchant = buyFromMerchant,
    reaction = rxn > 0 and rxn or nil,
  }
end

---Convert every saved item to its in-memory table form (called on login). Tolerates
---tables left behind by a crash/reload and hand-edited entries; keeps itemID synced
---to the table key and drops any stale itemLink. Idempotent.
---@param db RsSettings
local function rsInflate(db)
  for _, profile in pairs(db.profiles or {}) do
    for key, item in pairs(--[[---@not nil]] profile) do
      if type(item) == "string" then
        local inflated = rsItemFromString(item, key)
        -- Best-effort: refresh name/type from the item cache when it's known
        local info = RS.GetItemInfo(inflated.itemID)
        if info then
          if inflated.itemName == "" then inflated.itemName = info.itemName end
          if info.itemType and info.itemType ~= "" then inflated.itemType = info.itemType end
        end
        profile[key] = inflated
      elseif type(item) == "table" then
        rsCleanItem( --[[---@type RsTradeCommand]] item, tonumber(key) or item.itemID)
      end
    end
  end
end

---Convert every in-memory item table to its one-line saved string (called on logout
---so WoW writes the compact format to disk). Idempotent.
---@param db RsSettings
local function rsDeflate(db)
  for _, profile in pairs(db.profiles or {}) do
    for key, item in pairs(--[[---@not nil]] profile) do
      if type(item) == "table" then
        profile[key] = rsItemToString( --[[---@type RsTradeCommand]] item)
      end
    end
  end
end

---Remove empty profiles that no character points at (e.g. a leftover "default" from
---an older version). A character's own list is referenced via profileKeys, so even an
---empty alt list is kept.
---@param db RsSettings
local function rsPruneEmptyOrphans(db)
  local keep = {}
  for _, name in pairs(db.profileKeys or {}) do
    keep[name] = true
  end
  if db.currentProfile then
    keep[db.currentProfile] = true
  end
  for name, profile in pairs(db.profiles or {}) do
    if not keep[name] and next( --[[---@not nil]] profile) == nil then
      db.profiles[name] = nil
    end
  end
end

---Pack all in-memory item tables back into the one-line saved strings. Called from
---eventsModule.OnLogout right before WoW writes the SavedVariables file. Exposed as a
---method so the events module (which can't see the file-local rsDeflate) can call it.
function RS:DeflateForSave()
  rsDeflate(restockerModule.settings)
end

---One-time import of a character's old per-character data (RestockerSettings, a v1
---array-of-items layout) into the account-wide DB. Each profile is converted from an
---array into a table keyed by itemID and stored under a name that is namespaced to
---this character, so different characters keep separate lists in the shared file:
---  old "default"  -> "<charKey>"            (the character's main list)
---  old "raid" etc -> "<charKey> - raid"     (extra named profiles, kept distinct)
---The character is then pointed (via profileKeys) at the imported version of whatever
---profile it was using. Existing account entries win, so re-running is harmless.
---@param legacy RsSettings|nil The old per-character saved table
---@param db RsSettings The account-wide saved table
---@param charKey string This character's "Name-Realm" key
local function rsImportLegacyPerChar(legacy, db, charKey)
  if type(legacy) ~= "table" then
    return
  end

  db.profiles = db.profiles or {}
  db.profileKeys = db.profileKeys or {}

  -- Adopt shared scalar settings from the first character that migrates
  if db.framePos == nil then db.framePos = legacy.framePos end
  if db.autoOpenAtBank == nil then db.autoOpenAtBank = legacy.autoOpenAtBank end
  if db.autoOpenAtMerchant == nil then db.autoOpenAtMerchant = legacy.autoOpenAtMerchant end
  if db.loginMessage == nil then db.loginMessage = legacy.loginMessage end
  if db.slashCommand == nil then db.slashCommand = legacy.slashCommand end

  -- Map an old profile name to this character's namespaced name
  local function targetName(oldName)
    if oldName == nil or oldName == "default" then
      return charKey
    end
    return charKey .. " - " .. oldName
  end

  for name, oldProfile in pairs(legacy.profiles or {}) do
    local target = targetName(name)
    local dst = db.profiles[target] or {}
    -- Old profiles are arrays, so ipairs walks every saved item
    for _, item in ipairs(--[[---@not nil]] oldProfile) do
      local id = tonumber(item.itemID)
      if id and dst[id] == nil then
        dst[id] = rsCleanItem(CopyTable(item), id)
      end
    end
    db.profiles[target] = dst
  end

  -- Default this character to the imported version of its previously active profile
  if db.profileKeys[charKey] == nil then
    db.profileKeys[charKey] = targetName(legacy.currentProfile)
  end
end

---Stable per-character identity used to pick that character's own list.
---@return string "Name-Realm" (realm spaces stripped), or just "Name" if no realm
function RS:GetCharKey()
  local name = UnitName("player") or "Unknown"
  local realm = GetRealmName() or ""
  realm = ( --[[---@not nil]] realm:gsub("%s+", ""))
  if realm ~= "" then
    return name .. "-" .. realm
  end
  return name
end

---Switch the active profile AND remember the choice for THIS character, so each
---character returns to its own list next login. Use this instead of writing
---settings.currentProfile directly.
---@param name string
function RS:UseProfile(name)
  local settings = restockerModule.settings
  settings.currentProfile = name
  settings.profileKeys = settings.profileKeys or {}
  settings.profileKeys[RS:GetCharKey()] = name
end

---Pick the profile this character should use on login (its remembered choice, or a
---fresh profile named after the character), creating it if missing.
function RS:InitCharacterProfile()
  local settings = restockerModule.settings
  settings.profiles = settings.profiles or --[[---@type RsProfileCollection]] {}
  settings.profileKeys = settings.profileKeys or {}

  local charKey = RS:GetCharKey()
  local profileName = settings.profileKeys[charKey] or charKey

  settings.profiles[profileName] = settings.profiles[profileName] or {}
  RS:UseProfile(profileName)
end

function RS:loadSettings()
  local settings = restockerModule.settings
  settings.profiles = settings.profiles or --[[---@type RsProfileCollection]] {}

  -- currentProfile is chosen per-character in InitCharacterProfile (called right
  -- after loadSettings), so we no longer force a shared "default" profile here.
  settings.framePos = settings.framePos or {}
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

---Print a debug message, but only when debug messages are enabled. Accepts an optional
---printf-style format plus args, so the (potentially expensive) string is only built
---when debugging is actually on -- prefer RS:Debug("x=%s", v) over RS:Debug("x="..v).
---@param fmt string
function RS:Debug(fmt, ...)
  if not restockerModule.settings.debugMessages then
    return
  end
  local msg = fmt
  if select("#", ...) > 0 then
    msg = string.format(fmt, ...)
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cffbb3333RS|r: " .. tostring(msg))
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
  -- Saved variables are now stored account-wide in RestockerDB (was per-character
  -- RestockerSettings). RestockerDB keeps profiles keyed by itemID, without itemLink.
  -- Each character keeps its own list (profile named after the character), so all
  -- characters share one file but Warrior and Priest see separate lists.
  RestockerDB = RestockerDB or --[[---@type RsSettings]] {}
  if RestockerDB.dataVersion == nil then
    RestockerDB.profiles = RestockerDB.profiles or {}
    RestockerDB.dataVersion = RS_DATA_VERSION
  end
  RestockerDB.profileKeys = RestockerDB.profileKeys or {}

  -- One-time per-character import: fold this character's old per-character list into
  -- its own profile in the account-wide DB the first time it logs in after the update.
  if RestockerSettings and not RestockerSettings.migratedToAccount then
    rsImportLegacyPerChar( --[[---@type RsSettings]] RestockerSettings, RestockerDB, self:GetCharKey())
    RestockerSettings.migratedToAccount = true
  end

  restockerModule.settings = RestockerDB

  self.restockedItems = false
  self.framepool = --[[---@type RsRestockingListRow[] ]] {}
  self.headerpool = --[[---@type RsControl[] ]] {} -- section-header rows (sort by type)
  self.hiddenFrame = CreateFrame("Frame", nil, --[[---@type WowControl]] UIParent)
  self.hiddenFrame:Hide()
  self:loadSettings()

  -- Unpack the one-line string entries into in-memory tables (and tolerate any tables
  -- left by a crash or pasted in by hand). Item links are rebuilt from the itemID.
  rsInflate(restockerModule.settings)

  -- Select this character's own list (creating it if this is a fresh character)
  self:InitCharacterProfile()

  -- Drop leftover empty orphan profiles (e.g. an old shared "default")
  rsPruneEmptyOrphans(restockerModule.settings)
  -- (Re-packing into the one-line form happens in eventsModule.OnLogout, which calls
  --  RS:DeflateForSave just before WoW writes the SavedVariables file.)

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

  RS:Show()
  RS:Hide()

  eventsModule:InitEvents()

  RsModule:CallInEachModule("OnModuleInit", nil)

  if not RS.MainFrame then
    mainFrameModule:CreateMenu()
  end -- setup the UI

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