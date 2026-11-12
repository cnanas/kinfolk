-- Foxden: building blocks for the dashboard pages.

local _, ns = ...
local UI = ns.UI
local C = UI.C

-- A scrolling list that fills its height with rows and scrolls with the mouse wheel.
--   local l = UI.List(parent, rowHeight, makeRow(row), fillRow(row, item, index))
--   l:SetItems(items); size it with points or SetSize; it re-lays out on resize.
function UI.List(parent, rowH, makeRow, fillRow)
  local l = CreateFrame("Frame", nil, parent)
  l.rows, l.items, l.offset, l.count = {}, {}, 0, 0
  l.thumb = l:CreateTexture(nil, "OVERLAY")
  l.thumb:SetWidth(3); l.thumb:SetColorTexture(1, 1, 1, 0.18)
  function l:Redraw()
    local max = math.max(0, #self.items - self.count)
    self.offset = math.max(0, math.min(self.offset, max))
    for i = 1, self.count do
      local row, idx = self.rows[i], i + self.offset
      local item = self.items[idx]
      if item then fillRow(row, item, idx); row:Show() else row:Hide() end
    end
    if max > 0 then
      local h = self:GetHeight()
      local th = math.max(20, h * self.count / #self.items)
      self.thumb:SetHeight(th)
      self.thumb:ClearAllPoints()
      self.thumb:SetPoint("TOPRIGHT", 0, -(h - th) * self.offset / max)
      self.thumb:Show()
    else
      self.thumb:Hide()
    end
  end
  function l:Layout()
    local n = math.max(1, math.floor(self:GetHeight() / rowH))
    for i = 1, n do
      if not self.rows[i] then
        local row = CreateFrame("Button", nil, self)
        row:SetHeight(rowH)
        row.hover = UI.Fill(row, C.hover, "ARTWORK"); row.hover:Hide()
        row.sel = UI.Fill(row, C.raised, "BACKGROUND"); row.sel:Hide()
        row.bar = row:CreateTexture(nil, "ARTWORK"); row.bar:SetPoint("TOPLEFT"); row.bar:SetPoint("BOTTOMLEFT"); row.bar:SetWidth(2); row.bar:Hide()
        local sep = row:CreateTexture(nil, "BORDER")
        sep:SetColorTexture(unpack(C.line)); sep:SetPoint("BOTTOMLEFT", 12, 0); sep:SetPoint("BOTTOMRIGHT", -12, 0); sep:SetHeight(1)
        row:SetScript("OnEnter", function(r) r.hover:Show() end)
        row:SetScript("OnLeave", function(r) r.hover:Hide() end)
        makeRow(row)
        self.rows[i] = row
      end
      local row = self.rows[i]
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
      row:SetPoint("RIGHT", self, "RIGHT", -5, 0)
    end
    for i = n + 1, #self.rows do self.rows[i]:Hide() end
    self.count = n
    self:Redraw()
  end
  function l:SetItems(items) self.items = items or {}; self:Redraw() end
  function l:Select(row, on)
    row.sel:SetShown(on); row.bar:SetShown(on)
    if on then row.bar:SetColorTexture(UI.Accent()) end
  end
  l:EnableMouseWheel(true)
  l:SetScript("OnMouseWheel", function(self, d) self.offset = self.offset - d * 2; self:Redraw() end)
  l:SetScript("OnSizeChanged", function(self) self:Layout() end)
  return l
end

-- Search box: calls onChange(text) as you type.
function UI.SearchBox(parent, width, placeholder, onChange)
  local box = CreateFrame("EditBox", nil, parent)
  box:SetSize(width, 26)
  box:SetAutoFocus(false)
  box:SetFont(UI.Font(), 12, "")
  box:SetTextColor(unpack(C.text))
  box:SetTextInsets(10, 10, 0, 0)
  UI.Fill(box, C.raised); UI.Border(box)
  local ph = UI.Text(box, 12, C.faint); ph:SetPoint("LEFT", 10, 0); ph:SetText(placeholder)
  box:SetScript("OnTextChanged", function(self) ph:SetShown(self:GetText() == ""); onChange(self:GetText()) end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return box
end

-- The game can't open web pages, so links are shown in a box you can copy from (Ctrl+C).
function UI.CopyBox(parent, width)
  local box = CreateFrame("EditBox", nil, parent)
  box:SetSize(width, 24)
  box:SetAutoFocus(false)
  box:SetFont(UI.Font(), 11, "")
  box:SetTextColor(unpack(C.dim))
  box:SetTextInsets(8, 8, 0, 0)
  UI.Fill(box, C.surface); UI.Border(box)
  function box:SetLink(text) self.link = text or ""; self:SetText(self.link); self:SetCursorPosition(0) end
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  box:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)
  box:SetScript("OnTextChanged", function(self, user) if user then self:SetText(self.link or ""); self:HighlightText() end end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return box
end

-- Row of small toggle chips (profession filters etc.). onPick(value)
function UI.Chips(parent, onPick)
  local c = CreateFrame("Frame", nil, parent)
  c:SetHeight(24)
  c.buttons = {}
  function c:SetOptions(options, current)
    local x = 0
    for i, o in ipairs(options) do
      local b = self.buttons[i]
      if not b then
        b = UI.Button(self, "", 60, 22, function(btn) onPick(btn.value) end)
        self.buttons[i] = b
      end
      b.value = o.value
      b.label:SetText(o.label)
      b:SetWidth(b.label:GetStringWidth() + 18)
      b:ClearAllPoints(); b:SetPoint("LEFT", x, 0)
      if o.value == current then b.label:SetTextColor(UI.Accent()) else b.label:SetTextColor(unpack(C.dim)) end
      b:Show()
      x = x + b:GetWidth() + 4
    end
    for i = #options + 1, #self.buttons do self.buttons[i]:Hide() end
  end
  return c
end
