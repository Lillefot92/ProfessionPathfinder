import os
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(open(os.path.join(HERE, "sp_bs.lua")).read())
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Gathering.lua", "Planner.lua", "UI.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute('''
local SP = ProfessionPathfinder
local onEvent = SP.eventFrame:GetScript("OnEvent")
local function show(plan)
  print(string.format("%s %d -> %d  total %.0f", plan.prof.name, plan.from, plan.to, plan.total))
  for _, p in ipairs(plan.prep) do print(string.format("  MAKE %-22s ~%d  (%s)", p.recipe.name, p.crafts, tostring(p.recipe.profession or "this profession"))) end
  for _, s in ipairs(plan.steps) do print(string.format("  %-24s %d-%d  ~%d crafts", s.recipe.name, s.from, s.to, s.crafts)) end
  for _, i in ipairs(plan.shopping) do print(string.format("  BUY %3dx %-14s %s", i.count, ITEMS[i.itemID], tostring(i.cost))) end
  print("  note: " .. tostring(SP.UI.frame.note._text))
end
onEvent(SP.eventFrame, "PLAYER_LOGIN")
print("== Blacksmithing before Mining was ever opened ==")
SetProf("Blacksmithing"); onEvent(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers(); show(SP.lastPlan)
print("== open Mining once ==")
SetProf("Mining"); onEvent(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers(); show(SP.lastPlan)
print("== Blacksmithing again: smelting used ==")
SetProf("Blacksmithing"); onEvent(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers(); show(SP.lastPlan)
local row = SP.UI.steps[1]; print("prep row clickable:", row.recipeID ~= nil, row.right._text)
''')
