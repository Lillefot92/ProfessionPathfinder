"""Build TrainerData.lua from trainer windows the addon has seen
(ProfessionPathfinderDB.teach / teachCost in a SavedVariables file).
Only recipes in Data.lua are kept. Merges with an existing TrainerData.lua,
so data from several players can be combined: the lowest skill wins."""
import sys, re, os
from lupa import LuaRuntime
out, data_lua, sv_files = sys.argv[1], sys.argv[2], sys.argv[3:]
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("SP = {}")
src = open(data_lua, encoding="utf-8").read().replace("local ADDON, SP = ...", "")
L.execute(src)
DATA = L.globals().SP.DATA
line_of = {}
for line, recipes in DATA.items():
    for sid in recipes.keys():
        line_of[int(sid)] = int(line)
known = {}  # spell -> (skill, cost)
if os.path.exists(out):
    for sid, req, cost in re.findall(r"\[(\d+)\]=\{(\d+),(\d+)\}", open(out, encoding="utf-8").read()):
        known[int(sid)] = (int(req), int(cost))
for f in sv_files:
    L.execute(open(f, encoding="utf-8").read())
    db = L.globals().ProfessionPathfinderDB
    costs = dict(db.teachCost.items()) if db.teachCost else {}
    for sid, req in (db.teach.items() if db.teach else []):
        sid, req = int(sid), int(req)
        if sid not in line_of: continue
        c = int(costs.get(sid, 0) or 0)
        if sid not in known or req < known[sid][0]:
            known[sid] = (req, c)
by_line = {}
for sid, v in known.items():
    by_line.setdefault(line_of[sid], []).append((sid,) + v)
NAMES = {164: "Blacksmithing", 165: "Leatherworking", 171: "Alchemy", 197: "Tailoring", 202: "Engineering",
         333: "Enchanting", 185: "Cooking", 129: "First Aid", 186: "Mining"}
with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write("-- Profession Pathfinder - what trainers ask for\n")
    f.write("-- Read from trainer windows in game. tools/make_trainer.py builds it.\n")
    f.write("-- [recipe spell ID] = { skill needed, cost in copper }\n\n")
    f.write("local ADDON, SP = ...\nSP.TRAINER = {\n")
    for line in sorted(by_line):
        rows = sorted(by_line[line])
        f.write("\t[%d] = { -- %s, %d recipes\n" % (line, NAMES.get(line, "?"), len(rows)))
        buf = "\t\t"
        for sid, req, cost in rows:
            item = "[%d]={%d,%d}," % (sid, req, cost)
            if len(buf) + len(item) > 110:
                f.write(buf.rstrip() + "\n"); buf = "\t\t"
            buf += item + " "
        f.write(buf.rstrip() + "\n\t},\n")
    f.write("}\n")
print({NAMES.get(l, l): len(v) for l, v in by_line.items()}, "total", len(known))
