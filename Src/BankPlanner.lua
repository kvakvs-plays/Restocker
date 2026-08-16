---@class RsBankPlannerModule
local bankPlannerModule = RsModule.bankPlannerModule

---@alias RsBankStoragePolicy "character"|"account"|"both"
---@alias RsBankTransferDirection "deposit"|"withdraw"

---@class RsBankTransferTask
---@field key string
---@field itemID number
---@field itemName string
---@field direction RsBankTransferDirection
---@field amount number
---@field storageKinds string[]

local validStoragePolicies = {
  character = true,
  account = true,
  both = true,
}

---@param policy string|nil
---@return boolean
function bankPlannerModule:IsValidStoragePolicy(policy)
  return policy ~= nil and validStoragePolicies[policy] == true
end

---@param policy RsBankStoragePolicy
---@return string[]
function bankPlannerModule:GetStorageKinds(policy)
  if policy == "account" then
    return { "account" }
  elseif policy == "both" then
    return { "character", "account" }
  end
  return { "character" }
end

local function getSummaryCount(snapshot, kind, itemID)
  local group = snapshot[kind]
  return group and group.summary[itemID] or 0
end

---@param profile RsTradeCommand[]
---@param snapshot RsBankSnapshot
---@param policy RsBankStoragePolicy
---@param blockedTasks table<string, boolean>|nil
---@return RsBankTransferTask[]
function bankPlannerModule:BuildTasks(profile, snapshot, policy, blockedTasks)
  local tasks = {} ---@type RsBankTransferTask[]
  local seenItems = {}
  local storageKinds = self:GetStorageKinds(policy)

  for _, item in ipairs(profile or {}) do
    local itemID = tonumber(item.itemID)
    if itemID and itemID > 0 and not seenItems[itemID] then
      seenItems[itemID] = true

      local target = math.max(0, math.floor(tonumber(item.amount) or 0))
      local playerCount = getSummaryCount(snapshot, "player", itemID)
      local storageCount = 0
      for _, kind in ipairs(storageKinds) do
        storageCount = storageCount + getSummaryCount(snapshot, kind, itemID)
      end

      local direction
      local amount = 0
      if item.stashTobank and playerCount > target then
        direction = "deposit"
        amount = playerCount - target
      elseif item.restockFromBank and playerCount < target and storageCount > 0 then
        direction = "withdraw"
        amount = math.min(target - playerCount, storageCount)
      end

      if direction and amount > 0 then
        local key = tostring(itemID) .. ":" .. direction
        if not blockedTasks or not blockedTasks[key] then
          table.insert(tasks, {
            key = key,
            itemID = itemID,
            itemName = item.itemName or tostring(itemID),
            direction = direction,
            amount = amount,
            storageKinds = storageKinds,
          })
        end
      end
    end
  end

  return tasks
end
