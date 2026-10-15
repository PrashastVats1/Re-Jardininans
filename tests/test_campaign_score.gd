extends "res://tests/test_case.gd"
## Level and campaign score in the running game: pausing keeps both, and a
## restart resets the level score and rolls the campaign score back to its
## value on entering the level.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const ENTRY_TOTAL: int = 1000


func run() -> void:
	await _test_default_entry_total()
	await _test_pause_keeps_both_scores_and_restart_rolls_back()
	tree.paused = false
	tree.unload_current_scene()
	await tree.process_frame


func _test_default_entry_total() -> void:
	var game := await _start_as_current_scene(-1)
	check_equal(game.campaign_score_at_entry, 0, "the shipped scene enters with a campaign total of 0")
	check_equal(game.session.get_campaign_score(), 0, "so its campaign score starts at 0")


func _test_pause_keeps_both_scores_and_restart_rolls_back() -> void:
	var game := await _start_as_current_scene(ENTRY_TOTAL)
	check_equal([game.session.score, game.session.get_campaign_score()], [0, ENTRY_TOTAL], "a fresh attempt starts at 0 level score and the entry total")
	_press("launch_ball")
	await tree.physics_frame
	var points := _break_one_brick(game)
	check(points > 0, "a destructible brick was broken")
	var level_score := game.session.score
	check_equal(level_score, points, "the level score counts the broken brick")
	check_equal(game.session.get_campaign_score(), ENTRY_TOTAL + points, "the campaign score adds it to the entry total")

	_press("pause")
	await tree.physics_frame
	check(tree.paused, "the game is paused")
	for i: int in 10:
		await tree.physics_frame
	check_equal([game.session.score, game.session.get_campaign_score()], [level_score, ENTRY_TOTAL + points], "pausing keeps both scores")
	_press("pause")
	await tree.physics_frame
	check(not tree.paused, "the game is resumed")
	check_equal([game.session.score, game.session.get_campaign_score()], [level_score, ENTRY_TOTAL + points], "resuming keeps both scores")
	check_equal(_sidebar_text(game, "%ScoreValue"), str(level_score), "the sidebar still shows the level score")

	game.restart()
	var restarted := await _current_game_after(game)
	check(restarted != null, "the restart loads a fresh game")
	if restarted == null:
		return
	check_equal(restarted.campaign_score_at_entry, ENTRY_TOTAL, "the restart keeps the entry total")
	check_equal(restarted.session.score, 0, "the restart resets the level score")
	check_equal(restarted.session.get_campaign_score(), ENTRY_TOTAL, "the restart rolls the campaign score back to the entry total")
	check_equal(_sidebar_text(restarted, "%ScoreValue"), "0", "the sidebar shows the reset level score")


## Starts main.tscn as the current scene; a negative total keeps the scene's default.
func _start_as_current_scene(entry_total: int) -> Game:
	var main := MAIN_SCENE.instantiate()
	var game := main.get_node("Game") as Game
	if entry_total >= 0:
		game.campaign_score_at_entry = entry_total
	game.pause_on_focus_loss = false
	tree.change_scene_to_node(main)
	await tree.process_frame
	await tree.physics_frame
	game.get_node("Playfield/Paddle").set_physics_process(false)
	return game


func _break_one_brick(game: Game) -> int:
	for child: Node in game.get_node("Playfield/Bricks").get_children():
		var brick := child as Brick
		if brick.is_destructible():
			while brick.hit_points > 0:
				brick.hit()
			return brick.brick_type.points
	return 0


func _current_game_after(old_game: Game) -> Game:
	for i: int in 5:
		await tree.process_frame
	if is_instance_valid(old_game) or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("Game") as Game


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
