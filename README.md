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
when every check passes. A test script that fails to load, or does not finish
within 120 seconds, is reported as a failure. To run only some scripts, add
`-- --tests=res://tests/test_sidebar.gd,res://tests/test_messages.gd`
(`--timeout=<seconds>` changes the time limit).

The headless run skips the rendered-pixel brick check. To include it, run in a
window (a game window opens briefly):

```bash
godot --path . --fixed-fps 60 --disable-vsync --script res://tests/run_tests.gd
```

Some tests deliberately load invalid levels, so the output includes engine
errors; each such test first prints a line saying how many errors to expect.

If you add or rename scripts, run `godot --headless --path . --import` once (or
open the editor) so new `class_name` types are registered before testing.

## Project settings at a glance

- Renderer: GL Compatibility
- Logical design canvas: 1280×720, landscape, `canvas_items` stretch with
  `expand` aspect. The window scales the canvas uniformly (nothing is
  stretched); on wider or taller windows the canvas is centered and the extra
  space shows the plain dark-green backdrop instead of black bars. Code reads the
  canvas size from the project's viewport width/height through
  `GameLayout.get_design_size()`.
- Gameplay arena: 960×720 on the left of the design canvas, in arena-local
  coordinates, read through `Playfield.get_size()` (the design canvas minus
  `GameLayout.SIDEBAR_WIDTH`). Resizing the window only offsets the canvas
  transforms — the ball, paddle, bricks and walls never move.
- Presentation is gameplay-first: the arena is solid black from the ceiling
  down, with no scenery, so every gameplay object stays easy to pick out. The
  strip above the ceiling (controls hint), the sidebar and any window margins
  share one plain dark green (`Backdrop/Fill` in `gameplay/game.tscn`), which
  keeps the arena's edges visible.
- Sidebar (`ui/hud/sidebar.tscn`, the 320 px column on the right): title,
  score and lives (from `GameSession`), level name (from the level's
  `LevelData`), then player name, high score and most levels in a row. Player
  records are not stored yet, so those show "—" placeholders.
- Default level: Test Garden (see [Levels](#levels)).
- Minimum window size: 960×540 (set at startup)
- 2D physics interpolation enabled, physics at the default 60 ticks/s
- Frame rate capped at 60 FPS (`application/run/max_fps`) for even frame
  pacing; vsync alone does not pace frames reliably on every Linux desktop
- Input actions: `move_left`, `move_right`, `launch_ball`, `pause`
  (moving the mouse over the arena steers the paddle; when the pointer moves
  off the arena or leaves the window, the paddle finishes its last move and
  then stays put; a movement key or losing focus stops it at once)
- 2D physics layers: `world`, `paddle`, `ball`, `bricks`, `killzone`

## Levels

The game currently has a single playable level, **Test Garden**
(`data/levels/test_level.tres`: 11 columns × 5 rows, 40 destructible bricks plus
2 stones). It is the only entry in `data/level_list.tres`, the list the game
loads its level from. The planned 64-level campaign (Level 1 being the
tutorial) does not exist yet.

`data/levels/fixture_islands.tres` (**Fixture Islands**, 9 columns × 7 rows)
is a test fixture, not a campaign level: it is deliberately not in the level
list, so the game never loads it. It exists so the level tests run against
more than one shape.

### Level format

A level is a `LevelData` resource (`gameplay/resources/level_data.gd`):

- `display_name`: shown in the sidebar.
- `rows`: one string per row of bricks, top to bottom, one character per
  column. Every row must have the same width. `.` or a space is an empty cell.
- `legend`: maps each brick character to a `BrickType`. Every character used in
  `rows` must be in the legend, every legend entry must be used, and `.` and
  space cannot be keys.

Brick types are shared resources in `data/bricks/` (`BrickType`: display name,
colour, hit points, points, destructible), so every level uses the same bricks:
red, yellow and blue blooms (1 hit, 50 points), the clay pot (2 hits,
120 points) and the indestructible garden stone (0 points). A level needs at
least one destructible brick; stones are allowed.

### Grid fit

Bricks are 76×28 px on an 80×32 px cell, laid out by `LevelGrid`
(`gameplay/level_grid.gd`). The grid is centred horizontally and starts at
y = 104. In the 960×720 arena:

- There must be at least one ball width (20 px) between the grid and each side
  wall, which allows at most 11 columns.
- There must be at least 200 px of open space between the bottom of the grid and
  the top of the paddle, which allows at most 10 rows.

Both limits are worked out from the arena, ball and paddle sizes, not
hardcoded.

### Validation

When a level loads, `LevelValidator` checks its structure (the rules above) and
that it fits the arena. If anything is wrong, the game logs each problem as an
error, shows "Level unavailable" and will not launch the ball. Checking that
every brick can be reached, and that the scripted autoplay can clear the
level, is done only by the tests. They run these checks, plus spawning,
scoring and grid placement, on every `.tres` file in `data/levels/`.

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
