class_name Sidebar
extends Control
## Information column to the right of the arena: score, lives and level from
## the running game, then the player's records. Player records are not stored
## yet, so those rows show PLACEHOLDER until a save system provides them.

const PLACEHOLDER: String = "—"

@onready var _score_value: Label = %ScoreValue
@onready var _lives_value: Label = %LivesValue
@onready var _level_value: Label = %LevelValue
@onready var _player_value: Label = %PlayerValue
@onready var _high_score_value: Label = %HighScoreValue
@onready var _level_streak_value: Label = %LevelStreakValue


func _ready() -> void:
	_player_value.text = PLACEHOLDER
	_high_score_value.text = PLACEHOLDER
	_level_streak_value.text = PLACEHOLDER


func set_score(score: int) -> void:
	_score_value.text = str(score)


func set_lives(lives: int) -> void:
	_lives_value.text = str(lives)


## For a level that can't be played: no life count is meaningful.
func clear_lives() -> void:
	_lives_value.text = PLACEHOLDER


## A campaign level (level_number above 0) is shown as "12 · Name"; any other
## level by its name alone.
func set_level(level_name: String, level_number: int = 0) -> void:
	if level_number > 0:
		_level_value.text = "%d · %s" % [level_number, level_name] if not level_name.is_empty() else str(level_number)
	else:
		_level_value.text = level_name if not level_name.is_empty() else PLACEHOLDER
