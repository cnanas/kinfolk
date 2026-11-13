-- Module: Loot. What each boss dropped, so the guild's journal can list boss loot
-- (Forever's in-game journal is empty). When a boss fight starts Foxden notes the
-- boss's NPC ID; anything green or better looted from that boss's corpse is recorded.
--
-- run.loot = { { e = encounterID, b = bossName, i = itemID, q = quality }, ... }

local _, ns = ...

local function npcID(guid)
  if type(guid) ~= "string" or ns.IsSecret(guid) then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

local function call(fn, ...) if type(fn) ~= "function" then return end return select(2, pcall(fn, ...)) end
-- loot sources come as pairs: guid, count, guid, count, ...
local function sources(slot)
  if type(GetLootSourceInfo) ~= "function" then return {} end
  local r = { pcall(GetLootSourceInfo, slot) }
  if not r[1] then return {} end
  local out = {}
  for k = 2, select("#", unpack(r)), 2 do out[#out + 1] = r[k] end
  return out
end

local function noteBoss(run, encounterID, name)
  for i = 1, 5 do
    local unit = "boss" .. i
    if UnitExists and UnitExists(unit) then
      local id = UnitGUID and npcID(UnitGUID(unit))
      if id then
        run._bossNpc = run._bossNpc or {}
        run._bossNpc[id] = { e = encounterID, b = name }
        if i == 1 and ns.db then -- remembered so the Journal can show this boss's model
          ns.db.bossNpc = ns.db.bossNpc or {}
          ns.db.bossNpc[encounterID] = id
        end
      end
    end
  end
end

local function onLoot(run)
  if not run or not run._bossNpc then return end
  run.loot = run.loot or {}
  run._lootSeen = run._lootSeen or {}
  for slot = 1, (call(GetNumLootItems) or 0) do
    local link = call(GetLootSlotLink, slot)
    local itemID = type(link) == "string" and not ns.IsSecret(link) and tonumber(link:match("item:(%d+)"))
    local okI, _, _, _, _, quality = false
    if type(GetLootSlotInfo) == "function" then okI, _, _, _, _, quality = pcall(GetLootSlotInfo, slot) end
    if not okI or ns.IsSecret(quality) then quality = nil end
    if itemID and ns.WishKind and ns.WishKind(itemID) and not (run._wishSaid and run._wishSaid[itemID]) then
      run._wishSaid = run._wishSaid or {}; run._wishSaid[itemID] = true
      ns.say("It dropped! " .. link .. " is on your wishlist (" .. ns.WISH_LABEL[ns.WishKind(itemID)]:lower() .. ").")
      if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
    end
    if itemID and (type(quality) ~= "number" or quality >= 2) then
      for _, guid in ipairs(sources(slot)) do
        local id = npcID(guid)
        local boss = id and run._bossNpc[id]
        local seenKey = tostring(guid) .. ":" .. itemID
        if boss and not run._lootSeen[seenKey] then
          run._lootSeen[seenKey] = true
          run.loot[#run.loot + 1] = { e = boss.e, b = boss.b, i = itemID, q = type(quality) == "number" and quality or nil }
          ns.Changed()
        end
      end
    end
  end
end

ns.RegisterModule({
  name = "Loot",
  events = {
    ENCOUNTER_START = function(_, run, encounterID, name)
      if not run or ns.IsSecret(encounterID) then return end
      noteBoss(run, encounterID, name)
      C_Timer.After(1, function() if ns.GetCurrentRun() == run then noteBoss(run, encounterID, name) end end)
    end,
    LOOT_OPENED = function(_, run) onLoot(run) end,
    -- once a wished item is in your bags, it comes off the list
    BAG_UPDATE_DELAYED = function()
      if not (ns.Wishlist and C_Item and C_Item.GetItemCount) then return end
      for _, w in ipairs(ns.Wishlist()) do
        local ok, n = pcall(C_Item.GetItemCount, w.i, true)
        if ok and type(n) == "number" and n > 0 then
          ns.say("You got " .. (w.n or "your wishlist item") .. "! It's off your wishlist.")
          ns.SetWish(w.i, nil)
          if ns.RefreshUI then ns.RefreshUI() end
          return
        end
      end
    end,
  },
})
