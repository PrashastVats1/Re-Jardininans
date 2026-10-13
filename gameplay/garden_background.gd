extends Node2D
## Procedural garden backdrop: sky gradient, rolling hills, grass and the hedge
## behind the HUD bar.

@export var hud_bar_height: float = 64.0
@export var sky_top: Color = Color(0.53, 0.8, 0.98)
@export var sky_bottom: Color = Color(0.86, 0.95, 0.9)
@export var far_hill_color: Color = Color(0.56, 0.8, 0.45)
@export var near_hill_color: Color = Color(0.42, 0.7, 0.33)
@export var grass_color: Color = Color(0.3, 0.58, 0.22)
@export var hedge_color: Color = Color(0.16, 0.38, 0.15)


func _draw() -> void:
	var playfield_size := Playfield.get_size()
	var w := playfield_size.x
	var h := playfield_size.y
	draw_polygon(
			PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w, h), Vector2(0.0, h)]),
			PackedColorArray([sky_top, sky_top, sky_bottom, sky_bottom]))

	for cloud: Vector2 in [Vector2(180.0, 340.0), Vector2(760.0, 380.0), Vector2(1110.0, 320.0)]:
		for puff: Vector3 in [Vector3(-34.0, 6.0, 26.0), Vector3(0.0, 0.0, 34.0), Vector3(36.0, 8.0, 24.0)]:
			draw_circle(cloud + Vector2(puff.x, puff.y), puff.z, Color(1.0, 1.0, 1.0, 0.55), true, -1.0, true)

	# Shapes that overhang the playfield are clipped to it, so nothing spills
	# into the backdrop margins around the design canvas.
	var bounds := Rect2(Vector2.ZERO, playfield_size)
	_draw_clipped_circle(Vector2(w * 0.18, h + 300.0), 460.0, far_hill_color, bounds)
	_draw_clipped_circle(Vector2(w * 0.82, h + 340.0), 520.0, far_hill_color, bounds)
	_draw_clipped_circle(Vector2(w * 0.5, h + 420.0), 520.0, near_hill_color, bounds)
	draw_rect(Rect2(0.0, h - 18.0, w, 18.0), grass_color)

	draw_rect(Rect2(0.0, 0.0, w, hud_bar_height), hedge_color)
	var x := 0.0
	while x <= w:
		_draw_clipped_circle(Vector2(x, hud_bar_height - 6.0), 12.0, hedge_color, bounds)
		x += 24.0


func _draw_clipped_circle(center: Vector2, radius: float, color: Color, bounds: Rect2) -> void:
	var circle := PackedVector2Array()
	var segments := clampi(int(radius * 0.5), 16, 128)
	for i: int in segments:
		circle.append(center + Vector2.from_angle(TAU * i / segments) * radius)
	var clip := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
	for part: PackedVector2Array in Geometry2D.intersect_polygons(circle, clip):
		draw_colored_polygon(part, color)
