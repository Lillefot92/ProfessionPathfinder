"""Where each recipe is learned, from wow.gg's WoW Forever profession lists.

Writes tools/data/forever_recipe_sources.txt, one line per recipe:
  <skill line> <recipe spell> trainer <skill the trainer teaches it at>
  <skill line> <recipe spell> item <name of the item that teaches it>
make_sources.py uses it to check the "probably taught by a trainer" guesses
and to link recipe items whose names don't match the recipe ("Recipe: Mithril
Head Trout" teaches "Mithril Headed Trout").

wow.gg keys enchants by effect, not spell, so those are matched by colors and
materials (wago.tools SpellReagents.csv).

  python3 tools/fetch_wowgg.py Data.lua SpellReagents.csv names.lua [cache dir]
(names.lua: SavedVariables from /ppf export, for the recipes' names)
"""
import csv, json, os, re, sys, urllib.request

PAGES = {"mining": 186, "first-aid": 129, "blacksmithing": 164, "leatherworking": 165, "alchemy": 171, "cooking": 185,
         "tailoring": 197, "engineering": 202, "enchanting": 333}
DATA_LUA, REAGENTS, NAMES = sys.argv[1:4]
CACHE = sys.argv[4] if len(sys.argv) > 4 else None
HERE = os.path.dirname(os.path.abspath(__file__))


def page(name):
    path = CACHE and os.path.join(CACHE, name + ".html")
    if path and os.path.exists(path):
        return open(path, encoding="utf-8").read()
    html = urllib.request.urlopen("https://wow.gg/professions/forever/" + name, timeout=60).read().decode("utf-8")
    if path:
        open(path, "w", encoding="utf-8").write(html)
    return html


def recipes(html):
    parts = re.findall(r'self\.__next_f\.push\(\[1,"(.*?)"\]\)</script>', html, re.S)
    text = "".join(json.loads('"' + p + '"') for p in parts)
    dec, out = json.JSONDecoder(), []
    for m in re.finditer(r'\{"spell":', text):
        try:
            out.append(dec.raw_decode(text, m.start())[0])
        except ValueError:
            pass
    return out


# our recipes: colors (Data.lua) and materials, to match wow.gg's enchants
colors = {}
line = None
for l in open(DATA_LUA, encoding="utf-8"):
    m = re.match(r"\s*\[(\d+)\] = \{ --", l)
    if m:
        line = int(m.group(1))
        continue
    if line:
        for sid, y, g in re.findall(r"\[(\d+)\]=\{(\d+),(\d+)", l):
            colors[(line, int(sid))] = (int(y), int(g))
mats = {}
for r in csv.DictReader(open(REAGENTS)):
    t = [(int(r[f"Reagent_{k}"] or 0), int(r[f"ReagentCount_{k}"] or 0)) for k in range(8)]
    mats[int(r["SpellID"])] = tuple(sorted(x for x in t if x[0] > 0 and x[1] > 0))

names = {}
for i, n in re.findall(r'\[(\d+)\] = "([^"]+)"', open(NAMES, encoding="utf-8", errors="replace").read()):
    names.setdefault(int(i), n)
# words in an enchant's name that match wow.gg's effect text
WORDS = {"defense": "armor", "protection": "armor", "deflection": "defense"}


def same_effect(sid, effect):
    what = names.get(sid, "").split(" - ")[-1].lower().split()
    effect = effect.lower()
    return all(WORDS.get(w, w) in effect for w in what if w not in ("minor", "lesser", "greater", "superior", "major"))


rows, enchants_unmatched = [], 0
for name, line in PAGES.items():
    ours = {sid for (l, sid) in colors if l == line}
    by_look = {}
    for sid in ours:
        by_look.setdefault((colors[(line, sid)], mats.get(sid, ())), []).append(sid)
    for r in recipes(page(name)):
        sid = r["spell"]
        if sid < 0:  # an enchant: find ours with the same colors and materials
            key = ((r["yellow"], r["grey"]), tuple(sorted((x["id"], x["count"]) for x in r.get("reagents", []))))
            found = by_look.get(key, [])
            if len(found) > 1:
                found = [f for f in found if same_effect(f, r.get("effect", ""))]
            if len(found) != 1:
                enchants_unmatched += 1
                continue
            sid = found[0]
        if sid not in ours:
            continue
        src = r.get("source")
        if src is None or src.get("trainers"):
            rows.append((line, sid, "trainer", str(r.get("learn") or "")))
        elif src.get("n"):
            rows.append((line, sid, "item", src["n"]))

out = os.path.join(HERE, "data", "forever_recipe_sources.txt")
with open(out, "w", encoding="utf-8") as f:
    f.write("# Where WoW Forever recipes are learned, from wow.gg (tools/fetch_wowgg.py)\n")
    f.write("# <skill line> <recipe spell> trainer <skill it's taught at> | item <item that teaches it>\n")
    for line, sid, kind, item in sorted(set(rows)):
        f.write(f"{line} {sid} {kind}" + (f" {item}" if item else "") + "\n")
print(len(set(rows)), "recipes written;", enchants_unmatched, "enchants not matched")
