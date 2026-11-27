"""The trade camps: plans bought with Merchant's Favor from Durotar Supply and
Logistics (Horde) or Azeroth Commerce Authority (Alliance). Planned only with
enough Favor and reputation (and the option on); otherwise shown with what
they cost and how to earn Favor."""
import os
from lupa import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__)); REPO = os.path.dirname(HERE)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(r'''
function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}
function UnitName() return "Brakka", "Ironhide" end function UnitFullName() return "Brakka", "Ironhide" end
FACTION = "Horde"
function UnitFactionGroup() return FACTION end
STANDING, FAVOR = {}, 0
C_Reputation = { GetFactionDataByID = function(id)
	return { name = ({ [2587] = "Durotar Supply and Logistics", [2586] = "Azeroth Commerce Authority" })[id] or "Faction", reaction = (STANDING[id] or 3) + 1 }
end }
C_CurrencyInfo = { GetCurrencyInfo = function(id) if id == 3402 then return { name = "Merchant's Favor", quantity = FAVOR } end end }
NAMES = { [1252311] = "Sentinel's Sabatons", [1248752] = "Mystic Mushroom" }
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
local function First(id) return SP.RecipeSources(id)[1] end
assert(SP.db.favorPlans == true, "on by default")

-- Sentinel's Sabatons: 90 Favor, Honored with your trade company
STANDING[2587], FAVOR = 4, 100
local s = First(1252311)
assert(s.kind == "rep" and s.faction == 2587 and s.npc.name == "Gor'mak", s.kind)
print(SP.SourceText(s))
assert(SP.SourceText(s):find("Honored with Durotar Supply and Logistics") and SP.SourceText(s):find("90 Merchant's Favor"))

STANDING[2587], FAVOR = 5, 20
s = First(1252311)
assert(s.kind == "favor", "Honored but not enough Favor: " .. s.kind)
print(SP.SourceText(s))
assert(SP.SourceText(s):find("you have 20") and SP.SourceText(s):find("Dokimi"))

FAVOR = 90
s = First(1252311)
assert(s.kind == "vendor" and s.currency == 3402 and s.amount == 90, s.kind)
print(SP.SourceText(s))
assert(SP.SourceText(s):find("for 90 Merchant's Favor") and SP.SourceText(s):find("The Barrens"))

-- the option off: shown, not planned
SP.db.favorPlans = false
s = First(1252311)
assert(s.kind == "favor" and SP.SourceText(s):find("turned off"), s.kind)
SP.db.favorPlans = true

-- only plans that help leveling are in: Mystic Mushroom (Enchanting, 45 Favor) isn't
assert(First(1248752) == nil, "Mystic Mushroom doesn't help leveling")

-- Alliance: the Redridge camp and the Azeroth Commerce Authority
FACTION = "Alliance"; STANDING[2586] = 5; FAVOR = 90
s = First(1252311)
assert(s.kind == "vendor" and s.npc.name == "Stondry Darkhammer", s.kind .. " " .. s.npc.name)
FAVOR = 0
s = First(1252311)
assert(s.kind == "favor" and SP.SourceText(s):find("Marcy Baker"))
FACTION = "Horde"

-- the Favor a plan spends: each recipe once
local r1 = { id = 1, unlearned = true, how = "vendor", favor = 60 }
local r2 = { id = 2, unlearned = true, how = "vendor", favor = 45 }
local plan = { steps = { { recipe = r1, crafts = 5 }, { recipe = r1, crafts = 3 }, { recipe = r2, crafts = 2 } },
	prep = { { recipe = { id = 3, how = "trainer" }, crafts = 1 } } }
assert(SP.PlanFavor(plan) == 105, SP.PlanFavor(plan))

-- a learn line names the cost
local where = SP.LearnWhere({ name = "Blacksmithing" }, { source = "vendor", item = 251429, recipe = r1, where = SP.Npc(900011) })
print(where)
assert(where:find("Gor'mak") and where:find("60 Merchant's Favor"))

-- ways past: a camp plan you can't afford yet is offered
STANDING[2587], FAVOR = 5, 0
local found = false
for _, f in ipairs(SP.WaysPast({ id = 164, name = "Blacksmithing" }, 235, 5)) do
	print(SP.WayText(f))
	if f.src.kind == "favor" or (f.src.kind == "rep" and f.src.currency) then found = true end
end
assert(found, "a trade camp plan among the ways past")
-- the other new vendors: Mishta (Cenarion Circle), Mahu/Saenorion, Pexmit
STANDING[609] = 5
local m = First(1297121) -- Venomspew Cord
assert(m.kind == "vendor" and m.npc.name == "Mishta" and m.price == 75000, m.kind)
STANDING[609] = 3
assert(First(1297121).kind == "rep")
local k = First(1255096) -- Mystic Heavy Armor Kit
assert(k.kind == "vendor" and k.npc.name == "Mahu", k.npc and k.npc.name)
FACTION = "Alliance"; assert(First(1255096).npc.name == "Saenorion"); FACTION = "Horde"
assert(First(1257487).npc.name == "Pexmit") -- Runecloth Cuffs
print("camps ok")
''')
