# test_rules_fight_order.gd
# Purpose: kc-fight-impl (firefight-order.md, approved): the Firefight activation order.
#   Columns A -> B -> C; beats front to back, one shooter per side per beat; every unit fires once
#   per round (moving up never resets it); First Shot exchange (a partner it kills never fires,
#   both First Shot = simultaneous); damage beyond the target is lost, Pierce carries it (Cover
#   applies); line advances; Suppress pins a unit, not a slot; Pick / Flank choose at their beat;
#   On Down hits the new front; a Guard / Fireteam death changes later beats and columns; the
#   event stream order the UI plays back; the AI estimator's beat order; the package data
#   (Pierce on the LMG units, Protector cost 4 without Guard) and the playback flags.
#   Units are put on the board directly on a flat map (no range bonuses for class NONE).
# Author: Mechanics Developer Agent (kc-fight-impl)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1
const L: int = 0
const M: int = 1
const R: int = 2


func _shots_by(m: MatchState, uid: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in F.events_of(m, RulesEvent.SHOT_FIRED):
		if int(e["shooter_uid"]) == uid:
			out.append(e)
	return out


func _u(id: String, fp: int, ar: int, kw: Dictionary = {}) -> CardData:
	return F.unit(id, fp, ar, F.W.NONE, kw)


# --- Order -----------------------------------------------------------------------------------

func test_columns_resolve_a_then_b_then_c_in_beats() -> void:
	var m: MatchState = F.new_match()
	for z: int in [R, L, M]:
		F.place(m, P, _u("p%d" % z, 1, 9), z)
		F.place(m, P, _u("q%d" % z, 1, 9), z)
		F.place(m, E, _u("e%d" % z, 1, 9), z)
	var start: int = m.events.size()
	m.firefight()
	var zones: Array[StringName] = []
	var beats_per_zone: Dictionary = {}
	for e: Dictionary in m.events_since(start):
		if e["type"] == RulesEvent.FIREFIGHT_STARTED:
			zones.append(e["zone"])
		elif e["type"] == RulesEvent.FIREFIGHT_BEAT:
			assert_eq(e["zone"], zones.back(), "a beat belongs to the column that is resolving")
			beats_per_zone[e["zone"]] = int(beats_per_zone.get(e["zone"], 0)) + 1
		elif e["type"] == RulesEvent.FIREFIGHT_COLUMN_ENDED:
			assert_eq(e["zone"], zones.back(), "the column ends before the next starts")
			assert_eq(int(e["beats"]), int(beats_per_zone[e["zone"]]), "beat count on the end event")
	assert_eq(zones, [&"left", &"mid", &"right"] as Array[StringName], "A, then B, then C")
	# 2 v 1 per column: beat 1 = both fronts, beat 2 = my row 2 alone (the enemy has fired).
	assert_eq(beats_per_zone, {&"left": 2, &"mid": 2, &"right": 2}, "two beats per column")


func test_front_units_fire_first_and_the_beat_is_simultaneous() -> void:
	var m: MatchState = F.new_match()
	var p1: RulesUnit = F.place(m, P, _u("p1", 2, 2), M)
	var p2: RulesUnit = F.place(m, P, _u("p2", 1, 9), M)
	var e1: RulesUnit = F.place(m, E, _u("e1", 2, 2), M)
	var e2: RulesUnit = F.place(m, E, _u("e2", 1, 9), M)
	m.firefight()
	var beats: Array[Dictionary] = F.events_of(m, RulesEvent.FIREFIGHT_BEAT)
	assert_eq(beats.size(), 2, "two beats")
	assert_eq((beats[0]["shooters"] as Array).size(), 2, "beat 1: one shooter per side")
	assert_true((beats[0]["shooters"] as Array).has(p1.uid) and (beats[0]["shooters"] as Array).has(e1.uid), "the fronts fire first")
	assert_false(p1.is_alive() or e1.is_alive(), "simultaneous: both fronts trade")
	assert_true((beats[1]["shooters"] as Array).has(p2.uid) and (beats[1]["shooters"] as Array).has(e2.uid), "then the moved-up row 2s")
	assert_eq([p2.armor, e2.armor], [8, 8], "row 2s hit each other after moving up")


func test_every_unit_fires_once_even_after_moving_up() -> void:
	# p1 fires in beat 1 and survives; p2 fires in beat 2 from row 2; e2 then kills p1, so p2 moves
	# up to the front after it has fired: it must not fire again (beat 3 is the enemy's e3 alone).
	var m: MatchState = F.new_match()
	var p1: RulesUnit = F.place(m, P, _u("p1", 0, 2), M)
	var p2: RulesUnit = F.place(m, P, _u("p2", 0, 9), M)
	F.place(m, E, _u("e1", 1, 9), M)
	F.place(m, E, _u("e2", 1, 9), M)
	var e3: RulesUnit = F.place(m, E, _u("e3", 1, 9), M)
	m.firefight()
	assert_false(p1.is_alive(), "p1 died in beat 2")
	assert_eq(_shots_by(m, p2.uid).size(), 1, "p2 fired once, from row 2")
	assert_eq(_shots_by(m, e3.uid).size(), 1, "e3 still fires (alone) in beat 3")
	assert_eq(p2.armor, 8, "e3's shot hit p2, the new front")
	var adv: Array[Dictionary] = F.events_of(m, RulesEvent.LINE_ADVANCED)
	assert_eq(adv.size(), 1, "one line advance")
	assert_eq(adv[0]["moves"], [{"uid": p2.uid, "from_row": 1, "to_row": 0}], "p2 row 2 -> row 1")
	assert_eq(adv[0]["side"], &"player", "my line closed up")
	for s: RulesSide in m.sides:
		for u: RulesUnit in s.units_on_board():
			assert_false(u.fired, "fired flags reset after the firefight")


# --- First Shot exchange ----------------------------------------------------------------------

func test_first_shot_kill_prevents_return_fire() -> void:
	var m: MatchState = F.new_match()
	var fs: RulesUnit = F.place(m, P, _u("fs", 3, 2, {"first_shot": true}), M)
	var slow: RulesUnit = F.place(m, E, _u("slow", 9, 3), M)
	var back: RulesUnit = F.place(m, E, _u("back", 1, 9), M)
	m.firefight()
	assert_false(slow.is_alive(), "killed in the First Shot beat")
	assert_eq(_shots_by(m, slow.uid).size(), 0, "a partner it kills never fires")
	var beats: Array[Dictionary] = F.events_of(m, RulesEvent.FIREFIGHT_BEAT)
	assert_eq(int(beats[0]["exchange"]), FirefightResolver.EXCHANGE_FIRST_SHOT, "beat 1 is the First Shot half")
	assert_eq(beats[0]["shooters"], [fs.uid], "only the First Shot unit fires in it")
	assert_eq(int(beats[1]["exchange"]), FirefightResolver.EXCHANGE_TOGETHER, "no reply beat: the partner is dead")
	assert_eq(beats[1]["shooters"], [back.uid], "the enemy's next unit fires alone (mine has fired)")
	assert_eq(fs.armor, 1, "hit only by the back unit")
	assert_eq(_shots_by(m, fs.uid)[0]["step"], FirefightResolver.STEP_FIRST_SHOT, "logged as a First Shot")


func test_first_shot_partner_that_survives_replies() -> void:
	var m: MatchState = F.new_match()
	var fs: RulesUnit = F.place(m, P, _u("fs", 2, 4, {"first_shot": true}), M)
	var tough: RulesUnit = F.place(m, E, _u("tough", 3, 5), M)
	m.firefight()
	var beats: Array[Dictionary] = F.events_of(m, RulesEvent.FIREFIGHT_BEAT)
	assert_eq(beats.size(), 2, "First Shot half, then the reply")
	assert_eq(int(beats[1]["exchange"]), FirefightResolver.EXCHANGE_REPLY, "beat 2 is the reply")
	assert_true(bool(beats[1]["first_shot_split"]), "flagged as a split exchange")
	assert_eq([tough.armor, fs.armor], [3, 1], "both landed, in order")


func test_both_first_shot_fire_together() -> void:
	var m: MatchState = F.new_match()
	var a: RulesUnit = F.place(m, P, _u("a", 3, 3, {"first_shot": true}), M)
	var b: RulesUnit = F.place(m, E, _u("b", 3, 3, {"first_shot": true}), M)
	m.firefight()
	assert_false(a.is_alive() or b.is_alive(), "simultaneous trade")
	var beats: Array[Dictionary] = F.events_of(m, RulesEvent.FIREFIGHT_BEAT)
	assert_eq(beats.size(), 1, "one beat")
	assert_false(bool(beats[0]["first_shot_split"]), "not split")


func test_back_row_first_shot_waits_for_its_beat() -> void:
	# "Front first": a row-2 First Shot unit does not fire before the front line.
	var m: MatchState = F.new_match()
	var front: RulesUnit = F.place(m, P, _u("front", 1, 9), M)
	var fs_back: RulesUnit = F.place(m, P, _u("fs_back", 5, 9, {"first_shot": true}), M)
	var e1: RulesUnit = F.place(m, E, _u("e1", 1, 9), M)
	F.place(m, E, _u("e2", 1, 9), M)
	m.firefight()
	var beats: Array[Dictionary] = F.events_of(m, RulesEvent.FIREFIGHT_BEAT)
	assert_true((beats[0]["shooters"] as Array).has(front.uid) and (beats[0]["shooters"] as Array).has(e1.uid), "the fronts fire in beat 1")
	assert_eq(int(_shots_by(m, fs_back.uid)[0]["beat"]), 2, "the back First Shot unit fires in beat 2")


# --- Pierce -------------------------------------------------------------------------------------

func test_extra_damage_is_lost_without_pierce() -> void:
	var m: MatchState = F.new_match()
	var big: RulesUnit = F.place(m, P, _u("big", 6, 9), M)
	F.place(m, E, _u("e1", 0, 2), M)
	var e2: RulesUnit = F.place(m, E, _u("e2", 0, 3), M)
	m.firefight()
	assert_eq(e2.armor, 3, "overkill does not carry")
	assert_eq(F.events_of(m, RulesEvent.PIERCE_CARRIED).size(), 0, "no Pierce event")
	assert_eq(int(_shots_by(m, big.uid)[0]["overkill"]), 4, "the overkill is logged")


func test_pierce_carries_down_the_line_and_cover_applies() -> void:
	var m: MatchState = F.new_match()
	var lmg: RulesUnit = F.place(m, P, _u("lmg", 6, 9, {"pierce": true}), M)
	var e1: RulesUnit = F.place(m, E, _u("e1", 0, 2), M)
	var e2: RulesUnit = F.place(m, E, _u("e2", 0, 2, {"cover": 1}), M)
	var e3: RulesUnit = F.place(m, E, _u("e3", 0, 5), M)
	assert_true(lmg.pierce, "the unit carries the printed keyword")
	m.firefight()
	# 6 on e1 (needs 2) -> 4 carried; e2: 4 - Cover 1 = 3, needs 2 -> dead; 4 - (1 + 2) = 1 -> e3.
	assert_false(e1.is_alive(), "target dead")
	assert_false(e2.is_alive(), "the carry kills the next one through its Cover")
	assert_eq(e3.armor, 4, "the rest reaches the third")
	var carries: Array[Dictionary] = F.events_of(m, RulesEvent.PIERCE_CARRIED)
	assert_eq(carries.size(), 2, "two carries")
	assert_eq([carries[0]["from_uid"], carries[0]["target_uid"], carries[0]["carried"], carries[0]["damage"]],
			[e1.uid, e2.uid, 4, 2], "carry 1: e1 -> e2")
	assert_eq([carries[1]["from_uid"], carries[1]["target_uid"], carries[1]["carried"], carries[1]["damage"]],
			[e2.uid, e3.uid, 1, 1], "carry 2: e2 -> e3")
	assert_eq(m.sides[P].eliminations, 2, "the Pierce kill is credited to the shooter")


func test_pierce_stopped_by_cover() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, _u("lmg", 3, 9, {"pierce": true}), M)
	F.place(m, E, _u("e1", 0, 2), M)
	var e2: RulesUnit = F.place(m, E, _u("e2", 0, 3, {"cover": 1}), M)
	m.firefight()
	assert_eq(e2.armor, 3, "1 carried, Cover 1 eats it")


# --- Live board: Suppress, Pick / Flank, On Down, links -----------------------------------------

func test_suppress_pins_the_unit_not_the_slot() -> void:
	var m: MatchState = F.new_match()
	var p1: RulesUnit = F.place(m, P, _u("p1", 3, 1), M)
	var p2: RulesUnit = F.place(m, P, _u("p2", 3, 9), M)
	F.place(m, E, _u("e1", 1, 20), M)
	F.place(m, E, _u("gunner", 0, 20, {"suppress": true}), M)
	m.firefight()
	assert_false(p1.is_alive(), "suppressed front died in beat 1")
	assert_eq(int(_shots_by(m, p1.uid)[0]["damage"]), 1, "it fired with 3 - 2")
	assert_eq(int(_shots_by(m, p2.uid)[0]["damage"]), 3, "the unit that moved up is not suppressed")


func test_pick_and_flank_choose_at_their_beat() -> void:
	var m: MatchState = F.new_match()
	var picker: RulesUnit = F.place(m, P, _u("picker", 1, 9, {"pick": true}), M)
	var flanker: RulesUnit = F.place(m, P, _u("flanker", 1, 9, {"flank": true}), M)
	F.place(m, E, _u("e1", 0, 9), M)
	var e2: RulesUnit = F.place(m, E, _u("e2", 0, 5), M)
	var e3: RulesUnit = F.place(m, E, _u("e3", 0, 1), M)
	m.firefight()
	assert_eq(int(_shots_by(m, picker.uid)[0]["target_uid"]), e3.uid, "beat 1: Pick takes the weakest (back) unit")
	assert_false(e3.is_alive(), "and kills it")
	var fl: Dictionary = _shots_by(m, flanker.uid)[0]
	assert_eq(int(fl["beat"]), 2, "the row-2 Flanker fires in beat 2")
	assert_eq(int(fl["target_uid"]), e2.uid, "at the back-most enemy as it stands then")


func test_on_down_hits_the_front_as_it_stands_then() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.demolitions(), M)  # 2/4, On Down 3 to the enemy point man
	m.sides[P].line(M)[0].armor = 2
	var e1: RulesUnit = F.place(m, E, _u("e1", 5, 2), M)
	var e2: RulesUnit = F.place(m, E, _u("e2", 0, 9), M)
	m.firefight()
	assert_false(e1.is_alive(), "e1 traded with the Demolitions Expert")
	assert_eq(e2.armor, 6, "On Down hit e2, the front after e1 was removed")


func test_guard_death_removes_its_cover_in_later_beats() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, _u("guard", 0, 2, {"neighbor_keyword": &"guard"}), M)
	var behind: RulesUnit = F.place(m, P, _u("behind", 0, 9), M)
	assert_eq(m.cover_of(behind), 1, "Guard covers the card behind")
	F.place(m, E, _u("e1", 5, 9), M)
	F.place(m, E, _u("e2", 2, 9), M)
	m.firefight()
	assert_eq(behind.armor, 7, "beat 2: the Guard is dead, so the full 2 lands")


func test_fireteam_death_in_a_switches_off_the_link_before_b() -> void:
	var m: MatchState = F.new_match()
	var a: RulesUnit = F.place(m, P, _u("ft_a", 2, 2, {"neighbor_keyword": &"fireteam"}), L)
	var b: RulesUnit = F.place(m, P, _u("ft_b", 2, 9, {"neighbor_keyword": &"fireteam"}), M)
	assert_eq(m.firepower_of(b), 3, "linked before the firefight")
	F.place(m, E, _u("killer", 5, 9), L)
	var target: RulesUnit = F.place(m, E, _u("target", 0, 3), M)
	m.firefight()
	assert_false(a.is_alive(), "A's Fireteam died in column A")
	assert_eq(target.armor, 1, "column B: the link is off, 2 lands instead of 3")


func test_patch_after_the_column() -> void:
	var m: MatchState = F.new_match()
	var hurt: RulesUnit = F.place(m, P, _u("hurt", 0, 6), M)
	var medic: RulesUnit = F.place(m, P, _u("medic", 0, 5, {"patch": 2}), M)
	F.place(m, E, _u("e1", 3, 9), M)
	var start: int = m.events.size()
	m.firefight()
	var types: Array = m.events_since(start).map(func(e: Dictionary) -> StringName: return e["type"])
	assert_true(types.find(RulesEvent.PATCHED) > types.rfind(RulesEvent.FIREFIGHT_BEAT), "Patch comes after the last beat")
	assert_true(types.find(RulesEvent.PATCHED) < types.find(RulesEvent.FIREFIGHT_COLUMN_ENDED), "and before the column ends")
	assert_eq(hurt.armor, 5, "6 - 3 + 2")
	assert_eq(medic.armor, 5, "the medic itself untouched")


# --- Event stream ----------------------------------------------------------------------------

func test_event_stream_order_within_a_beat() -> void:
	var m: MatchState = F.new_match()
	var lmg: RulesUnit = F.place(m, P, _u("lmg", 6, 9, {"pierce": true}), M)
	var e1: RulesUnit = F.place(m, E, _u("e1", 0, 2), M)
	F.place(m, E, _u("e2", 0, 1), M)
	var e3: RulesUnit = F.place(m, E, _u("e3", 0, 9), M)
	var start: int = m.events.size()
	m.firefight()
	var ev: Array[Dictionary] = m.events_since(start)
	var at: Callable = func(type: StringName, from: int = 0) -> int:
		for i: int in range(from, ev.size()):
			if ev[i]["type"] == type:
				return i
		return -1
	var i_start: int = at.call(RulesEvent.FIREFIGHT_STARTED)
	var i_beat1: int = at.call(RulesEvent.FIREFIGHT_BEAT)
	var i_shot: int = -1
	for i: int in ev.size():
		if ev[i]["type"] == RulesEvent.SHOT_FIRED and int(ev[i]["shooter_uid"]) == lmg.uid:
			i_shot = i
	var i_carry: int = at.call(RulesEvent.PIERCE_CARRIED)
	var i_dmg: int = at.call(RulesEvent.DAMAGE_DEALT, i_carry)
	var i_dead: int = at.call(RulesEvent.UNIT_ELIMINATED)
	var i_adv: int = at.call(RulesEvent.LINE_ADVANCED)
	var i_beat2: int = at.call(RulesEvent.FIREFIGHT_BEAT, i_beat1 + 1)
	var i_end: int = at.call(RulesEvent.FIREFIGHT_COLUMN_ENDED)
	var order: Array[int] = [i_start, i_beat1, i_shot, i_carry, i_dmg, i_dead, i_adv, i_beat2, i_end]
	var sorted: Array[int] = order.duplicate()
	sorted.sort()
	assert_true(i_start >= 0 and order == sorted, "start < beat < shot < carry < damage < death < advance < beat 2 < end: %s" % str(order))
	assert_eq(F.events_of(m, RulesEvent.PIERCE_CARRIED).size(), 2, "the carry goes e1 -> e2 -> e3")
	assert_eq(F.events_of(m, RulesEvent.UNIT_ELIMINATED).size(), 2, "e1 and e2 die in beat 1")
	assert_false(e1.is_alive(), "e1 dead")
	assert_eq(e3.armor, 6, "6 - 2 - 1 = 3 reach e3")
	var adv: Dictionary = ev[i_adv]
	assert_eq(adv["side"], &"enemy", "the enemy line closed up")
	assert_eq(adv["moves"], [{"uid": e3.uid, "from_row": 2, "to_row": 0}], "e3 row 3 -> row 1")
	assert_eq(ev[i_beat2]["shooters"], [e3.uid], "beat 2: e3 alone (my unit has fired)")
	assert_true(FirefightResolver.playback_seconds(ev) > 0.0, "the timing model reads the stream")


func test_no_shot_after_death_and_at_most_one_shot_per_unit_soak() -> void:
	# Seeded random boards: invariants the playback relies on.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	for trial: int in 40:
		var m: MatchState = F.new_match()
		for si: int in 2:
			for z: int in 3:
				for i: int in rng.randi_range(0, 4):
					var kw: Dictionary = {}
					match rng.randi_range(0, 6):
						0: kw = {"first_shot": true}
						1: kw = {"pick": true}
						2: kw = {"flank": true}
						3: kw = {"pierce": true}
						4: kw = {"cover": 1}
					F.place(m, si, _u("u%d" % i, rng.randi_range(0, 5), rng.randi_range(1, 6), kw), z)
		var start: int = m.events.size()
		m.firefight()
		var dead: Dictionary = {}
		var fired: Dictionary = {}
		for e: Dictionary in m.events_since(start):
			if e["type"] == RulesEvent.UNIT_ELIMINATED:
				dead[int(e["victim_uid"])] = true
			elif e["type"] == RulesEvent.SHOT_FIRED:
				var s: int = int(e["shooter_uid"])
				assert_false(dead.has(s), "trial %d: no shot after the shooter's death" % trial)
				assert_false(fired.has(s), "trial %d: one shot per unit per round" % trial)
				fired[s] = true
				assert_true(int(e["target_uid"]) >= 0, "trial %d: every shot has a target" % trial)


# --- AI estimator ----------------------------------------------------------------------------

func _rec(fp: int, armor: int, extra: Dictionary = {}) -> Dictionary:
	var r: Dictionary = AiView.new_record()
	r["fp"] = fp
	r["armor"] = armor
	r["max_armor"] = armor
	r.merge(extra, true)
	return r


func _estimate(mine: Array, foes: Array) -> Array:
	var planner: AiPlanner = AiPlanner.new()
	var sides: Array = [mine, foes]
	var n: Array[int] = [mine.size(), foes.size()]
	var armor: Array = [[], []]
	var fp: Array = [[], []]
	var cover: Array = [[], []]
	var fs: Array = [[], []]
	var survive: Array = [[], []]
	for si: int in 2:
		for r: Dictionary in sides[si]:
			armor[si].append(int(r["armor"]))
			fp[si].append(int(r["fp"]))
			cover[si].append(int(r["cover"]))
			fs[si].append(bool(r["first_shot"]))
			survive[si].append(0)
	planner._fight(sides, n, armor, fp, cover, fs, survive, [0, 0] as Array[int], [0, 0] as Array[int])
	return armor


func test_ai_estimator_plays_the_beat_order() -> void:
	# First Shot exchange: my First Shot front kills theirs, which never fires; their row 2 then hits.
	var a: Array = _estimate([_rec(3, 3, {"first_shot": true})], [_rec(9, 3), _rec(1, 9)])
	assert_eq(a[0], [2], "my unit takes only the back unit's 1")
	assert_eq(a[1][0], 0, "their front died before firing")
	# Pierce with Cover, as the resolver.
	var b: Array = _estimate([_rec(6, 9, {"pierce": true})], [_rec(0, 2), _rec(0, 2, {"cover": 1}), _rec(0, 5)])
	assert_eq(b[1], [-4, 0, 4], "6 on the front, 3 through Cover onto the second, 1 onto the third")
	# Every unit once: a row-2 shooter that fired is not re-used when it reaches the front.
	var c: Array = _estimate([_rec(0, 2), _rec(0, 9)], [_rec(1, 9), _rec(1, 9), _rec(1, 9)])
	assert_eq(c[0], [0, 8], "front dies in beat 2, row 2 takes the third shot")


func test_ai_view_records_carry_pierce() -> void:
	var m: MatchState = F.new_match()
	var g: RulesUnit = F.place(m, E, load("res://data/cards/gunner.tres") as CardData, M)
	var view: AiView = AiView.capture(m, E)
	var found: bool = false
	for r: Dictionary in view.lines[AiView.ME][M]:
		if int(r["uid"]) == g.uid:
			found = bool(r["pierce"])
	assert_true(found, "the Gunner's record has Pierce")


# --- Data and flags --------------------------------------------------------------------------

func test_pierce_is_on_the_lmg_units_only() -> void:
	var pierce: Array[StringName] = []
	for file: String in DirAccess.get_files_at("res://data/cards"):
		if not file.ends_with(".tres"):
			continue
		var c: CardData = load("res://data/cards/" + file) as CardData
		if c.is_unit():
			assert_eq(c.pierce, c.weapon_class == DataEnums.WeaponClass.LMG, "%s: Pierce iff LMG (head's answer O3)" % c.id)
			if c.pierce:
				pierce.append(c.id)
				assert_true(c.text.contains("Pierce"), "%s: the text says Pierce" % c.id)
	pierce.sort()
	assert_eq(pierce, [&"demolitions_expert", &"gunner"] as Array[StringName], "the Gunner and the Demolitions Expert")
	var v: DataValidator = DataValidator.new()
	var bad: CardData = F.hold_the_line()
	bad.pierce = true
	bad.validate(v)
	assert_true(str(v.issues).contains("keywords"), "a Tactic with Pierce is refused")


func test_protector_package_numbers_and_slide() -> void:
	var prot: CardData = load("res://data/cards/shieldman.tres") as CardData
	assert_eq([prot.cost, prot.cover, prot.arrives_front, prot.neighbor_keyword, prot.card_trait],
			[4, 1, true, &"", &"vanguard"], "Protector: cost 4, Cover 1, slides, no Guard, Vanguard")
	var m: MatchState = F.new_match(F.setup([prot]), F.setup())
	m.sides[P].supply = 7
	var old_front: RulesUnit = F.place(m, P, _u("old_front", 0, 9), M)
	var e1: RulesUnit = F.place(m, E, _u("e1", 3, 9), M)
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "shieldman"), M))["ok"], "Protector played")
	m.reveal()
	var p: RulesUnit = m.sides[P].line(M)[0]
	assert_eq(p.source_id, &"shieldman", "slid to row 1")
	assert_eq(m.cover_of(old_front), 0, "no Guard: the card behind gets no Cover")
	m.firefight()
	assert_eq(int(_shots_by(m, e1.uid)[0]["target_uid"]), p.uid, "beat 1: the enemy front shoots the Protector")
	assert_eq(p.armor, p.base_max_armor - 2, "3 - Cover 1")


func test_playback_flags_for_the_ui() -> void:
	assert_eq(FirefightResolver.default_playback_speed(false), 1.0, "x1 for the first runs")
	assert_eq(FirefightResolver.default_playback_speed(true), 2.0, "x2 after the tutorial")
	assert_true(FirefightResolver.PLAYBACK_TAP_TO_SKIP, "tap to skip always")
