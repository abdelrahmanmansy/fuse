extends RefCounted
## Base class for headless tests. Intentionally tiny and dependency-free:
## the runner discovers `test_*` methods and reports their failures.

var failures: Array[String] = []
var assertions: int = 0


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func eq(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s — expected %s, got %s" % [message, str(expected), str(actual)])


func near(actual: float, expected: float, epsilon: float, message: String) -> void:
	assertions += 1
	if absf(actual - expected) > epsilon:
		failures.append("%s — expected %f ± %f, got %f" % [message, expected, epsilon, actual])
