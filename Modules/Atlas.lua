-- Module: Atlas. Where each zone sits on its continent, read from the game's own
-- map data, so the guild website can draw its own (art-free) continent map with
-- guildmates' shared positions on it. Only names and rectangles: no map images.
--
-- FoxdenDB.atlas = {
--   v = 1,
--   conts = { [continentID] = { name = "Eastern Kingdoms" } },
--   maps  = { [uiMapID] = { name, cont = continentID, kind = "zone"|"city"|..., l, r, t, b } },  -- 0..1000 on the continent
-- }
-- Scanned once per continent (when you or a guildmate who shares their location is there).

local _, ns = ...
local db
local CONTINENT, ZONE = 2, 3 -- Enum.UIMapType values
local KIND = { [3] = "zone", [5] = "micro", [6] = "orphan" }

local function info(id)
  if not (C_Map and C_Map.GetMapInfo) then return nil end
  local ok, i = pcall(C_Map.GetMapInfo, id)
  if ok and type(i) == "table" and type(i.mapType) == "number" and not ns.IsSecret(i.mapType) then return i end
end

local function continentOf(id)
  local seen = 0
  local i = info(id)
  while i and seen < 10 do
    if i.mapType == CONTINENT then return i.mapID, i end
    if i.mapType < CONTINENT or not i.parentMapID or i.parentMapID == 0 then return nil end
    i = info(i.parentMapID); seen = seen + 1
  end
end

local function rect(id, cont)
  if not C_Map.GetMapRectOnMap then return nil end
  local ok, l, r, t, b = pcall(C_Map.GetMapRectOnMap, id, cont)
  if not ok or type(l) ~= "number" or ns.IsSecret(l) or r <= l or b <= t then return nil end
  local k = function(v) return math.floor(math.max(0, math.min(1, v)) * 1000 + 0.5) end
  return k(l), k(r), k(t), k(b)
end

local function addMap(id, cont, i)
  i = i or info(id)
  if not i then return end
  local l, r, t, b = rect(id, cont)
  if not l then return end
  db.atlas.maps[id] = { name = i.name, cont = cont, kind = KIND[i.mapType] or "zone", l = l, r = r, t = t, b = b }
end

local function scanContinent(cont, ci)
  ci = ci or info(cont)
  if not ci or db.atlas.conts[cont] then return end
  db.atlas.conts[cont] = { name = ci.name }
  local ok, kids = pcall(C_Map.GetMapChildrenInfo, cont, ZONE, true)
  if ok and type(kids) == "table" then
    for _, z in ipairs(kids) do addMap(z.mapID, cont, z) end
  end
end

-- Make sure a map a position was reported on can be placed on the website.
function ns.AtlasEnsure(id)
  if not db or type(id) ~= "number" or ns.IsSecret(id) then return end
  db.atlas = db.atlas or { v = 1, conts = {}, maps = {} }
  if db.atlas.maps[id] then return end
  local cont, ci = continentOf(id)
  if not cont then return end
  scanContinent(cont, ci)
  if not db.atlas.maps[id] then addMap(id, cont) end -- a city or sub-zone not listed as a zone
end

ns.RegisterModule({
  name = "Atlas",
  OnLoad = function(_, saved) db = saved end,
  events = {
    PLAYER_LOGIN = function()
      C_Timer.After(8, function()
        local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and type(m) == "number" then ns.AtlasEnsure(m) end
      end)
    end,
    CHAT_MSG_ADDON = function(_, _, prefix, text)
      if prefix ~= ns.PREFIX or ns.IsSecret(text) or text:sub(1, 2) ~= "L\t" then return end
      local map = tonumber((select(2, strsplit("\t", text))))
      if map then ns.AtlasEnsure(map) end
    end,
  },
})
