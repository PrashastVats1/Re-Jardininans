class_name Game
extends Node2D
## One level attempt: builds bricks from LevelData, connects the paddle, ball
## and HUD, and applies GameSession rules. Runs while paused so it can unpause;
## the Playfield child is pausable.

const BRICK_SCENE: PackedScene = preload("res://entities/brick/brick.tscn")
## Ignore launch presses this long after the game ends, so a click that was
## meant for the last ball doesn't instantly restart.
const RESTART_DELAY_MSEC: int = 600

## The level to play outside the campaign (development levels and fixtures).
## Set it before the game enters the tree; when it is unset the first level of
## [member level_list] is used. Leave it unset for a campaign game.
@export var level: LevelData
## Development levels; not the campaign.
@export var level_list: LevelList
## Starting lives outside the campaign; campaign levels use CampaignRules.
@export_range(1, 9) var starting_lives: int = 3
@export var pause_on_focus_loss: bool = true
## The campaign's levels in order: Level 1 is entry 0.
@export var campaign: LevelList
## Campaign level to play from [member campaign]; 0 means this is not a
## campaign game. Any other number must be a valid CampaignRules level with an
## entry in the campaign, or the game reports it and refuses to play.
@export var level_number: int = 0

## Campaign score on entering this level. Set it before the game enters the
## tree; a restart keeps it, so the campaign score rolls back to it.
var campaign_score_at_entry: int = 0
var session: GameSession

var _ended_at_msec: int = 0
var _restarting: bool = false
## LevelValidator problems with [member level]; when any exist, no bricks are
## spawned and the ball can't be launched.
var _level_problems: PackedStringArray = []

@onready var _bricks: Node2D = %Bricks
@onready var _paddle: Paddle = %Paddle
@onready var _ball: Ball = %Ball
@onready var _hud: Hud = %Hud


func _ready() -> void:
	get_window().min_size = GameLayout.MIN_WINDOW_SIZE
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()

	var selection_problems := _select_level()
	session = GameSession.new(get_level_starting_lives(), _build_level(selection_problems), campaign_score_at_entry)
	session.score_changed.connect(_hud.set_score)
	session.lives_changed.connect(_hud.set_lives)
	_ball.lost.connect(_on_ball_lost)

	_hud.set_score(session.score)
	_hud.set_lives(session.lives)
	_hud.set_level(level.display_name if level != null else "", level_number)
	_paddle.position = Vector2(Playfield.get_size().x * 0.5, LevelGrid.get_paddle_y())
	_paddle.reset_physics_interpolation()
	_ball.attach_to_paddle()
	if has_playable_level():
		_hud.show_message(_get_start_title(), "Press Space or click to launch.")
	else:
		_hud.clear_lives()
		_hud.show_message("Level unavailable", "This level's data is invalid, so it can't be played.\nSee the error log for details.")


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


## Centers the design canvas in the visible area by offsetting only the canvas
## transforms (world and HUD together), so physics bodies never move. Avoid a
## Camera2D here: with physics interpolation it applies offsets a frame late.
func _apply_layout() -> void:
	var viewport := get_viewport()
	var offset := GameLayout.get_offset(viewport.get_visible_rect().size)
	viewport.canvas_transform = Transform2D(0.0, offset)
	_hud.offset = offset


func has_playable_level() -> bool:
	return _level_problems.is_empty()


func is_campaign_game() -> bool:
	return level_number != 0


## Lives a fresh attempt starts with: the campaign rule for a campaign level,
## otherwise [member starting_lives].
func get_level_starting_lives() -> int:
	return CampaignRules.get_starting_lives(level_number) if is_campaign_game() else starting_lives


## Picks [member level] and returns any problems with the choice. A campaign
## game takes entry level_number - 1 of [member campaign]; anything else uses
## the assigned level or the first development level.
func _select_level() -> PackedStringArray:
	if not is_campaign_game():
		if level == null and level_list != null:
			level = level_list.get_level(0)
		return PackedStringArray()
	if level != null:
		var assigned := level
		level = null
		return PackedStringArray(["campaign level %d was requested but a level (%s) is also assigned; assign one or the other"
				% [level_number, LevelValidator.describe(assigned)]])
	if not CampaignRules.is_valid_level(level_number):
		return PackedStringArray(["campaign level %d does not exist: campaign levels are numbered 1 to %d"
				% [level_number, CampaignRules.LEVEL_COUNT]])
	if campaign == null:
		return PackedStringArray(["campaign level %d was requested but no campaign is assigned" % level_number])
	level = campaign.get_level(level_number - 1)
	if level == null:
		return PackedStringArray(["campaign level %d is missing: the campaign has %d level entries"
				% [level_number, campaign.size()]])
	return PackedStringArray()


func _get_start_title() -> String:
	if not is_campaign_game():
		return "Re-Jardinians!"
	return "Level %d: Tutorial" % level_number if CampaignRules.is_tutorial(level_number) else "Level %d" % level_number


## Spawns bricks and returns how many are destructible. A level that wasn't
## selected or fails validation spawns nothing, so it can never be played
## half-built.
func _build_level(selection_problems: PackedStringArray) -> int:
	_level_problems = selection_problems
	if _level_problems.is_empty():
		_level_problems = LevelValidator.validate(level, _ball.radius * 2.0, Playfield.get_size(), _paddle.size.y)
	for problem: String in _level_problems:
		push_error(problem)
	if not has_playable_level():
		return 0

	var columns := level.get_column_count()
	var destructible := 0
	for row: int in level.rows.size():
		var line := level.rows[row]
		for column: int in line.length():
			var brick_type := level.get_brick_type(line[column])
			if brick_type == null:
				continue
			var brick := BRICK_SCENE.instantiate() as Brick
			brick.setup(brick_type)
			brick.position = LevelGrid.get_cell_center(column, row, columns)
			brick.destroyed.connect(_on_brick_destroyed)
			_bricks.add_child(brick)
			if brick_type.destructible:
				destructible += 1
	return destructible


func _on_launch_pressed() -> void:
	if get_tree().paused or not has_playable_level():
		return
	match session.state:
		GameSession.State.READY:
			if session.launch():
				_ball.launch()
				_hud.hide_message()
		GameSession.State.WON, GameSession.State.GAME_OVER:
			if Time.get_ticks_msec() - _ended_at_msec < RESTART_DELAY_MSEC:
				return
			if _can_advance():
				advance()
			else:
				restart()


func _toggle_pause() -> void:
	if session.is_finished():
		return
	var tree := get_tree()
	tree.paused = not tree.paused
	_hud.set_paused(tree.paused)


func _on_brick_destroyed(brick: Brick) -> void:
	if not session.brick_destroyed(brick.brick_type.points):
		return
	if session.state != GameSession.State.WON:
		return
	_ball.stop()
	if not is_campaign_game():
		_show_end_message("Level cleared!", "Final score: %d\nPress Space or click to play again." % session.score)
	elif CampaignRules.is_last_level(level_number):
		_show_end_message("Campaign complete", "Final campaign score: %d\nPress Space or click to replay Level %d."
				% [session.get_campaign_score(), level_number])
	else:
		_show_end_message("Level %d cleared!" % level_number, "Campaign score: %d\nPress Space or click for Level %d."
				% [session.get_campaign_score(), level_number + 1])


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


## Replaces the current scene with a fresh copy playing the same level with the
## same settings and campaign score on entry. Reloading the scene file instead
## would bring back the scene's default level. The copy validates the level
## again when it loads.
func restart() -> void:
	_replace_with_fresh_game("restart", level_number, campaign_score_at_entry)


## After winning a campaign level other than the last, replaces the scene with
## a fresh game playing the next campaign level, entered with this level's
## final campaign score. A missing or invalid next level is refused when it
## loads, like any other.
func advance() -> void:
	if not _can_advance():
		push_error("Game.advance() needs a won campaign level before Level %d." % CampaignRules.LEVEL_COUNT)
		return
	_replace_with_fresh_game("advance", level_number + 1, session.get_campaign_score())


func _can_advance() -> bool:
	return is_campaign_game() and has_playable_level() and session.state == GameSession.State.WON \
			and CampaignRules.is_valid_level(level_number) and not CampaignRules.is_last_level(level_number)


## Only one replacement per game: the scene swap happens at the end of the
## frame, so later requests in the same frame must not queue another.
func _replace_with_fresh_game(action: String, next_level_number: int, entry_total: int) -> void:
	if _restarting:
		return
	var tree := get_tree()
	var scene := tree.current_scene
	if scene == null or not (scene == self or scene.is_ancestor_of(self)) or scene.scene_file_path.is_empty():
		push_error("Game.%s() needs the game to be part of a current scene loaded from a file." % action)
		return
	_restarting = true
	tree.paused = false
	var fresh := (load(scene.scene_file_path) as PackedScene).instantiate()
	var game := fresh.get_node(scene.get_path_to(self)) as Game
	game.level = null if is_campaign_game() else level
	game.level_list = level_list
	game.campaign = campaign
	game.level_number = next_level_number
	game.starting_lives = starting_lives
	game.pause_on_focus_loss = pause_on_focus_loss
	game.campaign_score_at_entry = entry_total
	tree.change_scene_to_node(fresh)
