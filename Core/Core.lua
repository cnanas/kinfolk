-- Foxden: core.
-- Owns the saved data and the life of a run (start, finish, resume after a
-- reload). Everything that gets recorded *during* a run lives in a module
-- under Modules/, and everything shown about a run lives in a view under
-- Views/. See ARCHITECTURE.md for how to add either.

local ADDON, ns = ...

-- Bump SCHEMA when the shape of a saved run changes, and teach the module
-- that owns the changed data to upgrade older runs in its Migrate hook.
ns.SCHEMA = 3

ns.DEFAULTS = { track = true, chat = true, remind = true, keep = 100, scale = 1, share = true, offer = false, shareLocation = true, welcomed = false, copyPopup = true, levelCard = true, shareLevelUps = true, guildDings = true, learnAll = true, levelScreenshot = false, tracker = true, minimapButton = true, rareAlerts = true }
ns.settings = setmetatable({}, { __index = ns.DEFAULTS }) -- replaced at load

local db, run
local frame = CreateFrame("Frame")

-- force = true for answers to slash commands, which always show
function ns.say(msg, force)
  if force or ns.settings.chat then print("|cff7fe3c4Foxden:|r " .. msg) end
end
local say = ns.say

function ns.IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) end

-- "Name-Realm" for the logged-in character (realm without spaces, as the game writes it in chat)
function ns.CharKey()
  local name = UnitName("player")
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or ""):gsub("%s", "")
  return name .. "-" .. realm
end

-- Saved data that isn't tied to a dungeon run: professions, inventory, guild crafters.
-- FoxdenDB.crafting = { chars = { [charKey] = {...} }, guild = { [charKey] = {...} } }
function ns.Crafting()
  local db = ns.db
  if not db then return nil end
  db.crafting = db.crafting or {}
  db.crafting.chars = db.crafting.chars or {}
  db.crafting.guild = db.crafting.guild or {}
  return db.crafting
end

function ns.MyCrafting()
  local c = ns.Crafting()
  if not c then return nil end
  local key = ns.CharKey()
  local me = c.chars[key]
  if not me then
    local _, class = UnitClass("player")
    me = { name = UnitName("player"), realm = (GetRealmName()), class = class, faction = (UnitFactionGroup("player")), professions = {} }
    c.chars[key] = me
  end
  me.level = UnitLevel("player")
  me.guild = GetGuildInfo("player")
  me.offer = ns.settings.offer and true or false -- takes craft requests from guildmates
  return me
end

-- UI files set ns.RefreshUI; anything that changes run data calls ns.Changed()
function ns.Changed() if ns.RefreshUI then ns.RefreshUI() end end

-- ---- modules ---------------------------------------------------------------
-- A module is a table with a `name` and any of:
--   events = { EVENT_NAME = function(self, run, ...) end }  (run may be nil)
--   OnLoad(self, db)          saved data is ready
--   OnRunStart(self, run)     a run just started; add your fields to it
--   OnCombatEnd(self, run)    a fight ended and the meter has settled
--   OnRunFinish(self, run)    last chance to record before the run is saved
--   OnRunSaved(self, run)     the run is saved (relay, copy box)
--   Migrate(self, run, from)  upgrade a run saved with an older schema
-- Hooks are isolated: an error in one module is reported and the rest carry on.

ns.modules = {}
local handlers = {} -- event -> { module, ... }
local CORE_EVENTS = { ADDON_LOADED = true, PLAYER_ENTERING_WORLD = true, ZONE_CHANGED_NEW_AREA = true, PLAYER_REGEN_ENABLED = true }

local function call(mod, fn, ...)
  local ok, err = pcall(fn, mod, ...)
  if not ok then geterrorhandler()(("Foxden [%s]: %s"):format(mod.name or "?", tostring(err))) end
end

local function fire(hook, ...)
  for _, mod in ipairs(ns.modules) do
    if mod[hook] then call(mod, mod[hook], ...) end
  end
end

function ns.RegisterModule(mod)
  ns.modules[#ns.modules + 1] = mod
  for event in pairs(mod.events or {}) do
    if not handlers[event] then
      handlers[event] = {}
      if not CORE_EVENTS[event] then frame:RegisterEvent(event) end
    end
    table.insert(handlers[event], mod)
  end
  return mod
end

-- ---- runs ------------------------------------------------------------------

-- Keys starting with "_" are scratch space for modules during a run and are
-- dropped when the run is saved.
local function stripScratch(r)
  for k in pairs(r) do
    if type(k) == "string" and k:sub(1, 1) == "_" then r[k] = nil end
  end
end

local function migrate(r)
  local from = r.schema or 1
  if from < ns.SCHEMA then
    fire("Migrate", r, from)
    r.schema = ns.SCHEMA
  end
end

local function prune()
  local keep = ns.settings.keep or 0
  if keep > 0 then
    while #db.runs > keep do table.remove(db.runs, 1) end
  end
end
ns.Prune = prune

-- Is this instance a real dungeon? true / false / nil (can't tell). Only the game's
-- dungeon journal can say "no", and on Forever it's empty, so every 5-player instance
-- counts (City of Dalaran is a real dungeon there). Visits without a fight aren't kept.
local NOT_DUNGEON = {}
local function isDungeon(name, instanceID)
  if NOT_DUNGEON[instanceID] then return false end
  if ns.Dungeons and ns.Dungeons[instanceID] then return true end -- Data/Dungeons.lua
  local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
  if EJ_GetInstanceForMap and okM and type(map) == "number" and not ns.IsSecret(map) then
    local okJ, jid = pcall(EJ_GetInstanceForMap, map)
    if okJ and type(jid) == "number" and jid > 0 then return true end
  end
  local list = db.journal and db.journal.dungeons
  if type(list) == "table" and #list > 0 then
    local want = ns.Slug and ns.Slug(name)
    for _, d in ipairs(list) do if ns.Slug and ns.Slug(d.name) == want then return true end end
    return false
  end
  return nil
end

local function startRun(name, difficultyName, instanceID)
  local now = GetServerTime()
  local dungeon = isDungeon(name, instanceID)
  run = {
    id = string.format("%d-%s", now, tostring(instanceID)),
    schema = ns.SCHEMA,
    dungeon = name,
    difficulty = difficultyName,
    instanceID = instanceID,
    startTime = now,
    loggedBy = UnitName("player"),
    addonVersion = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)(ADDON, "Version"),
  }
  run._notDungeon = dungeon == false or nil
  db.current = run
  fire("OnRunStart", run)
  if dungeon ~= false then say("Run started: " .. name .. ". Good luck in there!") end
  ns.Changed()
end

local function saveRun(r, reason, endTime)
  r.endTime = endTime
  r.duration = endTime - r.startTime
  r.endReason = reason
  stripScratch(r)
  r.pendingFinish = nil
  table.insert(db.runs, r)
  prune()
end

local function finishRun(reason)
  if not run then return end
  if InCombatLockdown() then run.pendingFinish = reason; return end
  fire("OnRunFinish", run)
  local r = run
  -- not worth keeping: a city that's an instance (Dalaran), or walking in and out
  -- without a fight. Nothing is saved, posted or relayed.
  local bosses = r.bosses and #r.bosses or 0
  if bosses == 0 and (r._notDungeon or (r.combatSeconds or 0) < 20) then
    db.current, run = nil, nil
    if not r._notDungeon then say("Left " .. r.dungeon .. " without a fight, so the run wasn't saved.") end
    ns.Changed()
    return
  end
  saveRun(r, reason, GetServerTime())
  db.current, run = nil, nil
  fire("OnRunSaved", r)
  say(string.format("Run saved: %s (%s).%s", r.dungeon, ns.UI and ns.UI.Time(r.duration) or r.duration .. "s",
    ns.settings.remind and (ns.IsCourier and ns.IsCourier() and " Type /fox sync to send it to Discord." or "") or ""))
  ns.Changed()
end
ns.FinishRun = finishRun

local function checkZone()
  local name, instanceType, _, difficultyName, _, _, _, instanceID = GetInstanceInfo()
  if instanceType == "party" then
    if run and run.instanceID ~= instanceID then finishRun("changed dungeon") end
    if not run and ns.settings.track then startRun(name, difficultyName, instanceID)
    elseif run then
      -- re-check (a run resumed after /reload may have been judged by an older version)
      local was = run._notDungeon
      run._notDungeon = isDungeon(name, instanceID) == false or nil
      if was ~= run._notDungeon and ns.RefreshTracker then ns.RefreshTracker() end
    end
  elseif run then
    finishRun("left dungeon")
  end
end

local function onLoad()
  FoxdenDB = FoxdenDB or { runs = {} }
  db = FoxdenDB
  db.runs = db.runs or {}
  db.settings = db.settings or {}
  for k, v in pairs(ns.DEFAULTS) do if db.settings[k] == nil then db.settings[k] = v end end
  ns.settings, ns.db = db.settings, db

  for _, r in ipairs(db.runs) do migrate(r) end
  run = db.current -- resume after /reload mid-dungeon
  if run then migrate(run) end
  fire("OnLoad", db)

  -- a run left open from an old session (logged out inside a dungeon) is closed
  -- at the last time we know of rather than stretching to now
  if run and GetServerTime() - run.startTime > 4 * 3600 then
    saveRun(run, "abandoned", run.lastSeen or run.startTime)
    db.current, run = nil, nil
  end
end

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON then return end
    onLoad()
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    C_Timer.After(1, checkZone)
  elseif event == "PLAYER_REGEN_ENABLED" then
    if run then run.lastSeen = GetServerTime() end
    -- give the damage meter a moment to close the fight before modules read it
    C_Timer.After(1.5, function()
      if run then fire("OnCombatEnd", run); ns.Changed() end
      if run and run.pendingFinish then finishRun(run.pendingFinish) end
    end)
  end
  local list = handlers[event]
  if list and db then
    for _, mod in ipairs(list) do call(mod, mod.events[event], run, ...) end
  end
end)
for event in pairs(CORE_EVENTS) do frame:RegisterEvent(event) end

-- ---- public API ------------------------------------------------------------

function ns.GetCurrentRun() return run end
-- the run to show in Foxden's pages: not a city visit that only looked like a dungeon
function ns.LiveRun() return run and not run._notDungeon and run or nil end
function ns.GetRuns() return db and db.runs or {} end

function ns.DeleteRun(id)
  if not db then return end
  for i = #db.runs, 1, -1 do
    if db.runs[i].id == id then table.remove(db.runs, i) end
  end
  ns.Changed()
end

function ns.Sync()
  if InCombatLockdown() then say("Wait until combat ends.", true) else ReloadUI() end
end

-- status lines modules can add to /fox status: ns.statusLines[#+1] = function(run) return "..." end
ns.statusLines = {}

SLASH_FOXDEN1 = "/fox"
SLASH_FOXDEN2 = "/foxden"
SLASH_FOXDEN3 = "/fd"
SlashCmdList.FOXDEN = function(msg)
  msg = strtrim((msg or ""):lower())
  if msg == "" or msg == "log" or msg == "show" then
    if ns.ToggleWindow then ns.ToggleWindow() end
  elseif msg == "options" or msg == "settings" or msg == "config" then
    if ns.OpenSettings then ns.OpenSettings() end
  elseif msg == "end" then
    if run then finishRun("ended manually") else say("No run in progress.", true) end
  elseif msg == "sync" then
    ns.Sync()
  elseif msg == "maptest" then
    if ns.MapTest then ns.MapTest() end
  elseif msg == "levelup" then
    if ns.ShowLevelUp then ns.ShowLevelUp(UnitLevel("player"), { str = 3, agi = 2, sta = 4, int = 1, spi = 1, hp = 22, mp = 30 }, 2700, true) end
  elseif msg == "note" or msg == "notes" then
    if ns.ToggleNote then ns.ToggleNote() end
  elseif msg == "note new" then
    if ns.OpenNote and ns.NewNote then ns.OpenNote(ns.NewNote()) end
  elseif msg == "tracker" then
    ns.settings.tracker = ns.settings.tracker == false
    say("Dungeon tracker " .. (ns.settings.tracker and "on." or "off."), true)
    if ns.RefreshTracker then ns.RefreshTracker() end
  elseif msg == "trainer" then
    if ns.OpenPage then ns.OpenPage("trainer") end
  elseif msg == "copy" then
    if ns.ShowCopyRun then ns.ShowCopyRun() end
  elseif msg == "welcome" then
    if ns.ShowWelcome then ns.ShowWelcome() end
  elseif msg == "journaltest" or msg == "journalscan" then
    if ns.JournalTest then ns.JournalTest() end
  elseif msg == "status" then
    if run then say("In " .. run.dungeon .. ".", true) else say(#db.runs .. " runs saved. No run in progress.", true) end
    for _, line in ipairs(ns.statusLines) do
      local ok, text = pcall(line, run)
      if ok and text then say(text, true) end
    end
  else
    say("/fox (dashboard) · /fox options · /fox status · /fox end · /fox sync · /fox copy · /fox note · /fox trainer · /fox levelup · /fox maptest · /fox journaltest · /fox welcome", true)
  end
end
