# FUSE — Technical Design (v0.1)

Working title. Date: 2026-10-30. Engine: **Godot 4.7.2 stable** (pinned).
Status: M0 foundation. No gameplay or rendering exists yet.

---

## 1. Decision summary

| Area | Choice |
| --- | --- |
| Engine | Godot 4.7.2, Forward+ (desktop) / Mobile (Android) |
| Language | Typed GDScript only (no .NET runtime on this machine; avoids a second toolchain) |
| Art pipeline | Blender 4.x → glTF 2.0; procedural placeholders first, commissioned/purchased finals |
| Simulation | Pure-logic fixed-tick core, shared by local play, adventure, and headless server |
| Local MP | Godot InputMap + per-device routing, up to 4 pads |
| Online | Server-authoritative 30 Hz snapshots over ENet, client prediction + reconciliation |
| Lobby/matchmaking | Small Node/Fastify ticket service; game servers are headless Godot processes |
| Audio | Godot buses + pooled `AudioStreamPlayer3D`; adaptive music layers |
| UI | Godot Control + Theme, 1920×1080 design space, Arabic RTL + English from day 1 |
| Platforms | Windows first (Steam), Android second (same codebase, Mobile renderer) |
| Testing | Zero-addon headless runner + golden scenario tests + load harness |
| CI | GitHub Actions `windows-latest`: headless tests + export check |

Deliberately excluded: Unity, a second engine, lockstep determinism, P2P as the
competitive model, a custom backend language for v1.

---

## 2. Engine comparison

Scored for *this* game (stylized 2.5D, animation-heavy, grid rules, 4–8 player online,
solo dev + AI agent, Windows + Android).

| Candidate | Rendering fit | Character animation | Grid gameplay | Pads / local MP | Online path | Win + Android | Agent-friendliness | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Godot 4.7** | Strong with art direction; SSAO/SSIL, glow, fog, decals, GPU particles, shaders | Strong: glTF skeletal, AnimationTree blend trees/state machines, IK modifiers, blend shapes | Excellent — no engine friction | Excellent, per-device input | Good: build authoritative headless server | Excellent, one-click export | Excellent: text scenes/resources, headless CLI, small diffs | **Pick** |
| Unreal 5 | Best raw fidelity (Lumen/Nanite) | Best-in-class (Control Rig, Sequencer) | Overkill | Good | Good (dedicated server) | Heavy; tens of GB, slow iteration | Poor: binary assets, C++/Blueprint, slow builds | Wrong cost/benefit for a 15×13 arena game |
| Bevy (Rust) | Good | Weak–moderate: no editor, hand-built state machines, immature skinning workflow | Excellent ECS | Moderate | Weak | Moderate | Strong for code, weak for content/art iteration | High-risk research project |
| Three.js / R3F | Moderate; stylized is achievable but lighting/animation tooling is manual | Weak: no skeletal pipeline, no blend trees | Excellent | Weak for native pads | Excellent (Colyseus proven) | Browser only (+ Capacitor wrapper) | Strong | Keep as web demo/reference, not the premium build |
| Cocos Creator 3.8 | Good | Moderate | Good | Moderate | Moderate | Good (Android-first) | Moderate | Viable, no advantage over Godot |
| Defold | Limited 3D | Weak | Good | Good | Moderate | Good | Good | 2D-focused; no |

**Why Godot:** the gameplay is cheap to simulate; the value is in animation, effects,
feel, and iteration speed. Godot gives a real editor + animation tooling + native
Windows/Android exports + a headless server mode, while staying small, MIT-licensed,
and fully text-based so an AI agent can work in it safely. Unreal wins on raw pixels but
its asset/compile workflow is the worst fit for this team and scope. The existing web
prototype proves the *rules and netcode shape*; it cannot deliver the animation quality
target efficiently.

---

## 3. What we reuse from `blast-arena/`

The existing web prototype is **not** deleted or modified. Reused as evidence and design input:

- Validated rules: 3.15 → 5.4 tiles/s speed, 2.4 s fuse, 450 ms blast, capacity 1→5,
  range 2→6, 34 % crate drop.
- Arena generation approach (seeded, border walls, pillar lattice, guaranteed spawns).
- Match phase machine: lobby → countdown → playing → results → rematch.
- Invite-code flow and public/private isolation; the 16-check smoke-test scenarios.
- AR/EN copy, character names/bios (VOLT, EMBER, NOVA, VINE) as a starting roster.
- Hard-won bug list (state init ordering, public-room code lookup, localStorage identity).

Not reused: rendering, UI, simulation code, Colyseus room implementation.

---

## 4. Target platforms & performance budgets

Budgets are targets to measure, not claims.

| Target | Resolution / FPS | Draw calls | Triangles | Lighting | Budget |
| --- | --- | --- | --- | --- | --- |
| Desktop min (GTX 1050 / Iris Xe) | 1080p60 | ≤ 400 | ≤ 500k | 1 shadowed directional + ≤ 4 local | sim ≤ 1.5 ms, render ≤ 10 ms |
| Desktop recommended | 1440p60 / 1080p120 | ≤ 600 | ≤ 900k | + SSAO/SSIL, volumetrics | ≤ 8 ms GPU |
| Android mid-range (Adreno 642L class) | 1080p60 / 720p60 | ≤ 150 | ≤ 150k | baked/vertex, no SSAO | ≤ 8 s cold load, 3.5 s warm |
| Network | 8 players | — | — | — | ≤ 20 KB/s down, ≤ 2 KB/s up per client |

Process: profile with Godot's profiler + an in-game frame-time overlay; record numbers per
milestone in `PROGRESS.md`. No optimization claims without a capture.

---

## 5. Architecture

### 5.1 Non-negotiable split

```
input → Command → [ SIMULATION ] → events + state → presentation
                        ↑
                 network / AI / replay
```

- `src/core/**` is pure GDScript: no `Node3D`, no scenes, no audio, no `Input`.
  It can run in a headless server process and in tests.
- Simulation advances in **fixed integer ticks** (60 Hz local, 30 Hz authoritative
  snapshot cadence). All durations are tick counts (fuse = 144 ticks).
- Positions are **fixed-point integers** (1/1024 tile) inside the sim; floats are
  rendering-only. This makes client prediction match the server exactly and avoids
  cross-platform float drift.
- One-shot outcomes are emitted as **ordered `SimEvent`s** (bomb placed, blast spawned,
  crate destroyed, pickup taken, player hit, round ended). Presentation never infers
  effects by polling state.
- RNG is owned by the sim, seeded per match, and advanced only inside the tick.
- Commands are data: `{ tick, player_id, dir, bomb_pressed, action_pressed }` — the same
  struct feeds local input, AI, network, and replay tests.

### 5.2 Folder structure

```
fuse/
├─ project.godot
├─ icon.svg
├─ docs/
│  ├─ TECHNICAL_DESIGN.md
│  └─ PROGRESS.md
├─ src/
│  ├─ core/                    # pure sim — no engine nodes
│  │  ├─ sim/                  # grid, match_sim, player_sim, bomb_sim, blast, rng, events
│  │  ├─ rules/                # ruleset.gd, powerup defs, tuning constants
│  │  ├─ arena/                # layout parse/validate, spawns, objectives
│  │  └─ net/                  # command/snapshot serialization, hashing
│  ├─ match/                   # MatchRunner: sim ⇄ views ⇄ audio ⇄ hud
│  ├─ presentation/
│  │  ├─ arena/                # tiles (MultiMesh), crates, props
│  │  ├─ actors/               # player, bomb, pickup, enemy views
│  │  ├─ camera/               # CameraRig, framing, trauma shake, hitstop
│  │  ├─ vfx/                  # Explosion, shockwave, debris, scorch decals
│  │  └─ audio/                # AudioDirector, sfx bank, music layers
│  ├─ input/                   # InputRouter, device assignment, rebinding
│  ├─ ui/                      # theme, screens, HUD, transitions
│  ├─ modes/                   # local_versus, adventure, online
│  ├─ progression/             # profile, save schema, unlocks
│  └─ online/                  # session, prediction, reconciliation, interpolation
├─ content/
│  ├─ characters/              # .glb + character .tres
│  ├─ arenas/                  # .txt layouts + metadata .json
│  ├─ environments/            # modular kits, materials
│  ├─ vfx/                     # shaders, particle materials
│  ├─ audio/
│  └─ ui/                      # fonts (OFL), icons, theme
├─ scenes/                     # Boot, MainMenu, Lobby, Match, AdventureMap
├─ tests/                      # headless runner + core tests
├─ tools/                      # python/blender/CI scripts
├─ art_src/                    # .blend sources (git-lfs later)
└─ server/                     # headless server entry + lobby service (M5)
```

### 5.3 Gameplay model (M1 scope)

- Grid: 15×13 default, configurable per arena; border walls, pillar lattice, crate field.
- Movement: tile-to-tile stepping with fixed-point interpolation, one-input buffer,
  corner assist. Crisp, deterministic, network-friendly. Not free 8-way physics.
- Bomb: capacity, fuse, range, chain via tick-ordered propagation queue.
- Blast: 4-way, blocked by walls, absorbed by the first crate; same-tick chains resolve
  deterministically.
- Power-ups: capacity, range, speed, kick (thrown bombs later).
- Damage: one hit = eliminated in versus; hearts in adventure.
- Match: countdown → playing → sudden death (arena shrinks) → results → rematch.
- Rules live in a `Ruleset` resource so game modes and tests can override them.

### 5.4 Presentation

- Arena: `MultiMeshInstance3D` for floor/wall/crate variants; per-arena environment
  scene for dressing. Instancing, not thousands of nodes.
- Characters: `Node3D` driven by interpolated sim state; animation never drives movement.
- Camera: perspective, ~38° FOV, 52–58° pitch, framing all alive players with soft
  deadzone + dynamic zoom; trauma-based shake (decays quadratically) and 40–80 ms hitstop
  on eliminations; optional orthographic mode.
- Readability: silhouette outlines on players, color-blind-safe bomb/powerup markers,
  blast telegraphs, off-screen indicators, layer-culled VFX that never hides the grid.
- Post: glow, SSAO/SSIL, volumetric fog (desktop), light chromatic aberration on blasts
  only; all toggleable for low-end/mobile.

### 5.5 Animation strategy (honest)

The visual target cannot be met by code alone. Plan is tiered:

- **Tier B (M1–M2 prototype):** procedurally generated stylized "puppet" characters from
  Blender Python — chunky silhouette, simple 20-bone rig, pose library, procedural
  locomotion (bob/lean/footstep), shader squash-and-stretch. Clearly labelled
  placeholder, but readable and animated (not gray cubes).
- **Tier A (M3 vertical slice onward):** authored/commissioned character per hero:
  model + 20–28 bone rig + 6 core clips (idle, run, carry, hurt, win, lose) + 2 emotes +
  blend shapes or shader face. Integrated through `AnimationTree` (BlendSpace2D locomotion,
  state machine, one-shot layer) plus a procedural additive layer for secondary motion.
- Environment: modular kit + trim sheet, baked AO/vertex color, emissive accents,
  animated props. Lighting and composition do the heavy lifting.
- **Gate:** the M3 slice must look premium in motion before content expands. If Tier B
  fails the gate, commission art instead of scaling placeholder content.

Estimated art cost: $250–600 per rigged/animated hero from an indie freelancer;
$1–3k for 4–6 heroes. Asset packs $0–300. Music/SFX $0–500 (CC0 + procedural).

### 5.6 Input & local multiplayer

- `InputRouter` maps physical devices → player slots; keyboard split sets + up to 4 pads.
- Rebindable actions, dead-zone config, hold/toggle bomb, UI focus with d-pad.
- Hot-join in local lobby, device reassignment without leaving the match.
- Pause only in local/adventure (not online).

### 5.7 Online (Phase 5)

| Concern | Decision |
| --- | --- |
| Model | Server-authoritative snapshots + client prediction (not lockstep, not P2P) |
| Transport | ENet (UDP), reliable + unreliable channels; WebSocket only if a web build returns |
| Tick | 60 Hz sim, 30 Hz snapshots, 60 Hz inputs, 100 ms interpolation buffer |
| Own movement | Predicted immediately; reconciled by replaying unacked commands |
| Others | Interpolated; no extrapolation beyond 150 ms |
| Bombs/explosions | Server owns fuse/chain/damage; client predicts placement, confirms on ack |
| Latency masking | Fuses are 2.4 s — RTT is hidden by the fuse animation, so no lag compensation needed |
| Rooms | 6-char codes, public/private isolation, ready-up, rematch, bots fill empty slots |
| Reconnect | 60 s seat reservation, full snapshot resync, session token |
| Security | Server validates every command, rate limits, signed tickets, no client state trust |
| Scale | One headless process hosts many rooms; measure before quoting capacity |

Why not lockstep: cross-platform float determinism is a trap; desync recovery is painful.
Why not P2P: host advantage, NAT, cheating, host migration. Game state is tiny (grid +
≤ 8 players + ≤ 20 bombs), so authoritative snapshots are cheap.

**Hosting estimate (to be measured):** one 2 vCPU / 4 GB VPS (Hetzner CX22, ~€5/mo) should
host dozens of rooms; Caddy provides TLS; a domain is ~$12/year. Matchmaker is a small
Node/Fastify service. Total early-access infra: ~€5–15/month. Steam Direct $100 one-time;
Google Play $25 one-time.

### 5.8 Adventure

- 3 worlds × 6 levels + 1 boss each at launch, plus 3 secret levels.
  - **Rustyard** — teaching: crates, kick, chasers, conveyor hazards.
  - **Frostline** — ice sliding, crumbling floors, patrollers.
  - **Hive** — acid pools, moving hazards, turret nests, boss arenas.
- Level = text layout + JSON metadata (objective, spawns, modifiers, rewards).
- Objectives: clear enemies, collect N, reach exit, survive, blast-open puzzle doors.
- Enemies: chaser, patroller, turret, bomber — utility/behavior-tree AI with telegraphed
  attacks; bosses are phase state machines with readable patterns.
- 2-player local co-op: shared level, individual lives, revive, star ratings
  (clear / time / no-hit), coins → cosmetics.
- Pipeline: layout + metadata + shared enemy/prop kit ⇒ new levels without code.

### 5.9 Persistence & progression

- Versioned save file in `user://` (JSON + schema version + migration).
- Profiles: input bindings, audio/video settings, unlocks, stars, coins, stats.
- Cosmetics only; no stat advantages in versus. Adventure upgrades are level-scoped.
- Cloud sync deferred until accounts exist (Nakama or Steam).

### 5.10 UI, localization, accessibility

- 1920×1080 design space, `canvas_items` stretch, safe-area aware for Android.
- Godot `Control` + one Theme resource; animated via Tween/AnimationPlayer; a
  `SceneRouter` owns fades/wipes and loading states.
- AR + EN from M1. Arabic shaping needs an OFL font with proper GSUB (Cairo/Rubik/Noto
  Kufi); RTL layout is mirrored and tested early, not bolted on at the end.
- Accessibility: remapping, color-blind palettes with pattern markers, screen-shake and
  flash intensity sliders, reduced motion, UI scale, hold-vs-toggle, subtitles for any VO.

---

## 6. Testing & CI

| Layer | What it proves | Tool |
| --- | --- | --- |
| Unit | Blast blocking, chain order, crate drops, kick slide, timers, win/sudden death | zero-addon headless runner |
| Golden scenarios | Text arena + scripted commands for N ticks → final state hash | same runner |
| Integration | 2–4 headless clients vs server converge; reconnection restores state | headless clients |
| Soak/load | 50+ bot rooms for 1 h, memory/CPU/latency | bot harness |
| Perf | Frame-time and draw-call captures per milestone | Godot profiler + overlay |
| Build | Windows export launches; Android export when SDK is present | CI |

CI: GitHub Actions `windows-latest`, Godot 4.7.2 pinned by checksum, run headless tests,
fail on non-zero exit. Windows CLI must use `Godot_*_console.exe` (the GUI exe does not
attach stdout/exit codes to PowerShell).

Enforce the architecture split with a CI grep: `src/core` may not reference
`res://scenes`, `res://content`, `Node3D`, `AudioStreamPlayer`, or `Input`.

---

## 7. Roadmap

Assumes one implementation agent + human direction/QA, art in parallel. Ranges are
calendar estimates, not promises.

| Milestone | Duration | Deliverable | Exit criteria |
| --- | --- | --- | --- |
| **M0 Foundation** | 1 wk | Sim skeleton, test runner, grid, docs, project bootstrap | Headless tests green; architecture guard in CI |
| **M1 Grey-box playable** | 2 wk | 1 human + 3 AI, bombs/chains/crates/power-ups, HUD, match flow, keyboard + gamepad | 60 fps; no soft-locks; unit + golden tests green; recorded playtest |
| **M2 Local versus** | 2–3 wk | 4-player local, device assignment, 3 arenas, settings, rematch | 4 pads/keyboard simultaneously; pause/rematch correct |
| **M3 Vertical slice** | 4–6 wk | One polished arena, 3 animated heroes, full VFX/audio/UI, perf pass | "Would I wishlist this?" review; 1080p60 on min spec; animation gate |
| **M4 Adventure act 1** | 6–8 wk | World 1 (6 levels + boss), 2P co-op, save/progression | 45–60 min campaign slice; no progression blockers |
| **M5 Online beta** | 4–6 wk | Dedicated servers, prediction, rooms/codes, matchmaking, reconnect, bots | 3-region latency test; 50-room soak; zero desyncs in 100 matches |
| **M6 Content + release** | 6–8 wk | 8 arenas, 6–8 heroes, 3 worlds, cosmetics, accessibility, localization, CI, Steam/Android | Store-ready builds; crash-free session; perf budgets met |

Critical path: art production (M3 gate) and netcode (M5). Early access-quality slice is
realistic around M3 (~3 months); 1.0 around 6–8 months.

---

## 8. Risks

| Risk | Severity | Mitigation |
| --- | --- | --- |
| Character art/animation quality (biggest) | High | Tier B procedural puppets now; commission 4–6 heroes for M3; hard gate before content scale-up |
| Online netcode complexity | High | Local-first; server-authoritative; prediction only for own movement; bots + soak tests; staged rollout |
| Scope (adventure + online + polish) | High | Fixed launch content counts; cut lists agreed per milestone; no ranked/MMR/chat in v1 |
| Arabic RTL in Godot | Medium | OFL Arabic font, mirroring + shaping test in M1; EN fallback if blocked |
| Android performance | Medium | Mobile renderer, baked lighting, particle budgets, real-device test at M2/M3 |
| OneDrive sync corrupting `.godot` / file locks | Medium | Exclude `fuse/.godot` and `build/` from OneDrive, or move the project to a non-synced path |
| Engine API churn | Low | Pin 4.7.2; upgrade only at milestone boundaries |
| Agent can't judge "fun"/visual quality | Medium | Human playtest at every milestone; screenshots/video evidence; explicit review gates |
| Matchmaking/abuse ops | Medium | Signed tickets, rate limits, server validation, minimal PII, Caddy TLS |

---

## 9. Non-goals for v1

Ranked MMR, cross-play with the web build, voice chat, level editor, mod support,
procedural campaign, 8-player local, console ports, monetization beyond a paid game.

---

## 10. Open decisions (defaults will be used unless changed)

1. **Brand:** keep *Blast Arena* or ship as *FUSE*? Default: working title FUSE.
2. **Art budget:** DIY only ($0) / packs ($100–300) / commission ($1–3k). Default: DIY to
   M3, then decide at the gate.
3. **Launch order:** Windows/Steam first, Android after. Default: yes.
4. **Existing web build:** freeze as a public demo/reference. Default: freeze, keep runnable.
5. **Languages:** AR + EN at launch. Default: yes, from M1.
