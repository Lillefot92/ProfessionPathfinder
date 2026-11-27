-- Profession Pathfinder - Core
-- Reads the open profession window (WoW Forever uses the retail
-- C_TradeSkillUI API), your bags and bank, and prices from Auctionator.

local ADDON, SP = ...
_G.ProfessionPathfinder = SP
-- The version comes from the .toc file, so it's set in one place
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local tocVersion = GetMeta and GetMeta(ADDON, "Version")
SP.version = (type(tocVersion) == "string" and not tocVersion:find("@")) and tocVersion or "dev"

SP.defaults = {
	target = 0,          -- 0 = the current skill cap (next trainer rank)
	favorPlans = true,   -- plan the trade camps' plans when you have the Merchant's Favor
	bagsFree = true,     -- materials you already have count as free
	resale = "vendor",   -- count what you get back for what you craft: "off", "vendor" or "best" (vendor or Auction House)
	netPick = false,     -- pick recipes by cost after selling (off: by what you pay now)
	selfGather = false,  -- gather & craft: only what you gather yourself and vendor items
	point = nil,         -- saved window position when detached
	shown = true,
	scale = 1,           -- planner window size
}

local pcall, ipairs, pairs, type, floor = pcall, ipairs, pairs, type, math.floor

local function Plain(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end
SP.Plain = Plain

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
function SP.ItemName(itemID)
	local name
	if C_Item and C_Item.GetItemNameByID then name = C_Item.GetItemNameByID(itemID) end
	if not name and C_Item and C_Item.RequestLoadItemDataByID then
		pcall(C_Item.RequestLoadItemDataByID, itemID)
		SP.waitingForItems = true
	end
	return name or ("item " .. itemID)
end

function SP.ItemIcon(itemID)
	if C_Item and C_Item.GetItemIconByID then return C_Item.GetItemIconByID(itemID) end
end

-- How many you own: bags, bank and reagent bag.
function SP.Owned(itemID)
	if C_Item and C_Item.GetItemCount then
		local ok, n = pcall(C_Item.GetItemCount, itemID, true, false, true)
		if ok and type(n) == "number" then return n end
	end
	return 0
end

---------------------------------------------------------------------------
-- Prices (copper). Auctionator's last scan, or its cached vendor price for
-- things merchants sell (thread, flux, vials), whichever is lower.
---------------------------------------------------------------------------
local CALLER = "Profession Pathfinder"

function SP.HasAuctionator()
	return Auctionator and Auctionator.API and Auctionator.API.v1 and true or false
end

function SP.Price(itemID)
	local best, source
	if SP.HasAuctionator() then
		local api = Auctionator.API.v1
		local ok, ah = pcall(api.GetAuctionPriceByItemID, CALLER, itemID)
		if ok and type(ah) == "number" and ah > 0 then best, source = ah, "ah" end
		if api.GetVendorPriceByItemID then
			local okV, vendor = pcall(api.GetVendorPriceByItemID, CALLER, itemID)
			if okV and type(vendor) == "number" and vendor > 0 and (not best or vendor < best) then
				best, source = vendor, "vendor"
			end
		end
	end
	return best, source
end

-- What a merchant pays you for an item (copper), from the game's item data
function SP.SellPrice(itemID)
	if not itemID then return end
	local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	if get then
		local ok, sell = pcall(function() return select(11, get(itemID)) end)
		sell = Plain(sell)
		if ok and type(sell) == "number" then return sell end
	end
	if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
end

-- What you get back for one crafted item. mode "vendor": a merchant's price;
-- "best": that or the Auction House price after the 5% cut, whichever is more.
local AH_CUT = 0.95
function SP.ResaleValue(itemID, mode)
	mode = mode or (SP.db and SP.db.resale) or "off"
	if mode == "off" or not itemID then return 0 end
	local value, source = SP.SellPrice(itemID) or 0, "vendor"
	if mode == "best" and SP.HasAuctionator() then
		local ok, ah = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, CALLER, itemID)
		if ok and type(ah) == "number" and ah * AH_CUT > value then value, source = ah * AH_CUT, "ah" end
	end
	return value, value > 0 and source or nil
end

function SP.Money(copper)
	if not copper then return "|cff999999?|r" end
	copper = floor(copper + 0.5)
	if GetCoinTextureString then return GetCoinTextureString(copper) end
	local g, s, c = floor(copper / 10000), floor(copper / 100) % 100, copper % 100
	if g > 0 then return g .. "g " .. s .. "s" end
	if s > 0 then return s .. "s " .. c .. "c" end
	return c .. "c"
end

---------------------------------------------------------------------------
-- Profession window
---------------------------------------------------------------------------
local DIFF = (Enum and Enum.TradeskillRelativeDifficulty) or { Optimal = 0, Medium = 1, Easy = 2, Trivial = 3 }
SP.DIFF = DIFF

-- Professions by skill line ID. The addon keys its own tables by these
-- English names; what the game calls them (any language) is only shown.
SP.PROF_KEY = { [129] = "First Aid", [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy",
	[182] = "Herbalism", [185] = "Cooking", [186] = "Mining", [197] = "Tailoring", [202] = "Engineering",
	[333] = "Enchanting", [356] = "Fishing", [393] = "Skinning" }
function SP.ProfKey(line, name)
	return SP.PROF_KEY[line or 0] or name
end

-- The profession's main skill line (164 for Blacksmithing). Opening a recipe
-- (the craft button, a click on a plan step) can switch the window to a
-- sub skill line with another ID, and the recipe data is keyed by the main
-- one, so look for it in the child's ID, its parent's, the base profession's
-- and finally the last one seen for this profession.
local NAME_LINE = {}
for line, name in pairs(SP.PROF_KEY) do NAME_LINE[name] = line end
local lastLine = {}
function SP.ProfLine(info, label)
	local T = C_TradeSkillUI
	local base
	if T and T.GetBaseProfessionInfo then
		local ok, b = pcall(T.GetBaseProfessionInfo)
		if ok and type(b) == "table" then base = b end
	end
	for _, id in ipairs({ info.professionID or false, info.parentProfessionID or false,
		base and base.professionID or false, base and base.parentProfessionID or false }) do
		if id and SP.PROF_KEY[id] then
			if label then lastLine[label] = id end
			return id
		end
	end
	return (label and (lastLine[label] or NAME_LINE[label])) or info.professionID
end

-- Seconds one craft takes (its cast time; 3 if the game doesn't say)
local castCache = {}
function SP.CastSeconds(recipeID)
	if castCache[recipeID] then return castCache[recipeID] end
	local t
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, recipeID)
		if ok and type(info) == "table" and type(info.castTime) == "number" and info.castTime > 0 then t = info.castTime / 1000 end
	end
	if not t and GetSpellInfo then
		local ok, _, _, _, cast = pcall(GetSpellInfo, recipeID)
		if ok and type(cast) == "number" and cast > 0 then t = cast / 1000 end
	end
	t = t or 3
	castCache[recipeID] = t
	return t
end

-- "about 25 min", "about 1 h 10 min"
function SP.Duration(seconds)
	local m = math.max(1, math.floor(seconds / 60 + 0.5))
	if m < 60 then return "about " .. m .. " min" end
	local h, rest = math.floor(m / 60), m % 60
	return "about " .. h .. " h" .. (rest > 0 and (" " .. rest .. " min") or "")
end

-- The open window's profession worked out from its recipes (most of them in
-- one profession's data), with skill from GetProfessions
function SP.ProfessionFromRecipes()
	local T = C_TradeSkillUI
	if not (T and T.GetAllRecipeIDs and SP.DATA) then return end
	local ok, ids = pcall(T.GetAllRecipeIDs)
	if not ok or type(ids) ~= "table" or #ids == 0 then return end
	local count, best, most = {}, nil, 0
	for _, id in ipairs(ids) do
		for line, data in pairs(SP.DATA) do
			if data[id] then
				count[line] = (count[line] or 0) + 1
				if count[line] > most then best, most = line, count[line] end
			end
		end
	end
	if not best or most * 2 < #ids then return end
	if not (GetProfessions and GetProfessionInfo) then return end
	local t = { pcall(GetProfessions) }
	if not t[1] then return end
	for i = 2, 7 do
		local idx = t[i]
		if idx then
			local okI, name, _, skill, max, _, _, line = pcall(GetProfessionInfo, idx)
			if okI and line == best and type(skill) == "number" and (max or 0) > 0 then
				lastLine[name] = best
				return { name = SP.ProfKey(best, name), label = name, id = best, skill = skill, max = max, fallback = true }
			end
		end
	end
end

-- The profession currently open: key (English), label (as the game calls
-- it), skill, max skill.
function SP.ProfessionInfo()
	local T = C_TradeSkillUI
	if not T then return end
	local info
	if T.GetChildProfessionInfo then
		local ok, i = pcall(T.GetChildProfessionInfo)
		if ok and type(i) == "table" and i.skillLevel then info = i end
	end
	if (not info or not info.maxSkillLevel or info.maxSkillLevel == 0) and T.GetBaseProfessionInfo then
		local ok, i = pcall(T.GetBaseProfessionInfo)
		if ok and type(i) == "table" and i.skillLevel then info = i end
	end
	-- Right after the window opens the game can give an empty profession
	-- (no name, 0/0). Then: which profession its recipes belong to, and the
	-- skill from your character's profession list.
	local empty = not info or ((info.maxSkillLevel or 0) == 0 and (info.professionName or "") == "")
	if empty then
		local fb = SP.ProfessionFromRecipes()
		if fb then return fb end
	end
	if not info then return end
	local label = info.professionName or info.parentProfessionName or "Profession"
	local id = SP.ProfLine(info, label)
	return {
		name = SP.ProfKey(id, label),
		label = label,
		id = id,
		enum = info.profession,
		skill = info.skillLevel or 0,
		max = info.maxSkillLevel or 0,
	}
end

-- Every learned recipe that can still give skill: difficulty, gray level,
-- required reagents and what it makes.
-- Materials and what a recipe makes, from the game
local function ReadSchematic(recipe)
	local T = C_TradeSkillUI
	local okS, s = pcall(T.GetRecipeSchematic, recipe.id, false)
	if not (okS and type(s) == "table") then return end
	for _, slot in ipairs(s.reagentSlotSchematics or {}) do
		local basic = (slot.required ~= false)
			and (slot.reagentType == nil or slot.reagentType == 1
				or (Enum and Enum.CraftingReagentType and slot.reagentType == Enum.CraftingReagentType.Basic))
		local first = slot.reagents and slot.reagents[1]
		if basic and first and first.itemID and (slot.quantityRequired or 0) > 0 then
			recipe.reagents[#recipe.reagents + 1] = { itemID = first.itemID, count = slot.quantityRequired }
		end
	end
	if s.outputItemID and s.outputItemID > 0 then
		recipe.output = s.outputItemID
		recipe.outputCount = s.quantityMin or 1
	end
end

-- Colors from the built-in data: yellow where Blizzard's data says, grey
-- from the game (it includes hotfixes) or else the data.
function SP.AddColors(list, line)
	local data = SP.DATA and line and SP.DATA[line]
	if not data then return end
	for _, r in ipairs(list or {}) do
		local d = data[r.id]
		if d then
			r.yellow = d[1]
			if not (r.gray and r.gray > 0) then r.gray = d[2] end
		end
	end
end

-- Recipes you haven't learned that a trainer is known to teach (seen by you
-- or in the built-in trainer data), with the skill and cost to learn them.
function SP.ScanCandidates(prof)
	local T = C_TradeSkillUI
	local list = {}
	if not (T and prof and SP.LearnAt and T.GetAllRecipeIDs) then return list end
	local ok, ids = pcall(T.GetAllRecipeIDs)
	if not ok or type(ids) ~= "table" then return list end
	for _, recipeID in ipairs(ids) do
		local okI, r = pcall(T.GetRecipeInfo, recipeID)
		if okI and type(r) == "table" and not r.learned and not r.isSalvageRecipe
			and not r.isRecraft and not r.isDummyRecipe then
			local at, how = SP.LearnAt(recipeID, prof.id)
			local cost, where, item, favor
			if how == "trainer" then
				cost = SP.TrainCost(recipeID, prof.id)
			elseif how == "maybe" then
				cost = SP.TrainCostGuess(prof.id, at)
			elseif SP.RecipeSources then
				-- no trainer teaches it: a recipe in your bags, from a vendor
				-- or from the Auction House (drops and quests aren't planned)
				for _, src in ipairs(SP.RecipeSources(recipeID)) do
					if src.kind == "bags" or src.kind == "alt" or src.kind == "vendor" or src.kind == "ah" then
						how, cost, where, item = src.kind, src.price or 0, src.npc or src.alt, src.item
						favor = src.kind == "vendor" and src.currency and src.amount or nil
						at = src.skill or at
						break
					end
				end
			end
			if at and (how == "trainer" or how == "maybe" or how == "bags" or how == "alt" or how == "vendor" or how == "ah") then
				local recipe = {
					id = recipeID, name = r.name, icon = r.icon, gray = r.maxTrivialLevel,
					ups = (r.numSkillUps and r.numSkillUps > 0) and r.numSkillUps or 1,
					reagents = {}, unlearned = true, learn = at, trainCost = cost or 0,
					how = how, where = where, recipeItem = item, favor = favor,
					checked = how == "maybe" and SP.TrainerChecked(recipeID, prof.id) or nil,
				}
				ReadSchematic(recipe)
				if #recipe.reagents > 0 then list[#list + 1] = recipe end
			end
		end
	end
	SP.AddColors(list, prof.id)
	return list
end

function SP.ScanRecipes()
	local T = C_TradeSkillUI
	local list = {}
	if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo) then return list end
	local ok, ids = pcall(T.GetAllRecipeIDs)
	if not ok or type(ids) ~= "table" then return list end
	for _, recipeID in ipairs(ids) do
		local okI, r = pcall(T.GetRecipeInfo, recipeID)
		-- Gray recipes are kept too: they can still make materials for others.
		if okI and type(r) == "table" and r.learned and not r.disabled and r.craftable ~= false
			and not r.isSalvageRecipe and not r.isRecraft and not r.isDummyRecipe then
			local recipe = {
				id = recipeID,
				name = r.name,
				icon = r.icon,
				diff = r.relativeDifficulty or DIFF.Trivial,
				gray = r.maxTrivialLevel,
				ups = (r.numSkillUps and r.numSkillUps > 0) and r.numSkillUps or 1,
				reagents = {},
			}
			ReadSchematic(recipe)
			if #recipe.reagents > 0 then list[#list + 1] = recipe end
		end
	end
	return list
end

-- Open a recipe in the profession window (best effort).
function SP.SelectRecipe(recipeID)
	if C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
		if pcall(C_TradeSkillUI.OpenRecipe, recipeID) then return end
	end
	if ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.RecipeList then
		local list = ProfessionsFrame.CraftingPage.RecipeList
		if list.SelectRecipe and C_TradeSkillUI.GetRecipeInfo then
			pcall(list.SelectRecipe, list, C_TradeSkillUI.GetRecipeInfo(recipeID), true)
		end
	end
end

---------------------------------------------------------------------------
-- Craft next: the current step's recipe, as many times as your bags allow
---------------------------------------------------------------------------
-- How many in your bags (crafting only uses bags, not the bank).
function SP.InBags(itemID)
	if C_Item and C_Item.GetItemCount then
		local ok, n = pcall(C_Item.GetItemCount, itemID, false)
		if ok and type(n) == "number" then return n end
	end
	return 0
end

-- How many times you can craft a recipe right now.
function SP.Craftable(r)
	local T = C_TradeSkillUI
	if T and T.GetRecipeInfo and r.id then
		local ok, info = pcall(T.GetRecipeInfo, r.id)
		if ok and type(info) == "table" and info.learned == false then return 0 end
		local n = ok and type(info) == "table" and Plain(info.numAvailable)
		if type(n) == "number" then return n end
	end
	local n
	for _, rg in ipairs(r.reagents or {}) do
		if rg.itemID and (rg.count or 0) > 0 then
			local can = floor(SP.InBags(rg.itemID) / rg.count)
			n = n and math.min(n, can) or can
		end
	end
	return n or 0
end

-- Materials you're short of for one craft: { {itemID, name, short} }
function SP.Missing(r)
	local out = {}
	for _, rg in ipairs(r.reagents or {}) do
		if rg.itemID then
			local short = math.ceil(rg.count) - SP.InBags(rg.itemID)
			if short > 0 then out[#out + 1] = { itemID = rg.itemID, name = SP.ItemName(rg.itemID), short = short } end
		end
	end
	return out
end

-- Things the recipe needs that you don't have right now: an Anvil or Forge
-- nearby, a Blacksmith Hammer in your bags... (empty if the game won't say)
function SP.Unmet(r)
	local out = {}
	local T = C_TradeSkillUI
	if not (T and T.GetRecipeRequirements and r and r.id) then return out end
	local ok, list = pcall(T.GetRecipeRequirements, r.id)
	if not ok or type(list) ~= "table" then return out end
	for _, req in ipairs(list) do
		local met = Plain(req.met)
		if type(req) == "table" and met == false and type(Plain(req.name)) == "string" then out[#out + 1] = req.name end
	end
	return out
end

-- What the craft button should do for this plan:
--   { recipe, count, step, prep }  craft it
--   { learn = step }              next step's recipe isn't learned yet
--   { missing = step, short }     not enough materials
--   { enchant = step }            enchants need an item: use the window
function SP.NextCraft(plan)
	if not plan or plan.atCap or plan.done then return nil end
	for _, step in ipairs(plan.steps) do
		local r = step.recipe
		if not step.noRecipe then
			if step.learn or not r.id then return { learn = step } end
			local want = math.max(1, step.crafts or 1)
			local n = SP.Craftable(r)
			if n > 0 then
				if not r.output and plan.prof and plan.prof.name == "Enchanting" then return { enchant = step } end
				return { recipe = r, step = step, count = math.min(n, want), needs = SP.Unmet(r) }
			end
			-- Short of materials: something from "Make first" you can make now?
			for _, prep in ipairs(plan.prep or {}) do
				local pr = prep.recipe
				if not pr.foreign and pr.id and not pr.unlearned then
					local m = SP.Craftable(pr)
					if m > 0 then return { recipe = pr, step = step, prep = true, count = math.min(m, math.max(1, prep.crafts)), needs = SP.Unmet(pr) } end
				end
			end
			return { missing = step, short = SP.Missing(r) }
		end
	end
end

function SP.IsCrafting()
	local T = C_TradeSkillUI
	if T and T.IsRecipeRepeating then
		local ok, rep = pcall(T.IsRecipeRepeating)
		return ok and Plain(rep) == true
	end
	return false
end

function SP.StopCrafting()
	local T = C_TradeSkillUI
	if T and T.StopRecipeRepeat then pcall(T.StopRecipeRepeat) end
	if StopTradeSkillRepeat then pcall(StopTradeSkillRepeat) end
end

-- Craft a recipe `count` times. Must run from a click.
function SP.Craft(r, count)
	local T = C_TradeSkillUI
	if not (T and T.CraftRecipe and r and r.id) then return false, "this game version has no crafting API" end
	local ok, err = pcall(T.CraftRecipe, r.id, count or 1)
	if not ok then return false, tostring(err) end
	return true
end

---------------------------------------------------------------------------
-- Legacy points: 150, 225 and 300 in each crafting profession give one
-- account-wide point the first time any character reaches them. We note
-- every milestone we see your characters reach (saved for the account).
---------------------------------------------------------------------------
SP.LEGACY = { 150, 225, 300 }
SP.CRAFTING = { Alchemy = true, Blacksmithing = true, Enchanting = true, Engineering = true, Leatherworking = true, Tailoring = true }

function SP.NoteLegacy(prof)
	if not (prof and SP.CRAFTING[prof.name]) then return end
	SP.db.legacy = SP.db.legacy or {}
	local t = SP.db.legacy[prof.name] or {}
	SP.db.legacy[prof.name] = t
	for _, m in ipairs(SP.LEGACY) do
		if prof.skill >= m and not t[m] then t[m] = true end
	end
end

-- The next milestone that still gives a point (nil when none left).
function SP.NextLegacy(prof)
	if not (prof and SP.CRAFTING[prof.name]) then return end
	local t = SP.db.legacy and SP.db.legacy[prof.name] or {}
	for _, m in ipairs(SP.LEGACY) do
		if prof.skill < m and not t[m] then return m end
	end
end

---------------------------------------------------------------------------
-- Your characters: professions and where each one stands (saved for the
-- whole account, updated whenever you log in or open a profession).
---------------------------------------------------------------------------
-- Which character this is. On Forever, UnitFullName gives the part after the
-- hyphen in the character's name ("Brakka" + "Ironhide", like the WTF folder
-- Brakka-Ironhide), every time. GetRealmName is unreliable there: sometimes the
-- server's name, sometimes that same part, sometimes empty. So the key is
-- name + that part, and older entries saved under a server name (it has
-- spaces) or an empty one move to it.
local function Plainstr(v)
	if type(v) ~= "string" or v == "" or (issecretvalue and issecretvalue(v)) then return nil end
	return v
end

local function StablePart()
	for _, try in ipairs({
		function() return select(2, UnitFullName("player")) end,
		function() return select(2, UnitName("player")) end,
	}) do
		local ok, r = pcall(try)
		r = ok and Plainstr(r)
		if r then return r end
	end
end

local function RealmName()
	for _, try in ipairs({
		function() return GetRealmName() end,
		function() return GetNormalizedRealmName() end,
	}) do
		local ok, r = pcall(try)
		r = ok and Plainstr(r)
		if r then return r end
	end
end

function SP.MergeEmptyRealm(old, full)
	local db = SP.db
	if not db or old == full then return end
	for _, name in ipairs({ "chars", "known" }) do
		local t = db[name]
		if t and t[old] then
			if not t[full] then
				t[full] = t[old]
			elseif name == "known" then
				for k, v in pairs(t[old]) do if t[full][k] == nil then t[full][k] = v end end
			elseif (t[old].updated or 0) > (t[full].updated or 0) then
				t[full] = t[old]
			end
			t[old] = nil
		end
	end
	for _, name in ipairs({ "said", "legacyNear" }) do
		local t, moves = db[name], {}
		for k, v in pairs(t or {}) do
			if type(k) == "string" and k:sub(1, #old + 1) == old .. ":" then moves[k] = v end
		end
		for k, v in pairs(moves) do
			t[full .. k:sub(#old + 1)] = v
			t[k] = nil
		end
	end
end

-- Move "Name-" and "Name-<server name>" entries to the stable key
function SP.MergeOldKeys(name, full)
	local db = SP.db
	if not db then return end
	local prefix = name .. "-"
	local olds = {}
	local function Consider(key)
		if type(key) ~= "string" or key:sub(1, #prefix) ~= prefix then return end
		local part = key:sub(#prefix + 1):match("^[^:]*")
		local old = prefix .. part
		if old ~= full and (part == "" or part:find(" ")) then olds[old] = true end
	end
	for _, t in ipairs({ db.chars, db.known, db.said, db.legacyNear }) do
		for k in pairs(t or {}) do Consider(k) end
	end
	for old in pairs(olds) do SP.MergeEmptyRealm(old, full) end
end

local function MyKey()
	local ok, name = pcall(UnitName, "player")
	name = ok and Plainstr(name) or "?"
	local part = SP.realm or StablePart()
	if part then
		if not SP.realm and SP.db then
			SP.realm = part
			SP.MergeOldKeys(name, name .. "-" .. part)
		end
		return name .. "-" .. part
	end
	-- no stable part: the realm, as WoW usually has it
	local realm = RealmName()
	if realm and SP.db and not SP.mergedEmpty then
		SP.mergedEmpty = true
		SP.MergeEmptyRealm(name .. "-", name .. "-" .. realm)
	end
	return name .. "-" .. (realm or "")
end
SP.MyKey = MyKey

function SP.SaveCharacter()
	if not SP.db then return end
	SP.db.chars = SP.db.chars or {}
	local key = MyKey()
	local c = SP.db.chars[key] or { next = {} }
	SP.db.chars[key] = c
	c.name = UnitName and UnitName("player") or "?"
	if UnitClass then
		local _, class = UnitClass("player")
		c.class = class
	end
	c.level = UnitLevel and UnitLevel("player") or c.level
	c.next = c.next or {}
	if GetProfessions and GetProfessionInfo then
		local t = { pcall(GetProfessions) }
		if t[1] then
			local profs = {}
			for i = 2, 7 do
				local idx = t[i]
				if idx then
					local ok, name, icon, skill, max, _, _, line = pcall(GetProfessionInfo, idx)
					if ok and name then profs[SP.ProfKey(line, name)] = { skill = skill or 0, max = max or 0, icon = icon, label = name } end
				end
			end
			if next(profs) then c.profs = profs end
		end
	end
	c.updated = time and time() or 0
end

---------------------------------------------------------------------------
-- Specializations (Armorsmith, Weaponsmith, Gnomish/Goblin Engineer,
-- Dragonscale/Elemental/Tribal Leatherworking): some recipes only a
-- specialist can learn.
---------------------------------------------------------------------------
local function KnowsSpell(id)
	for _, try in ipairs({
		function() return IsPlayerSpell(id) end,
		function() return C_SpellBook.IsSpellKnown(id) end,
		function() return IsSpellKnown(id) end,
	}) do
		local ok, v = pcall(try)
		if ok and v == true then return true end
	end
	return false
end

-- Specializations this character has (spell IDs), from the spell book and
-- from specialist recipes it already knows
function SP.MySpecs()
	local have = {}
	local c = SP.db and SP.db.chars and SP.db.chars[MyKey()]
	for spec in pairs(SP.SPECS or {}) do
		if KnowsSpell(spec) or (c and c.specs and c.specs[spec]) then have[spec] = true end
	end
	-- a Master Axe-, Hammer- or Swordsmith is a Weaponsmith too
	for spec, d in pairs(SP.SPECS or {}) do
		if have[spec] and d[5] then have[d[5]] = true end
	end
	return have
end

-- Note a specialization when you know one of its recipes
function SP.NoteSpecRecipes(recipes)
	if not (SP.SPEC_RECIPES and SP.db and SP.db.chars) then return end
	for _, r in ipairs(recipes or {}) do
		local spec = r.learned ~= false and not r.unlearned and SP.SPEC_RECIPES[r.id]
		if spec then
			SP.SaveCharacter()
			local c = SP.db.chars[MyKey()]
			c.specs = c.specs or {}
			c.specs[spec] = true
		end
	end
end

-- The specialization a recipe needs, if you don't have it
function SP.SpecBlocks(recipeID, have)
	local spec = SP.SPEC_RECIPES and SP.SPEC_RECIPES[recipeID]
	if not spec then return nil end
	have = have or SP.MySpecs()
	if have[spec] then return nil end
	return spec
end

-- The nearest trainer (or quest giver) for a specialization
function SP.SpecTrainer(spec, start)
	local d = SP.SPECS and SP.SPECS[spec]
	if not d then return nil end
	return SP.SortByDistance and SP.SortByDistance(start and d[7] or d[6])[1]
end

-- For a profession: specializations you could pick now (none yet, or the
-- next step), and their names
function SP.SpecChoice(line, skill, level)
	local have = SP.MySpecs()
	local choices = {}
	for spec, d in pairs(SP.SPECS or {}) do
		if d[2] == line and not have[spec] and (not d[5] or have[d[5]]) then
			-- only if you don't already have one at this level
			local taken = false
			for other, o in pairs(SP.SPECS) do
				if other ~= spec and o[2] == line and o[5] == d[5] and have[other] then taken = true end
			end
			if not taken then choices[#choices + 1] = { spec = spec, name = d[1], skill = d[3], level = d[4], ready = skill >= d[3] and (level or 0) >= d[4] } end
		end
	end
	table.sort(choices, function(a, b) return a.name < b.name end)
	return choices
end

-- After planning: remember what's next for this profession on this character.
function SP.SavePlanSummary(prof, plan, nextCraft)
	if not (SP.db and prof) then return end
	SP.SaveCharacter()
	local c = SP.db.chars[MyKey()]
	c.profs = c.profs or {}
	c.profs[prof.name] = c.profs[prof.name] or {}
	c.profs[prof.name].skill, c.profs[prof.name].max = prof.skill, prof.max
	local s = {}
	if plan then
		local step = plan.steps and plan.steps[1]
		if step then s.recipe, s.learn, s.from, s.to = step.recipe.name, step.learn, step.from, step.to end
		s.atCap = plan.atCap
	end
	if nextCraft and nextCraft.missing then s.missing = true end
	c.next[prof.name] = s
	-- What this profession's plan still uses (shown in the Characters view)
	c.needs = c.needs or {}
	c.needs[prof.name] = plan and plan.needs or nil
	c.needsFor = c.needsFor or {}
	c.needsFor[prof.name] = plan and plan.usedBy or nil
end

---------------------------------------------------------------------------
-- Gathering your own materials: which of your characters can get an item
---------------------------------------------------------------------------
-- { { who = "you" | name, prof, skill, ok = skill high enough } }
function SP.Gatherers(itemID)
	local src = SP.GATHER and SP.GATHER[itemID]
	if not src or not SP.db then return nil, nil end
	local out, me = {}, MyKey()
	-- cloth needs no profession: anyone can collect it
	if src.prof == "Cloth" then return { { who = "you", prof = "Cloth", skill = 0, ok = true, me = true } }, src end
	for key, c in pairs(SP.db.chars or {}) do
		local p = c.profs and c.profs[src.prof]
		if p then
			out[#out + 1] = { who = (key == me) and "you" or c.name, prof = src.prof, skill = p.skill or 0, ok = (p.skill or 0) >= src.skill, me = key == me }
		end
	end
	table.sort(out, function(a, b) if a.me ~= b.me then return a.me end return a.skill > b.skill end)
	return out, src
end

function SP.GatherVerb(prof)
	return ({ Mining = "mine", Herbalism = "pick", Skinning = "skin", Cloth = "collect" })[prof] or "gather"
end

---------------------------------------------------------------------------
-- Trainer ranks
---------------------------------------------------------------------------
-- For a profession at skill/max: the rank to train next, whether you can
-- now, and the character level it needs.
function SP.RankStatus(profName, skill, max)
	-- Fishing and Cooking ranks need the crafting levels, and their Artisan
	-- needs skill 225 (a quest) - method.gg / wow-professions.com Forever guides
	local fishing = profName == "Fishing" or profName == "Cooking"
	local gather = not fishing and SP.Gathering and SP.Gathering[profName] ~= nil
	for _, r in ipairs(SP.RANKS or {}) do
		if max == r.cap then
			local lvl = gather and r.gatherLevel or r.level
			local at = (fishing and r.name == "Artisan") and 225 or r.at
			local myLevel = UnitLevel and UnitLevel("player") or 1
			return { rank = r.name, at = at, level = lvl, cap = r.next,
				skillOK = skill >= at, levelOK = myLevel >= lvl }
		end
	end
end

---------------------------------------------------------------------------
-- Reminders in chat (each once per character)
---------------------------------------------------------------------------
function SP.RemindOnce(key, msg)
	if not SP.db then return end
	SP.db.said = SP.db.said or {}
	key = MyKey() .. ":" .. key
	if SP.db.said[key] then return end
	SP.db.said[key] = true
	print("|cff66bbffProfession Pathfinder:|r " .. msg)
end

function SP.CheckAllRanks()
	SP.SaveCharacter()
	local c = SP.db.chars and SP.db.chars[MyKey()]
	for name, p in pairs(c and c.profs or {}) do
		pcall(SP.CheckReminders, { name = name, skill = p.skill or 0, max = p.max or 0 })
	end
end

-- Where to get a rank, when it isn't simply your trainer
function SP.RankHow(profName, rank)
	-- the nearest trainer, book seller or quest giver for your faction
	local where = SP.RankWhere and SP.RankWhere(profName, rank)
	if where then return where end
	local horde = UnitFactionGroup and UnitFactionGroup("player") == "Horde"
	if profName == "Fishing" then
		if rank == "Expert" then return "the book \"The Bass and You\" (Old Man Heming, Booty Bay)" end
		if rank == "Artisan" then return "Nat Pagle's quest (Dustwallow Marsh)" end
	elseif profName == "Cooking" then
		if rank == "Expert" then
			return horde and "the Expert Cookbook (Wulan, Shadowprey Village, Desolace)" or "the Expert Cookbook (Shandrina, Mystral Lake, Ashenvale)"
		end
		if rank == "Artisan" then
			return "the quest Clamlette Surprise (Dirge Quikcleave, Gadgetzan, Tanaris)"
		end
	end
	return "your trainer"
end

function SP.CheckReminders(prof, plan)
	if not prof then return end
	local rs = SP.RankStatus(prof.name, prof.skill, prof.max)
	if rs and rs.skillOK then
		if rs.levelOK then
			SP.RemindOnce("rank:" .. prof.name .. ":" .. rs.rank,
				"you can learn " .. rs.rank .. " " .. (prof.label or prof.name) .. " now (cap " .. rs.cap .. ") from " .. SP.RankHow(prof.name, rs.rank) .. ".")
		else
			SP.RemindOnce("ranklvl:" .. prof.name .. ":" .. rs.rank,
				rs.rank .. " " .. (prof.label or prof.name) .. " needs character level " .. rs.level .. ". Your skill is ready.")
		end
	end
	local learn = plan and plan.toLearn and plan.toLearn[1]
	if learn and prof.skill >= learn.from then
		local where = SP.LearnWhere and SP.LearnWhere(prof, learn) or "your trainer"
		SP.RemindOnce("learn:" .. prof.name .. ":" .. (learn.recipe.name or "?"),
			"time to learn " .. (learn.recipe.name or "?") .. " (" .. (prof.label or prof.name) .. ") from " .. where .. ".")
	end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
SP.eventFrame = f
local pending = false

function SP.RequestRefresh()
	if pending then return end
	pending = true
	C_Timer.After(0.3, function()
		pending = false
		if SP.UI and SP.UI:IsOpen() then
			local ok, err = pcall(SP.Refresh)
			if not ok then
				print("|cff66bbffProfession Pathfinder|r error: " .. tostring(err))
				print("  Please report this bug, with a screenshot of this message.")
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Recipes from your other professions (e.g. Mining's smelting for
-- Blacksmithing bars). Saved per character when you open each window.
---------------------------------------------------------------------------
local CharKey = MyKey

function SP.RememberRecipes(prof, recipes)
	if not (prof and prof.name) then return end
	SP.db.known = SP.db.known or {}
	local mine = SP.db.known[CharKey()] or {}
	SP.db.known[CharKey()] = mine
	local list = {}
	for _, r in ipairs(recipes) do
		if r.output then
			list[#list + 1] = { id = r.id, name = r.name, icon = r.icon, output = r.output,
				outputCount = r.outputCount, reagents = r.reagents }
		end
	end
	mine[prof.name] = list
end

-- Recipes this character knows in OTHER professions (they can make materials).
function SP.OtherRecipes(profName)
	local out = {}
	local mine = SP.db.known and SP.db.known[CharKey()]
	for name, list in pairs(mine or {}) do
		if name ~= profName then
			for _, r in ipairs(list) do
				local copy = {}
				for k, v in pairs(r) do copy[k] = v end
				copy.profession = name
				copy.foreign = true
				out[#out + 1] = copy
			end
		end
	end
	return out
end

-- Professions that make materials for others (Mining smelts bars), to
-- remind you to open them once so their recipes can be used.
local SUPPLIERS = { [186] = true }
function SP.MyProfessions()
	local names = {}
	if GetProfessions and GetProfessionInfo then
		local ok, a, b, c, d, e = pcall(GetProfessions)
		if ok then
			for _, idx in ipairs({ a, b, c, d, e }) do
				local okI, name, _, _, _, _, _, skillLine = pcall(GetProfessionInfo, idx)
				if okI and name and SUPPLIERS[skillLine or 0] then names[#names + 1] = name end
			end
		end
	end
	return names
end

function SP.Refresh()
	SP.waitingForItems = false
	local prof = SP.tradeOpen and SP.ProfessionInfo() or nil
	-- While the window is still loading the game reports skill 0 / max 0:
	-- show "loading" and try again shortly instead of planning on that.
	if prof and (prof.max or 0) <= 0 then
		SP.loadTries = (SP.loadTries or 0) + 1
		if SP.UI then SP.UI:Show(prof, nil, true) end
		if SP.loadTries < 20 then SP.RequestRefresh() end
		return
	end
	SP.loadTries = 0
	if prof then
		SP.NoteLegacy(prof)
		-- A few points from a Legacy point: say so once
		local m = SP.NextLegacy(prof)
		if m and m - prof.skill <= 5 and prof.max >= m then
			SP.db.legacyNear = SP.db.legacyNear or {}
			local key = CharKey() .. ":" .. prof.name .. ":" .. m
			if not SP.db.legacyNear[key] then
				SP.db.legacyNear[key] = true
				print("|cff66bbffProfession Pathfinder:|r " .. (m - prof.skill) .. " more " .. (prof.label or prof.name) .. " skill to " .. m .. " for a Legacy point.")
			end
		end
	end
	pcall(SP.SaveCharacter)
	local recipes = prof and SP.ScanRecipes() or nil
	if prof and recipes and #recipes > 0 then SP.RememberRecipes(prof, recipes) end
	if prof and recipes then pcall(SP.NoteSpecRecipes, recipes) end
	if prof and recipes and SP.ObserveRecipes then pcall(SP.ObserveRecipes, prof, recipes) end
	if prof and SP.Trainer then pcall(SP.Trainer.Match, prof.label or prof.name) end
	if prof and recipes then SP.AddColors(recipes, prof.id) end
	local candidates = prof and SP.ScanCandidates(prof) or nil
	local plan = prof and SP.MakePlan(prof, recipes, SP.db, SP.OtherRecipes(prof.name), candidates) or nil
	SP.lastPlan = plan
	if prof and plan then
		pcall(SP.SavePlanSummary, prof, plan, SP.NextCraft(plan))
		pcall(SP.CheckReminders, prof, plan)
	end
	if SP.UI then SP.UI:Show(prof, plan) end
	-- item names that weren't cached yet: try again shortly
	if SP.waitingForItems then SP.RequestRefresh() end
end

f:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		ProfessionPathfinderDB = ProfessionPathfinderDB or {}
		for k, v in pairs(SP.defaults) do
			if ProfessionPathfinderDB[k] == nil then ProfessionPathfinderDB[k] = v end
		end
		SP.db = ProfessionPathfinderDB
		SP.db.useGuide, SP.db.planMode = nil, nil -- the old Wowhead route setting
		for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE", "TRADE_SKILL_LIST_UPDATE",
			"TRADE_SKILL_DATA_SOURCE_CHANGED", "SKILL_LINES_CHANGED", "BAG_UPDATE_DELAYED",
			"TRADE_SKILL_CRAFT_BEGIN", "UPDATE_TRADESKILL_CAST_COMPLETE", "UPDATE_TRADESKILL_CAST_STOPPED" }) do
			pcall(f.RegisterEvent, f, ev)
		end
		pcall(f.RegisterEvent, f, "PLAYER_LEVEL_UP")
		C_Timer.After(5, function() pcall(SP.CheckAllRanks) end)
	elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
		SP.tradeOpen = true
		if SP.UI then SP.UI:Open() end
		SP.RequestRefresh()
	elseif event == "TRADE_SKILL_CLOSE" then
		SP.tradeOpen = false
		if SP.UI then SP.UI:Close() end
	else
		if event == "SKILL_LINES_CHANGED" or event == "PLAYER_LEVEL_UP" then
			if not SP.rankPending then
				SP.rankPending = true
				C_Timer.After(2, function() SP.rankPending = false; pcall(SP.CheckAllRanks) end)
			end
		end
		SP.RequestRefresh()
	end
end)
f:RegisterEvent("PLAYER_LOGIN")
