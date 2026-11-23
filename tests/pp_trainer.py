import os
import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__))
ADDON_DIR = _os.path.dirname(HERE)
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open("sp_harness.lua").read())
lua.execute(open("sp_route.lua").read().replace("local BOOK", "BOOK"))
lua.execute("function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}")
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Data.lua", "Trainer.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(ADDON_DIR, fn)).read(), fn, ns)
lua.execute('''
local SP = ProfessionPathfinder
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder"); E(SP.eventFrame, "PLAYER_LOGIN")
SetProf("Blacksmithing")
local orig = C_TradeSkillUI.GetAllRecipeIDs
C_TradeSkillUI.GetAllRecipeIDs = function() local t = orig(); t[#t+1] = 9928; t[#t+1] = 7223; return t end
local gi = C_TradeSkillUI.GetRecipeInfo
C_TradeSkillUI.GetRecipeInfo = function(id)
  if id == 9928 then return { name = "Heavy Mithril Gauntlet", learned = false, maxTrivialLevel = 218, recipeID = id } end
  if id == 7223 then return { name = "Golden Scale Bracers", learned = false, maxTrivialLevel = 210, recipeID = id } end
  return gi(id) end
-- a trainer window
local SERV = { { "Heavy Mithril Gauntlet", "Blacksmithing", 200 }, { "Golden Scale Bracers", "Blacksmithing", 180 }, { "Journeyman Blacksmithing", nil, nil } }
function GetNumTrainerServices() return FILTER.unavailable and #SERV or 0 end
function GetTrainerServiceInfo(i) return SERV[i][1], "", "unavailable" end
function GetTrainerServiceSkillReq(i) return SERV[i][2], SERV[i][3], false end
function GetTrainerServiceCost(i) return 500 * i end
FILTER = { available = true, unavailable = false, used = false }
function GetTrainerServiceTypeFilter(k) return FILTER[k] end
function SetTrainerServiceTypeFilter(k, v) if type(v) ~= "boolean" then error("Usage: SetTrainerServiceTypeFilter(type, status)") end FILTER[k] = v end
print("trainer services read:", SP.Trainer.Read())
print("matched:", SP.Trainer.Match("Blacksmithing")); print("cost HMG:", SP.db.teachCost and SP.db.teachCost[9928])
SlashCmdList.PROFESSIONPATHFINDER("scan")
local txt = SP.reportFrame.edit._text
print((txt:match("Built%-in data.-\\n\\n") or txt:sub(1, 900)))
''')
lua.execute('''
function IsTradeskillTrainer() return true end
function GetTrainerServiceLevelReq() return 0 end
SlashCmdList.PROFESSIONPATHFINDER("trainer")
RunTimers()
print(ProfessionPathfinder.reportFrame.edit._text)
''')
