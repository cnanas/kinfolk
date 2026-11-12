-- Foxden: the "copy this run" box. The game can't reach the internet, so after a
-- run (for players without the companion app) Foxden shows the run as text,
-- already selected: Ctrl+C, then paste it on the guild website's "Post a run" page.
-- /fox copy shows it for the last run.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local W

local function build()
  W = CreateFrame("Frame", "FoxdenCopyRun", UIParent)
  W:SetSize(460, 214)
  W:SetPoint("TOP", 0, -140)
  W:SetFrameStrata("DIALOG")
  W:SetToplevel(true)
  W:EnableMouse(true)
  W:SetMovable(true)
  W:RegisterForDrag("LeftButton")
  W:SetScript("OnDragStart", W.StartMoving)
  W:SetScript("OnDragStop", W.StopMovingOrSizing)
  UI.Fill(W, C.bg); UI.Border(W, { 1, 1, 1, 0.14 })
  tinsert(UISpecialFrames, "FoxdenCopyRun")

  local accent = W:CreateTexture(nil, "ARTWORK"); accent:SetSize(3, 20); accent:SetPoint("TOPLEFT", 20, -20); UI.Accented(accent)
  W.title = UI.Text(W, 16); W.title:SetPoint("LEFT", accent, "RIGHT", 10, 0)
  local close = UI.CloseButton(W, function() W:Hide() end); close:SetPoint("TOPRIGHT", -10, -10)

  W.help = UI.Text(W, 12, C.dim); W.help:SetPoint("TOPLEFT", accent, "BOTTOMLEFT", 0, -12); W.help:SetWidth(420); W.help:SetWordWrap(true)

  W.box = UI.CopyBox(W, 420)
  W.box:SetMaxLetters(0)
  W.box:SetPoint("TOPLEFT", W.help, "BOTTOMLEFT", 0, -12)
  -- after Ctrl+C, close on its own
  W.box:SetScript("OnKeyDown", function(_, key)
    if key == "C" and (IsControlKeyDown() or IsMetaKeyDown and IsMetaKeyDown()) then
      C_Timer.After(0.1, function() W.copied:Show(); C_Timer.After(1.2, function() W:Hide() end) end)
    end
  end)
  W.copied = UI.Text(W, 12, C.good or C.dim); W.copied:SetPoint("TOPLEFT", W.box, "BOTTOMLEFT", 0, -8); W.copied:SetText("Copied. Now paste it on the website."); W.copied:Hide()

  W.note = UI.Text(W, 11, C.faint); W.note:SetPoint("BOTTOMLEFT", 20, 22); W.note:SetWidth(260); W.note:SetWordWrap(true)
  local stop = UI.Button(W, "Don't show after runs", 160, 26, function()
    ns.settings.copyPopup = false
    ns.say("The copy box won't open after runs. /fox copy still shows it; turn it back on in Settings.", true)
    W:Hide()
  end)
  stop:SetPoint("BOTTOMRIGHT", -20, 18)
end

function ns.ShowCopyRun(run)
  run = run or ns.GetRuns()[#ns.GetRuns()]
  if not run then ns.say("No saved runs yet.", true); return end
  if not W then build() end
  W.title:SetText("Run saved: " .. (run.dungeon or "dungeon"))
  local site = ns.SiteUrl and ns.SiteUrl()
  W.help:SetText("Press Ctrl+C (Cmd+C on a Mac) to copy it, then paste it on " ..
    (site and (site:gsub("^https?://", "") .. "/post") or "your guild website's \"Post a run\" page") .. ". It's posted to Discord from there.")
  W.note:SetText(ns.IsCourier and not ns.IsCourier()
    and "No rush: Foxden also hands it to a guildmate who runs the companion, next time you're both online."
    or "")
  W.copied:Hide()
  W.box:SetLink(ns.RunCode(run))
  W:Show()
  W.box:SetFocus()
  W.box:HighlightText()
end

ns.RegisterModule({
  name = "CopyRun",
  OnRunSaved = function(_, run)
    if ns.settings.copyPopup and ns.settings.welcomed and not (ns.IsCourier and ns.IsCourier()) then
      C_Timer.After(1.5, function() if not InCombatLockdown() then ns.ShowCopyRun(run) end end)
    end
  end,
})
