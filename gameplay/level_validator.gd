class_name LevelValidator
extends RefCounted
## Decides whether a level may be loaded into the arena: its data must be well
## formed (LevelData.validate()) and its grid must fit LevelGrid's limits.
## It says nothing about whether the ball can clear the level; see
## LevelReachability and the scripted-autoplay test for that.


## Returns every problem, each prefixed with the level's path or name; an empty
## array means the level can be built. The defaults are the stock ball, arena
## and paddle; pass the live values when they are known.
static func validate(level: LevelData, ball_diameter: float = Ball.DEFAULT_RADIUS * 2.0,
		arena_size: Vector2 = Playfield.get_size(), paddle_height: float = Paddle.DEFAULT_SIZE.y) -> PackedStringArray:
	if level == null:
		return PackedStringArray(["no level assigned"])
	var problems := level.validate()
	problems.append_array(check_fit(level, ball_diameter, arena_size, paddle_height))
	var label := describe(level)
	var labelled: PackedStringArray = []
	for problem: String in problems:
		labelled.append("%s: %s" % [label, problem])
	return labelled


## Grid bounds only: a ball-width gap beside the grid on both sides, and
## LevelGrid.MIN_PADDLE_CLEARANCE between the grid and the paddle.
static func check_fit(level: LevelData, ball_diameter: float = Ball.DEFAULT_RADIUS * 2.0,
		arena_size: Vector2 = Playfield.get_size(), paddle_height: float = Paddle.DEFAULT_SIZE.y) -> PackedStringArray:
	var problems: PackedStringArray = []
	var columns := level.get_column_count()
	var max_columns := LevelGrid.get_max_columns(ball_diameter, arena_size)
	if columns > max_columns:
		problems.append("%d columns are too wide: the %.0f px arena fits at most %d with a %.0f px ball gap on each side (side gap would be %.0f px)"
				% [columns, arena_size.x, max_columns, ball_diameter, LevelGrid.get_side_gap(columns, arena_size)])
	var rows := level.rows.size()
	var max_rows := LevelGrid.get_max_rows(arena_size, paddle_height)
	if rows > max_rows:
		problems.append("%d rows are too tall: they leave %.0f px above the paddle but at least %.0f px is required (at most %d rows fit)"
				% [rows, LevelGrid.get_paddle_clearance(rows, arena_size, paddle_height), LevelGrid.MIN_PADDLE_CLEARANCE, max_rows])
	return problems


static func describe(level: LevelData) -> String:
	if not level.resource_path.is_empty():
		return level.resource_path
	if not level.display_name.is_empty():
		return "level \"%s\"" % level.display_name
	return "unsaved level"
