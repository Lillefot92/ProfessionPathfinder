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
OWNED[6532] = 3
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Gathering.lua", "Planner.lua", "UI.lua", "Fishing.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute(r'''
local SP = ProfessionPathfinder
local function fire(ev, ...) for _, f in ipairs(ALLFRAMES or {}) do end end
local core = SP.eventFrame:GetScript("OnEvent")
core(SP.eventFrame, "PLAYER_LOGIN")
-- find Fishing's event frame: it's the last frame with an OnEvent that handles PLAYER_LOGIN; use the module directly
local Fish = SP.Fishing
local function state(label)
  local b = {}; for k, v in pairs(BINDS) do b[#b+1] = k .. "=" .. v end; table.sort(b)
  print(string.format("%-28s active=%s line=%s binds={%s} sfx=%s music=%s interact=%s status=[%s]", label, tostring(Fish.active), tostring(Fish.lineOut),
    table.concat(b, ", "), CV.Sound_SFXVolume, CV.Sound_MusicVolume, CV.SoftTargetInteract, (tostring(_G.ProfessionPathfinderFishStatus.text._text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))))
end
print("defaults:", SP.db.fishMode, SP.db.fishKey, SP.db.fishSound, SP.db.fishLure)
Fish.Update(); state("no pole")
POLE = true; Fish.Update(); state("pole on")
print("cast spell attr:", _G.ProfessionPathfinderFishCast:GetAttribute("spell"), "lure macro:", _G.ProfessionPathfinderFishLure:GetAttribute("macrotext"))
-- simulate channel start/stop through the module's event frame
local evf = _G.ProfessionPathfinderFishOwner
''')
lua.execute(r'''
local SP = ProfessionPathfinder
local Fish = SP.Fishing
local E = Fish.eventFrame:GetScript("OnEvent")
local function state(label)
  local b = {}; for k, v in pairs(BINDS) do b[#b+1] = k .. "=" .. v end; table.sort(b)
  print(string.format("%-28s active=%s line=%s binds={%s} sfx=%s music=%s interact=%s", label, tostring(Fish.active), tostring(Fish.lineOut),
    table.concat(b, ", "), CV.Sound_SFXVolume, CV.Sound_MusicVolume, CV.SoftTargetInteract))
end
E(Fish.eventFrame, "UNIT_SPELLCAST_CHANNEL_START", "player", "g", 7620); state("line out")
E(Fish.eventFrame, "UNIT_SPELLCAST_CHANNEL_STOP", "player", "g", 7620); RunTimers(); state("caught")
LUREON = true; E(Fish.eventFrame, "BAG_UPDATE_DELAYED"); state("lure on")
E(Fish.eventFrame, "PLAYER_REGEN_DISABLED"); COMBAT = true; state("combat")
COMBAT = false; E(Fish.eventFrame, "PLAYER_REGEN_ENABLED"); state("after combat")
POLE = false; E(Fish.eventFrame, "PLAYER_EQUIPMENT_CHANGED"); state("pole off")
POLE = true; E(Fish.eventFrame, "PLAYER_EQUIPMENT_CHANGED"); state("pole on again")
E(Fish.eventFrame, "PLAYER_LOGOUT"); state("logout (sound restored)")
print("saved after logout:", SP.db.fishSaved, SP.db.fishInteractSaved)
SlashCmdList.PROFESSIONPATHFINDER("fish"); state("/sup fish (off)")
''')
