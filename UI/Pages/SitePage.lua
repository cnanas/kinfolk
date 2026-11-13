-- Shared bits for pages that show the companion's snapshot of the website.
local _, ns = ...
local UI = ns.UI
local C = UI.C

ns.NO_SITE = "This needs your guild's website.\n\nStart the companion app and click Sync. Everything else in Foxden works without it."

function UI.EmptyNote(parent)
  local t = UI.Text(parent, 13, C.dim, "CENTER")
  t:SetWordWrap(true)
  return t
end
