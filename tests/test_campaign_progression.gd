extends "res://tests/test_case.gd"
## Winning a campaign level and confirming loads the next one, once, with the
## campaign score handed over; game over and restart replay the same level;
## Level 64 ends the campaign; a missing or invalid next level is refused;
## development levels never progress. Uses in-memory campaigns of fixture
## levels worth LEVEL_POINTS each, with main.tscn as the current scene.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
## Six 50-point flowers per fixture level.
const LEVEL_POINTS: int = 300


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


var _campaign: LevelList
var _log: ErrorLog = ErrorLog.new()
var _root_children: int


func run() -> void:
	_campaign = _make_campaign(CampaignRules.LEVEL_COUNT)
	OS.add_logger(_log)
	await _test_level_1_advances_once()
	await _test_lives_across_band_boundaries(10, 5, 4, false)
	await _test_lives_across_band_boundaries(20, 4, 3, true)
	await _test_game_over_replays_the_same_level()
	await _test_level_64_completes_the_campaign()
	print("      (4 errors expected below: a missing and an invalid next level, and two refused advances)")
	await _test_missing_next_level_is_refused()
	await _test_invalid_next_level_is_refused()
	await _test_advance_is_refused_without_a_campaign_win()
	await _test_development_victory_does_not_progress()
	OS.remove_logger(_log)
	tree.paused = false
	tree.unload_current_scene()
	await tree.process_frame


func _test_level_1_advances_once() -> void:
	var game := await _start(_campaign, 1, 0)
	_root_children = tree.root.get_child_count()
	await _win(game)
	check_equal(game.session.get_campaign_score(), LEVEL_POINTS, "[1->2] Level 1 is won with %d points" % LEVEL_POINTS)
	check_equal(_text(game, "%MessageTitle"), "Level 1 cleared!", "[1->2] the victory message names Level 1")
	check_equal(_text(game, "%MessageBody"), "Campaign score: %d\nPress Space or click for Level 2." % LEVEL_POINTS,
			"[1->2] it shows the campaign score and offers Level 2")
	for i: int in 10:
		await tree.process_frame
	check(is_instance_valid(game) and tree.current_scene == game.get_parent(), "[1->2] winning alone doesn't advance")
	_press("launch_ball")
	for i: int in 3:
		await tree.process_frame
	check(is_instance_valid(game), "[1->2] a press during the end delay doesn't advance")

	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	OS.delay_msec(Game.RESTART_DELAY_MSEC + 50)
	_press("launch_ball")
	_press("launch_ball")
	_press("launch_ball")
	var level_2 := await _current_game_after(game)
	check_equal(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), orphans, "[1->2] the repeated presses left no stray game scenes")
	_check_level(level_2, 2, 5, LEVEL_POINTS, "[1->2]")
	if level_2 == null:
		return
	check_equal(level_2.session.state, GameSession.State.READY, "[1->2] the extra presses neither advanced again nor launched Level 2")
	check_equal(tree.root.get_child_count(), _root_children, "[1->2] exactly one game scene is running")
	check_equal(_log.take(), PackedStringArray(), "[1->2] no engine errors")

	await _test_pause_keeps_both_scores(level_2)
	await _test_restart_after_partial_progress(level_2)


func _test_pause_keeps_both_scores(game: Game) -> void:
	_press("launch_ball")
	await tree.physics_frame
	_break_bricks(game, 2)
	var scores := [game.session.score, game.session.get_campaign_score()]
	check_equal(scores, [100, LEVEL_POINTS + 100], "[Level 2] two bricks add to both scores")
	_press("pause")
	await tree.physics_frame
	check(tree.paused, "[Level 2] paused")
	for i: int in 10:
		await tree.physics_frame
	_press("pause")
	await tree.physics_frame
	check(not tree.paused, "[Level 2] resumed")
	check_equal([game.session.score, game.session.get_campaign_score()], scores, "[Level 2] pausing and resuming keep both scores")


func _test_restart_after_partial_progress(game: Game) -> void:
	game.restart()
	var again := await _current_game_after(game)
	_check_level(again, 2, 5, LEVEL_POINTS, "[Level 2 restart]")
	check_equal(tree.root.get_child_count(), _root_children, "[Level 2 restart] exactly one game scene is running")


## With [param call_twice], advance() is called twice in the same frame instead
## of confirming: the old game leaves the tree on the first call, so the second
## must be ignored rather than replace the scene again.
func _test_lives_across_band_boundaries(from_level: int, from_lives: int, to_lives: int, call_twice: bool) -> void:
	var label := "[%d->%d]" % [from_level, from_level + 1]
	var game := await _start(_campaign, from_level, 1000)
	check_equal(game.session.lives, from_lives, "%s Level %d starts with %d lives" % [label, from_level, from_lives])
	await _win(game)
	var next: Game
	if call_twice:
		game.advance()
		game.advance()
		next = await _current_game_after(game)
		check_equal(_log.take(), PackedStringArray(), "%s a second advance() in the same frame is ignored without errors" % label)
	else:
		next = await _confirm(game)
	_check_level(next, from_level + 1, to_lives, 1000 + LEVEL_POINTS, label)
	check_equal(tree.root.get_child_count(), _root_children, "%s exactly one game scene is running" % label)


func _test_game_over_replays_the_same_level() -> void:
	var game := await _start(_campaign, 11, 700)
	_press("launch_ball")
	await tree.physics_frame
	_break_bricks(game, 1)
	await _lose_all_lives(game)
	check_equal(game.session.state, GameSession.State.GAME_OVER, "[game over] Level 11 is lost")
	var again := await _confirm(game)
	_check_level(again, 11, 4, 700, "[game over]")
	check_equal(tree.root.get_child_count(), _root_children, "[game over] exactly one game scene is running")


func _test_level_64_completes_the_campaign() -> void:
	var game := await _start(_campaign, 64, 5000)
	await _win(game)
	var final_score := 5000 + LEVEL_POINTS
	check_equal(_text(game, "%MessageTitle"), "Campaign complete", "[64] winning Level 64 completes the campaign")
	check_equal(_text(game, "%MessageBody"), "Final campaign score: %d\nPress Space or click to replay Level 64." % final_score,
			"[64] it shows the final campaign score and offers a replay of Level 64")
	for i: int in 30:
		await tree.process_frame
	check(is_instance_valid(game) and game.session.state == GameSession.State.WON, "[64] the completion screen stays up")
	var again := await _confirm(game)
	_check_level(again, 64, 3, 5000, "[64 replay]")
	check_equal(_log.take(), PackedStringArray(), "[64] Level 65 was never requested (no errors)")
	check_equal(tree.root.get_child_count(), _root_children, "[64] exactly one game scene is running")


func _test_missing_next_level_is_refused() -> void:
	var game := await _start(_make_campaign(3), 3, 0)
	await _win(game)
	check_equal(_text(game, "%MessageTitle"), "Level 3 cleared!", "[missing] the end of a short list is not the campaign's end")
	check_equal(_text(game, "%MessageBody"), "Campaign score: %d\nPress Space or click for Level 4." % LEVEL_POINTS,
			"[missing] it offers Level 4 like any campaign level before 64")
	var next := await _confirm(game)
	check_equal(_log.take(), PackedStringArray(["campaign level 4 is missing: the campaign has 3 level entries"]),
			"[missing] the missing Level 4 is reported once")
	await _check_refused(next, 4, "[missing]")


func _test_invalid_next_level_is_refused() -> void:
	var campaign := _make_campaign(2)
	campaign.get_level(1).rows = PackedStringArray(["AAAA", "AA"])
	var game := await _start(campaign, 1, 0)
	await _win(game)
	var next := await _confirm(game)
	check_equal(_log.take(), LevelValidator.validate(campaign.get_level(1)), "[invalid] Level 2's diagnostics are reported once")
	await _check_refused(next, 2, "[invalid]")


func _test_advance_is_refused_without_a_campaign_win() -> void:
	var game := await _start(_campaign, 64, 0)
	await _win(game)
	game.advance()
	await tree.process_frame
	check_equal(_log.take(), PackedStringArray(["Game.advance() needs a won campaign level before Level 64."]), "[advance] refused after Level 64")
	check(is_instance_valid(game) and game.level_number == 64, "[advance] Level 64 stays on its completion screen")

	var playing := await _start(_campaign, 5, 0)
	playing.advance()
	await tree.process_frame
	check_equal(_log.take(), PackedStringArray(["Game.advance() needs a won campaign level before Level 64."]), "[advance] refused before winning")
	check(is_instance_valid(playing) and playing.level_number == 5, "[advance] an unfinished level doesn't advance")


func _test_development_victory_does_not_progress() -> void:
	var game := await _start(null, 0, 0)
	var level := game.level
	check(not game.is_campaign_game() and level.display_name == "Test Garden", "[dev] Test Garden is a development level")
	await _win(game)
	check_equal(_text(game, "%MessageTitle"), "Level cleared!", "[dev] the victory title is unchanged")
	check_equal(_text(game, "%MessageBody"), "Final score: %d\nPress Space or click to play again." % game.session.score,
			"[dev] the victory body is unchanged")
	var again := await _confirm(game)
	check(again != null and again.level == level and again.level_number == 0 and not again.is_campaign_game(),
			"[dev] confirming replays Test Garden as a development level")
	if again != null:
		check_equal([again.session.score, again.session.lives, again.campaign_score_at_entry], [0, 3, 0], "[dev] fresh score and lives, no campaign total")
		check_equal(_text(again, "%LevelValue"), "Test Garden", "[dev] the sidebar still shows just the name")
	check_equal(_log.take(), PackedStringArray(), "[dev] no engine errors")


func _check_level(game: Game, number: int, lives: int, entry_total: int, label: String) -> void:
	check(game != null, "%s a fresh game is running" % label)
	if game == null:
		return
	check_equal(game.level_number, number, "%s plays Level %d" % [label, number])
	check(game.level == game.campaign.get_level(number - 1), "%s plays campaign entry %d" % [label, number - 1])
	check(game.has_playable_level(), "%s Level %d is playable" % [label, number])
	check_equal(game.session.lives, lives, "%s starts with %d lives" % [label, lives])
	check_equal(game.session.score, 0, "%s level score starts at 0" % label)
	check_equal(game.campaign_score_at_entry, entry_total, "%s enters with a campaign total of %d" % [label, entry_total])
	check_equal(game.session.get_campaign_score(), entry_total, "%s campaign score starts at the entry total" % label)
	check_equal(_text(game, "%LevelValue"), "%d · Campaign %d" % [number, number], "%s sidebar shows Level %d" % [label, number])
	check_equal(_text(game, "%LivesValue"), str(lives), "%s sidebar shows %d lives" % [label, lives])
	check_equal(_text(game, "%ScoreValue"), "0", "%s sidebar shows the level score 0" % label)
	check_equal(_text(game, "%MessageTitle"), "Level %d" % number, "%s start message names Level %d" % [label, number])


func _check_refused(game: Game, number: int, label: String) -> void:
	check(game != null, "%s a fresh game is running" % label)
	if game == null:
		return
	check_equal(game.level_number, number, "%s it is Level %d, not a skipped one" % [label, number])
	check(not game.has_playable_level(), "%s Level %d is refused" % [label, number])
	check_equal(game.get_node("Playfield/Bricks").get_child_count(), 0, "%s no bricks are spawned" % label)
	check_equal(_text(game, "%MessageTitle"), "Level unavailable", "%s the player is told the level is unavailable" % label)
	check_equal(_text(game, "%LivesValue"), Sidebar.PLACEHOLDER, "%s no life count is shown" % label)
	OS.delay_msec(Game.RESTART_DELAY_MSEC + 50)
	_press("launch_ball")
	for i: int in 5:
		await tree.process_frame
	check(is_instance_valid(game) and tree.current_scene == game.get_parent(), "%s pressing launch neither advances nor restarts" % label)
	check(game.session.state == GameSession.State.READY and (game.get_node("Playfield/Ball") as Ball).is_attached(),
			"%s the ball can't be launched" % label)
	check_equal(tree.root.get_child_count(), _root_children, "%s exactly one game scene is running" % label)


## Starts main.tscn as the current scene; a null campaign with level 0 plays
## the shipped development level.
func _start(campaign: LevelList, number: int, entry_total: int) -> Game:
	var main := MAIN_SCENE.instantiate()
	var game := main.get_node("Game") as Game
	game.campaign = campaign
	game.level_number = number
	game.campaign_score_at_entry = entry_total
	game.pause_on_focus_loss = false
	tree.change_scene_to_node(main)
	await tree.process_frame
	await tree.process_frame
	game.get_node("Playfield/Paddle").set_physics_process(false)
	return game


func _win(game: Game) -> void:
	_press("launch_ball")
	await tree.physics_frame
	_break_bricks(game, -1)
	check_equal(game.session.state, GameSession.State.WON, "Level %d is won" % game.level_number)


## Breaks [param count] destructible bricks, or all of them when negative.
func _break_bricks(game: Game, count: int) -> void:
	for child: Node in game.get_node("Playfield/Bricks").get_children():
		var brick := child as Brick
		if count == 0:
			return
		if brick.is_destructible() and brick.hit_points > 0:
			while brick.hit_points > 0:
				brick.hit()
			count -= 1


func _lose_all_lives(game: Game) -> void:
	var ball := game.get_node("Playfield/Ball") as Ball
	while game.session.state != GameSession.State.GAME_OVER:
		if game.session.state == GameSession.State.READY:
			_press("launch_ball")
			await tree.physics_frame
		ball.lost.emit()
		await tree.physics_frame


## Confirms the end screen after the delay and returns the game that replaces it.
func _confirm(game: Game) -> Game:
	OS.delay_msec(Game.RESTART_DELAY_MSEC + 50)
	_press("launch_ball")
	return await _current_game_after(game)


func _current_game_after(old_game: Game) -> Game:
	for i: int in 5:
		await tree.process_frame
	if is_instance_valid(old_game) or tree.current_scene == null:
		return null
	var game := tree.current_scene.get_node_or_null("Game") as Game
	if game != null:
		game.get_node("Playfield/Paddle").set_physics_process(false)
	return game


func _make_campaign(count: int) -> LevelList:
	var flower := BrickType.new()
	flower.display_name = "Fixture flower"
	var list := LevelList.new()
	for number: int in range(1, count + 1):
		var level := LevelData.new()
		level.display_name = "Campaign %d" % number
		level.rows = PackedStringArray(["AAAA", "A..A"])
		level.legend = {"A": flower}
		list.levels.append(level)
	return list


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _text(game: Game, path: String) -> String:
	var owner_path := "Hud" if path in ["%MessageTitle", "%MessageBody"] else "Hud/Sidebar"
	return (game.get_node(owner_path).get_node(path) as Label).text
