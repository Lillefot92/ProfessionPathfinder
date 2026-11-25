"""Gather & craft mode: only materials you can gather (or an alt can), cloth
from humanoids and vendor items; no Auction House. Gathering counts as effort,
gold only for vendor items; gathering skills to raise are flagged."""
import os
from lupa import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__)); REPO = os.path.dirname(HERE)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(r'''
function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}
function UnitName() return "Tester" end function GetRealmName() return "Forever" end
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Data.lua", "TrainerData.lua", "Sources.lua", "Trainer.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(REPO, fn)).read(), fn, ns)
lua.execute(r'''
local SP = ProfessionPathfinder
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder"); E(SP.eventFrame, "PLAYER_LOGIN")
SP.OvertimeBonus = function() return 0 end
SP.Chance = function() return 1 end
SP.db.chars = { ["Tester-Forever"] = { name = "Tester", profs = { Mining = { skill = 40 } } } }
-- Elemental Earth is cheap on the AH; everything else has no AH price
AH = { [7067] = 1 }
local function R(id, name, reagents, out) return { id = id, name = name, ups = 1, reagents = reagents, output = out, outputCount = 1 } end
local STONE = R(1, "Rough Sharpening Stone", { { itemID = 2835, count = 1 } }, 2862)       -- Rough Stone (mined)
local BELT  = R(2, "Copper Chain Belt", { { itemID = 2840, count = 6 } }, 2851)            -- Copper Bars (smelted)
local EARTH = R(3, "Earthy Thing", { { itemID = 7067, count = 1 } }, 9999)                 -- Elemental Earth: AH only
local BRONZE = R(4, "Bronze Thing", { { itemID = 2841, count = 2 }, { itemID = 2880, count = 1 } }, 9998) -- Bronze Bar + Weak Flux
local SMELT = { id = 50, name = "Smelt Copper", reagents = { { itemID = 2770, count = 1 } }, output = 2840, outputCount = 1, foreign = true, profession = "Mining" }
local prof = { name = "Blacksmithing", id = 164, skill = 1, max = 20 }
local db = { bagsFree = false, resale = "off" }

-- normal mode: the cheap Auction House recipe wins
db.selfGather = false
local p = SP.MakePlan(prof, { STONE, BELT, EARTH }, db, { SMELT }, {})
print("normal:", p.steps[1].recipe.name)
assert(p.steps[1].recipe == EARTH)

-- gather & craft: Auction House materials are out; fewest things to gather wins
db.selfGather = true
p = SP.MakePlan(prof, { STONE, BELT, EARTH }, db, { SMELT }, {})
print("self:", p.steps[1].recipe.name, "gold", p.total, "gather", p.gatherCount)
assert(p.selfGather and p.steps[1].recipe == STONE)
for _, s in ipairs(p.steps) do assert(s.recipe ~= EARTH) end
assert(p.total == 0 and p.gatherCount == 19, "19 Rough Stones, no gold")
assert(p.shopping[1].itemID == 2835 and p.shopping[1].gather and p.shopping[1].cost == nil)
assert(p.steps[1].get[2835] and math.abs(p.steps[1].get[2835] - 19) < 1e-6)
assert(#p.gatherWarn == 0)

-- only the belt: smelting your own ore (Mining window seen) means gathering ore
p = SP.MakePlan(prof, { BELT, EARTH }, db, { SMELT }, {})
assert(p.steps[1].recipe == BELT)
local got = {}
for _, it in ipairs(p.shopping) do got[it.itemID] = it end
assert(got[2770] and got[2770].gather and not got[2840], "mine Copper Ore and smelt it")
assert(#p.prep == 1 and p.prep[1].recipe == SMELT)

-- Bronze needs Mining 65 (you have 40) and Weak Flux from a vendor (gold)
p = SP.MakePlan(prof, { BRONZE }, db, {}, {})
assert(p.steps[1].recipe == BRONZE)
local w = p.gatherWarn[1]
print("warn:", w and (w.prof .. " " .. w.skill .. " have " .. w.have))
assert(w and w.prof == "Mining" and w.skill == 65 and w.have == 40)
got = {}
for _, it in ipairs(p.shopping) do got[it.itemID] = it end
assert(got[2880] and got[2880].source == "vendor" and got[2880].cost and got[2880].cost > 0)
assert(p.total == got[2880].cost, "gold is only the vendor flux")

-- nobody can mine: ore recipes are out, cloth needs no profession
SP.db.chars = { ["Tester-Forever"] = { name = "Tester", profs = {} } }
p = SP.MakePlan(prof, { STONE, BELT }, db, { SMELT }, {})
assert(#p.steps == 0 and p.selfStuck, "nothing you can gather")
local BANDAGE = R(5, "Linen Bandage", { { itemID = 2589, count = 1 } }, 1251)
p = SP.MakePlan({ name = "First Aid", id = 129, skill = 1, max = 20 }, { BANDAGE }, db, {}, {})
assert(p.steps[1].recipe == BANDAGE and p.shopping[1].source == "cloth")
print("cloth where:", SP.GatherWhere(SP.GATHER[2589]))

-- an alt who can mine counts
SP.db.chars = { ["Tester-Forever"] = { name = "Tester", profs = {} }, ["Alt-Forever"] = { name = "Alt", profs = { Mining = { skill = 100 } } } }
p = SP.MakePlan(prof, { STONE }, db, {}, {})
assert(p.steps[1].recipe == STONE and #p.gatherWarn == 0)
-- materials nobody can gather yet are left for later: Truesilver (Mining 230, you have 40)
-- loses to three Rough Stones you can mine now, even though it's one bar vs three stones
SP.db.chars = { ["Tester-Forever"] = { name = "Tester", profs = { Mining = { skill = 40 } } } }
local TRUE = R(6, "Truesilver Thing", { { itemID = 6037, count = 1 } }, 9997)
local STONES = R(7, "Stone Thing", { { itemID = 2835, count = 3 } }, 9996)
p = SP.MakePlan(prof, { TRUE, STONES }, db, {}, {})
print("reachable first:", p.steps[1].recipe.name)
assert(p.steps[1].recipe == STONES)
SP.db.chars["Tester-Forever"].profs.Mining.skill = 240
p = SP.MakePlan(prof, { TRUE, STONES }, db, {}, {})
assert(p.steps[1].recipe == TRUE, "once you can mine Truesilver, one bar beats three stones")

-- zones that fit the character's level
assert(SP.FitZones("Badlands, Tanaris, The Hinterlands or Searing Gorge", 38) == "Badlands, Tanaris or The Hinterlands")
assert(SP.FitZones("Badlands, Tanaris, The Hinterlands or Searing Gorge", 30) == "Badlands (level 35+)")
assert(SP.FitZones("Felwood", 40) == "Felwood (level 48+)")
assert(SP.FitZones("Felwood", 50) == "Felwood")
assert(SP.FitZones("Wetlands (raptors)", 20) == "Wetlands (raptors)")
assert(SP.FitZones("Badlands or Tanaris", nil) == "Badlands or Tanaris")

-- the window draws a gather & craft plan (rows, notes, tooltips) without errors
SP.db.chars = { ["Tester-Forever"] = { name = "Tester", profs = { Mining = { skill = 40 } } } }
SP.db.selfGather = true
p = SP.MakePlan(prof, { BRONZE, STONE }, db, {}, {})
SP.UI:Create()
SP.UI:Show(prof, p)
local f = SP.UI.frame
print("total shown")
print("ok")
''')
