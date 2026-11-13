-- Page: Recipes. Every recipe in one searchable list: the skill it needs, who in the
-- guild can make it, and what the materials cost. Pick one to see its materials with
-- auction prices and a total, and to request it. Crafting between guildmates is free:
-- you bring the materials.
-- Data: the companion's snapshot of the website (ns.Site().costs / .shop / .mats / .skill)
-- plus the professions Foxden shares over guild chat (ns.Crafting()) and the profession
-- trainers you've visited (FoxdenDB.trainers.prof).

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16

local page = { key = "recipes", label = "Recipes", order = 50 }
local query, prof, selected = "", nil, nil
local categories, show, sort = {}, "all", "skill" -- categories: a set, empty = all; show: all / guild / requests / skillups

local DIFF = { orange = { 1, 0.5, 0.25 }, yellow = { 1, 0.9, 0.2 }, green = { 0.35, 0.8, 0.35 }, grey = { 0.55, 0.57, 0.6 } }
-- How hard a recipe is at your skill, like the colours in the game's profession window.
local function difficulty(c, mine)
  local yellow, grey = c[10] or 0, c[11] or 0
  if not mine or grey <= 0 then return nil end
  if mine >= grey then return "grey" end
  if mine < yellow then return "orange" end
  return mine < (yellow + grey) / 2 and "yellow" or "green"
end
-- Your own skill in a profession on this character, if you have it.
local function mySkill(profession)
  local c = ns.Crafting and ns.Crafting()
  local me = c and c.chars and c.chars[ns.CharKey()]
  local p = me and me.professions and me.professions[profession]
  return p and tonumber(p.skill) or nil
end

-- who can make what: [itemID or recipe name] = { takers = "A, B" (take requests), known = { name, ... } }
local function makers()
  local site, map = ns.Site(), {}
  local function at(k) map[k] = map[k] or { known = {}, seen = {} }; return map[k] end
  for _, l in ipairs(site and site.shop or {}) do
    local e = at(l[2] > 0 and l[2] or l[3])
    e.takers, e.recipe, e.inPerson = l[8], l[1], l[7] == 1
  end
  local c = ns.Crafting and ns.Crafting()
  local function addAll(name, profs, mine)
    for _, d in pairs(profs or {}) do
      for _, r in ipairs(d.recipes or {}) do
        local k = (r.item and r.item > 0 and r.item) or r.name
        if k then
          local e = at(k)
          if not e.seen[name] then e.seen[name] = true; e.known[#e.known + 1] = name; if not mine then e.others = e.others or {}; e.others[#e.others + 1] = name end end
        end
      end
    end
  end
  if c then
    for key, ch in pairs(c.chars or {}) do addAll(ch.name or key:match("^[^-]+") or key, ch.professions, true) end
    for key, g in pairs(c.guild or {}) do if not (c.chars or {})[key] then addAll(key:match("^[^-]+") or key, g.professions, false) end end
  end
  return map
end

-- profession skill needed to learn a recipe, by name: the website's list, then trainers you visited
local function skillMap()
  local map = {}
  for _, d in pairs(ns.db and ns.db.trainers and ns.db.trainers.prof or {}) do
    for _, s in ipairs(d.spells or {}) do if s.name and s.skillReq then map[s.name] = s.skillReq end end
  end
  local site = ns.Site()
  for name, req in pairs(site and type(site.skill) == "table" and site.skill or {}) do map[name] = map[name] or req end
  return map
end

-- Save a craft request; the companion sends it to the guild website on the next sync.
function ns.RequestCraft(recipeID, itemID, name, qty)
  if not ns.db then return end
  ns.db.craftRequests = ns.db.craftRequests or {}
  local list = ns.db.craftRequests
  list[#list + 1] = { id = GetServerTime() .. "-" .. recipeID, recipe = recipeID, item = itemID, name = name, qty = qty or 1, at = GetServerTime(), char = ns.CharKey() }
  while #list > 30 do table.remove(list, 1) end
  ns.say(string.format("Request saved: %dx %s. It goes to the guild website on your next sync; the crafter then tells you where to send the materials.", qty or 1, name))
  ns.Changed()
end

-- Ask the whole guild (the website's crafting board); the companion posts it on the next sync.
function ns.AskBoard(itemID, name, qty)
  if not ns.db then return end
  ns.db.boardAsks = ns.db.boardAsks or {}
  local list = ns.db.boardAsks
  list[#list + 1] = { id = GetServerTime() .. "-" .. (itemID or 0), item = name, itemId = itemID, qty = qty or 1, char = ns.CharKey(), at = GetServerTime() }
  while #list > 30 do table.remove(list, 1) end
  ns.say(string.format("Asked the guild for %dx %s. It goes on the website's crafting board (and Discord) on your next sync.", qty or 1, name))
  ns.Changed()
end

local function whisper(to, item, name, qty, mats)
  local _, link = UI.ItemLook(item or 0)
  local parts = {}
  for _, m in ipairs(mats or {}) do parts[#parts + 1] = ((m[2] or 1) * qty) .. "x " .. (m[3] or "?") end
  local msg = string.format("Hi! Could you make %dx %s for me? I'll bring the materials%s. Thanks!", qty, link or name, #parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or "")
  if #msg > 250 then msg = string.format("Hi! Could you make %dx %s for me? I'll bring the materials. Thanks!", qty, link or name) end
  SendChatMessage(msg, "WHISPER", nil, to)
  ns.say("Whispered " .. to .. ".")
end

function page:Build(f)
  -- one row of dropdowns: profession, categories (pick several), what to show, sort
  self.chips = UI.Dropdown(f, 190, "Profession", function(v) prof = v; categories = {}; selected = nil; self:Refresh() end)
  self.cats = UI.Dropdown(f, 200, "Categories", function(set) categories = set; selected = nil; self:Refresh() end, true)
  self.shows = UI.Dropdown(f, 190, "Show", function(v) show = v; self:Refresh() end)
  self.sorts = UI.Dropdown(f, 130, "Sort", function(v) sort = v; self:Refresh() end)
  self.search = UI.SearchBox(f, 200, "Search recipes", function(t) query = t:lower(); self:Refresh() end)
  self.head = {}
  for i, label in ipairs({ "Recipe", "Skill", "Who can make it", "Materials" }) do self.head[i] = UI.Text(f, 11, C.faint, i == 4 and "RIGHT" or "LEFT"); self.head[i]:SetText(label) end
  self.list = UI.List(f, 32, function(r)
    UI.ItemRow(r, 12)
    r.name = UI.Text(r, 12); r.name:SetPoint("LEFT", 40, 0)
    r.skill = UI.Text(r, 11, C.dim)
    r.who = UI.Text(r, 11, C.dim)
    r.cost = UI.Text(r, 12, C.text, "RIGHT"); r.cost:SetPoint("RIGHT", -12, 0)
    r:SetScript("OnClick", function(row) selected = row.rid; self:Refresh() end)
  end, function(r, c)
    local w = self.list:GetWidth()
    r.rid = c[1]
    UI.SetRowItem(r, c[2], nil, c[3])
    r.name:SetWidth(w * 0.38 - 28)
    r.name:SetText(c[3] .. (c[6] > 1 and ("  |cff999fb0x" .. c[6] .. "|r") or ""))
    r.skill:ClearAllPoints(); r.skill:SetPoint("LEFT", w * 0.40, 0)
    local learn, grey = self.skills[c[3]], c[11] or 0
    r.skill:SetText((learn and ("|cffe6e8ee" .. learn .. "|r  ") or "") .. (grey > 0 and ((c[10] or 0) .. "/" .. grey) or ""))
    local d = difficulty(c, self.mine)
    if d then r.skill:SetTextColor(unpack(DIFF[d])) else r.skill:SetTextColor(unpack(C.dim)) end
    local m = self.makers[c[2] > 0 and c[2] or c[3]]
    r.who:ClearAllPoints(); r.who:SetPoint("LEFT", w * 0.56, 0); r.who:SetWidth(w * 0.24)
    if m and m.takers then r.who:SetText(m.takers); r.who:SetTextColor(UI.Accent())
    elseif m and #m.known > 0 then r.who:SetText(table.concat(m.known, ", ")); r.who:SetTextColor(unpack(C.text))
    else r.who:SetText(""); end
    r.cost:SetText(c[7] >= 0 and ns.Money(c[7]) or "|cff999fb0no price|r")
    self.list:Select(r, c[1] == selected)
  end)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })

  -- the picked recipe
  local d = CreateFrame("Frame", nil, f)
  self.detail = d
  UI.Fill(d, C.surface); UI.Border(d)
  d.icon = d:CreateTexture(nil, "ARTWORK"); d.icon:SetSize(36, 36); d.icon:SetPoint("TOPLEFT", 14, -14)
  d.title = UI.Text(d, 16); d.title:SetPoint("TOPLEFT", 60, -14); d.title:SetWordWrap(true)
  d.sub = UI.Text(d, 11, C.dim); d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -4); d.sub:SetWordWrap(true)
  d.matHead = UI.Text(d, 12); UI.Accented(d.matHead); d.matHead:SetText("Materials")
  d.matCols = UI.Text(d, 11, C.faint, "RIGHT"); d.matCols:SetText("each          total")
  d.rows = {}
  d.total = UI.Text(d, 13); d.totalValue = UI.Text(d, 13, C.text, "RIGHT")
  d.line = d:CreateTexture(nil, "BORDER"); d.line:SetColorTexture(unpack(C.line)); d.line:SetHeight(1)
  d.note = UI.Text(d, 11, C.dim); d.note:SetWordWrap(true); d.note:SetJustifyV("TOP")
  d.whoHead = UI.Text(d, 12); UI.Accented(d.whoHead); d.whoHead:SetText("Who can make it")
  d.who = UI.Text(d, 12, C.text); d.who:SetWordWrap(true); d.who:SetJustifyV("TOP")
  d.request = UI.Button(d, "Request", 110, 28, function() if self.onRequest then self.onRequest() end end, "primary")
  d.whisper = UI.Button(d, "Whisper", 150, 28, function() if self.onWhisper then self.onWhisper() end end)
  d.ask = UI.Button(d, "Ask the guild", 120, 28, function() if self.onAsk then self.onAsk() end end)
  d.qtyLabel = UI.Text(d, 11, C.dim); d.qtyLabel:SetText("How many")
  d.minus = UI.Button(d, "-", 24, 24, function() self.qty = math.max(1, (self.qty or 1) - 1); self:Refresh() end)
  d.qty = UI.Text(d, 13, C.text, "CENTER")
  d.plus = UI.Button(d, "+", 24, 24, function() self.qty = math.min(20, (self.qty or 1) + 1); self:Refresh() end)
  d.hint = UI.Text(d, 11, C.faint); d.hint:SetWordWrap(true); d.hint:SetJustifyV("TOP")
  d.empty = UI.Text(d, 12, C.dim, "CENTER"); d.empty:SetWordWrap(true); d.empty:SetPoint("CENTER")
  d.empty:SetText("Pick a recipe to see its materials, what they cost, and who can make it for you.\n\nCrafting between guildmates is free: you bring the materials.")
  self.qty = 1
  self.empty = UI.EmptyNote(f)
end

function page:Layout(w, h)
  self.w, self.h = w, h
  local inner = w - PAD * 2
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER"); self.empty:SetWidth(inner - 60)
  self:Place()
end

-- The search box and dropdowns sit in one row, wrapping onto a second when the window is narrow.
function page:Place()
  local w, h = self.w, self.h
  if not w then return end
  local f = self.list:GetParent()
  local inner = w - PAD * 2
  local detailW = math.max(300, math.floor(inner * 0.38))
  local listW = inner - detailW - 14
  local x, y = 0, -PAD
  for _, el in ipairs({ self.search, self.chips, self.cats, self.shows, self.sorts }) do
    if el:IsShown() then
      local ew = el:GetWidth()
      if x > 0 and x + ew > inner then x, y = 0, y - 32 end
      el:ClearAllPoints(); el:SetPoint("TOPLEFT", PAD + x, y)
      x = x + ew + 8
    end
  end
  y = y - 26 - 16
  self.head[1]:ClearAllPoints(); self.head[1]:SetPoint("TOPLEFT", PAD + 40, y)
  self.head[2]:ClearAllPoints(); self.head[2]:SetPoint("TOPLEFT", PAD + listW * 0.40, y)
  self.head[3]:ClearAllPoints(); self.head[3]:SetPoint("TOPLEFT", PAD + listW * 0.56, y)
  self.head[4]:ClearAllPoints(); self.head[4]:SetPoint("TOPRIGHT", f, "TOPLEFT", PAD + listW - 17, y)
  self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", PAD, y - 18); self.list:SetSize(listW, math.max(60, h + y - 18 - PAD))
  self.detail:ClearAllPoints(); self.detail:SetPoint("TOPLEFT", PAD + listW + 14, y + 4); self.detail:SetSize(detailW, math.max(60, h + y + 4 - PAD))
  self.detailW = detailW
  self.detail.empty:SetWidth(detailW - 40)
end

local function matRow(d, i)
  local r = d.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, d); r:SetHeight(24)
  UI.ItemRow(r, 0)
  r.showMats = false
  r.name = UI.Text(r, 12); r.name:SetPoint("LEFT", 26, 0)
  r.total = UI.Text(r, 12, C.text, "RIGHT"); r.total:SetPoint("RIGHT", 0, 0)
  r.each = UI.Text(r, 11, C.dim, "RIGHT"); r.each:SetPoint("RIGHT", -78, 0)
  d.rows[i] = r
  return r
end

function page:Refresh(arg)
  if type(arg) == "table" and arg.search then
    query = arg.search:lower(); selected = nil
    self.search:SetText(arg.search)
  end
  local site = ns.Site()
  local has = site ~= nil
  for _, el in ipairs({ self.chips, self.cats, self.shows, self.sorts, self.search, self.list, self.detail }) do el:SetShown(has) end
  for _, hd in ipairs(self.head) do hd:SetShown(has) end
  self.empty:SetShown(not has)
  if not has then self.empty:SetText(ns.NO_SITE); return end
  self.makers, self.skills = makers(), skillMap()

  local profs, seen = {}, {}
  for _, c in ipairs(site.costs or {}) do seen[c[4]] = (seen[c[4]] or 0) + 1 end
  for p, n in pairs(seen) do if n > 10 then profs[#profs + 1] = { value = p, label = p } end end
  table.sort(profs, function(a, b) return a.label < b.label end)
  if not prof then -- start on a profession this character has
    for _, p in ipairs(profs) do if not prof and mySkill(p.value) then prof = p.value end end
  end
  prof = prof or (profs[1] and profs[1].value)
  self.chips:SetOptions(profs, query == "" and prof or nil)

  -- categories of the picked profession
  local cats, seenCat = {}, {}
  if query == "" then
    for _, c in ipairs(site.costs or {}) do
      local k = c[5] ~= "" and c[5] or "Other"
      if c[4] == prof and not seenCat[k] then seenCat[k] = true; cats[#cats + 1] = { value = k, label = k } end
    end
    table.sort(cats, function(a, b) return a.label < b.label end)
  end
  for k in pairs(categories) do if not seenCat[k] then categories[k] = nil end end
  self.cats:SetShown(query == "" and #cats > 1)
  self.cats:SetOptions(cats, categories, "All categories")

  self.mine = query == "" and mySkill(prof) or nil
  local shows = { { value = "all", label = "All recipes" }, { value = "guild", label = "Guild can make" }, { value = "requests", label = "Takes requests" } }
  if self.mine then shows[#shows + 1] = { value = "skillups", label = "Skill-ups for me (" .. self.mine .. ")" } elseif show == "skillups" then show = "all" end
  self.shows:SetOptions(shows, show)
  self.sorts:SetOptions({ { value = "skill", label = "Skill" }, { value = "name", label = "Name" }, { value = "cost", label = "Cost" } }, sort)
  self:Place()

  local items, picked = {}, nil
  local makersOf = self.makers
  for _, c in ipairs(site.costs or {}) do
    local inScope = (query ~= "" and c[3]:lower():find(query, 1, true)) or (query == "" and c[4] == prof and (next(categories) == nil or categories[c[5] ~= "" and c[5] or "Other"]))
    if inScope then
      local m = makersOf[c[2] > 0 and c[2] or c[3]]
      local keep = show == "all"
        or (show == "guild" and m ~= nil and (m.takers ~= nil or #m.known > 0))
        or (show == "requests" and m ~= nil and m.takers ~= nil)
        or (show == "skillups" and difficulty(c, self.mine) ~= "grey" and (c[11] or 0) > 0)
      if keep then items[#items + 1] = c end
    end
    if c[1] == selected then picked = c end
  end
  local skills = self.skills
  local function skillKey(c) return skills[c[3]] or ((c[10] or 0) > 0 and c[10]) or ((c[11] or 0) > 0 and c[11]) or 999 end
  table.sort(items, function(a, b)
    if sort == "cost" then
      local ca, cb = a[7] >= 0 and a[7] or 1e12, b[7] >= 0 and b[7] or 1e12
      if ca ~= cb then return ca < cb end
    elseif sort == "skill" then
      local sa, sb = skillKey(a), skillKey(b)
      if sa ~= sb then return sa < sb end
    end
    return a[3] < b[3]
  end)
  if query ~= "" and #items == 1 then picked = items[1]; selected = picked[1] end
  if type(arg) == "table" and arg.search then -- a jump from search: open the recipe with that exact name
    for _, c in ipairs(items) do if c[3]:lower() == query then picked = c; selected = c[1] end end
  end
  self.list:SetItems(items)
  self:ShowDetail(site, picked)
end

function page:ShowDetail(site, c)
  local d, w = self.detail, (self.detailW or 320) - 28
  local parts = { d.icon, d.title, d.sub, d.matHead, d.matCols, d.total, d.totalValue, d.line, d.note, d.whoHead, d.who, d.request, d.whisper, d.ask, d.qtyLabel, d.minus, d.qty, d.plus, d.hint }
  for _, el in ipairs(parts) do el:SetShown(c ~= nil) end
  d.empty:SetShown(c == nil)
  if not c then for _, r in ipairs(d.rows) do r:Hide() end return end
  if self.detailFor ~= c[1] then self.detailFor = c[1]; self.qty = 1 end
  local qty = self.qty or 1
  local itemID = c[2] > 0 and c[2] or nil

  local name, _, quality, icon = nil, nil, nil, nil
  if itemID then name, _, quality, icon = UI.ItemLook(itemID) end
  d.icon:SetTexture(icon or 134400)
  d.title:SetWidth(w - 46); d.title:SetText(c[3]); d.title:SetTextColor(UI.QualityColor(quality))
  local bits = { c[4] }
  local skill = self.skills[c[3]]
  if skill then bits[#bits + 1] = "learned at skill " .. skill end
  if (c[11] or 0) > 0 then bits[#bits + 1] = "turns yellow at " .. (c[10] or 0) .. ", grey at " .. c[11] end
  if c[5] ~= "" then table.insert(bits, 2, c[5]) end
  if c[6] > 1 then bits[#bits + 1] = "makes " .. c[6] end
  if itemID and c[8] >= 0 then bits[#bits + 1] = "sells for " .. ns.MoneyPlain(c[8]) end
  d.sub:SetWidth(w - 46); d.sub:SetText(table.concat(bits, "  ·  "))

  -- materials with auction prices
  local y = -70
  d.matHead:ClearAllPoints(); d.matHead:SetPoint("TOPLEFT", 14, y)
  d.matCols:ClearAllPoints(); d.matCols:SetPoint("TOPRIGHT", -14, y)
  y = y - 22
  local mats = ns.MaterialsFor and ns.MaterialsFor(itemID, c[3])
  local total, missing = 0, false
  for i, m in ipairs(mats or {}) do
    local r = matRow(d, i)
    local n = (m[2] or 1) * qty
    r.name:SetWidth(w - 26 - 150)
    r.name:SetText(n .. "x " .. (UI.SetRowItem(r, m[1], nil, m[3]) or m[3] or "?"))
    local each = m[4] or -1
    if each >= 0 then
      r.each:SetText(ns.Money(each)); r.total:SetText(ns.Money(each * n)); total = total + each * n
    else
      r.each:SetText(""); r.total:SetText("|cff999fb0no price|r"); missing = true
    end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 14, y); r:SetWidth(w); r:Show()
    y = y - 26
  end
  for i = #(mats or {}) + 1, #d.rows do d.rows[i]:Hide() end
  d.matCols:SetShown(mats ~= nil)
  d.line:ClearAllPoints(); d.line:SetPoint("TOPLEFT", 14, y - 2); d.line:SetPoint("TOPRIGHT", -14, y - 2)
  d.line:SetShown(mats ~= nil); d.total:SetShown(mats ~= nil); d.totalValue:SetShown(mats ~= nil)
  if mats then
    y = y - 10
    d.total:ClearAllPoints(); d.total:SetPoint("TOPLEFT", 14, y); d.total:SetText(qty > 1 and ("Total for " .. qty) or "Total")
    d.totalValue:ClearAllPoints(); d.totalValue:SetPoint("TOPRIGHT", -14, y); d.totalValue:SetText(ns.Money(total) .. (missing and " |cff999fb0+|r" or ""))
    y = y - 22
    d.note:SetText("Estimated from the auction house" .. (site.pricesAt and site.pricesAt > 0 and (", prices from " .. ns.Ago(site.pricesAt)) or "") .. ". You bring these; the crafting itself is free.")
  else
    d.note:SetText(site.mats and "No materials listed for this recipe." or "Click Sync to load materials and prices.")
  end
  d.note:SetWidth(w); d.note:ClearAllPoints(); d.note:SetPoint("TOPLEFT", 14, y)
  y = y - (d.note:GetStringHeight() or 14) - 16

  -- who, and asking them
  local m = self.makers[itemID or c[3]]
  local me = UnitName("player")
  d.whoHead:ClearAllPoints(); d.whoHead:SetPoint("TOPLEFT", 14, y); y = y - 20
  local other = m and m.others and m.others[1]
  if m and m.takers then d.who:SetText(m.takers .. "  |cff999fb0(takes requests" .. (m.inPerson and ", meet in person" or "") .. ")|r")
  elseif m and #m.known > 0 then d.who:SetText(table.concat(m.known, ", "))
  else d.who:SetText("|cff999fb0Nobody in the guild is known to make this yet.|r") end
  d.who:SetWidth(w); d.who:ClearAllPoints(); d.who:SetPoint("TOPLEFT", 14, y)
  y = y - (d.who:GetStringHeight() or 14) - 14

  local canRequest = m and m.takers ~= nil
  local canWhisper = other ~= nil and other ~= me
  for _, el in ipairs({ d.qtyLabel, d.minus, d.qty, d.plus }) do el:SetShown(true) end
  d.request:SetShown(canRequest); d.whisper:SetShown(canWhisper); d.ask:Show()
  do
    d.qtyLabel:ClearAllPoints(); d.qtyLabel:SetPoint("TOPLEFT", 14, y - 6)
    d.minus:ClearAllPoints(); d.minus:SetPoint("TOPLEFT", 80, y)
    d.qty:ClearAllPoints(); d.qty:SetPoint("LEFT", d.minus, "RIGHT", 0, 0); d.qty:SetWidth(34); d.qty:SetText(qty)
    d.plus:ClearAllPoints(); d.plus:SetPoint("LEFT", d.minus, "RIGHT", 34, 0)
    y = y - 34
    local x = 14
    if canRequest then d.request:ClearAllPoints(); d.request:SetPoint("TOPLEFT", x, y); x = x + 118 end
    if canWhisper then
      d.whisper.label:SetText("Whisper " .. other); d.whisper:SetWidth(d.whisper.label:GetStringWidth() + 28)
      d.whisper:ClearAllPoints(); d.whisper:SetPoint("TOPLEFT", x, y); x = x + d.whisper:GetWidth() + 8
    end
    d.ask:ClearAllPoints(); d.ask:SetPoint("TOPLEFT", x, y)
    y = y - 38
  end
  self.onRequest = canRequest and function() ns.RequestCraft(m.recipe or c[1], itemID, c[3], qty) end or nil
  self.onWhisper = canWhisper and function() whisper(other, itemID, c[3], qty, mats) end or nil
  self.onAsk = function() ns.AskBoard(itemID, c[3], qty) end

  if canRequest then d.hint:SetText("Request saves it for the guild website (sent on your next sync). The crafter accepts it, then you mail them the materials.")
  elseif canWhisper then d.hint:SetText(other .. " hasn't turned on craft requests, so ask them directly: Whisper sends a message with the materials you'll bring.")
  elseif m and #m.known > 0 then d.hint:SetText("Only your own characters know this recipe. Ask the guild puts it on the crafting board for any crafter to take.")
  else d.hint:SetText("Nobody in the guild is known to make this yet. Ask the guild puts it on the crafting board for any crafter to take.") end
  d.hint:SetWidth(w); d.hint:ClearAllPoints(); d.hint:SetPoint("TOPLEFT", 14, y)
end

ns.RegisterPage(page)
