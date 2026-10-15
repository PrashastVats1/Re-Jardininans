class_name CampaignRules
extends RefCounted
## Fixed rules of the campaign, by level number (1 to LEVEL_COUNT). They don't
## depend on which levels exist yet: Test Garden and the test fixtures are not
## campaign levels.
##
## Every function accepts any int. A number outside 1..LEVEL_COUNT is not a
## campaign level: it gets 0 starting lives and is neither the tutorial nor the
## last level, so callers must check is_valid_level() before using the result.

const LEVEL_COUNT: int = 64
const TUTORIAL_LEVEL: int = 1
## Starting lives by band, in level order: x is the band's last level, y its
## lives. The bands must cover 1..LEVEL_COUNT without gaps.
const LIVES_BANDS: Array[Vector2i] = [Vector2i(10, 5), Vector2i(20, 4), Vector2i(64, 3)]


static func is_valid_level(level_number: int) -> bool:
	return level_number >= 1 and level_number <= LEVEL_COUNT


static func is_tutorial(level_number: int) -> bool:
	return level_number == TUTORIAL_LEVEL


static func is_last_level(level_number: int) -> bool:
	return level_number == LEVEL_COUNT


## Lives a fresh attempt at [param level_number] starts with; 0 when it is not
## a campaign level.
static func get_starting_lives(level_number: int) -> int:
	if not is_valid_level(level_number):
		return 0
	for band: Vector2i in LIVES_BANDS:
		if level_number <= band.x:
			return band.y
	return 0
