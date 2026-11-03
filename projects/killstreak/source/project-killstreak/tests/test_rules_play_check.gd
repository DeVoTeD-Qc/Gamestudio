# test_rules_play_check.gd
# Purpose: f02 engine play-check API. MatchState.can_submit() runs exactly submit()'s checks
#   without changing the state and returns a stable reason code; submit() returns the same
#   code when it refuses. One test per code family, plus legal_targets() / check_use() /
#   needs_unit_target() and the mulligan codes.
# Author: Mechanics Developer Agent (f02)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1


static func _load(id: String) -> LoadoutItem:
	return load("res://data/loadout/%s.tres" % id) as LoadoutItem


func _kit(deck: Array = []) -> SideSetup:
	var p: SideSetup = F.setup(deck, F.kestrel())
	p.secondary = _load("p12_sidearm")
	p.lethal = _load("frag_grenade")
	p.tactical = _load("flashbang")
	p.killstreaks.assign([_load("recon_drone"), _load("mortar_barrage")])
	return p


## can_submit gives `code`, changes nothing, and submit() then refuses with the same result.
func _expect(m: MatchState, intent: Dictionary, code: StringName, label: String, side: int = P) -> Dictionary:
	var before: Array = [m.sides[side].plays.size(), m.sides[side].supply, m.sides[side].hand.size(), m.events.size()]
	var c: Dictionary = m.can_submit(side, intent)
	assert_eq([c["ok"], c["code"]], [false, code], "%s: can_submit code (%s)" % [label, c["reason"]])
	assert_eq([m.sides[side].plays.size(), m.sides[side].supply, m.sides[side].hand.size(), m.events.size()], before,
			"%s: can_submit changed nothing" % label)
	var r: Dictionary = m.submit(side, intent)
	assert_eq(r, c, "%s: submit refuses with the same result" % label)
	return c


func _expect_ok(m: MatchState, intent: Dictionary, label: String, side: int = P) -> void:
	var plays: int = m.sides[side].plays.size()
	var c: Dictionary = m.can_submit(side, intent)
	assert_eq([c["ok"], c["code"]], [true, &"ok"], "%s: can_submit ok (%s)" % [label, c["reason"]])
	assert_eq(m.sides[side].plays.size(), plays, "%s: can_submit queued nothing" % label)
	var r: Dictionary = m.submit(side, intent)
	assert_true(r["ok"], "%s: submit accepts" % label)
	assert_eq(r["code"], &"ok", "%s: submit code ok" % label)


# --- Any intent ------------------------------------------------------------------------------

func test_phase_ready_side_and_unknown_codes() -> void:
	var m: MatchState = F.new_match(F.setup([F.rifleman()]))
	var uid: int = F.hand_uid(m, P, "rifleman")
	_expect(m, {"type": &"dance"}, &"unknown_intent", "unknown")
	assert_eq(m.can_submit(7, RulesIntent.play_card(uid, F.LEFT))["code"], &"bad_side", "bad side")
	m.set_ready(P)
	_expect(m, RulesIntent.play_card(uid, F.LEFT), &"already_ready", "READY")
	m.set_ready(P, false)
	m.phase = MatchState.Phase.REVEAL
	_expect(m, RulesIntent.play_card(uid, F.LEFT), &"wrong_phase", "Reveal")
	m.phase = MatchState.Phase.DEPLOY
	_expect_ok(m, RulesIntent.play_card(uid, F.LEFT), "back in Deploy")


# --- Cards -----------------------------------------------------------------------------------

func test_card_codes_hand_supply_zone_full() -> void:
	var m: MatchState = F.new_match(F.setup([F.rifleman(), F.breacher(), F.tripwire()]))
	var rifle: int = F.hand_uid(m, P, "rifleman")
	_expect(m, RulesIntent.play_card(9999, F.LEFT), &"not_in_hand", "not in hand")
	m.sides[P].supply = 2
	var c: Dictionary = _expect(m, RulesIntent.play_card(F.hand_uid(m, P, "breacher"), F.LEFT), &"not_enough_supply", "Breacher 3 > 2")
	assert_eq([c["data"]["cost"], c["data"]["supply"], c["reason"]], [3, 2, "not enough Supply"], "data + legacy reason")
	_expect(m, RulesIntent.play_card(rifle, -1), &"no_zone", "unit without a zone")
	_expect(m, RulesIntent.play_card(F.hand_uid(m, P, "tripwire_charge"), -1), &"no_zone", "equipment without a zone")
	for i: int in m.config.zone_capacity:
		F.place(m, P, F.unit("u%d" % i, 1, 1), F.MID)
	c = _expect(m, RulesIntent.play_card(rifle, F.MID), &"zone_full", "full Mid")
	assert_eq([c["data"]["zone"], c["data"]["capacity"], c["reason"]], [F.MID, m.config.zone_capacity, "zone full"], "zone_full data")
	_expect_ok(m, RulesIntent.play_card(rifle, F.LEFT), "Left is free")


func test_tactic_zone_and_target_codes() -> void:
	var m: MatchState = F.new_match(F.setup([F.suppressing_fire(), F.flank_route()]))
	m.sides[P].supply = 9
	_expect(m, RulesIntent.play_card(F.hand_uid(m, P, "suppressing_fire"), -1), &"no_zone", "CHOSEN_ZONE needs a zone")
	var flank: int = F.hand_uid(m, P, "flank_route")
	var c: Dictionary = _expect(m, RulesIntent.play_card(flank, F.MID), &"no_target", "Flank Route without a unit")
	assert_eq(c["data"]["want"], &"friendly", "wants a friendly unit")
	var mover: RulesUnit = F.place(m, P, F.unit("mover", 1, 9), F.LEFT)
	_expect(m, RulesIntent.play_card(flank, F.LEFT, mover.uid, F.LEFT), &"same_zone", "move to its own zone")
	c = _expect(m, RulesIntent.play_card(flank, F.RIGHT, mover.uid, F.RIGHT), &"not_adjacent", "flanks are not adjacent")
	assert_eq(c["data"]["from_zone"], F.LEFT, "from_zone data")
	# A move into a full zone is legal (it fizzles at Reveal) but flagged.
	for i: int in m.config.zone_capacity:
		F.place(m, P, F.unit("m%d" % i, 1, 1), F.MID)
	var w: Dictionary = m.can_submit(P, RulesIntent.play_card(flank, F.MID, mover.uid, F.MID))
	assert_eq([w["ok"], w["data"].get("warnings", [])], [true, [&"dest_full"]], "dest_full warning")


# --- Items -----------------------------------------------------------------------------------

func test_item_codes_operator_range_target() -> void:
	var m: MatchState = F.new_match(_kit())
	var a: RulesUnit = F.place(m, E, F.unit("a", 0, 9), F.MID)
	var far: RulesUnit = F.place(m, E, F.unit("far", 0, 9), F.RIGHT)
	_expect(m, RulesIntent.use_item(&"gunship"), &"not_in_loadout", "not in loadout")
	_expect(m, RulesIntent.use_item(&"frag_grenade", F.MID), &"operator_not_placed", "Frag without an Operator")
	_expect(m, RulesIntent.use_item(&"p12_sidearm", -1, a.uid), &"operator_not_placed", "Sidearm without an Operator")
	F.place_operator(m, P, F.LEFT)
	_expect(m, RulesIntent.use_item(&"frag_grenade", -1), &"no_zone", "Frag needs a zone")
	var c: Dictionary = _expect(m, RulesIntent.use_item(&"frag_grenade", F.RIGHT), &"out_of_range", "Frag two zones away")
	assert_eq(c["data"]["operator_zone"], F.LEFT, "operator_zone data")
	_expect(m, RulesIntent.use_item(&"p12_sidearm", -1, -1), &"no_target", "Sidearm without a target")
	_expect(m, RulesIntent.use_item(&"p12_sidearm", -1, far.uid), &"target_out_of_range", "Sidearm at Right from Left")
	_expect(m, RulesIntent.use_item(&"p12_sidearm", -1, a.uid), &"target_out_of_range", "Sidearm at Mid from Left")
	var near: RulesUnit = F.place(m, E, F.unit("near", 0, 9), F.LEFT)
	m.sides[P].supply = 0
	c = _expect(m, RulesIntent.use_item(&"p12_sidearm", -1, near.uid), &"not_enough_supply", "Sidearm costs 1")
	m.sides[P].supply = 3
	_expect_ok(m, RulesIntent.use_item(&"p12_sidearm", -1, near.uid), "Sidearm in the Operator's zone")
	c = _expect(m, RulesIntent.use_item(&"p12_sidearm", -1, near.uid), &"no_uses_left", "once per round")
	assert_eq(c["data"]["per"], &"round", "per round")
	_expect_ok(m, RulesIntent.use_item(&"frag_grenade", F.MID), "Frag adjacent")
	c = _expect(m, RulesIntent.use_item(&"frag_grenade", F.LEFT), &"on_cooldown", "Frag again")
	assert_eq(c["data"]["rounds"], 3, "ready in 3 rounds")


func test_killstreak_not_in_tray_then_called_in() -> void:
	var m: MatchState = F.new_match(_kit())
	_expect(m, RulesIntent.use_item(&"mortar_barrage", F.MID), &"not_in_tray", "not earned")
	StreakTracker.grant(m, P, &"mortar_barrage")
	_expect(m, RulesIntent.use_item(&"mortar_barrage", -1), &"no_zone", "Mortar needs a zone")
	assert_eq(m.check_use(P, &"mortar_barrage")["ok"], true, "usable once in the tray")
	_expect_ok(m, RulesIntent.use_item(&"mortar_barrage", F.MID), "Mortar on Mid")
	assert_false(&"mortar_barrage" in m.sides[P].streak_tray, "left the tray")
	_expect(m, RulesIntent.use_item(&"mortar_barrage", F.MID), &"not_in_tray", "used up")


func test_uses_per_match_code() -> void:
	var once: LoadoutItem = F.item("one_shot", DataEnums.LoadoutSlot.LETHAL, [
			F.eff(F.TR.ON_PLAY, F.K.DAMAGE, F.T.ALL_ENEMIES, F.Z.CHOSEN_ZONE, 1)])
	once.uses_per_match = 1
	var p: SideSetup = F.setup()
	p.lethal = once
	var m: MatchState = F.new_match(p)
	_expect_ok(m, RulesIntent.use_item(&"one_shot", F.MID), "first use")
	m.resolve_round()
	m.begin_round()
	var c: Dictionary = _expect(m, RulesIntent.use_item(&"one_shot", F.MID), &"no_uses_left", "second use")
	assert_eq([c["data"]["per"], c["reason"]], [&"match", "already used this match"], "per match")


# --- Operator --------------------------------------------------------------------------------

func test_operator_codes() -> void:
	var m: MatchState = F.new_match(F.setup())
	_expect(m, RulesIntent.place_operator(F.MID), &"no_operator", "no Operator to place")
	_expect(m, RulesIntent.rotate(F.MID), &"no_operator", "no Operator to rotate")
	m = F.new_match(F.setup([], F.kestrel()))
	_expect(m, RulesIntent.rotate(F.MID), &"operator_not_placed", "rotate before placing")
	_expect(m, RulesIntent.place_operator(-1), &"no_zone", "place needs a zone")
	_expect_ok(m, RulesIntent.place_operator(F.LEFT), "place Left")
	_expect(m, RulesIntent.place_operator(F.MID), &"already_placed", "once per Deploy")
	_expect(m, RulesIntent.rotate(F.LEFT), &"same_zone", "rotate to where it is")
	_expect(m, RulesIntent.rotate(F.RIGHT), &"not_adjacent", "Left -> Right")
	_expect_ok(m, RulesIntent.rotate(F.MID), "Left -> Mid")
	var c: Dictionary = _expect(m, RulesIntent.rotate(F.RIGHT), &"no_rotations_left", "one Rotation")
	assert_eq(c["data"]["allowed"], 1, "allowed data")
	m.resolve_round()
	m.begin_round()
	_expect(m, RulesIntent.place_operator(F.LEFT), &"cant_place", "on the board: can't be placed")
	for i: int in m.config.zone_capacity:
		F.place(m, P, F.unit("r%d" % i, 1, 1), F.RIGHT)
	_expect(m, RulesIntent.rotate(F.RIGHT), &"zone_full", "rotate into a full zone")


# --- legal_targets / check_use / needs_unit_target ---------------------------------------------

func test_legal_targets_match_submit() -> void:
	var m: MatchState = F.new_match(_kit([F.rifleman(), F.flank_route(), F.ammo_resupply()]))
	m.sides[P].supply = 9
	var a: RulesUnit = F.place(m, E, F.unit("a", 0, 9), F.MID)
	F.place(m, E, F.unit("b", 0, 9), F.RIGHT)
	assert_eq(m.legal_targets(P, &"frag_grenade"), [] as Array[Dictionary], "no Operator: Frag has no target")
	assert_eq(m.check_use(P, &"frag_grenade")["code"], &"operator_not_placed", "check_use says why")
	F.place_operator(m, P, F.MID)
	var zones: Array = m.legal_targets(P, &"frag_grenade").map(func(t: Dictionary) -> int: return t["zone"])
	assert_eq(zones, [0, 1, 2], "Mid Operator: Frag reaches every zone")
	var sidearm: Array[Dictionary] = m.legal_targets(P, &"p12_sidearm")
	assert_eq(sidearm.map(func(t: Dictionary) -> int: return t["target_uid"]).filter(func(u: int) -> bool: return u != a.uid), [],
			"Sidearm: only the enemy in the Operator's zone")
	assert_false(sidearm.is_empty(), "Sidearm has a target")
	assert_eq(m.needs_unit_target(P, &"p12_sidearm"), &"enemy", "Sidearm needs an enemy")
	assert_eq(m.needs_unit_target(P, &"frag_grenade"), &"", "Frag needs a zone only")
	var rifle: int = F.hand_uid(m, P, "rifleman")
	assert_eq(m.legal_targets(P, rifle).map(func(t: Dictionary) -> int: return t["zone"]), [0, 1, 2], "unit: any zone")
	var draw: Array[Dictionary] = m.legal_targets(P, F.hand_uid(m, P, "ammo_resupply"))
	assert_true(draw.any(func(t: Dictionary) -> bool: return t["zone"] == -1), "no-zone tactic: zone -1 is legal")
	var flank: int = F.hand_uid(m, P, "flank_route")
	assert_eq(m.needs_unit_target(P, flank), &"friendly", "Flank Route needs a friendly")
	var op_uid: int = m.sides[P].operator_unit.uid
	assert_eq(m.legal_targets(P, flank).map(func(t: Dictionary) -> int: return t["target_uid"]), [op_uid, op_uid],
			"only the Operator can be moved yet")
	m.submit(P, RulesIntent.play_card(rifle, F.LEFT))
	var moves: Array = m.legal_targets(P, flank).filter(func(t: Dictionary) -> bool: return t["target_uid"] == rifle)
	assert_eq(moves, [{"zone": 1, "target_uid": rifle}], "queued Rifleman can move Left -> Mid only")
	# Every legal target is accepted by submit().
	for t: Dictionary in m.legal_targets(P, &"frag_grenade"):
		assert_true(m.can_submit(P, RulesIntent.use_item(&"frag_grenade", t["zone"], t["target_uid"]))["ok"], "legal -> ok %s" % t)
	assert_eq(m.legal_targets(P, &"operator").map(func(t: Dictionary) -> int: return t["zone"]), [0, 2], "Rotation targets")


func test_check_use_reports_shared_refusal() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.MID)
	m.sides[P].supply = 0
	assert_eq(m.check_use(P, &"p12_sidearm")["code"], &"not_enough_supply", "Sidearm without Supply")
	assert_eq(m.check_use(P, &"recon_drone")["code"], &"not_in_tray", "Recon Drone not earned")
	m.sides[P].supply = 2
	assert_eq(m.check_use(P, &"p12_sidearm")["code"], &"no_target", "no enemy on the board")
	F.place(m, E, F.unit("w", 0, 9), F.LEFT)
	assert_eq(m.check_use(P, &"p12_sidearm")["code"], &"target_out_of_range", "only an enemy outside the Operator's zone")
	F.place(m, E, F.unit("x", 0, 9), F.MID)
	assert_true(m.check_use(P, &"p12_sidearm")["ok"], "an enemy in Mid")
	StreakTracker.grant(m, P, &"recon_drone")
	assert_eq(m.legal_targets(P, &"recon_drone").size(), 4, "Recon Drone: no target needed (any zone value works)")


# --- Mulligan ----------------------------------------------------------------------------------

func test_mulligan_codes() -> void:
	var deck: Array = []
	for i: int in 10:
		deck.append(F.rifleman())
	var m: MatchState = F.new_match(F.setup(deck))
	var uid: int = m.sides[P].hand[0].uid
	assert_eq(m.can_mulligan(P, [9999])["code"], &"not_in_hand", "unknown card")
	assert_true(m.can_mulligan(P, [uid])["ok"], "free mulligan in Round 1")
	m.submit(P, RulesIntent.play_card(m.sides[P].hand[1].uid, F.LEFT))
	assert_eq(m.mulligan(P, [uid])["code"], &"already_played", "only before plays")
	m.undo_last(P)
	var hand_size: int = m.sides[P].hand.size()
	assert_eq(m.mulligan(P, [uid])["code"], &"ok", "mulligan")
	assert_eq(m.sides[P].hand.size(), hand_size, "same hand size")
	assert_eq(m.mulligan(P, [])["code"], &"no_mulligan", "only one")
	m.phase = MatchState.Phase.REVEAL
	assert_eq(m.can_mulligan(P)["code"], &"wrong_phase", "not in Deploy")
	assert_eq(m.undo_last(P)["code"], &"nothing_to_undo", "undo code")
