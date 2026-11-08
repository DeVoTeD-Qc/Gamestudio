# dd_test_case.gd
# Purpose: Base class for DeadDraw tests: assertions plus helpers that build runs with a
#   scripted deck. Tests extend this file by path.
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


## A run for `survivor` with every perk in the pool, seeded, then a scripted deck/street.
## Codes: "Z9", "Z9!payday" (Carrier), "W:revolver", "A4", "M5", "B2" (see DDCard.parse()).
func make_run(survivor: String, deck_codes: Array = [], street_codes: Array = [], b: DDBalance = null) -> DDRun:
	var r: DDRun = DDRun.new(b if b != null else bal())
	r.start(survivor, bal().all_perks(), 1234)
	if not deck_codes.is_empty() or not street_codes.is_empty():
		r.setup_street(deck_codes, street_codes)
	return r


## A run with no survivor passive (plain rules), scripted deck.
func plain_run(deck_codes: Array, street_codes: Array = [], b: DDBalance = null) -> DDRun:
	var r: DDRun = DDRun.new(b if b != null else bal())
	r.start("rosa", bal().all_perks(), 99)
	r.passive = ""
	r.setup_street(deck_codes, street_codes)
	return r


## Puts the run on its boss wave with an empty Skipped pile, then deals `street_codes` with an
## empty deck: the boss street comes next (or the last lap if `skipped_codes` is given).
func to_boss_wave(r: DDRun, deck_codes: Array, street_codes: Array = [], skipped_codes: Array = []) -> void:
	r.wave_index = r.wave_count() - 1
	r.last_lap = false
	r.skipped.clear()
	for c: Variant in skipped_codes:
		r.skipped.append(r.as_card(c))
	r.setup_street(deck_codes, street_codes)


## Clears the current district at once: boss wave, empty deck, boss street fought bare with
## lots of HP. Leaves the run at the safehouse (or WON).
func clear_district(r: DDRun) -> void:
	r.hp = r.max_hp
	r.cover = 0
	to_boss_wave(r, [], [])
	r.cover = 40
	var guard: int = 0
	while r.phase == DDRun.Phase.STREET and guard < 10:
		guard += 1
		r.resolve(0, DDRun.BARE if r.street[0].kind == DDCard.ZOMBIE else DDRun.USE)


func gun(r: DDRun, s: int, wid: String = "pistol") -> DDWeapon:
	r.slots[s] = r.make_weapon(wid)
	return r.slots[s]


func filler(n: int, code: String = "B2") -> Array:
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
