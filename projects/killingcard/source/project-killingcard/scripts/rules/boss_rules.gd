# boss_rules.gd
# Purpose: The three boss rules of run-v2.md §4, one line each, each on a system the player knows:
#     reinforcements  Meridian_Six:     from round meridian_supply_from (5; kc-v2-tune, head I2), +meridian_supply (1) Supply every round
#     dug_in          Bulwark Prime:    starts the match with a Mortar Pit (a real enemy Field) in every column
#                                       (prime_pit_zones); Overrun tears them down as any Field
#     horde           The Hollow Choir: from round choir_from_round (2), a 1/2 Shambler (token: no control,
#                                       Pick and Flank ignore it, its kills count) joins the back of its
#                                       emptiest column every round
#   The boss side is always MatchState.ENEMY. Static; the match's boss fields (boss_rule, boss_card, the
#   numbers from RunConfig) live on MatchState so MatchClone copies them.
# Dependencies: RulesCard, RulesUnit, RulesEvent, SynergyRules (MatchState passed in).
# Author: Mechanics Developer Agent (kc-v2-impl)
class_name BossRules
extends RefCounted

const REINFORCEMENTS: StringName = &"reinforcements"
const DUG_IN: StringName = &"dug_in"
const HORDE: StringName = &"horde"
const RULES: Array[StringName] = [REINFORCEMENTS, DUG_IN, HORDE]
const BOSS_SIDE: int = 1


## Match start (after decks and Operators): Dug In places its pits.
static func on_match_start(state) -> void:
	if state.boss_rule != DUG_IN or state.boss_card == null:
		return
	var s = state.sides[BOSS_SIDE]
	for z: int in state.config.prime_pit_zones:
		if z < 0 or z > 2:
			continue
		var rc: RulesCard = RulesCard.new(state.new_uid(), state.boss_card, SynergyRules.TRAIT_DEFAULT)
		s.equipment[z].append({"card": rc, "round": 1})
		state.emit_event(RulesEvent.EQUIPMENT_PLACED, {"side": state.side_name(BOSS_SIDE), "card_uid": rc.uid,
				"card_id": rc.card.id, "zone": state.zone_name(z), "hidden": false})
		state.emit_event(RulesEvent.BOSS_RULE_TRIGGERED, {"rule": DUG_IN, "side": state.side_name(BOSS_SIDE),
				"zone": state.zone_name(z), "card_uid": rc.uid, "what": "Dug In: a Mortar Pit in column %s" % "ABC"[z]})


## Extra Supply the boss gets this round (Briefing).
static func supply_bonus(state, side: int) -> int:
	if side != BOSS_SIDE or state.boss_rule != REINFORCEMENTS:
		return 0
	return state.config.meridian_supply if state.round_number >= state.config.meridian_supply_from else 0


## Briefing, after Supply and draws: Horde's Shambler.
static func on_briefing(state) -> void:
	if state.boss_rule == REINFORCEMENTS:
		var extra: int = supply_bonus(state, BOSS_SIDE)
		if extra > 0:
			state.emit_event(RulesEvent.BOSS_RULE_TRIGGERED, {"rule": REINFORCEMENTS, "side": state.side_name(BOSS_SIDE),
					"amount": extra, "what": "Reinforcements: +%d Supply" % extra})
	if state.boss_rule != HORDE or state.boss_card == null or state.round_number < state.config.choir_from_round:
		return
	var best: int = -1
	var best_n: int = 99
	for z: int in 3:
		var n: int = state.sides[BOSS_SIDE].line(z).size()
		if n < state.config.zone_capacity and n < best_n:
			best = z
			best_n = n
	if best < 0:
		return
	var u: RulesUnit = state.create_unit(BOSS_SIDE, state.boss_card)
	state.put_in_line(u, best, false)
	state.emit_event(RulesEvent.BOSS_RULE_TRIGGERED, {"rule": HORDE, "side": state.side_name(BOSS_SIDE),
			"uid": u.uid, "zone": state.zone_name(best), "what": "Horde: a Shambler joins column %s" % "ABC"[best]})


## The round `rule` starts in this config (0 = from the start).
static func start_round(cfg: RunConfig, rule: StringName) -> int:
	match rule:
		REINFORCEMENTS:
			return cfg.meridian_supply_from
		HORDE:
			return cfg.choir_from_round
	return 0


## A boss text with "{from}" replaced by the round its rule starts (player-facing strings never hard-code it).
static func format_text(cfg: RunConfig, rule: StringName, text: String) -> String:
	return text.replace("{from}", str(start_round(cfg, rule)))


## True while the rule is in effect this round (for the plate's lit state).
static func active(state) -> bool:
	match state.boss_rule:
		REINFORCEMENTS:
			return state.round_number >= state.config.meridian_supply_from
		HORDE:
			return state.round_number >= state.config.choir_from_round
		DUG_IN:
			return true
	return false


## When the rule starts, for the plate ("From round 5").
static func note(state) -> String:
	match state.boss_rule:
		REINFORCEMENTS:
			return "From round %d" % start_round(state.config, REINFORCEMENTS)
		HORDE:
			return "From round %d" % state.config.choir_from_round
		DUG_IN:
			return "From the start"
	return ""
