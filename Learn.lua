-- Profession Pathfinder - learning from your own crafting
--
-- The game tells addons when a recipe turns gray (maxTrivialLevel) but not
-- when it turns yellow or green, so the planner used to assume the usual
-- 25 points from yellow to gray. This file watches the colors change as
-- your skill rises and remembers where each recipe turned yellow and green.
-- It also logs every craft (skill before and after) so the estimates can
-- follow your real results. Everything is saved account-wide, so every
-- character's crafting improves the numbers for the others.
--
-- SP.db.learn[recipeID] = {
--   gray, yellow, green          -- skill levels seen in game (exact = true when seen 1 point apart)
--   yellowExact, greenExact
--   lastDiff, lastSkill          -- last color seen and at which skill
--   log = { [color] = { c = crafts, u = skill-ups } }
-- }

local ADDON, SP = ...
local DIFF = SP.DIFF
local max, min, floor = math.max, math.min, math.floor

local function DB()
	if not SP.db then return {} end
	SP.db.learn = SP.db.learn or {}
	return SP.db.learn
end
SP.LearnDB = DB

function SP.LearnEntry(recipeID)
	if not recipeID then return nil end
	return DB()[recipeID]
end

local function Note(e, key, skill, exact)
	if exact then
		e[key], e[key .. "Exact"] = skill, true
	elseif not e[key .. "Exact"] then
		e[key] = skill -- within a few points; refined when seen exactly
	end
end

-- Called with every recipe scan: notice color changes since the last scan.
function SP.ObserveRecipes(prof, recipes)
	if not (prof and recipes) then return end
	local L = DB()
	local skill = prof.skill or 0
	SP.recipeIndex = SP.recipeIndex or {}
	for _, r in ipairs(recipes) do
		SP.recipeIndex[r.id] = r
		local e = L[r.id]
		if not e then e = {}; L[r.id] = e end
		if r.gray and r.gray > 0 then e.gray = r.gray end
		local last, lastSkill = e.lastDiff, e.lastSkill
		if last ~= nil and lastSkill and skill > lastSkill and r.diff ~= last and skill - lastSkill <= 3 then
			local exact = skill - lastSkill == 1
			if last == DIFF.Optimal and r.diff == DIFF.Medium then Note(e, "yellow", skill, exact) end
			if last == DIFF.Optimal and r.diff == DIFF.Easy then Note(e, "yellow", skill, false); Note(e, "green", skill, false) end
			if last == DIFF.Medium and r.diff == DIFF.Easy then Note(e, "green", skill, exact) end
		end
		e.lastDiff, e.lastSkill = r.diff, skill
	end
end

-- Points from yellow to gray for this recipe: seen in game, else worked out
-- from green (green sits halfway), else the usual 25.
function SP.Span(r)
	local e = r and SP.LearnEntry(r.id)
	local gray = r and r.gray
	-- Blizzard's data says where yellow starts
	if r and r.yellow and gray and gray > r.yellow then return gray - r.yellow, "data" end
	if e and gray and gray > 0 then
		if e.yellow and gray > e.yellow then return gray - e.yellow, "seen" end
		if e.green and gray > e.green then return 2 * (gray - e.green), "green" end
	end
	return 25, nil
end

-- Your results with a recipe at its current color: crafts, skill-ups
function SP.Results(recipeID, diff)
	local e = SP.LearnEntry(recipeID)
	local lg = e and e.log and e.log[diff]
	if not lg then return 0, 0 end
	return lg.c or 0, lg.u or 0
end

---------------------------------------------------------------------------
-- Working Overtime (Legacy): +4% skill-up chance per rank, read straight from
-- the game's Legacy perk trees (a trait config that spends currency 4225;
-- trait system 45 in Forever)
---------------------------------------------------------------------------
local LEGACY_CURRENCY = 4225
local OVERTIME = { ["Working Overtime"] = true, ["Overtime"] = true }
local ot = { cfg = nil, node = nil, rank = 0, at = -60 }
local function Secret(v) return issecretvalue and issecretvalue(v) end

local function UsesLegacyCurrency(cfg, tree)
	if not C_Traits.GetTreeCurrencyInfo then return false end
	local ok, list = pcall(C_Traits.GetTreeCurrencyInfo, cfg, tree, false)
	if not ok or type(list) ~= "table" then return false end
	for _, c in ipairs(list) do
		if c.traitCurrencyID == LEGACY_CURRENCY then return true end
	end
	return false
end

local function LegacyConfig()
	if not (C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigIDBySystemID) then return end
	local tries, seen = {}, {}
	local function Try(sys)
		local ok, cfg = pcall(C_Traits.GetConfigIDBySystemID, sys)
		if ok and type(cfg) == "number" and cfg > 0 and not seen[cfg] then seen[cfg] = true; tries[#tries + 1] = cfg end
	end
	Try(45)
	for sys = 1, 120 do Try(sys) end
	for _, cfg in ipairs(tries) do
		local ok, info = pcall(C_Traits.GetConfigInfo, cfg)
		for _, tree in ipairs(ok and type(info) == "table" and info.treeIDs or {}) do
			if UsesLegacyCurrency(cfg, tree) then return cfg, info.treeIDs end
		end
	end
end

local function NodeName(cfg, node)
	local ok, info = pcall(C_Traits.GetNodeInfo, cfg, node)
	if not ok or type(info) ~= "table" then return end
	local entry = info.activeEntry and info.activeEntry.entryID or (info.entryIDs and info.entryIDs[1])
	if not (entry and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo) then return end
	local ok2, e = pcall(C_Traits.GetEntryInfo, cfg, entry)
	if not (ok2 and type(e) == "table" and e.definitionID) then return end
	local ok3, d = pcall(C_Traits.GetDefinitionInfo, e.definitionID)
	if not (ok3 and type(d) == "table") then return end
	local name = d.overrideName
	if (not name or name == "") and d.spellID then
		name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(d.spellID)
	end
	if name and not Secret(name) then return name end
end

-- Find the Working Overtime node once; after that only its rank is read
local function FindOvertime()
	local cfg, trees = LegacyConfig()
	if not cfg or not C_Traits.GetTreeNodes then return end
	for _, tree in ipairs(trees) do
		local ok, nodes = pcall(C_Traits.GetTreeNodes, tree)
		for _, node in ipairs(ok and nodes or {}) do
			if OVERTIME[NodeName(cfg, node) or ""] then return cfg, node end
		end
	end
end

function SP.OvertimeRank()
	local now = GetTime and GetTime() or 0
	if now - ot.at < 30 then return ot.rank end
	ot.at = now
	if not ot.node then ot.cfg, ot.node = FindOvertime() end
	local rank = 0
	if ot.node then
		local ok, info = pcall(C_Traits.GetNodeInfo, ot.cfg, ot.node)
		if ok and type(info) == "table" then
			local r = info.activeRank or info.currentRank or 0
			if type(r) == "number" and not Secret(r) then rank = r end
		end
	end
	ot.rank = rank
	return rank
end

-- spending a Legacy point: read again straight away
local otFrame = CreateFrame("Frame")
pcall(otFrame.RegisterEvent, otFrame, "TRAIT_CONFIG_UPDATED")
otFrame:SetScript("OnEvent", function() ot.at = -60 end)

function SP.OvertimeBonus()
	if SP.db and SP.db.overtime == false then return 0 end
	return 0.04 * SP.OvertimeRank()
end

---------------------------------------------------------------------------
-- Craft log: skill when the cast starts, skill a moment after it finishes
---------------------------------------------------------------------------
local function SkillNow()
	local p = SP.ProfessionInfo and SP.ProfessionInfo()
	return p and p.skill
end

local pending
local function Finish(entry, after)
	if not (entry and after and entry.before) then return end
	local ups = after - entry.before
	if ups < 0 or ups > 5 then return end -- a trainer rank or a different profession
	local e = DB()[entry.id]
	if not e then e = {}; DB()[entry.id] = e end
	e.log = e.log or {}
	local lg = e.log[entry.diff] or { c = 0, u = 0 }
	lg.c, lg.u = lg.c + 1, lg.u + ups
	e.log[entry.diff] = lg
end

local starts = {}
local f = CreateFrame("Frame")
SP.learnFrame = f
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
	if event == "PLAYER_LOGIN" then
		pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_START", "player")
		pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SUCCEEDED", "player")
		return
	end
	if issecretvalue and issecretvalue(spellID) then return end
	local r = SP.recipeIndex and SP.recipeIndex[spellID]
	if not r then return end
	if event == "UNIT_SPELLCAST_START" then
		starts[spellID] = SkillNow()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local before = starts[spellID] or SkillNow()
		starts[spellID] = nil
		if pending then Finish(pending, before) end -- the last craft's result is in by now
		local entry = { id = spellID, diff = r.diff, before = before }
		pending = entry
		C_Timer.After(1.5, function()
			if pending == entry then
				Finish(entry, SkillNow())
				pending = nil
			end
		end)
	end
end)

