-- Page: Requests. Open craft requests for your characters, from the website.
-- Accepting and updating happens on your private orders page (link below);
-- the game can't open web pages, so copy it into your browser.

local _, ns = ...
local UI = ns.UI
local C = UI.C
local PAD = 16
local STATUS = { requested = "Requested", accepted = "Waiting for materials", crafted = "Crafted", mailed = "Delivered" }

local page = { key = "orders", label = "Requests", order = 80 }

function page:Build(f)
  self.intro = UI.Text(f, 12, C.dim); self.intro:SetWordWrap(true)
  self.list = UI.List(f, 46, function(r)
    r.name = UI.Text(r, 13); r.name:SetPoint("TOPLEFT", 14, -8)
    r.sub = UI.Text(r, 11, C.dim); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
    r.status = UI.Text(r, 12, C.text, "RIGHT"); r.status:SetPoint("TOPRIGHT", -14, -8)
  end, function(r, o)
    if o.board then
      r.name:SetText(o[3] .. "x " .. o[2] .. "  |cff999fb0crafting board|r")
      r.sub:SetText("For " .. (o.who or "?") .. (o.note and o.note ~= "" and (": " .. o.note) or "") .. ". Free: they bring the materials.")
      r.status:SetText(o.status == "claimed" and ("Being made by " .. (o.by or "?")) or o.status == "sending" and "Goes out on your next sync" or "Open: take it on the website")
      if o.status == "open" then r.status:SetTextColor(UI.Accent()) else r.status:SetTextColor(unpack(C.dim)) end
      return
    end
    if o.mine then
      r.name:SetText(o[3] .. "x " .. o[2])
      r.sub:SetText("Your request, " .. date("%b %d, %H:%M", o.at))
      r.status:SetText(o.sent and "Sent to the guild website" or "Goes out on your next sync")
      r.status:SetTextColor(unpack(C.dim))
      return
    end
    r.name:SetText(o[3] .. "x " .. o[2] .. "  |cff999fb0#" .. o[1] .. "|r")
    r.sub:SetText("For " .. o[4] .. ", who brings the materials" .. (o[8] ~= "" and (", taken by " .. o[8]) or ", open to any crafter"))
    r.status:SetText(STATUS[o[5]] or o[5])
    if o[5] == "requested" then r.status:SetTextColor(UI.Accent()) else r.status:SetTextColor(unpack(C.text)) end
  end)
  UI.Fill(self.list, { 0, 0, 0, 0.12 })
  self.foot = UI.Text(f, 11, C.dim); self.foot:SetWordWrap(true)
  self.link = UI.CopyBox(f, 300)
  self.empty = UI.EmptyNote(f)
end

function page:Layout(w, h)
  local inner = w - PAD * 2
  self.intro:ClearAllPoints(); self.intro:SetPoint("TOPLEFT", PAD, -PAD); self.intro:SetWidth(inner)
  self.list:ClearAllPoints(); self.list:SetPoint("TOPLEFT", PAD, -PAD - 44); self.list:SetSize(inner, h - PAD * 2 - 44 - 66)
  self.foot:ClearAllPoints(); self.foot:SetPoint("BOTTOMLEFT", PAD, PAD + 32); self.foot:SetWidth(inner)
  self.link:ClearAllPoints(); self.link:SetPoint("BOTTOMLEFT", PAD, PAD); self.link:SetWidth(inner)
  self.empty:ClearAllPoints(); self.empty:SetPoint("CENTER"); self.empty:SetWidth(inner - 60)
end

function page:Refresh()
  local site = ns.Site()
  local has = site ~= nil
  for _, el in ipairs({ self.intro, self.list, self.foot, self.link }) do el:SetShown(has) end
  self.empty:SetShown(not has)
  if not has then self.empty:SetText(ns.NO_SITE); return end
  local orders = {}
  for _, o in ipairs(site.orders or {}) do orders[#orders + 1] = o end
  local nTheirs = #orders
  -- then the requests you made in game (Recipes > Request), newest first
  local mine = ns.db and ns.db.craftRequests or {}
  for i = #mine, 1, -1 do
    local q = mine[i]
    orders[#orders + 1] = { "", q.name, q.qty or 1, "", "", 0, "", "", "", mine = true, at = q.at, sent = (site.at or 0) > (q.at or 0) }
  end
  -- the guild's crafting board (from the website), and asks you made in game
  for _, b in ipairs(type(site.board) == "table" and site.board or {}) do
    orders[#orders + 1] = { "", b[2], b[3], "", "", 0, "", "", "", board = true, who = b[4], status = b[5], by = b[6], note = b[7] }
  end
  for i = #(ns.db and ns.db.boardAsks or {}), 1, -1 do
    local q = ns.db.boardAsks[i]
    if (site.at or 0) <= (q.at or 0) then orders[#orders + 1] = { "", q.item, q.qty or 1, "", "", 0, "", "", "", board = true, who = UnitName("player"), status = "sending" } end
  end
  if nTheirs > 0 then
    self.intro:SetText(nTheirs .. (nTheirs == 1 and " open request" or " open requests") .. " for your characters, as of " .. date("%b %d, %H:%M", site.at) .. ". Free crafting: the requester mails you the materials.")
  elseif #mine > 0 then
    self.intro:SetText("Your own requests are listed below. Requests guildmates make for your crafts show up here too, after a sync.")
  else
    self.intro:SetText("No open requests. Ask for a craft on the Recipes tab; requests guildmates make for your crafts show up here after a sync.")
  end
  self.list:SetItems(orders)
  local me = ns.CharKey and ns.CharKey()
  local links = site.links or {}
  local mine = links[me] or select(2, next(links))
  if mine and mine.orders then
    self.foot:SetText("Accept, decline and update requests on your private requests page. Copy this link into your browser (don't share it):")
    self.link:SetLink(mine.orders)
  else
    self.foot:SetText("Your private requests link appears after the companion uploads your professions.")
    self.link:SetLink((site.site or "") .. "/craft")
  end
end

ns.RegisterPage(page)
