-- Foxden: shared look.
-- Flat dark surfaces, 1px hairlines, one accent color. When EllesmereUI is
-- installed, its skinning API hands us the player's accent color and UI font so
-- these windows sit comfortably next to the rest of their interface.

local ADDON, ns = ...
local UI = {}
ns.UI = UI

UI.C = {
  bg       = { 0.055, 0.060, 0.072, 1 },
  surface  = { 0.085, 0.092, 0.108, 1 },
  raised   = { 0.115, 0.124, 0.145, 1 },
  hover    = { 1, 1, 1, 0.05 },
  line     = { 1, 1, 1, 0.08 },
  text     = { 0.93, 0.94, 0.96, 1 },
  dim      = { 0.60, 0.63, 0.69, 1 },
  faint    = { 0.42, 0.45, 0.50, 1 },
  danger   = { 0.94, 0.42, 0.42, 1 },
}
local FOX = { 0.498, 0.890, 0.769 } -- #7FE3C4

local skin -- EllesmereUI skin handle, when available
local accented = {} -- { region, alpha, kind }

function UI.Accent()
  if skin and skin.IsEnabled and skin.IsEnabled() and skin.GetAccentColor then
    local r, g, b = skin.GetAccentColor()
    if r then return r, g, b end
  end
  return FOX[1], FOX[2], FOX[3]
end

function UI.Font()
  if skin and skin.IsEnabled and skin.IsEnabled() and skin.GetFont then
    local path = skin.GetFont()
    if path then return path end
  end
  return STANDARD_TEXT_FONT
end

-- Paint a texture or font string in the accent color and keep it in sync.
function UI.Accented(region, alpha)
  accented[#accented + 1] = { region, alpha or 1 }
  local r, g, b = UI.Accent()
  if region.SetColorTexture then region:SetColorTexture(r, g, b, alpha or 1)
  else region:SetTextColor(r, g, b, alpha or 1) end
  return region
end

local texts = {}
local function recolor()
  local r, g, b = UI.Accent()
  for _, a in ipairs(accented) do
    local region, alpha = a[1], a[2]
    if region.SetColorTexture then region:SetColorTexture(r, g, b, alpha)
    else region:SetTextColor(r, g, b, alpha) end
  end
  local font = UI.Font()
  for _, t in ipairs(texts) do t.fs:SetFont(font, t.size, "") end
  if ns.RefreshUI then ns.RefreshUI() end
end

if EllesmereUI and EllesmereUI.RegisterSkin then
  EllesmereUI.RegisterSkin(ADDON, function(S)
    skin = S
    if S.OnLooksChanged then S.OnLooksChanged(recolor) end
    recolor()
  end)
end

-- ---- primitives ------------------------------------------------------------

function UI.Fill(frame, color, layer)
  local t = frame:CreateTexture(nil, layer or "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(unpack(color))
  return t
end

-- 1px hairline border drawn inside the frame
function UI.Border(frame, color)
  color = color or UI.C.line
  local edges = {}
  for i, pts in ipairs({
    { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
    { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
  }) do
    local t = frame:CreateTexture(nil, "BORDER")
    t:SetColorTexture(unpack(color))
    t:SetPoint(pts[1]); t:SetPoint(pts[2])
    if pts[3] then t:SetWidth(pts[3]) else t:SetHeight(pts[4]) end
    edges[i] = t
  end
  return edges
end

function UI.Text(parent, size, color, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(UI.Font(), size, "")
  fs:SetTextColor(unpack(color or UI.C.text))
  fs:SetJustifyH(justify or "LEFT")
  fs:SetWordWrap(false)
  texts[#texts + 1] = { fs = fs, size = size }
  return fs
end

-- Flat button. style: nil (quiet), "primary" (accent), "danger"
function UI.Button(parent, label, width, height, onClick, style)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, height or 26)
  local bg = UI.Fill(b, style == "primary" and { 0, 0, 0, 0 } or UI.C.raised)
  if style == "primary" then UI.Accented(bg, 0.16) end
  UI.Border(b, UI.C.line)
  local hover = UI.Fill(b, UI.C.hover, "ARTWORK"); hover:Hide()
  b.label = UI.Text(b, 12, style == "danger" and UI.C.danger or UI.C.text, "CENTER")
  b.label:SetPoint("CENTER")
  b.label:SetText(label)
  if style == "primary" then UI.Accented(b.label) end
  b:SetScript("OnEnter", function() hover:Show() end)
  b:SetScript("OnLeave", function() hover:Hide() end)
  b:SetScript("OnClick", onClick)
  return b
end

-- Small square icon-less close button: an X drawn from two rotated lines
function UI.CloseButton(parent, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(24, 24)
  local hover = UI.Fill(b, UI.C.hover, "ARTWORK"); hover:Hide()
  for _, angle in ipairs({ 45, -45 }) do
    local l = b:CreateTexture(nil, "OVERLAY")
    l:SetColorTexture(unpack(UI.C.dim))
    l:SetSize(12, 1.5)
    l:SetPoint("CENTER")
    l:SetRotation(math.rad(angle))
  end
  b:SetScript("OnEnter", function() hover:Show() end)
  b:SetScript("OnLeave", function() hover:Hide() end)
  b:SetScript("OnClick", onClick)
  return b
end

-- A settings row: title and description on the left, control on the right.
local function settingRow(parent, width, title, desc)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width, desc and 52 or 40)
  row.title = UI.Text(row, 13)
  row.title:SetPoint("TOPLEFT", 0, desc and -10 or -13)
  row.title:SetText(title)
  if desc then
    row.desc = UI.Text(row, 11, UI.C.dim)
    row.desc:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -4)
    row.desc:SetPoint("RIGHT", row, "RIGHT", -150, 0)
    row.desc:SetText(desc)
  end
  local sep = row:CreateTexture(nil, "BORDER")
  sep:SetColorTexture(unpack(UI.C.line))
  sep:SetPoint("BOTTOMLEFT"); sep:SetPoint("BOTTOMRIGHT"); sep:SetHeight(1)
  return row
end

-- On/off switch. get() -> boolean, set(boolean)
function UI.Toggle(parent, width, title, desc, get, set)
  local row = settingRow(parent, width, title, desc)
  local sw = CreateFrame("Button", nil, row)
  sw:SetSize(38, 20)
  sw:SetPoint("RIGHT", 0, 0)
  local track = sw:CreateTexture(nil, "BACKGROUND"); track:SetAllPoints()
  local knob = sw:CreateTexture(nil, "ARTWORK"); knob:SetSize(14, 14)
  UI.Border(sw, UI.C.line)
  function row:Refresh()
    local on = get()
    if on then
      local r, g, b = UI.Accent()
      track:SetColorTexture(r, g, b, 0.85)
      knob:SetColorTexture(0.05, 0.06, 0.07, 1)
      knob:ClearAllPoints(); knob:SetPoint("RIGHT", -3, 0)
    else
      track:SetColorTexture(unpack(UI.C.raised))
      knob:SetColorTexture(unpack(UI.C.dim))
      knob:ClearAllPoints(); knob:SetPoint("LEFT", 3, 0)
    end
  end
  sw:SetScript("OnClick", function() set(not get()); row:Refresh() end)
  row:EnableMouse(true)
  row:SetScript("OnMouseUp", function() set(not get()); row:Refresh() end)
  row:Refresh()
  return row
end

-- Pick one of a list of values with < and > arrows.
-- values = { {value, "label"}, ... }
function UI.Stepper(parent, width, title, desc, values, get, set)
  local row = settingRow(parent, width, title, desc)
  local box = CreateFrame("Frame", nil, row)
  box:SetSize(132, 24)
  box:SetPoint("RIGHT")
  UI.Fill(box, UI.C.raised); UI.Border(box)
  local label = UI.Text(box, 12, UI.C.text, "CENTER")
  label:SetPoint("CENTER")
  local function index()
    local cur = get()
    for i, v in ipairs(values) do if v[1] == cur then return i end end
    return 1
  end
  local function arrow(text, delta, point)
    local b = CreateFrame("Button", nil, box)
    b:SetSize(24, 24); b:SetPoint(point)
    local hover = UI.Fill(b, UI.C.hover, "ARTWORK"); hover:Hide()
    local fs = UI.Text(b, 13, UI.C.dim, "CENTER"); fs:SetPoint("CENTER"); fs:SetText(text)
    b:SetScript("OnEnter", function() hover:Show() end)
    b:SetScript("OnLeave", function() hover:Hide() end)
    b:SetScript("OnClick", function()
      local i = math.max(1, math.min(#values, index() + delta))
      set(values[i][1]); row:Refresh()
    end)
    return b
  end
  local prev, nextB = arrow("<", -1, "LEFT"), arrow(">", 1, "RIGHT")
  function row:Refresh()
    local i = index()
    label:SetText(values[i][2])
    prev:SetAlpha(i > 1 and 1 or 0.3)
    nextB:SetAlpha(i < #values and 1 or 0.3)
  end
  row:Refresh()
  return row
end

function UI.SectionLabel(parent, text)
  local fs = UI.Text(parent, 11, nil)
  UI.Accented(fs)
  fs:SetText(text:upper())
  return fs
end

-- ---- formatting ------------------------------------------------------------

function UI.Time(s)
  s = math.max(0, math.floor((s or 0) + 0.5))
  local floor = math.floor
  if s >= 3600 then return string.format("%d:%02d:%02d", floor(s / 3600), floor((s % 3600) / 60), s % 60) end
  return string.format("%d:%02d", floor(s / 60), s % 60)
end

function UI.Num(n)
  n = n or 0
  if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
  if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
  if n >= 1e4 then return string.format("%.0fk", n / 1e3) end
  if n >= 1e3 then return string.format("%.1fk", n / 1e3) end
  return tostring(math.floor(n + 0.5))
end

function UI.ClassColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 0.62, 0.65, 0.70
end

function UI.ClassName(class)
  if not class then return "" end
  if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] then
    return LOCALIZED_CLASS_NAMES_MALE[class]
  end
  return class:sub(1, 1) .. class:sub(2):lower()
end

-- "Name-Realm" and "Name" refer to the same player in stats and party lists
function UI.ShortName(name)
  return name and (name:gsub("%-.*$", "")) or "?"
end
