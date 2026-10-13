class_name Paddle
extends AnimatableBody2D
## Player paddle. Keyboard input moves it at a fixed speed. Moving the pointer
## inside the game window switches to following it; the pointer leaving the
## window or the window losing focus stops following, so the paddle stays put.

@export var size: Vector2 = Vector2(140.0, 22.0)
@export var keyboard_speed: float = 900.0
## Caps how fast the paddle chases the pointer so it never teleports through the ball.
@export var mouse_follow_speed: float = 2400.0
@export var body_color: Color = Color(0.55, 0.35, 0.18)
@export var leaf_color: Color = Color(0.36, 0.72, 0.28)

## Sign of the most recent horizontal movement, used to pick the launch side.
var last_direction_x: float = 1.0

var _follow_mouse: bool = false
## Last in-window pointer x, in the parent's coordinates.
var _mouse_target_x: float = 0.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	(_collision_shape.shape as RectangleShape2D).size = size
	var window := get_window()
	window.mouse_exited.connect(stop_following_mouse)
	window.focus_exited.connect(stop_following_mouse)
	queue_redraw()


func get_half_width() -> float:
	return size.x * 0.5


func is_following_mouse() -> bool:
	return _follow_mouse


func stop_following_mouse() -> void:
	_follow_mouse = false


# The target comes from motion events rather than polling the mouse position:
# for the root window Godot reports the OS cursor position even when it is
# outside the window, which used to drag the paddle against an edge.
func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	# Window creation can emit a synthetic motion event with no movement.
	if motion == null or motion.relative.is_zero_approx():
		return
	var window := get_window()
	if not window.has_focus() or not _is_inside_window(motion, window):
		return
	_mouse_target_x = (get_parent() as CanvasItem).make_input_local(motion).position.x
	_follow_mouse = true


func _physics_process(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	var target_x := position.x
	if not is_zero_approx(axis):
		_follow_mouse = false
		target_x += axis * keyboard_speed * delta
	elif _follow_mouse:
		target_x = move_toward(position.x, _mouse_target_x, mouse_follow_speed * delta)

	var half_width := get_half_width()
	target_x = clampf(target_x, half_width, Playfield.get_size().x - half_width)
	if not is_equal_approx(target_x, position.x):
		last_direction_x = signf(target_x - position.x)
	position.x = target_x


# Motion can still arrive from outside the window while a button is held.
func _is_inside_window(motion: InputEventMouseMotion, window: Window) -> bool:
	var window_point := window.get_final_transform() * motion.position
	return Rect2(Vector2.ZERO, Vector2(window.size)).has_point(window_point)


func _draw() -> void:
	var half := size * 0.5
	var radius := half.y
	draw_rect(Rect2(-half.x + radius, -half.y, size.x - radius * 2.0, size.y), body_color)
	draw_circle(Vector2(-half.x + radius, 0.0), radius, body_color, true, -1.0, true)
	draw_circle(Vector2(half.x - radius, 0.0), radius, body_color, true, -1.0, true)
	draw_rect(Rect2(-half.x + radius, -half.y, size.x - radius * 2.0, size.y * 0.4), leaf_color)
	draw_rect(Rect2(-half.x + radius, half.y - 4.0, size.x - radius * 2.0, 3.0), body_color.darkened(0.3))
