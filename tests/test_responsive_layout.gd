extends "res://tests/test_case.gd"
## Resizing the window only changes canvas offsets: walls, bricks, paddle and
## ball keep their arena coordinates (in the scene and in the physics server),
## a moving ball keeps bouncing inside the arena across resizes, the plain
## backdrop fills the whole visible area, and the sidebar stays flush against
## the arena's right edge.

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
	var backdrop := game.get_node("Backdrop/Fill") as ColorRect
	var sidebar := game.get_node("Hud/Sidebar") as Control
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
		var arena_right_on_screen := tree.root.get_canvas_transform() * Vector2(arena.x, 0.0)
		check_equal(sidebar.get_global_transform_with_canvas().origin, arena_right_on_screen,
				"%s sidebar's left edge is on the arena's right edge on screen" % label)
		check_equal(sidebar.size, Vector2(GameLayout.SIDEBAR_WIDTH, arena.y), "%s sidebar keeps its size" % label)
		if DisplayServer.get_name() != "headless":
			await _check_frame_pixels(offset, backdrop.color, label)

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


## The margins outside the design canvas show the plain backdrop colour, and
## on either side of the arena's right edge the pixels are black arena and the
## sidebar divider, so the world and the HUD layer line up exactly.
func _check_frame_pixels(offset: Vector2, frame_color: Color, label: String) -> void:
	await RenderingServer.frame_post_draw
	var viewport := tree.root.get_viewport()
	var image := viewport.get_texture().get_image()
	var scale := Vector2(image.get_size()) / viewport.get_visible_rect().size
	var design := GameLayout.get_design_size()
	var arena := Playfield.get_size()
	var divider := (tree.root.find_child("Divider", true, false) as ColorRect).color
	var expectations: Dictionary = {
		offset + Vector2(arena.x - 3.0, design.y * 0.5): Color.BLACK,
		offset + Vector2(arena.x + 1.0, design.y * 0.5): divider,
	}
	if offset.x > 0.0:
		expectations[Vector2(offset.x * 0.5, offset.y + design.y * 0.5)] = frame_color
		expectations[Vector2(offset.x - 3.0, offset.y + design.y - 30.0)] = frame_color
	if offset.y > 0.0:
		expectations[Vector2(design.x * 0.5, offset.y * 0.5)] = frame_color
		expectations[Vector2(design.x * 0.18, offset.y + design.y + 3.0)] = frame_color
	for point: Vector2 in expectations:
		var color := image.get_pixelv(Vector2i((point * scale).floor()))
		var expected: Color = expectations[point]
		check(absf(color.r - expected.r) < 0.05 and absf(color.g - expected.g) < 0.05 and absf(color.b - expected.b) < 0.05,
				"%s screen point %s shows %s (got %s)" % [label, point, expected, color])
