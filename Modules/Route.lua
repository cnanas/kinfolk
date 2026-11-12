-- Module: Route. Where the run went, as far as the game allows.
--
-- Always (when the client provides them): which map floor you were on and when,
-- and where each boss sits on that floor (the Dungeon Journal's pins).
-- Only if the game allows reading your own position inside dungeons: your path,
-- sampled every 2 seconds, and where you stood at each kill. Many clients block
-- this in instances; then `allowed` is false and only floors + pins are kept.
-- Party members' positions are never read.
--
-- run.route = {
--   allowed = true | false,
--   floors  = { { map = uiMapID, name = "...", at = secondsIntoRun }, ... },  -- each floor change
--   path    = { { m = uiMapID, x = 0..1000, y = 0..1000, t = seconds }, ... }, -- your own position
--   pins    = { [uiMapID] = { { name = "...", x = 0..1000, y = 0..1000 }, ... } },
--   kills   = { { name = "...", m = uiMapID, x, y, t }, ... },
-- }

local _, ns = ...
local isSecret = ns.IsSecret
local TICK, MIN_MOVE, MAX_POINTS = 2, 5, 2000 -- seconds, thousandths of the map, points per run
local ticker

local function bestMap()
  if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
  local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
  if ok and type(m) == "number" and not isSecret(m) then return m end
end

-- Own position on a map as 0..1000 integers, or nil if the game won't say.
local function position(map)
  if not (map and C_Map.GetPlayerMapPosition) then return nil end
  local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  if not ok or not pos or not pos.GetXY then return nil end
  local okXY, x, y = pcall(pos.GetXY, pos)
  if not okXY or isSecret(x) or isSecret(y) or type(x) ~= "number" or type(y) ~= "number" then return nil end
  if x <= 0 and y <= 0 then return nil end
  return math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5)
end

local function mapName(map)
  local ok, info = pcall(C_Map.GetMapInfo, map)
  return ok and info and info.name or nil
end

-- Boss pins the Dungeon Journal shows on this floor.
local function bossPins(map)
  local list = {}
  if not (C_EncounterJournal and C_EncounterJournal.GetEncountersOnMap) then return list end
  local ok, encounters = pcall(C_EncounterJournal.GetEncountersOnMap, map)
  if not ok or type(encounters) ~= "table" then return list end
  for _, e in ipairs(encounters) do
    local name
    if EJ_GetEncounterInfo and e.encounterID then
      local okN, n = pcall(EJ_GetEncounterInfo, e.encounterID)
      if okN then name = n end
    end
    if name and type(e.mapX) == "number" and type(e.mapY) == "number" then
      list[#list + 1] = { name = name, x = math.floor(e.mapX * 1000 + 0.5), y = math.floor(e.mapY * 1000 + 0.5) }
    end
  end
  return list
end

local function sample()
  local run = ns.GetCurrentRun()
  if not run then if ticker then ticker:Cancel(); ticker = nil end; return end
  local r = run.route
  if not r then return end
  local t = GetServerTime() - run.startTime
  local map = bestMap()
  if not map then return end

  local lastFloor = r.floors[#r.floors]
  if not lastFloor or lastFloor.map ~= map then
    r.floors[#r.floors + 1] = { map = map, name = mapName(map), at = t }
    if r.pins[map] == nil then r.pins[map] = bossPins(map) end
  end

  local x, y = position(map)
  if r.allowed == nil then r.allowed = x ~= nil end
  if x and #r.path < MAX_POINTS then
    local last = r.path[#r.path]
    if not last or last.m ~= map or math.abs(last.x - x) + math.abs(last.y - y) >= MIN_MOVE then
      r.path[#r.path + 1] = { m = map, x = x, y = y, t = t }
    end
  end
end

local function start(run)
  run.route = run.route or { floors = {}, path = {}, pins = {}, kills = {} }
  if ticker then ticker:Cancel() end
  ticker = C_Timer.NewTicker(TICK, sample)
  C_Timer.After(1, sample)
end

ns.RegisterModule({
  name = "Route",
  OnRunStart = function(_, run) start(run) end,
  OnLoad = function()
    -- resumed after a /reload mid-dungeon
    C_Timer.After(2, function() local run = ns.GetCurrentRun(); if run then start(run) end end)
  end,
  OnRunFinish = function(_, run)
    sample()
    if ticker then ticker:Cancel(); ticker = nil end
  end,
  events = {
    ENCOUNTER_END = function(_, run, _, encounterName, _, _, success)
      if not run or not run.route or success ~= 1 then return end
      local map = bestMap()
      local x, y = position(map)
      table.insert(run.route.kills, { name = encounterName, m = map, x = x, y = y, t = GetServerTime() - run.startTime })
    end,
  },
})

-- /fox maptest: what this client allows, in one line each.
function ns.MapTest()
  local map = bestMap()
  ns.say("Map test" .. (IsInInstance() and " (inside an instance)" or " (outdoors)") .. ":", true)
  ns.say(map and ("  Floor: " .. (mapName(map) or "?") .. " (map " .. map .. ")") or "  Floor: the game didn't say which map you're on.", true)
  local x, y = position(map)
  ns.say(x and string.format("  Your position: YES (%.1f, %.1f). Paths can be recorded here.", x / 10, y / 10)
    or "  Your position: blocked here. Runs will show floors and boss locations only.", true)
  local pins = map and bossPins(map) or {}
  ns.say("  Boss pins on this floor: " .. #pins .. (#pins > 0 and (" (" .. pins[1].name .. "…)") or ""), true)
  local okL, layers = pcall(C_Map.GetMapArtLayers, map or 0)
  ns.say("  Map art: " .. ((okL and type(layers) == "table" and layers[1]) and "available" or "none for this floor"), true)
end
