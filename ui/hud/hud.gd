class_name Hud
extends CanvasLayer
## Controls hint and centered state messages over the arena, and the sidebar
## column to its right with score, lives, level and player records. Game shifts
## the whole layer by the same offset as the world.

@onready var _frame: Control = $Frame
@onready var _sidebar: Sidebar = %Sidebar
@onready var _message_panel: PanelContainer = %MessagePanel
@onready var _message_title: Label = %MessageTitle
@onready var _message_body: Label = %MessageBody
@onready var _pause_panel: PanelContainer = %PausePanel

var _has_message: bool = false


func _ready() -> void:
	# The scene anchors both to the full rect for the editor preview; at runtime
	# the frame covers exactly the arena and the sidebar the column to its right,
	# whatever the visible area's size.
	var arena := Playfield.get_size()
	_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_frame.position = Vector2.ZERO
	_frame.size = arena
	_sidebar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_sidebar.position = Vector2(arena.x, 0.0)
	_sidebar.size = Vector2(GameLayout.SIDEBAR_WIDTH, arena.y)


func set_score(score: int) -> void:
	_sidebar.set_score(score)


func set_lives(lives: int) -> void:
	_sidebar.set_lives(lives)


func set_level(level_name: String) -> void:
	_sidebar.set_level(level_name)


func show_message(title: String, body: String) -> void:
	_message_title.text = title
	_message_body.text = body
	_has_message = true
	_message_panel.visible = not _pause_panel.visible


func hide_message() -> void:
	_has_message = false
	_message_panel.visible = false


func set_paused(paused: bool) -> void:
	_pause_panel.visible = paused
	_message_panel.visible = _has_message and not paused
