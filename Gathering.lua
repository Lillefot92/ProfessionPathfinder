-- Profession Pathfinder - gathering
-- Where to mine, pick herbs, skin and fish for your skill, the skill each
-- node needs, and which profession gathers which material.

local ADDON, SP = ...

---------------------------------------------------------------------------
-- Gathering (Mining, Herbalism, Skinning, Fishing)
-- Source: wow-professions.com WoW Forever leveling guides (beta-based)
-- Node skills: Classic values, confirmed by those guides where listed.
---------------------------------------------------------------------------
local function Z(from, to, what, alliance, horde, note)
	return { from = from, to = to, what = what, alliance = alliance, horde = horde or alliance, note = note }
end

SP.Gathering = {
	Mining = {
		nodes = { { "Copper", 1 }, { "Tin", 65 }, { "Silver", 75 }, { "Iron", 125 }, { "Gold", 155 }, { "Mithril", 175 },
			{ "Truesilver", 230 }, { "Dark Iron", 230 }, { "Thorium", 245 }, { "Rich Thorium", 275 } },
		route = {
			Z(1, 65, "Copper", "Elwynn Forest", "Durotar", "Smelting Copper also gives skill to about 65."),
			Z(65, 75, "Tin", "Redridge Mountains or Wetlands", "Silverpine Forest or Hillsbrad Foothills", "Smelt Tin too."),
			Z(75, 125, "Silver and Tin", "Redridge Mountains or Wetlands", "Silverpine Forest or Hillsbrad Foothills", "Smelting Bronze gives skill to about 105."),
			Z(125, 155, "Iron", "Thousand Needles, Arathi Highlands, Desolace or Stranglethorn Vale", nil, "Smelting Iron (from 130) gives skill to about 140."),
			Z(155, 175, "Gold and Iron", "Arathi Highlands, Thousand Needles, Desolace or Badlands", nil, "Smelting Gold gives skill to about 185: a few Gold Bars get you to 175 for Mithril."),
			Z(175, 245, "Mithril (Truesilver from 230)", "Badlands, Tanaris, The Hinterlands or Searing Gorge"),
			Z(245, 275, "Thorium", "Un'Goro Crater, Blasted Lands, Felwood or Burning Steppes"),
			Z(275, 300, "Rich Thorium", "Un'Goro Crater, Winterspring or Burning Steppes"),
		},
	},
	Herbalism = {
		nodes = { { "Peacebloom", 1 }, { "Silverleaf", 1 }, { "Earthroot", 15 }, { "Mageroyal", 50 }, { "Briarthorn", 70 },
			{ "Stranglekelp", 85 }, { "Bruiseweed", 100 }, { "Wild Steelbloom", 115 }, { "Kingsblood", 125 }, { "Liferoot", 150 },
			{ "Fadeleaf", 160 }, { "Goldthorn", 170 }, { "Khadgar's Whisker", 185 }, { "Firebloom", 205 }, { "Purple Lotus", 210 },
			{ "Sungrass", 230 }, { "Ghost Mushroom", 245 }, { "Gromsblood", 250 }, { "Golden Sansam", 260 }, { "Dreamfoil", 270 },
			{ "Mountain Silversage", 280 }, { "Plaguebloom", 285 } },
		route = {
			Z(1, 70, "Peacebloom, Silverleaf, Earthroot", "Elwynn Forest, Dun Morogh or Teldrassil", "Durotar, Mulgore or Tirisfal Glades"),
			Z(70, 115, "Mageroyal, Briarthorn, Stranglekelp", "Loch Modan or Darkshore", "Silverpine Forest"),
			Z(115, 170, "Bruiseweed, Wild Steelbloom, Kingsblood", "Hillsbrad Foothills, Stonetalon Mountains or Wetlands"),
			Z(170, 205, "Liferoot, Fadeleaf, Goldthorn, Khadgar's Whisker", "Stranglethorn Vale, Arathi Highlands, Swamp of Sorrows or Dustwallow Marsh"),
			Z(205, 230, "Purple Lotus, Firebloom", "Badlands, Tanaris or Searing Gorge", nil, "Train Artisan first: no trainer there."),
			Z(230, 270, "Sungrass, Golden Sansam, Ghost Mushroom", "The Hinterlands or Feralas"),
			Z(270, 300, "Gromsblood, Dreamfoil, Mountain Silversage, Plaguebloom", "Felwood"),
		},
	},
	Skinning = {
		route = {
			Z(1, 75, "level 1-15 beasts", "Elwynn Forest or Northshire", "Durotar (Valley of Trials)"),
			Z(75, 125, "level 16-25 beasts", "Loch Modan or The Barrens", "The Barrens"),
			Z(125, 150, "level 25-30 beasts", "Wetlands (raptors)"),
			Z(150, 225, "level 30-45 beasts", "Duskwood (worgen) or Hillsbrad yetis", "Hillsbrad Foothills (yeti cave)"),
			Z(225, 280, "level 43-56 beasts", "Feralas (Feral Scar Vale)"),
			Z(280, 300, "level 50-60 beasts", "Un'Goro Crater"),
		},
	},
	Fishing = {
		route = {
			Z(1, 75, "starting zone waters", "Elwynn Forest, Dun Morogh, Teldrassil or Zephras Isle", "Durotar, Mulgore, Tirisfal Glades or Zephras Isle", "Use a Shiny Bauble."),
			Z(75, 150, "low-level zones and capital cities", "Westfall, Loch Modan, Darkshore or Wetlands", "The Barrens, Silverpine Forest or Orgrimmar", "Journeyman from any fishing trainer (skill 50, level 10). Nightcrawlers if fish get away."),
			Z(150, 225, "mid-level zones", "Dustwallow Marsh, Arathi Highlands or Desolace", nil, "Expert from the book \"The Bass and You\" (Old Man Heming, Booty Bay). Bright Baubles from him too."),
			Z(225, 300, "high-level zones", "Feralas, Tanaris, The Hinterlands or Un'Goro Crater", nil, "Artisan: quest from Nat Pagle in Dustwallow Marsh. Use Bright Baubles."),
		},
	},
}

-- Level range of each zone, so suggestions fit your character
SP.ZONE_LEVELS = {
	["Elwynn Forest"] = { 1, 10 }, ["Dun Morogh"] = { 1, 10 }, ["Teldrassil"] = { 1, 10 }, ["Northshire"] = { 1, 5 },
	["Durotar"] = { 1, 10 }, ["Mulgore"] = { 1, 10 }, ["Tirisfal Glades"] = { 1, 10 },
	["Westfall"] = { 10, 20 }, ["Loch Modan"] = { 10, 20 }, ["Darkshore"] = { 10, 20 }, ["Silverpine Forest"] = { 10, 20 },
	["The Barrens"] = { 10, 25 }, ["Redridge Mountains"] = { 15, 25 }, ["Stonetalon Mountains"] = { 15, 27 },
	["Ashenvale"] = { 18, 30 }, ["Duskwood"] = { 18, 30 }, ["Wetlands"] = { 20, 30 }, ["Hillsbrad Foothills"] = { 20, 30 },
	["Thousand Needles"] = { 25, 35 }, ["Alterac Mountains"] = { 30, 40 }, ["Arathi Highlands"] = { 30, 40 },
	["Desolace"] = { 30, 40 }, ["Stranglethorn Vale"] = { 30, 45 }, ["Dustwallow Marsh"] = { 35, 45 },
	["Badlands"] = { 35, 45 }, ["Swamp of Sorrows"] = { 35, 45 }, ["Feralas"] = { 40, 50 }, ["The Hinterlands"] = { 40, 50 },
	["Tanaris"] = { 40, 50 }, ["Searing Gorge"] = { 43, 50 }, ["Azshara"] = { 45, 55 }, ["Blasted Lands"] = { 45, 55 },
	["Un'Goro Crater"] = { 48, 55 }, ["Felwood"] = { 48, 55 }, ["Burning Steppes"] = { 50, 58 },
	["Western Plaguelands"] = { 51, 58 }, ["Eastern Plaguelands"] = { 53, 60 }, ["Winterspring"] = { 53, 60 }, ["Silithus"] = { 55, 60 },
}

-- Keep only the zones in a "A, B or C" list that fit a character of this level
-- (a couple of levels above is fine). If none fit, the easiest one with its level.
function SP.FitZones(text, level)
	if not text or not level or level <= 0 then return text end
	local parts = {}
	for raw in (text:gsub(" or ", ", ")):gmatch("[^,]+") do
		local piece = raw:match("^%s*(.-)%s*$")
		if piece ~= "" then parts[#parts + 1] = piece end
	end
	if #parts < 2 then
		local r = SP.ZONE_LEVELS[(parts[1] or ""):gsub("%s*%b()", "")]
		if r and r[1] > level + 2 then return text .. " (level " .. r[1] .. "+)" end
		return text
	end
	local fit, easiest, easiestMin = {}, nil, 999
	for _, piece in ipairs(parts) do
		local r = SP.ZONE_LEVELS[piece:gsub("%s*%b()", "")]
		if not r or r[1] <= level + 2 then fit[#fit + 1] = piece end
		if r and r[1] < easiestMin then easiest, easiestMin = piece, r[1] end
	end
	if #fit == 0 then return easiest .. " (level " .. easiestMin .. "+)" end
	if #fit == 1 then return fit[1] end
	return table.concat(fit, ", ", 1, #fit - 1) .. " or " .. fit[#fit]
end

-- Cloth: no profession needed, it drops from humanoids of these levels
SP.Gathering.Cloth = {
	route = {
		Z(1, 2, "Linen Cloth (humanoids level 5-15)", "Westfall or Elwynn Forest (Defias)", "Durotar or The Barrens (quilboars and centaurs)"),
		Z(2, 3, "Wool Cloth (humanoids level 15-25)", "Westfall or Redridge Mountains", "The Barrens or Hillsbrad Foothills"),
		Z(3, 4, "Silk Cloth (humanoids level 25-35)", "Stranglethorn Vale (Venture Co.) or Hillsbrad Foothills (Syndicate)"),
		Z(4, 5, "Mageweave Cloth (humanoids level 35-50)", "Stranglethorn Vale (trolls), Tanaris (Wastewander) or Desolace (centaurs)"),
		Z(5, 6, "Runecloth (humanoids level 50-60)", "Eastern Plaguelands, Winterspring (Deadwood furbolgs) or Felwood"),
	},
}

-- Next trainer rank: { needed skill, cap after training, how }
-- Character level needed (Icy Veins' WoW Forever profession guide):
-- crafting / gathering professions.
SP.RANKS = {
	{ at = 50, cap = 75, next = 150, name = "Journeyman", level = 10, gatherLevel = 0 },
	{ at = 125, cap = 150, next = 225, name = "Expert", level = 20, gatherLevel = 10 },
	{ at = 200, cap = 225, next = 300, name = "Artisan", level = 35, gatherLevel = 25 },
}

-- Smelting (Mining): which smelts you know, which give skill now, which a
-- trainer can teach you now, and the next one.
-- { known = {...}, skillUps = {...}, learnNow = {...}, next = {...} }; each
-- entry { id, name, at, yellow, gray, color, trainer }
local function SmeltName(id)
	local n = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
	if not n and GetSpellInfo then n = GetSpellInfo(id) end
	return n
end

function SP.Smelting(skill)
	local out = { known = {}, skillUps = {}, learnNow = {}, next = nil }
	local data = SP.DATA and SP.DATA[186]
	if not data then return out end
	local saved = {}
	local me = SP.MyKey and SP.MyKey()
	for _, r in ipairs(SP.db and SP.db.known and me and SP.db.known[me] and SP.db.known[me].Mining or {}) do saved[r.id] = true end
	local list = {}
	for id, d in pairs(data) do
		local at, how = SP.LearnAt(id, 186)
		if at and (how == "start" or how == "trainer" or how == "maybe") then
			local name = SmeltName(id)
			if name then
				list[#list + 1] = { id = id, name = name, at = at, yellow = d[1], gray = d[2],
					known = saved[id] or d[3] == 1 or SP.KnowsSpell(id) }
			end
		end
	end
	table.sort(list, function(a, b) if a.at ~= b.at then return a.at < b.at end return a.id < b.id end)
	for _, s in ipairs(list) do
		if skill < s.gray then
			s.color = skill < s.yellow and "orange" or (skill < (s.yellow + s.gray) / 2 and "yellow" or "green")
		end
		if s.known then
			out.known[#out.known + 1] = s
			if s.color then out.skillUps[#out.skillUps + 1] = s end
		elseif s.at <= skill then
			if s.color then
				s.trainer = SP.RecipeTrainer and SP.RecipeTrainer("Mining", s.at)
				out.learnNow[#out.learnNow + 1] = s
			end
		elseif not out.next then
			out.next = s
		end
	end
	-- best skill-ups first
	local rank = { orange = 1, yellow = 2, green = 3 }
	table.sort(out.skillUps, function(a, b) return rank[a.color] < rank[b.color] end)
	return out
end

-- Highest beast level you can skin
function SP.SkinLevel(skill)
	if skill < 100 then return math.floor(skill / 10) + 10 end
	return math.floor(skill / 5)
end

---------------------------------------------------------------------------
-- Materials you can gather: item ID -> { profession, node or source, skill }
-- Ores, stones and bars (smelted from your own ore) come from Mining node
-- skills above; herbs from the Herbalism nodes; leather and hides from
-- Skinning, by the beast levels that drop them (Classic values).
---------------------------------------------------------------------------
local function M(node, skill, how) return { prof = "Mining", node = node, skill = skill, how = how } end
local function H(node, skill) return { prof = "Herbalism", node = node, skill = skill } end
local function K(skill, beasts) return { prof = "Skinning", skill = skill, beasts = beasts } end
local function C(node, levels) return { prof = "Cloth", node = node, skill = 0, from = "level " .. levels .. " humanoids" } end
SP.GATHER = {
	-- Ores
	[2770] = M("Copper", 1), [2771] = M("Tin", 65), [2775] = M("Silver", 75), [2772] = M("Iron", 125),
	[2776] = M("Gold", 155), [3858] = M("Mithril", 175), [7911] = M("Truesilver", 230), [11370] = M("Dark Iron", 230),
	[10620] = M("Thorium", 245),
	-- Stones (from the same veins)
	[2835] = M("Copper", 1), [2836] = M("Tin", 65), [2838] = M("Iron", 125), [7912] = M("Mithril", 175), [12365] = M("Thorium", 245),
	-- Bars: smelt your own ore
	[2840] = M("Copper", 1, "smelt"), [2841] = M("Copper and Tin", 65, "smelt"), [2842] = M("Silver", 75, "smelt"),
	[3575] = M("Iron", 125, "smelt"), [3577] = M("Gold", 155, "smelt"), [3860] = M("Mithril", 175, "smelt"),
	[6037] = M("Truesilver", 230, "smelt"), [12359] = M("Thorium", 245, "smelt"),
	-- Herbs
	[2447] = H("Peacebloom", 1), [765] = H("Silverleaf", 1), [2449] = H("Earthroot", 15), [785] = H("Mageroyal", 50),
	[2450] = H("Briarthorn", 70), [3820] = H("Stranglekelp", 85), [2453] = H("Bruiseweed", 100), [3355] = H("Wild Steelbloom", 115),
	[3356] = H("Kingsblood", 125), [3357] = H("Liferoot", 150), [3818] = H("Fadeleaf", 160), [3821] = H("Goldthorn", 170),
	[3358] = H("Khadgar's Whisker", 185), [4625] = H("Firebloom", 205), [8831] = H("Purple Lotus", 210), [8838] = H("Sungrass", 230),
	[8845] = H("Ghost Mushroom", 245), [8846] = H("Gromsblood", 250), [13464] = H("Golden Sansam", 260), [13463] = H("Dreamfoil", 270),
	[13465] = H("Mountain Silversage", 280), [13466] = H("Plaguebloom", 285),
	-- Leather and hides
	[2934] = K(1, "level 1-20"), [2318] = K(1, "level 1-20"), [783] = K(1, "level 1-20"),
	[2319] = K(100, "level 20-30"), [4232] = K(100, "level 20-30"),
	[4234] = K(150, "level 30-40"), [4235] = K(150, "level 30-40"),
	[4304] = K(200, "level 40-50"), [8169] = K(200, "level 40-50"),
	[8170] = K(250, "level 50-60"), [8171] = K(250, "level 50-60"),
	-- Cloth (anyone)
	[2589] = C("Linen", "5-15"), [2592] = C("Wool", "15-25"), [4306] = C("Silk", "25-35"),
	[4338] = C("Mageweave", "35-50"), [14047] = C("Runecloth", "50-60"),
}

-- Where to gather it: the first route zone that lists the node (or, for
-- Skinning, the zone for the skill needed).
function SP.GatherWhere(src)
	local g = SP.Gathering[src.prof]
	if not g or (src.node and src.node:find(" and ", 1, true)) then return end
	for _, z in ipairs(g.route) do
		if src.node and z.what:find(src.node:match("^(%S+)"), 1, true) then return SP.ZoneFor(z) end
		if not src.node and src.skill >= z.from and src.skill < z.to then return SP.ZoneFor(z) end
	end
end
