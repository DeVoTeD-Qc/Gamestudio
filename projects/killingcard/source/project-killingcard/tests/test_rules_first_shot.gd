# test_rules_first_shot.gd
# Purpose: b01 "First Shot unit still gets shot" (playtest, iPhone web build). Scripted boards
#   that pin down when a First Shot unit can and cannot be hit by the unit it is shooting:
#   a First Shot shot that is lethal on its own (after Cover, Suppress, carried
#   damage) means that target never fires in the Main step. Damage the First Shot unit still
#   takes must come from somewhere else (the next enemy unit, an enemy First Shot unit, Suppress
#   making the shot non-lethal, ...), and the event log must name that real shooter.
#   Map: F.map() = Left Close, Mid Long, Right Mid. kc-pos-cut: no range bonus any more, so the
#   cases that needed the old "Breacher 5 at Close" use a 5-FP Breacher (_breacher5).
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1


## The fixture Breacher with 5 FP (what the old Shotgun +2 at Close gave it).
func _breacher5() -> CardData:
	var c: CardData = F.breacher()
	c.firepower = 5
	return c


## SHOT_FIRED events fired BY uid (any step).
func _shots_by(m: MatchState, uid: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in F.events_of(m, RulesEvent.SHOT_FIRED):
		if int(e["shooter_uid"]) == uid:
			out.append(e)
	return out


## SHOT_FIRED events that hit uid (with damage > 0).
func _hits_on(m: MatchState, uid: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in F.events_of(m, RulesEvent.SHOT_FIRED):
		if int(e["target_uid"]) == uid and int(e["damage"]) > 0:
			out.append(e)
	return out


## Damage that landed on uid, per DAMAGE_DEALT.
func _damage_on(m: MatchState, uid: int) -> int:
	var total: int = 0
	for e: Dictionary in F.events_of(m, RulesEvent.DAMAGE_DEALT):
		if int(e["target_uid"]) == uid:
			total += int(e["amount"])
	return total


# --- the reported case ------------------------------------------------------------------

func test_breacher_at_close_kills_point_man_before_it_fires() -> void:
	var m: MatchState = F.new_match(null, null, F.map())
	var breacher: RulesUnit = F.place(m, P, F.breacher(), F.LEFT)  # 3
	var target: RulesUnit = F.place(m, E, F.rifleman(), F.LEFT)    # 2/2, no First Shot
	m.firefight()
	assert_false(target.is_alive(), "Breacher (5) kills the 2-Armor point man")
	assert_eq(_shots_by(m, target.uid).size(), 0, "the dead target never fires")
	assert_eq(breacher.armor, 4, "Breacher untouched")
	assert_eq(_damage_on(m, breacher.uid), 0, "no damage event on the Breacher")


func test_firepower_is_what_makes_it_lethal() -> void:
	# Same 4-Armor target: 5 FP kills it, 3 FP does not (kc-pos-cut: the column no longer matters).
	var m: MatchState = F.new_match(null, null, F.map())
	var close_b: RulesUnit = F.place(m, P, _breacher5(), F.LEFT)
	var close_t: RulesUnit = F.place(m, E, F.unit("tank", 2, 5, F.W.NONE), F.LEFT)
	var mid_b: RulesUnit = F.place(m, P, F.breacher(), F.RIGHT)
	var mid_t: RulesUnit = F.place(m, E, F.unit("tank", 2, 5, F.W.NONE), F.RIGHT)
	close_t.armor = 4
	mid_t.armor = 4
	m.firefight()
	assert_false(close_t.is_alive(), "5 >= 4, dead in First Shot step")
	assert_eq(close_b.armor, 4, "it never fired back")
	assert_eq(mid_t.armor, 1, "3 < 4, it survives the First Shot step")
	assert_eq(mid_b.armor, 2, "so it fires in the Main step (legit)")


func test_damage_carried_over_counts_toward_lethal() -> void:
	var m: MatchState = F.new_match(null, null, F.map())
	var pm: RulesUnit = F.place(m, P, F.point_man(), F.RIGHT)  # 2 FP at Mid (SMG +0 at Mid)
	var t: RulesUnit = F.place(m, E, F.unit("hurt", 4, 5), F.RIGHT)
	t.armor = 2  # damaged in an earlier round
	m.firefight()
	assert_false(t.is_alive(), "2 FP finishes a unit carrying damage")
	assert_eq(pm.armor, 3, "it never fired")


func test_cover_reduces_below_lethal_so_target_fires() -> void:
	var m: MatchState = F.new_match(null, null, F.map())
	var b: RulesUnit = F.place(m, P, _breacher5(), F.LEFT)  # 5
	var t: RulesUnit = F.place(m, E, F.unit("covered", 2, 5, F.W.NONE, {"cover": 1}), F.LEFT)
	m.firefight()
	assert_eq(t.armor, 1, "5 - Cover 1 = 4 < 5: survives the First Shot step")
	assert_eq(b.armor, 2, "and fires in Main (correct)")


func test_suppress_makes_first_shot_non_lethal() -> void:
	# Enemy Gunner (Suppress) is behind its point man: my point man Breacher gets -2 FP.
	var m: MatchState = F.new_match(null, null, F.map())
	var b: RulesUnit = F.place(m, P, _breacher5(), F.LEFT)  # 5 - 2 = 3
	var t: RulesUnit = F.place(m, E, F.unit("front", 2, 4), F.LEFT)
	F.place(m, E, F.gunner(), F.LEFT)
	m.firefight()
	assert_eq(t.armor, 1, "3 < 4: the point man survives")
	assert_eq(F.events_of(m, RulesEvent.SUPPRESSED).size(), 1, "Suppress logged")
	assert_true(_shots_by(m, t.uid).size() == 1 and _shots_by(m, t.uid)[0]["step"] == FirefightResolver.STEP_BEAT,
			"the surviving point man replies in the next beat")
	assert_false(b.is_alive() and b.armor == 4, "the Breacher was hit")


# --- other enemy units ---------------------------------------------------------------

func test_next_enemy_unit_shoots_in_main_not_the_dead_one() -> void:
	var m: MatchState = F.new_match(null, null, F.map())
	var b: RulesUnit = F.place(m, P, F.breacher(), F.LEFT)
	var front: RulesUnit = F.place(m, E, F.rifleman(), F.LEFT)
	var back: RulesUnit = F.place(m, E, F.unit("back", 2, 6), F.LEFT)
	m.firefight()
	assert_false(front.is_alive(), "front dead in First Shot step")
	assert_eq(_shots_by(m, front.uid).size(), 0, "front never fires")
	var hits: Array[Dictionary] = _hits_on(m, b.uid)
	assert_eq(hits.size(), 1, "one hit on the Breacher")
	assert_eq(int(hits[0]["shooter_uid"]), back.uid, "from the NEXT unit in line")
	assert_eq(hits[0]["step"], FirefightResolver.STEP_BEAT, "in a later beat (no First Shot)")
	assert_eq(b.armor, 2, "4 - 2")


func test_enemy_first_shot_point_man_trades_in_first_shot_step() -> void:
	var m: MatchState = F.new_match(null, null, F.map())
	var b: RulesUnit = F.place(m, P, F.breacher(), F.LEFT)       # 3
	var epm: RulesUnit = F.place(m, E, F.point_man(), F.LEFT)    # 2, First Shot, 3 Armor
	m.firefight()
	assert_false(epm.is_alive(), "enemy Point Man dies")
	assert_eq(b.armor, 2, "but it ALSO had First Shot: simultaneous, 2 lands")
	var hits: Array[Dictionary] = _hits_on(m, b.uid)
	assert_eq(hits[0]["step"], FirefightResolver.STEP_FIRST_SHOT, "the hit is in the First Shot step")


func test_pick_and_flank_first_shot_leave_point_man_alive() -> void:
	# A First Shot unit with Pick (via Flank Route grant on a Marksman) kills the weakest unit,
	# not the point man; the point man then fires in Main. Correct per rules.
	var m: MatchState = F.new_match(null, null, F.map())
	var mk: RulesUnit = F.place(m, P, F.marksman(), F.LEFT)  # 2, Pick
	mk.add_mod(F.K.GRANT_FIRST_SHOT, 0, m.round_number)
	var front: RulesUnit = F.place(m, E, F.unit("front", 1, 4), F.LEFT)
	var weak: RulesUnit = F.place(m, E, F.unit("weak", 1, 1), F.LEFT)
	m.firefight()
	assert_false(weak.is_alive(), "Pick kills the weakest in the First Shot step")
	assert_eq(_shots_by(m, weak.uid).size(), 0, "which never fires")
	assert_eq(front.armor, 4, "point man untouched")
	assert_eq(mk.armor, 1, "point man fires at the Marksman in Main")


func test_full_round_breacher_from_hand_vs_point_man() -> void:
	# Same as the report but through Deploy -> Reveal -> Firefight with real arrival.
	var p: SideSetup = F.setup([F.breacher()])
	var m: MatchState = F.new_match(p, null, F.map())
	m.sides[P].supply = 7
	var t: RulesUnit = F.place(m, E, F.rifleman(), F.LEFT)
	var res: Dictionary = m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "breacher"), F.LEFT))
	assert_true(res["ok"], "Breacher played")
	m.resolve_round()
	assert_false(t.is_alive(), "point man killed")
	var b: RulesUnit = m.sides[P].line(F.LEFT)[0]
	assert_eq(b.armor, 4, "Breacher untouched after a full round")


func test_enemy_blind_strike_strips_first_shot_so_target_fires_back() -> void:
	# kc-loadout-cut: the old Flashbang's effects on a test-only killstreak: -2 FP and no First Shot
	# this round, in the chosen zone. The player's Breacher then fires in Main with 3, simultaneously.
	var e: SideSetup = F.setup([], F.kestrel())
	var m: MatchState = F.new_match(null, e, F.map())
	F.grant(m, E, F.blind_strike())
	F.place_operator(m, E, F.MID)  # the strike reaches Left (adjacent); no firefight in Mid
	var b: RulesUnit = F.place(m, P, _breacher5(), F.LEFT)  # 5 - 2 = 3
	var t: RulesUnit = F.place(m, E, F.unit("front", 2, 3), F.LEFT)
	assert_true(m.submit(E, RulesIntent.use_item(&"blind_strike", F.LEFT))["ok"], "enemy strike on Left")
	m.resolve_round()
	assert_false(t.is_alive(), "3 still kills it")
	assert_eq(_shots_by(m, b.uid)[0]["step"], FirefightResolver.STEP_BEAT, "but the Breacher fired without First Shot")
	assert_eq(b.armor, 2, "so the target shot back")


func test_shieldman_arriving_front_takes_the_first_shot() -> void:
	# Ruling 6: a Shieldman arriving at Reveal becomes point man; the First Shot hits it (Cover 1)
	# and the old point man, now second in line, fires in Main.
	var en: SideSetup = F.setup([F.shieldman()])
	var m: MatchState = F.new_match(null, en, F.map())
	m.sides[E].supply = 7
	var b: RulesUnit = F.place(m, P, F.breacher(), F.LEFT)
	var old_pm: RulesUnit = F.place(m, E, F.rifleman(), F.LEFT)
	assert_true(m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "shieldman"), F.LEFT))["ok"], "Shieldman played")
	m.resolve_round()
	assert_true(old_pm.is_alive(), "old point man was not the First Shot target any more")
	assert_eq(b.armor, 4 - 2 - 1, "both enemy units hit the Breacher in Main")
