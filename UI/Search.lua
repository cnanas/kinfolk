-- Foxden: the search box in the window header. Finds dungeons, bosses, quests, boss
-- loot and recipes, and jumps to them. The index is built from Foxden's own dungeon
-- list and the website snapshot, the first time you type.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local MAX = 8

local index, indexFor
local function build()
  local site = ns.Site and ns.Site()
  local stamp = site and site.at or 0
  if index and indexFor == stamp then return index end
  index, indexFor = {}, stamp
  local bySlug = {}
  local function add(label, kind, sub, key, arg)
    if type(label) ~= "string" or label == "" then return end
    index[#index + 1] = { label = label, lower = label:lower(), kind = kind, sub = sub, key = key, arg = arg }
  end
  for _, d in pairs(ns.Dungeons or {}) do
    bySlug[ns.Slug(d.name)] = d.name
    add(d.name, d.raid and "Raid" or "Dungeon", d.levels and #d.levels == 2 and ("levels " .. d.levels[1] .. "-" .. d.levels[2]) or nil, "journal", { dungeon = d.name })
    for _, b in ipairs(d.bosses or {}) do add(b.name, "Boss", d.name, "journal", { dungeon = d.name, boss = b.name }) end
  end
  if site then
    for slug, list in pairs(type(site.quests) == "table" and site.quests or {}) do
      local dn = bySlug[slug]
      if dn then for _, q in ipairs(list) do add(q[2], "Quest", dn, "journal", { dungeon = dn, view = "quests" }) end end
    end
    for slug, bosses in pairs(type(site.loot) == "table" and site.loot or {}) do
      local dn = bySlug[slug]
      if dn then
        for boss, items in pairs(bosses) do
          for _, it in ipairs(items) do add(it[2], "Loot", boss .. ", " .. dn, "journal", { dungeon = dn, boss = boss }) end
        end
      end
    end
    for _, c in ipairs(type(site.costs) == "table" and site.costs or {}) do add(c[3], "Recipe", c[4], "recipes", { search = c[3] }) end
  end
  return index
end

local function find(text)
  local q = text:lower()
  local starts, contains = {}, {}
  if #q < 2 then return starts end
  for _, e in ipairs(build()) do
    local at = e.lower:find(q, 1, true)
    if at == 1 then starts[#starts + 1] = e elseif at then contains[#contains + 1] = e end
    if #starts >= MAX then break end
  end
  for _, e in ipairs(contains) do if #starts < MAX then starts[#starts + 1] = e end end
  return starts
end
ns.SearchFind = find

function ns.BuildSearch(W, header, x)
  local box, drop
  local function close() drop:Hide() end
  local function show(results)
    for i, r in ipairs(drop.rows) do
      local e = results[i]
      r.entry = e
      if e then
        r.label:SetText(e.label); r.kind:SetText(e.kind .. (e.sub and ("  ·  " .. e.sub) or ""))
        r:Show()
      else r:Hide() end
    end
    drop.none:SetShown(#results == 0)
    drop:SetHeight(math.max(1, #results) * 30 + 8)
    drop:Show()
  end
  box = UI.SearchBox(header, 300, "Search dungeons, bosses, quests, items…", function(t)
    if not drop then return end
    if (t or "") == "" or #t < 2 then close() else show(find(t)) end
  end)
  box:SetPoint("LEFT", x, 0)
  box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); close() end)
  box:SetScript("OnEnterPressed", function(self)
    local first = drop:IsShown() and drop.rows[1].entry
    if first then ns.OpenPage(first.key, first.arg); self:SetText(""); self:ClearFocus(); close() end
  end)
  drop = CreateFrame("Frame", nil, W)
  drop:SetFrameStrata("DIALOG")
  drop:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -4); drop:SetWidth(420)
  UI.Fill(drop, C.surface); UI.Border(drop, { 1, 1, 1, 0.16 })
  drop:Hide()
  drop.rows = {}
  for i = 1, MAX do
    local r = CreateFrame("Button", nil, drop)
    r:SetHeight(30); r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 30); r:SetPoint("RIGHT", drop, "RIGHT", -4, 0)
    local hover = UI.Fill(r, C.hover, "ARTWORK"); hover:Hide()
    r.label = UI.Text(r, 13); r.label:SetPoint("LEFT", 10, 0); r.label:SetWidth(210)
    r.kind = UI.Text(r, 11, C.dim, "RIGHT"); r.kind:SetPoint("RIGHT", -10, 0); r.kind:SetWidth(180)
    r:SetScript("OnEnter", function() hover:Show() end)
    r:SetScript("OnLeave", function() hover:Hide() end)
    r:SetScript("OnClick", function(self)
      local e = self.entry
      if e then ns.OpenPage(e.key, e.arg) end
      box:SetText(""); box:ClearFocus(); close()
    end)
    drop.rows[i] = r
  end
  drop.none = UI.Text(drop, 12, C.dim); drop.none:SetPoint("LEFT", 14, 0); drop.none:SetText("Nothing found.")
  W.search, W.searchDrop = box, drop
  W:HookScript("OnHide", close)
end
