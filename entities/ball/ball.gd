class_name Ball
extends CharacterBody2D
## The ball. Moves with swept move_and_collide() steps so it cannot tunnel
## through thin bricks at high speed, and computes its own bounces.

signal lost

const MAX_COLLISIONS_PER_STEP: int = 4

@export var paddle: Paddle
@export var radius: float = 10.0
@export var initial_speed: float = 420.0
@export var max_speed: float = 900.0
@export var speed_gain_per_brick_hit: float = 10.0
@export_range(0.0, 45.0) var min_angle_from_horizontal_deg: float = 18.0
@export_range(0.0, 45.0) var min_angle_from_vertical_deg: float = 6.0
@export_range(0.0, 85.0) var paddle_max_bounce_angle_deg: float = 60.0
## Paddle hit offset used for the launch direction (0 = straight up).
@export_range(0.0, 1.0) var launch_offset: float = 0.25
## How far below the playfield's bottom edge the ball must fall to count as lost.
@export var lost_margin: float = 40.0
@export var fill_color: Color = Color(1.0, 0.84, 0.25)
@export var outline_color: Color = Color(0.7, 0.4, 0.12)

var direction: Vector2 = Vector2.UP
var speed: float = 0.0
## Set from the playfield height in _ready().
var lost_below_y: float = 0.0

var _attached: bool = false
var _active: bool = false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	(_collision_shape.shape as CircleShape2D).radius = radius
	lost_below_y = Playfield.get_size().y + lost_margin
	queue_redraw()


func is_attached() -> bool:
	return _attached


func attach_to_paddle() -> void:
	_attached = true
	_active = true
	speed = initial_speed
	direction = Vector2.UP
	_follow_paddle()
	reset_physics_interpolation()


func launch() -> void:
	if not _attached:
		return
	var side := paddle.last_direction_x if paddle != null else 1.0
	start_moving(BounceMath.paddle_bounce_direction(launch_offset * side, paddle_max_bounce_angle_deg), initial_speed)


## Starts free movement in [param new_direction] at [param new_speed].
func start_moving(new_direction: Vector2, new_speed: float) -> void:
	_attached = false
	_active = true
	direction = new_direction.normalized()
	speed = new_speed


## Freezes the ball in place, e.g. after the level is won.
func stop() -> void:
	_active = false


func _physics_process(delta: float) -> void:
	if not _active:
		return
	if _attached:
		_follow_paddle()
		return
	_move(delta)
	if position.y > lost_below_y:
		_active = false
		lost.emit()


func _move(delta: float) -> void:
	var remaining := direction * speed * delta
	for i: int in MAX_COLLISIONS_PER_STEP:
		var collision := move_and_collide(remaining)
		if collision == null:
			return
		_bounce(collision)
		remaining = direction * collision.get_remainder().length()
		if remaining.is_zero_approx():
			return


func _bounce(collision: KinematicCollision2D) -> void:
	var collider := collision.get_collider()
	var previous_x_sign := signf(direction.x)

	if collider is Paddle and position.y < (collider as Paddle).position.y:
		var hit_paddle := collider as Paddle
		var offset := BounceMath.paddle_hit_offset(position.x, hit_paddle.position.x, hit_paddle.get_half_width())
		direction = BounceMath.paddle_bounce_direction(offset, paddle_max_bounce_angle_deg)
	else:
		direction = direction.bounce(collision.get_normal())

	if collider is Brick:
		(collider as Brick).hit()
		speed = minf(speed + speed_gain_per_brick_hit, max_speed)

	direction = BounceMath.constrain_direction(
			direction,
			min_angle_from_horizontal_deg,
			min_angle_from_vertical_deg,
			previous_x_sign)


func _follow_paddle() -> void:
	if paddle == null:
		return
	position = paddle.position + Vector2(0.0, -(paddle.size.y * 0.5 + radius + 2.0))


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, fill_color, true, -1.0, true)
	draw_circle(Vector2.ZERO, radius, outline_color, false, 2.0, true)
	draw_circle(Vector2(-radius * 0.35, -radius * 0.35), radius * 0.3, Color(1.0, 1.0, 1.0, 0.75), true, -1.0, true)
