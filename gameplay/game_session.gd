class_name GameSession
extends RefCounted
## Rules for one level attempt: score, lives and the win/lose state.
## Every transition is guarded, so late events after the game ends are ignored.

signal score_changed(score: int)
signal lives_changed(lives: int)
signal state_changed(state: State)

enum State { READY, PLAYING, WON, GAME_OVER }

var score: int = 0
var lives: int
var bricks_remaining: int
var state: State = State.READY


func _init(starting_lives: int = 3, destructible_bricks: int = 0) -> void:
	lives = maxi(starting_lives, 1)
	bricks_remaining = maxi(destructible_bricks, 0)


func is_finished() -> bool:
	return state == State.WON or state == State.GAME_OVER


## Returns true if the ball may be launched now.
func launch() -> bool:
	if state != State.READY:
		return false
	_set_state(State.PLAYING)
	return true


## Returns true if the brick counted towards score and progress.
func brick_destroyed(points: int) -> bool:
	if state != State.PLAYING or bricks_remaining <= 0:
		return false
	score += maxi(points, 0)
	bricks_remaining -= 1
	score_changed.emit(score)
	if bricks_remaining == 0:
		_set_state(State.WON)
	return true


## Returns true if a life was actually lost.
func ball_lost() -> bool:
	if state != State.PLAYING:
		return false
	lives -= 1
	lives_changed.emit(lives)
	_set_state(State.GAME_OVER if lives <= 0 else State.READY)
	return true


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	state_changed.emit(state)
