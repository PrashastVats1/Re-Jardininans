extends "res://tests/test_case.gd"
## Regression tests for the "no bricks visible" bug: the level must keep its
## rows on disk, spawn the expected bricks inside the playfield, and (when a
## window is available) actually render them.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const TEST_LEVEL_PATH: String = "res://data/levels/test_level.tres"
const EXPECTED_COUNTS: Dictionary = {
	"Clay pot": 7,
	"Red bloom": 11,
	"Yellow bloom": 11,
	"Blue bloom": 11,
	"Garden stone": 2,
}


func run() -> void:
	_test_no_untyped_literal_defaults_on_typed_array_exports()
	_test_level_file_keeps_rows()
	await _test_spawned_bricks()
	await _test_level_fits_arena_and_is_reachable()


## The editor builds non-tool resources from export defaults; a bare [] default
## on a PackedStringArray export makes it discard the saved rows on re-save.
func _test_no_untyped_literal_defaults_on_typed_array_exports() -> void:
	var pattern := RegEx.create_from_string("@export[^\\n]*:\\s*(Packed\\w+Array|Array\\[[^\\]]+\\])\\s*=\\s*\\[")
	var offenders: PackedStringArray = []
	for path: String in _gd_files("res://"):
		var source := FileAccess.get_file_as_string(path)
		for line: String in source.split("\n"):
			if pattern.search(line) != null:
				offenders.append("%s: %s" % [path, line.strip_edges()])
	check(offenders.is_empty(), "typed array exports use typed initializers, found: %s" % [offenders])


func _test_level_file_keeps_rows() -> void:
	var text := FileAccess.get_file_as_string(TEST_LEVEL_PATH)
	check(text.contains("rows = PackedStringArray(\""), "test_level.tres stores its brick rows on disk")


func _test_spawned_bricks() -> void:
	var main := MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	var game := main.get_node("Game") as Game
	var bricks_parent := game.get_node("Playfield/Bricks") as Node2D
	var background := game.get_node("Background") as Node2D

	var counts: Dictionary = {}
	var positions: Dictionary = {}
	var all_inside := true
	var all_visible := true
	var all_typed := true
	var bricks: Array[Brick] = []
	for child: Node in bricks_parent.get_children():
		var brick := child as Brick
		if brick == null:
			continue
		bricks.append(brick)
		all_typed = all_typed and brick.brick_type != null
		if brick.brick_type != null:
			counts[brick.brick_type.display_name] = int(counts.get(brick.brick_type.display_name, 0)) + 1
		var rect := Rect2(brick.global_position - Brick.SIZE * 0.5, Brick.SIZE)
		all_inside = all_inside and _brick_area((game.get_node("Playfield") as Playfield).ceiling_y).encloses(rect)
		all_visible = all_visible and brick.is_visible_in_tree() and brick.modulate.a > 0.99 \
				and brick.scale.is_equal_approx(Vector2.ONE)
		positions[brick.global_position.round()] = true

	check_equal(bricks.size(), 42, "test level spawns 42 Brick nodes under Playfield/Bricks")
	check(all_typed, "every brick has a BrickType")
	check_equal(counts, EXPECTED_COUNTS, "brick types match the level legend")
	check(all_inside, "every brick lies fully inside the playfield below the HUD bar")
	check(all_visible, "every brick is visible, opaque and unscaled")
	check_equal(positions.size(), bricks.size(), "no two bricks share a position")
	check(Brick.SIZE.x > 0.0 and Brick.SIZE.y > 0.0, "brick visual size is non-zero")
	check(bricks_parent.is_visible_in_tree(), "Bricks container is visible")
	check(background.get_index() < game.get_node("Playfield").get_index() and bricks_parent.z_index >= background.z_index,
			"bricks draw above the background")

	if DisplayServer.get_name() == "headless":
		print("      (skipped pixel check: headless display)")
	elif not bricks.is_empty():
		await _check_rendered_pixels(bricks)

	main.queue_free()
	await tree.process_frame


## Samples the rendered frame inside each brick's flat fill (clear of the top
## highlight and the outline) and at an empty arena spot, so a brick that
## exists but isn't drawn fails.
func _check_rendered_pixels(bricks: Array[Brick]) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var viewport := tree.root.get_viewport()
	var image := viewport.get_texture().get_image()
	# The captured image covers the whole visible area (expand aspect, no bars),
	# scaled to whatever size the window manager gave the window.
	var scale := Vector2(image.get_size()) / viewport.get_visible_rect().size
	var to_screen := Transform2D(0.0, scale, 0.0, Vector2.ZERO) * viewport.get_canvas_transform()
	var matched := 0
	var sampled := 0
	for brick: Brick in bricks:
		var point := to_screen * (brick.global_position + Vector2(-26.0, 7.0))
		var pixel := Vector2i(point.round())
		if not Rect2i(Vector2i.ZERO, image.get_size()).has_point(pixel):
			continue
		sampled += 1
		if _colors_close(image.get_pixelv(pixel), brick.brick_type.color, 0.08):
			matched += 1
	check(sampled == bricks.size(), "every brick center is on screen (%d/%d)" % [sampled, bricks.size()])
	check(matched == sampled and sampled > 0, "rendered pixels match brick colors at %d/%d bricks" % [matched, sampled])

	var empty := Vector2i((to_screen * Vector2(Playfield.get_size().x * 0.5, 320.0)).round())
	check(_colors_close(image.get_pixelv(empty), Color.BLACK, 0.03), "empty arena below the bricks is black, not brick-colored")


## The level in the running game must pass validation with the live ball and
## paddle (ball-sized gaps beside the grid, clearance above the paddle), and
## every destructible brick must be reachable: peeling bricks from the open
## sides (stones never break) has to expose all of them.
func _test_level_fits_arena_and_is_reachable() -> void:
	var main := MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	var game := main.get_node("Game") as Game
	var level := game.level
	var playfield := game.get_node("Playfield") as Playfield
	var ball_diameter := (game.get_node("Playfield/Ball") as Ball).radius * 2.0
	var paddle_height := (game.get_node("Playfield/Paddle") as Paddle).size.y
	var columns := level.get_column_count()
	var side_gap := LevelGrid.get_side_gap(columns)
	var top_gap := LevelGrid.GRID_TOP - playfield.ceiling_y

	check_equal(columns, 11, "test level is 11 columns wide")
	check_equal(LevelValidator.validate(level, ball_diameter, Playfield.get_size(), paddle_height), PackedStringArray(),
			"test level passes structural and grid-fit validation with the live ball and paddle")
	check(game.has_playable_level(), "game accepted the test level")
	check(top_gap >= ball_diameter, "ball fits between the ceiling and the top row (%.0f px)" % top_gap)
	var unreachable := LevelReachability.find_unreachable(level, side_gap >= ball_diameter, top_gap >= ball_diameter)
	check(unreachable.is_empty(), "every destructible brick can be reached (unreachable cells: %s)" % [unreachable])

	main.queue_free()
	await tree.process_frame


## The playfield below the ceiling.
func _brick_area(ceiling_y: float) -> Rect2:
	var size := Playfield.get_size()
	return Rect2(0.0, ceiling_y, size.x, size.y - ceiling_y)


func _colors_close(a: Color, b: Color, tolerance: float) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


func _gd_files(dir_path: String) -> PackedStringArray:
	var files: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir_path):
		if file.get_extension() == "gd":
			files.append(dir_path.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir_path):
		if not sub.begins_with("."):
			files.append_array(_gd_files(dir_path.path_join(sub)))
	return files
