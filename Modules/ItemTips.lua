-- Module: ItemTips. The guild website shows item stats on hover. Blizzard's website API
-- doesn't know every Forever item, so for the ones it's missing Foxden reads the game's own
-- item tooltip here (a few a second, out of combat) and the companion uploads the text.
-- The website's snapshot says which items it still needs (site.tipWant).
--
-- FoxdenDB.itemTips[itemID] = { { l = left text, r = right text, c = "rrggbb" }, ... }

local _, ns = ...
local db
local queue, pos, ticker, retried = nil, 0, nil, {}

local function clean(s)
  return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|n", " "))
end
local function hex(c)
  if type(c) ~= "table" or type(c.r) ~= "number" then return nil end
  local h = string.format("%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
  return h ~= "ffffff" and h or nil
end

local function read(id)
  if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return nil end
  local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" or #data.lines < 2 then return nil end
  local out = {}
  for _, ln in ipairs(data.lines) do
    local l = ln.leftText
    if type(l) == "string" and not ns.IsSecret(l) then
      l = clean(l)
      if l ~= "" and l ~= " " then
        local e = { l = l:sub(1, 400), c = hex(ln.leftColor) }
        local r = ln.rightText
        if type(r) == "string" and not ns.IsSecret(r) and r ~= "" then e.r = clean(r):sub(1, 80) end
        out[#out + 1] = e
      end
    end
    if #out >= 40 then break end
  end
  return #out >= 2 and out or nil
end
ns.ReadItemTip = read

local function step()
  if not queue or InCombatLockdown() then return end
  for _ = 1, 3 do
    pos = pos + 1
    local id = queue[pos]
    if not id then
      ticker:Cancel(); ticker, queue = nil, nil
      ns.Changed()
      return
    end
    if not db.itemTips[id] then
      local tip = read(id)
      if tip then db.itemTips[id] = tip
      elseif not retried[id] then
        -- the game hasn't loaded this item yet: ask for it and look again at the end
        retried[id] = true
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        queue[#queue + 1] = id
      end
    end
  end
end

local function start()
  local site = ns.Site and ns.Site()
  local want = site and type(site.tipWant) == "table" and site.tipWant or {}
  db.itemTips = db.itemTips or {}
  -- keep only what the website still asks for, so the saved file stays small
  local wanted = {}
  for _, id in ipairs(want) do wanted[id] = true end
  for id in pairs(db.itemTips) do if not wanted[id] then db.itemTips[id] = nil end end
  if #want == 0 or ticker then return end
  queue, pos, retried = {}, 0, {}
  for _, id in ipairs(want) do if not db.itemTips[id] then queue[#queue + 1] = id end end
  if #queue == 0 then queue = nil; return end
  ticker = C_Timer.NewTicker(0.25, step)
end

ns.RegisterModule({
  name = "ItemTips",
  OnLoad = function(_, saved) db = saved end,
  events = { PLAYER_LOGIN = function() C_Timer.After(30, start) end },
})
