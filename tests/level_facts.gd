extends RefCounted
## Expected values for any level, worked out from its rows and brick types
## alone, so generic tests don't depend on one level's numbers. Deliberately
## independent of Game and LevelData's own counting.

const LEVELS_DIR: String = "res://data/levels"


## Every level resource under data/levels, sorted by path.
static func level_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	for file: String in DirAccess.get_files_at(LEVELS_DIR):
		if file.get_extension() == "tres":
			paths.append(LEVELS_DIR.path_join(file))
	paths.sort()
	return paths


static func brick_types(level: LevelData) -> Array[BrickType]:
	var types: Array[BrickType] = []
	for row: String in level.rows:
		for column: int in row.length():
			var symbol := row[column]
			if symbol != "." and symbol != " " and level.legend.get(symbol) is BrickType:
				types.append(level.legend[symbol])
	return types


static func brick_count(level: LevelData) -> int:
	return brick_types(level).size()


static func destructible_count(level: LevelData) -> int:
	return brick_types(level).filter(func(brick_type: BrickType) -> bool: return brick_type.destructible).size()


## Brick counts keyed by brick type display name.
static func type_counts(level: LevelData) -> Dictionary:
	var counts: Dictionary = {}
	for brick_type: BrickType in brick_types(level):
		counts[brick_type.display_name] = int(counts.get(brick_type.display_name, 0)) + 1
	return counts


## Score for breaking every destructible brick once.
static func full_clear_score(level: LevelData) -> int:
	var score := 0
	for brick_type: BrickType in brick_types(level):
		if brick_type.destructible:
			score += brick_type.points
	return score
