-- Foxden: the page under Settings > AddOns.

local ADDON, ns = ...
local UI = ns.UI
local C = UI.C

local CONTENT_W = 560

-- root is what Settings shows; the content scrolls inside it (mouse wheel), so
-- nothing is cut off on short screens.
local rows = {}
local root = CreateFrame("Frame")
root.name = "Foxden"
local scroll = CreateFrame("ScrollFrame", nil, root)
scroll:SetAllPoints()
local panel = CreateFrame("Frame", nil, scroll)
panel:SetSize(CONTENT_W + 40, 1200)
scroll:SetScrollChild(panel)
scroll:EnableMouseWheel(true)
local function maxScroll()
  local last = rows[#rows]
  if not (last and last:GetBottom() and panel:GetTop()) then return 0 end
  return math.max(0, (panel:GetTop() - last:GetBottom()) + 24 - scroll:GetHeight())
end
scroll:SetScript("OnMouseWheel", function(self, delta)
  self:SetVerticalScroll(math.min(maxScroll(), math.max(0, self:GetVerticalScroll() - delta * 40)))
end)
scroll:SetScript("OnSizeChanged", function(self, w) panel:SetWidth(math.max(CONTENT_W + 40, w or 0)) end)

local function set(key) return function(v) ns.settings[key] = v; if ns.RefreshUI then ns.RefreshUI() end end end
local function get(key) return function() return ns.settings[key] end end

-- header
local accent = panel:CreateTexture(nil, "ARTWORK")
accent:SetSize(3, 22); accent:SetPoint("TOPLEFT", 20, -20)
UI.Accented(accent)
local title = UI.Text(panel, 20)
title:SetPoint("LEFT", accent, "RIGHT", 10, 0)
title:SetText("Foxden")
local version = UI.Text(panel, 11, C.faint)
version:SetPoint("LEFT", title, "RIGHT", 10, -2)
local meta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
version:SetText(meta and ("v" .. (meta(ADDON, "Version") or "")) or "")
local intro = UI.Text(panel, 12, C.dim)
intro:SetPoint("TOPLEFT", accent, "BOTTOMLEFT", 0, -10)
intro:SetText("Your guild's dungeon log, journal, roster and crafting, in game.")

-- actions
local open = UI.Button(panel, "Open dashboard", 130, 28, function()
  if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
  ns.ToggleWindow()
end, "primary")
open:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -16)
local sync = UI.Button(panel, "Sync to Discord", 130, 28, function() ns.Sync() end)
sync:SetPoint("LEFT", open, "RIGHT", 8, 0)

-- status card
local card = CreateFrame("Frame", nil, panel)
card:SetSize(CONTENT_W, 56)
card:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -16)
UI.Fill(card, C.surface); UI.Border(card)
local dot = card:CreateTexture(nil, "ARTWORK")
dot:SetSize(8, 8); dot:SetPoint("TOPLEFT", 14, -16)
local status = UI.Text(card, 13); status:SetPoint("LEFT", dot, "RIGHT", 10, 0)
local statusSub = UI.Text(card, 11, C.dim); statusSub:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -6)

-- sections
local function section(label, anchor, gap)
  local fs = UI.SectionLabel(panel, label)
  fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or 24))
  return fs
end
local function add(row, anchor, first)
  row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, first and -4 or 0)
  rows[#rows + 1] = row
  return row
end

local s1 = section("Logging", card)
local r1 = add(UI.Toggle(panel, CONTENT_W, "Track dungeon runs",
  "Start a run automatically when you enter a dungeon.", get("track"), set("track")), s1, true)
local r2 = add(UI.Toggle(panel, CONTENT_W, "Chat messages",
  "Say in chat when a run starts and when it's saved.", get("chat"), set("chat")), r1)
local r3 = add(UI.Toggle(panel, CONTENT_W, "Sync reminder",
  "Remind you to sync after each run so it reaches Discord.", get("remind"), set("remind")), r2)
local r4 = add(UI.Toggle(panel, CONTENT_W, "Show the copy box after runs",
  "If you don't run the companion app: the run, ready to paste on the guild website.", get("copyPopup"), set("copyPopup")), r3)

local r5 = add(UI.Toggle(panel, CONTENT_W, "Dungeon tracker",
  "A small window in dungeons: time inside, XP gained, gold looted and which bosses are down.", get("tracker"), function(v) ns.settings.tracker = v; if ns.RefreshTracker then ns.RefreshTracker() end end), r4)

local sL = section("Leveling", r5)
local rL1 = add(UI.Toggle(panel, CONTENT_W, "Show the level-up card",
  "Your gains, how long the level took, what's new at your trainer and guildmates near your level.", get("levelCard"), set("levelCard")), sL, true)
local rL2 = add(UI.Toggle(panel, CONTENT_W, "Tell the guild when I level up",
  "Guildmates with Foxden see a small \"reached level\" note. Only your level is sent.", get("shareLevelUps"), set("shareLevelUps")), rL1)
local rL3 = add(UI.Toggle(panel, CONTENT_W, "Show when guildmates level up",
  "A small note at the top of the screen for a few seconds.", get("guildDings"), set("guildDings")), rL2)
local rL4 = add(UI.Toggle(panel, CONTENT_W, "\"Learn all\" button at your trainer",
  "Learns every available ability in one click, except ones you skipped on the Trainer page.", get("learnAll"), set("learnAll")), rL3)
local rL5 = add(UI.Toggle(panel, CONTENT_W, "Screenshot every 10 levels",
  "Takes a screenshot with the level-up card on milestone levels.", get("levelScreenshot"), set("levelScreenshot")), rL4)

local sC = section("Crafting", rL5)
local rC = add(UI.Toggle(panel, CONTENT_W, "Share my professions with the guild",
  "Guildmates with the addon see what you can craft. Bags and bank are never shared.", get("share"), function(v)
    ns.settings.share = v
    if v and ns.ShareProfessions then ns.ShareProfessions(true) end
    if ns.RefreshUI then ns.RefreshUI() end
  end), sC, true)
local rO = add(UI.Toggle(panel, CONTENT_W, "Take craft requests from guildmates",
  "Guildmates can request your crafts on the website. Free: they bring the materials.", get("offer"), function(v)
    ns.settings.offer = v
    if ns.ShareProfessions then ns.ShareProfessions(true) end
    if ns.RefreshUI then ns.RefreshUI() end
  end), rC)

local rL = add(UI.Toggle(panel, CONTENT_W, "Share my location with the guild",
  "Guildmates see your zone and position on their map (and signed-in members on the guild website). Never inside dungeons or raids.", get("shareLocation"), function(v)
    if ns.SetShareLocation then ns.SetShareLocation(v) else ns.settings.shareLocation = v end
    if ns.RefreshUI then ns.RefreshUI() end
  end), rO)

local s2 = section("History and window", rL)
local r4 = add(UI.Stepper(panel, CONTENT_W, "Keep runs",
  "Older runs are removed from the game's log. Discord keeps everything.",
  { { 25, "Last 25" }, { 50, "Last 50" }, { 100, "Last 100" }, { 250, "Last 250" }, { 0, "All" } },
  get("keep"), function(v) ns.settings.keep = v; if ns.Prune and ns.db then ns.Prune() end; if ns.RefreshUI then ns.RefreshUI() end end), s2, true)
add(UI.Stepper(panel, CONTENT_W, "Dashboard scale", "Size of everything in the /fox window. Drag its corner to resize the window itself.",
  { { 0.8, "80%" }, { 0.9, "90%" }, { 1, "100%" }, { 1.1, "110%" }, { 1.2, "120%" }, { 1.3, "130%" } },
  get("scale"), set("scale")), r4)

function ns.RefreshSettings()
  for _, r in ipairs(rows) do r:Refresh() end
  local run = ns.GetCurrentRun and ns.GetCurrentRun()
  local count = ns.GetRuns and #ns.GetRuns() or 0
  if run then
    dot:SetColorTexture(UI.Accent())
    status:SetText("Logging " .. (run.dungeon or "a dungeon"))
    statusSub:SetText(string.format("%d fights counted  ·  %d bosses down  ·  %d wipes", run.fights or 0, #(run.bosses or {}), run.wipes or 0))
  else
    if ns.settings.track then dot:SetColorTexture(unpack(C.dim)) else dot:SetColorTexture(unpack(C.danger)) end
    status:SetText(ns.settings.track and "Ready. The next dungeon you enter is logged." or "Tracking is off")
    statusSub:SetText(count .. (count == 1 and " run" or " runs") .. " in the log"
      .. ((ns.MeterReady and not ns.MeterReady()) and "  ·  Damage meter unavailable, time and bosses only" or ""))
  end
end

-- the page is already "shown" when Settings first displays it, so refresh on open too
root:SetScript("OnShow", function() ns.RefreshSettings() end)

local category
if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
  category = Settings.RegisterCanvasLayoutCategory(root, "Foxden")
  category.ID = "Foxden"
  Settings.RegisterAddOnCategory(category)
elseif InterfaceOptions_AddCategory then
  InterfaceOptions_AddCategory(root)
end

function ns.OpenSettings()
  if category and Settings.OpenToCategory then
    Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(root)
    InterfaceOptionsFrame_OpenToCategory(root)
  end
end
