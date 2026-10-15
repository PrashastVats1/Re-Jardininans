extends "res://tests/test_case.gd"
## CampaignRules for every level number: 64 levels, Level 1 alone is the
## tutorial, starting lives 5 / 4 / 3 for levels 1-10 / 11-20 / 21-64, and
## safe answers for numbers that are not campaign levels.

const INVALID_LEVELS: Array[int] = [0, -1, -64, 65, 100, 1 << 31, -(1 << 31), 9223372036854775807]


func run() -> void:
	_test_level_count()
	_test_every_level()
	_test_band_boundaries()
	_test_tutorial_and_last_level()
	_test_invalid_level_numbers()
	_test_bands_cover_the_campaign()
	_test_independent_of_level_files()


func _test_level_count() -> void:
	check_equal(CampaignRules.LEVEL_COUNT, 64, "the campaign has exactly 64 levels")
	check_equal(CampaignRules.TUTORIAL_LEVEL, 1, "Level 1 is the tutorial")


## The expected lives are written out here rather than read from LIVES_BANDS.
func _test_every_level() -> void:
	var wrong_lives: PackedStringArray = []
	var invalid: Array[int] = []
	var tally: Dictionary = {}
	for level: int in range(1, 65):
		var expected := 5 if level <= 10 else 4 if level <= 20 else 3
		var lives := CampaignRules.get_starting_lives(level)
		if lives != expected:
			wrong_lives.append("level %d: %d lives, expected %d" % [level, lives, expected])
		if not CampaignRules.is_valid_level(level):
			invalid.append(level)
		tally[lives] = int(tally.get(lives, 0)) + 1
	check(wrong_lives.is_empty(), "every level 1-64 starts with the right lives %s" % [wrong_lives])
	check(invalid.is_empty(), "levels 1-64 are all valid %s" % [invalid])
	check_equal(tally, {5: 10, 4: 10, 3: 44}, "10 levels start with 5 lives, 10 with 4 and 44 with 3")


func _test_band_boundaries() -> void:
	var boundaries := {1: 5, 10: 5, 11: 4, 20: 4, 21: 3, 63: 3, 64: 3}
	for level: int in boundaries:
		check_equal(CampaignRules.get_starting_lives(level), boundaries[level], "level %d starts with %d lives" % [level, boundaries[level]])


func _test_tutorial_and_last_level() -> void:
	var tutorials: Array[int] = []
	var last: Array[int] = []
	for level: int in range(-2, 70):
		if CampaignRules.is_tutorial(level):
			tutorials.append(level)
		if CampaignRules.is_last_level(level):
			last.append(level)
	check_equal(tutorials, [1] as Array[int], "only Level 1 is the tutorial")
	check_equal(last, [64] as Array[int], "only Level 64 is the last level")


func _test_invalid_level_numbers() -> void:
	for level: int in INVALID_LEVELS:
		check(not CampaignRules.is_valid_level(level), "%d is not a campaign level" % level)
		check_equal(CampaignRules.get_starting_lives(level), 0, "%d gets 0 starting lives" % level)
		check(not CampaignRules.is_tutorial(level) and not CampaignRules.is_last_level(level),
				"%d is neither the tutorial nor the last level" % level)


## Each band starts right after the previous one, gives at least one life, and
## the last band ends exactly at LEVEL_COUNT.
func _test_bands_cover_the_campaign() -> void:
	var problems: PackedStringArray = []
	var first := 1
	for band: Vector2i in CampaignRules.LIVES_BANDS:
		if band.x < first:
			problems.append("band ending at %d is empty or out of order" % band.x)
		if band.y < 1:
			problems.append("band ending at %d gives %d lives" % [band.x, band.y])
		first = band.x + 1
	check(problems.is_empty(), "lives bands are in order with at least one life each %s" % [problems])
	check_equal(first - 1, CampaignRules.LEVEL_COUNT, "the last lives band ends at Level %d" % CampaignRules.LEVEL_COUNT)


## The rules are about level numbers only; the development level list keeps
## Test Garden and is not the campaign.
func _test_independent_of_level_files() -> void:
	var source := FileAccess.get_file_as_string("res://gameplay/campaign_rules.gd")
	check(not source.contains("level_list") and not source.contains("res://data"), "campaign rules read no level files")
	var list := load("res://data/level_list.tres") as LevelList
	check(list != null and list.size() == 1 and list.get_level(0).display_name == "Test Garden",
			"the development level list is unchanged (Test Garden only)")
