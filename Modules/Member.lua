-- Module: Member. What this character shares with the guild, and a few lookups pages use:
--   a loot wishlist, the dungeons you want to run, map pins made from notes,
--   and which dungeon quests you've done or are carrying (read from the game).
-- The companion uploads FoxdenDB.member; the website hands everyone's back in its snapshot.
--
-- FoxdenDB.member[charKey] = { class, level,
--   wishlist = { { i = itemID, k = "ms"|"os"|"tm", n = name, b = boss, d = dungeon }, ... },
--   lfg = { "deadmines", ... }, pins = { { t = text, zone, map, x, y, at }, ... } }

local _, ns = ...
local db

local function me()
  db.member = db.member or {}
  local k = ns.CharKey()
  local m = db.member[k] or {}
  db.member[k] = m
  m.wishlist, m.lfg, m.pins = m.wishlist or {}, m.lfg or {}, m.pins or {}
  local _, class = UnitClass("player")
  m.class, m.level = class, UnitLevel("player")
  return m
end
ns.Member = function() return db and me() or nil end

-- ---- loot wishlist ---------------------------------------------------------------
-- Each wish has a kind: "ms" main spec, "os" off spec, "tm" transmog.
ns.WISH_KINDS = { "ms", "os", "tm" }
ns.WISH_LABEL = { ms = "Main spec", os = "Off spec", tm = "Transmog" }
ns.WISH_COLOR = { ms = "|cffff9a3c", os = "|cff6fb7ff", tm = "|cffd58cff" }

-- Picks made on the guild website for a character with this name (from the snapshot).
local function webWishes()
  local site = ns.Site and ns.Site()
  local rows = site and type(site.webWishes) == "table" and site.webWishes[UnitName("player")] or {}
  local out = {}
  for _, r in ipairs(rows) do
    if type(r) == "table" and r[1] then out[#out + 1] = { i = r[1], k = r[2], n = r[3], b = r[4], d = r[5], web = true } end
  end
  return out
end

function ns.WishKind(itemID)
  if not db then return nil end
  local m = me()
  for _, w in ipairs(m.wishlist) do if w.i == itemID then return w.k or "ms" end end
  m.webRemoved = m.webRemoved or {}
  if not m.webRemoved[itemID] then
    for _, w in ipairs(webWishes()) do if w.i == itemID then return w.k or "ms" end end
  end
  return nil
end
function ns.IsWished(itemID) return ns.WishKind(itemID) ~= nil end

-- kind: "ms" / "os" / "tm", or nil to take it off the list
function ns.SetWish(itemID, kind, name, boss, dungeon)
  local m = me()
  local list = m.wishlist
  -- a website pick changed in game: the game's choice wins from now on
  m.webRemoved = m.webRemoved or {}
  for _, w in ipairs(webWishes()) do
    if w.i == itemID then
      m.webRemoved[itemID] = true
      if kind and not name then name, boss, dungeon = w.n, w.b, w.d end
    end
  end
  for i, w in ipairs(list) do
    if w.i == itemID then
      if kind then w.k = kind else table.remove(list, i) end
      ns.Changed(); return kind
    end
  end
  if kind then list[#list + 1] = { i = itemID, k = kind, n = name, b = boss, d = dungeon }; ns.Changed() end
  return kind
end

-- The star cycles: not wanted -> main spec -> off spec -> transmog -> not wanted
function ns.CycleWish(itemID, name, boss, dungeon)
  local cur = ns.WishKind(itemID)
  local nextKind = (cur == nil and "ms") or (cur == "ms" and "os") or (cur == "os" and "tm") or nil
  return ns.SetWish(itemID, nextKind, name, boss, dungeon)
end

-- Your wishlist: picks made in game, plus website picks for this character's name.
function ns.Wishlist()
  if not db then return {} end
  local m = me()
  local out, seen = {}, {}
  for _, w in ipairs(m.wishlist) do out[#out + 1] = w; seen[w.i] = true end
  m.webRemoved = m.webRemoved or {}
  for _, w in ipairs(webWishes()) do
    if not seen[w.i] and not m.webRemoved[w.i] then out[#out + 1] = w; seen[w.i] = true end
  end
  return out
end

-- Guildmates who want an item (from the website snapshot), without you:
-- "Silver (main spec), Kagor (transmog)" or nil
function ns.WantedBy(itemID)
  local site = ns.Site and ns.Site()
  local s = site and type(site.wants) == "table" and site.wants[itemID]
  if type(s) ~= "string" or s == "" then return nil end
  local mine, out = UnitName("player"), {}
  for entry in s:gmatch("[^,]+") do
    entry = entry:gsub("^%s+", ""):gsub("%s+$", "")
    if entry:match("^[^%s(]+") ~= mine then out[#out + 1] = entry end
  end
  return #out > 0 and table.concat(out, ", ") or nil
end

-- ---- wanting to run a dungeon ------------------------------------------------------
function ns.IsLfg(slug)
  if not db then return false end
  for _, s in ipairs(me().lfg) do if s == slug then return true end end
  return false
end

function ns.ToggleLfg(slug)
  local list = me().lfg
  for i, s in ipairs(list) do
    if s == slug then table.remove(list, i); ns.Changed(); return false end
  end
  list[#list + 1] = slug
  ns.Changed()
  return true
end

-- Everyone who wants a dungeon: you (if you do) plus guildmates from the snapshot.
-- { { name, level, class, me = true }, ... }
function ns.LfgFor(slug)
  local out, seen = {}, {}
  local mine = UnitName("player")
  if ns.IsLfg(slug) then
    local _, class = UnitClass("player")
    out[1] = { name = mine, level = UnitLevel("player"), class = class, me = true }; seen[mine] = true
  end
  local site = ns.Site and ns.Site()
  for _, r in ipairs(site and type(site.lfg) == "table" and site.lfg[slug] or {}) do
    if not seen[r[1]] then seen[r[1]] = true; out[#out + 1] = { name = r[1], level = (r[2] or 0) > 0 and r[2] or nil, class = r[3] ~= "" and r[3] or nil } end
  end
  return out
end

-- ---- map pins from notes ---------------------------------------------------------------
function ns.IsPinned(note)
  if not db or not note then return false end
  for _, p in ipairs(me().pins) do if p.id == note.id then return true end end
  return false
end

-- Share a note's location with the guild as a map pin (or take it back). The note needs a
-- map position (Add location outdoors).
function ns.TogglePin(note)
  local list = me().pins
  for i, p in ipairs(list) do
    if p.id == note.id then table.remove(list, i); ns.Changed(); if ns.RefreshMapPins then ns.RefreshMapPins() end; return false end
  end
  local l = note.loc
  if not (l and l.map and l.x) then return nil end
  list[#list + 1] = { id = note.id, t = (ns.NoteTitle and ns.NoteTitle(note) or ""):sub(1, 200), zone = l.zone, map = l.map, x = l.x, y = l.y, at = note.at }
  while #list > 40 do table.remove(list, 1) end
  ns.Changed()
  if ns.RefreshMapPins then ns.RefreshMapPins() end
  return true
end

-- ---- quests: done, in your log, or not picked up -------------------------------------
function ns.QuestState(questID)
  if type(questID) ~= "number" then return nil end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
    local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
    if ok and done == true then return "done" end
  elseif IsQuestFlaggedCompleted then
    local ok, done = pcall(IsQuestFlaggedCompleted, questID)
    if ok and done == true then return "done" end
  end
  if C_QuestLog and C_QuestLog.IsOnQuest then
    local ok, on = pcall(C_QuestLog.IsOnQuest, questID)
    if ok and on == true then return "have" end
  elseif C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
    local ok, idx = pcall(C_QuestLog.GetLogIndexForQuestID, questID)
    if ok and idx then return "have" end
  end
  return nil
end

-- A dungeon's quests for your faction, counted: total, done, in your log, and the ones to pick up.
function ns.QuestProgress(dungeonName)
  local site = ns.Site and ns.Site()
  local rows = site and type(site.quests) == "table" and site.quests[ns.Slug(dungeonName)]
  if not rows then return nil end
  local faction = UnitFactionGroup and UnitFactionGroup("player")
  local f = faction == "Alliance" and "A" or faction == "Horde" and "H" or nil
  local p = { total = 0, done = 0, have = 0, missing = {} }
  for _, q in ipairs(rows) do
    if q[3] == "" or not f or q[3] == f then
      p.total = p.total + 1
      local st = ns.QuestState(q[1])
      if st == "done" then p.done = p.done + 1
      elseif st == "have" then p.have = p.have + 1
      else p.missing[#p.missing + 1] = q[2] end
    end
  end
  return p
end

ns.RegisterModule({
  name = "Member",
  OnLoad = function(_, saved) db = saved end,
  events = {
    PLAYER_LOGIN = function() me() end,
    PLAYER_LEVEL_UP = function() C_Timer.After(1, function() me(); ns.Changed() end) end,
  },
})
