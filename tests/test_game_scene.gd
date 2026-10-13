extends "res://tests/test_case.gd"
## Smoke test: the main scene loads, builds the level and wires its nodes.

const MAIN_SCENE_PATH: String = "res://main.tscn"


func run() -> void:
	var configured_main: String = ProjectSettings.get_setting("application/run/main_scene")
	if configured_main.begins_with("uid://"):
		configured_main = ResourceUID.get_id_path(ResourceUID.text_to_id(configured_main))
	check_equal(configured_main, MAIN_SCENE_PATH, "main.tscn is the configured main scene")
	for action: String in ["move_left", "move_right", "launch_ball", "pause"]:
		check(InputMap.has_action(action), "input action '%s' is defined in project.godot" % action)

	var main_scene := load(MAIN_SCENE_PATH) as PackedScene
	check(main_scene != null, "main scene loads")
	if main_scene == null:
		return
	var main := main_scene.instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	await tree.physics_frame

	var game := main.get_node_or_null("Game") as Game
	check(game != null, "main scene contains the Game")
	if game != null:
		check(game.session != null, "game created a session")
		check_equal(game.session.state, GameSession.State.READY, "game starts READY")
		check_equal(game.session.lives, 3, "game starts with three lives")
		check_equal(game.session.bricks_remaining, 40, "game counts 40 destructible bricks")
		var bricks := game.get_node("Playfield/Bricks")
		check_equal(bricks.get_child_count(), 42, "42 bricks spawned (40 + 2 stones)")
		var ball := game.get_node("Playfield/Ball") as Ball
		check(ball.paddle != null, "ball is linked to the paddle")
		check(ball.is_attached(), "ball starts attached to the paddle")
	main.queue_free()
	await tree.process_frame
