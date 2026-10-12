extends "res://tests/test_case.gd"
## Restart after game over / victory, driven by real key and mouse events with
## main.tscn as the current scene (as when the game is launched normally).
## Engine errors are captured so the old "set_input_as_handled on a null value"
## script error fails the test instead of only being printed.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")


class ErrorLog extends Logger:
	var _mutex: Mutex = Mutex.new()
	var _errors: PackedStringArray = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		_errors.append("%s:%d %s %s" % [file.get_file(), line, code, rationale])
		_mutex.unlock()

	func take() -> PackedStringArray:
		_mutex.lock()
		var copy := _errors.duplicate()
		_errors.clear()
		_mutex.unlock()
		return copy


var _log: ErrorLog = ErrorLog.new()


func run() -> void:
	OS.add_logger(_log)
	await _test_restart_after_game_over(_space_key(), "Space")
	await _test_restart_after_game_over(_left_click(), "left click")
	await _test_restart_after_victory()
	await _test_restart_ignored_during_delay()
	OS.remove_logger(_log)
	tree.unload_current_scene()
	await tree.process_frame


func _test_restart_after_game_over(restart_event: InputEvent, label: String) -> void:
	var game := await _load_main_as_current_scene()
	await _play_until_game_over(game)
	check_equal(game.session.state, GameSession.State.GAME_OVER, "[%s] reached game over" % label)
	await _restart_with(restart_event, game, label)


func _test_restart_after_victory() -> void:
	var game := await _load_main_as_current_scene()
	_send(_space_key())
	await tree.physics_frame
	for child: Node in game.get_node("Playfield/Bricks").get_children():
		var brick := child as Brick
		while brick.is_destructible() and brick.hit_points > 0:
			brick.hit()
	check_equal(game.session.state, GameSession.State.WON, "[victory] destroying every brick wins")
	await _restart_with(_left_click(), game, "victory")


func _test_restart_ignored_during_delay() -> void:
	var game := await _load_main_as_current_scene()
	await _play_until_game_over(game)
	var old_main := tree.current_scene
	_send(_space_key())
	for i: int in 5:
		await tree.process_frame
	check(tree.current_scene == old_main, "[delay] a press right after game over does not restart")
	check_equal(game.session.state, GameSession.State.GAME_OVER, "[delay] still GAME_OVER")
	check_equal(_log.take(), PackedStringArray(), "[delay] no engine errors")


func _restart_with(restart_event: InputEvent, game: Game, label: String) -> void:
	var old_main := tree.current_scene
	_log.take()
	OS.delay_msec(Game.RESTART_DELAY_MSEC + 50)
	_send(restart_event)
	for i: int in 5:
		await tree.process_frame
	check_equal(_log.take(), PackedStringArray(), "[%s] restart input produces no engine errors" % label)
	check(not is_instance_valid(game), "[%s] old game was freed" % label)

	var new_main := tree.current_scene
	check(new_main != null and new_main != old_main, "[%s] restart loads a fresh main scene" % label)
	if new_main == null or new_main == old_main:
		return
	var new_game := new_main.get_node("Game") as Game
	check_equal(new_game.session.state, GameSession.State.READY, "[%s] restarted game is READY" % label)
	check_equal(new_game.session.score, 0, "[%s] score reset to 0" % label)
	check_equal(new_game.session.lives, 3, "[%s] lives reset to 3" % label)
	check_equal(new_game.session.bricks_remaining, 52, "[%s] 52 destructible bricks again" % label)
	check_equal(new_game.get_node("Playfield/Bricks").get_child_count(), 54, "[%s] full brick layout respawned" % label)
	check((new_game.get_node("Playfield/Ball") as Ball).is_attached(), "[%s] ball reset onto the paddle" % label)
	check_approx((new_game.get_node("Playfield/Paddle") as Node2D).position.x, 640.0, "[%s] paddle reset to center" % label)
	check(not tree.paused, "[%s] tree is not paused after restart" % label)


func _load_main_as_current_scene() -> Game:
	tree.change_scene_to_packed(MAIN_SCENE)
	await tree.process_frame
	await tree.process_frame
	var game := tree.current_scene.get_node("Game") as Game
	game.pause_on_focus_loss = false
	game.get_node("Playfield/Paddle").set_physics_process(false)
	return game


func _play_until_game_over(game: Game) -> void:
	var paddle := game.get_node("Playfield/Paddle") as Paddle
	var ball := game.get_node("Playfield/Ball") as Ball
	var steps := 0
	while game.session.state != GameSession.State.GAME_OVER and steps < 60 * 60:
		if game.session.state == GameSession.State.READY:
			_send(_space_key())
		elif not ball.is_attached():
			paddle.position.x = paddle.get_half_width() if ball.position.x > 640.0 else 1280.0 - paddle.get_half_width()
		await tree.physics_frame
		steps += 1


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	var release := event.duplicate() as InputEvent
	if release is InputEventKey:
		(release as InputEventKey).pressed = false
	elif release is InputEventMouseButton:
		(release as InputEventMouseButton).pressed = false
	Input.parse_input_event(release)


func _space_key() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.keycode = KEY_SPACE
	event.pressed = true
	return event


func _left_click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(640.0, 400.0)
	event.global_position = event.position
	return event
