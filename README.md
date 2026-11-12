# Foxden

A guild companion addon for WoW Forever. It logs your dungeon runs, keeps a dungeon journal, tracks who in the guild can craft what, and shows the guild roster, all in one resizable window.

Foxden works on its own in game. The optional companion app posts each run to your guild's Discord.

## What it does

- **Dungeon log.** Records each run: dungeon and difficulty, total time and time in combat, the party, boss kills, wipes, and per-player totals from the game's built-in damage meter (damage, healing, interrupts, dispels, damage taken, deaths). Only one person in the group needs the addon.
- **Journal.** Every dungeon's bosses, abilities and loot, read from the game's own Encounter Journal.
- **Crafting.** Shares your professions and recipes with guildmates over guild addon messages, so anyone can see who can make what.
- **Roster.** Name, rank, level, class, online status and zone. Guild notes are never collected.
- **Location sharing (optional).** Guildmates who opt in appear as dots on the world map. Positions are never shared from inside instances.

The first time you log in, Foxden asks what you want to share. Nothing is sent until you choose **Save and start**. Type `/fox welcome` to change your choices later.

## Install

1. Get Foxden from CurseForge or Wago (any addon manager works), or download `Foxden-<version>.zip` from this repository's Releases and unzip it into:
   `World of Warcraft/_forever_/Interface/AddOns/`
   The path should end in `AddOns/Foxden/Foxden.toc`.
2. Launch the game and make sure **Foxden** is enabled in the AddOns list.
3. If the AddOns list says it's out of date, check **Load out of date AddOns**.

## Commands

- `/fox`: open the window (also in the minimap addon menu)
- `/fox options`: settings
- `/fox status`: current run progress
- `/fox end`: finish the current run without leaving the dungeon
- `/fox sync`: reload so the run is saved to disk (and posted, if the companion is running)
- `/fox welcome`: change what you share

WoW only writes saved data to disk on `/reload` or logout, so use `/fox sync` after a run if you want it posted straight away.

Not everyone needs the companion: Foxden hands your finished runs to a guildmate who runs it, the next time you're both online. If your guild has a website, you can also paste a run there yourself: Foxden shows it ready to copy after each run (or type `/fox copy`).

## Post runs to Discord (optional)

The companion is a small Node.js app (version 18 or newer) that runs on your computer while you play. It watches Foxden's saved data and posts each new run to a Discord channel.

```bash
cd companion
npm install
cp config.example.json config.json
```

Edit `config.json`:

- `savedVariablesFile`: the full path to `Foxden.lua` in `WTF/Account/<YOUR ACCOUNT>/SavedVariables/`. It appears after you've logged in once with Foxden enabled.
- `webhookUrl`: in Discord, open your channel's settings, then Integrations > Webhooks > New Webhook > Copy Webhook URL. Keep this private.
- `guildName` and `botName`: how posts are labelled.
- Leave `siteUrl` and `siteKey` empty.

Check what it would post with `npm run dry-run`, then leave `npm start` running while you play, or run `npm run sync` afterwards to send everything you missed in one go. It remembers what it has posted, so nothing is posted twice.

## Guild websites: coming soon

Some pages in the window (Shop, Costs and Orders) need a guild website: a shop where guildmates craft for each other for free (you bring the materials), craft requests, a shared boss journal with tips from your guild, and run pages. Guild websites are coming soon as a service. Everything else in Foxden works without one.

## Free crafting, never real money

Crafting through Foxden is free between guildmates: you bring the materials, a guildmate makes it. Never buy or sell gold, items or services for real money; Blizzard bans it.

## License

MIT. See `LICENSE`.
