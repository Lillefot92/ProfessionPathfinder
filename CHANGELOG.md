# Changelog

## 1.0.0 (first public release)

- **Plans come from game data.** They use recipe colors from Blizzard's data, grey levels from the game, and trainer recipes with their skill and cost.
- **Recipes to learn are part of the plan.** That includes recipes for materials, like Solid Grinding Stone. Training costs are counted in the total.
- **Vendor and Auction House recipes are planned too**, with the vendor's name and location, and recipes in your bags count as free. Drop and quest recipes are shown in tooltips.
- **Where to go:** the nearest trainer for each recipe and rank (your faction only), the Expert books and Artisan quests for First Aid, Cooking and Fishing. Click to pin the place on your map or in TomTom. Locations come from QuestieDB's WoW Forever data.
- **Every profession from 1 to 300:** recipes no item teaches are treated as trainer recipes, so plans don't stop at the end of the Apprentice trainer data.
- **Trainer windows are read automatically.** Each one adds the trainer's recipes, skill requirements and prices.
- **Skill-up estimates improve as you craft.** They use the recipe colors seen in game, your own craft results and the Working Overtime Legacy perk.
- **It works in any game language.** Professions, recipes and fishing zones are recognized by their game IDs.
- **Shopping list:** Auctionator prices and an Auctionator shopping list, materials you own left off, and cheaper-to-make materials planned.
- **Gathering zones** for Mining, Herbalism, Skinning and Fishing, and which of your characters can gather a material.
- **Fishing help:** one key per catch, lure reminder and timer, zone advice, a catch log, and the fish your Cooking plan needs.
- **`/ppf scan` and `/ppf trainer`** produce text to copy into bug reports.
- Licensed under GPL-3.0-or-later.
