import os
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(r'''
BINDS = {}
function ClearOverrideBindings(o) BINDS = {} end
function SetOverrideBinding(o, p, key, cmd) BINDS[key] = cmd end
function SetOverrideBindingClick(o, p, key, btn) BINDS[key] = "CLICK " .. btn end
COMBAT = false
function InCombatLockdown() return COMBAT end
POLE = false
function GetInventoryItemID(u, s) if s == 16 then return POLE and 6256 or 1234 end end
C_Item.GetItemInfoInstant = function(id) if id == 6256 then return id, "INV", "x", "x", 1, 2, 20 end return id, "INV", "x", "x", 1, 2, 7 end
LUREON = false
function GetWeaponEnchantInfo() return LUREON end
CV = { Sound_SFXVolume = "0.4", Sound_MusicVolume = "0.6", Sound_AmbienceVolume = "0.5", Sound_EnableAllSound = "1", Sound_EnableSFX = "1", Sound_EnableSoundWhenGameIsInBG = "0", SoftTargetInteract = "1", SoftTargetInteractRange = "10" }
C_CVar = { GetCVar = function(k) return CV[k] end, SetCVar = function(k, v) CV[k] = v end }
function GetBindingText(k) return k end
C_Spell = C_Spell or {}
C_Spell.GetSpellName = function(id) if id == 7620 or id == 7731 then return "Fishing" end end
OWNED[6532] = 3; OWNED[6530] = 5
NOW = 1000; function GetTime() return NOW end
SKILL, BONUS, MAX = 140, 0, 150
function GetProfessions() return 1, 2, nil, 4, 5 end
COOK = 112
function GetProfessionInfo(i) if i == 5 and COOK then return "Cooking", "i", COOK, 150, 0, 0, 185, 0 end if i == 4 then return "Fishing", "icon", SKILL, MAX, 0, 0, 356, BONUS end if i == 1 then return "Blacksmithing", "i", 100, 150, 0, 0, 164, 0 end end
ZONE = "Westfall"; function GetRealZoneText() return ZONE end
LOOT = {}
function IsFishingLoot() return true end
function GetNumLootItems() return #LOOT end
function GetLootSlotLink(i) return "|Hitem:" .. LOOT[i][1] .. ":|h" end
function GetLootSlotInfo(i) return "tex", "name", LOOT[i][2] end
SELL = { [6308] = 4, [4603] = 6, [6358] = 4, [6359] = 5 }  -- catfish, yellowtail, oily blackmouth, firefin
ITEMS[6308] = "Raw Bristle Whisker Catfish"; ITEMS[6358] = "Oily Blackmouth"; ITEMS[6359] = "Firefin Snapper"
C_Item.GetItemInfo = function(id) return ITEMS[id], nil, 1, 1, 1, "t", "s", 20, "", "i", SELL[id] or 0 end
Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(c, id) return ({ [6358] = 150, [6359] = 90 })[id] end } } }
ERR_FISH_ESCAPED = "Your fish got away!"
LUREMS = nil
function GetWeaponEnchantInfo() if LUREMS then return true, LUREMS end return false end
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Gathering.lua", "Planner.lua", "UI.lua", "Fishing.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute(r'''
local SP = ProfessionPathfinder
SP.eventFrame:GetScript("OnEvent")(SP.eventFrame, "PLAYER_LOGIN")
local Fish = SP.Fishing
local E = Fish.eventFrame:GetScript("OnEvent")
E(Fish.eventFrame, "PLAYER_LOGIN"); RunTimers()
OWNED[6308] = 20
POLE = true; Fish.Update()
local st = _G.ProfessionPathfinderFishStatus
local function strip(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function show(label) Fish.UpdateStatus(); print("== " .. label); for l in strip(st.info._text):gmatch("[^\n]+") do print("  " .. l) end end
SP.SaveCharacter(); local ch = SP.db.chars[SP.MyKey()]
-- what the last Cooking plan used (saved when the Cooking window was open)
ch.needs = { Cooking = { [6308] = 60, [8365] = 45, [4603] = 90 } }
ch.needsFor = { Cooking = { [6308] = { recipe = "Bristle Whisker Catfish", from = 112, to = 175 },
  [8365] = { recipe = "Mithril Head Trout", from = 175, to = 225 }, [4603] = { recipe = "Spotted Yellowtail", from = 225, to = 300 } } }
show("cooking 112, 20 catfish, in Westfall")
ZONE = "Wetlands"; show("in Wetlands")
OWNED[6308] = 100; show("100 catfish")
COOK = 200; show("cooking 200")
COOK = 280; ZONE = "Tanaris"; show("cooking 280 in Tanaris")
COOK = nil; show("no cooking")
COOK = 112; OWNED[6308] = 20
local needs = Fish.CookingNeeds()
for _, e in ipairs(needs) do print(string.format("  need %-28s %3d/%3d  (cooking %d-%d)", e.name, e.have, e.need, e.from, e.to)) end
Fish.SaveCookingNeeds()
local c = SP.db.chars[SP.MyKey()]
local t = {}; for id, n in pairs(c.needs["Cooking fish"] or {}) do t[#t+1] = id .. "=" .. n end; table.sort(t); print("saved:", table.concat(t, " "))
local tt = {}; GameTooltip = setmetatable({}, { __index = function(t, k)
  if k == "AddLine" or k == "SetText" then return function(_, s) tt[#tt+1] = strip(s) end end
  if k == "AddDoubleLine" then return function(_, a, b) tt[#tt+1] = strip(a) .. "  ....  " .. strip(b) end end
  return function() end end })
Fish.ShowTooltip(st); print("== tooltip"); for _, l in ipairs(tt) do print("  " .. l) end
SP.db.chars[SP.MyKey()].profs = { Cooking = { skill = 125, max = 150 } }
SP.db.said = {}; UnitLevel = function() return 30 end
SP.CheckReminders({ name = "Cooking", skill = 125, max = 150 })
SP.CheckReminders({ name = "Fishing", skill = 225, max = 225 })
SP.CheckReminders({ name = "Cooking", skill = 210, max = 225 })
''')
