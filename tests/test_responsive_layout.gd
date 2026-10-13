extends "res://tests/test_case.gd"
## Resizing the window only changes canvas offsets: walls, bricks, paddle and
## ball keep their arena coordinates (in the scene and in the physics server),
## a moving ball keeps bouncing inside the arena across resizes, and the
## backdrop fills the whole visible area.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1024, 768),
	Vector2i(1280, 800), Vector2i(960, 540), Vector2i(1280, 720),
]
const FRAMES_PER_SIZE: int = 30


func run() -> void:
	var original_size := tree.root.size
	var main := MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	var game := main.get_node("Game") as Game
	game.pause_on_focus_loss = false
	var paddle := game.get_node("Playfield/Paddle") as Paddle
	var ball := game.get_node("Playfield/Ball") as Ball
	var playfield := game.get_node("Playfield") as Playfield
	var backdrop := game.get_node("Backdrop/GardenBackdrop") as Control
	# The test steers the paddle under the ball so no life is lost.
	paddle.set_physics_process(false)
	await tree.physics_frame

	var initial := _positions(game)
	var launch := InputEventAction.new()
	launch.action = "launch_ball"
	launch.pressed = true
	Input.parse_input_event(launch)
	await tree.physics_frame
	check_equal(game.session.state, GameSession.State.PLAYING, "ball launched")

	var arena := Playfield.get_size()
	var unchanged_by_resize := true
	var bad_step := ""
	var left_arena := ""
	var prev_ball := ball.position
	for window_size: Vector2i in SIZES:
		var before := _positions(game)
		tree.root.size = window_size
		var after := _positions(game)
		unchanged_by_resize = unchanged_by_resize and before == after
		prev_ball = ball.position

		var label := "[%dx%d]" % [window_size.x, window_size.y]
		var visible := tree.root.get_visible_rect().size
		var offset := GameLayout.get_offset(visible)
		check_equal(tree.root.get_canvas_transform().origin, offset, "%s world offset applied in the same frame" % label)
		check_equal((game.get_node("Hud") as CanvasLayer).offset, offset, "%s HUD offset applied in the same frame" % label)
		await tree.process_frame
		check_equal(backdrop.get_global_rect(), Rect2(Vector2.ZERO, visible), "%s backdrop fills the visible area" % label)
		if DisplayServer.get_name() != "headless" and offset != Vector2.ZERO:
			await _check_backdrop_pixels(offset, label)

		for frame: int in FRAMES_PER_SIZE:
			paddle.position.x = clampf(ball.position.x, paddle.get_half_width(), arena.x - paddle.get_half_width())
			await tree.physics_frame
			var step := ball.position.distance_to(prev_ball)
			if step > ball.speed / Engine.physics_ticks_per_second + 0.01 and bad_step.is_empty():
				bad_step = "%s step %.2f at speed %.0f" % [label, step, ball.speed]
			prev_ball = ball.position
			var inside := ball.position.x >= ball.radius - 0.5 and ball.position.x <= arena.x - ball.radius + 0.5 \
					and ball.position.y >= playfield.ceiling_y + ball.radius - 0.5
			if not inside and left_arena.is_empty():
				left_arena = "%s ball at %s" % [label, ball.position]

	check(unchanged_by_resize, "resizing never moves walls, bricks, paddle or ball (scene and physics server)")
	check(bad_step.is_empty(), "ball moves at most one physics step per tick across resizes %s" % bad_step)
	check(left_arena.is_empty(), "ball stays inside the arena walls across resizes %s" % left_arena)
	check_equal(game.session.lives, game.starting_lives, "no life lost while resizing")

	var walls_and_bricks_kept := true
	for key: Variant in initial:
		if not is_instance_valid(key):
			continue
		var node := key as Node2D
		if node is Brick or node is CollisionShape2D:
			walls_and_bricks_kept = walls_and_bricks_kept and node.global_position == (initial[node] as Array)[0]
	check(walls_and_bricks_kept, "walls and surviving bricks are exactly where they started")

	tree.root.size = original_size
	main.queue_free()
	await tree.process_frame


## Node -> [scene global position, physics server position] for the walls,
## bricks, paddle and ball.
func _positions(game: Game) -> Dictionary:
	var positions: Dictionary = {}
	var nodes: Array[Node2D] = []
	for wall: Node in game.get_node("Playfield/Walls").get_children():
		nodes.append(wall as Node2D)
	for brick: Node in game.get_node("Playfield/Bricks").get_children():
		nodes.append(brick as Node2D)
	nodes.append(game.get_node("Playfield/Paddle") as Node2D)
	nodes.append(game.get_node("Playfield/Ball") as Node2D)
	for node: Node2D in nodes:
		var body := node as CollisionObject2D
		var server_position := Vector2.INF
		if body != null:
			server_position = (PhysicsServer2D.body_get_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM) as Transform2D).origin
		positions[node] = [node.global_position, server_position]
	return positions


## The margins outside the design canvas show the hedge backdrop, including
## right next to the arena's bottom corner where the background hills overhang.
func _check_backdrop_pixels(offset: Vector2, label: String) -> void:
	await RenderingServer.frame_post_draw
	var viewport := tree.root.get_viewport()
	var image := viewport.get_texture().get_image()
	var scale := Vector2(image.get_size()) / viewport.get_visible_rect().size
	var design := GameLayout.get_design_size()
	var points: Array[Vector2] = []
	if offset.x > 0.0:
		points = [Vector2(offset.x * 0.5, offset.y + design.y * 0.5), Vector2(offset.x - 3.0, offset.y + design.y - 30.0)]
	else:
		points = [Vector2(design.x * 0.5, offset.y * 0.5), Vector2(design.x * 0.18, offset.y + design.y + 3.0)]
	var backdrop := game_backdrop_colors()
	for point: Vector2 in points:
		var color := image.get_pixelv(Vector2i((point * scale).floor()))
		var matches := false
		for expected: Color in backdrop:
			matches = matches or (absf(color.r - expected.r) < 0.05 and absf(color.g - expected.g) < 0.05 and absf(color.b - expected.b) < 0.05)
		check(matches, "%s margin at %s shows the backdrop (got %s)" % [label, point, color])


func game_backdrop_colors() -> Array[Color]:
	var backdrop := preload("res://gameplay/garden_backdrop.gd").new() as Control
	var colors: Array[Color] = [backdrop.base_color, backdrop.leaf_color, backdrop.flower_color]
	backdrop.free()
	return colors
