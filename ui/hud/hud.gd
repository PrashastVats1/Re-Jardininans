class_name Hud
extends CanvasLayer
## Score, lives, controls hint and centered state messages, laid out over the
## arena (the sidebar column to its right stays free). Game shifts the whole
## layer by the same offset as the world.

@onready var _frame: Control = $Frame
@onready var _score_label: Label = %ScoreLabel
@onready var _lives_label: Label = %LivesLabel
@onready var _message_panel: PanelContainer = %MessagePanel
@onready var _message_title: Label = %MessageTitle
@onready var _message_body: Label = %MessageBody
@onready var _pause_panel: PanelContainer = %PausePanel

var _has_message: bool = false


func _ready() -> void:
	# The scene anchors the frame to the full rect for the editor preview; at
	# runtime it covers exactly the arena, whatever the visible area's size.
	_frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_frame.position = Vector2.ZERO
	_frame.size = Playfield.get_size()


func set_score(score: int) -> void:
	_score_label.text = "Score: %d" % score


func set_lives(lives: int) -> void:
	_lives_label.text = "Lives: %d" % lives


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
