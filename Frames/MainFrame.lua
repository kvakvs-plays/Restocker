local TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsMainFrameModule
local mainFrameModule = RsModule.mainFrameModule ---@type RsMainFrameModule
local restockerModule = RsModule.restockerModule ---@type RsRestockerModule

RS.hiddenFrame = CreateFrame("Frame", nil, UIParent)
RS.hiddenFrame:Hide()

---@class RsControl: WowControl
---@field width number
---@field height number

---@class RsRestockerFrame: RsControl
---@field profileDropDownMenu WowControl
---@field editBox RsControl
---@field addBtn RsControl
---@field addGrp RsControl
---@field listInset RsControl
---@field scrollFrame RsControl
---@field scrollChild RsControl
---@field title RsControl
---@field reactionBox RsControl

function mainFrameModule:CreateAddonFrame()
  local settings = restockerModule.settings
  local addonFrame = --[[---@type RsRestockerFrame]] CreateFrame("Frame", "RestockerMainFrame", UIParent,
    "BasicFrameTemplate");
  addonFrame.width = 350
  addonFrame.height = 400
  addonFrame:SetSize(addonFrame.width, addonFrame.height);
  addonFrame:SetPoint(settings.framePos.point or "RIGHT",
    UIParent, settings.framePos.relativePoint or "RIGHT",
    settings.framePos.xOfs or -5,
    settings.framePos.yOfs or 0);
  addonFrame:SetFrameStrata("FULLSCREEN");
  addonFrame:SetMovable(true)
  addonFrame:EnableMouse(true)
  addonFrame:RegisterForDrag("LeftButton")
  addonFrame:SetScript("OnDragStart", addonFrame.StartMoving)
  addonFrame:SetScript("OnDragStop", addonFrame.StopMovingOrSizing)
  return addonFrame
end

function mainFrameModule:CreateListInset(addonFrame)
  local listInset = --[[---@type RsControl]] CreateFrame("Frame", nil, addonFrame, "InsetFrameTemplate3");
  listInset.width = addonFrame.width - 6
  listInset.height = addonFrame.height - 60
  listInset:SetSize(listInset.width, listInset.height);
  listInset:SetPoint("TOPLEFT", addonFrame, "TOPLEFT", 2, -22);
  addonFrame.listInset = listInset
  return listInset
end

function mainFrameModule:CreateScrollFrame(addonFrame, listInset)
  local scrollFrame = --[[---@type RsControl]] CreateFrame("ScrollFrame", nil, addonFrame, "UIPanelScrollFrameTemplate")
  scrollFrame.width = addonFrame.listInset.width - 4
  scrollFrame.height = addonFrame.listInset.height - 32
  scrollFrame:SetSize(scrollFrame.width - 30, scrollFrame.height);
  scrollFrame:SetPoint("TOPLEFT", listInset, "TOPLEFT", 8, -6);
  addonFrame.scrollFrame = scrollFrame
  return scrollFrame
end

function mainFrameModule:CreateScrollChild(scrollFrame, addonFrame)
  local scrollChild = --[[---@type RsControl]] CreateFrame("Frame", nil, ScrollFrame)
  scrollChild.width = scrollFrame:GetWidth()
  scrollChild.height = scrollFrame:GetHeight()
  scrollChild:SetWidth(scrollChild.width)
  scrollChild:SetHeight(scrollChild.height - 10)
  addonFrame.scrollChild = scrollChild

  scrollFrame:SetScrollChild(scrollChild)
  return scrollChild
end

function mainFrameModule:CreateTitle(addonFrame)
  local title = --[[---@type WowFontString]] addonFrame:CreateFontString(nil, "OVERLAY");
  title:SetFontObject("GameFontHighlightLarge");
  title:SetPoint("CENTER", addonFrame.TitleBg, "CENTER", 0, 0);
  title:SetText("Restocker");
  addonFrame.title = title
  return title
end

function mainFrameModule:CreateAddGroup(addonFrame, listInset)
  local addGrp = --[[---@type RsControl]] CreateFrame("Frame", nil, addonFrame);
  addGrp:SetPoint("BOTTOM", addonFrame.listInset, "BOTTOM", 0, 2);
  addGrp:SetSize(listInset.width - 5, 25);
  addonFrame.addGrp = addGrp
  return addGrp
end

function mainFrameModule:CreateAddButton(addGrp)
  local addBtn = --[[---@type RsControl]] CreateFrame("Button", nil, addGrp, "GameMenuButtonTemplate");
  addBtn:SetPoint("BOTTOMRIGHT", addGrp, "BOTTOMRIGHT");
  addBtn:SetSize(60, 25);
  addBtn:SetText("Add");
  addBtn:SetNormalFontObject("GameFontNormal");
  addBtn:SetHighlightFontObject("GameFontHighlight");
  addBtn:SetScript("OnClick", function(self, button, down)
    local editBox = self:GetParent():GetParent().editBox
    local text = editBox:GetText()

    RS:addItem(text);

    editBox:SetText("")
    editBox:ClearFocus()
  end);
  return addBtn
end

function mainFrameModule:CreateEditbox(addonFrame, addBtn)
  local editBox = CreateFrame("EditBox", nil, addonFrame.addGrp, "InputBoxTemplate");
  editBox:SetPoint("RIGHT", addBtn, "LEFT", 3);
  editBox:SetAutoFocus(false);
  editBox:SetSize(addonFrame.addGrp:GetWidth() - addBtn:GetWidth() - 5, 25);
  editBox:SetScript("OnEnterPressed", function(self)
    local text = self:GetText()
    RS:addItem(text)
    self:SetText("")
    self:ClearFocus()
  end)
  editBox:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
      local infoType, _, info2 = GetCursorInfo()
      if infoType == "item" then
        RS:addItem(info2)
        ClearCursor()
      end
    end
  end)
  editBox:SetScript("OnReceiveDrag", function(self)
    local infoType, _, info2 = GetCursorInfo()
    if infoType == "item" then
      RS:addItem(info2)
      ClearCursor()
    end
  end)
  editBox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(RS.FormatTexture(RS.BAG_ICON) .. " Add an item")
    GameTooltip:AddLine("Drop an item from your bag, or type a numeric item ID")
    GameTooltip:Show()
  end)
  editBox:SetScript("OnLeave", function(self, motion)
    GameTooltip:Hide()
  end)

  addonFrame.editBox = editBox
  addonFrame.addBtn = addBtn
  return editBox
end

function mainFrameModule:CreateSettingsButton(addonFrame)
  local settingsBtn = --[[---@type RsControl]] CreateFrame("Button", nil, addonFrame, "GameMenuButtonTemplate");
  settingsBtn:SetPoint("BOTTOMRIGHT", addonFrame, "BOTTOMRIGHT", -8, 8);
  settingsBtn:SetSize(80, 25);
  settingsBtn:SetText("Settings");
  settingsBtn:SetNormalFontObject("GameFontNormal");
  settingsBtn:SetHighlightFontObject("GameFontHighlight");

  settingsBtn:SetScript("OnClick", function(self, button, down)
    LibStub("AceConfigDialog-3.0"):Open(TOCNAME)
  end);
  return settingsBtn
end

function mainFrameModule:CreateProfilesDropdown(addonFrame)
  local settings = restockerModule.settings
  local profileText = addonFrame:CreateFontString(nil, "OVERLAY")
  profileText:SetPoint("BOTTOMLEFT", addonFrame, "BOTTOMLEFT", 10, 12)
  profileText:SetFontObject("GameFontNormal")
  profileText:SetText("Profile:")

  local Restocker_ProfileDropDownMenu = CreateFrame("Frame", "Restocker_ProfileDropDownMenu", addonFrame,
    "UIDropDownMenuTemplate")
  Restocker_ProfileDropDownMenu:SetPoint("LEFT", profileText, "LEFT", 80, 0)
  --Restocker_ProfileDropDownMenu.displayMode = "MENU"
  UIDropDownMenu_SetWidth(Restocker_ProfileDropDownMenu, 120, 500)
  UIDropDownMenu_SetButtonWidth(Restocker_ProfileDropDownMenu, 140)
  UIDropDownMenu_SetText(Restocker_ProfileDropDownMenu, settings.currentProfile)

  Restocker_ProfileDropDownMenu.initialize = function(self, level)
    if not level then
      return
    end

    for profileName, _ in pairs(settings.profiles) do
      local info = UIDropDownMenu_CreateInfo()

      info.text = profileName
      info.arg1 = profileName
      info.func = RS.DropDownMenuSelectProfile
      info.checked = profileName == settings.currentProfile

      UIDropDownMenu_AddButton(info, 1)
    end
  end

  addonFrame.profileDropDownMenu = Restocker_ProfileDropDownMenu
end

function mainFrameModule:CreateMenu()
  local addonFrame = self:CreateAddonFrame()
  local listInset = self:CreateListInset(addonFrame)
  local scrollFrame = self:CreateScrollFrame(addonFrame, listInset)
  local _ = self:CreateScrollChild(scrollFrame, addonFrame)
  local _ = self:CreateTitle(addonFrame)
  local addGrp = self:CreateAddGroup(addonFrame, listInset)
  local addBtn = self:CreateAddButton(addGrp)
  local _ = self:CreateEditbox(addonFrame, addBtn)

  self:CreateProfilesDropdown(addonFrame)
  local _ = self:CreateSettingsButton(addonFrame)

  table.insert(UISpecialFrames, "RestockerMainFrame")
  addonFrame:Hide()

  RS.MainFrame = addonFrame
  return RS.MainFrame
end

-- Handle shiftclicks of items
local origChatEdit_InsertLink = ChatEdit_InsertLink;
ChatEdit_InsertLink = function(link)
  if RS.MainFrame.editBox:IsVisible() and RS.MainFrame.editBox:HasFocus() then
    return RS:addItem(link)
  end
  return origChatEdit_InsertLink(link);
end

function RS.DropDownMenuSelectProfile(self, arg1, arg2, checked)
  RS:ChangeProfile(arg1)
end

---@param text string|number
function RS:addItem(text)
  local settings = restockerModule.settings
  local currentProfile = settings.profiles[settings.currentProfile]

  if tonumber(text) then
    text = --[[---@not nil]] tonumber(text)
  end

  --local itemName, itemLink = GetItemInfo(text)
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