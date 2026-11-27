"""Specializations: recipes only an Armorsmith, Weaponsmith, Gnomish or Goblin
Engineer, or Dragonscale/Elemental/Tribal Leatherworker can learn are only
planned for that specialist, who is sent to the specialization trainer. A
note says when you can specialize. Also: an empty realm name ("Krigar-")
is merged into the full character key once the realm is known."""
import os
from lupa import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__)); REPO = os.path.dirname(HERE)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(r'''
function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}
REALM = ""
function UnitName() return "Krigar" end function GetRealmName() return REALM end
function UnitFactionGroup() return "Horde" end
LEVEL = 39
function UnitLevel() return LEVEL end
KNOWN = {}
function IsPlayerSpell(id) return KNOWN[id] == true end
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Data.lua", "TrainerData.lua", "Sources.lua", "Trainer.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(REPO, fn)).read(), fn, ns)
lua.execute(r'''
local SP = ProfessionPathfinder
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder"); E(SP.eventFrame, "PLAYER_LOGIN")

-- the realm isn't known yet: things are saved under "Krigar-"
assert(SP.MyKey() == "Krigar-")
SP.db.chars = { ["Krigar-"] = { name = "Krigar", updated = 10, profs = { Mining = { skill = 213 } } } }
SP.db.said = { ["Krigar-:learn:Blacksmithing:X"] = true, ["Other-Realm:learn:Y"] = true }
SP.db.known = { ["Krigar-"] = { Mining = { 1 } }, ["Krigar-CAMWOW"] = { Blacksmithing = { 2 } } }
-- then it shows up: everything moves to the full key
REALM = "CAMWOW"
assert(SP.MyKey() == "Krigar-CAMWOW")
assert(SP.db.chars["Krigar-CAMWOW"] and not SP.db.chars["Krigar-"], "character moved")
assert(SP.db.said["Krigar-CAMWOW:learn:Blacksmithing:X"] and not SP.db.said["Krigar-:learn:Blacksmithing:X"], "reminders moved")
assert(SP.db.said["Other-Realm:learn:Y"], "others untouched")
assert(SP.db.known["Krigar-CAMWOW"].Mining and SP.db.known["Krigar-CAMWOW"].Blacksmithing and not SP.db.known["Krigar-"], "known recipes merged")

-- Forever: UnitFullName gives "Krigar" + "Kossan" every time, while
-- GetRealmName flips between the server's name, "Kossan" and nothing.
-- The key is always Krigar-Kossan, and the server-name entries move to it.
SP.realm = nil; SP.mergedEmpty = nil
SP.db.chars = {
	["Krigar-CAMWOW EU4 Realm 6 PvP"] = { name = "Krigar", updated = 50, profs = { Blacksmithing = { skill = 182 } } },
	["Krigar-Kossan"] = { name = "Krigar", updated = 40, profs = { Cooking = { skill = 100 } } },
	["Krigar-"] = { name = "Krigar", updated = 10 },
	["Sneaky-CAMWOW EU4 Realm 6 PvP"] = { name = "Sneaky", updated = 30 },
	["Sneaky-Lillefot"] = { name = "Sneaky", updated = 35 },
}
SP.db.said = { ["Krigar-CAMWOW EU4 Realm 6 PvP:rank:Blacksmithing:Expert"] = true, ["Krigar-Kossan:rank:Cooking:Artisan"] = true,
	["Sneaky-CAMWOW EU4 Realm 6 PvP:rank:Skinning:Journeyman"] = true }
SP.db.known = { ["Krigar-CAMWOW EU4 Realm 6 PvP"] = { Blacksmithing = { 1 } }, ["Krigar-Kossan"] = { Cooking = { 2 } } }
UnitFullName = function() return "Krigar", "Kossan" end
UnitName = function() return "Krigar", "Kossan" end
REALM = "CAMWOW EU4 Realm 6 PvP"
assert(SP.MyKey() == "Krigar-Kossan", SP.MyKey())
assert(not SP.db.chars["Krigar-CAMWOW EU4 Realm 6 PvP"] and not SP.db.chars["Krigar-"], "old Krigar keys merged")
assert(SP.db.chars["Krigar-Kossan"].updated == 50, "the newer record wins")
assert(SP.db.said["Krigar-Kossan:rank:Blacksmithing:Expert"] and SP.db.said["Krigar-Kossan:rank:Cooking:Artisan"])
assert(SP.db.known["Krigar-Kossan"].Blacksmithing and SP.db.known["Krigar-Kossan"].Cooking)
assert(SP.db.chars["Sneaky-CAMWOW EU4 Realm 6 PvP"] and SP.db.said["Sneaky-CAMWOW EU4 Realm 6 PvP:rank:Skinning:Journeyman"], "other characters wait for their own login")
REALM = ""
assert(SP.MyKey() == "Krigar-Kossan")
REALM = "Kossan"
assert(SP.MyKey() == "Krigar-Kossan")

SP.OvertimeBonus = function() return 0 end
SP.Chance = function() return 1 end
AH = setmetatable({}, { __index = function() return 100 end })
local function R(id, name, learn) return { id = id, name = name, ups = 1, reagents = { { itemID = 90000 + id, count = 1 } }, output = 80000 + id, outputCount = 1,
	unlearned = true, learn = learn, trainCost = 0, how = "maybe", yellow = learn, gray = learn + 40 } end
-- Truesilver Gauntlets (Armorsmith) is cheaper than a normal recipe
AH[90000 + 9954] = 1
local GAUNTLETS = R(9954, "Truesilver Gauntlets", 225)
local NORMAL = R(9937, "Normal Plate Thing", 225)
local prof = { name = "Blacksmithing", id = 164, skill = 225, max = 240 }
local db = { bagsFree = false, resale = "off" }

-- not a specialist: the Armorsmith recipe is left out
local p = SP.MakePlan(prof, {}, db, {}, { GAUNTLETS, NORMAL })
print("no spec:", p.steps[1].recipe.name, p.specSkipped and p.specSkipped[9788])
assert(p.steps[1].recipe == NORMAL and p.specSkipped[9788] == 1)
-- a note says you can specialize, and where
LEVEL = 40
local note = SP.SpecNote(prof, p)
print(note)
assert(note:find("Armorsmith or Weaponsmith") and note:find("Krathok Moltenfist") and note:find("left out"))
LEVEL = 39
assert(SP.SpecNote(prof, p) == nil, "level 40 needed")
LEVEL = 40

-- an Armorsmith gets it, from the Armorsmith trainer
KNOWN[9788] = true
p = SP.MakePlan(prof, {}, db, {}, { GAUNTLETS, NORMAL })
assert(p.steps[1].recipe == GAUNTLETS and not p.specSkipped)
local where, npc = SP.LearnWhere(prof, p.steps[1])
print("learn at:", where)
assert(npc and npc.name == "Okothos Ironrager", where)
assert(SP.SpecNote(prof, p) == nil, "already specialized")
-- a Weaponsmith doesn't
KNOWN[9788] = nil; KNOWN[9787] = true
p = SP.MakePlan(prof, {}, db, {}, { GAUNTLETS, NORMAL })
assert(p.steps[1].recipe == NORMAL)
-- at 250 a Weaponsmith hears about the Master specializations (level 50)
LEVEL = 50
local note2 = SP.SpecNote({ name = "Blacksmithing", id = 164, skill = 250, max = 300 }, nil)
print(note2)
assert(note2 and note2:find("Master Axesmith") and note2:find("Master Swordsmith") and not note2:find("Armorsmith"))
-- a Master Swordsmith counts as a Weaponsmith
KNOWN[9787] = nil; KNOWN[17039] = true
assert(SP.MySpecs()[9787])
KNOWN[17039] = nil

-- knowing a specialist recipe counts, even if the spell check misses it
SP.NoteSpecRecipes({ { id = 12716, name = "Goblin Mortar" } })
assert(SP.MySpecs()[20222], "Goblin Engineer from a known Goblin recipe")
local eng = { name = "Engineering", id = 202, skill = 210, max = 225 }
local GNOME = R(12899, "Gnomish Shrink Ray", 205); local GOBLIN = R(12717, "Goblin Mining Helmet", 205)
AH[90000 + 12899] = 1
p = SP.MakePlan(eng, {}, db, {}, { GNOME, GOBLIN })
assert(p.steps[1].recipe == GOBLIN, "a Goblin Engineer can't learn Gnomish recipes")
assert(SP.SpecNote(eng, p) == nil)

-- every specialization has a trainer for each faction (or a neutral one)
for spec, d in pairs(SP.SPECS) do
	for _, fac in ipairs({ "Horde", "Alliance" }) do
		UnitFactionGroup = function() return fac end
		assert(SP.SpecTrainer(spec), d[1] .. " trainer for " .. fac)
		assert(SP.SpecTrainer(spec, true), d[1] .. " start for " .. fac)
	end
end
UnitFactionGroup = function() return "Horde" end
-- the game's item data marks plans that need a specialization
assert(SP.SPEC_RECIPES[16741] == 9788 or SP.SPEC_RECIPES[16729] == 9788, "Lionheart Helm-style plans")
local n = 0 for _ in pairs(SP.SPEC_RECIPES) do n = n + 1 end
print("specialist recipes:", n)
assert(n > 80)
''')
print("ok")
