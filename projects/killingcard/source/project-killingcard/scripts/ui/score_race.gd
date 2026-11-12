# score_race.gd
# Purpose: kc-clarity (playtest v28: 4 of 5 players could not say how a match is scored or why a
#   round flipped). The words for the score race, from the viewer's side, in one place:
#   - goal_line: "First to 6: you 0, rival 2." (inspectors, the recap's last line)
#   - recap: the round that just resolved, per column: "A  you 2 vs 0 left · you +1", from the
#     ZONE_CONTROL events (units each side still had at the Score step, Holders) and MODE_SCORED.
#   A column is held by the only side with units left in it (or the only side with a Holder there);
#   it gives its holder +1 point (a Hot Zone +2) at round end. A mode that scores eliminations
#   (Firefight) gets a one-line recap instead.
# Usage: const ScoreRace: GDScript = preload("res://scripts/ui/score_race.gd")
#        var rc: Dictionary = ScoreRace.recap(state, me_side, events)
# Dependencies: MatchState, RulesEvent, ModeRules, TerrainRules, MapData.
# Author: UI/UX Agent (kc-clarity)
extends RefCounted

const LETTERS: PackedStringArray = ["A", "B", "C"]


## The match's target score (0 when the state has no mode rules).
static func target(state) -> int:
	var mr: ModeRules = state.hooks.mode_rules if state.hooks != null else null
	return mr.target if mr != null else 0


## True when columns score (Zone Control); false when eliminations do (Firefight).
static func columns_score(state) -> bool:
	var mr: ModeRules = state.hooks.mode_rules if state.hooks != null else null
	return mr == null or mr.score_source == ModeRules.ScoreSource.CONTROLLED_ZONES


## "First to 6: you 0, rival 2."
static func goal_line(state, me: int) -> String:
	var t: int = target(state)
	var mine: int = state.sides[me].score
	var theirs: int = state.sides[1 - me].score
	if t <= 0:
		return "Score: you %d, rival %d." % [mine, theirs]
	return "First to %d: you %d, rival %d." % [t, mine, theirs]


## The recap of the round that just resolved, from `me`'s side:
## {title: "ROUND 2 · FIRST TO 6", rows: [{letter, owner (&"player"/&"enemy"/&"contested"/&"empty",
## viewer-relative), text, points}], score: "Score 3-4 (you-rival).", plain: one-line text}.
## rows is empty for a mode that scores eliminations.
static func recap(state, me: int, events: Array) -> Dictionary:
	var me_name: StringName = state.side_name(me)
	var gained: Array[int] = [0, 0]
	var lost: Array[int] = [0, 0]
	var rows: Array = []
	var zone_ids: Array = MapData.ZONE_IDS
	for ev: Dictionary in events:
		match ev.get("type"):
			RulesEvent.MODE_SCORED:
				gained = [int(ev.get("player_gained", 0)), int(ev.get("enemy_gained", 0))]
			RulesEvent.UNIT_ELIMINATED:
				lost[0 if StringName(ev.get("victim_side", &"")) == me_name else 1] += 1
			RulesEvent.ZONE_CONTROL:
				rows.append(_row(state, me, ev, zone_ids))
	if me != 0:
		gained.reverse()
	var t: int = target(state)
	var title: String = "ROUND %d" % int(state.round_number) + (" · FIRST TO %d" % t if t > 0 else "")
	var score: String = "Score: you %d, rival %d." % [state.sides[me].score, state.sides[1 - me].score]
	var losses: PackedStringArray = []
	if lost[1] > 0:
		losses.append("eliminated %d" % lost[1])
	if lost[0] > 0:
		losses.append("lost %d" % lost[0])
	var units: String = ("You " + " and ".join(losses) + ".") if not losses.is_empty() else ""
	if not columns_score(state):
		rows.clear()
	var plain: String = "Round %d: you +%d, rival +%d (%d-%d)." % [int(state.round_number), gained[0], gained[1],
			state.sides[me].score, state.sides[1 - me].score]
	if units != "":
		plain += " " + units
	return {"title": title, "rows": rows, "score": score, "units": units, "plain": plain,
			"gained": gained}


static func _row(state, me: int, ev: Dictionary, zone_ids: Array) -> Dictionary:
	var z: int = zone_ids.find(StringName(ev.get("zone", &"")))
	var owner_name: StringName = StringName(ev.get("owner", &"empty"))
	var me_name: StringName = state.side_name(me)
	var owner: StringName = owner_name
	if owner_name == &"player" or owner_name == &"enemy":
		owner = &"player" if owner_name == me_name else &"enemy"
	var mine_i: int = 0 if me == 0 else 1
	var units: Array[int] = [int(ev.get("player_units", -1)), int(ev.get("enemy_units", -1))]
	var holders: Array[bool] = [bool(ev.get("player_holder", false)), bool(ev.get("enemy_holder", false))]
	if mine_i != 0:
		units.reverse()
		holders.reverse()
	var worth: int = 1
	if z >= 0 and "terrain" in state and z < (state.terrain as Array).size() and state.terrain[z] == TerrainRules.HOT_ZONE:
		worth = 2
	var why: String = ""
	if units[0] >= 0:
		if units[0] == 0 and units[1] == 0:
			why = "nobody left"
		else:
			why = "you %d vs %d left" % [units[0], units[1]]
			if owner == &"player" and units[1] > 0 and holders[0]:
				why += ", your Holder"
			elif owner == &"enemy" and units[0] > 0 and holders[1]:
				why += ", their Holder"
	var result: String = {&"player": "you +%d" % worth, &"enemy": "rival +%d" % worth,
			&"contested": "even, no point", &"empty": "no point"}.get(owner, "no point")
	if worth > 1 and owner in [&"player", &"enemy"]:
		result += " (Hot Zone)"
	var text: String = (why + " · " + result) if why != "" else result
	return {"letter": LETTERS[z] if z >= 0 else "?", "owner": owner, "text": text,
			"points": worth if owner in [&"player", &"enemy"] else 0}
