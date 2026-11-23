# Profession Pathfinder

Plans the cheapest way to level your professions in **WoW Forever**, using the game's own recipe data.

Open a profession and Profession Pathfinder shows you:
- what to craft next and how many
- which recipes to learn, at what skill, for how much, and **where**: the nearest trainer, or the vendor that sells the recipe
- a shopping list with Auction House prices
- who teaches your next rank (or which book or quest you need), with the location: click to pin it on your map

It adds a craft button, tells you where to gather your own materials, and helps with fishing.

![Profession Pathfinder next to the Blacksmithing window](docs/screenshot-plan.png)

## Features

- **A plan built from game data.** For every skill point, it picks the cheapest recipe per skill-up: recipes you know, recipes a trainer teaches once your skill allows, and recipes you can buy from a vendor or the Auction House (or already have in your bags). Orange recipes, which always give a point, are used where they save money. Hotfixes are picked up automatically.
- **Where to go.** Trainers for every profession and rank, the Expert books and Artisan quests for First Aid, Cooking and Fishing, and recipe vendors, nearest first and for your faction only. Click one to put a pin on your map (and in TomTom, if you use it).
- **Exact recipe colors.** Where each recipe turns yellow comes from Blizzard's own data, and where it turns grey from the game itself.
- **It learns as you play:**
  - Every trainer window you open is read, so it knows which recipes the trainer sells and at what skill.
  - Every craft is logged, so its estimates move towards your real skill-up results.
- **A shopping list and costs.**
  - Prices come from [Auctionator](https://www.curseforge.com/wow/addons/auctionator) if you have it, and the list can be sent to Auctionator as a shopping list.
  - Materials you already own can be left off.
  - Cheaper-to-make materials, like smelting bars, are planned too.
- **Your other characters.** It shows each character's professions and which of them can gather a material themselves.
- **Legacy.** It counts the Working Overtime perk in skill-up chances and shows when you're close to a Legacy point.
- **Gathering.** With no profession window open, it shows where to mine, pick herbs, skin and fish for your skill.
- **Fishing help:**
  - one key to cast and to loot, pressed once per catch
  - the best lure you have, with a timer
  - whether a zone suits your skill
  - a catch log per zone
  - which fish your Cooking plan still needs
- **It works in any game language.** Professions, recipes and zones are recognized by their game IDs.

## Commands

| Command | What it does |
|---|---|
| `/ppf` | Show or hide the window. With no profession open, it shows where to gather. |
| `/ppf options` | The options page. |
| `/ppf target <skill>` | Plan up to a skill instead of your current cap (`0` = cap). |
| `/ppf bags` | Leave materials you own off the shopping list (on/off). |
| `/ppf chars` | All your characters' professions. |
| `/ppf fish` | One-key fishing on/off. `/ppf fish log` shows fishing by zone; `/ppf fish reset` starts a new session. |
| `/ppf scan` | Recipe data check, with a profession window open. Useful for bug reports. |
| `/ppf trainer` | Trainer data check, with a trainer window open. |
| `/ppf export` | For developers: saves the game's recipe names and recipe-item skills, to rebuild `Sources.lua`. |

`/pathfinder` works too.

## Where the numbers come from

| What | Source |
|---|---|
| Recipes, materials, what they make, grey level | The game, read live from your profession window |
| Where a recipe turns yellow | Blizzard's recipe table (`SkillLineAbility`), built into `Data.lua` |
| The skill a trainer sells a recipe at, and the price | Trainer windows: built-in data in `TrainerData.lua`, plus every trainer you open |
| Prices | Auctionator, when it's installed |
| Trainers, rank books and quests, recipe vendors, drops and quests, NPC locations | [QuestieDB](https://github.com/Questie/QuestieDB)'s WoW Forever database (GPL-3.0), built into `Sources.lua` |
| Gathering zone tips | General advice, based on community leveling guides such as wow-professions.com |

When the trainer skill for a recipe isn't known yet, the planner waits until the recipe turns yellow. That is always safe, just sometimes later than needed.

### Known limits
- Recipes that only **drop** or come from **quests** aren't planned, because you can't count on getting them. They're shown in tooltips so you know they exist.
- Recipes no item teaches are assumed to come from a trainer (marked "probably"). The exact skill and price are known once you open a trainer window that lists them: trainers only show recipes up to your current rank, so open the trainer at each rank.
- Locations come from QuestieDB. Some new WoW Forever areas (such as Zephras Isle and the Riverglades) aren't fully in it yet, so their trainers may be missing.
- Skill-up counts are estimates. The chance of a skill-up is random.

## Reporting a problem

Please open an issue with:
- what you expected and what happened
- a screenshot of the window
- the text from `/ppf scan`: open the profession window, type the command, then press Ctrl+C in the window that opens

## For developers

- `tests/`: tests that run outside the game against a mock of the game API. Run them with `python3 tests/run_tests.py`; they need [lupa](https://pypi.org/project/lupa/).
- `tools/make_data.py`: rebuilds `Data.lua` from a `SkillLineAbility` CSV exported from [wago.tools](https://wago.tools/db2/SkillLineAbility) for the current Forever build.
- `tools/make_trainer.py`: merges trainer data from SavedVariables files into `TrainerData.lua`.
- `tools/make_sources.py`: builds `Sources.lua` from a [QuestieDB](https://github.com/Questie/QuestieDB) checkout and a SavedVariables file with `/ppf export` in it.
- Releases are built by the [BigWigs packager](https://github.com/BigWigsMods/packager) when a version tag (`v1.0.0`) is pushed.

## License

Profession Pathfinder is free software under the [GNU General Public License v3.0 or later](LICENSE).
`Sources.lua` is built from [QuestieDB](https://github.com/Questie/QuestieDB) (GPL-3.0); thanks to the Questie team.

Author: Krigar Kossan
