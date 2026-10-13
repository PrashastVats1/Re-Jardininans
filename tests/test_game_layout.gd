extends "res://tests/test_case.gd"
## GameLayout maths for common window shapes, cross-checked against the engine's
## own canvas_items + expand scaling in the running game, plus the minimum
## window size.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
## [window size, visible logical size, design canvas offset]
const CASES: Array = [
	[Vector2i(1280, 720), Vector2(1280.0, 720.0), Vector2(0.0, 0.0)],
	[Vector2i(1920, 1080), Vector2(1280.0, 720.0), Vector2(0.0, 0.0)],
	[Vector2i(2560, 1080), Vector2(1706.0, 720.0), Vector2(213.0, 0.0)],
	[Vector2i(1024, 768), Vector2(1280.0, 960.0), Vector2(0.0, 120.0)],
	[Vector2i(1280, 800), Vector2(1280.0, 800.0), Vector2(0.0, 40.0)],
	[Vector2i(960, 540), Vector2(1280.0, 720.0), Vector2(0.0, 0.0)],
]


func run() -> void:
	_test_pure_layout()
	await _test_running_game_layout()


func _test_pure_layout() -> void:
	var design := GameLayout.get_design_size()
	for case: Array in CASES:
		var window_size: Vector2i = case[0]
		var label := "[%dx%d]" % [window_size.x, window_size.y]
		var visible := GameLayout.get_visible_size(Vector2(window_size))
		check_equal(visible, case[1], "%s visible logical size" % label)
		var offset := GameLayout.get_offset(visible)
		check_equal(offset, case[2], "%s design canvas offset" % label)
		check(Rect2(Vector2.ZERO, visible).encloses(Rect2(offset, design)), "%s design canvas fits inside the visible area" % label)
	check_equal(GameLayout.get_offset(Vector2(1000.0, 600.0)), Vector2.ZERO, "offset never goes negative")


func _test_running_game_layout() -> void:
	var original_size := tree.root.size
	var main := MAIN_SCENE.instantiate()
	tree.root.add_child(main)
	var game := main.get_node("Game") as Game
	var hud := game.get_node("Hud") as CanvasLayer
	await tree.process_frame

	check_equal(tree.root.min_size, GameLayout.MIN_WINDOW_SIZE, "game sets the 960x540 minimum window size")
	for case: Array in CASES:
		var window_size: Vector2i = case[0]
		var label := "[%dx%d running]" % [window_size.x, window_size.y]
		tree.root.size = window_size
		await tree.process_frame
		check_equal(tree.root.size, window_size, "%s window took the requested size" % label)
		check_equal(tree.root.get_visible_rect().size, case[1], "%s engine visible size matches GameLayout" % label)
		check_equal(tree.root.get_canvas_transform().origin, case[2], "%s world canvas is offset" % label)
		check_equal(hud.offset, case[2], "%s HUD layer has the same offset" % label)

	tree.root.size = Vector2i(700, 400)
	await tree.process_frame
	check_equal(tree.root.size, GameLayout.MIN_WINDOW_SIZE, "[700x400] window is clamped to the minimum")
	check_equal(tree.root.get_visible_rect().size, GameLayout.get_design_size(), "[700x400] clamped window shows exactly the design canvas")
	check_equal(tree.root.get_canvas_transform().origin, Vector2.ZERO, "[700x400] no offset at the minimum size")

	tree.root.size = original_size
	main.queue_free()
	await tree.process_frame
