-- Mining (smelting) then Blacksmithing
ITEMS = { [2770] = "Copper Ore", [2840] = "Copper Bar", [2835] = "Rough Stone", [2862] = "Rough Sharpening Stone", [2880] = "Weak Flux" }
OWNED = { [2770] = 30 }
AH = { [2840] = 40, [2770] = 20, [2835] = 5 }
VENDOR = { [2880] = 100 }
function UnitName() return "Tester" end
function GetRealmName() return "Forever" end
function GetProfessions() return 1, 2 end
function GetProfessionInfo(i) if i == 1 then return "Blacksmithing", nil, 0, 0, 0, 0, 164 end return "Mining", nil, 0, 0, 0, 0, 186 end
local PROF = "Mining"
local function diffAt(r, s)
	if s >= r.gray then return 3 end
	if s >= (r.yellow + r.gray) / 2 then return 2 end
	if s >= r.yellow then return 1 end
	return 0
end
local BOOK = {
	Mining = { skill = 60, max = 75, recipes = {
		[101] = { name = "Smelt Copper", gray = 50, yellow = 25, reagents = { { 2770, 1 } }, out = 2840 },
	} },
	Blacksmithing = { skill = 30, max = 75, recipes = {
		[201] = { name = "Rough Sharpening Stone", gray = 45, yellow = 15, reagents = { { 2835, 1 } }, out = 2862 },
		[202] = { name = "Copper Bracers", gray = 50, yellow = 20, reagents = { { 2840, 2 } } },
		[203] = { name = "Copper Chain Belt", gray = 70, yellow = 35, reagents = { { 2840, 6 } } },
		[204] = { name = "Copper Chain Pants", gray = 75, yellow = 50, reagents = { { 2840, 4 } } },
		[205] = { name = "Runed Copper Gauntlets", gray = 85, yellow = 65, reagents = { { 2840, 8 }, { 2880, 2 } } },
	} },
}
C_TradeSkillUI.GetChildProfessionInfo = function() local b = BOOK[PROF]; return { professionName = PROF, skillLevel = b.skill, maxSkillLevel = b.max } end
C_TradeSkillUI.GetAllRecipeIDs = function() local ids = {} for id in pairs(BOOK[PROF].recipes) do ids[#ids+1] = id end table.sort(ids) return ids end
C_TradeSkillUI.GetRecipeInfo = function(id) local b = BOOK[PROF]; local r = b.recipes[id]; return { name = r.name, learned = true, relativeDifficulty = diffAt(r, b.skill), maxTrivialLevel = r.gray, numSkillUps = 1, icon = id, craftable = true } end
C_TradeSkillUI.GetRecipeSchematic = function(id)
	local r = BOOK[PROF].recipes[id]; local slots = {}
	for _, rg in ipairs(r.reagents) do slots[#slots+1] = { required = true, reagentType = 1, quantityRequired = rg[2], reagents = { { itemID = rg[1] } } } end
	return { reagentSlotSchematics = slots, outputItemID = r.out, quantityMin = 1 }
end
function SetProf(p) PROF = p end
