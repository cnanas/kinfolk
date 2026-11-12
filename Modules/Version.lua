-- Module: Version. Tells you once per session when a guildmate runs a newer
-- Foxden. Only the version number is sent, and only after the welcome popup.
--
-- Messages (prefix "Foxden"): "V <version>". Sent once, shortly after login.
-- Anyone who hears an older version answers with theirs (at most every 10 minutes,
-- after a random pause) so people who just logged in learn about updates too.

local _, ns = ...
local PREFIX = "Foxden"
local told, lastReply = false, 0

local function mine()
  return (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)("Foxden", "Version") or "0"
end

-- 1 if a > b, -1 if a < b, 0 if equal. Compares "2.10.1" numerically, part by part.
function ns.CompareVersions(a, b)
  local pa, pb = {}, {}
  for n in tostring(a):gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
  for n in tostring(b):gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
  for i = 1, math.max(#pa, #pb) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then return x > y and 1 or -1 end
  end
  return 0
end

local function canSend() return ns.settings.welcomed and IsInGuild() and C_ChatInfo and C_ChatInfo.SendAddonMessage end
local function announce() if canSend() then pcall(C_ChatInfo.SendAddonMessage, PREFIX, "V\t" .. mine(), "GUILD") end end

local function onMessage(prefix, text, channel, sender)
  if prefix ~= PREFIX or channel ~= "GUILD" or ns.IsSecret(text) or ns.IsSecret(sender) then return end
  local kind, theirs = strsplit("\t", text)
  if kind ~= "V" or not theirs or not theirs:match("^%d+[%d.]*$") then return end
  local cmp = ns.CompareVersions(theirs, mine())
  if cmp > 0 and not told then
    told = true
    ns.newerVersion = theirs
    ns.say(string.format("Foxden %s is out (you have %s). Update from CurseForge, Wago or github.com/cnanas/foxden.", theirs, mine()), true)
  elseif cmp < 0 and GetTime() - lastReply > 600 then
    lastReply = GetTime()
    C_Timer.After(3 + math.random() * 20, announce)
  end
end

ns.RegisterModule({
  name = "Version",
  events = {
    PLAYER_LOGIN = function() C_Timer.After(20, announce) end,
    CHAT_MSG_ADDON = function(_, _, prefix, text, channel, sender) onMessage(prefix, text, channel, sender) end,
  },
})

table.insert(ns.statusLines, function()
  return ns.newerVersion and string.format("Foxden %s: a newer version (%s) is out.", mine(), ns.newerVersion) or ("Foxden " .. mine() .. ".")
end)
