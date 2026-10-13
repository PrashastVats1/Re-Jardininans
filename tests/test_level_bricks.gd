extends "res://tests/test_case.gd"
## Regression tests for the "no bricks visible" bug, for every level under
## data/levels: each must keep its rows on disk, spawn exactly the bricks its
## data describes inside the playfield, and (when a window is available)
## actually render them. Also checks each level fits and is reachable in the
## running game.

const LevelFacts := preload("res://tests/level_facts.gd")
const MAIN_SCENE: PackedScene = preload("res://main.tscn")


func run() -> void:
	_test_no_untyped_literal_defaults_on_typed_array_exports()
	var paths := LevelFacts.level_paths()
	check(paths.size() >= 2, "Test Garden and at least one fixture are checked (%s)" % [paths])
	for path: String in paths:
		var label := path.get_file()
		_test_level_file_keeps_rows(path, label)
		var level := load(path) as LevelData
		check(level != null, "%s loads as LevelData" % label)
		if level == null:
			continue
		await _test_spawned_bricks(level, label)
		await _test_level_fits_arena_and_is_reachable(level, label)


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


func _test_level_file_keeps_rows(path: String, label: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	check(text.contains("rows = PackedStringArray(\""), "%s stores its brick rows on disk" % label)


func _test_spawned_bricks(level: LevelData, label: String) -> void:
	var game := await _start_game(level)
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

	check(game.level == level, "[%s] the game loaded the requested level" % label)
	check_equal(bricks.size(), LevelFacts.brick_count(level), "[%s] spawns one Brick node per brick cell" % label)
	check_equal(game.session.bricks_remaining, LevelFacts.destructible_count(level), "[%s] session counts the destructible bricks" % label)
	check(all_typed, "[%s] every brick has a BrickType" % label)
	check_equal(counts, LevelFacts.type_counts(level), "[%s] brick types match the level legend" % label)
	check(all_inside, "[%s] every brick lies fully inside the playfield below the ceiling" % label)
	check(all_visible, "[%s] every brick is visible, opaque and unscaled" % label)
	check_equal(positions.size(), bricks.size(), "[%s] no two bricks share a position" % label)
	check(Brick.SIZE.x > 0.0 and Brick.SIZE.y > 0.0, "brick visual size is non-zero")
	check(bricks_parent.is_visible_in_tree(), "[%s] Bricks container is visible" % label)
	check(background.get_index() < game.get_node("Playfield").get_index() and bricks_parent.z_index >= background.z_index,
			"[%s] bricks draw above the background" % label)

	if DisplayServer.get_name() == "headless":
		print("      (skipped pixel check for %s: headless display)" % label)
	elif not bricks.is_empty():
		var empty_cell := _first_empty_cell(level)
		var empty_point := Vector2.INF
		if empty_cell != Vector2i(-1, -1):
			empty_point = (game.get_node("Playfield") as Node2D).global_transform \
					* LevelGrid.get_cell_center(empty_cell.x, empty_cell.y, level.get_column_count())
		await _check_rendered_pixels(bricks, empty_point, label)

	game.get_parent().queue_free()
	await tree.process_frame


## Samples the rendered frame inside each brick's flat fill (clear of the top
## highlight and the outline), so a brick that exists but isn't drawn fails,
## and at the centre of an empty grid cell (if any), which must stay black.
func _check_rendered_pixels(bricks: Array[Brick], empty_point: Vector2, label: String) -> void:
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
	check(sampled == bricks.size(), "[%s] every brick center is on screen (%d/%d)" % [label, sampled, bricks.size()])
	check(matched == sampled and sampled > 0, "[%s] rendered pixels match brick colors at %d/%d bricks" % [label, matched, sampled])

	if empty_point != Vector2.INF:
		var empty := Vector2i((to_screen * empty_point).round())
		check(_colors_close(image.get_pixelv(empty), Color.BLACK, 0.03), "[%s] an empty grid cell renders black, not brick-colored" % label)


## Top-most, then left-most empty cell, or (-1, -1) when every cell holds a brick.
func _first_empty_cell(level: LevelData) -> Vector2i:
	for row: int in level.rows.size():
		for column: int in level.get_column_count():
			if level.get_brick_type(level.rows[row][column]) == null:
				return Vector2i(column, row)
	return Vector2i(-1, -1)


## The level in the running game must pass validation with the live ball and
## paddle (ball-sized gaps beside the grid, clearance above the paddle), and
## every destructible brick must be reachable: peeling bricks from the open
## sides (stones never break) has to expose all of them. Reachability is a
## grid-only check; actual clearing is shown by the scripted-autoplay test.
func _test_level_fits_arena_and_is_reachable(level: LevelData, label: String) -> void:
	var game := await _start_game(level)
	var playfield := game.get_node("Playfield") as Playfield
	var ball_diameter := (game.get_node("Playfield/Ball") as Ball).radius * 2.0
	var paddle_height := (game.get_node("Playfield/Paddle") as Paddle).size.y
	var side_gap := LevelGrid.get_side_gap(level.get_column_count())
	var top_gap := LevelGrid.GRID_TOP - playfield.ceiling_y

	check_equal(LevelValidator.validate(level, ball_diameter, Playfield.get_size(), paddle_height), PackedStringArray(),
			"[%s] passes structural and grid-fit validation with the live ball and paddle" % label)
	check(game.has_playable_level(), "[%s] game accepted the level" % label)
	check(top_gap >= ball_diameter, "[%s] ball fits between the ceiling and the top row (%.0f px)" % [label, top_gap])
	var unreachable := LevelReachability.find_unreachable(level, side_gap >= ball_diameter, top_gap >= ball_diameter)
	check(unreachable.is_empty(), "[%s] every destructible brick can be reached (unreachable cells: %s)" % [label, unreachable])

	game.get_parent().queue_free()
	await tree.process_frame


func _start_game(level: LevelData) -> Game:
	var main := MAIN_SCENE.instantiate()
	var game := main.get_node("Game") as Game
	game.level = level
	tree.root.add_child(main)
	await tree.physics_frame
	return game


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
