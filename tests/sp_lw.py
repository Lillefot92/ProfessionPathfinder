import os
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open("sp_harness.lua").read())
route = open("sp_route.lua").read()
lw = '''	Leatherworking = { skill = 1, max = 75, recipes = {
		[401] = { name = "Light Leather", gray = 40, yellow = 20, reagents = { { 2934, 3 } }, out = 2318 },
		[402] = { name = "Light Armor Kit", gray = 60, yellow = 30, reagents = { { 2318, 1 } } },
		[403] = { name = "Handstitched Leather Boots", gray = 55, yellow = 40, reagents = { { 2318, 2 }, { 2320, 1 } } },
	} },
}
C_TradeSkillUI.GetChildProfessionInfo'''
route = route.replace("}\nC_TradeSkillUI.GetChildProfessionInfo", lw, 1)
route += '''
function LearnLW(name, reagents, gray, yellow, out) local b = BOOK.Leatherworking.recipes; local id = 450; while b[id] do id = id + 1 end b[id] = { name = name, gray = gray, yellow = yellow, reagents = reagents, out = out } end
function SetSkill(p, s, m) BOOK[p].skill = s; BOOK[p].max = m or BOOK[p].max end
ITEMS[2934] = "Ruined Leather Scraps"; ITEMS[2318] = "Light Leather"; ITEMS[2320] = "Coarse Thread"; ITEMS[783] = "Light Hide"; ITEMS[4289] = "Salt"
ITEMS[2321] = "Fine Thread"; ITEMS[4340] = "Gray Dye"; ITEMS[4246] = "Fine Leather Belt"; ITEMS[4233] = "Cured Medium Hide"; ITEMS[4235] = "Heavy Hide"
AH[2934] = 10; AH[2318] = 40; AH[2319] = 80; AH[783] = 60; AH[4246] = 900; AH[4233] = 300; AH[4235] = 250
VENDOR[2320] = 10; VENDOR[4289] = 50; VENDOR[2321] = 100; VENDOR[4340] = 125
OWNED[2318] = 12
'''
lua.execute(route)
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute('''
local SP = ProfessionPathfinder
local onEvent = SP.eventFrame:GetScript("OnEvent")
local function strip(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function show(plan)
  print(string.format("%s %d -> %d (reached %s)  total %s  guide=%s", plan.prof.name, plan.from, plan.to, tostring(plan.reached), SP.Money(plan.total), tostring(plan.guide and plan.guide.name)))
  for _, s in ipairs(plan.steps) do print(string.format("  %-26s %3d-%3d  ~%2d crafts %s %s", s.recipe.name, s.from, s.to, s.crafts, s.learn and "(learn)" or "", s.learn and s.source or "")) end
  for _, p in ipairs(plan.prep) do print(string.format("  MAKE %-22s ~%d", p.recipe.name, p.crafts)) end
  for _, i in ipairs(plan.shopping) do print(string.format("  BUY %4dx %-22s %s", i.count, i.name or ITEMS[i.itemID] or tostring(i.itemID), SP.Money(i.cost))) end
  print("  note: " .. strip(SP.UI.frame.note._text))
  print("  sub: " .. strip(SP.UI.frame.sub._text))
end
onEvent(SP.eventFrame, "PLAYER_LOGIN")
print("== Leatherworking 1/75 ==")
SetProf("Leatherworking"); onEvent(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers(); RunTimers(); show(SP.lastPlan)
print("== Leatherworking 100/150, knows Fine Leather Belt and Dark Leather Pants ==")
SetSkill("Leatherworking", 100, 150)
LearnLW("Fine Leather Belt", { { 2318, 6 }, { 2320, 2 } }, 120, 80, 4246)
LearnLW("Dark Leather Pants", { { 2319, 12 }, { 4340, 1 }, { 2321, 1 } }, 135, 115)
SP.RequestRefresh(); RunTimers(); show(SP.lastPlan)
''')
