local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

local bankModule = RsModule.bankModule ---@type RsBankModule
local restockerModule = RsModule.restockerModule ---@type RsRestockerModule
local eventsModule = RsModule.eventsModule ---@type RsEventsModule

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
    local parent = self:GetParent()
    local text = parent.text:GetText()

    if amount == "" then
      amount = 0;
    end

    for _, item in ipairs(settings.profiles[settings.currentProfile]) do
      if item.itemName == text then
        item.amount = --[[---@not nil]] tonumber(amount)
      end
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
      local parent = self:GetParent()
      local text = parent.text:GetText()

      if amount == "" then
        amount = 0;
      end

      for _, item in ipairs(settings.profiles[settings.currentProfile]) do
        if item.itemName == text then
          item.amount = --[[---@not nil]] tonumber(amount)
        end
      end
    end)

  rsTooltip(editBox, "Amount to restock|n"
    .. restockerModule:Color("ffffff", "Press Enter when finished editing"))

  frame.editBox = editBox
  frame.isInUse = true
  frame:Show()

  return editBox;
end

-- Add a small edit box defaulting to empty value, aligning to the left of alignFrame.
---Will check faction reaction on vendor if not empty.
---@param frame RsRestockerFrame
---@param chainTo RsRestockerFrame
local function rsRequireReactionEditBox(frame, chainTo)
  local settings = restockerModule.settings
  local reactionBox = --[[---@type WowInputBox]] CreateFrame("EditBox", nil, frame, "InputBoxTemplate");

  reactionBox:SetSize(20, 20)
  reactionBox:SetPoint("RIGHT", chainTo, "LEFT", -4, 0);
  reactionBox:SetAutoFocus(false);
  reactionBox:SetTextColor(0.8, 0.5, 0.3)

  reactionBox:SetScript("OnEnterPressed",
    function(self)
      local reaction = self:GetText()
      local parent = self:GetParent()
      local text = parent.text:GetText()

      if reaction == "" then
        reaction = 0;
      end

      for _, item in ipairs(settings.profiles[settings.currentProfile]) do
        if item.itemName == text then
          item.reaction = --[[---@not nil]] tonumber(reaction)
        end
      end
      reactionBox:ClearFocus()
      self:SetText(tonumber(reaction));
      RS:Update()
    end)

  reactionBox:SetScript("OnKeyUp",
    function(self)
      local reaction = self:GetText()
      local parent = self:GetParent()
      local text = parent.text:GetText()

      if reaction == "" then
        reaction = 0;
      end

      for _, item in ipairs(settings.profiles[settings.currentProfile]) do
        if item.itemName == text then
          item.reaction = --[[---@not nil]] tonumber(reaction)
        end
      end
    end)

  -- Tooltip
  rsTooltip(reactionBox,
    restockerModule:Color("ffffff", "Required vendor reputation (default 0 or empty)") .. "|n"
    .. "Check player's reputation standing with the vendor before you buy|n"
    .. "Neutral=4, Friendly=5, Honored=6, Revered=7, Exalted=8|n"
    .. restockerModule:Color("ffffff", "Press Enter when finished editing"))

  -- Save the value
  frame.reactionBox = reactionBox
  frame:Show()

  return reactionBox;
end

local function rsOnDeleteButtonClick(self)
  local parent = self:GetParent()
  local text = parent.text:GetText()
  local settings = restockerModule.settings
  local profile = --[[---@not nil]] settings.profiles[settings.currentProfile]

  for i, item in ipairs(profile) do
    if item.itemName == text then
      tremove(settings.profiles[settings.currentProfile], i)
      RS:Update();
      break
    end
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
  btn:SetSize(24, 24)
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
  btn:SetSize(36, 24)
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
  btn:SetSize(36, 24)
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
  local frame = --[[---@type RsReusableFrame]] CreateFrame("Frame", nil, RS.hiddenFrame, nil)
  frame.index = #RS.framepool + 1
  frame:SetSize(RS.MainFrame.scrollChild:GetWidth(), 20);

  if #RS.framepool == 0 then
    frame:SetPoint("TOP", RS.MainFrame.scrollChild, "TOP")
  else
    frame:SetPoint("TOP", RS.framepool[#RS.framepool], "BOTTOM")
  end

  RS.MainFrame.scrollChild:SetHeight(#RS.framepool * 20)
  return frame
end

---@class RsItemButton: WowControl
---@field item RsTradeCommand

---@class RsRestockingListRow: RsControl
---@field text WowFontString
---@field editBox WowInputBox
---@field delBtn RsItemButton
---@field buyBtn RsItemButton
---@field toBankBtn RsItemButton
---@field fromBankBtn RsItemButton
---@field amountBox WowControl
---@field reactionBox WowControl
---@field item RsTradeCommand

---Create UI row for items
---@return RsRestockingListRow
---@param item RsTradeCommand
function RS:CreateRestockListRow(item)
  local frame = --[[---@type RsRestockingListRow]] self:CreateFrame()

  -- ITEM TEXT
  local text = frame:CreateFontString(nil, "OVERLAY", nil);
  text:SetFontObject("GameFontHighlight");
  text:SetPoint("LEFT", frame, "LEFT");
  frame.text = text

  -- BUTTONS (reverse order right to left)
  frame.delBtn = rsDeleteButton(frame)
  frame.buyBtn = rsBuyFromMerchantButton(frame, frame.delBtn, item)
  frame.toBankBtn = rsStashToBankButton(frame, frame.buyBtn, item)
  frame.fromBankBtn = rsRestockFromBankButton(frame, frame.toBankBtn, item)

  -- EDITBOX
  frame.amountBox = rsAmountEditBox(frame, frame.fromBankBtn)
  frame.reactionBox = rsRequireReactionEditBox(frame, frame.amountBox)

  table.insert(RS.framepool, frame)
  return frame
end

---@param row RsRestockingListRow
---@param item RsTradeCommand
function RS:UpdateRestockListRow(row, item)
  row.buyBtn.item = item
  row.fromBankBtn.item = item
  row.toBankBtn.item = item

  if item.buyFromMerchant == nil or item.buyFromMerchant then
    -- nil default to true
    row.buyBtn:SetText("$")
  else
    row.buyBtn:SetText("-")
  end
  if item.stashTobank then
    row.toBankBtn:SetText(">B")
  else
    row.toBankBtn:SetText("-")
  end
  if item.restockFromBank then
    row.fromBankBtn:SetText("B>")
  else
    row.fromBankBtn:SetText("-")
  end

  row.text:SetText(item.itemName)
  row.editBox:SetText(tostring(item.amount or 0))
  row.reactionBox:SetText(tostring(item.reaction or 0))
end

function RS:addListFrames()
  local settings = restockerModule.settings
  local profile = --[[---@not nil]] settings.profiles[settings.currentProfile]

  for _, item in ipairs(profile) do
    local frame = RS:CreateRestockListRow(item)
    frame.text:SetText(item.itemName)
    frame.editBox:SetText(tostring(item.amount))
  end
end