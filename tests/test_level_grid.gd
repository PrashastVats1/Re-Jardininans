extends "res://tests/test_case.gd"
## LevelGrid geometry: the shared numbers agree with the scenes, the limits are
## right at and around their boundaries, and the running game places the Test
## Garden bricks and the paddle exactly where the grid says.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const BRICK_SCENE: PackedScene = preload("res://entities/brick/brick.tscn")
const ARENA: Vector2 = Vector2(960.0, 720.0)
const PADDLE_HEIGHT: float = 22.0


func run() -> void:
	_test_constants_match_scenes()
	_test_default_arena_is_the_playfield()
	_test_limits_for_the_960x720_arena()
	_test_clearance_boundary()
	_test_width_boundary()
	_test_layouts_that_do_not_fit()
	_test_tiny_arenas()
	_test_cell_centers()
	await _test_game_uses_the_grid()


func _test_constants_match_scenes() -> void:
	check_equal(LevelGrid.CELL_SIZE, LevelGrid.BRICK_SIZE + LevelGrid.SPACING, "a cell is a brick plus spacing")
	check_equal(Brick.SIZE, LevelGrid.BRICK_SIZE, "Brick.SIZE is the grid's brick size")
	var brick := BRICK_SCENE.instantiate()
	var shape := (brick.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	check_equal(shape.size, LevelGrid.BRICK_SIZE, "brick collision shape matches the grid's brick size")
	brick.free()
	check_equal(Paddle.DEFAULT_SIZE.y, PADDLE_HEIGHT, "paddle default height is %.0f px" % PADDLE_HEIGHT)


func _test_default_arena_is_the_playfield() -> void:
	var arena := Playfield.get_size()
	check_equal(LevelGrid.get_max_columns(), LevelGrid.get_max_columns(0.0, arena), "max columns default to the playfield")
	check_equal(LevelGrid.get_max_rows(), LevelGrid.get_max_rows(arena, Paddle.DEFAULT_SIZE.y), "max rows default to the playfield and paddle")
	check_equal(LevelGrid.get_paddle_y(), arena.y - LevelGrid.PADDLE_BOTTOM_OFFSET, "paddle y defaults to the playfield")


func _test_limits_for_the_960x720_arena() -> void:
	check_equal(LevelGrid.CELL_SIZE, Vector2(80.0, 32.0), "cells are 80x32")
	check_equal(LevelGrid.get_max_columns(0.0, ARENA), 12, "12 columns fill 960 px")
	check_equal(LevelGrid.get_max_columns(20.0, ARENA), 11, "11 columns leave a 20 px gap on each side")
	check_equal(LevelGrid.get_paddle_y(ARENA), 660.0, "paddle centre 60 px above the bottom")
	check_equal(LevelGrid.get_paddle_top(ARENA, PADDLE_HEIGHT), 649.0, "paddle top at 649")
	check_equal(LevelGrid.get_max_rows(ARENA, PADDLE_HEIGHT), 10, "10 rows keep 200 px above the paddle")
	check_equal(LevelGrid.get_paddle_clearance(5, ARENA, PADDLE_HEIGHT), 385.0, "5 rows leave 385 px")
	check_equal(LevelGrid.get_paddle_clearance(10, ARENA, PADDLE_HEIGHT), 225.0, "10 rows leave 225 px")
	check_equal(LevelGrid.get_paddle_clearance(11, ARENA, PADDLE_HEIGHT), 193.0, "11 rows leave only 193 px")
	check_equal(LevelGrid.get_footprint_size(11, 5), Vector2(880.0, 160.0), "11x5 footprint")
	check_equal(LevelGrid.get_side_gap(11, ARENA), 40.0, "11 columns leave 40 px each side")


## Exactly MIN_PADDLE_CLEARANCE is allowed; one pixel less is not.
func _test_clearance_boundary() -> void:
	var exact := Vector2(960.0, LevelGrid.GRID_TOP + 10 * 32.0 + LevelGrid.MIN_PADDLE_CLEARANCE + PADDLE_HEIGHT * 0.5 + LevelGrid.PADDLE_BOTTOM_OFFSET)
	check_equal(exact.y, 695.0, "boundary arena is 695 px tall")
	check_equal(LevelGrid.get_paddle_clearance(10, exact, PADDLE_HEIGHT), LevelGrid.MIN_PADDLE_CLEARANCE, "[695] 10 rows leave exactly the minimum")
	check_equal(LevelGrid.get_max_rows(exact, PADDLE_HEIGHT), 10, "[695] exactly the minimum still fits 10 rows")
	check(LevelGrid.fits(1, 10, 0.0, exact, PADDLE_HEIGHT), "[695] a 10-row layout fits")
	var short := exact - Vector2(0.0, 1.0)
	check_equal(LevelGrid.get_paddle_clearance(10, short, PADDLE_HEIGHT), LevelGrid.MIN_PADDLE_CLEARANCE - 1.0, "[694] 10 rows leave 1 px too little")
	check_equal(LevelGrid.get_max_rows(short, PADDLE_HEIGHT), 9, "[694] only 9 rows fit")
	check(not LevelGrid.fits(1, 10, 0.0, short, PADDLE_HEIGHT), "[694] a 10-row layout does not fit")


## A footprint exactly as wide as the space allowed fits; one pixel less does not.
func _test_width_boundary() -> void:
	check_equal(LevelGrid.get_side_gap(12, ARENA), 0.0, "12 columns touch both walls")
	check(LevelGrid.fits(12, 1, 0.0, ARENA, PADDLE_HEIGHT), "12 columns fit with no side gap")
	check_equal(LevelGrid.get_max_columns(0.0, Vector2(959.0, 720.0)), 11, "[959] a pixel narrower fits only 11")
	check_equal(LevelGrid.get_max_columns(20.0, Vector2(920.0, 720.0)), 11, "[920, gap 20] 11 columns fit exactly")
	check_equal(LevelGrid.get_max_columns(20.0, Vector2(919.0, 720.0)), 10, "[919, gap 20] only 10 fit")


func _test_layouts_that_do_not_fit() -> void:
	check(not LevelGrid.fits(13, 1, 0.0, ARENA, PADDLE_HEIGHT), "13 columns are too wide")
	check_equal(LevelGrid.get_side_gap(13, ARENA), -40.0, "13 columns overhang each wall by 40 px")
	check(not LevelGrid.fits(12, 1, 20.0, ARENA, PADDLE_HEIGHT), "12 columns leave no room for a 20 px gap")
	check(not LevelGrid.fits(11, 11, 0.0, ARENA, PADDLE_HEIGHT), "11 rows are too tall")
	check(LevelGrid.fits(11, 10, 20.0, ARENA, PADDLE_HEIGHT), "11x10 with a 20 px gap fits")
	check(LevelGrid.fits(0, 0, 0.0, ARENA, PADDLE_HEIGHT), "an empty grid fits")


func _test_tiny_arenas() -> void:
	check_equal(LevelGrid.get_max_columns(0.0, Vector2(50.0, 720.0)), 0, "narrower than one cell fits no columns")
	check_equal(LevelGrid.get_max_columns(40.0, Vector2(60.0, 720.0)), 0, "gaps wider than the arena fit no columns, never negative")
	check_equal(LevelGrid.get_max_rows(Vector2(960.0, 300.0), PADDLE_HEIGHT), 0, "an arena too short for the clearance fits no rows, never negative")


func _test_cell_centers() -> void:
	check_equal(LevelGrid.get_cell_center(0, 0, 11, ARENA), Vector2(80.0, 120.0), "11 columns: first centre")
	check_equal(LevelGrid.get_cell_center(10, 4, 11, ARENA), Vector2(880.0, 248.0), "11 columns: row 4, last column centre")
	check_equal(LevelGrid.get_cell_center(1, 1, 11, ARENA) - LevelGrid.get_cell_center(0, 0, 11, ARENA), LevelGrid.CELL_SIZE,
			"neighbouring centres are one cell apart")
	for columns: int in [1, 4, 11, 12]:
		var first := LevelGrid.get_cell_center(0, 0, columns, ARENA)
		var last := LevelGrid.get_cell_center(columns - 1, 0, columns, ARENA)
		check_equal((first.x + last.x) * 0.5, ARENA.x * 0.5, "%d columns are centred" % columns)
		check_equal(first - LevelGrid.CELL_SIZE * 0.5, Vector2(LevelGrid.get_side_gap(columns, ARENA), LevelGrid.GRID_TOP),
				"%d columns: footprint starts at the side gap and GRID_TOP" % columns)


## The Test Garden layout predates LevelGrid; its pinned corner positions and
## the paddle start prove the refactor moved nothing.
func _test_game_uses_the_grid() -> void:
	var main := MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	var game := main.get_node("Game") as Game
	var level := game.level
	var columns := level.get_column_count()
	var expected: Array[Vector2] = []
	for row: int in level.rows.size():
		for column: int in columns:
			if level.get_brick_type(level.rows[row][column]) != null:
				expected.append(LevelGrid.get_cell_center(column, row, columns))
	var actual: Array[Vector2] = []
	for child: Node in game.get_node("Playfield/Bricks").get_children():
		actual.append((child as Node2D).position)
	check_equal(actual, expected, "every brick sits at its grid cell centre, in row order")
	check(actual.has(Vector2(240.0, 120.0)) and actual.has(Vector2(720.0, 120.0)), "clay pots span x 240 to 720 on row 0 (y 120)")
	check(actual.has(Vector2(80.0, 152.0)) and actual.has(Vector2(880.0, 216.0)), "full rows span x 80 to 880 (y 152 to 216)")
	check(actual.has(Vector2(240.0, 248.0)) and actual.has(Vector2(720.0, 248.0)), "stones at x 240 and 720 on row 4 (y 248)")
	var paddle := game.get_node("Playfield/Paddle") as Paddle
	check_equal(paddle.position, Vector2(480.0, 660.0), "paddle starts at (480, 660)")
	check_equal(paddle.size, Paddle.DEFAULT_SIZE, "game's paddle uses the default size the grid assumes")
	main.queue_free()
	await tree.process_frame
