extends "res://tests/test_case.gd"
## LevelValidator: one in-memory fixture per structural and grid-fit rule, with
## the fit limits derived from LevelGrid rather than written down, plus the
## game refusing to build a level that fails.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const BALL_SCENE: PackedScene = preload("res://entities/ball/ball.tscn")
const LEVELS_DIR: String = "res://data/levels"


class ErrorLog extends Logger:
	var _mutex: Mutex = Mutex.new()
	var _errors: PackedStringArray = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		_errors.append(code if rationale.is_empty() else "%s %s" % [code, rationale])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var copy := _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return copy


var _ball_diameter: float = Ball.DEFAULT_RADIUS * 2.0


func run() -> void:
	_test_stock_ball_matches_default()
	_test_valid_levels()
	_test_structure_rules()
	_test_brick_type_rules()
	_test_fit_rules()
	_test_diagnostics_name_the_level()
	_test_level_files_are_valid()
	await _test_game_refuses_invalid_levels()
	await _test_game_builds_a_valid_fixture()


func _test_stock_ball_matches_default() -> void:
	var ball := BALL_SCENE.instantiate() as Ball
	check_equal(ball.radius, Ball.DEFAULT_RADIUS, "the ball scene uses Ball.DEFAULT_RADIUS, which validation assumes")
	ball.free()


func _test_valid_levels() -> void:
	check_equal(_problems(["AB", "BA"], {"A": _type(), "B": _type()}), PackedStringArray(), "a small well-formed level is valid")
	check_equal(_problems(["S.A.S"], {"A": _type(), "S": _stone()}), PackedStringArray(),
			"indestructible bricks are allowed alongside destructible ones")
	check_equal(_problems(["A A"], {"A": _type()}), PackedStringArray(), "a space is an empty cell")


func _test_structure_rules() -> void:
	var a := _type()
	_expect_includes(_problems([], {}), "level has no rows", "empty level")
	_expect_includes(_problems(["", ""], {}), "rows have no cells", "rows with no cells")
	_expect_one(_problems(["AAA", "AA"], {"A": a}), ["row 1", "2 cells", "row 0 is 3", "same width"], "unequal row lengths")
	_expect_one(_problems(["AA", "AAA"], {"A": a}), ["row 1", "3 cells", "row 0 is 2"], "a longer later row")
	_expect_one(_problems(["AX"], {"A": a}), ["row 0, column 1", "'X'", "not in the legend"], "unknown row character")
	_expect_one(_problems(["AN"], {"A": a, "N": null}), ["'N'", "not a BrickType"], "null legend entry")
	_expect_one(_problems(["AN"], {"A": a, "N": Resource.new()}), ["'N'", "not a BrickType"], "legend entry of the wrong type")
	_expect_one(_problems(["A"], {"A": a, "AB": a}), ["\"AB\"", "single character"], "multi-character legend key")
	_expect_one(_problems(["A"], {"A": a, 7: a}), ["7", "single character"], "non-string legend key")
	_expect_one(_problems(["A."], {"A": a, ".": a}), ["'.'", "reserved for empty cells"], "legend entry for the empty-cell symbol")
	_expect_one(_problems(["A"], {"A": a, "B": _type()}), ["'B'", "not used"], "unused legend entry")
	_expect_one(_problems(["SS"], {"S": _stone()}), ["no destructible bricks"], "only indestructible bricks")
	var many := _problems(["AX", "A"], {"A": a, "B": a})
	check_equal(many.size(), 3, "every problem is reported at once, not just the first (%s)" % [many])


func _test_brick_type_rules() -> void:
	_expect_one(_problems(["A"], {"A": _type(0)}), ["'A'", "Fixture", "hit points must be at least 1", "got 0"], "brick type with 0 hit points")
	_expect_one(_problems(["A"], {"A": _type(1, -5)}), ["'A'", "points must not be negative", "got -5"], "brick type with negative points")
	check_equal(_problems(["A"], {"A": _type(1, 0)}), PackedStringArray(), "a destructible brick worth 0 points is allowed")
	check_equal(_type(0, -1).validate().size(), 2, "BrickType reports both problems")


## Exactly at each LevelGrid limit is valid; one more column or row is not.
func _test_fit_rules() -> void:
	var a := _type()
	var max_columns := LevelGrid.get_max_columns(_ball_diameter)
	var max_rows := LevelGrid.get_max_rows()
	check(max_columns > 0 and max_rows > 0, "the arena fits at least one column and row (%d x %d)" % [max_columns, max_rows])
	check(LevelGrid.get_max_columns(0.0) > max_columns, "the ball gap costs at least one column")

	check_equal(_problems(_grid(max_columns, 1), {"A": a}), PackedStringArray(), "%d columns (the limit) fit" % max_columns)
	_expect_one(_problems(_grid(max_columns + 1, 1), {"A": a}), ["%d columns are too wide" % (max_columns + 1), "at most %d" % max_columns],
			"one column over the limit")
	check_equal(_problems(_grid(1, max_rows), {"A": a}), PackedStringArray(), "%d rows (the limit) fit" % max_rows)
	_expect_one(_problems(_grid(1, max_rows + 1), {"A": a}), ["%d rows are too tall" % (max_rows + 1), "at least %.0f px" % LevelGrid.MIN_PADDLE_CLEARANCE],
			"one row over the limit")
	check_equal(_problems(_grid(max_columns + 1, max_rows + 1), {"A": a}).size(), 2, "too wide and too tall are both reported")

	var level := _level(_grid(max_columns, 1), {"A": a})
	var wider_ball := LevelGrid.get_side_gap(max_columns) + 1.0
	check_equal(LevelValidator.check_fit(level, wider_ball).size(), 1, "a ball wider than the side gap rejects the same grid")
	var narrow := Playfield.get_size() - Vector2(LevelGrid.CELL_SIZE.x, 0.0)
	check_equal(LevelValidator.check_fit(level, _ball_diameter, narrow).size(), 1, "a narrower arena rejects the same grid")
	var short := Playfield.get_size() - Vector2(0.0, LevelGrid.CELL_SIZE.y)
	check_equal(LevelValidator.check_fit(_level(_grid(1, max_rows), {"A": a}), _ball_diameter, short).size(), 1,
			"a shorter arena rejects the same rows")


func _test_diagnostics_name_the_level() -> void:
	var level := _level(["AX"], {"A": _type()})
	level.display_name = "Broken Bed"
	var problems := LevelValidator.validate(level)
	check(problems.size() == 1 and problems[0].begins_with("level \"Broken Bed\": "), "unsaved levels are named by display name (%s)" % [problems])
	level.display_name = ""
	problems = LevelValidator.validate(level)
	check(problems.size() == 1 and problems[0].begins_with("unsaved level: "), "nameless levels still get a label (%s)" % [problems])
	check_equal(LevelValidator.describe(load(LEVELS_DIR.path_join("test_level.tres"))), LEVELS_DIR.path_join("test_level.tres"),
			"saved levels are named by path")
	check_equal(LevelValidator.validate(null), PackedStringArray(["no level assigned"]), "a missing level is reported")


func _test_level_files_are_valid() -> void:
	var checked := 0
	for file: String in DirAccess.get_files_at(LEVELS_DIR):
		if file.get_extension() != "tres":
			continue
		var level := load(LEVELS_DIR.path_join(file)) as LevelData
		check(level != null, "%s loads as LevelData" % file)
		if level != null:
			checked += 1
			check_equal(LevelValidator.validate(level), PackedStringArray(), "%s passes validation" % file)
	check(checked > 0, "at least one level file was validated")


func _test_game_refuses_invalid_levels() -> void:
	print("      (3 errors expected below: the game reporting deliberately invalid levels)")
	var too_wide := _level(_grid(LevelGrid.get_max_columns(_ball_diameter) + 1, 1), {"A": _type()})
	await _check_refused(_level(["AAA", "AA"], {"A": _type()}), "same width", "unequal rows")
	await _check_refused(too_wide, "too wide", "too wide")
	await _check_refused(null, "no level assigned", "no level")


## Every engine error logged from building the game until the end of the check
## must be one of the level's own diagnostics, so an unrelated error (or a
## restart attempt) fails the test instead of passing as "the expected error".
func _check_refused(level: LevelData, expected_error: String, label: String) -> void:
	var log := ErrorLog.new()
	OS.add_logger(log)
	var game := await _start_game(level)
	var ball := game.get_node("Playfield/Ball") as Ball
	var paddle := game.get_node("Playfield/Paddle") as Paddle
	var expected := LevelValidator.validate(level, ball.radius * 2.0, Playfield.get_size(), paddle.size.y)
	check(expected.size() >= 1 and Array(expected).any(func(problem: String) -> bool: return problem.contains(expected_error)),
			"[%s] the validator diagnoses '%s' (%s)" % [label, expected_error, expected])
	check(not game.has_playable_level(), "[%s] game reports the level as unplayable" % label)
	check_equal(game.get_node("Playfield/Bricks").get_child_count(), 0, "[%s] no bricks are spawned" % label)
	check_equal(game.session.bricks_remaining, 0, "[%s] nothing to clear" % label)
	var hud := game.get_node("Hud")
	check((hud.get_node("%MessagePanel") as Control).visible and (hud.get_node("%MessageTitle") as Label).text == "Level unavailable",
			"[%s] the player is told the level is unavailable" % label)

	var session_events: Array[String] = []
	game.session.state_changed.connect(func(state: GameSession.State) -> void: session_events.append("state %d" % state))
	game.session.score_changed.connect(func(score: int) -> void: session_events.append("score %d" % score))
	game.session.lives_changed.connect(func(lives: int) -> void: session_events.append("lives %d" % lives))
	var ball_at := ball.position
	# Past the restart delay too, so a press can't be mistaken for a restart.
	OS.delay_msec(Game.RESTART_DELAY_MSEC + 50)
	for press: int in 3:
		_press("launch_ball")
		for i: int in 10:
			await tree.physics_frame
	check_equal(game.session.state, GameSession.State.READY, "[%s] launch is ignored" % label)
	check(ball.is_attached() and ball.position == ball_at, "[%s] ball stays still on the paddle" % label)
	check_equal(session_events, [] as Array[String], "[%s] no score, lives or state change" % label)
	check(is_instance_valid(game) and game.is_inside_tree(), "[%s] the game is not restarted or freed" % label)
	check_equal(log.take(), expected, "[%s] the only engine errors are the level's diagnostics, once each" % label)
	OS.remove_logger(log)
	await _end_game(game)


func _test_game_builds_a_valid_fixture() -> void:
	var rows := ["S.AB.S", "AABBAA"]
	var level := _level(rows, {"A": _type(), "B": _type(2, 70), "S": _stone()})
	var log := ErrorLog.new()
	OS.add_logger(log)
	var game := await _start_game(level)
	OS.remove_logger(log)
	check_equal(log.take(), PackedStringArray(), "[valid fixture] no engine errors")
	check(game.has_playable_level(), "[valid fixture] game accepts it")
	check_equal(game.get_node("Playfield/Bricks").get_child_count(), 10, "[valid fixture] every brick is spawned")
	check_equal(game.session.bricks_remaining, level.count_destructible(), "[valid fixture] destructible count comes from the level")
	check_equal((game.get_node("Hud").get_node("%MessageTitle") as Label).text, "Re-Jardinians!", "[valid fixture] normal start message")
	await _end_game(game)


func _start_game(level: LevelData) -> Game:
	var main := MAIN_SCENE.instantiate()
	var game := main.get_node("Game") as Game
	game.level = level
	game.pause_on_focus_loss = false
	tree.root.add_child(main)
	main.get_node("Game/Playfield/Paddle").set_physics_process(false)
	await tree.physics_frame
	return game


func _end_game(game: Game) -> void:
	tree.paused = false
	game.get_parent().queue_free()
	await tree.process_frame


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _expect_includes(problems: PackedStringArray, fragment: String, label: String) -> void:
	check(Array(problems).any(func(problem: String) -> bool: return problem.contains(fragment)),
			"%s: a problem mentions '%s' (got %s)" % [label, fragment, problems])


func _expect_one(problems: PackedStringArray, fragments: Array, label: String) -> void:
	var ok := problems.size() == 1
	for fragment: String in fragments:
		ok = ok and problems[0].contains(fragment)
	check(ok, "%s: exactly one problem mentioning %s (got %s)" % [label, fragments, problems])


func _problems(rows: Array, legend: Dictionary) -> PackedStringArray:
	var level := _level(rows, legend)
	var labelled := LevelValidator.validate(level, _ball_diameter)
	var prefix := LevelValidator.describe(level) + ": "
	var plain: PackedStringArray = []
	for problem: String in labelled:
		check(problem.begins_with(prefix), "problem is prefixed with the level's label: %s" % problem)
		plain.append(problem.trim_prefix(prefix))
	return plain


func _level(rows: Array, legend: Dictionary) -> LevelData:
	var level := LevelData.new()
	level.rows = PackedStringArray(rows)
	level.legend = legend
	return level


func _grid(columns: int, rows: int) -> Array:
	var grid: Array = []
	for row: int in rows:
		grid.append("A".repeat(columns))
	return grid


func _type(hit_points: int = 1, points: int = 50) -> BrickType:
	var brick_type := BrickType.new()
	brick_type.display_name = "Fixture"
	brick_type.hit_points = hit_points
	brick_type.points = points
	return brick_type


func _stone() -> BrickType:
	var stone := _type(1, 0)
	stone.display_name = "Fixture stone"
	stone.destructible = false
	return stone
