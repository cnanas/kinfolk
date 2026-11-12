-- Page: Shop. Crafts guild members offer, for free: the requester brings the materials.
-- Data: the companion's snapshot of the website (ns.Site().shop).

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16

local page = { key = "shop", label = "Shop", section = "craft", order = 50 }
local query, selected = "", nil

function page:Build(f)
  self.intro = UI.Text(f, 12, C.dim); self.intro:SetWordWrap(true)
  self.search = UI.SearchBox(f, 240, "Search the shop", function(t) query = t:lower(); self:Refresh() end)
  self.head = {}
  for i, label in ipairs({ "Craft", "Crafters", "Materials, about" }) do self.head[i] = UI.Text(f, 11, C.faint, i > 2 and "RIGHT" or "LEFT"); self.head[i]:SetText(label) end
  self.list = UI.List(f, 34, function(r)
    r.name = UI.Text(r, 12); r.name:SetPoint("LEFT", 12, 0)
    r.who = UI.Text(r, 11, C.dim)
    r.price = UI.Text(r, 12, C.text, "RIGHT")
    r:SetScript("OnClick", function(row) selected = row.rid; self:Refresh() end)
  end, function(r, l, i)
    r.rid = l[1]
    r.name:SetText(l[3] .. (l[7] == 1 and "  |cff999fb0(meet in person)|r" or ""))
    r.who:SetText(l[8]); r.price:SetText((l[5] or -1) >= 0 and ns.Money(l[5]) or "|cff999fb0no price|r")
    local w = self.list:GetWidth()
    r.name:SetWidth(w * 0.42); r.who:ClearAllPoints(); r.who:SetPoint("LEFT", w * 0.44, 0); r.who:SetWidth(w * 0.32)
    r.price:ClearAllPoints(); r.price:SetPoint("RIGHT", -12, 0)
    self.list:Select(r, l[1] == selected)
  end)
  self.foot = UI.Text(f, 11, C.dim); self.foot:SetWordWrap(true)
  self.link = UI.CopyBox(f, 300)
  self.empty = UI.EmptyNote(f)
end

function page:Layout(w, h)
  local inner = w - PAD * 2
  self.intro:ClearAllPoints(); self.intro:SetPoint("TOPLEFT", PAD, -PAD); self.intro:SetWidth(inner)
  self.search:ClearAllPoints(); self.search:SetPoint("TOPLEFT", PAD, -PAD - 40)
  local cols = { 12, inner * 0.44, nil, nil }
  self.head[1]:ClearAllPoints(); self.head[1]:SetPoint("TOPLEFT", PAD + 12, -PAD - 78)
  self.head[2]:ClearAllPoints(); self.head[2]:SetPoint("TOPLEFT", PAD + cols[2], -PAD - 78)
  self.head[3]:ClearAllPoints(); self.head[3]:SetPoint("TOPRIGHT", self.intro:GetParent(), "TOPLEFT", PAD + inner - 17, -PAD - 78)
  self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", PAD, -PAD - 96); self.list:SetSize(inner, h - PAD * 2 - 96 - 64)
  self.foot:ClearAllPoints(); self.foot:SetPoint("BOTTOMLEFT", PAD, PAD + 32); self.foot:SetWidth(inner)
  self.link:ClearAllPoints(); self.link:SetPoint("BOTTOMLEFT", PAD, PAD); self.link:SetWidth(inner)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER"); self.empty:SetWidth(inner - 60)
end

function page:Refresh()
  local site = ns.Site()
  local has = site ~= nil
  for _, el in ipairs({ self.intro, self.search, self.list, self.foot, self.link }) do el:SetShown(has) end
  for _, h in ipairs(self.head) do h:SetShown(has) end
  self.empty:SetShown(not has)
  if not has then self.empty:SetText(ns.NO_SITE); return end
  self.intro:SetText("Crafts guild members offer, for free: you bring the materials, they make it. The value shown is only a guide to what the materials cost at the auction house.")
  local items = {}
  for _, l in ipairs(site.shop or {}) do
    if query == "" or l[3]:lower():find(query, 1, true) or l[4]:lower():find(query, 1, true) then items[#items + 1] = l end
  end
  table.sort(items, function(a, b) return a[4] == b[4] and a[3] < b[3] or a[4] < b[4] end)
  self.list:SetItems(items)
  if #site.shop == 0 then
    self.foot:SetText("The shop is empty. Crafters join by turning on \"Offer my crafts in the guild shop\" in Settings, then syncing.")
    self.link:SetLink((site.site or "") .. "/shop")
  elseif selected then
    self.foot:SetText("To order, whisper a crafter in game or request it on the website (copy this link into your browser):")
    self.link:SetLink((site.site or "") .. "/shop/" .. selected)
  else
    self.foot:SetText("Click a craft for its order link. Request on the website or whisper a crafter, then mail them the materials when they accept.")
    self.link:SetLink((site.site or "") .. "/shop")
  end
end

ns.RegisterPage(page)
