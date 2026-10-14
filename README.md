# Football Manager (Godot)

A football management simulation game for Godot 4: pure-GDScript engine
(players, tactics, minute-by-minute match sim, seasons, transfers, training,
persistence, mod loading) with a landscape club-command UI.

Ported from the Kotlin/Android `football-manager` project. See
`docs/godot-migration.md` for the module map, deliberate engine differences,
and the test parity checklist.

## Open & run

1. Godot 4.x → Import → select `project.godot`.
2. Press F5. Boots a LaLiga career from `data/laliga.json`.
3. Rail switches Dashboard / Squad / Tactics / Match / League / Transfers.
   The top-bar button advances (matchday, rest day, or season rollover).

## Tests

GUT is vendored under `addons/gut` (MIT, © Tom "Butch" Wesley).
In-editor: GUT dock → run `tests/`. Headless: see CI.

## Layout

- `scripts/model/` — domain types (player, club, game, transfers, …)
- `scripts/sim/` — tactics, lineup, match engine, results
- `scripts/season/` — fixtures, standings, season state/runner
- `scripts/calculator/` — ratings, valuation, wages, development
- `scripts/usecase/` — one file per gameplay operation
- `scripts/persistence/` — JSON saves + named slots + validation
- `scripts/mod/` — community JSON database loader
- `scripts/seed/` — deterministic demo-world generator
- `scripts/core/` — seeded RNG + ISO-date helpers
- `scripts/app/` + `ui/` — autoload state + code-built landscape UI
- `data/` — bundled league databases (`laliga.json`, `sample-mod.json`)
- `tests/` — GUT engine tests
