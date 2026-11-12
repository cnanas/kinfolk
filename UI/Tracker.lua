-- Foxden: the dungeon tracker. A small window while you're in a dungeon run:
-- time inside, XP gained, gold looted, and the dungeon's bosses (grey until killed).
-- XP and gold are also saved on the run (run.xp, run.gold).
-- Drag to move (position is remembered); X hides it for this run.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local W = 236
local frame, hiddenFor
local ICON = 24

-- ---- counting XP and gold ------------------------------------------------------

local function xpNow()
  return UnitXP and UnitXP("player") or 0, UnitXPMax and UnitXPMax("player") or 0, UnitLevel("player") or 0
end

local function startCounting(run)
  local xp, max, level = xpNow()
  run._xp = { last = xp, max = max, level = level }
  run._money = GetMoney and GetMoney() or 0
  run.xp, run.gold = run.xp or 0, run.gold or 0
end

local function onXP(run)
  if not run or not run._xp then return end
  local xp, max, level = xpNow()
  local t = run._xp
  if level > t.level then
    run.xp = run.xp + math.max(0, t.max - t.last) + xp -- finished the old level, plus progress into the new one
  elseif xp >= t.last then
    run.xp = run.xp + (xp - t.last)
  end
  t.last, t.max, t.level = xp, max, level
end

local function onMoney(run)
  if not run or not run._money or not GetMoney then return end
  local now = GetMoney()
  if now > run._money then run.gold = (run.gold or 0) + (now - run._money) end -- earnings only; spending doesn't count against it
  run._money = now
end

-- ---- the dungeon's bosses, from the journal Foxden read ----------------------------

local function bossesFor(name)
  local want = ns.Slug and ns.Slug(name)
  for _, d in ipairs(ns.db and ns.db.journal and ns.db.journal.dungeons or {}) do
    if ns.Slug(d.name) == want then return d.bosses or {} end
  end
  return {}
end

local function portrait(b)
  if b._icon ~= nil then return b._icon end
  b._icon = false
  if EJ_GetCreatureInfo and b.id then
    local ok, _, _, _, _, icon = pcall(EJ_GetCreatureInfo, 1, b.id)
    if ok and icon and not ns.IsSecret(icon) then b._icon = icon end
  end
  return b._icon
end

local function killed(run, b)
  for _, k in ipairs(run.bosses or {}) do
    if (b.encounterID and k.id == b.encounterID) or k.name == b.name then return true end
  end
  return false
end

-- ---- the window ------------------------------------------------------------------------

local function build()
  frame = CreateFrame("Frame", "FoxdenTracker", UIParent)
  frame:SetSize(W, 120)
  frame:SetFrameStrata("MEDIUM")
  frame:SetClampedToScreen(true)
  frame:EnableMouse(true); frame:SetMovable(true); frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.settings.trackerPos = { p, rp, x, y }
  end)
  UI.Fill(frame, C.bg); UI.Border(frame, { 1, 1, 1, 0.12 })
  local accent = frame:CreateTexture(nil, "ARTWORK"); accent:SetSize(3, 16); accent:SetPoint("TOPLEFT", 12, -12); UI.Accented(accent)
  frame.title = UI.Text(frame, 13); frame.title:SetPoint("LEFT", accent, "RIGHT", 8, 0); frame.title:SetWidth(W - 90); frame.title:SetWordWrap(false)
  frame.clock = UI.Text(frame, 13, C.text, "RIGHT"); frame.clock:SetPoint("TOPRIGHT", -34, -12)
  local close = UI.CloseButton(frame, function() hiddenFor = ns.GetCurrentRun() and ns.GetCurrentRun().id; frame:Hide() end)
  close:SetPoint("TOPRIGHT", -6, -6)

  frame.xpLabel = UI.Text(frame, 11, C.dim); frame.xpLabel:SetPoint("TOPLEFT", 14, -38); frame.xpLabel:SetText("XP")
  frame.xp = UI.Text(frame, 12, C.text, "RIGHT"); frame.xp:SetPoint("TOPRIGHT", -14, -38)
  frame.goldLabel = UI.Text(frame, 11, C.dim); frame.goldLabel:SetPoint("TOPLEFT", 14, -56); frame.goldLabel:SetText("Gold looted")
  frame.gold = UI.Text(frame, 12, C.text, "RIGHT"); frame.gold:SetPoint("TOPRIGHT", -14, -56)

  frame.icons = {}
  frame.bossLine = UI.Text(frame, 11, C.dim)
  frame:SetScript("OnUpdate", function(self, e)
    self.tick = (self.tick or 0) + e
    if self.tick < 1 then return end
    self.tick = 0
    local run = ns.GetCurrentRun()
    if run then self.clock:SetText(UI.Time(GetServerTime() - run.startTime)) end
  end)
end

local function icon(i)
  local b = frame.icons[i]
  if b then return b end
  b = CreateFrame("Frame", nil, frame); b:SetSize(ICON, ICON)
  b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints()
  b.ring = UI.Border(b, { 1, 1, 1, 0.15 })
  b.check = b:CreateTexture(nil, "OVERLAY"); b.check:SetSize(14, 14); b.check:SetPoint("BOTTOMRIGHT", 4, -4)
  b.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  b:EnableMouse(true)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(self.name or "Boss")
    GameTooltip:AddLine(self.dead and "Killed" or "Not killed yet", 0.7, 0.7, 0.75)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  frame.icons[i] = b
  return b
end

local function refresh()
  local run = ns.GetCurrentRun()
  local want = run and not run._notDungeon and ns.settings.tracker ~= false and hiddenFor ~= run.id
  if not want then if frame then frame:Hide() end return end
  if not frame then build() end
  if not frame:IsShown() then
    frame:ClearAllPoints()
    local p = ns.settings.trackerPos
    if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else frame:SetPoint("TOPRIGHT", -220, -220) end
  end
  frame.title:SetText(run.dungeon or "Dungeon")
  frame.clock:SetText(UI.Time(GetServerTime() - run.startTime))
  local _, _, level = xpNow()
  local maxLevel = (GetMaxPlayerLevel and GetMaxPlayerLevel()) or 60
  frame.xp:SetText(level >= maxLevel and "|cff999fb0max level|r" or ("+" .. UI.Num(run.xp or 0)))
  frame.gold:SetText(ns.Money(run.gold or 0))

  local bosses = bossesFor(run.dungeon)
  local dead = 0
  local perRow = math.floor((W - 28 + 6) / (ICON + 6))
  for i, b in ipairs(bosses) do
    local f = icon(i)
    local tex = portrait(b)
    f.tex:SetTexture(tex or 134400)
    f.dead, f.name = killed(run, b), b.name
    if f.dead then dead = dead + 1 end
    f.tex:SetDesaturated(not f.dead); f.tex:SetAlpha(f.dead and 1 or 0.45)
    f.check:SetShown(f.dead)
    local row, col = math.floor((i - 1) / perRow), (i - 1) % perRow
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", 14 + col * (ICON + 6), -80 - row * (ICON + 6)); f:Show()
  end
  for i = #bosses + 1, #frame.icons do frame.icons[i]:Hide() end
  local rows = math.max(1, math.ceil(#bosses / perRow))
  local wipes = run.wipes or 0
  frame.bossLine:ClearAllPoints(); frame.bossLine:SetPoint("TOPLEFT", 14, -80 - rows * (ICON + 6) - (#bosses > 0 and 2 or -4))
  frame.bossLine:SetText(#bosses > 0
    and string.format("%d/%d bosses%s", dead, #bosses, wipes > 0 and string.format("  ·  %d %s", wipes, wipes == 1 and "wipe" or "wipes") or "")
    or ("Bosses killed: " .. #(run.bosses or {}) .. (wipes > 0 and string.format("  ·  %d %s", wipes, wipes == 1 and "wipe" or "wipes") or "")))
  frame:SetHeight(80 + (#bosses > 0 and rows * (ICON + 6) or 0) + 26)
  frame:Show()
end
ns.RefreshTracker = refresh

ns.RegisterModule({
  name = "Tracker",
  OnRunStart = function(_, run) startCounting(run); hiddenFor = nil; C_Timer.After(0.2, refresh) end,
  OnRunFinish = function(_, run) onXP(run); onMoney(run); if frame then frame:Hide() end end,
  OnLoad = function() C_Timer.After(2, function() local r = ns.GetCurrentRun(); if r and not r._xp then startCounting(r) end refresh() end) end,
  events = {
    PLAYER_XP_UPDATE = function(_, run) if run then onXP(run); refresh() end end,
    PLAYER_LEVEL_UP = function(_, run) if run then C_Timer.After(0.5, function() onXP(run); refresh() end) end end,
    PLAYER_MONEY = function(_, run) if run then onMoney(run); refresh() end end,
    ENCOUNTER_END = function(_, run) if run then C_Timer.After(0.1, refresh) end end,
  },
})
