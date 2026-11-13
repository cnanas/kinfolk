-- Page: Guild roster. Who's online and where, straight from the game, with a map of
-- the continent showing guildmates who share their location (their last known spot).

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16

local page = { key = "roster", label = "Roster", order = 90 }
local query, onlineOnly = "", true
local continent -- uiMapID of the continent shown on the map

local function agoText(t)
  local s = math.max(0, GetServerTime() - (t or 0))
  if s < 300 then return "now" end
  if s < 3600 then return math.floor(s / 60) .. " min ago" end
  if s < 86400 then return math.floor(s / 3600) .. " h ago" end
  return math.floor(s / 86400) .. " d ago"
end

-- Last known positions as pins on a continent map (0..1000), from the zone rectangles
-- the Atlas module read from the game.
local function pinsOn(cont)
  local atlas, pins = ns.db and ns.db.atlas, {}
  if not atlas then return pins end
  local now = GetServerTime()
  for key, l in pairs(ns.db.locations or {}) do
    local z = atlas.maps and atlas.maps[l.map]
    if z and z.cont == cont and type(l.x) == "number" and now - (l.at or 0) < 7 * 86400 then
      local name = key:match("^[^-]+") or key
      pins[#pins + 1] = {
        x = z.l + (z.r - z.l) * l.x / 1000, y = z.t + (z.b - z.t) * l.y / 1000,
        key = key, label = name, n = name:sub(1, 1),
        sub = (l.zone or z.name or "") .. ", " .. agoText(l.at), on = now - (l.at or 0) < 600,
      }
    end
  end
  return pins
end

local function seenText(h)
  if not h then return "" end
  if h < 1 then return "less than an hour ago" end
  if h < 24 then return h .. (h == 1 and " hour ago" or " hours ago") end
  local d = math.floor(h / 24)
  return d .. (d == 1 and " day ago" or " days ago")
end

function page:Build(f)
  self.summary = UI.Text(f, 12, C.dim); self.summary:SetWordWrap(true)
  self.search = UI.SearchBox(f, 220, "Search names or zones", function(t) query = t:lower(); self:Refresh() end)
  self.toggle = UI.Button(f, "Online only", 110, 26, function() onlineOnly = not onlineOnly; self:Refresh() end)
  self.head = {}
  for i, label in ipairs({ "Name", "Level", "", "Zone", "Status" }) do self.head[i] = UI.Text(f, 11, C.faint, i == 5 and "RIGHT" or "LEFT"); self.head[i]:SetText(label) end
  self.list = UI.List(f, 30, function(r)
    r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetSize(8, 8); r.dot:SetPoint("LEFT", 12, 0)
    r.name = UI.Text(r, 12); r.level = UI.Text(r, 12, C.dim); r.rank = UI.Text(r, 12, C.dim); r.zone = UI.Text(r, 12); r.status = UI.Text(r, 11, C.dim, "RIGHT")
  end, function(r, m)
    local w = self.list:GetWidth()
    r.name:ClearAllPoints(); r.name:SetPoint("LEFT", 28, 0); r.name:SetWidth(w * 0.27)
    r.level:ClearAllPoints(); r.level:SetPoint("LEFT", w * 0.30, 0)
    r.rank:Hide()
    r.zone:ClearAllPoints(); r.zone:SetPoint("LEFT", w * 0.38, 0); r.zone:SetWidth(w * 0.36)
    r.status:ClearAllPoints(); r.status:SetPoint("RIGHT", -12, 0)
    r.name:SetText(UI.ShortName(m.name)); r.name:SetTextColor(UI.ClassColor(m.class))
    r.level:SetText(m.level or ""); r.rank:SetText(m.rank or "")
    local loc = self.locs and self.locs[m.name]
    r.zone:SetText((m.zone or "—") .. (loc and m.online and string.format("  |cff999fb0%.1f, %.1f|r", loc.x / 10, loc.y / 10) or ""))
    r.zone:SetTextColor(unpack(m.online and C.text or C.dim))
    if m.online then r.dot:SetColorTexture(0.30, 0.78, 0.56, 1); r.status:SetText(m.mobile and "On mobile" or "Online")
    else r.dot:SetColorTexture(0.42, 0.45, 0.50, 1); r.status:SetText(seenText(m.seenHours)) end
  end)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })
  self.mapHead = UI.Text(f, 14); self.mapHead:SetText("Where everyone is")
  self.conts = UI.Chips(f, function(v) continent = v; self:Refresh() end)
  self.map = UI.MapCanvas(f)
  self.mapNote = UI.Text(f, 11, C.faint); self.mapNote:SetWordWrap(true)
  self.empty = UI.Text(f, 13, C.dim, "CENTER"); self.empty:SetWordWrap(true)
end

function page:Layout(w, h)
  local inner = w - PAD * 2
  local mapW = math.max(280, math.floor(inner * 0.40))
  local mapH = math.floor(mapW / 1.5)
  local listW = inner - mapW - 16
  self.summary:ClearAllPoints(); self.summary:SetPoint("TOPLEFT", PAD, -PAD); self.summary:SetWidth(inner)
  self.search:ClearAllPoints(); self.search:SetPoint("TOPLEFT", PAD, -PAD - 28)
  self.toggle:ClearAllPoints(); self.toggle:SetPoint("LEFT", self.search, "RIGHT", 8, 0)
  local cols = { 28, listW * 0.30, listW * 0.38, listW * 0.50 }
  for i = 1, 4 do self.head[i]:ClearAllPoints(); self.head[i]:SetPoint("TOPLEFT", PAD + cols[i], -PAD - 66) end
  self.head[3]:Hide() -- rank: left out to make room for the map
  self.head[5]:ClearAllPoints(); self.head[5]:SetPoint("TOPRIGHT", self.list:GetParent(), "TOPLEFT", PAD + listW - 17, -PAD - 66)
  self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", PAD, -PAD - 84); self.list:SetSize(listW, h - PAD * 2 - 84)
  local mx = PAD + listW + 16
  self.mapHead:ClearAllPoints(); self.mapHead:SetPoint("TOPLEFT", mx, -PAD - 30)
  self.conts:ClearAllPoints(); self.conts:SetPoint("TOPLEFT", mx, -PAD - 54); self.conts:SetWidth(mapW)
  self.map:ClearAllPoints(); self.map:SetPoint("TOPLEFT", mx, -PAD - 84)
  self.mapW, self.mapH = mapW, math.min(mapH, h - PAD * 2 - 84 - 40)
  self.mapNote:ClearAllPoints(); self.mapNote:SetPoint("TOPLEFT", mx, -PAD - 84 - self.mapH - 8); self.mapNote:SetWidth(mapW)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER"); self.empty:SetWidth(inner - 60)
end

function page:Refresh()
  if ns.RequestRoster then ns.RequestRoster() end
  local r = ns.db and ns.db.roster
  local has = r and r.members and #r.members > 0
  for _, el in ipairs({ self.summary, self.search, self.toggle, self.list, self.mapHead, self.conts, self.map, self.mapNote }) do el:SetShown(has) end
  for i, hd in ipairs(self.head) do hd:SetShown(has and i ~= 3) end
  self.empty:SetShown(not has)
  if not has then
    self.empty:SetText(IsInGuild() and "Loading the guild roster…" or "You're not in a guild on this character.")
    return
  end
  self.locs = ns.GuildLocations and ns.GuildLocations() or {}
  local online, list = 0, {}
  for _, m in ipairs(r.members) do
    if m.online then online = online + 1 end
    if (not onlineOnly or m.online) and (query == "" or m.name:lower():find(query, 1, true) or (m.zone or ""):lower():find(query, 1, true)) then list[#list + 1] = m end
  end
  table.sort(list, function(a, b)
    if a.online ~= b.online then return a.online end
    if not a.online then return (a.seenHours or 1e9) < (b.seenHours or 1e9) end
    return (a.rankIndex or 99) < (b.rankIndex or 99) or ((a.rankIndex or 99) == (b.rankIndex or 99) and a.name < b.name)
  end)
  local sharing = 0
  for _ in pairs(self.locs) do sharing = sharing + 1 end
  self.summary:SetText(string.format("%s: %d of %d members online. %d sharing their location right now.", r.guild or "Guild", online, #r.members, sharing))
  self.toggle.label:SetText(onlineOnly and "Show everyone" or "Online only")
  self.list:SetItems(list)

  -- the map: the continent you're on (or the first one known), with everyone's last spot
  local atlas = ns.db.atlas
  local opts = {}
  for id, c in pairs(atlas and atlas.conts or {}) do opts[#opts + 1] = { value = id, label = c.name or ("Continent " .. id) } end
  table.sort(opts, function(a, b) return a.label < b.label end)
  if not continent or not (atlas and atlas.conts and atlas.conts[continent]) then
    local mine = ns.db.locations and ns.db.locations[ns.CharKey()]
    local z = mine and atlas and atlas.maps and atlas.maps[mine.map]
    continent = (z and z.cont) or (opts[1] and opts[1].value)
  end
  self.conts:SetOptions(opts, continent)
  self.conts:SetShown(has and #opts > 1)
  local pins = continent and pinsOn(continent) or {}
  self.map:Draw(continent, self.mapW or 300, self.mapH or 200, pins)
  if not continent then
    self.mapNote:SetText("The map appears once Foxden knows where you are: turn on location sharing in Settings and step outside.")
  elseif #pins == 0 then
    self.mapNote:SetText("Nobody on this continent is sharing their location. Guildmates with Foxden who share it show up here.")
  else
    self.mapNote:SetText(#pins .. (#pins == 1 and " guildmate" or " guildmates") .. " here. Bright dots were seen in the last 10 minutes; grey dots are the last place they were seen. Hover a dot for the name and zone.")
  end
end

ns.RegisterPage(page)
