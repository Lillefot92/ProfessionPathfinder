-- Profession Pathfinder - Fishing helper
-- One key to fish: with a fishing pole equipped, your fishing key casts.
-- While the line is out, the same key becomes the game's "Interact" key,
-- which picks the bobber, so pressing it when the bobber splashes catches
-- the fish. You press the key every time: nothing is automatic.
-- Also: louder splash (sound settings while fishing, restored after), a lure
-- timer with Shift + key to put the best lure on the pole, where to fish for
-- your skill, and a catch log (what you caught, what got away, gold per hour).
-- Zones and lures: wow-professions.com, method.gg and kami-labs WoW Forever
-- fishing guides (beta-based; Forever may differ).

local ADDON, SP = ...
local Fish = {}
SP.Fishing = Fish
local PREFIX = "|cff66bbffProfession Pathfinder:|r "

Fish.defaults = {
	fishMode = true,      -- one-key fishing when a pole is equipped
	fishKey = "F",        -- the key
	fishSound = true,     -- louder splash while fishing
	fishLure = true,      -- lure reminder + Shift + key to apply
	fishLog = true,       -- catch log and zone tips on the status line
	fishCook = true,      -- the fish your cooking plan needs
	fishData = {},        -- fishData[zone] = { casts, catches, escapes, time, value, items = {} }
}

for k, v in pairs(Fish.defaults) do SP.defaults[k] = v end

local FISHING_IDS = { 7620, 7731, 7732, 18248 }
-- Lures, best first: { item, bonus, fishing skill needed, where }
local LURES = {
	{ 6533, 100, 100, "Aquadynamic Fish Attractor", "Engineering, or fishing vendors" },
	{ 6532, 75, 100, "Bright Baubles", "Old Man Heming in Booty Bay, fishing vendors" },
	{ 7307, 75, 100, "Flesh Eating Worm", "Duskwood (rare drop)" },
	{ 6811, 50, 50, "Aquadynamic Fish Lens", "Fishing Rack" },
	{ 6530, 50, 50, "Nightcrawlers", "Fishing supply vendors" },
	{ 6529, 25, 1, "Shiny Bauble", "Fishing supply and trade vendors" },
}
Fish.LURES = LURES

-- Zones: the skill the guides send you there from. Below it fish get away more.
local ZONES = {
	["Elwynn Forest"] = 1, ["Dun Morogh"] = 1, ["Teldrassil"] = 1, ["Durotar"] = 1, ["Mulgore"] = 1,
	["Tirisfal Glades"] = 1, ["Zephras Isle"] = 1,
	["Stormwind City"] = 1, ["Ironforge"] = 1, ["Darnassus"] = 1, ["Orgrimmar"] = 1, ["Thunder Bluff"] = 1, ["Undercity"] = 1,
	["Westfall"] = 50, ["Loch Modan"] = 50, ["Darkshore"] = 50, ["Silverpine Forest"] = 50, ["The Barrens"] = 50, ["Wetlands"] = 50,
	["Redridge Mountains"] = 100, ["Duskwood"] = 100, ["Ashenvale"] = 100, ["Stonetalon Mountains"] = 100, ["Hillsbrad Foothills"] = 100,
	["Dustwallow Marsh"] = 125, ["Stranglethorn Vale"] = 125, ["Arathi Highlands"] = 125, ["Alterac Mountains"] = 150,
	["Desolace"] = 150, ["Swamp of Sorrows"] = 150, ["Thousand Needles"] = 150, ["Feralas"] = 150,
	["Tanaris"] = 200, ["Azshara"] = 200, ["Western Plaguelands"] = 200, ["The Hinterlands"] = 200, ["Felwood"] = 225,
	["Un'Goro Crater"] = 225, ["Deadwind Pass"] = 225, ["Moonglade"] = 225,
	["Eastern Plaguelands"] = 250, ["Winterspring"] = 250,
}
Fish.ZONES = ZONES

-- Fish the cooking route uses: where they swim and the fishing skill at
-- which they stop getting away (method.gg, wowhead, wow-professions; Classic
-- values where Forever's guides don't say). water: "inland" = lakes and
-- rivers, "coast" = the sea.
local FISH = {
	[6291] = { name = "Raw Brilliant Smallfish", water = "inland", skill = 1,
		zones = { "Elwynn Forest", "Dun Morogh", "Teldrassil", "Durotar", "Mulgore", "Tirisfal Glades", "Zephras Isle" } },
	[6289] = { name = "Raw Longjaw Mud Snapper", water = "inland", skill = 75,
		zones = { "Westfall", "Loch Modan", "Darkshore", "Silverpine Forest", "The Barrens", "Redridge Mountains",
			"Stormwind City", "Ironforge", "Orgrimmar", "Undercity", "Thunder Bluff", "Darnassus" } },
	[6308] = { name = "Raw Bristle Whisker Catfish", water = "inland", skill = 150,
		zones = { "Redridge Mountains", "Duskwood", "Wetlands", "Hillsbrad Foothills", "Stonetalon Mountains", "Ashenvale", "Dustwallow Marsh" } },
	[8365] = { name = "Raw Mithril Head Trout", water = "inland", skill = 225,
		zones = { "Arathi Highlands", "Alterac Mountains", "Dustwallow Marsh", "Desolace", "Stranglethorn Vale", "Thousand Needles", "Swamp of Sorrows" } },
	[4603] = { name = "Raw Spotted Yellowtail", water = "coast", skill = 300,
		zones = { "Tanaris", "Feralas", "Azshara", "The Hinterlands", "Stranglethorn Vale", "Thousand Needles", "Dustwallow Marsh" } },
	-- Too rare to plan on (Bay of Storms, about 1 in 20 catches, needs about
	-- 330 skill): keep cooking Spotted Yellowtail to 300 instead, about 90
	-- more for the last 25 points (wow-professions: 140 for 225-300).
	[13893] = { name = "Large Raw Mightfish", water = "coast", skill = 330, rare = true,
		zones = { "Azshara" }, alt = 4603, altCount = 90 },
}
Fish.FISH = FISH

local function SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
end

local function FishingName()
	for _, id in ipairs(FISHING_IDS) do
		local n = SpellName(id)
		if n then return n end
	end
	return "Fishing"
end

local function IsFishingSpell(spellID)
	if not spellID or (issecretvalue and issecretvalue(spellID)) then return false end
	for _, id in ipairs(FISHING_IDS) do if id == spellID then return true end end
	return SpellName(spellID) == FishingName()
end

-- Is a fishing pole in your main hand?
function Fish.PoleEquipped()
	local id = GetInventoryItemID and GetInventoryItemID("player", 16)
	if not id then return false end
	local classID, subID
	if C_Item and C_Item.GetItemInfoInstant then
		local _, _, _, _, _, c, s = C_Item.GetItemInfoInstant(id)
		classID, subID = c, s
	end
	return classID == 2 and subID == 20
end

local function Count(itemID)
	if C_Item and C_Item.GetItemCount then
		local ok, n = pcall(C_Item.GetItemCount, itemID)
		if ok and type(n) == "number" then return n end
	end
	return 0
end

-- Your fishing skill: base, bonus from gear and lure, cap
function Fish.Skill()
	if not (GetProfessions and GetProfessionInfo) then return end
	local t = { pcall(GetProfessions) }
	if not t[1] then return end
	for i = 2, 7 do
		local idx = t[i]
		if idx then
			local ok, name, _, skill, max, _, _, line, bonus = pcall(GetProfessionInfo, idx)
			if ok and (line == 356 or name == FishingName() or name == "Fishing") then
				return skill or 0, (type(bonus) == "number" and bonus or 0), max or 0
			end
		end
	end
end

-- The best lure in your bags you can use (and the best you could use)
function Fish.BestLure()
	local skill = Fish.Skill() or 300
	for _, l in ipairs(LURES) do
		if skill >= l[3] and Count(l[1]) > 0 then return l[1], l end
	end
end

function Fish.BestUsableLure()
	local skill = Fish.Skill() or 0
	for _, l in ipairs(LURES) do
		-- what you can buy: skip the rare drop and the Engineering-only one
		if skill >= l[3] and l[1] ~= 7307 and l[1] ~= 6533 then return l end
	end
end

-- Lure on the pole? (true / false / nil when the game won't say), and
-- seconds left
function Fish.HasLure()
	if not GetWeaponEnchantInfo then return nil end
	local ok, has, ms = pcall(GetWeaponEnchantInfo)
	if not ok or (issecretvalue and (issecretvalue(has) or issecretvalue(ms))) then return nil end
	return has and true or false, (has and type(ms) == "number") and ms / 1000 or nil
end

local function Clock(sec)
	sec = math.max(0, math.floor(sec or 0))
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

---------------------------------------------------------------------------
-- Secure buttons (clicked through the key binding)
---------------------------------------------------------------------------
local owner = CreateFrame("Frame", "ProfessionPathfinderFishOwner", UIParent)

local cast = CreateFrame("Button", "ProfessionPathfinderFishCast", UIParent, "SecureActionButtonTemplate")
cast:SetAttribute("type", "spell")
cast:RegisterForClicks("AnyUp", "AnyDown")
cast:Hide()

local lure = CreateFrame("Button", "ProfessionPathfinderFishLure", UIParent, "SecureActionButtonTemplate")
lure:SetAttribute("type", "macro")
lure:RegisterForClicks("AnyUp", "AnyDown")
lure:Hide()

---------------------------------------------------------------------------
-- Sound: louder effects, quiet music and ambience, sound in the background.
-- The old values are saved (also across /reload) and put back after.
---------------------------------------------------------------------------
local SOUND = {
	Sound_EnableAllSound = "1", Sound_EnableSFX = "1", Sound_SFXVolume = "1",
	Sound_MusicVolume = "0", Sound_AmbienceVolume = "0", Sound_EnableSoundWhenGameIsInBG = "1",
}

local function GetCV(name)
	if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
	return GetCVar and GetCVar(name)
end
local function SetCV(name, value)
	if C_CVar and C_CVar.SetCVar then return pcall(C_CVar.SetCVar, name, value) end
	if SetCVar then return pcall(SetCVar, name, value) end
end

local function SoundOn()
	if not SP.db.fishSound or SP.db.fishSaved then return end
	local saved = {}
	for k, v in pairs(SOUND) do
		saved[k] = GetCV(k)
		SetCV(k, v)
	end
	SP.db.fishSaved = saved
end

local function SoundOff()
	local saved = SP.db.fishSaved
	if not saved then return end
	for k, v in pairs(saved) do if v ~= nil then SetCV(k, v) end end
	SP.db.fishSaved = nil
end

-- Soft-target "Interact" picks the bobber; the range is raised so a far
-- cast still reaches it. Saved and restored like the sound.
local INTERACT = { SoftTargetInteract = "3", SoftTargetInteractRange = "30" }
local function InteractOn()
	if SP.db.fishInteractSaved then return end
	local saved = {}
	for k, v in pairs(INTERACT) do saved[k] = GetCV(k); SetCV(k, v) end
	SP.db.fishInteractSaved = saved
end
local function InteractOff()
	local saved = SP.db.fishInteractSaved
	if not saved then return end
	for k, v in pairs(saved) do if v ~= nil then SetCV(k, v) end end
	SP.db.fishInteractSaved = nil
end

---------------------------------------------------------------------------
-- Small status line while fishing mode is on
---------------------------------------------------------------------------
local status = CreateFrame("Frame", "ProfessionPathfinderFishStatus", UIParent)
status:SetSize(460, 36)
status:SetPoint("TOP", UIParent, "TOP", 0, -110)
status.text = status:CreateFontString(nil, "OVERLAY", "GameFontNormal")
status.text:SetPoint("TOP")
status.info = status:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status.info:SetPoint("TOP", status.text, "BOTTOM", 0, -3)
status:EnableMouse(true)
status:SetScript("OnEnter", function(self) Fish.ShowTooltip(self) end)
status:SetScript("OnLeave", function() GameTooltip:Hide() end)
status:Hide()

local function KeyLabel(key)
	return (GetBindingText and GetBindingText(key, "KEY_")) or key
end

---------------------------------------------------------------------------
-- Catch log: this session in memory, every zone saved
---------------------------------------------------------------------------
local session = { casts = 0, catches = 0, escapes = 0, time = 0, value = 0, items = {}, recent = {} }
Fish.session = session

local function Now() return GetTime and GetTime() or 0 end

-- Zones by the game's map ID, so this works in any language (the English
-- name is only the addon's own key). Zones without an ID here (new Forever
-- zones) fall back to the name the game shows.
local MAP = {
	[1411] = "Durotar", [1412] = "Mulgore", [1413] = "The Barrens", [1416] = "Alterac Mountains", [1417] = "Arathi Highlands",
	[1418] = "Badlands", [1419] = "Blasted Lands", [1420] = "Tirisfal Glades", [1421] = "Silverpine Forest",
	[1422] = "Western Plaguelands", [1423] = "Eastern Plaguelands", [1424] = "Hillsbrad Foothills", [1425] = "The Hinterlands",
	[1426] = "Dun Morogh", [1427] = "Searing Gorge", [1428] = "Burning Steppes", [1429] = "Elwynn Forest", [1430] = "Deadwind Pass",
	[1431] = "Duskwood", [1432] = "Loch Modan", [1433] = "Redridge Mountains", [1434] = "Stranglethorn Vale",
	[1435] = "Swamp of Sorrows", [1436] = "Westfall", [1437] = "Wetlands", [1438] = "Teldrassil", [1439] = "Darkshore",
	[1440] = "Ashenvale", [1441] = "Thousand Needles", [1442] = "Stonetalon Mountains", [1443] = "Desolace", [1444] = "Feralas",
	[1445] = "Dustwallow Marsh", [1446] = "Tanaris", [1447] = "Azshara", [1448] = "Felwood", [1449] = "Un'Goro Crater",
	[1450] = "Moonglade", [1451] = "Silithus", [1452] = "Winterspring", [1453] = "Stormwind City", [1454] = "Orgrimmar",
	[1455] = "Ironforge", [1456] = "Thunder Bluff", [1457] = "Darnassus", [1458] = "Undercity",
}
Fish.MAP = MAP

-- The zone you're in: its map ID (walking up from caves and towns) and key
function Fish.CurrentZone()
	if C_Map and C_Map.GetBestMapForUnit then
		local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
		local guard = 0
		while ok and type(id) == "number" and id > 0 and guard < 6 do
			if MAP[id] then return MAP[id], id end
			local okI, info = pcall(C_Map.GetMapInfo, id)
			if not (okI and type(info) == "table" and info.parentMapID) then break end
			id, guard = info.parentMapID, guard + 1
		end
	end
	local z = GetRealZoneText and GetRealZoneText()
	if not z or z == "" then z = GetZoneText and GetZoneText() end
	if issecretvalue and issecretvalue(z) then return "?" end
	return (z and z ~= "") and z or "?"
end

local function ZoneName()
	return (Fish.CurrentZone())
end

local function ZoneData(zone)
	if not SP.db then return {} end
	SP.db.fishData = SP.db.fishData or {}
	local d = SP.db.fishData[zone]
	if not d then
		d = { casts = 0, catches = 0, escapes = 0, time = 0, value = 0, items = {} }
		SP.db.fishData[zone] = d
	end
	return d
end

-- What a fish is worth: AH (Auctionator) if it beats the vendor
local function Value(itemID)
	local vendor = 0
	if C_Item and C_Item.GetItemInfo then
		local ok, _, _, _, _, _, _, _, _, _, _, sell = pcall(C_Item.GetItemInfo, itemID)
		if ok and type(sell) == "number" then vendor = sell end
	end
	local A = Auctionator and Auctionator.API and Auctionator.API.v1
	if A and A.GetAuctionPriceByItemID then
		local ok, p = pcall(A.GetAuctionPriceByItemID, "Profession Pathfinder", itemID)
		if ok and type(p) == "number" and p > vendor then return p end
	end
	return vendor
end
Fish.Value = Value

local function Money(c)
	if SP.Money then return SP.Money(c) end
	c = math.floor((c or 0) + 0.5)
	local g, sv, co = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
	if g > 0 then return string.format("%dg %02ds", g, sv) end
	if sv > 0 then return string.format("%ds %02dc", sv, co) end
	return co .. "c"
end

local function PerHour(value, time)
	if (time or 0) < 300 then return nil end -- 5 minutes before guessing
	return value / time * 3600
end

-- the last 10 casts that ended in a catch (true) or got away (false)
local function Remember(caught)
	table.insert(session.recent, caught)
	if #session.recent > 10 then table.remove(session.recent, 1) end
end

local function GotAwayRecently()
	local n, away = 0, 0
	for _, c in ipairs(session.recent) do n = n + 1; if not c then away = away + 1 end end
	return away, n
end

function Fish.OnCast()
	local now = Now()
	local zone = ZoneName()
	local d = ZoneData(zone)
	if session.lastCast then
		local dt = math.min(now - session.lastCast, 45) -- longer gaps are breaks
		session.time = session.time + dt
		if session.lastZone then local ld = ZoneData(session.lastZone); ld.time = (ld.time or 0) + dt end
	end
	if session.lastZone and session.lastZone ~= zone then session.recent = {} end -- new water, new count
	session.lastCast, session.lastZone = now, zone
	session.casts = session.casts + 1
	d.casts = (d.casts or 0) + 1
	session.result = nil
end

function Fish.OnCatch(loot)
	if session.result then return end
	session.result = "caught"
	local zone = session.lastZone or ZoneName()
	local d = ZoneData(zone)
	session.catches = session.catches + 1
	d.catches = (d.catches or 0) + 1
	for _, e in ipairs(loot) do
		local v = Value(e.id) * e.count
		session.value = session.value + v
		d.value = (d.value or 0) + v
		session.items[e.id] = (session.items[e.id] or 0) + e.count
		d.items = d.items or {}
		d.items[e.id] = (d.items[e.id] or 0) + e.count
	end
	Remember(true)
end

function Fish.OnEscape()
	if session.result then return end
	session.result = "escaped"
	local d = ZoneData(session.lastZone or ZoneName())
	session.escapes = session.escapes + 1
	d.escapes = (d.escapes or 0) + 1
	Remember(false)
end

function Fish.ResetSession()
	session.casts, session.catches, session.escapes, session.time, session.value = 0, 0, 0, 0, 0
	session.items, session.recent, session.lastCast = {}, {}, nil
end

---------------------------------------------------------------------------
-- Cooking: the fish your cooking plan still needs
---------------------------------------------------------------------------
local function ProfSkill(skillLine, english)
	if not (GetProfessions and GetProfessionInfo) then return end
	local t = { pcall(GetProfessions) }
	if not t[1] then return end
	for i = 2, 7 do
		local idx = t[i]
		if idx then
			local ok, name, _, skill, max, _, _, line = pcall(GetProfessionInfo, idx)
			if ok and (line == skillLine or name == english) then return skill or 0, max or 0 end
		end
	end
end

function Fish.CookingSkill() return ProfSkill(185, "Cooking") end

local function Have(itemID)
	if C_Item and C_Item.GetItemCount then
		local ok, n = pcall(C_Item.GetItemCount, itemID, true) -- bags and bank
		if ok and type(n) == "number" then return n end
	end
	return Count(itemID)
end

-- { { id, name, need, have, from, to, recipe, fish } ... }: the fish your
-- Cooking plan uses, from the last time you opened your Cooking window
function Fish.CookingNeeds()
	local skill = Fish.CookingSkill()
	local c = skill and SP.db and SP.db.chars and SP.MyKey and SP.db.chars[SP.MyKey()]
	local needs = c and c.needs and c.needs.Cooking
	if not needs then return nil, skill end
	local usedBy = c.needsFor and c.needsFor.Cooking or {}
	local out = {}
	for id, n in pairs(needs) do
		local u = usedBy[id] or {}
		if FISH[id] and n > 0 and (u.to or math.huge) > skill then
			out[#out + 1] = { id = id, name = FISH[id].name, need = n, from = u.from or skill, to = u.to or skill,
				recipe = u.recipe, fish = FISH[id] }
		end
	end
	table.sort(out, function(a, b) return a.from < b.from end)
	-- the same fish in back-to-back steps: one line
	local merged = {}
	for _, e in ipairs(out) do
		local last = merged[#merged]
		if last and last.id == e.id then
			last.need, last.to = last.need + e.need, e.to
			last.instead = last.instead or e.instead
		else
			merged[#merged + 1] = e
		end
	end
	out = merged
	-- what you own counts against the earliest step first
	local left = {}
	for _, e in ipairs(out) do
		if left[e.id] == nil then left[e.id] = Have(e.id) end
		e.have = math.min(e.need, left[e.id])
		left[e.id] = left[e.id] - e.have
	end
	return out, skill
end

-- The fish to catch now: the first one you don't have enough of
function Fish.CookingTarget()
	local needs, skill = Fish.CookingNeeds()
	if not needs then return nil, skill end
	for _, e in ipairs(needs) do
		if e.have < e.need then return e, skill, needs end
	end
	return nil, skill, needs
end

local function In(list, zone)
	for _, z in ipairs(list or {}) do if z == zone then return true end end
	return false
end

-- Save the fish your cooking needs, for the Characters view
function Fish.SaveCookingNeeds()
	if not (SP.db and SP.db.chars and SP.MyKey) then return end
	local c = SP.db.chars[SP.MyKey()]
	if not c then return end
	local needs = Fish.CookingNeeds()
	c.needs = c.needs or {}
	if not needs then c.needs["Cooking fish"] = nil return end
	local t = {}
	for _, e in ipairs(needs) do t[e.id] = (t[e.id] or 0) + e.need end
	c.needs["Cooking fish"] = next(t) and t or nil
end

local function CookingLine()
	local e, skill, needs = Fish.CookingTarget()
	if not skill then return nil end
	if not e then
		if needs and #needs > 0 then return "|cff40bf40Cooking " .. skill .. ": you have every fish your cooking needs.|r" end
		return nil
	end
	local zone = ZoneName()
	local short = e.name:gsub("^Raw ", ""):gsub("^Large Raw ", "Large ")
	local here = In(e.fish.zones, zone)
	local line = "Cooking " .. skill .. ": |cffffffff" .. short .. " " .. e.have .. "/" .. e.need .. "|r"
	if e.fish.rare then
		line = line .. "  |cffff8040rare: hover for details|r"
	elseif here then
		line = line .. "  |cff40bf40swim here (" .. (e.fish.water == "coast" and "fish the sea" or "fish lakes and rivers") .. ")|r"
	else
		local z = {}
		for i = 1, math.min(3, #e.fish.zones) do z[#z + 1] = e.fish.zones[i] end
		line = line .. "  |cff999999" .. (e.fish.water == "coast" and "coast of " or "lakes in ") .. table.concat(z, ", ") .. "|r"
	end
	return line
end
Fish.CookingLine = CookingLine

-- Where to fish next: the route step for your skill, for your faction
function Fish.Where(skill)
	local g = SP.Gathering and SP.Gathering.Fishing
	if not (g and skill) then return end
	for _, z in ipairs(g.route) do
		if skill >= z.from and skill < z.to then return (SP.ZoneFor and SP.ZoneFor(z)) or z.alliance, z end
	end
	local last = g.route[#g.route]
	return last and ((SP.ZoneFor and SP.ZoneFor(last)) or last.alliance), last
end

-- One line about the zone you're in
function Fish.ZoneTip(skill, bonus)
	local zone = ZoneName()
	local away, n = GotAwayRecently()
	local where = Fish.Where(skill)
	if n >= 5 and away >= 3 then
		local l = Fish.BestLure()
		local has = Fish.HasLure()
		local fix = (has == false and l) and ("put on a lure (Shift-" .. ((GetBindingText and GetBindingText(SP.db.fishKey, "KEY_")) or SP.db.fishKey) .. ")")
			or ("fish an easier zone" .. (where and (": " .. where) or ""))
		return "|cffff8040" .. away .. " of your last " .. n .. " fish got away: " .. fix .. "|r"
	end
	local need = ZONES[zone]
	if need and skill then
		if skill + (bonus or 0) < need then
			return "|cffff8040" .. zone .. " is hard for your skill: fish may get away. " .. (where and ("Try " .. where .. ".") or "") .. "|r"
		end
		if need + 100 <= skill and where then
			return "|cff999999" .. zone .. " is easy (skill still rises anywhere). Better fish in " .. where .. ".|r"
		end
		return "|cff40bf40" .. zone .. ": good spot for your skill|r"
	end
	return where and ("|cff999999For your skill: " .. where .. "|r") or nil
end


function Fish.UpdateStatus()
	if not Fish.active then status:Hide() return end
	local key = KeyLabel(SP.db.fishKey)
	local line
	if Fish.lineOut then
		line = "|cff40bf40Fishing:|r press |cffffffff" .. key .. "|r when the bobber splashes"
	else
		line = "|cff66bbffFishing:|r |cffffffff" .. key .. "|r cast / catch"
	end
	if SP.db.fishLure then
		local has, left = Fish.HasLure()
		local best = Fish.BestLure()
		if has and left then
			line = line .. "   " .. (left < 60 and "|cffff8040" or "|cff999999") .. "lure " .. Clock(left) .. "|r"
		elseif has == false and best then
			line = line .. "   |cffff8040No lure:|r Shift-" .. key
		elseif has == false then
			line = line .. "   |cff999999no lure|r"
		end
	end
	status.text:SetText(line)
	local info = ""
	if SP.db.fishLog ~= false then
		local skill, bonus, max = Fish.Skill()
		local bits = {}
		if skill then
			bits[#bits + 1] = "Skill " .. skill .. ((bonus or 0) > 0 and ("|cff40bf40+" .. bonus .. "|r") or "") .. (max and max > 0 and ("/" .. max) or "")
		end
		if session.casts > 0 then
			bits[#bits + 1] = session.catches .. " caught" .. (session.escapes > 0 and (", |cffff8040" .. session.escapes .. " got away|r") or "")
			local ph = PerHour(session.value, session.time)
			bits[#bits + 1] = ph and ("about " .. Money(ph) .. "/hour") or ("worth " .. Money(session.value))
		end
		info = table.concat(bits, "  ·  ")
		local tip = skill and Fish.ZoneTip(skill, bonus)
		if skill and max and max > 0 and skill >= max and max < 300 then
			tip = "|cffffd100At your cap: " .. (max == 75 and "train Journeyman at a fishing trainer" or max == 150 and "Expert is the book \"The Bass and You\" (Old Man Heming, Booty Bay)" or "Artisan is Nat Pagle's quest (Dustwallow Marsh)") .. "|r"
		end
		if tip then info = info .. (info ~= "" and "\n" or "") .. tip end
		if SP.db.fishCook ~= false then
			local ok, cook = pcall(CookingLine)
			if ok and cook then info = info .. (info ~= "" and "\n" or "") .. cook end
		end
	end
	status.info:SetText(info)
	status:Show()
end

-- Hover the status line: this session and your best zones
function Fish.ShowTooltip(owner)
	GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
	GameTooltip:SetText("Fishing", 1, 1, 1)
	local skill, bonus = Fish.Skill()
	if skill then
		local where, z = Fish.Where(skill)
		if where then GameTooltip:AddLine("For skill " .. skill .. ": " .. where .. (z and z.note and (". " .. z.note) or ""), 0.8, 0.8, 0.8, true) end
	end
	local best = Fish.BestUsableLure()
	local _, mine = Fish.BestLure()
	if best and (not mine or mine[2] < best[2]) then
		GameTooltip:AddLine("Best lure for you: " .. best[4] .. " (+" .. best[2] .. "), from " .. best[5] .. ".", 1, 0.82, 0, true)
	elseif mine then
		GameTooltip:AddLine("Lure: " .. mine[4] .. " (+" .. mine[2] .. "), " .. Count(mine[1]) .. " in your bags.", 0.8, 0.8, 0.8, true)
	end
	local cookIDs = {}
	if SP.db.fishCook ~= false then
		local okN, needs, cskill = pcall(Fish.CookingNeeds)
		if okN and needs and #needs > 0 then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Fish for your cooking (skill " .. cskill .. ")", 1, 0.82, 0)
			local shown = 0
			for _, e in ipairs(needs) do
				cookIDs[e.id] = true
				if shown < 4 then
					shown = shown + 1
					local done = e.have >= e.need
					GameTooltip:AddDoubleLine(e.name .. "  |cff999999cooking " .. e.from .. "-" .. e.to .. "|r", e.have .. "/" .. e.need,
						1, 1, 1, done and 0.25 or 1, done and 0.75 or 1, done and 0.25 or 1)
					if e.instead then
						GameTooltip:AddLine("   Also to 300, instead of " .. e.instead .. ": that one is only in Azshara's Bay of Storms, about 1 in 20 catches, at about 330 skill.", 0.7, 0.7, 0.7, true)
					end
					if not done then
						local where = e.fish.note or ((e.fish.water == "coast" and "The sea: " or "Lakes and rivers: ") .. table.concat(e.fish.zones, ", ")
							.. ". Rarely gets away from fishing skill " .. e.fish.skill .. ".")
						GameTooltip:AddLine("   " .. where, 0.7, 0.7, 0.7, true)
					end
				end
			end
		elseif okN and cskill == nil then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Tip: learn Cooking (any cooking trainer). The fish you catch can level it.", 0.7, 0.7, 0.7, true)
		end
	end
	if session.casts > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddDoubleLine("This session", Clock(session.time) .. " fishing", 1, 0.82, 0, 1, 1, 1)
		GameTooltip:AddDoubleLine("Caught / got away / missed", session.catches .. " / " .. session.escapes .. " / " .. math.max(0, session.casts - session.catches - session.escapes), 0.8, 0.8, 0.8, 1, 1, 1)
		local list = {}
		for id, n in pairs(session.items) do list[#list + 1] = { id = id, n = n, v = Value(id) * n } end
		table.sort(list, function(a, b) return a.v > b.v end)
		for i = 1, math.min(8, #list) do
			local e = list[i]
			local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(e.id)) or (FISH[e.id] and FISH[e.id].name) or ("item " .. e.id)
			GameTooltip:AddDoubleLine(name .. " x" .. e.n .. (cookIDs[e.id] and "  |cff40bf40(cooking)|r" or ""), Money(e.v), 1, 1, 1, 1, 1, 1)
		end
		GameTooltip:AddDoubleLine("Worth", Money(session.value), 0.8, 0.8, 0.8, 0.25, 0.75, 0.25)
	end
	local zones = {}
	for zone, d in pairs(SP.db.fishData or {}) do
		local ph = PerHour(d.value or 0, d.time or 0)
		if ph then zones[#zones + 1] = { zone = zone, ph = ph, d = d } end
	end
	table.sort(zones, function(a, b) return a.ph > b.ph end)
	if #zones > 0 then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Your best zones (gold per hour)", 1, 0.82, 0)
		for i = 1, math.min(5, #zones) do
			local z = zones[i]
			local away = (z.d.escapes or 0) > 0 and string.format(", %d%% got away", math.floor(100 * z.d.escapes / math.max(1, z.d.catches + z.d.escapes) + 0.5)) or ""
			GameTooltip:AddDoubleLine(z.zone .. "  |cff999999" .. z.d.catches .. " caught" .. away .. "|r", Money(z.ph), 1, 1, 1, 1, 1, 1)
		end
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Prices: Auctionator if it beats the vendor. /ppf fish log lists every zone, /ppf fish reset starts a new session.", 0.6, 0.6, 0.6, true)
	GameTooltip:Show()
end

-- /ppf fish log
function Fish.PrintLog()
	local zones = {}
	for zone, d in pairs(SP.db.fishData or {}) do zones[#zones + 1] = { zone = zone, d = d, ph = PerHour(d.value or 0, d.time or 0) or 0 } end
	table.sort(zones, function(a, b) return a.ph > b.ph end)
	if #zones == 0 then print(PREFIX .. "no fishing logged yet.") return end
	print(PREFIX .. "fishing by zone:")
	for _, z in ipairs(zones) do
		local d = z.d
		print(string.format("  %s: %d caught, %d got away, %s fishing, worth %s%s", z.zone, d.catches or 0, d.escapes or 0, Clock(d.time or 0),
			Money(d.value or 0), z.ph > 0 and (" (about " .. Money(z.ph) .. "/hour)") or ""))
	end
end

---------------------------------------------------------------------------
-- Bindings
---------------------------------------------------------------------------
local function Bind()
	if InCombatLockdown() then return end
	ClearOverrideBindings(owner)
	if not Fish.active then return end
	local key = SP.db.fishKey
	if not key or key == "" then return end
	if Fish.lineOut then
		SetOverrideBinding(owner, true, key, "INTERACTTARGET")
	else
		SetOverrideBindingClick(owner, true, key, "ProfessionPathfinderFishCast", "LeftButton")
	end
	-- Shift + key: put the best lure in your bags on the pole
	if SP.db.fishLure and not key:find("-", 1, true) then
		local best = Fish.BestLure()
		if best then
			lure:SetAttribute("macrotext", "/use item:" .. best .. "\n/use 16")
			SetOverrideBindingClick(owner, true, "SHIFT-" .. key, "ProfessionPathfinderFishLure", "LeftButton")
		end
	end
end

function Fish.Update()
	if not SP.db then return end
	if InCombatLockdown() then Fish.pending = true return end
	Fish.pending = false
	local want = SP.db.fishMode and Fish.PoleEquipped()
	if want and not Fish.active then
		Fish.active = true
		cast:SetAttribute("spell", FishingName())
		InteractOn()
		SoundOn()
		print(PREFIX .. "fishing mode on. Press |cffffffff" .. KeyLabel(SP.db.fishKey) .. "|r to cast, and the same key when the bobber splashes."
			.. (SP.db.fishLure and " Shift-" .. KeyLabel(SP.db.fishKey) .. " puts on a lure." or ""))
	elseif not want and Fish.active then
		Fish.active, Fish.lineOut = false, false
		InteractOff()
		SoundOff()
		print(PREFIX .. "fishing mode off.")
	end
	if Fish.active then
		if SP.db.fishSound then SoundOn() else SoundOff() end
	end
	Bind()
	Fish.UpdateStatus()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
Fish.eventFrame = ev
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		for k, v in pairs(Fish.defaults) do
			if SP.db and SP.db[k] == nil then SP.db[k] = v end
		end
		-- Left over from a crash or /reload while fishing: put settings back first
		if SP.db then SoundOff(); InteractOff() end
		for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
			"UNIT_INVENTORY_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_LOGOUT", "LOOT_OPENED", "UI_ERROR_MESSAGE",
			"ZONE_CHANGED_NEW_AREA", "SKILL_LINES_CHANGED" }) do
			pcall(ev.RegisterEvent, ev, e)
		end
		for _, e in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
			pcall(ev.RegisterUnitEvent, ev, e, "player")
		end
		C_Timer.After(2, Fish.Update)
		C_Timer.After(3, function() pcall(Fish.SaveCookingNeeds) end)
	elseif event == "PLAYER_LOGOUT" then
		-- don't leave your sound settings changed
		if SP.db then SoundOff(); InteractOff() end
	elseif event == "PLAYER_REGEN_DISABLED" then
		-- Bindings can't change in combat: give your key back now
		ClearOverrideBindings(owner)
		status:Hide()
		Fish.lineOut = false
	elseif event == "PLAYER_REGEN_ENABLED" then
		Fish.Update()
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		local _, _, spellID = ...
		if Fish.active and IsFishingSpell(spellID) then
			Fish.lineOut = true
			pcall(Fish.OnCast)
			Bind()
			Fish.UpdateStatus()
		end
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		if Fish.lineOut then
			Fish.lineOut = false
			Fish.stoppedAt = GetTime and GetTime() or 0
			-- give the loot window a moment before the key casts again
			C_Timer.After(0.5, function() Bind(); Fish.UpdateStatus() end)
		end
	elseif event == "LOOT_OPENED" then
		if not Fish.active then return end
		local fishing = IsFishingLoot and select(2, pcall(IsFishingLoot))
		local recent = Fish.stoppedAt and (GetTime() - Fish.stoppedAt) < 3
		if fishing ~= true and not (fishing == nil and recent) then return end
		local loot = {}
		for i = 1, (GetNumLootItems and GetNumLootItems() or 0) do
			local okL, link = pcall(GetLootSlotLink, i)
			local id = okL and type(link) == "string" and tonumber(link:match("item:(%d+)"))
			if id then
				local okI, _, _, n = pcall(GetLootSlotInfo, i)
				loot[#loot + 1] = { id = id, count = (okI and type(n) == "number" and n > 0) and n or 1 }
			end
		end
		pcall(Fish.OnCatch, loot)
		pcall(Fish.SaveCookingNeeds)
		Fish.UpdateStatus()
	elseif event == "UI_ERROR_MESSAGE" then
		local _, msg = ...
		if not Fish.active or (issecretvalue and issecretvalue(msg)) then return end
		if msg == (ERR_FISH_ESCAPED or "Your fish got away!") then
			pcall(Fish.OnEscape)
			Fish.UpdateStatus()
		end
	elseif event == "ZONE_CHANGED_NEW_AREA" or event == "SKILL_LINES_CHANGED" then
		if event == "SKILL_LINES_CHANGED" then pcall(Fish.SaveCookingNeeds) end
		if Fish.active then Fish.UpdateStatus() end
	elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UNIT_INVENTORY_CHANGED" or event == "BAG_UPDATE_DELAYED" then
		if event == "UNIT_INVENTORY_CHANGED" and ... ~= "player" then return end
		Fish.Update()
	end
end)

-- Once a second while fishing: lure clock, and a warning when it runs out
local tick = 0
status:SetScript("OnUpdate", function(_, dt)
	tick = tick + dt
	if tick < 1 then return end
	tick = 0
	if not (Fish.active and SP.db and SP.db.fishLure) then return end
	local has = Fish.HasLure()
	if Fish.hadLure and has == false then
		print(PREFIX .. "your lure ran out." .. (Fish.BestLure() and (" Shift-" .. ((GetBindingText and GetBindingText(SP.db.fishKey, "KEY_")) or SP.db.fishKey) .. " puts on a new one.") or ""))
		if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.RAID_WARNING or 8959, "Master") end
	end
	Fish.hadLure = has
	Fish.UpdateStatus()
end)

-- /ppf fish: turn fishing mode on/off
function Fish.Toggle()
	SP.db.fishMode = not SP.db.fishMode
	if SP.db.fishMode and not Fish.PoleEquipped() then
		print(PREFIX .. "fishing mode is on: equip a fishing pole to start.")
	end
	Fish.Update()
	if not SP.db.fishMode then print(PREFIX .. "one-key fishing is off.") end
end
