# Bank Restocking Rewrite Plan

## Goal

Reintroduce reliable, opt-in bank balancing after the legacy bank engine has been removed. The rewrite will maintain each configured item's target quantity in player bags while leaving all vendor restocking behavior unchanged.

## Current baseline

The legacy implementation has been removed before starting the rewrite:

- Bank target calculation, task scheduling, coroutine pacing, stack scanning, splitting, placement, and best-fit helpers are no longer loaded.
- Bank events, automatic bank-window behavior, and per-item bank controls are hidden during the rewrite hiatus.
- `autoOpenAtBank`, `stashTobank`, and `restockFromBank` remain untouched in existing `RestockerSettings` data.
- Merchant purchase logic and the bank-aware crafting-reagent calculation remain behaviorally unchanged.

## Behavior and saved data

- Continue using the retained `stashTobank` and `restockFromBank` item flags:
  - Deposit quantities above the configured bag target only when `stashTobank` is enabled.
  - Withdraw quantities below the target only when `restockFromBank` is enabled and selected-bank stock exists.
  - A target of zero with deposits enabled stashes all copies from player bags.
  - Never move an item in a disabled direction.
- Add a versioned saved-variable migration and a `bankStorageByProfile` map with `"character"`, `"account"`, and `"both"` policies. Existing profiles default to `"character"`.
- Keep storage-policy lifecycle aligned with profile operations: add defaults it, rename moves it, copy copies it, and delete removes it.
- Exclude guild and reagent banks. Offer account-bank policies only on clients that support them. If a configured store is unavailable, fail closed with a clear status instead of substituting another store.
- For `"both"`, prioritize character-bank containers and then account-bank containers, and start only when every selected pool is accessible.

## Architecture

Build three isolated layers:

1. A flavor-aware container adapter that discovers accessible player bags, purchased character-bank containers, and accessible account-bank tabs without hardcoded offsets.
2. A pure planner that snapshots containers by item ID and calculates the remaining deposit or withdrawal delta for each configured item.
3. An event-driven executor that performs one transfer at a time, confirms the inventory change, then rescans and replans.

Use item IDs as identity. Skip invalid or unresolved records safely. Never use a cached snapshot to continue moving after the inventory has changed.

## Transfer selection and execution

- Select sources deterministically: an exact-sized stack first, then the largest whole stack not exceeding the remaining delta, then the smallest oversized stack that must be split.
- Prefer a compatible partial destination stack that can accept the transfer, then a compatible empty slot.
- Do not require a blanket free slot in both bag and bank; base feasibility on the selected source and destination.
- Skip a blocked transfer and attempt other feasible transfers before reporting capacity exhaustion.
- Use explicit pickup/split and destination operations so selected storage policy is respected.
- Never disturb a cursor item that the addon does not own. Track cursor ownership and clean up only addon-owned cursor state.
- Drive progress from bank-interaction, bag-update, bank-slot, and item-lock events instead of an `OnUpdate` coroutine or ping-derived delay.
- After each operation, verify the expected source/destination change. Retry an unconfirmed operation at most three times with a three-second confirmation timeout, then stop that item with a clear status.
- Abort safely on bank close or profile change. User inventory changes cause a rescan and replan.

## UI

- Restore the per-item “To bank” and “From bank” controls and the bank auto-open preference.
- Add a per-profile storage dropdown. Show account-bank choices only when the client supports them.
- Show concise completion, unavailable-storage, capacity, and retry-failure status without repeated chat spam.

## Tests and acceptance criteria

- Pure planner tests: exact target, shortage, excess, zero target, independent direction flags, insufficient stock, invalid item IDs, and every storage policy.
- Container tests: full-stack moves, splits, partial-stack merges, incompatible bags, locked slots, full containers, purchased-bank-bag discovery, and account-bank restrictions.
- Executor tests: delayed updates, unrelated user moves, occupied cursor, failed confirmation, retry exhaustion, profile changes, and bank closure.
- Migration tests: existing bank flags remain unchanged; every existing profile receives the character-bank default; profile add/rename/copy/delete keeps the policy map consistent.
- Manual smoke tests on every supported TOC flavor, with account-bank coverage on Mainline.
- Vendor regression tests must confirm deficits, reputation gates, limited stock, purchase stack sizing, and crafting-reagent calculations remain unchanged.
