# Foxden architecture

Features are added as files, not by editing the core.

## Layout

| Folder | What lives there |
|---|---|
| `Core/Core.lua` | Saved data, starting and finishing runs, resuming after `/reload`, the module and status-line registries, slash commands. |
| `Core/Comm.lua` | One paced queue (`ns.Send`) for every hidden addon message, under the game's per-prefix limit; retries throttled sends. |
| `Core/Json.lua` | JSON encoder for runs leaving the game (`ns.RunCode` for the copy box, `ns.RunForTransfer` for the relay; path thinned to 400 points). |
| `Core/Style.lua` | The look: colors, text, buttons, switches, steppers, formatting. Takes accent and font from EllesmereUI when present. |
| `Modules/` | **Recorders.** Each one watches its own game events and writes its own fields on the run. |
| `UI/Window.lua` | The `/fox` dashboard: resizable window, sidebar, page registry (`ns.RegisterPage`), view registry. |
| `UI/Widgets.lua` | Scrolling list, search box, copyable link box, filter chips. |
| `UI/Pages/` | **Pages** in the sidebar: Overview, Runs, Journal, Players (Dungeon log); Shop, Costs, Crafters, Orders (Crafting). |
| `Core/Stats.lua` | Dungeon, player and total statistics from the runs saved in this game. |
| `Data/SiteData.lua` | Written by the companion: the website's shop, costs and your open orders (`FoxdenSiteData`). Read on /reload. |
| `UI/StatPanel.lua` | Stat tabs + class-colored bars, reused by views. |
| `Views/` | **Tabs** in the run detail (Overview, Fights, ...). |
| `UI/Settings.lua` | Settings > AddOns page. |
| `Modules/Relay.lua` | Hands finished runs to a guildmate whose companion is set up (a "courier"); couriers store them in `FoxdenDB.relay`. |
| `Modules/Atlas.lua` | Where each zone sits on its continent (names + rectangles from the game's map data, `FoxdenDB.atlas`), so the website can draw its own map. |
| `UI/CopyRun.lua` | The copy box after a run (`/fox copy`): `FOXDEN1:{json}` for the website's Post a run page. |

## Add a recorder

Create `Modules/Thing.lua` and list it in the `.toc` under the other modules:

```lua
local _, ns = ...
ns.RegisterModule({
  name = "Thing",
  OnRunStart  = function(self, run) run.thing = {} end,
  OnCombatEnd = function(self, run) end,   -- meter has settled after a fight
  OnRunFinish = function(self, run) end,   -- last chance before the run is saved
  Migrate     = function(self, run, fromSchema) end,
  events = {
    SOME_EVENT = function(self, run, ...) if not run then return end ... ns.Changed() end,
  },
})
```

- `run` is `nil` outside a dungeon; check it.
- Keys starting with `_` (e.g. `run._thing`) are scratch space and are not saved with the finished run.
- Values the client marks secret must be skipped: `ns.IsSecret(v)`.
- A hook that errors is reported and isolated; the other modules keep working.

## Add a page

Create `UI/Pages/Thing.lua`, list it in the `.toc` with the other pages:

```lua
local _, ns = ...
ns.RegisterPage({
  key = "thing", label = "Thing", section = "log" or "craft", order = 45,
  Build   = function(self, frame) ... end,      -- once, the first time it's opened
  Layout  = function(self, w, h) ... end,       -- on open and every resize
  Refresh = function(self, arg) ... end,        -- data changed / page opened
})
```

## Add a view

Create `Views/Thing.lua`, list it in the `.toc` after `UI/Window.lua`:

```lua
local _, ns = ...
ns.RegisterView({
  key = "thing", label = "Thing", order = 30,
  Build   = function(self, pane, width, height) ... end, -- once
  Refresh = function(self, entry) ... end,               -- entry.run, entry.live
})
```

## Changing the saved shape of a run

Bump `ns.SCHEMA` in `Core/Core.lua` and upgrade old runs in the owning module's `Migrate`. Views should still cope with fields missing on old runs.

| Schema | Change |
|---|---|
| 1 | First release: totals only. |
| 2 | `run.segments`: one entry per fight with its own stats. Modules split out of the core. |
| 3 | `run.route`: floors visited, boss pins, and your own path where the game allows it (Modules/Route.lua). |

## Saved run fields

| Field | Owner |
|---|---|
| `id, schema, dungeon, difficulty, instanceID, startTime, endTime, duration, endReason, loggedBy, addonVersion, lastSeen` | Core |
| `party` | Party |
| `bosses, wipes` | Bosses |
| `stats, segments, combatSeconds, fights` | Meter |
| `route` | Route |
| `relayedTo, relayedAt` | Relay (sender side: which courier took it) |

Not part of a run: `FoxdenDB.journal` (Modules/Journal.lua: the game's Encounter Journal, re-read after patches or with `/fox journaltest`), `FoxdenDB.crafting` (professions, inventory, guild crafters).

The companion app reads these from SavedVariables; new fields pass through to `raw` mode untouched.
