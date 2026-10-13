extends "res://tests/test_case.gd"
## LevelReachability on small in-memory grids. Reachability only says the ball
## could touch every destructible brick; actual clearing is proven by the
## scripted-autoplay test.


func run() -> void:
	var a := BrickType.new()
	var s := BrickType.new()
	s.destructible = false
	var legend := {"A": a, "S": s}

	check_equal(_unreachable(["AAA", "AAA"], legend), [], "an open grid is fully reachable")
	check_equal(_unreachable(["SAS", "SAS", "SAS"], legend), [], "bricks are peeled one by one from below")
	check_equal(_unreachable(["SSS", "SAS", "S.S"], legend), [], "empty cells let the ball in")
	check_equal(_unreachable(["SSS", "SAS", "SSS"], legend), [Vector2i(1, 1)], "a brick walled in by stones is unreachable")
	check_equal(_unreachable(["AASAA", "SSSSS"], legend, true, false), [], "open sides reach bricks above a stone floor")
	check_equal(_unreachable(["AASAA", "SSSSS"], legend, false, false), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(3, 0), Vector2i(4, 0)],
			"with sides and top closed, bricks above a stone floor are unreachable")
	check_equal(_unreachable(["SAS", "SSS"], legend, false, true), [], "an open top reaches the top row")
	check_equal(_unreachable(["SAS", "SSS"], legend, false, false), [Vector2i(1, 0)], "a closed top does not")
	check_equal(_unreachable(["SS", "SS"], legend), [], "stones themselves are never reported")


func _unreachable(rows: Array, legend: Dictionary, open_sides: bool = true, open_top: bool = true) -> Array:
	var level := LevelData.new()
	level.rows = PackedStringArray(rows)
	level.legend = legend
	var cells: Array = []
	cells.assign(LevelReachability.find_unreachable(level, open_sides, open_top))
	cells.sort()
	return cells
