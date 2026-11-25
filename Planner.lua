-- Profession Pathfinder - Planner
-- For every skill point from now to the target, pick the recipe with the
-- lowest expected cost per skill point: recipes you know, and recipes a
-- trainer teaches once your skill allows (learned along the way). Then add
-- up crafts, materials and training costs.
--
-- Skill-up odds: orange (below yellow) always gives a point. Yellow and green
-- follow the classic formula, chance = (gray - skill) / (gray - yellow).
-- Yellow comes from Blizzard's data (Data.lua), gray from the game. Your own
-- results at the recipe's current color and the Legacy perk Working
-- Overtime are added in. Treat counts as estimates.

local ADDON, SP = ...
local DIFF = SP.DIFF
local max, min, ceil, abs, floor = math.max, math.min, math.ceil, math.abs, math.floor

local TRAINER_CHANCE = 0.4 -- below this, new trainer recipes are almost always better
local MIN_POINTS = 5       -- always plan at least this many points
local UNKNOWN_PRICE = 2500 -- copper per item when no price is known: assume it's not cheap
local SWITCH = 1.15        -- only change recipe when another is 15% cheaper per point
local TRAIN_SPREAD = 10    -- a training fee counts as spread over this many points
local GATHER_EFFORT = 40   -- gather & craft: each item you gather weighs like this many copper
local VENDOR_GUESS = 50    -- a vendor material with no known price
local REACH_PENALTY = 4    -- gather & craft: a material none of your characters can gather yet weighs this much more

-- Chance of a skill-up for recipe r at `level` (we're at `skill` now), from
-- the colors alone.
local function ModelChance(r, level, skill)
	local gray = r.gray
	-- exact colors from the data: orange below yellow, then the formula
	if r.yellow and gray and gray > r.yellow then
		if level >= gray then return 0 end
		if level == skill and r.diff == DIFF.Optimal then return 1 end
		if level < r.yellow then return 1 end
		return min(1, (gray - level) / (gray - r.yellow))
	end
	if gray and gray > 0 then
		if level >= gray then return 0 end
		local span = SP.Span and SP.Span(r) or 25
		local p = min(1, (gray - level) / span)
		if r.diff == DIFF.Optimal then
			if level == skill then return 1 end
			return p
		end
		-- yellow or green now: it can't turn orange again
		if level == skill then
			if r.diff == DIFF.Medium then return max(0.5, min(0.95, p)) end
			return max(0.1, min(0.5, p))
		end
		return min(0.95, p)
	end
	-- gray level unknown: go by today's color only
	if r.diff == DIFF.Optimal then return 1 end
	if r.diff == DIFF.Medium then return 0.75 end
	if r.diff == DIFF.Easy then return 0.3 end
	return 0
end

local TRUST = 5 -- your results count like this many crafts of the formula
function SP.Chance(r, level, skill)
	local p = ModelChance(r, level, skill)
	if p <= 0 then return 0 end
	-- your own results at today's color (only for the point you're on now)
	if level == skill and r.diff ~= DIFF.Optimal and SP.Results then
		local c, u = SP.Results(r.id, r.diff)
		if c >= 3 then p = (u + TRUST * p) / (c + TRUST) end
	end
	if p < 1 and SP.OvertimeBonus then p = min(1, p + SP.OvertimeBonus()) end
	return max(0.01, p)
end

function SP.MakePlan(prof, recipes, db, others, candidates)
	local skill, cap = prof.skill, prof.max
	local target = cap
	if db.target and db.target > skill then target = (cap > 0) and min(db.target, cap) or db.target end
	local plan = { prof = prof, from = skill, to = target, reached = skill, steps = {}, prep = {}, shopping = {}, total = 0, unknownPrices = false }
	if cap > 0 and skill >= cap then plan.atCap = true return plan end
	if target <= skill then plan.done = true return plan end

	candidates = candidates or {}
	-- recipes only a specialist can learn: only if you're that specialist
	if SP.SpecBlocks then
		local have, keep = SP.MySpecs(), {}
		for _, r in ipairs(candidates) do
			local spec = SP.SpecBlocks(r.id, have)
			if spec then
				plan.specSkipped = plan.specSkipped or {}
				plan.specSkipped[spec] = (plan.specSkipped[spec] or 0) + 1
			else
				keep[#keep + 1] = r
			end
		end
		candidates = keep
	end
	local taught = {}
	plan.trainCost = 0

	-- Which of your recipes make which item (to craft materials yourself).
	-- Your other professions' recipes count too (smelting bars for Blacksmithing).
	local maker = {}
	for _, r in ipairs(recipes) do
		if r.output and not maker[r.output] then maker[r.output] = r end
	end
	for _, r in ipairs(others or {}) do
		if r.output and not maker[r.output] then maker[r.output] = r end
	end
	-- Trainer recipes for materials you can't buy cheaper (Solid Grinding
	-- Stone): learned along the way if the plan reaches their skill.
	for _, r in ipairs(candidates or {}) do
		if r.output and not maker[r.output] and r.learn <= target then maker[r.output] = r end
	end

	-- Gather & craft: only materials you (or one of your characters) can
	-- gather, cloth from humanoids, and what a vendor sells. No Auction House.
	-- Gathering counts as effort when choosing recipes, not as gold.
	local selfMode = db.selfGather and true or false
	plan.selfGather = selfMode
	local function Source(id)
		local src = SP.GATHER and SP.GATHER[id]
		if src then
			local gs = SP.Gatherers(id)
			if gs and #gs > 0 then
				if src.prof == "Cloth" then return "cloth" end
				return src.how == "smelt" and "smelt" or "gather"
			end
		end
		if SP.VENDOR_SOLD and SP.VENDOR_SOLD[id] then return "vendor" end
	end

	-- Market value of an item: the cheaper of buying it and making it.
	local priceOf, unit = {}, {}
	local function Price(id)
		if priceOf[id] == nil then
			local p, src = SP.Price(id)
			if selfMode then
				local how = Source(id)
				if how == "gather" or how == "cloth" then p, src = GATHER_EFFORT, how
				elseif how == "smelt" then p, src = GATHER_EFFORT * 1.5, how
				elseif how == "vendor" then p, src = (src == "vendor" and p) or VENDOR_GUESS, "vendor"
				else p, src = nil, nil end
				-- needs a gathering skill none of your characters has yet: leave it for later
				if how == "gather" or how == "smelt" then
					local able = false
					for _, g in ipairs(SP.Gatherers(id) or {}) do if g.ok then able = true end end
					if not able then p = p * REACH_PENALTY end
				end
			end
			priceOf[id] = { p = p, src = src }
		end
		return priceOf[id].p, priceOf[id].src
	end
	local function Unit(id, depth)
		depth = depth or 0
		if unit[id] then return unit[id].p, unit[id].how end
		local p, src = Price(id)
		local how = src
		local r = maker[id]
		if r and depth < 3 then
			local craft, known = 0, true
			for _, rg in ipairs(r.reagents) do
				local rp = Unit(rg.itemID, depth + 1)
				if not rp then known = false break end
				craft = craft + rg.count * rp
			end
			if known then
				craft = craft / (r.outputCount or 1)
				if not p or craft < p then p, how = craft, "craft" end
			end
		end
		if depth == 0 then unit[id] = { p = p, how = how } end
		return p, how
	end

	-- Expected market cost of one craft (used to choose recipes).
	local function CraftCost(r)
		local cost = 0
		for _, rg in ipairs(r.reagents) do
			local p = Unit(rg.itemID)
			if not p then plan.unknownPrices = true end
			cost = cost + rg.count * (p or UNKNOWN_PRICE)
		end
		return cost
	end

	-- What you get back for what you craft (sold to a vendor or on the
	-- Auction House, per your setting), per craft
	local resaleMode = db.resale or "off"
	local resaleOf = {}
	local function Resale(id)
		if resaleOf[id] == nil then
			local v, src = SP.ResaleValue(id, resaleMode)
			resaleOf[id] = { v = v or 0, src = src }
		end
		return resaleOf[id].v, resaleOf[id].src
	end
	local function Back(r)
		if resaleMode == "off" or not r.output then return 0 end
		return (r.outputCount or 1) * Resale(r.output)
	end
	local produced = {}

	-- What you own (if "use my materials" is on), plus what the plan makes.
	local stock, buy, make, need = {}, {}, {}, {}
	local collect -- what the current step needs gathered or bought
	local function Have(id)
		if stock[id] == nil then stock[id] = db.bagsFree and SP.Owned(id) or 0 end
		return stock[id]
	end
	-- Get `amount` of an item: from stock, else make it (if cheaper), else buy.
	local function Acquire(id, amount, depth)
		need[id] = (need[id] or 0) + amount
		local fromStock = min(max(0, Have(id)), amount)
		stock[id] = Have(id) - fromStock
		local rest = amount - fromStock
		if rest <= 0 then return 0 end
		local _, how = Unit(id)
		local r = maker[id]
		if how == "craft" and r and (depth or 0) < 3 then
			local crafts = rest / (r.outputCount or 1)
			make[r] = (make[r] or 0) + crafts
			if r.unlearned and not taught[r] then
				taught[r] = true
				plan.trainCost = plan.trainCost + (r.trainCost or 0)
			end
			local cost = 0
			for _, rg in ipairs(r.reagents) do
				cost = cost + Acquire(rg.itemID, rg.count * crafts, (depth or 0) + 1)
			end
			return cost
		end
		buy[id] = (buy[id] or 0) + rest
		if collect then collect[id] = (collect[id] or 0) + rest end
		local p, src = Price(id)
		if selfMode and src ~= "vendor" then return 0 end
		return rest * (p or 0)
	end

	local level = skill
	local nameBuy = {} -- materials we only know by name (no item ID)

	-- Cheapest recipes you know, from `level` up to `upTo`. fill = closing a gap
	-- in the route: take whatever works, no "go to the trainer" stop.
	-- Recipes a trainer teaches, learned once the plan reaches their skill
	local function Score(r, p)
		-- net cost: materials minus what selling the result gets back (at least 1 copper,
		-- so recipes that make money tie and the best skill-up chance wins)
		local score = (db.netPick and max(1, CraftCost(r) - Back(r)) or CraftCost(r)) / (p * r.ups)
		if r.unlearned and not taught[r] then score = score + (r.trainCost or 0) / TRAIN_SPREAD end
		return score
	end
	-- Gather & craft: can every material be gathered, made or bought from a vendor
	-- (or is it already in your bags)? Recipes from the Auction House are out too.
	local function Usable(r)
		if not selfMode then return true end
		if r.how == "ah" then return false end
		for _, rg in ipairs(r.reagents or {}) do
			if not rg.itemID then return false end
			if not Unit(rg.itemID) and Have(rg.itemID) < rg.count then return false end
		end
		return true
	end
	-- Is a trainer recipe known that unlocks above this skill (still to come)?
	local function Ahead(lvl)
		for _, r in ipairs(candidates) do
			if not taught[r] and r.learn > lvl and r.learn <= target then return true end
		end
		return false
	end
	local function Search(upTo, fill)
		local guard = 0
		while level < upTo and guard < 1000 do
			guard = guard + 1
			-- Prefer recipes with a decent skill-up chance (green ones cost many
			-- crafts per point); fall back to low-chance ones only if that's all.
			local best, bestScore, bestP
			for pass = 1, 2 do
				for _, list in ipairs({ recipes, candidates }) do
					for _, r in ipairs(list) do
						if (not r.unlearned or r.learn <= level) and Usable(r) then
							local p = SP.Chance(r, level, skill)
							if p > 0 and (pass == 2 or p >= TRAINER_CHANCE) then
								local score = Score(r, p)
								if not best or score < bestScore - 0.5 or (abs(score - bestScore) <= 0.5 and p > bestP) then
									best, bestScore, bestP = r, score, p
								end
							end
						end
					end
				end
				if best then break end
			end
			if not best then
				if not fill then plan.stuckAt = level; plan.selfStuck = selfMode or nil end
				return false
			end
			-- Stay with the recipe you're making unless another is clearly cheaper
			local last = plan.steps[#plan.steps]
			local cur = last and last.recipe
			if cur and cur ~= best and (not cur.unlearned or cur.learn <= level) then
				local p = SP.Chance(cur, level, skill)
				if p > 0 and (p >= TRAINER_CHANCE or bestP < TRAINER_CHANCE) and Score(cur, p) <= bestScore * SWITCH then
					best, bestScore, bestP = cur, Score(cur, p), p
				end
			end
			-- Only low-chance recipes left and no trainer recipe known beyond
			-- this point: stop and point to the trainer instead of grinding
			-- green recipes.
			if not fill and bestP < TRAINER_CHANCE and level >= skill + MIN_POINTS and not Ahead(level) then
				plan.trainerAt = level return false
			end

			local crafts = 1 / bestP
			local stepCost = 0
			collect = {}
			for _, rg in ipairs(best.reagents) do
				stepCost = stepCost + Acquire(rg.itemID, rg.count * crafts, 0)
			end
			local got = collect
			collect = nil
			if best.output then
				stock[best.output] = Have(best.output) + (best.outputCount or 1) * crafts
				produced[best.output] = (produced[best.output] or 0) + (best.outputCount or 1) * crafts
			end

			local gain = min(best.ups, upTo - level)
			if last and last.recipe == best then
				last.to = level + gain
				last.crafts = last.crafts + crafts
				last.cost = last.cost + stepCost
				for id, n in pairs(got) do last.get[id] = (last.get[id] or 0) + n end
			else
				local step = { recipe = best, from = level, to = level + gain, crafts = crafts, cost = stepCost, fill = fill or nil, get = got }
				if best.unlearned and not taught[best] then
					taught[best] = true
					step.learn, step.learnAt, step.trainCost, step.source = true, best.learn, best.trainCost, best.how or "trainer"
					step.where, step.item = best.where, best.recipeItem
					plan.trainCost = plan.trainCost + (best.trainCost or 0)
				end
				plan.steps[#plan.steps + 1] = step
			end
			level = level + gain
		end
		return level >= upTo
	end

	Search(target, false)

	plan.reached = level
	plan.overtime = SP.OvertimeRank and SP.OvertimeRank() or 0
	-- Everything the plan uses (saved for the Characters view)
	plan.needs = {}
	for id, amount in pairs(need) do
		local n = ceil(amount - 0.05)
		if n > 0 then plan.needs[id] = n end
	end
	for _, step in ipairs(plan.steps) do
		step.crafts = ceil(step.crafts - 0.05)
		plan.total = plan.total + step.cost
	end
	plan.total = plan.total + (plan.trainCost or 0)
	-- What's left of what you crafted (not used later in the plan) and what it sells for
	plan.resale, plan.sell, plan.resaleMode = 0, {}, resaleMode
	if resaleMode ~= "off" then
		for id, made in pairs(produced) do
			local left = floor(min(made, max(0, stock[id] or 0)) + 0.05)
			local v, src = Resale(id)
			if left > 0 and v > 0 then
				plan.sell[#plan.sell + 1] = { itemID = id, count = left, each = v, source = src, value = v * left }
				plan.resale = plan.resale + v * left
			end
		end
		table.sort(plan.sell, function(a, b) return a.value > b.value end)
	end
	plan.net = plan.total - plan.resale
	for r, crafts in pairs(make) do
		local n = ceil(crafts - 0.05)
		if n > 0 then plan.prep[#plan.prep + 1] = { recipe = r, crafts = n, learn = r.unlearned or nil, learnAt = r.learn, trainCost = r.trainCost,
			source = r.unlearned and (r.how or "trainer") or nil, where = r.where, item = r.recipeItem } end
	end
	table.sort(plan.prep, function(a, b) return a.crafts > b.crafts end)

	plan.gatherWarn, plan.gatherCount = {}, 0
	local warned = {}
	for id, amount in pairs(buy) do
		local n = ceil(amount - 0.05)
		if n > 0 then
			local p, src = Price(id)
			local gold = not selfMode or src == "vendor"
			plan.shopping[#plan.shopping + 1] = { itemID = id, count = n, price = gold and p or nil, source = src,
				cost = (gold and p) and p * n or nil, gather = (not gold) or nil }
			if selfMode and not gold then
				plan.gatherCount = plan.gatherCount + n
				-- a gathering skill you still need to raise
				local g = SP.GATHER[id]
				local gs = SP.Gatherers(id)
				local able = false
				for _, who in ipairs(gs or {}) do if who.ok then able = true end end
				local key = g and (g.prof .. ":" .. g.skill)
				if g and not able and not warned[key] then
					warned[key] = true
					local mine = gs and gs[1]
					plan.gatherWarn[#plan.gatherWarn + 1] = { prof = g.prof, skill = g.skill, node = g.node, itemID = id,
						have = mine and mine.skill or 0, who = mine and not mine.me and mine.who or nil }
				end
			end
		end
	end
	table.sort(plan.gatherWarn, function(a, b) if a.prof ~= b.prof then return a.prof < b.prof end return a.skill < b.skill end)
	for name, amount in pairs(nameBuy) do
		local n = ceil(amount - 0.05)
		if n > 0 then plan.shopping[#plan.shopping + 1] = { name = name, count = n } end
	end
	table.sort(plan.shopping, function(a, b)
		if (a.gather and 1 or 0) ~= (b.gather and 1 or 0) then return a.gather and true or false end
		if a.gather then return a.count > b.count end
		return (a.cost or 0) > (b.cost or 0)
	end)

	-- Where each material is first used (for the fishing helper)
	plan.usedBy = {}
	for _, step in ipairs(plan.steps) do
		for _, rg in ipairs(step.recipe.reagents or {}) do
			if rg.itemID and not plan.usedBy[rg.itemID] then
				plan.usedBy[rg.itemID] = { recipe = step.recipe.name, from = step.from, to = step.to }
			end
		end
	end

	-- Recipes on the route you still need to learn (next one first).
	plan.toLearn = {}
	for _, step in ipairs(plan.steps) do
		if step.learn then plan.toLearn[#plan.toLearn + 1] = step end
	end
	for _, prep in ipairs(plan.prep) do
		if prep.learn then
			plan.toLearn[#plan.toLearn + 1] = { recipe = prep.recipe, learn = true, learnAt = prep.learnAt, from = prep.learnAt,
				trainCost = prep.trainCost, source = prep.source, where = prep.where, item = prep.item }
		end
	end
	table.sort(plan.toLearn, function(a, b) return (a.learnAt or a.from or 0) < (b.learnAt or b.from or 0) end)
	return plan
end

-- Send the shopping list to Auctionator as a shopping list.
function SP.ExportToAuctionator(plan)
	if not (SP.HasAuctionator() and Auctionator.API.v1.CreateShoppingList) then return false, "Auctionator isn't loaded" end
	local api = Auctionator.API.v1
	local terms = {}
	for _, item in ipairs(plan.shopping) do
		if item.source ~= "vendor" and not item.gather then
			local name = item.name or SP.ItemName(item.itemID)
			local ok, s = pcall(api.ConvertToSearchString, "Profession Pathfinder", { searchString = name, isExact = true, quantity = item.count })
			terms[#terms + 1] = ok and s or name
		end
	end
	if #terms == 0 then return false, "nothing to buy at the auction house" end
	local name = "Pathfinder: " .. (plan.prof.label or plan.prof.name or "Profession")
	local ok, err = pcall(api.CreateShoppingList, "Profession Pathfinder", name, terms)
	if not ok then return false, tostring(err) end
	return true, name
end
