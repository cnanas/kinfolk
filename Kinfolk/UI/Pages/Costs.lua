-- Page: Costs. What each craft costs to make now, and what it sells for.
-- Data: the companion's snapshot of the website (ns.Site().costs).

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16

local page = { key = "costs", label = "Costs", section = "craft", order = 60 }
local query, prof = "", nil

function page:Build(f)
  self.chips = UI.Chips(f, function(v) prof = v; self:Refresh() end)
  self.search = UI.SearchBox(f, 220, "Search all crafts", function(t) query = t:lower(); self:Refresh() end)
  self.head = {}
  for i, label in ipairs({ "Craft", "Cost to make", "Sells for", "Margin" }) do self.head[i] = UI.Text(f, 11, C.faint, i > 1 and "RIGHT" or "LEFT"); self.head[i]:SetText(label) end
  self.list = UI.List(f, 30, function(r)
    r.name = UI.Text(r, 12); r.name:SetPoint("LEFT", 12, 0)
    r.cost = UI.Text(r, 12, C.text, "RIGHT"); r.sells = UI.Text(r, 12, C.dim, "RIGHT"); r.margin = UI.Text(r, 12, C.text, "RIGHT")
  end, function(r, c)
    local w = self.list:GetWidth()
    r.name:SetWidth(w * 0.46)
    r.name:SetText(c[3] .. (c[6] > 1 and ("  |cff999fb0x" .. c[6] .. "|r") or "") .. (c[9] == 1 and "  |cfff0a35e(low supply)|r" or ""))
    r.cost:ClearAllPoints(); r.cost:SetPoint("RIGHT", -w * 0.36, 0)
    r.sells:ClearAllPoints(); r.sells:SetPoint("RIGHT", -w * 0.18, 0)
    r.margin:ClearAllPoints(); r.margin:SetPoint("RIGHT", -12, 0)
    r.cost:SetText(c[7] >= 0 and ns.Money(c[7]) or "|cfff0a35emissing prices|r")
    r.sells:SetText(c[2] == 0 and "enchant" or ns.Money(c[8]))
    if c[7] >= 0 and c[8] >= 0 then
      local m = c[8] - c[7]
      r.margin:SetText((m < 0 and "|cfff06b6b-" or "|cff6fd39a") .. ns.MoneyPlain(math.abs(m)) .. "|r")
    else r.margin:SetText("") end
  end)
  self.foot = UI.Text(f, 11, C.faint); self.foot:SetWordWrap(true)
  self.empty = UI.EmptyNote(f)
end

function page:Layout(w, h)
  local inner = w - PAD * 2
  self.chips:ClearAllPoints(); self.chips:SetPoint("TOPLEFT", PAD, -PAD); self.chips:SetWidth(inner)
  self.search:ClearAllPoints(); self.search:SetPoint("TOPLEFT", PAD, -PAD - 34)
  local f = self.list:GetParent()
  self.head[1]:ClearAllPoints(); self.head[1]:SetPoint("TOPLEFT", PAD + 12, -PAD - 72)
  self.head[2]:ClearAllPoints(); self.head[2]:SetPoint("TOPRIGHT", f, "TOPLEFT", PAD + inner - inner * 0.36 - 5, -PAD - 72)
  self.head[3]:ClearAllPoints(); self.head[3]:SetPoint("TOPRIGHT", f, "TOPLEFT", PAD + inner - inner * 0.18 - 5, -PAD - 72)
  self.head[4]:ClearAllPoints(); self.head[4]:SetPoint("TOPRIGHT", f, "TOPLEFT", PAD + inner - 17, -PAD - 72)
  self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", PAD, -PAD - 90); self.list:SetSize(inner, h - PAD * 2 - 90 - 30)
  self.foot:ClearAllPoints(); self.foot:SetPoint("BOTTOMLEFT", PAD, PAD); self.foot:SetWidth(inner)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER"); self.empty:SetWidth(inner - 60)
end

function page:Refresh()
  local site = ns.Site()
  local has = site ~= nil
  for _, el in ipairs({ self.chips, self.search, self.list, self.foot }) do el:SetShown(has) end
  for _, h in ipairs(self.head) do h:SetShown(has) end
  self.empty:SetShown(not has)
  if not has then self.empty:SetText(ns.NO_SITE); return end
  local profs, seen = {}, {}
  for _, c in ipairs(site.costs or {}) do if not seen[c[4]] then seen[c[4]] = 0 end; seen[c[4]] = seen[c[4]] + 1 end
  for p, n in pairs(seen) do if n > 10 then profs[#profs + 1] = { value = p, label = p } end end
  table.sort(profs, function(a, b) return a.label < b.label end)
  prof = prof or (seen["Blacksmithing"] and "Blacksmithing") or (profs[1] and profs[1].value)
  self.chips:SetOptions(profs, query == "" and prof or nil)
  local items = {}
  for _, c in ipairs(site.costs or {}) do
    if (query ~= "" and c[3]:lower():find(query, 1, true)) or (query == "" and c[4] == prof) then items[#items + 1] = c end
  end
  table.sort(items, function(a, b) return a[5] == b[5] and a[3] < b[3] or a[5] < b[5] end)
  self.list:SetItems(items)
  self.foot:SetText(string.format("Cost is per item made, using the cheapest of auction, vendor or crafting each material. Prices from Alliance auction house %s, fetched %s.",
    tostring(site.house or "?"), site.pricesAt and site.pricesAt > 0 and date("%b %d, %H:%M", site.pricesAt) or "?"))
end

ns.RegisterPage(page)
