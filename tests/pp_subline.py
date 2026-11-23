"""Opening a recipe (craft button, plan click) can switch the profession window
to a sub skill line with another ID. The plan must stay the same: Blizzard's
colors are keyed by the main line (164), so a wrong ID used to drop them."""
import os, re
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "pp_route_bs.py")).read()
# Same book and prices, but the child profession's ID can be changed.
src = src.replace('professionID = (PROF == "Mining" and 186 or 164), skillLevel',
                  'professionID = (PROF == "Mining" and 186 or CHILD_ID), parentProfessionID = CHILD_PARENT, skillLevel')
src = src.replace('PROF = "Blacksmithing"\n', 'PROF = "Blacksmithing"\nCHILD_ID = 164\nCHILD_PARENT = nil\nBASE_ID = 164\n'
                  'C_TradeSkillUI.GetBaseProfessionInfo = function() local b = BOOK[PROF]; if not BASE_ID then return nil end '
                  'return { professionName = PROF, professionID = (PROF == "Mining" and 186 or BASE_ID), skillLevel = b.skill, maxSkillLevel = b.max } end\n', 1)
head, tail = src.split("lua.execute('''\nlocal SP = ProfessionPathfinder", 1)
exec(compile(head, "pp_subline_setup", "exec"))
lua.execute(r'''
local SP = ProfessionPathfinder
SPD = SP.DATA
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder"); E(SP.eventFrame, "PLAYER_LOGIN")
SetProf("Mining"); E(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers()
local function Plan()
  SetProf("Blacksmithing"); E(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers()
  local p = SP.lastPlan
  local out = { "id " .. tostring(SP.ProfessionInfo().id) }
  for _, s in ipairs(p.steps) do out[#out+1] = s.from .. "-" .. s.to .. " " .. s.crafts .. "x " .. s.recipe.name end
  out[#out+1] = "total " .. math.floor(p.total)
  return table.concat(out, "\n")
end
local fresh = Plan()
CHILD_ID, CHILD_PARENT = 2437, 164                  -- sub line, parent given
local sub1 = Plan()
CHILD_ID, CHILD_PARENT, BASE_ID = 2437, nil, 164    -- sub line, base profession says 164
local sub2 = Plan()
CHILD_ID, CHILD_PARENT, BASE_ID = 2437, nil, nil    -- nothing says 164: last one seen
local sub3 = Plan()
print(fresh)
assert(fresh:find("^id 164"), "fresh window should be line 164")
assert(sub1 == fresh, "parent ID case differs:\n" .. sub1)
assert(sub2 == fresh, "base profession case differs:\n" .. sub2)
assert(sub3 == fresh, "remembered line case differs:\n" .. sub3)
print("same plan on the sub skill line")
''')
