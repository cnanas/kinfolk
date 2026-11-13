-- Foxden: a round button on the minimap edge. Click opens Foxden, right-click opens
-- Settings, drag moves it around the minimap. Minimap button collectors (EllesmereUI's
-- minimap bar and similar) pick it up like any other addon's button.
-- settings.minimapButton (default on), settings.minimapAngle (degrees).

local _, ns = ...
local button

local function place()
  local a = math.rad(ns.settings.minimapAngle or 205)
  local r = (Minimap:GetWidth() or 140) / 2 + 6
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function build()
  if button or not Minimap then return end
  button = CreateFrame("Button", "FoxdenMinimapButton", Minimap)
  button:SetSize(32, 32)
  button:SetFrameStrata("MEDIUM"); button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  local bg = button:CreateTexture(nil, "BACKGROUND"); bg:SetSize(20, 20); bg:SetPoint("CENTER")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  local icon = button:CreateTexture(nil, "ARTWORK"); icon:SetSize(20, 20); icon:SetPoint("CENTER")
  icon:SetTexture("Interface\\Icons\\Spell_Nature_SpiritWolf"); icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  if icon.SetMask then pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
  button.icon = icon
  local border = button:CreateTexture(nil, "OVERLAY"); border:SetSize(54, 54); border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  button:SetScript("OnClick", function(_, which) Foxden_OnAddonCompartmentClick(nil, which) end)
  button:SetScript("OnEnter", function(self) Foxden_OnAddonCompartmentEnter(nil, self) end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
  button:SetScript("OnDragStart", function(self)
    if self:GetParent() ~= Minimap then return end -- a button bar owns it now
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local s = Minimap:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      ns.settings.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      place()
    end)
  end)
  button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  place()
end

function ns.RefreshMinimapButton()
  if ns.settings.minimapButton == false then
    if button then button:Hide() end
    return
  end
  build()
  if button then button:Show() end
end

ns.RegisterModule({
  name = "MinimapButton",
  events = { PLAYER_LOGIN = function() ns.RefreshMinimapButton() end },
})
