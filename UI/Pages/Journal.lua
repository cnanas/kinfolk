-- Page: Journal. Every dungeon: its map with boss pins, each boss's
-- description, abilities and loot (from the game's own Encounter Journal),
-- the guild's tips (written on the website), and the guild's own record.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local LIST_W, PAD = 220, 16
local ROLE_TAG = { tank = "Tank", damage = "DPS", healer = "Healer", deadly = "Deadly", important = "Important",
  interruptible = "Interrupt", magic = "Magic", curse = "Curse", poison = "Poison", disease = "Disease", enrage = "Enrage" }

local page = { key = "journal", label = "Dungeons", order = 30 }
local selDungeon, selBoss, selFloor
local jview = "bosses" -- or "quests", "runs"
local questsAll = false -- show the other faction's quests too

local function hex(r, g, b) return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) end

-- Every Forever dungeon and raid (Data/Dungeons.lua), the game's journal when it has data,
-- and anything else you've run. Sorted by level like the game's dungeon list; raids last.
local function dungeonList()
  local list, bySlug = {}, {}
  local function entry(name)
    local k = ns.Slug(name)
    if not bySlug[k] then bySlug[k] = { name = name }; list[#list + 1] = bySlug[k] end
    return bySlug[k]
  end
  for _, d in pairs(ns.Dungeons or {}) do entry(d.name).static = d end
  for _, d in ipairs(ns.db and ns.db.journal and ns.db.journal.dungeons or {}) do entry(d.name).journal = d end
  for _, st in ipairs(ns.Stats.Dungeons()) do entry(st.name).stats = st end
  local function lvl(e) return e.static and e.static.levels and e.static.levels[1] or 99 end
  table.sort(list, function(a, b)
    local ra, rb = a.static and a.static.raid and 1 or 0, b.static and b.static.raid and 1 or 0
    if ra ~= rb then return ra < rb end
    if lvl(a) ~= lvl(b) then return lvl(a) < lvl(b) end
    return a.name < b.name
  end)
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
    -- the rest of the dungeon's bosses, in the game's order
    for _, b in ipairs(e.static and e.static.bosses or {}) do
      if not seen[b.name] then seen[b.name] = true; bosses[#bosses + 1] = { name = b.name, n = #bosses + 1, pins = {} } end
    end
  end
  return bosses
end

-- What a boss looks like: a display ID Foxden noted in a fight (or a guildmate's, from the
-- website), else its NPC ID (Data/Dungeons.lua, or learned in a fight).
local function visual(e, name)
  local look, npc
  local looks, npcs = ns.db and ns.db.bossLooks or {}, ns.db and ns.db.bossNpc or {}
  for _, b in ipairs(e.static and e.static.bosses or {}) do
    if b.name == name then
      npc = b.npc
      for _, id in ipairs(b.ids or {}) do look = look or looks[id]; npc = npc or npcs[id] end
    end
  end
  local site = ns.Site()
  for _, r in ipairs(site and type(site.bosses) == "table" and site.bosses[ns.Slug(e.name)] or {}) do
    if r[2] == name then
      if not look and (r[3] or 0) > 0 then look = r[3] end
      if not npc and (r[4] or 0) > 0 then npc = r[4] end
      look = look or looks[r[1]]; npc = npc or npcs[r[1]]
    end
  end
  for _, run in ipairs(e.stats and e.stats.runs or {}) do
    for _, k in ipairs(run.bosses or {}) do if k.name == name then look = look or k.look; npc = npc or k.npc end end
  end
  return look, npc
end

local function floorsOf(e)
  if e.journal and #(e.journal.floors or {}) > 0 then return e.journal.floors end
  local list, seen = {}, {}
  for _, r in ipairs(e.stats and e.stats.runs or {}) do
    for _, f in ipairs(r.route and r.route.floors or {}) do
      local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(f.map)
      local isDungeonMap = not info or not info.mapType or info.mapType >= 4 -- 4 = dungeon, 5 = micro
      if isDungeonMap and not seen[f.map] then seen[f.map] = true; list[#list + 1] = { map = f.map, name = f.name } end
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
  local loot, note = {}, nil -- loot rows are drawn as item buttons below the text
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
  if not j then
    -- loot the guild has seen drop from this boss (recorded in runs)
    local count, order = {}, {}
    for _, r in ipairs(e.stats and e.stats.runs or {}) do
      for _, l in ipairs(r.loot or {}) do
        if l.b == boss.name and l.i then
          if not count[l.i] then order[#order + 1] = l.i end
          count[l.i] = (count[l.i] or 0) + 1
        end
      end
    end
    -- plus the website's list (QuestieDB for classic dungeons, and the whole guild's drops)
    local site = ns.Site()
    local listed = site and type(site.loot) == "table" and site.loot[ns.Slug(e.name)] and site.loot[ns.Slug(e.name)][boss.name]
    local names = {}
    for _, it in ipairs(listed or {}) do
      if type(it) == "table" and it[1] then
        names[it[1]] = it[2]
        if not count[it[1]] then order[#order + 1] = it[1]; count[it[1]] = 0 end
      end
    end
    for _, id in ipairs(order) do loot[#loot + 1] = { id = id, seen = count[id], name = names[id] } end
    local n = {}
    if #order == 0 then n[#n + 1] = "Nothing recorded yet. Foxden notes what this boss drops in your runs." end
    if listed and #listed > 0 then n[#n + 1] = "Loot tables for classic dungeons: QuestieDB (GPLv3)." end
    if e.static then n[#n + 1] = "Boss list: ForeverDungeonRoutes by Checkov23 (MIT)." end
    note = table.concat(n, "\n")
  end
  return table.concat(lines, "\n"), loot, note
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
    if e.static and e.static.levels and #e.static.levels == 2 then bits[#bits + 1] = "levels " .. e.static.levels[1] .. "-" .. e.static.levels[2] end
    local nb = e.journal and #e.journal.bosses or (e.static and #e.static.bosses) or 0
    if nb > 0 then bits[#bits + 1] = nb .. " bosses" end
    if e.stats then bits[#bits + 1] = #e.stats.runs .. (#e.stats.runs == 1 and " run" or " runs") end
    if e.stats and e.stats.best then bits[#bits + 1] = "best " .. UI.Time(e.stats.best.duration) end
    r.sub:SetText(table.concat(bits, ", "))
    self.list:Select(r, e.name == selDungeon)
  end)
  self.list:SetPoint("TOPLEFT"); self.list:SetPoint("BOTTOMLEFT"); self.list:SetWidth(LIST_W)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })

  self.title = UI.Text(f, 20)
  self.sub = UI.Text(f, 12, C.dim); self.sub:SetWordWrap(true)
  self.lfg = UI.Button(f, "I want to run this", 150, 24, function()
    if not selDungeon then return end
    local on = ns.ToggleLfg(ns.Slug(selDungeon))
    ns.say(on and ("You're listed as wanting " .. selDungeon .. ". Guildmates see it after your next sync.") or ("You're no longer listed for " .. selDungeon .. "."))
    ns.RefreshUI()
  end)
  self.lfgWho = UI.Text(f, 11, C.dim); self.lfgWho:SetWordWrap(false)
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
  -- the boss's own model, drawn by the game
  self.portraitBox = CreateFrame("Frame", nil, self.detail); self.portraitBox:SetSize(76, 76); self.portraitBox:SetPoint("TOPLEFT")
  UI.Fill(self.portraitBox, C.surface); UI.Border(self.portraitBox)
  self.portrait = CreateFrame("PlayerModel", nil, self.portraitBox); self.portrait:SetPoint("TOPLEFT", 1, -1); self.portrait:SetPoint("BOTTOMRIGHT", -1, 1)
  self.portraitBox:Hide()
  self.body = UI.Text(self.detail, 12, C.text)
  self.body:SetPoint("TOPLEFT", 0, -28)
  self.body:SetWordWrap(true); self.body:SetJustifyV("TOP")
  self.lootHead = UI.Text(self.detail, 12); UI.Accented(self.lootHead); self.lootHead:SetText("Loot")
  self.lootNote = UI.Text(self.detail, 11, C.dim); self.lootNote:SetWordWrap(true); self.lootNote:SetJustifyV("TOP")
  self.lootRows = {}
  self.scroll:SetScript("OnMouseWheel", function(s, d)
    local max = math.max(0, (self.detail:GetHeight() or 0) - (s:GetHeight() or 0))
    s:SetVerticalScroll(math.max(0, math.min(max, (s:GetVerticalScroll() or 0) - d * 40)))
  end)

  -- Bosses / Quests
  self.viewTabs = {}
  for _, v in ipairs({ { "bosses", "Bosses" }, { "quests", "Quests" }, { "runs", "Runs" } }) do
    local b = CreateFrame("Button", nil, f)
    b.key = v[1]
    b.bg = UI.Fill(b, C.raised); b.bg:Hide()
    b.text = UI.Text(b, 12, C.dim, "CENTER"); b.text:SetPoint("CENTER"); b.text:SetText(v[2])
    b.under = b:CreateTexture(nil, "ARTWORK"); b.under:SetPoint("BOTTOMLEFT"); b.under:SetPoint("BOTTOMRIGHT"); b.under:SetHeight(2)
    b:SetSize(92, 26)
    b:SetScript("OnClick", function() jview = v[1]; ns.RefreshUI() end)
    self.viewTabs[#self.viewTabs + 1] = b
  end
  -- this dungeon's runs
  self.runList = UI.List(f, 44, function(r)
    r.name = UI.Text(r, 13); r.name:SetPoint("TOPLEFT", 14, -7)
    r.sub = UI.Text(r, 11, C.dim); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
    r.time = UI.Text(r, 13, C.text, "RIGHT"); r.time:SetPoint("TOPRIGHT", -14, -7)
    r.meta = UI.Text(r, 11, C.dim, "RIGHT"); r.meta:SetPoint("TOPRIGHT", r.time, "BOTTOMRIGHT", 0, -4)
    r:SetScript("OnClick", function(row) ns.OpenPage("runs", row.id) end)
  end, function(r, run)
    r.id = run.id
    r.name:SetText(run.endTime and date("%b %d, %H:%M", run.endTime) or "Run")
    local names = {}
    for _, m in ipairs(run.party or {}) do names[#names + 1] = m.name end
    r.sub:SetText(#names > 0 and table.concat(names, ", ") or (run.loggedBy and ("Logged by " .. run.loggedBy) or ""))
    r.time:SetText(UI.Time(run.duration or 0))
    local b, w = run.bosses and #run.bosses or 0, run.wipes or 0
    r.meta:SetText(b .. (b == 1 and " boss" or " bosses") .. (w > 0 and (", " .. w .. (w == 1 and " wipe" or " wipes")) or ""))
  end)
  UI.Fill(self.runList, { 0, 0, 0, 0.12 })
  self.runEmpty = UI.Text(f, 12, C.dim); self.runEmpty:SetWordWrap(true)
  self.runEmpty:SetText("No runs of this dungeon logged yet. Walk in and Foxden records it on its own.")

  self.qscroll = CreateFrame("ScrollFrame", nil, f)
  self.qscroll:EnableMouseWheel(true)
  self.qbody = CreateFrame("Frame", nil, self.qscroll)
  self.qscroll:SetScrollChild(self.qbody)
  self.qblocks = {}
  self.qempty = UI.Text(self.qbody, 12, C.dim); self.qempty:SetPoint("TOPLEFT"); self.qempty:SetWordWrap(true)
  self.qfilter = UI.Button(self.qbody, "Show both factions", 150, 24, function() questsAll = not questsAll; ns.RefreshUI() end)
  self.qfilter:SetPoint("TOPLEFT")
  self.qfilterNote = UI.Text(self.qbody, 11, C.dim); self.qfilterNote:SetPoint("LEFT", self.qfilter, "RIGHT", 12, 0)
  self.qnote = UI.Text(self.qbody, 11, C.faint); self.qnote:SetWordWrap(true)
  self.qnote:SetText("Quest text and rewards: Blizzard Entertainment. Quest givers, locations, levels and objectives: QuestieDB (GPLv3) for classic dungeons; for the new dungeons, Foxden learns where quests start and end as the guild picks them up and turns them in. ")
  self.qscroll:SetScript("OnMouseWheel", function(s, d)
    local max = math.max(0, (self.qbody:GetHeight() or 0) - (s:GetHeight() or 0))
    s:SetVerticalScroll(math.max(0, math.min(max, (s:GetVerticalScroll() or 0) - d * 40)))
  end)

  self.empty = UI.Text(f, 13, C.dim, "CENTER"); self.empty:SetWordWrap(true)
  self.empty:SetText("No dungeons yet. Run a dungeon and it appears here.")
end

function page:Layout(w, h)
  self.w, self.h = w, h
  local x, dw = LIST_W + PAD + 1, w - LIST_W - PAD * 2 - 1
  self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", x, -PAD); self.title:SetWidth(dw - 290)
  self.sub:ClearAllPoints(); self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -6); self.sub:SetWidth(dw)
  self.lfg:ClearAllPoints(); self.lfg:SetPoint("TOPLEFT", x, -PAD - 58)
  self.lfgWho:ClearAllPoints(); self.lfgWho:SetPoint("LEFT", self.lfg, "RIGHT", 10, 0); self.lfgWho:SetWidth(dw - 170)
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
  local tx = x + dw
  for i = #self.viewTabs, 1, -1 do
    local b = self.viewTabs[i]
    tx = tx - b:GetWidth()
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", tx, -PAD)
  end
  self.qscroll:ClearAllPoints(); self.qscroll:SetPoint("TOPLEFT", x, top + 30); self.qscroll:SetSize(dw, h + top + 30 - PAD)
  self.runList:ClearAllPoints(); self.runList:SetPoint("TOPLEFT", x, top + 30); self.runList:SetSize(dw, h + top + 30 - PAD)
  self.runEmpty:ClearAllPoints(); self.runEmpty:SetPoint("TOPLEFT", x + 14, top + 16); self.runEmpty:SetWidth(dw - 28)
  self.qbody:SetWidth(dw - 12); self.qempty:SetWidth(dw - 12)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER", LIST_W / 2, 0); self.empty:SetWidth(dw - 40)
end

-- ---- loot rows: the game's own item data (icon, quality colour, tooltip) ---------------
local waitingItems = false
local function itemLook(id, fallback)
  local name, link, quality
  if C_Item and C_Item.GetItemInfo then name, link, quality = C_Item.GetItemInfo(id)
  elseif GetItemInfo then name, link, quality = GetItemInfo(id) end
  if not name then
    waitingItems = true
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  end
  local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id)) or 134400
  return name or fallback or ("Item " .. id), link, quality, icon
end

local function lootRow(parent)
  local r = CreateFrame("Button", nil, parent); r:SetHeight(24)
  r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(20, 20); r.icon:SetPoint("LEFT")
  r.name = UI.Text(r, 12); r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
  -- wishlist star (boss loot only)
  r.star = CreateFrame("Button", nil, r); r.star:SetSize(20, 20); r.star:SetPoint("RIGHT", -2, 0)
  r.star.tex = r.star:CreateTexture(nil, "ARTWORK"); r.star.tex:SetAllPoints()
  r.star.tex:SetTexture("Interface\\Common\\ReputationStar"); r.star.tex:SetTexCoord(0, 0.5, 0, 0.5)
  r.star:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  r.star:SetScript("OnClick", function(b, which)
    local row = b:GetParent()
    if not row.id or not row.wish then return end
    local name = row.name:GetText()
    local kind
    if which == "RightButton" then kind = ns.SetWish(row.id, nil) else kind = ns.CycleWish(row.id, name, row.wish.boss, row.wish.dungeon) end
    ns.say(kind and (name .. ": on your wishlist as " .. ns.WISH_LABEL[kind]:lower() .. ".") or (name .. " removed from your wishlist."))
    ns.RefreshUI()
  end)
  r.star:SetScript("OnEnter", function(b)
    local kind = ns.WishKind(b:GetParent().id)
    GameTooltip:SetOwner(b, "ANCHOR_TOP")
    GameTooltip:SetText(kind and ("On your wishlist: " .. ns.WISH_LABEL[kind]) or "Add to your wishlist")
    GameTooltip:AddLine("Click to step through Main spec, Off spec, Transmog, off. Right-click removes it.", 1, 1, 1, true)
    GameTooltip:AddLine("Foxden reminds you at this boss, tells you when it drops, and shows guildmates what you want it for.", 0.7, 0.72, 0.78, true)
    GameTooltip:Show()
  end)
  r.star:SetScript("OnLeave", GameTooltip_Hide)
  r.star:Hide()
  r.seen = UI.Text(r, 11, C.dim, "RIGHT"); r.seen:SetPoint("RIGHT", r.star, "LEFT", -8, 0)
  local hover = UI.Fill(r, C.hover, "BACKGROUND"); hover:Hide()
  r:SetScript("OnEnter", function(self)
    hover:Show()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if not pcall(GameTooltip.SetItemByID, GameTooltip, self.id) then GameTooltip:AddLine(self.name:GetText() or "") end
    GameTooltip:AddLine("Shift-click to link it in chat.", 0.6, 0.63, 0.69)
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", function() hover:Hide(); GameTooltip:Hide() end)
  r:SetScript("OnClick", function(self)
    if IsModifiedClick and IsModifiedClick("CHATLINK") and self.link and ChatEdit_InsertLink then ChatEdit_InsertLink(self.link) end
  end)
  return r
end

function page:SetPortrait(look, npc)
  local m, box = self.portrait, self.portraitBox
  local key = look and ("d" .. look) or npc and ("n" .. npc) or nil
  if not key then box:Hide(); self.portraitKey = nil; return false end
  if self.portraitKey ~= key then
    self.portraitKey = key
    local ok = false
    if m.ClearModel then pcall(m.ClearModel, m) end
    if look and m.SetDisplayInfo then ok = pcall(m.SetDisplayInfo, m, look) end
    if not ok and npc and m.SetCreature then ok = pcall(m.SetCreature, m, npc) end
    if ok and m.SetPortraitZoom then pcall(m.SetPortraitZoom, m, 0.8) end
    self.portraitOk = ok
  end
  box:SetShown(self.portraitOk == true)
  return self.portraitOk == true
end

function page:LayoutLoot(loot, note)
  local w = self.detail:GetWidth() or 300
  local y = -((self.headH or 20) + 8 + (self.body:GetStringHeight() or 0) + 14)
  local shown = #loot > 0 or (note and note ~= "")
  self.lootHead:SetShown(#loot > 0 or (note or ""):find("Nothing recorded") ~= nil)
  local h = 0
  if self.lootHead:IsShown() then
    self.lootHead:ClearAllPoints(); self.lootHead:SetPoint("TOPLEFT", 0, y); y = y - 20; h = h + 20
  end
  waitingItems = false
  for i, it in ipairs(loot) do
    local r = self.lootRows[i] or lootRow(self.detail); self.lootRows[i] = r
    local name, link, quality, icon = itemLook(it.id, it.name)
    r.id, r.link = it.id, link
    r.icon:SetTexture(icon)
    r.name:SetText(name)
    local qr, qg, qb = 1, 1, 1
    if quality and C_Item and C_Item.GetItemQualityColor then qr, qg, qb = C_Item.GetItemQualityColor(quality)
    elseif quality and GetItemQualityColor then qr, qg, qb = GetItemQualityColor(quality) end
    r.name:SetTextColor(qr or 1, qg or 1, qb or 1)
    local kind, others = ns.WishKind and ns.WishKind(it.id), ns.WantedBy and ns.WantedBy(it.id)
    local wished = kind ~= nil
    local bits = {}
    if kind then bits[#bits + 1] = ns.WISH_COLOR[kind] .. ns.WISH_LABEL[kind] .. "|r" end
    if others then bits[#bits + 1] = "wanted by " .. others end
    if it.seen and it.seen > 0 then bits[#bits + 1] = "seen " .. it.seen .. "x" end
    r.seen:SetText(table.concat(bits, "  ·  "))
    r.wish = { boss = selBoss, dungeon = selDungeon }
    r.star:Show()
    r.star.tex:SetDesaturated(not wished); r.star.tex:SetAlpha(wished and 1 or 0.35)
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, y); r:SetWidth(w); r:Show()
    y = y - 26; h = h + 26
  end
  for i = #loot + 1, #self.lootRows do self.lootRows[i]:Hide() end
  self.lootNote:SetShown(shown and note ~= nil and note ~= "")
  if self.lootNote:IsShown() then
    self.lootNote:SetWidth(w); self.lootNote:SetText(note)
    self.lootNote:ClearAllPoints(); self.lootNote:SetPoint("TOPLEFT", 0, y - 6)
    h = h + 10 + (self.lootNote:GetStringHeight() or 14)
  end
  local key = tostring(selDungeon) .. "/" .. tostring(selBoss)
  if self.itemKey ~= key then self.itemKey, self.itemTries = key, 0 end
  if waitingItems and not self.itemWait and self.itemTries < 5 then
    self.itemTries = self.itemTries + 1
    -- item data arrives a moment later; redraw once it has
    self.itemWait = true
    C_Timer.After(0.6, function() self.itemWait = nil; if self.scroll:IsVisible() then ns.RefreshUI() end end)
  end
  return h + 14
end

-- ---- quests (from the website: Blizzard's quest text and rewards, QuestieDB givers) -----
-- row: { id, title, faction, level, minLevel, giver, area, map, x, y, ender, objective, after, xp, money, rep, items, choice, text }
local function questsOf(e)
  local site = ns.Site()
  local rows = site and type(site.quests) == "table" and site.quests[ns.Slug(e.name)] or {}
  local mine = UnitFactionGroup and UnitFactionGroup("player")
  local f = mine == "Alliance" and "A" or mine == "Horde" and "H" or nil
  local out = {}
  for _, q in ipairs(rows) do
    if type(q) == "table" and (questsAll or q[3] == "" or not f or q[3] == f) then out[#out + 1] = q end
  end
  return out, #rows
end

local FACTION = {
  A = "|cff4a8cffAlliance|r",
  H = "|cffe5483cHorde|r",
  [""] = "|cff99a1b0Both factions|r",
}

local function pinOnMap(map, x, y, name)
  if not (map and map > 0 and C_Map and C_Map.SetUserWaypoint and UiMapPoint) then return false end
  if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(map) then return false end
  local ok = pcall(function()
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
  end)
  if ok then ns.say(string.format("Map pin set on %s (%d, %d).", name, math.floor(x + 0.5), math.floor(y + 0.5))) end
  return ok
end

local function questBlock(parent)
  local b = CreateFrame("Frame", nil, parent)
  b.title = UI.Text(b, 14); b.title:SetPoint("TOPLEFT")
  b.meta = UI.Text(b, 11, C.dim, "RIGHT"); b.meta:SetPoint("TOPRIGHT")
  b.text = UI.Text(b, 12, C.text); b.text:SetWordWrap(true); b.text:SetJustifyV("TOP")
  b.pin = UI.Button(b, "Pin start", 96, 22, function(btn) local q = btn.q; if q then pinOnMap(q[8], q[9], q[10], q[6] ~= "" and q[6] or "the quest start") end end)
  b.pinEnd = UI.Button(b, "Pin turn-in", 104, 22, function(btn) local q = btn.q; if q then pinOnMap(q[20], q[21], q[22], q[11] ~= "" and q[11] or q[6] ~= "" and q[6] or "the turn-in") end end)
  b.pinEnd:SetPoint("LEFT", b.pin, "RIGHT", 8, 0)
  b.rows = {}
  b.story = UI.Text(b, 11, C.dim); b.story:SetWordWrap(true); b.story:SetJustifyV("TOP")
  b.line = b:CreateTexture(nil, "BORDER"); b.line:SetColorTexture(unpack(C.line)); b.line:SetHeight(1)
  return b
end

function page:LayoutQuests(e)
  local quests, totalQuests = questsOf(e)
  local w = (self.qbody:GetWidth() or 400)
  local mine = UnitFactionGroup and UnitFactionGroup("player") or "your faction"
  self.qfilter.label:SetText(questsAll and ("Show " .. mine .. " only") or "Show both factions")
  self.qfilter:SetWidth(self.qfilter.label:GetStringWidth() + 24)
  self.qfilterNote:SetText(questsAll and string.format("All %d quests", totalQuests) or string.format("%s and both-faction quests (%d of %d)", mine, #quests, totalQuests))
  self.qfilter:SetShown(totalQuests > 0); self.qfilterNote:SetShown(totalQuests > 0)
  local ar, ag, ab = UI.Accent()
  local head, dim = hex(ar, ag, ab), hex(C.dim[1], C.dim[2], C.dim[3])
  local y = totalQuests > 0 and 36 or 0
  waitingItems = false
  for i, q in ipairs(quests) do
    local b = self.qblocks[i] or questBlock(self.qbody); self.qblocks[i] = b
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -y); b:SetWidth(w); b:Show()
    b.title:SetText(q[2]); b.title:SetWidth(w - 130)
    local lvl = (q[4] or 0) > 0 and ("Level " .. q[4] .. (((q[5] or 0) > 0 and q[5] ~= q[4]) and (" (from " .. q[5] .. ")") or "")) or ""
    local st = ns.QuestState and ns.QuestState(q[1])
    local status = st == "done" and "|cff6fd39aDone|r   " or st == "have" and "|cffe8c35aIn your quest log|r   " or ""
    b.meta:SetText(status .. lvl .. (lvl ~= "" and "   " or "") .. (FACTION[q[3] or ""] or FACTION[""]))
    b.title:SetTextColor(unpack(st == "done" and C.faint or C.text))
    local lines = {}
    if q[6] ~= "" then
      local where = q[6] .. (q[7] ~= "" and (dim .. " in " .. q[7]) or "") .. ((q[9] or 0) > 0 and string.format(" (%d, %d)", math.floor(q[9] + 0.5), math.floor(q[10] + 0.5)) or "") .. (q[7] ~= "" and "|r" or "")
      lines[#lines + 1] = head .. "Get it from|r  " .. where .. ((q[11] ~= "" and (q[20] or 0) == 0) and (dim .. "; turn in to |r" .. q[11]) or "")
    end
    if (q[20] or 0) > 0 and (q[20] ~= q[8] or math.abs((q[21] or 0) - (q[9] or 0)) > 1 or math.abs((q[22] or 0) - (q[10] or 0)) > 1) then
      lines[#lines + 1] = head .. "Turn in to|r  " .. (q[11] ~= "" and q[11] or q[6]) .. dim .. string.format(" (%d, %d)", math.floor(q[21] + 0.5), math.floor(q[22] + 0.5)) .. "|r"
    end
    if q[12] ~= "" then lines[#lines + 1] = head .. "Objective|r  " .. q[12] end
    if q[13] ~= "" then lines[#lines + 1] = head .. "Needs first|r  " .. q[13] end
    local rew = {}
    if (q[14] or 0) > 0 then rew[#rew + 1] = UI.Num(q[14]) .. " XP" end
    if (q[15] or 0) > 0 then rew[#rew + 1] = ns.Money(q[15]) end
    if q[16] ~= "" then rew[#rew + 1] = q[16] .. " reputation" end
    if #rew > 0 then lines[#lines + 1] = head .. "Rewards|r  " .. table.concat(rew, ", ") end
    b.text:SetWidth(w); b.text:SetText(table.concat(lines, "\n"))
    b.text:ClearAllPoints(); b.text:SetPoint("TOPLEFT", 0, -22)
    local by = 22 + (b.text:GetStringHeight() or 0) + 6
    -- reward items: the game's own item data
    local items = {}
    for _, id in ipairs(q[17] or {}) do items[#items + 1] = { id = id } end
    local choice = q[18] or {}
    if #choice > 0 then items[#items + 1] = { label = "Choose one:" } end
    for _, id in ipairs(choice) do items[#items + 1] = { id = id } end
    local n = 0
    for _, it in ipairs(items) do
      n = n + 1
      local r = b.rows[n] or lootRow(b); b.rows[n] = r
      if it.label then
        r.id, r.link = nil, nil; r.icon:SetTexture(nil); r.name:SetText(dim .. it.label .. "|r"); r.name:SetTextColor(1, 1, 1); r.seen:SetText("")
        r:EnableMouse(false)
      else
        r:EnableMouse(true)
        local name, link, quality, icon = itemLook(it.id)
        r.id, r.link = it.id, link
        r.icon:SetTexture(icon); r.name:SetText(name); r.seen:SetText("")
        local qr, qg, qb = 1, 1, 1
        if quality and C_Item and C_Item.GetItemQualityColor then qr, qg, qb = C_Item.GetItemQualityColor(quality) end
        r.name:SetTextColor(qr or 1, qg or 1, qb or 1)
      end
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -by); r:SetWidth(w); r:Show()
      by = by + 26
    end
    for k = n + 1, #b.rows do b.rows[k]:Hide() end
    b.pin.q, b.pinEnd.q = q, q
    local hasStart, hasEnd = (q[8] or 0) > 0, (q[20] or 0) > 0
    b.pin:SetShown(hasStart); b.pinEnd:SetShown(hasEnd)
    b.pin:ClearAllPoints(); b.pin:SetPoint("TOPLEFT", 0, -by - 2)
    b.pinEnd:ClearAllPoints()
    if hasStart then b.pinEnd:SetPoint("LEFT", b.pin, "RIGHT", 8, 0) else b.pinEnd:SetPoint("TOPLEFT", 0, -by - 2) end
    if hasStart or hasEnd then by = by + 30 end
    b.story:SetWidth(w); b.story:SetText(q[19] or "")
    b.story:ClearAllPoints(); b.story:SetPoint("TOPLEFT", 0, -by - 2)
    by = by + ((q[19] or "") ~= "" and ((b.story:GetStringHeight() or 0) + 8) or 0)
    b.line:ClearAllPoints(); b.line:SetPoint("TOPLEFT", 0, -by - 8); b.line:SetPoint("TOPRIGHT", 0, -by - 8)
    b:SetHeight(by + 10)
    y = y + by + 22
  end
  for k = #quests + 1, #self.qblocks do self.qblocks[k]:Hide() end
  self.qempty:SetShown(#quests == 0)
  self.qempty:SetText(ns.Site() and ns.Site().quests and "No quests listed for this dungeon." or "Quests come from your guild's website: start the companion and type /fox sync.")
  self.qnote:ClearAllPoints(); self.qnote:SetPoint("TOPLEFT", 0, -y); self.qnote:SetWidth(w); self.qnote:SetShown(#quests > 0)
  self.qbody:SetHeight(y + 60)
  local key = "q/" .. tostring(selDungeon)
  if self.itemKey ~= key then self.itemKey, self.itemTries = key, 0 end
  if waitingItems and not self.itemWait and self.itemTries < 5 then
    self.itemTries = self.itemTries + 1
    self.itemWait = true
    C_Timer.After(0.6, function() self.itemWait = nil; if self.qscroll:IsVisible() then ns.RefreshUI() end end)
  end
  return #quests
end

function page:Refresh(arg)
  local list = dungeonList()
  if type(arg) == "table" and arg.dungeon then
    -- a jump from search or Home: pick the dungeon (and boss or tab) and scroll to it
    local want = ns.Slug(arg.dungeon)
    for i, x in ipairs(list) do
      if ns.Slug(x.name) == want then
        selDungeon, selBoss, selFloor = x.name, arg.boss, nil
        jview = arg.view or "bosses"
        self.list.offset = math.max(0, i - 3)
      end
    end
  end
  local e
  for _, x in ipairs(list) do if x.name == selDungeon then e = x end end
  if not e then e = list[1]; selDungeon = e and e.name end
  self.list:SetItems(list)
  local has = e ~= nil
  for _, el in ipairs({ self.title, self.sub, self.map, self.mapNote, self.bosses, self.scroll, self.lfg, self.lfgWho }) do el:SetShown(has) end
  self.empty:SetShown(not has)
  for _, t in ipairs(self.viewTabs) do t:SetShown(has) end
  self.runList:SetShown(has and jview == "runs"); self.runEmpty:Hide()
  self.qscroll:SetShown(has and jview == "quests")
  for _, b in ipairs(self.floorButtons) do b:Hide() end
  if not has then return end

  self.title:SetText(e.name)
  local slug = ns.Slug(e.name)
  local wantIt = ns.IsLfg and ns.IsLfg(slug)
  self.lfg.label:SetText(wantIt and "You want to run this" or "I want to run this")
  if wantIt then self.lfg.label:SetTextColor(UI.Accent()) else self.lfg.label:SetTextColor(unpack(C.text)) end
  local seekers, names = ns.LfgFor and ns.LfgFor(slug) or {}, {}
  for _, sk in ipairs(seekers) do names[#names + 1] = (sk.me and "you" or sk.name) .. (sk.level and (" " .. sk.level) or "") end
  self.lfgWho:SetText(#names > 0 and ("Want to run it: " .. table.concat(names, ", ")) or "Nobody has asked for this one yet.")
  local nq = #questsOf(e)
  local ar, ag, ab = UI.Accent()
  for _, t in ipairs(self.viewTabs) do
    local on = t.key == jview
    t.bg:SetShown(on); t.under:SetShown(on); t.under:SetColorTexture(ar, ag, ab, 1)
    t.text:SetTextColor(unpack(on and C.text or C.dim))
    if t.key == "quests" then
      local qp = ns.QuestProgress and ns.QuestProgress(e.name)
      t.text:SetText(qp and qp.total > 0 and ("Quests (" .. qp.done .. "/" .. qp.total .. ")") or nq > 0 and ("Quests (" .. nq .. ")") or "Quests")
    end
    if t.key == "runs" then local nr = e.stats and #e.stats.runs or 0; t.text:SetText(nr > 0 and ("Runs (" .. nr .. ")") or "Runs") end
    t:Show()
  end
  local questsOn, runsOn = jview == "quests", jview == "runs"
  for _, el in ipairs({ self.map, self.mapNote, self.bosses, self.scroll }) do el:SetShown(not questsOn and not runsOn) end
  self.qscroll:SetShown(questsOn)
  self.runList:SetShown(runsOn); self.runEmpty:Hide()
  if runsOn then
    for _, b in ipairs(self.floorButtons) do b:Hide() end
    local runs = {}
    for i = #(e.stats and e.stats.runs or {}), 1, -1 do runs[#runs + 1] = e.stats.runs[i] end
    self.runList:SetItems(runs)
    self.runEmpty:SetShown(#runs == 0)
    local st = e.stats
    self.sub:SetText(st and string.format("%d %s logged.  Fastest clear %s, typical %s.", #st.runs, #st.runs == 1 and "run" or "runs",
      st.best and UI.Time(st.best.duration) or "—", st.typical and UI.Time(st.typical) or "—") or "")
    return
  end
  if questsOn then
    for _, b in ipairs(self.floorButtons) do b:Hide() end
    self.sub:SetText(e.static and e.static.levels and #e.static.levels == 2 and string.format("%s, levels %d-%d.", e.static.raid and "Raid" or "Dungeon", e.static.levels[1], e.static.levels[2]) or "")
    if self.qdungeon ~= e.name then self.qdungeon = e.name; self.qscroll:SetVerticalScroll(0) end
    self:LayoutQuests(e)
    return
  end
  local s = e.stats
  self.sub:SetText(s and string.format("%d %s logged.  Fastest clear %s, typical %s, %.1f wipes per run.", #s.runs, #s.runs == 1 and "run" or "runs",
    s.best and UI.Time(s.best.duration) or "—", s.typical and UI.Time(s.typical) or "—", s.wipes / #s.runs)
    or ((e.journal and e.journal.desc) or ((e.static and e.static.levels and #e.static.levels == 2) and string.format("%s, levels %d-%d. Not run by the guild yet.", e.static.raid and "Raid" or "Dungeon", e.static.levels[1], e.static.levels[2])) or "Not run by the guild yet."))
  if e.static and e.static.wings then
    local w = {}
    for _, x in ipairs(e.static.wings) do w[#w + 1] = x.name .. " " .. x.levels[1] .. "-" .. x.levels[2] end
    self.sub:SetText((self.sub:GetText() or "") .. "\nWings: " .. table.concat(w, ", "))
  end

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
  self.map:SetShown(#floors > 0)
  local art = #floors > 0 and self.map:Draw(selFloor, self.mapW or 400, self.mapH or 267, pins)
  self.mapNote:SetText(#floors == 0 and "The game has no map picture for this dungeon."
    or (#pins == 0 and "No boss locations on this floor." or "Numbers are the boss order. Click a pin or a name for details.") .. (art and "" or ""))

  local boss
  for _, b in ipairs(bosses) do if b.name == selBoss then boss = b end end
  self.bossTitle:SetText(boss and boss.name or "")
  local hasPortrait = false
  if boss then hasPortrait = self:SetPortrait(visual(e, boss.name)) else self:SetPortrait(nil, nil) end
  self.bossTitle:ClearAllPoints(); self.bossTitle:SetPoint("TOPLEFT", hasPortrait and 90 or 0, hasPortrait and -26 or 0)
  self.bossTitle:SetWidth((self.detail:GetWidth() or 300) - (hasPortrait and 90 or 0))
  self.headH = hasPortrait and 76 or (self.bossTitle:GetStringHeight() or 20)
  self.body:ClearAllPoints(); self.body:SetPoint("TOPLEFT", 0, -(self.headH + 8))
  local text, loot, note
  if boss then text, loot, note = detailText(e, boss) end
  self.body:SetText(text or "No bosses known for this dungeon yet.")
  local h = self:LayoutLoot(loot or {}, note)
  self.detail:SetHeight(self.headH + (self.body:GetStringHeight() or 200) + h + 16)
  self.scroll:SetVerticalScroll(0)
end

ns.RegisterPage(page)
