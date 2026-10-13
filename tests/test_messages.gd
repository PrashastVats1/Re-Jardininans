extends "res://tests/test_case.gd"
## The centered messages: a level-independent start prompt, ball lost, pause,
## victory and game over, each shown and hidden at the right time.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const START_BODY: String = "Press Space or click to launch."


func run() -> void:
	await _test_start_ball_lost_and_pause()
	await _test_victory_message()
	await _test_game_over_message()


func _test_start_ball_lost_and_pause() -> void:
	var main := await _spawn()
	var game := main.get_node("Game") as Game
	var hud := game.get_node("Hud") as Hud
	check(_panel(hud, "%MessagePanel").visible, "[start] start panel is shown")
	check_equal(_text(hud, "%MessageTitle"), "Re-Jardinians!", "[start] start title is the game name")
	check_equal(_text(hud, "%MessageBody"), START_BODY, "[start] start body is only the launch instruction")

	_press("launch_ball")
	await tree.physics_frame
	check(not _panel(hud, "%MessagePanel").visible, "[start] launching hides the start panel")

	_press("pause")
	await _frames(2)
	check(tree.paused and _panel(hud, "%PausePanel").visible, "[pause] pausing shows the pause panel")
	_press("pause")
	await _frames(2)
	check(not tree.paused and not _panel(hud, "%PausePanel").visible, "[pause] resuming hides the pause panel")

	(game.get_node("Playfield/Ball") as Ball).lost.emit()
	await tree.physics_frame
	check(_panel(hud, "%MessagePanel").visible, "[ball lost] panel is shown")
	check_equal(_text(hud, "%MessageTitle"), "Ball lost!", "[ball lost] title")
	check_equal(_text(hud, "%MessageBody"), "2 lives left.\n" + START_BODY, "[ball lost] body gives lives left and the launch instruction")

	_press("pause")
	await _frames(2)
	check(not _panel(hud, "%MessagePanel").visible and _panel(hud, "%PausePanel").visible, "[pause] pause panel replaces a message")
	_press("pause")
	await _frames(2)
	check(_panel(hud, "%MessagePanel").visible and not _panel(hud, "%PausePanel").visible, "[pause] the message returns after resuming")
	await _free(main)


func _test_victory_message() -> void:
	var main := await _spawn()
	var game := main.get_node("Game") as Game
	var hud := game.get_node("Hud") as Hud
	_press("launch_ball")
	await tree.physics_frame
	for child: Node in game.get_node("Playfield/Bricks").get_children():
		var brick := child as Brick
		while brick.is_destructible() and not brick.is_queued_for_deletion() and game.session.state == GameSession.State.PLAYING \
				and brick.collision_layer != 0:
			brick.hit()
	await tree.physics_frame
	check_equal(game.session.state, GameSession.State.WON, "[victory] destroying every brick wins")
	check(_panel(hud, "%MessagePanel").visible, "[victory] panel is shown")
	check_equal(_text(hud, "%MessageTitle"), "Level cleared!", "[victory] title is not tied to a theme")
	check_equal(_text(hud, "%MessageBody"), "Final score: %d\nPress Space or click to play again." % game.session.score,
			"[victory] body gives the final score and how to play again")
	await _free(main)


func _test_game_over_message() -> void:
	var main := await _spawn()
	var game := main.get_node("Game") as Game
	var hud := game.get_node("Hud") as Hud
	var ball := game.get_node("Playfield/Ball") as Ball
	for life: int in game.starting_lives:
		_press("launch_ball")
		await tree.physics_frame
		ball.lost.emit()
		await tree.physics_frame
	check_equal(game.session.state, GameSession.State.GAME_OVER, "[game over] losing every ball ends the game")
	check(_panel(hud, "%MessagePanel").visible, "[game over] panel is shown")
	check_equal(_text(hud, "%MessageTitle"), "Game over", "[game over] title")
	check_equal(_text(hud, "%MessageBody"), "Final score: %d\nPress Space or click to try again." % game.session.score,
			"[game over] body gives the final score and how to try again")
	await _free(main)


func _spawn() -> Node:
	var main := MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	(main.get_node("Game") as Game).pause_on_focus_loss = false
	await tree.physics_frame
	return main


func _free(main: Node) -> void:
	tree.paused = false
	main.queue_free()
	await tree.process_frame


func _panel(hud: Hud, path: String) -> Control:
	return hud.get_node(path) as Control


func _text(hud: Hud, path: String) -> String:
	return (hud.get_node(path) as Label).text


func _press(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _frames(count: int) -> void:
	for i: int in count:
		await tree.process_frame
