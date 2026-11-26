"""Build Data.lua from Blizzard's SkillLineAbility table (wago.tools CSV).
Keeps the crafting professions plus Cooking, First Aid and Mining (smelting).
Per recipe (= spell ID): yellow (TrivialSkillLineRankLow), grey
(TrivialSkillLineRankHigh) and 1 when it's learned with the profession.
With the SpellCooldowns table (4th argument) it also lists recipes with a
cooldown (transmutes, Mooncloth), which can't be crafted over and over.

usage: make_data.py <SkillLineAbility.csv> <out Data.lua> <build> [SpellCooldowns.csv]"""
import csv, sys
src, out, build = sys.argv[1], sys.argv[2], sys.argv[3]
cooldowns_csv = sys.argv[4] if len(sys.argv) > 4 else None
LINES = {164: "Blacksmithing", 165: "Leatherworking", 171: "Alchemy", 197: "Tailoring",
         202: "Engineering", 333: "Enchanting", 185: "Cooking", 129: "First Aid", 186: "Mining"}
data = {k: [] for k in LINES}
for r in csv.DictReader(open(src, encoding="utf-8")):
    sl = int(r["SkillLine"])
    if sl not in LINES: continue
    low, high = int(r["TrivialSkillLineRankLow"]), int(r["TrivialSkillLineRankHigh"])
    if high <= 0: continue
    data[sl].append((int(r["Spell"]), low, high, 1 if r["AcquireMethod"] == "1" else 0, int(r["ID"])))
with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write("-- Profession Pathfinder - recipe data\n")
    f.write("-- Generated from Blizzard's SkillLineAbility table, WoW Forever build %s.\n" % build)
    f.write("-- Do not edit by hand: tools/make_data.py builds it.\n")
    f.write("-- [recipe spell ID] = { yellow, grey, learnedWithProfession }\n\n")
    f.write("local ADDON, SP = ...\nSP.DATA_BUILD = %r\nSP.DATA = {\n" % build)
    for sl in sorted(data):
        rows = sorted(data[sl])
        f.write("\t[%d] = { -- %s, %d recipes\n" % (sl, LINES[sl], len(rows)))
        line = "\t\t"
        for spell, low, high, auto, _ in rows:
            item = "[%d]={%d,%d%s}," % (spell, low, high, ",1" if auto else "")
            if len(line) + len(item) > 110:
                f.write(line.rstrip() + "\n"); line = "\t\t"
            line += item + " "
        f.write(line.rstrip() + "\n\t},\n")
    f.write("}\n")
    if cooldowns_csv:
        spells = {spell for rows in data.values() for spell, *_ in rows}
        cd = {}
        for r in csv.DictReader(open(cooldowns_csv, encoding="utf-8")):
            s_id = int(r["SpellID"])
            t = max(int(r["CategoryRecoveryTime"] or 0), int(r["RecoveryTime"] or 0)) // 1000
            if s_id in spells and t > 0: cd[s_id] = max(cd.get(s_id, 0), t)
        f.write("\n-- Recipes with a cooldown: [recipe spell ID] = seconds\nSP.COOLDOWN = {\n\t")
        f.write(" ".join("[%d]=%d," % (k, cd[k]) for k in sorted(cd)))
        f.write("\n}\n")
print({LINES[k]: len(v) for k, v in data.items()})
