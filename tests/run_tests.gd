extends SceneTree
## Plugin-free test runner. From the project folder:
##   godot --headless --path . --fixed-fps 60 --script res://tests/run_tests.gd
## Exits with code 0 when every check passes, 1 otherwise. Optional user args
## after "--": --tests=<path,path,...> runs only those scripts, and
## --timeout=<seconds> changes the per-script time limit.

const TestCase := preload("res://tests/test_case.gd")
const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_bounce_math.gd",
	"res://tests/test_game_session.gd",
	"res://tests/test_level_data.gd",
	"res://tests/test_brick_library.gd",
	"res://tests/test_level_grid.gd",
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
	"res://tests/test_sidebar.gd",
	"res://tests/test_messages.gd",
	"res://tests/test_runner.gd",
]
## Real seconds a script may take, so a test that never finishes (e.g. awaits a
## signal that never comes) is reported instead of stalling the whole run.
const DEFAULT_TIMEOUT_SEC: float = 120.0


func _initialize() -> void:
	_run_all.call_deferred()


func _run_all() -> void:
	var paths: Array[String] = TEST_SCRIPTS.duplicate()
	var timeout_sec := DEFAULT_TIMEOUT_SEC
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tests="):
			paths.assign(arg.trim_prefix("--tests=").split(",", false))
		elif arg.begins_with("--timeout="):
			timeout_sec = arg.trim_prefix("--timeout=").to_float()

	var total_checks := 0
	var total_failures := 0
	for path: String in paths:
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL  %s: could not load script" % path.get_file())
			total_failures += 1
			continue
		var test: TestCase = script.new()
		test.tree = self
		var finished := await _run_with_timeout(test, timeout_sec)
		total_checks += test.checks
		total_failures += test.failures.size()
		if not finished:
			total_failures += 1
			print("FAIL  %s: did not finish within %.0f s (still waiting; likely hung)" % [path.get_file(), timeout_sec])
		else:
			print("%s  %s (%d checks)" % ["PASS" if test.failures.is_empty() else "FAIL", path.get_file(), test.checks])
		for failure: String in test.failures:
			print("      - " + failure)
	print("\n%d checks, %d failures" % [total_checks, total_failures])
	quit(1 if total_failures > 0 else 0)


func _run_with_timeout(test: TestCase, timeout_sec: float) -> bool:
	var finished := [false]
	var run_test := func() -> void:
		await test.run()
		finished[0] = true
	run_test.call()
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while not finished[0] and Time.get_ticks_msec() < deadline:
		await process_frame
	return finished[0]
