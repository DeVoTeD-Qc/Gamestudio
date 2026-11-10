# firefight_resolver.gd
# Purpose: The Firefight phase (core-rules §2.4, Rulings 5/6/8, firefight-order.md §2), stateless
#   and deterministic (no randomness at all):
#   0. Killstreak strikes (kc-ks-seq, killstreak_strikes.gd): the strikes queued at Reveal (Mortar
#      Barrage) and the START_OF_FIREFIGHT effects registered earlier (Attack Helo) hit one at a
#      time, oldest first, then this round's in Reveal order; each strike's dead are removed before
#      the next; then the lines close up.
#   1. Columns resolve in order A (left) -> B (mid) -> C (right); a column fights only when both
#      sides have units in it. In a column:
#      a. Suppress N: each Suppress N unit gives the enemy front unit -N FP this round (it pins that
#         unit, not the slot; kc-wip-impl: the Gunner is Suppress 2, the Riot Shield Suppress 1).
#      b. Beats until the column is resolved. In a beat the front-most living unit of each side
#         that has not fired this round shoots; the two shots are simultaneous. First Shot
#         exchange (head's answer O2): when exactly one of the two has First Shot, it fires first
#         in its own beat and its damage lands at once; a partner it kills never fires.
#         Each shot picks its target at that moment (front unit; Pick: lowest Armor, ties
#         front-most; Flank: back-most; untargetable units skipped by Pick / Flank). Damage =
#         FP - target Cover (both read live, so links / auras / sets follow the board). Damage
#         beyond what the target needs is lost, unless the shooter has Pierce: then it carries to
#         the next enemy behind the target (that unit's Cover applies) while any is left.
#         Damage lands, the dead are removed (On Down resolves on the board as it is then) and the
#         lines move up. Every unit fires at most once per round (`RulesUnit.fired`; moving up
#         never resets it). The column ends when one side has no units left in it, or no unit on
#         either side can still fire.
#         kc-wip-impl Beam (Laser Gunner, wip-set.md §2.4): a Beam unit's shot, in its own beat, hits
#         each living unit of its own side ahead of it in its line and every living enemy in the
#         column, its FP each minus that unit's Cover (no Pick / Flank / Pierce). A friendly unit it
#         downs gives nobody credit (the killer's side is the victim's). Event BEAM_FIRED.
#      c. Patch N: each living Medic heals the most damaged other friendly unit in the column.
#   Event stream (playback; firefight-order.md "Implementation notes"):
#     FIREFIGHT_STARTED {zone}, SUPPRESSED, then per beat FIREFIGHT_BEAT {zone, beat, shooters,
#     exchange}, SHOT_FIRED (step &"beat" / &"first_shot"), PIERCE_CARRIED, DAMAGE_DEALT,
#     SURVIVED_LETHAL, UNIT_ELIMINATED (+ On Down events), LINE_ADVANCED; then PATCHED and
#     FIREFIGHT_COLUMN_ENDED {zone, beats}.
# Dependencies: DataEnums, RulesUnit, RulesSide, RulesEvent, EffectResolver (MatchState passed in).
# Author: Mechanics Developer Agent
class_name FirefightResolver
extends RefCounted

## Firepower the enemy point man loses per Suppress unit (core-rules §1). kc-wip-impl: the default of
## Suppress N (RulesUnit.suppress_amount; the Gunner's Suppress 2).
const SUPPRESS_AMOUNT: int = 2
## SHOT_FIRED.step values. STEP_FIRST_SHOT: the shooter has First Shot (it fires before a partner
## without it, or trades at once with a partner that also has it); STEP_BEAT: any other shot.
## STEP_MAIN is no longer emitted (the old two-step resolver); kept so older playback code reads.
const STEP_BEAT: StringName = &"beat"
const STEP_FIRST_SHOT: StringName = &"first_shot"
const STEP_MAIN: StringName = &"main"
## FIREFIGHT_BEAT.exchange values.
const EXCHANGE_TOGETHER: int = 0   ## both shooters fire at once (or only one side has a shooter)
const EXCHANGE_FIRST_SHOT: int = 1 ## the First Shot beat of a split exchange
const EXCHANGE_REPLY: int = 2      ## its partner's reply (only if it survived)
## A column has at most 4 units a side, so at most 8 beats; this is only a loop guard.
const MAX_BEATS: int = 16
## Playback (head's answer O4, for the UI): x1 for the first runs (until the tutorial is done),
## x2 after; tap-to-skip always allowed. Timing model at x1 (firefight-order.md §5).
const PLAYBACK_SPEED_FIRST_RUNS: float = 1.0
const PLAYBACK_SPEED_AFTER_TUTORIAL: float = 2.0
const PLAYBACK_TAP_TO_SKIP: bool = true
const PLAYBACK_COLUMN_S: float = 0.4
const PLAYBACK_BEAT_S: float = 0.8
const PLAYBACK_ADVANCE_S: float = 0.35


static func resolve(state) -> void:
	var rows: Dictionary = _rows(state)
	# Step 0: Killstreak strikes (kc-ks-seq, killstreak_strikes.gd), one at a time in queue order.
	KillstreakStrikes.resolve_step0(state)
	state.process_eliminations()
	_emit_advances(state, rows)
	for z: int in state.ZONE_COUNT:
		if has_firefight(state, z):
			resolve_zone(state, z)
	for s: RulesSide in state.sides:
		for u: RulesUnit in s.units_on_board():
			u.fired = false


## True when both sides have units in zone z.
static func has_firefight(state, z: int) -> bool:
	return not state.sides[0].line(z).is_empty() and not state.sides[1].line(z).is_empty()


static func resolve_zone(state, z: int) -> void:
	state.emit_event(RulesEvent.FIREFIGHT_STARTED, {"zone": state.zone_name(z)})
	_suppress(state, z)
	var beats: int = _run_beats(state, z)
	_patch(state, z)
	state.emit_event(RulesEvent.FIREFIGHT_COLUMN_ENDED, {"zone": state.zone_name(z), "beats": beats})


static func _suppress(state, z: int) -> void:
	for si: int in state.side_order():
		for u: RulesUnit in state.sides[si].line(z):
			if not u.suppress:
				continue
			var foe_line: Array = state.sides[1 - si].line(z)
			if foe_line.is_empty():
				continue
			var target: RulesUnit = foe_line[0]
			var amount: int = maxi(1, u.suppress_amount)
			target.add_mod(DataEnums.EffectKind.MODIFY_FIREPOWER, -amount, state.round_number)
			state.emit_event(RulesEvent.SUPPRESSED, {"side": state.side_name(si), "uid": u.uid,
					"target_uid": target.uid, "amount": amount, "zone": state.zone_name(z)})


## Next shooter of side si in column z: the front-most living unit that has not fired (null = none).
static func next_shooter(state, si: int, z: int) -> RulesUnit:
	for u: RulesUnit in state.sides[si].line(z):
		if u.is_alive() and not u.fired:
			return u
	return null


## Runs the beats of column z (§2.2 / §2.3). Returns the number of beats played.
static func _run_beats(state, z: int) -> int:
	var beat: int = 0
	while beat < MAX_BEATS:
		if not has_firefight(state, z):
			break
		var shooters: Array[RulesUnit] = []
		for si: int in state.side_order():
			var u: RulesUnit = next_shooter(state, si, z)
			if u != null:
				shooters.append(u)
		if shooters.is_empty():
			break
		if shooters.size() == 2 and state.has_first_shot(shooters[0]) != state.has_first_shot(shooters[1]):
			var first: RulesUnit = shooters[0] if state.has_first_shot(shooters[0]) else shooters[1]
			var second: RulesUnit = shooters[1] if first == shooters[0] else shooters[0]
			beat += 1
			_beat(state, z, beat, [first], EXCHANGE_FIRST_SHOT)
			if second.is_alive() and second.zone == z and has_firefight(state, z):
				beat += 1
				_beat(state, z, beat, [second], EXCHANGE_REPLY)
			continue
		beat += 1
		_beat(state, z, beat, shooters, EXCHANGE_TOGETHER)
	return beat


## One beat: the shooters fire at once (targets and damage read now), then damage lands,
## the dead are removed and the lines move up.
static func _beat(state, z: int, beat: int, shooters: Array, exchange: int) -> void:
	var uids: Array[int] = []
	for u: RulesUnit in shooters:
		uids.append(u.uid)
	state.emit_event(RulesEvent.FIREFIGHT_BEAT, {"zone": state.zone_name(z), "beat": beat, "shooters": uids,
			"exchange": exchange, "first_shot_split": exchange != EXCHANGE_TOGETHER})
	var rows: Dictionary = _rows(state)
	var hits: Array = []  # [target, damage, src], in shot order
	for u: RulesUnit in shooters:
		u.fired = true
		var si: int = u.side
		var step: StringName = STEP_FIRST_SHOT if state.has_first_shot(u) else STEP_BEAT
		if u.beam:
			_beam(state, z, beat, u, step, hits)
			continue
		var foe_line: Array = state.sides[1 - si].line(z)
		var target: RulesUnit = pick_target(state, u, foe_line, {})
		if target == null:
			state.emit_event(RulesEvent.SHOT_FIRED, {"side": state.side_name(si), "shooter_uid": u.uid,
					"target_uid": -1, "zone": state.zone_name(z), "damage": 0, "step": step, "beat": beat,
					"overkill": 0, "pierce": state.has_pierce(u)})
			continue
		var src: Dictionary = _source(state, si, u)
		var dmg: int = maxi(0, state.firepower_of(u) - state.cover_of(target))
		hits.append([target, dmg, src])
		state.emit_event(RulesEvent.SHOT_FIRED, {"side": state.side_name(si), "shooter_uid": u.uid,
				"target_uid": target.uid, "zone": state.zone_name(z), "damage": dmg, "step": step, "beat": beat,
				"overkill": maxi(0, dmg - target.armor), "pierce": state.has_pierce(u)})
		if state.has_pierce(u):  # kc-v2-impl: Breach Point gives Pierce
			_pierce(state, z, beat, u, src, foe_line, target, dmg - target.armor, hits)
	for h: Array in hits:
		state.deal_damage(h[0], int(h[1]), h[2], false)
	state.process_eliminations()
	_emit_advances(state, rows)


## kc-wip-impl Beam: the shot of `u` hits each living friendly ahead of it in its line, then every
## living enemy in column z (its FP each, minus each target's Cover). Hits land with the beat's others.
static func _beam(state, z: int, beat: int, u: RulesUnit, step: StringName, hits: Array) -> void:
	var si: int = u.side
	var src: Dictionary = _source(state, si, u)
	var fp: int = state.firepower_of(u)
	var targets: Array[RulesUnit] = []
	var own: Array = state.sides[si].line(z)
	for i: int in own.find(u):
		if (own[i] as RulesUnit).is_alive():
			targets.append(own[i])
	var first_enemy: RulesUnit = null
	for e: RulesUnit in state.sides[1 - si].line(z):
		if e.is_alive():
			targets.append(e)
			if first_enemy == null:
				first_enemy = e
	var listed: Array[Dictionary] = []
	for t: RulesUnit in targets:
		var dmg: int = maxi(0, fp - state.cover_of(t))
		hits.append([t, dmg, src])
		listed.append({"uid": t.uid, "side": state.side_name(t.side), "damage": dmg, "friendly": t.side == si})
	# Playback reads SHOT_FIRED for the tracer: the beam's shot at the first enemy it hits.
	state.emit_event(RulesEvent.SHOT_FIRED, {"side": state.side_name(si), "shooter_uid": u.uid,
			"target_uid": first_enemy.uid if first_enemy != null else -1, "zone": state.zone_name(z),
			"damage": maxi(0, fp - state.cover_of(first_enemy)) if first_enemy != null else 0, "step": step,
			"beat": beat, "overkill": 0, "pierce": false, "beam": true})
	state.emit_event(RulesEvent.BEAM_FIRED, {"side": state.side_name(si), "shooter_uid": u.uid,
			"zone": state.zone_name(z), "beat": beat, "hits": listed})


## Pierce: `left` damage beyond what `from` needs carries down the enemy line (Cover applies).
static func _pierce(state, z: int, beat: int, u: RulesUnit, src: Dictionary, foe_line: Array,
		from: RulesUnit, left: int, hits: Array) -> void:
	var idx: int = foe_line.find(from)
	var prev: RulesUnit = from
	while left > 0 and idx + 1 < foe_line.size():
		idx += 1
		var nxt: RulesUnit = foe_line[idx]
		if not nxt.is_alive():
			continue
		var cov: int = state.cover_of(nxt)
		var d2: int = mini(maxi(0, left - cov), nxt.armor)
		state.emit_event(RulesEvent.PIERCE_CARRIED, {"side": state.side_name(u.side), "shooter_uid": u.uid,
				"from_uid": prev.uid, "target_uid": nxt.uid, "carried": left, "damage": d2,
				"zone": state.zone_name(z), "beat": beat})
		if d2 > 0:
			hits.append([nxt, d2, src])
		left -= cov + nxt.armor
		prev = nxt


## {uid: [side, zone, row]} for every unit on the board (to report line advances).
static func _rows(state) -> Dictionary:
	var out: Dictionary = {}
	for si: int in 2:
		for z: int in state.ZONE_COUNT:
			var line: Array = state.sides[si].line(z)
			for i: int in line.size():
				out[(line[i] as RulesUnit).uid] = [si, z, i]
	return out


## LINE_ADVANCED {side, zone, moves: [{uid, from_row, to_row}]} for each line whose survivors moved up.
static func _emit_advances(state, before: Dictionary) -> void:
	for si: int in state.side_order():
		for z: int in state.ZONE_COUNT:
			var line: Array = state.sides[si].line(z)
			var moves: Array[Dictionary] = []
			for i: int in line.size():
				var u: RulesUnit = line[i]
				var was: Array = before.get(u.uid, [])
				if was.size() == 3 and int(was[0]) == si and int(was[1]) == z and int(was[2]) > i:
					moves.append({"uid": u.uid, "from_row": int(was[2]), "to_row": i})
			if not moves.is_empty():
				state.emit_event(RulesEvent.LINE_ADVANCED, {"side": state.side_name(si), "zone": state.zone_name(z),
						"moves": moves})


static func _source(state, si: int, u: RulesUnit) -> Dictionary:
	return {"side": si, "uid": u.uid, "source_id": u.source_id,
			"source_kind": state.SRC_OPERATOR if u.is_operator else state.SRC_UNIT}


## Target of one shot. `assigned` (uid -> damage already promised) skips doomed units; in the beat
## order damage lands before the next shot, so the resolver passes {}. Null when there is no enemy.
static func pick_target(state, shooter: RulesUnit, foe_line: Array, assigned: Dictionary) -> RulesUnit:
	var candidates: Array[RulesUnit] = []
	for u: RulesUnit in foe_line:
		if u.is_alive() and int(assigned.get(u.uid, 0)) < u.armor:
			candidates.append(u)
	if candidates.is_empty():
		return null
	# kc-v2-impl: Smoke turns Pick / Flank off in its column (state.can_pick / can_flank).
	var picks: bool = state.can_pick(shooter)
	if picks or state.can_flank(shooter):
		var eligible: Array[RulesUnit] = []
		for u: RulesUnit in candidates:
			if not state.is_untargetable_by_pick_flank(u):
				eligible.append(u)
		if not eligible.is_empty():
			if picks:
				var best: RulesUnit = eligible[0]
				for u: RulesUnit in eligible:
					if u.armor - int(assigned.get(u.uid, 0)) < best.armor - int(assigned.get(best.uid, 0)):
						best = u
				return best
			return eligible.back()
	return candidates[0]


static func _patch(state, z: int) -> void:
	for si: int in state.side_order():
		var line: Array = state.sides[si].line(z)
		for medic: RulesUnit in line:
			if medic.patch <= 0 or not medic.is_alive():
				continue
			var best: RulesUnit = EffectResolver.most_damaged(state, line, medic)
			if best == null:
				continue
			var healed: int = mini(medic.patch, best.damage_taken(state.round_number))
			best.armor += healed
			state.emit_event(RulesEvent.PATCHED, {"side": state.side_name(si), "uid": medic.uid,
					"target_uid": best.uid, "amount": healed, "zone": state.zone_name(z)})


## Default Firefight playback speed for the UI (O4); a saved player setting overrides it.
static func default_playback_speed(tutorial_done: bool) -> float:
	return PLAYBACK_SPEED_AFTER_TUTORIAL if tutorial_done else PLAYBACK_SPEED_FIRST_RUNS


## Seconds a slice of the event stream takes at x1 under the timing model (banners, beats, advances).
static func playback_seconds(events: Array) -> float:
	var s: float = 0.0
	for e: Dictionary in events:
		match e.get("type", &""):
			RulesEvent.FIREFIGHT_STARTED: s += PLAYBACK_COLUMN_S
			RulesEvent.FIREFIGHT_BEAT: s += PLAYBACK_BEAT_S
			RulesEvent.LINE_ADVANCED: s += PLAYBACK_ADVANCE_S
	return s
