--
--This Module contains auto-buy table for ingredients for craftable items (example rogue poisons)
--
--local _TOCNAME, _ADDONPRIVATE = ... ---@type RestockerAddon
local RS = RS_ADDON ---@type RestockerAddon

---@alias RsCraftingBookItemName {[string]: RsRecipe}
---@alias RsCraftingBookItemId {[number]: RsRecipe}

---@class RsBuyIngredientsModule
---@field buyIngredients RsCraftingBookItemName
---@field buyIngredientsWait RsCraftingBookItemId
local buyIngredientsModule = RsModule.buyIngredientsModule
---
local envModule = KvModuleManager.envModule
local restockerModule = RsModule.restockerModule ---@type RsRestockerModule
local itemModule = RsModule.itemModule ---@type RsItemModule
local recipeModule = RsModule.recipeModule ---@type RsRecipeModule

buyIngredientsModule.buyIngredients = --[[---@type RsCraftingBookItemName]] {}
buyIngredientsModule.buyIngredientsWait = --[[---@type RsCraftingBookItemId]] {}

---@param recipe RsRecipe
function buyIngredientsModule:AddRecipe(recipe)
  -- Two situations can happen:
  -- 1. GetItemInfo will work and return all values required
  -- 2. Some values will not work - then we place the task into buyiModule.buyIngredientsWait and do later
  local function postpone()
    self.buyIngredientsWait[recipe.item.id] = recipe
  end

  local itemVal = --[[---@not nil]] RS.GetItemInfo(recipe.item.id)
  if not itemVal then
    postpone()
    return
  end
  recipe.item.localizedName = itemVal.itemName -- update localizedName

  local ing1 = recipe.ingredient1
  local ing1Item = RS.GetItemInfo(ing1.item.id)
  if not ing1Item then
    postpone()
    return
  end
  ing1.item.localizedName = (--[[---@not nil]] ing1Item).itemName -- update localizedName

  local ing2Item --- @type GIICacheItem
  local ing3Item --- @type GIICacheItem

  if recipe.ingredient2 then
    local ing2 = --[[---@not nil]] recipe.ingredient2
    ing2Item = --[[---@not nil]] RS.GetItemInfo(ing2.item.id)
    if not ing2Item then
      postpone()
      return
    end
    ing2.item.localizedName = ing2Item.itemName -- update localizedName
  end

  if recipe.ingredient3 then
    local ing3 = --[[---@not nil]] recipe.ingredient3
    ing3Item = --[[---@not nil]] RS.GetItemInfo(ing3.item.id)
    if not ing3Item then
      postpone()
      return
    end
    ing3.item.localizedName = ing3Item.itemName -- update localizedName
  end

  self.buyIngredients[itemVal.itemName] = recipe -- added with localized name key
  self.buyIngredientsWait[recipe.item.id] = nil -- delete the waiting one
end

---@param item RsItem
---@param reagent1 RsIngredient Pair of {Item, Count} First reagent to craft
---@param reagent2 RsIngredient|nil Nil or pair of {Item, Count} 2nd reagent to craft
---@param reagent3 RsIngredient|nil Nil or pair of {Item, Count} 3rd reagent to craft
function buyIngredientsModule:Recipe(item, reagent1, reagent2, reagent3)
  local recipe = recipeModule:Create(item, reagent1, reagent2, reagent3)
  self:AddRecipe(recipe)
end

function buyIngredientsModule:RetryWaitRecipes()
  for _, recipe in pairs(self.buyIngredientsWait) do
    self:AddRecipe(recipe)
  end
end

---@param item RsItem
---@param reagent1 RsIngredient
---@param reagent2 RsIngredient|nil
---@param reagent3 RsIngredient|nil
function buyIngredientsModule:TbcRecipe(item, reagent1, reagent2, reagent3)
  if envModule.haveTBC then
    self:Recipe(item, reagent1, reagent2, reagent3)
  end
end

---@param item RsItem
---@param reagent1 RsIngredient
---@param reagent2 RsIngredient|nil
---@param reagent3 RsIngredient|nil
function buyIngredientsModule:ClassicRecipe(item, reagent1, reagent2, reagent3)
  if envModule.isClassic then
    self:Recipe(item, reagent1, reagent2, reagent3)
  end
end

function buyIngredientsModule:SetupAutobuyIngredients()
  if envModule.haveWotLK then
    return -- in WotLK poisons are buyable pre-crafted
  end

  if next(self.buyIngredients) then
    return -- do not double-init
  end

  local maidensAnguish = {
    item  = itemModule:Create(2931, "Maiden's Anguish"),
    count = 1
  } -- always 1 in crafts
  local dustOfDeter = itemModule:Create(8924, "Dust of Deterioration")
  local dustOfDecay = itemModule:Create(2928, "Dust of Decay")
  local essOfAgony = itemModule:Create(8923, "Essence of Agony")
  local essOfPain = itemModule:Create(2930, "Essence of Pain")
  local deathweed = itemModule:Create(5173, "Deathweed")

  local crystalVial = { item = itemModule:Create(8925, "Crystal Vial"), count = 1 }
  local leadedVial = { item = itemModule:Create(3372, "Leaded Vial"), count = 1 }
  local emptyVial = { item = itemModule:Create(3371, "Empty Vial"), count = 1 }

  --
  -- INSTANT POISONS
  --
  local instant7 = itemModule:Create(21927, "Instant Poison VII")
  local instant6 = itemModule:Create(8928, "Instant Poison VI")
  local instant5 = itemModule:Create(8927, "Instant Poison V")
  local instant4 = itemModule:Create(8926, "Instant Poison IV")
  local instant3 = itemModule:Create(6950, "Instant Poison III")
  local instant2 = itemModule:Create(6949, "Instant Poison II")
  local instant1 = itemModule:Create(6947, "Instant Poison")

  self:TbcRecipe(instant7, maidensAnguish, crystalVial, nil)
  self:TbcRecipe(instant6, { item = dustOfDeter, count = 2 }, crystalVial, nil)
  self:TbcRecipe(instant5, { item = dustOfDeter, count = 2 }, crystalVial, nil)
  self:TbcRecipe(instant4, { item = dustOfDeter, count = 1 }, crystalVial, nil)
  self:TbcRecipe(instant3, { item = dustOfDeter, count = 2 }, leadedVial, nil)
  self:TbcRecipe(instant2, { item = dustOfDecay, count = 1 }, leadedVial, nil)

  self:ClassicRecipe(instant6, { item = dustOfDeter, count = 4 }, crystalVial, nil)
  self:ClassicRecipe(instant5, { item = dustOfDeter, count = 3 }, crystalVial, nil)
  self:ClassicRecipe(instant4, { item = dustOfDeter, count = 2 }, crystalVial, nil)
  self:ClassicRecipe(instant3, { item = dustOfDeter, count = 1 }, leadedVial, nil)
  self:ClassicRecipe(instant2, { item = dustOfDecay, count = 3 }, leadedVial, nil)

  self:Recipe(instant1, { item = dustOfDecay, count = 1 }, emptyVial, nil)

  --
  -- CRIPPLING POISONS
  --
  local crip2 = itemModule:Create(3776, "Crippling Poison II")
  local crip1 = itemModule:Create(3775, "Crippling Poison")

  self:TbcRecipe(crip2, { item = essOfAgony, count = 1 }, crystalVial, nil)
  self:ClassicRecipe(crip2, { item = essOfAgony, count = 3 }, crystalVial, nil)

  self:Recipe(crip1, { item = essOfPain, count = 1 }, emptyVial, nil)

  --
  -- DEADLY POISONS
  --
  local deadly7 = itemModule:Create(22054, "Deadly Poison VII")
  local deadly6 = itemModule:Create(22053, "Deadly Poison VI")
  local deadly5 = itemModule:Create(20844, "Deadly Poison V")
  local deadly4 = itemModule:Create(8985, "Deadly Poison IV")
  local deadly3 = itemModule:Create(8984, "Deadly Poison III")
  local deadly2 = itemModule:Create(2893, "Deadly Poison II")
  local deadly1 = itemModule:Create(2892, "Deadly Poison")

  self:TbcRecipe(deadly7, maidensAnguish, crystalVial, nil)
  self:TbcRecipe(deadly6, maidensAnguish, crystalVial, nil)
  self:TbcRecipe(deadly5, { item = deathweed, count = 2 }, crystalVial, nil)
  self:TbcRecipe(deadly4, { item = deathweed, count = 2 }, crystalVial, nil)
  self:TbcRecipe(deadly3, { item = deathweed, count = 1 }, crystalVial, nil)
  self:TbcRecipe(deadly2, { item = deathweed, count = 2 }, leadedVial, nil)
  self:TbcRecipe(deadly1, { item = deathweed, count = 1 }, leadedVial, nil)

  self:ClassicRecipe(deadly5, { item = deathweed, count = 7 }, crystalVial, nil)
  self:ClassicRecipe(deadly4, { item = deathweed, count = 5 }, crystalVial, nil)
  self:ClassicRecipe(deadly3, { item = deathweed, count = 3 }, crystalVial, nil)
  self:ClassicRecipe(deadly2, { item = deathweed, count = 2 }, leadedVial, nil)
  self:ClassicRecipe(deadly1, { item = deathweed, count = 1 }, leadedVial, nil)

  -- MIND-NUMBING POISONS
  local mindNumbing3 = itemModule:Create(9186, "Mind-numbing Poison III")
  local mindNumbing2 = itemModule:Create(6951, "Mind-numbing Poison II")
  local mindNumbing1 = itemModule:Create(5237, "Mind-numbing Poison")

  self:TbcRecipe(mindNumbing3, { item = essOfAgony, count = 1 }, crystalVial, nil)
  self:TbcRecipe(mindNumbing2, { item = essOfAgony, count = 1 }, leadedVial, nil)
  self:TbcRecipe(mindNumbing1, { item = dustOfDecay, count = 1 }, emptyVial, nil)

  self:ClassicRecipe(mindNumbing3, { item = dustOfDeter, count = 2 }, { item = essOfAgony, count = 2 }, crystalVial)
  self:ClassicRecipe(mindNumbing2, { item = dustOfDecay, count = 4 }, { item = essOfPain, count = 4 }, leadedVial)
  self:ClassicRecipe(mindNumbing1, { item = dustOfDecay, count = 1 }, { item = essOfPain, count = 1 }, emptyVial)

  -- WOUND POISONS
  local wound5 = itemModule:Create(22055, "Wound Poison V")
  local wound4 = itemModule:Create(10922, "Wound Poison IV")
  local wound3 = itemModule:Create(10921, "Wound Poison III")
  local wound2 = itemModule:Create(10920, "Wound Poison II")
  local wound1 = itemModule:Create(10918, "Wound Poison")

  self:TbcRecipe(wound5, { item = essOfAgony, count = 2 }, crystalVial, nil)
  self:TbcRecipe(wound4, { item = essOfAgony, count = 1 }, { item = deathweed, count = 1}, crystalVial)
  self:TbcRecipe(wound3, { item = essOfAgony, count = 1 }, crystalVial, nil)
  self:TbcRecipe(wound2, { item = essOfPain, count = 1 }, { item = deathweed, count = 1 }, leadedVial)
  self:TbcRecipe(wound1, { item = essOfPain, count = 1 }, leadedVial, nil)

  self:ClassicRecipe(wound4, { item = essOfAgony, count = 2 }, { item = deathweed, count = 2 }, crystalVial)
  self:ClassicRecipe(wound3, { item = essOfAgony, count = 1 }, { item = deathweed, count = 2 }, crystalVial)
  self:ClassicRecipe(wound2, { item = essOfPain, count = 1 }, { item = deathweed, count = 2 }, leadedVial)
  self:ClassicRecipe(wound1, { item = essOfPain, count = 1 }, { item = deathweed, count = 1 }, leadedVial)

  -- ANESTHETIC POISON
  local anesth1 = itemModule:Create(21835, "Anesthetic Poison")
  self:TbcRecipe(anesth1, maidensAnguish, { item = deathweed, count = 1 }, crystalVial)
end

--- Check if any of the items user wants to restock are on our crafting autobuy list
function buyIngredientsModule:CraftingPurchaseOrder()
  local purchaseOrder = {} ---@type table<string, number> Maps localized item name to buy count
  local settings = restockerModule.settings

  -- Check auto-buy reagents table
  local profile = settings.profiles[settings.currentProfile]

  for _, item in pairs(--[[---@not nil]] profile) do
    if buyIngredientsModule.buyIngredients[item.itemName] ~= nil then
      local craftedName = item.itemName
      local craftedRestockAmount = item.amount
      local haveCrafted = GetItemCount(item.itemID, true)
      local inBags = GetItemCount(item.itemID, false)
      local craftedMissing = craftedRestockAmount - haveCrafted
      local inBank = haveCrafted - inBags
      local minDifference

      if inBank == 0 then
        minDifference = 1
      else
        minDifference = craftedRestockAmount / 2
      end

      if craftedMissing >= minDifference and craftedMissing > 0 then
        local recipe = buyIngredientsModule.buyIngredients[craftedName]

        ---@param i RsIngredient|nil
        local function forEachIngredient(i)
          if i then
            local amountToGet = (--[[---@not nil]] i).count * craftedMissing
            local locName = (--[[---@not nil]] i).item.localizedName
            local purchase = purchaseOrder[locName]

            purchaseOrder[locName] = purchase and purchase + amountToGet or amountToGet
          end -- if ingredient
        end
        forEachIngredient(recipe.ingredient1)
        forEachIngredient(recipe.ingredient2)
        forEachIngredient(recipe.ingredient3)
      end -- if need to buy missing reagents/ingredients
    end
  end

  for reagent, val in pairs(purchaseOrder) do
    local inBags = GetItemCount(reagent, false)
    if inBags > 0 then
      purchaseOrder[reagent] = purchaseOrder[reagent] - inBags
    end
  end

  return purchaseOrder
end

function buyIngredientsModule.OnModuleInit()
  -- Craftable recipes (rogue poisons, etc)
  buyIngredientsModule:SetupAutobuyIngredients()
end
