# mode_rules.gd
# Purpose: Win conditions of the prototype game modes (core-rules §4, §9, Ruling 12,
#   Rulings part 2 #13): mode scoring at the end of each round, the round cap,
#   overtime and draw, and the match-end outcome the run layer (p10) consumes.
#   The mode is data: RunMatchData.mode picks a row of MODES (what scores, which
#   RunConfig field holds the target); all numbers come from RunConfig
#   (zone_control_target, firefight_target, round_cap, overtime_draw_round).
#
#   - Zone Control: +1 point per zone you control at the Score step.
#   - Firefight:    +1 per credited elimination this round (Operator downs count;
#                   killstreak kills count; Sentries and own-side losses give no credit).
#   End check after every round (the match only ends at a round-end):
#   1. One side leads and the leader has reached the target  -> leader wins (target).
#      Both at/over the target but tied -> play on; the next round-end with a leader wins.
#   2. Round `round_cap` (8) with a leader                   -> leader wins (round_cap).
#   3. Overtime, rounds 9..overtime_draw_round (10): first round-end with a leader wins.
#   4. Still tied at the end of round overtime_draw_round   -> draw (no ticket lost).
#
#   Wiring (p10 builds the match):
#     var hooks := MatchHooks.new()          # or the p05 hooks subclass
#     hooks.mode_rules = ModeRules.create(match_data.mode, run_config)
#     var m := MatchState.new(run_config, match_data.map, player, enemy, seed, hooks)
#   After the match: m.result (&"player" / &"enemy" / &"draw") and
#   hooks.mode_rules.outcome (see _build_outcome), also carried by the MATCH_ENDED event.
#   MatchHooks without mode_rules keeps the p04 sandbox behaviour (never ends).
# Dependencies: DataEnums, RunConfig, RulesEvent (MatchState passed in untyped).
# Author: Mechanics Developer Agent
class_name ModeRules
extends RefCounted

const RESULT_PLAYER: StringName = &"player"
const RESULT_ENEMY: StringName = &"enemy"
const RESULT_DRAW: StringName = &"draw"

## Why the match ended (outcome.reason).
const REASON_TARGET: StringName = &"target"
const REASON_ROUND_CAP: StringName = &"round_cap"
const REASON_OVERTIME: StringName = &"overtime"
const REASON_DRAW: StringName = &"overtime_draw"

## What earns mode points.
enum ScoreSource { CONTROLLED_ZONES, ELIMINATIONS }

## Mode table: the only place a mode is described. Detonator is out of the
## prototype (Ruling 11) and falls back to Zone Control with a warning.
const MODES: Dictionary = {
	DataEnums.GameMode.ZONE_CONTROL: {
		"name": &"zone_control", "score": ScoreSource.CONTROLLED_ZONES, "target_field": "zone_control_target",
	},
	DataEnums.GameMode.FIREFIGHT: {
		"name": &"firefight", "score": ScoreSource.ELIMINATIONS, "target_field": "firefight_target",
	},
}
const FALLBACK_MODE: int = DataEnums.GameMode.ZONE_CONTROL

var mode: int = FALLBACK_MODE
var mode_name: StringName = &"zone_control"
var score_source: ScoreSource = ScoreSource.CONTROLLED_ZONES
## Points needed to win before the round cap.
var target: int = 6
## Last regular round; a tie here starts overtime.
var round_cap: int = 8
## Last overtime round; still tied after it -> draw.
var draw_round: int = 10
## Points each side gained in the last scored round [player, enemy].
var last_gain: Array[int] = [0, 0]
## Empty while the match runs; filled once by check_match_end (see _build_outcome).
var outcome: Dictionary = {}


## Mode rules for a RunMatchData.mode value, numbers from `config` (defaults if null).
static func create(p_mode: int, config: RunConfig = null) -> ModeRules:
	var rules: ModeRules = ModeRules.new()
	rules.configure(p_mode, config)
	return rules


func configure(p_mode: int, config: RunConfig = null) -> void:
	var cfg: RunConfig = config if config != null else RunConfig.new()
	if not MODES.has(p_mode):
		push_warning("ModeRules: mode %s is not in the prototype; using Zone Control" % DataEnums.key_of(DataEnums.GameMode, p_mode))
		p_mode = FALLBACK_MODE
	var row: Dictionary = MODES[p_mode]
	mode = p_mode
	mode_name = row["name"]
	score_source = row["score"]
	target = int(cfg.get(row["target_field"]))
	round_cap = cfg.round_cap
	draw_round = maxi(cfg.overtime_draw_round, cfg.round_cap)
	last_gain = [0, 0]
	outcome = {}


# =============================================================================
# Hooks (called through MatchHooks)
# =============================================================================

## Default initiative (core-rules §2.3): the side behind on the mode score; ties -> player.
func initiative_side(state) -> int:
	var p: int = state.sides[0].score
	var e: int = state.sides[1].score
	if p != e:
		return 1 if e < p else 0
	return tie_initiative(state)


## Initiative tie rule (kc-syn-tune what-if; balance tools set it, see synergy-system.md §12).
##   player: the player; enemy: the enemy; alt: odd rounds the player, even rounds the enemy;
##   other: whoever did not hold it last round (round 1: the player); coin: round 1 a seeded
##   coin flip, then whoever did not hold it last round; random: a seeded coin flip every tie.
static var tiebreak: StringName = &"player"


func tie_initiative(state) -> int:
	var rnd: int = int(state.round_number)
	match tiebreak:
		&"enemy":
			return 1
		&"alt":
			return 0 if rnd % 2 == 1 else 1
		&"other":
			return 0 if rnd <= 1 else 1 - int(state.initiative)
		&"coin":
			return coin(state, 1) if rnd <= 1 else 1 - int(state.initiative)
		&"random":
			return coin(state, rnd)
	return 0


## Seeded coin flip (0 or 1) for `round`; does not touch the match RNG, so draws stay the same.
static func coin(state, rnd: int) -> int:
	return hash([int(state.seed_value), rnd, &"initiative"]) & 1


## Score step: add this round's mode points. `control` = control_of() per zone,
## taken at the start of the Score step (the same values as the ZONE_CONTROL events).
func score_round(state, control: Array) -> void:
	for si: int in 2:
		last_gain[si] = points_for_round(state, si, control)
		state.sides[si].score += last_gain[si]
	state.emit_event(RulesEvent.MODE_SCORED, {
		"mode": mode_name,
		"player_gained": last_gain[0], "enemy_gained": last_gain[1],
		"player_score": state.sides[0].score, "enemy_score": state.sides[1].score,
		"target": target,
	})


## Points `side` earns this round under this mode.
func points_for_round(state, side: int, control: Array) -> int:
	var n: int = 0
	match score_source:
		ScoreSource.CONTROLLED_ZONES:
			for c: int in control:
				if c == side:
					n += 1
		ScoreSource.ELIMINATIONS:
			var me: StringName = state.side_name(side)
			for rec: Dictionary in state.round_eliminations:
				if rec["credit"] and rec["by_side"] == me:
					n += 1
	return n


## &"player" / &"enemy" / &"draw" to end the match now, &"" to play on.
## Emits OVERTIME_STARTED when the round cap ends tied.
func check_match_end(state) -> StringName:
	if not outcome.is_empty():
		return outcome["result"]
	var r: int = state.round_number
	var p: int = state.sides[0].score
	var e: int = state.sides[1].score
	var result: StringName = &""
	var reason: StringName = &""
	if p != e:
		var leader_score: int = maxi(p, e)
		if r > round_cap:
			reason = REASON_OVERTIME
		elif leader_score >= target:
			reason = REASON_TARGET
		elif r == round_cap:
			reason = REASON_ROUND_CAP
		if reason != &"":
			result = RESULT_PLAYER if p > e else RESULT_ENEMY
	elif r >= draw_round:
		result = RESULT_DRAW
		reason = REASON_DRAW
	elif r == round_cap:
		state.emit_event(RulesEvent.OVERTIME_STARTED, {
			"player_score": p, "enemy_score": e, "last_round": draw_round,
		})
	if result != &"":
		outcome = _build_outcome(state, result, reason)
	return result


## Extra MATCH_ENDED fields (the outcome minus `result`, which MatchState adds).
func match_end_details(_state) -> Dictionary:
	return outcome.duplicate()


# =============================================================================
# Queries (UI / AI)
# =============================================================================

func is_overtime(round_number: int) -> bool:
	return round_number > round_cap


## Points `side` still needs to reach the target (0 once reached).
func points_to_target(state, side: int) -> int:
	return maxi(0, target - int(state.sides[side].score))


func _build_outcome(state, result: StringName, reason: StringName) -> Dictionary:
	return {
		"result": result,
		"winner": result if result != RESULT_DRAW else &"",
		"is_draw": result == RESULT_DRAW,
		"reason": reason,
		"mode": mode_name,
		"rounds": int(state.round_number),
		"overtime": is_overtime(state.round_number),
		"player_score": int(state.sides[0].score),
		"enemy_score": int(state.sides[1].score),
		"target": target,
		"player_eliminations": int(state.sides[0].eliminations),
		"enemy_eliminations": int(state.sides[1].eliminations),
	}
