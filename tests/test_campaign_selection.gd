extends "res://tests/test_case.gd"
## Choosing a campaign level by number from an in-memory campaign (the real
## campaign levels don't exist yet): Level N is entry N - 1, starting lives
## follow CampaignRules, a bad number or missing entry is refused safely, and
## a restart keeps the level number and the campaign score on entry.
## Development levels keep their own starting lives and presentation.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
## Expected starting lives, written out rather than read from CampaignRules.
const LIVES_AT: Dictionary = {1: 5, 10: 5, 11: 4, 20: 4, 21: 3, 64: 3}


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


func run() -> void:
	_campaign = _make_campaign(CampaignRules.LEVEL_COUNT)
	for level_number: int in LIVES_AT:
		await _test_selects_campaign_level(level_number)
	await _test_development_levels_are_not_campaign_levels()
	await _test_refuses_bad_selections()
	await _test_restart_keeps_campaign_level()
	tree.unload_current_scene()
	await tree.process_frame


func _test_selects_campaign_level(level_number: int) -> void:
	var label := "Level %d" % level_number
	var game := await _start(func(g: Game) -> void:
		g.campaign = _campaign
		g.level_number = level_number
		g.starting_lives = 9)
	check(game.is_campaign_game(), "[%s] is a campaign game" % label)
	check(game.level == _campaign.get_level(level_number - 1), "[%s] plays campaign entry %d" % [label, level_number - 1])
	check_equal(game.level.display_name, "Campaign %d" % level_number, "[%s] is the level named for its number" % label)
	check(game.has_playable_level(), "[%s] is playable" % label)
	check_equal(game.session.lives, LIVES_AT[level_number], "[%s] starts with %d lives, ignoring starting_lives" % [label, LIVES_AT[level_number]])
	check_equal(game.get_level_starting_lives(), LIVES_AT[level_number], "[%s] reports its campaign starting lives" % label)
	check_equal(_text(game, "%LivesValue"), str(LIVES_AT[level_number]), "[%s] sidebar shows those lives" % label)
	check_equal(_text(game, "%LevelValue"), "%d · Campaign %d" % [level_number, level_number], "[%s] sidebar shows the level number and name" % label)
	var title := "Level 1: Tutorial" if level_number == 1 else "Level %d" % level_number
	check_equal(_text(game, "%MessageTitle"), title, "[%s] start message is titled \"%s\"" % [label, title])
	await _stop(game)


func _test_development_levels_are_not_campaign_levels() -> void:
	var game := await _start(func(_g: Game) -> void: pass)
	check(not game.is_campaign_game() and game.level_number == 0, "the shipped scene is not a campaign game")
	check(game.campaign == null, "the shipped scene has no campaign assigned")
	check_equal(game.level.display_name, "Test Garden", "it plays the development level Test Garden")
	check_equal(game.session.lives, game.starting_lives, "development levels start with starting_lives")
	check_equal(_text(game, "%LivesValue"), str(game.starting_lives), "the sidebar shows Test Garden's numeric lives")
	check_equal(_text(game, "%LevelValue"), "Test Garden", "the sidebar names Test Garden without a level number")
	check_equal(_text(game, "%MessageTitle"), "Re-Jardinians!", "the start message keeps the game title")
	await _stop(game)

	var fixture := load("res://data/levels/fixture_islands.tres") as LevelData
	game = await _start(func(g: Game) -> void:
		g.level = fixture
		g.campaign = _campaign
		g.starting_lives = 7)
	check(not game.is_campaign_game() and game.level == fixture, "a directly assigned fixture is played as a development level")
	check_equal(game.session.lives, 7, "a directly assigned level starts with starting_lives (7)")
	check_equal(_text(game, "%LivesValue"), "7", "the sidebar shows the fixture's numeric lives")
	check_equal(_text(game, "%LevelValue"), "Fixture Islands", "the sidebar names the fixture without a level number")
	await _stop(game)


func _test_refuses_bad_selections() -> void:
	var short := _make_campaign(3)
	var with_gap := _make_campaign(3)
	with_gap.levels[1] = null
	var broken := _make_campaign(1)
	broken.get_level(0).rows = PackedStringArray(["AAAA", "AA"])
	var cases := [
		[_campaign, -1, null, "campaign level -1 does not exist: campaign levels are numbered 1 to 64"],
		[_campaign, 65, null, "campaign level 65 does not exist: campaign levels are numbered 1 to 64"],
		[_campaign, 1000, null, "campaign level 1000 does not exist: campaign levels are numbered 1 to 64"],
		[short, 5, null, "campaign level 5 is missing: the campaign has 3 level entries"],
		[with_gap, 2, null, "campaign level 2 is missing: the campaign has 3 level entries"],
		[null, 1, null, "campaign level 1 was requested but no campaign is assigned"],
		[_campaign, 3, _fixture("Stray"), "campaign level 3 was requested but a level (level \"Stray\") is also assigned; assign one or the other"],
		[broken, 1, null, LevelValidator.validate(broken.get_level(0))[0]],
	]
	print("      (%d errors expected below: deliberately bad campaign selections)" % cases.size())
	var log := ErrorLog.new()
	OS.add_logger(log)
	for case: Array in cases:
		var label := "level %d: %s" % [case[1], case[3]]
		var game := await _start(func(g: Game) -> void:
			g.campaign = case[0]
			g.level_number = case[1]
			g.level = case[2])
		check_equal(log.take(), PackedStringArray([case[3]]), "[%s] exactly this problem is reported" % case[1])
		check(not game.has_playable_level(), "[%s] is refused" % label)
		check_equal(game.get_node("Playfield/Bricks").get_child_count(), 0, "[%s] spawns no bricks" % case[1])
		check_equal(_text(game, "%MessageTitle"), "Level unavailable", "[%s] tells the player the level is unavailable" % case[1])
		check_equal(_text(game, "%LivesValue"), Sidebar.PLACEHOLDER, "[%s] the sidebar shows no life count" % case[1])
		_press("launch_ball")
		await tree.physics_frame
		check(game.session.state == GameSession.State.READY and (game.get_node("Playfield/Ball") as Ball).is_attached(),
				"[%s] the ball can't be launched" % case[1])
		check_equal(_text(game, "%LivesValue"), Sidebar.PLACEHOLDER, "[%s] still no life count after trying to launch" % case[1])
		await _stop(game)
	OS.remove_logger(log)


## Restarting, after losing a ball or even after a win, replays the same
## campaign level with its own lives and the same campaign score on entry.
## (Confirming a win advances instead; see test_campaign_progression.gd.)
func _test_restart_keeps_campaign_level() -> void:
	var game := await _start_as_current_scene(func(g: Game) -> void:
		g.campaign = _campaign
		g.level_number = 11
		g.campaign_score_at_entry = 2500)
	_press("launch_ball")
	await tree.physics_frame
	(game.get_node("Playfield/Ball") as Ball).lost.emit()
	await tree.physics_frame
	check_equal(game.session.lives, 3, "Level 11 lost a ball: 3 of its 4 lives left")

	game.restart()
	var restarted := await _current_game_after(game)
	_check_campaign_setup(restarted, "after a restart")
	if restarted == null:
		return

	_press("launch_ball")
	await tree.physics_frame
	for child: Node in restarted.get_node("Playfield/Bricks").get_children():
		var brick := child as Brick
		while brick.is_destructible() and brick.hit_points > 0:
			brick.hit()
	check_equal(restarted.session.state, GameSession.State.WON, "Level 11 can be won")
	check(restarted.session.get_campaign_score() > 2500, "winning adds to the campaign score")
	restarted.restart()
	_check_campaign_setup(await _current_game_after(restarted), "after winning and then restarting")


func _check_campaign_setup(game: Game, label: String) -> void:
	check(game != null, "[%s] a fresh game is running" % label)
	if game == null:
		return
	check_equal(game.level_number, 11, "[%s] still campaign Level 11" % label)
	check(game.campaign == _campaign and game.level == _campaign.get_level(10), "[%s] still the same campaign entry" % label)
	check_equal(game.session.lives, 4, "[%s] lives reset to Level 11's 4" % label)
	check_equal(game.session.score, 0, "[%s] level score reset to 0" % label)
	check_equal(game.campaign_score_at_entry, 2500, "[%s] campaign score on entry unchanged" % label)
	check_equal(game.session.get_campaign_score(), 2500, "[%s] campaign score rolled back to the entry total" % label)
	check_equal(_text(game, "%LevelValue"), "11 · Campaign 11", "[%s] sidebar still shows Level 11" % label)


## Campaign of [param count] distinct valid levels named "Campaign 1" onwards.
func _make_campaign(count: int) -> LevelList:
	var list := LevelList.new()
	for number: int in range(1, count + 1):
		list.levels.append(_fixture("Campaign %d" % number))
	return list


func _fixture(level_name: String) -> LevelData:
	var flower := BrickType.new()
	flower.display_name = "Fixture flower"
	var level := LevelData.new()
	level.display_name = level_name
	level.rows = PackedStringArray(["AAAA", "A..A"])
	level.legend = {"A": flower}
	return level


func _start(setup: Callable) -> Game:
	var main := MAIN_SCENE.instantiate()
	var game := main.get_node("Game") as Game
	game.pause_on_focus_loss = false
	setup.call(game)
	tree.root.add_child(main)
	await tree.physics_frame
	game.get_node("Playfield/Paddle").set_physics_process(false)
	return game


func _stop(game: Game) -> void:
	game.get_parent().queue_free()
	await tree.process_frame


func _start_as_current_scene(setup: Callable) -> Game:
	var main := MAIN_SCENE.instantiate()
	var game := main.get_node("Game") as Game
	game.pause_on_focus_loss = false
	setup.call(game)
	tree.change_scene_to_node(main)
	await tree.process_frame
	await tree.process_frame
	game.get_node("Playfield/Paddle").set_physics_process(false)
	return game


func _current_game_after(old_game: Game) -> Game:
	for i: int in 5:
		await tree.process_frame
	if is_instance_valid(old_game) or tree.current_scene == null:
		return null
	var game := tree.current_scene.get_node_or_null("Game") as Game
	if game != null:
		game.get_node("Playfield/Paddle").set_physics_process(false)
	return game


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _text(game: Game, path: String) -> String:
	var owner_path := "Hud" if path == "%MessageTitle" else "Hud/Sidebar"
	return (game.get_node(owner_path).get_node(path) as Label).text
