extends "res://tests/test_case.gd"
## The ordered level list, choosing which level the game loads, and restart
## keeping that choice and the game's settings (re-validating every time).

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const LEVEL_LIST_PATH: String = "res://data/level_list.tres"
const TEST_LEVEL_PATH: String = "res://data/levels/test_level.tres"
const SAVED_LIST_PATH: String = "user://test_level_list_order.tres"


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


func run() -> void:
	_test_level_list_file()
	_test_level_list_order()
	await _test_default_level_comes_from_the_list()
	await _test_loads_a_chosen_level()
	await _test_restart_keeps_level_and_lives()
	await _test_invalid_level_stays_rejected_after_restart()
	await _test_restart_outside_the_current_scene_is_refused()
	tree.unload_current_scene()
	await tree.process_frame


func _test_level_list_file() -> void:
	var list := load(LEVEL_LIST_PATH) as LevelList
	check(list != null, "level_list.tres loads as a LevelList")
	if list == null:
		return
	check_equal(list.size(), 1, "the list holds exactly one level for now")
	check(list.get_level(0) == load(TEST_LEVEL_PATH), "its only level is Test Garden (the shared resource, not a copy)")
	check(list.get_level(1) == null and list.get_level(-1) == null, "out-of-range indices give null")
	for index: int in list.size():
		check_equal(LevelValidator.validate(list.get_level(index)), PackedStringArray(), "list entry %d passes validation" % index)


## Order survives both in memory and a save/load round trip.
func _test_level_list_order() -> void:
	var list := LevelList.new()
	var names := ["First", "Second", "Third"]
	for level_name: String in names:
		list.levels.append(_fixture(level_name))
	check_equal(_names(list), names, "levels keep their order in memory")
	check_equal(ResourceSaver.save(list, SAVED_LIST_PATH), OK, "a list can be saved")
	var reloaded := ResourceLoader.load(SAVED_LIST_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelList
	check(reloaded != null and _names(reloaded) == names, "levels keep their order after saving and loading (%s)"
			% [_names(reloaded) if reloaded != null else null])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVED_LIST_PATH))


func _test_default_level_comes_from_the_list() -> void:
	var main := MAIN_SCENE.instantiate()
	var game := main.get_node("Game") as Game
	check(game.level == null, "the scene selects no level explicitly")
	check(game.level_list != null and game.level_list.resource_path == LEVEL_LIST_PATH, "the scene's default list is level_list.tres")
	tree.root.add_child(main)
	await tree.physics_frame
	check(game.level == game.level_list.get_level(0), "an unselected game plays the list's first level")
	check(game.has_playable_level(), "the default level is playable")
	main.queue_free()
	await tree.process_frame


func _test_loads_a_chosen_level() -> void:
	var fixture := _fixture("Fixture Bed")
	var game := await _start_as_current_scene(fixture, 3)
	check(game.level == fixture, "the chosen level is the one loaded")
	check_equal(game.get_node("Playfield/Bricks").get_child_count(), _brick_count(fixture), "the chosen level's bricks are spawned")
	check_equal(game.session.bricks_remaining, fixture.count_destructible(), "the session counts the chosen level's bricks")
	check_equal(_sidebar_text(game, "%LevelValue"), "Fixture Bed", "the sidebar names the chosen level")

	var fresh := MAIN_SCENE.instantiate()
	var fresh_game := fresh.get_node("Game") as Game
	check(fresh_game.level == null and fresh_game.level_list == load(LEVEL_LIST_PATH), "the scene's defaults are untouched by choosing a level")
	check_equal((load(LEVEL_LIST_PATH) as LevelList).size(), 1, "the level list is untouched by choosing a level")
	fresh.free()


func _test_restart_keeps_level_and_lives() -> void:
	var fixture := _fixture("Fixture Bed")
	var game := await _start_as_current_scene(fixture, 5)
	check_equal(game.session.lives, 5, "the game starts with the configured 5 lives")
	await _win(game)
	check_equal(game.session.state, GameSession.State.WON, "the chosen level can be won")
	OS.delay_msec(Game.RESTART_DELAY_MSEC + 50)
	_press("launch_ball")
	var restarted := await _current_game_after(game)
	_check_same_setup(restarted, fixture, 5, "after winning")
	if restarted == null:
		return
	restarted.restart()
	_check_same_setup(await _current_game_after(restarted), fixture, 5, "after a second restart")


func _test_invalid_level_stays_rejected_after_restart() -> void:
	print("      (3 errors expected below: an invalid level reported on load and on reload, and a refused restart)")
	var invalid := _fixture("Broken Bed")
	invalid.rows = PackedStringArray(["AAAA", "SS"])
	var log := ErrorLog.new()
	OS.add_logger(log)
	var game := await _start_as_current_scene(invalid, 4)
	var expected := LevelValidator.validate(invalid)
	check(not expected.is_empty(), "the invalid fixture has diagnostics")
	check(not game.has_playable_level(), "the invalid level is rejected on first load")
	check_equal(log.take(), expected, "first load reports exactly the level's diagnostics")
	game.restart()
	var restarted := await _current_game_after(game)
	check_equal(log.take(), expected, "the reload reports the same diagnostics again")
	OS.remove_logger(log)
	check(restarted != null and restarted.level == invalid, "the reload keeps the invalid level instead of falling back to the default")
	if restarted == null:
		return
	check(not restarted.has_playable_level(), "the invalid level is still rejected after the reload")
	check_equal(restarted.get_node("Playfield/Bricks").get_child_count(), 0, "still no bricks are spawned")
	check_equal(restarted.starting_lives, 4, "starting lives are kept across the reload")
	check_equal((restarted.get_node("Hud").get_node("%MessageTitle") as Label).text, "Level unavailable", "the player is still told the level is unavailable")


func _test_restart_outside_the_current_scene_is_refused() -> void:
	var main := MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	var game := main.get_node("Game") as Game
	var scene_before := tree.current_scene
	var log := ErrorLog.new()
	OS.add_logger(log)
	game.restart()
	await tree.process_frame
	await tree.process_frame
	OS.remove_logger(log)
	var errors := log.take()
	check(errors.size() == 1 and errors[0].contains("current scene"), "restart explains why it can't run (%s)" % [errors])
	check(tree.current_scene == scene_before and is_instance_valid(game), "nothing is replaced")
	main.queue_free()
	await tree.process_frame


func _check_same_setup(game: Game, level: LevelData, lives: int, label: String) -> void:
	check(game != null, "[%s] a fresh game is running" % label)
	if game == null:
		return
	check(game.level == level, "[%s] the same level is loaded, not the default" % label)
	check_equal(game.starting_lives, lives, "[%s] starting lives are kept" % label)
	check_equal(game.session.lives, lives, "[%s] the session starts with those lives" % label)
	check_equal(game.session.state, GameSession.State.READY, "[%s] the game is READY" % label)
	check_equal(game.session.score, 0, "[%s] score is reset" % label)
	check_equal(game.get_node("Playfield/Bricks").get_child_count(), _brick_count(level), "[%s] the level's bricks are respawned" % label)
	check(_sidebar_text(game, "%LevelValue") == level.display_name and _sidebar_text(game, "%LivesValue") == str(lives),
			"[%s] the sidebar shows the level and lives" % label)
	check(not game.pause_on_focus_loss, "[%s] other game settings are kept too" % label)


func _start_as_current_scene(level: LevelData, lives: int) -> Game:
	var main := MAIN_SCENE.instantiate()
	var game := main.get_node("Game") as Game
	game.level = level
	game.starting_lives = lives
	game.pause_on_focus_loss = false
	tree.change_scene_to_node(main)
	await tree.process_frame
	await tree.process_frame
	game.get_node("Playfield/Paddle").set_physics_process(false)
	return game


## Waits for the scene swap a restart schedules and returns the new game.
func _current_game_after(old_game: Game) -> Game:
	for i: int in 5:
		await tree.process_frame
	if is_instance_valid(old_game):
		check(false, "the old game was freed by the restart")
		return null
	var game := tree.current_scene.get_node_or_null("Game") as Game if tree.current_scene != null else null
	if game != null:
		game.get_node("Playfield/Paddle").set_physics_process(false)
	return game


func _win(game: Game) -> void:
	_press("launch_ball")
	await tree.physics_frame
	for child: Node in game.get_node("Playfield/Bricks").get_children():
		var brick := child as Brick
		while brick.is_destructible() and brick.hit_points > 0:
			brick.hit()


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _fixture(level_name: String) -> LevelData:
	var flower := BrickType.new()
	flower.display_name = "Fixture flower"
	var stone := BrickType.new()
	stone.display_name = "Fixture stone"
	stone.points = 0
	stone.destructible = false
	var level := LevelData.new()
	level.display_name = level_name
	level.rows = PackedStringArray(["AAAA", "S..S"])
	level.legend = {"A": flower, "S": stone}
	return level


func _brick_count(level: LevelData) -> int:
	var count := 0
	for row: String in level.rows:
		for column: int in row.length():
			if level.get_brick_type(row[column]) != null:
				count += 1
	return count


func _names(list: LevelList) -> Array:
	var names: Array = []
	for index: int in list.size():
		names.append(list.get_level(index).display_name)
	return names


func _sidebar_text(game: Game, label_path: String) -> String:
	return (game.get_node("Hud/Sidebar").get_node(label_path) as Label).text
