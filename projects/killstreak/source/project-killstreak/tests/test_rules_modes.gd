# test_rules_modes.gd
# Purpose: p06 game modes (core-rules §4, §9, §10, Ruling 12, Rulings part 2 #13):
#   Zone Control and Firefight scoring, targets, the round-8 cap, overtime rounds 9-10,
#   the draw after round 10, the MATCH_ENDED outcome, data-driven numbers, and that
#   typical matches with real data finish within the round cap.
# Author: Mechanics Developer Agent
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const Sim = preload("res://tests/mode_sim.gd")
const P: int = 0
const E: int = 1
const ZC: int = DataEnums.GameMode.ZONE_CONTROL
const FF: int = DataEnums.GameMode.FIREFIGHT


func _match(mode: int, player: SideSetup = null, enemy: SideSetup = null, config: RunConfig = null) -> MatchState:
	var hooks: MatchHooks = MatchHooks.new()
	hooks.mode_rules = ModeRules.create(mode, config)
	return F.new_match(player, enemy, null, 1, hooks, config)


## Resolves `n` rounds (starting the next Briefing after each, unless the match ended).
func _advance(m: MatchState, n: int) -> void:
	for i: int in n:
		m.resolve_round()
		m.begin_round()


func _outcome(m: MatchState) -> Dictionary:
	return m.hooks.mode_rules.outcome


## Unkillable, harmless unit: holds a zone without fighting.
func _holder_unit(id: String = "post") -> CardData:
	return F.unit(id, 0, 99)


# --- Zone Control scoring ----------------------------------------------------------------

func test_zone_control_one_point_per_controlled_zone() -> void:
	var m: MatchState = _match(ZC)
	F.place(m, P, _holder_unit(), F.LEFT)
	F.place(m, P, _holder_unit(), F.MID)
	F.place(m, E, _holder_unit(), F.MID)      # contested
	F.place(m, E, _holder_unit(), F.RIGHT)
	m.resolve_round()
	assert_eq([m.sides[P].score, m.sides[E].score], [1, 1], "Left player, Mid contested, Right enemy")
	var scored: Dictionary = F.events_of(m, RulesEvent.MODE_SCORED).back()
	assert_eq([scored["mode"], scored["player_gained"], scored["enemy_gained"], scored["target"]],
			[&"zone_control", 1, 1, 6], "MODE_SCORED event")
	m.begin_round()
	m.resolve_round()
	assert_eq([m.sides[P].score, m.sides[E].score], [2, 2], "points add up every round")


func test_zone_control_holder_and_sentry_rules() -> void:
	# Holder controls a contested zone; a Sentry neither controls nor blocks (Ruling 5).
	var m: MatchState = _match(ZC)
	F.place(m, P, F.unit("anchor", 0, 99, F.W.LMG, {"holder": true}), F.LEFT)
	F.place(m, E, _holder_unit(), F.LEFT)
	F.place(m, P, F.sentry(), F.MID)
	F.place(m, E, F.sentry(), F.RIGHT)
	F.place(m, P, _holder_unit(), F.RIGHT)
	m.resolve_round()
	assert_eq([m.sides[P].score, m.sides[E].score], [2, 0], "Holder Left + Right despite the enemy Sentry; Mid Sentry alone scores nothing")


func test_zone_control_first_to_six_wins_and_stops_the_match() -> void:
	var m: MatchState = _match(ZC)
	for z: int in 3:
		F.place(m, P, _holder_unit(), z)
	m.resolve_round()
	assert_eq(m.result, &"", "3 points: not yet")
	m.begin_round()
	m.resolve_round()
	assert_eq([m.phase, m.result, m.round_number], [MatchState.Phase.ENDED, &"player", 2], "6 points at the end of round 2")
	var o: Dictionary = _outcome(m)
	assert_eq([o["winner"], o["is_draw"], o["reason"], o["overtime"], o["player_score"], o["enemy_score"]],
			[&"player", false, &"target", false, 6, 0], "outcome")
	m.begin_round()
	assert_eq(m.round_number, 2, "no round after the end")


func test_zone_control_target_is_checked_only_at_round_end() -> void:
	# Even with 5 points, the match goes on until a round-end puts someone at 6.
	var m: MatchState = _match(ZC)
	m.sides[P].score = 5
	m.resolve_round()
	assert_eq(m.result, &"", "no point this round: still 5")
	m.begin_round()
	F.place(m, P, _holder_unit(), F.MID)
	m.resolve_round()
	assert_eq([m.result, _outcome(m)["player_score"]], [&"player", 6], "won at the round-end that reached 6")


func test_both_reach_target_same_round_leader_wins() -> void:
	var m: MatchState = _match(ZC)
	m.sides[P].score = 5
	m.sides[E].score = 5
	F.place(m, P, _holder_unit(), F.LEFT)
	F.place(m, P, _holder_unit(), F.MID)
	F.place(m, E, _holder_unit(), F.RIGHT)
	m.resolve_round()
	assert_eq([m.result, _outcome(m)["reason"], _outcome(m)["player_score"], _outcome(m)["enemy_score"]],
			[&"player", &"target", 7, 6], "both past 6: the leader wins")


func test_tied_at_or_over_target_plays_on_until_a_leader() -> void:
	# Interpretation: "first to 6" with both on 6 at the same round-end is not a winner;
	# the next round-end with a leader wins (same rule as overtime), still within the cap.
	var m: MatchState = _match(ZC)
	m.sides[P].score = 5
	m.sides[E].score = 5
	F.place(m, P, _holder_unit(), F.LEFT)
	F.place(m, E, _holder_unit(), F.RIGHT)
	m.resolve_round()
	assert_eq([m.result, m.sides[P].score, m.sides[E].score], [&"", 6, 6], "6-6: play on")
	m.begin_round()
	F.place(m, E, _holder_unit(), F.MID)
	m.resolve_round()
	assert_eq([m.result, _outcome(m)["reason"], m.round_number], [&"enemy", &"target", 2], "7-8: enemy leads, wins")


# --- Round cap, overtime, draw (Ruling 12, §9) ---------------------------------------------

func test_round_cap_leader_wins_below_target() -> void:
	var m: MatchState = _match(ZC)
	_advance(m, 7)
	assert_eq([m.round_number, m.result], [8, &""], "nobody scored in 7 rounds")
	F.place(m, E, _holder_unit(), F.MID)
	m.resolve_round()
	var o: Dictionary = _outcome(m)
	assert_eq([m.result, o["reason"], o["rounds"], o["overtime"], o["enemy_score"]],
			[&"enemy", &"round_cap", 8, false, 1], "round 8 -> most points wins")


func test_tie_at_round_eight_starts_overtime_and_first_leader_wins() -> void:
	var m: MatchState = _match(ZC)
	_advance(m, 8)
	assert_eq([m.result, m.round_number, m.phase], [&"", 9, MatchState.Phase.DEPLOY], "0-0 after 8: round 9 is played")
	var ot: Array[Dictionary] = F.events_of(m, RulesEvent.OVERTIME_STARTED)
	assert_eq(ot.size(), 1, "overtime announced once")
	assert_eq([ot[0]["round"], ot[0]["last_round"]], [8, 10], "after round 8, up to round 10")
	assert_eq(m.sides[P].supply, 7, "Supply stays capped at 7 in overtime")
	F.place(m, P, _holder_unit(), F.LEFT)
	m.resolve_round()
	var o: Dictionary = _outcome(m)
	assert_eq([m.result, o["reason"], o["rounds"], o["overtime"]], [&"player", &"overtime", 9, true], "first round-end with a leader")


func test_overtime_still_tied_after_nine_goes_to_ten() -> void:
	var m: MatchState = _match(FF)
	m.sides[P].score = 3
	m.sides[E].score = 3
	_advance(m, 9)
	assert_eq([m.result, m.round_number], [&"", 10], "3-3 through round 9")
	F.place(m, P, F.unit("gun", 9, 20), F.MID)
	F.place(m, E, F.unit("target", 0, 1), F.MID)
	m.resolve_round()
	assert_eq([m.result, _outcome(m)["reason"], _outcome(m)["rounds"], m.sides[P].score], [&"player", &"overtime", 10, 4], "round 10 elimination decides")


func test_still_tied_after_round_ten_is_a_draw() -> void:
	# §9 + Ruling 12: draw, no ticket lost (the run layer reads is_draw).
	var m: MatchState = _match(ZC)
	_advance(m, 9)
	F.place(m, P, _holder_unit(), F.LEFT)
	F.place(m, E, _holder_unit(), F.RIGHT)
	m.resolve_round()
	assert_eq([m.phase, m.result, m.round_number], [MatchState.Phase.ENDED, &"draw", 10], "1-1 after round 10")
	var o: Dictionary = _outcome(m)
	assert_eq([o["winner"], o["is_draw"], o["reason"], o["player_score"], o["enemy_score"]],
			[&"", true, &"overtime_draw", 1, 1], "draw outcome")
	var ended: Array[Dictionary] = F.events_of(m, RulesEvent.MATCH_ENDED)
	assert_eq(ended.size(), 1, "one MATCH_ENDED")
	assert_eq(ended[0]["result"], &"draw", "event result")
	m.begin_round()
	assert_eq(m.round_number, 10, "no round 11")


func test_match_ended_event_carries_the_outcome() -> void:
	var m: MatchState = _match(FF)
	m.sides[P].score = 6
	F.place(m, P, F.unit("gun", 9, 20), F.MID)
	F.place(m, E, F.unit("target", 0, 1), F.MID)
	m.resolve_round()
	var ev: Dictionary = F.events_of(m, RulesEvent.MATCH_ENDED).back()
	var o: Dictionary = _outcome(m)
	for key: String in o:
		assert_eq(ev[key], o[key], "event field " + key)
	assert_eq([ev["mode"], ev["target"], ev["round"], ev["player_eliminations"]], [&"firefight", 7, 1, 1], "fields")
	var types: Array = m.events.map(func(e: Dictionary) -> StringName: return e["type"])
	assert_true(types.rfind(RulesEvent.ROUND_ENDED) < types.rfind(RulesEvent.MATCH_ENDED), "ROUND_ENDED comes first")


# --- Firefight ----------------------------------------------------------------------------

func test_firefight_scores_credited_eliminations_including_operator() -> void:
	var m: MatchState = _match(FF, F.setup([], F.primary("op", 9, 20)))
	F.place_operator(m, P, F.LEFT)
	F.place(m, E, F.unit("a", 0, 1), F.LEFT)
	F.place(m, P, F.unit("gun", 9, 20), F.MID)
	F.place(m, E, F.unit("b", 0, 1), F.MID)
	F.place(m, P, _holder_unit(), F.RIGHT)    # controls a zone: worth nothing in Firefight
	m.resolve_round()
	assert_eq([m.sides[P].score, m.sides[E].score], [2, 0], "two kills, zones ignored")
	var scored: Dictionary = F.events_of(m, RulesEvent.MODE_SCORED).back()
	assert_eq([scored["mode"], scored["player_gained"], scored["target"]], [&"firefight", 2, 7], "MODE_SCORED event")


func test_firefight_operator_down_counts_and_both_operators_down_same_step() -> void:
	# §9: both Operators down in the same step -> both get elimination credit.
	var m: MatchState = _match(FF, F.setup([], F.primary("op_p", 9, 3)), F.setup([], F.primary("op_e", 9, 3)))
	F.place_operator(m, P, F.MID)
	F.place_operator(m, E, F.MID)
	m.resolve_round()
	assert_eq([m.sides[P].score, m.sides[E].score], [1, 1], "each Operator down scores for the other side")
	assert_eq([m.sides[P].streak, m.sides[E].streak], [0, 0], "both streaks reset")
	assert_eq(m.result, &"", "1-1: no winner")


## Lets any loadout item be used (the Streak Tray / cooldowns are p05's, tested there).
class AnyItemHooks extends MatchHooks:
	func can_use_item(_state, _side: int, _item: LoadoutItem) -> String:
		return ""


func test_firefight_killstreak_kills_count_sentry_and_no_credit_do_not() -> void:
	# Rulings part 2 #13: killstreak kills are credited for mode scoring (not for streak).
	var p: SideSetup = F.setup()
	p.killstreaks.assign([F.mortar()])
	var hooks: AnyItemHooks = AnyItemHooks.new()
	hooks.mode_rules = ModeRules.create(FF)
	var m: MatchState = F.new_match(p, null, null, 1, hooks)
	F.place(m, E, F.rifleman(), F.RIGHT)
	F.place(m, E, F.sentry(), F.RIGHT)
	F.place(m, P, F.unit("sentry_killer", 9, 20), F.LEFT)
	F.place(m, E, F.sentry(), F.LEFT)
	m.submit(P, RulesIntent.use_item(&"mortar_barrage", F.RIGHT))
	m.resolve_round()
	assert_eq(m.sides[P].score, 1, "Mortar kills the Rifleman (+1); the Sentries give no credit")
	assert_eq(m.sides[P].streak, 0, "still no streak from the killstreak")


func test_firefight_first_to_seven() -> void:
	var m: MatchState = _match(FF)
	for i: int in 4:
		F.place(m, P, F.unit("gun%d" % i, 9, 20), F.LEFT)
		F.place(m, E, F.unit("t%d" % i, 0, 1), F.LEFT)
	m.resolve_round()
	assert_eq([m.sides[P].score, m.result], [4, &""], "4 kills")
	m.begin_round()
	for i: int in 3:
		F.place(m, E, F.unit("u%d" % i, 0, 1), F.LEFT)
	m.resolve_round()
	assert_eq([m.result, _outcome(m)["reason"], _outcome(m)["player_score"], m.round_number], [&"player", &"target", 7, 2], "7 eliminations win")


func test_firefight_round_cap_most_eliminations() -> void:
	var m: MatchState = _match(FF)
	m.sides[E].score = 2
	m.sides[P].score = 1
	_advance(m, 7)
	m.resolve_round()
	assert_eq([m.result, _outcome(m)["reason"], m.round_number], [&"enemy", &"round_cap", 8], "2-1 at round 8")


# --- Data-driven -------------------------------------------------------------------------

func test_numbers_come_from_run_config() -> void:
	var cfg: RunConfig = RunConfig.new()
	cfg.zone_control_target = 2
	cfg.round_cap = 3
	cfg.overtime_draw_round = 4
	var m: MatchState = _match(ZC, null, null, cfg)
	F.place(m, P, _holder_unit(), F.LEFT)
	F.place(m, P, _holder_unit(), F.MID)
	m.resolve_round()
	assert_eq([m.result, _outcome(m)["target"]], [&"player", 2], "custom target")
	var d: MatchState = _match(ZC, null, null, cfg)
	_advance(d, 3)
	assert_eq(F.events_of(d, RulesEvent.OVERTIME_STARTED).size(), 1, "custom round cap")
	_advance(d, 1)
	assert_eq([d.result, d.round_number], [&"draw", 4], "custom draw round")
	var rules: ModeRules = ModeRules.create(FF, cfg)
	assert_eq([rules.mode_name, rules.target, rules.round_cap, rules.draw_round], [&"firefight", 7, 3, 4], "Firefight reads firefight_target")


func test_default_run_config_targets() -> void:
	var cfg: RunConfig = tree.root.get_node("CardDB").get_run_config()
	assert_not_null(cfg, "run_config.tres loaded")
	var zc: ModeRules = ModeRules.create(ZC, cfg)
	var ff: ModeRules = ModeRules.create(FF, cfg)
	assert_eq([zc.target, ff.target, zc.round_cap, zc.draw_round], [6, 7, 8, 10], "core-rules §10 numbers")
	for slot: RunMatchData in cfg.matches:
		assert_true(ModeRules.MODES.has(slot.mode), "every run match uses a prototype mode")


func test_detonator_falls_back_to_zone_control() -> void:
	# Detonator is out of the prototype (Rulings 11/12); the validator warns, the rules fall back.
	var rules: ModeRules = ModeRules.create(DataEnums.GameMode.DETONATOR)
	assert_eq([rules.mode, rules.mode_name, rules.target], [ZC, &"zone_control", 6], "fallback")


func test_initiative_follows_mode_score() -> void:
	var m: MatchState = _match(FF)
	m.sides[P].score = 2
	m.sides[E].score = 1
	m.resolve_round()
	assert_eq(m.initiative, E, "enemy behind -> enemy first")
	m.begin_round()
	m.sides[E].score = 2
	m.resolve_round()
	assert_eq(m.initiative, P, "tie -> player")


func test_hooks_without_mode_never_end() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, _holder_unit(), F.LEFT)
	_advance(m, 12)
	assert_eq([m.result, m.round_number, m.sides[P].score], [&"", 13, 0], "p04 sandbox: no mode, no score, no end")


# --- Typical matches (real data) ----------------------------------------------------------

func _typical_rounds(mode: int) -> Array[int]:
	var cfg: RunConfig = tree.root.get_node("CardDB").get_run_config()
	var rounds: Array[int] = []
	for i: int in cfg.matches.size():
		for k: int in 6:
			var m: MatchState = Sim.match_for(cfg, cfg.matches[i], 1000 + k * 13 + i, mode)
			Sim.play_out(m)
			assert_eq(m.phase, MatchState.Phase.ENDED, "match %d seed %d ended" % [i, k])
			rounds.append(int(_outcome(m)["rounds"]))
	return rounds


func _check_typical(mode: int, label: String) -> void:
	var rounds: Array[int] = _typical_rounds(mode)
	var within: int = rounds.filter(func(r: int) -> bool: return r <= 8).size()
	rounds.sort()
	assert_true(rounds.back() <= 10, "%s: never past round 10 (%s)" % [label, str(rounds)])
	assert_true(rounds[rounds.size() / 2] <= 8, "%s: median within 8 rounds (%s)" % [label, str(rounds)])
	assert_true(within * 10 >= rounds.size() * 9, "%s: at least 90%% finish within 8 rounds (%d/%d)" % [label, within, rounds.size()])


func test_typical_zone_control_matches_finish_within_eight_rounds() -> void:
	_check_typical(ZC, "Zone Control")


func test_typical_firefight_matches_finish_within_eight_rounds() -> void:
	_check_typical(FF, "Firefight")
