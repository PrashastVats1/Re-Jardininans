class_name Playfield
extends Node2D
## The play area, in arena-local coordinates starting at the origin. get_size()
## is the single source of truth for its dimensions; the arena is placed at the
## top-left of the design canvas. Lays out the boundary walls around it.

const WALL_THICKNESS: float = 200.0

## Bottom edge of the ceiling wall, i.e. the height of the HUD bar.
@export var ceiling_y: float = 64.0

@onready var _left_wall: CollisionShape2D = $Walls/Left
@onready var _right_wall: CollisionShape2D = $Walls/Right
@onready var _top_wall: CollisionShape2D = $Walls/Top


## The design canvas minus the sidebar on its right (960x720 for 1280x720).
static func get_size() -> Vector2:
	return GameLayout.get_design_size() - Vector2(GameLayout.SIDEBAR_WIDTH, 0.0)


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
