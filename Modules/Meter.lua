-- Module: Meter. Reads the game's damage meter (C_DamageMeter) after every
-- fight. Values are secret while in combat, so this only reads once combat ends.
--
-- run.stats         = { [player] = { damage = n, healing = n, ... } }  whole run
-- run.segments      = { { label, kind = "boss"|"trash", kill, at, duration, stats }, ... }
-- run.combatSeconds = seconds spent in combat
-- run.fights        = number of fights counted

local _, ns = ...
local isSecret = ns.IsSecret

-- Only types the client defines are read; guessing numeric IDs could log the wrong meter.
local T = Enum and Enum.DamageMeterType or {}
local TYPES = {}
for key, enumName in pairs({
  damage = "DamageDone", healing = "HealingDone", absorbs = "Absorbs",
  interrupts = "Interrupts", dispels = "Dispels", damageTaken = "DamageTaken",
  avoidable = "AvoidableDamageTaken", deaths = "Deaths",
}) do
  if T[enumName] ~= nil then TYPES[key] = T[enumName] end
end

local function ready()
  if not C_DamageMeter or not C_DamageMeter.GetAvailableCombatSessions then return false end
  if C_DamageMeter.IsDamageMeterAvailable and not C_DamageMeter.IsDamageMeterAvailable() then return false end
  return true
end
ns.MeterReady = ready

-- One meter session -> { [player] = { stat = amount } }, or nil if anything is still secret
local function readSession(id)
  local byPlayer = {}
  for key, typeID in pairs(TYPES) do
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromID, id, typeID)
    if ok and session and session.combatSources then
      for _, src in ipairs(session.combatSources) do
        local name, amount = src.name, src.totalAmount
        if isSecret(name) or isSecret(amount) then return nil end
        if name and amount and amount > 0 then
          byPlayer[name] = byPlayer[name] or {}
          byPlayer[name][key] = (byPlayer[name][key] or 0) + amount
        end
      end
    end
  end
  return byPlayer
end

local function capture(run)
  if not ready() or InCombatLockdown() then return end
  local m = run._meter
  local fresh = {}
  for _, s in ipairs(C_DamageMeter.GetAvailableCombatSessions() or {}) do
    local id = s.sessionID
    if id and not isSecret(id) and not m.known[id] and not m.counted[id] then
      local stats = readSession(id)
      if stats then
        local dur = (not isSecret(s.durationSeconds)) and s.durationSeconds or 0
        local name = (not isSecret(s.name)) and s.name or nil
        fresh[#fresh + 1] = { id = id, stats = stats, duration = dur, name = name }
        m.counted[id] = true
      end
    end
  end
  if #fresh == 0 then return end
  table.sort(fresh, function(a, b) return a.id < b.id end)

  -- Boss fights that ended since the last read belong to the newest sessions,
  -- matched from the end: a boss is the fight that was going when it ended.
  local log = run._encounterLog or {}
  local bossFor = {}
  local fi = #fresh
  for li = #log, (m.encountersSeen or 0) + 1, -1 do
    if fi < 1 then break end
    bossFor[fi] = log[li]; fi = fi - 1
  end
  m.encountersSeen = #log

  local now = GetServerTime() - run.startTime
  for i, f in ipairs(fresh) do
    for name, s in pairs(f.stats) do
      run.stats[name] = run.stats[name] or {}
      for key, v in pairs(s) do run.stats[name][key] = (run.stats[name][key] or 0) + v end
    end
    run.combatSeconds = run.combatSeconds + f.duration
    run.fights = run.fights + 1
    local boss = bossFor[i]
    run.segments[#run.segments + 1] = {
      label = boss and boss.name or f.name or "Trash",
      kind = boss and "boss" or "trash",
      kill = boss and boss.kill or nil,
      at = math.max(0, now - math.floor(f.duration + 0.5)), -- seconds into the run it started (approx.)
      duration = f.duration,
      stats = f.stats,
    }
  end
end

ns.RegisterModule({
  name = "Meter",
  OnRunStart = function(_, run)
    run.stats, run.segments, run.combatSeconds, run.fights = {}, {}, 0, 0
    -- fights already in the meter before the run started aren't counted
    local known = {}
    if ready() then
      for _, s in ipairs(C_DamageMeter.GetAvailableCombatSessions() or {}) do
        if s.sessionID and not isSecret(s.sessionID) then known[s.sessionID] = true end
      end
    end
    run._meter = { known = known, counted = {} }
  end,
  OnCombatEnd = function(_, run) capture(run) end,
  OnRunFinish = function(_, run) capture(run) end,
  Migrate = function(_, run, from)
    if from < 2 then
      run.segments = run.segments or {}
      -- a run that was in progress when the addon updated
      if run.knownSessions then
        run._meter = { known = run.knownSessions, counted = run.countedSessions or {} }
        run.knownSessions, run.countedSessions = nil, nil
      end
    end
  end,
})

table.insert(ns.statusLines, function(run)
  if not ready() then return "The damage meter isn't available, so only time, party, and bosses are logged." end
  if run then return (run.fights or 0) .. " fights counted." end
end)
