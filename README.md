# FUSE

Working title for a modern **2.5D bomb-arena action game** (Atomic Bomberman-inspired),
built in **Godot 4.7.2**. Windows first, Android after.

> **Status: M1 complete — grey-box playable.**
> A full 1P-vs-CPU or 2P-local match runs on a 15×13 arena with bombs, chain reactions,
> destructible crates, pickups, sudden death and a results screen. Characters, bombs,
> fire and pickups are code-built **grey-box meshes** with procedural motion (walk bob,
> start squash, fuse pulse, blast rise/fall, elimination flatten) — no character art,
> no audio and no menus yet. See [`docs/PROGRESS.md`](docs/PROGRESS.md) for exactly
> what exists and what does not.

![Grey-box match](docs/screenshots/m1-gameplay.png)

*Real captured frame from `--shot` mode (`build/shots/m1-final2.png`), tick 362:
two fighters, one armed bomb, six blast tiles, one pickup.*

---

## Requirements

- Godot **4.7.2** (standard build, not .NET)
- Windows 10/11 for development
- Blender 4.x only when working on real art (not needed until M3)

The engine used by this project is installed at:

```
%LOCALAPPDATA%\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe
```

Use the **console** executable for command-line work:

```
%LOCALAPPDATA%\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe
```

The GUI executable does not attach stdout or return exit codes to PowerShell, which
breaks test automation.

## Play

```powershell
cd "C:\Users\ALMASA\OneDrive\Documents\Default Project\fuse"
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe" --path .
```

| Input | Action |
| --- | --- |
| `W A S D` + `Space` | Player 1 move / drop bomb |
| Arrow keys + `Enter` | Player 2 move / drop bomb |
| Gamepad left stick or D-pad + `A`/`X` | Player 1 or 2 (pad order) |
| `1` / `2` | One player vs CPU / two players local (restarts the match) |
| `R` | Restart the match |
| `Esc` | Pause / resume |

The default mode is **1P vs CPU**: an AI opponent reads the same public simulation
state a client sees and issues ordinary move/bomb commands. It plans timed escape
routes, so it will not walk along its own blast lane.

## Run the tests

```powershell
cd "C:\Users\ALMASA\OneDrive\Documents\Default Project\fuse"
$godot = "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --script res://tests/run_tests.gd
```

Expected: `37 test(s), 201 assertion(s), 0 failure(s)` then `PASS` and exit code `0`.
Add `-- --verbose` to list each test by name.

Architecture guard (fails if `src/core` ever touches nodes, input, audio or the clock):

```powershell
powershell -ExecutionPolicy Bypass -File tools/check_core_boundaries.ps1
```

AI self-play smoke test (proves a match actually resolves; prints bombs, explosions,
crates, pickups, eliminations):

```powershell
& $godot --headless --path . --script res://tools/ai_selfplay.gd
# optional diagnostics:  ... --script res://tools/ai_selfplay.gd -- trace
```

Expected: `PASS`, exit code `0`, roughly 50+ bombs, 50+ crates and a winner.

## Screenshots

Shot mode fast-forwards a seeded AI-vs-AI match, waits for a frame that contains
bombs, fire and at least two living fighters, then writes a PNG and quits:

```powershell
New-Item -ItemType Directory build\shots -Force | Out-Null
$shot = (Resolve-Path build\shots).Path + "\m1.png"
& $godot --path . --resolution 1600x900 -- --shot=$shot --shot-ticks=360 --seed=4242
```

Flags (after `--`): `--shot=<path>`, `--shot-ticks=<n>` (default 480), `--seed=<n>`.

Two PowerShell helpers inspect a capture without opening it:

```powershell
powershell -ExecutionPolicy Bypass -File tools/preview_png.ps1 build\shots\m1.png 108 40
powershell -ExecutionPolicy Bypass -File tools/analyze_png.ps1 build\shots\m1.png
```

`preview_png.ps1` prints an ASCII luminance map; `analyze_png.ps1` reports accent
colours (player/fire/text) and their screen positions.

## Layout

| Path | Purpose |
| --- | --- |
| `src/core/` | Pure simulation: grid, rules, arena, match state, events. No nodes, scenes, audio, input, clock or `await`. |
| `src/render/` | Grey-box 3D views (arena, player, bomb, blast, pickup), palette/materials, camera rig. Read-only over sim state. |
| `src/input/` | Keyboard/gamepad → `{dir, bomb}` commands. The only device-aware layer. |
| `src/ai/` | Deterministic command-emitting opponent (normal match participant). |
| `src/app/` | Game shell: fixed-tick driver, lighting, shot mode. |
| `src/ui/` | HUD: phase banner, clock, per-player stats, controls hint. |
| `scenes/` | `main.tscn` entry scene. Menu/lobby/adventure scenes arrive M2–M4. |
| `tests/` | Headless tests and golden state hashes. |
| `tools/` | Self-play, golden-hash dump, core boundary guard, PNG analysis. |
| `docs/` | Technical design, progress log, screenshots. |
| `src/online/`, `server/` | Prediction/reconciliation and authoritative server (M5, not present yet). |

## Docs

- [`docs/TECHNICAL_DESIGN.md`](docs/TECHNICAL_DESIGN.md) — stack decision, architecture, netcode, roadmap, risks.
- [`docs/PROGRESS.md`](docs/PROGRESS.md) — verified status, test results, next steps.

## Related project

`../blast-arena/` is an earlier **web** prototype (React Three Fiber + Colyseus). It is
untouched and kept as a reference for rules, match flow, and networking behavior. It is
not the codebase for this game.
