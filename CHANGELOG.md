# Changelog

## 1.3.0

Finishing your profession, and one set of saved data per character.

- Blacksmithing now reaches 300. WoW Forever's own end-game plans are in: Bold Dirk from Pexmit (Dae'gun, Mount Hyjal) and the Goregasher and Clutchlord's plans from Vargus (Cenarion Hold, Silithus). Before, plans stopped around 286
- Plans that need reputation (Vargus, the Argent Dawn and Thorium Brotherhood quartermasters) are planned once you have the reputation. Until then the tooltip says what's needed and where you stand, like "at Friendly with Cenarion Circle (you're Neutral)"
- When a plan does stop early, the window names the best ways past that point: reputation plans, quests and common drops, instead of only "visit your trainer"
- Plans on your other characters count too, if you use Syndicator: "Mega has Plans: Thorium Boots (bank): mail it to this character"
- Magnus Frostwake's plans explain that you need the Spectral Essence from the Scholomance quest chain to see him
- Each character now keeps one set of saved data. On Forever the game sometimes gives the server's name as your realm, sometimes the second part of your character's name ("Kossan" in Krigar-Kossan) and sometimes nothing, so a character could end up saved twice (and an alt could show up twice in gather & craft mode). The character is now always known by that second part, which never changes, and what was saved under the server's name moves there when you log in on that character.

## 1.2.2

- Recipes with a cooldown are no longer planned: the transmutes (Iron to Gold, Mithril to Truesilver, Arcanite, the elemental ones), Mooncloth and Refined Scale of Onyxia. You can only make them once in a while, so they can't be part of a leveling route, and they aren't used to make materials either. Thanks for the report on CurseForge!

## 1.2.1

Specializations, and characters on realms whose name the game doesn't always give.

- Recipes only a specialist can learn (Armorsmith, Weaponsmith and the Master Axe-, Hammer- and Swordsmiths, Gnomish and Goblin Engineers, Dragonscale, Elemental and Tribal Leatherworkers) are only planned for that specialist, and you're sent to the specialization trainer to learn them. Before, plans could include Truesilver Gauntlets or Truesilver Champion for any blacksmith
- When you can pick a specialization, the window says so and who to talk to
- `/ppf scan` shows the specializations it sees on your character
- The game sometimes gives an empty realm name on Forever. Things saved then (like "Krigar-") now move to your full character name once the realm is known, instead of being kept twice

## 1.2.0

Gather & craft mode, and net cost.

- New gather & craft mode (`/ppf gather` or the options): levels a profession with only what you gather yourself, cloth from humanoids and vendor items, no Auction House. Picks the recipes that need the least gathering, lists what to gather and where, shows what each step needs, and tells you when a gathering skill has to go up first (like Mining 65 for Tin)
- Your other characters' gathering counts too: if your alt can mine it, it's in
- Cloth (Linen to Runecloth) is listed with the humanoid levels that drop it and where to farm them
- Materials you can gather right now come first; ones that need a higher gathering skill are left for later
- Gathering, cloth and fishing zones now fit your character's level: only zones you can handle are suggested, or the easiest one with its level (like "Badlands (level 35+)")
- Shows what you'd get back for what you craft (selling to a vendor, or vendor or Auction House, whichever pays more, with Auctionator prices after the 5% cut), and what the plan costs after that
- New option "Pick recipes by cost after selling": cheaper in the end, but it can need much more gold up front, so it's off by default
- Things the plan uses later, like bars for your next recipe, aren't counted as sold
- Long notes no longer cover the bottom of the shopping list

## 1.1.0

Alliance support.

- Checked every profession and rank for the Alliance: trainers, the Expert books and Artisan quests for First Aid, Cooking and Fishing, recipe vendors and gathering zones all point to Alliance (or neutral) places
- Plans reach the same skill for Alliance as for Horde in every profession
- Fixed the backup text for Artisan Cooking: the quest Clamlette Surprise comes from Dirge Quikcleave in Gadgetzan for both factions
- Added Redridge Mountains as a closer Alliance zone for Tin and Silver

## 1.0.0

First release.

- Plans the cheapest way to level any crafting profession from 1 to 300, using the game's own recipe data
- Shows which recipes to learn and where: the nearest trainer for your faction, or the vendor selling the recipe. Click to pin it on your map
- Shows who teaches your next rank, including the Expert books and Artisan quests for First Aid, Cooking and Fishing
- Shopping list with Auctionator prices, a craft button, gathering zones and a fishing helper
- Learns from the trainer windows you open and from your own crafts
- Works in any game language

Only tested on Horde so far. Alliance testing is coming.
