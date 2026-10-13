extends "res://tests/test_case.gd"
## The design canvas has one source (the project's base viewport size), the
## arena size has one source (Playfield.get_size()), and the walls, paddle,
## ball, bricks, background and HUD are all derived from them.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const SCANNED_DIRS: PackedStringArray = ["res://gameplay", "res://entities", "res://ui", "res://data"]


func run() -> void:
	_test_single_source_of_truth()
	_test_no_hard_coded_playfield_numbers()
	await _test_scene_uses_playfield_size()


func _test_single_source_of_truth() -> void:
	var design := GameLayout.get_design_size()
	check_equal(design, Vector2(1280.0, 720.0), "design canvas is 1280x720")
	check_equal(design, Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height")),
			"design canvas comes from the project's viewport size")
	check_approx(design.x / design.y, 16.0 / 9.0, "design canvas is 16:9")
	check_equal(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "canvas_items stretch")
	check_equal(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "expand aspect shows extra backdrop instead of bars")

	var size := Playfield.get_size()
	check_equal(size, Vector2(960.0, 720.0), "arena is 960x720")
	check_equal(size, design - Vector2(GameLayout.SIDEBAR_WIDTH, 0.0), "arena is the design canvas minus the sidebar")
	check_equal(GameLayout.SIDEBAR_WIDTH, 320.0, "sidebar column is 320 wide")
	check_equal(Playfield.get_rect(), Rect2(Vector2.ZERO, size), "arena rect starts at the origin")


func _test_no_hard_coded_playfield_numbers() -> void:
	var pattern := RegEx.create_from_string("\\b(1280|720)(\\.0)?\\b")
	var offenders: PackedStringArray = []
	for dir_path: String in SCANNED_DIRS:
		for path: String in _files(dir_path):
			if not path.get_extension() in ["gd", "tscn", "tres"]:
				continue
			var line_number := 0
			for line: String in FileAccess.get_file_as_string(path).split("\n"):
				line_number += 1
				if pattern.search(line) != null:
					offenders.append("%s:%d" % [path, line_number])
	check(offenders.is_empty(), "no hard-coded 1280/720 outside project.godot, found: %s" % [offenders])


func _test_scene_uses_playfield_size() -> void:
	var size := Playfield.get_size()
	var main := MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	var game := main.get_node("Game") as Game
	var playfield := game.get_node("Playfield") as Playfield

	var left := _wall_rect(game, "Left")
	var right := _wall_rect(game, "Right")
	var top := _wall_rect(game, "Top")
	check_approx(left.end.x, 0.0, "left wall's inner edge is the playfield's left edge")
	check_approx(right.position.x, size.x, "right wall's inner edge is the playfield's right edge")
	check_approx(top.end.y, playfield.ceiling_y, "ceiling wall sits under the HUD bar")
	check(left.position.y <= 0.0 and left.end.y >= size.y and right.position.y <= 0.0 and right.end.y >= size.y,
			"side walls cover the full playfield height")
	check(top.position.x <= 0.0 and top.end.x >= size.x, "ceiling covers the full playfield width")

	var paddle := game.get_node("Playfield/Paddle") as Paddle
	check_equal(paddle.position, Vector2(size.x * 0.5, size.y - game.paddle_bottom_offset), "paddle starts centered near the bottom")
	var ball := game.get_node("Playfield/Ball") as Ball
	check_approx(ball.lost_below_y, size.y + ball.lost_margin, "ball is lost just below the playfield")
	check_approx(ball.position.x, size.x * 0.5, "ball starts on the centered paddle")

	var min_x := INF
	var max_x := -INF
	for child: Node in game.get_node("Playfield/Bricks").get_children():
		var brick := child as Brick
		min_x = minf(min_x, brick.position.x - Brick.SIZE.x * 0.5)
		max_x = maxf(max_x, brick.position.x + Brick.SIZE.x * 0.5)
	check_approx((min_x + max_x) * 0.5, size.x * 0.5, "brick layout is centered in the playfield")
	check(min_x >= 0.0 and max_x <= size.x, "brick layout fits the playfield width")

	var background := game.get_node("Background")
	check(not "playfield_size" in background, "background has no separate playfield size")
	check_equal(background.get("color"), Color.BLACK, "arena background is solid black")
	check_approx(background.call("get_top"), playfield.ceiling_y, "black starts at the ceiling, leaving the strip above it to the frame")

	# HUD positions are in design-canvas units (the layer offset is applied separately).
	var controls := game.get_node("Hud/Frame/ControlsLabel") as Label
	var message := game.get_node("Hud/Frame/MessagePanel") as Control
	var pause_panel := game.get_node("Hud/Frame/PausePanel") as Control
	var sidebar := game.get_node("Hud/Sidebar") as Control
	var arena_rect := Playfield.get_rect()
	check_equal((game.get_node("Hud/Frame") as Control).get_rect(), arena_rect, "HUD frame covers exactly the arena")
	check_approx(controls.get_global_rect().get_center().x, size.x * 0.5, "controls hint is centered over the arena")
	check(controls.get_global_rect().end.y <= playfield.ceiling_y, "controls hint sits in the strip above the ceiling")
	check(controls.get_minimum_size().x <= controls.size.x + 0.01, "controls hint text fits its box")
	check_approx(message.get_global_rect().get_center().x, size.x * 0.5, "message panel is centered over the arena")
	check_approx(pause_panel.get_global_rect().get_center().x, size.x * 0.5, "pause panel is centered over the arena")
	check(arena_rect.encloses(controls.get_global_rect()) and arena_rect.encloses(message.get_global_rect())
			and arena_rect.encloses(pause_panel.get_global_rect()), "arena overlays stay over the arena, out of the sidebar column")
	check_equal(sidebar.get_global_rect(), Rect2(size.x, 0.0, GameLayout.SIDEBAR_WIDTH, size.y),
			"sidebar fills the column right of the arena")
	check_equal(sidebar.get_global_rect().end, GameLayout.get_design_size(), "sidebar ends at the design canvas's bottom-right corner")

	var catching_mouse: PackedStringArray = []
	for root: Node in [game.get_node("Hud"), game.get_node("Backdrop")]:
		for control: Control in _controls(root):
			if control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
				catching_mouse.append(str(root.get_path_to(control)))
	check(catching_mouse.is_empty(), "no HUD, sidebar or backdrop control intercepts the mouse %s" % [catching_mouse])

	if DisplayServer.get_name() != "headless":
		await _check_rendered_regions(size, playfield.ceiling_y, (game.get_node("Backdrop/Fill") as ColorRect).color)

	main.queue_free()
	await tree.process_frame


## Empty arena spots render pure black; the strip above the ceiling and an
## empty spot in the sidebar render the plain frame colour.
func _check_rendered_regions(size: Vector2, ceiling_y: float, frame_color: Color) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var viewport := tree.root.get_viewport()
	var image := viewport.get_texture().get_image()
	var scale := Vector2(image.get_size()) / viewport.get_visible_rect().size
	var to_screen := Transform2D(0.0, scale, 0.0, Vector2.ZERO) * viewport.get_canvas_transform()
	var expectations: Dictionary = {
		Vector2(4.0, size.y - 4.0): Color.BLACK,
		Vector2(size.x - 4.0, size.y - 4.0): Color.BLACK,
		Vector2(20.0, ceiling_y + 4.0): Color.BLACK,
		Vector2(size.x * 0.5, 320.0): Color.BLACK,
		Vector2(8.0, ceiling_y * 0.5): frame_color,
		Vector2(size.x + GameLayout.SIDEBAR_WIDTH - 8.0, size.y - 8.0): frame_color,
	}
	for point: Vector2 in expectations:
		var color := image.get_pixelv(Vector2i((to_screen * point).floor()))
		var expected: Color = expectations[point]
		check(absf(color.r - expected.r) < 0.03 and absf(color.g - expected.g) < 0.03 and absf(color.b - expected.b) < 0.03,
				"rendered %s is %s (got %s)" % [point, "black" if expected == Color.BLACK else "the frame colour", color])


func _wall_rect(game: Game, wall_name: String) -> Rect2:
	var wall := game.get_node("Playfield/Walls/" + wall_name) as CollisionShape2D
	var shape_size := (wall.shape as RectangleShape2D).size
	return Rect2(wall.global_position - shape_size * 0.5, shape_size)


func _files(dir_path: String) -> PackedStringArray:
	var files: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir_path):
		files.append(dir_path.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir_path):
		files.append_array(_files(dir_path.path_join(sub)))
	return files


func _controls(node: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in node.get_children():
		if child is Control:
			found.append(child as Control)
		found.append_array(_controls(child))
	return found
