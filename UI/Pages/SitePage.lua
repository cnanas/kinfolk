-- Shared bits for pages that show the companion's snapshot of the website.
local _, ns = ...
local UI = ns.UI
local C = UI.C

ns.NO_SITE = "This page needs a guild website.\n\nEverything else in Foxden works without one. Guild websites (shop, crafting costs, orders and a shared journal) are coming soon as a service. If your guild already has one, start its companion app and click Sync."

function UI.EmptyNote(parent)
  local t = UI.Text(parent, 13, C.dim, "CENTER")
  t:SetWordWrap(true)
  return t
end
