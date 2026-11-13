-- Foxden: the dungeon tracker. A small window while you're in a dungeon run:
-- time inside, XP gained, gold looted, and the dungeon's bosses (grey until killed).
-- XP and gold are also saved on the run (run.xp, run.gold).
-- Drag to move (position is remembered); X hides it for this run.
-- Boss portraits: the game's journal when it has them (Forever's is empty), else the
-- look Foxden noted when a guildmate fought that boss (FoxdenDB.bossLooks, the website).

local _, ns = ...
local UI = ns.UI
local C = UI.C
local W = 264
local frame, hiddenFor
local ICON, GAP, PAD = 40, 8, 16

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

-- Forever's in-game journal is empty, so the list also comes from the guild's own
-- kills: the website's list (from everyone's runs) and this computer's saved runs, in the
-- order the guild usually kills them, then the rest of the dungeon's bosses (Data/Dungeons.lua).
local learned = {}
local function bossesFor(name, run)
  local want = ns.Slug and ns.Slug(name)
  for _, d in ipairs(ns.db and ns.db.journal and ns.db.journal.dungeons or {}) do
    if ns.Slug(d.name) == want and d.bosses and #d.bosses > 0 then return d.bosses, #d.bosses end
  end
  local list, seen = {}, {}
  local function add(id, bname, look)
    id = tonumber(id) or 0
    local k = id > 0 and id or bname
    if not bname then return end
    if seen[k] or seen[bname] then
      if look and look > 0 and learned[k] and not learned[k].look then learned[k].look = look end
      return
    end
    seen[k], seen[bname] = true, true
    learned[k] = learned[k] or { encounterID = id > 0 and id or nil, name = bname }
    if look and look > 0 then learned[k].look = look end
    list[#list + 1] = learned[k]
  end
  local site = ns.Site and ns.Site()
  for _, b in ipairs(site and type(site.bosses) == "table" and site.bosses[want] or {}) do add(b[1], b[2], tonumber(b[3])) end
  for i = #(ns.db and ns.db.runs or {}), 1, -1 do
    local r = ns.db.runs[i]
    if ns.Slug(r.dungeon) == want then for _, k in ipairs(r.bosses or {}) do add(k.id, k.name, k.look) end end
  end
  -- then the dungeon's full list (Data/Dungeons.lua) for bosses nobody has killed yet
  local d = run and ns.Dungeons and ns.Dungeons[run.instanceID]
  for _, b in ipairs(d and d.bosses or {}) do
    local dup = seen[b.name]
    for _, id in ipairs(b.ids or {}) do if seen[id] then dup = true end end
    if not dup then add(b.ids and b.ids[1], b.name) end
    local e = learned[(b.ids and b.ids[1]) or b.name]
    if e then e.ids = b.ids end
  end
  local known = #list
  for _, k in ipairs(run and run.bosses or {}) do add(k.id, k.name, k.look) end -- killed now, not known before
  return list, known
end

local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

local function journalIcon(b)
  if b._icon ~= nil then return b._icon end
  b._icon = false
  if EJ_GetCreatureInfo and b.id then
    local ok, _, _, _, _, icon = pcall(EJ_GetCreatureInfo, 1, b.id)
    if ok and icon and not ns.IsSecret(icon) then b._icon = icon end
  end
  return b._icon
end

-- Paint a boss portrait on a texture. Returns true when it's a real portrait.
local function setPortrait(tex, b)
  local icon = journalIcon(b)
  if icon then tex:SetTexture(icon); return true end
  local look = b.look or (b.encounterID and ns.db and ns.db.bossLooks and ns.db.bossLooks[b.encounterID])
  if look and SetPortraitTextureFromCreatureDisplayID and pcall(SetPortraitTextureFromCreatureDisplayID, tex, look) then return true end
  tex:SetTexture(SKULL)
  return false
end

local function killed(run, b)
  for _, k in ipairs(run.bosses or {}) do
    if (b.encounterID and k.id == b.encounterID) or k.name == b.name then return true end
    for _, id in ipairs(b.ids or {}) do if k.id == id then return true end end
  end
  return false
end

-- ---- wishlist and splits -------------------------------------------------------------

-- Your wishlist items that drop from a boss of this dungeon: { [bossName] = { wish, ... } }
local function wishesHere(dungeon)
  local out, slug = {}, ns.Slug(dungeon)
  for _, w in ipairs(ns.Wishlist and ns.Wishlist() or {}) do
    if w.b and w.d and ns.Slug(w.d) == slug then out[w.b] = out[w.b] or {}; table.insert(out[w.b], w) end
  end
  return out
end

-- The guild's best run of this dungeon, boss by boss: { [encounterID] = seconds }, total, who.
local function bestRun(dungeon)
  local slug = ns.Slug(dungeon)
  local site = ns.Site and ns.Site()
  local b = site and type(site.splits) == "table" and site.splits[slug]
  local times, total, by = {}, nil, nil
  if type(b) == "table" then
    total, by = b.time, b.by
    for _, x in ipairs(b.bosses or {}) do times[x[1]] = x[2] end
  end
  -- your own best on this computer, if faster (or the only one)
  for _, d in ipairs(ns.Stats and ns.Stats.Dungeons() or {}) do
    if ns.Slug(d.name) == slug and d.best and (d.best.duration or 0) >= 60 and (not total or d.best.duration < total) then
      total, by, times = d.best.duration, d.best.loggedBy, {}
      for _, k in ipairs(d.best.bosses or {}) do if k.id and k.killedAt then times[k.id] = k.killedAt end end
    end
  end
  return times, total, by
end

local function signed(seconds)
  local s = math.floor(math.abs(seconds) + 0.5)
  return (seconds < 0 and "-" or "+") .. UI.Time(s)
end

-- ---- the window ------------------------------------------------------------------------

local function round(f, tex)
  if not f.CreateMaskTexture then return end
  local ok, m = pcall(f.CreateMaskTexture, f)
  if not ok or not m or not tex.AddMaskTexture then return end
  m:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  m:SetAllPoints(tex)
  tex:AddMaskTexture(m)
end

local function stat(label, x)
  local l = UI.Text(frame, 11, C.dim); l:SetPoint("TOPLEFT", x, -44); l:SetText(label)
  local v = UI.Text(frame, 17); v:SetPoint("TOPLEFT", x, -60)
  return v
end

local function build()
  frame = CreateFrame("Frame", "FoxdenTracker", UIParent)
  frame:SetSize(W, 140)
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
  local accent = frame:CreateTexture(nil, "ARTWORK"); accent:SetSize(3, 16); accent:SetPoint("TOPLEFT", PAD, -14); UI.Accented(accent)
  frame.title = UI.Text(frame, 14); frame.title:SetPoint("LEFT", accent, "RIGHT", 8, 0); frame.title:SetWidth(W - 70)
  local close = UI.CloseButton(frame, function() hiddenFor = ns.GetCurrentRun() and ns.GetCurrentRun().id; frame:Hide() end)
  close:SetPoint("TOPRIGHT", -8, -8)

  local col = (W - PAD * 2) / 3
  frame.clock = stat("Time", PAD)
  frame.xp = stat("XP", PAD + col)
  frame.gold = stat("Gold looted", PAD + col * 2)

  local rule = frame:CreateTexture(nil, "ARTWORK"); rule:SetColorTexture(1, 1, 1, 0.08)
  rule:SetPoint("TOPLEFT", PAD, -88); rule:SetPoint("TOPRIGHT", -PAD, -88); rule:SetHeight(1)

  frame.icons = {}
  frame.bossLine = UI.Text(frame, 11, C.dim)
  frame.splitLine = UI.Text(frame, 11, C.dim)
  frame.wishLine = UI.Text(frame, 11, C.dim); frame.wishLine:SetWidth(W - PAD * 2); frame.wishLine:SetWordWrap(true)
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
  b.ring = b:CreateTexture(nil, "BACKGROUND"); b.ring:SetPoint("TOPLEFT", -2, 2); b.ring:SetPoint("BOTTOMRIGHT", 2, -2)
  b.ring:SetColorTexture(1, 1, 1, 0.18); round(b, b.ring)
  b.back = b:CreateTexture(nil, "BORDER"); b.back:SetAllPoints(); b.back:SetColorTexture(0.12, 0.13, 0.15, 1); round(b, b.back)
  b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints(); round(b, b.tex)
  b.check = b:CreateTexture(nil, "OVERLAY"); b.check:SetSize(18, 18); b.check:SetPoint("BOTTOMRIGHT", 3, -3)
  b.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  b.star = b:CreateTexture(nil, "OVERLAY"); b.star:SetSize(16, 16); b.star:SetPoint("TOPRIGHT", 4, 4)
  b.star:SetTexture("Interface\\Common\\ReputationStar"); b.star:SetTexCoord(0, 0.5, 0, 0.5); b.star:Hide()
  b:EnableMouse(true)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(self.name or "Boss")
    GameTooltip:AddLine(self.dead and "Killed" or "Not killed yet", 0.7, 0.7, 0.75)
    for _, w in ipairs(self.wishes or {}) do GameTooltip:AddLine("Wishlist: " .. (w.n or "?") .. " (" .. (ns.WISH_LABEL[w.k or "ms"] or "") .. ")", 1, 0.82, 0.3) end
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
  frame.xp:SetText(level >= maxLevel and "|cff999fb0max|r" or UI.Num(run.xp or 0))
  frame.gold:SetText(ns.Money(run.gold or 0))

  local bosses, known = bossesFor(run.dungeon, run)
  local wishes = wishesHere(run.dungeon)
  local dead = 0
  local perRow = math.floor((W - PAD * 2 + GAP) / (ICON + GAP))
  local r, g, bl = UI.Accent()
  for i, b in ipairs(bosses) do
    local f = icon(i)
    setPortrait(f.tex, b)
    f.dead, f.name = killed(run, b), b.name
    f.wishes = wishes[b.name]
    f.star:SetShown(f.wishes ~= nil and not f.dead)
    if f.dead then dead = dead + 1 end
    f.tex:SetDesaturated(f.dead); f.tex:SetAlpha(f.dead and 0.55 or 1)
    if f.dead then f.ring:SetColorTexture(r, g, bl, 1) else f.ring:SetColorTexture(1, 1, 1, 0.18) end
    f.check:SetShown(f.dead)
    local row, col = math.floor((i - 1) / perRow), (i - 1) % perRow
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", PAD + col * (ICON + GAP), -102 - row * (ICON + GAP)); f:Show()
  end
  for i = #bosses + 1, #frame.icons do frame.icons[i]:Hide() end
  local rows = #bosses > 0 and math.ceil(#bosses / perRow) or 0
  local wipes = run.wipes or 0
  local w = wipes > 0 and string.format("  ·  %d %s", wipes, wipes == 1 and "wipe" or "wipes") or ""
  local top = rows > 0 and (-102 - rows * (ICON + GAP) - 4) or -100
  frame.bossLine:ClearAllPoints(); frame.bossLine:SetPoint("TOPLEFT", PAD, top)
  frame.bossLine:SetText(known > 0 and string.format("%d/%d bosses%s", dead, #bosses, w)
    or ("Bosses killed: " .. #(run.bosses or {}) .. w .. (#bosses == 0 and "  ·  the guild learns them as you go" or "")))
  -- how you're doing against the guild's best run, as of the last boss you killed
  local times, total, by = bestRun(run.dungeon)
  local last = run.bosses and run.bosses[#run.bosses]
  local y = top - 18
  if last and times[last.id] then
    local delta = (last.killedAt or 0) - times[last.id]
    frame.splitLine:SetText(string.format("%s%s|r vs guild best at %s", delta <= 0 and "|cff6fd39a" or "|cfff06b6b", signed(delta), last.name or "the last boss"))
    frame.splitLine:Show()
  elseif total then
    frame.splitLine:SetText("Guild best " .. UI.Time(total) .. (by and (" by " .. by) or ""))
    frame.splitLine:Show()
  else frame.splitLine:Hide() end
  if frame.splitLine:IsShown() then frame.splitLine:ClearAllPoints(); frame.splitLine:SetPoint("TOPLEFT", PAD, y); y = y - 16 end
  -- what you still want from this dungeon
  local want = {}
  for _, b in ipairs(bosses) do
    if wishes[b.name] and not killed(run, b) then for _, w in ipairs(wishes[b.name]) do want[#want + 1] = w.n or "?" end end
  end
  if #want > 0 then
    frame.wishLine:SetText("|cffffd24dWishlist:|r " .. table.concat(want, ", "))
    frame.wishLine:ClearAllPoints(); frame.wishLine:SetPoint("TOPLEFT", PAD, y); frame.wishLine:Show()
    y = y - (frame.wishLine:GetStringHeight() or 12) - 4
  else frame.wishLine:Hide() end
  frame:SetHeight(-y + 10)
  frame:Show()
end
ns.RefreshTracker = refresh

ns.RegisterModule({
  name = "Tracker",
  OnRunStart = function(_, run)
    startCounting(run); hiddenFor = nil; C_Timer.After(0.2, refresh)
    if run._notDungeon then return end
    -- a quick briefing: quests you could still pick up, and your wishlist here
    C_Timer.After(2, function()
      if ns.GetCurrentRun() ~= run then return end
      local qp = ns.QuestProgress and ns.QuestProgress(run.dungeon)
      if qp and qp.total > 0 then
        local msg = string.format("Quests here: %d of %d done%s.", qp.done, qp.total, qp.have > 0 and (", " .. qp.have .. " in your log") or "")
        if #qp.missing > 0 then msg = msg .. " Not picked up: " .. table.concat(qp.missing, ", ", 1, math.min(4, #qp.missing)) .. (#qp.missing > 4 and (" and " .. (#qp.missing - 4) .. " more") or "") .. "." end
        ns.say(msg)
      end
      local n, names = 0, {}
      for boss, list in pairs(wishesHere(run.dungeon)) do for _, w in ipairs(list) do n = n + 1; names[#names + 1] = (w.n or "?") .. " (" .. boss .. ")" end end
      if n > 0 then ns.say("On your wishlist here: " .. table.concat(names, ", ") .. ".") end
    end)
  end,
  OnRunFinish = function(_, run) onXP(run); onMoney(run); if frame then frame:Hide() end end,
  OnLoad = function() C_Timer.After(2, function() local r = ns.GetCurrentRun(); if r and not r._xp then startCounting(r) end refresh() end) end,
  events = {
    PLAYER_XP_UPDATE = function(_, run) if run then onXP(run); refresh() end end,
    PLAYER_LEVEL_UP = function(_, run) if run then C_Timer.After(0.5, function() onXP(run); refresh() end) end end,
    PLAYER_MONEY = function(_, run) if run then onMoney(run); refresh() end end,
    ENCOUNTER_START = function(_, run, _, name)
      if not run or ns.IsSecret(name) then return end
      for _, w in ipairs(wishesHere(run.dungeon)[name] or {}) do
        ns.say("Wishlist: " .. (w.n or "?") .. " (" .. (ns.WISH_LABEL[w.k or "ms"] or ""):lower() .. ") can drop from " .. name .. ".")
      end
    end,
    ENCOUNTER_END = function(_, run) if run then C_Timer.After(0.1, refresh) end end,
  },
})
