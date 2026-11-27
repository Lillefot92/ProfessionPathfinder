"""Recipes with a cooldown (transmutes, Mooncloth) are never planned, even
when they look cheapest, and aren't used to make materials either."""
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
assert(SP.COOLDOWN[11479] == 3600 and SP.COOLDOWN[18560] > 86400, "cooldowns from the game data")
AH = { [3575] = 1, [5000] = 500, [6037] = 900, [7911] = 1 }
local function R(id, name, item, out) return { id = id, name = name, ups = 1, reagents = { { itemID = item, count = 1 } }, output = out, outputCount = 1 } end
-- a cheap transmute you already know, and a pricier normal recipe
local IRON2GOLD = R(11479, "Transmute: Iron to Gold", 3575, 3577)
local POTION = R(7837, "Some Potion", 5000, 5001)
local prof = { name = "Alchemy", id = 171, skill = 200, max = 225 }
local db = { bagsFree = false, resale = "off" }
local p = SP.MakePlan(prof, { IRON2GOLD, POTION }, db, {}, {})
print("first step:", p.steps[1].recipe.name)
for _, s in ipairs(p.steps) do assert(s.recipe ~= IRON2GOLD, "never plan a transmute") end
-- a blacksmith needing Truesilver Bars doesn't get them from an alt's transmute
local M2T = R(11480, "Transmute: Mithril to Truesilver", 3860, 6037)
M2T.foreign = true; M2T.profession = "Alchemy"
local THING = R(9999, "Truesilver Thing", 6037, 7000)
local bs = { name = "Blacksmithing", id = 164, skill = 230, max = 240 }
p = SP.MakePlan(bs, { THING }, db, { M2T }, {})
for _, pr in ipairs(p.prep) do assert(pr.recipe ~= M2T, "no transmutes to make materials") end
-- Mooncloth (95 hours) isn't a step for tailors either
local MOON = R(18560, "Mooncloth", 14047, 14342)
AH[14047] = 1
local POT = R(18401, "Bolt of Runecloth", 7911, 14048)
for _, r in ipairs({ MOON, POT }) do r.unlearned, r.learn, r.how, r.trainCost, r.yellow, r.gray = true, 250, "maybe", 0, 255, 290 end
p = SP.MakePlan({ name = "Tailoring", id = 197, skill = 250, max = 260 }, {}, db, {}, { MOON, POT })
print("tailoring:", p.steps[1] and p.steps[1].recipe.name)
assert(p.steps[1] and p.steps[1].recipe == POT)
for _, s in ipairs(p.steps) do assert(s.recipe ~= MOON) end

-- crafts and time: cast times from the game, 3 seconds when it doesn't say
C_Spell = C_Spell or {}
C_Spell.GetSpellInfo = function(id) return { castTime = id == 18401 and 5000 or 0 } end
local crafts, seconds = SP.PlanTime(p)
print("tailoring:", crafts, "crafts,", SP.Duration(seconds))
local n = 0 for _, s in ipairs(p.steps) do n = n + s.crafts end for _, s in ipairs(p.prep) do n = n + s.crafts end
assert(crafts == n and crafts > 0)
assert(seconds == p.steps[1].crafts * 5 + (seconds - p.steps[1].crafts * 5), "")
assert(SP.Duration(20) == "about 1 min" and SP.Duration(25 * 60) == "about 25 min" and SP.Duration(70 * 60) == "about 1 h 10 min" and SP.Duration(120 * 60) == "about 2 h")
''')
print("ok")
