# Re-Jardinians!

An original, offline, garden-themed brick-breaker made with Godot, inspired by
the classic *Jardinains!*. Built for personal and family play, not for sale.

## Requirements

- Godot **4.7.2 Standard** (GDScript, no .NET)
- No plugins or external dependencies

## Running

1. Open Godot 4.7.2 and import this folder (`project.godot`).
2. Press **F5** to run the main scene (`res://main.tscn`).

## Controls

| Action | Keys |
|---|---|
| Move paddle | Left/Right arrows, A/D, or move the mouse |
| Launch ball / play again | Space or left click |
| Pause / resume | P or Esc |

## Tests

Plugin-free tests live in `tests/`. Run them from the project folder, replacing
`godot` with the path to your Godot 4.7.2 executable if it is not on `PATH`
(e.g. `~/Downloads/Godot_v4.7.2-stable_linux.x86_64`):

```bash
godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
```

`--fixed-fps 60` makes each frame exactly one physics step, so the physics
simulations run quickly and deterministically. The command exits with code 0
when every check passes.

The headless run skips the rendered-pixel brick check. To include it, run in a
window (a game window opens briefly):

```bash
godot --path . --fixed-fps 60 --disable-vsync --script res://tests/run_tests.gd
```

If you add or rename scripts, run `godot --headless --path . --import` once (or
open the editor) so new `class_name` types are registered before testing.

## Project settings at a glance

- Renderer: GL Compatibility
- Logical resolution: 1280×720, landscape, fixed 16:9 playfield
  (`canvas_items` stretch, `keep` aspect — letterboxed on other window shapes)
- 2D physics interpolation enabled
- Input actions: `move_left`, `move_right`, `launch_ball`, `pause`
  (mouse movement controls the paddle directly)
- 2D physics layers: `world`, `paddle`, `ball`, `bricks`, `killzone`

## Folder layout

Folders are created only when their first real file is added.

```text
res://
├── main.tscn          # entry scene
├── assets/            # shared art, audio, fonts, shaders
├── autoload/          # global singletons, added only when needed
├── core/              # constants and small helpers
├── data/              # designer-edited resources (bricks, levels, campaign)
├── entities/          # one folder per game object: scene + script + art
├── gameplay/          # game session, level loading, resource class definitions
├── ui/                # screens, HUD, pause menu, theme
├── tests/             # plugin-free automated tests (logic, physics, scenes)
└── docs/              # project documentation
```

## Conventions

- File and folder names: lowercase `snake_case` (e.g. `brick_type.gd`).
  Never rely on case alone to distinguish files — Windows and macOS are
  case-insensitive.
- Class names: `PascalCase` (`class_name BrickType`).
- GDScript: tabs for indentation, static typing wherever practical.
- Avoid the characters `: * ? " < > |` and symlinks in file names.

## Repository notes

- The project folder name contains `!`. In an interactive bash shell, use
  single quotes (`cd 're-jardinians!'`) or tab-completion to avoid history
  expansion.
- Export output goes outside this repository; see
  [docs/exporting.md](docs/exporting.md).
