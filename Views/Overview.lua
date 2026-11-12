-- View: Overview. Summary tiles, whole-run stat bars, party and bosses.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local ROLE = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }

local view = { key = "overview", label = "Overview", order = 10 }

function view:Build(pane, width)
  self.pane = pane
  self.tiles = {}
  for i, label in ipairs({ "Total time", "In combat", "Bosses", "Wipes" }) do
    local t = CreateFrame("Frame", nil, pane)
    t:SetHeight(54)
    UI.Fill(t, C.surface); UI.Border(t)
    t.value = UI.Text(t, 18); t.value:SetPoint("TOPLEFT", 12, -10)
    t.label = UI.Text(t, 10, C.dim); t.label:SetPoint("BOTTOMLEFT", 12, 10); t.label:SetText(label:upper())
    self.tiles[i] = t
  end
  self.stats = UI.StatPanel(pane, width, UI.ALL_STATS, 5)
  self.partyHead = UI.SectionLabel(pane, "Party")
  self.bossHead = UI.SectionLabel(pane, "Bosses")
  self.partyLines, self.bossLines = {}, {}
  for i = 1, 5 do
    self.partyLines[i] = { UI.Text(pane, 12), UI.Text(pane, 11, C.dim, "RIGHT") }
    self.bossLines[i] = { UI.Text(pane, 12), UI.Text(pane, 11, C.dim, "RIGHT") }
  end
end

function view:Layout(width)
  local tileW = (width - 3 * 8) / 4
  for i, t in ipairs(self.tiles) do
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", (i - 1) * (tileW + 8), 0); t:SetWidth(tileW)
  end
  self.stats:SetPanelWidth(width)
  self.stats:ClearAllPoints(); self.stats:SetPoint("TOPLEFT", 0, -70)
  local colY = -70 - self.stats:GetHeight() - 12
  local half = (width - 16) / 2
  self.partyHead:ClearAllPoints(); self.partyHead:SetPoint("TOPLEFT", 0, colY)
  self.bossHead:ClearAllPoints(); self.bossHead:SetPoint("TOPLEFT", half + 16, colY)
  for i = 1, 5 do
    local y = colY - 18 - (i - 1) * 18
    local pn, pr = self.partyLines[i][1], self.partyLines[i][2]
    pn:ClearAllPoints(); pn:SetPoint("TOPLEFT", 0, y); pn:SetWidth(half - 90)
    pr:ClearAllPoints(); pr:SetPoint("TOPLEFT", half - 90, y); pr:SetWidth(90)
    local bn, bt = self.bossLines[i][1], self.bossLines[i][2]
    bn:ClearAllPoints(); bn:SetPoint("TOPLEFT", half + 16, y); bn:SetWidth(half - 60)
    bt:ClearAllPoints(); bt:SetPoint("TOPLEFT", width - 60, y); bt:SetWidth(60)
  end
end

function view:Refresh(e)
  local run = e.run
  local combat = run.combatSeconds or 0
  local values = { UI.Time(ns.RunDuration(e)), UI.Time(combat), tostring(run.bosses and #run.bosses or 0), tostring(run.wipes or 0) }
  for i, t in ipairs(self.tiles) do t.value:SetText(values[i]) end
  local empty
  if not ns.MeterReady() and not next(run.stats or {}) then
    empty = "The damage meter wasn't available, so this run has time, party, and bosses only."
  elseif e.live then
    empty = "Numbers appear after each fight ends."
  end
  self.stats:Set(run.stats, combat, ns.ClassLookup(run), empty)
  for i, line in ipairs(self.partyLines) do
    local m = run.party and run.party[i]
    if m then
      line[1]:SetText(m.name or "?"); line[1]:SetTextColor(UI.ClassColor(m.class))
      line[2]:SetText((ROLE[m.role] and (ROLE[m.role] .. "  ") or "") .. UI.ClassName(m.class))
    else
      line[1]:SetText(""); line[2]:SetText("")
    end
  end
  for i, line in ipairs(self.bossLines) do
    local b = run.bosses and run.bosses[i]
    if b then
      line[1]:SetText(b.name or "?"); line[1]:SetTextColor(unpack(C.text)); line[2]:SetText(UI.Time(b.killedAt))
    else
      line[1]:SetText(i == 1 and "None yet" or ""); line[1]:SetTextColor(unpack(C.dim)); line[2]:SetText("")
    end
  end
end

ns.RegisterView(view)
