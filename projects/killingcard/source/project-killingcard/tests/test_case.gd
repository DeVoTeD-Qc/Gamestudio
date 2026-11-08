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


## kc-econ: round 1 gives 1 Supply, so a seeded opening hand may hold no unit it can pay for. UI tests
## that need "a playable unit" top the side up to its cheapest unit's cost (never lower it) and
## refresh the controller so the hand redraws. `filter` (RulesCard -> bool) narrows the units.
static func afford_a_unit(controller: Node, side: int = 0, filter: Callable = Callable()) -> void:
	var s: RulesSide = controller.state.sides[side]
	var cheapest: int = -1
	for rc: RulesCard in s.hand:
		if rc.card.is_unit() and (not filter.is_valid() or filter.call(rc)):
			cheapest = rc.card.cost if cheapest < 0 else mini(cheapest, rc.card.cost)
	if cheapest > s.supply:
		s.supply = cheapest
		if controller.has_method(&"refresh"):
			controller.refresh()
