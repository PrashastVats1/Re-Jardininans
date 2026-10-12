extends "res://tests/test_case.gd"
## End-to-end runs of the real main scene, driven through the input actions.
## A scripted paddle plays to victory; a missing paddle plays to game over.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const MAX_STEPS_TO_WIN: int = 60 * 60 * 5
const EXPECTED_FULL_SCORE: int = 10 * 120 + 42 * 50


func run() -> void:
	await _test_pause_freezes_play()
	await _test_autoplay_reaches_victory()
	await _test_losing_all_lives_ends_game()


func _test_pause_freezes_play() -> void:
	var game := await _start_game()
	_press("launch_ball")
	for i: int in 10:
		await tree.physics_frame
	_press("pause")
	await tree.physics_frame
	check(tree.paused, "pause action pauses the tree")
	var ball := _ball(game)
	var frozen_at := ball.position
	for i: int in 30:
		await tree.physics_frame
	check(ball.position.is_equal_approx(frozen_at), "ball does not move while paused")
	_press("launch_ball")
	await tree.physics_frame
	check_equal(game.session.state, GameSession.State.PLAYING, "launch is ignored while paused")
	_press("pause")
	await tree.physics_frame
	check(not tree.paused, "pause action resumes")
	for i: int in 5:
		await tree.physics_frame
	check(not ball.position.is_equal_approx(frozen_at), "ball moves again after resuming")
	await _end_game(game)


func _test_autoplay_reaches_victory() -> void:
	var game := await _start_game()
	var ball := _ball(game)
	var paddle := game.get_node("Playfield/Paddle") as Paddle
	_press("launch_ball")
	var steps := 0
	var unexpectedly_paused := false
	while steps < MAX_STEPS_TO_WIN and game.session.state != GameSession.State.WON:
		unexpectedly_paused = unexpectedly_paused or tree.paused
		var aim := sin(steps * 0.013) * paddle.get_half_width() * 0.8
		paddle.position.x = clampf(ball.position.x - aim, paddle.get_half_width(), 1280.0 - paddle.get_half_width())
		if game.session.state == GameSession.State.READY:
			_press("launch_ball")
		await tree.physics_frame
		steps += 1
	check(not unexpectedly_paused, "game was never paused during autoplay")
	check_equal(game.session.state, GameSession.State.WON, "scripted paddle clears the level within %d steps (bricks left: %d)" % [MAX_STEPS_TO_WIN, game.session.bricks_remaining])
	check_equal(game.session.score, EXPECTED_FULL_SCORE, "full clear scores every brick exactly once")
	check(ball.speed <= ball.max_speed + 0.001, "ball speed never exceeds max_speed")

	var score_at_win := game.session.score
	for i: int in 30:
		await tree.physics_frame
	_press("pause")
	await tree.physics_frame
	check(not tree.paused, "pause is ignored after victory")
	check_equal(game.session.score, score_at_win, "score is frozen after victory")
	check_equal(game.session.state, GameSession.State.WON, "state stays WON")
	await _end_game(game)


func _test_losing_all_lives_ends_game() -> void:
	var game := await _start_game()
	var ball := _ball(game)
	var paddle := game.get_node("Playfield/Paddle") as Paddle
	var lives_seen: Array[int] = []
	game.session.lives_changed.connect(func(lives: int) -> void: lives_seen.append(lives))
	var steps := 0
	while steps < 60 * 60 and game.session.state != GameSession.State.GAME_OVER:
		if game.session.state == GameSession.State.READY:
			_press("launch_ball")
		elif not ball.is_attached():
			var far_side := paddle.get_half_width() if ball.position.x > 640.0 else 1280.0 - paddle.get_half_width()
			paddle.position.x = far_side
		await tree.physics_frame
		steps += 1
	check_equal(game.session.state, GameSession.State.GAME_OVER, "missing every ball ends the game")
	check_equal(lives_seen, [2, 1, 0] as Array[int], "lives count down 3 -> 0 exactly once each")
	var score_at_end := game.session.score
	_press("launch_ball")
	for i: int in 60:
		await tree.physics_frame
	check_equal(game.session.state, GameSession.State.GAME_OVER, "state stays GAME_OVER")
	check_equal(game.session.score, score_at_end, "score is frozen after game over")
	await _end_game(game)


func _start_game() -> Game:
	var main := MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	# The tests position the paddle directly and control pausing themselves; stop
	# the real mouse, keyboard or window focus from interfering in a windowed run.
	main.get_node("Game/Playfield/Paddle").set_physics_process(false)
	var game := main.get_node("Game") as Game
	game.pause_on_focus_loss = false
	await tree.physics_frame
	return game


func _end_game(game: Game) -> void:
	tree.paused = false
	game.get_parent().queue_free()
	await tree.process_frame


func _ball(game: Game) -> Ball:
	return game.get_node("Playfield/Ball") as Ball


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
