-- Page: Crafters. Your characters' professions and guildmates' (shared over
-- guild chat by their addons), with every recipe they know.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local LIST_W, PAD = 240, 16

local page = { key = "crafters", label = "Crafters", section = "craft", order = 70 }
local selected

local function crafterList()
  local c, list = ns.Crafting(), {}
  if not c then return list end
  for key, ch in pairs(c.chars) do if next(ch.professions or {}) then list[#list + 1] = { key = key, name = ch.name or key, class = ch.class, profs = ch.professions, mine = true } end end
  for key, g in pairs(c.guild) do if not c.chars[key] and next(g.professions or {}) then list[#list + 1] = { key = key, name = key:match("^[^-]+") or key, class = g.class, profs = g.professions } end end
  table.sort(list, function(a, b) if a.mine ~= b.mine then return a.mine == true end return a.name < b.name end)
  return list
end

-- item/spell -> name: the website snapshot first, then the game's own item cache.
local function nameMap()
  local site, map = ns.Site(), {}
  for _, c in ipairs(site and site.costs or {}) do if c[2] > 0 then map[c[2]] = c[3] end end
  return map
end

function page:Build(f)
  self.list = UI.List(f, 46, function(r)
    r.name = UI.Text(r, 13); r.name:SetPoint("TOPLEFT", 14, -8)
    r.sub = UI.Text(r, 11, C.dim); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4); r.sub:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    r:SetScript("OnClick", function(row) selected = row.key; ns.RefreshUI() end)
  end, function(r, c)
    r.key = c.key
    r.name:SetText(c.name .. (c.mine and "  |cff999fb0(you)|r" or "")); r.name:SetTextColor(UI.ClassColor(c.class))
    local bits = {}
    for p, d in pairs(c.profs) do bits[#bits + 1] = p .. " " .. (d.skill or "?") end
    table.sort(bits)
    r.sub:SetText(table.concat(bits, ", "))
    self.list:Select(r, c.key == selected)
  end)
  self.list:SetPoint("TOPLEFT"); self.list:SetPoint("BOTTOMLEFT"); self.list:SetWidth(LIST_W)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })
  self.title = UI.Text(f, 20)
  self.sub = UI.Text(f, 12, C.dim)
  self.recipes = UI.List(f, 28, function(r)
    r.name = UI.Text(r, 12); r.name:SetPoint("LEFT", 12, 0)
    r.prof = UI.Text(r, 11, C.dim, "RIGHT"); r.prof:SetPoint("RIGHT", -12, 0)
  end, function(r, x) r.name:SetText(x.name); r.prof:SetText(x.prof) end)
  self.empty = UI.EmptyNote(f)
end

function page:Layout(w, h)
  local x, dw = LIST_W + PAD + 1, w - LIST_W - PAD * 2 - 1
  self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", x, -PAD)
  self.sub:ClearAllPoints(); self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -6); self.sub:SetWidth(dw)
  self.recipes:ClearAllPoints(); self.recipes:SetPoint("TOPLEFT", x, -PAD - 62); self.recipes:SetSize(dw, h - PAD * 2 - 62)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER"); self.empty:SetWidth(w - 80)
end

function page:Refresh()
  local list = crafterList()
  local c
  for _, x in ipairs(list) do if x.key == selected then c = x end end
  if not c then c = list[1]; selected = c and c.key end
  self.list:SetItems(list)
  local has = c ~= nil
  for _, el in ipairs({ self.list, self.title, self.sub, self.recipes }) do el:SetShown(has) end
  self.empty:SetShown(not has)
  if not has then
    self.empty:SetText("No crafters yet.\n\nOpen each of your profession windows once and your recipes are saved here. Guildmates with the addon show up as their addons share.")
    return
  end
  self.title:SetText(c.name); self.title:SetTextColor(UI.ClassColor(c.class))
  local names, recipes, bits = nameMap(), {}, {}
  for prof, d in pairs(c.profs) do
    bits[#bits + 1] = string.format("%s %s%s (%d recipes)", prof, tostring(d.skill or "?"), d.maxSkill and ("/" .. d.maxSkill) or "", #(d.recipes or {}))
    for _, r in ipairs(d.recipes or {}) do
      local name = r.name or (r.item and (names[r.item] or (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(r.item)) or (GetItemInfo and GetItemInfo(r.item))))
      recipes[#recipes + 1] = { name = name or (r.item and ("Item " .. r.item)) or "Recipe", prof = prof }
    end
  end
  table.sort(bits)
  table.sort(recipes, function(a, b) return a.prof == b.prof and a.name < b.name or a.prof < b.prof end)
  self.sub:SetText(table.concat(bits, "   ") .. (c.mine and "" or "   |cff999fb0shared over guild chat|r"))
  self.recipes:SetItems(recipes)
end

ns.RegisterPage(page)
