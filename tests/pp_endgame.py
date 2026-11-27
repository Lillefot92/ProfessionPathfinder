"""The end of Blacksmithing: Forever's plans from Pexmit (Mount Hyjal) and
Vargus (Silithus), plans that need reputation only once you have it, and
a note with the best ways past a point where the plan stops."""
import os
from lupa import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__)); REPO = os.path.dirname(HERE)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(r'''
function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}
function UnitName() return "Krigar", "Kossan" end function UnitFullName() return "Krigar", "Kossan" end
function UnitFactionGroup() return "Horde" end
STANDING = {}
C_Reputation = { GetFactionDataByID = function(id) return { name = ({ [609] = "Cenarion Circle", [529] = "Argent Dawn" })[id] or "Faction", reaction = (STANDING[id] or 3) + 1 } end }
NAMES = { [1297138] = "Goregasher Grips", [1297141] = "Clutchlord's Grips", [1252365] = "Bold Dirk", [16657] = "Imperial Plate Boots", [16652] = "Thorium Boots" }
C_Spell = { GetSpellName = function(id) return NAMES[id] or ("Recipe " .. id) end }
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Data.lua", "TrainerData.lua", "Sources.lua", "Trainer.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(REPO, fn)).read(), fn, ns)
lua.execute(r'''
local SP = ProfessionPathfinder
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder"); E(SP.eventFrame, "PLAYER_LOGIN")
local function Kinds(id) local t = {} for _, s in ipairs(SP.RecipeSources(id)) do t[#t + 1] = s.kind end return table.concat(t, ",") end

-- Bold Dirk: Pexmit, no reputation needed, 10 gold
local s = SP.RecipeSources(1252365)[1]
assert(s.kind == "vendor" and s.npc.name == "Pexmit" and s.price == 100000 and s.skill == 270, Kinds(1252365))
assert(SP.NpcPlace(s.npc) == "Dae'gun, Mount Hyjal", SP.NpcPlace(s.npc))
SP.Pin(s.npc) -- no fixed spot: says so instead of pinning
print(SP.SourceText(s))

-- Goregasher Grips: Vargus at Cenarion Circle Friendly
STANDING[609] = 3
assert(Kinds(1297138) == "rep", Kinds(1297138))
local r = SP.RecipeSources(1297138)[1]
print(SP.SourceText(r))
assert(SP.SourceText(r):find("Friendly with Cenarion Circle") and SP.SourceText(r):find("you're Neutral"))
STANDING[609] = 4
assert(Kinds(1297138) == "vendor", "Friendly: planned like any vendor")
-- Support needs Honored
assert(Kinds(1297139) == "rep")
STANDING[609] = 5
assert(Kinds(1297139) == "vendor")
STANDING[609] = 3

-- Magnus Frostwake: no reputation, but the Spectral Essence
local m = SP.RecipeSources(16971)[1]
print(SP.SourceText(m))
assert(m.kind == "rep" and SP.SourceText(m):find("Spectral Essence"))

-- a plan on another character (Syndicator): mail it over. Thorium Boots plans drop (bind on equip)
Syndicator = { API = { GetInventoryInfoByItemID = function(item)
	if item == 12693 then
		return { characters = { { character = "Krigar", bags = 0 }, { character = "Mega", bags = 0, bank = 1 } } }
	end
	return { characters = {} }
end } }
local boots
for _, rows in pairs(SP.RECIPE_ITEMS) do for _, e in ipairs(rows) do if e[1] == 12693 then boots = boots or e end end end
local bootsSpell
for sid, rows in pairs(SP.RECIPE_ITEMS) do for _, e in ipairs(rows) do if e == boots then bootsSpell = sid end end end
assert(bootsSpell, "a dropped plan to test with")
local a = SP.RecipeSources(bootsSpell)[1]
print(SP.SourceText(a))
assert(a.kind == "alt" and a.alt.name == "Mega" and a.alt.spot == "bank")
assert(SP.LearnWhere({ name = "Blacksmithing" }, { source = "alt", item = boots[1], where = a.alt }):find("on Mega %(bank%): mail it"))
Syndicator = nil

-- stuck at 286 with no reputation: the ways past it
local prof = { name = "Blacksmithing", id = 164, skill = 286, max = 300 }
local ways = SP.WaysPast(prof, 286, 3)
for _, w in ipairs(ways) do print("  " .. SP.WayText(w)) end
assert(#ways == 3)
assert(ways[1].src.kind == "rep" and ways[1].name:find("Grips"), "reputation plans first")
local kinds = {} for _, w in ipairs(ways) do kinds[w.src.kind] = true end
assert(kinds.quest or kinds.drop, "a mix of ways")
-- specialist and cooldown recipes aren't suggested
for _, w in ipairs(SP.WaysPast(prof, 286, 20)) do
	assert(not SP.SpecBlocks(w.id), w.name .. " needs a specialization")
end
''')
print("ok")
