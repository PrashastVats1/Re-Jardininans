class_name BounceMath
extends RefCounted
## Pure ball-direction helpers. No scene access, so they are unit-testable.


## Direction after hitting the paddle. [param hit_offset] is -1 at the paddle's
## left edge, 0 at its center and 1 at its right edge.
static func paddle_bounce_direction(hit_offset: float, max_angle_deg: float) -> Vector2:
	var angle := deg_to_rad(max_angle_deg) * clampf(hit_offset, -1.0, 1.0)
	return Vector2(sin(angle), -cos(angle))


## Where along the paddle the ball hit, from -1 (left edge) to 1 (right edge).
static func paddle_hit_offset(ball_x: float, paddle_x: float, paddle_half_width: float) -> float:
	if paddle_half_width <= 0.0:
		return 0.0
	return clampf((ball_x - paddle_x) / paddle_half_width, -1.0, 1.0)


## Keeps [param direction] at least [param min_from_horizontal_deg] away from
## horizontal and [param min_from_vertical_deg] away from vertical, preserving
## its quadrant. A zero x component uses [param fallback_x_sign]; a zero y
## component is treated as upward. Returns a unit vector.
static func constrain_direction(
		direction: Vector2,
		min_from_horizontal_deg: float,
		min_from_vertical_deg: float,
		fallback_x_sign: float = 1.0) -> Vector2:
	var x_sign := signf(direction.x)
	if x_sign == 0.0:
		x_sign = -1.0 if fallback_x_sign < 0.0 else 1.0
	var y_sign := signf(direction.y)
	if y_sign == 0.0:
		y_sign = -1.0

	var elevation := atan2(absf(direction.y), absf(direction.x))
	elevation = clampf(
			elevation,
			deg_to_rad(min_from_horizontal_deg),
			deg_to_rad(90.0 - min_from_vertical_deg))
	return Vector2(cos(elevation) * x_sign, sin(elevation) * y_sign)
