-- Foxden: guildmates who share their location, as class-colored dots on the
-- world map (with name, zone and how fresh it is on hover). Works on the zone
-- map and zoomed out to the continent.

local _, ns = ...
local UI = ns.UI
local pins = {}

local function canvas()
  return WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
end

local function classOf(key)
  for _, m in ipairs(ns.db and ns.db.roster and ns.db.roster.members or {}) do if m.name == key then return m.class end end
end

local function pin(i, parent)
  local p = pins[i]
  if not p then
    p = CreateFrame("Frame", nil, parent)
    p:SetSize(12, 12)
    p.ring = p:CreateTexture(nil, "ARTWORK"); p.ring:SetAllPoints(); p.ring:SetColorTexture(0, 0, 0, 0.9)
    p.dot = p:CreateTexture(nil, "OVERLAY"); p.dot:SetPoint("TOPLEFT", 2, -2); p.dot:SetPoint("BOTTOMRIGHT", -2, 2)
    for _, t in ipairs({ p.ring, p.dot }) do pcall(t.SetMask, t, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    p:EnableMouse(true)
    p:SetScript("OnEnter", function(s)
      GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
      GameTooltip:SetText(s.name or "Guildmate")
      if s.zone then GameTooltip:AddLine(s.zone, 1, 1, 1) end
      if s.age then GameTooltip:AddLine(s.age < 60 and "Just now" or (math.floor(s.age / 60) .. " min ago"), 0.7, 0.7, 0.7) end
      GameTooltip:Show()
    end)
    p:SetScript("OnLeave", GameTooltip_Hide)
    pins[i] = p
  end
  return p
end

function ns.RefreshMapPins()
  local child = canvas()
  if not child or not WorldMapFrame:IsShown() then return end
  local shown = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local w, h = child:GetWidth(), child:GetHeight()
  local now, n = GetServerTime(), 0
  for key, l in pairs(ns.GuildLocations and ns.GuildLocations() or {}) do
    if key ~= ns.CharKey() then
      local x, y, ok = l.x / 1000, l.y / 1000, l.map == shown
      if not ok and shown and C_Map.GetMapRectOnMap then
        local okR, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, l.map, shown)
        if okR and minX then
          x, y = minX + (maxX - minX) * x, minY + (maxY - minY) * y
          ok = x >= 0 and x <= 1 and y >= 0 and y <= 1
        end
      end
      if ok then
        n = n + 1
        local p = pin(n, child)
        p.name, p.zone, p.age = key:match("^[^-]+") or key, l.zone, now - (l.at or now)
        p.dot:SetColorTexture(UI.ClassColor(classOf(key)))
        p:ClearAllPoints(); p:SetPoint("CENTER", child, "TOPLEFT", x * w, -y * h)
        p:SetFrameLevel((child:GetFrameLevel() or 1) + 20)
        p:Show()
      end
    end
  end
  for i = n + 1, #pins do pins[i]:Hide() end
end

ns.RegisterModule({
  name = "MapPins",
  events = {
    PLAYER_LOGIN = function()
      if not WorldMapFrame then return end
      WorldMapFrame:HookScript("OnShow", function() ns.RefreshMapPins() end)
      if WorldMapFrame.OnMapChanged then hooksecurefunc(WorldMapFrame, "OnMapChanged", function() ns.RefreshMapPins() end) end
      C_Timer.NewTicker(5, function() if WorldMapFrame:IsShown() then ns.RefreshMapPins() end end)
    end,
  },
})
