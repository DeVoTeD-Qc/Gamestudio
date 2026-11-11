# Seeded sim/game parity for the v4 rules: every case in tests/data/v4_parity.json was computed
# by tools/sim_deaddraw_v4.py's own rule functions (tools/v4_parity_cases.py, seed 4); DDRun must
# return the same numbers. Regenerate the fixture after a sim change:
#   python3 projects/deaddraw/tools/v4_parity_cases.py
extends "res://tests/dd_test_case.gd"

const FIXTURE: String = "res://tests/data/v4_parity.json"


func _cases(key: String) -> Array:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(d is Dictionary, "fixture loads")
	return (d as Dictionary).get(key, []) if d is Dictionary else []


func _ints(a: Variant) -> Array[int]:
	var out: Array[int] = []
	for v: Variant in a:
		out.append(int(v))
	return out


func _run(patches: Array, hp: int, street: Array = ["C2", "C2", "C2", "C2"]) -> DDRun:
	var r: DDRun = plain_run(filler(8), street)
	r.slots = [null, null]
	for p: Variant in patches:
		r.patches.append(str(p))
	r.hp = hp
	return r


func test_parity_legal_and_challenges() -> void:
	var r: DDRun = plain_run(filler(8))
	var bad: int = 0
	var cs: Array = _cases("legal")
	check(cs.size() >= 400, "400 rule cases")
	for c: Variant in cs:
		if r.legal(str(c["rule"]), _ints(c["stack"]), int(c["z"]), bool(c["rosa"])) != bool(c["ok"]):
			bad += 1
			if bad <= 5:
				check(false, "legal %s %s + %d (rosa %s): sim says %s" % [c["rule"], str(c["stack"]), int(c["z"]), str(c["rosa"]), str(c["ok"])])
	eq(bad, 0, "every rule case matches the sim")
	bad = 0
	for c: Variant in _cases("challenge"):
		if r.challenge_met(str(c["wid"]), _ints(c["stack"])) != bool(c["met"]):
			bad += 1
			if bad <= 5:
				check(false, "challenge %s %s: sim says %s" % [c["wid"], str(c["stack"]), str(c["met"])])
	eq(bad, 0, "every challenge case matches the sim")


func test_parity_gun_kills() -> void:
	var bad: int = 0
	var cs: Array = _cases("gun_kill")
	check(cs.size() >= 250, "250 gun kills")
	for c: Variant in cs:
		var z: int = int(c["z"])
		var r: DDRun = _run(c["patches"], int(c["hp0"]), ["Z%d" % z, "C2", "C2", "C2"])
		gun(r, 0, str(c["wid"]), c["stack"])
		var p0: int = r.points
		var dmg: int = int(r.preview(0, 0)["damage"])
		r.attack(0, 0)
		var got: Array = [dmg, r.points - p0, r.hp, r.cover, r.slot(0) != null]
		var want: Array = [int(c["damage"]), int(c["points"]), int(c["hp"]), int(c["cover"]), bool(c["kept"])]
		if got != want:
			bad += 1
			if bad <= 5:
				check(false, "%s %s + %d %s: game %s, sim %s" % [c["wid"], str(c["stack"]), z, str(c["patches"]), str(got), str(want)])
	eq(bad, 0, "every gun kill matches the sim (damage, points, HP, Cover, Encore)")


func test_parity_melee() -> void:
	var bad: int = 0
	for c: Variant in _cases("melee"):
		var z: int = int(c["z"])
		var r: DDRun = _run(c["patches"], 20, ["K:%s" % str(c["mid"]) if str(c["mid"]) != "" else "C2", "Z%d" % z, "C2", "C2"])
		if str(c["mid"]) != "":
			r.resolve(0, DDRun.TAKE)
		else:
			r.resolve(0, DDRun.USE)
		r.cover = 0
		r.hp = int(c["hp0"])
		var i: int = idx(r, "Z%d" % z)
		var u0: int = r.melee_uses()
		var dmg: int = int(r.preview(i, DDRun.MELEE)["damage"])
		var p0: int = r.points
		r.attack(i, DDRun.MELEE)
		var got: Array = [u0, dmg, r.melee_uses(), r.points - p0]
		var want: Array = [int(c["uses0"]), int(c["damage"]), int(c["uses_after"]), int(c["points"])]
		if got != want:
			bad += 1
			if bad <= 5:
				check(false, "melee %s vs %d %s: game %s, sim %s" % [c["mid"], z, str(c["patches"]), str(got), str(want)])
	eq(bad, 0, "every melee kill matches the sim (power, uses, no points)")
	for c: Variant in _cases("take"):
		var r2: DDRun = _run(c["patches"], 20, ["K:" + str(c["mid"]), "C2", "C2", "C2"])
		r2.resolve(0, DDRun.TAKE)
		eq([int(r2.melee["power"]), r2.melee_uses()], [int(c["power"]), int(c["uses"])], "take %s %s" % [c["mid"], str(c["patches"])])


func test_parity_salvage_medkits_rooms() -> void:
	for c: Variant in _cases("salvage"):
		var r: DDRun = _run([], 20, ["W:pistol", "C2", "C2", "C2"])
		gun(r, 0, str(c["wid"]), c["stack"])
		var p0: int = r.points
		r.resolve(0, DDRun.EQUIP1)
		eq(r.points - p0, int(c["points"]), "salvage %s %s" % [c["wid"], str(c["stack"])])
	for c: Variant in _cases("medkit"):
		var r2: DDRun = _run(c["patches"], int(c["hp0"]), ["M%d" % int(c["v"]), "C2", "C2", "C2"])
		r2.passive = str(c["passive"])
		r2.cover = int(c["cover0"])
		r2.resolve(0, DDRun.USE)
		eq([r2.hp, r2.cover], [int(c["hp"]), int(c["cover"])], "medkit %d %s %s from %d" % [int(c["v"]), c["passive"], str(c["patches"]), int(c["hp0"])])
	for c: Variant in _cases("room"):
		var r3: DDRun = _run(["lockpick"] if bool(c["lockpick"]) else [], 20)
		r3.district_index = int(c["district"])
		eq(r3.room_cost(int(c["room"])), int(c["cost"]), "room %d/%d lockpick %s" % [int(c["district"]), int(c["room"]), str(c["lockpick"])])


func test_parity_safehouse_shop() -> void:
	for c: Variant in _cases("shop"):
		var r: DDRun = plain_run(filler(8))
		r.patches = bal().patches()          # every Patch owned: no boss / shop Patch, supplies only
		clear_district(r)
		r.max_hp = 20
		r.hp = int(c["hp0"])
		r.points = int(c["points0"])
		var n: int = r.supplies_max()
		if n > 0:
			r.buy_supplies(n)
		var ev: Dictionary = r.leave_safehouse()
		eq([n, int(ev.get("left_behind", -1)), r.hp, r.points], [int(c["bought"]), int(c["lost"]), int(c["hp"]), int(c["points"])],
			"shop: %d HP, %d points" % [int(c["hp0"]), int(c["points0"])])
