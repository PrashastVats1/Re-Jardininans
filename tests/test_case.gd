extends RefCounted
## Minimal base for plugin-free tests run by tests/run_tests.gd.

var tree: SceneTree
var checks: int = 0
var failures: PackedStringArray = []


## Override in test scripts. May use await.
func run() -> void:
	await tree.process_frame


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func check_equal(actual: Variant, expected: Variant, message: String) -> void:
	check(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])


func check_approx(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	check(absf(actual - expected) <= tolerance, "%s (expected %f, got %f)" % [message, expected, actual])
