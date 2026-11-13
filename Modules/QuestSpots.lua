-- Module: QuestSpots. Where quests start and end, learned while you play: when you
-- accept or turn in a quest, Foxden notes the NPC and where you're standing (outdoors
-- only; the game hides positions inside dungeons). Shared with the guild through the
-- website, so dungeon quests that no database knows yet gain map pins.
--
-- FoxdenDB.questSpots[questID] = { s = { n = npc, m = mapID, x, y }, e = { ... } }   (x, y in 0-100)

local _, ns = ...
local db

local function here()
  if IsInInstance and IsInInstance() then return nil end
  local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
  if not okM or type(map) ~= "number" or ns.IsSecret(map) then return nil end
  local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
  if not okP or not pos then return nil end
  local x, y = pos:GetXY()
  if type(x) ~= "number" or ns.IsSecret(x) or x <= 0 then return nil end
  return map, math.floor(x * 10000 + 0.5) / 100, math.floor(y * 10000 + 0.5) / 100
end

local function npcName()
  for _, unit in ipairs({ "npc", "questnpc" }) do
    if UnitExists and UnitExists(unit) then
      local n = UnitName(unit)
      if type(n) == "string" and not ns.IsSecret(n) then return n end
    end
  end
end

local function note(questID, kind)
  if type(questID) ~= "number" or ns.IsSecret(questID) or not db then return end
  local map, x, y = here()
  if not map then return end
  db.questSpots = db.questSpots or {}
  local q = db.questSpots[questID] or {}
  q[kind] = { n = npcName() or "", m = map, x = x, y = y }
  db.questSpots[questID] = q
  ns.Changed()
end

ns.RegisterModule({
  name = "QuestSpots",
  OnLoad = function(_, saved) db = saved end,
  events = {
    QUEST_ACCEPTED = function(_, _, a, b) note(type(b) == "number" and b or a, "s") end, -- (questID) or (index, questID) on older clients
    QUEST_TURNED_IN = function(_, _, questID) note(questID, "e") end,
  },
})
