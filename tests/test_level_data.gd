extends "res://tests/test_case.gd"
## Test Garden's known properties, pinned on purpose as a regression test (the
## generic tests derive their expectations from each level's data instead),
## the fixture level being genuinely different, and LevelData's own checks.

const LevelFacts := preload("res://tests/level_facts.gd")
const TEST_LEVEL_PATH: String = "res://data/levels/test_level.tres"
const FIXTURE_PATH: String = "res://data/levels/fixture_islands.tres"
const LEVEL_LIST_PATH: String = "res://data/level_list.tres"
const TEST_GARDEN_TYPE_COUNTS: Dictionary = {
	"Clay pot": 7,
	"Red bloom": 11,
	"Yellow bloom": 11,
	"Blue bloom": 11,
	"Garden stone": 2,
}
## 7 clay pots at 120 points plus 33 blooms at 50 points.
const TEST_GARDEN_FULL_SCORE: int = 7 * 120 + 33 * 50


func run() -> void:
	_test_test_level_resource()
	_test_fixture_differs_from_test_garden()
	_test_validation_reports_problems()


func _test_test_level_resource() -> void:
	var level := load(TEST_LEVEL_PATH) as LevelData
	check(level != null, "test level loads as LevelData")
	if level == null:
		return
	check_equal(level.validate(), PackedStringArray(), "test level has no validation problems")
	check_equal(LevelValidator.validate(level), PackedStringArray(), "test level fits the arena")
	check_equal(level.display_name, "Test Garden", "test level is named Test Garden")
	check_equal(level.get_column_count(), 11, "test level is 11 columns wide")
	check_equal(level.rows.size(), 5, "test level is 5 rows tall")
	check_equal(level.count_destructible(), 40, "test level has 40 destructible bricks")
	check_equal(LevelFacts.brick_count(level), 42, "test level has 42 bricks (40 + 2 stones)")
	check_equal(LevelFacts.type_counts(level), TEST_GARDEN_TYPE_COUNTS, "test level's brick mix is unchanged")
	check_equal(LevelFacts.full_clear_score(level), TEST_GARDEN_FULL_SCORE, "test level's full clear is worth 2490")
	check(level.get_brick_type(".") == null, "'.' is an empty cell")
	var stone := level.get_brick_type("S")
	check(stone != null and not stone.destructible, "'S' is an indestructible stone")


## The fixture exists to prove nothing is tailored to Test Garden, so it must
## differ in shape and brick mix, and it must not be in the playable level list.
func _test_fixture_differs_from_test_garden() -> void:
	var garden := load(TEST_LEVEL_PATH) as LevelData
	var fixture := load(FIXTURE_PATH) as LevelData
	check(fixture != null, "fixture loads as LevelData")
	if fixture == null or garden == null:
		return
	check_equal(LevelValidator.validate(fixture), PackedStringArray(), "fixture passes validation")
	check(fixture.get_column_count() != garden.get_column_count(), "fixture has a different width (%d columns)" % fixture.get_column_count())
	check(fixture.rows.size() != garden.rows.size(), "fixture has a different height (%d rows)" % fixture.rows.size())
	check(LevelFacts.destructible_count(fixture) != LevelFacts.destructible_count(garden), "fixture has a different number of destructible bricks")
	check(LevelFacts.type_counts(fixture).keys() != LevelFacts.type_counts(garden).keys(), "fixture uses a different set of brick types")
	check(LevelFacts.full_clear_score(fixture) != LevelFacts.full_clear_score(garden), "fixture has a different full-clear score")
	check(fixture.display_name != garden.display_name, "fixture has its own name")
	var list := load(LEVEL_LIST_PATH) as LevelList
	check(not list.levels.has(fixture), "fixture is not in the playable level list")


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
