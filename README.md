# FUSE

Working title for a modern **2.5D bomb-arena action game** (Atomic Bomberman-inspired),
built in **Godot 4.7.2**. Windows first, Android after.

> **Status: M0 foundation.** Only the pure-logic tile grid and the headless test harness
> exist. There is no gameplay or rendering yet — see `docs/PROGRESS.md` for what is and
> is not implemented.

---

## Requirements

- Godot **4.7.2** (standard build, not .NET)
- Windows 10/11 for development
- Blender 4.x only when working on real art (not needed for M0/M1)

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

## Run the tests

```powershell
cd "C:\Users\ALMASA\OneDrive\Documents\Default Project\fuse"
$godot = "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --script res://tests/run_tests.gd
```

Expected: `PASS` and exit code `0`.

## Open the project

```powershell
& "$env:LOCALAPPDATA\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64.exe" --path .
```

## Layout

| Path | Purpose |
| --- | --- |
| `src/core/` | Pure simulation: grid, rules, match state. No nodes, scenes, audio, or input. |
| `src/presentation/` | Views, VFX, audio, camera (added in M1). |
| `src/ui/` | Menus, HUD, theme (added in M1/M2). |
| `src/online/` | Prediction, reconciliation, sessions (added in M5). |
| `content/` | Characters, arenas, environments, audio, UI assets. |
| `scenes/` | Boot, menu, lobby, match, adventure map. |
| `tests/` | Headless tests and golden scenarios. |
| `docs/` | Technical design and progress log. |
| `server/` | Headless authoritative server + lobby service (M5). |

## Docs

- [`docs/TECHNICAL_DESIGN.md`](docs/TECHNICAL_DESIGN.md) — stack decision, architecture, netcode, roadmap, risks.
- [`docs/PROGRESS.md`](docs/PROGRESS.md) — verified status, test results, next steps.

## Related project

`../blast-arena/` is an earlier **web** prototype (React Three Fiber + Colyseus). It is
untouched and kept as a reference for rules, match flow, and networking behavior. It is
not the codebase for this game.
