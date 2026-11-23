"""Where to learn: the nearest trainer for your faction that teaches the next
rank, the First Aid / Cooking / Fishing books and quests, map pins, and
recipes from vendors becoming part of the plan."""
import os
from lupa import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__)); ADDON_DIR = os.path.dirname(HERE)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(r'''
function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}
function UnitName() return "Tester" end function GetRealmName() return "Forever" end
FACTION = "Horde"
function UnitFactionGroup() return FACTION end
-- maps: Kalimdor (continent 1) or Eastern Kingdoms (0); world position = map offset + coordinates
local CONT = { [1411] = 1, [1454] = 1, [1445] = 1, [1446] = 1, [1412] = 1, [1456] = 1, [1413] = 1, [1440] = 1, [1443] = 1, [1444] = 1, [1450] = 1, [1451] = 1, [1452] = 1, [1457] = 1, [1438] = 1, [1439] = 1, [1441] = 1, [1442] = 1, [1447] = 1, [1448] = 1, [1449] = 1 }
HERE_MAP, HERE_X, HERE_Y = 1454, 0.5, 0.5
function CreateVector2D(x, y) return { x = x, y = y } end
C_Map = {
  GetBestMapForUnit = function() return HERE_MAP end,
  GetPlayerMapPosition = function() return { x = HERE_X, y = HERE_Y } end,
  GetWorldPosFromMapPos = function(map, v) return CONT[map] or 0, { x = (map % 100) * 10 + v.x, y = v.y } end,
  GetAreaInfo = function(a) return nil end,
  CanSetUserWaypointOnMap = function() return true end,
  SetUserWaypoint = function(p) PINNED = p end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { map = m, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Data.lua", "TrainerData.lua", "Sources.lua", "Trainer.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute(r'''
local SP = ProfessionPathfinder
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder"); E(SP.eventFrame, "PLAYER_LOGIN")
local function first(prof, rank) local p = SP.RankPlaces(prof, rank)[1]; return p and p.npc.name, p end

-- Horde in Orgrimmar: Artisan Blacksmithing at Saru Steelfury
local name, p = first("Blacksmithing", "Artisan")
print("BS Artisan (Horde, Orgrimmar):", name, p and p.text)
assert(name == "Saru Steelfury", name)
-- Expert: a trainer teaching at least Expert, in Orgrimmar too
name = first("Blacksmithing", "Expert"); print("BS Expert:", name); assert(name)
-- every trainer listed is friendly to the Horde
for _, q in ipairs(SP.RankPlaces("Blacksmithing", "Journeyman")) do assert(q.npc.faction:find("H"), q.npc.name) end
-- First Aid: Expert is a book, Artisan the Triage quest
name, p = first("First Aid", "Expert"); print("FA Expert:", p.text); assert(name == "Balai Lok'Wein" and p.how == "book")
name, p = first("First Aid", "Artisan"); print("FA Artisan:", p.text); assert(name == "Doctor Gregory Victor" and p.how == "quest")
name, p = first("Fishing", "Expert"); print("Fishing Expert:", p.text); assert(name == "Old Man Heming")
name, p = first("Fishing", "Artisan"); print("Fishing Artisan:", p.text); assert(name == "Nat Pagle")
name, p = first("Cooking", "Artisan"); print("Cooking Artisan:", p.text); assert(name == "Dirge Quikcleave")
print("Mining Artisan:", (first("Mining", "Artisan")))
print("RankHow:", SP.RankHow("Blacksmithing", "Artisan"))

-- Alliance
FACTION = "Alliance"; HERE_MAP = 1453
name = first("Blacksmithing", "Artisan"); print("BS Artisan (Alliance):", name); assert(name and name ~= "Saru Steelfury")
name = first("First Aid", "Artisan"); print("FA Artisan (Alliance):", name); assert(name == "Doctor Gustaf VanHowzen")
name = first("First Aid", "Expert"); assert(name == "Deneb Walker", name)

-- pin
SP.Pin(SP.Npc(3355)); assert(PINNED and PINNED.map == 1454, "pin")

-- recipe sources: Beer Basted Boar Ribs (2795) is sold in Stormwind (Alliance)
local function kinds(id) local t = {} for _, s in ipairs(SP.RecipeSources(id)) do t[#t+1] = s.kind end return table.concat(t, ",") end
print("Boar Ribs, Alliance:", kinds(2795)); assert(kinds(2795):find("vendor"))
FACTION = "Horde"; HERE_MAP = 1454
print("Boar Ribs, Horde:", kinds(2795)); assert(not kinds(2795):find("vendor"))
for _, s in ipairs(SP.RecipeSources(2795)) do print("  ", SP.SourceText(s)) end
-- vendor recipes become plan candidates (Alliance can buy Beer Basted Boar Ribs)
FACTION = "Alliance"; HERE_MAP = 1453
C_TradeSkillUI.GetAllRecipeIDs = function() return { 2795 } end
C_TradeSkillUI.GetRecipeInfo = function(id) return { name = "Beer Basted Boar Ribs", learned = false, maxTrivialLevel = 60, numSkillUps = 1, icon = 1 } end
C_TradeSkillUI.GetRecipeSchematic = function(id) return { reagentSlotSchematics = { { required = true, reagentType = 1, quantityRequired = 1, reagents = { { itemID = 2677 } } } }, outputItemID = 2888, quantityMin = 1 } end
local c = SP.ScanCandidates({ name = "Cooking", id = 185, skill = 10, max = 75 })
assert(#c == 1 and c[1].how == "vendor" and c[1].where and c[1].where.name, "candidate")
print("candidate:", c[1].name, c[1].how, c[1].where.name, "learn at", c[1].learn, "cost", c[1].trainCost)
local plan = SP.MakePlan({ name = "Cooking", id = 185, skill = 25, max = 75 }, {}, SP.db, {}, c)
local st = plan.steps[1]
assert(st and st.learn and st.source == "vendor" and st.where, "step")
local text, npc = SP.LearnWhere(plan.prof, st)
print("plan step:", st.recipe.name, st.from .. "-" .. st.to, "learn from:", text)
assert(npc and npc.name == st.where.name)
-- the window at the First Aid cap shows who to see for Artisan, click pins
function UnitLevel() return 40 end
SP.UI:Show({ name = "First Aid", label = "First Aid", id = 129, skill = 225, max = 225 }, { atCap = true, shopping = {}, steps = {}, prep = {} })
local row = SP.UI.steps[1]
print("at cap:", row.text._text, "|", row.right._text, "|", SP.UI.frame.note._text)
assert(row._shown and row.pin and row.pin.name == "Doctor Gustaf VanHowzen", "cap row")
PINNED = nil; row:GetScript("OnClick")(row, "LeftButton"); assert(PINNED, "row click pins")
-- Horde can't buy it: no candidate
FACTION = "Horde"; HERE_MAP = 1454
assert(#SP.ScanCandidates({ name = "Cooking", id = 185, skill = 10, max = 75 }) == 0, "horde candidate")
print("ok")
''')
