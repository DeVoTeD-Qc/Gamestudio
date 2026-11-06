# test_rules_loadout.gd
# Purpose: p05 activated loadout and Operator respawn (LoadoutRules): uses per match, Operator
#   down / respawn, and the Rulings part 2 engine changes (Tripwire armed before arrivals, full
#   zone returns the card, Flank Route fizzles, negative Armor change). kc-loadout-cut: the
#   P-12 Sidearm, Frag Grenade, Flashbang and their cooldowns are gone (their tests too).
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1


static func _load(id: String) -> LoadoutItem:
	return load("res://data/loadout/%s.tres" % id) as LoadoutItem


func _kit() -> SideSetup:
	return F.setup([], F.kestrel())


func _next_round(m: MatchState) -> void:
	m.resolve_round()
	m.begin_round()


func test_removed_loadout_items_are_gone() -> void:
	for id: String in ["p12_sidearm", "frag_grenade", "flashbang"]:
		assert_false(ResourceLoader.exists("res://data/loadout/%s.tres" % id), "%s.tres deleted" % id)
	var s: SideSetup = SideSetup.new()
	for field: String in ["secondary", "lethal", "tactical"]:
		assert_false(field in s, "SideSetup has no %s" % field)
		assert_false(field in SquadData.new(), "SquadData has no %s" % field)
	assert_false("cooldowns" in RulesSide.new(), "no cooldown state")
	assert_false("cooldown_rounds" in LoadoutItem.new(), "no cooldown field")


func test_uses_per_match() -> void:
	var p: SideSetup = _kit()
	var once: LoadoutItem = F.item("one_shot", DataEnums.LoadoutSlot.KILLSTREAK,
			[F.eff(F.TR.ON_PLAY, F.K.DRAW, F.T.OWNER, F.Z.ANY, 1)])
	once.uses_per_match = 1
	var m: MatchState = F.new_match(p)
	F.grant(m, P, once)
	assert_true(m.submit(P, RulesIntent.use_item(&"one_shot"))["ok"], "first use")
	_next_round(m)
	F.grant(m, P, once)  # earned again
	assert_eq(m.submit(P, RulesIntent.use_item(&"one_shot"))["reason"], "already used this match", "once per match")


# --- Operator down & respawn ------------------------------------------------------------------

func test_operator_down_then_respawn_free_full_armor_any_zone() -> void:
	var m: MatchState = F.new_match(_kit())
	var op: RulesUnit = F.place_operator(m, P, F.MID)
	F.place(m, E, F.unit("big", 20, 20), F.MID)
	m.resolve_round()
	assert_false(op.is_on_board(), "down")
	assert_eq(F.events_of(m, RulesEvent.OPERATOR_DOWN).size(), 1, "logged")
	assert_eq(m.sides[E].eliminations, 1, "the enemy gets +1 elimination")
	m.begin_round()
	F.grant(m, P, F.point_strike())
	assert_eq(m.submit(P, RulesIntent.use_item(&"point_strike", F.LEFT))["reason"], "Operator is not on the board",
			"no Operator-range item while down")
	var supply: int = m.sides[P].supply
	assert_true(m.submit(P, RulesIntent.place_operator(F.RIGHT))["ok"], "respawn in any zone")
	assert_eq(m.sides[P].supply, supply, "for free")
	m.reveal()
	assert_eq([op.zone, op.armor], [F.RIGHT, 7], "full Armor")


func test_respawn_can_wait_a_round() -> void:
	var m: MatchState = F.new_match(_kit())
	var op: RulesUnit = F.place_operator(m, P, F.MID)
	F.place(m, E, F.unit("big", 20, 20), F.MID)
	_next_round(m)
	_next_round(m)
	assert_true(m.sides[P].operator_can_deploy, "still off the board, may deploy")
	assert_true(m.submit(P, RulesIntent.place_operator(F.LEFT))["ok"], "placed in round 3")
	m.reveal()
	assert_eq(op.zone, F.LEFT, "back")


func test_no_respawn_when_disabled() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.MID)
	F.place(m, E, F.unit("big", 20, 20), F.MID)
	m.respawn_enabled = false
	_next_round(m)
	assert_false(m.sides[P].operator_can_deploy, "Detonator-style: no respawn")
	assert_false(m.submit(P, RulesIntent.place_operator(F.LEFT))["ok"], "can't place")


func test_respawn_into_a_tripwire_triggers_it() -> void:
	var e: SideSetup = F.setup([F.tripwire()])
	var m: MatchState = F.new_match(_kit(), e)
	var op: RulesUnit = F.place_operator(m, P, F.MID)
	F.place(m, E, F.unit("big", 20, 20), F.MID)
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "tripwire_charge"), F.LEFT))
	_next_round(m)
	m.submit(P, RulesIntent.place_operator(F.LEFT))
	m.reveal()
	assert_eq(op.armor, 7 - 3, "the respawned Operator sets off the trap")


# --- Rulings part 2 engine changes --------------------------------------------------------------

func test_tripwire_armed_before_arrivals_on_deploy_resolves_first() -> void:
	# Rulings part 2 #2: the trap catches same-Reveal arrivals; On Deploy before the trap.
	var p: SideSetup = F.setup([F.tripwire()])
	var e: SideSetup = F.setup([F.recon_specialist()])
	var m: MatchState = F.new_match(p, e)
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "recon_specialist"), F.RIGHT))  # initiative: player (tie)
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "tripwire_charge"), F.RIGHT))
	m.reveal()
	var types: Array = m.events.map(func(ev: Dictionary) -> StringName: return ev["type"])
	var placed: int = types.find(RulesEvent.EQUIPMENT_PLACED)
	var arrived: int = types.find(RulesEvent.UNIT_ARRIVED)
	var triggered: int = types.find(RulesEvent.EQUIPMENT_TRIGGERED)
	assert_true(placed >= 0 and placed < arrived and arrived < triggered, "placed -> arrival -> trap")
	assert_eq(m.sides[E].intel_reveals.get(2, []), [F.RIGHT], "On Deploy resolved (before the trap killed it)")
	assert_eq(m.sides[E].line(F.RIGHT).size(), 0, "3 damage kills the 1/2 Recon Specialist")


func test_tripwire_catches_flank_route_and_sentry_arrivals() -> void:
	var e: SideSetup = F.setup([F.tripwire(), F.tripwire()])
	var p: SideSetup = F.setup([F.flank_route()])
	p.killstreaks.assign([_load("sentry_turret")])
	var m: MatchState = F.new_match(p, e)
	m.sides[E].supply = 4
	var mover: RulesUnit = F.place(m, P, F.unit("mover", 0, 9), F.LEFT)
	var wires: Array = m.sides[E].hand.map(func(c: RulesCard) -> int: return c.uid)
	m.submit(E, RulesIntent.play_card(wires[0], F.MID))
	m.submit(E, RulesIntent.play_card(wires[1], F.RIGHT))
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "flank_route"), -1, mover.uid, F.MID))
	StreakTracker.grant(m, P, &"sentry_turret")
	m.submit(P, RulesIntent.use_item(&"sentry_turret", F.RIGHT))
	m.reveal()
	assert_eq(mover.armor, 6, "moved in and took 3")
	var sentry: RulesUnit = m.sides[P].line(F.RIGHT)[0]
	assert_eq(sentry.armor, 4 - (3 - 1), "the summoned Sentry sets off the other one (Cover 1)")
	assert_eq([m.sides[E].equipment[F.MID].size(), m.sides[E].equipment[F.RIGHT].size()], [0, 0], "both consumed")


func test_unit_returns_to_hand_when_zone_still_full_no_refund() -> void:
	var m: MatchState = F.new_match(F.setup([F.rifleman()]))
	for i: int in 3:
		F.place(m, P, F.unit("u%d" % i, 0, 9), F.LEFT)
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "rifleman"), F.LEFT))["ok"], "4th slot")
	F.place(m, P, F.unit("squatter", 0, 9), F.LEFT)  # zone filled before Reveal
	m.reveal()
	assert_true(F.hand_uid(m, P, "rifleman") >= 0, "back in hand")
	assert_eq(m.sides[P].supply, 1, "Supply not refunded")
	var ev: Array[Dictionary] = F.events_of(m, RulesEvent.CARD_RETURNED)
	assert_eq([ev.size(), ev[0]["card_id"], ev[0]["zone"]], [1, &"rifleman", &"left"], "logged")


func test_flank_route_into_full_zone_fizzles() -> void:
	var m: MatchState = F.new_match(F.setup([F.flank_route()]))
	var mover: RulesUnit = F.place(m, P, F.unit("mover", 0, 9), F.LEFT)
	for i: int in 4:
		F.place(m, P, F.unit("m%d" % i, 0, 9), F.MID)
	assert_true(m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "flank_route"), -1, mover.uid, F.MID))["ok"], "queued")
	m.reveal()
	assert_eq(mover.zone, F.LEFT, "didn't move")
	var wasted: Array = F.events_of(m, RulesEvent.EFFECT_WASTED).filter(func(ev: Dictionary) -> bool: return ev["kind"] == "MOVE_UNIT")
	assert_eq(wasted.size(), 1, "fizzled")


func test_negative_armor_change_is_not_damage() -> void:
	var weaken: CardData = F.tactic("weaken", 0, [F.eff(F.TR.ON_PLAY, F.K.MODIFY_ARMOR, F.T.ALL_ENEMIES, F.Z.CHOSEN_ZONE, -5)])
	var m: MatchState = F.new_match(F.setup([weaken]))
	var u: RulesUnit = F.place(m, E, F.unit("u", 0, 2), F.MID)
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "weaken"), F.MID))
	m.reveal()
	assert_eq([u.is_alive(), u.armor], [true, 1], "never below 1")
	assert_eq(F.events_of(m, RulesEvent.UNIT_ELIMINATED).size(), 0, "no elimination, no credit")
