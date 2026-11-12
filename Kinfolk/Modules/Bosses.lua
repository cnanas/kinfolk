-- Module: Bosses. Boss kills (with time into the run) and wipes.
-- run.bosses = { { id, name, killedAt }, ... }   run.wipes = n
-- Also leaves run._encounterLog for the Meter module to label fights.

local _, ns = ...

ns.RegisterModule({
  name = "Bosses",
  OnRunStart = function(_, run)
    run.bosses, run.wipes = {}, 0
  end,
  events = {
    ENCOUNTER_END = function(_, run, encounterID, encounterName, _, _, success)
      if not run or ns.IsSecret(encounterID) then return end
      local kill = success == 1
      if kill then
        run.bosses[#run.bosses + 1] = { id = encounterID, name = encounterName, killedAt = GetServerTime() - run.startTime }
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
