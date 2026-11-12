-- Foxden: the first-run popup. Asks what to share with the guild. Both
-- start switched on, but nothing is shared until "Save and start" is pressed;
-- closing the window shares nothing and asks again next login. /fox welcome reopens it.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local W

local choice = { location = true, professions = true }

local function build()
  W = CreateFrame("Frame", "FoxdenWelcome", UIParent)
  W:SetSize(520, 330)
  W:SetPoint("CENTER", 0, 60)
  W:SetFrameStrata("DIALOG")
  W:SetToplevel(true)
  W:EnableMouse(true)
  W:SetMovable(true)
  W:RegisterForDrag("LeftButton")
  W:SetScript("OnDragStart", W.StartMoving)
  W:SetScript("OnDragStop", W.StopMovingOrSizing)
  UI.Fill(W, C.bg); UI.Border(W, { 1, 1, 1, 0.14 })
  tinsert(UISpecialFrames, "FoxdenWelcome")

  local accent = W:CreateTexture(nil, "ARTWORK"); accent:SetSize(3, 22); accent:SetPoint("TOPLEFT", 22, -22); UI.Accented(accent)
  local title = UI.Text(W, 18); title:SetPoint("LEFT", accent, "RIGHT", 10, 0); title:SetText("Welcome to Foxden")
  local close = UI.CloseButton(W, function() W:Hide() end); close:SetPoint("TOPRIGHT", -10, -10)
  local intro = UI.Text(W, 12, C.dim); intro:SetPoint("TOPLEFT", accent, "BOTTOMLEFT", 0, -14); intro:SetWidth(476); intro:SetWordWrap(true)
  intro:SetText("Choose what your guild can see. You can change these any time in Settings > AddOns > Foxden.")

  local r1 = UI.Toggle(W, 476, "Share my location with the guild",
    "Guildmates with Foxden see your zone and position on their map. Never inside dungeons or raids.",
    function() return choice.location end, function(v) choice.location = v end)
  r1:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -16)
  local r2 = UI.Toggle(W, 476, "Share my professions with the guild",
    "So guildmates can find you as a crafter. Your bags and gold are never shared.",
    function() return choice.professions end, function(v) choice.professions = v end)
  r2:SetPoint("TOPLEFT", r1, "BOTTOMLEFT", 0, -6)
  W.rows = { r1, r2 }

  local save = UI.Button(W, "Save and start", 150, 30, function()
    ns.settings.welcomed = true
    ns.settings.share = choice.professions
    if ns.SetShareLocation then ns.SetShareLocation(choice.location) else ns.settings.shareLocation = choice.location end
    if choice.professions and ns.ShareProfessions then ns.ShareProfessions(true) end
    ns.say(string.format("Saved. Location sharing %s, profession sharing %s.", choice.location and "on" or "off", choice.professions and "on" or "off"), true)
    W:Hide()
    ns.Changed()
  end, "primary")
  save:SetPoint("BOTTOMRIGHT", -22, 22)
  local later = UI.Text(W, 11, C.faint); later:SetPoint("BOTTOMLEFT", 22, 30); later:SetWidth(300); later:SetWordWrap(true)
  later:SetText("Closing this window shares nothing; it will ask again next time.")
end

function ns.ShowWelcome()
  if not W then build() end
  -- first time: both on; afterwards: what was chosen before
  if ns.settings.welcomed then choice.location, choice.professions = ns.settings.shareLocation == true, ns.settings.share == true
  else choice.location, choice.professions = true, true end
  for _, r in ipairs(W.rows) do r:Refresh() end
  W:Show()
end

ns.RegisterModule({
  name = "Welcome",
  events = {
    PLAYER_LOGIN = function() C_Timer.After(6, function() if not ns.settings.welcomed then ns.ShowWelcome() end end) end,
  },
})
