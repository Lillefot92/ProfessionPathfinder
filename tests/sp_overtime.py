import os
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open("sp_harness.lua").read())
lua.execute(open("sp_route.lua").read())
lua.execute('''
LegacyCoach = nil
RANK = 3
C_Traits = {
  GetConfigIDBySystemID = function(sys) if sys == 45 then return 838578 end return 0 end,
  GetConfigInfo = function(cfg) if cfg == 838578 then return { treeIDs = { 1118, 1187 } } end end,
  GetTreeCurrencyInfo = function(cfg, tree) return { { traitCurrencyID = 4225 } } end,
  GetTreeNodes = function(tree) if tree == 1118 then return { 1, 2 } end return { 3 } end,
  GetNodeInfo = function(cfg, node) return { activeEntry = { entryID = node * 10 }, activeRank = node == 3 and RANK or 1 } end,
  GetEntryInfo = function(cfg, e) return { definitionID = e } end,
  GetDefinitionInfo = function(d) local n = { [10] = "Thrill of Adventure", [20] = "Bountiful Harvest", [30] = "Working Overtime" } return { overrideName = n[d] } end,
}
T = 0
function GetTime() return T end
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute('''
local SP = ProfessionPathfinder
SP.eventFrame:GetScript("OnEvent")(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder")
print("rank", SP.OvertimeRank(), "bonus", SP.OvertimeBonus())
RANK = 4; T = 10
print("cached (10s later)", SP.OvertimeRank())
T = 45
print("after 45s", SP.OvertimeRank())
C_Traits.GetConfigIDBySystemID = function() return 0 end
''')
