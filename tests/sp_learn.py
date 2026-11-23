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
local L = SP.learnFrame:GetScript("OnEvent")
local function strip(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
onEvent(SP.eventFrame, "PLAYER_LOGIN"); L(SP.learnFrame, "PLAYER_LOGIN")
SP.db.useGuide = false
SetProf("Leatherworking"); onEvent(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers(); RunTimers()
-- level from 15 to 45 one point at a time: the addon watches colors change
for s = 15, 45 do SetSkill("Leatherworking", s, 75); SP.RequestRefresh(); RunTimers() end
for id, e in pairs(SP.db.learn) do print(string.format("recipe %d: gray %s yellow %s%s green %s%s", id, tostring(e.gray), tostring(e.yellow), e.yellowExact and "!" or "~", tostring(e.green), e.greenExact and "!" or "~")) end
print("span Light Armor Kit:", SP.Span(SP.recipeIndex[402]))
-- craft Light Armor Kit 6 times at 45 (yellow): 3 skill-ups
local skill = 45
for i = 1, 6 do
  L(SP.learnFrame, "UNIT_SPELLCAST_START", "player", "g", 402)
  if i % 2 == 0 then skill = skill + 1; SetSkill("Leatherworking", skill, 75) end
  L(SP.learnFrame, "UNIT_SPELLCAST_SUCCEEDED", "player", "g", 402)
  RunTimers()
end
RunTimers(); RunTimers()
local e = SP.db.learn[402]
for d, lg in pairs(e.log or {}) do print("log color " .. d .. ": " .. lg.u .. "/" .. lg.c) end
SP.RequestRefresh(); RunTimers()
local r = SP.recipeIndex[402]
print(string.format("chance now (skill %d, %s): %.2f", skill, r.diff, SP.Chance(r, skill, skill)))
-- Working Overtime 3 (Legacy Coach)
LegacyCoach = { ReadRanks = function() return { ["Working Overtime"] = 3 }, 3 end }
GetTime = function() return 1000 end
print(string.format("with Working Overtime 3: %.2f", SP.Chance(r, skill, skill)))
-- other characters
BankBuddyDB = { inv = { ["Bankalt-Forever"] = { name = "Bankalt", bags = { [2318] = 5 }, bank = { [2318] = 20 } }, [SP.MyKey()] = { name = "me", bags = { [2318] = 99 } } } }
-- guide mode with Overtime
SP.db.useGuide = true; SetSkill("Leatherworking", 45, 75); OWNED[2318] = 0; SP.db.bagsFree = true; SP.RequestRefresh(); RunTimers()
print("sub: " .. strip(SP.UI.frame.sub._text))
for _, st in ipairs(SP.lastPlan.steps) do print(string.format("  %-28s %d-%d ~%d %s", st.recipe.name, st.from, st.to, st.crafts, tostring(st.adjusted))) end
for i, row in ipairs(SP.UI.items) do if row._shown and row.text._text then print("  BUY " .. strip(row.text._text)) end end
''')
