extends "res://tests/test_case.gd"
## The game caps rendering at 60 FPS for even frame pacing, while physics keeps
## its own 60 Hz tick with interpolation smoothing what is drawn in between.


func run() -> void:
	check_equal(ProjectSettings.get_setting("application/run/max_fps"), 60, "project caps the frame rate at 60 FPS")
	check_equal(Engine.max_fps, 60, "the 60 FPS cap is applied to the running engine")
	check_equal(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"), 60, "physics ticks at 60 Hz")
	check(ProjectSettings.get_setting("physics/common/physics_interpolation"), "physics interpolation stays enabled")
	check(tree.physics_interpolation, "physics interpolation is active in the running scene tree")
