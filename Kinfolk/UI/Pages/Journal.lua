-- Page: Journal. Every dungeon: its map with boss pins, each boss's
-- description, abilities and loot (from the game's own Encounter Journal),
-- the guild's tips (written on the website), and the guild's own record.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local LIST_W, PAD = 220, 16
local ROLE_TAG = { tank = "Tank", damage = "DPS", healer = "Healer", deadly = "Deadly", important = "Important",
  interruptible = "Interrupt", magic = "Magic", curse = "Curse", poison = "Poison", disease = "Disease", enrage = "Enrage" }

local page = { key = "journal", label = "Journal", section = "log", order = 30 }
local selDungeon, selBoss, selFloor

local function hex(r, g, b) return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) end

-- Journal dungeons from the game, plus dungeons you've run that the journal lacks.
local function dungeonList()
  local list, byName = {}, {}
  for _, d in ipairs(ns.db and ns.db.journal and ns.db.journal.dungeons or {}) do
    local e = { name = d.name, journal = d }
    list[#list + 1] = e; byName[d.name] = e
  end
  for _, s in ipairs(ns.Stats.Dungeons()) do
    if byName[s.name] then byName[s.name].stats = s
    else local e = { name = s.name, stats = s }; list[#list + 1] = e; byName[s.name] = e end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

-- Bosses: the journal's, or the ones killed in your runs. Pins: journal, else where the map recorder saw them.
local function bossesOf(e)
  local bosses = {}
  if e.journal then
    for i, b in ipairs(e.journal.bosses) do bosses[#bosses + 1] = { name = b.name, n = i, j = b, pins = b.pins } end
  else
    local seen = {}
    for _, r in ipairs(e.stats and e.stats.runs or {}) do
      for _, b in ipairs(r.bosses or {}) do
        if not seen[b.name] then seen[b.name] = true; bosses[#bosses + 1] = { name = b.name, n = #bosses + 1, pins = {} } end
      end
      for map, list in pairs(r.route and r.route.pins or {}) do
        for _, p in ipairs(list) do
          for _, b in ipairs(bosses) do if b.name == p.name and #b.pins == 0 then b.pins[1] = { m = tonumber(map), x = p.x, y = p.y } end end
        end
      end
    end
  end
  return bosses
end

local function floorsOf(e)
  if e.journal and #(e.journal.floors or {}) > 0 then return e.journal.floors end
  local list, seen = {}, {}
  for _, r in ipairs(e.stats and e.stats.runs or {}) do
    for _, f in ipairs(r.route and r.route.floors or {}) do
      if not seen[f.map] then seen[f.map] = true; list[#list + 1] = { map = f.map, name = f.name } end
    end
  end
  return list
end

-- The guild's record against one boss, from fight breakdowns.
local function bossRecord(e, name)
  local kills, wipes, fastest = 0, 0, nil
  for _, r in ipairs(e.stats and e.stats.runs or {}) do
    for _, s in ipairs(r.segments or {}) do
      if s.kind == "boss" and s.label == name then
        if s.kill then kills = kills + 1; if not fastest or s.duration < fastest then fastest = s.duration end else wipes = wipes + 1 end
      end
    end
  end
  return kills, wipes, fastest
end

local function itemName(id)
  if C_Item and C_Item.GetItemNameByID then local n = C_Item.GetItemNameByID(id); if n then return n end end
  if GetItemInfo then local n = GetItemInfo(id); if n then return n end end
  return "Item " .. id
end

local function detailText(e, boss)
  local ar, ag, ab = UI.Accent()
  local head = hex(ar, ag, ab)
  local dim = hex(C.dim[1], C.dim[2], C.dim[3])
  local lines = {}
  local function section(title) lines[#lines + 1] = "\n" .. head .. title .. "|r" end
  local j = boss.j
  if j and j.desc and j.desc ~= "" then lines[#lines + 1] = j.desc end

  if j and #j.sections > 0 then
    section("Abilities")
    for _, s in ipairs(j.sections) do
      local tags = {}
      for flag in (s.flags or ""):gmatch("[^,]+") do if ROLE_TAG[flag] then tags[#tags + 1] = "[" .. ROLE_TAG[flag] .. "]" end end
      lines[#lines + 1] = string.rep("    ", s.depth or 0) .. "• |cffffffff" .. (s.t or "") .. "|r" .. (#tags > 0 and ("  " .. dim .. table.concat(tags, " ") .. "|r") or "")
      if s.d and s.d ~= "" then lines[#lines + 1] = string.rep("    ", (s.depth or 0) + 1) .. dim .. s.d .. "|r" end
    end
  end

  -- guild tips come from the website snapshot (written by guild members)
  local site = ns.Site()
  local tips = {}
  for _, t in ipairs(site and site.tips or {}) do
    if t[1] == ns.Slug(e.name) and t[2] == boss.name then tips[#tips + 1] = t end
  end
  section("Guild tips")
  if #tips > 0 then
    local order = { tank = 1, damage = 2, healer = 3, all = 4 }
    table.sort(tips, function(a, b) return (order[a[3]] or 9) < (order[b[3]] or 9) end)
    for _, t in ipairs(tips) do
      lines[#lines + 1] = "|cffffffff" .. (ROLE_TAG[t[3]] or "Everyone") .. ":|r " .. t[4] .. (t[5] and t[5] ~= "" and (dim .. "  (" .. t[5] .. ")|r") or "")
    end
  else
    lines[#lines + 1] = dim .. "No tips yet. Guild members add them on the website's Journal page, then they show here after a sync.|r"
  end

  if j and #j.loot > 0 then
    section("Loot")
    local names = {}
    for _, id in ipairs(j.loot) do names[#names + 1] = itemName(id) end
    lines[#lines + 1] = table.concat(names, ", ")
  end

  local kills, wipes, fastest = bossRecord(e, boss.name)
  section("The guild's record")
  if kills + wipes > 0 then
    lines[#lines + 1] = string.format("%d %s, %d %s%s", kills, kills == 1 and "kill" or "kills", wipes, wipes == 1 and "wipe" or "wipes",
      fastest and (", fastest kill " .. UI.Time(fastest)) or "")
  else
    lines[#lines + 1] = dim .. "No fights against this boss in your logged runs yet.|r"
  end
  if not j then lines[#lines + 1] = "\n" .. dim .. "Description, abilities and loot come from the game's journal: type /kin journaltest.|r" end
  return table.concat(lines, "\n")
end

function page:Build(f)
  self.list = UI.List(f, 44, function(r)
    r.name = UI.Text(r, 13); r.name:SetPoint("TOPLEFT", 14, -7); r.name:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    r.sub = UI.Text(r, 11, C.dim); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
    r:SetScript("OnClick", function(row) selDungeon, selBoss, selFloor = row.dname, nil, nil; ns.RefreshUI() end)
  end, function(r, e)
    r.dname = e.name
    r.name:SetText(e.name)
    local bits = {}
    if e.journal then bits[#bits + 1] = #e.journal.bosses .. " bosses" end
    if e.stats then bits[#bits + 1] = #e.stats.runs .. (#e.stats.runs == 1 and " run" or " runs") end
    if e.stats and e.stats.best then bits[#bits + 1] = "best " .. UI.Time(e.stats.best.duration) end
    r.sub:SetText(table.concat(bits, ", "))
    self.list:Select(r, e.name == selDungeon)
  end)
  self.list:SetPoint("TOPLEFT"); self.list:SetPoint("BOTTOMLEFT"); self.list:SetWidth(LIST_W)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })

  self.title = UI.Text(f, 20)
  self.sub = UI.Text(f, 12, C.dim); self.sub:SetWordWrap(true)
  self.floorButtons = {}
  self.map = UI.MapCanvas(f)
  self.map.onPin = function(name) selBoss = name; ns.RefreshUI() end
  self.mapNote = UI.Text(f, 11, C.faint); self.mapNote:SetWordWrap(true)

  self.bosses = UI.List(f, 30, function(r)
    r.n = UI.Text(r, 11, C.faint); r.n:SetPoint("LEFT", 10, 0)
    r.name = UI.Text(r, 13); r.name:SetPoint("LEFT", 30, 0); r.name:SetPoint("RIGHT", r, "RIGHT", -8, 0)
    r:SetScript("OnClick", function(row) selBoss = row.bname; ns.RefreshUI() end)
  end, function(r, b)
    r.bname = b.name
    r.n:SetText(b.n); r.name:SetText(b.name)
    self.bosses:Select(r, b.name == selBoss)
  end)
  UI.Fill(self.bosses, { 0, 0, 0, 0.12 })

  -- boss detail: one rich text block in a scroll frame
  self.scroll = CreateFrame("ScrollFrame", nil, f)
  self.scroll:EnableMouseWheel(true)
  self.detail = CreateFrame("Frame", nil, self.scroll)
  self.scroll:SetScrollChild(self.detail)
  self.bossTitle = UI.Text(self.detail, 16)
  self.bossTitle:SetPoint("TOPLEFT", 0, 0)
  self.body = UI.Text(self.detail, 12, C.text)
  self.body:SetPoint("TOPLEFT", self.bossTitle, "BOTTOMLEFT", 0, -8)
  self.body:SetWordWrap(true); self.body:SetJustifyV("TOP")
  self.scroll:SetScript("OnMouseWheel", function(s, d)
    local max = math.max(0, (self.detail:GetHeight() or 0) - (s:GetHeight() or 0))
    s:SetVerticalScroll(math.max(0, math.min(max, (s:GetVerticalScroll() or 0) - d * 40)))
  end)

  self.empty = UI.Text(f, 13, C.dim, "CENTER"); self.empty:SetWordWrap(true)
  self.empty:SetText("No dungeons yet.\n\nType /kin journaltest to read the game's dungeon journal, or run a dungeon and it appears here.")
end

function page:Layout(w, h)
  self.w, self.h = w, h
  local x, dw = LIST_W + PAD + 1, w - LIST_W - PAD * 2 - 1
  self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", x, -PAD)
  self.sub:ClearAllPoints(); self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -6); self.sub:SetWidth(dw)
  -- map on the left (3:2), bosses + detail on the right
  local mapW = math.floor(dw * 0.56)
  local mapH = math.floor(mapW / 1.5)
  local top = -PAD - 84
  if mapH > h + top - PAD - 30 then mapH = h + top - PAD - 30; mapW = math.floor(mapH * 1.5) end
  self.mapX, self.mapY, self.mapW, self.mapH = x, top, mapW, mapH
  self.map:ClearAllPoints(); self.map:SetPoint("TOPLEFT", x, top)
  self.mapNote:ClearAllPoints(); self.mapNote:SetPoint("TOPLEFT", x, top - mapH - 6); self.mapNote:SetWidth(mapW)
  local rx, rw = x + mapW + 16, dw - mapW - 16
  local bossH = math.min(30 * 8, math.floor((h + top - PAD) * 0.4))
  self.bosses:ClearAllPoints(); self.bosses:SetPoint("TOPLEFT", rx, top - 32); self.bosses:SetSize(rw, bossH)
  self.scroll:ClearAllPoints(); self.scroll:SetPoint("TOPLEFT", rx, top - 32 - bossH - 12); self.scroll:SetSize(rw, h + top - 32 - bossH - 12 - PAD)
  self.detail:SetWidth(rw - 8)
  self.bossTitle:SetWidth(rw - 8); self.body:SetWidth(rw - 8)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER", LIST_W / 2, 0); self.empty:SetWidth(dw - 40)
end

function page:Refresh()
  local list = dungeonList()
  local e
  for _, x in ipairs(list) do if x.name == selDungeon then e = x end end
  if not e then e = list[1]; selDungeon = e and e.name end
  self.list:SetItems(list)
  local has = e ~= nil
  for _, el in ipairs({ self.title, self.sub, self.map, self.mapNote, self.bosses, self.scroll }) do el:SetShown(has) end
  self.empty:SetShown(not has)
  for _, b in ipairs(self.floorButtons) do b:Hide() end
  if not has then return end

  self.title:SetText(e.name)
  local s = e.stats
  self.sub:SetText(s and string.format("%d %s logged.  Fastest clear %s, typical %s, %.1f wipes per run.", #s.runs, #s.runs == 1 and "run" or "runs",
    s.best and UI.Time(s.best.duration) or "—", s.typical and UI.Time(s.typical) or "—", s.wipes / #s.runs)
    or ((e.journal and e.journal.desc) or "Not run by the guild yet."))

  -- floors
  local floors = floorsOf(e)
  local valid = false
  for _, fl in ipairs(floors) do if fl.map == selFloor then valid = true end end
  if not valid then selFloor = floors[1] and floors[1].map end
  local bx = self.mapX
  for i, fl in ipairs(floors) do
    local b = self.floorButtons[i]
    if not b then b = UI.Button(self.list:GetParent(), "", 80, 24, function(btn) selFloor = btn.map; ns.RefreshUI() end); self.floorButtons[i] = b end
    b.map = fl.map
    b.label:SetText(fl.name or ("Floor " .. i))
    b:SetWidth(math.min(170, b.label:GetStringWidth() + 20))
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", bx, self.mapY + 30)
    if fl.map == selFloor then b.label:SetTextColor(UI.Accent()) else b.label:SetTextColor(unpack(C.text)) end
    bx = bx + b:GetWidth() + 6
    b:SetShown(#floors > 1)
  end

  -- bosses and their pins on this floor
  local bosses = bossesOf(e)
  local found = false
  for _, b in ipairs(bosses) do if b.name == selBoss then found = true end end
  if not found then selBoss = bosses[1] and bosses[1].name end
  self.bosses:SetItems(bosses)
  local pins = {}
  for _, b in ipairs(bosses) do
    for _, p in ipairs(b.pins or {}) do
      if p.m == selFloor then pins[#pins + 1] = { x = p.x, y = p.y, n = b.n, key = b.name, label = b.name, sub = "Click for abilities, loot and tips", on = b.name == selBoss } end
    end
  end
  local art = self.map:Draw(selFloor, self.mapW or 400, self.mapH or 267, pins)
  self.mapNote:SetText(#floors == 0 and "No map floors known yet: run the dungeon or type /kin journaltest."
    or (#pins == 0 and "No boss locations on this floor." or "Numbers are the boss order. Click a pin or a name for details.") .. (art and "" or ""))

  local boss
  for _, b in ipairs(bosses) do if b.name == selBoss then boss = b end end
  self.bossTitle:SetText(boss and boss.name or "")
  self.body:SetText(boss and detailText(e, boss) or "No bosses known for this dungeon yet.")
  self.detail:SetHeight((self.bossTitle:GetStringHeight() or 20) + (self.body:GetStringHeight() or 200) + 16)
  self.scroll:SetVerticalScroll(0)
end

ns.RegisterPage(page)
