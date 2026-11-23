local function Mock(name)
	local o = { _shown = false }
	return setmetatable(o, { __index = function(t, k)
		if k == "IsShown" then return function(self) return self._shown end end
		if k == "Show" then return function(self) self._shown = true end end
		if k == "Hide" then return function(self) self._shown = false end end
		if k == "SetText" then return function(self, v) self._text = v end end
		if k == "SetScript" then return function(self, n, f) rawset(self, "_s_" .. n, f) end end
		if k == "GetScript" then return function(self, n) return rawget(self, "_s_" .. n) end end
		if k:match("^Create") then return function() return Mock(k) end end
		if k:match("^%l") then return nil end -- fields (lowercase) aren't methods
		return function() end
	end })
end
function CreateFrame(_, name) local f = Mock(name); if name then _G[name] = f end; return f end
UIParent = Mock("UIParent"); GameTooltip = Mock("GameTooltip")
TIMERS = {}
C_Timer = { After = function(d, fn) TIMERS[#TIMERS + 1] = fn end }
function RunTimers() local t = TIMERS; TIMERS = {}; for _, fn in ipairs(t) do fn() end end
function print(...) local t = {} for i=1,select("#", ...) do t[#t+1]=tostring(select(i, ...)) end io.write((table.concat(t, " "):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")), "\n") end
SlashCmdList = {}
Enum = { TradeskillRelativeDifficulty = { Optimal = 0, Medium = 1, Easy = 2, Trivial = 3 }, CraftingReagentType = { Basic = 1 } }

ITEMS = { [2589] = "Linen Cloth", [2320] = "Coarse Thread", [2996] = "Bolt of Linen Cloth", [2321] = "Fine Thread" }
OWNED = { [2589] = 20 }
AH = { [2589] = 15, [2996] = 60, [2321] = 200 }
VENDOR = { [2320] = 10, [2321] = 100 }
C_Item = {
	GetItemNameByID = function(id) return ITEMS[id] end,
	GetItemIconByID = function(id) return id end,
	GetItemCount = function(id) return OWNED[id] or 0 end,
}
Auctionator = { API = { v1 = {
	GetAuctionPriceByItemID = function(c, id) return AH[id] end,
	GetVendorPriceByItemID = function(c, id) return VENDOR[id] end,
	ConvertToSearchString = function(c, t) return '"' .. t.searchString .. '";;;;;;;;;;;;;' .. t.quantity end,
	CreateShoppingList = function(c, name, terms) CREATED = { name = name, terms = terms } end,
} } }

SKILL = 40
RECIPES = {
	[1] = { name = "Bolt of Linen Cloth", gray = 50, yellow = 25, reagents = { { 2589, 2 } }, out = 2996 },
	[2] = { name = "Linen Bag", gray = 70, yellow = 55, reagents = { { 2996, 3 }, { 2320, 3 } } },
	[3] = { name = "Heavy Linen Gloves", gray = 75, yellow = 60, reagents = { { 2996, 2 }, { 2320, 2 } } },
	[4] = { name = "Reinforced Linen Cape", gray = 85, yellow = 70, reagents = { { 2996, 2 }, { 2320, 3 } } },
	[5] = { name = "Linen Cloak", gray = 45, yellow = 30, reagents = { { 2996, 1 }, { 2320, 1 } } },
}
local function diffAt(r, s)
	if s >= r.gray then return 3 end
	local green = (r.yellow + r.gray) / 2
	if s >= green then return 2 end
	if s >= r.yellow then return 1 end
	return 0
end
C_TradeSkillUI = {
	GetChildProfessionInfo = function() return { professionName = "Tailoring", skillLevel = SKILL, maxSkillLevel = 75 } end,
	GetAllRecipeIDs = function() return { 1, 2, 3, 4, 5 } end,
	GetRecipeInfo = function(id) local r = RECIPES[id]; return { name = r.name, learned = true, relativeDifficulty = diffAt(r, SKILL), maxTrivialLevel = r.gray, numSkillUps = 1, icon = id, craftable = true } end,
	GetRecipeSchematic = function(id)
		local r = RECIPES[id]; local slots = {}
		for _, rg in ipairs(r.reagents) do slots[#slots+1] = { required = true, reagentType = 1, quantityRequired = rg[2], reagents = { { itemID = rg[1] } } } end
		return { reagentSlotSchematics = slots, outputItemID = r.out, quantityMin = 1 }
	end,
	OpenRecipe = function(id) OPENED = id end,
}
