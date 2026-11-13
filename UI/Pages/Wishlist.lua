-- Page: Wishlist. The boss loot you've starred on the Dungeons pages, each marked main
-- spec, off spec or transmog. Foxden reminds you at the boss and tells you when it drops;
-- guildmates see what you want after a sync.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16

local page = { key = "wishlist", label = "Wishlist", order = 18 }

function page:Build(f)
  self.intro = UI.Text(f, 12, C.dim); self.intro:SetWordWrap(true)
  self.head = {}
  for i, label in ipairs({ "Item", "For", "Drops from", "Also wanted by" }) do self.head[i] = UI.Text(f, 11, C.faint); self.head[i]:SetText(label) end
  self.list = UI.List(f, 34, function(r)
    UI.ItemRow(r, 12)
    r.showMats = false
    r.name = UI.Text(r, 12); r.name:SetPoint("LEFT", 40, 0)
    r.kind = CreateFrame("Button", nil, r); r.kind:SetHeight(22)
    r.kind.text = UI.Text(r.kind, 12); r.kind.text:SetPoint("LEFT")
    r.kind:SetScript("OnClick", function(b)
      local w = b:GetParent().w
      if w then ns.SetWish(w.i, (w.k == "ms" and "os") or (w.k == "os" and "tm") or "ms"); self:Refresh() end
    end)
    r.kind:SetScript("OnEnter", function(b) GameTooltip:SetOwner(b, "ANCHOR_TOP"); GameTooltip:SetText("Click to change: main spec, off spec, transmog"); GameTooltip:Show() end)
    r.kind:SetScript("OnLeave", GameTooltip_Hide)
    r.from = UI.Text(r, 11, C.dim)
    r.others = UI.Text(r, 11, C.dim)
    r.remove = UI.Button(r, "Remove", 64, 22, function(b) local w = b:GetParent().w; if w then ns.SetWish(w.i, nil); self:Refresh() end end)
    r.remove:SetPoint("RIGHT", -8, 0)
    r:SetScript("OnClick", function(row) if row.w and row.w.d then ns.OpenPage("journal", { dungeon = row.w.d, boss = row.w.b }) end end)
  end, function(r, w)
    local wd = self.list:GetWidth()
    r.w = w
    r.name:SetWidth(wd * 0.30 - 28)
    r.name:SetText(UI.SetRowItem(r, w.i, nil, w.n) or w.n or ("Item " .. w.i))
    local k = w.k or "ms"
    r.kind:ClearAllPoints(); r.kind:SetPoint("LEFT", wd * 0.32, 0); r.kind:SetWidth(wd * 0.12)
    r.kind.text:SetText(ns.WISH_COLOR[k] .. ns.WISH_LABEL[k] .. "|r")
    r.from:ClearAllPoints(); r.from:SetPoint("LEFT", wd * 0.45, 0); r.from:SetWidth(wd * 0.27)
    r.from:SetText((w.b or "?") .. (w.d and (", " .. w.d) or "") .. (w.web and "  |cff999fb0(from the website)|r" or ""))
    r.others:ClearAllPoints(); r.others:SetPoint("LEFT", wd * 0.73, 0); r.others:SetWidth(wd * 0.27 - 80)
    r.others:SetText(ns.WantedBy(w.i) or "")
  end)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })
  self.empty = UI.Text(f, 13, C.dim, "CENTER"); self.empty:SetWordWrap(true)
  self.empty:SetText("Your wishlist is empty.\n\nOpen Dungeons, pick a boss, and click the star next to any item it drops. Click again to switch between main spec, off spec and transmog.")
end

function page:Layout(w, h)
  local inner = w - PAD * 2
  self.intro:ClearAllPoints(); self.intro:SetPoint("TOPLEFT", PAD, -PAD); self.intro:SetWidth(inner)
  local cols = { 40, inner * 0.32, inner * 0.45, inner * 0.73 }
  for i = 1, 4 do self.head[i]:ClearAllPoints(); self.head[i]:SetPoint("TOPLEFT", PAD + cols[i], -PAD - 40) end
  self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", PAD, -PAD - 58); self.list:SetSize(inner, h - PAD * 2 - 58)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER"); self.empty:SetWidth(inner - 80)
end

function page:Refresh()
  local list = {}
  for _, w in ipairs(ns.Wishlist()) do list[#list + 1] = w end
  local order = { ms = 1, os = 2, tm = 3 }
  table.sort(list, function(a, b)
    if (a.d or "") ~= (b.d or "") then return (a.d or "") < (b.d or "") end
    if (order[a.k or "ms"]) ~= (order[b.k or "ms"]) then return order[a.k or "ms"] < order[b.k or "ms"] end
    return (a.n or "") < (b.n or "")
  end)
  local has = #list > 0
  self.list:SetShown(has); self.intro:SetShown(has); self.empty:SetShown(not has)
  for _, hd in ipairs(self.head) do hd:SetShown(has) end
  self.intro:SetText(#list .. (#list == 1 and " item" or " items") .. ". Foxden reminds you at the boss and tells you when one drops. Guildmates see your list after your next sync. Click a row to open its boss. Picks made on the guild website for a character named " .. (UnitName("player") or "you") .. " show up here too.")
  self.list:SetItems(list)
end

ns.RegisterPage(page)
