"""Recipes you're missing: at 300 the window lists what this character doesn't
know yet in the open profession, grouped easiest first (trainer, vendor,
reputation, quests, drops, ...), with where to get each one. Recipes only the
other faction can get and other specializations' recipes are left out."""
import os, re
from lupa import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__)); REPO = os.path.dirname(HERE)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(r'''
function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}
function UnitName() return "Brakka", "Ironhide" end function UnitFullName() return "Brakka", "Ironhide" end
FACTION = "Horde"
function UnitFactionGroup() return FACTION end
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Data.lua", "TrainerData.lua", "Sources.lua", "Trainer.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(REPO, fn)).read(), fn, ns)
lua.execute(r'''
local SP = ProfessionPathfinder
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder"); E(SP.eventFrame, "PLAYER_LOGIN")
-- the Cooking window: every Cooking recipe, a few of them learned
LEARNED = { [2538] = true, [2540] = true, [8604] = true }
C_TradeSkillUI = C_TradeSkillUI or {}
C_TradeSkillUI.GetAllRecipeIDs = function()
	local ids = {}
	for id in pairs(SP.DATA[185]) do ids[#ids + 1] = id end
	table.sort(ids)
	return ids
end
C_TradeSkillUI.GetRecipeInfo = function(id) return { recipeID = id, name = "Recipe " .. id, learned = LEARNED[id] or false } end
local prof = { name = "Cooking", id = 185, skill = 300, max = 300 }

local function Find(m, id)
	for key, list in pairs(m.groups) do
		for _, e in ipairs(list) do if e.id == id then return key, e end end
	end
end
local m = SP.MissingRecipes(prof)
print("known " .. m.known .. " of " .. m.total)
for _, key in ipairs(SP.MISSING_ORDER) do if m.groups[key] then print(key, #m.groups[key]) end end
assert(m.known == 3 and m.total > 60, m.total)
-- a vendor recipe: Mithril Headed Trout ("Recipe: Mithril Head Trout")
local g, e = Find(m, 20916)
assert(g == "vendor" and e.pin and e.where, tostring(g))
-- taught by Henry Stern in Razorfen Downs
g, e = Find(m, 13028)
assert(g == "world" and e.tips[1]:find("Henry Stern"), tostring(g))
-- a trainer recipe at 300: ready to learn now
local trainerNow = m.groups.now and m.groups.now[1]
assert(trainerNow and trainerNow.tips[1]:find("trainer"), "trainer recipes are ready now")
-- Beer Basted Boar Ribs: an Alliance vendor and an Alliance quest, so not for the Horde
assert(not Find(m, 2795), "Alliance-only recipe left out for the Horde")
FACTION = "Alliance"
local ma = SP.MissingRecipes(prof)
g = Find(ma, 2795)
assert(g == "vendor" or g == "quest", "the Alliance gets it: " .. tostring(g))
FACTION = "Horde"

-- the window: at 300 it opens on the missing recipes; the button goes back to the plan
SP.UI:Show(prof, { steps = {}, prep = {}, shopping = {}, total = 0, toLearn = {}, atCap = true, reached = 300 })
assert(SP.UI:MissingShown() and SP.UI.missingRows and #SP.UI.missingRows > 20)
local f = SP.UI.frame
assert(f.planHeader._text:find("you know 3 of"), f.planHeader._text)
assert(f.viewButton._text == "Plan", tostring(f.viewButton._text))
local first = SP.UI.steps[1]
assert(first._shown and first.text._text:find("Ready to learn now"), first.text._text)
-- scrolling moves the list
local before = SP.UI.steps[2].text._text
f:GetScript("OnMouseWheel")(f, -1)
assert(SP.UI.scroll == 3 and SP.UI.steps[2].text._text ~= before)
-- below 300 the plan stays, the button opens the list
SP.UI.profView = nil
SP.UI:Show({ name = "Cooking", id = 185, skill = 200, max = 225 }, nil)
assert(not SP.UI:MissingShown() and f.viewButton._text == "Missing")
-- a specialist's recipe isn't listed for someone without that specialization
LEARNED = {}
local bs = SP.MissingRecipes({ name = "Blacksmithing", id = 164, skill = 300, max = 300 })
C_TradeSkillUI.GetAllRecipeIDs = function()
	local ids = {}
	for id in pairs(SP.DATA[164]) do ids[#ids + 1] = id end
	return ids
end
bs = SP.MissingRecipes({ name = "Blacksmithing", id = 164, skill = 300, max = 300 })
assert(bs.otherSpec > 0 and not Find(bs, 9954), "Armorsmith/Weaponsmith recipes left out without the specialization")
print("other specializations left out: " .. bs.otherSpec .. ", Blacksmithing missing: " .. bs.total)
''')
print("missing ok")
if os.environ.get("PP_SHOW_UNKNOWN"):
    import json
    names = {}
    for i, n in re.findall(r'\[(\d+)\] = "([^"]+)"', open("/home/claude/export/sv.lua", encoding="utf-8", errors="replace").read()):
        names.setdefault(int(i), n)
    gg = json.load(open("/home/claude/wowgg/wowgg.json"))["cooking"]
    lua.execute("C_TradeSkillUI.GetAllRecipeIDs = function() local ids = {} for id in pairs(ProfessionPathfinder.DATA[185]) do ids[#ids + 1] = id end return ids end")
    m = lua.eval("ProfessionPathfinder.MissingRecipes({ name = 'Cooking', id = 185, skill = 300, max = 300 })")
    for e in (m.groups["unknown"] or {}).values():
        r = gg.get(str(e.id))
        print(e.id, names.get(e.id), lua.eval("function(id) local d = ProfessionPathfinder.DATA[185][id] return d[3] end")(e.id),
              "| wow.gg:", (r.get("source") or {}).get("n") if r and r.get("source") else ("trainer" if r else "NOT ON WOW.GG"),
              list((r.get("source") or {}).keys()) if r and r.get("source") else "")
