local TOCNAME, _ADDONPRIVATE = ... ---@type string, RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsAceMainFrameModule
---@field frame table|nil AceGUI Frame widget
---@field addItemEditBox table|nil AceGUI EditBox widget
local aceMainFrameModule = RsModule.aceMainFrameModule ---@type RsAceMainFrameModule
local bankContainerModule = RsModule.bankContainerModule ---@type RsBankContainerModule
local bankModule = RsModule.bankModule ---@type RsBankModule
local restockerModule = RsModule.restockerModule ---@type RsRestockerModule
local settingsModule = RsModule.settingsModule ---@type RsSettingsModule

local AceGUI = LibStub("AceGUI-3.0")

local reputationList = {
  [0] = "Any rep",
  [4] = "Neutral",
  [5] = "Friendly",
  [6] = "Honored",
  [7] = "Revered",
  [8] = "Exalted"
}
local reputationOrder = { 0, 4, 5, 6, 7, 8 }

local bankStorageList = {
  character = "Character bank",
  account = "Account bank",
  both = "Character + account",
}

local function getCurrentProfile()
  local settings = restockerModule.settings
  return settings.profiles and settings.profiles[settings.currentProfile] or {}
end

local function addItemFromText(text)
  if text and text ~= "" then
    RS:addItem(text)
  end
end

local function addCursorItem()
  local infoType, _, info2 = GetCursorInfo()
  if infoType == "item" then
    RS:addItem(info2)
    ClearCursor()
    return true
  end
  return false
end

local function installDropTarget(frame)
  if not frame or frame.restockerAceDropTarget then
    return
  end

  frame.restockerAceDropTarget = true
  frame:EnableMouse(true)
  frame:SetScript("OnReceiveDrag", addCursorItem)
  frame:HookScript("OnMouseUp", function(_self, button)
    if button == "LeftButton" then
      addCursorItem()
    end
  end)
end

local function refreshAfterBankSensitiveChange()
  RS:Update()
  if bankModule.bankIsOpen then
    bankModule:Restart()
  end
end

local function createProfileList()
  local settings = restockerModule.settings
  local profileList = {}
  local profileOrder = {}

  for profileName, _ in pairs(settings.profiles or {}) do
    profileList[profileName] = profileName
    table.insert(profileOrder, profileName)
  end
  table.sort(profileOrder)

  return profileList, profileOrder
end

local function removeItem(itemToRemove)
  local profile = getCurrentProfile()

  for i, item in ipairs(profile) do
    if item == itemToRemove then
      tremove(profile, i)
      refreshAfterBankSensitiveChange()
      return
    end
  end
end

function aceMainFrameModule:GetOrCreateFrame()
  if self.frame then
    return self.frame
  end

  local settings = restockerModule.settings
  settings.aceFrameStatus = settings.aceFrameStatus or { width = RS.defaults.mainFrameWidth, height = 500 }

  local frame = AceGUI:Create("Frame")
  frame:SetTitle("Restocker")
  frame:SetStatusText(bankModule.status or "")
  frame:SetStatusTable(settings.aceFrameStatus)
  frame:SetLayout("Flow")

  installDropTarget(frame.frame)
  installDropTarget(frame.content)

  self.frame = frame
  return frame
end

function aceMainFrameModule:SetStatus(message)
  if self.frame then
    self.frame:SetStatusText(message or "")
  end
end

function aceMainFrameModule:IsShown()
  return self.frame and self.frame.frame and self.frame.frame:IsShown()
end

function aceMainFrameModule:Show()
  self:GetOrCreateFrame():Show()
end

function aceMainFrameModule:Hide()
  if self.frame then
    self.frame:Hide()
  end
end

---@return boolean shown
function aceMainFrameModule:Toggle()
  if self:IsShown() then
    self:Hide()
    return false
  end

  self:Show()
  return true
end

function aceMainFrameModule:SavePosition()
  if not self.frame or not self.frame.frame then
    return
  end

  local settings = restockerModule.settings
  local status = settings.aceFrameStatus or {}
  settings.aceFrameStatus = status
  status.width = self.frame.frame:GetWidth()
  status.height = self.frame.frame:GetHeight()
  status.top = self.frame.frame:GetTop()
  status.left = self.frame.frame:GetLeft()
end

function aceMainFrameModule:CreateToolbar(parent)
  local settings = restockerModule.settings
  local profileList, profileOrder = createProfileList()

  local profileDropDown = AceGUI:Create("Dropdown")
  profileDropDown:SetLabel("Profile")
  profileDropDown:SetList(profileList, profileOrder)
  profileDropDown:SetValue(settings.currentProfile)
  profileDropDown:SetWidth(160)
  profileDropDown:SetCallback("OnValueChanged", function(_widget, _event, profileName)
    RS:ChangeProfile(profileName)
  end)
  parent:AddChild(profileDropDown)

  local bankStorageOrder = { "character" }
  local bankStorageValues = { character = bankStorageList.character }
  if bankContainerModule:SupportsAccountBank() then
    bankStorageValues.account = bankStorageList.account
    bankStorageValues.both = bankStorageList.both
    table.insert(bankStorageOrder, "account")
    table.insert(bankStorageOrder, "both")
  end

  local bankStorageDropDown = AceGUI:Create("Dropdown")
  bankStorageDropDown:SetLabel("Bank storage")
  bankStorageDropDown:SetList(bankStorageValues, bankStorageOrder)
  bankStorageDropDown:SetValue(settingsModule:GetBankStorage(settings.currentProfile))
  bankStorageDropDown:SetWidth(180)
  bankStorageDropDown:SetCallback("OnValueChanged", function(_widget, _event, policy)
    settingsModule:SetBankStorage(settings.currentProfile, policy)
    refreshAfterBankSensitiveChange()
  end)
  parent:AddChild(bankStorageDropDown)

  local settingsButton = AceGUI:Create("Button")
  settingsButton:SetText("Settings")
  settingsButton:SetWidth(90)
  settingsButton:SetCallback("OnClick", function()
    LibStub("AceConfigDialog-3.0"):Open(TOCNAME)
  end)
  parent:AddChild(settingsButton)
end

function aceMainFrameModule:CreateAddControls(parent)
  local editBox = AceGUI:Create("EditBox")
  editBox:SetLabel("Item name or item ID (or drop an item here)")
  editBox:SetWidth(250)
  editBox:SetCallback("OnEnterPressed", function(widget, _event, value)
    addItemFromText(value)
    widget:SetText("")
    AceGUI:ClearFocus()
  end)
  parent:AddChild(editBox)
  self.addItemEditBox = editBox

  local addButton = AceGUI:Create("Button")
  addButton:SetText("Add")
  addButton:SetWidth(60)
  addButton:SetCallback("OnClick", function()
    addItemFromText(editBox.editbox:GetText())
    editBox:SetText("")
    AceGUI:ClearFocus()
  end)
  parent:AddChild(addButton)
end

function aceMainFrameModule:CreateListHeader(parent)
  local row = AceGUI:Create("SimpleGroup")
  row:SetFullWidth(true)
  row:SetLayout("Flow")
  parent:AddChild(row)

  local itemLabel = AceGUI:Create("Label")
  itemLabel:SetText("Item")
  itemLabel:SetWidth(210)
  row:AddChild(itemLabel)

  local amountLabel = AceGUI:Create("Label")
  amountLabel:SetText("Qty")
  amountLabel:SetWidth(95)
  row:AddChild(amountLabel)

  local buyLabel = AceGUI:Create("Label")
  buyLabel:SetText("Buy")
  buyLabel:SetWidth(70)
  row:AddChild(buyLabel)

  local toBankLabel = AceGUI:Create("Label")
  toBankLabel:SetText("To bank")
  toBankLabel:SetWidth(90)
  row:AddChild(toBankLabel)

  local fromBankLabel = AceGUI:Create("Label")
  fromBankLabel:SetText("From bank")
  fromBankLabel:SetWidth(105)
  row:AddChild(fromBankLabel)

  local reputationLabel = AceGUI:Create("Label")
  reputationLabel:SetText("Vendor rep")
  reputationLabel:SetWidth(130)
  row:AddChild(reputationLabel)
end

---@param parent table AceGUI container
---@param item RsTradeCommand
function aceMainFrameModule:CreateItemRow(parent, item)
  local row = AceGUI:Create("SimpleGroup")
  row:SetFullWidth(true)
  row:SetLayout("Flow")
  parent:AddChild(row)

  local itemLabel = AceGUI:Create("InteractiveLabel")
  itemLabel:SetText(item.itemLink and item.itemLink ~= "" and item.itemLink or item.itemName)
  itemLabel:SetWidth(210)
  row:AddChild(itemLabel)

  local amountBox = AceGUI:Create("EditBox")
  amountBox:SetText(tostring(item.amount or 0))
  amountBox:SetWidth(95)
  amountBox:SetCallback("OnTextChanged", function(_widget, _event, value)
    if value == "" then
      value = "0"
    end
    item.amount = tonumber(value) or 0
  end)
  amountBox:SetCallback("OnEnterPressed", function(widget, _event, value)
    if value == "" then
      value = "0"
    end
    item.amount = tonumber(value) or 0
    widget:SetText(tostring(item.amount))
    AceGUI:ClearFocus()
    refreshAfterBankSensitiveChange()
  end)
  row:AddChild(amountBox)

  local buyCheckBox = AceGUI:Create("CheckBox")
  buyCheckBox:SetLabel("")
  buyCheckBox:SetWidth(70)
  buyCheckBox:SetValue(item.buyFromMerchant == nil or item.buyFromMerchant)
  buyCheckBox:SetCallback("OnValueChanged", function(_widget, _event, value)
    item.buyFromMerchant = value
    RS:Update()
  end)
  row:AddChild(buyCheckBox)

  local toBankCheckBox = AceGUI:Create("CheckBox")
  toBankCheckBox:SetLabel("")
  toBankCheckBox:SetWidth(90)
  toBankCheckBox:SetValue(item.stashTobank and true or false)
  toBankCheckBox:SetCallback("OnValueChanged", function(_widget, _event, value)
    item.stashTobank = value
    refreshAfterBankSensitiveChange()
  end)
  row:AddChild(toBankCheckBox)

  local fromBankCheckBox = AceGUI:Create("CheckBox")
  fromBankCheckBox:SetLabel("")
  fromBankCheckBox:SetWidth(105)
  fromBankCheckBox:SetValue(item.restockFromBank and true or false)
  fromBankCheckBox:SetCallback("OnValueChanged", function(_widget, _event, value)
    item.restockFromBank = value
    refreshAfterBankSensitiveChange()
  end)
  row:AddChild(fromBankCheckBox)

  local reputationDropDown = AceGUI:Create("Dropdown")
  reputationDropDown:SetList(reputationList, reputationOrder)
  reputationDropDown:SetValue(item.reaction or 0)
  reputationDropDown:SetWidth(100)
  reputationDropDown:SetCallback("OnValueChanged", function(_widget, _event, value)
    item.reaction = value or 0
    RS:Update()
  end)
  row:AddChild(reputationDropDown)

  local deleteButton = AceGUI:Create("Button")
  deleteButton:SetText("X")
  deleteButton:SetWidth(40)
  deleteButton:SetCallback("OnClick", function()
    removeItem(item)
  end)
  row:AddChild(deleteButton)
end

---@param restockItems RsTradeCommand[]|nil
function aceMainFrameModule:Refresh(restockItems)
  if not self.frame then
    return
  end

  self.frame:ReleaseChildren()
  self.frame:SetLayout("Flow")

  self:CreateToolbar(self.frame)
  self:CreateAddControls(self.frame)

  local list = AceGUI:Create("ScrollFrame")
  list:SetFullWidth(true)
  list:SetFullHeight(true)
  list:SetLayout("List")
  self.frame:AddChild(list)

  self:CreateListHeader(list)

  for _, item in ipairs(restockItems or getCurrentProfile()) do
    self:CreateItemRow(list, item)
  end

  installDropTarget(self.frame.frame)
  installDropTarget(self.frame.content)
  installDropTarget(list.frame)
end
