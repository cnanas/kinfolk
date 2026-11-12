-- Module: Inventory. Counts what this character carries, so the website can
-- show which materials you already have. Bags are counted whenever they
-- change; the bank only while it's open (the game hides it otherwise), so the
-- last bank count is kept.
--
-- crafting.chars[me].bags = { [itemID] = count }, .bank = {...}, .bagsAt, .bankAt
-- Stays private: only your own companion uploads it, and it never goes over guild chat.

local _, ns = ...
local bagTimer, bankOpen

local function count(bagIDs)
  local out = {}
  for _, bag in ipairs(bagIDs) do
    local okN, slots = pcall(C_Container.GetContainerNumSlots, bag)
    for slot = 1, (okN and slots or 0) do
      local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
      if ok and info and info.itemID and not ns.IsSecret(info.itemID) then
        out[info.itemID] = (out[info.itemID] or 0) + (info.stackCount or 1)
      end
    end
  end
  return out
end

local function bagIDs()
  local ids = {}
  local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 -- includes the reagent bag where it exists
  for bag = 0, last do ids[#ids + 1] = bag end
  return ids
end

-- Classic-style bank (-1 plus bank bags) and modern bank tabs, whichever this client has.
-- Account-wide (warband) tabs are skipped: they aren't this character's.
local function bankIDs()
  local ids, seen = {}, {}
  local function add(id) if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
  add(BANK_CONTAINER or -1)
  local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) + 1
  for bag = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do add(bag) end
  if Enum and Enum.BagIndex then
    for key, id in pairs(Enum.BagIndex) do
      if type(key) == "string" and key:find("Bank") and not key:find("Account") then add(id) end
    end
  end
  return ids
end

local function scanBags()
  bagTimer = nil
  local me = ns.MyCrafting()
  if not me then return end
  me.bags, me.bagsAt = count(bagIDs()), GetServerTime()
end

local function scanBank()
  if not bankOpen then return end
  local me = ns.MyCrafting()
  if not me then return end
  me.bank, me.bankAt = count(bankIDs()), GetServerTime()
end

ns.RegisterModule({
  name = "Inventory",
  events = {
    PLAYER_ENTERING_WORLD = function() C_Timer.After(3, scanBags) end,
    BAG_UPDATE_DELAYED = function()
      if not bagTimer then bagTimer = C_Timer.NewTimer(1, scanBags) end
      if bankOpen then scanBank() end
    end,
    BANKFRAME_OPENED = function() bankOpen = true; C_Timer.After(0.5, scanBank) end,
    BANKFRAME_CLOSED = function() scanBank(); bankOpen = nil end,
    PLAYERBANKSLOTS_CHANGED = function() scanBank() end,
  },
})

table.insert(ns.statusLines, function()
  local me = ns.MyCrafting()
  if not me then return end
  local n = 0
  for _ in pairs(me.bags or {}) do n = n + 1 end
  return string.format("Inventory: %d kinds of items in bags; bank %s.", n,
    me.bankAt and ("counted " .. date("%b %d", me.bankAt)) or "not counted yet (open your bank once)")
end)
