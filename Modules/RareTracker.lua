-- Module: RareTracker. Notices rares and rare elites when you target or mouse over them
-- (or see their nameplate), alive or dead, and:
--   - remembers the sighting (FoxdenDB.rareSightings), which the companion uploads so the
--     guild website can learn respawn times;
--   - tells guildmates with Foxden ("RS" message), who get a small note on screen.
-- Respawn windows come back from the website's snapshot (site.rares) and your own kills.
--
-- FoxdenDB.rareSightings = { { i = npcID, k = "seen"|"killed", at, m = uiMapID, x, y, by }, ... } (last 300)

local _, ns = ...
local db
local lastSaid = {} -- [npcID .. kind] = time, so one rare isn't announced over and over

local function npcID(guid)
  if type(guid) ~= "string" or ns.IsSecret(guid) then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" then return tonumber(id) end
end

local function here()
  if IsInInstance and IsInInstance() then return nil end
  local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
  if not okM or type(map) ~= "number" or ns.IsSecret(map) then return nil end
  local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  if not okP or not pos then return map end
  local x, y = pos:GetXY()
  if type(x) ~= "number" or ns.IsSecret(x) then return map end
  return map, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
end

local function rareName(id)
  local r = ns.Rares and ns.Rares[id]
  return r and r[1] or ("Rare " .. id)
end

local function record(id, kind, map, x, y, by)
  db.rareSightings = db.rareSightings or {}
  local list = db.rareSightings
  local now = GetServerTime()
  -- one entry per rare and kind every 5 minutes is plenty
  for i = #list, math.max(1, #list - 40), -1 do
    local s = list[i]
    if s.i == id and s.k == kind and now - (s.at or 0) < 300 then return false end
  end
  list[#list + 1] = { i = id, k = kind, at = now, m = map, x = x, y = y, by = by }
  while #list > 300 do table.remove(list, 1) end
  ns.Changed()
  if ns.RefreshUI then ns.RefreshUI() end
  return true
end

local function toast(text)
  if ns.ShowGuildNote then ns.ShowGuildNote(text) else ns.say(text) end
  if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
end

local function check(unit)
  if not UnitExists or not UnitExists(unit) then return end
  local okC, class = pcall(UnitClassification, unit)
  if not okC or (class ~= "rare" and class ~= "rareelite") then return end
  local id = npcID(UnitGUID and UnitGUID(unit))
  if not id or not (ns.Rares and ns.Rares[id]) then return end
  local dead = UnitIsDead and UnitIsDead(unit)
  local kind = dead and "killed" or "seen"
  local map, x, y = here()
  if not record(id, kind, map, x, y, UnitName("player")) then return end
  -- tell the guild once in a while
  local key = id .. kind
  if (lastSaid[key] or 0) + 600 < GetTime() and ns.settings.welcomed and ns.settings.rareAlerts ~= false and IsInGuild() then
    lastSaid[key] = GetTime()
    ns.Send(table.concat({ "RS", id, kind, map or 0, x or 0, y or 0 }, "\t"), "GUILD")
  end
  if kind == "seen" then ns.say(string.format("Rare: %s%s.", rareName(id), x and string.format(" at %d, %d", math.floor(x + 0.5), math.floor(y + 0.5)) or "")) end
end

-- When it may be up again: from the website's snapshot, or your own last kill + the timer.
-- returns status text, seconds until the window opens (nil if unknown)
function ns.RareNext(id)
  local site = ns.Site and ns.Site()
  local r = site and type(site.rares) == "table" and site.rares[id]
  local lastKill, minM, maxM = r and r[1] or 0, r and r[3] or 0, r and r[4] or 0
  for _, s in ipairs(db and db.rareSightings or {}) do
    if s.i == id and s.k == "killed" and (s.at or 0) > lastKill then lastKill = s.at end
  end
  local lastSeen = r and r[2] or 0
  for _, s in ipairs(db and db.rareSightings or {}) do if s.i == id and s.k == "seen" and (s.at or 0) > lastSeen then lastSeen = s.at end end
  if lastKill > 0 and minM > 0 and lastSeen <= lastKill then
    local now = GetServerTime()
    local from, to = lastKill + minM * 60, lastKill + maxM * 60
    if now >= from then return now >= to and "should be up" or "may be up now", 0 end
    local function m(sec) local mm = math.ceil(sec / 60); return mm < 60 and (mm .. " min") or string.format("%d h %d min", math.floor(mm / 60), mm % 60) end
    return "in " .. m(from - now) .. (to > from and ("-" .. m(to - now)) or ""), from - now
  end
  return nil, nil
end

-- The last sighting (yours or the guild's): kind, time, who
function ns.RareLast(id)
  local best
  for _, s in ipairs(db and db.rareSightings or {}) do if s.i == id and (not best or s.at > best.at) then best = s end end
  local site = ns.Site and ns.Site()
  local r = site and type(site.rares) == "table" and site.rares[id]
  if r then
    if (r[1] or 0) > 0 and (not best or r[1] > best.at) then best = { k = "killed", at = r[1], by = r[5] } end
    if (r[2] or 0) > 0 and (not best or r[2] > best.at) then best = { k = "seen", at = r[2], by = r[6] } end
  end
  return best
end

local function onMessage(prefix, text, channel, sender)
  if prefix ~= ns.PREFIX or channel ~= "GUILD" or ns.IsSecret(text) or ns.IsSecret(sender) then return end
  local kind, id, what, map, x, y = strsplit("\t", text)
  if kind ~= "RS" then return end
  id, map, x, y = tonumber(id), tonumber(map), tonumber(x), tonumber(y)
  if not id or not (ns.Rares and ns.Rares[id]) or (what ~= "seen" and what ~= "killed") then return end
  local who = sender:gsub("%-.*", "")
  if who == UnitName("player") then return end
  record(id, what, map and map > 0 and map or nil, x and x > 0 and x or nil, y and y > 0 and y or nil, who)
  if what == "seen" and ns.settings.rareAlerts ~= false then
    local r = ns.Rares[id]
    toast(string.format("|cffffd24d%s|r spotted %s in %s%s", who, r[1], r[5], x and x > 0 and string.format(" (%d, %d)", math.floor(x + 0.5), math.floor(y + 0.5)) or ""))
  end
end

ns.RegisterModule({
  name = "RareTracker",
  OnLoad = function(_, saved) db = saved end,
  events = {
    PLAYER_TARGET_CHANGED = function() check("target") end,
    UPDATE_MOUSEOVER_UNIT = function() check("mouseover") end,
    NAME_PLATE_UNIT_ADDED = function(_, _, unit) if unit then check(unit) end end,
    UNIT_HEALTH = function(_, _, unit) if unit == "target" and UnitIsDead and UnitIsDead("target") then check("target") end end,
    CHAT_MSG_ADDON = function(_, _, prefix, text, channel, sender) onMessage(prefix, text, channel, sender) end,
  },
})
