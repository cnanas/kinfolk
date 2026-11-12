-- Page: Overview. The dashboard: number tiles, recent runs, fastest clears, top damage.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16

local page = { key = "overview", label = "Overview", section = "log", order = 10 }

function page:Build(f)
  self.tiles = {}
  for i = 1, 4 do
    local t = CreateFrame("Frame", nil, f)
    t:SetHeight(64)
    UI.Fill(t, C.surface); UI.Border(t)
    t.value = UI.Text(t, 22); t.value:SetPoint("TOPLEFT", 14, -10)
    t.label = UI.Text(t, 11, C.dim); t.label:SetPoint("TOPLEFT", t.value, "BOTTOMLEFT", 0, -4)
    t.sub = UI.Text(t, 10, C.faint); t.sub:SetPoint("BOTTOMRIGHT", -12, 10)
    self.tiles[i] = t
  end
  self.recentHead = UI.Text(f, 14); self.recentHead:SetText("Recent runs")
  self.recent = UI.List(f, 44, function(r)
    r.name = UI.Text(r, 13); r.name:SetPoint("TOPLEFT", 12, -7); r.name:SetPoint("RIGHT", r, "RIGHT", -90, 0)
    r.sub = UI.Text(r, 11, C.dim); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
    r.time = UI.Text(r, 13, C.text, "RIGHT"); r.time:SetPoint("TOPRIGHT", -12, -7)
    r.meta = UI.Text(r, 11, C.dim, "RIGHT"); r.meta:SetPoint("TOPRIGHT", r.time, "BOTTOMRIGHT", 0, -4)
    r:SetScript("OnClick", function(row) ns.OpenPage("runs", row.id) end)
  end, function(r, e)
    local run = e.run
    r.id = e.id
    r.name:SetText(run.dungeon or "Unknown")
    if e.live then r.sub:SetText("In progress"); r.sub:SetTextColor(UI.Accent())
    else r.sub:SetTextColor(unpack(C.dim)); r.sub:SetText((run.difficulty and run.difficulty ~= "" and (run.difficulty .. ", ") or "") .. (run.endTime and date("%b %d, %H:%M", run.endTime) or "")) end
    r.time:SetText(UI.Time(ns.RunDuration(e)))
    local b, w = run.bosses and #run.bosses or 0, run.wipes or 0
    r.meta:SetText(b .. (b == 1 and " boss" or " bosses") .. (w > 0 and (", " .. w .. (w == 1 and " wipe" or " wipes")) or ""))
  end)
  UI.Fill(self.recent, { 0, 0, 0, 0.12 })
  self.recentEmpty = UI.Text(f, 12, C.dim); self.recentEmpty:SetWordWrap(true)
  self.recentEmpty:SetText("No runs yet. Step into a dungeon and the log starts on its own.")

  self.bestHead = UI.Text(f, 14); self.bestHead:SetText("Fastest clears")
  self.dpsHead = UI.Text(f, 14); self.dpsHead:SetText("Top damage per second")
  self.bestLines, self.dpsLines = {}, {}
  for i = 1, 6 do self.bestLines[i] = { UI.Text(f, 12), UI.Text(f, 12, C.text, "RIGHT") } end
  for i = 1, 6 do self.dpsLines[i] = { UI.Text(f, 12), UI.Text(f, 12, C.text, "RIGHT") } end
end

function page:Layout(w, h)
  local inner = w - PAD * 2
  local tileW = (inner - 3 * 10) / 4
  for i, t in ipairs(self.tiles) do t:ClearAllPoints(); t:SetPoint("TOPLEFT", PAD + (i - 1) * (tileW + 10), -PAD); t:SetWidth(tileW) end
  local top = -PAD - 64 - 20
  local leftW = math.floor(inner * 0.58)
  local rightX, rightW = PAD + leftW + 20, inner - leftW - 20
  self.recentHead:ClearAllPoints(); self.recentHead:SetPoint("TOPLEFT", PAD, top)
  self.recent:ClearAllPoints(); self.recent:SetPoint("TOPLEFT", PAD, top - 24); self.recent:SetSize(leftW, h + top - 24 - PAD)
  self.recentEmpty:ClearAllPoints(); self.recentEmpty:SetPoint("TOPLEFT", PAD + 12, top - 36); self.recentEmpty:SetWidth(leftW - 24)
  local function lines(head, list, y)
    head:ClearAllPoints(); head:SetPoint("TOPLEFT", rightX, y)
    for i, l in ipairs(list) do
      l[1]:ClearAllPoints(); l[1]:SetPoint("TOPLEFT", rightX, y - 24 - (i - 1) * 20); l[1]:SetWidth(rightW - 70)
      l[2]:ClearAllPoints(); l[2]:SetPoint("TOPRIGHT", self.recent:GetParent(), "TOPLEFT", rightX + rightW, y - 24 - (i - 1) * 20); l[2]:SetWidth(70)
    end
  end
  lines(self.bestHead, self.bestLines, top)
  lines(self.dpsHead, self.dpsLines, top - 24 - 6 * 20 - 18)
end

function page:Refresh()
  local t = ns.Stats.Totals()
  local site = ns.Site()
  local tiles = {
    { t.runs, "runs logged", t.week .. " this week" },
    { t.bosses, "bosses down", "in " .. t.dungeons .. (t.dungeons == 1 and " dungeon" or " dungeons") },
    { string.format("%.1f", t.seconds / 3600), "hours inside", "" },
    { site and #site.shop or "—", "crafts to request", site and "from guildmates, free" or "sync to load crafting" },
  }
  for i, tile in ipairs(self.tiles) do tile.value:SetText(tiles[i][1]); tile.label:SetText(tiles[i][2]); tile.sub:SetText(tiles[i][3]) end

  local list = {}
  local live = ns.GetCurrentRun()
  if live then list[1] = { run = live, live = true, id = "live" } end
  local runs = ns.GetRuns()
  for i = #runs, 1, -1 do list[#list + 1] = { run = runs[i], id = runs[i].id } end
  self.recent:SetItems(list)
  self.recentEmpty:SetShown(#list == 0)

  local dungeons = ns.Stats.Dungeons()
  local bests = {}
  for _, d in ipairs(dungeons) do if d.best then bests[#bests + 1] = d end end
  table.sort(bests, function(a, b) return a.name < b.name end)
  for i, l in ipairs(self.bestLines) do
    local d = bests[i]
    l[1]:SetText(d and d.name or (i == 1 and "No clears yet" or "")); l[1]:SetTextColor(unpack(d and C.text or C.dim))
    l[2]:SetText(d and UI.Time(d.best.duration) or "")
  end
  local players = ns.Stats.Players()
  table.sort(players, function(a, b) return a.bestDps > b.bestDps end)
  for i, l in ipairs(self.dpsLines) do
    local p = players[i]
    if p and p.bestDps > 0 then
      l[1]:SetText(i .. ".  " .. p.name); l[1]:SetTextColor(UI.ClassColor(p.class)); l[2]:SetText(UI.Num(p.bestDps) .. "/s")
    else
      l[1]:SetText(i == 1 and "Needs runs with damage meter data" or ""); l[1]:SetTextColor(unpack(C.dim)); l[2]:SetText("")
    end
  end
end

ns.RegisterPage(page)
