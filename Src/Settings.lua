---@class RsSettingsModule
local settingsModule = RsModule.settingsModule
local restockerModule = RsModule.restockerModule

---@param name string
---@return boolean Success, false if exists
function settingsModule:AddProfile(name)
  local profiles = restockerModule.settings.profiles or {}

  if profiles[name] ~= nil or not name or name == "" then
    return false
  end

  profiles[name] = {}
  return true
end

---@param name string
function settingsModule:DeleteProfile(name)
  restockerModule.settings.profiles = restockerModule.settings.profiles or {}
  restockerModule.settings.profiles[name] = nil
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
