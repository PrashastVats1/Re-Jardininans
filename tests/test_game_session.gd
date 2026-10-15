extends "res://tests/test_case.gd"


func run() -> void:
	_test_initial_state()
	_test_launch_only_when_ready()
	_test_scoring_and_victory()
	_test_lives_and_game_over()
	_test_no_changes_after_end()
	_test_campaign_score()
	_test_new_attempt_rolls_campaign_score_back()


func _test_initial_state() -> void:
	var session := GameSession.new(3, 5)
	check_equal(session.score, 0, "starts with zero score")
	check_equal(session.lives, 3, "starts with three lives")
	check_equal(session.bricks_remaining, 5, "tracks destructible bricks")
	check_equal(session.state, GameSession.State.READY, "starts READY")
	check(not session.is_finished(), "not finished at start")


func _test_launch_only_when_ready() -> void:
	var session := GameSession.new(3, 5)
	check(not session.brick_destroyed(50), "bricks do not score before launch")
	check(session.launch(), "launch from READY succeeds")
	check_equal(session.state, GameSession.State.PLAYING, "launch moves to PLAYING")
	check(not session.launch(), "second launch is rejected")


func _test_scoring_and_victory() -> void:
	var session := GameSession.new(3, 2)
	var transitions: Array[GameSession.State] = []
	session.state_changed.connect(func(state: GameSession.State) -> void: transitions.append(state))
	session.launch()
	check(session.brick_destroyed(50), "first brick counts")
	check_equal(session.score, 50, "score after first brick")
	check_equal(session.state, GameSession.State.PLAYING, "still playing with bricks left")
	check(session.brick_destroyed(120), "last brick counts")
	check_equal(session.score, 170, "score after last brick")
	check_equal(session.state, GameSession.State.WON, "clearing all bricks wins")
	check(session.is_finished(), "won session is finished")
	check_equal(transitions, [GameSession.State.PLAYING, GameSession.State.WON] as Array[GameSession.State], "exactly one transition each to PLAYING and WON")


func _test_lives_and_game_over() -> void:
	var session := GameSession.new(3, 10)
	session.launch()
	check(session.ball_lost(), "losing a ball while playing counts")
	check_equal(session.lives, 2, "one life lost")
	check_equal(session.state, GameSession.State.READY, "back to READY after losing a life")
	check(not session.ball_lost(), "cannot lose a ball while READY")
	check_equal(session.lives, 2, "lives unchanged while READY")

	session.launch()
	session.ball_lost()
	session.launch()
	session.ball_lost()
	check_equal(session.lives, 0, "no lives left")
	check_equal(session.state, GameSession.State.GAME_OVER, "losing the last life ends the game")


func _test_no_changes_after_end() -> void:
	var won := GameSession.new(3, 1)
	won.launch()
	won.brick_destroyed(50)
	check(not won.brick_destroyed(50), "no scoring after victory")
	check(not won.ball_lost(), "no life lost after victory")
	check(not won.launch(), "no launch after victory")
	check_equal(won.score, 50, "score frozen after victory")
	check_equal(won.lives, 3, "lives frozen after victory")

	var lost := GameSession.new(1, 5)
	lost.launch()
	lost.ball_lost()
	check_equal(lost.state, GameSession.State.GAME_OVER, "single life session ends")
	check(not lost.brick_destroyed(50), "no scoring after game over")
	check(not lost.launch(), "no launch after game over")
	check_equal(lost.score, 0, "score frozen after game over")


func _test_campaign_score() -> void:
	var outside := GameSession.new(3, 2)
	check_equal(outside.campaign_score_at_entry, 0, "without a campaign total the entry score is 0")
	check_equal(outside.get_campaign_score(), 0, "and the campaign score starts at 0")

	var session := GameSession.new(3, 2, 1000)
	check_equal(session.score, 0, "the level score starts at 0 on a fresh attempt")
	check_equal(session.get_campaign_score(), 1000, "the campaign score starts at the entry total")
	var reported: Array[int] = []
	session.score_changed.connect(func(score: int) -> void: reported.append(score))
	session.launch()
	session.brick_destroyed(50)
	check_equal([session.score, session.get_campaign_score()], [50, 1050], "a brick adds to both scores")
	session.brick_destroyed(120)
	check_equal([session.score, session.get_campaign_score()], [170, 1170], "the last brick adds to both scores")
	check_equal(reported, [50, 170] as Array[int], "score_changed still reports the level score")
	check_equal(session.campaign_score_at_entry, 1000, "the entry total never changes during the attempt")
	check(not session.brick_destroyed(50), "no scoring after victory")
	check_equal(session.get_campaign_score(), 1170, "the campaign score is frozen after victory")

	var lost := GameSession.new(1, 5, 300)
	lost.launch()
	lost.brick_destroyed(50)
	lost.ball_lost()
	check_equal(lost.state, GameSession.State.GAME_OVER, "losing the only life ends the attempt")
	check_equal([lost.score, lost.get_campaign_score()], [50, 350], "game over keeps the points scored so far")

	check_equal(GameSession.new(3, 2, -40).get_campaign_score(), 0, "a negative entry total is treated as 0")


## A restart is a new attempt with the same entry total.
func _test_new_attempt_rolls_campaign_score_back() -> void:
	var first := GameSession.new(3, 5, 800)
	first.launch()
	first.brick_destroyed(50)
	first.brick_destroyed(120)
	check_equal(first.get_campaign_score(), 970, "the first attempt scored 170")
	var retry := GameSession.new(3, 5, first.campaign_score_at_entry)
	check_equal(retry.score, 0, "the retry's level score is 0")
	check_equal(retry.get_campaign_score(), 800, "the retry's campaign score is back to the entry total")
