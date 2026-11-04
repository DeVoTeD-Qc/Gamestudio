# test_runner.gd
# Purpose: The headless runner fails a test that hits a script error (cz19b BUG-07). Runs a second
#   Godot on tests/fixtures/runner (a clean test, a script error after an assertion, one before any
#   assertion) and checks the report and the exit code.
# Author: UI/UX Agent (cz19b)
extends "res://tests/test_case.gd"


func test_script_error_after_an_assertion_fails_the_test() -> void:
	var out: Array = []
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"-s", "res://tests/run_tests.gd", "--", "--dir=res://tests/fixtures/runner"]
	var code: int = OS.execute(OS.get_executable_path(), args, out, true)
	var text: String = "\n".join(out)
	assert_eq(code, 1, "the runner exits 1 when a test errors")
	assert_true("PASS test_runner_fixture.gd::test_a_clean" in text, "a clean test passes")
	assert_true("FAIL test_runner_fixture.gd::test_b_error_after_assertion" in text,
			"an error after the first assertion fails the test:\n%s" % text.right(1500))
	assert_true("script error: Invalid type in function '_takes_int'" in text, "the failure quotes the error")
	assert_true("FAIL test_runner_fixture.gd::test_c_error_before_assertion" in text, "an error before any assertion fails")
	assert_true("1 passed, 2 failed" in text, "summary counts the errored tests as failed")
