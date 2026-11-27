"""Right after a profession window opens, the game can give an empty
profession (no name, 0/0), as First Aid did in /ppf scan. Then the addon
works out the profession from the window's recipes and takes the skill from
the character's profession list."""
import os
from lupa import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__)); REPO = os.path.dirname(HERE)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(r'''
function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}
function UnitName() return "Krigar", "Kossan" end function UnitFullName() return "Krigar", "Kossan" end
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Data.lua", "TrainerData.lua", "Sources.lua", "Trainer.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(REPO, fn)).read(), fn, ns)
lua.execute(r'''
local SP = ProfessionPathfinder
local EMPTY = { skillLevel = 0, maxSkillLevel = 0, professionName = "" }
C_TradeSkillUI = C_TradeSkillUI or {}
C_TradeSkillUI.GetChildProfessionInfo = function() return EMPTY end
C_TradeSkillUI.GetBaseProfessionInfo = function() return EMPTY end
C_TradeSkillUI.GetAllRecipeIDs = function() return { 1230117, 1263001, 1244435 } end
function GetProfessions() return 1, 2, nil, 4, 5, 6 end
local P = { [1] = { "Blacksmithing", 1, 182, 225, 0, 0, 164 }, [2] = { "Mining", 1, 213, 225, 0, 0, 186 },
	[4] = { "Fishing", 1, 150, 225, 0, 0, 356 }, [5] = { "Cooking", 1, 225, 225, 0, 0, 185 }, [6] = { "First Aid", 1, 230, 300, 0, 0, 129 } }
function GetProfessionInfo(i) local p = P[i] return p[1], p[2], p[3], p[4], p[5], p[6], p[7] end
local prof = SP.ProfessionInfo()
print(prof and (prof.name .. " " .. prof.skill .. "/" .. prof.max .. " line " .. prof.id))
assert(prof and prof.name == "First Aid" and prof.id == 129 and prof.skill == 230 and prof.max == 300 and prof.fallback)
-- a normal answer from the game is used as it is
C_TradeSkillUI.GetChildProfessionInfo = function() return { skillLevel = 231, maxSkillLevel = 300, professionName = "First Aid", professionID = 129 } end
prof = SP.ProfessionInfo()
assert(prof.skill == 231 and not prof.fallback)
-- recipes from nowhere in particular: no guess
C_TradeSkillUI.GetChildProfessionInfo = function() return EMPTY end
C_TradeSkillUI.GetAllRecipeIDs = function() return { 1, 2, 3 } end
prof = SP.ProfessionInfo()
assert(not prof or not prof.fallback)
''')
print("ok")
