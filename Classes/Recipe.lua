local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@class RsRecipeModule
local recipeModule = RsModule.recipeModule ---@type RsRecipeModule

---@class RsIngredient
---@field item RsItem
---@field count number

---@class RsRecipe
---@field item RsItem
---@field ingredient1 RsIngredient
---@field ingredient2 RsIngredient|nil
---@field ingredient3 RsIngredient|nil

local recipeClass = {}
recipeClass.__index = recipeClass

---@return RsRecipe
---@param reagent1 RsIngredient
---@param reagent2 RsIngredient|nil
---@param reagent3 RsIngredient|nil
function recipeModule:Create(item, reagent1, reagent2, reagent3)
  local fields = --[[---@type RsRecipe]] {}

  fields.item = item
  fields.ingredient1 = reagent1
  fields.ingredient2 = reagent2
  fields.ingredient3 = reagent3

  setmetatable(fields, recipeClass)

  return fields
end