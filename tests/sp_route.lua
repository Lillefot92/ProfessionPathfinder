ITEMS = { [2770]="Copper Ore",[2771]="Tin Ore",[2775]="Silver Ore",[2840]="Copper Bar",[3576]="Tin Bar",[2841]="Bronze Bar",[2842]="Silver Bar",
 [2835]="Rough Stone",[2836]="Coarse Stone",[3470]="Rough Grinding Stone",[3478]="Coarse Grinding Stone",[2838]="Heavy Stone",[3575]="Iron Bar",
 [3466]="Strong Flux",[2319]="Medium Leather",[2605]="Green Dye",[2880]="Weak Flux" }
OWNED = { [2770] = 40, [2835] = 10 }
AH = { [2770]=20,[2771]=30,[2775]=85,[2840]=40,[3576]=60,[2841]=80,[2842]=120,[2835]=5,[2836]=15,[2838]=30,[3575]=150,[2319]=50,[3470]=20 }
VENDOR = { [3466]=200,[2880]=100,[2605]=100 }
function UnitName() return "Tester" end
function GetRealmName() return "Forever" end
function GetProfessions() return 1, 2 end
function GetProfessionInfo(i) if i == 1 then return "Blacksmithing", nil, 0, 0, 0, 0, 164 end return "Mining", nil, 0, 0, 0, 0, 186 end
local PROF = "Mining"
local function diffAt(r, s) if s >= r.gray then return 3 end if s >= (r.yellow + r.gray) / 2 then return 2 end if s >= r.yellow then return 1 end return 0 end
local BOOK = {
	Mining = { skill = 108, max = 150, recipes = {
		[101] = { name = "Smelt Copper", gray = 75, yellow = 25, reagents = { { 2770, 1 } }, out = 2840 },
		[102] = { name = "Smelt Tin", gray = 100, yellow = 65, reagents = { { 2771, 1 } }, out = 3576 },
		[103] = { name = "Smelt Bronze", gray = 115, yellow = 65, reagents = { { 2840, 1 }, { 3576, 1 } }, out = 2841, outCount = 2 },
		[104] = { name = "Smelt Silver", gray = 125, yellow = 75, reagents = { { 2775, 1 } }, out = 2842 },
	} },
	Blacksmithing = { skill = 73, max = 150, recipes = {
		[201] = { name = "Rough Sharpening Stone", gray = 45, yellow = 15, reagents = { { 2835, 1 } } },
		[202] = { name = "Rough Grinding Stone", gray = 85, yellow = 45, reagents = { { 2835, 2 } }, out = 3470 },
		[203] = { name = "Copper Chain Belt", gray = 105, yellow = 70, reagents = { { 2840, 6 } } },
		[204] = { name = "Runed Copper Belt", gray = 130, yellow = 110, reagents = { { 2840, 10 } } },
		[205] = { name = "Coarse Grinding Stone", gray = 95, yellow = 75, reagents = { { 2836, 2 } }, out = 3478 },
		[206] = { name = "Heavy Copper Broadsword", gray = 155, yellow = 135, reagents = { { 2840, 14 }, { 2319, 2 } } },
	} },
}
C_TradeSkillUI.GetChildProfessionInfo = function() local b = BOOK[PROF]; return { professionName = PROF, professionID = (PROF == "Mining" and 186 or 164), skillLevel = b.skill, maxSkillLevel = b.max } end
C_TradeSkillUI.GetAllRecipeIDs = function() local ids = {} for id in pairs(BOOK[PROF].recipes) do ids[#ids+1] = id end table.sort(ids) return ids end
C_TradeSkillUI.GetRecipeInfo = function(id) local b = BOOK[PROF]; local r = b.recipes[id]; return { name = r.name, learned = true, relativeDifficulty = diffAt(r, b.skill), maxTrivialLevel = r.gray, numSkillUps = 1, icon = id, craftable = true } end
C_TradeSkillUI.GetRecipeSchematic = function(id)
	local r = BOOK[PROF].recipes[id]; local slots = {}
	for _, rg in ipairs(r.reagents) do slots[#slots+1] = { required = true, reagentType = 1, quantityRequired = rg[2], reagents = { { itemID = rg[1] } } } end
	return { reagentSlotSchematics = slots, outputItemID = r.out, quantityMin = r.outCount or 1 }
end
function SetProf(p) PROF = p end
function Learn(name, reagents, gray, yellow, out) local b = BOOK.Blacksmithing.recipes; local id = 300; while b[id] do id = id + 1 end b[id] = { name = name, gray = gray, yellow = yellow, reagents = reagents, out = out } end
