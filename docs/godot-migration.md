# Godot Migration (Kotlin → GDScript)

Port of `football-manager` (Kotlin/Android) to Godot 4. GDScript can be opened
directly in the Godot editor — no Gradle, no Android SDK.

## Open & run

1. Godot 4.x → Import → select `project.godot`.
2. Press F5. The game boots a LaLiga career (`data/laliga.json`) and shows
   the dashboard. Rail switches sections; the top-bar button advances.
3. Target is landscape (1280×720 base, `canvas_items` + `expand` stretch;
   `display/window/handheld/orientation=4` = sensor landscape on export).

## Layout

| Kotlin (`football-manager/`) | Godot (`fm-godot/`) | Status |
|---|---|---|
| `engine/.../model/*` | `scripts/model/*` | Ported (faithful) |
| `engine/.../simulation/{Tactics,Team,Lineup,MatchEvent,MatchStats,MatchResult}` | `scripts/sim/*` | Ported (faithful) |
| `engine/.../simulation/MatchEngine.kt` | `scripts/sim/match_engine.gd` | Ported (faithful) |
| `engine/.../simulation/season/*` | `scripts/season/*` | Ported (faithful) |
| `engine/.../calculator/*` | `scripts/calculator/*` | Ported (faithful) |
| `engine/.../usecase/*` (16) | `scripts/usecase/*` | Ported (faithful) |
| `engine/.../serialization/*` | `scripts/persistence/save_game.gd` | Reimplemented on `FileAccess`+`JSON` (same field names where cheap) |
| `engine/.../mod/*` | `scripts/mod/mod_loader.gd` | Ported (faithful) |
| `engine/.../seed/SeedData.kt` | `scripts/seed/seed_data.gd` | Ported (faithful) |
| `engine/.../seed/LaLigaData.kt` | `data/laliga.json` | Reused as-is via ModLoader (not rewritten) |
| `engine/.../repository/*` | folded into `SaveGame` + `Game` | Reimplemented |
| `engine/.../graphics/GraphicsPack.kt` | not ported | Future: Godot `ResourceLoader` pack |
| `engine/.../logging/*` | `MatchEngine.verbose` flag | Reimplemented (NoOp default) |
| `app/...` (Compose UI, 28 files) | `scripts/app/` + `ui/main.tscn` | Ported: menu-first boot, new-career wizard, dashboard command center, sortable squad table + inspector + training, tactics (formation/axes/pitch/bench swap/auto XI), match centre (preview/result/timeline/stats/ratings), full standings + your-season strip, transfers (market/inspector/sell/history + buy/sell), slot save/load dialog |
| `app/.../GameViewModel.kt` | `scripts/app/game_state.gd` (autoload `AppState`) | Ported responsibilities (advance, tactics, lineup, training, transfers, save/load, navigation state) |
| Engine + app tests (44 files) | `tests/test_engine.gd` (GUT) | Written, NOT executed (no Godot binary/GUT here): ratings math, attribute clamp, 90-fixture double round-robin, seeded engine determinism, mod load counts, transfer balance math |
| Engine + app tests (44 files) | — | NOT ported. Needs GUT + Godot binary (neither available here). Manual parity checklist below |

## Deliberate behavior notes (parity-critical)

- **PRNG differs**: Godot `RandomNumberGenerator` ≠ Kotlin `Random`. Same seeds do
  NOT reproduce Kotlin sequences. Determinism holds within the Godot build only.
- **Mutability**: Kotlin immutable data classes are mutable `RefCounted`s here.
  `SeasonState.duplicate()/set_*` return new states sharing element refs.
- **Exceptions → asserts**: Kotlin `require`/`error` become `push_error + assert`
  (stripped in release — release continues with partial data).
- **Rating quirk preserved**: `(rating * 10).roundToInt() / 10.0.coerceIn(1.0, 10.0)`
  divides by 10.0 (the coerce binds the literal, so no 1..10 clamp). The port does
  `round(rating * 10.0) / 10.0` with a PARITY comment — identical numbers.
- **IDs**: Kotlin `Long` → Godot 64-bit `int`. Null ids → `-1` sentinel.
- **Dates**: ISO `"YYYY-MM-DD"` strings (`FMDate.add_days/days_between`); string
  comparison is chronological.
- **Two Fixture types**: model `Fixture` → `CalendarData.ModelFixture` (inner class);
  season fixture → `SeasonFixture` (distinct class_name).
- **Bid/contract flow**: engine use-cases ported and unit-covered in Kotlin, but —
  as in the Android app — the UI exposes direct transfers only.

## Parity checklist (for GUT, when a Godot binary is available)

1. `PlayerAttributes.overall(ST)` on a known player equals the Kotlin value
   (weights copied verbatim; spot-check ST/CB/GK).
2. `PlayerCalculator.calculate_effective_overall` at fitness 100/morale 50 equals
   base × 1.0 × 1.0 (morale factor 0.90 + 0.20×0.5 = 1.0).
3. `FixtureGenerator` on 10 clubs → 90 fixtures, every pair twice, round grouping
   identical to `FixtureGeneratorTest` expectations.
4. `SeasonRunner.play_next_matchday` == `SeasonSimulator` full-season table for the
   same seed (mirror of `SeasonRunnerTest`).
5. `DirectTransfer` balance/budget math and history record (mirror VM transfer tests).
6. Save → load round-trip preserves clubs/players/season/results.

## Verification status

- GitHub Actions CI (`.github/workflows/ci.yml`, Godot 4.5.1 + GUT v9.5.0):
  **passing** — headless import, per-file parse-check, 6/6 GUT tests
  (`tests/test_engine.gd`), headless boot smoke test with zero script errors.
- Fixed along the way from real CI logs: autoload/class_name clash, `get()`
  override (renamed `attr_value`), `from_dict` arity, `Array = null` defaults,
  `take_last` → `slice`, dialog `mode` clash, datetime weekday flag, GUT/4.5
  version pairing.
- Not yet done: on-device/emulator visual check and Android export
  (keystore + templates) — both need a machine with Godot/a device, neither
  available to the porting agent.
