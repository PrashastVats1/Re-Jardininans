class_name LevelReachability
extends RefCounted
## A coarse, grid-only check that the ball could ever touch every destructible
## brick. Starting from the open space below the grid (and beside or above it
## when those gaps are wide enough for the ball), cells open one at a time as
## their neighbours open; destructible bricks open once reachable, because the
## ball can break them, but indestructible bricks never do.
##
## It ignores ball physics, angles and paddle skill, so a fully reachable level
## is not proven winnable: the scripted-autoplay test is what shows a level can
## actually be cleared. Expects a level that passes LevelValidator.


## Returns the grid cells (column, row) of destructible bricks the ball can never reach.
static func find_unreachable(level: LevelData, open_sides: bool = true, open_top: bool = true) -> Array[Vector2i]:
	var row_count := level.rows.size()
	var columns := level.get_column_count()
	var open: Dictionary = {}
	for row: int in row_count:
		for column: int in columns:
			open[Vector2i(column, row)] = false
	var changed := true
	while changed:
		changed = false
		for cell: Vector2i in open:
			var brick_type := _cell_type(level, cell)
			if open[cell] or brick_type != null and not brick_type.destructible:
				continue
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next := cell + step
				var reachable: bool
				if open.has(next):
					reachable = open[next]
				elif next.y >= row_count:
					reachable = true
				elif next.y < 0:
					reachable = open_top
				else:
					reachable = open_sides
				if reachable:
					open[cell] = true
					changed = true
					break
	var unreachable: Array[Vector2i] = []
	for cell: Vector2i in open:
		var brick_type := _cell_type(level, cell)
		if brick_type != null and brick_type.destructible and not open[cell]:
			unreachable.append(cell)
	return unreachable


static func _cell_type(level: LevelData, cell: Vector2i) -> BrickType:
	var line := level.rows[cell.y]
	return level.get_brick_type(line[cell.x]) if cell.x < line.length() else null
