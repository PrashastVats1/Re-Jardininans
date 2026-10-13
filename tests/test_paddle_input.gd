extends "res://tests/test_case.gd"
## Paddle input: keyboard movement, following the pointer only while it is over
## the arena inside the game window, finishing the last in-arena move when the
## pointer leaves, and stopping at once on keyboard input or focus loss.
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
		await _test_fast_pointer_inside_arena_is_tracked()
		await _test_leaving_window_mid_chase_finishes_at_last_target()
		await _test_leaving_into_sidebar_mid_chase_settles_at_boundary()
		await _test_target_is_clamped_to_paddle_range()
		await _test_motion_outside_window_is_ignored()
		await _test_reentering_window_resumes_following()
		await _test_focus_loss_stops_following()
		await _test_keyboard_overrides_pointer()
		await _test_keyboard_cancels_unfinished_mouse_target()
		await _test_zero_motion_is_ignored()
		await _test_pointer_outside_arena_is_ignored_at_offset_layouts()
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


## A quick sweep across most of the arena in three frames: the paddle catches
## up within about 130 ms (8 physics frames) of the pointer stopping.
func _test_fast_pointer_inside_arena_is_tracked() -> void:
	await _reset_paddle()
	_paddle.position.x = 100.0
	for x: float in [400.0, 600.0, 860.0]:
		_move_pointer_to(x)
		await _frames(1)
	check(_paddle.is_following_mouse(), "[fast] fast motion inside the arena keeps mouse-follow")
	await _frames(8)
	check_approx(_paddle.position.x, 860.0, "[fast] paddle reaches the pointer within 8 frames after it stops", 0.01)


func _test_leaving_window_mid_chase_finishes_at_last_target() -> void:
	await _reset_paddle()
	_move_pointer_to(_width - 100.0)
	await _frames(2)
	var x_when_left := _paddle.position.x
	check(x_when_left > _width * 0.5 and x_when_left < _width - 100.0, "[leave] paddle was mid-way to the pointer (x=%.0f)" % x_when_left)
	tree.root.mouse_exited.emit()
	await _frames(1)
	check(not _paddle.is_following_mouse(), "[leave] leaving the window stops accepting pointer targets")
	await _frames(SETTLE_FRAMES)
	check_approx(_paddle.position.x, _width - 100.0, "[leave] paddle finishes at the last in-arena target", 0.01)
	check(not _paddle.has_mouse_target(), "[leave] the finished target is dropped")
	_paddle.position.x = 400.0
	await _frames(SETTLE_FRAMES)
	check_approx(_paddle.position.x, 400.0, "[leave] nothing pulls the paddle after it settles", 0.01)


## Pointer jumps toward the right edge, then over the sidebar while the paddle
## is still catching up: the paddle stops at the right edge of its range.
func _test_leaving_into_sidebar_mid_chase_settles_at_boundary() -> void:
	await _reset_paddle()
	_move_pointer_to(_width - 20.0)
	await _frames(2)
	var x_mid := _paddle.position.x
	Input.parse_input_event(_motion_at(Vector2(_width + GameLayout.SIDEBAR_WIDTH * 0.5, 400.0)))
	await _frames(1)
	check(x_mid > _width * 0.5 and x_mid < _width - 20.0 - _paddle.get_half_width(), "[sidebar] paddle was still catching up (x=%.0f)" % x_mid)
	check(not _paddle.is_following_mouse(), "[sidebar] pointer over the sidebar stops accepting targets")
	Input.parse_input_event(_motion_at(Vector2(_width + 40.0, 400.0)))
	Input.parse_input_event(_motion_at(Vector2(_width + 200.0, 600.0)))
	await _frames(SETTLE_FRAMES)
	check_approx(_paddle.position.x, _width - _paddle.get_half_width(), "[sidebar] paddle settles at its clamped right boundary", 0.01)
	check(not _paddle.is_following_mouse() and not _paddle.has_mouse_target(), "[sidebar] sidebar motion never restarts mouse control")


func _test_target_is_clamped_to_paddle_range() -> void:
	await _reset_paddle()
	_move_pointer_to(5.0)
	await _frames(SETTLE_FRAMES)
	check_approx(_paddle.position.x, _paddle.get_half_width(), "[clamp] pointer near the left wall settles the paddle at its left limit", 0.01)
	_move_pointer_to(_width - 5.0)
	await _frames(SETTLE_FRAMES)
	check_approx(_paddle.position.x, _width - _paddle.get_half_width(), "[clamp] pointer near the right wall settles the paddle at its right limit", 0.01)


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
	_move_pointer_to(_width - 200.0)
	await _frames(SETTLE_FRAMES)
	check(_paddle.is_following_mouse(), "[re-enter] moving inside again resumes mouse-follow")
	check_approx(_paddle.position.x, _width - 200.0, "[re-enter] paddle follows the pointer again", 0.5)

	Input.parse_input_event(_motion_at(Vector2(_width + GameLayout.SIDEBAR_WIDTH * 0.5, 400.0)))
	await _frames(2)
	_move_pointer_to(250.0)
	await _frames(SETTLE_FRAMES)
	check(_paddle.is_following_mouse(), "[re-enter] returning from the sidebar resumes mouse-follow")
	check_approx(_paddle.position.x, 250.0, "[re-enter] paddle follows the pointer after the sidebar", 0.01)

	tree.root.focus_exited.emit()
	await _frames(2)
	_move_pointer_to(600.0)
	await _frames(SETTLE_FRAMES)
	check(_paddle.is_following_mouse(), "[re-enter] moving inside after a focus loss resumes mouse-follow")
	check_approx(_paddle.position.x, 600.0, "[re-enter] paddle follows the pointer after a focus loss", 0.01)


func _test_focus_loss_stops_following() -> void:
	await _reset_paddle()
	_move_pointer_to(_width - 100.0)
	await _frames(2)
	var x_when_unfocused := _paddle.position.x
	check(x_when_unfocused > _width * 0.5 and x_when_unfocused < _width - 100.0, "[focus] paddle was mid-way to the pointer (x=%.0f)" % x_when_unfocused)
	tree.root.focus_exited.emit()
	await _frames(SETTLE_FRAMES)
	check(not _paddle.is_following_mouse() and not _paddle.has_mouse_target(), "[focus] losing focus cancels mouse control")
	check_approx(_paddle.position.x, x_when_unfocused, "[focus] paddle stops where it was, without finishing the move", 0.01)


func _test_keyboard_overrides_pointer() -> void:
	await _reset_paddle()
	_move_pointer_to(_width - 160.0)
	await _frames(SETTLE_FRAMES)
	check(_paddle.is_following_mouse(), "[override] paddle is following the pointer first")
	Input.action_press("move_left")
	await _frames(10)
	Input.action_release("move_left")
	check(not _paddle.is_following_mouse(), "[override] a movement key cancels mouse-follow")
	check(_paddle.position.x < _width - 160.0 - 100.0, "[override] keyboard moves the paddle away from the pointer")
	var x_after_keys := _paddle.position.x
	await _frames(SETTLE_FRAMES)
	check_approx(_paddle.position.x, x_after_keys, "[override] paddle does not drift back to the old pointer", 0.01)


## A target left unfinished by the pointer leaving must not pull the paddle once
## a movement key has taken over, either during or after the key press.
func _test_keyboard_cancels_unfinished_mouse_target() -> void:
	await _reset_paddle()
	_move_pointer_to(_width - 100.0)
	await _frames(2)
	tree.root.mouse_exited.emit()
	await _frames(1)
	check(_paddle.has_mouse_target() and _paddle.position.x < _width - 100.0, "[stale] paddle is still finishing the last target")
	Input.action_press("move_left")
	await _frames(1)
	check(not _paddle.has_mouse_target(), "[stale] a movement key drops the unfinished target")
	await _frames(4)
	Input.action_release("move_left")
	var x_after_keys := _paddle.position.x
	await _frames(SETTLE_FRAMES)
	check_approx(_paddle.position.x, x_after_keys, "[stale] paddle stays where the keyboard left it", 0.01)

	_move_pointer_to(_width - 160.0)
	await _frames(2)
	Input.action_press("move_right")
	await _frames(1)
	Input.action_release("move_right")
	check(not _paddle.is_following_mouse() and not _paddle.has_mouse_target(), "[stale] a key tap mid-chase cancels mouse control")
	var x_after_tap := _paddle.position.x
	await _frames(SETTLE_FRAMES)
	check_approx(_paddle.position.x, x_after_tap, "[stale] paddle does not resume the old chase after the tap", 0.01)


func _test_zero_motion_is_ignored() -> void:
	await _reset_paddle()
	var event := _motion_at(Vector2(200.0, 400.0))
	event.relative = Vector2.ZERO
	event.screen_relative = Vector2.ZERO
	Input.parse_input_event(event)
	await _frames(SETTLE_FRAMES)
	check(not _paddle.is_following_mouse(), "[synthetic] zero-movement motion does not start mouse-follow")
	check_approx(_paddle.position.x, _width * 0.5, "[synthetic] paddle stays centered", 0.01)


## At the default size and at window shapes that put backdrop margins around the
## design canvas: the pointer maps to the right arena x through the offset, and
## movement over the sidebar or the margins never steers the paddle.
func _test_pointer_outside_arena_is_ignored_at_offset_layouts() -> void:
	var original_size := tree.root.size
	var arena := Playfield.get_size()
	var design := GameLayout.get_design_size()
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1080), Vector2i(1024, 768)]:
		tree.root.size = window_size
		await _frames(2)
		var offset := tree.root.get_canvas_transform().origin
		var label := "[layout %dx%d]" % [window_size.x, window_size.y]
		if window_size != Vector2i(1280, 720):
			check(not offset.is_zero_approx(), "%s design canvas is offset (%s)" % [label, offset])

		await _reset_paddle()
		_move_pointer_to(300.0)
		await _frames(SETTLE_FRAMES)
		check(_paddle.is_following_mouse(), "%s pointer over the arena starts mouse-follow" % label)
		check_approx(_paddle.position.x, 300.0, "%s paddle reaches the pointer's arena x" % label, 0.5)

		var outside: Dictionary = {}
		outside["sidebar"] = Vector2(arena.x + GameLayout.SIDEBAR_WIDTH * 0.5, 400.0)
		outside["sidebar's left edge"] = Vector2(arena.x + 1.0, 400.0)
		if offset.x >= 4.0:
			outside["left margin"] = Vector2(-offset.x * 0.5, 400.0)
			outside["right margin"] = Vector2(design.x + offset.x * 0.5, 400.0)
		if offset.y >= 4.0:
			outside["top margin"] = Vector2(300.0, -offset.y * 0.5)
			outside["bottom margin"] = Vector2(300.0, arena.y + offset.y * 0.5)
		for place: String in outside:
			_move_pointer_to(300.0)
			await _frames(2)
			Input.parse_input_event(_motion_at(outside[place]))
			await _frames(SETTLE_FRAMES)
			check(not _paddle.is_following_mouse(), "%s pointer over the %s stops mouse-follow" % [label, place])
			check_approx(_paddle.position.x, 300.0, "%s pointer over the %s does not move the paddle" % [label, place], 0.01)
	tree.root.size = original_size
	await _frames(2)


func _test_click_launches_without_starting_follow() -> void:
	await _reset_paddle()
	check_equal(_game.session.state, GameSession.State.READY, "[click] game is waiting for launch")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _to_window_pixels(Vector2(_width * 0.5, 400.0))
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


## Arena point -> window pixels: the world canvas offset, then the stretch transform.
func _to_window_pixels(arena_point: Vector2) -> Vector2:
	return tree.root.get_final_transform() * (tree.root.get_canvas_transform() * arena_point)


func _motion_at(playfield_point: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = _to_window_pixels(playfield_point)
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
