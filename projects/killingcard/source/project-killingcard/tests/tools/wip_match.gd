# wip_match.gd
# Purpose: kc-wip-design sim-only MatchState that plays the Wip set's four NEW mechanics (wip-set.md §2),
#   so the sims can measure them before the engine has them. Nothing in scripts/ changes.
#     Suppress N  At the start of the firefight, each Suppress N unit gives the enemy front unit in its
#                 column -N FP this round (the shipped Suppress is the fixed -2 of FirefightResolver).
#                 Played here before the columns resolve; columns are independent, so this matches
#                 "at the start of its column" except after an Attack Helo kill (rare).
#     Supply      Hacker's On Deploy: +1 Supply in the next round only (terrain_supply_next, the Supply
#                 Cache's slot, so it shows in SUPPLY_GAINED.extra).
#     Agile       Once per round, after Reveal, an Agile unit in a column with no enemy (and another friendly
#                 that keeps holding it) moves to the adjacent column (as the Operator's Rotate) with the most
#                 enemy units and room, at the back. A greedy proxy for the player's order; the AI does not
#                 plan it.
#     Beam        The Laser Gunner's shot hits every unit in front of it in its column: your units ahead
#                 of it and every enemy unit there, its FP each (Cover applies). Played at the start of the
#                 column instead of in its own beat (the sim fires it before the front trades; the rule
#                 fires it in its beat, which can only find fewer friendlies ahead). Friendly downs give
#                 nobody elimination credit (MatchState: by_side == victim side).
#   Premium Loadout: see _reveal_tactic (an AI-playable stand-in).
#   The AI's look-ahead (MatchClone -> plain MatchState) does not know these rules: it values the Hacker,
#   Runner, Riot Shield and Laser Gunner as their printed stats only.
# Author: Sr Game Designer Agent (kc-wip-design)
extends MatchState

const W: GDScript = preload("res://tests/tools/wip_cards.gd")

var wip_supply_next: Array[int] = [0, 0]
## Sim counters: [beam enemy damage, beam friendly damage, beam friendly downs, agile moves, hacker supply].
var wip_stats: Array[int] = [0, 0, 0, 0, 0]


func begin_round() -> void:
	for si: int in 2:
		terrain_supply_next[si] += wip_supply_next[si]
		wip_stats[4] += wip_supply_next[si]
		wip_supply_next[si] = 0
	super.begin_round()


func _arrive(si: int, play: Dictionary) -> bool:
	var ok: bool = super._arrive(si, play)
	if ok and play["kind"] == &"unit":
		var rc: RulesCard = play["card"]
		var amount: int = int(W.SUPPLY_NEXT.get(rc.card.id, 0))
		if amount > 0 and sides[si].find_unit(rc.uid) != null:
			wip_supply_next[si] += amount
	return ok


func firefight() -> void:
	_agile()
	for z: int in ZONE_COUNT:
		if sides[0].line(z).is_empty() or sides[1].line(z).is_empty():
			continue
		_suppress_n(z)
		_beams(z)
	process_eliminations()
	super.firefight()


func _suppress_n(z: int) -> void:
	for si: int in side_order():
		for u: RulesUnit in sides[si].line(z):
			var amount: int = int(W.SUPPRESS_N.get(u.source_id, 0))
			var foe: Array = sides[1 - si].line(z)
			if amount <= 0 or foe.is_empty() or not u.is_alive():
				continue
			var target: RulesUnit = foe[0]
			target.add_mod(DataEnums.EffectKind.MODIFY_FIREPOWER, -amount, round_number)
			emit_event(RulesEvent.SUPPRESSED, {"side": side_name(si), "uid": u.uid, "target_uid": target.uid,
					"amount": amount, "zone": zone_name(z)})


func _beams(z: int) -> void:
	for si: int in side_order():
		var line: Array = sides[si].line(z).duplicate()
		for i: int in line.size():
			var u: RulesUnit = line[i]
			if u.source_id not in W.BEAM or not u.is_alive() or u.fired:
				continue
			u.fired = true
			var fp: int = firepower_of(u)
			var src: Dictionary = {"side": si, "uid": u.uid, "source_id": u.source_id, "source_kind": SRC_UNIT}
			for j: int in i:
				var f: RulesUnit = line[j]
				if f.is_alive():
					var d: int = deal_damage(f, fp, src)
					wip_stats[1] += d
					if not f.is_alive():
						wip_stats[2] += 1
			for e: RulesUnit in sides[1 - si].line(z).duplicate():
				if e.is_alive():
					wip_stats[0] += deal_damage(e, fp, src)


## Premium Loadout (sim stand-in, wip_cards.gd): +1/+1 for good to your front unit in the chosen column.
func _reveal_tactic(si: int, play: Dictionary) -> void:
	var rc: RulesCard = play["card"]
	if rc.card.id != &"premium_loadout":
		super._reveal_tactic(si, play)
		return
	emit_event(RulesEvent.CARD_REVEALED, {"side": side_name(si), "card_uid": rc.uid, "card_id": rc.card.id, "zone": zone_name(play["zone"])})
	var line: Array = sides[si].line(play["zone"]) if is_zone(play["zone"]) else []
	if not line.is_empty():
		var u: RulesUnit = line[0]
		u.add_mod(DataEnums.EffectKind.MODIFY_FIREPOWER, 1, RulesUnit.PERMANENT)
		u.base_max_armor += 1
		u.armor += 1
	sides[si].discard.append(rc)
	emit_event(RulesEvent.CARD_DISCARDED, {"side": side_name(si), "card_uid": rc.uid, "card_id": rc.card.id})


## Agile (greedy proxy, see the header).
func _agile() -> void:
	for si: int in side_order():
		var s: RulesSide = sides[si]
		for u: RulesUnit in s.units_on_board().duplicate():
			if u.source_id not in W.AGILE or not u.is_alive():
				continue
			# Leave only a column with no enemy that another friendly still holds (control is kept).
			if not sides[1 - si].line(u.zone).is_empty() or s.line(u.zone).size() < 2:
				continue
			var best: int = -1
			var best_score: int = 0
			for z: int in ZONE_COUNT:
				if not are_adjacent(u.zone, z) or s.line(z).size() >= config.zone_capacity:
					continue
				var score: int = sides[1 - si].line(z).size() * 2 - s.line(z).size()
				if sides[1 - si].line(z).size() > 0 and (best < 0 or score > best_score):
					best = z
					best_score = score
			if best < 0:
				continue
			var from: int = u.zone
			s.line(from).erase(u)
			put_in_line(u, best)
			wip_stats[3] += 1
			emit_event(RulesEvent.UNIT_MOVED, {"side": side_name(si), "uid": u.uid, "from_zone": zone_name(from),
					"zone": zone_name(best)})
			trigger_traps(si, u)
