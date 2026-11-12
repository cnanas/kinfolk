-- Page: Guild roster. Who's online and where, straight from the game.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16

local page = { key = "roster", label = "Roster", section = "guild", order = 90 }
local query, onlineOnly = "", true

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
  for i, label in ipairs({ "Name", "Level", "Rank", "Zone", "Status" }) do self.head[i] = UI.Text(f, 11, C.faint, i == 5 and "RIGHT" or "LEFT"); self.head[i]:SetText(label) end
  self.list = UI.List(f, 30, function(r)
    r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetSize(8, 8); r.dot:SetPoint("LEFT", 12, 0)
    r.name = UI.Text(r, 12); r.level = UI.Text(r, 12, C.dim); r.rank = UI.Text(r, 12, C.dim); r.zone = UI.Text(r, 12); r.status = UI.Text(r, 11, C.dim, "RIGHT")
  end, function(r, m)
    local w = self.list:GetWidth()
    r.name:ClearAllPoints(); r.name:SetPoint("LEFT", 28, 0); r.name:SetWidth(w * 0.24)
    r.level:ClearAllPoints(); r.level:SetPoint("LEFT", w * 0.27, 0)
    r.rank:ClearAllPoints(); r.rank:SetPoint("LEFT", w * 0.34, 0); r.rank:SetWidth(w * 0.16)
    r.zone:ClearAllPoints(); r.zone:SetPoint("LEFT", w * 0.52, 0); r.zone:SetWidth(w * 0.30)
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
  self.empty = UI.Text(f, 13, C.dim, "CENTER"); self.empty:SetWordWrap(true)
end

function page:Layout(w, h)
  local inner = w - PAD * 2
  self.summary:ClearAllPoints(); self.summary:SetPoint("TOPLEFT", PAD, -PAD); self.summary:SetWidth(inner)
  self.search:ClearAllPoints(); self.search:SetPoint("TOPLEFT", PAD, -PAD - 28)
  self.toggle:ClearAllPoints(); self.toggle:SetPoint("LEFT", self.search, "RIGHT", 8, 0)
  local cols = { 28, inner * 0.27, inner * 0.34, inner * 0.52 }
  for i = 1, 4 do self.head[i]:ClearAllPoints(); self.head[i]:SetPoint("TOPLEFT", PAD + cols[i], -PAD - 66) end
  self.head[5]:ClearAllPoints(); self.head[5]:SetPoint("TOPRIGHT", self.list:GetParent(), "TOPLEFT", PAD + inner - 17, -PAD - 66)
  self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", PAD, -PAD - 84); self.list:SetSize(inner, h - PAD * 2 - 84)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER"); self.empty:SetWidth(inner - 60)
end

function page:Refresh()
  if ns.RequestRoster then ns.RequestRoster() end
  local r = ns.db and ns.db.roster
  local has = r and r.members and #r.members > 0
  for _, el in ipairs({ self.summary, self.search, self.toggle, self.list }) do el:SetShown(has) end
  for _, hd in ipairs(self.head) do hd:SetShown(has) end
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
  self.summary:SetText(string.format("%s: %d of %d members online. %d sharing their location (dots on your world map).", r.guild or "Guild", online, #r.members, sharing))
  self.toggle.label:SetText(onlineOnly and "Show everyone" or "Online only")
  self.list:SetItems(list)
end

ns.RegisterPage(page)
