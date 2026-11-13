-- Page: Leveling planner. The cheapest way to raise a profession from one skill to
-- another at today's prices: which recipes to make at each skill, about how many, and
-- one shopping list (less what's already in your bags and bank).
--
-- At each skill point it picks the recipe with the lowest expected cost of one skill-up:
-- a recipe always gives a point while it's orange (below its yellow threshold), then less
-- often until it turns grey: chance = (grey - skill) / (grey - yellow). Whether you can
-- already learn a recipe comes from profession trainers the guild has visited; without
-- that it's estimated as 30 below the yellow threshold.
-- Data: ns.Site().costs (cost, yellow, grey), .mats (materials and prices), .skill.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16

local page = { key = "planner", label = "Leveling planner", order = 55 }
local prof, from, to
local skip = {}

local function mySkill(profession)
  local c = ns.Crafting and ns.Crafting()
  local me = c and c.chars and c.chars[ns.CharKey()]
  local p = me and me.professions and me.professions[profession]
  return p and tonumber(p.skill) or nil, p and tonumber(p.maxSkill) or nil
end

local function learnSkills()
  local map = {}
  for _, d in pairs(ns.db and ns.db.trainers and ns.db.trainers.prof or {}) do
    for _, s in ipairs(d.spells or {}) do if s.name and s.skillReq then map[s.name] = s.skillReq end end
  end
  local site = ns.Site()
  for name, req in pairs(site and type(site.skill) == "table" and site.skill or {}) do map[name] = map[name] or req end
  return map
end

-- returns steps { { c = costRow, from, to, crafts, cost, estimated } }, total cost, skill reached, materials { [item] = { qty, name, each } }
function ns.PlanProfession(profession, fromSkill, toSkill, skipped)
  local site = ns.Site()
  local learn = learnSkills()
  local usable = {}
  for _, c in ipairs(site and site.costs or {}) do
    if c[4] == profession and (c[11] or 0) > 0 and (c[7] or -1) > 0 and not (skipped and skipped[c[1]]) then usable[#usable + 1] = c end
  end
  local steps, cur, exact, reached = {}, nil, 0, fromSkill
  for s = fromSkill, toSkill - 1 do
    local best, bestCost, bestChance
    for _, c in ipairs(usable) do
      local yellow, grey = c[10] or 0, c[11]
      local learnAt = learn[c[3]] or math.max(1, yellow - 30)
      if s < grey and s >= learnAt then
        local chance = (s < yellow) and 1 or ((grey > yellow) and (grey - s) / (grey - yellow) or 0)
        if chance > 0 then
          local cost = c[7] * math.max(1, c[6] or 1) / chance
          if cur and cur.c == c then cost = cost * 0.97 end -- stay on a recipe unless switching really saves
          if not bestCost or cost < bestCost then best, bestCost, bestChance = c, cost, chance end
        end
      end
    end
    if not best then break end
    if not cur or cur.c ~= best then
      if cur then cur.crafts = math.ceil(exact) end
      cur = { c = best, from = s, to = s + 1, crafts = 0, estimated = learn[best[3]] == nil }
      steps[#steps + 1] = cur; exact = 0
    end
    exact = exact + 1 / bestChance
    cur.to = s + 1; reached = s + 1
  end
  if cur then cur.crafts = math.ceil(exact) end
  local total, mats = 0, {}
  for _, st in ipairs(steps) do
    st.cost = st.crafts * st.c[7] * math.max(1, st.c[6] or 1)
    total = total + st.cost
    for _, m in ipairs(ns.MaterialsFor(st.c[2] > 0 and st.c[2] or nil, st.c[3]) or {}) do
      local e = mats[m[1]] or { id = m[1], qty = 0, name = m[3], each = m[4] or -1 }
      e.qty = e.qty + (m[2] or 1) * st.crafts
      mats[m[1]] = e
    end
  end
  return steps, total, reached, mats
end

local function numberBox(parent, onChange)
  local box = CreateFrame("EditBox", nil, parent)
  box:SetSize(60, 26); box:SetAutoFocus(false); box:SetNumeric(true); box:SetMaxLetters(3)
  box:SetFont(UI.Font(), 12, ""); box:SetTextColor(unpack(C.text)); box:SetTextInsets(10, 6, 0, 0)
  UI.Fill(box, C.raised); UI.Border(box)
  local function done(self) self:ClearFocus(); onChange(tonumber(self:GetText())) end
  box:SetScript("OnEnterPressed", done); box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEditFocusLost", function(self) onChange(tonumber(self:GetText())) end)
  return box
end

function page:Build(f)
  self.prof = UI.Dropdown(f, 200, "Profession", function(v) prof = v; from, to = nil, nil; skip = {}; self:Refresh() end)
  self.fromLabel = UI.Text(f, 11, C.dim); self.fromLabel:SetText("From skill")
  self.fromBox = numberBox(f, function(v) if v and v ~= from then from = math.max(1, math.min(449, v)); self:Refresh() end end)
  self.toLabel = UI.Text(f, 11, C.dim); self.toLabel:SetText("to")
  self.toBox = numberBox(f, function(v) if v and v ~= to then to = math.max(2, math.min(450, v)); self:Refresh() end end)
  self.summary = UI.Text(f, 13); self.summary:SetWordWrap(true)

  self.stepsHead = UI.Text(f, 14); self.stepsHead:SetText("What to make")
  self.steps = UI.List(f, 36, function(r)
    UI.ItemRow(r, 62)
    r.range = UI.Text(r, 11, C.dim); r.range:SetPoint("LEFT", 10, 0)
    r.name = UI.Text(r, 12); r.name:SetPoint("LEFT", 90, 0)
    r.skipB = UI.Button(r, "Skip", 44, 20, function(b) local st = b:GetParent().st; if st then skip[st.c[1]] = true; self:Refresh() end end)
    r.skipB:SetPoint("RIGHT", -6, 0)
    r.cost = UI.Text(r, 12, C.text, "RIGHT"); r.cost:SetPoint("RIGHT", r.skipB, "LEFT", -10, 0)
    r.crafts = UI.Text(r, 12, C.dim, "RIGHT"); r.crafts:SetPoint("RIGHT", r.skipB, "LEFT", -90, 0)
  end, function(r, st)
    local w = self.steps:GetWidth()
    r.st = st
    r.range:SetText(st.from .. "-" .. st.to)
    UI.SetRowItem(r, st.c[2], nil, st.c[3])
    r.name:SetWidth(math.max(60, w - 90 - 210))
    r.name:SetText(st.c[3] .. (st.estimated and "  |cff999fb0check your trainer|r" or ""))
    r.crafts:SetText("make about " .. st.crafts)
    r.cost:SetText(ns.Money(math.floor(st.cost + 0.5)))
  end)
  UI.Fill(self.steps, { 0, 0, 0, 0.12 })

  self.shopHead = UI.Text(f, 14); self.shopHead:SetText("Shopping list")
  self.shopTotal = UI.Text(f, 13, C.text, "RIGHT")
  self.shop = UI.List(f, 34, function(r)
    UI.ItemRow(r, 10)
    r.showMats = false
    r.name = UI.Text(r, 12); r.name:SetPoint("LEFT", 38, 0)
    r.have = UI.Text(r, 11, C.dim, "RIGHT")
    r.cost = UI.Text(r, 12, C.text, "RIGHT"); r.cost:SetPoint("RIGHT", -10, 0)
  end, function(r, m)
    local w = self.shop:GetWidth()
    r.name:SetWidth(math.max(60, w - 38 - 170))
    local n = UI.SetRowItem(r, m.id, nil, m.name)
    r.name:SetText(m.qty .. "x " .. (n or m.name or "?"))
    r.have:ClearAllPoints(); r.have:SetPoint("RIGHT", -86, 0)
    r.have:SetText(m.have > 0 and ("have " .. math.min(m.have, m.qty)) or "")
    if m.need == 0 then r.cost:SetText("|cff6fd39agot it|r")
    elseif m.each >= 0 then r.cost:SetText(ns.Money(m.each * m.need))
    else r.cost:SetText("|cff999fb0no price|r") end
  end)
  UI.Fill(self.shop, { 0, 0, 0, 0.12 })
  self.reset = UI.Button(f, "Bring back skipped", 150, 22, function() skip = {}; self:Refresh() end)
  self.note = UI.Text(f, 11, C.faint); self.note:SetWordWrap(true)
  self.empty = UI.EmptyNote(f)
end

function page:Layout(w, h)
  local inner = w - PAD * 2
  self.prof:ClearAllPoints(); self.prof:SetPoint("TOPLEFT", PAD, -PAD)
  self.fromLabel:ClearAllPoints(); self.fromLabel:SetPoint("LEFT", self.prof, "RIGHT", 14, 0)
  self.fromBox:ClearAllPoints(); self.fromBox:SetPoint("LEFT", self.fromLabel, "RIGHT", 8, 0)
  self.toLabel:ClearAllPoints(); self.toLabel:SetPoint("LEFT", self.fromBox, "RIGHT", 8, 0)
  self.toBox:ClearAllPoints(); self.toBox:SetPoint("LEFT", self.toLabel, "RIGHT", 8, 0)
  self.summary:ClearAllPoints(); self.summary:SetPoint("TOPLEFT", PAD, -PAD - 40); self.summary:SetWidth(inner)
  local top = -PAD - 84
  local leftW = math.floor(inner * 0.58)
  local rightX, rightW = PAD + leftW + 16, inner - leftW - 16
  local bodyH = h + top - 24 - PAD - 56
  self.stepsHead:ClearAllPoints(); self.stepsHead:SetPoint("TOPLEFT", PAD, top)
  self.reset:ClearAllPoints(); self.reset:SetPoint("TOPRIGHT", self.steps:GetParent(), "TOPLEFT", PAD + leftW, top + 4)
  self.steps:ClearAllPoints(); self.steps:SetPoint("TOPLEFT", PAD, top - 24); self.steps:SetSize(leftW, bodyH)
  self.shopHead:ClearAllPoints(); self.shopHead:SetPoint("TOPLEFT", rightX, top)
  self.shopTotal:ClearAllPoints(); self.shopTotal:SetPoint("TOPRIGHT", self.steps:GetParent(), "TOPLEFT", rightX + rightW, top)
  self.shop:ClearAllPoints(); self.shop:SetPoint("TOPLEFT", rightX, top - 24); self.shop:SetSize(rightW, bodyH)
  self.note:ClearAllPoints(); self.note:SetPoint("BOTTOMLEFT", PAD, PAD); self.note:SetWidth(inner)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER"); self.empty:SetWidth(inner - 60)
end

function page:Refresh()
  local site = ns.Site()
  local has = site ~= nil
  local all = { self.prof, self.fromLabel, self.fromBox, self.toLabel, self.toBox, self.summary, self.stepsHead, self.steps, self.shopHead, self.shopTotal, self.shop, self.reset, self.note }
  for _, el in ipairs(all) do el:SetShown(has) end
  self.empty:SetShown(not has)
  if not has then self.empty:SetText(ns.NO_SITE); return end

  local profs, seen = {}, {}
  for _, c in ipairs(site.costs or {}) do seen[c[4]] = (seen[c[4]] or 0) + 1 end
  for p, n in pairs(seen) do if n > 10 then profs[#profs + 1] = { value = p, label = p } end end
  table.sort(profs, function(a, b) return a.label < b.label end)
  if not prof then for _, p in ipairs(profs) do if not prof and mySkill(p.value) then prof = p.value end end end
  prof = prof or (profs[1] and profs[1].value)
  self.prof:SetOptions(profs, prof)
  local mine, cap = mySkill(prof)
  from = from or mine or 1
  to = to or math.max(from + 1, math.min(450, cap or (from + 75)))
  if to <= from then to = math.min(450, from + 1) end
  if not self.fromBox:HasFocus() then self.fromBox:SetText(from) end
  if not self.toBox:HasFocus() then self.toBox:SetText(to) end

  local steps, total, reached, mats = ns.PlanProfession(prof, from, to, skip)
  -- the shopping list, less what's in your bags and bank
  local c = ns.Crafting and ns.Crafting()
  local me = c and c.chars and c.chars[ns.CharKey()] or {}
  local list, shopTotal, missingPrice = {}, 0, false
  for _, m in pairs(mats) do
    m.have = ((me.bags or {})[m.id] or 0) + ((me.bank or {})[m.id] or 0)
    m.need = math.max(0, m.qty - m.have)
    if m.need > 0 then if m.each >= 0 then shopTotal = shopTotal + m.each * m.need else missingPrice = true end end
    list[#list + 1] = m
  end
  table.sort(list, function(a, b) return math.max(0, a.each) * a.need > math.max(0, b.each) * b.need end)
  self.steps:SetItems(steps); self.shop:SetItems(list)
  self.shopTotal:SetText(#list > 0 and (ns.Money(math.floor(shopTotal + 0.5)) .. (missingPrice and " +" or "")) or "")
  local nSkip = 0; for _ in pairs(skip) do nSkip = nSkip + 1 end
  self.reset:SetShown(nSkip > 0)
  if #steps == 0 then
    self.summary:SetText("No recipe with known prices gives skill-ups at " .. from .. ". Try another starting skill, or sync for fresh prices.")
  else
    local crafts = 0; for _, st in ipairs(steps) do crafts = crafts + st.crafts end
    self.summary:SetText(string.format("%s %d to %d: about %d crafts, %s of materials%s.%s", prof, from, reached, crafts, ns.MoneyPlain(math.floor(total + 0.5)),
      shopTotal < total - 1 and (" (" .. ns.MoneyPlain(math.floor(shopTotal + 0.5)) .. " to buy after what you have)") or "",
      reached < to and ("  It stops at " .. reached .. ": nothing with known prices gives skill-ups after that.") or ""))
  end
  self.note:SetText("Craft counts are averages: a recipe always gives a point while it's orange, then less often until it turns grey. \"Check your trainer\" marks recipes nobody in the guild has read at a trainer yet. Skip a recipe you can't learn and the plan works around it. Your bank is counted as of the last time you opened it.")
end

ns.RegisterPage(page)
