import os
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open("sp_harness.lua").read())
route = open("sp_route.lua").read()
extra = '''	Enchanting = { skill = 15, max = 75, recipes = {
		[501] = { name = "Runed Copper Rod", gray = 5, yellow = 1, reagents = { { 6217, 1 } } },
	} },
	Tailoring = { skill = 200, max = 225, recipes = {
		[601] = { name = "Black Mageweave Gloves", gray = 215, yellow = 195, reagents = { { 4339, 2 }, { 8343, 2 } } },
	} },
	Alchemy = { skill = 1, max = 75, recipes = {
		[701] = { name = "Elixir of Minor Force", gray = 40, yellow = 10, reagents = { { 765, 1 }, { 3371, 1 } } },
		[702] = { name = "Elixir of Minor Defense", gray = 60, yellow = 30, reagents = { { 765, 1 }, { 2447, 1 }, { 3371, 1 } } },
	} },
}
C_TradeSkillUI.GetChildProfessionInfo'''
route = route.replace("}\nC_TradeSkillUI.GetChildProfessionInfo", extra, 1)
route += '''
function SetSkill(p, s, m) BOOK[p].skill = s; BOOK[p].max = m or BOOK[p].max end
PROFS = { { "Blacksmithing", 73, 150 }, { "Mining", 140, 150 }, { "Skinning", 142, 150 }, { "Fishing", 30, 75 } }
function GetProfessions() return 2, 3, nil, 4, nil end
function GetProfessionInfo(i) local p = PROFS[i] or PROFS[3]; return p[1], "icon", p[2], p[3], 0, 0, 0 end
PROFS[4] = { "Fishing", 30, 75 }
function UnitFactionGroup() return "Horde" end
AH[765] = 20; AH[2447] = 15; VENDOR[3371] = 4
'''
lua.execute(route)
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute('''
function UnitClass() return "Warrior", "WARRIOR" end
function UnitLevel() return LVL or 25 end
time = os.time
RAID_CLASS_COLORS = { WARRIOR = { colorStr = "ffc79c6e" }, HUNTER = { colorStr = "ffaad372" } }
local SP = ProfessionPathfinder
local onEvent = SP.eventFrame:GetScript("OnEvent")
local function strip(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end
local function all()
  local f = SP.UI.frame
  print("sub:", strip(f.sub._text), "| button:", strip(f.craftButton._text), "| legacy:", strip(f.legacy._text))
  for _, list in ipairs({ SP.UI.steps, SP.UI.makes, SP.UI.items }) do
    for i, r in ipairs(list) do if r._shown then
      print(string.format("  %-66s %s", strip(r.text._text), strip(r.right._text)))
      local t = rawget(r, "tip"); if t and list == SP.UI.items then print("      " .. strip(t[#t])) end
    end end
  end
  print("  note: " .. strip(f.note._text))
end
onEvent(SP.eventFrame, "PLAYER_LOGIN"); RunTimers()
print("== Blacksmithing 73/150, Mining 140 ==")
SetProf("Blacksmithing"); onEvent(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers(); RunTimers()
all()
print("== Blacksmithing 130/150 (Expert ready), level 15 ==")
LVL = 15; SetSkill("Blacksmithing", 130, 150); SP.RequestRefresh(); RunTimers(); RunTimers()
print("  note: " .. strip(SP.UI.frame.note._text))
print("== at cap 150/150, level 25 ==")
LVL = 25; SetSkill("Blacksmithing", 150, 150); SP.RequestRefresh(); RunTimers(); RunTimers()
print("  note: " .. strip(SP.UI.frame.note._text), "| button:", strip(SP.UI.frame.craftButton._text))
onEvent(SP.eventFrame, "TRADE_SKILL_CLOSE")
-- another character (the Hunter)
SP.db.chars["Lazlo-Realm"] = { name = "Lazlo", class = "HUNTER", level = 12, profs = { Skinning = { skill = 80, max = 150 }, Leatherworking = { skill = 45, max = 75 } }, next = { Leatherworking = { recipe = "Light Armor Kit", from = 45, to = 55 } } }
print("== /sup chars ==")
SlashCmdList.PROFESSIONPATHFINDER("chars"); RunTimers(); RunTimers()
all()
print("== toggle back to gathering ==")
SP.UI.frame.viewButton:GetScript("OnClick")(); RunTimers()
print("sub:", strip(SP.UI.frame.sub._text), "view button:", SP.UI.frame.viewButton._text)
''')
