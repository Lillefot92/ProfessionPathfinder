-- Profession Pathfinder - where to go
-- Trainers for each rank, rank books and quests, and where recipe items come
-- from (vendors, drops, quests), from Sources.lua. Sorted by distance from
-- you, and pinned on your map when you click them.

local ADDON, SP = ...

local function Faction()
	local f = UnitFactionGroup and UnitFactionGroup("player")
	return f == "Horde" and "H" or (f == "Alliance" and "A" or nil)
end
SP.FactionLetter = Faction

-- An NPC from Sources.lua, with the zone name in your language
function SP.Npc(id)
	local n = SP.NPCS and SP.NPCS[id]
	if not n then return end
	local zone = n[8]
	if C_Map and C_Map.GetAreaInfo then
		local ok, z = pcall(C_Map.GetAreaInfo, n[4])
		if ok and type(z) == "string" and z ~= "" then zone = z end
	end
	if not n[6] then zone = n[8] end -- no fixed spot: keep the more exact place name
	return { id = id, name = n[1], title = n[2] ~= "" and n[2] or nil, faction = n[3], area = n[4], map = n[5],
		x = n[6], y = n[7], zone = zone, rep = n[9] == "rep", event = n[9] == "event", note = n[10] }
end

function SP.Friendly(npc)
	local f = Faction()
	return npc and (not f or npc.faction:find(f, 1, true) ~= nil)
end

-- "Orgrimmar 82.3, 23.0"
function SP.NpcPlace(npc)
	if not npc then return "" end
	if not npc.x then return npc.zone or "?" end
	return string.format("%s %.1f, %.1f", npc.zone or "?", npc.x, npc.y or 0)
end

-- Your position in world coordinates: continent, x, y
local function WorldPos(map, x, y)
	if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
	local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
	if ok and cont and pos then
		local px, py = pos.x, pos.y
		if pos.GetXY then px, py = pos:GetXY() end
		if type(px) == "number" and type(py) == "number" then return cont, px, py end
	end
end
local function MyPos()
	if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
	local okM, map = pcall(C_Map.GetBestMapForUnit, "player")
	if not okM or not map then return end
	local okP, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
	if not okP or not pos then return end
	local x, y = pos.x, pos.y
	if pos.GetXY then x, y = pos:GetXY() end
	if type(x) ~= "number" or (issecretvalue and issecretvalue(x)) then return end
	return map, WorldPos(map, x, y)
end

-- Sort NPC IDs: friendly ones only, nearest first (same continent), then
-- the rest. Returns NPC tables.
function SP.SortByDistance(ids)
	local out = {}
	local myMap, cont, mx, my = MyPos()
	for _, id in ipairs(ids or {}) do
		local npc = SP.Npc(id)
		if npc and SP.Friendly(npc) then
			npc.dist = math.huge
			if cont and npc.x then
				local c, x, y = WorldPos(npc.map, npc.x / 100, npc.y / 100)
				if c == cont then npc.dist = math.sqrt((x - mx) ^ 2 + (y - my) ^ 2) end
			end
			if myMap and npc.map == myMap and npc.dist == math.huge then npc.dist = 0 end
			out[#out + 1] = npc
		end
	end
	table.sort(out, function(a, b)
		if a.dist ~= b.dist then return a.dist < b.dist end
		return a.name < b.name
	end)
	return out
end

-- Pin an NPC on your map (and TomTom, if you use it)
function SP.Pin(npc)
	if not npc then return end
	local title = npc.name .. (npc.title and (" <" .. npc.title .. ">") or "")
	if not npc.x then
		print("|cff66bbffProfession Pathfinder:|r " .. title .. ", " .. SP.NpcPlace(npc) .. " (moves between a few spots, so there's no pin).")
		return
	end
	local done = false
	if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
		local ok = pcall(function()
			if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(npc.map) then error("no") end
			C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(npc.map, npc.x / 100, npc.y / 100))
			if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
		end)
		done = ok
	end
	if TomTom and TomTom.AddWaypoint then
		pcall(TomTom.AddWaypoint, TomTom, npc.map, npc.x / 100, npc.y / 100, { title = title, from = "Profession Pathfinder" })
		done = true
	end
	print("|cff66bbffProfession Pathfinder:|r " .. title .. ", " .. SP.NpcPlace(npc) .. (done and " - pinned on your map." or "."))
end

---------------------------------------------------------------------------
-- Ranks: who teaches the next one
---------------------------------------------------------------------------
local RANK_CAP = { Apprentice = 75, Journeyman = 150, Expert = 225, Artisan = 300 }

-- Trainers for a profession that teach up to at least `cap`, nearest first
function SP.TrainersFor(profKey, cap)
	local ids = {}
	for _, t in ipairs(SP.TRAINERS and SP.TRAINERS[profKey] or {}) do
		if t[2] >= (cap or 0) then ids[#ids + 1] = t[1] end
	end
	return SP.SortByDistance(ids)
end

local function QuestName(q)
	if C_QuestLog and C_QuestLog.GetTitleForQuestID then
		local ok, t = pcall(C_QuestLog.GetTitleForQuestID, q.id)
		if ok and type(t) == "string" and t ~= "" then return t end
	end
	return q.name
end

local function BookName(id, fallback)
	local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
	return n or fallback
end

-- Where to learn a rank. Returns a list of places:
-- { npc = NPC, how = "train" | "book" | "quest", text = "..." }, nearest first.
function SP.RankPlaces(profKey, rank)
	local out = {}
	local special = SP.RANK_SPECIAL and SP.RANK_SPECIAL[profKey] and SP.RANK_SPECIAL[profKey][rank]
	if special and special.book then
		local book = BookName(special.book, special.name)
		for _, npc in ipairs(SP.SortByDistance(special.vendors)) do
			out[#out + 1] = { npc = npc, how = "book", item = special.book,
				text = "Buy the book " .. book .. " from " .. npc.name .. " (" .. SP.NpcPlace(npc) .. ")" }
		end
	elseif special and special.quests then
		for _, q in ipairs(special.quests) do
			for _, npc in ipairs(SP.SortByDistance(q.starts)) do
				out[#out + 1] = { npc = npc, how = "quest", quest = q.id,
					text = "Do the quest " .. QuestName(q) .. " from " .. npc.name .. " (" .. SP.NpcPlace(npc) .. ")" }
			end
		end
		table.sort(out, function(a, b) return a.npc.dist < b.npc.dist end)
	else
		for _, npc in ipairs(SP.TrainersFor(profKey, RANK_CAP[rank] or 0)) do
			out[#out + 1] = { npc = npc, how = "train",
				text = npc.name .. (npc.title and (" <" .. npc.title .. ">") or "") .. " (" .. SP.NpcPlace(npc) .. ")" }
		end
	end
	return out
end

-- Short text for chat and notes: "Saru Steelfury in Orgrimmar 82.3, 23.0"
function SP.RankWhere(profKey, rank)
	local p = SP.RankPlaces(profKey, rank)[1]
	if not p then return end
	if p.how == "book" then
		return "the book " .. BookName(p.item, "") .. " from " .. p.npc.name .. " in " .. SP.NpcPlace(p.npc), p
	elseif p.how == "quest" then
		return "the quest " .. (p.text:match("quest (.-) from ") or "") .. " from " .. p.npc.name .. " in " .. SP.NpcPlace(p.npc), p
	end
	return p.npc.name .. " in " .. SP.NpcPlace(p.npc), p
end

-- The nearest trainer who can teach a recipe you learn at `learnAt`
function SP.RecipeTrainer(profKey, learnAt)
	local cap = (learnAt or 0) <= 75 and 75 or (learnAt <= 150 and 150 or (learnAt <= 225 and 225 or 300))
	return SP.TrainersFor(profKey, cap)[1]
end

---------------------------------------------------------------------------
-- Recipe items: where a recipe comes from when no trainer teaches it
---------------------------------------------------------------------------
-- Reputation: your standing with a faction, 0 Hated .. 3 Neutral, 4 Friendly,
-- 5 Honored, 6 Revered, 7 Exalted (nil if the game doesn't say)
local FACTION_NAMES = { [59] = "Thorium Brotherhood", [270] = "Zandalar Tribe", [529] = "Argent Dawn", [576] = "Timbermaw Hold",
	[609] = "Cenarion Circle", [910] = "Brood of Nozdormu" }
local STANDING_NAMES = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" }

function SP.Standing(factionID)
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local ok, d = pcall(C_Reputation.GetFactionDataByID, factionID)
		if ok and type(d) == "table" and type(d.reaction) == "number" then return d.reaction - 1 end
	end
	if GetFactionInfoByID then
		local ok, _, _, standing = pcall(GetFactionInfoByID, factionID)
		if ok and type(standing) == "number" and standing > 0 then return standing - 1 end
	end
end

function SP.FactionName(factionID)
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local ok, d = pcall(C_Reputation.GetFactionDataByID, factionID)
		if ok and type(d) == "table" and type(d.name) == "string" and d.name ~= "" then return d.name end
	end
	if GetFactionInfoByID then
		local ok, name = pcall(GetFactionInfoByID, factionID)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
	return FACTION_NAMES[factionID] or ("faction " .. factionID)
end

-- Your faction's trade company (the camps that sell plans for Merchant's Favor)
function SP.TradeFaction()
	local f = UnitFactionGroup and UnitFactionGroup("player")
	return f == "Horde" and 2587 or (f == "Alliance" and 2586 or nil)
end

-- How much of a currency you have, and its name
local CURRENCY_NAMES = { [3402] = "Merchant's Favor" }
function SP.CurrencyAmount(id)
	if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
		local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
		if ok and type(info) == "table" and type(info.quantity) == "number" then return info.quantity end
	end
	if GetCurrencyInfo then
		local ok, _, amount = pcall(GetCurrencyInfo, id)
		if ok and type(amount) == "number" then return amount end
	end
end

function SP.CurrencyName(id)
	if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
		local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
		if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then return info.name end
	end
	return CURRENCY_NAMES[id] or ("currency " .. id)
end

-- How to earn Merchant's Favor and trade company reputation
function SP.FavorHow()
	local f = UnitFactionGroup and UnitFactionGroup("player")
	local who = f == "Alliance" and "Marcy Baker at Three Corners, Redridge" or "Dokimi west of the Crossroads"
	return "Earn Merchant's Favor by turning in Waylaid Crates to " .. who .. ", and reputation with Craftsman's Writs"
end

function SP.StandingName(standing)
	if not standing then return "?" end
	local label = _G["FACTION_STANDING_LABEL" .. (standing + 1)]
	return type(label) == "string" and label or STANDING_NAMES[standing + 1] or "?"
end

-- Your other characters that hold an item, from Syndicator (if you use it):
-- { { name = "Banky", spot = "bank" }, ... }
function SP.AltsWith(itemID)
	local api = Syndicator and Syndicator.API and Syndicator.API.GetInventoryInfoByItemID
	if not api then return {} end
	local ok, info = pcall(api, itemID, true, true)
	if not ok or type(info) ~= "table" or type(info.characters) ~= "table" then return {} end
	local me = UnitName and UnitName("player")
	local out = {}
	for _, c in ipairs(info.characters) do
		if type(c) == "table" and c.character and c.character ~= me then
			local spot = ((c.bags or 0) > 0 and "bags") or ((c.bank or 0) > 0 and "bank") or ((c.mail or 0) > 0 and "mail") or nil
			if spot then out[#out + 1] = { name = c.character, spot = spot } end
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- Every way to get a recipe spell, best first:
-- { kind = "bags" | "vendor" | "ah" | "drop" | "quest" | "object", item, skill, price, npc, ... }
function SP.RecipeSources(spellID)
	local rows = SP.RECIPE_ITEMS and SP.RECIPE_ITEMS[spellID]
	if not rows then return {} end
	local out = {}
	for _, e in ipairs(rows) do
		local item, skill, price, bop, vendors, drops, nDrops, objects, quests, faction, standing, currency, amount =
			e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8], e[9], e[10], e[11], e[12], e[13]
		if faction == -1 then faction = SP.TradeFaction() end -- your trade company
		local base = { item = item, skill = skill, bop = bop }
		-- a plan bought with a currency (Merchant's Favor): planned only if you have
		-- enough of it, and the option is on
		local curOK = true
		if currency then
			local haveCur = SP.CurrencyAmount(currency)
			base.currency, base.amount, base.haveCur = currency, amount, haveCur
			curOK = not (SP.db and SP.db.favorPlans == false) and (haveCur or 0) >= amount
		end
		local function Add(t) for k, v in pairs(base) do if t[k] == nil then t[k] = v end end out[#out + 1] = t end
		-- a plan that needs reputation: only if you have it
		local have = faction and SP.Standing(faction)
		local repOK = not faction or (have and have >= standing)
		if faction then base.faction, base.standing, base.have = faction, standing, have end
		if repOK and SP.Owned and SP.Owned(item) > 0 then
			Add({ kind = "bags", price = 0 })
		elseif repOK and not bop then
			-- on one of your other characters: mail it over
			local alt = SP.AltsWith(item)[1]
			if alt then Add({ kind = "alt", price = 0, alt = alt }) end
		end
		-- vendors anyone can buy from, and reputation vendors once you have the
		-- reputation; the rest are shown, holiday vendors left out
		local open, rep = {}, {}
		for _, npc in ipairs(SP.SortByDistance(vendors)) do
			if npc.event then -- left out
			elseif (npc.rep and not (faction and repOK)) or not repOK then rep[#rep + 1] = npc
			else open[#open + 1] = npc end
		end
		if open[1] then
			if curOK then Add({ kind = "vendor", price = price, npc = open[1], others = #open - 1 })
			else Add({ kind = "favor", npc = open[1] }) end
		end
		if rep[1] then Add({ kind = "rep", price = price, npc = rep[1] }) end
		if not bop and repOK then
			local ah = SP.Price and SP.Price(item)
			if ah then Add({ kind = "ah", price = ah }) end
		end
		for _, q in ipairs(quests or {}) do Add({ kind = "quest", quest = q }) end
		if (nDrops or 0) > 0 then
			Add({ kind = "drop", drops = SP.SortByDistance(drops), count = nDrops })
		end
		if (objects or 0) > 0 then Add({ kind = "object", count = objects }) end
	end
	return out
end

function SP.RecipeItemName(id)
	local n = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
	if not n and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
	return n or ("item " .. id)
end

-- One line describing a source, for tooltips
function SP.SourceText(s)
	local item = SP.RecipeItemName(s.item)
	if s.kind == "bags" then return "You have " .. item .. ": use it to learn the recipe." end
	if s.kind == "alt" then return s.alt.name .. " has " .. item .. " (" .. s.alt.spot .. "): mail it to this character." end
	if s.kind == "vendor" then
		local cost = s.currency and (" for " .. s.amount .. " " .. SP.CurrencyName(s.currency))
			or (s.price and (" for about " .. SP.Money(s.price))) or ""
		return "Buy " .. item .. " from " .. s.npc.name .. " (" .. SP.NpcPlace(s.npc) .. ")" .. cost .. "."
	end
	if s.kind == "favor" then
		local name = SP.CurrencyName(s.currency)
		local at = item .. " costs " .. s.amount .. " " .. name .. " at " .. s.npc.name .. " (" .. SP.NpcPlace(s.npc) .. ")"
		if SP.db and SP.db.favorPlans == false then
			return at .. ". Plans bought with " .. name .. " are turned off in the options."
		end
		return at .. "; you have " .. (s.haveCur or 0) .. ". " .. SP.FavorHow() .. "."
	end
	if s.kind == "rep" then
		local who = s.npc.name .. " (" .. SP.NpcPlace(s.npc) .. ")"
		if s.faction then
			return item .. " is sold by " .. who .. " at " .. SP.StandingName(s.standing) .. " with " .. SP.FactionName(s.faction)
				.. (s.have and (" (you're " .. SP.StandingName(s.have) .. ")") or "")
				.. (s.currency and (", for " .. s.amount .. " " .. SP.CurrencyName(s.currency)) or "") .. "."
		end
		if s.npc.note then return item .. " is sold by " .. who .. ", " .. s.npc.note .. "." end
		return item .. " is sold by " .. who .. " to players with enough reputation."
	end
	if s.kind == "ah" then return "Buy " .. item .. " at the Auction House (about " .. SP.Money(s.price) .. ")." end
	if s.kind == "quest" then
		local name = SP.QUEST_NAMES and SP.QUEST_NAMES[s.quest] or ("quest " .. s.quest)
		if C_QuestLog and C_QuestLog.GetTitleForQuestID then
			local ok, t = pcall(C_QuestLog.GetTitleForQuestID, s.quest)
			if ok and type(t) == "string" and t ~= "" then name = t end
		end
		return item .. " is a reward from the quest " .. name .. "."
	end
	if s.kind == "drop" then
		if s.count > 5 or not s.drops[1] then return item .. " drops from many creatures (" .. s.count .. ")." end
		local names = {}
		for i = 1, math.min(3, #s.drops) do names[#names + 1] = s.drops[i].name .. " (" .. (s.drops[i].zone or "?") .. ")" end
		return item .. " drops from " .. table.concat(names, ", ") .. "."
	end
	if s.kind == "object" then return item .. " is found in chests or objects in the world." end
	return item
end

---------------------------------------------------------------------------
-- Recipes you're missing (once you've reached 300, or from the window's
-- button): what this character doesn't know yet in the open profession and
-- how to get each one, easiest first.
---------------------------------------------------------------------------
SP.MISSING_ORDER = { "now", "trainer", "vendor", "favor", "rep", "quest", "drop", "ah", "world", "seasonal", "unknown" }
SP.MISSING_TITLES = {
	now = "Ready to learn now", trainer = "From a trainer, at a higher skill", vendor = "Buy from a vendor",
	favor = "Buy with Merchant's Favor", rep = "Needs reputation", quest = "Quest rewards", drop = "Drops",
	ah = "Auction House", world = "Taught by an NPC out in the world", seasonal = "Holiday vendors (only during the event)",
	unknown = "Source not known yet",
}

-- Quest starters you can talk to (your faction), nearest first
local function QuestStarters(qid)
	local info = SP.QUEST_INFO and SP.QUEST_INFO[qid]
	if not info then return nil, nil end
	return SP.SortByDistance(info[3]), info
end

local function PickSource(prof, id, srcs)
	-- easiest first: bags, an alt, a vendor you can buy from now, Favor,
	-- reputation, a quest, a drop, the Auction House
	local RANK = { bags = 1, alt = 2, vendor = 3, favor = 4, rep = 5, quest = 6, drop = 7, object = 8, ah = 9 }
	local best
	for _, src in ipairs(srcs) do
		local usable = true
		if src.kind == "quest" then
			local starters, info = QuestStarters(src.quest)
			-- a quest only the other faction can start
			if info and #info[3] > 0 and #starters == 0 then usable = false end
			src.starter, src.info = starters and starters[1], info
		end
		if usable and RANK[src.kind] and (not best or RANK[src.kind] < RANK[best.kind]) then best = src end
	end
	return best
end

-- The nearest trainer for a recipe; some trainers are only known for the
-- lower ranks (Cooking), so fall back to them
local function NearestTrainer(prof, at)
	if not SP.RecipeTrainer then return nil end
	for _, lvl in ipairs({ at or 1, 225, 150, 75 }) do
		if lvl <= (at or 1) then
			local t = SP.RecipeTrainer(prof.name, lvl)
			if t then return t end
		end
	end
end

-- From SP.COLLECT (wow.gg): recipes the rest of the data has no source for
local function MySide(side)
	local f = UnitFactionGroup and UnitFactionGroup("player")
	return side == nil or side == "" or (side == "h" and f == "Horde") or (side == "a" and f == "Alliance")
end

local function Pct(x) return x and (x >= 1 and string.format("%d%%", math.floor(x + 0.5)) or string.format("%.1f%%", x)) or "?" end

local function CollectEntry(prof, e, c)
	local item = c.n or "the recipe"
	if c.t then
		local d = SP.DATA[prof.id] and SP.DATA[prof.id][e.id]
		local at = d and d[1] or 1
		if at > 300 then return nil end  -- needs more than 300: not in Forever
		local t = NearestTrainer(prof, at)
		e.group = at <= (prof.skill or 0) and "now" or "trainer"
		e.at, e.pin, e.where = at, t, t and t.zone or "a trainer"
		table.insert(e.tips, 1, "A trainer teaches it from about skill " .. at .. (t and (": nearest " .. t.name .. " in " .. SP.NpcPlace(t)) or "") .. ".")
		return e
	end
	local lines, group, where = {}, nil, nil
	local mine = 0
	for _, v in ipairs(c.v or {}) do
		if MySide(v[3]) then
			mine = mine + 1
			if mine <= 3 then
				local cost = (c.c and c.c[2] and (" for " .. c.c[2] .. " " .. (c.c[1] or "currency")))
					or (v[4] and (" for about " .. SP.Money(v[4]))) or ""
				lines[#lines + 1] = "Buy " .. item .. " from " .. (v[1] or "a vendor") .. " (" .. (v[2] or "?") .. ")" .. cost .. "."
			end
			group = group or ((c.c and c.c[1] == "Merchant's Favor") and "favor" or "vendor")
			where = where or v[2]
		end
	end
	local quests = 0
	for _, q in ipairs(c.q or {}) do
		if MySide(q[3]) then
			quests = quests + 1
			lines[#lines + 1] = item .. " is a reward from the quest " .. (q[1] or "?") .. " (" .. (q[2] or "?") .. (q[4] and (", level " .. q[4]) or "") .. ")."
			group = group or "quest"
			where = where or q[2]
		end
	end
	if c.d then
		local names = {}
		for _, d in ipairs(c.d) do names[#names + 1] = (d[1] or "?") .. " (" .. (d[2] or "?") .. (d[3] and (", " .. Pct(d[3])) or "") .. ")" end
		lines[#lines + 1] = item .. " drops from " .. table.concat(names, ", ")
			.. ((c.dn or 0) > #c.d and (" and " .. (c.dn - #c.d) .. " more") or "") .. "."
		group = group or "drop"
		where = where or c.d[1][2]
	end
	if c.o then
		lines[#lines + 1] = item .. " is found in chests or objects in the world."
		group = group or "drop"
	end
	-- only the other faction can buy it or do the quest
	if not group then return nil end
	e.group, e.where = group, where
	for i, l in ipairs(lines) do table.insert(e.tips, i, l) end
	e.tips[#e.tips + 1] = "|cff999999Source from wow.gg's WoW Forever lists.|r"
	return e
end

-- "Skill-ups: orange until 175, gray from 215"; skill stops at 300, so colors
-- above it are left out ("orange all the way to 300")
function SP.SkillUpsText(yellow, gray)
	if yellow >= 300 then return "Skill-ups: orange all the way to 300." end
	if gray > 300 then return "Skill-ups: orange until " .. yellow .. ", then yellow or green up to 300." end
	return "Skill-ups: orange until " .. yellow .. ", gray from " .. gray .. "."
end

function SP.MissingEntry(prof, id, r)
	local line = prof.id
	local e = { id = id, name = r and r.name or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)) or ("recipe " .. id),
		icon = r and r.icon, tips = {} }
	local d = SP.DATA[line] and SP.DATA[line][id]
	if d then e.tips[#e.tips + 1] = "|cff999999" .. SP.SkillUpsText(d[1], d[2]) .. "|r" end
	if SP.NPC_TAUGHT and SP.NPC_TAUGHT[id] then
		e.group, e.where = "world", SP.NPC_TAUGHT[id]
		table.insert(e.tips, 1, "Taught by " .. SP.NPC_TAUGHT[id] .. ".")
		return e
	end
	local at, how = SP.LearnAt(id, line)
	if how == "trainer" or how == "maybe" then
		if (at or 0) > 300 then return nil end  -- needs more than 300: not in Forever
		local t = NearestTrainer(prof, at)
		e.group = (at or 0) <= (prof.skill or 0) and "now" or "trainer"
		e.at, e.pin = at, t
		e.where = t and t.zone or "a trainer"
		local sure = how == "trainer" or SP.TrainerChecked(id, line)
		table.insert(e.tips, 1, (sure and "A trainer teaches it" or "Probably a trainer teaches it") .. " from skill " .. (at or "?")
			.. (t and (": nearest " .. t.name .. " in " .. SP.NpcPlace(t)) or "") .. ".")
		return e
	end
	local c = SP.COLLECT and SP.COLLECT[id]
	if c and not (SP.RECIPE_ITEMS and SP.RECIPE_ITEMS[id]) then return CollectEntry(prof, e, c) end
	local srcs = SP.RecipeSources(id)
	local best = PickSource(prof, id, srcs)
	local at_ = 0
	for _, src in ipairs(srcs) do
		if src.kind ~= "quest" or src.starter or not src.info or #src.info[3] == 0 then
			at_ = at_ + 1
			table.insert(e.tips, at_, SP.SourceText(src))
		end
	end
	if not best then
		-- the recipe item exists but only the other faction can buy it: not for you
		local rows = SP.RECIPE_ITEMS and SP.RECIPE_ITEMS[id]
		if rows then
			-- sold only during a holiday (in your faction's cities)
			local CITY = { Horde = { Orgrimmar = true, ["Thunder Bluff"] = true, Undercity = true },
				Alliance = { ["Stormwind City"] = true, Ironforge = true, Darnassus = true } }
			local mine = CITY[UnitFactionGroup and UnitFactionGroup("player") or ""] or {}
			for _, row in ipairs(rows) do
				local list = SP.SortByDistance(row[5])
				table.sort(list, function(a, b) return (mine[a.zone] and 1 or 0) > (mine[b.zone] and 1 or 0) end)
				for _, npc in ipairs(list) do
					if npc.event then
						e.group, e.pin, e.where = "seasonal", npc, npc.zone
						table.insert(e.tips, 1, "Sold by " .. npc.name .. " (" .. SP.NpcPlace(npc) .. ") during the holiday.")
						return e
					end
				end
			end
			for _, row in ipairs(rows) do
				local vendorsOther = row[5] and #row[5] > 0 and #SP.SortByDistance(row[5]) == 0
				local questsOther = row[9] and #row[9] > 0
				for _, qid in ipairs(row[9] or {}) do
					local starters, info = QuestStarters(qid)
					if not (info and #info[3] > 0 and #starters == 0) then questsOther = false end
				end
				local onlyThose = (#(row[5] or {}) == 0 or vendorsOther) and (#(row[9] or {}) == 0 or questsOther)
					and (row[7] or 0) == 0 and (row[8] or 0) == 0
				if onlyThose and (vendorsOther or questsOther) then return nil end
			end
		end
		e.group = "unknown"
		if #e.tips <= 1 then table.insert(e.tips, 1, "No source in the addon's data yet.") end
		return e
	end
	e.source = best
	local kind = best.kind
	e.group = (kind == "bags" or kind == "alt") and "now" or (kind == "object" and "drop") or kind
	if kind == "vendor" or kind == "favor" or kind == "rep" then
		e.pin, e.where = best.npc, best.npc.zone
	elseif kind == "quest" then
		local info = best.info
		e.pin = best.starter
		e.where = info and info[1] > 0 and ("level " .. info[1]) or (best.starter and best.starter.zone)
		if best.starter then
			e.tips[#e.tips + 1] = "Starts at " .. best.starter.name .. " (" .. SP.NpcPlace(best.starter) .. ")"
				.. (info and info[2] > 0 and (", from level " .. info[2]) or "") .. "."
		end
	elseif kind == "drop" then
		local first = best.drops and best.drops[1]
		if best.count <= 5 and first then e.pin, e.where = first, first.zone else e.where = best.count .. " creatures" end
		if not best.bop then e.tips[#e.tips + 1] = "|cff999999It can be traded: check the Auction House too.|r" end
	elseif kind == "ah" then
		e.where = SP.Money(best.price)
	elseif kind == "bags" then
		e.where = "in your bags"
	elseif kind == "alt" then
		e.where = "on " .. best.alt.name
	end
	return e
end

function SP.MissingRecipes(prof)
	local out = { known = 0, total = 0, otherSpec = 0, groups = {} }
	local T = C_TradeSkillUI
	local data = prof and SP.DATA and SP.DATA[prof.id]
	if not (T and T.GetAllRecipeIDs and T.GetRecipeInfo and data) then return out end
	local ok, ids = pcall(T.GetAllRecipeIDs)
	if not ok or type(ids) ~= "table" then return out end
	local mine = SP.MySpecs and SP.MySpecs() or {}
	local seen = {}
	for _, id in ipairs(ids) do
		if data[id] and not seen[id] then
			seen[id] = true
			local okI, r = pcall(T.GetRecipeInfo, id)
			if okI and type(r) == "table" and not r.isSalvageRecipe then
				local spec = SP.SPEC_RECIPES and SP.SPEC_RECIPES[id]
				if SP.NOT_LISTED and SP.NOT_LISTED[id] and not r.learned then
					out.unlisted = (out.unlisted or 0) + 1  -- not in WoW Forever
				elseif r.learned then
					out.total, out.known = out.total + 1, out.known + 1
				elseif spec and not mine[spec] then
					out.otherSpec = out.otherSpec + 1  -- another specialization's recipe
				else
					local e = SP.MissingEntry(prof, id, r)
					if e then
						out.total = out.total + 1
						out.groups[e.group] = out.groups[e.group] or {}
						table.insert(out.groups[e.group], e)
					end
				end
			end
		end
	end
	for _, list in pairs(out.groups) do
		table.sort(list, function(a, b)
			if (a.at or 0) ~= (b.at or 0) then return (a.at or 0) < (b.at or 0) end
			return a.name < b.name
		end)
	end
	return out
end

-- Where to learn a planned recipe (a plan step, prep entry or toLearn
-- entry): text for notes and chat, and the NPC to pin (if any)
function SP.LearnWhere(prof, e)
	local how = e.source or "trainer"
	local item = e.item and SP.RecipeItemName(e.item)
	if how == "bags" then return "the " .. (item or "recipe") .. " in your bags" end
	if how == "alt" and type(e.where) == "table" and e.where.spot then
		return "the " .. (item or "recipe") .. " on " .. e.where.name .. " (" .. e.where.spot .. "): mail it to this character"
	end
	if how == "ah" then return "the Auction House (" .. (item or "recipe") .. ")" end
	if how == "vendor" and e.where then
		local favor = e.recipe and e.recipe.favor
		local cost = favor and (" (" .. favor .. " " .. SP.CurrencyName(3402) .. ")") or ""
		return (item or "the recipe") .. " from " .. e.where.name .. " in " .. SP.NpcPlace(e.where) .. cost, e.where
	end
	-- a specialist's recipe: the specialization trainer
	local id = e.id or (e.recipe and e.recipe.id)
	local spec = id and SP.SPEC_RECIPES and SP.SPEC_RECIPES[id]
	local st = spec and SP.SpecTrainer(spec)
	if st then return st.name .. " in " .. SP.NpcPlace(st), st end
	local t = SP.RecipeTrainer(prof and prof.name, e.learnAt or e.from)
	if t then return t.name .. " in " .. SP.NpcPlace(t), t end
	return "your trainer"
end

---------------------------------------------------------------------------
-- Specializations: a note when you can pick one
---------------------------------------------------------------------------
-- "Armorsmith or Weaponsmith: talk to Krathok Moltenfist in Orgrimmar"
function SP.SpecNote(prof, plan)
	if not (prof and SP.SpecChoice) then return nil end
	local level = UnitLevel and UnitLevel("player")
	if issecretvalue and issecretvalue(level) then level = nil end
	local ready = {}
	for _, c in ipairs(SP.SpecChoice(prof.id, prof.skill, level or 0)) do
		-- for a while after it becomes possible (or while the plan leaves recipes out)
		if c.ready and (prof.skill < c.skill + 50 or (plan and plan.specSkipped)) then ready[#ready + 1] = c end
	end
	if #ready == 0 then return nil end
	local groups, order = {}, {}
	for _, c in ipairs(ready) do
		local npc = SP.SpecTrainer(c.spec, true)
		local key = npc and npc.name or "?"
		if not groups[key] then groups[key] = { npc = npc, names = {} }; order[#order + 1] = key end
		table.insert(groups[key].names, c.name)
	end
	-- all in one zone (the Master trainers in Everlook): one line
	local zone, same = nil, #order > 1
	for _, key in ipairs(order) do
		local npc = groups[key].npc
		if not npc then same = false elseif zone == nil then zone = npc.zone elseif npc.zone ~= zone then same = false end
	end
	if same then
		local names, who = {}, {}
		for _, key in ipairs(order) do
			for _, n in ipairs(groups[key].names) do names[#names + 1] = n end
			who[#who + 1] = key
		end
		local function Or(t) return #t > 1 and (table.concat(t, ", ", 1, #t - 1) .. " or " .. t[#t]) or t[1] end
		local text = "You can specialize now: |cffffffff" .. Or(names) .. "|r (talk to " .. Or(who) .. " in " .. zone .. ")."
		if plan and plan.specSkipped then text = text .. " Recipes only a specialist can learn are left out of the plan until then." end
		return text
	end
	local parts = {}
	for _, key in ipairs(order) do
		local g = groups[key]
		local names = table.concat(g.names, " or ")
		parts[#parts + 1] = "|cffffffff" .. names .. "|r" .. (g.npc and (" (talk to " .. g.npc.name .. " in " .. SP.NpcPlace(g.npc) .. ")") or "")
	end
	local text = "You can specialize now: " .. table.concat(parts, ", or ") .. "."
	if plan and plan.specSkipped then
		text = text .. " Recipes only a specialist can learn are left out of the plan until then."
	end
	return text
end

---------------------------------------------------------------------------
-- When a plan stops early: the best ways past that point (plans from
-- reputation vendors, quests and common drops, which aren't planned)
---------------------------------------------------------------------------
local function RecipeName(id)
	if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
		local ok, r = pcall(C_TradeSkillUI.GetRecipeInfo, id)
		if ok and type(r) == "table" and type(r.name) == "string" and r.name ~= "" then return r.name end
	end
	if C_Spell and C_Spell.GetSpellName then
		local ok, n = pcall(C_Spell.GetSpellName, id)
		if ok and type(n) == "string" and n ~= "" then return n end
	end
end

local ORDER = { rep = 1, favor = 1, quest = 2, drop = 3 }
function SP.WaysPast(prof, level, count)
	local data = prof and SP.DATA and SP.DATA[prof.id]
	if not (data and level) then return {} end
	local have = SP.MySpecs and SP.MySpecs() or {}
	local found = {}
	for id, d in pairs(data) do
		local gray = d[2]
		if gray > level and not (SP.COOLDOWN and (SP.COOLDOWN[id] or 0) > 300)
			and not (SP.SpecBlocks and SP.SpecBlocks(id, have)) then
			for _, src in ipairs(SP.RecipeSources(id)) do
				local at = src.skill or d[1]
				local useful = ORDER[src.kind] and at <= level + 10
					and (src.kind ~= "drop" or src.count >= 20) -- rare drops aren't a way
				if useful then
					-- a vendor with a special requirement (Magnus Frostwake) comes last
					local rank = (src.kind == "rep" and not src.faction) and 4 or ORDER[src.kind]
					found[#found + 1] = { id = id, src = src, at = at, rank = rank, gray = gray, now = at <= level,
						gap = src.faction and (src.standing - (src.have or 3)) or 0 }
					break
				end
			end
		end
	end
	table.sort(found, function(a, b)
		if a.rank ~= b.rank then return a.rank < b.rank end
		if a.now ~= b.now then return a.now end
		if a.gap ~= b.gap then return a.gap < b.gap end
		if a.gray ~= b.gray then return a.gray > b.gray end
		return a.id < b.id
	end)
	local out, kinds, seen = {}, {}, {}
	for _, f in ipairs(found) do
		-- a mix: at most two of a kind, one per vendor or quest
		local who = (f.src.npc and ("npc" .. f.src.npc.id)) or (f.src.quest and ("q" .. f.src.quest)) or ("r" .. f.id)
		if (kinds[f.src.kind] or 0) < 2 and not seen[who] then
			seen[who] = true
			kinds[f.src.kind] = (kinds[f.src.kind] or 0) + 1
			local name = RecipeName(f.id)
			if name then
				f.name = name
				out[#out + 1] = f
				if #out >= (count or 3) then break end
			end
		end
	end
	return out
end

-- "Goregasher Grips (plans from Vargus, Silithus 51.2, 38.9, at Friendly with Cenarion Circle; you're Neutral)"
function SP.WayText(f)
	local s, text = f.src, nil
	if s.kind == "rep" then
		local who = s.npc.name .. ", " .. SP.NpcPlace(s.npc)
		if s.faction then
			text = "plans from " .. who .. ", at " .. SP.StandingName(s.standing) .. " with " .. SP.FactionName(s.faction)
				.. (s.have and ("; you're " .. SP.StandingName(s.have)) or "")
				.. (s.currency and (", " .. s.amount .. " " .. SP.CurrencyName(s.currency)) or "")
		else
			text = "plans from " .. who .. (s.npc.note and (", " .. s.npc.note) or "")
		end
	elseif s.kind == "favor" then
		text = "plans from " .. s.npc.name .. ", " .. SP.NpcPlace(s.npc) .. ", " .. s.amount .. " " .. SP.CurrencyName(s.currency)
			.. "; you have " .. (s.haveCur or 0)
	elseif s.kind == "quest" then
		local q = SP.QUEST_NAMES and SP.QUEST_NAMES[s.quest] or ("quest " .. s.quest)
		if C_QuestLog and C_QuestLog.GetTitleForQuestID then
			local ok, t = pcall(C_QuestLog.GetTitleForQuestID, s.quest)
			if ok and type(t) == "string" and t ~= "" then q = t end
		end
		text = "plans from the quest " .. q
	elseif s.kind == "drop" then
		text = "plans drop from " .. s.count .. " kinds of creatures" .. (s.bop and "" or ", or look on the Auction House")
	end
	return f.name .. " (" .. text .. (f.at > 0 and (", from skill " .. f.at) or "") .. ")"
end
