# Restocker Agent Instructions

These instructions apply to the whole repository.

## Project Context

- This is **Restocker**, a Lua World of Warcraft addon.
- Lua target is **Lua 5.1** with WoW additions: `bit` is available, but there is no `goto`, no `bit32`, and no integer division operator `//`.
- The addon uses Ace3 libraries where possible for UI, addon state, options, events, timers, and minimap integration.
- Keep code compatible with the supported Classic-era addon clients already represented by the repository TOC files. Check the actual TOC files and `toc_template.toc` before changing interface numbers, load order, or saved variable declarations.
- The local Blizzard UI source checkout is at `F:\Projects\WowAddons\BlizzardInterfaceCode\`. Use it as the first reference for WoW UI/API behavior when available.

## Working Rules

- Read these instructions before editing.
- Prefer narrow, localized changes that match the existing Lua style and file organization.
- Use `.codex/map.md` as the repository code map: consult it first for code locations, then use `rg` and the TOC load order for confirmation.
  - Keep `.codex/map.md` updated whenever Lua files, named functions, UI hooks, slash commands, events, or load-order relationships are added, removed, renamed, or moved.
- For WoW API or Lua questions, verify against the local BlizzardInterfaceCode checkout or primary sources when the answer is uncertain or version-sensitive.
- Preserve unrelated dirty-tree changes.

## Lua Style

- Use file-scope `local addonName, ns = ...` where the file pattern supports it.
- Keep values local by default. Export through `ns` or existing module tables, not new globals, unless external addon access requires a global.
- Use 2-space indentation and no tabs in Lua.
- Use `function foo(a, b, c)`, with comma-space argument formatting and no padded parentheses.
- Add type annotations/specs where the surrounding code uses them and the type is knowable.
- Suggest or add documentation comments for functions and parameters when they clarify behavior.
- Comment the reason for non-obvious behavior, especially combat lockdown, taint avoidance, and client-version quirks. Do not restate simple code.

## WoW Client Compatibility

- Assume that many Retail APIs exist as Classic engine is constantly modernized by Blizzard, but check globals such as `_G["C_Spell"]`, `C_Timer`, and `GetSpellInfo` before using them.
- Detect client flavor with `WOW_PROJECT_ID` when behavior differs (this is also available via `Src\KvLib\KvEnv.lua` in form of `envModule` fields: `isClassic`, `isTBC`, `isWotLK`, `isCata` etc.):

  ```lua
  local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
  local isBCC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
  ```

- Spell IDs differ between clients. Do not hardcode an ID without verifying it for the target flavor. Prefer name lookup through `GetSpellInfo(spellID)` when appropriate.
- For multi-flavor changes, update the source of truth and generated files consistently. `Restocker.toc` says it is generated from `toc_template.toc`.

## Combat Lockdown And Taint

- Protected functions cannot be called while `InCombatLockdown()` is true.
- Do not do these in combat on protected frames: `frame:Show()`, `frame:Hide()`, `SetAttribute`, `RegisterUnitWatch`, action button reassignment, macro edits, or secure frame parent changes.
- Defer risky setup through `PLAYER_REGEN_ENABLED`:

  ```lua
  if InCombatLockdown() then
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(self)
      self:UnregisterEvent("PLAYER_REGEN_ENABLED")
      doSetup()
    end)
  else
    doSetup()
  end
  ```

- Avoid tainting Blizzard frames. Do not hook `UIParent`, action bars, or unit frames with non-secure code that may later run from a protected path. If a hook is necessary, use `hooksecurefunc`.

## Events And Performance

- Prefer one event frame per addon area and dispatch by event name where that fits the existing pattern.
- For combat log handling, use `COMBAT_LOG_EVENT_UNFILTERED` with `CombatLogGetCurrentEventInfo()`.
- For unit events, prefer `RegisterUnitEvent("UNIT_AURA", "player", "target")` over broad event registration when possible.
- Unregister events that are no longer needed.
- Avoid `OnUpdate` unless it is throttled with an accumulator.
- Avoid table allocation in hot paths. Reuse tables and `wipe(t)` rather than replacing tables in tight loops.
- Cache hot global lookups as locals at chunk top.
- Avoid frequent `..` concatenation and broad `pairs` scans in hot loops.

## Saved Variables

- Declare saved variables in the TOC files. This addon currently uses `## SavedVariablesPerCharacter: RestockerSettings`.
- Saved variable globals are populated only after `ADDON_LOADED` for this addon. Do not read them at file scope.
- Use versioned migrations where schema changes are needed. Do not silently overwrite user data.

## Frames And XML

- Name frames only when `_G["FrameName"]` access is required.
- Use templates such as `UIPanelButtonTemplate` and `BackdropTemplate` where appropriate. TBC-compatible backdrop code may require explicit `BackdropTemplate`.
- Use normal frame strata for UI. Do not use `TOOLTIP` for regular addon windows.

## Libraries

- Use LibStub for embedded libraries, for example `local AceGUI = LibStub("AceGUI-3.0")`.
- Prefer libraries known to support the target Classic clients: Ace3, LibSharedMedia-3.0, LibDataBroker-1.1, LibDBIcon-1.0, and CallbackHandler-1.0.
- Embed required libraries unless the TOC declares them as dependencies or optional dependencies.

## WeakAuras Notes

These rules apply only when editing WeakAuras snippets, not normal addon runtime files.

- Use `aura_env` for state, not globals.
- Keep trigger code pure. Put animations and sounds in actions.
- For Trigger State Updaters, mutate `allstates` and return `true` when states changed.
- Declare custom variables in the WeakAuras custom variables section so conditions and actions can read them.
- Subscribe to the minimum event set and filter `COMBAT_LOG_EVENT_UNFILTERED` early.
- Do not leave `print()` debug output in shipped auras.
