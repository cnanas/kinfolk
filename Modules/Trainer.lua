-- Module: Trainer. Reads your class trainer's full list when you visit (every
-- rank, including ones you're too low for), so Foxden can show what you can learn
-- now and next, with levels and costs. No bundled spell lists: one visit fills it.
-- Profession trainers are read the same way. Adds a "Learn all" button at the trainer.
--
-- FoxdenDB.trainers = {
--   class = { [CLASS] = { at, spells = { { id, name, rank, level, cost, icon }, ... } } },
--   prof  = { [profession] = { at, spells = { { id, name, level, cost, icon, skill, skillReq } } } },
--   learned = { [charKey] = { [key] = true } },   -- seen as "used" at the trainer (fallback when no spell ID)
--   ignore  = { [charKey] = { [key] = true } },   -- abilities you chose to skip
-- }

local _, ns = ...
local db
local FILTERS = { "available", "unavailable", "used" }
local tip, button, toldThisSession

local function T()
  db.trainers = db.trainers or {}
  local t = db.trainers
  t.class, t.prof, t.learned, t.ignore = t.class or {}, t.prof or {}, t.learned or {}, t.ignore or {}
  return t
end

local function key(s) return s.id and tostring(s.id) or ((s.name or "?") .. "|" .. (s.rank or "")) end
ns.TrainerKey = key

local function spellID(i)
  tip = tip or CreateFrame("GameTooltip", "FoxdenTrainerTip", nil, "GameTooltipTemplate")
  tip:SetOwner(UIParent, "ANCHOR_NONE")
  local ok = pcall(tip.SetTrainerService, tip, i)
  if not ok then return nil end
  local ok2, _, id = pcall(tip.GetSpell, tip)
  tip:Hide()
  return ok2 and type(id) == "number" and not ns.IsSecret(id) and id or nil
end

local function call(fn, ...) if not fn then return nil end local ok, a, b, c, d = pcall(fn, ...); if ok then return a, b, c, d end end

-- Read every service with all filters on, then put the player's filters back.
local function read()
  local saved = {}
  for _, f in ipairs(FILTERS) do
    saved[f] = call(GetTrainerServiceTypeFilter, f)
    call(SetTrainerServiceTypeFilter, f, 1)
  end
  local list, used = {}, {}
  for i = 1, (call(GetNumTrainerServices) or 0) do
    local name, rank, kind = call(GetTrainerServiceInfo, i)
    if name and kind ~= "header" and not ns.IsSecret(name) then
      local s = {
        id = spellID(i), name = name, rank = (rank ~= "" and rank) or nil,
        level = call(GetTrainerServiceLevelReq, i) or 0, cost = call(GetTrainerServiceCost, i) or 0,
        icon = call(GetTrainerServiceIcon, i),
      }
      local skill, skillRank, hasReq = call(GetTrainerServiceSkillReq, i)
      if skill and hasReq ~= nil then s.skill, s.skillReq = skill, skillRank end
      list[#list + 1] = s
      if kind == "used" then used[key(s)] = true end
    end
  end
  for _, f in ipairs(FILTERS) do if saved[f] ~= nil then call(SetTrainerServiceTypeFilter, f, saved[f] and 1 or 0) end end
  return list, used
end

local function capture()
  if not db or InCombatLockdown() then return end
  local list, used = read()
  if #list == 0 then return end
  local t = T()
  if call(IsTradeskillTrainer) then
    local prof = list[1].skill or "Profession"
    t.prof[prof] = { at = GetServerTime(), spells = list }
  else
    local _, class = UnitClass("player")
    t.class[class] = { at = GetServerTime(), spells = list }
    local me = ns.CharKey()
    t.learned[me] = t.learned[me] or {}
    for k in pairs(used) do t.learned[me][k] = true end
    if not toldThisSession then
      toldThisSession = true
      ns.say(string.format("Saved your trainer's list (%d abilities). See it any time in /fox → Trainer.", #list))
    end
  end
  ns.Changed()
end

-- ---- reading it back -----------------------------------------------------------

local function known(s, me)
  if s.id then
    if IsPlayerSpell and call(IsPlayerSpell, s.id) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown and call(C_SpellBook.IsSpellKnown, s.id) then return true end
    if IsSpellKnown and call(IsSpellKnown, s.id) then return true end
  end
  local l = db and db.trainers and db.trainers.learned and db.trainers.learned[me]
  return l and l[key(s)] or false
end

-- Your class's abilities, each with .status = "known" | "ready" | "soon" | "skipped".
-- nil when you haven't visited your class trainer yet.
function ns.ClassAbilities()
  if not db then return nil end
  local _, class = UnitClass("player")
  local c = T().class[class]
  if not c then return nil end
  local me, level = ns.CharKey(), UnitLevel("player")
  local ignore = T().ignore[me] or {}
  local out = {}
  for _, s in ipairs(c.spells) do
    local status = known(s, me) and "known" or ignore[key(s)] and "skipped" or (s.level <= level and "ready") or "soon"
    out[#out + 1] = setmetatable({ status = status }, { __index = s })
  end
  table.sort(out, function(a, b) if a.level ~= b.level then return a.level < b.level end return (a.name .. (a.rank or "")) < (b.name .. (b.rank or "")) end)
  return out, c.at
end

function ns.SetSkipped(s, on)
  local me = ns.CharKey()
  local t = T()
  t.ignore[me] = t.ignore[me] or {}
  t.ignore[me][key(s)] = on or nil
  ns.Changed()
end

-- ---- "Learn all" at the trainer --------------------------------------------------

local function learnable()
  local me = ns.CharKey()
  local ignore = T().ignore[me] or {}
  local list, total = {}, 0
  for i = 1, (call(GetNumTrainerServices) or 0) do
    local name, rank, kind = call(GetTrainerServiceInfo, i)
    if kind == "available" then
      local s = { id = spellID(i), name = name, rank = (rank ~= "" and rank) or nil }
      if not ignore[key(s)] then
        local cost = call(GetTrainerServiceCost, i) or 0
        list[#list + 1] = i; total = total + cost
      end
    end
  end
  return list, total
end

local function updateButton()
  if not button then return end
  local list, total = learnable()
  button:SetShown(#list > 0 and not call(IsTradeskillTrainer))
  button.label:SetText(string.format("Learn all (%d)  %s", #list, ns.MoneyPlain and ns.MoneyPlain(total) or ""))
  button:SetWidth(math.max(150, button.label:GetStringWidth() + 24))
end

local function makeButton()
  local parent = _G.ClassTrainerFrame
  if button or not parent or not ns.UI then return end
  button = ns.UI.Button(parent, "Learn all", 150, 24, function()
    if InCombatLockdown() then return end
    local list, total = learnable()
    if total > GetMoney() then ns.say("Not enough gold to learn everything at once.", true); return end
    for j = #list, 1, -1 do call(BuyTrainerService, list[j]) end -- highest first, so indexes don't shift
    C_Timer.After(0.5, updateButton)
  end, "primary")
  button:SetPoint("BOTTOMRIGHT", parent, "TOPRIGHT", 0, 4)
  button:SetScript("OnEnter", function(b)
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    GameTooltip:AddLine("Foxden: learn every available ability")
    GameTooltip:AddLine("Skips anything you marked \"Skip\" on the Trainer page.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", GameTooltip_Hide)
end

ns.RegisterModule({
  name = "Trainer",
  OnLoad = function(_, saved) db = saved end,
  events = {
    TRAINER_SHOW = function()
      C_Timer.After(0.2, function()
        capture()
        if ns.settings.learnAll ~= false then makeButton(); updateButton() end
      end)
    end,
    TRAINER_UPDATE = function() if button and button:IsShown() then C_Timer.After(0.1, updateButton) end end,
    LEARNED_SPELL_IN_TAB = function() ns.Changed() end,
  },
})
