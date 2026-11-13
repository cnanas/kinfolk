-- Foxden: notes. A small pop-out window to jot things down while you quest or level:
-- text, where you are, and screenshots. Share a note in guild chat, or queue it for
-- Discord (the companion posts it with its screenshots on your next sync).
-- /fox note opens it; the Notes tab in the window lists them all.
--
-- FoxdenDB.notes = { { id, at, char, text, loc = { zone, map, x, y }, shots = { localTime, ... },
--                      discord = "queued", guildAt = serverTime }, ... }

local _, ns = ...
local UI = ns.UI
local C = UI.C
local W, H = 360, 330
local pop, current

local function notes()
  ns.db.notes = ns.db.notes or {}
  return ns.db.notes
end

function ns.Notes() return ns.db and notes() or {} end

function ns.NewNote()
  local list = notes()
  local n = { id = GetServerTime() .. "-" .. math.random(1000, 9999), at = GetServerTime(), char = ns.CharKey(), text = "" }
  list[#list + 1] = n
  while #list > 300 do table.remove(list, 1) end
  ns.Changed()
  return n
end

function ns.DeleteNote(note)
  local list = notes()
  for i = #list, 1, -1 do if list[i] == note then table.remove(list, i) end end
  if current == note then current = nil; if pop then pop:Hide() end end
  ns.Changed()
end

function ns.NoteTitle(note)
  local first = (note.text or ""):match("^%s*([^\n]+)") or ""
  if first == "" then return note.loc and note.loc.zone or "Empty note" end
  return #first > 60 and (first:sub(1, 57) .. "...") or first
end

function ns.NoteWhere(note)
  local l = note.loc
  if not l then return nil end
  return (l.zone or "?") .. (l.x and string.format(" (%d, %d)", math.floor(l.x + 0.5), math.floor(l.y + 0.5)) or "")
end

-- Where you are now: zone, and the map position when the game gives one (not inside dungeons).
local function here()
  local zone = GetRealZoneText and GetRealZoneText() or (GetZoneText and GetZoneText()) or "?"
  local sub = GetSubZoneText and GetSubZoneText() or ""
  local loc = { zone = (sub ~= "" and sub ~= zone) and (sub .. ", " .. zone) or zone }
  local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
  if okM and type(map) == "number" and not ns.IsSecret(map) then
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
    if okP and pos then
      local x, y = pos:GetXY()
      if type(x) == "number" and not ns.IsSecret(x) and x > 0 then
        loc.map, loc.x, loc.y = map, math.floor(x * 10000 + 0.5) / 100, math.floor(y * 10000 + 0.5) / 100
      end
    end
  end
  return loc
end

function ns.NoteAddLocation(note)
  note.loc = here()
  ns.Changed()
  return note.loc
end

-- Take a screenshot without Foxden's own windows in it, and remember when, so the
-- companion can find the file to attach.
function ns.NoteScreenshot(note, after)
  if not Screenshot then return end
  local wasPop = pop and pop:IsShown()
  local win = _G.FoxdenFrame
  local wasWin = win and win:IsShown()
  if wasPop then pop:Hide() end
  if wasWin then win:Hide() end
  C_Timer.After(0.15, function()
    note.shots = note.shots or {}
    note.shots[#note.shots + 1] = time()
    Screenshot()
    C_Timer.After(0.7, function()
      if wasWin then win:Show() end
      if wasPop and current == note then pop:Show() end
      ns.Changed()
      if after then after() end
      if ns.RefreshNote then ns.RefreshNote() end
    end)
  end)
end

-- Guild chat allows about 255 characters a line: send the note as up to four lines.
function ns.NoteToGuild(note)
  if not (IsInGuild and IsInGuild()) then ns.say("You're not in a guild on this character.", true); return end
  local text = (note.text or ""):gsub("%s*\n%s*", "  "):gsub("^%s+", ""):gsub("%s+$", "")
  local where = ns.NoteWhere(note)
  if where then text = text .. (text ~= "" and "  " or "") .. "@ " .. where end
  if text == "" then ns.say("This note is empty.", true); return end
  local lines, max = {}, 240
  while #text > 0 and #lines < 4 do
    if #text <= max then lines[#lines + 1] = text; text = ""
    else
      local cut = text:sub(1, max):match("^.*()%s") or max
      lines[#lines + 1] = text:sub(1, cut); text = text:sub(cut + 1)
    end
  end
  if #text > 0 then lines[#lines] = lines[#lines]:sub(1, max - 3) .. "..." end
  for i, l in ipairs(lines) do SendChatMessage((i == 1 and "[Note] " or "") .. l, "GUILD") end
  note.guildAt = GetServerTime()
  ns.Changed()
  ns.say("Note shared in guild chat.")
end

function ns.NoteToDiscord(note)
  if (note.text or "") == "" and not note.loc and not (note.shots and #note.shots > 0) then ns.say("This note is empty.", true); return end
  note.discord = "queued"
  note.discordAt = GetServerTime()
  ns.Changed()
  ns.say("Queued for Discord. It posts on your next sync" .. ((note.shots and #note.shots > 0) and " with its screenshots." or "."))
end

-- ---- the pop-out window ------------------------------------------------------------

local function refresh()
  if not pop or not current then return end
  local n = current
  pop.date:SetText(date("%b %d, %H:%M", n.at))
  if pop.edit:GetText() ~= (n.text or "") then pop.edit:SetText(n.text or "") end
  local bits = {}
  local where = ns.NoteWhere(n)
  if where then bits[#bits + 1] = "|cffe6e8ee" .. where .. "|r" end
  local shots = n.shots and #n.shots or 0
  if shots > 0 then bits[#bits + 1] = shots .. (shots == 1 and " screenshot" or " screenshots") end
  if n.discord == "queued" then bits[#bits + 1] = "queued for Discord" end
  pop.meta:SetText(#bits > 0 and table.concat(bits, "  ·  ") or "Type your note. Add where you are or a screenshot below.")
  pop.loc.label:SetText(n.loc and "Update location" or "Add location")
  pop.loc:SetWidth(pop.loc.label:GetStringWidth() + 22)
end
ns.RefreshNote = refresh

local function build()
  pop = CreateFrame("Frame", "FoxdenNote", UIParent)
  pop:SetSize(W, H)
  pop:SetFrameStrata("HIGH"); pop:SetToplevel(true)
  pop:SetClampedToScreen(true)
  pop:EnableMouse(true); pop:SetMovable(true); pop:RegisterForDrag("LeftButton")
  pop:SetScript("OnDragStart", pop.StartMoving)
  pop:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.settings.notePos = { p, rp, x, y }
  end)
  local p = ns.settings.notePos
  if p then pop:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else pop:SetPoint("RIGHT", -260, 60) end
  UI.Fill(pop, C.bg); UI.Border(pop, { 1, 1, 1, 0.14 })

  local accent = pop:CreateTexture(nil, "ARTWORK"); accent:SetSize(3, 16); accent:SetPoint("TOPLEFT", 14, -13); UI.Accented(accent)
  local title = UI.Text(pop, 14); title:SetPoint("LEFT", accent, "RIGHT", 8, 0); title:SetText("Note")
  pop.date = UI.Text(pop, 11, C.faint); pop.date:SetPoint("LEFT", title, "RIGHT", 10, -1)
  local close = UI.CloseButton(pop, function() pop:Hide() end); close:SetPoint("TOPRIGHT", -6, -6)
  local all = UI.Button(pop, "All notes", 76, 22, function() ns.OpenPage("notes") end); all:SetPoint("RIGHT", close, "LEFT", -6, 0)
  local new = UI.Button(pop, "New", 48, 22, function() ns.OpenNote(ns.NewNote()) end); new:SetPoint("RIGHT", all, "LEFT", -6, 0)

  -- the text
  local box = CreateFrame("Frame", nil, pop)
  box:SetPoint("TOPLEFT", 14, -42); box:SetPoint("BOTTOMRIGHT", -14, 96)
  UI.Fill(box, C.surface); UI.Border(box)
  local scroll = CreateFrame("ScrollFrame", nil, box)
  scroll:SetPoint("TOPLEFT", 8, -8); scroll:SetPoint("BOTTOMRIGHT", -8, 8)
  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true); edit:SetAutoFocus(false)
  edit:SetFont(UI.Font(), 13, ""); edit:SetTextColor(unpack(C.text))
  edit:SetWidth(W - 28 - 16)
  if edit.SetMaxLetters then edit:SetMaxLetters(1500) end
  scroll:SetScrollChild(edit)
  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  edit:SetScript("OnTextChanged", function(self, user)
    if current and user then current.text = self:GetText(); ns.Changed() end
  end)
  edit:SetScript("OnCursorChanged", function(_, _, y, _, h)
    local top, view = scroll:GetVerticalScroll(), scroll:GetHeight()
    if -y < top then scroll:SetVerticalScroll(-y) elseif -y + h > top + view then scroll:SetVerticalScroll(-y + h - view) end
  end)
  box:EnableMouse(true); box:SetScript("OnMouseDown", function() edit:SetFocus() end)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, d)
    local max = math.max(0, (edit:GetHeight() or 0) - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 30)))
  end)
  pop.edit = edit

  pop.meta = UI.Text(pop, 11, C.dim); pop.meta:SetPoint("BOTTOMLEFT", 14, 72); pop.meta:SetWidth(W - 28); pop.meta:SetWordWrap(false)

  pop.loc = UI.Button(pop, "Add location", 110, 24, function() if current then ns.NoteAddLocation(current); refresh(); ns.RefreshUI() end end)
  pop.loc:SetPoint("BOTTOMLEFT", 14, 42)
  local shot = UI.Button(pop, "Screenshot", 96, 24, function() if current then ns.NoteScreenshot(current) end end)
  shot:SetPoint("LEFT", pop.loc, "RIGHT", 6, 0)
  local guild = UI.Button(pop, "Share in guild chat", 150, 24, function() if current then ns.NoteToGuild(current); refresh() end end)
  guild:SetPoint("BOTTOMLEFT", 14, 12)
  local discord = UI.Button(pop, "Send to Discord", 130, 24, function() if current then ns.NoteToDiscord(current); refresh() end end, "primary")
  discord:SetPoint("LEFT", guild, "RIGHT", 6, 0)
  discord:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Send to Discord")
    GameTooltip:AddLine("The game can't reach Discord itself. The note is queued, and the companion app posts it, with its screenshots, on your next sync.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  discord:HookScript("OnLeave", GameTooltip_Hide)
  pop:SetScript("OnHide", function() edit:ClearFocus(); if ns.RefreshUI then ns.RefreshUI() end end)
  pop:Hide()
end

-- Open the pop-out on a note (the one you had open, your latest, or a new one).
function ns.OpenNote(note)
  if not ns.db then return end
  if not pop then build() end
  local list = notes()
  current = note or current or list[#list] or ns.NewNote()
  local found = false
  for _, n in ipairs(list) do if n == current then found = true end end
  if not found then current = ns.NewNote() end
  refresh()
  pop:Show()
  if (current.text or "") == "" then pop.edit:SetFocus() end
end

function ns.ToggleNote()
  if pop and pop:IsShown() then pop:Hide() else ns.OpenNote() end
end
