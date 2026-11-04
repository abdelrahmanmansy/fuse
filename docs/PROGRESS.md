# FUSE — progress log

Updated: 2026-11-04
Environment: Windows 11 · Godot 4.7.2 stable · Python 3.12 · Node 24 · Git
Project: `C:\Users\ALMASA\OneDrive\Documents\Default Project\fuse`

**Status: M2.5 complete (verified). The game boots into a localized front end (English +
Arabic with RTL), plays a best-of series with local 1P/2P, pause, settings and procedural
SFX, and the arena now reads like classic Bomberman (grass checkerboard, brick pillars,
wooden crates, white-suited fighters, glossy bombs, layered fire). Character art is still
code-built primitives; no music, no external models/textures.**

| Milestone | State |
| --- | --- |
| M0 foundation | ✅ complete, committed `f9742e7` |
| M1 grey-box playable | ✅ complete, committed `4979242` |
| M2 local versus front end | ✅ complete, committed `ee511a0` |
| M2.5 localization + classic art pass | ✅ complete, committed `162e633` |
| M2.6 input & feel pass | ✅ complete, verified (74 tests, 525 assertions) |
| M3 vertical slice | ⬜ next |
| M4 adventure campaign | ⬜ not started |
| M5 online beta | ⬜ not started |
| M6 release | ⬜ not started |

---

## M2.5 — Arabic/English + classic art pass (verified)

### What changed for the player

- **The game looks like Bomberman.** A world-space floor shader paints the classic green
  grass checkerboard with dark tile seams; pillars are terracotta brick; crates are warm
  timber with frames and diagonal braces; fighters wear white suits with coloured helmets,
  gloves and boots, blinking eyes and an antenna; bombs are glossy black spheres with an
  animated angled fuse; explosions layer additive flame cones, ground glow and orbiting
  licks; pickups are emissive icons on rings.
- **The camera reads top-down.** Elevation raised from 56° to **68°**; wall height trimmed
  to 1.45 and stone caps inset to 0.88 tile so the floor stays visible.
- **Arabic ships from day one.** Every title, pause, settings, series and HUD string has
  an Arabic translation; Arabic switches the menu column to RTL; the bundled Noto Sans
  Arabic font provides shaping. English remains the default.
- **Language is a persisted setting**, changed from the title's SETTINGS screen and applied
  immediately (no restart).

### New modules

| File | Responsibility |
| --- | --- |
| `src/app/l10n.gd` | Static AR/EN string tables, `t()` lookup with English fallback, locale normalization. |
| `src/ui/theme_builder.gd` | Builds the default theme: Noto Sans for Latin, Noto Sans Arabic fallback, per-size font overrides. |
| `src/render/floor.gdshader` | One-slab world-space checkerboard: two grass tones, per-tile jitter, grass speckle, dark seams. |
| `src/render/brick.gdshader` | Procedural terracotta brick and mortar. |
| `src/render/crate.gdshader` | Procedural timber planks, dark frame and diagonal braces. |
| `assets/fonts/` | Noto Sans + Noto Sans Arabic (OFL) and their licenses. |
| `tests/test_l10n.gd` | Locale normalization, key coverage AR/EN, placeholder consistency, RTL flag. |

`arena_view.gd` was rewritten around the shaders: one floor slab plus `MultiMesh` layers
for walls, stone caps and crates. `player_view.gd`, `bomb_view.gd`, `blast_view.gd` and
`pickup_view.gd` were rewritten for the classic look and richer procedural motion.

### Captured evidence

All frames are real 1600×900 captures from the running build.

| Capture | What it shows |
| --- | --- |
| `docs/screenshots/m2-title-en.png` | English title block over a live attract match. |
| `docs/screenshots/m2-title-ar.png` | The same screen in Arabic, right-to-left column. |
| `docs/screenshots/m2-settings-en.png` / `-ar.png` | Bilingual settings card with the language row. |
| `docs/screenshots/m2-pause-en.png` / `-ar.png` | Bilingual pause menu. |
| `docs/screenshots/m2-series-en.png` / `-ar.png` | Bilingual results/series card. |
| `docs/screenshots/m2-gameplay-en.png` | Tick 1101, seed 2024: two fighters, bomb, fire and pickups on the checkerboard. |

Pixel check on the gameplay capture: floor tones `(93,165,74)` and `(110,185,91)`
alternate, confirming a visible checkerboard; board composition ~40% stone, ~25% crate,
~16% green floor, ~16% shadow.

### Verification evidence

```
63 test(s), 487 assertion(s), 0 failure(s)
PASS                                   (EXIT=0)

UI flow: 56 check(s)
PASS                                   (EXIT=0)

boot smoke, 300 frames                 (EXIT=0, no SCRIPT ERROR)
AI self-play: ticks=2768 phase=4 winner=2   (EXIT=0)
core boundary check passed (11 file(s))     (EXIT=0)
windowed run, 240 frames               (EXIT=0)
```

### Bugs found and fixed during M2.5

1. **The "tan blanket" was wall caps, not a material bug.** Sandy albedo caps at 0.97
   tile and raised 1.7 units covered most of the board at low camera angles. Fixed by
   shrinking/insetting the caps, darkening them to cool stone, and raising the camera.
2. **`source_color` uniforms rendered near-black.** Godot treats uniform defaults as sRGB
   and converts them to linear, so values that looked right on paper came out crushed.
   The shaders now carry sRGB-space defaults, and the floor/brick/crate palettes were
   retuned against real captures.
3. **`arena_style.gd` still exported the old per-tile floor colours** after the checker
   moved into the shader; removed so there is one source of truth.
4. **Player arm pivots were parented to the lean pivot**, so the walk swing fought the
   lean. Shoulders now hang off `_rig` and compose cleanly.
5. **Arabic text needed font fallback, not just translation.** Godot's default font has no
   Arabic coverage; `theme_builder.gd` attaches Noto Sans Arabic as a fallback and the RTL
   direction is set on the menu root.

---

## M2.6 — input & feel pass (verified)

### What changed for the player

- **Instant turnaround.** Pressing the opposite direction mid-step now reverses the
  character on the spot instead of finishing the tile first. Reversing into an armed bomb
  is refused, so you cannot clip through it.
- **Faster base movement.** Base speed raised from 54 to 64 fixed-point units per tick
  (3.15 → 3.75 tiles/s, 19 → 16 ticks per tile). The upgrade curve now tops out at
  104 fp (≈6.1 tiles/s) instead of 94.
- **No dropped presses.** Bomb, pause, restart and mode keys are latched from the real
  input event as it happens, then consumed by the next simulation tick. A tap that starts
  and ends between two ticks is no longer lost, even during a frame hitch.
- **Bomb input buffer.** A bomb press stays queued for 6 ticks (100 ms), so pressing just
  before a capacity slot frees or before the countdown ends still places the bomb on the
  first legal tick. Presses during READY carry into GO instead of being discarded.
- **Better analog stick.** Deadzone lowered from 0.40 to 0.28 and the most-deflected axis
  now wins, so diagonal pushes follow the direction you actually mean.
- **Cleaner shell.** Pausing/unpausing resets the tick accumulator (no catch-up burst),
  focus loss suspends device reads and clears queued presses (no stuck keys on return),
  and starting a round syncs the edge trackers so the menu-confirm keypress cannot drop
  a bomb on tick one.

### Verification evidence

```
74 test(s), 525 assertion(s), 0 failure(s)
PASS                                   (EXIT=0)
UI flow: 56 check(s)                   (EXIT=0)
SMOKE_EXIT=0 · SELFPLAY_EXIT=0 · BOUNDARY_EXIT=0
```

New coverage: mid-tile reversal, reversal blocked by a bomb, bomb-press buffering and
expiry, countdown buffering, and `tests/test_input_router.gd` for event latching
(bomb/P2/global actions/clear/suspend). Golden hashes were intentionally regenerated for
the new speed curve and buffered-bomb state:

| Scenario | Hash |
| --- | --- |
| seed 4242, 600 ticks, scripted | `3618636086` |
| seed 4242, 200 ticks, idle | `3308826698` |
| seed 4242, 200 ticks, scripted | `4227721462` |

---

## M2 — local versus front end (verified)

### What a player can do

- Boot to a **title screen** with a live AI-vs-AI attract match running behind it.
- Choose **LOCAL VERSUS** (2 players) or **SOLO** (1 player vs CPU).
- Play a **best-of series** (default best of 3; 1 or 5 selectable) with a between-round
  results card, next round, rematch and quit to title.
- **Pause** mid-match and resume, restart the round, or leave to title.
- Open **SETTINGS** from the title: master volume, SFX volume, series length,
  fullscreen. Values apply immediately and persist across launches.
- Hear **procedural SFX** for bomb placement, crate breaks, explosions, pickups, hits
  and match wins.

### New modules

| File | Responsibility |
| --- | --- |
| `src/app/app_flow.gd` | Pure screen/series state machine (TITLE/MATCH/RESULTS), best-of scoring, draws and round limits. No nodes or input, so it is unit-tested headlessly. |
| `src/app/settings.gd` | Persisted settings (`user://settings.json`) with a sanitising loader: defaults for missing keys, volume clamping, whitelisted series lengths/locales, corrupt JSON discarded. |
| `src/audio/sfx_library.gd` | Runtime PCM synthesis (noise bursts, FM-ish tones, envelopes) for six sounds. Deterministic, zero binary assets. |
| `src/audio/audio_director.gd` | `SimEvent` → sound mapping with a 16-voice pool, master gain and mute. Knows nothing about rules. |
| `src/ui/ui_kit.gd` | Shared menu styling: palette, outlined labels, button focus ring, panels. |
| `src/ui/screens/menu_panel.gd` | Full-screen menu base (dim backdrop, centred column, footer, recursive first-focus). |
| `src/ui/screens/title_screen.gd` | Brand block and mode/settings/quit actions. |
| `src/ui/screens/pause_menu.gd` | Resume / restart round / quit to title. |
| `src/ui/screens/series_panel.gd` | Round result, running score, series winner, next action. |
| `src/ui/screens/settings_screen.gd` | Volume sliders with a visible gold focus frame, series cycler, fullscreen toggle, back. |
| `tools/ui_flow_test.gd` | Real-scene end-to-end menu test driven by synthesized key events. |

`src/app/main.gd` now owns the flow: it loads settings before building the world, runs
the attract match on the title, records real `MATCH_ENDED` events into the series,
feeds every `SimEvent` to the audio director, applies volume/fullscreen changes, and
mutes audio during automation.

### Captured evidence

All frames come from the real renderer at 1600×900. M2.5 re-shot every screen in both
languages; the current files are listed in the M2.5 section above.

| Capture (current) | What the pixels show |
| --- | --- |
| `docs/screenshots/m2-title-en.png` / `-ar.png` | Centred title block over a dimmed attract match with the checkerboard visible. |
| `docs/screenshots/m2-settings-en.png` / `-ar.png` | Settings card with cyan border and a gold focus frame on the active row. |
| `docs/screenshots/m2-pause-en.png` / `-ar.png` | Gold `PAUSED` heading and action buttons. |
| `docs/screenshots/m2-series-en.png` / `-ar.png` | Cyan results panel, round/score text and the next action. |

### Verification evidence

Headless test suite (new `test_app_flow.gd`, `test_settings.gd`, `test_sfx.gd`):

```
55 test(s), 313 assertion(s), 0 failure(s) in 464 ms
PASS
EXIT=0
```

End-to-end UI flow (`tools/ui_flow_test.gd`, synthesized key events, real AI rounds):

```
UI flow: 47 check(s)
PASS
EXIT=0
```

It verifies, in order: boot to title, open SETTINGS from the keyboard, raise a volume
with `Right`, confirm the audio director gain follows, cycle the series length with
`Enter`, confirm the flow adopts it, close settings with BACK, reopen it and close with
`ESC`, start a 1P match, pause and resume, play a genuine AI-decided round to `RESULTS`,
advance to round 2, reach a decided 2-0 series, rematch with a cleared score, and quit to
title.

Boot smoke (real scene, 300 frames):

```
EXIT=0
```

No `SCRIPT ERROR`, parse error or leaked-object warning in the log.

### Bugs found and fixed during M2

1. **Settings sanitizer crashed on a partial file.** `{"best_of": 5.0}` made the loader
   read `raw["fullscreen"]` directly after `get()` returned a default, aborting
   `_sanitize()` and returning an empty dictionary. Now the value is read once and
   type-checked. Regression: `test_integral_float_series_is_accepted`.
2. **Corrupt JSON printed a GDScript error.** Switched from `JSON.parse_string()` to a
   `JSON` instance and its error return, so a bad settings file fails quietly.
3. **Audio playback leaked at exit in headless runs.** Headless now mutes the director
   from boot, so no `AudioStreamPlaybackWAV` is left dangling.
4. **Sliders had no visible keyboard focus.** Volume rows are wrapped in a panel whose
   border turns gold while the slider is focused; captures confirm the frame.
5. **Settings changed the series length mid-test.** The UI test normalized back to
   best-of-3 before the match assertions so the run stays deterministic.
6. **Packed-array fade was applied to a copy.** `_fade()` now returns the buffer and
   callers assign it; SFX tails actually fade.
7. **`_focus_first()` only looked at direct children**, so the settings card would not
   take focus. It now recurses into containers.

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
| `src/app/main.gd` | Fixed-tick driver (60 Hz, max 4 catch-up steps), world environment, key/fill lights, camera wiring, event → camera shake, shot/capture modes. |
| `src/render/arena_style.gd` | Single source of truth for palette, player colours, tile→world conversion (tile size 2.0), materials. |
| `src/render/arena_view.gd` | `MultiMeshInstance3D` floor/wall/crate build; incremental crate refresh on `CRATE_DESTROYED`. |
| `src/render/player_view.gd` | Capsule body, facing visor with smoothed yaw, walk bob, start-of-step squash, spawn-guard shimmer, elimination flatten/fade. Driven by fixed-point `visual_position()`. |
| `src/render/bomb_view.gd` | Sphere + pulsing emissive fuse flash, scale pop on placement, slide offset when kicked. |
| `src/render/blast_view.gd` | Per-tile fire column with rise/fall driven by blast age. |
| `src/render/pickup_view.gd` | Floating, spinning icon per pickup type, colour-coded. |
| `src/render/camera_rig.gd` | Auto-fit orthographic-ish perspective camera at 56° elevation, fov 50, followed by decaying shake. |
| `src/ui/hud.gd` | Phase banner (`READY`/countdown/`GO!`/winner/`DRAW`), match clock, per-player stat panels, controls hint. |
| `src/input/input_router.gd` | Keyboard + gamepad → `{dir, bomb}`; edge-detects bomb/pause/restart/mode keys. |
| `src/ai/simple_ai.gd` | Deterministic opponent: danger map of armed bombs **and burning blast tiles**, time-aware escape BFS, plant only when a safe route exists after the new bomb, crate/enemy objectives, seeded roaming. |

Design rule kept intact: views read simulation state and never write it; the simulation
still has no node, input, audio or clock access (guard script enforces this).

### Verification evidence (M1)

Headless suite at the time:

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

Captured frame at the time (superseded by `docs/screenshots/m2-gameplay-en.png` after the
M2.5 art pass; seed 4242, `--shot-ticks=360`):

```
shot state: tick=362 phase=2 bombs=1 blasts=6 pickups=1 eliminations=0
  player 0 tile=(1, 1) alive=true stats=1/2/0 kick=false
  player 1 tile=(12, 1) alive=true stats=1/2/0 kick=false
  on screen: player 0 -> (507.96, 237.35)
  on screen: player 1 -> (1069.61, 237.35)
shot saved: ...\m1-final2.png (err=0)
```

Independent pixel checks: cyan P1 body at `(508,237)` = `R94 G226 B255`, coral P2 body
at `(1069,237)` = `R255 G143 B127`, HUD text present, mean luminance 61.0.

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
  crosses a tile in 16 ticks (3.75 tiles/s) and carries the remainder across chained
  tiles. Pressing the opposite direction mid-tile reverses the step in place.
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
a simulation change is intentional; regenerated in M2.6 for the input/speed pass):

| Scenario | Hash |
| --- | --- |
| seed 4242, 600 ticks, scripted commands | `3618636086` |
| seed 4242, 200 ticks, idle | `3308826698` |
| seed 4242, 200 ticks, scripted | `4227721462` |

Soak: 10,000 ticks with 4 players and no scene tree, under the 5 s budget.

---

## Not implemented (do not assume otherwise)

- No character models, textures, rigs, animation clips or VFX sprites — all geometry is
  primitives and shaders built from code. No `.glb`/`.blend` assets exist. The "classic
  art pass" is code, not authored art.
- No music, mixing bus, ambience or voice. SFX are synthesized placeholders.
- No adventure content, world map, bosses or progression.
- No online play: no ENet transport, prediction, reconciliation, matchmaking or server.
- No Android build/export, controller rebinding UI, or save profiles/unlocks.
- Arabic covers the current front end and HUD only; there is no adventure/campaign text to
  translate yet.

## Known issues / watch items

1. Project lives under OneDrive. Exclude `fuse/.godot/` and `fuse/build/` from sync, or
   move `fuse/` to a non-synced path before heavy asset work.
2. Blender is not installed (required at M3).
3. No git remote/CI yet; local repo only. Boundary script is ready for CI.
4. `blast-arena/` (earlier web prototype) is untouched and remains a rules/netcode reference.
5. Running the Godot console binary in the foreground from some shells can stall on this
   machine; capturing output to a file or running it in the background works reliably.
6. Settings persistence writes `user://settings.json`; tests redirect to
   `user://settings_test.json` / `user://settings_uitest.json` and clean up.
7. The AI is a fairness-neutral test opponent, not a designed difficulty curve.

---

## Next: M3 — vertical slice

1. Pick a theme and produce a first real art direction pass (characters, bombs, arena
   tiles, UI frames) with Blender → glTF; keep the code-built views as the fallback path.
2. Replace runtime-synth SFX with designed audio and add one music loop plus a mixer.
3. Character select with per-character stats/specials (rules-driven, tested headlessly).
4. Menu polish: transitions, animated focus, input glyph swapping (keyboard vs pad),
   and a language switch reachable before the title.
5. Expand tests: settings UI edge cases, series with changing best-of, audio voice-pool
   exhaustion, Arabic string coverage for new screens.
