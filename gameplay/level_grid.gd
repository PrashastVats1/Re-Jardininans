class_name LevelGrid
extends RefCounted
## Brick grid geometry in arena coordinates, independent of any node, so the
## game and anything that checks whether a level fits use the same numbers.
##
## Each cell is one brick plus SPACING; a grid of c columns and r rows takes a
## footprint of c x r cells, centred horizontally with its top edge at
## GRID_TOP, and each brick sits at the centre of its cell. Arena-dependent
## limits derive from Playfield.get_size(); the arena size is a parameter so
## other sizes can be checked too.

const BRICK_SIZE: Vector2 = Vector2(76.0, 28.0)
const SPACING: Vector2 = Vector2(4.0, 4.0)
const CELL_SIZE: Vector2 = BRICK_SIZE + SPACING
const GRID_TOP: float = 104.0
## Distance from the arena's bottom edge to the paddle's centre.
const PADDLE_BOTTOM_OFFSET: float = 60.0
## Open play space required between the grid's footprint and the paddle's top.
const MIN_PADDLE_CLEARANCE: float = 200.0


static func get_footprint_size(columns: int, rows: int) -> Vector2:
	return Vector2(columns * CELL_SIZE.x, rows * CELL_SIZE.y)


## Centre of the brick in [param column], [param row] of a grid that is
## [param columns] wide.
static func get_cell_center(column: int, row: int, columns: int, arena_size: Vector2 = Playfield.get_size()) -> Vector2:
	var first_center := Vector2((arena_size.x - columns * CELL_SIZE.x) * 0.5, GRID_TOP) + CELL_SIZE * 0.5
	return first_center + Vector2(column * CELL_SIZE.x, row * CELL_SIZE.y)


## Space between each side of the footprint and the arena wall; negative when
## the grid is wider than the arena.
static func get_side_gap(columns: int, arena_size: Vector2 = Playfield.get_size()) -> float:
	return (arena_size.x - columns * CELL_SIZE.x) * 0.5


static func get_grid_bottom(rows: int) -> float:
	return GRID_TOP + rows * CELL_SIZE.y


static func get_paddle_y(arena_size: Vector2 = Playfield.get_size()) -> float:
	return arena_size.y - PADDLE_BOTTOM_OFFSET


static func get_paddle_top(arena_size: Vector2 = Playfield.get_size(), paddle_height: float = Paddle.DEFAULT_SIZE.y) -> float:
	return get_paddle_y(arena_size) - paddle_height * 0.5


## Open space between the bottom of a [param rows]-row grid and the paddle.
static func get_paddle_clearance(rows: int, arena_size: Vector2 = Playfield.get_size(), paddle_height: float = Paddle.DEFAULT_SIZE.y) -> float:
	return get_paddle_top(arena_size, paddle_height) - get_grid_bottom(rows)


## Most columns whose footprint fits the arena with at least
## [param min_side_gap] free on each side.
static func get_max_columns(min_side_gap: float = 0.0, arena_size: Vector2 = Playfield.get_size()) -> int:
	return maxi(floori((arena_size.x - min_side_gap * 2.0) / CELL_SIZE.x), 0)


## Most rows that keep MIN_PADDLE_CLEARANCE above the paddle.
static func get_max_rows(arena_size: Vector2 = Playfield.get_size(), paddle_height: float = Paddle.DEFAULT_SIZE.y) -> int:
	var available := get_paddle_top(arena_size, paddle_height) - MIN_PADDLE_CLEARANCE - GRID_TOP
	return maxi(floori(available / CELL_SIZE.y), 0)


static func fits(columns: int, rows: int, min_side_gap: float = 0.0, arena_size: Vector2 = Playfield.get_size(),
		paddle_height: float = Paddle.DEFAULT_SIZE.y) -> bool:
	return columns <= get_max_columns(min_side_gap, arena_size) and rows <= get_max_rows(arena_size, paddle_height)
