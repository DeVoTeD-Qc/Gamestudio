# dd_test_case.gd
# Purpose: Base class for DeadDraw tests: assertions plus helpers that build v3 runs with a
#   scripted pile and street. Tests extend this file by path.
# Author: Mechanics Developer Agent
extends RefCounted

var tree: SceneTree
var failures: Array = []
var assertions: int = 0


func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append(msg)


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	assertions += 1
	if typeof(actual) != typeof(expected) and not (actual is float or actual is int):
		failures.append("%s: expected %s, got %s" % [msg, str(expected), str(actual)])
	elif actual != expected:
		failures.append("%s: expected %s, got %s" % [msg, str(expected), str(actual)])


func bal() -> DDBalance:
	return DDBalance.get_default()


## A seeded run for `survivor`, then (optionally) a scripted pile (first code = next card dealt)
## and street. Codes: "Z9", "W:rifle", "M5", "C2".
func make_run(survivor: String, pile_codes: Array = [], street_codes: Array = [], b: DDBalance = null) -> DDRun:
	var r: DDRun = DDRun.new(b if b != null else bal())
	r.start(survivor, 1234)
	if not pile_codes.is_empty() or not street_codes.is_empty():
		r.setup_street(pile_codes, street_codes)
	return r


## A run with no survivor passive (plain rules), scripted pile / street.
func plain_run(pile_codes: Array, street_codes: Array = [], b: DDBalance = null) -> DDRun:
	var r: DDRun = DDRun.new(b if b != null else bal())
	r.start("rosa", 99)
	r.passive = ""
	r.setup_street(pile_codes, street_codes)
	return r


## Puts the run on its last wave with an empty pile and `street_codes` on the street; the next
## deal (or setup with <= 1 card) starts the boss street.
func to_boss(r: DDRun, street_codes: Array = []) -> void:
	r.wave_index = r.wave_count() - 1
	r.setup_street([], street_codes)


## Clears the current district at once (boss street fought with lots of Cover). Leaves the run
## at the safehouse (or WON).
func clear_district(r: DDRun) -> void:
	r.hp = r.max_hp
	to_boss(r, [])
	r.cover = 60
	var guard: int = 0
	while r.phase == DDRun.Phase.STREET and guard < 10:
		guard += 1
		var i: int = 0
		while i < r.street.size() and r.street[i].kind != DDCard.ZOMBIE:
			i += 1
		if i >= r.street.size():
			r.resolve(0, DDRun.USE if r.street[0].kind != DDCard.WEAPON else DDRun.SCRAP)
		else:
			r.attack(i, DDRun.MELEE)


func gun(r: DDRun, s: int, wid: String = "pistol", stack: Array = []) -> DDGun:
	r.slots[s] = r.make_gun(wid)
	for z: Variant in stack:
		(r.slots[s] as DDGun).stack.append(int(z))
	return r.slots[s]


func filler(n: int, code: String = "C2") -> Array:
	var a: Array = []
	for k: int in n:
		a.append(code)
	return a


## Index of the first street card with this code, or -1.
func idx(r: DDRun, code: String) -> int:
	for k: int in r.street.size():
		if r.street[k].code() == code:
			return k
	return -1


func codes(cards: Array) -> Array:
	var out: Array = []
	for c: Variant in cards:
		out.append((c as DDCard).code())
	return out


func balance_with(overrides: Dictionary) -> DDBalance:
	var b: DDBalance = DDBalance.from_file(DDBalance.DEFAULT_PATH)
	for k: String in overrides:
		b.config[k] = overrides[k]
	return b
