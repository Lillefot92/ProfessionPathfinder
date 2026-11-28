"""Build Sources.lua: trainers, rank books/quests and recipe sources for
Profession Pathfinder, from QuestieDB's WoW Forever database (GPL-3.0,
https://github.com/Questie/QuestieDB) and the game's own names.

usage: make_sources.py <QuestieDB checkout> <Data.lua> <names> <out Sources.lua> [ItemSparse.csv]

<names> is a SavedVariables file with ProfessionPathfinderDB.export, written
in game by /ppf export (spell names of every recipe in Data.lua, and the skill
each recipe item needs). It links recipe items to recipe spells by name.

ItemSparse.csv (the game's item table, from wago.tools for the same build)
tells which recipe items need a specialization (RequiredAbility)."""
import os, re, sys
from lupa import LuaRuntime

QDB, DATA_LUA, NAMES, OUT = sys.argv[1:5]
ITEMSPARSE = sys.argv[5] if len(sys.argv) > 5 else None
L = LuaRuntime(unpack_returned_tuples=True)

def lua_items(t):
    return [] if t is None else list(t.items())

def load_db(kind):
    src = open(os.path.join(QDB, "data", "Forever", "forever%sDB.lua" % kind), encoding="utf-8").read()
    m = re.search(r"\.\w+Data = \[(=*)\[(.*?)\]\1\]", src, re.S)
    t = L.execute(m.group(2))
    return {int(k): {int(i): x for i, x in v.items()} for k, v in t.items()}

def tolist(x):
    if x is None: return []
    if isinstance(x, (int, float, str)): return [x]
    return [x[i] for i in sorted(x.keys())]

npc, item, quest = load_db("Npc"), load_db("Item"), load_db("Quest")

# area ID -> (uiMapID, English zone name)
amap = {}
src = open(os.path.join(QDB, "support", "Forever", "Zones", "areaIdToUiMapId.lua"), encoding="utf-8").read()
main = src.split("ZoneDB.private.areaIdToUiMapId = ", 1)[1]
for a, m, name in re.findall(r"\[(\d+)\] = (\d+), -- (.*)", main):
    amap[int(a)] = (int(m), name.split(" -> ")[-1].strip())

# Data.lua: every recipe spell per skill line
L.execute("SP = {}")
L.execute(open(DATA_LUA, encoding="utf-8").read().replace("local ADDON, SP = ...", ""))
DATA = {int(line): {int(s): [d[1], d[2]] for s, d in rec.items()} for line, rec in L.globals().SP.DATA.items()}

PROF = {"Alchemist": "Alchemy", "Blacksmith": "Blacksmithing", "Enchanter": "Enchanting", "Engineer": "Engineering",
        "Leatherworker": "Leatherworking", "Tailor": "Tailoring"}
CAP = {"Journeyman": 150, "Expert": 225, "Artisan": 300, "Master": 300}
GATHER = {"Herbalism Trainer": "Herbalism", "Herbalist": "Herbalism", "Superior Herbalist": "Herbalism", "Apprentice Herbalist": "Herbalism",
          "Mining Trainer": "Mining", "Miner": "Mining", "Skinning Trainer": "Skinning", "Skinner": "Skinning"}
SECONDARY = {"First Aid Trainer": "First Aid", "Physician": "First Aid", "Cooking Trainer": "Cooking", "Cook": "Cooking",
             "Superior Cook": "Cooking", "Fishing Trainer": "Fishing", "Fisherman": "Fishing", "Superior Fisherman": "Fishing",
             "Fishing Trainer & Supplies": "Fishing"}

def where(nid):
    r = npc[nid]
    zone = r.get(9)
    spawns = r.get(7)
    pts = None
    if spawns is not None:
        for z, p in spawns.items():
            if zone is None or int(z) == zone or pts is None:
                plist = tolist(p)
                if plist and plist[0][1] >= 0:
                    pts = (int(z), round(plist[0][1], 1), round(plist[0][2], 1))
                if zone is not None and int(z) == zone: break
    if pts is None: return None
    area = pts[0]
    m = amap.get(area)
    if not m: return None
    return area, m[0], pts[1], pts[2], m[1]

# Vendors that only sell to players with reputation, or only during a
# holiday: their recipes are shown but not planned
REP_VENDORS = {"Meilosh", "Aendel Windspear", "Vargus", "Mishta", "Rin'wosho the Trader", "Magnus Frostwake",
               "Argent Quartermaster Hasana", "Argent Quartermaster Lightspark", "Quartermaster Miranda Breechlock",
               "Lokhtos Darkbargainer"}
EVENT_TITLES = {"Smokywood Pastures"}
# Why a restricted vendor is restricted, when it isn't reputation
VENDOR_NOTES = {"Magnus Frostwake": "only visible while you wear the Spectral Essence from the Scholomance quest chain"}

# WoW Forever's own new plans that QuestieDB doesn't have yet: [plan item] = vendors.
# Skill, price, binding and reputation come from the game's item table.
# Checked Nov 27 2026 (Wowhead Forever, wow-professions.com).
EXTRA_PLANS = {
    251468: [900001],                     # Plans: Bold Dirk - Pexmit, Mount Hyjal
    275598: [15176], 275599: [15176], 275600: [15176],   # Goregasher Grips/Support/Stompers - Vargus
    275601: [15176], 275602: [15176], 275603: [15176],   # Clutchlord's Grips/Support/Stompers - Vargus
}
# Plans that are only added when they help leveling (tools/data/leveling_plans.txt,
# made by tools/eval_plans.py): item = vendors
EXTRA_CANDIDATES = {
    252783: [3005, 4225], 252784: [3005, 4225],   # Mystic/Forceful Medium Armor Kit - Mahu, Saenorion
    252811: [3005, 4225], 252812: [3005, 4225],   # Mystic/Forceful Heavy Armor Kit - Mahu, Saenorion
    254124: [900001],                             # Pattern: Runecloth Cuffs - Pexmit, Mount Hyjal
    275580: [15179], 275581: [15179], 275582: [15179],   # Venomspew Gloves/Cord/Footpads - Mishta, Cenarion Hold
    275583: [15179], 275584: [15179], 275585: [15179],   # Swarmtender's Gloves/Cord/Footpads - Mishta
}
# PP_ALL_PLANS=1: every candidate and trade camp plan (to test which ones help)
ALL_PLANS = os.environ.get("PP_ALL_PLANS") == "1"
_here = os.path.dirname(os.path.abspath(__file__))
LEVELING = set()
for _l in open(os.path.join(_here, "data", "leveling_plans.txt"), encoding="utf-8"):
    _l = _l.split("#", 1)[0].strip()
    if _l: LEVELING.add(int(_l))
def Wanted(item): return ALL_PLANS or item in LEVELING

# NPCs QuestieDB doesn't have yet: id = { name, title, friendly to, area, map, x, y, zone }
# (no x, y: they move between a few spots)
EXTRA_NPCS = {
    900001: ("Pexmit", "", "AH", 0, 2482, None, None, "Dae'gun, Mount Hyjal"),
    # The trade camps (Merchant's Favor): Durotar Supply and Logistics west of the
    # Crossroads, Azeroth Commerce Authority at Three Corners in Redridge
    900010: ("Apothecary Durelle", "Durotar Supply and Logistics", "H", 17, 1413, 49.8, 29.4, "The Barrens"),
    900011: ("Gor'mak", "Durotar Supply and Logistics", "H", 17, 1413, 49.8, 29.6, "The Barrens"),
    900012: ("Aza'bek", "Durotar Supply and Logistics", "H", 17, 1413, 49.6, 29.2, "The Barrens"),
    900013: ("Beneris", "Durotar Supply and Logistics", "H", 17, 1413, 49.6, 29.8, "The Barrens"),
    900014: ("Fizzlefuse", "Durotar Supply and Logistics", "H", 17, 1413, 49.8, 29.6, "The Barrens"),
    900015: ("Pawani", "Durotar Supply and Logistics", "H", 17, 1413, 49.6, 29.6, "The Barrens"),
    900016: ("Jim'bek", "Durotar Supply and Logistics", "H", 17, 1413, 49.6, 29.4, "The Barrens"),
    900020: ("Nina Surefire", "Azeroth Commerce Authority", "A", 44, 1433, 10.5, 72.7, "Redridge Mountains"),
    900021: ("Stondry Darkhammer", "Azeroth Commerce Authority", "A", 44, 1433, 10.5, 72.7, "Redridge Mountains"),
    900022: ("Kalsey Sanden", "Azeroth Commerce Authority", "A", 44, 1433, 10.5, 72.7, "Redridge Mountains"),
    900023: ("Alynsia", "Azeroth Commerce Authority", "A", 44, 1433, 10.5, 72.7, "Redridge Mountains"),
    900024: ("Fritz Fizzle", "Azeroth Commerce Authority", "A", 44, 1433, 10.5, 72.7, "Redridge Mountains"),
    900025: ("Daniel Stitchsong", "Azeroth Commerce Authority", "A", 44, 1433, 10.5, 72.7, "Redridge Mountains"),
    900026: ("Mivin Shadowweave", "Azeroth Commerce Authority", "A", 44, 1433, 10.5, 72.7, "Redridge Mountains"),
}
CAMP_VENDORS = {"Alchemy": (900010, 900020), "Blacksmithing": (900011, 900021), "Cooking": (900012, 900022),
                "Enchanting": (900013, 900023), "Engineering": (900014, 900024), "Leatherworking": (900015, 900025),
                "Tailoring": (900016, 900026)}
CAMP_LINE = {"Alchemy": 171, "Blacksmithing": 164, "Cooking": 185, "Enchanting": 333, "Engineering": 202,
             "Leatherworking": 165, "Tailoring": 197}
MERCHANTS_FAVOR = 3402          # the currency
TRADE_FACTION = -1              # your faction's trade company (2587 Horde, 2586 Alliance)
STANDING = {"": None, "Friendly": 4, "Honored": 5, "Revered": 6, "Exalted": 7}
def flag(nid):
    r = npc[nid]
    if r.get(1) in REP_VENDORS: return "rep"
    if r.get(14) in EVENT_TITLES: return "event"
    return None

used = {}
def ref(nid):
    if nid in EXTRA_NPCS:
        used[nid] = EXTRA_NPCS[nid]
        return nid
    w = where(nid)
    if not w: return None
    r = npc[nid]
    used[nid] = (r.get(1), r.get(14), r.get(13) or "", ) + w
    return nid

trainers = {}
for nid, r in npc.items():
    sub = r.get(14)
    if not sub or not ((r.get(15) or 0) & 16) or (r.get(13) or "") == "": continue
    prof, cap = None, None
    m = re.fullmatch(r"(Journeyman|Expert|Artisan|Master) (\w+?)( Trainer)?", sub)
    if m and m.group(2) in PROF:
        prof, cap = PROF[m.group(2)], CAP[m.group(1)]
    elif sub == "Expert Leathercrafter":
        prof, cap = "Leatherworking", 225
    elif sub == "Master Leatherworking Trainer":
        prof, cap = "Leatherworking", 300
    elif sub in GATHER:
        prof, cap = GATHER[sub], 300
    elif sub in SECONDARY:
        prof, cap = SECONDARY[sub], 150
    elif sub == "Trauma Surgeon":
        prof, cap = "First Aid", 300  # after the Triage quest
    if prof and ref(nid):
        trainers.setdefault(prof, []).append((nid, cap))

def item_id(name):
    for k, r in item.items():
        if r.get(1) == name: return k
def vendors_of(iid):
    return [v for v in tolist(item[iid].get(14)) if v in npc and ref(v)]
def quest_starts(qid):
    return [s for s in tolist(quest[qid].get(2)[1]) if s in npc and ref(s)] if quest[qid].get(2) else []

special = {
    "First Aid": {"Expert": ("book", item_id("Expert First Aid - Under Wraps")), "Artisan": ("quest", [6622, 6624])},
    "Cooking": {"Expert": ("book", item_id("Expert Cookbook")), "Artisan": ("quest", [6610])},
    "Fishing": {"Expert": ("book", item_id("Expert Fishing - The Bass and You")), "Artisan": ("quest", [6607])},
}

# ---------------------------------------------------------------- recipe items
# Recipe items (class 9) per profession (subclass), linked to recipe spells by name
SUB_LINE = {1: 165, 2: 197, 3: 202, 4: 164, 5: 185, 6: 171, 7: 129, 8: 333}
L.execute(open(NAMES, encoding="utf-8").read())
ex = L.globals().ProfessionPathfinderDB.export
spell_name = {int(k): v for k, v in ex["spells"].items()}
item_info = {int(k): v for k, v in ex["items"].items()} if ex["items"] else {}

def norm(s):
    s = s.lower()
    s = re.sub(r"[:\-,'\"()]", " ", s)
    return " ".join(s.split())
by_name = {}
for line, rec in DATA.items():
    for sid in rec:
        n = spell_name.get(sid)
        if n: by_name.setdefault((line, norm(n)), []).append(sid)

# Where recipes are learned, from wow.gg's Forever lists (tools/fetch_wowgg.py):
# checks the trainer guesses, and links items whose names differ from the recipe
GG = {}
GG_ITEM = {}
GG_LEARN = {}  # skill a trainer teaches it at (wow.gg)
for _l in open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "forever_recipe_sources.txt"), encoding="utf-8"):
    if _l.startswith("#") or not _l.strip(): continue
    _p = _l.rstrip("\n").split(" ", 3)
    GG[(int(_p[0]), int(_p[1]))] = _p[2]
    if _p[2] == "trainer" and len(_p) > 3 and _p[3].isdigit(): GG_LEARN[(int(_p[0]), int(_p[1]))] = int(_p[3])
    if _p[2] == "item": GG_ITEM.setdefault((int(_p[0]), norm(_p[3])), []).append(int(_p[1]))

recipes, unmatched, recipe_ids, linked = {}, [], [], set()
for iid, r in item.items():
    if r.get(12) != 9 or r.get(13) not in SUB_LINE: continue
    name = r.get(1) or ""
    if ":" not in name: continue
    line = SUB_LINE[r.get(13)]
    bare = name.split(":", 1)[1]
    sids = by_name.get((line, norm(bare))) or by_name.get((line, norm(name)))
    if not sids:  # "Ornate Mithril Shoulder" teaches "Ornate Mithril Shoulders"
        sids = by_name.get((line, norm(bare) + "s")) or by_name.get((line, norm(bare).rstrip("s")))
    if not sids:  # renamed: "Recipe: Mithril Head Trout" teaches "Mithril Headed Trout" (wow.gg)
        sids = GG_ITEM.get((line, norm(name)))
    if sids: linked.update(sids)  # taught by an item (even a retired one): not a trainer recipe
    if name.startswith("Deprecated"): continue
    recipe_ids.append(iid)
    if not sids:
        unmatched.append((iid, name)); continue
    vend = vendors_of(iid)
    drops = [d for d in tolist(r.get(2)) if d in npc]
    objs = tolist(r.get(3))
    quests = [q for q in tolist(r.get(6)) if q in quest]
    if not (vend or drops or objs or quests or tolist(r.get(4))): continue
    info = item_info.get(iid)
    skill = info and info["skill"]
    sell = info and info["sell"]
    bop = info and info["bind"] == 1
    for sid in sids:
        e = recipes.setdefault(sid, [])
        e.append(dict(item=iid, line=line, vendors=vend, drops=drops, drops5=[d for d in drops[:5] if ref(d)], objs=len(objs), quests=quests,
                      skill=int(skill) if skill else None, price=int(sell) * 4 if sell else None, bop=bool(bop)))

# The game's item table: reputation needed to buy a plan, and Forever's new plans
sparse = {}
if ITEMSPARSE:
    import csv
    for row in csv.DictReader(open(ITEMSPARSE, encoding="utf-8")):
        sparse[int(row["ID"])] = row
for sid, rows in recipes.items():
    for e in rows:
        r = sparse.get(e["item"])
        if r and int(r["MinFactionID"] or 0) > 0:
            e["faction"], e["standing"] = int(r["MinFactionID"]), int(r["MinReputation"] or 0)
if sparse:
    extra = dict(EXTRA_PLANS)
    extra.update({i: v for i, v in EXTRA_CANDIDATES.items() if Wanted(i)})
    for iid, vend in extra.items():
        r = sparse[iid]
        name = r["Display_lang"]
        line = {164: 164, 165: 165, 171: 171, 197: 197, 202: 202, 333: 333, 185: 185, 129: 129}.get(int(r["RequiredSkill"] or 0))
        bare = name.split(":", 1)[1]
        sids = by_name.get((line, norm(bare)))
        assert sids, name
        linked.update(sids)
        for nid in vend: ref(nid)
        for sid in sids:
            if any(e["item"] == iid for e in recipes.get(sid, [])): continue
            e = dict(item=iid, line=line, vendors=vend, drops=[], drops5=[], objs=0, quests=[],
                     skill=int(r["RequiredSkillRank"] or 0) or None, price=int(r["BuyPrice"] or 0) or None, bop=r["Bonding"] == "1")
            if int(r["MinFactionID"] or 0) > 0:
                e["faction"], e["standing"] = int(r["MinFactionID"]), int(r["MinReputation"] or 0)
            recipes.setdefault(sid, []).append(e)
            recipe_ids.append(iid)

# The trade camps' recipes (Merchant's Favor, and reputation with your trade company)
camp_count = 0
if sparse:
    by_item_name = {}
    for iid, r in sparse.items():
        if iid >= 200000: by_item_name.setdefault(r["Display_lang"], []).append(iid)
    PREFIX = ("Plans: ", "Pattern: ", "Recipe: ", "Formula: ", "Schematic: ")
    here = os.path.dirname(os.path.abspath(__file__))
    for raw in open(os.path.join(here, "data", "merchants_favor.txt"), encoding="utf-8"):
        if raw.startswith("#") or not raw.strip(): continue
        prof, name, skill, cost, standing = [x.strip() for x in raw.split("|")]
        line = CAMP_LINE[prof]
        variants = [name, name + "s", name[:-1] if name.endswith("s") else name]
        iid = next((i for v in variants for p in PREFIX for i in by_item_name.get(p + v, [])), None)
        sids = next((by_name[(line, norm(v))] for v in variants if (line, norm(v)) in by_name), None)
        if not (iid and sids): continue
        if not Wanted(iid): continue
        r = sparse[iid]
        for nid in CAMP_VENDORS[prof]: ref(nid)
        linked.update(sids)
        for sid in sids:
            if any(e["item"] == iid for e in recipes.get(sid, [])): continue
            e = dict(item=iid, line=line, vendors=list(CAMP_VENDORS[prof]), drops=[], drops5=[], objs=0, quests=[],
                     skill=int(r["RequiredSkillRank"] or 0) or int(skill), price=None, bop=r["Bonding"] == "1",
                     currency=MERCHANTS_FAVOR, amount=int(cost))
            if STANDING[standing]: e["faction"], e["standing"] = TRADE_FACTION, STANDING[standing]
            recipes.setdefault(sid, []).append(e)
            if iid not in recipe_ids: recipe_ids.append(iid)
            camp_count += 1
    print("trade camp recipes:", camp_count)

# Probably taught by a trainer: not learned with the profession, no item
# teaches it, and it belongs to this game (it makes an item WoW Forever has,
# or it's an older enchant-style recipe that makes no item)
outputs = {int(k): int(v) for k, v in ex["outputs"].items()} if ex["outputs"] else {}
START = {int(line): {int(sp) for sp, d in rec.items() if d[3] == 1} for line, rec in L.globals().SP.DATA.items()}
# Taught by an NPC out in the world, with no item and no trainer (wow.gg lists
# them like trainer recipes)
NPC_TAUGHT = {
    22813: "Knot Thimblejack, Dire Maul (after The Gordok Ogre Suit)",  # Gordok Ogre Suit, Tailoring
    22815: "Knot Thimblejack, Dire Maul (after The Gordok Ogre Suit)",  # Gordok Ogre Suit, Leatherworking
    13028: "Henry Stern, Razorfen Downs",  # Goldthorn Tea
    14891: "the Black Forge, Blackrock Depths",  # Smelt Dark Iron: only at the Black Forge
}
# Smelting: trainers teach smelts at fixed skills that don't follow the colors
# (Smelt Tin at 65 while it's yellow from 50, Smelt Silver at 75 while orange
# until 100), so Mining uses wow.gg's learn skill
LEARN_FROM_GG = {186}
maybe, checked, gg_not_trainer = {}, {}, 0
for line, rec in DATA.items():
    for sid in rec:
        if sid in linked or sid in START.get(line, ()) or sid not in spell_name: continue
        if sid in NPC_TAUGHT: continue  # taught by an NPC out in the world, not a trainer
        if GG.get((line, sid)) == "item":  # an item teaches it (a drop, quest or vendor): not a trainer
            gg_not_trainer += 1
            continue
        out = outputs.get(sid)
        # WoW Forever's own new recipes (spell IDs above 1,000,000) are left
        # out: many come from other sources, and trainer windows add the
        # ones trainers teach. So are other games' recipes (Season of
        # Discovery, 400000s).
        if (out and out in item) or (not out and sid < 100000):
            maybe.setdefault(line, []).append(sid)
            if GG.get((line, sid)) == "trainer": checked.setdefault(line, []).append(sid)
print("trainer guesses:", sum(len(v) for v in maybe.values()), "confirmed by wow.gg:", sum(len(v) for v in checked.values()),
      "not trainer recipes (an item teaches them):", gg_not_trainer)

# rank books and quests: resolve their NPCs now, so they're in SP.NPCS
special_rows = {}
for prof in sorted(special):
    for rank, (kind, x) in special[prof].items():
        if kind == "book":
            special_rows.setdefault(prof, []).append((rank, "book", x, vendors_of(x)))
        else:
            special_rows.setdefault(prof, []).append((rank, "quest", [(qid, quest_starts(qid)) for qid in x], None))

# ---------------------------------------------------------------- specializations
# (spell, name, profession line, skill, level, needs this spec first, trainers, who starts it)
SPECS = [
    (9788, "Armorsmith", 164, 200, 40, None, [11177, 5164], [11176, 11145]),
    (9787, "Weaponsmith", 164, 200, 40, None, [11178, 11146], [11176, 11145]),
    (17041, "Master Axesmith", 164, 250, 50, 9787, [11192], [11192]),
    (17040, "Master Hammersmith", 164, 250, 50, 9787, [11191], [11191]),
    (17039, "Master Swordsmith", 164, 250, 50, 9787, [11193], [11193]),
    (20219, "Gnomish Engineer", 202, 200, 30, None, [7944, 7406], [7944, 7406]),
    (20222, "Goblin Engineer", 202, 200, 30, None, [8126, 8738], [8126]),
    (10656, "Dragonscale Leatherworking", 165, 225, 40, None, [7866, 7867], [7866, 7867]),
    (10658, "Elemental Leatherworking", 165, 225, 40, None, [7868, 7869], [7868, 7869]),
    (10660, "Tribal Leatherworking", 165, 225, 40, None, [7870, 7871], [7870, 7871]),
]
# Taught only by a specialization trainer (no item, so the game data can't tell)
SPEC_TRAINER_RECIPES = {
    9788: [9954, 9974],                    # Truesilver Gauntlets, Truesilver Breastplate
    9787: [10003, 10015, 10007],           # The Shatterer, Truesilver Champion, Phantom Blade
    20219: [12899, 12895, 12897, 12902, 12903, 12905, 12906, 12907, 12759],
    20222: [12718, 12717, 12716, 12715, 12760, 8895, 12755, 12754, 12908, 12758],
    10656: [10619, 10650],                 # Dragonscale Gauntlets, Dragonscale Breastplate
    10658: [10630, 10632],                 # Gauntlets of the Sea, Helm of Fire
    10660: [10621, 10647],                 # Wolfshead Helm, Feathered Breastplate
}
spec_recipes = {}
for sp, sids in SPEC_TRAINER_RECIPES.items():
    for sid in sids:
        assert any(sid in rec for rec in DATA.values()), sid
        spec_recipes[sid] = sp
if sparse:
    spec_of = {s[0] for s in SPECS}
    for row in sparse.values():
        sp = int(row["RequiredAbility"] or 0)
        if sp not in spec_of: continue
        iid = int(row["ID"])
        for sid, rows in recipes.items():
            if any(e["item"] == iid for e in rows): spec_recipes[sid] = sp
spec_rows = []
for sp, name, line, skill, level, parent, tr, st in SPECS:
    spec_rows.append((sp, name, line, skill, level, parent, [t for t in tr if ref(t)], [t for t in st if ref(t)]))

# ---------------------------------------------------------------- write
def q(s): return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'
def ids(xs): return "{" + ",".join(str(x) for x in xs) + "}"
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("-- Profession Pathfinder - where to train and where recipes come from\n")
    f.write("-- Built by tools/make_sources.py from QuestieDB's WoW Forever database\n")
    f.write("-- (GPL-3.0, https://github.com/Questie/QuestieDB). Do not edit by hand.\n\n")
    f.write("local ADDON, SP = ...\n\n")
    f.write("-- [npc ID] = { name, title, friendly to (A/H/AH), area ID, map ID, x, y, zone (English),\n")
    f.write("--   \"rep\" (sells only to some players) or \"event\" (only during a holiday), why it's restricted }\n")
    f.write("SP.NPCS = {\n")
    for nid in sorted(used):
        n, sub, fac, area, umap, x, y, zone = used[nid]
        fl = flag(nid) if nid not in EXTRA_NPCS else None
        note = VENDOR_NOTES.get(n)
        tail = ("," + (q(fl) if fl else "nil")) if (fl or note) else ""
        if note: tail += "," + q(note)
        f.write("\t[%d]={%s,%s,%s,%d,%d,%s,%s,%s%s},\n" % (nid, q(n), q(sub or ""), q(fac), area, umap,
            "nil" if x is None else x, "nil" if y is None else y, q(zone), tail))
    f.write("}\n\n-- Trainers: [profession] = { {npc ID, highest skill cap they teach}, ... }\nSP.TRAINERS = {\n")
    for prof in sorted(trainers):
        f.write("\t[%s] = {" % q(prof) + ", ".join("{%d,%d}" % t for t in sorted(trainers[prof])) + "},\n")
    f.write("}\n\n-- Ranks you don't get from a trainer: a book (item, vendors) or a quest (quest IDs, who starts it)\nSP.RANK_SPECIAL = {\n")
    for prof in sorted(special_rows):
        f.write("\t[%s] = {\n" % q(prof))
        for rank, kind, x, vend in special_rows[prof]:
            if kind == "book":
                f.write("\t\t%s = { book = %d, name = %s, vendors = %s },\n" % (rank, x, q(item[x][1]), ids(vend)))
            else:
                parts = ", ".join("{ id = %d, name = %s, starts = %s }" % (qid, q(quest[qid][1]), ids(st)) for qid, st in x)
                f.write("\t\t%s = { quests = { %s } },\n" % (rank, parts))
        f.write("\t},\n")
    f.write("}\n\n-- Recipes from items: [recipe spell] = { {item, skill to learn, vendor price, bind on pickup,\n")
    f.write("--   vendors, NPCs that drop it (up to 5), number of NPCs that drop it, objects, quests,\n")
    f.write("--   reputation faction needed to buy it (-1: your trade company), standing (0 Hated .. 3 Neutral, 4 Friendly,\n")
    f.write("--   5 Honored, 6 Revered, 7 Exalted), currency it costs, how much}, ... }\nSP.RECIPE_ITEMS = {\n")
    for sid in sorted(recipes):
        rows = []
        for e in recipes[sid]:
            row = "{%d,%s,%s,%s,%s,%s,%d,%d,%s" % (e["item"], e["skill"] or "nil", e["price"] or "nil", "true" if e["bop"] else "false",
                ids([v for v in e["vendors"]]), ids(e["drops5"]), len(e["drops"]), e["objs"], ids(e["quests"]))
            if e.get("faction") or e.get("currency"):
                row += ",%s,%s" % (e.get("faction") or "nil", e.get("standing") if e.get("standing") is not None else "nil")
            if e.get("currency"): row += ",%d,%d" % (e["currency"], e["amount"])
            rows.append(row + "}")
        f.write("\t[%d]={%s},\n" % (sid, ",".join(rows)))
    f.write("}\n\n-- Recipes probably taught by a trainer (no item teaches them): [skill line] = { recipe spell, ... }\nSP.MAYBE_TRAINER = {\n")
    for line in sorted(maybe):
        f.write("\t[%d] = {" % line)
        for i, sid in enumerate(sorted(maybe[line])):
            f.write(("\n\t\t" if i % 14 == 0 else " ") + "%d," % sid)
        f.write("\n\t},\n")
    f.write("}\n\n-- Trainer guesses confirmed by wow.gg's Forever lists: [skill line] = { recipe spell, ... }\nSP.TRAINER_CHECKED = {\n")
    for line in sorted(checked):
        f.write("\t[%d] = {" % line)
        for i, sid in enumerate(sorted(checked[line])):
            f.write(("\n\t\t" if i % 14 == 0 else " ") + "%d," % sid)
        f.write("\n\t},\n")
    f.write("}\n\n-- Skill a trainer teaches it at, where that isn't the yellow skill (smelting; wow.gg)\nSP.TRAINER_LEARN = {\n")
    for line in sorted(LEARN_FROM_GG):
        learn_ids = sorted(sid for sid in checked.get(line, []) if (line, sid) in GG_LEARN)
        f.write("\t[%d] = { %s },\n" % (line, " ".join("[%d]=%d," % (sid, GG_LEARN[(line, sid)]) for sid in learn_ids)))
    f.write("}\n\n-- Every recipe item (for /ppf export)\nSP.RECIPE_ITEM_IDS = {")
    for i, iid in enumerate(sorted(recipe_ids)):
        f.write(("\n\t" if i % 16 == 0 else " ") + "%d," % iid)
    f.write("\n}\n\n-- Quest names (English; the game's own name is used when it knows the quest)\nSP.QUEST_NAMES = {\n")
    qn = set()
    for sid in recipes:
        for e in recipes[sid]: qn.update(e["quests"])
    for prof in special.values():
        for kind, x in prof.values():
            if kind == "quest": qn.update(x)
    for qid in sorted(qn):
        f.write("\t[%d]=%s,\n" % (qid, q(quest[qid][1])))
    f.write("}\n")
    # Quests that reward a recipe: level, level needed, who starts them (for the
    # missing recipes list)
    f.write("\n-- Recipe quests: [quest] = { quest level, level needed, { NPCs that start it } }\nSP.QUEST_INFO = {\n")
    rq = set()
    for sid in recipes:
        for e in recipes[sid]: rq.update(e["quests"])
    for qid in sorted(rq):
        r = quest[qid]
        f.write("\t[%d]={%d,%d,{%s}},\n" % (qid, r.get(5) or 0, r.get(4) or 0, ",".join(str(n) for n in quest_starts(qid))))
    f.write("}\n")
    # Where to get recipes the rest of the data has no source for (wow.gg), for
    # the missing recipes list only: never planned
    import json as _json
    col = _json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "forever_collect.json"), encoding="utf-8"))
    in_maybe = {sid for ids_ in maybe.values() for sid in ids_}
    def lstr(x): return "nil" if x is None else (q(x) if isinstance(x, str) else ("%g" % x))
    f.write("\n-- Where to get recipes nothing else here covers (wow.gg), for the missing recipes list:\n")
    f.write("-- [recipe spell] = { t = taught by a trainer, n = recipe item, c = {currency, amount},\n")
    f.write("--   v = {{vendor, zone, side, price}}, d = {{creature, zone, chance}}, dn = how many drop it,\n")
    f.write("--   q = {{quest, zone, side, level}}, o = found in objects/places/the world }\nSP.COLLECT = {\n")
    ncol = 0
    for line_s, recs in sorted(col.items()):
        line = int(line_s)
        for sid_s, c in sorted(recs.items(), key=lambda kv: int(kv[0])):
            sid = int(sid_s)
            if sid in recipes or sid in in_maybe or sid in START.get(line, ()) or sid in NPC_TAUGHT: continue
            if sid not in DATA.get(line, {}): continue
            parts = []
            if c.get("t"): parts.append("t=1")
            if c.get("n"): parts.append("n=" + q(c["n"]))
            if c.get("cost"): parts.append("c={%s,%s}" % (lstr(c["cost"][0]), lstr(c["cost"][1])))
            if c.get("v"): parts.append("v={" + ",".join("{%s,%s,%s,%s}" % tuple(lstr(x) for x in v) for v in c["v"]) + "}")
            if c.get("d"): parts.append("d={" + ",".join("{%s,%s,%s}" % tuple(lstr(x) for x in d) for d in c["d"]) + "}")
            if c.get("dn"): parts.append("dn=%d" % c["dn"])
            if c.get("q"): parts.append("q={" + ",".join("{%s,%s,%s,%s}" % tuple(lstr(x) for x in qq) for qq in c["q"]) + "}")
            if c.get("o"): parts.append("o=" + q(c["o"]))
            if not parts: continue
            f.write("\t[%d]={%s},\n" % (sid, ",".join(parts)))
            ncol += 1
    f.write("}\n")
    print("recipes for the missing list only (wow.gg):", ncol)
    # Recipes in the game's tables that wow.gg's Forever lists don't have, with no
    # other source either: from other game versions, left out of the missing list
    f.write("\n-- Recipes not in WoW Forever as far as wow.gg and the rest of the data know (left out of the missing list)\nSP.NOT_LISTED = {")
    nl = 0
    for line in sorted(col):
        L_ = int(line)
        for sid in sorted(DATA.get(L_, {})):
            if (L_, sid) in GG or sid in recipes or sid in in_maybe or sid in START.get(L_, ()) or sid in NPC_TAUGHT: continue
            if str(sid) in col[line]: continue
            f.write(("\n\t" if nl % 14 == 0 else " ") + "[%d]=true," % sid)
            nl += 1
    f.write("\n}\n")
    print("recipes not listed for Forever:", nl)
    # Recipes taught by an NPC out in the world (no item, no trainer)
    f.write("\n-- Taught by an NPC in the world: [recipe spell] = where\nSP.NPC_TAUGHT = {\n")
    for sid, where_ in sorted(NPC_TAUGHT.items()):
        f.write("\t[%d]=%s,\n" % (sid, q(where_)))
    f.write("}\n")
    # Materials a regular vendor sells (thread, vials, flux, dyes, spices...),
    # for the gather & craft mode: the planner may buy these, nothing else
    f.write("\n-- Specializations: [spell] = { name, profession line, skill, level, needs first, trainers, who starts it }\nSP.SPECS = {\n")
    for sp, name, line, skill, level, parent, tr, st in spec_rows:
        f.write("\t[%d] = { %s, %d, %d, %d, %s, %s, %s },\n" % (sp, q(name), line, skill, level, parent or "nil", ids(tr), ids(st)))
    f.write("}\n-- Recipes only a specialist can learn: [recipe spell] = specialization spell\nSP.SPEC_RECIPES = {")
    for i, sid in enumerate(sorted(spec_recipes)):
        f.write(("\n\t" if i % 8 == 0 else " ") + "[%d]=%d," % (sid, spec_recipes[sid]))
    f.write("\n}\n")
    f.write("\n-- Materials sold by a regular vendor (not reputation or holiday vendors)\nSP.VENDOR_SOLD = {")
    sold = []
    for iid, r in item.items():
        if r.get(12) not in (0, 5, 7): continue
        if any(n in npc and flag(n) is None for n in tolist(r.get(14))): sold.append(iid)
    for i, iid in enumerate(sorted(sold)):
        f.write(("\n\t" if i % 12 == 0 else " ") + "[%d]=true," % iid)
    f.write("\n}\n")
print("vendor-sold materials:", len(sold))
print("trainers:", {k: len(v) for k, v in trainers.items()})
print("recipes linked:", len(recipes), "unmatched items:", len(unmatched))
print("probably trainer:", {k: len(v) for k, v in maybe.items()})
for u in unmatched[:40]: print("  unmatched", u)
