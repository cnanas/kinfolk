-- Page: Home ("For you"). What matters for this character right now: dungeons for your
-- level (with the quests you can pick up), what's ready at your trainer, your recent
-- runs, and who in the guild is online near your level.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16

local page = { key = "overview", label = "For you", order = 10 }

local function card(f, title, buttonLabel, onClick)
  local c = CreateFrame("Frame", nil, f)
  UI.Fill(c, C.surface); UI.Border(c)
  c.title = UI.Text(c, 14); c.title:SetPoint("TOPLEFT", 14, -12); c.title:SetText(title)
  c.big = UI.Text(c, 20); c.big:SetPoint("TOPLEFT", 14, -36)
  c.body = UI.Text(c, 12, C.dim); c.body:SetPoint("TOPLEFT", 14, -64); c.body:SetWordWrap(true); c.body:SetJustifyV("TOP")
  if buttonLabel then
    c.button = UI.Button(c, buttonLabel, 110, 24, onClick)
    c.button:SetPoint("TOPRIGHT", -12, -10)
  end
  return c
end

-- Dungeons whose level range fits you; if that's fewer than three, the next ones up.
local function dungeonsFor(level)
  local fit, next = {}, {}
  for _, d in pairs(ns.Dungeons or {}) do
    if not d.raid and d.levels and #d.levels == 2 then
      if level >= d.levels[1] and level <= d.levels[2] then fit[#fit + 1] = d
      elseif d.levels[1] > level and d.levels[1] <= level + 6 then next[#next + 1] = d end
    end
  end
  local byLevel = function(a, b) if a.levels[1] ~= b.levels[1] then return a.levels[1] < b.levels[1] end return a.name < b.name end
  table.sort(fit, byLevel); table.sort(next, byLevel)
  for _, d in ipairs(next) do if #fit < 5 then d._soon = true; fit[#fit + 1] = d end end
  return fit
end

local function questCount(name)
  local site = ns.Site()
  local rows = site and type(site.quests) == "table" and site.quests[ns.Slug(name)]
  if not rows then return nil end
  local mine = UnitFactionGroup and UnitFactionGroup("player")
  local f = mine == "Alliance" and "A" or mine == "Horde" and "H" or nil
  local n = 0
  for _, q in ipairs(rows) do if q[3] == "" or not f or q[3] == f then n = n + 1 end end
  return n
end

function page:Build(f)
  self.hello = UI.Text(f, 20)
  self.helloSub = UI.Text(f, 12, C.dim)

  self.dungHead = UI.Text(f, 14); self.dungHead:SetText("Dungeons for your level")
  self.dungeons = UI.List(f, 50, function(r)
    r.name = UI.Text(r, 14); r.name:SetPoint("TOPLEFT", 14, -8)
    r.sub = UI.Text(r, 11, C.dim); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -5)
    r.right = UI.Text(r, 12, C.dim, "RIGHT"); r.right:SetPoint("RIGHT", -14, 0)
    r:SetScript("OnClick", function(row) ns.OpenPage("journal", { dungeon = row.dname }) end)
  end, function(r, d)
    r.dname = d.name
    r.name:SetText(d.name)
    local bits = { "Levels " .. d.levels[1] .. "-" .. d.levels[2], #d.bosses .. " bosses" }
    local qp = ns.QuestProgress and ns.QuestProgress(d.name)
    if qp and qp.total > 0 then
      local open = #qp.missing
      bits[#bits + 1] = open > 0 and ("|cffe8c35a" .. open .. (open == 1 and " quest" or " quests") .. " to pick up|r") or (qp.done == qp.total and "all quests done" or "quests in your log")
    end
    local seekers = ns.LfgFor and ns.LfgFor(ns.Slug(d.name)) or {}
    if #seekers > 0 then bits[#bits + 1] = "|cff7fe3c4" .. #seekers .. " want to run it|r" end
    r.sub:SetText(table.concat(bits, "  ·  "))
    local st = d._stats
    if st and st.best then r.right:SetText(#st.runs .. (#st.runs == 1 and " run, best " or " runs, best ") .. UI.Time(st.best.duration)); r.right:SetTextColor(unpack(C.text))
    elseif d._soon then r.right:SetText("from level " .. d.levels[1]); r.right:SetTextColor(unpack(C.faint))
    else r.right:SetText("not run yet"); r.right:SetTextColor(unpack(C.faint)) end
  end)
  UI.Fill(self.dungeons, { 0, 0, 0, 0.12 })

  self.recentHead = UI.Text(f, 14); self.recentHead:SetText("Recent runs")
  self.allRuns = UI.Button(f, "All runs", 80, 22, function() ns.OpenPage("runs") end)
  self.recent = UI.List(f, 44, function(r)
    r.name = UI.Text(r, 13); r.name:SetPoint("TOPLEFT", 14, -7); r.name:SetPoint("RIGHT", r, "RIGHT", -90, 0)
    r.sub = UI.Text(r, 11, C.dim); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
    r.time = UI.Text(r, 13, C.text, "RIGHT"); r.time:SetPoint("TOPRIGHT", -14, -7)
    r.meta = UI.Text(r, 11, C.dim, "RIGHT"); r.meta:SetPoint("TOPRIGHT", r.time, "BOTTOMRIGHT", 0, -4)
    r:SetScript("OnClick", function(row) ns.OpenPage("runs", row.id) end)
  end, function(r, e)
    local run = e.run
    r.id = e.id
    r.name:SetText(run.dungeon or "Unknown")
    if e.live then r.sub:SetText("In progress"); r.sub:SetTextColor(UI.Accent())
    else r.sub:SetTextColor(unpack(C.dim)); r.sub:SetText(run.endTime and date("%b %d, %H:%M", run.endTime) or "") end
    r.time:SetText(UI.Time(ns.RunDuration(e)))
    local b, w = run.bosses and #run.bosses or 0, run.wipes or 0
    r.meta:SetText(b .. (b == 1 and " boss" or " bosses") .. (w > 0 and (", " .. w .. (w == 1 and " wipe" or " wipes")) or ""))
  end)
  UI.Fill(self.recent, { 0, 0, 0, 0.12 })
  self.recentEmpty = UI.Text(f, 12, C.dim); self.recentEmpty:SetWordWrap(true)
  self.recentEmpty:SetText("No runs yet. Walk into a dungeon and Foxden starts logging on its own.")

  self.trainer = card(f, "At your trainer", "Open trainer", function() ns.OpenPage("trainer") end)
  self.guild = card(f, "Guild", "Roster", function() ns.OpenPage("roster") end)
  self.craft = card(f, "Looking for group", "Dungeons", function() ns.OpenPage("journal") end)
end

function page:Layout(w, h)
  local inner = w - PAD * 2
  self.hello:ClearAllPoints(); self.hello:SetPoint("TOPLEFT", PAD, -PAD)
  self.helloSub:ClearAllPoints(); self.helloSub:SetPoint("TOPLEFT", self.hello, "BOTTOMLEFT", 0, -6)
  local top = -PAD - 62
  local leftW = math.floor(inner * 0.60)
  local rightX, rightW = PAD + leftW + 16, inner - leftW - 16
  local bodyH = h + top - PAD
  local recentH = math.min(44 * 3, math.max(44, math.floor(bodyH * 0.32)))
  local dungH = bodyH - 24 - recentH - 24 - 16
  self.dungHead:ClearAllPoints(); self.dungHead:SetPoint("TOPLEFT", PAD, top)
  self.dungeons:ClearAllPoints(); self.dungeons:SetPoint("TOPLEFT", PAD, top - 24); self.dungeons:SetSize(leftW, dungH)
  local ry = top - 24 - dungH - 16
  self.recentHead:ClearAllPoints(); self.recentHead:SetPoint("TOPLEFT", PAD, ry)
  self.allRuns:ClearAllPoints(); self.allRuns:SetPoint("TOPRIGHT", self.recentHead:GetParent(), "TOPLEFT", PAD + leftW, ry + 4)
  self.recent:ClearAllPoints(); self.recent:SetPoint("TOPLEFT", PAD, ry - 24); self.recent:SetSize(leftW, recentH)
  self.recentEmpty:ClearAllPoints(); self.recentEmpty:SetPoint("TOPLEFT", PAD + 14, ry - 36); self.recentEmpty:SetWidth(leftW - 28)
  local cardH = math.floor((bodyH - 2 * 12) / 3)
  for i, c in ipairs({ self.trainer, self.guild, self.craft }) do
    c:ClearAllPoints(); c:SetPoint("TOPLEFT", rightX, top - (i - 1) * (cardH + 12)); c:SetSize(rightW, cardH)
    c.body:SetWidth(rightW - 28)
  end
end

function page:Refresh()
  local level = UnitLevel("player") or 1
  local _, class = UnitClass("player")
  self.hello:SetText(UnitName("player") or "Hello"); self.hello:SetTextColor(UI.ClassColor(class))
  self.helloSub:SetText("Level " .. level .. " " .. (UI.ClassName and UI.ClassName(class) or ""))

  -- dungeons for your level
  local stats = {}
  for _, s in ipairs(ns.Stats.Dungeons()) do stats[ns.Slug(s.name)] = s end
  local list = dungeonsFor(level)
  for _, d in ipairs(list) do d._stats = stats[ns.Slug(d.name)] end
  self.dungeons:SetItems(list)

  -- recent runs
  local runs = {}
  local live = ns.LiveRun()
  if live then runs[1] = { run = live, live = true, id = "live" } end
  local saved = ns.GetRuns()
  for i = #saved, 1, -1 do runs[#runs + 1] = { run = saved[i], id = saved[i].id } end
  self.recent:SetItems(runs)
  self.recentEmpty:SetShown(#runs == 0)

  -- trainer
  local abilities = ns.ClassAbilities and ns.ClassAbilities()
  local t = self.trainer
  if not abilities then
    t.big:SetText("No list yet")
    t.body:SetText("Visit your class trainer once and Foxden keeps the whole list: what's ready, what's next and the cost.")
  else
    local ready, cost, names, soon = 0, 0, {}, nil
    for _, s in ipairs(abilities) do
      if s.status == "ready" then ready = ready + 1; cost = cost + (s.cost or 0); if #names < 4 then names[#names + 1] = s.name .. (s.rank and (" " .. s.rank) or "") end
      elseif s.status == "soon" and not soon then soon = s end
    end
    if ready > 0 then
      t.big:SetText(ready .. (ready == 1 and " ability ready" or " abilities ready"))
      t.body:SetText(ns.Money(cost) .. " to learn them all\n" .. table.concat(names, ", ") .. (ready > #names and (", +" .. (ready - #names) .. " more") or ""))
    else
      t.big:SetText("All caught up")
      t.body:SetText(soon and ("Next: " .. soon.name .. (soon.rank and (" " .. soon.rank) or "") .. " at level " .. soon.level) or "Nothing more to learn.")
    end
  end

  -- guild
  local g = self.guild
  local members = ns.db and ns.db.roster and ns.db.roster.members or {}
  local online, near = 0, {}
  local me = UnitName("player")
  for _, m in ipairs(members) do
    if m.online then
      online = online + 1
      local short = UI.ShortName(m.name or "")
      if short ~= me and m.level and math.abs(m.level - level) <= 4 then near[#near + 1] = short .. " " .. m.level end
    end
  end
  if #members == 0 then
    g.big:SetText(IsInGuild and IsInGuild() and "Loading…" or "No guild")
    g.body:SetText(IsInGuild and IsInGuild() and "Open the Roster tab to load who's online." or "Join a guild to see who's online and where.")
  else
    g.big:SetText(online .. " of " .. #members .. " online")
    g.body:SetText(#near > 0 and ("Near your level: " .. table.concat(near, ", ")) or "Nobody near your level is online right now.")
  end

  -- looking for group: the dungeons guildmates (and you) have asked for
  local c = self.craft
  local wanted = {}
  for _, d in pairs(ns.Dungeons or {}) do
    local seekers = ns.LfgFor and ns.LfgFor(ns.Slug(d.name)) or {}
    if #seekers > 0 then wanted[#wanted + 1] = { name = d.name, seekers = seekers } end
  end
  table.sort(wanted, function(a, b) if #a.seekers ~= #b.seekers then return #a.seekers > #b.seekers end return a.name < b.name end)
  if #wanted == 0 then
    c.big:SetText("Nobody yet")
    c.body:SetText("Open a dungeon and click \"I want to run this\". Guildmates see it, and Discord hears when three of you want the same one.")
  else
    c.big:SetText(#wanted .. (#wanted == 1 and " dungeon wanted" or " dungeons wanted"))
    local lines = {}
    for i = 1, math.min(3, #wanted) do
      local names = {}
      for _, sk in ipairs(wanted[i].seekers) do names[#names + 1] = (sk.me and "you" or sk.name) .. (sk.level and (" " .. sk.level) or "") end
      lines[#lines + 1] = "|cffe6e8ee" .. wanted[i].name .. "|r: " .. table.concat(names, ", ")
    end
    c.body:SetText(table.concat(lines, "\n"))
  end
  -- the next dungeon night planned on the guild website
  local site = ns.Site()
  local nextUp
  for _, e in ipairs(site and type(site.events) == "table" and site.events or {}) do
    if (e[2] or 0) > GetServerTime() - 3600 and (not nextUp or e[2] < nextUp[2]) then nextUp = e end
  end
  if nextUp then
    c.body:SetText((c.body:GetText() or "") .. "\n\n|cffe6e8eeDungeon night:|r " .. nextUp[1] .. ", " .. date("%a %b %d, %H:%M", nextUp[2])
      .. " (" .. (nextUp[3] or 0) .. " signed up). Sign up on the guild website.")
  end
end

ns.RegisterPage(page)
