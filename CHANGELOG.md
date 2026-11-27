# Changelog

## 1.3.1

Fewer wrong trips to the trainer.

- When the addon doesn't know where a recipe comes from, it guesses "probably taught by a trainer". Every guess has been checked against wow.gg's WoW Forever recipe lists. 436 are confirmed and now read "a trainer teaches it" without the "probably"
- Recipes that really come from a drop, a quest or a vendor are no longer sent to the trainer. Examples: Troll's Blood Elixir (a rare drop in Arathi Highlands), Mithril Plate Bracers and Shoulders, the Timbermaw patterns, Major Healing Potion and Festival Suit
- Recipe items whose names differ from the recipe are now linked, so their vendors show up and can be planned. Examples: "Recipe: Mithril Head Trout" for Mithril Headed Trout, "Recipe: Elixir of Ogre's Strength" and "Recipe: Elixir of Superior Defense" for Elixir of Greater Defense
- Gordok Ogre Suit and Goldthorn Tea are taught by NPCs out in the world (in Dire Maul and Razorfen Downs), so they're no longer planned as trainer recipes

## 1.3.0

Finishing your profession, and one set of saved data per character.

- Blacksmithing now reaches 300. WoW Forever's own end-game plans are in: Bold Dirk from Pexmit (Dae'gun, Mount Hyjal) and the Goregasher and Clutchlord's plans from Vargus (Cenarion Hold, Silithus). Before, plans stopped around 286
- Plans that need reputation (Vargus, the Argent Dawn and Thorium Brotherhood quartermasters) are planned once you have the reputation. Until then the tooltip says what's needed and where you stand, like "at Friendly with Cenarion Circle (you're Neutral)"
- When a plan does stop early, the window names the best ways past that point: reputation plans, quests and common drops, instead of only "visit your trainer"
- Plans on your other characters count too, if you use Syndicator: "Mega has Plans: Thorium Boots (bank): mail it to this character"
- New plans that help you level, and only those. Every new Forever plan with a known seller was run through a 1–300 simulation, and the ones that make the climb cheaper are in:
  - Blacksmithing: the Sabatons, Waistguard and Wristguard(s) of the Officer's, Sentinel's, Warder's, Prefect's and Justicar's sets, and the Arcanite Blacksmith Hammer, from the trade camps for Merchant's Favor (Gor'mak west of the Crossroads, Stondry Darkhammer at Three Corners, Redridge)
  - Leatherworking: Forceful Thick Armor Kit from the trade camps (Pawani, Daniel Stitchsong), and Mystic and Forceful Heavy Armor Kit from Mahu (Thunder Bluff) and Saenorion (Darnassus)
  - Tailoring: Runecloth Cuffs from Pexmit (Mount Hyjal), and the Venomspew and Swarmtender's Cord plus Venomspew Footpads from Mishta (Cenarion Hold, Silithus, Cenarion Circle Honored)
  - Trade camp plans are planned when you have the Favor and the reputation they need. Until then the tooltip says what they cost, what you have and how to earn Favor (Waylaid Crates to Dokimi or Marcy Baker, reputation with Craftsman's Writs). The window shows the Favor a plan spends next to the gold, in red if you don't have that much. Turn off "Use plans bought with Merchant's Favor" in the options to keep your Favor for other things
- The plan header now says roughly how long the crafting takes, like "Plan: 142 crafts, about 12 min", from each recipe's cast time
- Magnus Frostwake's plans explain that you need the Spectral Essence from the Scholomance quest chain to see him
- Right after a profession window opens, the game can give an empty profession (no name, 0/0), which left the window without a plan. The addon now works out the profession from the window's recipes and takes your skill from your character's profession list
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
