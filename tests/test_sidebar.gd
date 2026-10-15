extends "res://tests/test_case.gd"
## The sidebar shows the running game's score, lives and level from the
## session and LevelData, marks the not-yet-stored player records as
## placeholders, and keeps any content inside its 320 px column.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

var _game: Game
var _sidebar: Sidebar


func run() -> void:
	var main := MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	_game = main.get_node("Game") as Game
	_game.pause_on_focus_loss = false
	_sidebar = _game.get_node("Hud/Sidebar") as Sidebar
	await tree.physics_frame

	_test_initial_content()
	await _test_score_and_lives_follow_the_session()
	_test_content_fits_the_column()

	main.queue_free()
	await tree.process_frame


func _test_initial_content() -> void:
	check_equal(_text("%Title"), "Re-Jardinians!", "sidebar shows the game title")
	check_equal(_text("%ScoreValue"), str(_game.session.score), "sidebar starts at the session's score")
	check_equal(_text("%LivesValue"), str(_game.session.lives), "sidebar starts at the session's lives")
	check_equal(_text("%LevelValue"), _game.level.display_name, "sidebar shows the current level's name")
	for record: String in ["%PlayerValue", "%HighScoreValue", "%LevelStreakValue"]:
		check_equal(_text(record), Sidebar.PLACEHOLDER, "player record %s shows the placeholder" % record.trim_prefix("%"))


func _test_score_and_lives_follow_the_session() -> void:
	check(_game.session.launch(), "session launches")
	(_game.get_node("Playfield/Ball") as Ball).launch()

	var target: Brick = null
	for child: Node in _game.get_node("Playfield/Bricks").get_children():
		var brick := child as Brick
		if brick.is_destructible():
			target = brick
			break
	var hits := 0
	while is_instance_valid(target) and not target.is_queued_for_deletion() and hits < 10:
		target.hit()
		hits += 1
	await tree.physics_frame
	check(_game.session.score > 0, "destroying a brick scores points")
	check_equal(_text("%ScoreValue"), str(_game.session.score), "sidebar score follows the session after a brick")

	(_game.get_node("Playfield/Ball") as Ball).lost.emit()
	await tree.physics_frame
	check_equal(_game.session.lives, _game.starting_lives - 1, "losing the ball costs a life")
	check_equal(_text("%LivesValue"), str(_game.session.lives), "sidebar lives follow the session after a lost ball")


## Long values are trimmed rather than widening the column, and the rows fit
## its height, whatever a future level or player record contains.
func _test_content_fits_the_column() -> void:
	var column := _sidebar.get_global_rect()
	_sidebar.set_score(999999999)
	_sidebar.set_level("A level name far too long to fit in the sidebar column")
	_sidebar.set_lives(99)
	var outside: PackedStringArray = []
	for label: Label in _labels(_sidebar):
		if not column.encloses(label.get_global_rect()) or label.get_minimum_size().x > column.size.x:
			outside.append(String(label.name))
	check(outside.is_empty(), "long sidebar text stays inside the column %s" % [outside])
	_sidebar.set_level("A campaign level name far too long to fit in the sidebar column", 64)
	var level_label := _sidebar.get_node("%LevelValue") as Label
	check(column.encloses(level_label.get_global_rect()) and level_label.get_minimum_size().x <= column.size.x,
			"a long numbered campaign level stays inside the column")
	var rows := _sidebar.get_node("Margin/Rows") as Control
	check(rows.get_combined_minimum_size().y <= column.size.y - 48.0, "sidebar rows fit the column height (%.0f px)" % rows.get_combined_minimum_size().y)
	_sidebar.set_level("")
	check_equal(_text("%LevelValue"), Sidebar.PLACEHOLDER, "a level without a name shows the placeholder")


func _text(path: String) -> String:
	return (_sidebar.get_node(path) as Label).text


func _labels(node: Node) -> Array[Label]:
	var found: Array[Label] = []
	for child: Node in node.get_children():
		if child is Label:
			found.append(child as Label)
		found.append_array(_labels(child))
	return found
