"""/ppf export: recipe names, the skill each recipe item needs (from its
tooltip), and its sell price end up in ProfessionPathfinderDB.export."""
import os
from lupa import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__)); ADDON_DIR = os.path.dirname(HERE)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(r'''
function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}
function UnitName() return "Tester" end function GetRealmName() return "Forever" end function GetLocale() return "enUS" end
ITEM_MIN_SKILL = "Requires %s (%d)"
C_Spell = { GetSpellName = function(id) return "Spell " .. id end }
local loaded = {}
C_Item.RequestLoadItemDataByID = function(id) loaded[id] = true end
C_Item.IsItemDataCachedByID = function(id) return loaded[id] == true end
C_Item.GetItemNameByID = function(id) return loaded[id] and ("Recipe: Thing " .. id) or nil end
C_Item.GetItemInfo = function(id) return "Recipe", nil, 1, 20, 0, "Recipe", "Cooking", 1, "", 0, 125, 9, 5, 0 end
C_Item.GetItemSpell = function(id) return "Learning", 483 end
C_TooltipInfo = { GetItemByID = function(id) return { lines = { { leftText = "Recipe: Thing" }, { leftText = "Requires Cooking (75)" }, { leftText = "Sell Price: 1s 25c" } } } end }
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Data.lua", "TrainerData.lua", "Sources.lua", "Trainer.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute('''
local SP = ProfessionPathfinder
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder"); E(SP.eventFrame, "PLAYER_LOGIN")
SlashCmdList.PROFESSIONPATHFINDER("export")
for i = 1, 5 do RunTimers() end
local ex = ProfessionPathfinderDB.export
assert(ex, "no export")
local n, it = 0, nil
for _ in pairs(ex.spells) do n = n + 1 end
local id = SP.RECIPE_ITEM_IDS[1]
it = ex.items[id]
assert(n > 2000, "spells " .. n)
assert(it and it.skill == 75 and it.skillName == "Cooking" and it.sell == 125 and it.bind == 0, "item " .. tostring(it and it.skill))
print("export ok", n, id, it.skill)
''')
