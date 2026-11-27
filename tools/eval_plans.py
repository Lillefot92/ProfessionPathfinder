"""Which new plans help leveling (the trade camps' plans and EXTRA_CANDIDATES in
make_sources.py). Simulates 1-300 for every crafting profession with real reagents
(wago.tools SpellReagents.csv) priced at the game's vendor value (ItemSparse
BuyPrice, or SellPrice x 4), with trainers, vendors and all new plans learnable.
Then drops new plans one at a time and keeps only those whose loss makes the
route stop earlier or cost at least 1 gold more. Plans with the same colors and
materials but one (the same piece in another set) are kept too: which one is
cheapest depends on your server's prices.

  PP_ALL_PLANS=1 python3 tools/make_sources.py ...   (Sources.lua with every candidate)
  python3 tools/eval_plans.py SpellReagents.csv ItemSparse.csv > tools/data/leveling_plans.txt
  python3 tools/make_sources.py ...                  (only the plans that help)
"""
import csv, os, re, sys
from lupa import LuaRuntime
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REAGENTS_CSV, SPARSE_CSV = sys.argv[1:3]
THRESH = 10000  # copper: a plan must save at least 1 gold

reag = {}
for r in csv.DictReader(open(REAGENTS_CSV)):
    t = [(int(r[f"Reagent_{k}"] or 0), int(r[f"ReagentCount_{k}"] or 0)) for k in range(8)]
    t = [x for x in t if x[0] > 0 and x[1] > 0]
    if t: reag[int(r["SpellID"])] = t
price, item_name = {}, {}
for r in csv.DictReader(open(SPARSE_CSV, encoding="utf-8")):
    price[int(r["ID"])] = int(r["BuyPrice"] or 0) or int(r["SellPrice"] or 0) * 4
    item_name[int(r["ID"])] = r["Display_lang"]
src = open(os.path.join(REPO, "tools", "make_sources.py")).read()
cand_block = src.split("EXTRA_CANDIDATES = {", 1)[1].split("\n}", 1)[0]
candidates = {int(x) for x in re.findall(r"(\d{6}):", cand_block)}

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(open(os.path.join(REPO, "tests/sp_harness.lua")).read())
G = lua.globals()
G.REAG = lua.table_from({k: lua.table_from([lua.table_from(x) for x in v]) for k, v in reag.items()})
G.PRICE = lua.table_from({k: max(1, v) for k, v in price.items()})
G.CAND = lua.table_from({i: True for i in candidates})
lua.execute(r'''
function GetTime() return 0 end tinsert = table.insert; UISpecialFrames = {}
function UnitName() return "Tester" end function GetRealmName() return "Forever" end
AH = setmetatable({}, { __index = function(_, id) return PRICE[id] or 1000 end }); VENDOR = {}
FACTION = "Horde"; function UnitFactionGroup() return FACTION end
C_CurrencyInfo = { GetCurrencyInfo = function() return { name = "Favor", quantity = 99999 } end }
C_Reputation = { GetFactionDataByID = function() return { name = "F", reaction = 8 } end }
''')
loader = lua.eval("function(src, name, ns) local f = assert(load(src, '@'..name)); return f('ProfessionPathfinder', ns) end")
ns = lua.table()
for fn in ["Core.lua", "Sources.lua", "Where.lua", "Data.lua", "TrainerData.lua", "Trainer.lua", "Gathering.lua", "Learn.lua", "Planner.lua", "UI.lua", "Fishing.lua", "Diagnose.lua"]:
    loader(open(os.path.join(REPO, fn)).read(), fn, ns)
lua.execute(r'''
local SP = ProfessionPathfinder
local E = SP.eventFrame:GetScript("OnEvent")
E(SP.eventFrame, "ADDON_LOADED", "ProfessionPathfinder"); E(SP.eventFrame, "PLAYER_LOGIN")
SP.db.bagsFree = false
SP.OvertimeBonus = function() return 0 end
EXCLUDE = {}
function NewItem(id)
  for _, e in ipairs(SP.RECIPE_ITEMS[id] or {}) do
    if e[12] or CAND[e[1]] then return e[1] end
  end
end
function NewIds(line) local o = {} for id in pairs(SP.DATA[line]) do if NewItem(id) then o[#o + 1] = id end end table.sort(o) return o end
local DIFF = SP.DIFF
local function Diff(y, g, s)
  if s >= g then return DIFF.Trivial end
  if s >= (y + g) / 2 then return DIFF.Easy end
  if s >= y then return DIFF.Medium end
  return DIFF.Optimal
end
function Sim(line)
  local data = SP.DATA[line]
  local known = {}
  for id, d in pairs(data) do if d[3] == 1 then known[id] = true end end
  local skill, cost, used = 1, 0, {}
  for _, cap in ipairs({ 75, 150, 225, 300 }) do
    if skill < cap then
      local recipes, cands = {}, {}
      for id, d in pairs(data) do
        local y, g = d[1], d[2]
        local r = { id = id, name = tostring(id), yellow = y, gray = g, ups = 1, reagents = {} }
        for _, rg in ipairs(REAG[id] or { { 100000 + id, 1 } }) do r.reagents[#r.reagents + 1] = { itemID = rg[1], count = rg[2] } end
        if known[id] then r.diff = Diff(y, g, skill); recipes[#recipes + 1] = r
        elseif not EXCLUDE[id] and not (SP.COOLDOWN and (SP.COOLDOWN[id] or 0) > 300) then
          local t = SP.TRAINER[line] and SP.TRAINER[line][id]; local learn = t and t[1]
          if not learn then
            local at, how = SP.LearnAt(id, line)
            if how == "maybe" then learn = at end
            for _, src in ipairs(SP.RecipeSources(id)) do
              if not learn and src.kind == "vendor" then learn = src.skill or y end
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
        known[s.recipe.id] = true; cost = cost + (s.cost or 0)
        if s.recipe.unlearned and NewItem(s.recipe.id) then used[#used + 1] = s.recipe.id end
      end
      if plan.reached < cap then return plan.reached, cost, used end
      skill = plan.reached
    end
  end
  return skill, cost, used
end
''')
def sim(line):
    reached, cost, used = G.Sim(line)
    return reached, cost, set(used.values())
def same(line, i, j):
    # the same piece in another set: same colors, one material swapped (Purple
    # Lotus for Black Pearl, say), so which is cheapest depends on your server
    a, b = G.ProfessionPathfinder.DATA[line][i], G.ProfessionPathfinder.DATA[line][j]
    if (a[1], a[2]) != (b[1], b[2]): return False
    ra, rb = set(reag.get(i, [])), set(reag.get(j, []))
    return len(ra) == len(rb) and len(ra - rb) <= 1
keep_items, notes = set(), []
for faction in ["Horde", "Alliance"]:
    G.FACTION = faction
    for line in [164, 165, 171, 185, 197, 202, 333]:
        G.EXCLUDE = lua.table()
        new = list(G.NewIds(line).values())
        full = sim(line)
        for i in new:
            if i not in full[2]: G.EXCLUDE[i] = True
        best = sim(line)
        for i in sorted(full[2], reverse=True):
            G.EXCLUDE[i] = True
            r = sim(line)
            if r[0] >= best[0] and r[1] - best[1] < THRESH: best = r
            else:
                G.EXCLUDE[i] = None
                why = "needed to reach %d" % best[0] if r[0] < best[0] else "saves about %dg" % ((r[1] - best[1]) / 10000)
                kept = {i} | {j for j in new if j != i and same(line, i, j)}
                for j in kept:
                    it = G.NewItem(j)
                    if it not in keep_items:
                        keep_items.add(it)
                        notes.append((it, "%s (%s, %s)" % (item_name.get(it, it), faction, why if j == i else "same as " + item_name.get(G.NewItem(i), "?"))))
print("# Plans (item IDs) from tools/data/merchants_favor.txt and EXTRA_CANDIDATES that")
print("# help leveling: chosen by tools/eval_plans.py. Only these are added.")
for it, note in sorted(notes):
    print("%d  # %s" % (it, note))
