class_name Game
extends Node2D
## One level attempt: builds bricks from LevelData, connects the paddle, ball
## and HUD, and applies GameSession rules. Runs while paused so it can unpause;
## the Playfield child is pausable.

const BRICK_SCENE: PackedScene = preload("res://entities/brick/brick.tscn")
## Ignore launch presses this long after the game ends, so a click that was
## meant for the last ball doesn't instantly restart.
const RESTART_DELAY_MSEC: int = 600

@export var level: LevelData
@export_range(1, 9) var starting_lives: int = 3
@export var playfield_width: float = 1280.0
@export var brick_area_top: float = 104.0
@export var brick_spacing: Vector2 = Vector2(4.0, 4.0)
@export var pause_on_focus_loss: bool = true

var session: GameSession

var _ended_at_msec: int = 0
var _restarting: bool = false

@onready var _bricks: Node2D = %Bricks
@onready var _ball: Ball = %Ball
@onready var _hud: Hud = %Hud


func _ready() -> void:
	session = GameSession.new(starting_lives, _build_level())
	session.score_changed.connect(_hud.set_score)
	session.lives_changed.connect(_hud.set_lives)
	_ball.lost.connect(_on_ball_lost)

	_hud.set_score(session.score)
	_hud.set_lives(session.lives)
	_ball.attach_to_paddle()
	_hud.show_message("Re-Jardinians!", "Clear every flower brick.\nPress Space or click to launch.")


func _unhandled_input(event: InputEvent) -> void:
	# Mark the event handled before acting on it: restarting reloads the scene,
	# which removes this node from the tree (get_viewport() becomes null).
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_toggle_pause()
	elif event.is_action_pressed("launch_ball"):
		get_viewport().set_input_as_handled()
		_on_launch_pressed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and pause_on_focus_loss and session != null \
			and session.state == GameSession.State.PLAYING and not get_tree().paused:
		_toggle_pause()


## Spawns bricks and returns how many are destructible.
func _build_level() -> int:
	if level == null:
		push_error("Game has no LevelData assigned.")
		return 0
	for problem: String in level.validate():
		push_error("%s: %s" % [level.resource_path, problem])

	var cell := Brick.SIZE + brick_spacing
	var columns := level.get_column_count()
	var first_center := Vector2((playfield_width - columns * cell.x) * 0.5, brick_area_top) + cell * 0.5
	var destructible := 0
	for row: int in level.rows.size():
		var line := level.rows[row]
		for column: int in line.length():
			var brick_type := level.get_brick_type(line[column])
			if brick_type == null:
				continue
			var brick := BRICK_SCENE.instantiate() as Brick
			brick.setup(brick_type)
			brick.position = first_center + Vector2(column * cell.x, row * cell.y)
			brick.destroyed.connect(_on_brick_destroyed)
			_bricks.add_child(brick)
			if brick_type.destructible:
				destructible += 1
	return destructible


func _on_launch_pressed() -> void:
	if get_tree().paused:
		return
	match session.state:
		GameSession.State.READY:
			if session.launch():
				_ball.launch()
				_hud.hide_message()
		GameSession.State.WON, GameSession.State.GAME_OVER:
			if Time.get_ticks_msec() - _ended_at_msec >= RESTART_DELAY_MSEC:
				_restart()


func _toggle_pause() -> void:
	if session.is_finished():
		return
	var tree := get_tree()
	tree.paused = not tree.paused
	_hud.set_paused(tree.paused)


func _on_brick_destroyed(brick: Brick) -> void:
	if not session.brick_destroyed(brick.brick_type.points):
		return
	if session.state == GameSession.State.WON:
		_ball.stop()
		_show_end_message("Garden cleared!", "Final score: %d\nPress Space or click to play again." % session.score)


func _on_ball_lost() -> void:
	if not session.ball_lost():
		return
	if session.state == GameSession.State.GAME_OVER:
		_show_end_message("Game over", "Final score: %d\nPress Space or click to try again." % session.score)
		return
	_ball.attach_to_paddle()
	var lives_text := "1 life" if session.lives == 1 else "%d lives" % session.lives
	_hud.show_message("Ball lost!", "%s left.\nPress Space or click to launch." % lives_text)


func _show_end_message(title: String, body: String) -> void:
	_ended_at_msec = Time.get_ticks_msec()
	_hud.show_message(title, body)


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	get_tree().paused = false
	get_tree().reload_current_scene()
