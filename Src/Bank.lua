--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsBankModule
---@field bankIsOpen boolean
---@field currentlyRestocking boolean
---@field updateTimer number
---@field state BankRestockState
local bankModule = RsModule.bankModule
bankModule.bankIsOpen = false
bankModule.updateTimer = 0

local restockerModule = RsModule.restockerModule ---@type RsRestockerModule
local bagModule = RsModule.bagModule ---@type RsBagModule
local merchantModule = RsModule.merchantModule ---@type RsMerchantModule

-- After this many consecutive steps that fail to reduce the outstanding work (a move that
-- keeps being rejected, or an item stuck locked), stop and report what's still short --
-- instead of retrying forever. Retrying a handful of times first rides out transient
-- "Couldn't split those items" races without ever bothering the user.
local MAX_STUCK_STEPS = 5

---@class BankRestockState
---@field playerInventory RsInventory Character bag contents, re-scanned every step
---@field bankInventory RsInventory Bank contents, re-scanned every step
---@field currentProfile RsTradeCommand[]
---@field lastRemainingWork number Outstanding move total at the previous step (watchdog)
---@field stuckSteps number Consecutive steps that made no progress (watchdog)
---@field consolidating boolean True once move work is done and we're just tidying stacks
---@field lastStackCount number Maintained-item stack count at the previous tidy step
---@field tidySteps number Consecutive tidy steps that merged nothing (tidy watchdog)
local stateClass = {}
stateClass.__index = stateClass

function bankModule:NewState()
  local state = --[[---@type BankRestockState]] {}
  state.lastRemainingWork = math.huge
  state.stuckSteps = 0
  state.consolidating = false
  state.lastStackCount = math.huge
  state.tidySteps = 0

  setmetatable(state, stateClass)

  state:Rescan()

  return state
end

---Refresh the profile and re-scan bags + bank. Called at the START OF EVERY restock step,
---so the plan is always derived from what is actually in the containers right now. This is
---the core of the fix: a move the server rejected or only partially placed shows up as
---"still short" on the next step and gets retried, instead of being assumed done. (The old
---code snapshotted once and deducted from a plan optimistically, which silently left an
---item short whenever a move didn't fully land. Recomputing here is safe now because the
---watchdog in RunRestockLogic stops us if we stop making progress -- the missing piece that
---previously turned recompute-every-step into endless "Couldn't split" spam.)
function stateClass:Rescan()
  -- Don't snapshot while an item is stranded on the cursor -- it would be uncounted and we
  -- would think we're short and move things that are already fine.
  if CursorHasItem() then
    ClearCursor()
  end

  local settings = restockerModule.settings
  self.currentProfile = --[[---@not nil]] settings.profiles[settings.currentProfile]

  self:UpdateInventory()
end

---@return number Total number of items still to move that we can actually act on: shortfalls
---the bank can supply, plus excesses to stash. Zero means done -- either everything is at
---target, or the only gaps left are items the bank has none of (nothing more we can do).
function stateClass:RemainingWork()
  local work = 0
  for itemID, eachItem in pairs(self.currentProfile) do
    local haveInBag = self.playerInventory.summary[itemID] or 0
    local haveInBank = self.bankInventory.summary[itemID] or 0

    if eachItem.restockFromBank and eachItem.amount > haveInBag and haveInBank > 0 then
      work = work + math.min(eachItem.amount - haveInBag, haveInBank)
    end
    if eachItem.stashTobank and haveInBag > eachItem.amount then
      work = work + (haveInBag - eachItem.amount)
    end
  end
  return work
end

---@return number Total number of slots the maintained items occupy in the PLAYER bags. Used
---as the tidy-phase progress signal: each successful merge collapses two stacks into one, so
---this strictly decreases while consolidation is making headway and plateaus when done (or if
---a merge bounces), which the tidy watchdog uses to stop.
function stateClass:CountMaintainedStacks()
  local n = 0
  for _itemID, slots in pairs(self.playerInventory.slots) do
    n = n + #slots
  end
  return n
end

---A user-facing message for why we stopped when work still remains. Prefers the specific
---"bag/bank is full" cause; otherwise lists exactly what we couldn't move.
---@return string
function stateClass:StuckMessage()
  local bagCheck = bagModule:CheckBankBagSpace()
  if bagCheck == "both" then
    return "Restocker: stopped -- both bag and bank are full."
  elseif bagCheck == "bank" then
    return "Restocker: stopped -- bank is full, free a slot and reopen."
  elseif bagCheck == "bag" then
    return "Restocker: stopped -- bag is full, free a slot and reopen."
  end

  local parts = --[[---@type string[] ]] {}
  for itemID, eachItem in pairs(self.currentProfile) do
    local haveInBag = self.playerInventory.summary[itemID] or 0
    local haveInBank = self.bankInventory.summary[itemID] or 0

    if eachItem.restockFromBank and eachItem.amount > haveInBag and haveInBank > 0 then
      parts[#parts + 1] = string.format("%dx %s",
          math.min(eachItem.amount - haveInBag, haveInBank), eachItem.itemName)
    elseif eachItem.stashTobank and haveInBag > eachItem.amount then
      parts[#parts + 1] = string.format("%dx %s (extra)",
          haveInBag - eachItem.amount, eachItem.itemName)
    end
  end

  if #parts == 0 then
    return "Restocker: stopped, no progress could be made."
  end
  return "Restocker: stopped, couldn't move: " .. table.concat(parts, ", ")
end

---Called once on Addon creation. Sets up constants for bank bags
function bankModule.OnModuleInit()
end

---Issue one stash move: find the first over-stocked item and send some to the bank. The
---excess is computed fresh from this step's scan, not from a running tally.
---@return boolean True if a move was issued this step
function bankModule.StashToBank()
  local state = bankModule.state

  for itemID, eachItem in pairs(state.currentProfile) do
    if eachItem.stashTobank then
      local haveInBag = state.playerInventory.summary[itemID] or 0
      local excess = haveInBag - eachItem.amount
      if excess > 0 then
        RS:Debug("Too many %s in bag (%d need %d)", eachItem.itemName, haveInBag, eachItem.amount)
        if bagModule:MoveFromPlayerToBank(state.bankInventory, itemID, excess) then
          return true -- issued one move; caller yields and re-scans next step
        end
      end
    end
  end

  return false
end

---Issue one restock move: find the first under-stocked item the bank can supply and pull
---some in. The shortfall is computed fresh from this step's scan.
---@return boolean True if a move was issued this step
function bankModule.RestockFromBank()
  local state = bankModule.state

  for itemID, eachItem in pairs(state.currentProfile) do
    if eachItem.restockFromBank then
      local haveInBag = state.playerInventory.summary[itemID] or 0
      local haveInBank = state.bankInventory.summary[itemID] or 0
      local short = eachItem.amount - haveInBag
      if short > 0 and haveInBank > 0 then
        RS:Debug("Too few %s in bag (%d need %d)", eachItem.itemName, haveInBag, eachItem.amount)
        -- stuckSteps > 0 means the previous step's move never landed -- in practice the
        -- flaky exact split. Switch to whole-stack overshoot, which always lands; the
        -- watchdog would otherwise burn its retries on the same bounced split and give up
        -- short (the "couldn't move: 2x ..." stop).
        local overshoot = state.stuckSteps > 0
        if bagModule:MoveFromBankToPlayer(state.playerInventory, itemID, math.min(short, haveInBank), overshoot) then
          return true -- issued one move; caller yields and re-scans next step
        end
      end
    end
  end

  return false
end

---Merge one pair of partial stacks of a maintained item in the PLAYER bags, to undo the
---fragmentation that free-slot-first placement leaves behind (e.g. 10 + 9 + 1 -> 20). Only
---does "full-absorb" merges: it picks up a whole stack and drops it onto another that has
---room for ALL of it, so no split is involved -- splitting-then-merging is the operation
---that gets bounced by the server, and a whole-stack pickup-then-drop is the reliable manual
---consolidation move. Pairs that can't fully absorb (e.g. 11 + 11) are left alone; they're
---already at the fewest stacks a non-splitting merge can reach.
---@return boolean True if a merge was issued this step
function bankModule.ConsolidateOne()
  local state = bankModule.state

  for itemID, slots in pairs(state.playerInventory.slots) do
    if #slots >= 2 then
      local info = RS.GetItemInfo(itemID)
      local maxStack = info and info.itemStackCount
      if maxStack and maxStack > 1 then
        -- slots are sorted smallest-first (SortSlots). Emptying the smallest into another
        -- stack removes a slot with the least risk of overflow.
        local source = slots[1]
        for i = 2, #slots do
          local dest = slots[i]
          if source.count + dest.count <= maxStack then
            RS:Debug("Consolidate %s: %d from %s:%s -> %s:%s",
                (info and info.itemName) or itemID, source.count,
                source.bag, source.slot, dest.bag, dest.slot)
            C_Container.PickupContainerItem(source.bag, source.slot) -- pick up whole stack
            C_Container.PickupContainerItem(dest.bag, dest.slot)     -- drop onto it -> merges
            return true
          end
        end
      end
    end
  end

  return false
end

function stateClass:UpdateInventory()
  local settings = restockerModule.settings
  local currentProfile = --[[---@not nil]] settings.profiles[settings.currentProfile]

  -- Is this bag/bank item one we maintain? Profiles are keyed by itemID, so this is an
  -- O(1) lookup instead of scanning the whole profile by name for every bag slot.
  local itemExistsFn = ---@param itemID number
  function(itemID)
    return currentProfile[itemID] ~= nil
  end

  self.playerInventory = bagModule:GetItemsInBags(itemExistsFn)
  self.bankInventory = bagModule:GetItemsInBank(itemExistsFn)
end

---Stop restocking and stop the periodic timer.
---@param message string|nil Optional message to print
local function finishRestocking(message)
  bankModule.currentlyRestocking = false
  RS.onUpdateFrame:Hide() -- stop the periodic OnUpdate timer
  if message then
    RS:Print(message)
  end
end

---Run a single restock step: re-scan reality, then issue at most one move. The coroutine
---calls this once per eligible tick (only after the previous move has settled -- see the
---lock gate in BankUpdateFn) and yields between calls.
---@return boolean True if finished (done, or given up)
function bankModule:RunRestockLogic()
  local state = bankModule.state

  if not bankModule.bankIsOpen then
    finishRestocking("Bank is not open")
    return true
  end

  -- HARD SAFETY INVARIANT: never sell at a merchant. The moves below use
  -- C_Container.UseContainerItem to shift whole stacks, and that call SELLS the item when a
  -- merchant window is open (it only moves to the bank when a BANK is open). A bank and a
  -- merchant can't normally both be open, but if the merchant flag is set -- a stale flag, or
  -- an odd BANKFRAME/MERCHANT event order -- issuing a stash here would vendor the player's
  -- "too many" excess. Refuse to act: bail cleanly, and the next real bank visit restarts.
  if merchantModule.merchantIsOpen then
    RS:Debug("Merchant open -- aborting bank restock so UseContainerItem can never sell")
    finishRestocking(nil)
    return true
  end

  -- Reconcile against reality every step: re-derive the outstanding work from what's
  -- actually in the bags/bank right now. A move that was rejected or only partially placed
  -- simply reappears as remaining work and gets retried; a move that worked shrinks the
  -- work for real.
  state:Rescan()

  local remaining = state:RemainingWork()

  if remaining > 0 then
    state.consolidating = false -- still moving; tidy phase (below) hasn't started

    -- Watchdog. We only get here with locks already settled (BankUpdateFn gates on that), so
    -- if the outstanding work did NOT shrink since last step, the last move genuinely didn't
    -- land -- a rejected split, or something we can't place. Retry a few times to absorb
    -- transient races, then give up with a clear message. This is the piece both previous
    -- designs lacked: it neither spams forever (recompute-every-step) nor reports success
    -- while short (optimistic-deduct).
    if remaining < state.lastRemainingWork then
      state.stuckSteps = 0
    else
      state.stuckSteps = state.stuckSteps + 1
      if state.stuckSteps >= MAX_STUCK_STEPS then
        finishRestocking(state:StuckMessage())
        return true
      end
    end
    state.lastRemainingWork = remaining

    -- ONE move per tick: stash an over-stocked item, otherwise pull an under-stocked one.
    -- Doing only one keeps a stash and a restock from firing in the same tick and fighting
    -- over the cursor. ALWAYS keep going (return false) even if nothing was issued -- a slot
    -- may still be locked from the previous move; the watchdog above is what stops us if
    -- we're genuinely stuck. Stashing runs first so it can free a bag slot for restocking.
    if bankModule.StashToBank() then
      return false
    end
    if bankModule.RestockFromBank() then
      return false
    end
    return false
  end

  -- All items are at target. TIDY PHASE (best-effort): merge the partial stacks that
  -- free-slot-first placement leaves behind. This can never leave an item short (totals are
  -- already correct) -- the worst case is that a merge doesn't take and we simply stop.
  if not state.consolidating then
    state.consolidating = true -- entering tidy phase; start its watchdog fresh
    state.lastStackCount = math.huge
    state.tidySteps = 0
  end

  -- Tidy watchdog: each successful merge collapses two stacks into one, so the maintained
  -- stack count strictly drops while we're making progress. If it stops dropping (fully
  -- consolidated, or a merge got bounced), finish cleanly -- restocking already succeeded,
  -- so this is a normal "Finished", not a problem to report.
  local stacks = state:CountMaintainedStacks()
  if stacks < state.lastStackCount then
    state.tidySteps = 0
  else
    state.tidySteps = state.tidySteps + 1
    if state.tidySteps >= MAX_STUCK_STEPS then
      finishRestocking("Finished restocking. Hold Shift to skip next time.")
      return true
    end
  end
  state.lastStackCount = stacks

  if bankModule.ConsolidateOne() then
    return false -- merged a pair; re-scan next tick and keep tidying
  end

  -- Nothing left to merge: genuinely done.
  finishRestocking("Finished restocking. Hold Shift to skip next time.")
  return true
end

local function restockCoro()
  --bankModule.state = bankModule:NewState()
  while bankModule:RunRestockLogic() == false and bankModule.bankIsOpen do
    coroutine.yield()
  end
end

local theCoroutineObject = coroutine.create(restockCoro)

function bankModule:MaintainAndResumeCoro()
  if theCoroutineObject == nil or coroutine.status(theCoroutineObject) == "dead" then
    RS:Debug("Maintain: create coro")
    theCoroutineObject = coroutine.create(restockCoro)
  end

  if coroutine.status(theCoroutineObject) == "running" then
    RS:Debug("Maintain: coro running")
    return
  end

  local ok, err = coroutine.resume(theCoroutineObject)

  if not ok then
    -- Surface the error to the user instead of letting it vanish, then stop so we don't
    -- respawn the coroutine and re-trigger the same error every tick. Reopening the bank
    -- (RestartRestocking) creates a fresh coroutine and retries.
    RS:Print("Restocking stopped due to an error: " .. tostring(err))
    finishRestocking(nil)
    theCoroutineObject = nil
  end
end

function bankModule.BankUpdateFn(self, elapsed)
  if bankModule.bankIsOpen == false then
    RS.onUpdateFrame:Hide() -- stop the periodic timer in the update frame
    return -- nope
  end

  bankModule.updateTimer = bankModule.updateTimer + elapsed

  -- One move is issued per tick. Pace ticks to the connection so a move has time to be
  -- confirmed by the server before the next one: wait ~3x the round-trip, but never
  -- faster than 0.140s.
  local _down, _up, pingHome, pingWorld = GetNetStats()
  local maxPing = math.max(pingHome, pingWorld)
  local updateInterval = math.max(0.140, (maxPing * 3) / 1000)

  if bankModule.updateTimer >= updateInterval then
    bankModule.updateTimer = 0

    if bankModule.currentlyRestocking then
      -- Wait until the previous move has FULLY settled (no slot still locked) before
      -- issuing the next one. Firing a split while the server is still consolidating the
      -- item from a move ~140ms ago is what gets rejected with "Couldn't split those
      -- items". The fixed tick interval alone isn't enough on a laggy connection. Only wait
      -- on OUR items -- an unrelated locked slot must not stall the restock forever.
      if bankModule.state and bagModule:IsSomethingLocked(bankModule.state.currentProfile) then
        return
      end
      bankModule:MaintainAndResumeCoro()
    end
  end
end

function bankModule:RestartRestocking()
  self.state = self:NewState()
  self.currentlyRestocking = true
  theCoroutineObject = coroutine.create(restockCoro) -- fresh run for this bank visit
  RS.onUpdateFrame:Show() -- start the periodic timer in the update frame
end

RS.onUpdateFrame = CreateFrame("Frame")
RS.onUpdateFrame:SetScript("OnUpdate", bankModule.BankUpdateFn)

--- (Re)start a restock for debugging. Only runs when a bank is actually open -- it never
--- fakes bankIsOpen (doing that drove real moves against a closed bank). It hands off to
--- the normal OnUpdate timer, which paces moves to the connection and waits for each to
--- settle before the next -- it does NOT step RunRestockLogic synchronously, because moves
--- are asynchronous (server round-trip) and back-to-back calls would trip the no-progress
--- watchdog on moves that simply haven't landed yet. For offline logic tests with no game
--- running, see Tests/RestockPlannerTest.lua (run: lua Tests/RestockPlannerTest.lua).
--- /console scriptErrors 1   then   /run RS_ADDON.Test()
function RS.Test()
  if not bankModule.bankIsOpen then
    RS:Print("RS.Test: open a bank first (this won't fake one). For offline logic tests run Tests/RestockPlannerTest.lua")
    return
  end
  RS:Print("RS.Test: restarting restock; watch the debug log as the timer steps it.")
  bankModule:RestartRestocking()
end
