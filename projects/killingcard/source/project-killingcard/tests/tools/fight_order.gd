# fight_order.gd
# Purpose: kc-fight PROTOTYPE (sim only, not the game's rules): the firefight activation
#   orders of documentation/design/firefight-order.md, run on the real MatchState through
#   tests/tools/fight_state.gd. The shipped resolver (scripts/rules/firefight_resolver.gd) is
#   untouched; FightState calls this instead when `order` is not &"now".
#     now    the shipped resolver. kc-fight-impl: that IS the beat order now ("seq" + fs=exchange,
#            Pierce from the card data), so `now` is the shipped game and `seq` the prototype copy.
#     seq    "Front to back" (recommended): columns A -> B -> C. In a column, beats: each beat
#            the front-most unit of each side that has not fired yet fires; the two shots of a
#            beat are simultaneous, then damage lands, the dead are removed and the lines close
#            up. Every unit fires at most once per round. First Shot: see `fs_mode`.
#     front  "Front duel" (the literal reading): only the unit at the front of its line fires;
#            when it dies the next unit moves up and fires in the next beat if it has not fired.
#            Units that never reach the front never fire.
#   fs_mode  pass      First Shot units of the column fire first, front to back, in their own
#                      beats (as today's First Shot step, but one beat at a time);
#            exchange  a First Shot unit fires before the unit it trades with in its beat
#                      (its damage lands first; a partner it kills never fires).
#   pierce   card ids with the prototype keyword PIERCE: damage over what the target needs
#            continues to the next enemy behind it in that column (that unit's Cover applies).
#            Without Pierce, damage over the target's Armor is lost.
#   Stats: shots / beats / advances per column for the playback-time estimate.
# Dependencies: MatchState (passed in), FirefightResolver (helpers), RulesUnit, RulesEvent.
# Author: Sr Game Designer Agent (kc-fight)
extends RefCounted

static var order: StringName = &"seq"
static var fs_mode: StringName = &"pass"
static var pierce: Dictionary = {}
## Running counters: {shots, beats, advances, columns, rounds}.
static var stats: Dictionary = {}
## Playback timing model at SPEED x1 (§5): column banner, one beat (shots + damage numbers), line advance.
const PLAYBACK_COLUMN_S: float = 0.4
const PLAYBACK_BEAT_S: float = 0.8
const PLAYBACK_ADVANCE_S: float = 0.35


static func count(key: String, by: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + by


static func resolve(state) -> void:
	for f: Dictionary in state.firefight_effects.duplicate():
		if int(f["until_round"]) >= state.round_number:
			EffectResolver.resolve_effect(state, f["effect"], f["ctx"])
	state.process_eliminations()
	count("rounds")
	var b0: int = int(stats.get("beats", 0))
	var a0: int = int(stats.get("advances", 0))
	var c0: int = int(stats.get("columns", 0))
	for z: int in state.ZONE_COUNT:
		if FirefightResolver.has_firefight(state, z):
			resolve_zone(state, z)
	# Playback-time histogram (seconds at x1, firefight-order.md §5 timing model).
	var secs: float = PLAYBACK_COLUMN_S * (int(stats.get("columns", 0)) - c0) + PLAYBACK_BEAT_S * (int(stats.get("beats", 0)) - b0) \
			+ PLAYBACK_ADVANCE_S * (int(stats.get("advances", 0)) - a0)
	count("t_hist:%d" % mini(int(secs), 12))
	count("t_ms", int(secs * 1000.0))
	for s: RulesSide in state.sides:
		for u: RulesUnit in s.units_on_board():
			u.fired = false


static func resolve_zone(state, z: int) -> void:
	count("columns")
	state.emit_event(RulesEvent.FIREFIGHT_STARTED, {"zone": state.zone_name(z)})
	FirefightResolver._suppress(state, z)
	if order == &"front":
		_run_beats(state, z, &"front")
	elif fs_mode == &"pass":
		_run_beats(state, z, &"fs")
		_run_beats(state, z, &"all")
	else:
		_run_beats(state, z, &"all")
	FirefightResolver._patch(state, z)


## Next shooter of side si in column z for this kind of pass (null = none).
static func _next(state, si: int, z: int, pass_kind: StringName) -> RulesUnit:
	var line: Array = state.sides[si].line(z)
	if pass_kind == &"front":
		if line.is_empty():
			return null
		var u: RulesUnit = line[0]
		return u if u.is_alive() and not u.fired else null
	for u: RulesUnit in line:
		if u.is_alive() and not u.fired and (pass_kind != &"fs" or state.has_first_shot(u)):
			return u
	return null


static func _run_beats(state, z: int, pass_kind: StringName) -> void:
	var guard: int = 0
	while guard < 24:
		guard += 1
		if not FirefightResolver.has_firefight(state, z):
			return
		var shooters: Array[RulesUnit] = []
		for si: int in state.side_order():
			var u: RulesUnit = _next(state, si, z, pass_kind)
			if u != null:
				shooters.append(u)
		if shooters.is_empty():
			return
		if pass_kind != &"fs" and fs_mode == &"exchange" and shooters.size() == 2 \
				and state.has_first_shot(shooters[0]) != state.has_first_shot(shooters[1]):
			var first: RulesUnit = shooters[0] if state.has_first_shot(shooters[0]) else shooters[1]
			var second: RulesUnit = shooters[1] if first == shooters[0] else shooters[0]
			_beat(state, z, [first])
			if second.is_alive() and second.zone == z and FirefightResolver.has_firefight(state, z):
				_beat(state, z, [second])
			continue
		_beat(state, z, shooters)


## One beat: the shooters fire at once, then damage lands and the lines close up.
static func _beat(state, z: int, shooters: Array) -> void:
	count("beats")
	var hits: Array = []  # [target, dmg, src]
	for u: RulesUnit in shooters:
		u.fired = true
		count("shots")
		var si: int = u.side
		var foe_line: Array = state.sides[1 - si].line(z)
		var assigned: Dictionary = {}
		var target: RulesUnit = FirefightResolver.pick_target(state, u, foe_line, assigned)
		if target == null:
			continue
		var src: Dictionary = FirefightResolver._source(state, si, u)
		var dmg: int = maxi(0, state.firepower_of(u) - state.cover_of(target))
		hits.append([target, dmg, src])
		if dmg > target.armor:  # overkill a Pierce would carry on (stats only)
			count("excess", dmg - target.armor)
			count("excess:" + String(u.source_id), dmg - target.armor)
		count("shots:" + String(u.source_id))
		state.emit_event(RulesEvent.SHOT_FIRED, {"side": state.side_name(si), "shooter_uid": u.uid,
				"target_uid": target.uid, "zone": state.zone_name(z), "damage": dmg, "step": &"beat"})
		if pierce.has(String(u.source_id)):
			var left: int = dmg - target.armor
			var idx: int = foe_line.find(target)
			while left > 0 and idx + 1 < foe_line.size():
				idx += 1
				var nxt: RulesUnit = foe_line[idx]
				var d2: int = mini(maxi(0, left - state.cover_of(nxt)), nxt.armor)
				if d2 > 0:
					hits.append([nxt, d2, src])
					count("pierce_damage", d2)
				left -= state.cover_of(nxt) + nxt.armor
	var lines_before: int = state.sides[0].line(z).size() + state.sides[1].line(z).size()
	for h: Array in hits:
		state.deal_damage(h[0], int(h[1]), h[2], false)
	state.process_eliminations()
	var lines_after: int = state.sides[0].line(z).size() + state.sides[1].line(z).size()
	if lines_after < lines_before:
		count("advances")
