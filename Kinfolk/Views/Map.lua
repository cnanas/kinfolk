-- View: Map. The dungeon's own map art for each floor you visited, with boss
-- pins numbered in kill order, and your path if the game allowed recording it.
-- Data: run.route (Modules/Route.lua).

local _, ns = ...
local UI = ns.UI
local C = UI.C

local view = { key = "map", label = "Map", order = 30 }
local MAX_SEGMENTS = 400

local function uniqueFloors(route)
  local seen, list = {}, {}
  for _, f in ipairs(route.floors or {}) do
    if not seen[f.map] then seen[f.map] = true; list[#list + 1] = f end
  end
  return list
end

-- Boss kill order by name, from the run's boss list.
local function killOrder(run)
  local order = {}
  for i, b in ipairs(run.bosses or {}) do if b.name and not order[b.name] then order[b.name] = i end end
  return order
end

function view:Layout(width, height)
  self.width, self.height = width, height
  self.note:SetWidth(width); self.empty:SetWidth(width - 60)
end

function view:Build(pane, width, height)
  self.pane, self.width, self.height = pane, width, height
  self.floorButtons = {}
  self.holder = CreateFrame("Frame", nil, pane)
  self.holder:SetClipsChildren(true)
  UI.Fill(self.holder, C.surface)
  self.tiles, self.lines, self.pins = {}, {}, {}
  self.note = UI.Text(pane, 11, C.dim)
  self.note:SetPoint("BOTTOMLEFT", 0, 0)
  self.note:SetWidth(width); self.note:SetWordWrap(true)
  self.empty = UI.Text(pane, 12, C.dim, "CENTER")
  self.empty:SetPoint("CENTER"); self.empty:SetWidth(width - 60); self.empty:SetWordWrap(true)
end

local function tile(self, i)
  local t = self.tiles[i]
  if not t then t = self.holder:CreateTexture(nil, "ARTWORK"); self.tiles[i] = t end
  return t
end

local function line(self, i)
  local l = self.lines[i]
  if not l then
    l = self.holder:CreateLine(nil, "OVERLAY")
    l:SetThickness(2)
    self.lines[i] = l
  end
  return l
end

local function pin(self, i)
  local p = self.pins[i]
  if not p then
    p = CreateFrame("Frame", nil, self.holder)
    p:SetSize(18, 18)
    p:SetFrameLevel(self.holder:GetFrameLevel() + 5)
    p.bg = p:CreateTexture(nil, "ARTWORK"); p.bg:SetAllPoints()
    p.ring = p:CreateTexture(nil, "BORDER"); p.ring:SetPoint("TOPLEFT", -1, 1); p.ring:SetPoint("BOTTOMRIGHT", 1, -1); p.ring:SetColorTexture(0, 0, 0, 0.8)
    p.num = UI.Text(p, 10, { 0.05, 0.06, 0.08, 1 }, "CENTER"); p.num:SetPoint("CENTER", 0, 0)
    p:EnableMouse(true)
    p:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(s.label or "Boss"); if s.sub then GameTooltip:AddLine(s.sub, 1, 1, 1) end; GameTooltip:Show() end)
    p:SetScript("OnLeave", GameTooltip_Hide)
    self.pins[i] = p
  end
  return p
end

-- Draws one floor's art into the holder; returns false if this client has no art for it.
local function drawArt(self, map, w, h)
  for _, t in ipairs(self.tiles) do t:Hide() end
  if not (C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return false end
  local okL, layers = pcall(C_Map.GetMapArtLayers, map)
  local okT, textures = pcall(C_Map.GetMapArtLayerTextures, map, 1)
  if not (okL and type(layers) == "table" and layers[1] and okT and type(textures) == "table" and #textures > 0) then return false end
  local layer = layers[1]
  local lw, lh = layer.layerWidth or 1002, layer.layerHeight or 668
  local tw, th = layer.tileWidth or 256, layer.tileHeight or 256
  local cols = math.max(1, math.ceil(lw / tw))
  local sx, sy = w / lw, h / lh
  for i, tex in ipairs(textures) do
    local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
    local t = tile(self, i)
    t:ClearAllPoints()
    t:SetSize(tw * sx, th * sy)
    t:SetPoint("TOPLEFT", self.holder, "TOPLEFT", col * tw * sx, -row * th * sy)
    t:SetTexture(tex); t:SetTexCoord(0, 1, 0, 1)
    t:Show()
  end
  return true
end

function view:Refresh(e)
  local run = e.run
  local route = run.route
  for _, b in ipairs(self.floorButtons) do b:Hide() end
  for _, l in ipairs(self.lines) do l:Hide() end
  for _, p in ipairs(self.pins) do p:Hide() end
  local floors = route and uniqueFloors(route) or {}
  self.holder:SetShown(#floors > 0); self.note:SetShown(#floors > 0)
  self.empty:SetShown(#floors == 0)
  if #floors == 0 then
    self.empty:SetText((run.schema or 1) < 3 and "This run was logged before maps were added."
      or e.live and "The map fills in as you move through the dungeon." or "The game didn't report any map floors for this run.")
    return
  end

  if run.id ~= self.runId then self.runId, self.floor = run.id, nil end
  local floor = self.floor
  local valid = false
  for _, f in ipairs(floors) do if f.map == floor then valid = true end end
  if not valid then floor = floors[1].map; self.floor = floor end

  -- floor buttons (only when there's more than one)
  local top = 0
  if #floors > 1 then
    local x = 0
    for i, f in ipairs(floors) do
      local b = self.floorButtons[i]
      if not b then
        b = UI.Button(self.pane, "", 90, 24, function(btn) self.floor = btn.map; ns.RefreshUI() end)
        self.floorButtons[i] = b
      end
      b.map = f.map
      b.label:SetText(f.name or ("Floor " .. i))
      b:SetWidth(math.min(160, math.max(70, b.label:GetStringWidth() + 20)))
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", x, 0)
      if f.map == floor then b.label:SetTextColor(UI.Accent()) else b.label:SetTextColor(unpack(C.text)) end
      x = x + b:GetWidth() + 6
      b:Show()
    end
    top = 32
  end

  -- fit the map (3:2 like the game's dungeon maps) into the space left
  local availH = self.height - top - 30
  local w = math.min(self.width, availH * 1.5)
  local h = w / 1.5
  self.holder:ClearAllPoints()
  self.holder:SetPoint("TOPLEFT", (self.width - w) / 2, -top)
  self.holder:SetSize(w, h)
  local hasArt = drawArt(self, floor, w, h)
  local px = function(x, y) return x / 1000 * w, -y / 1000 * h end

  -- your path on this floor, thinned to MAX_SEGMENTS
  local pts = {}
  for _, p in ipairs(route.path or {}) do if p.m == floor then pts[#pts + 1] = p end end
  local step = math.max(1, math.ceil(#pts / MAX_SEGMENTS))
  local r, g, b = UI.Accent()
  local n = 0
  for i = 1 + step, #pts, step do
    local a, c = pts[i - step], pts[i]
    n = n + 1
    local l = line(self, n)
    l:SetColorTexture(r, g, b, 0.9)
    l:SetStartPoint("TOPLEFT", self.holder, px(a.x, a.y))
    l:SetEndPoint("TOPLEFT", self.holder, px(c.x, c.y))
    l:Show()
  end

  -- boss pins: journal locations, numbered by kill order; kills without a pin use where you stood
  local order = killOrder(run)
  local k = 0
  local placed = {}
  for _, bp in ipairs((route.pins or {})[floor] or {}) do
    k = k + 1
    local p = pin(self, k)
    local num = order[bp.name]
    p:ClearAllPoints(); p:SetPoint("CENTER", self.holder, "TOPLEFT", px(bp.x, bp.y))
    if num then p.bg:SetColorTexture(r, g, b, 1) else p.bg:SetColorTexture(0.55, 0.58, 0.64, 1) end
    p.num:SetText(num or "")
    p.label, p.sub = bp.name, num and ("Killed " .. UI.Time(run.bosses[num].killedAt) .. " into the run") or "Not killed this run"
    placed[bp.name] = true
    p:Show()
  end
  for _, kill in ipairs(route.kills or {}) do
    if kill.m == floor and kill.x and not placed[kill.name] then
      k = k + 1
      local p = pin(self, k)
      p:ClearAllPoints(); p:SetPoint("CENTER", self.holder, "TOPLEFT", px(kill.x, kill.y))
      p.bg:SetColorTexture(r, g, b, 1)
      p.num:SetText(order[kill.name] or "")
      p.label, p.sub = kill.name, "Killed " .. UI.Time(kill.t) .. " into the run"
      p:Show()
    end
  end

  local bits = {}
  if not hasArt then bits[#bits + 1] = "This client has no map picture for this floor." end
  if route.allowed == false then bits[#bits + 1] = "The game doesn't allow reading your position in this dungeon, so only boss locations are shown."
  elseif #pts > 0 then bits[#bits + 1] = "The line is your own path. Party members' positions aren't available to addons." end
  if k == 0 then bits[#bits + 1] = "No boss locations on this floor." end
  self.note:SetText(table.concat(bits, " "))
end

ns.RegisterView(view)
