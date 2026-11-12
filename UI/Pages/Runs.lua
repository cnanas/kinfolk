-- Page: Runs. Every run (the one in progress pinned on top), and the selected
-- run's detail with its tabs (Overview, Fights, Map; see Views/).

local _, ns = ...
local UI = ns.UI
local C = UI.C
local LIST_W, PAD, VIEW_TOP = 260, 16, 84

local page = { key = "runs", label = "Runs", section = "log", order = 20 }
local selectedId, viewKey

local function entries()
  local list = {}
  local live = ns.GetCurrentRun()
  if live then list[1] = { run = live, live = true, id = "live" } end
  local runs = ns.GetRuns()
  for i = #runs, 1, -1 do list[#list + 1] = { run = runs[i], id = runs[i].id } end
  return list
end

function page:Build(f)
  self.list = UI.List(f, 50, function(r)
    r.name = UI.Text(r, 13); r.name:SetPoint("TOPLEFT", 14, -9); r.name:SetPoint("RIGHT", r, "RIGHT", -70, 0)
    r.sub = UI.Text(r, 11, C.dim); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -5)
    r.time = UI.Text(r, 13, C.text, "RIGHT"); r.time:SetPoint("TOPRIGHT", -14, -9)
    r.meta = UI.Text(r, 11, C.dim, "RIGHT"); r.meta:SetPoint("TOPRIGHT", r.time, "BOTTOMRIGHT", 0, -5)
    r:SetScript("OnClick", function(row) selectedId = row.id; ns.RefreshUI() end)
  end, function(r, e)
    local run = e.run
    r.id = e.id
    r.name:SetText(run.dungeon or "Unknown")
    if e.live then r.sub:SetText("In progress"); r.sub:SetTextColor(UI.Accent())
    else r.sub:SetTextColor(unpack(C.dim)); r.sub:SetText((run.difficulty and run.difficulty ~= "" and (run.difficulty .. ", ") or "") .. (run.endTime and date("%b %d, %H:%M", run.endTime) or "")) end
    r.time:SetText(UI.Time(ns.RunDuration(e)))
    local b, w = run.bosses and #run.bosses or 0, run.wipes or 0
    r.meta:SetText(b .. (b == 1 and " boss" or " bosses") .. (w > 0 and (", " .. w .. (w == 1 and " wipe" or " wipes")) or ""))
    self.list:Select(r, e.id == selectedId)
  end)
  self.list:SetPoint("TOPLEFT"); self.list:SetPoint("BOTTOMLEFT"); self.list:SetWidth(LIST_W)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })
  local divider = f:CreateTexture(nil, "BORDER")
  divider:SetColorTexture(unpack(C.line)); divider:SetPoint("TOPLEFT", self.list, "TOPRIGHT"); divider:SetPoint("BOTTOMLEFT", self.list, "BOTTOMRIGHT"); divider:SetWidth(1)

  local d = CreateFrame("Frame", nil, f)
  d:SetPoint("TOPLEFT", self.list, "TOPRIGHT", PAD + 1, -PAD)
  d:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  self.detail = d
  d.title = UI.Text(d, 20); d.title:SetPoint("TOPLEFT"); d.title:SetPoint("RIGHT", d, "RIGHT", -90, 0)
  d.sub = UI.Text(d, 11, C.dim); d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -6); d.sub:SetPoint("RIGHT", d, "RIGHT", -90, 0)
  d.delete = UI.Button(d, "Delete", 70, 24, function()
    if selectedId and selectedId ~= "live" then StaticPopup_Show("KINFOLK_DELETE", nil, nil, selectedId) end
  end, "danger")
  d.delete:SetPoint("TOPRIGHT")
  d.viewTabs = {}
  local x = 0
  for _, view in ipairs(ns.views) do
    local b = CreateFrame("Button", nil, d)
    b.key = view.key
    b.bg = UI.Fill(b, C.raised); b.bg:Hide()
    b.text = UI.Text(b, 12, C.dim, "CENTER"); b.text:SetPoint("CENTER"); b.text:SetText(view.label)
    b:SetSize(math.floor(b.text:GetStringWidth() + 0.5) + 28, 26)
    b:SetPoint("TOPLEFT", x, -46)
    x = x + b:GetWidth()
    b.under = b:CreateTexture(nil, "ARTWORK"); b.under:SetPoint("BOTTOMLEFT"); b.under:SetPoint("BOTTOMRIGHT"); b.under:SetHeight(2)
    b:SetScript("OnClick", function() viewKey = view.key; ns.RefreshUI() end)
    d.viewTabs[#d.viewTabs + 1] = b
  end
  d.strip = d:CreateTexture(nil, "BORDER"); d.strip:SetColorTexture(unpack(C.line)); d.strip:SetPoint("TOPLEFT", 0, -72); d.strip:SetPoint("TOPRIGHT", 0, -72); d.strip:SetHeight(1)
  d.panes = {}
  for _, view in ipairs(ns.views) do
    local pane = CreateFrame("Frame", nil, d)
    pane:SetPoint("TOPLEFT", 0, -VIEW_TOP); pane:SetPoint("BOTTOMRIGHT")
    local ok, err = pcall(view.Build, view, pane, 500, 380)
    if not ok then geterrorhandler()("Kinfolk view " .. view.key .. ": " .. tostring(err)) end
    d.panes[view.key] = pane
  end
  viewKey = viewKey or (ns.views[1] and ns.views[1].key)
  d.empty = UI.Text(d, 13, C.dim, "CENTER"); d.empty:SetPoint("CENTER", 0, 20); d.empty:SetWordWrap(true)
  d.empty:SetText("No runs yet.\n\nStep into a dungeon and the log starts on its own.")
end

function page:Layout(w, h)
  local dw, dh = w - LIST_W - PAD * 2 - 1, h - PAD * 2
  self.detail.empty:SetWidth(dw - 40)
  for _, view in ipairs(ns.views) do
    if view.Layout then
      local ok, err = pcall(view.Layout, view, dw, dh - VIEW_TOP)
      if not ok then geterrorhandler()("Kinfolk view " .. view.key .. ": " .. tostring(err)) end
    end
  end
end

function page:Refresh(arg)
  if arg then selectedId = arg end
  local list = entries()
  local sel
  for _, e in ipairs(list) do if e.id == selectedId then sel = e end end
  if not sel then sel = list[1]; selectedId = sel and sel.id end
  self.list:SetItems(list)

  local d = self.detail
  local has = sel ~= nil
  d.title:SetShown(has); d.sub:SetShown(has); d.strip:SetShown(has); d.delete:SetShown(has and not sel.live)
  for _, b in ipairs(d.viewTabs) do b:SetShown(has) end
  d.empty:SetShown(not has)
  for key, pane in pairs(d.panes) do pane:SetShown(has and key == viewKey) end
  if not has then return end

  local run = sel.run
  d.title:SetText(run.dungeon or "Unknown")
  local bits = {}
  if run.difficulty and run.difficulty ~= "" then bits[#bits + 1] = run.difficulty end
  if sel.live then bits[#bits + 1] = "In progress" elseif run.endTime then bits[#bits + 1] = date("%A, %b %d at %H:%M", run.endTime) end
  if run.loggedBy then bits[#bits + 1] = "Logged by " .. run.loggedBy end
  if run.endReason == "abandoned" then bits[#bits + 1] = "Closed when you logged back in" end
  d.sub:SetText(table.concat(bits, ", "))
  local r, g, b = UI.Accent()
  for _, t in ipairs(d.viewTabs) do
    local on = t.key == viewKey
    t.bg:SetShown(on); t.under:SetShown(on); t.under:SetColorTexture(r, g, b, 1)
    t.text:SetTextColor(unpack(on and C.text or C.dim))
  end
  for _, view in ipairs(ns.views) do
    if view.key == viewKey then
      local ok, err = pcall(view.Refresh, view, sel)
      if not ok then geterrorhandler()("Kinfolk view " .. view.key .. ": " .. tostring(err)) end
    end
  end
end

ns.RegisterPage(page)
