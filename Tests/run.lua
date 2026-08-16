local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function assertTrue(value, message)
  if not value then
    error(message or "expected true", 2)
  end
end

local function group(summary)
  return { summary = summary or {}, slots = {}, emptySlots = {}, containers = {} }
end

local function testPlanner()
  RsModule = { bankPlannerModule = {} }
  dofile("Src/BankPlanner.lua")
  local planner = RsModule.bankPlannerModule

  local snapshot = {
    player = group({ [100] = 10, [200] = 2, [300] = 7 }),
    character = group({ [200] = 2 }),
    account = group({ [200] = 4 }),
  }
  local profile = {
    { itemID = 100, itemName = "Deposit", amount = 5, stashTobank = true },
    { itemID = 200, itemName = "Withdraw", amount = 5, restockFromBank = true },
    { itemID = 300, itemName = "Disabled", amount = 1 },
    { itemID = 0, itemName = "Invalid", amount = 4, stashTobank = true },
  }

  local tasks = planner:BuildTasks(profile, snapshot, "both")
  assertEqual(#tasks, 2, "planner task count")
  assertEqual(tasks[1].direction, "deposit", "deposit direction")
  assertEqual(tasks[1].amount, 5, "deposit amount")
  assertEqual(tasks[2].direction, "withdraw", "withdraw direction")
  assertEqual(tasks[2].amount, 3, "combined-bank withdrawal amount")
  assertEqual(tasks[2].storageKinds[1], "character", "combined storage priority")
  assertEqual(tasks[2].storageKinds[2], "account", "combined account fallback")

  local accountTasks = planner:BuildTasks({ profile[2] }, snapshot, "account")
  assertEqual(accountTasks[1].amount, 3, "account-only withdrawal")

  local zeroTasks = planner:BuildTasks({
    { itemID = 300, itemName = "All", amount = 0, stashTobank = true },
  }, snapshot, "character")
  assertEqual(zeroTasks[1].amount, 7, "zero target deposits everything")

  local blocked = planner:BuildTasks(profile, snapshot, "both", { ["100:deposit"] = true })
  assertEqual(#blocked, 1, "blocked task filtering")
  assertEqual(blocked[1].itemID, 200, "unblocked task remains")
end

local function testMigration()
  local oldItem = { itemID = 100, stashTobank = true, restockFromBank = true }
  local settings = {
    profiles = { default = { oldItem }, raid = {} },
    currentProfile = "default",
    autoOpenAtBank = true,
  }
  RsModule = {
    settingsModule = {},
    restockerModule = { settings = settings },
  }
  dofile("Src/Settings.lua")
  local module = RsModule.settingsModule
  module:Migrate(settings)

  assertEqual(settings.schemaVersion, 1, "schema version")
  assertEqual(settings.bankStorageByProfile.default, "character", "default profile migration")
  assertEqual(settings.bankStorageByProfile.raid, "character", "second profile migration")
  assertTrue(oldItem.stashTobank and oldItem.restockFromBank, "bank flags preserved")
  assertTrue(settings.autoOpenAtBank, "bank auto-open preserved")

  assertTrue(module:AddProfile("new"), "profile add")
  assertEqual(settings.bankStorageByProfile.new, "character", "new profile storage")
  module:SetBankStorage("new", "account")
  assertEqual(module:GetBankStorage("new"), "account", "profile storage setter")
  module:RenameBankStorage("new", "renamed")
  assertEqual(settings.bankStorageByProfile.new, nil, "profile storage rename removes old key")
  assertEqual(module:GetBankStorage("renamed"), "account", "profile storage rename preserves policy")
  module:CopyBankStorage("renamed", "copy")
  assertEqual(module:GetBankStorage("copy"), "account", "profile storage copy")
  settings.profiles.copy = {}
  module:DeleteProfile("copy")
  assertEqual(settings.profiles.copy, nil, "profile deletion")
  assertEqual(settings.bankStorageByProfile.copy, nil, "profile storage deletion")
end

local function testContainerAdapter()
  local containers = {
    [0] = {
      size = 4,
      slots = { [1] = { itemID = 100, stackCount = 8, isLocked = false, hyperlink = "item:100" } },
    },
    [-1] = {
      size = 4,
      slots = { [1] = { itemID = 100, stackCount = 5, isLocked = false, hyperlink = "item:100" } },
    },
    [13] = {
      size = 2,
      slots = { [1] = { stackCount = 1, isLocked = false, hyperlink = "unknown" } },
    },
  }
  local cursor

  local function getContainer(bag)
    return containers[bag]
  end

  C_Container = {
    GetContainerNumSlots = function(bag)
      local container = getContainer(bag)
      return container and container.size or 0
    end,
    GetContainerNumFreeSlots = function(bag)
      local container = getContainer(bag)
      if not container then
        return 0, 0
      end
      local used = 0
      for _, _ in pairs(container.slots) do
        used = used + 1
      end
      return container.size - used, 0
    end,
    GetContainerItemInfo = function(bag, slot)
      local container = getContainer(bag)
      return container and container.slots[slot] or nil
    end,
    PickupContainerItem = function(bag, slot)
      local container = getContainer(bag)
      local destination = container.slots[slot]
      if not cursor then
        cursor = destination
        container.slots[slot] = nil
      elseif not destination then
        container.slots[slot] = cursor
        cursor = nil
      elseif destination.itemID == cursor.itemID then
        destination.stackCount = destination.stackCount + cursor.stackCount
        cursor = nil
      end
    end,
    SplitContainerItem = function(bag, slot, amount)
      local source = containers[bag].slots[slot]
      source.stackCount = source.stackCount - amount
      cursor = {
        itemID = source.itemID,
        stackCount = amount,
        isLocked = false,
        hyperlink = source.hyperlink,
      }
    end,
  }
  Enum = {
    BagIndex = {
      Bank = -1,
      ReagentBag = 5,
      BankBag_1 = 6,
      BankBag_7 = 12,
      AccountBankTab_1 = 13,
      AccountBankTab_5 = 17,
    },
  }
  WOW_PROJECT_MAINLINE = 1
  WOW_PROJECT_ID = WOW_PROJECT_MAINLINE
  BACKPACK_CONTAINER = 0
  BANK_CONTAINER = -1
  NUM_BAG_SLOTS = 4
  NUM_BANKBAGSLOTS = 7
  CursorHasItem = function()
    return cursor ~= nil
  end
  ClearCursor = function()
    cursor = nil
  end
  GetItemFamily = function()
    return 0
  end
  RS_ADDON = {
    GetItemInfo = function(itemID)
      return { itemId = itemID, itemStackCount = 20 }
    end,
  }
  RsModule = { bankContainerModule = {} }
  dofile("Src/BankContainers.lua")
  local adapter = RsModule.bankContainerModule

  assertTrue(adapter:SupportsAccountBank(), "account bank support detection")
  local snapshot = assert(adapter:CreateSnapshot("both"))
  assertEqual(snapshot.player.summary[100], 8, "player scan")
  assertEqual(snapshot.character.summary[100], 5, "character bank scan")
  assertEqual(#snapshot.account.containers, 1, "purchased account tab discovery")
  assertEqual(#snapshot.account.emptySlots, 1, "unknown occupied slot is not treated as empty")
  assertEqual(snapshot.account.emptySlots[1].slot, 2, "known empty account slot")

  local task = {
    key = "100:deposit",
    itemID = 100,
    itemName = "Test item",
    direction = "deposit",
    amount = 3,
    storageKinds = { "character", "account" },
  }
  local action = assert(adapter:FindAction(task, snapshot))
  assertEqual(action.source.bag, 0, "deposit source")
  assertEqual(action.destination.bag, -1, "character-bank destination priority")
  assertEqual(action.amount, 3, "split amount")
  assertTrue(adapter:ExecuteAction(action), "adapter executes split and merge")
  assertEqual(containers[0].slots[1].stackCount, 5, "source after split")
  assertEqual(containers[-1].slots[1].stackCount, 8, "destination after merge")
  assertEqual(cursor, nil, "cursor cleared by successful move")
end

local function testExecutor()
  local playerItemCount = 0
  local executeChangesCount = true
  local cursorBusy = false
  local printed = {}
  local timerID = 0

  local fakeAdapter = {
    CreateSnapshot = function()
      return { player = group({ [100] = playerItemCount }) }
    end,
    FindAction = function(_, task)
      return {
        key = task.key,
        itemID = 100,
        itemName = "Executor item",
        direction = "withdraw",
        amount = 2,
        source = { bag = -1, slot = 1 },
        destination = { bag = 0, slot = 1 },
      }
    end,
    ExecuteAction = function()
      if executeChangesCount then
        playerItemCount = 2
      end
      return true
    end,
  }
  local fakePlanner = {
    BuildTasks = function(_, _profile, _snapshot, _policy, blocked)
      if playerItemCount >= 2 or blocked["100:withdraw"] then
        return {}
      end
      return {
        {
          key = "100:withdraw",
          itemID = 100,
          itemName = "Executor item",
          direction = "withdraw",
          amount = 2,
          storageKinds = { "character" },
        },
      }
    end,
  }
  local settings = {
    profiles = { default = { { itemID = 100 } } },
    currentProfile = "default",
    autoOpenAtBank = false,
  }
  RS_ADDON = {
    ScheduleTimer = function(_self, _callback, _delay)
      timerID = timerID + 1
      return timerID
    end,
    CancelTimer = function()
      return true
    end,
    Print = function(_self, message)
      table.insert(printed, message)
    end,
    Show = function() end,
    Hide = function() end,
  }
  IsShiftKeyDown = function()
    return false
  end
  CursorHasItem = function()
    return cursorBusy
  end
  RsModule = {
    bankModule = {},
    bankContainerModule = fakeAdapter,
    bankPlannerModule = fakePlanner,
    restockerModule = { settings = settings },
    settingsModule = { GetBankStorage = function() return "character" end },
    aceMainFrameModule = {},
  }
  dofile("Src/Bank.lua")
  local executor = RsModule.bankModule
  executor.OnModuleInit()
  executor:Open()
  assertTrue(executor.pending ~= nil, "executor starts one transfer")
  executor:ConfirmPending(false)
  executor:ProcessNext()
  assertEqual(executor.movedCount, 2, "executor confirmed amount")
  assertTrue(not executor.currentlyRestocking, "executor completes")

  playerItemCount = 0
  executeChangesCount = false
  executor:Open()
  assertTrue(executor.pending ~= nil, "close test transfer pending")
  executor:Close()
  assertEqual(executor.pending, nil, "bank close clears pending transfer")
  assertTrue(not executor.bankIsOpen and not executor.currentlyRestocking, "bank close aborts executor")

  executor:Open()
  assertTrue(executor.pending ~= nil, "user-change test transfer pending")
  playerItemCount = 1
  executor:ConfirmPending(false)
  assertEqual(executor.pending, nil, "unrelated inventory change triggers replan")
  assertEqual(executor.movedCount, 0, "unrelated inventory change is not counted")
  executor:Close()

  playerItemCount = 0
  cursorBusy = true
  executor:Open()
  assertEqual(executor.pending, nil, "occupied cursor prevents a transfer")
  assertEqual(executor.status, "Waiting for the cursor to be cleared", "occupied cursor status")
  executor:Close()
  cursorBusy = false

  playerItemCount = 0
  executeChangesCount = false
  executor:Open()
  for _ = 1, 3 do
    assertTrue(executor.pending ~= nil, "retry transfer pending")
    executor:ConfirmPending(true)
    executor:ProcessNext()
  end
  assertTrue(executor.blockedTasks["100:withdraw"] ~= nil, "retry exhaustion blocks task")
  assertTrue(not executor.currentlyRestocking, "executor stops after retry exhaustion")
  assertTrue(#printed > 0, "executor reports terminal failures")
end

testPlanner()
testMigration()
testContainerAdapter()
testExecutor()

print("All Restocker bank tests passed")
