-- Module: Leveling. Records each level-up: stat gains and how long the level took
-- (from /played, read quietly), shows Foxden's level-up card, and tells guildmates
-- with Foxden that you dinged (a small toast on their screen).
--
-- FoxdenDB.levels[charKey] = { start = totalPlayedAtThisLevelStart,
--   history = { [level] = { at, seconds, gains = { str, agi, sta, int, spi, hp, mp } } } }
-- Message (prefix "Foxden", GUILD): "D <level> <class>"  — only after the welcome popup.

local _, ns = ...
local db
local waiting                 -- level-up waiting for its /played answer
local lastAsk = 0
local shownWithoutTime     -- level whose card showed before /played answered

local function me()
  db.levels = db.levels or {}
  local k = ns.CharKey()
  db.levels[k] = db.levels[k] or { history = {} }
  return db.levels[k]
end

-- Ask the server for /played without printing it in chat: the chat windows stop
-- listening for the answer while we ask, and start again as soon as it arrives
-- (or after 3 seconds). Another addon's /played request still prints as normal.
local muted = {}
local function unmute()
  for f in pairs(muted) do pcall(f.RegisterEvent, f, "TIME_PLAYED_MSG"); muted[f] = nil end
end
local function askPlayed()
  if not RequestTimePlayed or GetTime() - lastAsk < 2 then return end
  lastAsk = GetTime()
  for i = 1, (NUM_CHAT_WINDOWS or 10) do
    local f = _G["ChatFrame" .. i]
    if f and f.IsEventRegistered and f:IsEventRegistered("TIME_PLAYED_MSG") then
      f:UnregisterEvent("TIME_PLAYED_MSG"); muted[f] = true
    end
  end
  C_Timer.After(3, unmute)
  pcall(RequestTimePlayed)
end
ns.UnmutePlayed = unmute

local function statNow()
  local s = {}
  for i = 1, 5 do local ok, base = pcall(UnitStat, "player", i); s[i] = ok and base or 0 end
  s.hp = UnitHealthMax and UnitHealthMax("player") or 0
  s.mp = UnitPowerMax and UnitPowerMax("player", 0) or 0
  return s
end
local before -- stats at the start of this level, so gains can be worked out if the event doesn't say

function ns.LevelHistory(charKey)
  return db and db.levels and db.levels[charKey or ns.CharKey()]
end

-- The card and the guild toast live in UI/LevelUp.lua (ns.ShowLevelUp, ns.ShowGuildDing).
local function remember(name, level, class)
  db.dings = db.dings or {}
  table.insert(db.dings, { name = name, level = level, class = class, at = GetServerTime() })
  while #db.dings > 200 do table.remove(db.dings, 1) end
end

local function finish(level, gains, seconds)
  local m = me()
  m.history[level] = { at = GetServerTime(), seconds = seconds, gains = gains }
  if ns.ShowLevelUp and ns.settings.levelCard ~= false then ns.ShowLevelUp(level, gains, seconds) end
  if ns.settings.levelScreenshot and level % 10 == 0 and Screenshot then C_Timer.After(1.2, Screenshot) end
  ns.Changed()
end

local function onLevelUp(level, hp, mp, _, _, str, agi, sta, int, spi)
  level = tonumber(level) or UnitLevel("player")
  local gains = { str = str, agi = agi, sta = sta, int = int, spi = spi, hp = hp, mp = mp }
  -- some clients report the gains late or not at all: fill them from a before/after look
  C_Timer.After(1.5, function()
    local now = statNow()
    if before then
      local keys = { "str", "agi", "sta", "int", "spi" }
      for i, k in ipairs(keys) do if not gains[k] or gains[k] == 0 then gains[k] = math.max(0, (now[i] or 0) - (before[i] or 0)) end end
      if not gains.hp or gains.hp == 0 then gains.hp = math.max(0, now.hp - before.hp) end
      if not gains.mp or gains.mp == 0 then gains.mp = math.max(0, now.mp - before.mp) end
    end
    before = now
    waiting = { level = level, gains = gains }
    askPlayed()
    -- if /played never answers, show the card anyway
    C_Timer.After(4, function() if waiting and waiting.level == level then waiting = nil; shownWithoutTime = level; finish(level, gains, nil) end end)
  end)
  do local _, c = UnitClass("player"); remember(UnitName("player"), level, c) end
  if ns.settings.welcomed and ns.settings.shareLevelUps ~= false and IsInGuild() then
    local _, class = UnitClass("player")
    ns.Send(table.concat({ "D", level, class or "" }, "\t"), "GUILD")
  end
end

local function onPlayed(total, thisLevel)
  C_Timer.After(0, unmute) -- chat listens again once everyone has seen this answer
  if type(total) ~= "number" or ns.IsSecret(total) then return end
  local m = me()
  if waiting then
    local w = waiting
    waiting = nil
    local seconds = m.start and (total - m.start) or nil
    m.start = total
    finish(w.level, w.gains, seconds and seconds > 0 and seconds or nil)
  elseif shownWithoutTime and m.history[shownWithoutTime] and m.start then
    -- the answer came after the card: still record how long that level took
    local seconds = total - m.start
    if seconds > 0 then m.history[shownWithoutTime].seconds = seconds end
    shownWithoutTime = nil
    m.start = total
    ns.Changed()
  elseif type(thisLevel) == "number" then
    m.start = total - thisLevel
  end
end

local function onMessage(prefix, text, channel, sender)
  if prefix ~= ns.PREFIX or channel ~= "GUILD" or ns.IsSecret(text) or ns.IsSecret(sender) then return end
  local kind, level, class = strsplit("\t", text)
  if kind ~= "D" then return end
  if not sender:find("-") then sender = sender .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or "") end
  if sender == ns.CharKey() then return end
  level = tonumber(level)
  if level and level > 1 and level <= 200 then remember(sender:gsub("%-.*", ""), level, class ~= "" and class or nil) end
  if level and level > 1 and level <= 200 and ns.ShowGuildDing and ns.settings.guildDings ~= false then
    ns.ShowGuildDing(sender:gsub("%-.*", ""), level, class)
  end
end

ns.RegisterModule({
  name = "Leveling",
  OnLoad = function(_, saved) db = saved end,
  events = {
    PLAYER_LOGIN = function()
      before = statNow()
      C_Timer.After(6, askPlayed) -- learn when this level started
    end,
    PLAYER_LEVEL_UP = function(_, _, ...) onLevelUp(...) end,
    TIME_PLAYED_MSG = function(_, _, total, thisLevel) onPlayed(total, thisLevel) end,
    CHAT_MSG_ADDON = function(_, _, prefix, text, channel, sender) onMessage(prefix, text, channel, sender) end,
  },
})
