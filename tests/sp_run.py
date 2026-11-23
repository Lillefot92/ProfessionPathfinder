import os
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute('''
local SP = ProfessionPathfinder
local onEvent = SP.eventFrame:GetScript("OnEvent")
onEvent(SP.eventFrame, "PLAYER_LOGIN")
onEvent(SP.eventFrame, "TRADE_SKILL_SHOW")
RunTimers()
local function show(plan)
  print(string.format("%s %d -> %d  total %s", plan.prof.name, plan.from, plan.to, tostring(plan.total)))
  for _, p in ipairs(plan.prep) do print(string.format("  MAKE %-24s ~%d", p.recipe.name, p.crafts)) end
  for _, s in ipairs(plan.steps) do print(string.format("  %-24s %d-%d  ~%d crafts  cost %.0f", s.recipe.name, s.from, s.to, s.crafts, s.cost)) end
  for _, i in ipairs(plan.shopping) do print(string.format("  BUY %3dx %-20s @%s (%s) = %s", i.count, ITEMS[i.itemID], tostring(i.price), tostring(i.source), tostring(i.cost))) end
  if plan.stuckAt then print("  stuck at " .. plan.stuckAt) end
end
show(SP.lastPlan)
print("rows shown:", SP.UI.steps[1]:IsShown(), SP.UI.items[1]:IsShown(), SP.UI.frame:IsShown())
-- click first step
SP.UI.steps[1]:GetScript("OnClick")(SP.UI.steps[1]); print("opened recipe", OPENED)
-- Auctionator export
SP.UI.frame.ahButton:GetScript("OnClick")(); print("AH list:", CREATED and CREATED.name, CREATED and #CREATED.terms)
-- at cap
SKILL = 75; SP.RequestRefresh(); RunTimers(); print("at cap:", SP.lastPlan.atCap)
-- no Auctionator
SKILL = 40; local A = Auctionator; Auctionator = nil; SP.RequestRefresh(); RunTimers(); show(SP.lastPlan); print("note:", SP.UI.frame.note._text); Auctionator = A
-- target
SlashCmdList.PROFESSIONPATHFINDER("target 55"); RunTimers(); print("target 55 ->", SP.lastPlan.to)
SlashCmdList.PROFESSIONPATHFINDER("debug")
''')
