-- Foxden: the dashboard window (/fox). Resizable, with a sidebar of pages in
-- two sections, like the website. Pages live in UI/Pages/*.lua and register with
-- ns.RegisterPage; the run detail tabs (Overview, Fights, Map) are views in
-- Views/*.lua registered with ns.RegisterView and shown on the Runs page.

local ADDON, ns = ...
local UI = ns.UI
local C = UI.C

local HEADER_H, SIDE_W, PAD = 46, 172, 16
local MIN_W, MIN_H, MAX_W, MAX_H = 820, 520, 1700, 1100

-- ---- registries --------------------------------------------------------------

ns.views = {}
function ns.RegisterView(view)
  ns.views[#ns.views + 1] = view
  table.sort(ns.views, function(a, b) return (a.order or 50) < (b.order or 50) end)
end

-- A page: { key, label, section = "log"|"craft", order, Build(self, frame), Layout(self, w, h), Refresh(self, arg) }
ns.pages = {}
function ns.RegisterPage(page)
  ns.pages[#ns.pages + 1] = page
  table.sort(ns.pages, function(a, b) return (a.order or 50) < (b.order or 50) end)
end

local SECTIONS = { { key = "log", label = "Dungeon log" }, { key = "char", label = "Character" }, { key = "craft", label = "Crafting" }, { key = "guild", label = "Guild" } }

-- ---- helpers pages and views share -------------------------------------------

function ns.RunDuration(entry)
  if entry.live then return GetServerTime() - entry.run.startTime end
  return entry.run.duration or 0
end

function ns.ClassLookup(run)
  local map = {}
  for _, m in ipairs(run.party or {}) do map[m.name] = m.class end
  return function(name) return map[UI.ShortName(name)] end
end

function ns.Money(copper)
  if not copper or copper < 0 then return "—" end
  local g, s, c = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = "|cffe8c35a" .. g .. "g|r" end
  if s > 0 then parts[#parts + 1] = "|cffc7ccd4" .. s .. "s|r" end
  if c > 0 or #parts == 0 then parts[#parts + 1] = "|cffc47a4a" .. c .. "c|r" end
  return table.concat(parts, " ")
end

function ns.MoneyPlain(copper)
  copper = math.floor(copper or 0)
  local g, s, c = math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = g .. "g" end
  if s > 0 then parts[#parts + 1] = s .. "s" end
  if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
  return table.concat(parts, " ")
end

-- ---- window ------------------------------------------------------------------

local W, current, ticker, layoutTimer
local navButtons = {}

local function savePlace()
  local point, _, rel, x, y = W:GetPoint()
  ns.settings.window = { w = math.floor(W:GetWidth()), h = math.floor(W:GetHeight()), point = point, rel = rel, x = x, y = y }
end

local function layout()
  layoutTimer = nil
  if not current or not current.frame then return end
  local w, h = W.content:GetWidth(), W.content:GetHeight()
  if current.Layout then
    local ok, err = pcall(current.Layout, current, w, h)
    if not ok then geterrorhandler()("Foxden page " .. current.key .. ": " .. tostring(err)) end
  end
end

local function refresh(arg)
  if not current or not current.frame then return end
  local ok, err = pcall(current.Refresh, current, arg)
  if not ok then geterrorhandler()("Foxden page " .. current.key .. ": " .. tostring(err)) end
end

function ns.OpenPage(key, arg)
  if not W then ns.ToggleWindow() end
  if not W:IsShown() then W:Show() end
  local page
  for _, p in ipairs(ns.pages) do if p.key == key then page = p end end
  if not page then return end
  if current and current ~= page and current.frame then current.frame:Hide() end
  current = page
  if not page.frame then
    page.frame = CreateFrame("Frame", nil, W.content)
    page.frame:SetAllPoints()
    local ok, err = pcall(page.Build, page, page.frame)
    if not ok then geterrorhandler()("Foxden page " .. key .. ": " .. tostring(err)) end
  end
  page.frame:Show()
  ns.settings.page = key
  for _, b in ipairs(navButtons) do
    local on = b.key == key
    b.sel:SetShown(on); b.bar:SetShown(on)
    if on then b.bar:SetColorTexture(UI.Accent()); b.text:SetTextColor(unpack(C.text)) else b.text:SetTextColor(unpack(C.dim)) end
  end
  layout()
  refresh(arg)
end

local function build()
  W = CreateFrame("Frame", "FoxdenFrame", UIParent)
  local saved = ns.settings.window
  W:SetSize(saved and saved.w or 1000, saved and saved.h or 640)
  if saved and saved.point then W:SetPoint(saved.point, UIParent, saved.rel or saved.point, saved.x or 0, saved.y or 0) else W:SetPoint("CENTER") end
  W:SetFrameStrata("HIGH")
  W:SetToplevel(true)
  W:SetClampedToScreen(true)
  W:SetMovable(true)
  W:SetResizable(true)
  if W.SetResizeBounds then W:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
  elseif W.SetMinResize then W:SetMinResize(MIN_W, MIN_H); W:SetMaxResize(MAX_W, MAX_H) end
  W:EnableMouse(true)
  W:Hide()
  UI.Fill(W, C.bg)
  UI.Border(W, { 1, 1, 1, 0.10 })
  tinsert(UISpecialFrames, "FoxdenFrame") -- Escape closes it

  -- header (drag to move)
  local header = CreateFrame("Frame", nil, W)
  header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(HEADER_H)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() W:StartMoving() end)
  header:SetScript("OnDragStop", function() W:StopMovingOrSizing(); savePlace() end)
  local accent = header:CreateTexture(nil, "ARTWORK")
  accent:SetSize(3, 18); accent:SetPoint("LEFT", PAD, 0)
  UI.Accented(accent)
  local title = UI.Text(header, 15); title:SetPoint("LEFT", accent, "RIGHT", 10, 0); title:SetText("Foxden")
  W.siteAge = UI.Text(header, 11, C.faint); W.siteAge:SetPoint("LEFT", title, "RIGHT", 12, -1)
  local close = UI.CloseButton(header, function() W:Hide() end)
  close:SetPoint("RIGHT", -12, 0)
  local settings = UI.Button(header, "Settings", 80, 26, function() ns.OpenSettings() end)
  settings:SetPoint("RIGHT", close, "LEFT", -10, 0)
  local sync = UI.Button(header, "Sync", 70, 26, function() ns.Sync() end, "primary")
  sync:SetPoint("RIGHT", settings, "LEFT", -8, 0)
  sync:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Sync")
    GameTooltip:AddLine("Reloads your UI so WoW writes your runs and crafts to disk. The companion app then posts them to the website and Discord, and brings back the shop, costs and orders.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  sync:HookScript("OnLeave", GameTooltip_Hide)
  local hl = header:CreateTexture(nil, "BORDER")
  hl:SetColorTexture(unpack(C.line)); hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT"); hl:SetHeight(1)

  -- sidebar
  local side = CreateFrame("Frame", nil, W)
  side:SetPoint("TOPLEFT", 0, -HEADER_H - 1); side:SetPoint("BOTTOMLEFT", 0, 1); side:SetWidth(SIDE_W)
  UI.Fill(side, { 0, 0, 0, 0.18 })
  local div = W:CreateTexture(nil, "BORDER")
  div:SetColorTexture(unpack(C.line)); div:SetPoint("TOPLEFT", side, "TOPRIGHT"); div:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT"); div:SetWidth(1)
  local y = -14
  for _, s in ipairs(SECTIONS) do
    local label = UI.Text(side, 11, C.faint); label:SetPoint("TOPLEFT", PAD, y); label:SetText(s.label)
    y = y - 22
    for _, p in ipairs(ns.pages) do
      if p.section == s.key then
        local b = CreateFrame("Button", nil, side)
        b.key = p.key
        b:SetPoint("TOPLEFT", 8, y); b:SetPoint("RIGHT", side, "RIGHT", -8, 0); b:SetHeight(30)
        b.sel = UI.Fill(b, C.raised); b.sel:Hide()
        b.bar = b:CreateTexture(nil, "ARTWORK"); b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(2); b.bar:Hide()
        local hover = UI.Fill(b, C.hover, "ARTWORK"); hover:Hide()
        b.text = UI.Text(b, 13, C.dim); b.text:SetPoint("LEFT", 12, 0); b.text:SetText(p.label)
        b:SetScript("OnEnter", function() hover:Show() end)
        b:SetScript("OnLeave", function() hover:Hide() end)
        b:SetScript("OnClick", function() ns.OpenPage(p.key) end)
        navButtons[#navButtons + 1] = b
        y = y - 32
      end
    end
    y = y - 14
  end

  -- content
  W.content = CreateFrame("Frame", nil, W)
  W.content:SetPoint("TOPLEFT", side, "TOPRIGHT", 1, 0)
  W.content:SetPoint("BOTTOMRIGHT", 0, 1)

  -- resize grip
  local grip = CreateFrame("Button", nil, W)
  grip:SetSize(16, 16); grip:SetPoint("BOTTOMRIGHT", -2, 2)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetScript("OnMouseDown", function() W:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function() W:StopMovingOrSizing(); savePlace(); layout(); refresh() end)
  W:SetScript("OnSizeChanged", function()
    if not layoutTimer then layoutTimer = C_Timer.NewTimer(0.05, function() layout(); refresh() end) end
  end)

  W:SetScript("OnShow", function()
    W:SetScale(ns.settings.scale or 1)
    local site = ns.Site()
    W.siteAge:SetText(site and ("Shop and prices from " .. date("%b %d, %H:%M", site.at)) or "Shop, costs and orders need a guild website (optional)")
    ns.OpenPage(current and current.key or ns.settings.page or "overview")
    ticker = C_Timer.NewTicker(1, function()
      if ns.GetCurrentRun() and current and (current.key == "overview" or current.key == "runs") then refresh() end
    end)
  end)
  W:SetScript("OnHide", function() if ticker then ticker:Cancel(); ticker = nil end end)

  StaticPopupDialogs["FOXDEN_DELETE"] = {
    text = "Delete this run from the log?\n\nIf it was already posted, it stays in Discord and on the website.",
    button1 = DELETE or "Delete", button2 = CANCEL or "Cancel",
    OnAccept = function(_, id) ns.DeleteRun(id) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
  }
end

function ns.RefreshUI()
  if ns.RefreshSettings then ns.RefreshSettings() end
  if not W or not W:IsShown() then return end
  W:SetScale(ns.settings.scale or 1)
  refresh()
end

function ns.ToggleWindow()
  if not W then build() end
  if W:IsShown() then W:Hide() else W:Show() end
end

-- Minimap addon button (the addon compartment) entry
function Foxden_OnAddonCompartmentClick(_, button)
  if button == "RightButton" then ns.OpenSettings() else ns.ToggleWindow() end
end
function Foxden_OnAddonCompartmentEnter(_, frame)
  GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
  GameTooltip:SetText("Foxden")
  local run = ns.GetCurrentRun()
  if run then GameTooltip:AddLine("In progress: " .. (run.dungeon or "?"), 1, 1, 1) end
  GameTooltip:AddLine(#ns.GetRuns() .. " runs logged", 0.7, 0.7, 0.7)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Click to open the dashboard", 0.5, 0.9, 0.77)
  GameTooltip:AddLine("Right-click for settings", 0.5, 0.9, 0.77)
  GameTooltip:Show()
end
function Foxden_OnAddonCompartmentLeave() GameTooltip:Hide() end
