# test_runner_fixture.gd
# Purpose: Fixture for tests/test_runner.gd (cz19b BUG-07), NOT part of the suite: run_tests.gd only
#   reads res://tests itself. Run on its own with -- --dir=res://tests/fixtures/runner, this file must
#   give exactly: test_a_clean PASS, test_b_error_after_assertion FAIL (a script error after an
#   assertion), test_c_error_before_assertion FAIL, and exit code 1.
# Author: UI/UX Agent (cz19b)
extends "res://tests/test_case.gd"


func test_a_clean() -> void:
	assert_true(true, "clean")


func test_b_error_after_assertion() -> void:
	assert_true(true, "first assertion passes")
	var wrong: Variant = "not a number"
	_takes_int(wrong)  # SCRIPT ERROR: Invalid type in function '_takes_int'
	assert_true(true, "never reached")


func test_c_error_before_assertion() -> void:
	var d: Dictionary = {}
	var n: int = d["missing"]  # SCRIPT ERROR: Invalid access to key
	assert_eq(n, 0, "never reached")


func _takes_int(n: int) -> int:
	return n + 1
