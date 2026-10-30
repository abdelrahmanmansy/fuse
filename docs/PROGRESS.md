# FUSE — progress log

Updated: 2026-10-30
Environment: Windows 11 · Godot 4.7.2 stable · Python 3.12 · Node 24 · Git
Project: `C:\Users\ALMASA\OneDrive\Documents\Default Project\fuse`

**Status: M0 in progress. No gameplay or rendering exists yet. Nothing visual has been
implemented or verified.**

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
  method, prints failures, exits `1` on any failure.
- `tests/case.gd` provides `check`, `eq`, `near`.
- Failure path proven with a deliberate failing probe: printed the failure and returned
  `EXIT=1`; probe removed.

### 4. First pure-logic slice

- `src/core/sim/grid.gd`: tile grid (`FLOOR`/`WALL`/`CRATE`), bounds, walkability,
  duplicate, ASCII layout parse/serialize, explicit error strings, no engine nodes.

Test run:

```
4 test(s), 21 assertion(s), 0 failure(s) in 20 ms
PASS
EXIT=0
```

Command:

```powershell
$godot = "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --script res://tests/run_tests.gd
```

### 5. Documentation

- `docs/TECHNICAL_DESIGN.md` — stack decision, architecture, netcode, budgets, roadmap, risks.
- `README.md` — how to run, layout, status.

---

## Not implemented (do not assume otherwise)

- No scenes, camera, lighting, materials, characters, animation, VFX, or audio.
- No movement, bombs, explosions, crates-as-entities, power-ups, AI, or match flow.
- No input mapping, UI/HUD, save system, local multiplayer, or networking.
- No Blender assets or `.glb` files.

---

## Known issues / watch items

1. Project lives under OneDrive. Exclude `fuse/.godot/` and `fuse/build/` from sync, or
   move `fuse/` to a non-synced path before heavy asset work.
2. No art tool installed yet (Blender required at M3; not blocking M0/M1).
3. No git remote/CI yet; local repo only.
4. `blast-arena/` (earlier web prototype) is untouched and remains a rules/netcode reference.

---

## Next: M0 completion (ordered)

1. `src/core/rules/ruleset.gd` + tuning constants (tick-based timers, fixed-point speed).
2. `src/core/sim/player_state.gd` + `match_sim.gd` skeleton with command queue and tick loop.
3. Movement + wall/crate collision + corner assist; tests for each axis and blocked corners.
4. Bombs, fuse ticks, directional blast propagation, chain reactions; tests for
   wall blocking, crate absorption, same-tick chains.
5. Crates + power-up drops + pickups; seeded RNG tests (same seed ⇒ same drops).
6. Golden scenario test: text arena + scripted commands → deterministic state hash.
7. CI grep guard: `src/core` must not reference scenes/content/nodes/audio/input.
8. `git init` + first commit; GitHub Actions workflow.

Acceptance for M0: all tests green headless, deterministic golden run, architecture guard
in place, and a `MatchSim` that can run 10,000 ticks without a scene tree.
