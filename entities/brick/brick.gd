class_name Brick
extends StaticBody2D
## One brick. Configure with setup() before adding it to the tree.

signal destroyed(brick: Brick)

const SIZE: Vector2 = LevelGrid.BRICK_SIZE

var brick_type: BrickType
var hit_points: int = 1

var _is_destroyed: bool = false


func setup(type: BrickType) -> void:
	brick_type = type
	hit_points = type.hit_points
	queue_redraw()


func is_destructible() -> bool:
	return brick_type != null and brick_type.destructible


func hit() -> void:
	if _is_destroyed:
		return
	if not is_destructible():
		_flash()
		return
	hit_points -= 1
	if hit_points > 0:
		queue_redraw()
		_flash()
		return
	_is_destroyed = true
	collision_layer = 0
	destroyed.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.2, 0.2), 0.12)
	tween.tween_callback(queue_free)


func _flash() -> void:
	modulate = Color(1.6, 1.6, 1.6)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.15)


func _draw() -> void:
	var color := brick_type.color if brick_type != null else Color.WHITE
	var rect := Rect2(-SIZE * 0.5, SIZE)
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position + Vector2(3.0, 3.0), Vector2(SIZE.x - 6.0, 5.0)), color.lightened(0.3))
	draw_rect(rect, color.darkened(0.4), false, 2.0)

	if not is_destructible():
		var crack_color := color.darkened(0.35)
		draw_polyline(PackedVector2Array([Vector2(-22.0, -8.0), Vector2(-10.0, 0.0), Vector2(-16.0, 9.0)]), crack_color, 2.0, true)
		draw_polyline(PackedVector2Array([Vector2(14.0, -9.0), Vector2(20.0, 2.0), Vector2(28.0, 6.0)]), crack_color, 2.0, true)
		return

	if hit_points < brick_type.hit_points:
		draw_polyline(PackedVector2Array([Vector2(-30.0, -10.0), Vector2(-18.0, -2.0), Vector2(-24.0, 6.0), Vector2(-12.0, 12.0)]), color.darkened(0.55), 2.0, true)
