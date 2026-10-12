extends "res://tests/test_case.gd"


func run() -> void:
	_test_paddle_bounce_direction()
	_test_paddle_hit_offset()
	_test_constrain_direction()


func _test_paddle_bounce_direction() -> void:
	var center := BounceMath.paddle_bounce_direction(0.0, 60.0)
	check(center.is_equal_approx(Vector2.UP), "center hit goes straight up")

	var right := BounceMath.paddle_bounce_direction(1.0, 60.0)
	check_approx(rad_to_deg(right.angle_to(Vector2.UP)), -60.0, "right edge bounces 60 degrees right")
	check(right.x > 0.0 and right.y < 0.0, "right edge goes up and right")

	var left := BounceMath.paddle_bounce_direction(-1.0, 60.0)
	check(left.is_equal_approx(Vector2(-right.x, right.y)), "left edge mirrors right edge")

	var beyond := BounceMath.paddle_bounce_direction(3.0, 60.0)
	check(beyond.is_equal_approx(right), "offsets beyond the edge are clamped")
	check_approx(beyond.length(), 1.0, "bounce direction is a unit vector")


func _test_paddle_hit_offset() -> void:
	check_approx(BounceMath.paddle_hit_offset(640.0, 640.0, 70.0), 0.0, "center offset")
	check_approx(BounceMath.paddle_hit_offset(675.0, 640.0, 70.0), 0.5, "half-right offset")
	check_approx(BounceMath.paddle_hit_offset(500.0, 640.0, 70.0), -1.0, "offset clamps at -1")
	check_approx(BounceMath.paddle_hit_offset(700.0, 640.0, 0.0), 0.0, "zero-width paddle gives 0")


func _test_constrain_direction() -> void:
	var near_horizontal := BounceMath.constrain_direction(Vector2(1.0, 0.01), 18.0, 6.0)
	check(_elevation_deg(near_horizontal) >= 18.0 - 0.01, "near-horizontal is lifted to 18 degrees")
	check(near_horizontal.x > 0.0 and near_horizontal.y > 0.0, "near-horizontal keeps its quadrant")

	var flat := BounceMath.constrain_direction(Vector2(-1.0, 0.0), 18.0, 6.0)
	check(flat.x < 0.0 and flat.y < 0.0, "exactly horizontal is sent upward")

	var near_vertical := BounceMath.constrain_direction(Vector2(0.001, -1.0), 18.0, 6.0)
	check(_elevation_deg(near_vertical) <= 84.0 + 0.01, "near-vertical is tilted at least 6 degrees")

	var vertical_left := BounceMath.constrain_direction(Vector2(0.0, -1.0), 18.0, 6.0, -1.0)
	check(vertical_left.x < 0.0, "exactly vertical uses the fallback x sign")

	var normal := Vector2(0.6, -0.8)
	check(BounceMath.constrain_direction(normal, 18.0, 6.0).is_equal_approx(normal), "allowed directions are unchanged")

	for raw: Vector2 in [Vector2(3.0, 0.2), Vector2(-0.05, 4.0), Vector2(0.0, 0.0)]:
		check_approx(BounceMath.constrain_direction(raw, 18.0, 6.0).length(), 1.0, "constrained %s is a unit vector" % raw)


func _elevation_deg(direction: Vector2) -> float:
	return rad_to_deg(atan2(absf(direction.y), absf(direction.x)))
