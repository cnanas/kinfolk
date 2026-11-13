-- Page: Notes. Everything you've jotted down with the pop-out note window (/fox note):
-- read it, open it to edit, pin its location on the map, share it, delete it.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local LIST_W, PAD = 280, 16

local page = { key = "notes", label = "Notes", order = 17 }
local selected

local function pinOnMap(l)
  if not (l and l.map and l.x and C_Map and C_Map.SetUserWaypoint and UiMapPoint) then return end
  if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(l.map) then ns.say("The game doesn't allow a map pin there.", true); return end
  local ok = pcall(function()
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(l.map, l.x / 100, l.y / 100))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
  end)
  if ok then ns.say("Map pin set: " .. (l.zone or "") .. ".") end
end

function page:Build(f)
  self.new = UI.Button(f, "New note", 100, 26, function() local n = ns.NewNote(); selected = n.id; ns.OpenNote(n); self:Refresh() end, "primary")
  self.list = UI.List(f, 50, function(r)
    r.name = UI.Text(r, 13); r.name:SetPoint("TOPLEFT", 14, -8); r.name:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    r.sub = UI.Text(r, 11, C.dim); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -5); r.sub:SetPoint("RIGHT", r, "RIGHT", -10, 0)
    r:SetScript("OnClick", function(row) selected = row.nid; self:Refresh() end)
  end, function(r, n)
    r.nid = n.id
    r.name:SetText(ns.NoteTitle(n))
    local bits = { date("%b %d, %H:%M", n.at) }
    if n.loc then bits[#bits + 1] = n.loc.zone end
    local shots = n.shots and #n.shots or 0
    if shots > 0 then bits[#bits + 1] = shots .. (shots == 1 and " screenshot" or " screenshots") end
    r.sub:SetText(table.concat(bits, "  ·  "))
    self.list:Select(r, n.id == selected)
  end)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })

  self.title = UI.Text(f, 18); self.title:SetWordWrap(true)
  self.meta = UI.Text(f, 11, C.dim); self.meta:SetWordWrap(true)
  self.scroll = CreateFrame("ScrollFrame", nil, f)
  self.scroll:EnableMouseWheel(true)
  self.body = CreateFrame("Frame", nil, self.scroll)
  self.scroll:SetScrollChild(self.body)
  self.text = UI.Text(self.body, 13, C.text); self.text:SetPoint("TOPLEFT"); self.text:SetWordWrap(true); self.text:SetJustifyV("TOP")
  self.scroll:SetScript("OnMouseWheel", function(s, d)
    local max = math.max(0, (self.body:GetHeight() or 0) - (s:GetHeight() or 0))
    s:SetVerticalScroll(math.max(0, math.min(max, (s:GetVerticalScroll() or 0) - d * 40)))
  end)
  local function note() for _, n in ipairs(ns.Notes()) do if n.id == selected then return n end end end
  self.buttons = {
    UI.Button(f, "Edit", 70, 26, function() local n = note(); if n then ns.OpenNote(n) end end, "primary"),
    UI.Button(f, "Pin on map", 100, 26, function() local n = note(); if n then pinOnMap(n.loc) end end),
    UI.Button(f, "Share as guild pin", 140, 26, function()
      local n = note(); if not n then return end
      local on = ns.TogglePin(n)
      if on == nil then ns.say("Add a location to this note first (outdoors), then it can be a map pin.", true)
      else ns.say(on and "Shared as a guild map pin. Guildmates see it on their world map after your next sync." or "Guild map pin removed.") end
      self:Refresh()
    end),
    UI.Button(f, "Share in guild chat", 150, 26, function() local n = note(); if n then ns.NoteToGuild(n); self:Refresh() end end),
    UI.Button(f, "Send to Discord", 130, 26, function() local n = note(); if n then ns.NoteToDiscord(n); self:Refresh() end end),
    UI.Button(f, "Delete", 70, 26, function() local n = note(); if n then ns.DeleteNote(n); selected = nil; self:Refresh() end end, "danger"),
  }
  self.empty = UI.Text(f, 13, C.dim, "CENTER"); self.empty:SetWordWrap(true)
  self.empty:SetText("No notes yet.\n\nClick New note (or type /fox note) for a small note window you can keep open while you play: write, add where you are, take a screenshot, then share it in guild chat or Discord.")
end

function page:Layout(w, h)
  local x, dw = LIST_W + PAD * 2, w - LIST_W - PAD * 3
  self.new:ClearAllPoints(); self.new:SetPoint("TOPLEFT", PAD, -PAD)
  self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", PAD, -PAD - 36); self.list:SetSize(LIST_W, h - PAD * 2 - 36)
  self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", x, -PAD); self.title:SetWidth(dw)
  self.meta:ClearAllPoints(); self.meta:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -6); self.meta:SetWidth(dw)
  self.bx = x
  local bx = x
  for _, b in ipairs(self.buttons) do b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", bx, PAD); bx = bx + b:GetWidth() + 6 end
  self.scroll:ClearAllPoints(); self.scroll:SetPoint("TOPLEFT", x, -PAD - 70); self.scroll:SetSize(dw, h - PAD * 2 - 70 - 40)
  self.body:SetWidth(dw - 8); self.text:SetWidth(dw - 8)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER", (LIST_W + PAD) / 2, 0); self.empty:SetWidth(dw - 40)
end

function page:Refresh()
  local all, list = ns.Notes(), {}
  for i = #all, 1, -1 do list[#list + 1] = all[i] end
  local n
  for _, x in ipairs(list) do if x.id == selected then n = x end end
  if not n then n = list[1]; selected = n and n.id end
  self.list:SetItems(list)
  local has = n ~= nil
  for _, el in ipairs({ self.title, self.meta, self.scroll }) do el:SetShown(has) end
  for _, b in ipairs(self.buttons) do b:SetShown(has) end
  self.empty:SetShown(not has)
  if not has then return end
  self.title:SetText(ns.NoteTitle(n))
  local bits = { date("%b %d, %H:%M", n.at) }
  local where = ns.NoteWhere(n)
  if where then bits[#bits + 1] = where end
  local shots = n.shots and #n.shots or 0
  if shots > 0 then bits[#bits + 1] = shots .. (shots == 1 and " screenshot (in your Screenshots folder)" or " screenshots (in your Screenshots folder)") end
  if ns.IsPinned(n) then bits[#bits + 1] = "shared as a guild map pin" end
  if n.guildAt then bits[#bits + 1] = "shared in guild chat" end
  if n.discord == "queued" then bits[#bits + 1] = "queued for Discord: posts on your next sync" end
  self.meta:SetText(table.concat(bits, "  ·  "))
  self.text:SetText((n.text or "") ~= "" and n.text or "|cff999fb0(no text)|r")
  self.body:SetHeight((self.text:GetStringHeight() or 20) + 10)
  local hasSpot = n.loc ~= nil and n.loc.map ~= nil
  self.buttons[2]:SetShown(hasSpot)
  self.buttons[3]:SetShown(hasSpot)
  self.buttons[3].label:SetText(ns.IsPinned(n) and "Remove guild pin" or "Share as guild pin")
  local bx = self.bx or 0
  for _, b in ipairs(self.buttons) do if b:IsShown() then b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", bx, PAD); bx = bx + b:GetWidth() + 6 end end
end

ns.RegisterPage(page)
