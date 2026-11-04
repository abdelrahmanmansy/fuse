# FUSE — progress log

Updated: 2026-11-04
Environment: Windows 11 · Godot 4.7.2 stable · Python 3.12 · Node 24 · Git
Project: `C:\Users\ALMASA\OneDrive\Documents\Default Project\fuse`

**Status: M1 complete (verified). A grey-box local match is playable end to end.
No audio, menus, or art assets exist yet.**

| Milestone | State |
| --- | --- |
| M0 foundation | ✅ complete, committed `f9742e7` |
| M1 grey-box playable | ✅ complete, verified (tests, self-play, captured frame) |
| M2 local versus polish | ⬜ next |
| M3 vertical slice | ⬜ not started |
| M4 adventure campaign | ⬜ not started |
| M5 online beta | ⬜ not started |
| M6 release | ⬜ not started |

---

## M1 — grey-box playable (verified)

### What a player can do

- Launch the project and immediately play a full match on a generated 15×13 arena.
- **1P vs CPU** (default) or **2P local** (`1` / `2` to switch modes).
- Move in cardinal directions with buffered input, drop bombs, chain-detonate them,
  destroy crates, collect four pickup types (extra bomb, range, speed, kick).
- Spawn guard, sudden death (world bombs after the 150 s clock), draw handling,
  results banner, `R` restart, `Esc` pause.
- Keyboard for both players, plus gamepad (left stick / D-pad, `A` or `X` to bomb).

### Presentation layer (`src/render`, `src/ui`, `src/app`)

| File | Responsibility |
| --- | --- |
| `src/app/main.gd` | Fixed-tick driver (60 Hz, max 4 catch-up steps), world environment, key/fill lights, camera wiring, event → camera shake, shot mode. |
| `src/render/arena_style.gd` | Single source of truth for palette, player colours, tile→world conversion (tile size 2.0), materials. |
| `src/render/arena_view.gd` | `MultiMeshInstance3D` floor/wall/crate build; incremental crate refresh on `CRATE_DESTROYED`. |
| `src/render/player_view.gd` | Capsule body, facing visor with smoothed yaw, walk bob, start-of-step squash, spawn-guard shimmer, elimination flatten/fade. Driven by fixed-point `visual_position()`. |
| `src/render/bomb_view.gd` | Sphere + pulsing emissive fuse flash, scale pop on placement, slide offset when kicked. |
| `src/render/blast_view.gd` | Per-tile fire column with rise/fall driven by blast age. |
| `src/render/pickup_view.gd` | Floating, spinning icon per pickup type, colour-coded. |
| `src/render/camera_rig.gd` | Auto-fit orthographic-ish perspective camera at 56° elevation, fov 50, followed by decaying shake. |
| `src/ui/hud.gd` | Phase banner (`READY`/countdown/`GO!`/winner/`DRAW`), match clock, per-player stat panels, controls hint, pause overlay. |
| `src/input/input_router.gd` | Keyboard + gamepad → `{dir, bomb}`; edge-detects bomb/pause/restart/mode keys. |
| `src/ai/simple_ai.gd` | Deterministic opponent: danger map of armed bombs **and burning blast tiles**, time-aware escape BFS, plant only when a safe route exists after the new bomb, crate/enemy objectives, seeded roaming. |

Design rule kept intact: views read simulation state and never write it; the simulation
still has no node, input, audio or clock access (guard script enforces this).

### Verification evidence

Headless suite:

```
37 test(s), 201 assertion(s), 0 failure(s) in 509 ms
PASS
EXIT=0
```

Architecture guard:

```
core boundary check passed (11 file(s))
EXIT=0
```

AI self-play, seed `20261031`, 4 players (`tools/ai_selfplay.gd`):

```
AI self-play: ticks=2768 phase=4 winner=2
  bombs=51 explosions=48 crates=59 pickups=19 eliminations=3 first_elim=1667
  final alive=["0:false", "1:false", "2:true", "3:false"] crates_left=0
PASS
EXIT=0
```

Captured frame, `docs/screenshots/m1-gameplay.png` (from shot mode, seed 4242,
1600×900, `--shot-ticks=360`):

```
shot state: tick=362 phase=2 bombs=1 blasts=6 pickups=1 eliminations=0
  player 0 tile=(1, 1) alive=true stats=1/2/0 kick=false
  player 1 tile=(12, 1) alive=true stats=1/2/0 kick=false
  on screen: player 0 -> (507.96, 237.35)
  on screen: player 1 -> (1069.61, 237.35)
shot saved: ...\m1-final2.png (err=0)
```

Independent pixel checks on that PNG: cyan P1 body at `(508,237)` = `R94 G226 B255`,
coral P2 body at `(1069,237)` = `R255 G143 B127`, HUD text present, mean luminance
61.0 (up from 56.4 before the palette/lighting pass). Both fighters and live fire are
therefore confirmed in the actual rendered image, not just in simulation state.

### Bugs found and fixed during M1

1. **Buffered direction was never cleared.** Releasing a key kept the last direction
   queued, so players (and the AI) could not stop on a tile. ZERO input now clears the
   buffer; regression test added in `tests/test_movement.gd`.
2. **AI retreated along its own blast lane.** It planted at `(3,2)` then walked to
   `(1,2)`, still inside its range-2 lane, and died. Replaced naive fleeing with a
   time-aware escape-route BFS and a "do not plant without an exit" rule.
3. **AI could never stand still to plant.** It always had buffered movement, so the
   plant branch was unreachable. It now returns ZERO when the tile it is entering is a
   valid firing position.
4. **AI walked into still-burning blast tiles.** Danger tracking only looked at armed
   bombs; once a bomb was removed its fire was invisible to the planner. Active blasts
   now contribute their remaining lifetime to the danger map.
5. **Self-play stalled with two bots circling empty corners.** Added enemy-chase
   fallback; the match now always resolves.
6. **Shot retries replayed the identical deterministic match**, producing `tick=0`
   frames. Retries now advance the seed.
7. **Blasts froze mid-burn on the results screen.** `RESULTS` now ticks blasts so the
   final explosion fades; test added in `tests/test_match.gd`.
8. **Debug screen coordinates were in 1920×1080 design space** while the PNG was
   1600×900; the print now scales by image/viewport size.

---

## M0 — foundation (verified, committed)

### 1. Environment audit

| Tool | Result |
| --- | --- |
| Godot | not installed → installed 4.7.2 stable to `%LOCALAPPDATA%\Programs\Godot\4.7.2` |
| .NET | not installed → GDScript only |
| Blender | not installed → needed at M3 for the art pipeline |
| Python / Git / Node | present (3.12 / 2.x / 24) |
| Disk free | ~86 GB |

Verified: `godot --headless --version` → `4.7.2.stable.official.ed1daf0bf`.

Windows CLI note: use `Godot_v4.7.2-stable_win64_console.exe`. The GUI exe does not
attach stdout or return an exit code to PowerShell.

### 2. Project bootstrap

- `project.godot`: 1920×1080 design space, `canvas_items` stretch, Forward+ desktop /
  Mobile renderer for Android, 60 Hz physics, 4K directional shadow, MSAA 2×.
  `run/main_scene` is `res://scenes/main.tscn`.
- Original `icon.svg`.
- `.gitignore` excludes `.godot/`, builds, exports, Blender backups.

### 3. Headless test harness (zero addons)

- `tests/run_tests.gd` recursively discovers `tests/test_*.gd`, runs every `test_*`
  method, prints failures, exits `1` on any failure. `-- --verbose` prints each test name.
- `tests/case.gd` provides `check`, `eq`, `near`.
- Failure path proven with a deliberate failing probe (printed the failure, `EXIT=1`);
  probe removed.

### 4. Simulation core

Pure `RefCounted` scripts, no nodes, no clock, no input, no audio:

| File | Responsibility |
| --- | --- |
| `src/core/sim/grid.gd` | tile grid, ASCII parse/serialize, bounds, walkability |
| `src/core/sim/rng.gd` | xorshift32 PRNG (32-bit safe, reproducible) |
| `src/core/sim/dirs.gd` | deterministic cardinal iteration order |
| `src/core/sim/sim_event.gd` | typed one-shot outcomes for VFX/SFX/netcode |
| `src/core/sim/player_sim.gd` | fixed-point tile stepping, stats, occupancy |
| `src/core/sim/bomb_sim.gd` | fuse + slide state, visual position |
| `src/core/sim/blast_cell.gd` | blast tile + creation tick |
| `src/core/sim/pickup.gd` | floor loot |
| `src/core/rules/ruleset.gd` | all tuning values (tick-based, tick-rate independent tests) |
| `src/core/arena/arena_layout.gd` | ASCII layouts, spawn validation, seeded generator |
| `src/core/sim/match_sim.gd` | authoritative match: phases, movement, bombs, chains, crates, pickups, damage, sudden death, results, `state_hash()` |

Behavior contracts pinned by tests:

- Fixed 60 Hz integer ticks; movement in fixed-point units (1024 = 1 tile); base speed
  crosses a tile in 19 ticks and carries the remainder across chained tiles.
- Input is command-in: `submit_command(player_id, dir, bomb)`, last write per tick wins;
  outcomes come out as ordered `SimEvent`s via `take_events()`.
- Bomb fuse starts at 144 ticks (2.4 s) and is decremented on the placement tick;
  a blast covers exactly `blast_ticks` (27) ticks.
- Blasts stop on walls, are absorbed by crates (which can drop loot), and chain-detonate
  bombs in the same tick.
- Players are vulnerable on both tiles while between two tiles; spawn guard and
  simultaneous-death draws are handled.
- Sudden death drops world-owned bombs on a fixed interval after the match clock expires.
- `state_hash()` is 32-bit FNV-1a over tick/phase/players/bombs/grid/blasts/pickups/RNG —
  no floats, no wall clock.

### 5. Golden hashes

Locked in `tests/test_golden.gd` (regenerate with `tools/dump_golden_hash.gd` only when
a simulation change is intentional):

| Scenario | Hash |
| --- | --- |
| seed 4242, 600 ticks, scripted commands | `3530677916` |
| seed 4242, 200 ticks, idle | `1752669574` |
| seed 4242, 200 ticks, scripted | `4161587804` |

Soak: 10,000 ticks with 4 players and no scene tree, under the 5 s budget.

---

## Not implemented (do not assume otherwise)

- No audio at all (music, SFX, mix).
- No menus, lobby, settings, pause menu beyond the overlay, or gamepad rebinding UI.
- No character models, textures, rigs, animation clips or VFX sprites — all geometry is
  grey-box primitives built from code. No `.glb`/`.blend` assets exist.
- No adventure content, world map, bosses or progression.
- No online play: no ENet transport, prediction, reconciliation, matchmaking or server.
- No Android build/export, no localization files yet (AR/EN planned from M2 onward).
- No save system, unlocks, or profiles.

## Known issues / watch items

1. Project lives under OneDrive. Exclude `fuse/.godot/` and `fuse/build/` from sync, or
   move `fuse/` to a non-synced path before heavy asset work.
2. Blender is not installed (required at M3).
3. No git remote/CI yet; local repo only. Boundary script is ready for CI.
4. `blast-arena/` (earlier web prototype) is untouched and remains a rules/netcode reference.
5. Running the Godot console binary in the foreground from some shells can stall on this
   machine; capturing output to a file or running it in the background works reliably.
6. The grey-box frame means luminance 61.0 and reads dark on some displays; the final
   art pass in M3 replaces palette and lighting anyway.
7. The AI is a fairness-neutral test opponent, not a designed difficulty curve.

---

## Next: M2 — local versus

1. Replace the instant-boot shell with a real front end: title → mode select (1P/2P) →
   arena/character pick → match → rematch. Keyboard and gamepad navigation.
2. Round/series scoring (best-of-N), per-player win tally, rematch flow on results.
3. Pause menu (resume, restart, quit to menu) instead of the current overlay only.
4. Settings screen: volume stubs, screen mode, input display; persist to `user://`.
5. Basic SFX layer wired to `SimEvent`s (place, explode, pickup, hit, win) with
   placeholder audio files.
6. Expand the test suite to cover mode/scene transitions and settings persistence.
7. Add Arabic + English string tables for all UI added in M2.
