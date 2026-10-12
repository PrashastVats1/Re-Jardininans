extends "res://tests/test_case.gd"
## Physics simulations. Run with --fixed-fps 60 so each frame is one 1/60 s step.

const BALL_SCENE: PackedScene = preload("res://entities/ball/ball.tscn")
const BRICK_SCENE: PackedScene = preload("res://entities/brick/brick.tscn")
const ARENA: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)


func run() -> void:
	await _test_ball_stays_in_closed_arena(900.0)
	await _test_ball_stays_in_closed_arena(2700.0)
	await _test_fast_ball_hits_brick_instead_of_tunneling(900.0)
	await _test_fast_ball_hits_brick_instead_of_tunneling(2700.0)


func _test_ball_stays_in_closed_arena(speed: float) -> void:
	var arena := _make_arena()
	var ball := BALL_SCENE.instantiate() as Ball
	ball.lost_below_y = INF
	ball.position = ARENA.get_center()
	arena.add_child(ball)
	ball.start_moving(Vector2(0.37, -0.93), speed)

	var inner := ARENA.grow(-ball.radius).grow(1.0)
	var escaped_at := -1
	var bad_angle := false
	for frame: int in 600:
		await tree.physics_frame
		if not inner.has_point(ball.position):
			escaped_at = frame
			break
		var elevation := rad_to_deg(atan2(absf(ball.direction.y), absf(ball.direction.x)))
		if elevation < ball.min_angle_from_horizontal_deg - 0.01 or elevation > 90.0 - ball.min_angle_from_vertical_deg + 0.01:
			bad_angle = true
	check(escaped_at == -1, "ball at %d px/s stays inside the arena for 600 steps (escaped at step %d, position %s)" % [speed, escaped_at, ball.position])
	check(not bad_angle, "ball at %d px/s never leaves the allowed angle range" % speed)
	arena.queue_free()
	await tree.process_frame


func _test_fast_ball_hits_brick_instead_of_tunneling(speed: float) -> void:
	var arena := _make_arena()
	var brick_type := BrickType.new()
	var brick := BRICK_SCENE.instantiate() as Brick
	brick.setup(brick_type)
	brick.position = Vector2(640.0, 200.0)
	arena.add_child(brick)
	var destroyed_count := [0]
	brick.destroyed.connect(func(_brick: Brick) -> void: destroyed_count[0] += 1)

	var ball := BALL_SCENE.instantiate() as Ball
	ball.lost_below_y = INF
	ball.max_speed = speed
	ball.position = Vector2(640.0, 600.0)
	arena.add_child(ball)
	ball.start_moving(Vector2(0.1, -1.0), speed)

	var bounced_back := false
	for frame: int in 120:
		await tree.physics_frame
		if destroyed_count[0] > 0 and ball.direction.y > 0.0:
			bounced_back = ball.position.y > brick.position.y
			break
	check_equal(destroyed_count[0], 1, "ball at %d px/s destroys the brick exactly once" % speed)
	check(bounced_back, "ball at %d px/s bounces back below the brick instead of passing through" % speed)
	arena.queue_free()
	await tree.process_frame


func _make_arena() -> Node2D:
	var arena := Node2D.new()
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	var thickness := 200.0
	for rect: Rect2 in [
			Rect2(ARENA.position.x - thickness, -thickness, thickness, ARENA.size.y + thickness * 2.0),
			Rect2(ARENA.end.x, -thickness, thickness, ARENA.size.y + thickness * 2.0),
			Rect2(-thickness, ARENA.position.y - thickness, ARENA.size.x + thickness * 2.0, thickness),
			Rect2(-thickness, ARENA.end.y, ARENA.size.x + thickness * 2.0, thickness)]:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		walls.add_child(collision)
	arena.add_child(walls)
	tree.root.add_child(arena)
	return arena
