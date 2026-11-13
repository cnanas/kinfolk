-- Page: Trainer. Your class abilities from your trainer's own list: what you can
-- learn now, what's coming and when, and what it costs. Right-click to skip one
-- (it's left out of "Learn all" at the trainer and of the totals).

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16

local page = { key = "trainer", label = "Trainer", order = 15 }
local view = "ready"
local LABEL = { ready = "Ready", soon = "Coming up", known = "Learned", skipped = "Skipped" }

function page:Build(f)
  self.title = UI.Text(f, 20)
  self.sub = UI.Text(f, 12, C.dim); self.sub:SetWordWrap(true)
  self.chips = UI.Chips(f, function(v) view = v; self:Refresh() end)
  self.list = UI.List(f, 34, function(r)
    r:RegisterForClicks("RightButtonUp")
    UI.ItemRow(r, 12)
    r.name = UI.Text(r, 12); r.name:SetPoint("LEFT", 40, 0)
    r.status = UI.Text(r, 11, C.dim, "RIGHT")
    r.level = UI.Text(r, 12, C.dim, "RIGHT")
    r.cost = UI.Text(r, 12, C.text, "RIGHT"); r.cost:SetPoint("RIGHT", -12, 0)
    r:SetScript("OnClick", function(row) if row.spell then ns.SetSkipped(row.spell, row.spell.status ~= "skipped") end end)
  end, function(r, s)
    r.spell = s
    local w = self.list:GetWidth()
    r.itemID, r.spellID, r.tipName, r.showMats = nil, s.id, s.name, false
    r.icon:SetTexture(s.icon or (s.id and C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(s.id)) or 134400)
    r.icon:SetDesaturated(s.status == "known" or s.status == "skipped")
    r.name:SetText(s.name .. (s.rank and ("  |cff999fb0" .. s.rank .. "|r") or "")); r.name:SetWidth(w * 0.5)
    r.name:SetTextColor(unpack((s.status == "known" or s.status == "skipped") and C.faint or C.text))
    r.level:ClearAllPoints(); r.level:SetPoint("RIGHT", -w * 0.30, 0); r.level:SetText("Level " .. s.level)
    r.status:ClearAllPoints(); r.status:SetPoint("RIGHT", -w * 0.16, 0); r.status:SetText(LABEL[s.status] or "")
    if s.status == "ready" then r.status:SetTextColor(UI.Accent()) else r.status:SetTextColor(unpack(C.dim)) end
    r.cost:SetText(s.status == "known" and "" or ns.Money(s.cost))
  end)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })
  self.hint = UI.Text(f, 11, C.faint); self.hint:SetText("Right-click an ability to skip it, or to bring it back.")
  self.empty = UI.EmptyNote(f)
end

function page:Layout(w, h)
  local inner = w - PAD * 2
  self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", PAD, -PAD)
  self.sub:ClearAllPoints(); self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -6); self.sub:SetWidth(inner)
  self.chips:ClearAllPoints(); self.chips:SetPoint("TOPLEFT", PAD, -PAD - 58); self.chips:SetWidth(inner)
  self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", PAD, -PAD - 90); self.list:SetSize(inner, h - PAD * 2 - 90 - 22)
  self.hint:ClearAllPoints(); self.hint:SetPoint("BOTTOMLEFT", PAD, PAD)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER"); self.empty:SetWidth(inner - 60)
end

function page:Refresh()
  local all, at, fromGuild = ns.ClassAbilities and ns.ClassAbilities()
  local has = all ~= nil
  for _, el in ipairs({ self.title, self.sub, self.chips, self.list, self.hint }) do el:SetShown(has) end
  self.empty:SetShown(not has)
  if not has then
    self.empty:SetText("Visit your class trainer once.\n\nFoxden reads the trainer's whole list (every rank, with the level and cost) and keeps it here, so you'll always know what you can learn and what's coming next.")
    return
  end
  local counts, readyCost, nextLevel = { ready = 0, soon = 0, known = 0, skipped = 0 }, 0, nil
  for _, s in ipairs(all) do
    counts[s.status] = counts[s.status] + 1
    if s.status == "ready" then readyCost = readyCost + (s.cost or 0) end
    if s.status == "soon" and (not nextLevel or s.level < nextLevel) then nextLevel = s.level end
  end
  local _, class = UnitClass("player")
  self.title:SetText(UI.ClassName and UI.ClassName(class) or class); self.title:SetTextColor(UI.ClassColor(class))
  local bits = { "Level " .. UnitLevel("player") }
  bits[#bits + 1] = counts.ready > 0 and (counts.ready .. " ready to learn, " .. ns.MoneyPlain(readyCost)) or "nothing to learn right now"
  if nextLevel then
    local n = 0
    for _, s in ipairs(all) do if s.status == "soon" and s.level == nextLevel then n = n + 1 end end
    bits[#bits + 1] = "next: " .. n .. " at level " .. nextLevel
  end
  bits[#bits + 1] = (fromGuild and "guild's trainer list from " or "trainer list from ") .. date("%b %d", at or GetServerTime())
  self.sub:SetText(table.concat(bits, "   ·   "))
  if counts[view] == 0 and view ~= "all" then view = counts.ready > 0 and "ready" or "soon" end
  self.chips:SetOptions({
    { value = "ready", label = "Ready (" .. counts.ready .. ")" },
    { value = "soon", label = "Coming up (" .. counts.soon .. ")" },
    { value = "known", label = "Learned (" .. counts.known .. ")" },
    { value = "skipped", label = "Skipped (" .. counts.skipped .. ")" },
    { value = "all", label = "All" },
  }, view)
  local items = {}
  for _, s in ipairs(all) do if view == "all" or s.status == view then items[#items + 1] = s end end
  self.list:SetItems(items)
end

ns.RegisterPage(page)
