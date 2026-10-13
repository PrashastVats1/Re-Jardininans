extends "res://tests/test_case.gd"
## Paddle input: keyboard movement, following the pointer only while it is in
## the game window, and staying put when the pointer leaves or focus is lost.
## Pointer events are injected through Input.parse_input_event in window pixels,
## exactly like OS events, so the root viewport's stretch transform is applied.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const SETTLE_FRAMES: int = 40

var _main: Node
var _game: Game
var _paddle: Paddle
var _width: float


func run() -> void:
	_width = Playfield.get_size().x
	_main = MAIN_SCENE.instantiate()
	tree.root.add_child(_main)
	_game = _main.get_node("Game") as Game
	_game.pause_on_focus_loss = false
	_paddle = _game.get_node("Playfield/Paddle") as Paddle
	await _frames(2)

	await _test_keyboard_moves_and_clamps()
	# A real window also receives the OS cursor's own enter/exit, focus and
	# motion events, which interleave with the injected ones nondeterministically.
	if DisplayServer.get_name() == "headless":
		await _test_pointer_inside_window_is_followed()
		await _test_pointer_leaving_window_keeps_last_position()
		await _test_motion_outside_window_is_ignored()
		await _test_reentering_window_resumes_following()
		await _test_focus_loss_stops_following()
		await _test_keyboard_overrides_pointer()
		await _test_zero_motion_is_ignored()
		await _test_click_launches_without_starting_follow()
	else:
		print("      (skipped pointer checks: real window receives OS pointer events)")

	_main.queue_free()
	await tree.process_frame


func _test_keyboard_moves_and_clamps() -> void:
	await _reset_paddle()
	var start_x := _paddle.position.x
	Input.action_press("move_right")
	await _frames(10)
	Input.action_release("move_right")
	check_approx(_paddle.position.x - start_x, _paddle.keyboard_speed * 10.0 / 60.0, "[keyboard] D/Right moves the paddle at keyboard_speed", 1.0)

	Input.action_press("move_left")
	await _frames(120)
	Input.action_release("move_left")
	check_approx(_paddle.position.x, _paddle.get_half_width(), "[keyboard] paddle stops at the left playfield edge")

	Input.action_press("move_right")
	await _frames(120)
	Input.action_release("move_right")
	check_approx(_paddle.position.x, _width - _paddle.get_half_width(), "[keyboard] paddle stops at the right playfield edge")


func _test_pointer_inside_window_is_followed() -> void:
	await _reset_paddle()
	_move_pointer_to(300.0)
	await _frames(SETTLE_FRAMES)
	check(_paddle.is_following_mouse(), "[pointer] motion inside the window starts mouse-follow")
	check_approx(_paddle.position.x, 300.0, "[pointer] paddle reaches the pointer x", 0.5)


func _test_pointer_leaving_window_keeps_last_position() -> void:
	await _reset_paddle()
	_move_pointer_to(_width - 100.0)
	await _frames(3)
	var x_when_left := _paddle.position.x
	check(x_when_left > _width * 0.5 and x_when_left < _width - 100.0, "[leave] paddle was mid-way to the pointer")
	tree.root.mouse_exited.emit()
	await _frames(SETTLE_FRAMES)
	check(not _paddle.is_following_mouse(), "[leave] leaving the window stops mouse-follow")
	check_approx(_paddle.position.x, x_when_left, "[leave] paddle stays at its last position", 0.01)


func _test_motion_outside_window_is_ignored() -> void:
	await _reset_paddle()
	_move_pointer_to(500.0)
	await _frames(SETTLE_FRAMES)
	var window_size := Vector2(tree.root.size)
	# e.g. dragging with a button held past the window edge
	_send_motion_in_window_pixels(Vector2(-60.0, window_size.y * 0.5))
	await _frames(SETTLE_FRAMES)
	check_approx(_paddle.position.x, 500.0, "[outside] motion left of the window does not pull the paddle", 0.5)
	_send_motion_in_window_pixels(Vector2(window_size.x + 60.0, window_size.y * 0.5))
	await _frames(SETTLE_FRAMES)
	check_approx(_paddle.position.x, 500.0, "[outside] motion right of the window does not pull the paddle", 0.5)

	tree.root.mouse_exited.emit()
	_send_motion_in_window_pixels(Vector2(-60.0, window_size.y * 0.5))
	await _frames(SETTLE_FRAMES)
	check(not _paddle.is_following_mouse(), "[outside] outside motion after leaving does not restart follow")
	check_approx(_paddle.position.x, 500.0, "[outside] paddle never jumps to an edge", 0.5)


func _test_reentering_window_resumes_following() -> void:
	await _reset_paddle()
	tree.root.mouse_exited.emit()
	await _frames(2)
	tree.root.mouse_entered.emit()
	_move_pointer_to(900.0)
	await _frames(SETTLE_FRAMES)
	check(_paddle.is_following_mouse(), "[re-enter] moving inside again resumes mouse-follow")
	check_approx(_paddle.position.x, 900.0, "[re-enter] paddle follows the pointer again", 0.5)


func _test_focus_loss_stops_following() -> void:
	await _reset_paddle()
	_move_pointer_to(_width - 100.0)
	await _frames(3)
	var x_when_unfocused := _paddle.position.x
	tree.root.focus_exited.emit()
	await _frames(SETTLE_FRAMES)
	check(not _paddle.is_following_mouse(), "[focus] losing focus stops mouse-follow")
	check_approx(_paddle.position.x, x_when_unfocused, "[focus] paddle stays where it was", 0.01)


func _test_keyboard_overrides_pointer() -> void:
	await _reset_paddle()
	_move_pointer_to(1000.0)
	await _frames(SETTLE_FRAMES)
	Input.action_press("move_left")
	await _frames(10)
	Input.action_release("move_left")
	check(not _paddle.is_following_mouse(), "[override] a movement key cancels mouse-follow")
	check(_paddle.position.x < 1000.0 - 100.0, "[override] keyboard moves the paddle away from the pointer")
	var x_after_keys := _paddle.position.x
	await _frames(SETTLE_FRAMES)
	check_approx(_paddle.position.x, x_after_keys, "[override] paddle does not drift back to the old pointer", 0.01)


func _test_zero_motion_is_ignored() -> void:
	await _reset_paddle()
	var event := _motion_at(Vector2(200.0, 400.0))
	event.relative = Vector2.ZERO
	event.screen_relative = Vector2.ZERO
	Input.parse_input_event(event)
	await _frames(SETTLE_FRAMES)
	check(not _paddle.is_following_mouse(), "[synthetic] zero-movement motion does not start mouse-follow")
	check_approx(_paddle.position.x, _width * 0.5, "[synthetic] paddle stays centered", 0.01)


func _test_click_launches_without_starting_follow() -> void:
	await _reset_paddle()
	check_equal(_game.session.state, GameSession.State.READY, "[click] game is waiting for launch")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = tree.root.get_final_transform() * Vector2(_width * 0.5, 400.0)
	click.global_position = click.position
	Input.parse_input_event(click)
	var release := click.duplicate() as InputEventMouseButton
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)
	check_equal(_game.session.state, GameSession.State.PLAYING, "[click] left click still launches the ball")
	check(not _paddle.is_following_mouse(), "[click] a click alone does not start mouse-follow")


func _reset_paddle() -> void:
	_paddle.stop_following_mouse()
	_paddle.position.x = _width * 0.5
	tree.root.mouse_entered.emit()
	await _frames(1)


func _move_pointer_to(playfield_x: float) -> void:
	Input.parse_input_event(_motion_at(Vector2(playfield_x, 400.0)))


func _motion_at(playfield_point: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = tree.root.get_final_transform() * playfield_point
	event.global_position = event.position
	event.relative = Vector2(4.0, 0.0)
	event.screen_relative = event.relative
	return event


func _send_motion_in_window_pixels(window_point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = window_point
	event.global_position = window_point
	event.relative = Vector2(-4.0, 0.0)
	event.screen_relative = event.relative
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for i: int in count:
		await tree.physics_frame
