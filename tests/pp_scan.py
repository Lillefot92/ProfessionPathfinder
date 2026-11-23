import os
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open("sp_harness.lua").read())
lua.execute(open("sp_route.lua").read().replace("local BOOK", "BOOK"))
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute('''
function GetTime() return 0 end
tinsert = table.insert; UISpecialFrames = {}
local SP = ProfessionPathfinder
SP.eventFrame:GetScript("OnEvent")(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder")
SetProf("Blacksmithing")
-- pretend the game also lists one recipe you don't know
local orig = C_TradeSkillUI.GetAllRecipeIDs
C_TradeSkillUI.GetAllRecipeIDs = function() local t = orig(); t[#t+1] = 9999; return t end
local gi = C_TradeSkillUI.GetRecipeInfo
C_TradeSkillUI.GetRecipeInfo = function(id) if id == 9999 then return { name = "Golden Scale Bracers", learned = false, maxTrivialLevel = 210, recipeID = 9999 } end return gi(id) end
SlashCmdList.PROFESSIONPATHFINDER("scan")
print(SP.reportFrame.edit._text or "(no text)")
''')
