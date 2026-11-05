# run_tests.gd
# Purpose: Headless test runner.
#   godot --headless --path . -s res://tests/run_tests.gd
#   Finds res://tests/test_*.gd, runs every test_* method, prints PASS/FAIL per test
#   and a summary, and exits with code 1 if anything failed (0 otherwise).
#   Autoloads from project.godot are added to the root before the first frame, so
#   tests can reach them via tree.root.get_node("EventBus") etc.
# Author: Mechanics Developer Agent
extends SceneTree

const TEST_DIR: String = "res://tests"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Let autoloads finish _ready() before any test touches them.
	await process_frame
	var passed: int = 0
	var failed: int = 0
	for path: String in _find_test_files():
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			print("FAIL %s (script did not load)" % path)
			failed += 1
			continue
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var test: RefCounted = script.new()
			test.set("tree", self)
			await test.call(method_name)
			var failures: Array = test.get("failures")
			var label: String = "%s::%s" % [path.get_file(), method_name]
			if int(test.get("assertions")) == 0:
				failures.append("no assertions ran (script error?)")
			if failures.is_empty():
				passed += 1
				print("PASS %s" % label)
			else:
				failed += 1
				print("FAIL %s" % label)
				for f: Variant in failures:
					print("     - %s" % f)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 or passed == 0 else 0)


func _find_test_files() -> PackedStringArray:
	var result: PackedStringArray = []
	# Optional filter: godot ... -s res://tests/run_tests.gd -- --only=<substring>
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for file: String in DirAccess.get_files_at(TEST_DIR):
		# Exported builds list .gd files as .gd.remap; tests only run from source.
		if file.begins_with("test_") and file.ends_with(".gd") and (only == "" or only in file):
			result.append(TEST_DIR.path_join(file))
	result.sort()
	return result
