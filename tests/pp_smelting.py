"""Mining: when to train a rank and when to learn a smelt. Smelts use the
skill a trainer really teaches them at (wow.gg), not their colors: Smelt Tin
at 65 (yellow from 50), Smelt Silver at 75 (orange until 100). The gathering
view says which smelts give skill now and which one to learn, and a new smelt
you can learn gets a chat reminder once."""
import os
from lupa import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__)); REPO = os.path.dirname(HERE)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(REPO, "tests/sp_harness.lua")).read())
lua.execute("""function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}
function UnitName() return 'Tester','Part' end function UnitFullName() return 'Tester','Part' end function GetRealmName() return 'Forever' end
function UnitFactionGroup() return 'Horde' end
LEVEL = 39 function UnitLevel() return LEVEL end
SKILL, MAX = 213, 225
NAMES = { [2657]="Smelt Copper", [3304]="Smelt Tin", [2659]="Smelt Bronze", [2658]="Smelt Silver", [3307]="Smelt Iron", [3308]="Smelt Gold", [3569]="Smelt Steel", [10097]="Smelt Mithril", [10098]="Smelt Truesilver", [16153]="Smelt Thorium", [14891]="Smelt Dark Iron", [22967]="Smelt Elementium", [1230161]="Smelt Forever", [1249637]="Smelt New275" }
KNOWN = {}
C_Spell = { GetSpellName = function(id) return NAMES[id] end }
function IsPlayerSpell(id) return KNOWN[id] == true end
function GetProfessions() return nil, nil, 1, nil, nil, nil end
function GetProfessionInfo(i) return 'Mining', 136248, SKILL, MAX, 0, 0, 186 end""")
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Data.lua", "TrainerData.lua", "Sources.lua", "Trainer.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(REPO, fn)).read(), fn, ns)
lua.execute(r"""
local SP = ProfessionPathfinder
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder"); E(SP.eventFrame, "PLAYER_LOGIN")
local said = {}
_G.print = function(...) said[#said+1] = table.concat({...}, " ") end
function Show(skill, max, level, known)
  KNOWN = {}
  for _, id in ipairs(known or {}) do KNOWN[id] = true end
  SKILL, MAX, LEVEL = skill, max, level
  said = {}; SP.db.said = {}
  SP.CheckAllRanks()
  SP.UI:Open() SP.UI.view = nil SP.UI:ShowGathering()
  local out = { "== Mining " .. skill .. "/" .. max .. ", level " .. level }
  for _, row in ipairs(SP.UI.steps) do
    if row._shown then out[#out+1] = "  row: " .. (row.text._text or "") .. "   [" .. (row.right._text or "") .. "]" end
  end
  for _, s in ipairs(said) do out[#out+1] = "  chat: " .. s end
  return table.concat(out, "\n")
end
""")
G = lua.globals()
import re
def show(skill, mx, level, known):
    return re.sub(r"\|c[0-9a-f]{8}|\|r", "", G.Show(skill, mx, level, lua.table_from(known)))
lua.execute("""
local SP = ProfessionPathfinder
local want = { [3304]=65, [2659]=65, [2658]=75, [3307]=125, [3308]=155, [10097]=175, [10098]=230, [16153]=250 }
for id, at in pairs(want) do
  local got, how = SP.LearnAt(id, 186)
  assert(got == at and how == "maybe" and SP.TrainerChecked(id, 186), id .. ": " .. tostring(got) .. " " .. tostring(how))
end
assert(select(2, SP.LearnAt(14891, 186)) ~= "maybe", "Smelt Dark Iron needs the Black Forge")
""")
t = show(100, 150, 15, [2657, 3304, 2659])
assert "Learn Smelt Silver now from Brek Stonehoof" in t, t
assert "Smelt for skill: Smelt Bronze" in t, t
assert "chat: Profession Pathfinder: you can learn Smelt Silver (Mining) now" in t, t
t = show(160, 225, 30, [2657, 3304, 2659, 2658, 3307])
assert "Learn Smelt Gold now" in t and "you can learn Smelt Gold (Mining) now" in t, t
t = show(213, 225, 39, [2657, 3304, 2659, 2658, 3307, 3308, 3569, 10097])
assert "Next smelt: Smelt Truesilver at 230" in t and "Train Artisan now" in t, t
assert "Learn Smelt" not in t, t
print("smelting ok")
