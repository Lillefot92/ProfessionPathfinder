import os
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(HERE, "sp_harness.lua")).read())
lua.execute('''
C_TradeSkillUI.CraftRecipe = function(id, n) CRAFTED = { id, n } end
C_TradeSkillUI.IsRecipeRepeating = function() return REPEAT or false end
C_TradeSkillUI.StopRecipeRepeat = function() STOPPED = true end
C_TradeSkillUI.GetRecipeRequirements = function(id) return { { name = 'Anvil', met = not FAR } } end
''')
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute(r'''
local SP = ProfessionPathfinder
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "PLAYER_LOGIN")
local function strip(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function show(label)
  SP.RequestRefresh(); RunTimers()
  local f = SP.UI.frame
  local b = f.craftButton
  print(string.format("%-34s button=[%s] enabled=%s | legacy=[%s]", label, strip(b._text), tostring(b._enabled ~= false), strip(f.legacy._text)))
  local tp = rawget(b, "tip"); if tp then print("     tip: " .. strip(table.concat(tp, " / "))) end
end
E(SP.eventFrame, "TRADE_SKILL_SHOW"); RunTimers()
SP.db.useGuide = false
OWNED = {}
show("cheapest, no mats")
OWNED = { [2589] = 40 }
show("linen cloth only")
OWNED = { [2589] = 10, [2996] = 30, [2320] = 30 }
FAR = true; show("bolts + thread, no anvil"); FAR = false
show("bolts + thread")
local b = SP.UI.frame.craftButton
b:GetScript("OnClick")(b, "LeftButton"); print("crafted:", CRAFTED[1], CRAFTED[2], "opened", OPENED)
b:GetScript("OnClick")(b, "RightButton"); print("crafted:", CRAFTED[1], CRAFTED[2])
REPEAT = true; show("while crafting")
b:GetScript("OnClick")(b, "LeftButton"); print("stopped:", STOPPED); REPEAT = false
SP.db.useGuide = true
show("Wowhead route (recipes not learned)")
SKILL = 75; show("at cap 75")
SKILL = 40
-- Legacy: Tailoring 146/150
local real = C_TradeSkillUI.GetChildProfessionInfo
C_TradeSkillUI.GetChildProfessionInfo = function() return { professionName = "Tailoring", skillLevel = SKILL, maxSkillLevel = 150 } end
SKILL = 146; SP.db.useGuide = false; show("Tailoring 146/150")
show("again (no second chat line)")
SKILL = 150; show("Tailoring 150 reached")
SKILL = 120; show("other char at 120 (150 done)")
C_TradeSkillUI.GetChildProfessionInfo = function() return { professionName = "Tailoring", skillLevel = SKILL, maxSkillLevel = 75 } end
SKILL = 60; show("Tailoring 60/75 (cap below 150)")
for k in pairs(SP.UI.steps) do local r = SP.UI.steps[k]; if r._shown then print("  step", strip(r.text._text), strip(r.right._text)) end end
E(SP.eventFrame, "TRADE_SKILL_CLOSE")
SlashCmdList.PROFESSIONPATHFINDER(""); RunTimers()
print("gathering view: craft shown", SP.UI.frame.craftButton._shown)
''')
