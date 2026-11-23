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
onEvent(SP.eventFrame, "PLAYER_LOGIN")
SetProf("Blacksmithing")
local real = C_TradeSkillUI.GetChildProfessionInfo
local calls = 0
C_TradeSkillUI.GetChildProfessionInfo = function() calls = calls + 1; if calls <= 2 then return { professionName = "Blacksmithing", skillLevel = 0, maxSkillLevel = 0 } end return real() end
local realB = C_TradeSkillUI.GetBaseProfessionInfo
C_TradeSkillUI.GetBaseProfessionInfo = function() if calls <= 2 then return { professionName = "Blacksmithing", skillLevel = 0, maxSkillLevel = 0 } end return realB and realB() end
onEvent(SP.eventFrame, "TRADE_SKILL_SHOW")
RunTimers(); RunTimers(); RunTimers()
print("calls", calls, "plan", SP.lastPlan and SP.lastPlan.from, SP.lastPlan and SP.lastPlan.reached)
print("sub:", SP.UI.frame.sub._text, "| total:", SP.UI.frame.total._text)
-- direct: done plan never crashes the UI
local plan = { prof = {name="X"}, from=5, to=5, reached=5, done=true, steps={}, prep={}, shopping={}, total=0 }
SP.UI:Show({ name = "X", skill = 5, max = 0 }, plan)
print("done note:", SP.UI.frame.note._text)
''')
