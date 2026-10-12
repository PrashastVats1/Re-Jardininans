class_name Paddle
extends AnimatableBody2D
## Player paddle. Keyboard input moves it at a fixed speed; moving the mouse
## switches to following the cursor until a movement key is pressed again.

@export var size: Vector2 = Vector2(140.0, 22.0)
@export var keyboard_speed: float = 900.0
## Caps how fast the paddle chases the cursor so it never teleports through the ball.
@export var mouse_follow_speed: float = 2400.0
@export var playfield_left: float = 0.0
@export var playfield_right: float = 1280.0
@export var body_color: Color = Color(0.55, 0.35, 0.18)
@export var leaf_color: Color = Color(0.36, 0.72, 0.28)

## Sign of the most recent horizontal movement, used to pick the launch side.
var last_direction_x: float = 1.0

var _follow_mouse: bool = false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	(_collision_shape.shape as RectangleShape2D).size = size
	queue_redraw()


func get_half_width() -> float:
	return size.x * 0.5


func _unhandled_input(event: InputEvent) -> void:
	# Window creation can emit a synthetic motion event with no movement; ignore it
	# so the paddle doesn't jump to wherever the cursor happens to be.
	var motion := event as InputEventMouseMotion
	if motion != null and not motion.relative.is_zero_approx() and get_window().has_focus():
		_follow_mouse = true


func _physics_process(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	var target_x := position.x
	if not is_zero_approx(axis):
		_follow_mouse = false
		target_x += axis * keyboard_speed * delta
	elif _follow_mouse:
		var mouse_x := (get_parent() as Node2D).get_local_mouse_position().x
		target_x = move_toward(position.x, mouse_x, mouse_follow_speed * delta)

	var half_width := get_half_width()
	target_x = clampf(target_x, playfield_left + half_width, playfield_right - half_width)
	if not is_equal_approx(target_x, position.x):
		last_direction_x = signf(target_x - position.x)
	position.x = target_x


func _draw() -> void:
	var half := size * 0.5
	var radius := half.y
	draw_rect(Rect2(-half.x + radius, -half.y, size.x - radius * 2.0, size.y), body_color)
	draw_circle(Vector2(-half.x + radius, 0.0), radius, body_color, true, -1.0, true)
	draw_circle(Vector2(half.x - radius, 0.0), radius, body_color, true, -1.0, true)
	draw_rect(Rect2(-half.x + radius, -half.y, size.x - radius * 2.0, size.y * 0.4), leaf_color)
	draw_rect(Rect2(-half.x + radius, half.y - 4.0, size.x - radius * 2.0, 3.0), body_color.darkened(0.3))
