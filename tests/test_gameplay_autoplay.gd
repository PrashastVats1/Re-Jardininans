extends "res://tests/test_case.gd"
## End-to-end runs of the real main scene, driven through the input actions.
## A scripted paddle plays every level under data/levels to victory; a missing
## paddle plays to game over.

const LevelFacts := preload("res://tests/level_facts.gd")
const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const MAX_STEPS_TO_WIN: int = 60 * 60 * 5


func run() -> void:
	await _test_pause_freezes_play()
	for path: String in LevelFacts.level_paths():
		var level := load(path) as LevelData
		check(level != null, "%s loads as LevelData" % path.get_file())
		if level != null:
			await _test_autoplay_reaches_victory(level, path.get_file())
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


func _test_autoplay_reaches_victory(level: LevelData, label: String) -> void:
	var expected_score := LevelFacts.full_clear_score(level)
	var game := await _start_game(level)
	var ball := _ball(game)
	var paddle := game.get_node("Playfield/Paddle") as Paddle
	_press("launch_ball")
	var steps := 0
	var unexpectedly_paused := false
	while steps < MAX_STEPS_TO_WIN and game.session.state != GameSession.State.WON:
		unexpectedly_paused = unexpectedly_paused or tree.paused
		var aim := sin(steps * 0.013) * paddle.get_half_width() * 0.8
		paddle.position.x = clampf(ball.position.x - aim, paddle.get_half_width(), Playfield.get_size().x - paddle.get_half_width())
		if game.session.state == GameSession.State.READY:
			_press("launch_ball")
		await tree.physics_frame
		steps += 1
	check(game.level == level, "[%s] the game plays the requested level" % label)
	check(not unexpectedly_paused, "[%s] game was never paused during autoplay" % label)
	check_equal(game.session.state, GameSession.State.WON, "[%s] scripted paddle clears the level within %d steps (bricks left: %d)"
			% [label, MAX_STEPS_TO_WIN, game.session.bricks_remaining])
	check_equal(game.session.score, expected_score, "[%s] full clear scores every destructible brick exactly once" % label)
	check(ball.speed <= ball.max_speed + 0.001, "[%s] ball speed never exceeds max_speed" % label)

	var score_at_win := game.session.score
	for i: int in 30:
		await tree.physics_frame
	_press("pause")
	await tree.physics_frame
	check(not tree.paused, "[%s] pause is ignored after victory" % label)
	check_equal(game.session.score, score_at_win, "[%s] score is frozen after victory" % label)
	check_equal(game.session.state, GameSession.State.WON, "[%s] state stays WON" % label)
	check_equal(_sidebar_text(game, "%ScoreValue"), str(expected_score), "[%s] sidebar shows the final score after victory" % label)
	check_equal(_sidebar_text(game, "%LivesValue"), str(game.session.lives), "[%s] sidebar shows the remaining lives after victory" % label)
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
			var width := Playfield.get_size().x
			var far_side := paddle.get_half_width() if ball.position.x > width * 0.5 else width - paddle.get_half_width()
			paddle.position.x = far_side
		await tree.physics_frame
		steps += 1
	var expected_lives: Array[int] = []
	expected_lives.assign(range(game.starting_lives - 1, -1, -1))
	check_equal(game.session.state, GameSession.State.GAME_OVER, "missing every ball ends the game")
	check_equal(lives_seen, expected_lives, "lives count down %d -> 0 exactly once each" % game.starting_lives)
	var score_at_end := game.session.score
	_press("launch_ball")
	for i: int in 60:
		await tree.physics_frame
	check_equal(game.session.state, GameSession.State.GAME_OVER, "state stays GAME_OVER")
	check_equal(game.session.score, score_at_end, "score is frozen after game over")
	check_equal(_sidebar_text(game, "%LivesValue"), "0", "sidebar shows 0 lives at game over")
	check_equal(_sidebar_text(game, "%ScoreValue"), str(score_at_end), "sidebar shows the final score at game over")
	await _end_game(game)


## Plays [param level], or the scene's default level when it is null.
func _start_game(level: LevelData = null) -> Game:
	var main := MAIN_SCENE.instantiate()
	(main.get_node("Game") as Game).level = level
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


func _sidebar_text(game: Game, label_path: String) -> String:
	return (game.get_node("Hud/Sidebar").get_node(label_path) as Label).text
