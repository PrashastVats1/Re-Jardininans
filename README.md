# Re-Jardinians!

An original, offline, garden-themed brick-breaker made with Godot, inspired by
the classic *Jardinains!*. Built for personal and family play, not for sale.

## Requirements

- Godot **4.7.2 Standard** (GDScript, no .NET)
- No plugins or external dependencies

## Running

1. Open Godot 4.7.2 and import this folder (`project.godot`).
2. Press **F5** to run the main scene (`res://main.tscn`).

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
├── tests/             # automated tests for pure gameplay logic
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
