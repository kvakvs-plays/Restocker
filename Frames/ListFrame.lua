local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

local bankModule = RsModule.bankModule ---@type RsBankModule
local restockerModule = RsModule.restockerModule ---@type RsRestockerModule
local eventsModule = RsModule.eventsModule ---@type RsEventsModule

-- Required-reputation choices for the per-row dropdown. `value` is the item.reaction
-- code the merchant logic compares against UnitReaction(vendor) -- 0 means "no
-- requirement". `discount` is the standard Classic faction-vendor price saving for
-- that standing, shown for reference (it is informational, not enforced here).
-- "Neutral" is omitted: requiring Neutral is the same as no requirement ("Any"), since
-- you can already buy from any vendor you're at least Neutral with.
local REP_STANDINGS = {
  { value = 0, label = "Any",      discount = 0 },
  { value = 5, label = "Friendly", discount = 5 },
  { value = 6, label = "Honored",  discount = 10 },
  { value = 7, label = "Revered",  discount = 15 },
  { value = 8, label = "Exalted",  discount = 20 },
}

---@param value number|nil
local function repStandingByValue(value)
  value = value or 0
  for _, s in ipairs(REP_STANDINGS) do
    if s.value == value then
      return s
    end
  end
  return REP_STANDINGS[1] -- default to "Any"
end

---Menu label, e.g. "Honored  (10% off)"
local function repMenuText(s)
  if s.discount and s.discount > 0 then
    return s.label .. "  (" .. s.discount .. "% off)"
  end
  return s.label
end

-- Height of one list row in pixels (raise for more spacing between rows)
RS.ROW_HEIGHT = 26

---Render a toggle button: always show its label, gold when on, dimmed grey when off.
---@param btn RsItemButton
---@param label string
---@param on boolean|nil
local function rsSetToggleButton(btn, label, on)
  btn:SetText(label)
  local fs = btn:GetFontString()
  if fs then
    if on then
      fs:SetTextColor(1, 0.82, 0) -- gold = enabled
    else
      fs:SetTextColor(0.5, 0.5, 0.5) -- grey = disabled
    end
  end
end

-- The reputation menu uses Blizzard's UIDropDownMenu API -- the SAME one the working
-- profile selector uses -- not EasyMenu (which is unreliable in current Classic Era).
-- One shared menu frame is reused by every row; the row/item it was opened for is
-- stashed here so the initializer knows what to draw and where to write the choice.
local repMenuItem = nil ---@type RsTradeCommand|nil
local repMenuRow = nil  ---@type RsRestockingListRow|nil

RS.repMenuFrame = RS.repMenuFrame
    or CreateFrame("Frame", "RestockerRepMenu", UIParent, "UIDropDownMenuTemplate")

---UIDropDownMenu initializer: a title plus one entry per standing, current one checked.
---Selecting an entry writes item.reaction and refreshes the row.
local function repMenuInitialize(_self, level)
  if not repMenuItem then
    return
  end

  local title = UIDropDownMenu_CreateInfo()
  title.text = "Required reputation"
  title.isTitle = true
  title.notCheckable = true
  UIDropDownMenu_AddButton(title, level)

  for _, s in ipairs(REP_STANDINGS) do
    local info = UIDropDownMenu_CreateInfo()
    info.text = repMenuText(s)
    info.checked = ((repMenuItem.reaction or 0) == s.value)
    info.func = function()
      -- store nil for "Any" so nothing is persisted; otherwise the standing code
      repMenuItem.reaction = (s.value > 0) and s.value or nil
      RS:UpdateRestockListRow( --[[---@not nil]] repMenuRow, --[[---@not nil]] repMenuItem)
      CloseDropDownMenus()
    end
    UIDropDownMenu_AddButton(info, level)
  end
end

local function rsTooltip(control, text)
  control:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(text)
    GameTooltip:Show()
  end)
  control:SetScript("OnLeave", function(self, motion)
    GameTooltip:Hide()
  end)
end

---Create an amount edit box, aligning to the left of alignFrame
---@param frame RsRestockerFrame
---@param chainTo RsRestockerFrame
local function rsAmountEditBox(frame, chainTo)
  local settings = restockerModule.settings
  local editBox = --[[---@type WowInputBox]] CreateFrame("EditBox", nil, frame, "InputBoxTemplate");

  editBox:SetSize(40, 20)
  editBox:SetPoint("RIGHT", chainTo, "LEFT", 3, 0);
  editBox:SetAutoFocus(false);
  editBox:SetScript("OnEnterPressed", function(self)
    local amount = self:GetText()
    local parent = --[[---@type RsRestockingListRow]] self:GetParent()

    if amount == "" then
      amount = 0;
    end

    if parent.item then
      parent.item.amount = --[[---@not nil]] tonumber(amount)
    end
    editBox:ClearFocus()
    self:SetText(tonumber(amount));
    RS:Update()
    if bankModule.bankIsOpen then
      eventsModule.OnBankOpen(true)
    end
  end);
  editBox:SetScript("OnKeyUp",
    function(self)
      local amount = self:GetText()
      local parent = --[[---@type RsRestockingListRow]] self:GetParent()

      if amount == "" then
        amount = 0;
      end

      if parent.item then
        parent.item.amount = --[[---@not nil]] tonumber(amount)
      end
    end)

  rsTooltip(editBox, "Amount to restock|n"
    .. restockerModule:Color("ffffff", "Press Enter when finished editing"))

  frame.editBox = editBox
  frame.isInUse = true
  frame:Show()

  return editBox;
end

---Create the required-reputation dropdown button, aligning to the left of chainTo.
---Clicking it opens a menu of standings (Any/Neutral/.../Exalted) with the standard
---vendor discount shown. The chosen standing is stored as item.reaction.
---@param frame RsRestockerFrame
---@param chainTo RsRestockerFrame
---@param item RsTradeCommand
---@return RsItemButton
local function rsReputationButton(frame, chainTo, item)
  local btn = --[[---@type RsItemButton]] CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")

  btn:SetPoint("RIGHT", chainTo, "LEFT", -4, 0)
  btn:SetSize(62, 22)
  btn.item = item

  local fs = btn:GetFontString()
  if fs then
    fs:SetFontObject("GameFontNormalSmall")
    fs:SetTextColor(0.85, 0.6, 0.35) -- keep the reputation control's amber tint
  end

  btn:SetScript("OnClick", function(self)
    repMenuItem = self.item
    repMenuRow = frame
    UIDropDownMenu_Initialize(RS.repMenuFrame, repMenuInitialize, "MENU")
    ToggleDropDownMenu(1, nil, RS.repMenuFrame, "cursor", 0, 0)
    -- The main window is FULLSCREEN strata, so the menu would open BEHIND it at the
    -- default DIALOG strata. Lift the open list above the window.
    if DropDownList1 then
      DropDownList1:SetFrameStrata("FULLSCREEN_DIALOG")
    end
  end)

  rsTooltip(btn,
    restockerModule:Color("ffffff", "Required vendor reputation") .. "|n"
    .. "Only buy from a vendor you are at least this standing with.|n"
    .. "Higher standing also means a cheaper price (Friendly 5%, Honored 10%,|n"
    .. "Revered 15%, Exalted 20%).|n"
    .. restockerModule:Color("ffffff", "Click to choose a standing"))

  return btn
end

local function rsOnDeleteButtonClick(self)
  local parent = --[[---@type RsRestockingListRow]] self:GetParent()
  local settings = restockerModule.settings
  local profile = --[[---@not nil]] settings.profiles[settings.currentProfile]
  local item = parent.item

  if item and item.itemID then
    -- Profiles are keyed by itemID, so removal is a direct delete
    profile[item.itemID] = nil
    RS:Update();
  end
end

---Create a X button which on click will remove the restocking item row
local function rsDeleteButton(frame)
  local btn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")

  btn:SetPoint("RIGHT", frame, "RIGHT", 8, 0)
  btn:SetSize(30, 30)
  btn:SetScript("OnClick", rsOnDeleteButtonClick)
  rsTooltip(btn, "Remove this item from the maintained list")
  return btn
end

---Create a button to toggle buying from merchants
---@param item RsTradeCommand
---@return RsItemButton
local function rsBuyFromMerchantButton(frame, chainTo, item)
  local btn = --[[---@type RsItemButton]] CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")

  btn:SetPoint("RIGHT", chainTo, "LEFT", 3, 0);
  btn:SetSize(50, 22)
  if btn:GetFontString() then btn:GetFontString():SetFontObject("GameFontNormalSmall") end
  btn.item = item

  btn:SetScript("OnClick", function(self)
    if self.item.buyFromMerchant == nil then
      self.item.buyFromMerchant = false -- nil default to true, so toggle to false
    else
      self.item.buyFromMerchant = not self.item.buyFromMerchant
    end
    RS:UpdateRestockListRow(frame, self.item)
  end)
  rsTooltip(btn, restockerModule:Color("ffffff", "Buy from merchant") .. "|n"
    .. "Buy necessary quantity from merchant, when merchant window is open")
  return btn
end

---Create a button to toggle storing to bank
---@param item RsTradeCommand
---@return RsItemButton
local function rsStashToBankButton(frame, chainTo, item)
  local btn = --[[---@type RsItemButton]] CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")

  btn:SetPoint("RIGHT", chainTo, "LEFT", 3, 0);
  btn:SetSize(62, 22)
  if btn:GetFontString() then btn:GetFontString():SetFontObject("GameFontNormalSmall") end
  btn.item = item

  btn:SetScript("OnClick", function(self)
    self.item.stashTobank = not self.item.stashTobank
    RS:UpdateRestockListRow(frame, self.item)
  end)
  rsTooltip(btn, restockerModule:Color("ffffff", "Stash to bank") .. "|n"
    .. "Store extra items in bank, when bank is open. Use 0 to store all")
  return btn
end

---Create a button to toggle restocking from bank
---@param item RsTradeCommand
---@return RsItemButton
local function rsRestockFromBankButton(frame, chainTo, item)
  local btn = --[[---@type RsItemButton]] CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")

  btn:SetPoint("RIGHT", chainTo, "LEFT", 3, 0);
  btn:SetSize(62, 22)
  if btn:GetFontString() then btn:GetFontString():SetFontObject("GameFontNormalSmall") end
  btn.item = item

  btn:SetScript("OnClick", function(self)
    self.item.restockFromBank = not self.item.restockFromBank
    RS:UpdateRestockListRow(frame, self.item)
  end)
  rsTooltip(btn, restockerModule:Color("ffffff", "Restock from bank") .. "|n"
    .. "Take necessary items items from bank, when bank is open")
  return btn
end

function RS:CreateFrame()
  -- Rows are positioned by RS:Update (absolute row index), not chained here, so headers
  -- and item rows can interleave freely.
  local frame = --[[---@type RsReusableFrame]] CreateFrame("Frame", nil, RS.hiddenFrame, nil)
  frame.index = #RS.framepool + 1
  frame:SetSize(RS.MainFrame.scrollChild:GetWidth(), RS.ROW_HEIGHT);
  return frame
end

---The item-type group used for sorting and section headers -- the exact WoW item class
---from GetItemInfo (e.g. "Consumable", "Weapon", "Armor", "Quest", "Trade Goods",
---"Miscellaneous"). Falls back to a stored type, then "Other" until the item is cached.
---@param item RsTradeCommand
---@return string
local function rsItemGroupOf(item)
  local info = RS.GetItemInfo(item.itemID)
  if info and info.itemType and info.itemType ~= "" then
    return info.itemType
  end
  if item.itemType and item.itemType ~= "" then
    return item.itemType
  end
  return "Other"
end

local function rsCompareName(a, b)
  return (a.itemName or "") < (b.itemName or "")
end

---Apply the text filter, then group the items by type into a render list: a sequence of
---{ item = <item> } entries with { header = <type> } entries at each group boundary.
---Items are sorted by type, then by name within each group.
---@param items RsTradeCommand[]
---@return table[]
function RS:BuildRenderList(items)
  -- Text filter: once 2+ characters are typed, keep only items whose name or type
  -- contains the text (case-insensitive, plain substring). Fewer chars = show all.
  local filter = RS.listFilter
  if filter and #filter >= 2 then
    local lf = filter:lower()
    local kept = {}
    for _, item in ipairs(items) do
      if ((item.itemName or ""):lower():find(lf, 1, true))
          or (rsItemGroupOf(item):lower():find(lf, 1, true)) then
        kept[#kept + 1] = item
      end
    end
    items = kept
  end

  -- Always grouped by item type, name-sorted within each group
  table.sort(items, function(a, b)
    local ga, gb = rsItemGroupOf(a), rsItemGroupOf(b)
    if ga ~= gb then
      return ga < gb
    end
    return rsCompareName(a, b)
  end)

  local renderList = {}
  local lastGroup = nil
  for _, item in ipairs(items) do
    local g = rsItemGroupOf(item)
    if g ~= lastGroup then
      renderList[#renderList + 1] = { header = g }
      lastGroup = g
    end
    renderList[#renderList + 1] = { item = item }
  end
  return renderList
end

---Create a section-header row (a tinted bar with the item-type name).
local function rsCreateHeaderRow()
  local frame = CreateFrame("Frame", nil, RS.hiddenFrame)
  frame:SetSize(RS.MainFrame.scrollChild:GetWidth(), RS.ROW_HEIGHT)

  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
  bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 1)
  bg:SetColorTexture(1, 0.82, 0, 0.10) -- subtle gold band

  local text = frame:CreateFontString(nil, "OVERLAY")
  text:SetFontObject("GameFontNormal")
  text:SetTextColor(1, 0.82, 0)
  text:SetPoint("LEFT", frame, "LEFT", 8, 0)
  frame.text = text

  table.insert(RS.headerpool, frame)
  return frame
end

---@return RsControl A free (or new) section-header row
function RS:GetHeaderRow()
  for _, h in ipairs(RS.headerpool) do
    if not h.isInUse then
      return h
    end
  end
  return rsCreateHeaderRow()
end

---@class RsItemButton: WowControl
---@field item RsTradeCommand

---@class RsRestockingListRow: RsControl
---@field text WowFontString
---@field icon WowTexture
---@field iconBtn WowControl
---@field editBox WowInputBox
---@field delBtn RsItemButton
---@field buyBtn RsItemButton
---@field toBankBtn RsItemButton
---@field fromBankBtn RsItemButton
---@field amountBox WowControl
---@field repBtn RsItemButton
---@field item RsTradeCommand

---Create UI row for items
---@return RsRestockingListRow
---@param item RsTradeCommand
function RS:CreateRestockListRow(item)
  local frame = --[[---@type RsRestockingListRow]] self:CreateFrame()
  frame.item = item

  -- ICON, with an invisible button over it that shows the item tooltip on hover
  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetPoint("LEFT", frame, "LEFT", 2, 0)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) -- trim the default icon border
  frame.icon = icon

  local iconBtn = CreateFrame("Button", nil, frame)
  iconBtn:SetAllPoints(icon)
  iconBtn:SetScript("OnEnter", function(self)
    local it = frame.item
    if not (it and it.itemID) then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    -- Prefer the cached colored link; fall back to a bare item: link (always valid)
    local info = RS.GetItemInfo(it.itemID)
    GameTooltip:SetHyperlink((info and info.itemLink) or ("item:" .. it.itemID))
    GameTooltip:Show()
  end)
  iconBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  frame.iconBtn = iconBtn

  -- CONTROLS, built right-to-left so the on-screen order is:
  --   [amount] [Bank Get] [Bank Put] [Buy Merchant] [Rep] [X]
  frame.delBtn = rsDeleteButton(frame)
  frame.repBtn = rsReputationButton(frame, frame.delBtn, item)
  frame.buyBtn = rsBuyFromMerchantButton(frame, frame.repBtn, item)
  frame.toBankBtn = rsStashToBankButton(frame, frame.buyBtn, item)
  frame.fromBankBtn = rsRestockFromBankButton(frame, frame.toBankBtn, item)
  frame.amountBox = rsAmountEditBox(frame, frame.fromBankBtn)

  -- ITEM NAME fills the gap between the icon and the leftmost control (the amount box).
  -- Anchoring both sides (plus no word-wrap) keeps long names from overlapping controls.
  local text = frame:CreateFontString(nil, "OVERLAY", nil);
  text:SetFontObject("GameFontHighlight");
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  text:SetPoint("LEFT", icon, "RIGHT", 4, 0);
  text:SetPoint("RIGHT", frame.amountBox, "LEFT", -6, 0);
  frame.text = text

  table.insert(RS.framepool, frame)
  return frame
end

---@param row RsRestockingListRow
---@param item RsTradeCommand
function RS:UpdateRestockListRow(row, item)
  row.item = item
  row.buyBtn.item = item
  row.fromBankBtn.item = item
  row.toBankBtn.item = item
  row.repBtn.item = item

  -- Toggle buttons always show their label; gold when on, dimmed grey when off.
  -- buyFromMerchant defaults to true (nil).
  rsSetToggleButton(row.buyBtn, "Buy", item.buyFromMerchant == nil or item.buyFromMerchant)
  rsSetToggleButton(row.fromBankBtn, "Withdraw", item.restockFromBank)
  rsSetToggleButton(row.toBankBtn, "Deposit", item.stashTobank)

  -- Icon + quality-colored name (from the item cache; falls back until it is known)
  local info = RS.GetItemInfo(item.itemID)
  if info then
    row.icon:SetTexture(info.itemTexture)
    local q = ITEM_QUALITY_COLORS[info.itemRarity or 1]
    if q then
      row.text:SetTextColor(q.r, q.g, q.b)
    else
      row.text:SetTextColor(1, 1, 1)
    end
  else
    row.icon:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark")
    row.text:SetTextColor(1, 1, 1)
  end

  row.text:SetText(item.itemName)
  row.editBox:SetText(tostring(item.amount or 0))

  -- Reputation requirement button label
  row.repBtn:SetText(repStandingByValue(item.reaction).label)
end

function RS:addListFrames()
  local settings = restockerModule.settings
  local profile = --[[---@not nil]] settings.profiles[settings.currentProfile]

  for _, item in pairs(profile) do
    local frame = RS:CreateRestockListRow(item)
    RS:UpdateRestockListRow(frame, item)
  end
end