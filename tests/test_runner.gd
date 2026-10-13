extends "res://tests/test_case.gd"
## The runner reports broken test scripts instead of waiting forever: one that
## fails to parse, and one that never finishes (awaits a signal that is never
## emitted). Runs the
## real runner in a separate headless Godot process on fixture scripts written
## to user://, and kills it if it does not exit in time.

const BROKEN_FIXTURE: String = "user://runner_fixture_broken.gd"
const STUCK_FIXTURE: String = "user://runner_fixture_stuck.gd"
const CHILD_DEADLINE_MSEC: int = 60000


func run() -> void:
	_write(BROKEN_FIXTURE, "extends \"res://tests/test_case.gd\"\nfunc run() -> void\n\tthis is not GDScript\n")
	_write(STUCK_FIXTURE, "\n".join([
		"extends \"res://tests/test_case.gd\"",
		"signal never_emitted",
		"func run() -> void:",
		"\tawait never_emitted",
		"\tcheck(true, \"never reached\")",
		""]))

	var pipe := OS.execute_with_pipe(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--fixed-fps", "60",
		"--script", "res://tests/run_tests.gd", "--",
		"--tests=%s,%s,res://tests/test_frame_rate.gd" % [BROKEN_FIXTURE, STUCK_FIXTURE], "--timeout=5"])
	check(not pipe.is_empty(), "runner subprocess started")
	if pipe.is_empty():
		return
	var pid: int = pipe["pid"]
	var deadline := Time.get_ticks_msec() + CHILD_DEADLINE_MSEC
	while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	var exited := not OS.is_process_running(pid)
	if not exited:
		OS.kill(pid)
	check(exited, "runner exits instead of hanging on broken scripts")
	var output := (pipe["stdio"] as FileAccess).get_as_text() if exited else ""
	check_equal(OS.get_process_exit_code(pid) if exited else -1, 1, "runner exits with code 1")
	check(output.contains("FAIL  runner_fixture_broken.gd: could not load script"), "a script that fails to parse is reported")
	check(output.contains("FAIL  runner_fixture_stuck.gd: did not finish within 5 s"), "a script that never finishes is reported")
	check(output.contains("PASS  test_frame_rate.gd"), "scripts after the broken ones still run")
	check(output.contains("5 checks, 2 failures"), "summary counts both broken scripts as failures")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BROKEN_FIXTURE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STUCK_FIXTURE))


func _write(path: String, source: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()
