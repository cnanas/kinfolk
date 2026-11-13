# Foxden

## 2.2.0

A big one: a simpler window, every Forever dungeon with its bosses, quests and loot, a loot
wishlist, a rare tracker, crafting tools and notes.

### A simpler window
- Four places in the sidebar (**Home, Dungeons, Crafting, Guild**) with tabs, instead of eleven pages. It remembers the tab you used last.
- A **search box** in the header finds any dungeon, boss, quest, loot item or recipe and jumps to it.
- **Home** is about you: dungeons for your level with the quests you can still pick up, what's ready at your trainer, your recent runs, and guildmates online near your level.
- Item and spell **tooltips everywhere** (hover any item; shift-click to link it), and a **minimap button** (click to open, right-click for Settings, shift-click for a note).

### Dungeons
- **Every Forever dungeon and raid**, including the nine new ones, with its full boss list (lists from ForeverDungeonRoutes, MIT). Scarlet Monastery, Blackrock Spire and Dire Maul show as one dungeon with their wings.
- **Bosses:** the boss's model, its loot as real items, the guild's tips and record.
- **Quests:** every dungeon quest with level, Alliance / Horde / both, objectives, rewards, and **map pins** for where to get it and turn it in. Quests show **Done** or **In your quest log**, and Foxden tells you what you haven't picked up when you walk in.
- **Runs:** your guild's runs of that dungeon. Click **I want to run this** to tell guildmates; their wishes show on Home.
- **Dungeon tracker** while you're inside: time, XP gained, gold looted, the bosses as portraits ticked off as you kill them, and how far ahead or behind the guild's best run you are.
- What each boss drops in your runs is recorded, so the journal fills in as the guild plays.

### Loot wishlist
- Star any boss drop as **main spec, off spec or transmog**. Foxden reminds you at the boss, tells you when it drops, and takes it off the list when you get it. Guildmates see who wants what. Home has a Wishlist tab.

### Rare tracker
- Every rare and rare elite with its spawn points (Guild → Rares). Foxden notes when you see or kill one, tells guildmates with a note on screen, and shows when it may be up again from respawn times the guild learns or enters.

### Crafting
- **Recipes:** one list for every recipe with profession, category (pick several), show and sort dropdowns. Each recipe shows where it turns yellow and grey, coloured for your own skill. Pick one for each material's auction price and a total, who can make it, and **Request**, **Whisper** or **Ask the guild**.
- **Leveling planner:** the cheapest way to level a profession at today's prices, with a shopping list that leaves out what's in your bags and bank.
- **Crafting is free:** no fees and no cash-on-delivery. You bring the materials, a guildmate makes it.

### Leveling and trainer
- **Trainer:** visit your class trainer once and Foxden keeps its whole list (what's ready, what's coming, the cost). Right-click to skip an ability; **Learn all** at the trainer learns the rest.
- **Level-up card** with your gains, how long the level took and what's new at your trainer; guildmates see a note when you ding. Every level-up is listed on the Leveling page.

### Notes
- `/fox note` opens a small note window to keep beside you: write, add where you are, take a screenshot. Share it in guild chat, send it to Discord with its screenshots (through the companion), or share its spot as a **guild map pin**.

### Guild
- **Roster map:** guildmates who share their location show on a map of the continent, at the last place they were seen.
- Your runs reach the guild website even without the companion app: Foxden hands them to a guildmate who runs it. `/fox copy` gives a run to paste on the website.

### Also
- Foxden is now **GPL-3.0-or-later** (it was MIT), so it can include data from other open projects; see THIRD-PARTY-NOTICES.md.
- Visits to a dungeon with no fight aren't saved. Guild messages are paced to stay under the game's limit. Windows are solid, and the Settings page scrolls.

## 2.1.0

First public release.

- **Dungeon log:** records each run's dungeon, difficulty, time, party, boss kills, wipes and per-player totals from the game's damage meter.
- **Journal:** every dungeon's bosses, abilities and loot from the game's Encounter Journal.
- **Crafters:** see which guildmates can craft what.
- **Roster:** your guild with rank, level, class, online status and zone, plus optional location sharing on the world map.
- **You choose what to share:** nothing is sent until you answer the welcome popup (`/fox welcome` to change it).
- **Update notice:** tells you once per session when a guildmate has a newer version.
- Commands: `/fox`, `/foxden` or `/fd`.
