-- Headless test for the bank restock planner (no WoW API needed).
--
-- Run it with:   lua Tests/RestockPlannerTest.lua
--
-- It models the SAME algorithm the live addon uses (Src/Bank.lua + Src/Bag.lua):
--   * re-scan the CURRENT bag/bank contents every step and re-derive the outstanding work
--     (RunRestockLogic -> stateClass:Rescan / RemainingWork)
--   * issue at most one move per step, then re-scan
--   * whole-stack moves auto-merge into existing partial stacks, overflow to a free slot
--   * a partial need is split off and best-fit merged; an "uncached" item skips the merge
--   * NOTHING is deducted from a running tally -- a move that gets rejected or can't be
--     placed simply leaves the item still short next scan, and is retried
--   * a WATCHDOG stops the run if MAX_STUCK_STEPS pass with no reduction in outstanding
--     work (a rejected split, or no room), reporting what's left -- instead of looping
--     forever (the old recompute-every-step spam) or claiming success while short (the old
--     optimistic-deduct bug)
--   * if an exact bank->bag split keeps being bounced ("Couldn't split those items"), fall
--     back to pulling the WHOLE stack -- overshoot the target, then stash the excess back.
--     Whole-stack moves always land, so the target is reached instead of stopping short
--
-- The rejection/watchdog scenarios below are the ones the shipped code previously got
-- wrong: an occasional failed move was counted as done, leaving "37 of 40" and a cheerful
-- "Finished restocking".

local STACK = 20
local WATCHDOG_LIMIT = 5 -- mirrors MAX_STUCK_STEPS in Src/Bank.lua

-- A container is { stacks = {counts...}, free = <free slot count> }
local function total(c)
  local t = 0
  for _, n in ipairs(c.stacks) do t = t + n end
  return t
end

local function compact(c)
  local r = {}
  for _, n in ipairs(c.stacks) do if n > 0 then r[#r + 1] = n end end
  c.stacks = r
end

local function smallestIndex(c)
  local bi, bv = nil, math.huge
  for i, n in ipairs(c.stacks) do
    if n > 0 and n < bv then bi, bv = i, n end
  end
  return bi
end

-- Add `count` to a container, merging into existing partial stacks first (fullest first),
-- then into new slots while free slots remain. `merge` false (uncached item) skips the
-- partial-stack merge. Returns how many actually landed -- the caller removes ONLY that
-- much from the source, so an item that can't be placed stays put (mirrors the live code
-- returning a split item to its slot rather than losing it).
local function addToContainer(c, count, merge)
  local landed = 0
  if merge then
    table.sort(c.stacks, function(a, b) return a > b end)
    for i = 1, #c.stacks do
      if count <= 0 then break end
      local room = STACK - c.stacks[i]
      if room > 0 then
        local add = math.min(room, count)
        c.stacks[i] = c.stacks[i] + add
        count, landed = count - add, landed + add
      end
    end
  end
  while count > 0 and c.free > 0 do
    local add = math.min(STACK, count)
    c.stacks[#c.stacks + 1] = add
    c.free = c.free - 1
    count, landed = count - add, landed + add
  end
  return landed
end

-- Outstanding work we can actually act on: shortfalls the bank can supply + excess to stash.
local function remainingWork(bag, bank, target, opts)
  local haveBag, haveBank = total(bag), total(bank)
  local work = 0
  if opts.fromBank and haveBag < target and haveBank > 0 then
    work = work + math.min(target - haveBag, haveBank)
  end
  if opts.stash and haveBag > target then
    work = work + (haveBag - target)
  end
  return work
end

-- Why the watchdog gave up, matching stateClass:StuckMessage (bag/bank full preferred,
-- else a plain "stuck" -- a move that keeps being rejected though there's room).
local function stuckStatus(bag, bank)
  local bagFree, bankFree = bag.free > 0, bank.free > 0
  if not bagFree and not bankFree then return "both full" end
  if not bagFree then return "bag full" end
  if not bankFree then return "bank full" end
  return "stuck"
end

-- Run a restock to `target`, returning the final bag/bank and a status string.
-- opts: { fromBank=bool, stash=bool, uncached=bool, failFirst=N, failAll=bool,
--         failBankSplits=bool }
--   failFirst=N        -> the first N move attempts are rejected (transient race), then succeed
--   failAll=true       -> every move attempt is rejected (permanently stuck)
--   failBankSplits=true -> every EXACT bank->bag split bounces (the flaky server op), but
--                          whole-stack moves land -- the case the overshoot fallback covers
local function runRestock(label, bag, bank, target, opts)
  compact(bag); compact(bank)
  local steps = 0
  local lastRemaining = math.huge
  local stuck = 0
  local failsLeft = opts.failAll and math.huge or (opts.failFirst or 0)

  while true do
    steps = steps + 1
    assert(steps < 2000, label .. ": did not terminate")

    local remaining = remainingWork(bag, bank, target, opts)
    if remaining == 0 then
      table.sort(bag.stacks, function(a, b) return a > b end)
      return bag, bank, "done", steps
    end

    -- Watchdog: locks are settled by the time we re-scan (BankUpdateFn gates on that), so
    -- no reduction means the last move did not land. Retry a few times, then give up.
    if remaining < lastRemaining then
      stuck = 0
    else
      stuck = stuck + 1
      if stuck >= WATCHDOG_LIMIT then
        table.sort(bag.stacks, function(a, b) return a > b end)
        return bag, bank, stuckStatus(bag, bank), steps
      end
    end
    lastRemaining = remaining

    -- Issue one move, computed fresh from current contents.
    local rejected = false
    if failsLeft > 0 then
      failsLeft = failsLeft - 1
      rejected = true -- the server rejected it / nothing could be placed: no change
    end

    if not rejected then
      local haveBag, haveBank = total(bag), total(bank)
      if opts.stash and haveBag > target then
        local si = smallestIndex(bag)
        local moveAmt = math.min(bag.stacks[si], haveBag - target)
        local landed = addToContainer(bank, moveAmt, not opts.uncached)
        bag.stacks[si] = bag.stacks[si] - landed
      elseif opts.fromBank and haveBag < target and haveBank > 0 then
        local want = math.min(target - haveBag, haveBank)
        local si = smallestIndex(bank)
        local moveAmt = math.min(bank.stacks[si], want)
        local isSplit = moveAmt < bank.stacks[si]
        -- Mirrors MoveFromBankToPlayer_1's overshoot fallback: a no-progress step means the
        -- exact split is being bounced, so pull the whole stack instead -- that always lands.
        if isSplit and stuck > 0 then
          moveAmt = bank.stacks[si]
          isSplit = false
        end
        if not (isSplit and opts.failBankSplits) then
          local landed = addToContainer(bag, moveAmt, not opts.uncached)
          bank.stacks[si] = bank.stacks[si] - landed
        end
      end
    end

    compact(bag); compact(bank)
  end
end

local function fmt(c)
  return "{" .. table.concat(c.stacks, ",") .. "} free=" .. c.free
end

local pass = 0
local function scenario(label, bag, bank, target, opts, check)
  local b, k, status, steps = runRestock(label, bag, bank, target, opts)
  print(("%-26s -> bag %-18s bank %-14s [%s, %d steps]"):format(
      label, fmt(b), fmt(k), status, steps))
  check(b, k, status)
  pass = pass + 1
end

-- 1. Split needed: bank has one big stack, pull a partial to hit an odd target
scenario("split needed", { stacks = { 5 }, free = 10 }, { stacks = { 20 }, free = 10 }, 17,
    { fromBank = true }, function(bag)
      assert(total(bag) == 17, "want 17")
    end)

-- 2. Multi-stack consolidation: messy bank stacks merge into fewest bag stacks
scenario("multi-stack consolidate", { stacks = { 17 }, free = 10 }, { stacks = { 5, 5, 5, 8 }, free = 10 }, 40,
    { fromBank = true }, function(bag)
      assert(total(bag) == 40, "want 40")
      assert(#bag.stacks == 2, "want 2 stacks, got " .. #bag.stacks)
    end)

-- 3. Bank full: stashing excess but the bank has no room -> stops, reports bank full
scenario("bank full", { stacks = { 20, 20, 20 }, free = 5 }, { stacks = { 20, 20 }, free = 0 }, 40,
    { stash = true }, function(_, _, status)
      assert(status == "bank full", "want bank full, got " .. status)
    end)

-- 4. Bag full: pulling from bank but bags are packed -> stops, reports bag full
scenario("bag full", { stacks = { 20, 20 }, free = 0 }, { stacks = { 20 }, free = 5 }, 60,
    { fromBank = true }, function(_, _, status)
      assert(status == "bag full", "want bag full, got " .. status)
    end)

-- 5. Uncached item: still reaches target, just without best-fit merging
scenario("uncached item", { stacks = {}, free = 10 }, { stacks = { 20, 20 }, free = 10 }, 40,
    { fromBank = true, uncached = true }, function(bag)
      assert(total(bag) == 40, "want 40 even when uncached")
    end)

-- 6. Already correct: no work, terminates immediately
scenario("already correct", { stacks = { 20, 20 }, free = 5 }, { stacks = { 10 }, free = 5 }, 40,
    { fromBank = true, stash = true }, function(bag, _, _)
      assert(total(bag) == 40, "stay at 40")
    end)

-- 7. Transient rejection: the first 2 split attempts are refused ("Couldn't split those
--    items"), then they go through. The old optimistic-deduct code counted the refused
--    moves as done and finished short; the watchdog-driven retry reaches the target.
scenario("transient rejection", { stacks = {}, free = 10 }, { stacks = { 20, 20 }, free = 10 }, 40,
    { fromBank = true, failFirst = 2 }, function(bag, _, status)
      assert(status == "done", "want done, got " .. status)
      assert(total(bag) == 40, "want 40 after recovering from rejects, got " .. total(bag))
    end)

-- 8. Permanent rejection: every move is refused though there's plenty of room. Must NOT
--    loop forever and must NOT report success -- it gives up as "stuck", still short.
scenario("permanent rejection", { stacks = {}, free = 10 }, { stacks = { 20, 20 }, free = 10 }, 40,
    { fromBank = true, failAll = true }, function(bag, _, status)
      assert(status == "stuck", "want stuck, got " .. status)
      assert(total(bag) == 0, "should have moved nothing, got " .. total(bag))
    end)

-- 9. Partial bank: the bank simply doesn't have enough. Pull all it has and finish
--    honestly at 26/40 -- this is a clean "done", not a stuck/error.
scenario("partial bank supply", { stacks = {}, free = 10 }, { stacks = { 20, 6 }, free = 10 }, 40,
    { fromBank = true }, function(bag, _, status)
      assert(status == "done", "want done, got " .. status)
      assert(total(bag) == 26, "want all 26 the bank had, got " .. total(bag))
    end)

-- 10. Flaky last-unit split, no stash-back: the exact split of the final 2 bounces every
--     time (the "8 need 10" log). The fallback pulls the whole stack and finishes OVER
--     target -- a little over beats stopping short with "couldn't move".
scenario("flaky split overshoots", { stacks = { 5, 2, 1 }, free = 10 }, { stacks = { 18 }, free = 10 }, 10,
    { fromBank = true, failBankSplits = true }, function(bag, _, status)
      assert(status == "done", "want done, got " .. status)
      assert(total(bag) >= 10, "must reach target, got " .. total(bag))
    end)

-- 11. Flaky split WITH stash-back: overshoot pulls the whole stack, then the stash pass
--     returns the excess, landing exactly on target. (Bag->bank splits still work here --
--     it's the bank->bag split that's the flaky op.)
scenario("flaky split + stash back", { stacks = { 5, 2, 1 }, free = 10 }, { stacks = { 18 }, free = 10 }, 10,
    { fromBank = true, stash = true, failBankSplits = true }, function(bag, _, status)
      assert(status == "done", "want done, got " .. status)
      assert(total(bag) == 10, "want exactly 10 after stash-back, got " .. total(bag))
    end)

-- ---------------------------------------------------------------------------------------
-- Consolidation (tidy phase) -- mirrors bankModule.ConsolidateOne: repeatedly take the
-- SMALLEST stack and pour it entirely into another stack that has room for ALL of it (a
-- "full absorb", no splitting). Each merge removes one stack; stop when no pair fully fits.
local function consolidate(stacks, maxStack)
  local steps = 0
  while true do
    steps = steps + 1
    assert(steps < 1000, "consolidate did not terminate")
    table.sort(stacks, function(a, b) return a < b end) -- smallest first
    local merged = false
    local source = stacks[1]
    for i = 2, #stacks do
      if source + stacks[i] <= maxStack then
        stacks[i] = stacks[i] + source
        table.remove(stacks, 1)
        merged = true
        break
      end
    end
    if not merged then break end
  end
  table.sort(stacks, function(a, b) return a > b end)
  return stacks
end

local function consolidateScenario(label, stacks, maxStack, wantStacks)
  local got = consolidate(stacks, maxStack)
  print(("consolidate %-16s -> {%s} (max %d)"):format(label, table.concat(got, ","), maxStack))
  assert(#got == #wantStacks, label .. ": want " .. #wantStacks .. " stacks, got " .. #got)
  for i = 1, #wantStacks do
    assert(got[i] == wantStacks[i], label .. ": stack " .. i .. " want " .. wantStacks[i] .. " got " .. got[i])
  end
  pass = pass + 1
end

print("")
-- The reported case: 10 + 9 + 1 should collapse to a single full stack.
consolidateScenario("10+9+1", { 10, 9, 1 }, 20, { 20 })
-- Many small stacks fully combine.
consolidateScenario("5+5+5+5", { 5, 5, 5, 5 }, 20, { 20 })
-- Already tidy: nothing to do.
consolidateScenario("single full", { 20 }, 20, { 20 })
-- Can't fully absorb either into the other without splitting -> left alone (already fewest
-- stacks a non-splitting merge can reach).
consolidateScenario("11+11", { 11, 11 }, 20, { 11, 11 })
consolidateScenario("11+11+11", { 11, 11, 11 }, 20, { 11, 11, 11 })

print(("\nALL %d RESTOCK PLANNER SCENARIOS PASSED"):format(pass))
