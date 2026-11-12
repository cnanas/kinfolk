-- Page: Players. Everyone in your logged runs, with totals and personal bests.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local LIST_W, PAD = 240, 16
local ROLE = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }

local page = { key = "players", label = "Players", section = "log", order = 40 }
local selected

function page:Build(f)
  self.list = UI.List(f, 46, function(r)
    r.name = UI.Text(r, 13); r.name:SetPoint("TOPLEFT", 14, -8)
    r.sub = UI.Text(r, 11, C.dim); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
    r.best = UI.Text(r, 12, C.text, "RIGHT"); r.best:SetPoint("TOPRIGHT", -14, -8)
    r:SetScript("OnClick", function(row) selected = row.pname; ns.RefreshUI() end)
  end, function(r, p)
    r.pname = p.name
    r.name:SetText(p.name); r.name:SetTextColor(UI.ClassColor(p.class))
    r.sub:SetText(#p.runs .. (#p.runs == 1 and " run" or " runs") .. (p.role and ROLE[p.role] and (", " .. ROLE[p.role]) or ""))
    r.best:SetText(p.bestDps > 0 and (UI.Num(p.bestDps) .. "/s") or "")
    self.list:Select(r, p.name == selected)
  end)
  self.list:SetPoint("TOPLEFT"); self.list:SetPoint("BOTTOMLEFT"); self.list:SetWidth(LIST_W)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })
  self.title = UI.Text(f, 20)
  self.sub = UI.Text(f, 12, C.dim)
  self.bestHead = UI.SectionLabel(f, "Personal bests")
  self.bests = {}
  for i = 1, 6 do self.bests[i] = { UI.Text(f, 12), UI.Text(f, 12, C.dim, "RIGHT"), UI.Text(f, 12, C.text, "RIGHT") } end
  self.runsHead = UI.SectionLabel(f, "Runs")
  self.runs = UI.List(f, 34, function(r)
    r.name = UI.Text(r, 12); r.name:SetPoint("LEFT", 12, 0)
    r.meta = UI.Text(r, 11, C.dim, "RIGHT"); r.meta:SetPoint("RIGHT", -12, 0)
    r:SetScript("OnClick", function(row) ns.OpenPage("runs", row.id) end)
  end, function(r, x)
    r.id = x.run.id
    r.name:SetText((x.run.dungeon or "?") .. "  |cff999fb0" .. (x.run.endTime and date("%b %d", x.run.endTime) or "") .. "|r")
    local bits = {}
    if x.dps > 0 then bits[#bits + 1] = UI.Num(x.dps) .. " dmg/s" end
    if x.hps > 0 then bits[#bits + 1] = UI.Num(x.hps) .. " heal/s" end
    if x.deaths > 0 then bits[#bits + 1] = "|cfff06b6b" .. x.deaths .. (x.deaths == 1 and " death" or " deaths") .. "|r" end
    r.meta:SetText(table.concat(bits, "   "))
  end)
  self.empty = UI.Text(f, 13, C.dim, "CENTER"); self.empty:SetWordWrap(true)
  self.empty:SetText("No players yet. Everyone in a logged run with damage meter data shows up here.")
end

function page:Layout(w, h)
  local x, dw = LIST_W + PAD + 1, w - LIST_W - PAD * 2 - 1
  self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", x, -PAD)
  self.sub:ClearAllPoints(); self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -6); self.sub:SetWidth(dw)
  self.bestHead:ClearAllPoints(); self.bestHead:SetPoint("TOPLEFT", x, -PAD - 62)
  for i, l in ipairs(self.bests) do
    local y = -PAD - 84 - (i - 1) * 20
    l[1]:ClearAllPoints(); l[1]:SetPoint("TOPLEFT", x, y); l[1]:SetWidth(dw * 0.5)
    l[2]:ClearAllPoints(); l[2]:SetPoint("TOPLEFT", x + dw * 0.5, y); l[2]:SetWidth(dw * 0.25)
    l[3]:ClearAllPoints(); l[3]:SetPoint("TOPLEFT", x + dw * 0.75, y); l[3]:SetWidth(dw * 0.25)
  end
  local runsY = -PAD - 84 - 6 * 20 - 16
  self.runsHead:ClearAllPoints(); self.runsHead:SetPoint("TOPLEFT", x, runsY)
  self.runs:ClearAllPoints(); self.runs:SetPoint("TOPLEFT", x, runsY - 20); self.runs:SetSize(dw, h + runsY - 20 - PAD)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER", LIST_W / 2, 0); self.empty:SetWidth(dw - 40)
end

function page:Refresh()
  local list = ns.Stats.Players()
  local p
  for _, x in ipairs(list) do if x.name == selected then p = x end end
  if not p then p = list[1]; selected = p and p.name end
  self.list:SetItems(list)
  local has = p ~= nil
  for _, el in ipairs({ self.title, self.sub, self.bestHead, self.runsHead, self.runs }) do el:SetShown(has) end
  self.empty:SetShown(not has)
  if not has then for _, l in ipairs(self.bests) do for _, t in ipairs(l) do t:SetText("") end end; return end

  local healer = p.role == "HEALER" or p.bestHps > p.bestDps
  self.title:SetText(p.name); self.title:SetTextColor(UI.ClassColor(p.class))
  local deaths, interrupts, bosses = 0, 0, 0
  for _, x in ipairs(p.runs) do deaths, interrupts, bosses = deaths + x.deaths, interrupts + x.interrupts, bosses + (x.run.bosses and #x.run.bosses or 0) end
  self.sub:SetText(string.format("%s%s.  %d runs, %d bosses, %d interrupts, %d deaths.", UI.ClassName(p.class), p.role and ROLE[p.role] and (", " .. ROLE[p.role]) or "", #p.runs, bosses, interrupts, deaths))

  local by, order = {}, {}
  for _, x in ipairs(p.runs) do
    local d = by[x.run.dungeon]
    if not d then d = { name = x.run.dungeon, n = 0, best = 0 }; by[x.run.dungeon] = d; order[#order + 1] = d end
    d.n = d.n + 1
    local rate = healer and x.hps or x.dps
    if rate > d.best then d.best = rate end
    if (x.run.bosses and #x.run.bosses or 0) > 0 and x.run.duration and (not d.fastest or x.run.duration < d.fastest) then d.fastest = x.run.duration end
  end
  table.sort(order, function(a, b) return a.n > b.n end)
  for i, l in ipairs(self.bests) do
    local d = order[i]
    l[1]:SetText(d and d.name or ""); l[2]:SetText(d and (d.fastest and UI.Time(d.fastest) or "—") or "")
    l[3]:SetText(d and d.best > 0 and (UI.Num(d.best) .. (healer and " heal/s" or " dmg/s")) or "")
  end
  local runs = {}
  for i = #p.runs, 1, -1 do runs[#runs + 1] = p.runs[i] end
  self.runs:SetItems(runs)
end

ns.RegisterPage(page)
