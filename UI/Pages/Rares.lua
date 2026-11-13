-- Page: Rares. Every rare and rare elite out in the world, sorted with the ones near your
-- level in your zone first: where they spawn, when the guild last saw or killed them, and
-- when they may be up again. Pin a spawn point on the map.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16

local page = { key = "rares", label = "Rares", order = 95 }
local scope, query = "near", ""

local function pinOnMap(map, x, y, name)
  if not (map and C_Map and C_Map.SetUserWaypoint and UiMapPoint) then return end
  if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(map) then ns.say("The game doesn't allow a map pin there.", true); return end
  local ok = pcall(function()
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
  end)
  if ok then ns.say(string.format("Map pin set on %s's spawn (%d, %d).", name, math.floor(x + 0.5), math.floor(y + 0.5))) end
end

local function agoText(t)
  local s = math.max(0, GetServerTime() - (t or 0))
  if s < 3600 then return math.max(1, math.floor(s / 60)) .. " min ago" end
  if s < 86400 then return math.floor(s / 3600) .. " h ago" end
  return math.floor(s / 86400) .. " d ago"
end

function page:Build(f)
  self.scope = UI.Dropdown(f, 220, "Show", function(v) scope = v; self:Refresh() end)
  self.search = UI.SearchBox(f, 200, "Search rares", function(t) query = t:lower(); self:Refresh() end)
  self.head = {}
  for i, label in ipairs({ "Rare", "Level", "Zone", "Last seen", "Next" }) do self.head[i] = UI.Text(f, 11, C.faint); self.head[i]:SetText(label) end
  self.list = UI.List(f, 40, function(r)
    r.name = UI.Text(r, 13); r.name:SetPoint("TOPLEFT", 12, -6)
    r.spots = UI.Text(r, 10, C.faint); r.spots:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.lvl = UI.Text(r, 12, C.dim); r.zone = UI.Text(r, 12, C.dim); r.last = UI.Text(r, 11, C.dim); r.next = UI.Text(r, 12)
    r.pin = UI.Button(r, "Pin", 44, 22, function(b) local x = b:GetParent().x; if x then pinOnMap(x[6], x[7][1], x[7][2], x[1]) end end)
    r.pin:SetPoint("RIGHT", -8, 0)
  end, function(r, x)
    local w = self.list:GetWidth()
    r.x = x
    r.name:SetText(x[1] .. (x[4] and "  |cffe8c35aRare elite|r" or "")); r.name:SetWidth(w * 0.30)
    local n = #x[7] / 2
    r.spots:SetText(string.format("%d, %d", math.floor(x[7][1] + 0.5), math.floor(x[7][2] + 0.5)) .. (n > 1 and ("  +" .. (n - 1) .. " more spawn points") or ""))
    r.lvl:ClearAllPoints(); r.lvl:SetPoint("LEFT", w * 0.32, 0); r.lvl:SetText(x[2] == x[3] and x[2] or (x[2] .. "-" .. x[3]))
    r.zone:ClearAllPoints(); r.zone:SetPoint("LEFT", w * 0.40, 0); r.zone:SetWidth(w * 0.20); r.zone:SetText(x[5])
    local last = ns.RareLast(x.id)
    r.last:ClearAllPoints(); r.last:SetPoint("LEFT", w * 0.61, 0); r.last:SetWidth(w * 0.18)
    r.last:SetText(last and ((last.k == "killed" and "killed " or "seen ") .. agoText(last.at) .. (last.by and (" by " .. last.by) or "")) or "")
    local nextText = ns.RareNext(x.id)
    r.next:ClearAllPoints(); r.next:SetPoint("RIGHT", r.pin, "LEFT", -10, 0)
    r.next:SetText(nextText or "")
    if nextText and nextText:find("up") then r.next:SetTextColor(0.44, 0.83, 0.6) else r.next:SetTextColor(unpack(C.text)) end
  end)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })
  self.foot = UI.Text(f, 11, C.faint); self.foot:SetWordWrap(true)
  self.foot:SetText("Foxden records a rare when you target or mouse over it (alive or dead) and tells guildmates. Respawn timers are learned from the guild's kills, or set by hand on the guild website's Rares page (Guild > Rares). Spawn points: QuestieDB (GPLv3).")
end

function page:Layout(w, h)
  local inner = w - PAD * 2
  self.scope:ClearAllPoints(); self.scope:SetPoint("TOPLEFT", PAD, -PAD)
  self.search:ClearAllPoints(); self.search:SetPoint("LEFT", self.scope, "RIGHT", 8, 0)
  local cols = { 12, inner * 0.32, inner * 0.40, inner * 0.61 }
  for i = 1, 4 do self.head[i]:ClearAllPoints(); self.head[i]:SetPoint("TOPLEFT", PAD + cols[i], -PAD - 40) end
  self.head[5]:ClearAllPoints(); self.head[5]:SetPoint("TOPLEFT", PAD + inner * 0.82, -PAD - 40)
  self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", PAD, -PAD - 58); self.list:SetSize(inner, h - PAD * 2 - 58 - 36)
  self.foot:ClearAllPoints(); self.foot:SetPoint("BOTTOMLEFT", PAD, PAD); self.foot:SetWidth(inner)
end

function page:Refresh()
  local level = UnitLevel("player") or 1
  local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
  local zone = okM and map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
  local zoneName = zone and zone.name
  self.scope:SetOptions({
    { value = "near", label = "Near my level (" .. level .. ")" },
    { value = "zone", label = "In " .. (zoneName or "this zone") },
    { value = "recent", label = "Seen or killed lately" },
    { value = "all", label = "All rares" },
  }, scope)
  local list = {}
  for id, r in pairs(ns.Rares or {}) do
    local keep = query == "" or r[1]:lower():find(query, 1, true) or r[5]:lower():find(query, 1, true)
    if keep then
      if scope == "near" then keep = r[2] <= level + 4 and r[3] >= level - 3
      elseif scope == "zone" then keep = (map and r[6] == map) or (zoneName and r[5] == zoneName)
      elseif scope == "recent" then local last = ns.RareLast(id); keep = last and GetServerTime() - last.at < 3 * 86400 end
    end
    if keep then local x = { unpack(r) }; x.id = id; x.last = ns.RareLast(id); list[#list + 1] = x end
  end
  table.sort(list, function(a, b)
    local ha, hb = zoneName and a[5] == zoneName or false, zoneName and b[5] == zoneName or false
    if ha ~= hb then return ha end
    local la, lb = a.last and a.last.at or 0, b.last and b.last.at or 0
    if scope == "recent" and la ~= lb then return la > lb end
    if a[2] ~= b[2] then return a[2] < b[2] end
    return a[1] < b[1]
  end)
  self.list:SetItems(list)
end

ns.RegisterPage(page)
