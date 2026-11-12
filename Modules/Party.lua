-- Module: Party. Who was in the group, with class and role.
-- run.party = { { name, realm, class, role, level }, ... }

local _, ns = ...

local function snapshot()
  local members = {}
  local units = { "player", "party1", "party2", "party3", "party4" }
  for _, unit in ipairs(units) do
    if UnitExists(unit) then
      local name, realm = UnitName(unit)
      local _, classFile = UnitClass(unit)
      members[#members + 1] = {
        name = name, realm = realm, class = classFile, level = UnitLevel(unit),
        role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE",
      }
    end
  end
  return members
end

-- people who join later are added; nobody is removed, since leaving mid-run
-- doesn't undo what they did
local function merge(current, fresh)
  local seen = {}
  for _, m in ipairs(current) do seen[m.name] = m end
  for _, m in ipairs(fresh) do
    if not seen[m.name] then current[#current + 1] = m; seen[m.name] = m
    elseif m.role ~= "NONE" then seen[m.name].role = m.role end
  end
end

ns.RegisterModule({
  name = "Party",
  OnRunStart = function(_, run) run.party = snapshot() end,
  events = {
    GROUP_ROSTER_UPDATE = function(_, run) if run then merge(run.party, snapshot()); ns.Changed() end end,
  },
})
