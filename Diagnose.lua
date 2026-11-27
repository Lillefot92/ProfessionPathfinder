-- Profession Pathfinder - /ppf scan
-- Finds out what the game tells addons about recipes you haven't learned
-- yet: whether they're listed at all, and which details come with them
-- (skill needed, colors, materials, where to learn them). The answer is
-- shown in a window you can copy from.

local ADDON, SP = ...

local function Plain(v)
	if issecretvalue and issecretvalue(v) then return "<secret>" end
	return v
end

-- One line per simple field of a table, sorted, nested tables summarised
local function Dump(t, out, indent)
	indent = indent or "    "
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	for _, k in ipairs(keys) do
		local v = Plain(t[k])
		if type(v) == "table" then
			local n = 0
			for _ in pairs(v) do n = n + 1 end
			out[#out + 1] = indent .. tostring(k) .. " = {" .. n .. " entries}"
		elseif type(v) ~= "function" then
			out[#out + 1] = indent .. tostring(k) .. " = " .. tostring(v)
		end
	end
end

local function Try(out, label, fn, ...)
	if type(fn) ~= "function" then
		out[#out + 1] = "  " .. label .. ": (not in this client)"
		return
	end
	local ok, a, b = pcall(fn, ...)
	if not ok then
		out[#out + 1] = "  " .. label .. ": error " .. tostring(a)
	elseif type(a) == "table" then
		out[#out + 1] = "  " .. label .. ":"
		Dump(a, out)
	else
		out[#out + 1] = "  " .. label .. ": " .. tostring(Plain(a)) .. (b ~= nil and (", " .. tostring(Plain(b))) or "")
	end
end

local function Describe(out, title, id)
	local T = C_TradeSkillUI
	out[#out + 1] = ""
	out[#out + 1] = title .. " (recipe " .. tostring(id) .. ")"
	Try(out, "GetRecipeInfo", T.GetRecipeInfo, id)
	local ok, s = pcall(T.GetRecipeSchematic, id, false)
	if ok and type(s) == "table" then
		local parts = {}
		for _, slot in ipairs(s.reagentSlotSchematics or {}) do
			local r = slot.reagents and slot.reagents[1]
			parts[#parts + 1] = tostring(slot.quantityRequired) .. "x " .. tostring(r and r.itemID)
		end
		out[#out + 1] = "  materials: " .. (#parts > 0 and table.concat(parts, ", ") or "none listed")
			.. "  makes: " .. tostring(s.outputItemID)
	else
		out[#out + 1] = "  GetRecipeSchematic: " .. (ok and "nothing" or ("error " .. tostring(s)))
	end
	Try(out, "GetRecipeSourceText", T.GetRecipeSourceText, id)
	Try(out, "GetRecipeRequirements", T.GetRecipeRequirements, id)
	Try(out, "GetRecipeItemLevelFilter", T.GetRecipeItemLevelFilter, id)
end

function SP.Diagnose()
	local out = {}
	local T = C_TradeSkillUI
	out[#out + 1] = "Profession Pathfinder " .. SP.version .. " recipe scan"
	local prof = SP.ProfessionInfo()
	if not (T and prof) then
		out[#out + 1] = "Open a profession window first, then type /ppf scan again."
		SP.ShowReport(out)
		return
	end
	out[#out + 1] = "Profession: " .. tostring(prof.name) .. " " .. prof.skill .. "/" .. prof.max
		.. " (id " .. tostring(prof.id) .. ", skill line " .. tostring(prof.enum) .. ")"
		.. (prof.fallback and "  [the window gave no profession: worked out from its recipes]" or "")
	if SP.MySpecs and SP.SPECS then
		local have = {}
		for spec in pairs(SP.MySpecs()) do have[#have + 1] = SP.SPECS[spec] and SP.SPECS[spec][1] or tostring(spec) end
		table.sort(have)
		out[#out + 1] = "Specializations: " .. (#have > 0 and table.concat(have, ", ") or "none") .. "  (character key " .. SP.MyKey() .. ")"
	end

	local ok, ids = pcall(T.GetAllRecipeIDs)
	ids = ok and type(ids) == "table" and ids or {}
	local learned, unlearned, firstLearned, firstUnlearned, highest = 0, 0, nil, nil, nil
	local withGray, withDiff = 0, 0
	for _, id in ipairs(ids) do
		local okI, r = pcall(T.GetRecipeInfo, id)
		if okI and type(r) == "table" then
			if r.learned then
				learned = learned + 1
				firstLearned = firstLearned or id
			else
				unlearned = unlearned + 1
				firstUnlearned = firstUnlearned or id
				if (r.maxTrivialLevel or 0) > 0 then withGray = withGray + 1 end
				if r.relativeDifficulty ~= nil then withDiff = withDiff + 1 end
				highest = id
			end
		end
	end
	out[#out + 1] = "All recipe IDs: " .. #ids .. "  learned: " .. learned .. "  not learned: " .. unlearned
	out[#out + 1] = "Not learned, but with a grey level: " .. withGray .. ", with a color: " .. withDiff

	local okF, filtered = pcall(T.GetFilteredRecipeIDs)
	if okF and type(filtered) == "table" then
		out[#out + 1] = "Shown in the window right now: " .. #filtered
	end

	-- Blizzard's data file vs what the game says now, and what trainers asked
	local data = SP.DATA and prof.id and SP.DATA[prof.id]
	if data then
		local inData, greyDiff, trainerSeen, trainerDiff = 0, {}, 0, {}
		for _, id in ipairs(ids) do
			local d = data[id]
			local okI, r = pcall(T.GetRecipeInfo, id)
			if d and okI and type(r) == "table" then
				inData = inData + 1
				if (r.maxTrivialLevel or 0) > 0 and r.maxTrivialLevel ~= d[2] and #greyDiff < 15 then
					greyDiff[#greyDiff + 1] = tostring(r.name) .. " grey " .. d[2] .. " -> " .. r.maxTrivialLevel
				end
				local req = SP.Trainer and SP.Trainer.Requires(id)
				if req then
					trainerSeen = trainerSeen + 1
					if req ~= d[1] and #trainerDiff < 25 then
						trainerDiff[#trainerDiff + 1] = tostring(r.name) .. ": trainer " .. req .. ", yellow " .. d[1]
					end
				end
			end
		end
		out[#out + 1] = ""
		out[#out + 1] = "Built-in data (build " .. tostring(SP.DATA_BUILD) .. "): " .. inData .. " of these recipes"
		out[#out + 1] = "Grey level changed since the data file: " .. (#greyDiff > 0 and table.concat(greyDiff, "; ") or "none")
		out[#out + 1] = "Trainer recipes seen: " .. trainerSeen .. (trainerSeen == 0 and " (visit a trainer for this profession, then scan again)" or "")
		if #trainerDiff > 0 then
			out[#out + 1] = "Learned before they turn yellow:"
			for _, l in ipairs(trainerDiff) do out[#out + 1] = "  " .. l end
		end
	end

	if SP.Fishing and SP.Fishing.CurrentZone then
		local key, mapID = SP.Fishing.CurrentZone()
		local okM, best = pcall(C_Map and C_Map.GetBestMapForUnit or function() end, "player")
		out[#out + 1] = "Zone: " .. tostring(GetRealZoneText and GetRealZoneText()) .. ", map " .. tostring(okM and best)
			.. " -> fishing zone " .. tostring(key) .. (mapID and (" (map " .. mapID .. ")") or " (by name)")
	end

	if firstLearned then Describe(out, "A recipe you know", firstLearned) end
	if firstUnlearned then Describe(out, "A recipe you don't know", firstUnlearned) end
	if highest and highest ~= firstUnlearned then Describe(out, "Another recipe you don't know", highest) end
	if not firstUnlearned then
		out[#out + 1] = ""
		out[#out + 1] = "No unlearned recipes are listed. In the profession window's filter, turn on"
		out[#out + 1] = "showing recipes you haven't learned (if there is such an option) and scan again."
	end
	SP.ShowReport(out)
end

-- A window with the text selected, ready for Ctrl+C
function SP.ShowReport(lines)
	local f = SP.reportFrame
	if not f then
		f = CreateFrame("Frame", "ProfessionPathfinderReport", UIParent, "BackdropTemplate")
		f:SetSize(620, 420)
		f:SetPoint("CENTER")
		f:SetFrameStrata("DIALOG")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		if f.SetBackdrop then
			f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
		end
		tinsert(UISpecialFrames, "ProfessionPathfinderReport")
		local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOPLEFT", 12, -10)
		title:SetText("Profession Pathfinder: press Ctrl+C to copy, Esc to close")
		local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", 0, 0)
		local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
		scroll:SetPoint("TOPLEFT", 12, -32)
		scroll:SetPoint("BOTTOMRIGHT", -32, 12)
		local edit = CreateFrame("EditBox", nil, scroll)
		edit:SetMultiLine(true)
		edit:SetAutoFocus(true)
		edit:SetFontObject(ChatFontNormal)
		edit:SetWidth(560)
		edit:SetScript("OnEscapePressed", function() f:Hide() end)
		scroll:SetScrollChild(edit)
		f.edit = edit
		SP.reportFrame = f
	end
	f.edit:SetText(table.concat(lines, "\n"))
	f:Show()
	f.edit:SetFocus()
	f.edit:HighlightText()
end

---------------------------------------------------------------------------
-- /ppf export: the game's own names for every recipe in Data.lua and the
-- skill each recipe item needs. Saved in ProfessionPathfinderDB.export (on
-- /reload or logout) to build Sources.lua with tools/make_sources.py.
---------------------------------------------------------------------------
local function SkillPattern()
	local fmt = ITEM_MIN_SKILL or "Requires %s (%d)"
	-- placeholders (%s, %d, %1$s, %2$d) first, then escape the rest
	local p = fmt:gsub("%%%d?%$?([sd])", function(t) return t == "s" and "\1" or "\2" end)
	p = p:gsub("[%(%)%.%-%+%[%]%^%$%?%*]", "%%%0")
	p = p:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
	return "^" .. p .. "$"
end

local function ReadItem(id, pat)
	if C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(id) then return nil end
	local info = { name = C_Item.GetItemNameByID(id) }
	if not info.name then return nil end
	local ok, _, _, _, _, _, _, _, _, _, _, sell, _, _, bind = pcall(C_Item.GetItemInfo, id)
	if ok then info.sell, info.bind = sell, bind end
	if C_Item.GetItemSpell then
		local okS, sname, sid = pcall(C_Item.GetItemSpell, id)
		if okS then info.spell, info.spellName = sid, sname end
	end
	if C_TooltipInfo and C_TooltipInfo.GetItemByID then
		local okT, data = pcall(C_TooltipInfo.GetItemByID, id)
		for _, line in ipairs(okT and data and data.lines or {}) do
			local text = line.leftText
			if type(text) == "string" and not (issecretvalue and issecretvalue(text)) then
				local prof, rank = text:match(pat)
				if prof and tonumber(rank) and not info.skill then info.skill, info.skillName = tonumber(rank), prof end
			end
		end
	end
	return info
end

function SP.Export()
	local db = SP.db
	local ex = { locale = GetLocale and GetLocale(), version = SP.version, spells = {}, outputs = {}, items = {} }
	local nSpells = 0
	for _, recipes in pairs(SP.DATA or {}) do
		for id in pairs(recipes) do
			local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
			if name and not (issecretvalue and issecretvalue(name)) then ex.spells[id] = name; nSpells = nSpells + 1 end
			local ok, s = pcall(C_TradeSkillUI.GetRecipeSchematic, id, false)
			if ok and type(s) == "table" and s.outputItemID and s.outputItemID > 0 then ex.outputs[id] = s.outputItemID end
		end
	end
	local ids, left, pass, pat = SP.RECIPE_ITEM_IDS or {}, {}, 0, SkillPattern()
	for _, id in ipairs(ids) do left[#left + 1] = id; pcall(C_Item.RequestLoadItemDataByID, id) end
	print("|cff66bbffProfession Pathfinder:|r exporting " .. nSpells .. " recipe names and " .. #ids .. " recipe items, please wait...")
	local function Step()
		pass = pass + 1
		local still = {}
		for _, id in ipairs(left) do
			local info = ReadItem(id, pat)
			if info then ex.items[id] = info else still[#still + 1] = id; pcall(C_Item.RequestLoadItemDataByID, id) end
		end
		left = still
		if #left > 0 and pass < 20 then C_Timer.After(1, Step) return end
		local n = 0
		for _ in pairs(ex.items) do n = n + 1 end
		db.export = ex
		print("|cff66bbffProfession Pathfinder:|r export done: " .. nSpells .. " recipe names, " .. n .. " of " .. #ids
			.. " recipe items" .. (#left > 0 and (" (" .. #left .. " didn't load)") or "") .. ". Type /reload to save it.")
	end
	C_Timer.After(1, Step)
end
