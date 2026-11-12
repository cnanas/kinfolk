# Kinfolk

A guild companion addon for WoW Forever. It logs your dungeon runs, keeps a dungeon journal, tracks who in the guild can craft what, and shows the guild roster, all in one resizable window.

Kinfolk works on its own in game. The optional companion app posts each run to your guild's Discord.

## What it does

- **Dungeon log.** Records each run: dungeon and difficulty, total time and time in combat, the party, boss kills, wipes, and per-player totals from the game's built-in damage meter (damage, healing, interrupts, dispels, damage taken, deaths). Only one person in the group needs the addon.
- **Journal.** Every dungeon's bosses, abilities and loot, read from the game's own Encounter Journal.
- **Crafting.** Shares your professions and recipes with guildmates over guild addon messages, so anyone can see who can make what.
- **Roster.** Name, rank, level, class, online status and zone. Guild notes are never collected.
- **Location sharing (optional).** Guildmates who opt in appear as dots on the world map. Positions are never shared from inside instances.

The first time you log in, Kinfolk asks what you want to share. Nothing is sent until you choose **Save and start**. Type `/kin welcome` to change your choices later.

## Install

1. Download this repository and copy the `Kinfolk` folder into your AddOns folder:
   `World of Warcraft/_forever_/Interface/AddOns/Kinfolk`
   The path should end in `AddOns/Kinfolk/Kinfolk.toc`.
2. Launch the game and make sure **Kinfolk** is enabled in the AddOns list.
3. If the AddOns list says it's out of date, check **Load out of date AddOns**.

## Commands

- `/kin`: open the window (also in the minimap addon menu)
- `/kin options`: settings
- `/kin status`: current run progress
- `/kin end`: finish the current run without leaving the dungeon
- `/kin sync`: reload so the run is saved to disk (and posted, if the companion is running)
- `/kin welcome`: change what you share

WoW only writes saved data to disk on `/reload` or logout, so use `/kin sync` after a run if you want it posted straight away.

## Post runs to Discord (optional)

The companion is a small Node.js app (version 18 or newer) that runs on your computer while you play. It watches Kinfolk's saved data and posts each new run to a Discord channel.

```bash
cd companion
npm install
cp config.example.json config.json
```

Edit `config.json`:

- `savedVariablesFile`: the full path to `Kinfolk.lua` in `WTF/Account/<YOUR ACCOUNT>/SavedVariables/`. It appears after you've logged in once with Kinfolk enabled.
- `webhookUrl`: in Discord, open your channel's settings, then Integrations > Webhooks > New Webhook > Copy Webhook URL. Keep this private.
- `guildName` and `botName`: how posts are labelled.
- Leave `siteUrl` and `siteKey` empty.

Check what it would post with `npm run dry-run`, then leave `npm start` running while you play. It remembers what it has posted, so nothing is posted twice.

## Guild websites: coming soon

Some pages in the window (Shop, Costs and Orders) need a guild website: a shop with fair crafting prices from the auction house, craft orders paid in game by cash-on-delivery mail, a shared boss journal with tips from your guild, and run pages. Guild websites are coming soon as a service. Everything else in Kinfolk works without one.

## Gold only

Kinfolk's crafting features are for in-game gold between guildmates on the same realm and faction. Never buy or sell gold, items or services for real money. Blizzard bans that.

## License

MIT. See `LICENSE`.
