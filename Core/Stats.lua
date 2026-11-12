-- Foxden: statistics from the runs saved in this game (the website has
-- everyone's; in game you see the runs your addon logged).

local _, ns = ...
local Stats = {}
ns.Stats = Stats

local function isClear(r) return (r.bosses and #r.bosses or 0) > 0 and r.endReason ~= "abandoned" and r.duration end

function Stats.Totals()
  local t = { runs = 0, bosses = 0, seconds = 0, dungeons = 0, week = 0 }
  local seen, weekAgo = {}, GetServerTime() - 7 * 86400
  for _, r in ipairs(ns.GetRuns()) do
    t.runs = t.runs + 1
    t.bosses = t.bosses + (r.bosses and #r.bosses or 0)
    t.seconds = t.seconds + (r.duration or 0)
    if not seen[r.dungeon] then seen[r.dungeon] = true; t.dungeons = t.dungeons + 1 end
    if (r.endTime or r.startTime or 0) > weekAgo then t.week = t.week + 1 end
  end
  return t
end

-- { { name, runs = {...}, best = run, typical = seconds, wipes, bosses }, ... } newest first
function Stats.Dungeons()
  local by, list = {}, {}
  for _, r in ipairs(ns.GetRuns()) do
    local d = by[r.dungeon]
    if not d then d = { name = r.dungeon or "Unknown", runs = {}, wipes = 0, bosses = 0, last = 0 }; by[r.dungeon] = d; list[#list + 1] = d end
    d.runs[#d.runs + 1] = r
    d.wipes = d.wipes + (r.wipes or 0)
    d.bosses = d.bosses + (r.bosses and #r.bosses or 0)
    d.last = math.max(d.last, r.endTime or r.startTime or 0)
    if isClear(r) and (not d.best or r.duration < d.best.duration) then d.best = r end
  end
  for _, d in ipairs(list) do
    local times = {}
    for _, r in ipairs(d.runs) do if isClear(r) then times[#times + 1] = r.duration end end
    table.sort(times)
    d.typical = times[math.max(1, math.ceil(#times / 2))]
  end
  table.sort(list, function(a, b) return a.last > b.last end)
  return list
end

-- boss -> { wipes, kills } from fight breakdowns
function Stats.WipesByBoss(runs)
  local by, list = {}, {}
  for _, r in ipairs(runs) do
    for _, s in ipairs(r.segments or {}) do
      if s.kind == "boss" and s.label then
        local b = by[s.label]
        if not b then b = { name = s.label, wipes = 0, kills = 0 }; by[s.label] = b; list[#list + 1] = b end
        if s.kill then b.kills = b.kills + 1 else b.wipes = b.wipes + 1 end
      end
    end
  end
  table.sort(list, function(a, b) return a.wipes > b.wipes end)
  return list
end

-- players seen in run stats: { { name, class, role, runs = { {run, dps, hps, deaths} }, bestDps, bestHps, last }, ... }
function Stats.Players()
  local by, list = {}, {}
  for _, r in ipairs(ns.GetRuns()) do
    local classOf, roleOf = {}, {}
    for _, m in ipairs(r.party or {}) do classOf[m.name], roleOf[m.name] = m.class, m.role end
    local secs = r.combatSeconds or 0
    for full, s in pairs(r.stats or {}) do
      local name = ns.UI.ShortName(full)
      local p = by[name]
      if not p then p = { name = name, runs = {}, bestDps = 0, bestHps = 0, last = 0 }; by[name] = p; list[#list + 1] = p end
      p.class = classOf[name] or p.class
      if roleOf[name] and roleOf[name] ~= "NONE" then p.role = roleOf[name] end
      local dps = secs > 0 and (s.damage or 0) / secs or 0
      local hps = secs > 0 and (s.healing or 0) / secs or 0
      p.runs[#p.runs + 1] = { run = r, dps = dps, hps = hps, deaths = s.deaths or 0, interrupts = s.interrupts or 0 }
      p.bestDps, p.bestHps = math.max(p.bestDps, dps), math.max(p.bestHps, hps)
      p.last = math.max(p.last, r.endTime or r.startTime or 0)
    end
  end
  table.sort(list, function(a, b) return a.last > b.last end)
  return list
end

-- Same key as the website's journal URLs: "The Deadmines" and "Deadmines" both become "deadmines".
function ns.Slug(name)
  return (tostring(name or ""):lower():gsub("^the%s+", ""):gsub("['’]", ""):gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", ""))
end

-- The companion's snapshot of the website (craft list, costs, requests), if it has written one.
function ns.Site()
  local s = FoxdenSiteData
  if type(s) == "table" and s.v == 1 then return s end
end
