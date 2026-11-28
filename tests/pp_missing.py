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
-- colors above the 300 cap aren't shown (Smelt Elementium: orange until 310 in the data)
assert(SP.SkillUpsText(310, 320) == "Skill-ups: orange all the way to 300.")
assert(SP.SkillUpsText(280, 310):find("up to 300"))
assert(SP.SkillUpsText(175, 215) == "Skill-ups: orange until 175, gray from 215.")
-- gather & craft mode: the Auctionator button explains why there's nothing to buy
Auctionator = { API = { v1 = { CreateShoppingList = function() end } } }
local gplan = { selfGather = true, shopping = { { itemID = 1, source = "vendor", count = 1 }, { itemID = 2, gather = "mine", count = 3 } } }
assert(SP.AuctionItems(gplan) == 0)
local okx, msg = SP.ExportToAuctionator(gplan)
assert(not okx and msg:find("gather & craft mode is on"), tostring(msg))
-- every profession, both factions: the list and the window build without errors
for _, fac in ipairs({ "Horde", "Alliance" }) do
	FACTION = fac
	for line, name in pairs({ [129] = "First Aid", [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy",
		[185] = "Cooking", [186] = "Mining", [197] = "Tailoring", [202] = "Engineering", [333] = "Enchanting" }) do
		C_TradeSkillUI.GetAllRecipeIDs = function()
			local ids = {}
			for id in pairs(SP.DATA[line]) do ids[#ids + 1] = id end
			return ids
		end
		local p = { name = name, id = line, skill = 300, max = 300 }
		local list = SP.MissingRecipes(p)
		assert(list.total > 10, name)
		SP.UI.profView = nil
		SP.UI:Show(p, { steps = {}, prep = {}, shopping = {}, total = 0, toLearn = {}, atCap = true, reached = 300 })
		assert(SP.UI.missingRows and #SP.UI.missingRows > 5, name)
	end
end
''')
print("missing ok")
