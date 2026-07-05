--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
--local RS = RS_ADDON ---@type RestockerAddon

---A row of controls one row per item to restock or stash
---@class RsReusableFrame: WowControl
---@field isInUse boolean
---@field index number
---@field text WowFontString The item name label
---@field icon WowTexture The item icon
---@field iconBtn WowControl Invisible button over the icon, shows the item tooltip
---@field editBox WowControl The item count editbox
---@field repBtn WowControl The required vendor reputation dropdown button

---@class RestockerAddon
---@field RegisterEvent function
---@field buying boolean Currently buying is in progress
---@field addItemWait {[number|string]: boolean|nil} Item ids waiting for resolution to be added to the buy list
---@field addonName string
---@field BAG_ICON string
---@field buyIngredients table<string, RsRecipe> Auto buy table contains ingredients to buy if restocking some crafted item
---@field buyIngredientsWait table<number, RsRecipe> Item ids waiting for resolution for auto-buy setup
---@field commands RsCommands
---@field defaults RsAddonDefaults
---@field EventFrame WowControl Hidden frame for addon events
---@field framepool RsReusableFrame[] A collection of UI frames
---@field hiddenFrame WowControl An UI frame
---@field loaded boolean
---@field MainFrame table Main frame of the addon
---@field merchantIsOpen boolean
---@field onUpdateFrame table Hidden frame for addon events
---@field optionsPanel table
---@field Print function
---@field restockedItems boolean
---@field slashPrefix string
---@field sortListAlphabetically boolean
---@field sortListNumerically boolean
---@field framepool table[]
---@field profileSelectedForDeletion string
---@field ICON_FORMAT string

---@class RsCommands
---@field show string
---@field profile {[string]: string}

---@class RsAddonDefaults
---@field prefix string
---@field color string
---@field slash string

---A single restock profile: items keyed by their itemID (no array, no duplicates)
---@alias RsProfile {[number]: RsTradeCommand}

---@class RsProfileCollection
---@field [string] RsProfile|nil
---@field default RsProfile|nil

---@class RsSettings
---@field autoOpenAtBank boolean
---@field autoOpenAtMerchant boolean
---@field currentProfile string
---@field framePos table
---@field loginMessage boolean Show restocker hello message
---@field profiles RsProfileCollection
---@field profileKeys {[string]: string}|nil Maps a character "Name-Realm" to its active profile name
---@field debugMessages boolean
---@field dataVersion number Saved-data layout version (see RS_DATA_VERSION)
---@field migratedToAccount boolean|nil Set on the old per-character table once imported