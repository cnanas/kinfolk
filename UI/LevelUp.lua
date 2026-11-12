-- Foxden: the level-up card (yours) and the small toast when a guildmate dings.
-- Simple and in Foxden's style: your gains, how long the level took, what's new at
-- your trainer, and who in the guild is near your level right now.
-- /fox levelup shows a preview.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local W = 420
local card
local function hex(r, g, b) return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) end

local STATS = { { "str", "Strength" }, { "agi", "Agility" }, { "sta", "Stamina" }, { "int", "Intellect" }, { "spi", "Spirit" } }

local function dur(s)
  if not s then return nil end
  local h, m = math.floor(s / 3600), math.floor((s % 3600) / 60)
  if h > 0 then return string.format("%dh %dm", h, m) end
  return string.format("%dm", math.max(1, m))
end

local function fastest(history, except)
  local best, at
  for lvl, h in pairs(history or {}) do
    if lvl ~= except and h.seconds and (not best or h.seconds < best) then best, at = h.seconds, lvl end
  end
  return best, at
end

local function nearby(level)
  local out = {}
  local me = UnitName("player")
  for _, m in ipairs(ns.db and ns.db.roster and ns.db.roster.members or {}) do
    local short = UI.ShortName(m.name or "")
    if m.online and short ~= me and m.level and math.abs(m.level - level) <= 3 then out[#out + 1] = m end
  end
  table.sort(out, function(a, b) return math.abs(a.level - level) < math.abs(b.level - level) end)
  return out
end

local function build()
  card = CreateFrame("Frame", "FoxdenLevelUp", UIParent)
  card:SetSize(W, 300)
  card:SetPoint("TOP", 0, -120)
  card:SetFrameStrata("DIALOG")
  card:EnableMouse(true); card:SetMovable(true); card:RegisterForDrag("LeftButton")
  card:SetScript("OnDragStart", card.StartMoving); card:SetScript("OnDragStop", card.StopMovingOrSizing)
  UI.Fill(card, C.bg); UI.Border(card, { 1, 1, 1, 0.14 })
  tinsert(UISpecialFrames, "FoxdenLevelUp")

  local accent = card:CreateTexture(nil, "ARTWORK"); accent:SetSize(3, 30); accent:SetPoint("TOPLEFT", 20, -20); UI.Accented(accent)
  card.title = UI.Text(card, 24); card.title:SetPoint("LEFT", accent, "RIGHT", 10, 0)
  card.tag = UI.Text(card, 12); card.tag:SetPoint("LEFT", card.title, "RIGHT", 10, -2); UI.Accented(card.tag)
  local close = UI.CloseButton(card, function() card:Hide() end); close:SetPoint("TOPRIGHT", -10, -10)
  card.time = UI.Text(card, 12, C.dim); card.time:SetPoint("TOPLEFT", accent, "BOTTOMLEFT", 0, -10); card.time:SetWidth(W - 40)

  card.gains = UI.Text(card, 13); card.gains:SetWidth(W - 40); card.gains:SetWordWrap(true)
  card.gains2 = UI.Text(card, 12, C.dim); card.gains2:SetWidth(W - 40)

  card.newHead = UI.SectionLabel(card, "New at your trainer")
  card.rows = {}
  for i = 1, 6 do
    local r = CreateFrame("Frame", nil, card); r:SetSize(W - 40, 20)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(16, 16); r.icon:SetPoint("LEFT")
    r.name = UI.Text(r, 12); r.name:SetPoint("LEFT", 22, 0)
    r.cost = UI.Text(r, 12, C.dim, "RIGHT"); r.cost:SetPoint("RIGHT")
    card.rows[i] = r
  end
  card.newNote = UI.Text(card, 11, C.dim); card.newNote:SetWidth(W - 40); card.newNote:SetWordWrap(true)

  card.nearHead = UI.SectionLabel(card, "Guildmates near your level")
  card.near = UI.Text(card, 12); card.near:SetWidth(W - 40); card.near:SetWordWrap(true)

  card.open = UI.Button(card, "Open Trainer page", 150, 26, function() card:Hide(); if ns.OpenPage then ns.OpenPage("trainer") end end, "primary")
  card.open:SetPoint("BOTTOMRIGHT", -20, 18)

  -- stays until closed or 25 seconds pass without the mouse on it
  card:SetScript("OnUpdate", function(self, e)
    if self:IsMouseOver() then self.left = 25 else self.left = (self.left or 25) - e end
    if self.left <= 0 then self:Hide() end
  end)
end

function ns.ShowLevelUp(level, gains, seconds, preview)
  if not card then build() end
  gains = gains or {}
  card.left = 25
  card.title:SetText("Level " .. level)
  card.tag:SetText(level % 10 == 0 and "Milestone" or "")

  local hist = ns.LevelHistory and ns.LevelHistory()
  local best, bestAt = fastest(hist and hist.history, level)
  local t = {}
  if seconds then t[#t + 1] = dur(seconds) .. " this level" end
  if seconds and best and seconds < best then t[#t + 1] = "your fastest yet" elseif best then t[#t + 1] = "fastest: " .. dur(best) .. " (level " .. bestAt .. ")" end
  card.time:SetText(#t > 0 and table.concat(t, "  ·  ") or (preview and "Preview" or ""))

  local g = {}
  for _, s in ipairs(STATS) do if (gains[s[1]] or 0) > 0 then g[#g + 1] = "+" .. gains[s[1]] .. " " .. s[2] end end
  card.gains:SetText(#g > 0 and table.concat(g, "   ") or "Stats unchanged")
  local g2 = {}
  if (gains.hp or 0) > 0 then g2[#g2 + 1] = "+" .. gains.hp .. " health" end
  if (gains.mp or 0) > 0 then g2[#g2 + 1] = "+" .. gains.mp .. " mana" end
  card.gains2:SetText(table.concat(g2, "   "))

  -- layout top to bottom
  local y = -78
  card.gains:ClearAllPoints(); card.gains:SetPoint("TOPLEFT", 20, y); y = y - card.gains:GetStringHeight() - 6
  card.gains2:ClearAllPoints(); card.gains2:SetPoint("TOPLEFT", 20, y); if card.gains2:GetText() ~= "" then y = y - 20 end
  y = y - 10
  card.newHead:ClearAllPoints(); card.newHead:SetPoint("TOPLEFT", 20, y); y = y - 22

  local list = ns.ClassAbilities and ns.ClassAbilities()
  local ready, total = {}, 0
  for _, s in ipairs(list or {}) do
    if s.status == "ready" then ready[#ready + 1] = s; total = total + (s.cost or 0) end
  end
  for i, r in ipairs(card.rows) do
    local s = ready[i]
    if s then
      r.icon:SetTexture(s.icon or 134400)
      r.name:SetText(s.name .. (s.rank and ("  |cff999fb0" .. s.rank .. "|r") or ""))
      r.cost:SetText(ns.Money(s.cost))
      r:ClearAllPoints(); r:SetPoint("TOPLEFT", 20, y); r:Show(); y = y - 22
    else r:Hide() end
  end
  if not list then
    card.newNote:SetText("Visit your class trainer once and Foxden will list what's new here from then on.")
  elseif #ready == 0 then
    card.newNote:SetText("Nothing new to learn at this level.")
  else
    card.newNote:SetText((#ready > #card.rows and (#ready - #card.rows) .. " more.  " or "") .. "Total " .. ns.MoneyPlain(total) .. (total > GetMoney() and "  (more than you're carrying)" or ""))
  end
  card.newNote:ClearAllPoints(); card.newNote:SetPoint("TOPLEFT", 20, y); y = y - card.newNote:GetStringHeight() - 14

  local near = nearby(level)
  card.nearHead:SetShown(#near > 0); card.near:SetShown(#near > 0)
  if #near > 0 then
    local names = {}
    for i = 1, math.min(6, #near) do
      local m = near[i]
      names[#names + 1] = string.format("|cff%s%s|r %d", hex(UI.ClassColor(m.class)), UI.ShortName(m.name), m.level)
    end
    card.nearHead:ClearAllPoints(); card.nearHead:SetPoint("TOPLEFT", 20, y); y = y - 22
    card.near:SetText(table.concat(names, "    ") .. (#near > 6 and ("   +" .. (#near - 6)) or ""))
    card.near:ClearAllPoints(); card.near:SetPoint("TOPLEFT", 20, y); y = y - card.near:GetStringHeight() - 10
  end
  card:SetHeight(-y + 60)
  card:Show()
  if ns.RequestRoster then ns.RequestRoster() end
end

-- ---- guildmate dinged: a small toast, top of the screen --------------------------

local toasts = {}
function ns.ShowGuildDing(name, level, class)
  local t = table.remove(toasts, 1)
  if not t then
    t = CreateFrame("Frame", nil, UIParent); t:SetSize(300, 34); t:SetFrameStrata("HIGH")
    UI.Fill(t, C.bg); UI.Border(t, { 1, 1, 1, 0.12 })
    local bar = t:CreateTexture(nil, "ARTWORK"); bar:SetSize(3, 34); bar:SetPoint("LEFT"); UI.Accented(bar)
    t.text = UI.Text(t, 13); t.text:SetPoint("LEFT", 14, 0)
  end
  t.text:SetText(string.format("|cff%s%s|r reached level %d%s", hex(UI.ClassColor(class)), name, level, level % 10 == 0 and "  |cff7fe3c4milestone|r" or ""))
  t:SetWidth(t.text:GetStringWidth() + 32)
  local shown = 0
  for _, o in ipairs(ns.dingToasts or {}) do if o:IsShown() then shown = shown + 1 end end
  t:ClearAllPoints(); t:SetPoint("TOP", 0, -64 - shown * 40)
  t:SetAlpha(1); t:Show()
  ns.dingToasts = ns.dingToasts or {}
  table.insert(ns.dingToasts, t)
  local life = 6
  t:SetScript("OnUpdate", function(self, e)
    life = life - e
    if life < 1 then self:SetAlpha(math.max(0, life)) end
    if life <= 0 then
      self:Hide(); self:SetScript("OnUpdate", nil)
      for i, o in ipairs(ns.dingToasts) do if o == self then table.remove(ns.dingToasts, i) break end end
      toasts[#toasts + 1] = self
    end
  end)
end
