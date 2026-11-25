"""Build Sources.lua: trainers, rank books/quests and recipe sources for
Profession Pathfinder, from QuestieDB's WoW Forever database (GPL-3.0,
https://github.com/Questie/QuestieDB) and the game's own names.

usage: make_sources.py <QuestieDB checkout> <Data.lua> <names> <out Sources.lua>

<names> is a SavedVariables file with ProfessionPathfinderDB.export, written
in game by /ppf export (spell names of every recipe in Data.lua, and the skill
each recipe item needs). It links recipe items to recipe spells by name."""
import os, re, sys
from lupa import LuaRuntime

QDB, DATA_LUA, NAMES, OUT = sys.argv[1:5]
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
def flag(nid):
    r = npc[nid]
    if r.get(1) in REP_VENDORS: return "rep"
    if r.get(14) in EVENT_TITLES: return "event"
    return None

used = {}
def ref(nid):
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

# Probably taught by a trainer: not learned with the profession, no item
# teaches it, and it belongs to this game (it makes an item WoW Forever has,
# or it's an older enchant-style recipe that makes no item)
outputs = {int(k): int(v) for k, v in ex["outputs"].items()} if ex["outputs"] else {}
START = {int(line): {int(sp) for sp, d in rec.items() if d[3] == 1} for line, rec in L.globals().SP.DATA.items()}
maybe = {}
for line, rec in DATA.items():
    for sid in rec:
        if sid in linked or sid in START.get(line, ()) or sid not in spell_name: continue
        out = outputs.get(sid)
        # WoW Forever's own new recipes (spell IDs above 1,000,000) are left
        # out: many come from other sources, and trainer windows add the
        # ones trainers teach. So are other games' recipes (Season of
        # Discovery, 400000s).
        if (out and out in item) or (not out and sid < 100000):
            maybe.setdefault(line, []).append(sid)

# rank books and quests: resolve their NPCs now, so they're in SP.NPCS
special_rows = {}
for prof in sorted(special):
    for rank, (kind, x) in special[prof].items():
        if kind == "book":
            special_rows.setdefault(prof, []).append((rank, "book", x, vendors_of(x)))
        else:
            special_rows.setdefault(prof, []).append((rank, "quest", [(qid, quest_starts(qid)) for qid in x], None))

# ---------------------------------------------------------------- write
def q(s): return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'
def ids(xs): return "{" + ",".join(str(x) for x in xs) + "}"
with open(OUT, "w", encoding="utf-8", newline="\n") as f:
    f.write("-- Profession Pathfinder - where to train and where recipes come from\n")
    f.write("-- Built by tools/make_sources.py from QuestieDB's WoW Forever database\n")
    f.write("-- (GPL-3.0, https://github.com/Questie/QuestieDB). Do not edit by hand.\n\n")
    f.write("local ADDON, SP = ...\n\n")
    f.write("-- [npc ID] = { name, title, friendly to (A/H/AH), area ID, map ID, x, y, zone (English),\n")
    f.write("--   \"rep\" (sells to players with reputation) or \"event\" (only during a holiday) }\n")
    f.write("SP.NPCS = {\n")
    for nid in sorted(used):
        n, sub, fac, area, umap, x, y, zone = used[nid]
        fl = flag(nid)
        f.write("\t[%d]={%s,%s,%s,%d,%d,%s,%s,%s%s},\n" % (nid, q(n), q(sub or ""), q(fac), area, umap, x, y, q(zone), ("," + q(fl)) if fl else ""))
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
    f.write("--   vendors, NPCs that drop it (up to 5), number of NPCs that drop it, objects, quests}, ... }\nSP.RECIPE_ITEMS = {\n")
    for sid in sorted(recipes):
        rows = []
        for e in recipes[sid]:
            rows.append("{%d,%s,%s,%s,%s,%s,%d,%d,%s}" % (e["item"], e["skill"] or "nil", e["price"] or "nil", "true" if e["bop"] else "false",
                ids([v for v in e["vendors"]]), ids(e["drops5"]), len(e["drops"]), e["objs"], ids(e["quests"])))
        f.write("\t[%d]={%s},\n" % (sid, ",".join(rows)))
    f.write("}\n\n-- Recipes probably taught by a trainer (no item teaches them): [skill line] = { recipe spell, ... }\nSP.MAYBE_TRAINER = {\n")
    for line in sorted(maybe):
        f.write("\t[%d] = {" % line)
        for i, sid in enumerate(sorted(maybe[line])):
            f.write(("\n\t\t" if i % 14 == 0 else " ") + "%d," % sid)
        f.write("\n\t},\n")
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
    # Materials a regular vendor sells (thread, vials, flux, dyes, spices...),
    # for the gather & craft mode: the planner may buy these, nothing else
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
