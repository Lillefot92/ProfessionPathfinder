-- Profession Pathfinder - Window
-- A panel beside the profession window: the plan, the shopping list and
-- the total cost. Click a step to open that recipe.

local ADDON, SP = ...
local UI = {}
SP.UI = UI

local WIDTH, ROW, MAX_STEPS, MAX_MAKE, MAX_ITEMS = 330, 18, 12, 5, 8
local PREFIX = "|cff66bbffProfession Pathfinder:|r "
local DIFF_COLOR = { [0] = "ff8040", [1] = "ffff00", [2] = "40bf40", [3] = "808080" }

local function MakeRow(parent, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(WIDTH - 20, ROW)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(ROW - 2, ROW - 2)
	b.icon:SetPoint("LEFT")
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
	b.text:SetPoint("RIGHT", b, "RIGHT", -90, 0)
	b.text:SetJustifyH("LEFT")
	b.text:SetWordWrap(false)
	b.right = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.right:SetPoint("RIGHT")
	b.right:SetJustifyH("RIGHT")
	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetAllPoints()
	b.hl:SetColorTexture(1, 1, 1, 0.08)
	if onClick then
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnClick", onClick)
	end
	b:SetScript("OnEnter", function(self)
		if not self.tip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		for i, line in ipairs(self.tip) do
			if i == 1 then GameTooltip:SetText(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
		end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

-- Plan rows: left-click opens the recipe; a row with a place (trainer,
-- vendor) pins it on your map with a right-click, or a left-click when
-- there's no recipe to open.
local function RowClick(b, button)
	if b.pin and (button == "RightButton" or not b.recipeID) then
		SP.Pin(b.pin)
	elseif b.recipeID then
		SP.SelectRecipe(b.recipeID)
	end
end

-- Tooltip line for a recipe you still have to learn
local function LearnTip(e, where)
	local at = e.learnAt or e.from or "?"
	local cost = (e.trainCost or 0) > 0 and SP.Money(e.trainCost) or nil
	local how = e.source or "trainer"
	if how == "bags" then return "Not learned yet: you have the recipe in your bags. Use it at skill " .. at .. "." end
	if how == "alt" then return "Not learned yet: " .. where .. ". Use it at skill " .. at .. "." end
	if how == "vendor" then return "Not learned yet: buy " .. where .. (cost and (" (about " .. cost .. ")") or "") .. ". Learn it at skill " .. at .. "." end
	if how == "ah" then return "Not learned yet: buy it at " .. where .. (cost and (" (about " .. cost .. ")") or "") .. ". Learn it at skill " .. at .. "." end
	if how == "maybe" and (e.checked or (e.recipe and e.recipe.checked)) then
		return "Not learned yet: a trainer teaches it from about skill " .. at .. (cost and (" (about " .. cost .. ")") or "")
			.. ". Nearest: " .. where .. "."
	end
	if how == "maybe" then
		return "Not learned yet: probably taught by a trainer from about skill " .. at .. (cost and (" (about " .. cost .. ")") or "")
			.. ". No trainer window has shown it yet: open your trainer's window to check. Nearest: " .. where .. "."
	end
	return "Not learned yet: a trainer teaches it from skill " .. at .. (cost and (" for " .. cost) or "") .. ". Nearest: " .. where .. "."
end

-- First zone of a "A, B or C" list, to fit the price column
local function ShortZone(z)
	z = z or ""
	local first = z:match("^([^,]+)") or z
	first = first:match("^(.-) or ") or first
	first = first:gsub("%s*%b()", "")
	if #first > 18 then first = first:sub(1, 17) .. "." end
	return first
end

local function LearnTag(source, checked)
	if source == "vendor" or source == "ah" then return "(buy recipe)" end
	if source == "bags" then return "(recipe in bags)" end
	if source == "alt" then return "(recipe on alt)" end
	if source == "maybe" and not checked then return "(learn?)" end
	return "(learn)"
end

local PLACE_ICON = { train = "Interface\\Icons\\INV_Misc_Note_01", book = "Interface\\Icons\\INV_Misc_Book_11",
	quest = "Interface\\GossipFrame\\AvailableQuestIcon" }

local function MakeButton(parent, label, w, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, 22)
	b:SetText(label)
	b:SetScript("OnClick", onClick)
	return b
end

function UI:Create()
	if self.frame then return end
	local f = CreateFrame("Frame", "ProfessionPathfinderFrame", UIParent, "BackdropTemplate")
	self.frame = f
	f:SetSize(WIDTH, 40 + 30 + 44 + MAX_STEPS * ROW + 20 + MAX_MAKE * ROW + 20 + MAX_ITEMS * ROW + 110)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	if f.SetBackdrop then
		f:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 14,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		f:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
	end
	f:Hide()

	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.title:SetPoint("TOPLEFT", 10, -10)
	f.title:SetText("Profession Pathfinder")

	f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	f.close:SetPoint("TOPRIGHT", 2, 2)
	f.close:SetScript("OnClick", function() SP.db.shown = false; f:Hide() end)

	f.gear = CreateFrame("Button", nil, f)
	f.gear:SetSize(16, 16)
	f.gear:SetPoint("RIGHT", f.close, "LEFT", -2, 0)
	f.gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
	f.gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	f.gear:SetScript("OnClick", function() SP.OpenOptions() end)
	f.gear:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Options")
		GameTooltip:Show()
	end)
	f.gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

	f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
	f.sub:SetPoint("RIGHT", -10, 0)
	f.sub:SetJustifyH("LEFT")

	-- Craft next: left-click crafts the step, right-click crafts one
	local cb = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	cb:SetSize(WIDTH - 20, 24)
	cb:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", 0, -6)
	cb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	cb:SetScript("OnClick", function(_, button) UI:CraftClick(button) end)
	cb:SetScript("OnEnter", function(self)
		if not self.tip then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		for i, line in ipairs(self.tip) do
			if i == 1 then GameTooltip:SetText(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
		end
		GameTooltip:Show()
	end)
	cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f.craftButton = cb
	-- Walking up to an anvil doesn't fire an event: re-check once a second
	local since = 0
	f:HookScript("OnUpdate", function(_, e)
		since = since + e
		if since < 1 then return end
		since = 0
		local nx = UI.next
		if nx and nx.recipe then
			local now = SP.Unmet(nx.recipe)
			if #now ~= #(nx.needs or {}) then
				nx.needs = now
				UI:UpdateCraftButton()
			end
		end
	end)

	f.legacy = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.legacy:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 0, -4)
	f.legacy:SetPoint("RIGHT", -10, 0)
	f.legacy:SetJustifyH("LEFT")
	f.legacy:SetTextColor(1, 0.82, 0)

	f.planHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.planHeader:SetPoint("TOPLEFT", f.legacy, "BOTTOMLEFT", 0, -6)
	f.planHeader:SetText("Plan (click a step to open the recipe)")

	self.steps = {}
	for i = 1, MAX_STEPS do
		local row = MakeRow(f, RowClick)
		row:SetPoint("TOPLEFT", f.planHeader, "BOTTOMLEFT", 0, -2 - (i - 1) * ROW)
		self.steps[i] = row
	end

	f.makeHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.makeHeader:SetPoint("TOPLEFT", f.planHeader, "BOTTOMLEFT", 0, -8 - MAX_STEPS * ROW)
	f.makeHeader:SetText("Make first (cheaper than buying)")

	self.makes = {}
	for i = 1, MAX_MAKE do
		local row = MakeRow(f, RowClick)
		row:SetPoint("TOPLEFT", f.makeHeader, "BOTTOMLEFT", 0, -2 - (i - 1) * ROW)
		self.makes[i] = row
	end

	f.shopHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.shopHeader:SetPoint("TOPLEFT", f.makeHeader, "BOTTOMLEFT", 0, -8 - MAX_MAKE * ROW)
	f.shopHeader:SetText("Shopping list")

	self.items = {}
	for i = 1, MAX_ITEMS do
		local row = MakeRow(f)
		row:SetPoint("TOPLEFT", f.shopHeader, "BOTTOMLEFT", 0, -2 - (i - 1) * ROW)
		self.items[i] = row
	end

	f.total = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	f.total:SetPoint("BOTTOMLEFT", 10, 38)
	f.total:SetPoint("RIGHT", -10, 0)
	f.total:SetJustifyH("LEFT")

	f.note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	f.note:SetPoint("BOTTOMLEFT", f.total, "TOPLEFT", 0, 4)
	f.note:SetPoint("RIGHT", -10, 0)
	f.note:SetJustifyH("LEFT")

	f.ahButton = MakeButton(f, "Auctionator list", 104, function()
		if not SP.lastPlan then return end
		local ok, msg = SP.ExportToAuctionator(SP.lastPlan)
		if ok then print(PREFIX .. "created the Auctionator shopping list \"" .. msg .. "\".")
		else print(PREFIX .. "couldn't create the list: " .. msg) end
	end)
	f.ahButton:SetPoint("BOTTOMLEFT", 8, 8)

	f.bagButton = MakeButton(f, "", 104, function()
		SP.db.bagsFree = not SP.db.bagsFree
		SP.RequestRefresh()
	end)
	f.bagButton:SetPoint("BOTTOMRIGHT", -8, 8)


	-- Without a profession window: switch between gathering and characters
	f.viewButton = MakeButton(f, "Characters", 104, function()
		UI.view = (UI.view == "chars") and "gather" or "chars"
		SP.RequestRefresh()
	end)
	f.viewButton:SetPoint("BOTTOMLEFT", 8, 8)
	f.viewButton:Hide()
end

function UI:Anchor()
	local f = self.frame
	f:SetScale(SP.db.scale or 1)
	f:ClearAllPoints()
	local host = (ProfessionsFrame and ProfessionsFrame:IsShown() and ProfessionsFrame)
		or (TradeSkillFrame and TradeSkillFrame:IsShown() and TradeSkillFrame)
	if host then
		f:SetPoint("TOPLEFT", host, "TOPRIGHT", 2, 0)
	else
		f:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
	end
end

function UI:Open()
	self:Create()
	self.open = true
	if SP.db.shown == false then return end
	self:Anchor()
	self.frame:Show()
end

function UI:Close()
	self.open = false
	if self.frame then self.frame:Hide() end
end

function UI:IsOpen()
	return self.open
end

function UI:Toggle()
	self:Create()
	SP.db.shown = not self.frame:IsShown()
	if SP.db.shown then
		self:Anchor()
		self.frame:Show()
		self.open = true
		SP.RequestRefresh()
	else
		self.frame:Hide()
	end
end

local function Range(a, b)
	return a .. "-" .. b
end

-- Trainers, book sellers or quest givers for the next rank, in the plan rows
function UI:ShowPlaces(places, rank)
	local f = self.frame
	f.planHeader:SetText("Where to learn " .. rank .. " (nearest first, click to pin)")
	for i, p in ipairs(places) do
		local row = self.steps[i]
		if not row then break end
		row.recipeID = nil
		row.pin = p.npc
		row.icon:SetTexture(PLACE_ICON[p.how])
		row.text:SetText("|cffffffff" .. p.npc.name .. "|r" .. (p.npc.title and (" |cff999999<" .. p.npc.title .. ">|r") or ""))
		row.right:SetText(p.npc.zone or "")
		row.tip = { p.npc.name, p.text .. ".", "|cff66bbffClick to pin it on your map.|r" }
		row:Show()
	end
end

function UI:Show(prof, plan, loading)
	self:Create()
	local f = self.frame
	for _, row in ipairs(self.steps) do row:Hide(); row.pin = nil end
	for _, row in ipairs(self.makes) do row:Hide(); row.pin = nil end
	for _, row in ipairs(self.items) do row:Hide(); row.pin = nil end
	f.bagButton:SetText(SP.db.bagsFree and "My mats: on" or "My mats: off")
	f.ahButton:SetEnabled(SP.HasAuctionator() and plan ~= nil and #plan.shopping > 0)
	f.note:SetText("")
	f.total:SetText("")
	f.makeHeader:Hide()
	f.legacy:SetText("")
	self.next = nil
	self:UpdateCraftButton()

	f.planHeader:SetText("Plan (click a step to open the recipe)")
	f.shopHeader:SetText(SP.db.selfGather and "Gather and buy (gather & craft mode)" or "Shopping list")
	f.shopHeader:Show()
	f.viewButton:SetShown(not prof)
	f.ahButton:SetShown(prof ~= nil)
	f.bagButton:SetShown(prof ~= nil)
	if not prof then
		self:ShowGathering()
		return
	end
	if loading then
		f.sub:SetText(prof.label or prof.name)
		f.note:SetText("Loading profession data...")
		return
	end
	f.sub:SetText(string.format("%s  |cffffffff%d / %d|r", prof.label or prof.name, prof.skill, prof.max))
	local legacyAt = SP.NextLegacy(prof)
	if legacyAt then
		f.legacy:SetText(string.format("Legacy point at %d: %d skill to go", legacyAt, legacyAt - prof.skill)
			.. (prof.max < legacyAt and "  |cff999999(train the next rank first)|r" or ""))
	end
	if not plan then return end
	if plan.done then
		f.note:SetText("Nothing to plan: you've reached your target. Use /ppf target 0 to plan to your skill cap.")
		return
	end

	if plan.atCap then
		f.sub:SetText(string.format("%s  |cffffffff%d / %d|r  - at your cap", prof.label or prof.name, prof.skill, prof.max))
		local rs = SP.RankStatus(prof.name, prof.skill, prof.max)
		if rs then
			local places = SP.RankPlaces and SP.RankPlaces(prof.name, rs.rank) or {}
			self:ShowPlaces(places, rs.rank)
			local first = places[1]
			local how = not first and "at your trainer"
				or (first.how == "book" and "from a book") or (first.how == "quest" and "with a quest") or "at a trainer"
			f.note:SetText("You're at the skill cap. Learn |cffffffff" .. rs.rank .. "|r " .. how
				.. (rs.levelOK and " now" or (" at character level " .. rs.level)) .. " (cap " .. rs.cap .. ")."
				.. (first and " Nearest first: click one to pin it on your map." or ""))
		else
			f.note:SetText("You're at the skill cap. Visit a trainer to learn the next rank.")
		end
		self.next = nil
		self:UpdateCraftButton()
		return
	end

	local ot = (plan.overtime or 0) > 0 and ("  |cffffd100Working Overtime +" .. (4 * plan.overtime) .. "%|r") or ""
	f.sub:SetText(string.format("%s  |cffffffff%d to %d|r%s", prof.label or prof.name, plan.from, plan.to, ot))

	-- Steps
	for i, step in ipairs(plan.steps) do
		local row = self.steps[i]
		if not row then break end
		local r = step.recipe
		row.recipeID = (not step.learn) and r.id or nil
		row.icon:SetTexture(r.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		local name
		if step.learn then
			name = "|cffffffff" .. (r.name or "?") .. "|r |cffff8040" .. LearnTag(step.source, step.checked) .. "|r"
		else
			name = "|cff" .. (DIFF_COLOR[r.diff] or "ffffff") .. (r.name or "?") .. "|r"
		end
		if step.noRecipe then
			row.text:SetText("|cffffffff" .. (r.name or "?") .. "|r")
		else
			row.text:SetText(string.format("~%dx %s", step.crafts, name))
		end
		local legacyHere = legacyAt and step.from < legacyAt and step.to >= legacyAt
		row.right:SetText(legacyHere and ("|cffffd100" .. Range(step.from, step.to) .. "|r") or Range(step.from, step.to))
		local tip = {
			r.name or "?",
			step.noRecipe and ("Skill " .. Range(step.from, step.to) .. ".")
				or string.format("Skill %s, about %d crafts.", Range(step.from, step.to), step.crafts),
			(not step.noRecipe and not plan.selfGather) and ("Materials to buy for this step: " .. SP.Money(step.cost)) or nil,
		}
		if plan.selfGather and step.get then
			local parts = {}
			for id, n in pairs(step.get) do
				local c = math.ceil(n - 0.05)
				if c > 0 then parts[#parts + 1] = c .. "x " .. (SP.ItemName(id) or "?") end
			end
			table.sort(parts)
			if #parts > 0 then tip[#tip + 1] = "|cff40bf40Gather or buy for this step: " .. table.concat(parts, ", ") .. "|r" end
		end
		if step.note then tip[#tip + 1] = step.note end
		-- what the planner has learned about this recipe
		local e = r.id and SP.LearnEntry and SP.LearnEntry(r.id)
		if e and (e.yellow or e.green) then
			tip[#tip + 1] = "|cff999999Colors seen in game: " .. (e.yellow and ("yellow from " .. e.yellow .. (e.yellowExact and "" or "~")) or "")
				.. (e.yellow and e.green and ", " or "") .. (e.green and ("green from " .. e.green .. (e.greenExact and "" or "~")) or "")
				.. (r.gray and r.gray > 0 and (", gray at " .. r.gray) or "") .. ".|r"
		end
		if e and e.log then
			local c, u, parts = 0, 0, {}
			for _, d in ipairs({ { SP.DIFF.Optimal, "orange" }, { SP.DIFF.Medium, "yellow" }, { SP.DIFF.Easy, "green" } }) do
				local lg = e.log[d[1]]
				if lg and lg.c > 0 then
					c, u = c + lg.c, u + lg.u
					parts[#parts + 1] = d[2] .. " " .. lg.u .. "/" .. lg.c
				end
			end
			if c > 0 then
				tip[#tip + 1] = "|cff66bbffYour results: " .. c .. " crafts, " .. u .. " skill-ups (" .. table.concat(parts, ", ") .. ").|r"
			end
		end
		if legacyHere then tip[#tip + 1] = "|cffffd100Reaching " .. legacyAt .. " gives a Legacy point.|r" end
		if step.noRecipe then
			-- nothing to learn or click
		elseif step.learn then
			local where, npc = SP.LearnWhere(prof, step)
			row.pin = npc
			tip[#tip + 1] = LearnTip(step, where)
			if npc then tip[#tip + 1] = "|cff66bbffClick to pin " .. npc.name .. " on your map.|r" end
		else
			if r.gray then tip[#tip + 1] = "Turns gray at " .. r.gray .. "." end
			tip[#tip + 1] = "Click to open the recipe."
		end
		row.tip = tip
		row:Show()
	end
	if #plan.steps > MAX_STEPS then
		self.steps[MAX_STEPS].text:SetText("... and " .. (#plan.steps - MAX_STEPS + 1) .. " more steps")
		self.steps[MAX_STEPS].right:SetText("")
		self.steps[MAX_STEPS].tip = nil
	end

	-- Make first
	if #plan.prep > 0 then f.makeHeader:Show() end
	for i, prep in ipairs(plan.prep) do
		local row = self.makes[i]
		if not row then break end
		local r = prep.recipe
		row.recipeID = (not r.foreign and not prep.learn) and r.id or nil
		row.icon:SetTexture(r.icon)
		row.text:SetText(string.format("~%dx |cffcccccc%s|r", prep.crafts, r.name or "?") .. (prep.learn and (" |cffff8040" .. LearnTag(prep.source, prep.recipe and prep.recipe.checked) .. "|r") or ""))
		row.right:SetText("|cff999999" .. (r.foreign and r.profession or prof.label or prof.name) .. "|r")
		local learnText
		if prep.learn then
			local where, npc = SP.LearnWhere(prof, prep)
			row.pin = npc
			learnText = LearnTip(prep, where) .. (npc and ("\n|cff66bbffClick to pin " .. npc.name .. " on your map.|r") or "")
		end
		row.tip = { r.name or "?", "Cheaper to make than to buy: used by the steps above.",
			learnText or (r.foreign and ("Made with " .. r.profession .. ".") or "Click to open the recipe.") }
		row:Show()
	end
	if #plan.prep > MAX_MAKE then
		self.makes[MAX_MAKE].text:SetText("... and " .. (#plan.prep - MAX_MAKE + 1) .. " more")
		self.makes[MAX_MAKE].right:SetText("")
	end

	-- Shopping list
	if #plan.shopping == 0 then
		local row = self.items[1]
		row.icon:SetTexture(nil)
		row.text:SetText("|cff40bf40You have everything you need.|r")
		row.right:SetText("")
		row.tip = nil
		row:Show()
	end
	local gatherSave, gatherCount = 0, 0
	for i, item in ipairs(plan.shopping) do
		local itemName = item.name or SP.ItemName(item.itemID)
		-- Can you (or another of your characters) gather it?
		local gtag, gtip = "", nil
		local gs, src = nil, nil
		if item.itemID then gs, src = SP.Gatherers(item.itemID) end
		if gs and #gs > 0 then
			local who
			for _, g in ipairs(gs) do if g.ok then who = g break end end
			local verb = SP.GatherVerb(src.prof)
			local zone = SP.GatherWhere(src)
			local from = src.from or src.beasts and (src.beasts .. " beasts") or (src.node and (src.node .. (src.prof == "Mining" and " veins" or ""))) or "nodes"
			if who then
				gatherSave, gatherCount = gatherSave + (item.cost or 0), gatherCount + 1
				gtag = " |cff40bf40(" .. (who.me and (src.how == "smelt" and "smelt" or verb) or who.who) .. ")|r"
				if src.how == "smelt" then
					gtip = (who.me and "You" or who.who) .. " can smelt this from " .. src.node .. " ore: mine it from " .. from .. (zone and (" in " .. zone) or "") .. "."
				else
					gtip = (who.me and "You" or who.who) .. " can " .. verb .. " this from " .. from .. (zone and (" in " .. zone) or "") .. "."
				end
			else
				local g = gs[1]
				gtip = "Needs " .. src.prof .. " " .. src.skill .. " to " .. verb .. " (" .. (g.me and "you have " or (g.who .. " has ")) .. g.skill .. ")."
			end
		end
		local row = self.items[i]
		if row then
			row.icon:SetTexture(item.itemID and SP.ItemIcon(item.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
			local where = item.source == "vendor" and " |cff999999(vendor)|r" or ""
			row.text:SetText(item.count .. "x " .. itemName .. where .. gtag)
			if item.gather then
				local zone = src and SP.GatherWhere(src)
				row.right:SetText("|cff40bf40" .. (zone and ShortZone(zone) or "gather") .. "|r")
				row.pin = nil
				row.tip = { itemName, "Gather: " .. item.count .. (item.itemID and ("  (you have " .. SP.Owned(item.itemID) .. ")") or ""),
					zone and ("Where: " .. zone) or nil }
			else
				row.right:SetText(SP.Money(item.cost))
				row.tip = {
					itemName,
					"Need to buy: " .. item.count .. (item.itemID and ("  (you have " .. SP.Owned(item.itemID) .. ")") or ""),
					"Price each: " .. SP.Money(item.price) .. (item.source == "vendor" and " at a vendor" or (item.price and " on the auction house" or "")),
				}
			end
			if gtip then row.tip[#row.tip + 1] = (gtag ~= "" and "|cff40bf40" or "|cff999999") .. gtip .. "|r" end
			row:Show()
		end
	end
	if #plan.shopping > MAX_ITEMS then
		self.items[MAX_ITEMS].text:SetText("... and " .. (#plan.shopping - MAX_ITEMS + 1) .. " more items")
		self.items[MAX_ITEMS].right:SetText("")
		self.items[MAX_ITEMS].tip = nil
	end

	-- crafts and roughly how long they take
	local crafts, seconds = SP.PlanTime(plan)
	if crafts > 0 then
		f.planHeader:SetText("Plan: " .. crafts .. " crafts, " .. SP.Duration(seconds) .. " (click a step)")
	end
	if plan.selfGather then
		f.total:SetText("Gold to " .. (plan.reached or plan.to or "?") .. ": " .. SP.Money(plan.total)
			.. "  |cff40bf40+ " .. (plan.gatherCount or 0) .. " things to gather|r")
	elseif (plan.resale or 0) > 0 then
		f.total:SetText("Cost to " .. (plan.reached or plan.to or "?") .. ": " .. SP.Money(plan.total)
			.. "  |cff999999(" .. SP.Money(plan.net) .. " after selling what you craft)|r")
	else
		f.total:SetText("Estimated cost to " .. (plan.reached or plan.to or "?") .. ": " .. SP.Money(plan.total))
	end
	-- plans bought with Merchant's Favor
	local favor = SP.PlanFavor and SP.PlanFavor(plan) or 0
	if favor > 0 then
		local have = SP.CurrencyAmount(3402) or 0
		f.total:SetText(f.total:GetText() .. (favor > have and "  |cffff6060+ " or "  |cff66ccff+ ") .. favor .. " " .. SP.CurrencyName(3402)
			.. (favor > have and (" (you have " .. have .. ")") or "") .. "|r")
	end
	self.next = SP.NextCraft(plan)
	self:UpdateCraftButton()

	-- Notes
	local notes = {}
	if plan.selfGather then
		for _, w in ipairs(plan.gatherWarn or {}) do
			local verb = SP.GatherVerb(w.prof)
			notes[#notes + 1] = "|cffffd100Raise " .. w.prof .. " to " .. w.skill .. "|r to " .. verb .. " " .. (w.node or "it")
				.. (w.who and (" (or let " .. w.who .. " do it)") or (" (you have " .. (w.have or 0) .. ")")) .. "."
		end
	end
	local nextLearn = plan.toLearn and plan.toLearn[1]
	if nextLearn then
		local where = SP.LearnWhere(prof, nextLearn)
		local at = nextLearn.learnAt or nextLearn.from
		notes[#notes + 1] = "Next to learn: |cffffffff" .. nextLearn.recipe.name .. "|r at skill " .. at .. ", from " .. where
			.. (nextLearn.source == "maybe" and not (nextLearn.checked or nextLearn.recipe.checked) and " (probably: not seen at a trainer yet)" or "")
			.. ((nextLearn.trainCost or 0) > 0 and (" (" .. SP.Money(nextLearn.trainCost) .. ")") or "") .. "."
	end
	if plan.trainerAt then
		notes[#notes + 1] = "From " .. plan.trainerAt .. " your known recipes rarely give skill. Check your trainer for new recipes (and reopen this window), or look for recipe drops at the Auction House."
	elseif plan.selfStuck then
		notes[#notes + 1] = "From " .. plan.stuckAt .. " no recipe can be made from what you gather and what vendors sell. Gather & craft mode works for professions that use ore, herbs, leather or cloth (turn it off in /ppf options or with /ppf gather)."
	elseif plan.stuckAt then
		local ways = SP.WaysPast and SP.WaysPast(prof, plan.stuckAt, 3) or {}
		if #ways > 0 then
			local list = {}
			for _, w in ipairs(ways) do list[#list + 1] = SP.WayText(w) end
			notes[#notes + 1] = "From " .. plan.stuckAt .. " you need plans the addon can't count on. Ways past it: " .. table.concat(list, "; ") .. "."
		else
			notes[#notes + 1] = "From " .. plan.stuckAt .. " no recipe you know, or that a trainer is known to teach, gives skill. Visit your trainer (and reopen this window), or look for recipes from vendors and drops."
		end
	elseif #plan.steps > 0 then
		notes[#notes + 1] = "Built from the game's own recipe data. Open a trainer's window now and then: the recipes it lists are added to the plan."
	end
	local rs = SP.RankStatus(prof.name, prof.skill, prof.max)
	if rs and rs.skillOK then
		notes[#notes + 1] = "You can learn |cffffffff" .. rs.rank .. "|r" .. (rs.levelOK and " now" or (" at character level " .. rs.level)) .. " (cap " .. rs.cap .. ")"
			.. " from " .. SP.RankHow(prof.name, rs.rank) .. "."
	end
	local specText = SP.SpecNote and SP.SpecNote(prof, plan)
	if specText then notes[#notes + 1] = specText end
	if gatherCount > 0 and not plan.selfGather then
		notes[#notes + 1] = "|cff40bf40Green items|r you can gather yourself" .. (gatherSave > 0 and (": saves about " .. SP.Money(gatherSave)) or "") .. "."
	end
	if prof.id == 186 or prof.enum == 6 or prof.name == "Mining" then
		local z = SP.GatherZone("Mining", prof.skill)
		notes[#notes + 1] = "Mining also rises from mining ore nodes" .. (z and (": " .. z.what .. " in " .. SP.ZoneFor(z)) or "") .. "."
	end
	local seen = SP.db.known and SP.db.known[SP.MyKey()] or {}
	-- Only professions that use metal bars care about smelting
	local usesBars = prof.name == "Blacksmithing" or prof.name == "Engineering"
	for _, name in ipairs(usesBars and SP.MyProfessions() or {}) do
		if name ~= prof.name and not seen[name] then
			notes[#notes + 1] = "Open your " .. name .. " window once so smelting can be used for bars."
		end
	end
	if plan.selfGather then
		notes[#notes + 1] = "Gather & craft mode: only what you gather and vendor items, no Auction House."
	elseif not SP.HasAuctionator() then
		notes[#notes + 1] = "Install Auctionator for prices."
	elseif plan.unknownPrices then
		notes[#notes + 1] = "Some prices are missing: do an Auctionator scan at the auction house."
	end
	if (plan.resale or 0) > 0 then
		local top = plan.sell[1]
		local name = top and ((C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(top.itemID)) or "your crafts")
		notes[#notes + 1] = "Selling what you craft gets back about " .. SP.Money(plan.resale)
			.. (plan.resaleMode == "best" and " (vendor or Auction House, whichever pays more)" or " at a vendor")
			.. (top and (", most from " .. top.count .. "x " .. name) or "") .. "."
	end
	f.note:SetText(table.concat(notes, " "))
	self:FitList(#plan.shopping)
	C_Timer.After(0, function() if UI.frame and UI.frame:IsShown() then UI:FitList(#plan.shopping) end end)
end

-- Long notes grow upward over the shopping list: hide the rows they would
-- cover, and say how many more there are on the last row that fits.
function UI:FitList(total)
	local f = self.frame
	local noteTop = f and f.note and f.note:GetTop()
	if not noteTop or (f.note:GetText() or "") == "" then return end
	local shown, lastFit = 0, nil
	for i = 1, MAX_ITEMS do
		local row = self.items[i]
		if row and row:IsShown() then
			shown = shown + 1
			local bottom = row:GetBottom()
			if bottom and bottom < noteTop + 2 then
				row:Hide()
			else
				lastFit = i
			end
		end
	end
	if lastFit and lastFit < math.min(total, MAX_ITEMS) or (lastFit and total > MAX_ITEMS and lastFit < MAX_ITEMS) then
		local row = self.items[lastFit]
		row.text:SetText("... and " .. (total - lastFit + 1) .. " more items")
		row.right:SetText("")
		row.icon:SetTexture(nil)
		row.tip = nil
	end
end

---------------------------------------------------------------------------
-- Craft button
---------------------------------------------------------------------------
local function ShortName(s, n)
	s = s or "?"
	if #s > n then return s:sub(1, n - 1) .. "..." end
	return s
end

function UI:UpdateCraftButton()
	local f = self.frame
	if not f then return end
	local b, nx = f.craftButton, self.next
	b:Show()
	b.tip = nil
	if SP.IsCrafting() then
		b:SetText("Crafting... click to stop")
		b:SetEnabled(true)
		b.tip = { "Stop crafting", "Stops after the current craft." }
		return
	end
	if not nx then
		b:SetText("Nothing to craft")
		b:SetEnabled(false)
		return
	end
	if nx.recipe and nx.needs and #nx.needs > 0 then
		local r = nx.recipe
		b:SetText("Needs " .. table.concat(nx.needs, ", ") .. " to craft")
		b:SetEnabled(false)
		b.tip = {
			(nx.prep and "Make " or "Craft ") .. nx.count .. "x " .. (r.name or "?"),
			"Needs: " .. table.concat(nx.needs, ", ") .. ".",
			"Stand next to it, or put the tool in your bags. The button lights up when you're ready.",
		}
		return
	end
	if nx.recipe then
		local r = nx.recipe
		b:SetText(string.format("%s %dx %s", nx.prep and "Make" or "Craft", nx.count, ShortName(r.name, 30)))
		b:SetEnabled(true)
		b.tip = {
			(nx.prep and "Make " or "Craft ") .. nx.count .. "x " .. (r.name or "?"),
			nx.prep and ("Needed for " .. (nx.step.recipe.name or "the next step") .. ".")
				or string.format("Step %s-%s, about %d crafts.", nx.step.from, nx.step.to, nx.step.crafts),
			"Left-click: craft " .. nx.count .. ". Right-click: craft 1.",
			"The plan updates as your skill goes up.",
		}
	elseif nx.learn then
		local st = nx.learn
		local where, npc = SP.LearnWhere(SP.lastPlan and SP.lastPlan.prof, st)
		b:SetText("Learn " .. ShortName(st.recipe.name, 26) .. " first")
		b:SetEnabled(npc ~= nil)
		self.pin = npc
		b.tip = { "Learn " .. (st.recipe.name or "?"), "From " .. where .. " at skill " .. st.from .. ".",
			npc and ("|cff66bbffClick to pin " .. npc.name .. " on your map.|r") or nil }
	elseif nx.enchant then
		b:SetText("Enchant: use the profession window")
		b:SetEnabled(false)
		b.tip = { nx.enchant.recipe.name or "?", "Enchants go on an item, so pick it in the profession window." }
	elseif nx.missing then
		local s = nx.short and nx.short[1]
		b:SetText(s and ("Need " .. s.short .. " more " .. ShortName(s.name, 22)) or "Missing materials")
		b:SetEnabled(false)
		local tip = { "Not enough materials for " .. (nx.missing.recipe.name or "the next step"), "Missing for one craft (in your bags):" }
		for _, m in ipairs(nx.short or {}) do tip[#tip + 1] = m.short .. "x " .. m.name end
		tip[#tip + 1] = "Materials in the bank don't count: take them out first."
		b.tip = tip
	end
end

function UI:CraftClick(button)
	if SP.IsCrafting() then SP.StopCrafting() SP.RequestRefresh() return end
	local nx = self.next
	if nx and nx.learn and self.pin then SP.Pin(self.pin) return end
	if not (nx and nx.recipe) then return end
	local count = (button == "RightButton") and 1 or nx.count
	SP.SelectRecipe(nx.recipe.id)
	local ok, err = SP.Craft(nx.recipe, count)
	if not ok then print(PREFIX .. "couldn't craft: " .. tostring(err) .. ". Use the Create button in the profession window.") end
	C_Timer.After(0.3, function() UI:UpdateCraftButton() end)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_PROFESSIONPATHFINDER1 = "/pathfinder"
SLASH_PROFESSIONPATHFINDER2 = "/ppf"
SlashCmdList.PROFESSIONPATHFINDER = function(msg)
	local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
	if cmd == "target" then
		local n = tonumber(arg)
		SP.db.target = n or 0
		print(PREFIX .. (n and ("planning up to skill " .. n) or "planning up to your skill cap"))
		SP.RequestRefresh()
	elseif cmd == "gather" then
		SP.db.selfGather = not SP.db.selfGather
		print(PREFIX .. (SP.db.selfGather and "gather & craft mode on: only what you gather yourself and vendor items" or "gather & craft mode off: Auction House materials are used again"))
		SP.RequestRefresh()
	elseif cmd == "bags" then
		SP.db.bagsFree = not SP.db.bagsFree
		print(PREFIX .. (SP.db.bagsFree and "materials you own are taken off the shopping list" or "shopping list ignores what you own"))
		SP.RequestRefresh()
	elseif cmd == "fish" or cmd == "fishing" then
		if not SP.Fishing then return end
		if arg == "log" then SP.Fishing.PrintLog()
		elseif arg == "reset" then SP.Fishing.ResetSession(); SP.Fishing.UpdateStatus(); print(PREFIX .. "new fishing session started.")
		else SP.Fishing.Toggle() end
	elseif cmd == "chars" or cmd == "characters" then
		UI.view = "chars"
		UI:Create()
		if not UI.frame:IsShown() then UI:Toggle() else SP.RequestRefresh() end
	elseif cmd == "scan" then
		SP.Diagnose()
	elseif cmd == "export" then
		SP.Export()
	elseif cmd == "trainer" then
		SP.Trainer.Report()
	elseif cmd == "options" or cmd == "config" or cmd == "settings" then
		SP.OpenOptions()
	elseif cmd == "help" then
		print(PREFIX .. "/ppf - show or hide the planner (with no profession window open it shows where to gather); /ppf options - options page; /ppf target <skill> - plan up to a skill (0 = cap); /ppf bags - take what you own off the shopping list (on/off); /ppf gather - gather & craft mode, only what you gather yourself (on/off); /ppf chars - all your characters' professions; /ppf fish - one-key fishing on/off; /ppf fish log - fishing by zone; /ppf fish reset - new fishing session; /ppf scan - recipe data check (for bug reports); /ppf trainer - trainer data check")
	else
		UI:Toggle()
	end
end

---------------------------------------------------------------------------
-- Options panel (Options > AddOns). Plain frames and textures only, so it
-- doesn't depend on Blizzard's changing settings widgets.
---------------------------------------------------------------------------
local Panel = {}

local function Tooltip(owner, title, text)
	if not text then return end
	owner:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 1, 1)
		GameTooltip:AddLine(text, nil, nil, nil, true)
		GameTooltip:Show()
	end)
	owner:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Round(v, step)
	return tonumber(string.format("%.2f", math.floor(v / step + 0.5) * step))
end

-- Build a panel from a layout list:
--   { "header", text }
--   { "check",  key, label, tip }
--   { "choice", key, label, { { value, text }, ... }, tip }
--   { "number", key, label, min, max, step, format(v) -> text, tip }
--   { "buttons", { { text, func, tip }, ... } }
--   { "text", text }
-- get(key) / set(key, value) read and write the settings.
function Panel.Build(title, subtitle, layout, get, set)
	local p = CreateFrame("Frame")
	p:Hide()
	p.controls = {}

	local t = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	t:SetPoint("TOPLEFT", 16, -16)
	t:SetText(title)
	local s = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
	s:SetPoint("RIGHT", -16, 0)
	s:SetJustifyH("LEFT")
	s:SetText(subtitle)

	local y = -64
	local LABEL_X, VALUE_X = 20, 250

	for _, e in ipairs(layout) do
		local kind = e[1]
		if kind == "header" then
			y = y - 8
			local h = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			h:SetPoint("TOPLEFT", 16, y)
			h:SetText(e[2])
			local line = p:CreateTexture(nil, "ARTWORK")
			line:SetColorTexture(1, 0.82, 0, 0.25)
			line:SetHeight(1)
			line:SetPoint("LEFT", h, "RIGHT", 8, 0)
			line:SetPoint("RIGHT", p, "RIGHT", -16, 0)
			y = y - 22

		elseif kind == "check" then
			local key, label, tip = e[2], e[3], e[4]
			local b = CreateFrame("CheckButton", nil, p)
			b:SetSize(24, 24)
			b:SetPoint("TOPLEFT", LABEL_X - 4, y + 2)
			b:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
			b:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
			b:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
			b:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
			b:SetHitRectInsets(0, -220, 0, 0)
			local l = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			l:SetPoint("LEFT", b, "RIGHT", 4, 0)
			l:SetText(label)
			b:SetScript("OnClick", function(self) set(key, self:GetChecked() and true or false) end)
			Tooltip(b, label, tip)
			p.controls[#p.controls + 1] = function() b:SetChecked(get(key) and true or false) end
			y = y - 28

		elseif kind == "choice" or kind == "number" then
			local key, label = e[2], e[3]
			local l = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			l:SetPoint("TOPLEFT", LABEL_X, y - 4)
			l:SetText(label)
			local prev = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
			prev:SetSize(24, 22)
			prev:SetPoint("TOPLEFT", VALUE_X, y)
			prev:SetText("<")
			local box = CreateFrame("Frame", nil, p)
			box:SetSize(150, 22)
			box:SetPoint("LEFT", prev, "RIGHT", 2, 0)
			local bg = box:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			bg:SetColorTexture(0, 0, 0, 0.4)
			local v = box:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
			v:SetAllPoints()
			local nextB = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
			nextB:SetSize(24, 22)
			nextB:SetPoint("LEFT", box, "RIGHT", 2, 0)
			nextB:SetText(">")

			local refresh, step
			if kind == "choice" then
				local values, tip = e[4], e[5]
				local function index()
					local cur = get(key)
					for i, opt in ipairs(values) do if opt[1] == cur then return i end end
					return 1
				end
				refresh = function() v:SetText(values[index()][2]) end
				step = function(d)
					local i = index() + d
					if i < 1 then i = #values elseif i > #values then i = 1 end
					set(key, values[i][1])
				end
				Tooltip(box, label, tip)
				box:EnableMouse(true)
			else
				local lo, hi, inc, fmt, tip, custom = e[4], e[5], e[6], e[7], e[8], e[9]
				refresh = function()
					local cur = tonumber(get(key)) or lo
					v:SetText(fmt and fmt(cur) or tostring(cur))
				end
				step = function(d)
					local cur = tonumber(get(key)) or lo
					local nv = custom and custom(cur, d) or Round(cur + d * inc, inc)
					if nv < lo then nv = lo elseif nv > hi then nv = hi end
					set(key, nv)
				end
				Tooltip(box, label, tip)
				box:EnableMouse(true)
			end
			prev:SetScript("OnClick", function() step(-1); p:Refresh() end)
			nextB:SetScript("OnClick", function() step(1); p:Refresh() end)
			box:EnableMouseWheel(true)
			box:SetScript("OnMouseWheel", function(_, d) step(d > 0 and 1 or -1); p:Refresh() end)
			p.controls[#p.controls + 1] = refresh
			y = y - 28

		elseif kind == "buttons" then
			y = y - 6
			local x = LABEL_X - 4
			for _, def in ipairs(e[2]) do
				local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
				b:SetText(def[1])
				b:SetSize(math.max(110, (b:GetFontString() and b:GetFontString():GetStringWidth() or 80) + 24), 22)
				b:SetPoint("TOPLEFT", x, y)
				b:SetScript("OnClick", function() def[2](); p:Refresh() end)
				Tooltip(b, def[1], def[3])
				x = x + (b:GetWidth() or 110) + 6
			end
			y = y - 30

		elseif kind == "text" then
			local fs = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			fs:SetPoint("TOPLEFT", LABEL_X - 4, y - 4)
			fs:SetPoint("RIGHT", -16, 0)
			fs:SetJustifyH("LEFT")
			fs:SetText(e[2])
			y = y - (fs:GetStringHeight() or 12) - 10
		end
	end

	function p:Refresh()
		for _, f in ipairs(self.controls) do pcall(f) end
	end
	p:SetScript("OnShow", function(self) self:Refresh() end)
	p.OnRefresh = p.Refresh
	p.height = -y + 16
	return p
end

-- Add the panel to Options > AddOns. Falls back to a movable window of its
-- own if the game's settings window can't take it.
function Panel.Register(p, name)
	p.name = name
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, p, name)
		if ok and cat then
			pcall(Settings.RegisterAddOnCategory, cat)
			p.category = cat
			return
		end
	end
end

function Panel.Open(p)
	-- The game no longer lets addons open the Options window (it's a
	-- protected action), so the settings open in a window of their own.
	-- They're still in Options > AddOns too.
	-- Own window
	if type(p.window) ~= "table" then
		local w = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		w:SetSize(560, p.height + 20)
		w:SetPoint("CENTER")
		w:SetFrameStrata("DIALOG")
		w:SetMovable(true)
		w:EnableMouse(true)
		w:RegisterForDrag("LeftButton")
		w:SetScript("OnDragStart", w.StartMoving)
		w:SetScript("OnDragStop", w.StopMovingOrSizing)
		w:SetClampedToScreen(true)
		if w.SetBackdrop then
			w:SetBackdrop({
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true, tileSize = 16, edgeSize = 14,
				insets = { left = 3, right = 3, top = 3, bottom = 3 },
			})
			w:SetBackdropColor(0.05, 0.05, 0.08, 0.97)
		end
		local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", 2, 2)
		p.window = w
	end
	-- (Options > AddOns borrows the page while it's open: take it back)
	p:SetParent(p.window)
	p:ClearAllPoints()
	p:SetAllPoints()
	p.window:Show()
	p:Show()
	p:Refresh()
end

---------------------------------------------------------------------------
-- Profession Pathfinder options page
---------------------------------------------------------------------------
function SP.ResetSettings()
	if not SP.db then return end
	wipe(SP.db)
	for k, v in pairs(SP.defaults) do SP.db[k] = v end
end

local function Get(key) return SP.db and SP.db[key] end
local function Set(key, value)
	if not SP.db then return end
	SP.db[key] = value
	local f = UI.frame
	if f then
		if key == "scale" then f:SetScale(value) end
		if key == "shown" then
			if value and UI:IsOpen() then UI:Anchor(); f:Show() elseif not value then f:Hide() end
		end
	end
	if key:sub(1, 4) == "fish" and SP.Fishing then SP.Fishing.Update() end
	SP.RequestRefresh()
end

local panel = Panel.Build("Profession Pathfinder",
	"Version " .. tostring(SP.version) .. ". Plans how to level your professions, with a shopping list. Settings save automatically.",
	{
		{ "header", "Planner window" },
		{ "check", "shown", "Show the planner when I open a profession",
			"Off: the planner stays hidden until you type /ppf." },
		{ "number", "scale", "Size", 0.6, 1.5, 0.05, function(v) return string.format("%d%%", v * 100 + 0.5) end },
		{ "header", "Planning" },
		{ "check", "selfGather", "Gather & craft: only use what I gather myself",
			"Plans with only materials you (or one of your characters) can gather, cloth from humanoids and vendor items. No Auction House. Shows where to gather everything and which gathering skill to raise first. Also /ppf gather." },
		{ "check", "bagsFree", "Count materials I already own",
			"Materials in your bags and bank are taken off the shopping list." },
		{ "choice", "resale", "Count what I get back", { { "off", "Off" }, { "vendor", "Selling to a vendor" }, { "best", "Vendor or AH, best" } },
			"Shows what you'd get back for the things you craft. Vendor: what a merchant pays. Vendor or AH: whichever pays more, with Auction House prices from Auctionator after the 5% cut. Things the plan uses later (like bars for your next recipe) aren't counted as sold." },
		{ "check", "favorPlans", "Use plans bought with Merchant's Favor",
			"The trade camps (Durotar Supply and Logistics west of the Crossroads, Azeroth Commerce Authority at Three Corners) sell plans for Merchant's Favor. On: the plan uses them when you have the Favor and the reputation. Off: they're only shown as a way to get further." },
		{ "check", "netPick", "Pick recipes by cost after selling",
			"Off: recipes are picked by what you pay now. On: by what's left after selling what you craft. That's cheaper in the end, but can need much more gold up front." },
		{ "number", "target", "Plan up to", 0, 300, 5, function(v) return v == 0 and "Skill cap" or string.format("skill %d", v) end,
			"Skill cap: up to the most your current rank allows. Or pick a skill level to stop at.",
			function(cur, d)
				-- start just above your current skill; going below it means "skill cap"
				local prof = SP.ProfessionInfo and SP.ProfessionInfo()
				local skill = (SP.lastPlan and SP.lastPlan.from) or (prof and prof.skill) or 0
				local first = math.floor(skill / 5) * 5 + 5
				if d > 0 then
					if cur < first then return math.min(300, first) end
					return math.min(300, cur + 5)
				end
				if cur <= first then return 0 end
				return cur - 5
			end },
		{ "header", "Fishing" },
		{ "check", "fishMode", "One-key fishing when a fishing pole is equipped",
			"Your fishing key casts. While the line is out, the same key catches (it becomes the game's Interact key, which picks the bobber). You still press it every time." },
		{ "choice", "fishKey", "Fishing key", { { "F", "F" }, { "G", "G" }, { "R", "R" }, { "`", "` (left of 1)" }, { "BUTTON4", "Mouse 4" }, { "BUTTON5", "Mouse 5" } },
			"Only while a fishing pole is equipped and you're out of combat. Your normal binding comes back when you take the pole off or a fight starts." },
		{ "check", "fishSound", "Louder splash while fishing",
			"Sound effects up, music and ambience off, sound on when the game is in the background. Put back when you stop fishing." },
		{ "check", "fishLure", "Lure reminder (Shift + key puts on a lure)",
			"Uses the best lure in your bags that your skill allows. Shows the time left on the lure, and warns you with a sound when it runs out." },
		{ "check", "fishLog", "Catch log and zone tips while fishing",
			"Under the fishing line: your skill, what you caught, what got away, gold per hour (Auctionator prices) and whether the zone suits your skill. Hover it for details. /ppf fish log lists every zone." },
		{ "check", "fishCook", "Show the fish your cooking needs",
			"While fishing: which fish your cooking plan needs next, how many you have (bags and bank), and where it swims." },
		{ "buttons", {
			{ "Auctionator list", function()
				local ok, msg = SP.ExportToAuctionator(SP.lastPlan)
				if ok then print(PREFIX .. "created the Auctionator shopping list \"" .. msg .. "\".")
				else print(PREFIX .. "couldn't create the list: " .. tostring(msg)) end
			end, "Creates an Auctionator shopping list from the last plan (open a profession first)." },
			{ "Reset all settings", function() SP.ResetSettings(); if UI.frame then UI:Anchor() end; SP.RequestRefresh() end },
		} },
		{ "text", "|cff999999/ppf shows or hides the planner (or where to gather when no profession window is open), /ppf options opens this page, /ppf help lists the commands.|r" },
	},
	Get, Set)
panel.OnDefault = function() SP.ResetSettings(); SP.RequestRefresh() end
Panel.Register(panel, "Profession Pathfinder")
SP.optionsPanel = panel

function SP.OpenOptions()
	Panel.Open(panel)
end

function ProfessionPathfinder_Compartment()
	UI:Toggle()
end

---------------------------------------------------------------------------
-- Gathering view (shown by /ppf when no profession window is open)
---------------------------------------------------------------------------
local GATHER_ICON = {
	Mining = "Interface\\Icons\\Trade_Mining", Herbalism = "Interface\\Icons\\Trade_Herbalism",
	Skinning = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", Fishing = "Interface\\Icons\\Trade_Fishing",
}

function SP.ZoneFor(z)
	local f = UnitFactionGroup and UnitFactionGroup("player")
	local text = f == "Horde" and z.horde or z.alliance
	local level = UnitLevel and UnitLevel("player")
	if issecretvalue and issecretvalue(level) then level = nil end
	return SP.FitZones and SP.FitZones(text, level) or text
end

function SP.GatherZone(prof, skill)
	local g = SP.Gathering and SP.Gathering[prof]
	if not g then return end
	for _, z in ipairs(g.route) do
		if skill < z.to then return z end
	end
	return g.route[#g.route]
end

-- Your gathering professions: { name, skill, max }
function SP.MyGathering()
	local out = {}
	if not (GetProfessions and GetProfessionInfo) then return out end
	local t = { pcall(GetProfessions) }
	if not t[1] then return out end
	for i = 2, 7 do
		local idx = t[i]
		if idx then
			local ok, label, icon, skill, max, _, _, line = pcall(GetProfessionInfo, idx)
			local name = ok and SP.ProfKey(line, label)
			if ok and name and SP.Gathering[name] then
				out[#out + 1] = { name = name, label = label, icon = icon, skill = skill or 0, max = max or 0 }
			end
		end
	end
	return out
end

local function NodeColor(skill, req)
	if skill < req then return nil end
	if skill < req + 25 then return "ff8040" end
	if skill < req + 50 then return "ffff00" end
	if skill < req + 100 then return "40bf40" end
	return "808080"
end

function UI:ShowGathering()
	local f = self.frame
	f.craftButton:Hide()
	f.legacy:SetText("")
	f.viewButton:SetText(self.view == "chars" and "Gathering" or "Characters")
	if self.view == "chars" then return self:ShowCharacters() end
	f.sub:SetText("Gathering")
	f.planHeader:SetText("Where to gather")
	f.shopHeader:Hide()
	f.makeHeader:Hide()
	f.ahButton:SetEnabled(false)
	local rows, n = self.steps, 0
	local function Add(icon, text, right, tip, pin)
		n = n + 1
		local row = rows[n]
		if not row then return end
		row.recipeID = nil
		row.pin = pin
		row.icon:SetTexture(icon)
		row.text:SetText(text)
		row.right:SetText(right or "")
		row.tip = tip
		row:Show()
	end
	local list = SP.MyGathering()
	for _, p in ipairs(list) do
		local g = SP.Gathering[p.name]
		Add(GATHER_ICON[p.name] or p.icon, "|cffffd100" .. (p.label or p.name) .. "|r", p.skill .. " / " .. p.max)
		local z = SP.GatherZone(p.name, p.skill)
		if z then
			Add(nil, "  " .. z.what .. " |cffaaaaaain|r " .. SP.ZoneFor(z), z.from .. "-" .. z.to,
				{ p.name .. " " .. z.from .. "-" .. z.to, "Gather: " .. z.what, "Where: " .. SP.ZoneFor(z), z.note })
		end
		if g.nodes then
			local best, all = {}, {}
			for i = #g.nodes, 1, -1 do
				local node = g.nodes[i]
				local c = NodeColor(p.skill, node[2])
				if c then
					all[#all + 1] = "|cff" .. c .. node[1] .. "|r (" .. node[2] .. ")"
					if (c == "ff8040" or c == "ffff00") and #best < 3 then best[#best + 1] = "|cff" .. c .. node[1] .. "|r" end
				else
					all[#all + 1] = "|cff888888" .. node[1] .. " (" .. node[2] .. ")|r"
				end
			end
			if #best > 0 then
				Add(nil, "  Best skill-ups: " .. table.concat(best, ", "), nil,
					{ "What you can gather", "Orange always gives a point, yellow usually, green sometimes, gray never.", table.concat(all, ", ") })
			end
		elseif p.name == "Skinning" then
			local lvl = SP.SkinLevel(p.skill)
			Add(nil, string.format("  Skin beasts up to level |cffffffff%d|r (best: %d-%d)", lvl, math.max(1, lvl - 3), lvl), nil,
				{ "Skinning", "Skill needed: level 1-10 beasts need 1, levels 11-19 need (level - 10) x 10, level 20 and up need level x 5.",
					"Beasts close to the highest level you can skin give points most often." })
		end
		if p.max < 300 and p.skill >= p.max - 15 then
			for _, r in ipairs(SP.RANKS) do
				if r.cap == p.max then
					local how, place = SP.RankHow(p.name, r.name)
					if how == "your trainer" then how = "a trainer" end
					local at = ((p.name == "Fishing" or p.name == "Cooking") and r.name == "Artisan") and 225 or r.at
					local tip = { "Learn " .. r.name .. " " .. (p.label or p.name), "From " .. how .. "." }
					local others = SP.RankPlaces and SP.RankPlaces(p.name, r.name) or {}
					for i = 2, math.min(4, #others) do tip[#tip + 1] = "|cffaaaaaaor " .. others[i].text .. "|r" end
					if place then tip[#tip + 1] = "|cff66bbffClick to pin " .. place.npc.name .. " on your map.|r" end
					Add(nil, "  |cffff8040Train " .. r.name .. "|r" .. (p.skill >= at and " now" or (" at " .. at)) .. " from " .. how, "cap " .. r.next,
						tip, place and place.npc)
					break
				end
			end
		end
	end
	if #list == 0 then
		Add(nil, "|cff888888You have no gathering professions.|r")
	end
	f.note:SetText("Open a crafting profession's window to plan it. Zones: wow-professions.com Forever guides.")
	f.total:SetText("")
end

---------------------------------------------------------------------------
-- Characters view: every character's professions, next step, rank and
-- Legacy milestone (characters appear once you log in on them).
---------------------------------------------------------------------------
local CLASS_COLOR = function(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c and c.colorStr then return c.colorStr end
	return "ffffffff"
end

function UI:ShowCharacters()
	local f = self.frame
	f.sub:SetText("Your characters")
	f.planHeader:SetText("Professions (hover for details)")
	f.shopHeader:Hide()
	f.makeHeader:Hide()
	SP.SaveCharacter()
	local rows = {}
	for _, r in ipairs(self.steps) do rows[#rows + 1] = r end
	for _, r in ipairs(self.makes) do rows[#rows + 1] = r end
	for _, r in ipairs(self.items) do rows[#rows + 1] = r end
	local n = 0
	local function Add(icon, text, right, tip, pin)
		n = n + 1
		local row = rows[n]
		if not row then return end
		row.recipeID = nil
		row.pin = pin
		row.icon:SetTexture(icon)
		row.text:SetText(text)
		row.right:SetText(right or "")
		row.tip = tip
		row:Show()
	end
	local me = SP.MyKey()
	local list = {}
	for key, c in pairs(SP.db.chars or {}) do list[#list + 1] = { key = key, c = c } end
	table.sort(list, function(a, b)
		if (a.key == me) ~= (b.key == me) then return a.key == me end
		return (a.c.level or 0) > (b.c.level or 0)
	end)
	for _, e in ipairs(list) do
		local c = e.c
		Add(nil, "|c" .. CLASS_COLOR(c.class) .. (c.name or e.key) .. "|r", "level " .. (c.level or "?"))
		local names = {}
		for name in pairs(c.profs or {}) do names[#names + 1] = name end
		table.sort(names, function(a, b)
			local ca, cb = SP.CRAFTING[a] and 0 or 1, SP.CRAFTING[b] and 0 or 1
			if ca ~= cb then return ca < cb end
			return a < b
		end)
		if #names == 0 then Add(nil, "  |cff999999No professions|r") end
		for _, name in ipairs(names) do
			local p = c.profs[name]
			local skill, max = p.skill or 0, p.max or 0
			local nx = c.next and c.next[name]
			local tip = { name .. "  " .. skill .. " / " .. max }
			local right = ""
			-- rank first (it blocks everything), then Legacy, then next step
			local rs = SP.RankStatus(name, skill, max)
			if rs and rs.skillOK then
				right = "|cffff8040train " .. rs.rank .. "|r"
				tip[#tip + 1] = "Train " .. rs.rank .. " (cap " .. rs.cap .. "), needs character level " .. rs.level .. "."
			end
			local legacyAt = SP.NextLegacy({ name = name, skill = skill })
			if legacyAt then
				if right == "" then right = "|cffffd100Legacy " .. legacyAt .. "|r" end
				tip[#tip + 1] = "|cffffd100Legacy point at " .. legacyAt .. ": " .. (legacyAt - skill) .. " to go.|r"
			end
			local text = "  " .. name .. " |cffffffff" .. skill .. "/" .. max .. "|r"
			if nx and nx.recipe then
				text = text .. "  |cff999999" .. (nx.learn and "learn " or "next: ") .. nx.recipe .. "|r"
				tip[#tip + 1] = (nx.learn and "Next: learn " or "Next: ") .. nx.recipe .. " (" .. (nx.from or "?") .. "-" .. (nx.to or "?") .. ")."
				if nx.missing then tip[#tip + 1] = "Short of materials last time you looked." end
			elseif SP.Gathering[name] then
				local z = SP.GatherZone(name, skill)
				if z then
					text = text .. "  |cff999999" .. z.what .. "|r"
					tip[#tip + 1] = "Gather " .. z.what .. " in " .. SP.ZoneFor(z) .. "."
				end
			elseif SP.CRAFTING[name] then
				tip[#tip + 1] = "Open this profession on " .. (c.name or "that character") .. " to plan it."
			end
			Add(p.icon, text, right, tip)
		end
	end
	f.note:SetText("Characters appear here after you log in on them with this version. Open a profession on each to see its next step.")
	f.total:SetText("")
end
