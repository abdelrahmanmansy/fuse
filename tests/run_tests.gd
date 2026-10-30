extends SceneTree
## Headless test runner with zero external addons.
##
##   godot --headless --path . --script res://tests/run_tests.gd
##
## Discovers tests/test_*.gd (recursively), instantiates each file, and calls
## every method whose name starts with `test_`. Exit code 1 on any failure.

const TEST_ROOT := "res://tests"


func _initialize() -> void:
	var files := _collect_test_files(TEST_ROOT)
	files.sort()

	var test_count := 0
	var assertion_count := 0
	var all_failures: Array[String] = []
	var started_at := Time.get_ticks_msec()

	for path in files:
		var script: Script = load(path)
		if script == null:
			all_failures.append("%s — could not be loaded" % path)
			continue

		var instance: Object = script.new()
		var methods := _test_methods(script)
		if methods.is_empty():
			all_failures.append("%s — no test_* methods found" % path)
			continue

		for method in methods:
			test_count += 1
			var first_assertion: int = instance.assertions
			var first_failure: int = instance.failures.size()
			instance.call(method)
			assertion_count += instance.assertions - first_assertion
			for i in range(first_failure, instance.failures.size()):
				all_failures.append("%s::%s — %s" % [path.get_file(), method, instance.failures[i]])

	var elapsed_ms := Time.get_ticks_msec() - started_at
	print("")
	for failure in all_failures:
		printerr("FAIL  " + failure)
	print("%d test(s), %d assertion(s), %d failure(s) in %d ms" % [
		test_count, assertion_count, all_failures.size(), elapsed_ms,
	])
	if all_failures.is_empty():
		print("PASS")
	quit(0 if all_failures.is_empty() else 1)


func _test_methods(script: Script) -> Array[String]:
	var names: Array[String] = []
	for method in script.get_script_method_list():
		var method_name: String = method.name
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	names.sort()
	return names


func _collect_test_files(directory: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("Cannot open test directory: %s" % directory)
		return found

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full_path := directory.path_join(entry)
		if dir.current_is_dir():
			found.append_array(_collect_test_files(full_path))
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			found.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
