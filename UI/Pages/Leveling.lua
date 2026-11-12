-- Page: Leveling. This character's level-ups as Foxden recorded them: how long
-- each level took (from /played) and what you gained.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16

local page = { key = "leveling", label = "Leveling", section = "char", order = 120 }

local function dur(s)
  if not s then return "—" end
  local h, m = math.floor(s / 3600), math.floor((s % 3600) / 60)
  return h > 0 and string.format("%dh %02dm", h, m) or string.format("%dm", math.max(1, m))
end

function page:Build(f)
  self.title = UI.Text(f, 20)
  self.sub = UI.Text(f, 12, C.dim); self.sub:SetWordWrap(true)
  self.list = UI.List(f, 34, function(r)
    r.level = UI.Text(r, 13); r.level:SetPoint("LEFT", 14, 0)
    r.time = UI.Text(r, 12, C.text, "RIGHT")
    r.gains = UI.Text(r, 11, C.dim)
    r.date = UI.Text(r, 11, C.faint, "RIGHT"); r.date:SetPoint("RIGHT", -12, 0)
  end, function(r, x)
    local w = self.list:GetWidth()
    r.level:SetText("Level " .. x.level)
    r.time:ClearAllPoints(); r.time:SetPoint("LEFT", 90, 0); r.time:SetWidth(80); r.time:SetJustifyH("LEFT")
    r.time:SetText(dur(x.seconds) .. (x.best and "  |cff7fe3c4fastest|r" or ""))
    local g, h = x.gains or {}, {}
    for _, k in ipairs({ { "str", "Str" }, { "agi", "Agi" }, { "sta", "Sta" }, { "int", "Int" }, { "spi", "Spi" } }) do
      if (g[k[1]] or 0) > 0 then h[#h + 1] = "+" .. g[k[1]] .. " " .. k[2] end
    end
    r.gains:ClearAllPoints(); r.gains:SetPoint("LEFT", 230, 0); r.gains:SetWidth(w - 230 - 90); r.gains:SetText(table.concat(h, "  "))
    r.date:SetText(x.at and date("%b %d", x.at) or "")
  end)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })
  self.empty = UI.EmptyNote(f)
end

function page:Layout(w, h)
  local inner = w - PAD * 2
  self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", PAD, -PAD)
  self.sub:ClearAllPoints(); self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -6); self.sub:SetWidth(inner)
  self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", PAD, -PAD - 62); self.list:SetSize(inner, h - PAD * 2 - 62)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER"); self.empty:SetWidth(inner - 60)
end

function page:Refresh()
  local hist = ns.LevelHistory and ns.LevelHistory()
  local items, total, best = {}, 0, nil
  for level, x in pairs(hist and hist.history or {}) do
    items[#items + 1] = { level = level, seconds = x.seconds, gains = x.gains, at = x.at }
    if x.seconds then total = total + x.seconds; if not best or x.seconds < best.seconds then best = items[#items] end end
  end
  if best then best.best = true end
  table.sort(items, function(a, b) return a.level > b.level end)
  local has = #items > 0
  self.title:SetShown(has); self.sub:SetShown(has); self.list:SetShown(has); self.empty:SetShown(not has)
  if not has then
    self.empty:SetText("No level-ups recorded yet.\n\nFrom your next level, Foxden notes how long each level took and what you gained, and shows a level-up card with what's new at your trainer.")
    return
  end
  local _, class = UnitClass("player")
  self.title:SetText(UnitName("player") .. ", level " .. UnitLevel("player")); self.title:SetTextColor(UI.ClassColor(class))
  local timed = 0
  for _, x in ipairs(items) do if x.seconds then timed = timed + 1 end end
  self.sub:SetText(string.format("%d level-ups recorded   ·   %s played across them%s", #items, dur(total),
    best and ("   ·   fastest: level " .. best.level .. " in " .. dur(best.seconds)) or ""))
  self.list:SetItems(items)
end

ns.RegisterPage(page)
