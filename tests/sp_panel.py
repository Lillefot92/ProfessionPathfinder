import os
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute(open(os.path.join(HERE, "sp_route.lua")).read())
lua.execute('''
FRAMES = {}
local orig = CreateFrame
CreateFrame = function(kind, name, parent, tmpl) local f = orig(kind, name); f._kind = kind; FRAMES[#FRAMES+1] = f; return f end
REG = {}
Settings = {
  RegisterCanvasLayoutCategory = function(frame, name) local c = { frame = frame, name = name, GetID = function() return 7 end }; REG.cat = c; return c end,
  RegisterAddOnCategory = function(c) REG.added = c end,
  OpenToCategory = function(id) REG.opened = id; SettingsPanel._shown = true end,
}
SettingsPanel = CreateFrame("Frame"); SettingsPanel._shown = false
wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end end
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Gathering.lua", "Planner.lua", "UI.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute('''
local SP = ProfessionPathfinder
local onEvent = SP.eventFrame:GetScript("OnEvent")
onEvent(SP.eventFrame, "PLAYER_LOGIN")
SetProf("Blacksmithing"); onEvent(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers(); RunTimers()
print("registered", REG.cat.name, REG.added ~= nil)
SlashCmdList.PROFESSIONPATHFINDER("options"); print("opened", REG.opened)
local panel = REG.cat.frame; panel:GetScript("OnShow")(panel)
local function find(text) for _, f in ipairs(FRAMES) do if f._text == text and f:GetScript("OnClick") then return f end end end
local db = ProfessionPathfinderDB
local n = 0
for _, f in ipairs(FRAMES) do if f._text == ">" then n = n + 1; f:GetScript("OnClick")(f) end end
print("arrows", n, "scale", db.scale, "useGuide", db.useGuide, "target", db.target)
RunTimers(); print("plan guide after toggle:", SP.lastPlan and SP.lastPlan.guide ~= nil, "to", SP.lastPlan.to)
for _, f in ipairs(FRAMES) do if f._kind == "CheckButton" then f.GetChecked = function() return false end; f:GetScript("OnClick")(f) end end
print("shown", db.shown, "bagsFree", db.bagsFree, "frame shown", SP.UI.frame:IsShown())
find("Auctionator list"):GetScript("OnClick")()
find("Reset all settings"):GetScript("OnClick")(); RunTimers()
print("after reset", db.scale, db.useGuide, db.target, db.shown, db.bagsFree)
SP.UI.frame.gear:GetScript("OnClick")(); print("gear opens", REG.opened)
SlashCmdList.PROFESSIONPATHFINDER("help")
''')
