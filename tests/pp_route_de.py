"""Blacksmithing 173 -> 225 with Blizzard's colors (Data.lua) and real trainer
data (TrainerData.lua). Materials are the classic ones; prices like the
user's Auction House."""
import os, sys
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(r'''
function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}
ITEMS = { [2772]="Iron Ore",[3575]="Iron Bar",[3857]="Coal",[3859]="Steel Bar",[3860]="Mithril Bar",[4338]="Mageweave Cloth",[4234]="Heavy Leather",
 [4304]="Thick Leather",[2605]="Green Dye",[2838]="Heavy Stone",[3486]="Heavy Grinding Stone",[7912]="Solid Stone",[7966]="Solid Grinding Stone",
 [3577]="Gold Bar",[6037]="Truesilver Bar",[1206]="Moss Agate",[2592]="Wool Cloth",[2835]="Rough Stone",[7071]="Iron Buckle" }
OWNED = {}
AH = { [2772]=235,[3575]=900,[3857]=400,[3859]=1500,[3860]=1100,[4338]=410,[4234]=500,[4304]=1200,[2838]=300,[3486]=890,[7912]=600,
 [3577]=6000,[6037]=10000,[1206]=3000,[2592]=200,[2835]=50 }
VENDOR = { [2605]=100 }
function UnitName() return "Tester" end
function GetRealmName() return "Forever" end
function GetProfessions() return 1, 2 end
function GetProfessionInfo(i) if i == 1 then return "Schmiedekunst", nil, 0, 0, 0, 0, 164 end return "Bergbau", nil, 0, 0, 0, 0, 186 end
PROF = "Blacksmithing"
local function R(name, learned, reagents, out) return { name = name, learned = learned, reagents = reagents, out = out } end
BOOK = {
  Mining = { skill = 172, max = 225, recipes = {
    [3307] = R("Smelt Iron", true, { { 2772, 1 } }, 3575), [3569] = R("Smelt Steel", true, { { 3575, 1 }, { 3857, 1 } }, 3859) } },
  Blacksmithing = { skill = 173, max = 225, recipes = {
    [3501] = R("Green Iron Bracers", true, { { 3575, 6 }, { 2605, 1 } }),
    [3506] = R("Green Iron Leggings", true, { { 3575, 8 }, { 3486, 1 }, { 2605, 1 } }),
    [3337] = R("Heavy Grinding Stone", true, { { 2838, 3 } }, 3486),
    [19667] = R("Golden Skeleton Key", true, { { 3577, 1 }, { 3486, 1 } }),
    [8768] = R("Iron Buckle", true, { { 3575, 1 } }, 7071),
    [3502] = R("Green Iron Helm", false, { { 3575, 12 }, { 2605, 1 } }),
    [3508] = R("Green Iron Hauberk", false, { { 3575, 20 }, { 3486, 4 }, { 2605, 2 }, { 1206, 2 } }),
    [7223] = R("Golden Scale Bracers", false, { { 3859, 5 }, { 3486, 2 } }),
    [9916] = R("Steel Breastplate", false, { { 3859, 16 }, { 3486, 3 } }),
    [9935] = R("Steel Plate Helm", false, { { 3859, 14 }, { 7966, 1 } }),
    [9928] = R("Heavy Mithril Gauntlet", false, { { 3860, 6 }, { 4338, 4 } }),
    [9926] = R("Heavy Mithril Shoulder", false, { { 3860, 8 }, { 4234, 6 } }),
    [9993] = R("Heavy Mithril Axe", false, { { 3860, 12 }, { 4304, 6 } }),
    [9920] = R("Solid Grinding Stone", false, { { 7912, 4 } }, 7966),
    [19668] = R("Truesilver Skeleton Key", false, { { 6037, 2 }, { 7966, 2 } }),
    [15972] = R("Glinting Steel Dagger", false, { { 3859, 10 }, { 3486, 1 } }),
    [460460] = R("Sulfuron Hammer", false, { { 3860, 50 } }),   -- another game version: no trainer
  } },
}
local DATAHIGH = {}
local function grayOf(id) for _, l in pairs(SPD or {}) do if l[id] then return l[id][2], l[id][1] end end end
local function diffAt(gray, yellow, s) if s >= gray then return 3 end if s >= (yellow + gray) / 2 then return 2 end if s >= yellow then return 1 end return 0 end
C_TradeSkillUI.GetChildProfessionInfo = function() local b = BOOK[PROF]; return { professionName = (PROF == "Mining" and "Bergbau" or "Schmiedekunst"), professionID = (PROF == "Mining" and 186 or 164), skillLevel = b.skill, maxSkillLevel = b.max } end
C_TradeSkillUI.GetAllRecipeIDs = function() local ids = {} for id in pairs(BOOK[PROF].recipes) do ids[#ids+1] = id end table.sort(ids) return ids end
C_TradeSkillUI.GetRecipeInfo = function(id)
  local b = BOOK[PROF]; local r = b.recipes[id]
  local gray, yellow = grayOf(id)
  gray, yellow = gray or 100, yellow or 50
  return { name = r.name, learned = r.learned, relativeDifficulty = r.learned and diffAt(gray, yellow, b.skill) or 0, maxTrivialLevel = gray, numSkillUps = 1, icon = id, craftable = true }
end
C_TradeSkillUI.GetRecipeSchematic = function(id)
  local r = BOOK[PROF].recipes[id]; local slots = {}
  for _, rg in ipairs(r.reagents) do slots[#slots+1] = { required = true, reagentType = 1, quantityRequired = rg[2], reagents = { { itemID = rg[1] } } } end
  return { reagentSlotSchematics = slots, outputItemID = r.out, quantityMin = 1 }
end
function SetProf(p) PROF = p end
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Data.lua", "TrainerData.lua", "Trainer.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute('''
local SP = ProfessionPathfinder
SPD = SP.DATA
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder"); E(SP.eventFrame, "PLAYER_LOGIN")
SetProf("Mining"); E(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers()
SetProf("Blacksmithing"); E(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers()
local plan = SP.lastPlan
local function strip(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function money(c) return string.format("%.1fg", (c or 0) / 10000) end
print(string.format("Plan %d -> %d (reached %d), guide: %s", plan.from, plan.to, plan.reached, tostring(plan.guide ~= nil)))
for _, s in ipairs(plan.steps) do
  print(string.format("  %3d-%3d  %3dx %-26s %s%s", s.from, s.to, s.crafts, s.recipe.name, money(s.cost),
    s.learn and ("   learn at " .. tostring(s.learnAt) .. " for " .. money(s.trainCost)) or ""))
end
print("  make first:") for _, p in ipairs(plan.prep) do print("    " .. p.crafts .. "x " .. p.recipe.name) end
print("  buy:") for _, b in ipairs(plan.shopping) do print(string.format("    %4dx %-22s %s", b.count, ITEMS[b.itemID] or b.itemID, money(b.cost))) end
print("  training " .. money(plan.trainCost) .. ", total " .. money(plan.total))
print("UI note: " .. strip(SP.UI.frame.note and SP.UI.frame.note._text))
''')
lua.execute('''
local SP = ProfessionPathfinder
local f = SP.UI.frame
local function strip(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
print("title line:", strip(f.sub._text))
print("plan key:", SP.lastPlan.prof.name, "label:", SP.lastPlan.prof.label)
''')
