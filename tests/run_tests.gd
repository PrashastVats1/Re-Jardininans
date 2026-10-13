extends SceneTree
## Plugin-free test runner. From the project folder:
##   godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
## Exits with code 0 when every check passes, 1 otherwise.

const TestCase := preload("res://tests/test_case.gd")
const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_bounce_math.gd",
	"res://tests/test_game_session.gd",
	"res://tests/test_level_data.gd",
	"res://tests/test_level_bricks.gd",
	"res://tests/test_ball_collisions.gd",
	"res://tests/test_game_scene.gd",
	"res://tests/test_gameplay_autoplay.gd",
	"res://tests/test_restart.gd",
	"res://tests/test_paddle_input.gd",
	"res://tests/test_playfield_dimensions.gd",
	"res://tests/test_game_layout.gd",
	"res://tests/test_responsive_layout.gd",
	"res://tests/test_frame_rate.gd",
]


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	var total_checks := 0
	var total_failures := 0
	for path: String in TEST_SCRIPTS:
		var script := load(path) as GDScript
		if script == null:
			print("FAIL  %s: could not load script" % path)
			total_failures += 1
			continue
		var test: TestCase = script.new()
		test.tree = self
		await test.run()
		total_checks += test.checks
		total_failures += test.failures.size()
		print("%s  %s (%d checks)" % ["PASS" if test.failures.is_empty() else "FAIL", path.get_file(), test.checks])
		for failure: String in test.failures:
			print("      - " + failure)
	print("\n%d checks, %d failures" % [total_checks, total_failures])
	quit(1 if total_failures > 0 else 0)
