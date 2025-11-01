## Restocker 2024.5.1

- [Cataclysm] Minor version update. Functionality looks like it is not broken.
- Note to rogues: Sell your pre-cata poisons and buy new, then re-add  
Restocker rules again. Poisons have changed.

## Restocker 2023.12.0

- Console command `/rs profile use xxx` will switch the active profile to `xxx`.

## Restocker 2023.11.0

- Updated the copy of KvLib for classic compatibility. Was using Windows directory Junctions before and that didn't go well.

## Restocker 2023.1.3

- First version compatible with Dragonflight (mainline WoW).
- Sometimes an error appears "Couldn't split those stacks" when taking from bank - Temporary workaround: manually move more 
items than you require from the bank, and reopen the bank it will balance the counts.

## Restocker 2023.1.2

- `C_Container` API change in the new patch for `GetContainer[NumSlots/ItemInfo]`
- Grand rework of the restacking logic, picking best fit for stackable goods

## Restocker 2023.1.0

- Restored the manage profiles functionality: create profile, delete profile 
now have their own settings tab.
- A button to open settings from /rs main window.

## Restocker 2022.12.3

- Bank operations code rewritten

## Restocker 2022.12.1, 12.2

- Can individually set behaviour per item: each item can be restocked from vendor, 
  taken from bank, or extras stashed to bank. Set restock amount to zero to always stash
  all to bank.
- Options window reworked with AceConfig
- `[Bug]` bag 11 (last bank bag) was not showing in WotLK despite being available

## Restocker 2022.7.1

- WotLK compatibility check
- `[WotLK]` Rogue poisons in WotLK are not craftable but buyable
- Merging addon versions for Classic, TBC and WotLK into one. Attempting to 
  import old settings too. This creates a dummy "RestockerTBC" addon which can be 
  deleted or ignored.

## Restocker TBC 2022.2.3, .4, .5, .6

- Improved bank to bag movements, less erratic stacks creation, do not leave temporary stacks
- Classic/SoM rogue restocking fixed
- Migrated addon startup and events to AceAddon/AceEvents
- `[Bug]` UI error when trying to Shift+click links in chat due to main frame being not initialized
- `[Bug]` Configuration error on first install, must initialize to empty dictionary
- `[Packaging Bug]` Ace3 embeds.xml was missing rows for CallbackHandler, 
  AceGUI

## Restocker TBC 2022.2.1

- `[Bug]` Accidentally introduced dependency on Questie, now fixed.

## Restocker TBC 2022.1.1

- Rogue poisons ingredients for classic were wrong from the Wowhead guide. Now updated to the
  correct ingredients.
- When stashing to bank, iterate bags in reverse orders, so that newest bagged items would be moved
  first, and not leave gaps in your bag.

## Restocker TBC 2022.1.0

- Restocking algorithm fixed. Now will always prefer to move smaller stacks before bigger stacks.
  This is still imperfect but should not leave small stacks behind, at least not many of those.

## Restocker TBC 2021.10.1

- Interval between bank clicks is now calculated based on ping to server (ping x3 but no faster than
  140 ms which is 7 times per second).

## Restocker TBC 2021.9.2

- A new editbox added to require vendor NPC reaction (neutral, friendly, honored or exalted) to
  restock each item. Empty value does not check the vendor reaction, number 4 requires neutral
  faction, 5 - friendly, 6 - honored, 7 - revered and 8 requires exalted standing with the vendor.

## Restocker TBC 2021.9.1

- UI version update for TBC Phase 2
- Fix: Bank restocking goes one item at a time, not multiple items in parallel
- Fix: Bank restocking will retry moving if a slot is locked (due to being moved at this time or
  other reasons), and will not attempt to move from other bag slots

## Restocker TBC 2021.8.2-3

- Fix: Bank restocking only does 1 pass and stops, allowing you to use bank normally.
- Fix: Bank restocking in and out will check the bag space before operations. Requires 1 free slot
  in both bank and character bag.
- Small fix to first move small stacks before splitting large
-

## Restocker TBC 2021.8.1

- Bank restocking bug fixed. Requires 1 free player bag slot to move into split bank stacks.
  Requires 1 free bank slot to move into split player bag stacks. Full stacks can be moved without
  splitting and no extra bag slot is required. For example: Moving 1 item into stack of 19 requires
  a free extra bag slot.

## Restocker TBC 2021.6.1

- Updated bank bag count for TBC, fixed restocking from bank bug

## Restocker TBC 2021.5.3

- Support for multiple languages, now rogue poisons and restocking in general will work in any
  language.

## Restocker TBC 2021.5.2

- TBC: Rogue poisons have became cheaper, reagent cost update

## Restocker TBC 2021.5.0-1

- Initial import of code and UI version bump.

## 6.2

- Now restocks items with random suffixes
- Now restocks items as soon as you press enter when changing restocking number on the main window
  while bank is open
- Reduced chat-spam when changing profiles at the bank.

## 6.1

- Added login message setting

## 6.0

- Fixed the "Restock from bank" checkbox resetting each time the addon loaded
- New experimental banking operation (should be way faster).

## 5.12

- Holding shift will now prevent the addon from doing its thing when opening bank/merchant
- Now buys the right amount of reagents based on if you have any in your bags or not

## 5.11

- Fixed addon continuing to grab stuff from bags / bank when there are no empty slots, will now stop
  when error comes up saying bags or bank is full.

## 5.10

- Fixed a bug when switching profiles while merchant window was open causing the addon to sell all
  items set to 0.

## 5.9

- Now allows shiftclicking and dragging items into textfield.

## 5.8

- Housekeeping and hopefully some improvements where the addon wasn't buying everything the first
  time you talked to a vendor.
    - This could also be because of how the game handles getting item info and if the item isn't
      cached then you have to wait for the server to send the data.

## 5.7

- Updated event driven restocking from bank to a OnUpdate script.

## 5.6.4

- Updated the logic regarding poisons and minimum supply.
    - Now checks if you have poisons in the bank, if you don't it will buy the needed amount of
      reagents every time to get to the cap.
    - If you do have poisons in the bank then it will only buy poison reagents if you are below 50%
      of your set amount (up to the cap).
    - By far the easiest thing to do in regards to this is to just craft a lot of poisons and store
      them in your bank and making a habit of visiting the bank to restock on already crafted
      poisons.
    - The change was made to make it easier for rogues still leveling to use this to restock on
      poison supplies when they visit a vendor but perhaps only missing ~30% of them.

- Removed the delay between opening 2 merchant windows. This was put in place to prevent the addon
  from buying basically double the amount of reagents because you closed the window to fast and
  reopened it. Inadvertantly it made automatic restocking from multiple vendors take longer so it's
  now been removed.

- Added a "Restocker finished restocking from vendor." message to indicate that you can now close
  the merchant window.
- Added a "Restocker finished restocking from bank." message.

## 5.6.3

- Finally fixed restocking from bank without getting an error about "Couldn't split those items".

## 5.6.2

- Added small delay (2 sec) before autobuying again to prevent accidental over-stocking.

## 5.6.1

- Fixed lua error

## 5.6

- Just a quick polish

## 5.1.5

- More fixing the annoying "Couldn't split those items" error

## 5.1.4

- Fixed deletion bug

## 5.1.3

- Fixed annoying "Couldn't split item" error when restocking from bank.

## 5.1.2

- Bumped interface version to 1.13.3

## 5.1.1

- Fixed lua error when buying poison reagents

## 5.1

- Added interface options panel
    - /rs config or using the interface options and going to Restocker
- Added toggles for autoshowing frame when visiting bank/vendor
- Added profiles creating/deletion to options panel

## 5.0.2

- Higher frame strata, should now not clip with other windows
- Fixed addon saving position between reloads/logouts
- Fixed autoclose when bank window closes

## 5.0

- Implemented profiles
    - use "/rs profiles" for more information on how to add/delete/copy/rename profiles
    - switching profiles is done with the dropdown on the addon frame
    - addon frame now shows when talking to bank and merchant for easy switching of profiles

## 4.0.2

- Preimplementation of profiles

## 4.0.1

- Will now put excess stock into bank

## 4.0

- Rewrote the entire addon and did a lot of housekeeping
- Should now be more stable
- Now supports adding ANY item via itemID
    - Items added by name still need to be cached by your game.
- Will now traverse the bankframe in reverse order (from the back).
    - What this basically accomplishes is better order in the bankframe where items get grabbed from
      the back first.

## 3.5.2

- Attempt to fix initialization issues

## 3.5.1

- Attempt to fix various lua errors

## 3.5

- Added manual changelog and package handlers

## Old

- Attempt to fix various bugs


- Updated bank restocking, slightly slower but far more accurate and reliable
- No longer restocks poison reagents from bank
- Removed summary of what was restocked from bank (it bugged out super hard and were reporting
  numbers twice or three times higher than they should be)


- Added scroll frame
- Added summary of what items were restocked when restocking from bank (vendor already does this
  because you see what you bought)


- Fixed lua error when restocking from bank


- Fixed lua error


- Added support for restocking from bank.
    - Poisons are supported but could be super bugged (i dont personally restock from bank so hard
      for me to think of all different situations)


- Fixed issue that appeard when number was prefixed with a 0. Now automatically deletes a leading 0
  from numbers.


- Now supports Poisons and will auto restock the reagents.
- Added field for the minimum amount of missing poisons before the addon restocks on the reagents (
  to avoid restocking for 1 poison)


- Extended input box to accommodate for four digit numbers.


- Updated logics for faster restocking
- Now buys multiple stacks if amount is above a stacksize
- Updated login message with instructions on how to open the window
