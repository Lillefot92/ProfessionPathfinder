"""Net cost: what you get back for what you craft (vendor or Auction House)
is taken off, recipes are picked by that net cost, and crafts the plan uses
later are not counted as sold."""
import os
from lupa import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__)); REPO = os.path.dirname(HERE)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(r'''
function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}
function UnitName() return "Tester" end function GetRealmName() return "Forever" end
SELL = {}
C_Item.GetItemInfo = function(id) return "item"..id, nil, 1, 1, 1, "", "", 1, "", 1, SELL[id] or 0 end
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
local db = { bagsFree = false }
-- A: 100c of material, makes something worth nothing
-- B: 150c of material, makes something a vendor pays 120c for
AH = { [901] = 100, [902] = 150 }
SELL = { [801] = 0, [802] = 120 }
local A = { id = 1, name = "A", ups = 1, reagents = { { itemID = 901, count = 1 } }, output = 801, outputCount = 1 }
local B = { id = 2, name = "B", ups = 1, reagents = { { itemID = 902, count = 1 } }, output = 802, outputCount = 1 }
local prof = { name = "Tailoring", id = 197, skill = 10, max = 20 }

db.resale = "off"
local p = SP.MakePlan(prof, { A, B }, db, {}, {})
print("off:", p.steps[1].recipe.name, p.total, p.resale, p.net)
assert(p.steps[1].recipe == A and p.resale == 0 and p.net == p.total)

-- by default recipes are picked by what you pay now; the money back is only shown
db.resale = "vendor"
p = SP.MakePlan(prof, { A, B }, db, {}, {})
assert(p.steps[1].recipe == A and p.resale == 0, "A's result sells for nothing")
db.netPick = true
p = SP.MakePlan(prof, { A, B }, db, {}, {})
print("vendor:", p.steps[1].recipe.name, p.total, p.resale, p.net)
assert(p.steps[1].recipe == B, "picks the recipe that's cheaper after selling")
assert(p.resale == 10 * 120 and p.net == p.total - p.resale and p.sell[1].itemID == 802 and p.sell[1].count == 10)

-- "best": the Auction House pays more than the vendor (after the 5% cut)
AH[801] = 200
db.resale = "best"
p = SP.MakePlan(prof, { A, B }, db, {}, {})
print("best:", p.steps[1].recipe.name, p.resale, p.sell[1] and p.sell[1].source)
assert(p.steps[1].recipe == A and p.sell[1].source == "ah" and math.abs(p.resale - 10 * 190) < 0.01)
AH[801] = nil

-- a craft the plan uses later isn't counted as sold: bars made at 10-15 feed the recipe from 15
local BAR = { id = 3, name = "Bar", ups = 1, reagents = { { itemID = 901, count = 1 } }, output = 803, outputCount = 1 }
local USE = { id = 4, name = "Use", ups = 1, reagents = { { itemID = 803, count = 2 } }, output = 804, outputCount = 1 }
SELL[803], SELL[804] = 30, 5
local chance = {}
SP.Chance = function(r, level) if r == BAR then return level < 15 and 1 or 0 end return level >= 15 and 1 or 0 end
db.resale = "vendor"
p = SP.MakePlan({ name = "Blacksmithing", id = 164, skill = 10, max = 25 }, { BAR, USE }, db, {}, {})
local sold = {}
for _, s in ipairs(p.sell) do sold[s.itemID] = s.count end
print("bars sold:", sold[803], "made items sold:", sold[804])
assert(not sold[803], "the 5 bars are all used by the next recipe")
assert(sold[804] == 10)
print("ok")
''')
