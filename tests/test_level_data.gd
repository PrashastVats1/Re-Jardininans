extends "res://tests/test_case.gd"

const TEST_LEVEL_PATH: String = "res://data/levels/test_level.tres"


func run() -> void:
	_test_test_level_resource()
	_test_validation_reports_problems()


func _test_test_level_resource() -> void:
	var level := load(TEST_LEVEL_PATH) as LevelData
	check(level != null, "test level loads as LevelData")
	if level == null:
		return
	check_equal(level.validate(), PackedStringArray(), "test level has no validation problems")
	check_equal(level.get_column_count(), 14, "test level is 14 columns wide")
	check_equal(level.count_destructible(), 52, "test level has 52 destructible bricks")
	check(level.get_brick_type(".") == null, "'.' is an empty cell")
	var stone := level.get_brick_type("S")
	check(stone != null and not stone.destructible, "'S' is an indestructible stone")


func _test_validation_reports_problems() -> void:
	var flower := BrickType.new()
	var stone := BrickType.new()
	stone.destructible = false

	var level := LevelData.new()
	level.rows = PackedStringArray(["F.X", "S.F"])
	level.legend = {"F": flower, "S": stone}
	check_equal(level.count_destructible(), 2, "counts only destructible bricks")
	var problems := level.validate()
	check_equal(problems.size(), 1, "one problem reported")
	check(problems.size() == 1 and problems[0].contains("'X'"), "unknown symbol is named")

	var only_stone := LevelData.new()
	only_stone.rows = PackedStringArray(["SS"])
	only_stone.legend = {"S": stone}
	check(only_stone.validate().size() == 1, "level without destructible bricks is rejected")

	check(LevelData.new().validate().size() >= 1, "empty level is rejected")
