# test_case.gd
# Purpose: Base class for headless tests. Extend it by path:
#   extends "res://tests/test_case.gd"
#   Every test_* method must make at least one assertion; a method that records
#   no assertion counts as failed (that is how a script error mid-test is caught).
# Author: Mechanics Developer Agent
extends RefCounted

## The SceneTree running the tests (set by run_tests.gd before each test).
var tree: SceneTree
var failures: Array[String] = []
var assertions: int = 0


func assert_true(condition: bool, message: String = "expected true") -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func assert_false(condition: bool, message: String = "expected false") -> void:
	assert_true(not condition, message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertions += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s expected <%s> got <%s>" % [message, str(expected), str(actual)])


func assert_not_null(value: Variant, message: String = "expected non-null") -> void:
	assert_true(value != null, message)
