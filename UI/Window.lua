-- Foxden: the dashboard window (/fox). Resizable. Four places in the sidebar (Home,
-- Dungeons, Crafting, Guild), each with a few tabs across the top; a search box in the
-- header finds dungeons, bosses, quests, loot and recipes. Pages live in UI/Pages/*.lua
-- and register with ns.RegisterPage; the run detail tabs (Overview, Fights, Map) are
-- views in Views/*.lua registered with ns.RegisterView and shown on the runs page.

local ADDON, ns = ...
local UI = ns.UI
local C = UI.C

local HEADER_H, SIDE_W, PAD, TABS_H = 50, 156, 16, 40
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

-- The sidebar: four places, each a set of pages shown as tabs.
local NAV = {
  { key = "home", label = "Home", icon = "Interface\\Icons\\Spell_Nature_SpiritWolf", pages = { "overview", "trainer", "wishlist", "notes" } },
  { key = "dungeons", label = "Dungeons", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01", pages = { "journal", "runs" } },
  { key = "crafting", label = "Crafting", icon = "Interface\\Icons\\Trade_BlackSmithing", pages = { "recipes", "planner", "crafters", "orders" } },
  { key = "guild", label = "Guild", icon = "Interface\\Icons\\INV_Shirt_GuildTabard_01", pages = { "roster", "rares", "leveling", "players" } },
}
local function groupOf(key)
  for _, g in ipairs(NAV) do
    if g.key == key then return g, g.pages[1] end
    for _, p in ipairs(g.pages) do if p == key then return g, p end end
  end
end

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

-- "5 min ago", "3 h ago", "Nov 12"
function ns.Ago(t)
  local s = math.max(0, GetServerTime() - (t or 0))
  if s < 90 then return "just now" end
  if s < 3600 then return math.floor(s / 60) .. " min ago" end
  if s < 86400 then return math.floor(s / 3600) .. " h ago" end
  return date("%b %d", t)
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

local tabButtons = {}
local function drawTabs(group, key)
  local r, g, b = UI.Accent()
  local x = PAD - 4
  for i, pkey in ipairs(group.pages) do
    local t = tabButtons[i]
    if not t then
      t = CreateFrame("Button", nil, W.tabs)
      t.text = UI.Text(t, 13, C.dim, "CENTER"); t.text:SetPoint("CENTER")
      t.under = t:CreateTexture(nil, "ARTWORK"); t.under:SetPoint("BOTTOMLEFT", 8, 0); t.under:SetPoint("BOTTOMRIGHT", -8, 0); t.under:SetHeight(2)
      t:SetScript("OnClick", function(self) ns.OpenPage(self.key) end)
      t:SetScript("OnEnter", function(self) if not self.on then self.text:SetTextColor(unpack(C.text)) end end)
      t:SetScript("OnLeave", function(self) if not self.on then self.text:SetTextColor(unpack(C.dim)) end end)
      tabButtons[i] = t
    end
    local page
    for _, p in ipairs(ns.pages) do if p.key == pkey then page = p end end
    t.key, t.on = pkey, pkey == key
    t.text:SetText(page and page.label or pkey)
    t:SetSize(math.floor((t.text:GetStringWidth() or 60) + 0.5) + 28, TABS_H)
    t:ClearAllPoints(); t:SetPoint("BOTTOMLEFT", x, 0)
    x = x + t:GetWidth()
    t.under:SetShown(t.on); t.under:SetColorTexture(r, g, b, 1)
    t.text:SetTextColor(unpack(t.on and C.text or C.dim))
    t:SetShown(page ~= nil)
  end
  for i = #group.pages + 1, #tabButtons do tabButtons[i]:Hide() end
end

-- key: a page ("journal") or a place ("dungeons": opens the tab you last used there).
function ns.OpenPage(key, arg)
  if not W then ns.ToggleWindow() end
  if not W:IsShown() then W:Show() end
  if key == "shop" or key == "costs" then key = "recipes" end -- older names
  local group, pkey = groupOf(key)
  if not group then return end
  ns.settings.tabs = ns.settings.tabs or {}
  if key == group.key then pkey = ns.settings.tabs[group.key] or pkey end
  local page
  for _, p in ipairs(ns.pages) do if p.key == pkey then page = p end end
  if not page then return end
  if current and current ~= page and current.frame then current.frame:Hide() end
  current = page
  if not page.frame then
    page.frame = CreateFrame("Frame", nil, W.content)
    page.frame:SetAllPoints()
    local ok, err = pcall(page.Build, page, page.frame)
    if not ok then geterrorhandler()("Foxden page " .. pkey .. ": " .. tostring(err)) end
  end
  page.frame:Show()
  ns.settings.page = pkey
  ns.settings.tabs[group.key] = pkey
  for _, b in ipairs(navButtons) do
    local on = b.key == group.key
    b.sel:SetShown(on); b.bar:SetShown(on)
    b.icon:SetDesaturated(not on); b.icon:SetAlpha(on and 1 or 0.7)
    if on then b.bar:SetColorTexture(UI.Accent()); b.text:SetTextColor(unpack(C.text)) else b.text:SetTextColor(unpack(C.dim)) end
  end
  drawTabs(group, pkey)
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
  local title = UI.Text(header, 16); title:SetPoint("LEFT", accent, "RIGHT", 10, 0); title:SetText("Foxden")
  local close = UI.CloseButton(header, function() W:Hide() end)
  close:SetPoint("RIGHT", -12, 0)
  local settings = UI.Button(header, "Settings", 80, 26, function() ns.OpenSettings() end)
  settings:SetPoint("RIGHT", close, "LEFT", -10, 0)
  local sync = UI.Button(header, "Sync", 70, 26, function() ns.Sync() end, "primary")
  sync:SetPoint("RIGHT", settings, "LEFT", -8, 0)
  sync:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Sync")
    GameTooltip:AddLine("Reloads your UI so the game saves your runs and crafts. The companion app then sends them to the guild website and Discord, and brings back quests, loot lists and crafting data.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  sync:HookScript("OnLeave", GameTooltip_Hide)
  W.siteAge = UI.Text(header, 11, C.faint, "RIGHT"); W.siteAge:SetPoint("RIGHT", sync, "LEFT", -14, 0)
  if ns.BuildSearch then ns.BuildSearch(W, header, SIDE_W + PAD) end
  local hl = header:CreateTexture(nil, "BORDER")
  hl:SetColorTexture(unpack(C.line)); hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT"); hl:SetHeight(1)

  -- sidebar
  local side = CreateFrame("Frame", nil, W)
  side:SetPoint("TOPLEFT", 0, -HEADER_H - 1); side:SetPoint("BOTTOMLEFT", 0, 1); side:SetWidth(SIDE_W)
  UI.Fill(side, { 0, 0, 0, 0.18 })
  local div = W:CreateTexture(nil, "BORDER")
  div:SetColorTexture(unpack(C.line)); div:SetPoint("TOPLEFT", side, "TOPRIGHT"); div:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT"); div:SetWidth(1)
  local y = -12
  for _, g in ipairs(NAV) do
    local b = CreateFrame("Button", nil, side)
    b.key = g.key
    b:SetPoint("TOPLEFT", 8, y); b:SetPoint("RIGHT", side, "RIGHT", -8, 0); b:SetHeight(40)
    b.sel = UI.Fill(b, C.raised); b.sel:Hide()
    b.bar = b:CreateTexture(nil, "ARTWORK"); b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(2); b.bar:Hide()
    local hover = UI.Fill(b, C.hover, "ARTWORK"); hover:Hide()
    b.icon = b:CreateTexture(nil, "OVERLAY"); b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 12, 0)
    b.icon:SetTexture(g.icon); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.text = UI.Text(b, 14, C.dim); b.text:SetPoint("LEFT", 42, 0); b.text:SetText(g.label)
    b:SetScript("OnEnter", function() hover:Show() end)
    b:SetScript("OnLeave", function() hover:Hide() end)
    b:SetScript("OnClick", function() ns.OpenPage(g.key) end)
    navButtons[#navButtons + 1] = b
    y = y - 44
  end

  -- content
  W.tabs = CreateFrame("Frame", nil, W)
  W.tabs:SetPoint("TOPLEFT", side, "TOPRIGHT", 1, 0); W.tabs:SetPoint("RIGHT", W, "RIGHT", 0, 0); W.tabs:SetHeight(TABS_H)
  local tl = W.tabs:CreateTexture(nil, "BORDER")
  tl:SetColorTexture(unpack(C.line)); tl:SetPoint("BOTTOMLEFT"); tl:SetPoint("BOTTOMRIGHT"); tl:SetHeight(1)
  W.content = CreateFrame("Frame", nil, W)
  W.content:SetPoint("TOPLEFT", W.tabs, "BOTTOMLEFT", 0, 0)
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
    W.siteAge:SetText(site and ("Synced " .. ns.Ago(site.at)) or "Not synced with a guild website")
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
  if button == "RightButton" then ns.OpenSettings()
  elseif IsShiftKeyDown and IsShiftKeyDown() and ns.ToggleNote then ns.ToggleNote()
  else ns.ToggleWindow() end
end
function Foxden_OnAddonCompartmentEnter(_, frame)
  GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
  GameTooltip:SetText("Foxden")
  local run = ns.LiveRun()
  if run then GameTooltip:AddLine("In progress: " .. (run.dungeon or "?"), 1, 1, 1) end
  GameTooltip:AddLine(#ns.GetRuns() .. " runs logged", 0.7, 0.7, 0.7)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Click to open the dashboard", 0.5, 0.9, 0.77)
  GameTooltip:AddLine("Shift-click for a quick note", 0.5, 0.9, 0.77)
  GameTooltip:AddLine("Right-click for settings", 0.5, 0.9, 0.77)
  GameTooltip:Show()
end
function Foxden_OnAddonCompartmentLeave() GameTooltip:Hide() end
