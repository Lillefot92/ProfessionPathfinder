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
	return { id = id, name = n[1], title = n[2] ~= "" and n[2] or nil, faction = n[3], area = n[4], map = n[5],
		x = n[6], y = n[7], zone = zone, rep = n[9] == "rep", event = n[9] == "event" }
end

function SP.Friendly(npc)
	local f = Faction()
	return npc and (not f or npc.faction:find(f, 1, true) ~= nil)
end

-- "Orgrimmar 82.3, 23.0"
function SP.NpcPlace(npc)
	if not npc then return "" end
	return string.format("%s %.1f, %.1f", npc.zone or "?", npc.x or 0, npc.y or 0)
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
			if cont then
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
-- Every way to get a recipe spell, best first:
-- { kind = "bags" | "vendor" | "ah" | "drop" | "quest" | "object", item, skill, price, npc, ... }
function SP.RecipeSources(spellID)
	local rows = SP.RECIPE_ITEMS and SP.RECIPE_ITEMS[spellID]
	if not rows then return {} end
	local out = {}
	for _, e in ipairs(rows) do
		local item, skill, price, bop, vendors, drops, nDrops, objects, quests =
			e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8], e[9]
		local base = { item = item, skill = skill, bop = bop }
		local function Add(t) for k, v in pairs(base) do if t[k] == nil then t[k] = v end end out[#out + 1] = t end
		if SP.Owned and SP.Owned(item) > 0 then Add({ kind = "bags", price = 0 }) end
		-- vendors anyone can buy from; reputation vendors are shown, holiday ones left out
		local open, rep = {}, {}
		for _, npc in ipairs(SP.SortByDistance(vendors)) do
			if npc.rep then rep[#rep + 1] = npc elseif not npc.event then open[#open + 1] = npc end
		end
		if open[1] then Add({ kind = "vendor", price = price, npc = open[1], others = #open - 1 }) end
		if rep[1] then Add({ kind = "rep", price = price, npc = rep[1] }) end
		if not bop then
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
	if s.kind == "vendor" then
		return "Buy " .. item .. " from " .. s.npc.name .. " (" .. SP.NpcPlace(s.npc) .. ")"
			.. (s.price and (" for about " .. SP.Money(s.price)) or "") .. "."
	end
	if s.kind == "rep" then
		return item .. " is sold by " .. s.npc.name .. " (" .. SP.NpcPlace(s.npc) .. ") to players with enough reputation."
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

-- Where to learn a planned recipe (a plan step, prep entry or toLearn
-- entry): text for notes and chat, and the NPC to pin (if any)
function SP.LearnWhere(prof, e)
	local how = e.source or "trainer"
	local item = e.item and SP.RecipeItemName(e.item)
	if how == "bags" then return "the " .. (item or "recipe") .. " in your bags" end
	if how == "ah" then return "the Auction House (" .. (item or "recipe") .. ")" end
	if how == "vendor" and e.where then
		return (item or "the recipe") .. " from " .. e.where.name .. " in " .. SP.NpcPlace(e.where), e.where
	end
	local t = SP.RecipeTrainer(prof and prof.name, e.learnAt or e.from)
	if t then return t.name .. " in " .. SP.NpcPlace(t), t end
	return "your trainer"
end
