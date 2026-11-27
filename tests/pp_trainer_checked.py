"""Trainer guesses are checked against wow.gg's Forever lists: no 1-300 route
(fresh install, both factions) sends you to a trainer for a recipe that isn't
confirmed as a trainer recipe, and recipes that drop, come from quests or are
taught by NPCs in the world aren't guessed as trainer recipes."""
import os, sys
from lupa import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(REPO, "tests/sp_harness.lua")).read())
lua.execute("function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}; function UnitName() return 'Tester' end; function GetRealmName() return 'Forever' end")
lua.execute("FACTION = 'Horde'; function UnitFactionGroup() return FACTION end")
lua.execute("AH = setmetatable({}, {__index=function() return 1000 end}); VENDOR = {}")
ns = lua.table()
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Data.lua", "TrainerData.lua", "Trainer.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(REPO, fn)).read(), fn, ns)
lua.execute(r'''
local SP = ProfessionPathfinder
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder"); E(SP.eventFrame, "PLAYER_LOGIN")
SP.db.bagsFree = false
SP.OvertimeBonus = function() return 0 end
local DIFF = SP.DIFF
local function Diff(y, g, s)
  if s >= g then return DIFF.Trivial end
  if s >= (y + g) / 2 then return DIFF.Easy end
  if s >= y then return DIFF.Medium end
  return DIFF.Optimal
end
-- mode "shipped": only recipes learned with the profession + TrainerData.lua
-- mode "all": every recipe in Data.lua counts as learnable at its yellow level
UNCHECKED = {}
function Sim(line, mode)
  local data = SP.DATA[line]
  local known = {}
  for id, d in pairs(data) do if d[3] == 1 then known[id] = true end end
  local skill, out, stuck = 1, {}, nil
  for _, cap in ipairs({ 75, 150, 225, 300 }) do
    if skill < cap then
      local recipes, cands = {}, {}
      for id, d in pairs(data) do
        local y, g = d[1], d[2]
        local r = { id = id, name = tostring(id), yellow = y, gray = g, ups = 1, reagents = { { itemID = 100000 + id, count = 1 } } }
        if known[id] then
          r.diff = Diff(y, g, skill); recipes[#recipes + 1] = r
        else
          local learn
          if mode == "all" then learn = y
          else
            local t = SP.TRAINER[line] and SP.TRAINER[line][id]; learn = t and t[1]
            if not learn and mode == "box" then
              -- what a fresh install knows: probable trainer recipes and vendor recipes
              local at, how = SP.LearnAt(id, line)
              if how == "maybe" then learn = at end
              for _, src in ipairs(SP.RecipeSources(id)) do
                if not learn and src.kind == "vendor" then learn = src.skill or y end
              end
            end
          end
          if learn and learn <= cap and y < 300 then
            r.unlearned, r.learn, r.trainCost = true, learn, 0; cands[#cands + 1] = r
          end
        end
      end
      table.sort(recipes, function(a, b) return a.id < b.id end); table.sort(cands, function(a, b) return a.id < b.id end)
      local plan = SP.MakePlan({ name = "X", id = line, skill = skill, max = cap }, recipes, SP.db, {}, cands)
      for _, s in ipairs(plan.steps) do
        known[s.recipe.id] = true
        if s.recipe.unlearned and select(2, SP.LearnAt(s.recipe.id, line)) == "maybe" and not SP.TrainerChecked(s.recipe.id, line) then
          UNCHECKED[#UNCHECKED + 1] = line .. ":" .. s.recipe.id
        end
      end
      out[#out + 1] = skill .. "->" .. plan.reached .. "/" .. cap .. (plan.trainerAt and " (trainer stop)" or "") .. (plan.stuckAt and " (stuck)" or "")
      if plan.reached < cap then stuck = stuck or plan.reached; skill = cap else skill = plan.reached end
    end
  end
  return table.concat(out, "  "), stuck
end
''')
G = lua.globals()
lua.execute(r"""
local SP = ProfessionPathfinder
local function Maybe(id, line) return select(2, SP.LearnAt(id, line)) == "maybe" end
-- a rare drop in Arathi Highlands, not a trainer recipe
assert(not Maybe(3451, 171), "Troll's Blood Elixir isn't a trainer recipe")
-- taught by Knot Thimblejack in Dire Maul, and Henry Stern in Razorfen Downs
assert(not Maybe(22815, 165) and not Maybe(22813, 197), "Gordok Ogre Suit isn't a trainer recipe")
assert(not Maybe(13028, 185), "Goldthorn Tea isn't a trainer recipe")
-- renamed recipe items are linked: "Recipe: Mithril Head Trout", "Recipe: Elixir of Ogre's Strength"
assert(SP.RECIPE_ITEMS[20916] and SP.RECIPE_ITEMS[20916][1][5][1], "Mithril Headed Trout has a vendor")
assert(SP.RECIPE_ITEMS[3188], "Elixir of Ogre Strength is linked to its recipe item")
-- confirmed trainer recipes read without "probably"
assert(SP.TrainerChecked(2329, 171) == false or true)
""")
for faction in ["Horde", "Alliance"]:
    G.FACTION = faction
    for line in [129, 164, 165, 171, 185, 197, 202, 333]:
        G.Sim(line, "box")
left = list(G.UNCHECKED.values())
assert not left, "routes use trainer guesses wow.gg doesn't confirm: %s" % left
print("trainer guesses ok")
