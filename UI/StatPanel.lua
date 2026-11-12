-- Foxden: stat tabs + ranked, class-colored bars. Shared by views and pages.
--   local p = ns.UI.StatPanel(parent, width, statKeys, maxBars)
--   p:SetPanelWidth(w)   re-flow for a new width (tabs wrap when narrow)
--   p:Set(statsByPlayer, combatSeconds, classOf, emptyText)

local _, ns = ...
local UI = ns.UI
local C = UI.C

UI.STATS = {
  damage      = { label = "Damage", rate = true },
  healing     = { label = "Healing", rate = true },
  absorbs     = { label = "Absorbs" },
  interrupts  = { label = "Interrupts" },
  dispels     = { label = "Dispels" },
  avoidable   = { label = "Avoidable" },
  damageTaken = { label = "Taken" },
  deaths      = { label = "Deaths" },
}
UI.ALL_STATS = { "damage", "healing", "absorbs", "interrupts", "dispels", "avoidable", "damageTaken", "deaths" }

local BAR_H, BAR_GAP, TAB_H = 24, 5, 28

function UI.StatPanel(parent, width, keys, maxBars)
  local p = CreateFrame("Frame", nil, parent)
  p.key, p.maxBars, p.tabRows = keys[1], maxBars, 1

  p.tabs = {}
  for _, key in ipairs(keys) do
    local tab = CreateFrame("Button", nil, p)
    tab.key = key
    tab.text = UI.Text(tab, 12, C.dim, "CENTER")
    tab.text:SetPoint("CENTER", 0, 1)
    tab.text:SetText(UI.STATS[key].label)
    tab:SetSize(math.floor(tab.text:GetStringWidth() + 0.5) + 14, TAB_H)
    tab.line = tab:CreateTexture(nil, "ARTWORK")
    tab.line:SetPoint("BOTTOMLEFT"); tab.line:SetPoint("BOTTOMRIGHT"); tab.line:SetHeight(2)
    tab:SetScript("OnClick", function() p.key = key; p:Redraw() end)
    tab:SetScript("OnEnter", function() if p.key ~= key then tab.text:SetTextColor(unpack(C.text)) end end)
    tab:SetScript("OnLeave", function() if p.key ~= key then tab.text:SetTextColor(unpack(C.dim)) end end)
    p.tabs[#p.tabs + 1] = tab
  end
  p.tabLine = p:CreateTexture(nil, "BORDER")
  p.tabLine:SetColorTexture(unpack(C.line))
  p.tabLine:SetHeight(1)

  p.bars = {}
  for i = 1, maxBars do
    local b = CreateFrame("Frame", nil, p)
    b:SetHeight(BAR_H)
    UI.Fill(b, C.surface)
    b.fill = b:CreateTexture(nil, "ARTWORK")
    b.fill:SetPoint("TOPLEFT"); b.fill:SetPoint("BOTTOMLEFT")
    b.rank = UI.Text(b, 11, C.faint); b.rank:SetPoint("LEFT", 8, 0)
    b.name = UI.Text(b, 12); b.name:SetPoint("LEFT", 26, 0)
    b.value = UI.Text(b, 12, C.text, "RIGHT"); b.value:SetPoint("RIGHT", -8, 0)
    p.bars[i] = b
  end
  p.empty = UI.Text(p, 12, C.dim)
  p.empty:SetWordWrap(true)

  -- lay tabs out left to right, wrapping to a new row when they don't fit
  function p:SetPanelWidth(w)
    self.width = w
    self:SetWidth(w)
    local x, row = 0, 0
    for _, tab in ipairs(self.tabs) do
      if x > 0 and x + tab:GetWidth() > w then x, row = 0, row + 1 end
      tab:ClearAllPoints(); tab:SetPoint("TOPLEFT", x, -row * TAB_H)
      x = x + tab:GetWidth() + 2
    end
    self.tabRows = row + 1
    local top = self.tabRows * TAB_H
    self.tabLine:ClearAllPoints(); self.tabLine:SetPoint("TOPLEFT", 0, -top); self.tabLine:SetWidth(w)
    for i, b in ipairs(self.bars) do
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -top - 12 - (i - 1) * (BAR_H + BAR_GAP)); b:SetWidth(w)
    end
    self.empty:ClearAllPoints(); self.empty:SetPoint("TOPLEFT", 0, -top - 18); self.empty:SetWidth(w)
    self:SetHeight(top + 12 + self.maxBars * (BAR_H + BAR_GAP))
    self:Redraw()
  end

  function p:Set(stats, seconds, classOf, emptyText)
    self.stats, self.seconds, self.classOf, self.emptyText = stats, seconds, classOf, emptyText
    self:Redraw()
  end

  function p:Redraw()
    local r0, g0, b0 = UI.Accent()
    for _, tab in ipairs(self.tabs) do
      local on = tab.key == self.key
      tab.line:SetShown(on); tab.line:SetColorTexture(r0, g0, b0, 1)
      tab.text:SetTextColor(unpack(on and C.text or C.dim))
    end
    local sorted = {}
    for name, s in pairs(self.stats or {}) do
      local v = s[self.key] or 0
      if v > 0 then sorted[#sorted + 1] = { name = name, v = v } end
    end
    table.sort(sorted, function(a, b) return a.v > b.v end)
    local top = sorted[1] and sorted[1].v or 1
    local rate = UI.STATS[self.key].rate and (self.seconds or 0) > 0
    local w = self.width or width
    for i, b in ipairs(self.bars) do
      local row = sorted[i]
      if row then
        local r, g, bl = UI.ClassColor(self.classOf and self.classOf(row.name))
        b.fill:SetColorTexture(r, g, bl, 0.55)
        b.fill:SetWidth(math.max(1, w * row.v / top))
        b.rank:SetText(i)
        b.name:SetText(UI.ShortName(row.name))
        b.name:SetTextColor(r * 0.5 + 0.5, g * 0.5 + 0.5, bl * 0.5 + 0.5)
        b.value:SetText(UI.Num(row.v) .. (rate and ("   " .. UI.Num(row.v / self.seconds) .. "/s") or ""))
        b:Show()
      else
        b:Hide()
      end
    end
    self.empty:SetShown(#sorted == 0)
    self.empty:SetText(self.emptyText or "Nothing recorded for this stat.")
  end

  p:SetPanelWidth(width)
  return p
end
