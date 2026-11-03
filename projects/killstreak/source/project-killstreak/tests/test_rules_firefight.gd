# test_rules_firefight.gd
# Purpose: p04 firefight rules: targeting, steps, keywords, damage / armor,
#   eliminations, control, and the core-rules §9 edge cases that touch the firefight.
#   Units are put on the board directly; fixtures are built in code.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const E: int = 1


func test_shots_hit_point_man_then_next_when_assigned_damage_kills() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.unit("a", 2, 9), F.MID)
	F.place(m, P, F.unit("b", 2, 9), F.MID)
	var front: RulesUnit = F.place(m, E, F.unit("front", 0, 2), F.MID)
	var back: RulesUnit = F.place(m, E, F.unit("back", 0, 5), F.MID)
	m.firefight()
	assert_false(front.is_alive(), "first shot kills the point man")
	assert_eq(back.armor, 3, "second shot moves on to the next unit in line")


func test_overkill_is_wasted() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.unit("big", 5, 9), F.MID)
	F.place(m, E, F.unit("front", 0, 2), F.MID)
	var back: RulesUnit = F.place(m, E, F.unit("back", 0, 3), F.MID)
	m.firefight()
	assert_eq(back.armor, 3, "extra damage does not carry over")
	assert_eq(F.line_ids(m, E, F.MID), [&"back"], "front eliminated")


func test_main_step_is_simultaneous_trade() -> void:
	var m: MatchState = F.new_match()
	var mine: RulesUnit = F.place(m, P, F.unit("mine", 2, 2), F.MID)
	var theirs: RulesUnit = F.place(m, E, F.unit("theirs", 2, 2), F.MID)
	m.firefight()
	assert_false(mine.is_alive(), "player unit traded")
	assert_false(theirs.is_alive(), "enemy unit traded")
	assert_eq(F.events_of(m, RulesEvent.UNIT_ELIMINATED).size(), 2, "two eliminations")


func test_first_shot_kills_before_target_fires() -> void:
	var m: MatchState = F.new_match()
	var breacher: RulesUnit = F.place(m, P, F.unit("fs", 3, 2, F.W.NONE, {"first_shot": true}), F.MID)
	F.place(m, E, F.unit("slow", 5, 3), F.MID)
	m.firefight()
	assert_eq(breacher.armor, 2, "dead unit never fires in the Main step")
	assert_true(m.sides[E].line(F.MID).is_empty(), "enemy eliminated in First Shot step")


func test_first_shot_units_on_both_sides_fire_together() -> void:
	var m: MatchState = F.new_match()
	var a: RulesUnit = F.place(m, P, F.unit("a", 3, 3, F.W.NONE, {"first_shot": true}), F.MID)
	var b: RulesUnit = F.place(m, E, F.unit("b", 3, 3, F.W.NONE, {"first_shot": true}), F.MID)
	m.firefight()
	assert_false(a.is_alive() or b.is_alive(), "both First Shot units die in the same step")
	var steps: Array[Dictionary] = F.events_of(m, RulesEvent.FIREFIGHT_STEP)
	assert_eq(steps.size(), 1, "no Main step needed (nobody left)")


func test_unit_killed_in_main_step_still_fires() -> void:
	var m: MatchState = F.new_match()
	var weak: RulesUnit = F.place(m, P, F.unit("weak", 4, 1), F.MID)
	var target: RulesUnit = F.place(m, E, F.unit("target", 1, 6), F.MID)
	m.firefight()
	assert_false(weak.is_alive(), "weak died")
	assert_eq(target.armor, 2, "but its shot still landed")


func test_pick_targets_lowest_armor_ties_front_most() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.unit("picker", 1, 9, F.W.NONE, {"pick": true}), F.MID)
	var front: RulesUnit = F.place(m, E, F.unit("front", 0, 5), F.MID)
	var tie_a: RulesUnit = F.place(m, E, F.unit("tie_a", 0, 2), F.MID)
	var tie_b: RulesUnit = F.place(m, E, F.unit("tie_b", 0, 2), F.MID)
	m.firefight()
	assert_eq([front.armor, tie_a.armor, tie_b.armor], [5, 1, 2], "Pick hits the front-most of the lowest")


func test_pick_skips_units_already_doomed_this_step() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.unit("p1", 2, 9, F.W.NONE, {"pick": true}), F.MID)
	F.place(m, P, F.unit("p2", 2, 9, F.W.NONE, {"pick": true}), F.MID)
	var low: RulesUnit = F.place(m, E, F.unit("low", 0, 2), F.MID)
	var next: RulesUnit = F.place(m, E, F.unit("next", 0, 3), F.MID)
	m.firefight()
	assert_false(low.is_alive(), "first Pick kills the lowest")
	assert_eq(next.armor, 1, "second Pick goes to the next-lowest living unit")


func test_flank_targets_back_most() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.flanker(), F.MID)
	var front: RulesUnit = F.place(m, E, F.unit("front", 0, 5), F.MID)
	var back: RulesUnit = F.place(m, E, F.unit("back", 0, 5), F.MID)
	m.firefight()
	assert_eq([front.armor, back.armor], [5, 3], "Flank hits the back of the line")


func test_untargetable_by_pick_flank_falls_back_to_line_order() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.flanker(), F.MID)
	var front: RulesUnit = F.place(m, E, F.unit("front", 0, 5), F.MID)
	var back: RulesUnit = F.place(m, E, F.unit("back", 0, 5), F.MID)
	back.add_mod(DataEnums.EffectKind.UNTARGETABLE_BY_PICK_FLANK, 1, m.round_number)
	m.firefight()
	assert_eq([front.armor, back.armor], [3, 5], "smoked unit can't be flanked")


func test_cover_reduces_each_hit() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.unit("a", 2, 9), F.MID)
	F.place(m, P, F.unit("b", 2, 9), F.MID)
	var shield: RulesUnit = F.place(m, E, F.shieldman(), F.MID)
	m.firefight()
	assert_eq(shield.armor, 3, "two hits of 2 vs Cover 1 deal 2 total")


func test_cover_reduces_effect_damage() -> void:
	var m: MatchState = F.new_match()
	var shield: RulesUnit = F.place(m, E, F.shieldman(), F.MID)
	m.deal_damage(shield, 2, {"side": P, "uid": -1, "source_id": &"mortar", "source_kind": MatchState.SRC_KILLSTREAK})
	assert_eq(shield.armor, 4, "Cover 1 also blocks effect damage")


func test_suppress_lowers_enemy_point_man_firepower() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.gunner(), F.MID)
	var pm: RulesUnit = F.place(m, E, F.unit("pm", 3, 9), F.MID)
	var second: RulesUnit = F.place(m, E, F.unit("second", 3, 9), F.MID)
	assert_eq(m.firepower_of(pm), 3, "before")
	m.firefight()
	assert_eq(m.firepower_of(pm), 1, "point man -2 FP this round")
	assert_eq(m.firepower_of(second), 3, "only the point man")
	assert_eq(m.sides[P].line(F.MID)[0].armor, 6 - 1 - 3, "gunner took 1 + 3")
	m.score()
	assert_eq(m.firepower_of(pm), 3, "Suppress ends with the round")


func test_firepower_never_below_zero() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.gunner(), F.MID)
	var pm: RulesUnit = F.place(m, E, F.unit("pm", 1, 9), F.MID)
	m.firefight()
	assert_eq(m.firepower_of(pm), 0, "1 - 2 clamps to 0")
	assert_eq(m.sides[P].line(F.MID)[0].armor, 6, "a 0 FP shot deals nothing")


func test_range_bonuses_come_from_run_config() -> void:
	var m: MatchState = F.new_match(null, null, F.map([F.R.CLOSE, F.R.LONG, F.R.MID]))
	var sniper: RulesUnit = F.place(m, P, F.marksman(), F.MID)
	var shotgun: RulesUnit = F.place(m, P, F.breacher(), F.LEFT)
	var shotgun_long: RulesUnit = F.place(m, E, F.breacher(), F.MID)
	var ar: RulesUnit = F.place(m, E, F.rifleman(), F.RIGHT)
	assert_eq(m.firepower_of(sniper), 4, "Sniper +2 at Long")
	assert_eq(m.firepower_of(shotgun), 5, "Shotgun +2 at Close")
	assert_eq(m.firepower_of(shotgun_long), 2, "Shotgun -1 at Long")
	assert_eq(m.firepower_of(ar), 3, "AR +1 at Mid")
	var cfg: RunConfig = RunConfig.new()
	cfg.range_bonus_sniper = PackedInt32Array([0, 0, 5])
	var m2: MatchState = F.new_match(null, null, F.map([F.R.CLOSE, F.R.LONG, F.R.MID]), 1, null, cfg)
	assert_eq(m2.firepower_of(F.place(m2, P, F.marksman(), F.MID)), 7, "tuned RunConfig value used")


func test_damage_persists_across_rounds() -> void:
	var m: MatchState = F.new_match()
	var tank: RulesUnit = F.place(m, P, F.unit("tank", 0, 6), F.MID)
	F.place(m, E, F.unit("hitter", 2, 9), F.MID)
	m.resolve_round()
	assert_eq(tank.armor, 4, "round 1 damage")
	m.begin_round()
	assert_eq(tank.armor, 4, "no healing between rounds")
	m.resolve_round()
	assert_eq(tank.armor, 2, "round 2 damage stacks")


func test_no_legal_target_wastes_the_shot() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.unit("fs", 5, 9, F.W.NONE, {"first_shot": true}), F.MID)
	F.place(m, P, F.unit("late", 2, 9), F.MID)
	F.place(m, E, F.unit("only", 0, 1), F.MID)
	m.firefight()
	var wasted: Array = F.events_of(m, RulesEvent.SHOT_FIRED).filter(func(e: Dictionary) -> bool: return e["target_uid"] == -1)
	assert_eq(wasted.size(), 1, "the Main step shot has no target")


func test_edge_dead_shieldman_lets_next_unit_be_point_man_same_step() -> void:
	# core-rules §9: damage is assigned per shot, so once enough damage is assigned to
	# kill the Shieldman, later shots of the same step go to the next unit in line.
	var m: MatchState = F.new_match()
	for i: int in 3:
		F.place(m, P, F.unit("r%d" % i, 3, 9), F.MID)
	var rifle: RulesUnit = F.place(m, E, F.unit("rifle", 0, 3), F.MID)
	var shield: RulesUnit = F.place(m, E, F.shieldman(), F.MID)
	shield.armor = 4
	assert_eq(F.line_ids(m, E, F.MID), [&"shieldman", &"rifle"], "Shieldman in front")
	m.firefight()
	assert_false(shield.is_alive(), "two shots (2 each after Cover) kill the Shieldman")
	assert_false(rifle.is_alive(), "third shot of the same step hits the new point man")


func test_edge_both_operators_down_same_step() -> void:
	var p: SideSetup = F.setup([], F.primary("op_p", 5, 4))
	var e: SideSetup = F.setup([], F.primary("op_e", 5, 4))
	var m: MatchState = F.new_match(p, e)
	F.place_operator(m, P, F.MID)
	F.place_operator(m, E, F.MID)
	m.sides[P].streak = 2
	m.sides[E].streak = 3
	m.resolve_round()
	assert_eq(F.events_of(m, RulesEvent.OPERATOR_DOWN).size(), 2, "both Operators down")
	assert_eq([m.sides[P].eliminations, m.sides[E].eliminations], [1, 1], "both sides get elimination credit")
	assert_eq([m.sides[P].streak, m.sides[E].streak], [0, 0], "both streaks reset")
	var changes: Array[Dictionary] = F.events_of(m, RulesEvent.STREAK_CHANGED)
	assert_eq(changes.size(), 2, "both streak changes logged")
	assert_true(changes[0]["gained"] == 1 and changes[0]["reset"], "the trade is counted, then reset")


func test_elimination_goes_to_discard_with_credit() -> void:
	var m: MatchState = F.new_match()
	var killer: RulesUnit = F.place(m, P, F.unit("killer", 3, 9), F.MID)
	var victim: RulesUnit = F.place(m, E, F.unit("victim", 0, 2), F.MID)
	m.firefight()
	var rec: Dictionary = F.events_of(m, RulesEvent.UNIT_ELIMINATED)[0]
	assert_eq([rec["victim_uid"], rec["by_uid"], rec["by_side"], rec["credit"]], [victim.uid, killer.uid, &"player", true], "killfeed record")
	assert_eq(m.sides[E].discard.size(), 1, "victim card in enemy discard pile")
	assert_eq(m.sides[E].discard[0].uid, victim.uid, "same card uid")
	assert_eq(m.sides[P].eliminations, 1, "credited")


func test_on_down_damages_enemy_point_man_here() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.demolitions(), F.MID)
	var pm: RulesUnit = F.place(m, E, F.unit("pm", 4, 6), F.MID)
	var other: RulesUnit = F.place(m, E, F.unit("other", 4, 6), F.MID)
	m.firefight()
	assert_eq(m.sides[P].line(F.MID).size(), 0, "Demolitions Expert went down")
	assert_eq(pm.armor, 6 - 2 - 3, "shot (2) + On Down (3) on the point man")
	assert_eq(other.armor, 6, "other untouched")
	var by: Array = F.events_of(m, RulesEvent.DAMAGE_DEALT).filter(func(e: Dictionary) -> bool: return e["source_id"] == &"demolitions_expert")
	assert_eq(by.size(), 2, "both hits attributed to Demolitions Expert")


func test_firefight_only_where_both_sides_have_units() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.unit("a", 2, 2), F.LEFT)
	F.place(m, E, F.unit("b", 2, 2), F.RIGHT)
	F.place(m, P, F.unit("c", 1, 5), F.MID)
	F.place(m, E, F.unit("d", 1, 5), F.MID)
	m.firefight()
	var zones: Array = F.events_of(m, RulesEvent.FIREFIGHT_STARTED).map(func(e: Dictionary) -> StringName: return e["zone"])
	assert_eq(zones, [&"mid"], "only Mid fights")


func test_anvil_aura_gives_other_units_plus_one() -> void:
	var m: MatchState = F.new_match()
	var anvil: RulesUnit = F.place(m, P, F.anvil(), F.LEFT)
	var buddy: RulesUnit = F.place(m, P, F.unit("buddy", 2, 2), F.LEFT)
	var far: RulesUnit = F.place(m, P, F.unit("far", 2, 2), F.RIGHT)
	assert_eq(m.firepower_of(buddy), 3, "+1 in Anvil's zone")
	assert_eq(m.firepower_of(far), 2, "not in other zones")
	assert_eq(m.firepower_of(anvil), 4, "no aura on herself (3 + 1 AR at Mid)")


func test_patch_heals_most_damaged_other_friendly() -> void:
	var m: MatchState = F.new_match()
	var medic: RulesUnit = F.place(m, P, F.combat_medic(), F.MID)
	var a: RulesUnit = F.place(m, P, F.unit("a", 0, 6), F.MID)
	var b: RulesUnit = F.place(m, P, F.unit("b", 0, 6), F.MID)
	F.place(m, E, F.unit("e", 0, 9), F.MID)
	medic.armor = 1
	a.armor = 5
	b.armor = 1
	m.firefight()
	assert_eq([medic.armor, a.armor, b.armor], [1, 5, 3], "most damaged other friendly +2, not the medic")
	a.armor = 6
	b.armor = 5
	m.firefight()
	assert_eq(b.armor, 6, "never above max Armor (5 + 2 -> 6)")


func test_patch_only_after_a_firefight_in_that_zone() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.combat_medic(), F.LEFT)
	var hurt: RulesUnit = F.place(m, P, F.unit("hurt", 0, 6), F.LEFT)
	hurt.armor = 2
	m.firefight()
	assert_eq(hurt.armor, 2, "no firefight in Left -> no Patch")


func test_holder_controls_contested_zone() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.anvil(), F.MID)
	F.place(m, E, F.unit("e", 0, 9), F.MID)
	assert_eq(m.control_of(F.MID), MatchState.PLAYER, "Holder takes the contested zone")
	F.place(m, E, F.unit("e_holder", 0, 9, F.W.NONE, {"holder": true}), F.MID)
	assert_eq(m.control_of(F.MID), MatchState.CONTROL_CONTESTED, "both Holders -> contested")
	F.place(m, P, F.unit("lone", 0, 9), F.LEFT)
	assert_eq(m.control_of(F.LEFT), MatchState.PLAYER, "alone -> control")
	assert_eq(m.control_of(F.RIGHT), MatchState.CONTROL_EMPTY, "empty")


func test_attack_helo_hits_point_men_before_first_shot_this_and_next_round() -> void:
	# Ruling 8: includes this round's firefight, hits before First Shot, no streak.
	var p: SideSetup = F.setup()
	p.killstreaks.assign([F.attack_helo()])
	var m: MatchState = F.new_match(p)
	StreakTracker.grant(m, P, &"attack_helo")  # p05: killstreaks come from the Streak Tray
	var fs_enemy: RulesUnit = F.place(m, E, F.unit("fs", 5, 2, F.W.NONE, {"first_shot": true}), F.LEFT)
	var mine: RulesUnit = F.place(m, P, F.unit("mine", 1, 3), F.LEFT)
	var far: RulesUnit = F.place(m, E, F.unit("far", 0, 6), F.RIGHT)
	assert_true(m.submit(P, RulesIntent.use_item(&"attack_helo"))["ok"], "helo activated")
	m.resolve_round()
	assert_false(fs_enemy.is_alive(), "Helo kills the First Shot point man first")
	assert_eq(mine.armor, 3, "so it never fired")
	assert_eq(far.armor, 4, "every zone, even without a firefight")
	assert_eq(m.sides[P].streak, 0, "killstreak eliminations give no streak")
	assert_true(F.events_of(m, RulesEvent.UNIT_ELIMINATED)[0]["by_killstreak"], "flagged as killstreak")
	m.begin_round()
	m.resolve_round()
	assert_eq(far.armor, 2, "next round's firefight too")
	m.begin_round()
	m.resolve_round()
	assert_eq(far.armor, 2, "then it ends")


func test_sentry_takes_a_slot_ignored_for_control_no_credit() -> void:
	# Ruling 5.
	var p: SideSetup = F.setup([F.rifleman()])
	p.killstreaks.assign([F.sentry_turret()])
	var m: MatchState = F.new_match(p)
	StreakTracker.grant(m, P, &"sentry_turret")
	for i: int in 3:
		F.place(m, P, F.unit("u%d" % i, 0, 9), F.LEFT)
	assert_true(m.submit(P, RulesIntent.use_item(&"sentry_turret", F.MID))["ok"], "Sentry called in on Mid")
	m.resolve_round()
	assert_eq(F.line_ids(m, P, F.MID), [&"sentry"], "Sentry at the back of Mid's line")
	assert_eq(m.control_of(F.MID), MatchState.CONTROL_EMPTY, "Sentry gives no control")
	F.place(m, E, F.unit("e", 0, 3), F.MID)
	assert_eq(m.control_of(F.MID), MatchState.ENEMY, "and doesn't block the enemy")
	# Capacity: Sentry uses 1 of 4 slots.
	m.begin_round()
	var sentry: RulesUnit = m.sides[P].line(F.MID)[0]
	for i: int in 3:
		F.place(m, P, F.unit("m%d" % i, 0, 9), F.MID)
	var r: Dictionary = m.submit(P, RulesIntent.play_card(F.hand_uid(m, P, "rifleman"), F.MID))
	assert_false(r["ok"], "zone full with the Sentry counted")
	m.deal_damage(sentry, 99, {"side": E, "uid": -1, "source_id": &"x", "source_kind": MatchState.SRC_UNIT})
	m.process_eliminations()
	assert_eq(m.sides[E].eliminations, 0, "no elimination credit for the Sentry")
	assert_eq(m.sides[P].discard.size(), 0, "token does not go to the discard pile")


func test_wren_eliminations_give_extra_streak() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, F.wren(), F.MID)
	F.place(m, E, F.unit("victim", 0, 2), F.MID)
	m.resolve_round()
	assert_eq(m.sides[P].streak, 2, "1 elimination + 1 bonus")


func test_survive_lethal_keeps_unit_at_given_armor() -> void:
	var m: MatchState = F.new_match()
	var tough: RulesUnit = F.place(m, P, F.unit("tough", 0, 3), F.MID)
	tough.survive_lethal = 1
	F.place(m, E, F.unit("a", 5, 9), F.MID)
	F.place(m, E, F.unit("b", 5, 9), F.MID)
	m.firefight()
	assert_eq(tough.armor, 1, "survived the step's lethal damage with 1 Armor")
	assert_eq(tough.survive_lethal, 0, "used up")
