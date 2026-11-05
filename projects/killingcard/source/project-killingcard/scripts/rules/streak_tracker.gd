# streak_tracker.gd
# Purpose: The streak meter and the Streak Tray (core-rules §2.5, Rulings 12-14 and
#   Rulings part 2 #12-14). Stateless and static: all state lives in RulesSide
#   (streak, streak_tray, earned_this_life). MatchHooks delegates to it.
#   Score order per side: + credited, streak-qualifying eliminations of this round
#   + effect bonuses (Wren, Comms Relay, Objective Focus) -> check thresholds and
#   fill the Streak Tray -> reset to 0 if the Operator went down this round.
# Dependencies: DataEnums, LoadoutItem, RulesSide, RulesEvent (MatchState passed in).
# Author: Mechanics Developer Agent
class_name StreakTracker
extends RefCounted

## Rulings part 2 #14 (the p03 open question): eliminations by your Equipment
## (Tripwire) and by On Down triggers (Demolitions Expert) count for the streak.
## Flip to false to exclude both; nothing else needs to change.
const EQUIPMENT_AND_ON_DOWN_COUNT_FOR_STREAK: bool = true

## Interpretation: a Sentry (a unit summoned by a killstreak) makes killstreak
## eliminations, so its kills give no streak, like the other killstreaks'.
const SUMMONED_BY_KILLSTREAK_COUNT_FOR_STREAK: bool = false

## Lowest threshold Streak Discipline (or any STREAK_THRESHOLD_MOD) can reach.
const MIN_THRESHOLD: int = 1


## Does this UNIT_ELIMINATED record add +1 to the streak of the side that made it?
## The single source of truth for "you eliminate" (streak, Field Salvage).
static func counts_for_streak(state, rec: Dictionary) -> bool:
	if not rec.get("credit", false) or rec.get("by_killstreak", false):
		return false
	var kind: StringName = rec.get("source_kind", &"")
	if not EQUIPMENT_AND_ON_DOWN_COUNT_FOR_STREAK and kind in [state.SRC_EQUIPMENT, state.SRC_ON_DOWN]:
		return false
	if not SUMMONED_BY_KILLSTREAK_COUNT_FOR_STREAK and kind == state.SRC_UNIT:
		var by_side: int = 0 if rec.get("by_side", &"") == &"player" else 1
		if rec.get("by_id", &"") in killstreak_summon_ids(state, by_side):
			return false
	return true


## Card ids of units this side's killstreaks summon (the Sentry).
static func killstreak_summon_ids(state, side: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for ks: LoadoutItem in state.sides[side].setup.killstreaks:
		if ks == null:
			continue
		for e: EffectData in ks.effects:
			if e != null and e.kind == DataEnums.EffectKind.SUMMON_UNIT and e.summon_card != null:
				out.append(e.summon_card.id)
	return out


## Streak needed for a killstreak: printed threshold + STREAK_THRESHOLD_MOD of the
## side's perks (Streak Discipline -1), never below MIN_THRESHOLD.
static func threshold_for(state, side: int, ks: LoadoutItem) -> int:
	var t: int = ks.streak_threshold
	for perk: LoadoutItem in state.sides[side].setup.perks:
		if perk == null:
			continue
		for e: EffectData in perk.effects:
			if e != null and e.kind == DataEnums.EffectKind.STREAK_THRESHOLD_MOD and e.trigger == DataEnums.Trigger.PASSIVE:
				t += e.amount
	return maxi(MIN_THRESHOLD, t)


## Score & Streak step, streak part (replaces the p04 baseline in MatchHooks).
static func apply_streak(state, side: int) -> void:
	var s: RulesSide = state.sides[side]
	var me: StringName = state.side_name(side)
	var gained: int = s.streak_bonus_this_round
	for rec: Dictionary in state.round_eliminations:
		if rec["by_side"] == me and counts_for_streak(state, rec):
			gained += 1
	var before: int = s.streak
	s.streak = maxi(0, s.streak + gained)
	var earned: Array[StringName] = fill_tray(state, side)
	var reset: bool = s.operator_down_this_round
	if reset:
		s.streak = 0
		s.earned_this_life.clear()
	if gained != 0 or reset or not earned.is_empty():
		state.emit_event(RulesEvent.STREAK_CHANGED, {
			"side": me, "streak": s.streak, "before": before, "gained": gained,
			"reset": reset, "earned": earned,
		})


## Puts every killstreak whose threshold the current streak reaches, and that was
## not earned yet this life, into the Streak Tray. Returns the ids earned now.
static func fill_tray(state, side: int) -> Array[StringName]:
	var s: RulesSide = state.sides[side]
	var earned: Array[StringName] = []
	for ks: LoadoutItem in s.setup.killstreaks:
		if ks == null or ks.id in s.earned_this_life:
			continue
		var t: int = threshold_for(state, side, ks)
		if s.streak >= t:
			s.earned_this_life.append(ks.id)
			earned.append(ks.id)
			if ks.id not in s.streak_tray:
				s.streak_tray.append(ks.id)
			state.emit_event(RulesEvent.KILLSTREAK_EARNED, {
				"side": state.side_name(side), "item_id": ks.id, "streak": s.streak, "threshold": t,
			})
	return earned


## Adds a killstreak to the tray directly (tutorial scripts, tests).
static func grant(state, side: int, item_id: StringName) -> void:
	var s: RulesSide = state.sides[side]
	if item_id not in s.streak_tray:
		s.streak_tray.append(item_id)


## Ids in the tray, for the UI / AI.
static func tray(state, side: int) -> Array[StringName]:
	return state.sides[side].streak_tray.duplicate()


## Streak still needed for each of the side's killstreaks (0 = in tray / earned this life).
static func progress(state, side: int) -> Dictionary:
	var s: RulesSide = state.sides[side]
	var out: Dictionary = {}
	for ks: LoadoutItem in s.setup.killstreaks:
		if ks == null:
			continue
		var t: int = threshold_for(state, side, ks)
		out[ks.id] = {"threshold": t, "in_tray": ks.id in s.streak_tray,
				"earned_this_life": ks.id in s.earned_this_life, "needed": maxi(0, t - s.streak)}
	return out
