# FUSE — progress log

Updated: 2026-10-31
Environment: Windows 11 · Godot 4.7.2 stable · Python 3.12 · Node 24 · Git
Project: `C:\Users\ALMASA\OneDrive\Documents\Default Project\fuse`

**Status: M0 complete (verified). M1 (grey-box playable) not started.
No scenes, rendering, audio or UI exist yet.**

---

## Done and verified

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
- Original `icon.svg`.
- `.gitignore` excludes `.godot/`, builds, exports, Blender backups.

### 3. Headless test harness (zero addons)

- `tests/run_tests.gd` recursively discovers `tests/test_*.gd`, runs every `test_*`
  method, prints failures, exits `1` on any failure. `-- --verbose` prints each test name.
- `tests/case.gd` provides `check`, `eq`, `near`.
- Failure path proven with a deliberate failing probe (printed the failure, `EXIT=1`);
  probe removed.

### 4. Simulation core (M0)

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

Behavior contracts that the tests pin down:

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

### 5. Test results (M0 gate)

```
35 test(s), 190 assertion(s), 0 failure(s) in 755 ms
PASS
EXIT=0
```

Command:

```powershell
$godot = "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --script res://tests/run_tests.gd
```

Golden hashes locked in `tests/test_golden.gd` (regenerate with
`tools/dump_golden_hash.gd` only when a simulation change is intentional):

| Scenario | Hash |
| --- | --- |
| seed 4242, 600 ticks, scripted commands | `3530677916` |
| seed 4242, 200 ticks, idle | `1752669574` |
| seed 4242, 200 ticks, scripted | `4161587804` |

Soak: 10,000 ticks with 4 players and no scene tree, under the 5 s budget
(measured in the same test run).

### 6. Architecture guard

`tools/check_core_boundaries.ps1` greps `src/core` for scene-tree access, node types,
`Input`, audio, scene preloads, wall-clock time, unseeded randomness and `await`.
Result: **passed (11 files)**.

### 7. Documentation

- `docs/TECHNICAL_DESIGN.md` — stack decision, architecture, netcode, budgets, roadmap, risks.
- `README.md` — how to run, layout, status.

---

## Bugs found and fixed while getting M0 green

1. Several `:=` inferences failed on untyped engine API returns (`rng.next_int`,
   `take_events()`); replaced with explicit types.
2. `ArenaLayout.generate` needed an explicit `Vector2i` for the spawn-pocket point.
3. Blast-lifetime test was off by one tick: the placement step already consumes a fuse
   tick, so the helper now steps `fuse - 1` times after placement.
4. Spawn-pocket test asserted border tiles stay floor; the generator correctly keeps the
   outer wall, so the test now checks interior tiles only.

---

## Not implemented (do not assume otherwise)

- No scenes, camera, lighting, materials, characters, animation, VFX, or audio.
- No input mapping, UI/HUD, save system, local multiplayer, or networking.
- No AI opponents.
- No Blender assets or `.glb` files.
- No adventure content, bosses or progression.

---

## Known issues / watch items

1. Project lives under OneDrive. Exclude `fuse/.godot/` and `fuse/build/` from sync, or
   move `fuse/` to a non-synced path before heavy asset work.
2. No art tool installed yet (Blender required at M3; not blocking M0/M1).
3. No git remote/CI yet; local repo only. Boundary script is ready for CI.
4. `blast-arena/` (earlier web prototype) is untouched and remains a rules/netcode reference.
5. Running the Godot console binary in the foreground from some shells can stall on this
   machine; capturing output to a file or running it in the background works reliably.

---

## Next: M1 — grey-box playable

1. `scenes/main.tscn` + app root: fixed-tick driver, camera rig, world environment.
2. `MultiMeshInstance3D` arena (floor/wall/crate) rebuilt from `MatchSim.grid`, with
   crate-removal updates from `SimEvent.CRATE_DESTROYED`.
3. Views for players, bombs, blasts and pickups driven only by sim state and events,
   with real animation (bob, pulse, fuse flash, blast fade).
4. Input router: P1 WASD+Space, P2 arrows+Enter, gamepad support, pause/restart.
5. HUD: phase banner, match clock, per-player stats, controls.
6. Simple deterministic-command AI for a 1-player match.
7. Verify by running the game and capturing screenshots; no visual claims without them.

Acceptance for M1: a full local match is playable and looks correct in screenshots,
with zero engine errors and the M0 tests still green.
