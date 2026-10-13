class_name Playfield
extends Node2D
## The play area. Its logical size is the project's base viewport size
## (display/window/size/viewport_width and viewport_height in project.godot),
## which is the single source of truth for playfield dimensions. Lays out the
## boundary walls around that rectangle.

const WALL_THICKNESS: float = 200.0

## Bottom edge of the ceiling wall, i.e. the height of the HUD bar.
@export var ceiling_y: float = 64.0

@onready var _left_wall: CollisionShape2D = $Walls/Left
@onready var _right_wall: CollisionShape2D = $Walls/Right
@onready var _top_wall: CollisionShape2D = $Walls/Top


static func get_size() -> Vector2:
	return Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))


static func get_rect() -> Rect2:
	return Rect2(Vector2.ZERO, get_size())


func _ready() -> void:
	var size := get_size()
	var side_wall_size := Vector2(WALL_THICKNESS, size.y + WALL_THICKNESS * 2.0)
	(_left_wall.shape as RectangleShape2D).size = side_wall_size
	(_right_wall.shape as RectangleShape2D).size = side_wall_size
	(_top_wall.shape as RectangleShape2D).size = Vector2(size.x + WALL_THICKNESS * 2.0, WALL_THICKNESS)
	_left_wall.position = Vector2(-WALL_THICKNESS * 0.5, size.y * 0.5)
	_right_wall.position = Vector2(size.x + WALL_THICKNESS * 0.5, size.y * 0.5)
	_top_wall.position = Vector2(size.x * 0.5, ceiling_y - WALL_THICKNESS * 0.5)
