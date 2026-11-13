-- Module: Bosses. Boss kills (with time into the run) and wipes.
-- run.bosses = { { id, name, killedAt }, ... }   run.wipes = n
-- Also leaves run._encounterLog for the Meter module to label fights.
-- When a fight starts, Foxden notes the boss's look (creature display ID) so the
-- dungeon tracker can show its portrait next time: FoxdenDB.bossLooks[encounterID] = displayID.

local _, ns = ...
local model

-- the display ID of boss1, read through a hidden model (nil if the game hides it)
local function bossLook()
  if not UnitExists or not UnitExists("boss1") then return nil end
  model = model or CreateFrame("PlayerModel", nil, UIParent)
  model:Hide()
  local ok = pcall(model.SetUnit, model, "boss1")
  if not ok or not model.GetDisplayInfo then return nil end
  local ok2, id = pcall(model.GetDisplayInfo, model)
  if ok2 and type(id) == "number" and not ns.IsSecret(id) and id > 0 then return id end
end

ns.RegisterModule({
  name = "Bosses",
  OnRunStart = function(_, run)
    run.bosses, run.wipes = {}, 0
  end,
  events = {
    ENCOUNTER_START = function(_, run, encounterID)
      if not run or ns.IsSecret(encounterID) then return end
      local function look()
        local id = bossLook()
        if id then
          run._looks = run._looks or {}
          run._looks[encounterID] = id
          ns.db.bossLooks = ns.db.bossLooks or {}
          ns.db.bossLooks[encounterID] = id
          if ns.RefreshTracker then ns.RefreshTracker() end
        end
        return id
      end
      if not look() then C_Timer.After(1, look) end
    end,
    ENCOUNTER_END = function(_, run, encounterID, encounterName, _, _, success)
      if not run or ns.IsSecret(encounterID) then return end
      local kill = success == 1
      if kill then
        local look = (run._looks and run._looks[encounterID]) or (ns.db.bossLooks and ns.db.bossLooks[encounterID])
        run.bosses[#run.bosses + 1] = { id = encounterID, name = encounterName, killedAt = GetServerTime() - run.startTime, look = look, npc = ns.db.bossNpc and ns.db.bossNpc[encounterID] }
      else
        run.wipes = (run.wipes or 0) + 1
      end
      run._encounterLog = run._encounterLog or {}
      table.insert(run._encounterLog, { id = encounterID, name = encounterName, kill = kill })
      ns.Changed()
    end,
  },
})

table.insert(ns.statusLines, function(run)
  if run then return string.format("%d bosses down, %d wipes.", #(run.bosses or {}), run.wipes or 0) end
end)
