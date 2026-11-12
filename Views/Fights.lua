-- View: Fights. Every fight in the run (boss pulls and trash), and the stat
-- bars for the one you pick. Data comes from run.segments (Modules/Meter.lua).

local _, ns = ...
local UI = ns.UI
local C = UI.C

local LIST_W, ROW_H = 212, 40
local KEYS = { "damage", "healing", "interrupts", "damageTaken", "deaths" }

local view = { key = "fights", label = "Fights", order = 20 }

function view:Build(pane, width, height)
  self.pane = pane
  self.list = UI.List(pane, ROW_H, function(r)
    r.mark = r:CreateTexture(nil, "ARTWORK")
    r.mark:SetPoint("TOPLEFT"); r.mark:SetPoint("BOTTOMLEFT"); r.mark:SetWidth(2)
    r.name = UI.Text(r, 12); r.name:SetPoint("TOPLEFT", 10, -7); r.name:SetPoint("RIGHT", r, "RIGHT", -52, 0)
    r.sub = UI.Text(r, 10, C.dim); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
    r.dur = UI.Text(r, 12, C.text, "RIGHT"); r.dur:SetPoint("TOPRIGHT", -10, -7)
    r:SetScript("OnClick", function(row) self.selected = row.index; ns.RefreshUI() end)
  end, function(r, s, idx)
    r.index = idx
    r.name:SetText(s.label or "Trash")
    if s.kind == "boss" then
      if s.kill then r.mark:SetColorTexture(UI.Accent()) else r.mark:SetColorTexture(unpack(C.danger)) end
      r.sub:SetText((s.kill and "Kill" or "Wipe") .. ", at " .. UI.Time(s.at))
      r.name:SetTextColor(unpack(C.text))
    else
      r.mark:SetColorTexture(unpack(C.line))
      r.sub:SetText("Trash, at " .. UI.Time(s.at))
      r.name:SetTextColor(unpack(C.dim))
    end
    r.dur:SetText(UI.Time(s.duration))
    r.sel:SetShown(idx == self.selected)
  end)
  self.list:SetPoint("TOPLEFT"); self.list:SetPoint("BOTTOMLEFT"); self.list:SetWidth(LIST_W)
  UI.Fill(self.list, { 0, 0, 0, 0.15 })
  self.title = UI.Text(pane, 15)
  self.sub = UI.Text(pane, 11, C.dim)
  self.stats = UI.StatPanel(pane, math.max(200, width - LIST_W - 16), KEYS, 5)
  self.empty = UI.Text(pane, 12, C.dim, "CENTER")
  self.empty:SetPoint("CENTER"); self.empty:SetWordWrap(true)
end

function view:Layout(width)
  local x, w = LIST_W + 16, math.max(200, width - LIST_W - 16)
  self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", x, -2); self.title:SetWidth(w)
  self.sub:ClearAllPoints(); self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -5)
  self.stats:SetPanelWidth(w)
  self.stats:ClearAllPoints(); self.stats:SetPoint("TOPLEFT", x, -48)
  self.empty:SetWidth(width - 60)
end

function view:Refresh(e)
  local run = e.run
  local segs = run.segments or {}
  local has = #segs > 0
  self.empty:SetShown(not has)
  self.list:SetShown(has); self.title:SetShown(has); self.sub:SetShown(has); self.stats:SetShown(has)
  if not has then
    self.empty:SetText(e.live and "Fights show up here as each one ends."
      or (run.schema or 1) < 2 and "This run was logged before fight breakdowns were added."
      or "No fights were recorded for this run.")
    return
  end
  if run.id ~= self.runId then self.runId, self.selected = run.id, nil; self.list.offset = 0 end
  self.selected = math.min(self.selected or #segs, #segs)
  self.list:SetItems(segs)
  local s = segs[self.selected]
  self.title:SetText(s.label or "Trash")
  self.sub:SetText(string.format("Fight %d of %d, %s, %s long", self.selected, #segs,
    s.kind == "boss" and (s.kill and "boss kill" or "boss wipe") or "trash", UI.Time(s.duration)))
  self.stats:Set(s.stats, s.duration, ns.ClassLookup(run))
end

ns.RegisterView(view)
