import os
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open("sp_harness.lua").read())
lua.execute("function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}")
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Data.lua", "TrainerData.lua", "Trainer.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute('''
local F = ProfessionPathfinder.Fishing
MAPID = 1454
C_Map = { GetBestMapForUnit = function() return MAPID end, GetMapInfo = function(id) if id == 9999 then return { parentMapID = 1413 } end return { parentMapID = 0 } end }
function GetRealZoneText() return "Orgrimmar (German: Orgrimmar)" end
print("Orgrimmar map:", F.CurrentZone())
MAPID = 9999; print("cave inside The Barrens:", F.CurrentZone())
MAPID = 123456; function GetRealZoneText() return "Zephras Isle" end; print("unknown map:", F.CurrentZone())
''')
