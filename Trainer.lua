-- Profession Pathfinder - what trainers teach
-- Blizzard's data files don't say which recipes a trainer sells or the skill
-- it asks for. The trainer window does: every time you open one, the recipes
-- it lists (including the ones you can't learn yet) are written down with
-- their skill requirement. The profession window then turns the names into
-- recipe IDs, so it works in any game language.

local ADDON, SP = ...
local Trainer = {}
SP.Trainer = Trainer

local function DB()
	SP.db.trainer = SP.db.trainer or {}   -- [skill name][recipe name] = skill needed
	SP.db.teach = SP.db.teach or {}       -- [recipe ID] = skill needed at a trainer
	return SP.db.trainer, SP.db.teach
end

local function Pass(ok, ...) if ok then return ... end end
local function Call(fn, ...)
	if type(fn) ~= "function" then return end
	return Pass(pcall(fn, ...))
end

-- Show every service, also the ones you can't learn yet or already know.
-- Newer game versions want true, older ones 1: try both, keep the error.
local function IsOn(kind)
	local v = Call(GetTrainerServiceTypeFilter, kind)
	return v == true or v == 1
end
local function ShowAll()
	Trainer.filterError = nil
	if type(SetTrainerServiceTypeFilter) ~= "function" then return end
	for _, kind in ipairs({ "available", "unavailable", "used" }) do
		if not IsOn(kind) then
			local ok, err = pcall(SetTrainerServiceTypeFilter, kind, true)
			if not ok or not IsOn(kind) then
				local ok2, err2 = pcall(SetTrainerServiceTypeFilter, kind, 1)
				if not ok2 or not IsOn(kind) then
					Trainer.filterError = kind .. ": " .. tostring(err2 or err or "stays off")
				end
			end
		end
	end
end
Trainer.ShowAll = ShowAll

function Trainer.Read()
	if not (SP.db and GetNumTrainerServices) then return 0 end
	ShowAll()
	local byName = DB()
	local n, found = Call(GetNumTrainerServices) or 0, 0
	for i = 1, n do
		local name, _, kind = Call(GetTrainerServiceInfo, i)
		local skillName, skillLevel = Call(GetTrainerServiceSkillReq, i)
		if name and kind ~= "header" and type(skillName) == "string" and skillName ~= ""
			and type(skillLevel) == "number" and skillLevel > 0 then
			byName[skillName] = byName[skillName] or {}
			byName[skillName][name] = skillLevel
			local cost = Call(GetTrainerServiceCost, i)
			if type(cost) == "number" then
				SP.db.trainerCost = SP.db.trainerCost or {}
				SP.db.trainerCost[skillName .. ":" .. name] = cost
			end
			found = found + 1
		end
	end
	Trainer.lastCount = found
	return found
end

-- With a profession window open: names from the trainer -> recipe IDs
function Trainer.Match(profName)
	if not (SP.db and profName and C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs) then return 0 end
	local byName, teach = DB()
	local list = byName[profName]
	if not list then return 0 end
	local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
	local matched = 0
	for _, id in ipairs(ok and ids or {}) do
		local okI, r = pcall(C_TradeSkillUI.GetRecipeInfo, id)
		if okI and type(r) == "table" and r.name and list[r.name] then
			teach[id] = list[r.name]
			local cost = SP.db.trainerCost and SP.db.trainerCost[profName .. ":" .. r.name]
			if cost then
				SP.db.teachCost = SP.db.teachCost or {}
				SP.db.teachCost[id] = cost
			end
			matched = matched + 1
		end
	end
	return matched
end

-- Without the profession window (or the profession): match every trainer
-- list against the built-in recipe IDs by spell name. The game names the
-- spells in your own language, so this works in any language too.
local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then
		local ok, n = pcall(C_Spell.GetSpellName, id)
		if ok and type(n) == "string" then return n end
	end
end

function Trainer.MatchAll()
	if not (SP.db and SP.DATA) then return 0 end
	local byName, teach = DB()
	local names = {} -- [skill line] = { [name] = recipe ID }
	for line, recipes in pairs(SP.DATA) do
		local t = {}
		for id in pairs(recipes) do
			local n = SpellName(id)
			if n and (not t[n] or id < t[n]) then t[n] = id end
		end
		names[line] = t
	end
	local total = 0
	for skillName, list in pairs(byName) do
		-- the skill line whose recipes match this trainer's list best
		local bestLine, best = nil, 0
		for line, t in pairs(names) do
			local hits = 0
			for name in pairs(list) do if t[name] then hits = hits + 1 end end
			if hits > best then bestLine, best = line, hits end
		end
		if not bestLine and SP.db.trainerLine then bestLine = SP.db.trainerLine[skillName] end
		if bestLine then
			local t = names[bestLine]
			local made -- trainers name some recipes after what they make ("Iron Bar")
			for name, req in pairs(list) do
				local id = t[name]
				if not id then
					made = made or Trainer.OutputNames(bestLine)
					id = made[name]
				end
				if id and not teach[id] then
					teach[id] = req
					local cost = SP.db.trainerCost and SP.db.trainerCost[skillName .. ":" .. name]
					if cost then
						SP.db.teachCost = SP.db.teachCost or {}
						SP.db.teachCost[id] = cost
					end
				end
				if id then total = total + 1 end
			end
			SP.db.trainerLine = SP.db.trainerLine or {}
			SP.db.trainerLine[skillName] = bestLine
		end
	end
	Trainer.matchedAll = total
	return total
end

-- [name of what a recipe makes] = recipe ID, for one skill line
function Trainer.OutputNames(line)
	local t = {}
	if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic and SP.DATA[line]) then return t end
	for id in pairs(SP.DATA[line]) do
		local ok, sch = pcall(C_TradeSkillUI.GetRecipeSchematic, id, false)
		local item = ok and type(sch) == "table" and sch.outputItemID
		if item and item > 0 then
			local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(item)
			if type(n) == "string" then
				if not t[n] or id < t[n] then t[n] = id end
			elseif C_Item and C_Item.RequestLoadItemDataByID then
				pcall(C_Item.RequestLoadItemDataByID, item) -- ready at the next login
			end
		end
	end
	return t
end

-- Skill a recipe can be learned at: seen at a trainer by you, else the
-- built-in trainer data, else where it turns yellow (always safe)
function SP.LearnAt(id, line)
	local seen = SP.db and SP.db.teach and SP.db.teach[id]
	if seen then return seen, "trainer" end
	local function From(l)
		local t = SP.TRAINER and SP.TRAINER[l] and SP.TRAINER[l][id]
		if t then return t[1], "trainer" end
	end
	if line then
		local v, how = From(line)
		if v then return v, how end
	else
		for l in pairs(SP.TRAINER or {}) do
			local v, how = From(l)
			if v then return v, how end
		end
	end
	local d = line and SP.DATA and SP.DATA[line] and SP.DATA[line][id]
	if not d and SP.DATA then
		for _, recipes in pairs(SP.DATA) do if recipes[id] then d = recipes[id] break end end
	end
	if d and d[3] ~= 1 and line and SP.MaybeTrainer(id, line) and d[1] > SP.TrainerSeenUpTo(line) then
		-- no item teaches it, and no trainer window has shown that high yet
		return d[1], "maybe"
	end
	if d then return d[3] == 1 and 1 or d[1], d[3] == 1 and "start" or "yellow" end
end

-- Recipes that are probably taught by a trainer (Sources.lua)
local maybeIndex
function SP.MaybeTrainer(id, line)
	if not maybeIndex then
		maybeIndex = {}
		for l, list in pairs(SP.MAYBE_TRAINER or {}) do
			maybeIndex[l] = {}
			for _, sid in ipairs(list) do maybeIndex[l][sid] = true end
		end
	end
	return maybeIndex[line] and maybeIndex[line][id] or false
end

-- The highest skill a trainer window has listed for this profession (built
-- in or seen by you): recipes below it that weren't listed aren't trainer
-- recipes after all.
function SP.TrainerSeenUpTo(line)
	local top = 0
	for _, t in pairs(SP.TRAINER and SP.TRAINER[line] or {}) do top = math.max(top, t[1]) end
	local data = SP.DATA and SP.DATA[line]
	for id, req in pairs(SP.db and SP.db.teach or {}) do
		if data and data[id] then top = math.max(top, req) end
	end
	return top
end

-- What a trainer probably charges for a recipe at this skill (the closest
-- one seen, in this profession if possible)
function SP.TrainCostGuess(line, at)
	local best, bestD
	local function Look(list, penalty)
		for _, t in pairs(list or {}) do
			local dist = math.abs(t[1] - at) + penalty
			if t[2] > 0 and (not bestD or dist < bestD) then best, bestD = t[2], dist end
		end
	end
	Look(SP.TRAINER and SP.TRAINER[line], 0)
	for l, list in pairs(SP.TRAINER or {}) do if l ~= line then Look(list, 30) end end
	return best or 0
end

-- What a trainer charges for a recipe (copper), if known
function SP.TrainCost(id, line)
	local c = SP.db and SP.db.teachCost and SP.db.teachCost[id]
	if c then return c end
	local t = SP.TRAINER and line and SP.TRAINER[line] and SP.TRAINER[line][id]
	return t and t[2] or 0
end

-- Skill needed to learn a recipe at a trainer, if a trainer was seen
-- teaching it
function Trainer.Requires(recipeID)
	return SP.db and SP.db.teach and SP.db.teach[recipeID]
end

-- /ppf trainer, with a trainer window open: everything the window tells
-- addons, for checking this works in this game version
function Trainer.Report()
	ShowAll()
	-- the list refills a moment after the filters change
	C_Timer.After(0.5, function()
		pcall(Trainer.Read)
		Trainer.BuildReport()
	end)
end

function Trainer.BuildReport()
	local out = { "Profession Pathfinder " .. SP.version .. " trainer check" }
	local function Has(name) return type(_G[name]) == "function" and "yes" or "MISSING" end
	for _, fn in ipairs({ "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceSkillReq",
		"GetTrainerServiceLevelReq", "GetTrainerServiceTypeFilter", "SetTrainerServiceTypeFilter", "IsTradeskillTrainer" }) do
		out[#out + 1] = fn .. ": " .. Has(fn)
	end
	out[#out + 1] = "Trainer windows seen since login: " .. (Trainer.shown or 0)
		.. ", last read: " .. tostring(Trainer.lastCount) .. " recipes" .. (Trainer.lastError and (", error: " .. Trainer.lastError) or "")
	out[#out + 1] = "Tradeskill trainer: " .. tostring(Call(IsTradeskillTrainer))
	for _, kind in ipairs({ "available", "unavailable", "used" }) do
		out[#out + 1] = "Filter " .. kind .. ": " .. tostring(Call(GetTrainerServiceTypeFilter, kind))
	end
	if Trainer.filterError then out[#out + 1] = "Could not turn on filter " .. Trainer.filterError end
	local n = Call(GetNumTrainerServices) or 0
	out[#out + 1] = "Services listed: " .. tostring(n)
	for i = 1, math.min(n, 25) do
		local a = { Call(GetTrainerServiceInfo, i) }
		local b = { Call(GetTrainerServiceSkillReq, i) }
		local lvl = Call(GetTrainerServiceLevelReq, i)
		local ta, tb = {}, {}
		for j = 1, 6 do ta[j] = tostring(a[j]) end
		for j = 1, 3 do tb[j] = tostring(b[j]) end
		out[#out + 1] = i .. ". " .. table.concat(ta, " | ") .. "  skill: " .. table.concat(tb, ", ") .. "  level: " .. tostring(lvl)
	end
	local saved = 0
	for _, list in pairs(SP.db and SP.db.trainer or {}) do for _ in pairs(list) do saved = saved + 1 end end
	local ids = 0
	for _ in pairs(SP.db and SP.db.teach or {}) do ids = ids + 1 end
	out[#out + 1] = "Trainer recipes saved so far: " .. saved .. ", matched to recipe IDs: " .. ids
	SP.ShowReport(out)
end

local f = CreateFrame("Frame")
for _, e in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE" }) do pcall(f.RegisterEvent, f, e) end
pcall(f.RegisterEvent, f, "PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		C_Timer.After(3, function() pcall(Trainer.MatchAll) end)
		return
	end
	if event == "TRAINER_SHOW" then Trainer.shown = (Trainer.shown or 0) + 1 end
	-- the list fills in a moment after the window opens
	C_Timer.After(0.3, function()
		local ok, err = pcall(Trainer.Read)
		Trainer.lastError = not ok and tostring(err) or nil
		pcall(Trainer.MatchAll)
	end)
end)
