extends "res://tests/test_case.gd"
## The brick types in data/bricks are shared by every level: levels must
## reference them rather than define their own, and the library itself must be
## consistent and readable on the black arena.

const BRICKS_DIR: String = "res://data/bricks"
const LEVELS_DIR: String = "res://data/levels"
## The values the test level was tuned with; changing them changes gameplay.
const EXPECTED_TYPES: Dictionary = {
	"blue_bloom.tres": ["Blue bloom", Color(0.36, 0.6, 0.95, 1), 1, 50, true],
	"clay_pot.tres": ["Clay pot", Color(0.82, 0.45, 0.27, 1), 2, 120, true],
	"garden_stone.tres": ["Garden stone", Color(0.56, 0.58, 0.6, 1), 1, 0, false],
	"red_bloom.tres": ["Red bloom", Color(0.93, 0.33, 0.4, 1), 1, 50, true],
	"yellow_bloom.tres": ["Yellow bloom", Color(0.98, 0.78, 0.25, 1), 1, 50, true],
}


func run() -> void:
	var library := _load_library()
	_test_library_values(library)
	_test_library_is_consistent(library)
	_test_colors_read_on_black(library)
	_test_levels_reference_library()


func _load_library() -> Dictionary:
	var library: Dictionary = {}
	for file: String in DirAccess.get_files_at(BRICKS_DIR):
		if file.get_extension() == "tres":
			library[file] = load(BRICKS_DIR.path_join(file))
	return library


func _test_library_values(library: Dictionary) -> void:
	check_equal(library.keys().size(), EXPECTED_TYPES.size(), "library holds the five original brick types")
	for file: String in EXPECTED_TYPES:
		var brick_type := library.get(file) as BrickType
		if brick_type == null:
			check(false, "%s loads as a BrickType" % file)
			continue
		var expected: Array = EXPECTED_TYPES[file]
		check_equal([brick_type.display_name, brick_type.color, brick_type.hit_points, brick_type.points, brick_type.destructible],
				expected, "%s keeps its name, colour, hit points, points and destructibility" % file)


func _test_library_is_consistent(library: Dictionary) -> void:
	var problems: PackedStringArray = []
	var names: Dictionary = {}
	for file: String in library:
		var brick_type := library[file] as BrickType
		if brick_type == null:
			problems.append("%s is not a BrickType" % file)
			continue
		if brick_type.display_name.is_empty():
			problems.append("%s has no display name" % file)
		elif names.has(brick_type.display_name):
			problems.append("%s and %s share the name '%s'" % [names[brick_type.display_name], file, brick_type.display_name])
		names[brick_type.display_name] = file
		if brick_type.hit_points < 1:
			problems.append("%s has %d hit points" % [file, brick_type.hit_points])
		if brick_type.points < 0:
			problems.append("%s awards negative points" % file)
	check(problems.is_empty(), "brick library is consistent %s" % [problems])


## Bricks are plain coloured blocks on a black arena, so their colour is what
## tells them apart: every type must contrast strongly with black (WCAG ratio
## >= 4.5) and differ clearly from the other types.
func _test_colors_read_on_black(library: Dictionary) -> void:
	var types: Array[BrickType] = []
	for file: String in library:
		if library[file] is BrickType:
			types.append(library[file])
	var low_contrast: PackedStringArray = []
	var look_alike: PackedStringArray = []
	for i: int in types.size():
		var ratio := (_luminance(types[i].color) + 0.05) / 0.05
		if ratio < 4.5:
			low_contrast.append("%s %.1f:1" % [types[i].display_name, ratio])
		for j: int in range(i + 1, types.size()):
			var a := types[i].color
			var b := types[j].color
			if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.15:
				look_alike.append("%s/%s" % [types[i].display_name, types[j].display_name])
	check(low_contrast.is_empty(), "every brick colour contrasts with the black arena %s" % [low_contrast])
	check(look_alike.is_empty(), "no two brick types share a look-alike colour %s" % [look_alike])


## A brick type defined inside a level file would be a private copy that can
## drift from the library, so every legend entry must be a library resource.
func _test_levels_reference_library() -> void:
	var level_count := 0
	for file: String in DirAccess.get_files_at(LEVELS_DIR):
		if file.get_extension() != "tres":
			continue
		var path := LEVELS_DIR.path_join(file)
		var level := load(path) as LevelData
		if level == null:
			continue
		level_count += 1
		check(not FileAccess.get_file_as_string(path).contains("[sub_resource"), "%s defines no brick types of its own" % file)
		var private: PackedStringArray = []
		for symbol: String in level.legend:
			var brick_type := level.get_brick_type(symbol)
			var type_path := brick_type.resource_path if brick_type != null else ""
			if type_path.get_base_dir() != BRICKS_DIR or type_path.contains("::") or load(type_path) != brick_type:
				private.append("'%s' -> %s" % [symbol, type_path])
		check(private.is_empty(), "%s uses only shared brick types from %s %s" % [file, BRICKS_DIR, private])
	check(level_count > 0, "at least one level was checked")


func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b
