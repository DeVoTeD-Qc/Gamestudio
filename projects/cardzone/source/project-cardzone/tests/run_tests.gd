# run_tests.gd
# Adapted from CallingCard tests/run_tests.gd (unchanged logic; originally from Killstreak).
# Purpose: Headless test runner.
#   godot --headless --path . -s res://tests/run_tests.gd
#   Finds res://tests/test_*.gd, runs every test_* method, prints PASS/FAIL per test
#   and a summary, and exits with code 1 if anything failed or nothing ran (0 otherwise).
#   Autoloads from project.godot are added to the root before the first frame, so
#   tests can reach them via tree.root.get_node("EventBus") etc.
#   Filter by file name: -- --only=<substring>  (e.g. -- --only=smoke)
#   Another folder of test_*.gd files: -- --dir=res://tests/fixtures/runner (test_runner.gd uses it)
#   Script errors (cz19b BUG-07): GDScript returns from a method on a runtime error and the caller
#   carries on, so "no assertions ran" alone let a test that errored AFTER its first assertion pass.
#   Godot 4.4 has no in-script error hook (OS.add_logger is 4.5+), so the runner starts itself
#   again as a child Godot with a private --log-file (the shared user://logs/godot.log is copied
#   and truncated by every Godot that starts, so it can't be trusted while other runs go on). The
#   child prints straight to this console; after each test it reads the new part of its own log
#   and fails the test for every "SCRIPT ERROR" logged meanwhile, quoting it. Engine "ERROR:"
#   lines (push_error, failures that tests provoke on purpose) do not count. The parent exits
#   with the child's result. -- --no-error-scan runs in this process without the scan.
# Author: Mechanics Developer Agent
extends SceneTree

const TEST_DIR: String = "res://tests"
const ERROR_MARK: String = "SCRIPT ERROR"
const LOG_DIR: String = "user://test_logs"

## This run's private engine log (the child only).
var _log: FileAccess = null
var _log_pos: int = 0
var _scan_errors: bool = true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Let autoloads finish _ready() before any test touches them.
	await process_frame
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	_scan_errors = not user_args.has("--no-error-scan")
	var log_path: String = ""
	for arg: String in user_args:
		if arg.begins_with("--log="):
			log_path = arg.trim_prefix("--log=")
	if _scan_errors and log_path == "":
		quit(_run_child(user_args))
		return
	if _scan_errors:
		_log = FileAccess.open(log_path, FileAccess.READ)
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
			_mark_log()
			await test.call(method_name)
			var failures: Array = test.get("failures")
			var label: String = "%s::%s" % [path.get_file(), method_name]
			if int(test.get("assertions")) == 0:
				failures.append("no assertions ran (script error?)")
			failures.append_array(_errors_since_mark())
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


## Runs the suite in a child Godot that logs to a private file; returns the exit code for this process.
func _run_child(user_args: PackedStringArray) -> int:
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var log_path: String = ProjectSettings.globalize_path(LOG_DIR.path_join("run-%d.log" % OS.get_process_id()))
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", log_path, "-s", "res://tests/run_tests.gd", "--", "--log=" + log_path]
	args.append_array(user_args)
	var pid: int = OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		print("FAIL run_tests: could not start the child run (script errors can't be detected otherwise; -- --no-error-scan skips the scan)")
		return 1
	while OS.is_process_running(pid):
		OS.delay_msec(100)
	var code: int = OS.get_process_exit_code(pid)
	DirAccess.remove_absolute(log_path)
	return 0 if code == 0 else 1


func _mark_log() -> void:
	if _log != null:
		_log_pos = _log.get_length()


## "script error: ..." failures for every SCRIPT ERROR logged since _mark_log().
func _errors_since_mark() -> Array[String]:
	var out: Array[String] = []
	if not _scan_errors:
		return out
	if _log == null:
		out.append("script errors can't be detected: the engine log file is not readable (use -- --no-error-scan to skip)")
		return out
	var end: int = _log.get_length()
	if end <= _log_pos:
		return out
	_log.seek(_log_pos)
	var lines: PackedStringArray = _log.get_buffer(end - _log_pos).get_string_from_utf8().split("\n")
	_log_pos = end
	for i: int in lines.size():
		if lines[i].begins_with(ERROR_MARK):
			var at: String = lines[i + 1].strip_edges() if i + 1 < lines.size() else ""
			out.append("script error: %s %s" % [lines[i].trim_prefix(ERROR_MARK + ": "), at])
	return out


func _find_test_files() -> PackedStringArray:
	var result: PackedStringArray = []
	# Optional filter: godot ... -s res://tests/run_tests.gd -- --only=<substring>
	var only: String = ""
	var dir: String = TEST_DIR
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg.begins_with("--dir="):  # the runner's own self-test (test_runner.gd) uses a fixture folder
			dir = arg.trim_prefix("--dir=")
	for file: String in DirAccess.get_files_at(dir):
		# Exported builds list .gd files as .gd.remap; tests only run from source.
		if file.begins_with("test_") and file.ends_with(".gd") and (only == "" or only in file):
			result.append(dir.path_join(file))
	result.sort()
	return result
