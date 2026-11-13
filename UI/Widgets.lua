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
  l.thumb:SetPoint("TOPRIGHT"); l.thumb:Hide()
  function l:Redraw()
    local max = math.max(0, #self.items - self.count)
    self.offset = math.max(0, math.min(self.offset, max))
    -- scroll thumb first, kept inside the list, so a row that fails to draw can't leave it stale
    local h = self:GetHeight() or 0
    if max > 0 and h > 0 then
      local th = math.min(h, math.max(20, h * self.count / #self.items))
      self.thumb:SetHeight(th)
      self.thumb:ClearAllPoints()
      self.thumb:SetPoint("TOPRIGHT", 0, -(h - th) * self.offset / max)
      self.thumb:Show()
    else
      self.thumb:Hide()
    end
    for i = 1, self.count do
      local row, idx = self.rows[i], i + self.offset
      local item = self.items[idx]
      if item then
        local ok, err = pcall(fillRow, row, item, idx)
        if ok then row:Show() else row:Hide(); geterrorhandler()(err) end
      else row:Hide() end
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
  -- Lays the chips out left to right and wraps onto more rows when the frame's width runs
  -- out; sets its own height (c.rows rows of 26).
  function c:SetOptions(options, current)
    local x, row = 0, 0
    local max = self:GetWidth() or 0
    for i, o in ipairs(options) do
      local b = self.buttons[i]
      if not b then
        b = UI.Button(self, "", 60, 22, function(btn) onPick(btn.value) end)
        self.buttons[i] = b
      end
      b.value = o.value
      b.label:SetText(o.label)
      local w = b.label:GetStringWidth() + 18
      b:SetWidth(w)
      if max > 60 and x > 0 and x + w > max then x, row = 0, row + 1 end
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", x, -row * 26 - 1)
      if o.value == current then b.label:SetTextColor(UI.Accent()) else b.label:SetTextColor(unpack(C.dim)) end
      b:Show()
      x = x + w + 4
    end
    for i = #options + 1, #self.buttons do self.buttons[i]:Hide() end
    self.rows = #options > 0 and row + 1 or 0
    self:SetHeight(math.max(1, self.rows) * 26 - 2)
    return self.rows
  end
  return c
end

-- ---- items and spells on list rows ---------------------------------------------------
-- UI.ItemRow(row, x) gives a list row an icon (at x) and makes it hoverable: the game's own
-- item or spell tooltip, and shift-click to link it in chat. UI.SetRowItem fills it per item.
local pending, waiter = false, nil
local function waitForItems()
  if waiter then return end
  waiter = CreateFrame("Frame")
  waiter:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  waiter:SetScript("OnEvent", function()
    if not pending or waiter.queued then return end
    waiter.queued = true
    C_Timer.After(0.5, function()
      waiter.queued, pending = false, false
      if ns.RefreshUI then ns.RefreshUI() end
    end)
  end)
end

function UI.ItemLook(itemID)
  local name, link, quality
  if C_Item and C_Item.GetItemInfo then name, link, quality = C_Item.GetItemInfo(itemID)
  elseif GetItemInfo then name, link, quality = GetItemInfo(itemID) end
  if not name then
    pending = true; waitForItems()
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
  end
  local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)) or (GetItemIcon and GetItemIcon(itemID))
  return name, link, quality, icon
end

function UI.QualityColor(quality)
  if quality and C_Item and C_Item.GetItemQualityColor then
    local r, g, b = C_Item.GetItemQualityColor(quality)
    if r then return r, g, b end
  end
  if quality and GetItemQualityColor then return GetItemQualityColor(quality) end
  return unpack(C.text)
end

-- A recipe's materials from the website snapshot: by crafted item ID, else by recipe name.
function ns.MaterialsFor(itemID, name)
  local site = ns.Site and ns.Site()
  if not site then return nil end
  local m = itemID and type(site.mats) == "table" and site.mats[itemID]
  if not m and name and type(site.matsByName) == "table" then m = site.matsByName[name] end
  return type(m) == "table" and #m > 0 and m or nil
end

-- Add "Materials" lines to the open tooltip.
function UI.AddMaterials(tip, itemID, name)
  local mats = ns.MaterialsFor(itemID, name)
  if not mats then return end
  tip:AddLine(" ")
  tip:AddLine("Materials", UI.Accent())
  for _, m in ipairs(mats) do
    local id, qty, mname = m[1], m[2] or 1, m[3]
    local n, _, q, icon = UI.ItemLook(id)
    local r, g, b = UI.QualityColor(q)
    tip:AddLine(string.format("|T%s:14:14:0:0|t  %dx %s", tostring(icon or 134400), qty, n or mname or ("Item " .. id)), r, g, b)
  end
end

function UI.ItemRow(r, x)
  r.icon = r.icon or r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(20, 20); r.icon:ClearAllPoints(); r.icon:SetPoint("LEFT", x or 12, 0)
  r:HookScript("OnEnter", function(self)
    if not self.itemID and not self.spellID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local ok
    if self.itemID then ok = pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)
    else ok = pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID) end
    if not ok then GameTooltip:AddLine(self.tipName or "") end
    if self.showMats ~= false then UI.AddMaterials(GameTooltip, self.itemID, self.tipName) end
    if self.itemID then GameTooltip:AddLine("Shift-click to link it in chat.", 0.6, 0.63, 0.69) end
    GameTooltip:Show()
  end)
  r:HookScript("OnLeave", function() GameTooltip:Hide() end)
  r:HookScript("OnClick", function(self)
    if self.itemID and IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
      local _, link = UI.ItemLook(self.itemID)
      if link then ChatEdit_InsertLink(link) end
    end
  end)
end

-- Fill an item row: itemID (or spellID), the name to show if the game hasn't loaded it yet.
-- Colours r.name by item quality unless keepColor.
function UI.SetRowItem(r, itemID, spellID, name, keepColor)
  itemID = (itemID and itemID > 0) and itemID or nil
  r.itemID, r.spellID, r.tipName = itemID, (not itemID and spellID and spellID > 0) and spellID or nil, name
  local icon, quality
  if itemID then
    local n, _, q, ic = UI.ItemLook(itemID)
    icon, quality = ic, q
    name = name or n
  elseif r.spellID then
    if C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(r.spellID)
    elseif GetSpellTexture then icon = GetSpellTexture(r.spellID) end
  end
  r.icon:SetTexture(icon or 134400)
  if not keepColor and r.name then r.name:SetTextColor(UI.QualityColor(quality)) end
  return name
end

-- ---- dropdown ----------------------------------------------------------------------
-- A compact picker: a button showing the current choice that opens a list.
--   local d = UI.Dropdown(parent, width, title, onChange, multi)
--   d:SetOptions({ { value, label }, ... }, current)   current: a value, or for multi a set { [value] = true }
-- Single: picking closes the list and calls onChange(value).
-- Multi: rows toggle with a tick, the list stays open, onChange(set) is called on every change;
--        the first row clears the selection ("All ...").
local openMenu
local catcher
local function closeMenu()
  if openMenu then openMenu:Hide(); openMenu = nil end
  if catcher then catcher:Hide() end
end
UI.CloseDropdowns = closeMenu

function UI.Dropdown(parent, width, title, onChange, multi)
  local ROW, MAXROWS = 24, 14
  local d = CreateFrame("Button", nil, parent)
  d:SetSize(width, 26)
  UI.Fill(d, C.raised); UI.Border(d)
  local hover = UI.Fill(d, C.hover, "ARTWORK"); hover:Hide()
  d.title = UI.Text(d, 11, C.faint); d.title:SetPoint("LEFT", 10, 0); d.title:SetText(title or "")
  d.value = UI.Text(d, 12); d.value:SetPoint("LEFT", d.title, "RIGHT", 6, 0); d.value:SetPoint("RIGHT", d, "RIGHT", -22, 0)
  d.arrow = d:CreateTexture(nil, "OVERLAY"); d.arrow:SetSize(12, 12); d.arrow:SetPoint("RIGHT", -7, -1)
  d.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow"); d.arrow:SetRotation(-math.pi / 2); d.arrow:SetVertexColor(0.7, 0.72, 0.78)
  d.options, d.current, d.offset = {}, nil, 0

  local menu = CreateFrame("Frame", nil, d)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -3)
  UI.Fill(menu, C.surface); UI.Border(menu, { 1, 1, 1, 0.18 })
  menu:Hide(); menu:EnableMouse(true); menu:EnableMouseWheel(true)
  menu.rows = {}
  d.menu = menu

  local function isOn(v)
    if multi then return type(d.current) == "table" and d.current[v] == true end
    return d.current == v
  end
  local function summary()
    if not multi then
      for _, o in ipairs(d.options) do if o.value == d.current then return o.label end end
      return ""
    end
    local n, one = 0, nil
    for _, o in ipairs(d.options) do if isOn(o.value) then n = n + 1; one = o.label end end
    if n == 0 then return d.allLabel or "All" end
    return n == 1 and one or (n .. " selected")
  end
  local function draw()
    local list = {}
    if multi then list[1] = { clear = true, label = d.allLabel or "All" } end
    for _, o in ipairs(d.options) do list[#list + 1] = o end
    local shown = math.min(#list, MAXROWS)
    d.offset = math.max(0, math.min(d.offset, #list - shown))
    local widest = width
    for i = 1, shown do
      local r = menu.rows[i]
      if not r then
        r = CreateFrame("Button", nil, menu); r:SetHeight(ROW)
        r.hover = UI.Fill(r, C.hover, "ARTWORK"); r.hover:Hide()
        r.check = r:CreateTexture(nil, "OVERLAY"); r.check:SetSize(14, 14); r.check:SetPoint("LEFT", 6, 0)
        r.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        r.text = UI.Text(r, 12); r.text:SetPoint("LEFT", 26, 0)
        r:SetScript("OnEnter", function(s) s.hover:Show() end)
        r:SetScript("OnLeave", function(s) s.hover:Hide() end)
        r:SetScript("OnClick", function(s)
          local o = s.opt
          if multi then
            local set = {}
            if not o.clear then
              for k, v in pairs(type(d.current) == "table" and d.current or {}) do set[k] = v end
              set[o.value] = (not set[o.value]) or nil
            end
            d.current = set
            d.value:SetText(summary()); draw()
            onChange(set)
          else
            d.current = o.value
            d.value:SetText(summary())
            closeMenu()
            onChange(o.value)
          end
        end)
        menu.rows[i] = r
      end
      local o = list[i + d.offset]
      r.opt = o
      r.text:SetText(o.label)
      local on = o.clear and (multi and next(type(d.current) == "table" and d.current or {}) == nil) or (not o.clear and isOn(o.value))
      r.check:SetShown(on)
      if on then r.text:SetTextColor(UI.Accent()) else r.text:SetTextColor(unpack(C.text)) end
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 3, -3 - (i - 1) * ROW); r:SetPoint("RIGHT", menu, "RIGHT", -3, 0)
      r:Show()
      widest = math.max(widest, (r.text:GetStringWidth() or 0) + 44)
    end
    for i = shown + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetSize(widest, shown * ROW + 6)
  end
  menu:SetScript("OnMouseWheel", function(_, delta) d.offset = d.offset - delta * 3; draw() end)

  function d:SetOptions(options, current, allLabel)
    self.options, self.current, self.allLabel = options or {}, current, allLabel
    self.value:SetText(summary())
    if menu:IsShown() then draw() end
  end
  d:SetScript("OnEnter", function() hover:Show() end)
  d:SetScript("OnLeave", function() hover:Hide() end)
  d:SetScript("OnClick", function()
    if menu:IsShown() then closeMenu(); return end
    closeMenu()
    if not catcher then
      -- an invisible full-screen button under the list: a click anywhere else closes it
      catcher = CreateFrame("Button", nil, UIParent)
      catcher:SetAllPoints(UIParent); catcher:SetFrameStrata("FULLSCREEN")
      catcher:SetScript("OnClick", closeMenu)
    end
    catcher:Show()
    d.offset = 0
    draw()
    menu:Show(); openMenu = menu
  end)
  d:SetScript("OnHide", function() if openMenu == menu then closeMenu() end end)
  return d
end
