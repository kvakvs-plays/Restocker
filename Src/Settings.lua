---@class RsSettingsModule
local settingsModule = RsModule.settingsModule
local restockerModule = RsModule.restockerModule

settingsModule.CURRENT_SCHEMA_VERSION = 1

---@param settings RsSettings
function settingsModule:Migrate(settings)
  settings.bankStorageByProfile = settings.bankStorageByProfile or {}

  if not settings.schemaVersion or settings.schemaVersion < 1 then
    for profileName, _ in pairs(settings.profiles or {}) do
      if settings.bankStorageByProfile[profileName] == nil then
        settings.bankStorageByProfile[profileName] = "character"
      end
    end
    settings.schemaVersion = 1
  end
end

---@param profileName string
---@return RsBankStoragePolicy
function settingsModule:GetBankStorage(profileName)
  local settings = restockerModule.settings
  local policy = settings.bankStorageByProfile and settings.bankStorageByProfile[profileName]
  if policy == "account" or policy == "both" then
    return policy
  end
  return "character"
end

---@param profileName string
---@param policy RsBankStoragePolicy
function settingsModule:SetBankStorage(profileName, policy)
  local settings = restockerModule.settings
  settings.bankStorageByProfile = settings.bankStorageByProfile or {}
  if policy ~= "account" and policy ~= "both" then
    policy = "character"
  end
  settings.bankStorageByProfile[profileName] = policy
end

---@param oldName string
---@param newName string
function settingsModule:RenameBankStorage(oldName, newName)
  self:SetBankStorage(newName, self:GetBankStorage(oldName))
  restockerModule.settings.bankStorageByProfile[oldName] = nil
end

---@param sourceName string
---@param destinationName string
function settingsModule:CopyBankStorage(sourceName, destinationName)
  self:SetBankStorage(destinationName, self:GetBankStorage(sourceName))
end

---@param name string
---@return boolean Success, false if exists
function settingsModule:AddProfile(name)
  local profiles = restockerModule.settings.profiles or {}

  if profiles[name] ~= nil or not name or name == "" then
    return false
  end

  profiles[name] = {}
  self:SetBankStorage(name, "character")
  return true
end

---@param name string
function settingsModule:DeleteProfile(name)
  restockerModule.settings.profiles = restockerModule.settings.profiles or {}
  restockerModule.settings.profiles[name] = nil
  if restockerModule.settings.bankStorageByProfile then
    restockerModule.settings.bankStorageByProfile[name] = nil
  end
end

---@return {[string]: string}
function settingsModule:GetProfileNames()
  local profileNames = {}
  local profiles = restockerModule.settings.profiles or {}
  for name, _ in pairs(profiles) do
    profileNames[name] = name
  end
  return profileNames
end
