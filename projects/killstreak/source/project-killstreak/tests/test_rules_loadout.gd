# test_rules_loadout.gd
# Purpose: p05 activated loadout and Operator respawn (LoadoutRules): P-12 Sidearm,
#   Frag Grenade and Flashbang from real data (Supply, uses per round, Cooldown 3 =
#   ready again in round N+3, undo refunds), COOLDOWN_MOD, uses per match, Operator
#   down / respawn, and the Rulings part 2 engine changes (Tripwire armed before
#   arrivals, full zone returns the card, Flank Route fizzles, negative Armor change).
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1


static func _load(id: String) -> LoadoutItem:
	return load("res://data/loadout/%s.tres" % id) as LoadoutItem


func _kit() -> SideSetup:
	var p: SideSetup = F.setup([], F.kestrel())
	p.secondary = _load("p12_sidearm")
	p.lethal = _load("frag_grenade")
	p.tactical = _load("flashbang")
	return p


func _next_round(m: MatchState) -> void:
	m.resolve_round()
	m.begin_round()


# --- Secondary -------------------------------------------------------------------------------

func test_sidearm_one_supply_one_damage_once_per_round_counts_for_streak() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.MID)
	var a: RulesUnit = F.place(m, E, F.unit("a", 0, 1), F.MID)
	var b: RulesUnit = F.place(m, E, F.unit("b", 0, 9), F.MID)
	assert_true(m.submit(P, RulesIntent.use_item(&"p12_sidearm", -1, a.uid))["ok"], "Sidearm on a")
	assert_eq(m.sides[P].supply, 1, "costs 1 Supply")
	var r: Dictionary = m.submit(P, RulesIntent.use_item(&"p12_sidearm", -1, b.uid))
	assert_eq([r["ok"], r["reason"]], [false, "already used this round"], "once per round")
	m.reveal()
	assert_false(a.is_alive(), "1 damage")
	var rec: Dictionary = F.events_of(m, RulesEvent.UNIT_ELIMINATED)[0]
	assert_eq(rec["source_kind"], MatchState.SRC_SECONDARY, "Secondary kill")
	m.firefight()
	m.score()
	assert_eq(m.sides[P].streak, 1, "counts for the streak")
	m.begin_round()
	assert_true(m.submit(P, RulesIntent.use_item(&"p12_sidearm", -1, b.uid))["ok"], "next round again (no cooldown)")


func test_sidearm_needs_supply_and_undo_refunds_the_use() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.MID)
	var a: RulesUnit = F.place(m, E, F.unit("a", 0, 9), F.MID)
	m.sides[P].supply = 0
	assert_eq(m.submit(P, RulesIntent.use_item(&"p12_sidearm", -1, a.uid))["reason"], "not enough Supply", "Supply")
	m.sides[P].supply = 1
	assert_true(m.submit(P, RulesIntent.use_item(&"p12_sidearm", -1, a.uid))["ok"], "used")
	assert_true(m.undo_last(P)["ok"], "undo")
	assert_eq(m.sides[P].supply, 1, "Supply back")
	assert_true(m.submit(P, RulesIntent.use_item(&"p12_sidearm", -1, a.uid))["ok"], "use back")


func test_sidearm_wasted_if_target_not_in_operator_zone() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.MID)
	var far: RulesUnit = F.place(m, E, F.unit("far", 0, 9), F.LEFT)
	m.submit(P, RulesIntent.use_item(&"p12_sidearm", -1, far.uid))
	m.reveal()
	assert_eq(far.armor, 9, "only an enemy in the Operator's zone")


# --- Lethal / Tactical cooldowns --------------------------------------------------------------

func test_frag_cooldown_ready_again_in_round_n_plus_3() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.LEFT)
	assert_true(m.submit(P, RulesIntent.use_item(&"frag_grenade", F.MID))["ok"], "round 1: used")
	assert_eq(m.sides[P].supply, 2, "0 Supply")
	_next_round(m)
	assert_eq(m.submit(P, RulesIntent.use_item(&"frag_grenade", F.MID))["reason"], "on cooldown (ready in 2 rounds)", "round 2")
	_next_round(m)
	assert_eq(m.submit(P, RulesIntent.use_item(&"frag_grenade", F.MID))["reason"], "on cooldown (ready in 1 round)", "round 3")
	_next_round(m)
	assert_eq(F.events_of(m, RulesEvent.ITEM_READY).size(), 1, "ready event at round 4 Briefing")
	assert_true(m.submit(P, RulesIntent.use_item(&"frag_grenade", F.MID))["ok"], "round 4 = N+3: ready")


func test_flashbang_cooldown_independent_of_frag_and_undo_refunds() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.MID)
	assert_true(m.submit(P, RulesIntent.use_item(&"flashbang", F.MID))["ok"], "Flashbang")
	assert_true(m.submit(P, RulesIntent.use_item(&"frag_grenade", F.MID))["ok"], "Frag the same round")
	assert_true(m.undo_last(P)["ok"], "undo Frag")
	assert_eq(LoadoutRules.cooldown_left(m, P, _load("frag_grenade")), 0, "Frag cooldown refunded")
	assert_eq(LoadoutRules.cooldown_left(m, P, _load("flashbang")), 3, "Flashbang still on Cooldown 3")
	_next_round(m)
	assert_true(m.submit(P, RulesIntent.use_item(&"frag_grenade", F.MID))["ok"], "Frag usable round 2")
	assert_false(m.submit(P, RulesIntent.use_item(&"flashbang", F.MID))["ok"], "Flashbang not")


func test_frag_and_flashbang_real_data_effects() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.LEFT)
	var pm: RulesUnit = F.place(m, E, F.unit("pm", 0, 2), F.MID)
	var second: RulesUnit = F.place(m, E, F.unit("second", 5, 5, F.W.NONE, {"first_shot": true}), F.MID)
	m.submit(P, RulesIntent.use_item(&"frag_grenade", F.MID))
	m.submit(P, RulesIntent.use_item(&"flashbang", F.MID))
	m.reveal()
	assert_eq([pm.is_alive(), second.armor], [false, 4], "Frag 2 + 1")
	assert_eq([m.firepower_of(second), m.has_first_shot(second)], [3, false], "Flashbang -2 FP, no First Shot")
	assert_eq(m.sides[P].streak, 0, "streak only moves in the Score step")
	m.firefight()
	m.score()
	assert_eq(m.sides[P].streak, 1, "the Lethal kill counts")


func test_cooldown_mod_perk_shortens_cooldowns() -> void:
	var p: SideSetup = _kit()
	var quick: LoadoutItem = F.item("quick_hands", DataEnums.LoadoutSlot.PERK,
			[F.eff(F.TR.PASSIVE, F.K.COOLDOWN_MOD, F.T.OWNER, F.Z.ANY, -1)])
	p.perks.append(quick)
	var m: MatchState = F.new_match(p)
	F.place_operator(m, P, F.MID)
	assert_eq(LoadoutRules.cooldown_for(m, P, _load("frag_grenade")), 2, "3 - 1")
	assert_eq(LoadoutRules.cooldown_for(m, P, _load("p12_sidearm")), 0, "no cooldown stays none")
	m.submit(P, RulesIntent.use_item(&"frag_grenade", F.MID))
	_next_round(m)
	assert_false(m.submit(P, RulesIntent.use_item(&"frag_grenade", F.MID))["ok"], "round 2: cooling")
	_next_round(m)
	assert_true(m.submit(P, RulesIntent.use_item(&"frag_grenade", F.MID))["ok"], "round 3 = N+2 with the perk")


func test_uses_per_match() -> void:
	var p: SideSetup = _kit()
	var once: LoadoutItem = F.item("one_shot", DataEnums.LoadoutSlot.SECONDARY,
			[F.eff(F.TR.ON_PLAY, F.K.DRAW, F.T.OWNER, F.Z.ANY, 1)])
	once.uses_per_match = 1
	p.secondary = once
	var m: MatchState = F.new_match(p)
	assert_true(m.submit(P, RulesIntent.use_item(&"one_shot"))["ok"], "first use")
	_next_round(m)
	assert_eq(m.submit(P, RulesIntent.use_item(&"one_shot"))["reason"], "already used this match", "once per match")


# --- Operator down & respawn ------------------------------------------------------------------

func test_operator_down_then_respawn_free_full_armor_any_zone_keeps_cooldowns() -> void:
	var m: MatchState = F.new_match(_kit())
	var op: RulesUnit = F.place_operator(m, P, F.MID)
	m.submit(P, RulesIntent.use_item(&"frag_grenade", F.MID))
	F.place(m, E, F.unit("big", 20, 20), F.MID)
	m.resolve_round()
	assert_false(op.is_on_board(), "down")
	assert_eq(F.events_of(m, RulesEvent.OPERATOR_DOWN).size(), 1, "logged")
	assert_eq(m.sides[E].eliminations, 1, "the enemy gets +1 elimination")
	m.begin_round()
	assert_false(m.submit(P, RulesIntent.use_item(&"frag_grenade", F.LEFT))["ok"], "cooldowns survive going down")
	assert_eq(m.submit(P, RulesIntent.use_item(&"p12_sidearm", -1, 0))["reason"], "Operator is not on the board", "no Sidearm while down")
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
