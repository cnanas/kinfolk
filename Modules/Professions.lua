-- Module: Professions. Records every recipe this character knows, whenever a
-- profession window is opened. Nothing to fill in.
--
-- crafting.chars[me].professions[name] = {
--   skill, maxSkill, scannedAt,
--   recipes = { { spell = recipeID, name = "...", item = craftedItemID or nil }, ... }
-- }
-- The game's recipe IDs are spell IDs and don't match the website's recipe IDs,
-- so the website matches on the crafted item (or the name, for enchants).

local _, ns = ...
local pending

local function professionInfo()
  if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
    local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
    if ok and type(info) == "table" then
      local name = info.parentProfessionName or info.professionName or info.name
      if name and name ~= "" then return name, info.skillLevel, info.maxSkillLevel end
    end
  end
  if GetTradeSkillLine then
    local name, skill, max = GetTradeSkillLine()
    if name and name ~= "" and name ~= "UNKNOWN" then return name, skill, max end
  end
end

-- a window showing someone else's linked profession, or the guild's, is not ours
local function isOwnProfession()
  if C_TradeSkillUI then
    if C_TradeSkillUI.IsTradeSkillLinked and C_TradeSkillUI.IsTradeSkillLinked() then return false end
    if C_TradeSkillUI.IsTradeSkillGuild and C_TradeSkillUI.IsTradeSkillGuild() then return false end
    if C_TradeSkillUI.IsNPCCrafting and C_TradeSkillUI.IsNPCCrafting() then return false end
  end
  return true
end

local function itemFromLink(link)
  return link and tonumber(link:match("item:(%d+)")) or nil
end

local function modernRecipes()
  if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo) then return nil end
  local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
  if not ok or type(ids) ~= "table" or not next(ids) then return nil end
  local list = {}
  for _, id in pairs(ids) do
    local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
    if okInfo and info and info.learned then
      local item
      if C_TradeSkillUI.GetRecipeSchematic then
        local okS, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, id, false)
        if okS and schematic then item = schematic.outputItemID end
      end
      if not item and C_TradeSkillUI.GetRecipeItemLink then
        local okL, link = pcall(C_TradeSkillUI.GetRecipeItemLink, id)
        if okL then item = itemFromLink(link) end
      end
      list[#list + 1] = { spell = id, name = info.name, item = item }
    end
  end
  return list
end

local function legacyRecipes()
  if not (GetNumTradeSkills and GetTradeSkillInfo) then return nil end
  local list = {}
  for i = 1, GetNumTradeSkills() do
    local name, kind = GetTradeSkillInfo(i)
    if kind and kind ~= "header" and kind ~= "subheader" then
      local link = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
      local spell = link and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)"))
      local item = GetTradeSkillItemLink and itemFromLink(GetTradeSkillItemLink(i))
      list[#list + 1] = { spell = spell, name = name, item = item }
    end
  end
  return #list > 0 and list or nil
end

local function scan()
  pending = nil
  if not isOwnProfession() then return end
  local name, skill, max = professionInfo()
  if not name then return end
  local recipes = modernRecipes() or legacyRecipes()
  if not recipes or #recipes == 0 then return end
  local me = ns.MyCrafting()
  if not me then return end
  local before = me.professions[name] and #me.professions[name].recipes or 0
  me.professions[name] = { skill = skill, maxSkill = max, scannedAt = GetServerTime(), recipes = recipes }
  if #recipes ~= before then
    ns.say(string.format("Saved %d %s recipes.", #recipes, name))
    if ns.ShareProfessions then ns.ShareProfessions() end
  end
  ns.Changed()
end

-- the list fills in over several events; scan once it settles
local function soon()
  if pending then return end
  pending = true
  C_Timer.After(0.75, scan)
end

ns.RegisterModule({
  name = "Professions",
  events = {
    TRADE_SKILL_SHOW = function() soon() end,
    TRADE_SKILL_LIST_UPDATE = function() soon() end,
    SKILL_LINES_CHANGED = function() soon() end,
  },
})

table.insert(ns.statusLines, function()
  local me = ns.MyCrafting()
  if not me then return end
  local bits = {}
  for prof, p in pairs(me.professions) do bits[#bits + 1] = string.format("%s %d (%d recipes)", prof, p.skill or 0, #p.recipes) end
  if #bits == 0 then return "Professions: open a profession window once so it can be saved." end
  table.sort(bits)
  return "Professions: " .. table.concat(bits, ", ")
end)
