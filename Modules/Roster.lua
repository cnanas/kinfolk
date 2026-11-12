-- Module: Roster. The guild's member list from the game: name, rank, level,
-- class, online, last seen, and zone (online members: where they are now;
-- offline: where they logged out). Notes are deliberately left out.
--
-- FoxdenDB.roster = { guild, at, members = { { name, rank, rankIndex, level, class, zone, online, mobile, seenHours }, ... } }

local _, ns = ...
local pending, lastRequest = false, 0

local function request()
  -- ask the server for a fresh roster; it answers with GUILD_ROSTER_UPDATE (and throttles repeats itself)
  if not IsInGuild() then return end
  if GetTime() - lastRequest < 15 then return end
  lastRequest = GetTime()
  if C_GuildInfo and C_GuildInfo.GuildRoster then pcall(C_GuildInfo.GuildRoster) elseif GuildRoster then pcall(GuildRoster) end
end
ns.RequestRoster = request

local function read()
  pending = false
  if not IsInGuild() or not ns.db then return end
  local ok, total = pcall(GetNumGuildMembers)
  if not ok or not total or total == 0 then return end
  local members = {}
  for i = 1, total do
    local okI, name, rank, rankIndex, level, _, zone, _, _, online, _, class, _, _, mobile = pcall(GetGuildRosterInfo, i)
    if okI and name and not ns.IsSecret(name) then
      local seen
      if not online and GetGuildRosterLastOnline then
        local okL, y, m, d, h = pcall(GetGuildRosterLastOnline, i)
        if okL and y then seen = ((y * 365 + m * 30 + d) * 24) + (h or 0) end
      end
      members[#members + 1] = {
        name = name, rank = rank, rankIndex = rankIndex, level = level, class = class,
        zone = (not ns.IsSecret(zone)) and zone or nil, online = online and true or false, mobile = mobile and true or nil, seenHours = seen,
      }
    end
  end
  ns.db.roster = { guild = GetGuildInfo("player"), at = GetServerTime(), members = members }
  ns.Changed()
end

ns.RegisterModule({
  name = "Roster",
  events = {
    PLAYER_LOGIN = function() C_Timer.After(8, request) end,
    GUILD_ROSTER_UPDATE = function()
      if not pending then pending = true; C_Timer.After(1, read) end
    end,
  },
})
