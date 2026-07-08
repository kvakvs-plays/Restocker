# Restocker Code Map

Last scanned: 2026-07-08.

This map is the first stop for finding Restocker code. Keep it current whenever Lua files or named functions are added, removed, renamed, or moved. Function lists intentionally omit line numbers so this file stays stable across small edits.

## Load Order

Source of truth: `toc_template.toc`. Generated TOCs should keep the same Lua load order.

1. `embeds.xml`
2. `Src\Module.lua`
3. `Src\KvLib\KvEnv.lua`
4. `Src\Restocker.lua`
5. `Src\KvLib\KvOptions.lua`
6. `Classes\RestockerClass.lua`
7. `Classes\BuyCommand.lua`
8. `Classes\RestockerConf.lua`
9. `Classes\Recipe.lua`
10. `Src\BuyIngredients.lua`
11. `Src\Events.lua`
12. `Src\AddonOptions.lua`
13. `Src\Settings.lua`
14. `Frames\AceMainFrame.lua`
15. `Frames\MainFrame.lua`
16. `Frames\ListFrame.lua`
17. `Frames\LegacyOptionsPanel.lua`
18. `Src\Bank.lua`
19. `Src\Merchant.lua`
20. `Src\Item.lua`
21. `Src\Cache.lua`
22. `Src\Inspect.lua`
23. `Src\Bag.lua`
24. `Src\Inventory.lua`

## Runtime Shape

- `RsModule` is the shared module registry. Runtime modules attach methods to tables such as `RsModule.bankModule`, `RsModule.merchantModule`, and `RsModule.addonOptionsModule`.
- `RS_ADDON` is the AceAddon instance created in `Src\Restocker.lua` with AceConsole and AceEvent mixed in.
- Saved variables are per-character in `RestockerSettings`, declared in TOCs as `## SavedVariablesPerCharacter: RestockerSettings`.
- Main user flows:
  - Startup: `RS:OnInitialize()` detects versions, `RS:OnEnable()` loads settings, registers slash commands, initializes events/modules/UI/options.
  - Merchant restock: `MERCHANT_SHOW` -> `eventsModule.OnMerchantShow()` -> `merchantModule:Restock()`.
  - Bank restock: `BANKFRAME_OPENED` -> `eventsModule.OnBankOpen()` -> `bankModule:RestartRestocking()` -> `RS.onUpdateFrame` -> `bankModule.BankUpdateFn()` -> bank coroutine.
  - Item add: Ace main-frame edit box/button/shift-click/drag-drop -> `RS:addItem()` -> `RS.GetItemInfo()` cache -> profile item list -> `RS:Update()`.

## Addon Files

### `Src\Module.lua`

Feature: declares the `RsModule` registry for all Restocker modules.

Functions:
- `RsModule:CallInEachModule(fnName, context)`

### `Src\KvLib\KvEnv.lua`

Feature: environment/client-flavor detection and compatibility function selection.

Functions:
- `envModule:DetectVersions()`

### `Src\Restocker.lua`

Feature: AceAddon creation, addon lifecycle, saved-variable setup, slash command dispatch, profile operations, UI refresh, compatibility wrappers, debug helpers.

Functions:
- `RS:Show()`
- `RS:Hide()`
- `RS:Toggle()`
- `RS:SlashCommand(args)`
- `RS:Update()`
- `RS:GetFirstEmpty(item)`
- `RS:AddProfile(newProfile)`
- `RS:DeleteProfile(profile)`
- `RS:RenameCurrentProfile(newName)`
- `RS:ChangeProfile(newProfile)`
- `RS:CopyProfile(profileToCopy)`
- `RS:addItem(text)`
- `RS:loadSettings()`
- `RS:RegisterSlashCommands()`
- `SlashCmdList.RESTOCKER` handler
- `RS:Debug(t)`
- `RS.FormatTexture(texture)`
- `RS:OnInitialize()`
- `RS:OnEnable()`
- `RS:OptionsInit()`
- `RS:OnDisable()`
- `restockerModule:Color(hex, text)`
- `restockerModule:GetContainerNumSlots(containerId)`
- `restockerModule:GetContainerNumFreeSlots(containerId)`
- `restockerModule:GetMerchantItemInfo(index)`
- `restockerModule:GetContainerItemInfo(bagId, slot)`
- `restockerModule:Dump(value, ...)`

### `Src\KvLib\KvOptions.lua`

Feature: small AceConfig option-table template helpers.

Functions:
- `optionsModule:ValueToText(type, value)`
- `optionsModule:TextToValue(type, editFieldText)`
- `optionsModule:TemplateCheckbox(name, dict, key, notify, _t)`
- `TemplateCheckbox.set(info, val)`
- `TemplateCheckbox.get(info)`
- `optionsModule:TemplateButton(name, onClick, _t)`
- `optionsModule:TemplateMultiselect(name, values, dict, notifyFn, setFn, getFn, _t)`
- `TemplateMultiselect.set(state, key, value)`
- `TemplateMultiselect.get(state, key)`
- `optionsModule:TemplateSelect(name, values, style, dict, notifyFn, setFn, getFn, _t)`
- `TemplateSelect.set(info, value)`
- `TemplateSelect.get(info)`
- `optionsModule:TemplateInput(type, name, dict, key, notify, _t)`
- `TemplateInput.set(info, val)`
- `TemplateInput.get(info)`
- `optionsModule:TemplateRange(name, rangeFrom, rangeTo, step, dict, key, notify, _t)`
- `TemplateRange.set(info, val)`
- `TemplateRange.get(info)`

### `Classes\RestockerClass.lua`

Feature: EmmyLua-style type declarations for `RestockerAddon`, settings, commands, defaults, profiles, and reusable list-row frames.

Functions:
- None.

### `Classes\BuyCommand.lua`

Feature: creates restock/bank/merchant item command records.

Functions:
- `buyCommandModule:Create(amount, itemName, itemID, itemLink)`

### `Classes\RestockerConf.lua`

Feature: legacy configuration type declaration placeholder.

Functions:
- None.

### `Classes\Recipe.lua`

Feature: creates craftable recipe records for reagent autobuy.

Functions:
- `recipeModule:Create(item, reagent1, reagent2, reagent3)`

### `Src\BuyIngredients.lua`

Feature: crafting reagent autobuy table, currently focused on rogue poisons by Classic/TBC/WotLK flavor.

Functions:
- `buyIngredientsModule:AddRecipe(recipe)`
- `postpone()`
- `buyIngredientsModule:Recipe(item, reagent1, reagent2, reagent3)`
- `buyIngredientsModule:RetryWaitRecipes()`
- `buyIngredientsModule:TbcRecipe(item, reagent1, reagent2, reagent3)`
- `buyIngredientsModule:ClassicRecipe(item, reagent1, reagent2, reagent3)`
- `buyIngredientsModule:SetupAutobuyIngredients()`
- `buyIngredientsModule:CraftingPurchaseOrder()`
- `forEachIngredient(i)`
- `buyIngredientsModule.OnModuleInit()`

### `Src\Events.lua`

Feature: registers WoW events and routes them into merchant, bank, cache, and saved-position behavior.

Functions:
- `eventsModule.OnEnteringWorld(login, reloadui)`
- `eventsModule.OnMerchantShow()`
- `eventsModule.OnMerchantClose()`
- `eventsModule.OnBankOpen(isMinor)`
- `eventsModule.OnBankClose()`
- `eventsModule.OnItemInfoReceived(itemID, success)`
- `eventsModule.OnLogout()`
- `eventsModule.OnUiErrorMessage(id, message)`
- `eventsModule:InitEvents()`

### `Src\AddonOptions.lua`

Feature: AceConfig options table for General and Profiles categories, with localized label lookup.

Functions:
- `_t(key)`
- `addonOptionsModule:TemplateCheckbox(name, dict, key, notify)`
- `addonOptionsModule:TemplateButton(name, onClick)`
- `addonOptionsModule:TemplateMultiselect(name, values, dict, notifyFn, setFn, getFn)`
- `addonOptionsModule:TemplateSelect(name, values, style, dict, notifyFn, setFn, getFn)`
- `addonOptionsModule:TemplateInput(type, name, dict, key, notify)`
- `addonOptionsModule:TemplateRange(name, rangeFrom, rangeTo, step, dict, key, notify)`
- `addonOptionsModule:CreateGeneralOptions()`
- `sortList.set(info, value)`
- `sortList.get(info)`
- `slashCommand.set(info, value)`
- `slashCommand.get(info)`
- `addonOptionsModule:CreateProfilesOptions()`
- `getProfileNames()`
- `createProfileName.notify(_key, value)`
- `deleteProfileButton.func()`
- `addonOptionsModule:CreateOptionsTable()`
- `addonOptionsModule:ResetDefaultOptions()`

### `Src\Settings.lua`

Feature: profile CRUD helpers used by AceConfig options.

Functions:
- `settingsModule:AddProfile(name)`
- `settingsModule:DeleteProfile(name)`
- `settingsModule:GetProfileNames()`

### `Frames\AceMainFrame.lua`

Feature: active AceGUI Restocker window used by `/rs`, with profile selection, item add controls, drag-drop item add, rows of restock item controls, and saved AceGUI frame status.

Functions:
- `getCurrentProfile()`
- `addItemFromText(text)`
- `addCursorItem()`
- `installDropTarget(frame)`
- `refreshAfterBankSensitiveChange()`
- `createProfileList()`
- `removeItem(itemToRemove)`
- `aceMainFrameModule:GetOrCreateFrame()`
- `aceMainFrameModule:IsShown()`
- `aceMainFrameModule:Show()`
- `aceMainFrameModule:Hide()`
- `aceMainFrameModule:Toggle()`
- `aceMainFrameModule:SavePosition()`
- `aceMainFrameModule:CreateToolbar(parent)`
- `aceMainFrameModule:CreateAddControls(parent)`
- `aceMainFrameModule:CreateListHeader(parent)`
- `aceMainFrameModule:CreateItemRow(parent, item)`
- `aceMainFrameModule:Refresh(restockItems)`

### `Frames\MainFrame.lua`

Feature: deprecated legacy frame-based Restocker window. It remains loadable for compatibility, but normal `/rs` show/hide/toggle uses `Frames\AceMainFrame.lua`.

Functions:
- `mainFrameModule:CreateAddonFrame()`
- `mainFrameModule:CreateListInset(addonFrame)`
- `mainFrameModule:CreateScrollFrame(addonFrame, listInset)`
- `mainFrameModule:CreateScrollChild(scrollFrame, addonFrame)`
- `mainFrameModule:CreateTitle(addonFrame)`
- `mainFrameModule:CreateAddGroup(addonFrame, listInset)`
- `mainFrameModule:CreateAddButton(addGrp)`
- `AddButton.OnClick(self, button, down)`
- `mainFrameModule:CreateEditbox(addonFrame, addBtn)`
- `EditBox.OnEnterPressed(self)`
- `EditBox.OnMouseUp(self, button)`
- `EditBox.OnReceiveDrag(self)`
- `EditBox.OnEnter(self)`
- `EditBox.OnLeave(self, motion)`
- `mainFrameModule:CreateSettingsButton(addonFrame)`
- `SettingsButton.OnClick(self, button, down)`
- `mainFrameModule:CreateProfilesDropdown(addonFrame)`
- `Restocker_ProfileDropDownMenu.initialize(self, level)`
- `mainFrameModule:CreateMenu()`
- `ChatEdit_InsertLink(link)`
- `RS.DropDownMenuSelectProfile(self, arg1, arg2, checked)`

### `Frames\ListFrame.lua`

Feature: deprecated legacy reusable rows for `Frames\MainFrame.lua`. The active `/rs` rows are AceGUI controls in `Frames\AceMainFrame.lua`.

Functions:
- `rsTooltip(control, text)`
- `rsAmountEditBox(frame, chainTo)`
- `AmountEditBox.OnEnterPressed(self)`
- `AmountEditBox.OnKeyUp(self)`
- `rsRequireReactionEditBox(frame, chainTo)`
- `ReactionEditBox.OnEnterPressed(self)`
- `ReactionEditBox.OnKeyUp(self)`
- `rsOnDeleteButtonClick(self)`
- `rsDeleteButton(frame)`
- `rsBuyFromMerchantButton(frame, chainTo, item)`
- `BuyFromMerchantButton.OnClick(self)`
- `rsStashToBankButton(frame, chainTo, item)`
- `StashToBankButton.OnClick(self)`
- `rsRestockFromBankButton(frame, chainTo, item)`
- `RestockFromBankButton.OnClick(self)`
- `RS:CreateFrame()`
- `RS:CreateRestockListRow(item)`
- `RS:UpdateRestockListRow(row, item)`
- `RS:addListFrames()`

### `Frames\LegacyOptionsPanel.lua`

Feature: deprecated manual Interface Options panel kept for reference; current options use AceConfig.

Functions:
- `RS:CreateOptionsMenu(name)`
- `loginMessage.OnClick(self, button)`
- `autoOpenAtMerchant.OnClick(self, button)`
- `autoOpenAtBank.OnClick(self, button)`
- `sortListAlphabetically.OnClick(self, button)`
- `sortListNumerically.OnClick(self, button)`
- `addProfileButton.OnClick(self, button, down)`
- `deleteProfileMenu.initialize(self, level)`
- `deleteProfileButton.OnClick(self, button, down)`
- `RS.selectProfileForDeletion(self, arg1, arg2, checked)`

### `Src\Bank.lua`

Feature: bank restocking state, bank-to-bag and bag-to-bank movement loop, coroutine throttled by `OnUpdate`.

Functions:
- `bankModule:NewState()`
- `bankModule.OnModuleInit()`
- `bankModule.StashToBank()`
- `bankModule.RestockFromBank()`
- `stateClass:UpdateInventory()`
- `itemExistsFn(itemname)`
- `stateClass:CountItemsTooMany()`
- `stateClass:CountItemsTooFew()`
- `bankModule:RunRestockLogic()`
- `restockCoro()`
- `bankModule:MaintainAndResumeCoro()`
- `bankModule.BankUpdateFn(self, elapsed)`
- `bankModule:RestartRestocking()`
- `RS.Test()`

### `Src\Merchant.lua`

Feature: merchant restock planning and purchase execution, including reagent purchase-order merging.

Functions:
- `merchantModule:CountTableItems(theTable)`
- `merchantModule:BuildSellOrder(sellOrders, eachRestockRecord)`
- `merchantModule:BuildPurchaseOrder(purchaseOrders, eachRestockRecord, vendorReaction)`
- `merchantModule:UpdatePurchaseOrdersWithCraftingReagents(purchaseOrders, ingredientName, toBuy)`
- `merchantModule:PurchaseMerchantItem(i, purchaseOrders, numPurchases)`
- `merchantModule:Restock()`

### `Src\Item.lua`

Feature: item value objects and stack-size comparator.

Functions:
- `itemModule:Create(id, englishName)`
- `itemModule:FromCachedItem(gii)`
- `itemModule.CompareByStacksizeAscending(a, b)`

### `Src\Cache.lua`

Feature: cached wrapper around WoW `GetItemInfo`.

Functions:
- `RS.GetItemInfo(arg)`

### `Src\Inspect.lua`

Feature: vendored `inspect.lua` table printer attached as `RS.Inspect`.

Functions:
- `rawpairs(t)`
- `smartQuote(str)`
- `escape(str)`
- `isIdentifier(str)`
- `isSequenceKey(k, sequenceLength)`
- `sortKeys(a, b)`
- `getSequenceLength(t)`
- `getNonSequentialKeys(t)`
- `countTableAppearances(t, tableAppearances)`
- `copySequence(s)`
- `makePath(path, ...)`
- `processRecursive(process, item, path, visited)`
- `Inspector:puts(...)`
- `Inspector:down(f)`
- `Inspector:tabify()`
- `Inspector:alreadyVisited(v)`
- `Inspector:getId(v)`
- `Inspector:putKey(k)`
- `Inspector:putTable(t)`
- `Inspector:putValue(v)`
- `inspect.inspect(root, options)`
- `inspect.__call(_, ...)`

### `Src\Bag.lua`

Feature: bag/bank container definitions, bag scans, free-space checks, and item movement primitives.

Functions:
- `bagSlotFromBag(bag)`
- `bagModule:NewBagDef(location, bagId, containerSlotId)`
- `createBackpack()`
- `createBag(bag)`
- `createBankMainBag()`
- `createBankBag(bag)`
- `onInit_playerBankBags()`
- `onInit_playerBankBagsReversed()`
- `onInit_playerBags()`
- `onInit_playerBagsReversed()`
- `bagModule.OnModuleInit()`
- `bagDefClass:NumSlots()`
- `bagDefClass:HasSpace()`
- `bagDefClass:PutCursorItem()`
- `bagModule:GetBankBags(reversed)`
- `bagModule:GetPlayerBags(reversed)`
- `bagModule:IsSomethingLocked()`
- `bagModule:GetItemsInBags(predicate)`
- `bagModule:ForEachBagItem(handler)`
- `bagModule:GetItemsInBank(predicate)`
- `bagModule:PutItemInBank(bankInventory, itemInfo, amount)`
- `bagModule:PutItemInPlayerBag(playerInventory, itemInfo, amount)`
- `bagModule:CheckSpace(bags)`
- `bagModule:ScanBagsFor(bags, predicate)`
- `rsContainerItemInfoMatchName(name)`
- `rsContainerItemInfoMatchNameAndSmall(name, moveAmount)`
- `rsContainerItemInfoMatchNameAndIs1Item(name, moveAmount)`
- `bagModule:MoveFromBankToPlayer_1(playerInventory, task, candidates, moveAmount)`
- `bagModule:MoveFromBankToPlayer(playerInventory, task, moveName, moveAmount)`
- `bagModule:MoveFromPlayerToBank_1(bankInventory, task, candidates, moveAmount)`
- `bagModule:MoveFromPlayerToBank(bankInventory, task, moveName, moveAmount)`
- `bagModule:CheckBankBagSpace()`

### `Src\Inventory.lua`

Feature: inventory summaries, item slot records, and stack merge best-fit lookup.

Functions:
- `inventoryModule:NewSlot(bag, slot, itemCount)`
- `inventoryModule:NewSlotNumber(bag, slot)`
- `inventoryModule:NewInventory()`
- `inventoryClass:SortSlots()`
- `sortFn(a, b)`
- `inventoryClass:FindBestFit(cachedItem, amount, bags)`
- `mergeDestinationSort(a, b)`

## Spec Files

These files are local WoW API/type stubs for tooling and static analysis, not addon runtime behavior.

### `Src\KvLib\Specs\WowGlobals.lua`

Functions:
- `C_Seasons.HasActiveSeason()`
- `C_Seasons.GetActiveSeason()`
- `strsplit(sep, str, count)`
- `debugprofilestop()`
- `CombatLogGetCurrentEventInfo()`
- `Dismount()`
- `DoEmote(e)`
- `GetSpellPowerCost(name)`
- `PlaySoundFile(s)`
- `GetTime()`
- `GetInstanceInfo()`
- `GetWeaponEnchantInfo()`
- `GetSpellCooldown(spellId)`
- `UnitPlayerOrPetInParty(unitId)`
- `UnitReaction(a, b)`
- `UnitPlayerOrPetInRaid(unitId)`
- `CastSpellByID(...)`
- `IsFlying()`
- `IsMounted()`
- `IsSpellKnown(...)`
- `GetShapeshiftForm(...)`
- `GetShapeshiftFormID(...)`
- `InCombatLockdown()`
- `UnitBuff(u, i, b)`
- `CancelUnitBuff(u, i)`
- `tContains(t, v)`
- `wipe(t)`
- `UnitName(...)`
- `UnitIsUnit(a, b)`
- `UnitLevel(u)`
- `GetSpellSubtext(spellId)`
- `GetSpellInfo(spellId)`
- `IsSpellInRange(...)`
- `UnitInParty(u)`
- `UnitInRaid(u)`
- `UnitIsPlayer(u)`
- `UnitCanCooperate(u, v)`
- `UnitFullName(u)`
- `UnitExists(u)`
- `UnitCreatureType(u)`
- `UnitCreatureFamily(u)`
- `UnitIsPVP(u)`
- `UnitIsDeadOrGhost(u)`
- `UnitOnTaxi(u)`
- `UnitInVehicle(u)`
- `UnitClass(u)`
- `IsModifierKeyDown()`
- `IsInInstance()`
- `IsOutdoors()`
- `IsInGroup()`
- `IsInRaid()`
- `IsResting()`
- `IsStealthed()`
- `UnitPower(u, pow)`
- `UnitPowerMax(u, pow)`
- `UnitRace(unit)`
- `GetMacroInfo(name)`
- `CreateMacro(name, icon, c, isChar)`
- `EditMacro(name, x, icon, text)`
- `GetNumMacros()`
- `GetNetStats()`
- `GetActiveTalentGroup()`
- `GetBuildInfo()`
- `GetCursorInfo()`
- `ClearCursor()`

### `Src\KvLib\Specs\WowInventory.lua`

Functions:
- `GetInventoryItemID(u, slot)`
- `GetInventoryItemLink(u, slot)`
- `GetInventorySlotInfo(slot)`
- `GetItemCount(name, includeBank, includeCharges)`
- `GetMerchantNumItems()`
- `GetMerchantItemInfo(i)`
- `GetMerchantItemLink(i)`
- `BuyMerchantItem(i, count)`
- `GetItemInfo(arg)`

### `Src\KvLib\Specs\WowUI.lua`

Functions:
- `SendChatMessage(s, msg, lang, name)`
- `GetAddOnMetadata(a, b)`
- `CreateFrame(name, x, parent, template)`
- `PanelTemplates_TabResize(t, n)`
- `PickupMacro(name)`
- `CursorHasItem()`

## UI Wiring

### Main Window

- `RS:Show()`, `RS:Hide()`, and `RS:Toggle()` delegate to `aceMainFrameModule`.
- `Frames\AceMainFrame.lua` creates an AceGUI `Frame` and stores size/position in `restockerModule.settings.aceFrameStatus`.
- Profile dropdown values come from `restockerModule.settings.profiles`; selecting a profile calls `RS:ChangeProfile(profileName)`.
- Add controls:
  - Add edit box `OnEnterPressed` calls `RS:addItem(text)`.
  - Add button reads the AceGUI edit box text and calls `RS:addItem(text)`.
  - AceGUI edit box shift-click insertion uses AceGUI's focused-edit-box hook.
  - Window/content/list drop targets read `GetCursorInfo()` and add dragged item links through `RS:addItem(info2)`.
- Settings button `OnClick` calls `LibStub("AceConfigDialog-3.0"):Open(TOCNAME)`.
- `Frames\MainFrame.lua` and `Frames\ListFrame.lua` are deprecated legacy UI files. They remain loaded but are no longer created by startup or slash-command routing.

### Restock List Rows

- `Frames\AceMainFrame.lua` rebuilds visible rows from the sorted active profile list supplied by `RS:Update()`.
- Each row writes directly to the active `RsTradeCommand`:
  - amount edit box writes `item.amount`; enter/OK refreshes UI and retriggers bank handling when the bank is open.
  - auto-buy checkbox writes `item.buyFromMerchant`, with nil/true displayed as enabled.
  - stash-to-bank checkbox writes `item.stashTobank`.
  - restock-from-bank checkbox writes `item.restockFromBank`.
  - required-reputation dropdown writes numeric `item.reaction` values `0`, `4`, `5`, `6`, `7`, or `8`.
  - delete button removes the item from the active profile and calls `RS:Update()`.

### Options UI

- `RS:OptionsInit()` registers the AceConfig table from `addonOptionsModule:CreateOptionsTable()` and adds it to Blizzard options with `AceConfigDialog-3.0`.
- General options in `Src\AddonOptions.lua`:
  - `loginMessage` toggle writes `restockerModule.settings.loginMessage`.
  - `autoOpenAtMerchant` toggle writes `restockerModule.settings.autoOpenAtMerchant`.
  - `autoOpenAtBank` toggle writes `restockerModule.settings.autoOpenAtBank`.
  - `sortList` radio select sets `RS.sortListAlphabetically`/`RS.sortListNumerically` and calls `RS:Update()`.
  - `slashCommand` radio select writes `restockerModule.settings.slashCommand`, calls `RS:RegisterSlashCommands()`, and prints the active command note.
  - `debugMessages` toggle writes `restockerModule.settings.debugMessages`.
- Profile options in `Src\AddonOptions.lua`:
  - `createProfileName` input calls `settingsModule:AddProfile(value)`.
  - `deleteProfileList` values come from `settingsModule:GetProfileNames()`.
  - `deleteProfileButton` execute calls `settingsModule:DeleteProfile(addonOptionsModule.deleteProfileName)`.
- Deprecated manual options in `Frames\LegacyOptionsPanel.lua` are not currently called from startup; they still wire checkboxes/buttons directly to settings and `RS:*Profile` functions if re-enabled.

## Slash Commands

- `Src\Restocker.lua` owns all slash command behavior.
- `RS:RegisterSlashCommands()` clears `SLASH_RESTOCKER1`, `SLASH_RESTOCKER2`, and `SlashCmdList.RESTOCKER`, then registers based on `restockerModule.settings.slashCommand`:
  - `"rs"` -> `/rs`
  - `"restocker"` -> `/restocker`
  - `"both"` or unknown -> `/restocker` and `/rs`
- `SlashCmdList.RESTOCKER(msg)` calls `RS:SlashCommand(msg)`.
- `RS:SlashCommand(args)` routes:
  - `show` -> `RS:Show()`
  - `profile add [name]` -> `RS:AddProfile(name)`
  - `profile delete [name]` -> `RS:DeleteProfile(name)`
  - `profile rename [name]` -> `RS:RenameCurrentProfile(name)`
  - `profile use [name]` -> `RS:ChangeProfile(name)`
  - `profile copy [name]` -> `RS:CopyProfile(name)`
  - `help` -> prints command help
  - `config` -> `AceConfigDialog-3.0:Open(TOCNAME)`
  - anything else -> `RS:Toggle()`

## Event Wiring

- `eventsModule:InitEvents()` registers these handlers on the AceEvent addon object:
  - `MERCHANT_SHOW` -> `eventsModule.OnMerchantShow()`
  - `MERCHANT_CLOSED` -> `eventsModule.OnMerchantClose()`
  - `BANKFRAME_OPENED` -> `eventsModule.OnBankOpen(isMinor)`
  - `BANKFRAME_CLOSED` -> `eventsModule.OnBankClose()`
  - `GET_ITEM_INFO_RECEIVED` -> `eventsModule.OnItemInfoReceived(itemID, success)`
  - `PLAYER_LOGOUT` -> `eventsModule.OnLogout()`
  - `PLAYER_ENTERING_WORLD` -> `eventsModule.OnEnteringWorld(login, reloadui)`
  - `UI_ERROR_MESSAGE` -> `eventsModule.OnUiErrorMessage(id, message)`
- `Src\Bank.lua` creates `RS.onUpdateFrame` and sets `OnUpdate` to `bankModule.BankUpdateFn` for bank transfer pacing.
- `RsModule:CallInEachModule("OnModuleInit", nil)` invokes module init hooks such as `bagModule.OnModuleInit()`, `bankModule.OnModuleInit()`, and `buyIngredientsModule.OnModuleInit()`.

## Embedded And Vendored Lua

The repository also contains embedded Ace3 and LibUIDropDownMenu Lua files under `Ace3\`. These files were included in the scan, but they are vendored library code rather than Restocker implementation. Prefer using their public APIs through `LibStub` instead of editing them unless the task is explicitly about embedded library maintenance.

Key embedded packages:
- `Ace3\LibStub\LibStub.lua`
- `Ace3\CallbackHandler-1.0\CallbackHandler-1.0.lua`
- `Ace3\AceAddon-3.0\AceAddon-3.0.lua`
- `Ace3\AceBucket-3.0\AceBucket-3.0.lua`
- `Ace3\AceComm-3.0\AceComm-3.0.lua`
- `Ace3\AceComm-3.0\ChatThrottleLib.lua`
- `Ace3\AceConfig-3.0\AceConfig-3.0.lua`
- `Ace3\AceConfig-3.0\AceConfigCmd-3.0\AceConfigCmd-3.0.lua`
- `Ace3\AceConfig-3.0\AceConfigDialog-3.0\AceConfigDialog-3.0.lua`
- `Ace3\AceConfig-3.0\AceConfigRegistry-3.0\AceConfigRegistry-3.0.lua`
- `Ace3\AceConsole-3.0\AceConsole-3.0.lua`
- `Ace3\AceDB-3.0\AceDB-3.0.lua`
- `Ace3\AceDBOptions-3.0\AceDBOptions-3.0.lua`
- `Ace3\AceEvent-3.0\AceEvent-3.0.lua`
- `Ace3\AceGUI-3.0\AceGUI-3.0.lua`
- `Ace3\AceGUI-3.0\widgets\*.lua`
- `Ace3\AceHook-3.0\AceHook-3.0.lua`
- `Ace3\AceLocale-3.0\AceLocale-3.0.lua`
- `Ace3\AceSerializer-3.0\AceSerializer-3.0.lua`
- `Ace3\AceTab-3.0\AceTab-3.0.lua`
- `Ace3\AceTimer-3.0\AceTimer-3.0.lua`
- `Ace3\!LibUIDropDownMenu\LibUIDropDownMenu\*.lua`
