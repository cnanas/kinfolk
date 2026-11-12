-- Module: Locate. Guild members who opt in share their own position with the
-- guild over hidden addon messages; everyone else's addon shows them as dots
-- on the world map and with coordinates on the Roster page.
--
-- Only your own position is ever read or sent. Nothing is sent inside dungeons
-- or raids (the game hides positions there anyway), or before you've answered
-- the welcome popup. Turning sharing off tells guildmates to drop your dot.
--
-- Messages (prefix "Foxden"): "L <uiMapID> <x 0-1000> <y 0-1000> <zone>" and "LX" (stopped sharing)
-- FoxdenDB.locations[charKey] = { map, x, y, zone, at }

local _, ns = ...
local PREFIX = "Foxden"
local EVERY, HEARTBEAT, STALE = 30, 120, 300 -- send at most every 30s; resend every 2 min even if still; hide after 5 min
local lastSent = { map = nil, x = -1, y = -1, at = 0 }

local function sharing() return ns.settings.shareLocation == true and ns.settings.welcomed and IsInGuild() end

local function myPosition()
  if IsInInstance() then return nil end
  local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
  if not okM or type(map) ~= "number" or ns.IsSecret(map) then return nil end
  local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  if not okP or not pos then return nil end
  local okXY, x, y = pcall(pos.GetXY, pos)
  if not okXY or type(x) ~= "number" or ns.IsSecret(x) or (x <= 0 and y <= 0) then return nil end
  local zone = GetRealZoneText and GetRealZoneText() or ""
  return map, math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5), zone
end

local function send(msg) if C_ChatInfo and C_ChatInfo.SendAddonMessage then pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "GUILD") end end

local function tick()
  if not sharing() then return end
  local map, x, y, zone = myPosition()
  if not map then return end
  local now = GetTime()
  local moved = map ~= lastSent.map or math.abs(x - lastSent.x) + math.abs(y - lastSent.y) >= 3
  if (moved and now - lastSent.at >= EVERY) or now - lastSent.at >= HEARTBEAT then
    send(table.concat({ "L", map, x, y, zone or "" }, "\t"))
    if ns.db then ns.db.locations = ns.db.locations or {}; ns.db.locations[ns.CharKey()] = { map = map, x = x, y = y, zone = zone, at = GetServerTime() } end
    lastSent = { map = map, x = x, y = y, at = now }
  end
end

function ns.SetShareLocation(on)
  ns.settings.shareLocation = on and true or false
  if not on then
    if IsInGuild() then send("LX") end
    if ns.db and ns.db.locations then ns.db.locations[ns.CharKey()] = nil end
  end
  lastSent.at = 0
  if on then C_Timer.After(1, tick) end
end

-- Fresh guildmate positions: { [charKey] = { map, x, y, zone, at } }, older than 5 minutes left out.
function ns.GuildLocations()
  local out, now = {}, GetServerTime()
  for key, l in pairs(ns.db and ns.db.locations or {}) do
    if now - (l.at or 0) <= STALE then out[key] = l end
  end
  return out
end

local function onMessage(prefix, text, channel, sender)
  if prefix ~= PREFIX or channel ~= "GUILD" or ns.IsSecret(text) or ns.IsSecret(sender) then return end
  if not sender:find("-") then sender = sender .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or "") end
  if sender == ns.CharKey() or not ns.db then return end
  ns.db.locations = ns.db.locations or {}
  local kind, map, x, y, zone = strsplit("\t", text)
  if kind == "L" then
    map, x, y = tonumber(map), tonumber(x), tonumber(y)
    if map and x and y and x >= 0 and x <= 1000 and y >= 0 and y <= 1000 then
      ns.db.locations[sender] = { map = map, x = x, y = y, zone = zone ~= "" and zone or nil, at = GetServerTime() }
      if ns.RefreshMapPins then ns.RefreshMapPins() end
    end
  elseif kind == "LX" then
    ns.db.locations[sender] = nil
    if ns.RefreshMapPins then ns.RefreshMapPins() end
  end
end

ns.RegisterModule({
  name = "Locate",
  events = {
    PLAYER_LOGIN = function()
      C_Timer.NewTicker(10, tick) -- checks every 10s; actually sends at most every 30s and only when moved
    end,
    CHAT_MSG_ADDON = function(_, _, prefix, text, channel, sender) onMessage(prefix, text, channel, sender) end,
  },
})
