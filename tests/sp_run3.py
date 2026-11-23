import os
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(open(os.path.join(HERE, "sp_route.lua")).read())
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Gathering.lua", "Planner.lua", "UI.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute('''
local SP = ProfessionPathfinder
local onEvent = SP.eventFrame:GetScript("OnEvent")
local function show(plan)
  print(string.format("%s %d -> %d (reached %s)  total %s  guide=%s", plan.prof.name, plan.from, plan.to, tostring(plan.reached), SP.Money(plan.total), tostring(plan.guide and plan.guide.name)))
  for _, s in ipairs(plan.steps) do print(string.format("  %-26s %3d-%3d  ~%2d crafts %s", s.recipe.name, s.from, s.to, s.crafts, s.learn and "(learn)" or "")) end
  for _, p in ipairs(plan.prep) do print(string.format("  MAKE %-22s ~%d (%s)", p.recipe.name, p.crafts, tostring(p.recipe.profession or "BS"))) end
  for _, i in ipairs(plan.shopping) do print(string.format("  BUY %4dx %-22s %s", i.count, i.name or ITEMS[i.itemID] or tostring(i.itemID), SP.Money(i.cost))) end
  print("  note: " .. tostring(SP.UI.frame.note._text))
end
onEvent(SP.eventFrame, "PLAYER_LOGIN")
SetProf("Mining"); onEvent(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers()
print("== Blacksmithing 73, Wowhead route ==")
SetProf("Blacksmithing"); onEvent(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers(); show(SP.lastPlan)
print("rows: step1", SP.UI.steps[1].text._text, "| step2", SP.UI.steps[2].text._text)
print("== after learning Silver Skeleton Key + Rough Bronze Leggings ==")
Learn("Silver Skeleton Key", { { 2842, 1 }, { 3470, 1 } }, 100, 80)
Learn("Rough Bronze Leggings", { { 2841, 6 } }, 125, 100)
SP.RequestRefresh(); RunTimers(); show(SP.lastPlan)
print("== route off (cheapest) ==")
SlashCmdList.PROFESSIONPATHFINDER("route"); RunTimers(); show(SP.lastPlan)
print("AH export:", select(2, SP.ExportToAuctionator(SP.lastPlan)))
''')
