# test_rules_streaks.gd
# Purpose: p05 streak meter and Streak Tray (StreakTracker): the streak resets only
#   when your Operator goes down, after that round's eliminations count; what counts
#   for the streak; thresholds, once per life, the tray; the 4 prototype killstreaks
#   (real data) and Streak Discipline / Objective Focus.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1


static func _load(id: String) -> LoadoutItem:
	return load("res://data/loadout/%s.tres" % id) as LoadoutItem


## Player kit with the real starter killstreaks (Recon 2 / Mortar 3 / Helo 5) + Sentry 4.
func _kit(deck: Array = [], perks: Array = []) -> SideSetup:
	var p: SideSetup = F.setup(deck, F.kestrel())
	p.killstreaks.assign([_load("recon_drone"), _load("mortar_barrage"), _load("sentry_turret"), _load("attack_helo")])
	for id: String in perks:
		p.perks.append(_load(id))
	return p


## n player killers vs n 1-Armor enemies in `zone` (all die in the Main step).
func _kills(m: MatchState, n: int, zone: int = F.LEFT) -> void:
	for i: int in n:
		F.place(m, P, F.unit("k%d" % i, 5, 20), zone)
		F.place(m, E, F.unit("v%d" % i, 0, 1), zone)


func _my_changes(m: MatchState) -> Array:
	return F.events_of(m, RulesEvent.STREAK_CHANGED).filter(func(ev: Dictionary) -> bool: return ev["side"] == &"player")


# --- The meter --------------------------------------------------------------------------

func test_squad_losses_never_change_the_streak() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.RIGHT)
	m.sides[P].streak = 1
	for r: int in 3:
		F.place(m, P, F.unit("loss%d" % r, 0, 1), F.LEFT)
		F.place(m, E, F.unit("e%d" % r, 5, 20), F.LEFT)
		m.resolve_round()
		assert_eq(m.sides[P].streak, 1, "round %d: squad loss keeps the streak" % (r + 1))
		m.begin_round()
	assert_eq(m.sides[E].eliminations, 3, "the enemy still got the kills")
	assert_eq(_my_changes(m).size(), 0, "no streak change logged")


func test_operator_down_resets_after_that_rounds_eliminations_count() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.MID)
	m.sides[P].streak = 1
	_kills(m, 2, F.LEFT)
	F.place(m, E, F.unit("op_killer", 20, 20), F.MID)
	m.resolve_round()
	var last: Dictionary = _my_changes(m).back()
	assert_eq([last["before"], last["gained"], last["reset"], last["streak"]], [1, 2, true, 0], "2 kills counted, then reset")
	assert_eq(last["earned"], [&"recon_drone", &"mortar_barrage"], "the trade still pays out (streak 3 before the reset)")
	assert_eq(m.sides[P].streak_tray, [&"recon_drone", &"mortar_barrage"], "kept in the tray after going down")
	assert_eq(m.sides[P].earned_this_life, [], "a new life starts")


func test_enemy_operator_down_gives_one_and_resets_their_streak() -> void:
	var e: SideSetup = F.setup([], F.primary("enemy_op", 0, 2))
	var m: MatchState = F.new_match(_kit(), e)
	F.place_operator(m, E, F.MID)
	m.sides[E].streak = 4
	F.place(m, P, F.unit("hunter", 5, 9), F.MID)
	m.resolve_round()
	assert_eq([m.sides[P].streak, m.sides[P].eliminations], [1, 1], "+1 elimination and streak for the Operator down")
	assert_eq(m.sides[E].streak, 0, "their streak resets")


func test_operator_kill_sources_count_lethal_secondary_tactic_equipment_on_down() -> void:
	# Rulings part 2 #14: units (incl. On Down), Operator, Secondary, Lethal, Tactics, Equipment.
	assert_true(StreakTracker.EQUIPMENT_AND_ON_DOWN_COUNT_FOR_STREAK, "the p03 open question is ruled YES")
	var p: SideSetup = F.setup([F.tripwire()], F.kestrel())
	var e: SideSetup = F.setup([F.unit("walker", 0, 3)])
	var m: MatchState = F.new_match(p, e)
	F.place(m, P, F.demolitions(), F.LEFT)
	F.place(m, E, F.unit("demo_killer", 4, 3), F.LEFT)  # kills the Demo, dies to its On Down
	m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "tripwire_charge"), F.RIGHT))
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "walker"), F.RIGHT))
	m.resolve_round()
	var kinds: Array = F.events_of(m, RulesEvent.UNIT_ELIMINATED).filter(
			func(ev: Dictionary) -> bool: return ev["by_side"] == &"player").map(
			func(ev: Dictionary) -> StringName: return ev["source_kind"])
	assert_eq(kinds, [MatchState.SRC_EQUIPMENT, MatchState.SRC_ON_DOWN], "Tripwire + On Down eliminations")
	assert_eq(m.sides[P].streak, 2, "both count for the streak")


func test_killstreak_and_sentry_eliminations_give_no_streak() -> void:
	var m: MatchState = F.new_match(_kit())
	StreakTracker.grant(m, P, &"mortar_barrage")
	StreakTracker.grant(m, P, &"sentry_turret")
	F.place(m, E, F.unit("mortared", 0, 2), F.RIGHT)
	F.place(m, E, F.unit("turreted", 0, 2), F.MID)
	assert_true(m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.RIGHT))["ok"], "Mortar")
	assert_true(m.submit(P, RulesIntent.use_item(&"sentry_turret", F.MID))["ok"], "Sentry")
	m.resolve_round()
	assert_eq(m.sides[P].eliminations, 2, "both credited for the mode")
	assert_eq(m.sides[P].streak, 0, "neither counts for the streak")


# --- Thresholds and the Streak Tray ---------------------------------------------------------

func test_thresholds_fill_the_tray_once_per_life() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.RIGHT)
	_kills(m, 2)
	m.resolve_round()
	assert_eq(m.sides[P].streak_tray, [&"recon_drone"], "streak 2 -> Recon Drone")
	assert_eq(F.events_of(m, RulesEvent.KILLSTREAK_EARNED).size(), 1, "earned event")
	m.begin_round()
	assert_true(m.submit(P, RulesIntent.use_item(&"recon_drone"))["ok"], "call it in")
	assert_eq(m.sides[P].streak_tray, [], "used -> out of the tray")
	_kills(m, 2, F.MID)
	m.resolve_round()
	assert_eq(m.sides[P].streak, 4, "streak 4")
	assert_eq(m.sides[P].streak_tray, [&"mortar_barrage", &"sentry_turret"], "3 and 4 earned; Recon not again this life")
	# Operator down -> new life: Recon can be earned again.
	m.begin_round()
	F.place(m, E, F.unit("op_killer", 30, 30), F.RIGHT)
	m.resolve_round()
	assert_eq(m.sides[P].streak, 0, "reset")
	m.begin_round()
	m.submit(P, RulesIntent.place_operator(F.MID))
	_kills(m, 2)
	m.resolve_round()
	assert_true(&"recon_drone" in m.sides[P].streak_tray, "earned again in the new life")


func test_reaching_several_thresholds_at_once() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.RIGHT)
	_kills(m, 4)
	F.place(m, P, F.unit("k_mid", 5, 20), F.MID)
	F.place(m, E, F.unit("v_mid", 0, 1), F.MID)
	m.resolve_round()
	assert_eq(m.sides[P].streak, 5, "5 eliminations")
	assert_eq(m.sides[P].streak_tray, [&"recon_drone", &"mortar_barrage", &"sentry_turret", &"attack_helo"], "all four")


func test_killstreak_needs_the_tray_and_undo_puts_it_back() -> void:
	var m: MatchState = F.new_match(_kit())
	var r: Dictionary = m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.LEFT))
	assert_eq([r["ok"], r["reason"]], [false, "killstreak not earned"], "not in the tray")
	StreakTracker.grant(m, P, &"mortar_barrage")
	assert_true(m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.LEFT))["ok"], "from the tray")
	assert_false(m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.MID))["ok"], "only once")
	assert_true(m.undo_last(P)["ok"], "undo")
	assert_eq(m.sides[P].streak_tray, [&"mortar_barrage"], "back in the tray")
	assert_true(m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.MID))["ok"], "usable again")
	assert_eq(m.sides[P].supply, 2, "killstreaks cost 0 Supply")


func test_streak_progress_query() -> void:
	var m: MatchState = F.new_match(_kit())
	m.sides[P].streak = 1
	var prog: Dictionary = StreakTracker.progress(m, P)
	assert_eq([prog[&"recon_drone"]["needed"], prog[&"attack_helo"]["needed"]], [1, 4], "streak still needed")


# --- The four killstreaks (real data) -----------------------------------------------------

func test_recon_drone_shows_deployments_and_strips_cover_this_round_and_next() -> void:
	var e: SideSetup = F.setup([F.shieldman(), F.unit("late", 0, 5, F.W.NONE, {"cover": 2})])
	var m: MatchState = F.new_match(_kit(), e)
	m.sides[E].supply = 9
	var dug_in: RulesUnit = F.place(m, E, F.unit("dug_in", 0, 9, F.W.NONE, {"cover": 1}), F.MID)
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "shieldman"), F.LEFT))  # AI commits first
	assert_eq(m.revealed_red_dots(P, F.LEFT), [], "only a red dot before the drone")
	StreakTracker.grant(m, P, &"recon_drone")
	assert_true(m.submit(P, RulesIntent.use_item(&"recon_drone"))["ok"], "Recon Drone")
	assert_eq(m.revealed_red_dots(P, F.LEFT), [&"shieldman"], "enemy deployments face-up during Deploy")
	m.reveal()
	var shield: RulesUnit = m.sides[E].line(F.LEFT)[0]
	assert_eq([m.cover_of(dug_in), m.cover_of(shield)], [0, 0], "lose Cover, also a unit that arrived later")
	m.firefight()
	m.score()
	m.begin_round()
	m.submit(E, RulesIntent.play_card(F.hand_uid(m, E, "late"), F.RIGHT))
	assert_eq(m.revealed_red_dots(P, F.RIGHT), [&"late"], "next round too")
	m.reveal()
	var late: RulesUnit = m.sides[E].line(F.RIGHT)[0]
	assert_eq(m.cover_of(late), 0, "next round's arrivals lose Cover")
	m.firefight()
	m.score()
	m.begin_round()
	assert_eq([m.cover_of(dug_in), m.cover_of(late)], [1, 2], "then Cover is back")
	assert_eq(m.cover_of(shield), 1, "Shieldman Cover back")


func test_mortar_barrage_two_damage_to_each_enemy_in_one_zone() -> void:
	var m: MatchState = F.new_match(_kit())
	F.place_operator(m, P, F.LEFT)
	_kills(m, 3, F.MID)
	m.resolve_round()
	assert_true(&"mortar_barrage" in m.sides[P].streak_tray, "earned at streak 3")
	m.begin_round()
	var a: RulesUnit = F.place(m, E, F.rifleman(), F.RIGHT)
	var b: RulesUnit = F.place(m, E, F.gunner(), F.RIGHT)
	var other: RulesUnit = F.place(m, E, F.unit("other", 0, 4), F.LEFT)
	assert_true(m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.RIGHT))["ok"], "call in on Right")
	m.reveal()
	assert_eq([a.is_alive(), b.armor, other.armor], [false, 4, 4], "2 to each enemy there only")
	m.firefight()
	m.score()
	assert_eq(m.sides[P].streak, 3 + 1, "only the Operator's firefight kill in Left adds streak")


func test_sentry_turret_real_data_places_a_sentry() -> void:
	var m: MatchState = F.new_match(_kit())
	StreakTracker.grant(m, P, &"sentry_turret")
	assert_true(m.submit(P, RulesIntent.use_item(&"sentry_turret", F.MID))["ok"], "Sentry")
	m.reveal()
	var s: RulesUnit = m.sides[P].line(F.MID)[0]
	assert_eq([s.source_id, s.base_firepower, s.armor, m.cover_of(s), s.counts_for_control], [&"sentry", 2, 4, 1, false], "FP 2 / AR 4, Cover 1, no control")


func test_attack_helo_real_data_two_firefights() -> void:
	var m: MatchState = F.new_match(_kit())
	StreakTracker.grant(m, P, &"attack_helo")
	var far: RulesUnit = F.place(m, E, F.unit("far", 0, 9), F.RIGHT)
	assert_true(m.submit(P, RulesIntent.use_item(&"attack_helo"))["ok"], "Helo")
	for r: int in 3:
		m.resolve_round()
		m.begin_round()
	assert_eq(far.armor, 9 - 2 - 2, "this round's and next round's firefights only")


# --- Perks ----------------------------------------------------------------------------------

func test_streak_discipline_lowers_thresholds_min_one() -> void:
	var p: SideSetup = _kit([], ["streak_discipline"])
	var one: LoadoutItem = F.item("cheap", DataEnums.LoadoutSlot.KILLSTREAK, [F.eff(F.TR.ON_PLAY, F.K.DRAW, F.T.OWNER, F.Z.ANY, 1)])
	one.streak_threshold = 1
	p.killstreaks.append(one)
	var m: MatchState = F.new_match(p)
	assert_eq(StreakTracker.threshold_for(m, P, _load("recon_drone")), 1, "Recon 2 -> 1")
	assert_eq(StreakTracker.threshold_for(m, P, _load("attack_helo")), 4, "Helo 5 -> 4")
	assert_eq(StreakTracker.threshold_for(m, P, one), 1, "never below 1")
	F.place_operator(m, P, F.RIGHT)
	_kills(m, 1)
	m.resolve_round()
	assert_eq(m.sides[P].streak_tray, [&"recon_drone", &"cheap"], "one kill earns Recon Drone with the perk")


func test_objective_focus_adds_streak_with_two_zones_before_tray_and_reset() -> void:
	var p: SideSetup = _kit([], ["objective_focus"])
	p.primary = F.primary("weak_op", 0, 1)
	var m: MatchState = F.new_match(p)
	F.place(m, P, F.unit("hold_l", 0, 9), F.LEFT)
	F.place(m, P, F.unit("hold_r", 0, 9), F.RIGHT)
	m.resolve_round()
	assert_eq(m.sides[P].streak, 1, "2 zones -> +1 (scorestreak)")
	m.begin_round()
	F.place_operator(m, P, F.MID)
	F.place(m, E, F.unit("op_killer", 9, 9), F.MID)
	m.resolve_round()
	var last: Dictionary = _my_changes(m).back()
	assert_eq([last["before"], last["gained"], last["earned"], last["reset"], last["streak"]],
			[1, 1, [&"recon_drone"], true, 0], "bonus counted, Recon earned, then reset (Rulings part 2 #12)")
	m.begin_round()
	F.place(m, E, F.unit("contest", 0, 99), F.RIGHT)
	m.resolve_round()
	assert_eq(m.sides[P].streak, 0, "only 1 zone -> nothing")


func test_field_salvage_draws_on_the_first_elimination_each_round() -> void:
	var deck: Array = []
	for i: int in 12:
		deck.append(F.unit("d%d" % i, 1, 1))
	var m: MatchState = F.new_match(_kit(deck, ["field_salvage"]))
	F.place_operator(m, P, F.RIGHT)
	_kills(m, 2)
	var hand: int = m.sides[P].hand.size()
	m.resolve_round()
	assert_eq(m.sides[P].hand.size(), hand + 1, "2 kills, 1 draw")
	assert_eq(F.events_of(m, RulesEvent.PERK_TRIGGERED).size(), 1, "logged once")
	m.begin_round()
	_kills(m, 1, F.MID)
	m.resolve_round()
	assert_eq(F.events_of(m, RulesEvent.PERK_TRIGGERED).size(), 2, "again next round")
	m.begin_round()
	StreakTracker.grant(m, P, &"mortar_barrage")
	F.place(m, E, F.unit("mortared", 0, 1), F.RIGHT)
	m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.RIGHT))
	m.resolve_round()
	assert_eq(m.sides[P].eliminations, 4, "the Mortar kill happened")
	assert_eq(F.events_of(m, RulesEvent.PERK_TRIGGERED).size(), 2, "a killstreak kill doesn't draw")


func test_grit_survives_lethal_once_per_match() -> void:
	var m: MatchState = F.new_match(_kit([], ["grit"]))
	var op: RulesUnit = F.place_operator(m, P, F.MID)
	F.place(m, E, F.unit("big", 20, 50), F.MID)
	m.resolve_round()
	assert_true(op.is_on_board(), "Grit: survived lethal damage")
	assert_eq(op.armor, 1, "with 1 Armor")
	assert_eq(F.events_of(m, RulesEvent.SURVIVED_LETHAL).size(), 1, "logged")
	m.begin_round()
	assert_eq(LoadoutRules.uses_left_this_match(m, P, _load("grit")), 0, "used up")
	m.resolve_round()
	assert_false(op.is_on_board(), "no second save")
	m.begin_round()
	assert_eq(op.survive_lethal, 0, "not re-armed after respawn")


func test_grit_stays_armed_until_needed() -> void:
	var m: MatchState = F.new_match(_kit([], ["grit"]))
	var op: RulesUnit = F.place_operator(m, P, F.MID)
	for r: int in 3:
		m.resolve_round()
		m.begin_round()
	assert_eq(op.survive_lethal, 1, "still armed in round 4")
	F.place(m, E, F.unit("big", 20, 50), F.MID)
	m.resolve_round()
	assert_eq([op.is_on_board(), op.armor], [true, 1], "saves the Operator in round 4")


func test_bracket_armor_bonus_applies_to_enemy_operator_from_squad_data() -> void:
	var md: RunMatchData = RunMatchData.new()
	md.enemy_armor_bonus = 1
	var squad: SquadData = load("res://data/squads/squad_anchor.tres") as SquadData
	var e: SideSetup = SideSetup.from_squad(squad, md)
	var m: MatchState = F.new_match(null, e)
	assert_eq(m.sides[E].operator_unit.armor, squad.primary.operator_armor + 1, "enemy Operator +1 Armor (content-log gap 5)")
