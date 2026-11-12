-- Kinfolk: a dungeon floor drawn with the game's own map art, plus numbered
-- pins. Used by the Journal page.
--   local m = UI.MapCanvas(parent)
--   m:Draw(uiMapID, width, height, pins)   pins = { { x = 0..1000, y = 0..1000, label, sub, n, on }, ... }
--   returns true if the floor had map art

local _, ns = ...
local UI = ns.UI
local C = UI.C

function UI.MapCanvas(parent)
  local m = CreateFrame("Frame", nil, parent)
  m:SetClipsChildren(true)
  UI.Fill(m, C.surface)
  UI.Border(m)
  m.tiles, m.pins = {}, {}
  m.noArt = UI.Text(m, 12, C.faint, "CENTER"); m.noArt:SetPoint("CENTER")
  m.noArt:SetText("No map picture for this floor in this client")

  local function tile(i)
    local t = m.tiles[i]
    if not t then t = m:CreateTexture(nil, "ARTWORK"); m.tiles[i] = t end
    return t
  end
  local function pin(i)
    local p = m.pins[i]
    if not p then
      p = CreateFrame("Button", nil, m)
      p:SetSize(20, 20)
      p.ring = p:CreateTexture(nil, "BORDER"); p.ring:SetPoint("TOPLEFT", -1, 1); p.ring:SetPoint("BOTTOMRIGHT", 1, -1); p.ring:SetColorTexture(0, 0, 0, 0.85)
      p.bg = p:CreateTexture(nil, "ARTWORK"); p.bg:SetAllPoints()
      p.num = UI.Text(p, 11, { 0.05, 0.06, 0.08, 1 }, "CENTER"); p.num:SetPoint("CENTER")
      p:SetScript("OnEnter", function(s) GameTooltip:SetOwner(s, "ANCHOR_RIGHT"); GameTooltip:SetText(s.label or "Boss"); if s.sub then GameTooltip:AddLine(s.sub, 1, 1, 1, true) end; GameTooltip:Show() end)
      p:SetScript("OnLeave", GameTooltip_Hide)
      p:SetScript("OnClick", function(s) if m.onPin then m.onPin(s.key) end end)
      m.pins[i] = p
    end
    return p
  end

  function m:Draw(map, w, h, pins)
    self:SetSize(w, h)
    for _, t in ipairs(self.tiles) do t:Hide() end
    for _, p in ipairs(self.pins) do p:Hide() end
    local hasArt = false
    if map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures then
      local okL, layers = pcall(C_Map.GetMapArtLayers, map)
      local okT, textures = pcall(C_Map.GetMapArtLayerTextures, map, 1)
      if okL and type(layers) == "table" and layers[1] and okT and type(textures) == "table" and #textures > 0 then
        local layer = layers[1]
        local lw, lh = layer.layerWidth or 1002, layer.layerHeight or 668
        local tw, th = layer.tileWidth or 256, layer.tileHeight or 256
        local cols = math.max(1, math.ceil(lw / tw))
        local sx, sy = w / lw, h / lh
        for i, tex in ipairs(textures) do
          local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
          local t = tile(i)
          t:ClearAllPoints(); t:SetSize(tw * sx, th * sy)
          t:SetPoint("TOPLEFT", self, "TOPLEFT", col * tw * sx, -row * th * sy)
          t:SetTexture(tex); t:SetTexCoord(0, 1, 0, 1); t:Show()
        end
        hasArt = true
      end
    end
    self.noArt:SetShown(not hasArt)
    local r, g, b = UI.Accent()
    for i, p in ipairs(pins or {}) do
      local f = pin(i)
      f.key, f.label, f.sub = p.key, p.label, p.sub
      f:ClearAllPoints(); f:SetPoint("CENTER", self, "TOPLEFT", p.x / 1000 * w, -p.y / 1000 * h)
      if p.on then f.bg:SetColorTexture(r, g, b, 1) else f.bg:SetColorTexture(0.62, 0.65, 0.70, 1) end
      f.num:SetText(p.n or "")
      f:Show()
    end
    return hasArt
  end
  return m
end
