# outcome_forecast.gd
# Purpose: The outcome preview (p12): what the coming Reveal + Firefight will do in each zone,
#   computed by the REAL rules engine on a copy of the match (MatchClone), using only what the
#   viewer can see:
#   - the viewer's own queued plays and own (even hidden) Equipment,
#   - the board (both lines with current Armor / modifiers), the other side's face-up Equipment
#     and effects already registered in earlier rounds (Attack Helo),
#   - the other side's committed plays are NOT used: they are face-down. Their unit arrivals
#     are reported per zone as `unknown` (the red-dot count, Ruling 13) and never simulated;
#     their hidden Equipment (Tripwire) is removed from the copy. Face-down tactics / items
#     leave no red dot, so the preview can always be wrong when the other side plays them.
#   The live state is never changed (tests/test_outcome_forecast.gd checks that). The preview
#   stops after the Firefight: Score-step END_OF_ROUND effects are not included, and `control`
#   is the zone owner at the start of the Score step (the value Zone Control scores).
#
#   forecast(state, viewer) -> {
#     ok: bool (false outside the viewer's open Deploy), initiative: int (side first at Reveal),
#     zones: [ per zone 0..2: {
#       dealt: int        damage the other side's units take in this zone (Reveal + Firefight),
#       taken: int        damage the viewer's units take,
#       kills: int        other-side units eliminated here,     kill_uids: Array[int]
#       losses: int       viewer units eliminated here,          loss_uids: Array[int]
#       fight: bool       a firefight happens in this zone,
#       control: StringName  &"player" (viewer) / &"enemy" / &"contested" / &"empty",
#       unknown: int      red dots: the other side's hidden arrivals, not simulated,
#       revealed: Array[StringName]  card ids behind those dots if the viewer revealed the zone,
#     } ] }
#   summarize(events, unit_zones, viewer) builds the same numbers from any event list, so tests
#   can hold the forecast against the events of the real resolve_round().
# Dependencies: MatchState, MatchClone, RulesSide, RulesUnit, RulesEvent, MapData.
# Author: UI/UX Agent (p12)
class_name OutcomeForecast
extends RefCounted


static func forecast(state: MatchState, viewer: int = MatchState.PLAYER) -> Dictionary:
	var out: Dictionary = {"ok": false, "initiative": MatchState.PLAYER, "zones": []}
	if state == null or state.phase != MatchState.Phase.DEPLOY or state.sides[viewer].ready:
		return out
	var dots: PackedInt32Array = state.red_dots(viewer)
	var sim: MatchState = MatchClone.copy(state)
	hide_foe_plan(sim, viewer)
	var zones_before: Dictionary = unit_zones(sim)
	var start: int = sim.events.size()
	sim.reveal()
	sim.firefight()
	var zones: Array = summarize(sim.events_since(start), zones_before, viewer)
	for z: int in MatchState.ZONE_COUNT:
		zones[z]["control"] = control_name(sim.control_of(z), viewer)
		zones[z]["unknown"] = dots[z]
		zones[z]["revealed"] = state.revealed_red_dots(viewer, z)
	out["ok"] = true
	out["initiative"] = sim.initiative
	out["zones"] = zones
	return out


## Strips from a COPY everything the viewer cannot see of the other side: its face-down plays
## of this Deploy (and arrival buffs waiting for them) and its hidden Equipment on the board.
static func hide_foe_plan(sim: MatchState, viewer: int) -> void:
	var foe: RulesSide = sim.sides[1 - viewer]
	foe.plays.clear()
	foe.arrival_buffs.clear()
	for z: int in MatchState.ZONE_COUNT:
		foe.equipment[z] = (foe.equipment[z] as Array).filter(func(entry: Dictionary) -> bool:
			return not (entry["card"] as RulesCard).card.hidden)


## uid -> zone of every unit on the board (the starting point for summarize()).
static func unit_zones(state: MatchState) -> Dictionary:
	var out: Dictionary = {}
	for s: RulesSide in state.sides:
		for u: RulesUnit in s.units_on_board():
			out[u.uid] = u.zone
	return out


## Per-zone damage / eliminations / firefights of an event list (see the header). `unit_zones`
## = unit_zones(state) taken before those events; arrivals and moves in the list update it.
static func summarize(events: Array, p_unit_zones: Dictionary, viewer: int = MatchState.PLAYER) -> Array:
	var where: Dictionary = p_unit_zones.duplicate()
	var me: StringName = MatchState.SIDE_NAMES[viewer]
	var zones: Array = []
	for z: int in MatchState.ZONE_COUNT:
		zones.append({"dealt": 0, "taken": 0, "kills": 0, "losses": 0, "kill_uids": [], "loss_uids": [],
				"fight": false, "control": &"empty", "unknown": 0, "revealed": []})
	for e: Dictionary in events:
		match e["type"]:
			RulesEvent.UNIT_ARRIVED, RulesEvent.UNIT_MOVED, RulesEvent.OPERATOR_PLACED, RulesEvent.OPERATOR_ROTATED:
				where[int(e["uid"])] = zone_index(e.get("zone", &""))
			RulesEvent.FIREFIGHT_STARTED:
				var fz: int = zone_index(e.get("zone", &""))
				if fz >= 0:
					zones[fz]["fight"] = true
			RulesEvent.DAMAGE_DEALT:
				var dz: int = int(where.get(int(e["target_uid"]), -1))
				if dz < 0:
					continue
				var key: String = "taken" if e["side"] == me else "dealt"
				zones[dz][key] = int(zones[dz][key]) + int(e["amount"])
			RulesEvent.UNIT_ELIMINATED:
				var ez: int = zone_index(e.get("zone", &""))
				if ez < 0:
					continue
				var mine: bool = e["victim_side"] == me
				zones[ez]["losses" if mine else "kills"] = int(zones[ez]["losses" if mine else "kills"]) + 1
				(zones[ez]["loss_uids" if mine else "kill_uids"] as Array).append(int(e["victim_uid"]))
				where.erase(int(e["victim_uid"]))
	return zones


## Zone owners from the ZONE_CONTROL events of a resolved round, relative to `viewer`.
static func control_from_events(events: Array, viewer: int = MatchState.PLAYER) -> Array[StringName]:
	var out: Array[StringName] = [&"empty", &"empty", &"empty"]
	var me: StringName = MatchState.SIDE_NAMES[viewer]
	var foe: StringName = MatchState.SIDE_NAMES[1 - viewer]
	for e: Dictionary in events:
		if e["type"] != RulesEvent.ZONE_CONTROL:
			continue
		var z: int = zone_index(e.get("zone", &""))
		var owner: StringName = StringName(e.get("owner", &"empty"))
		if owner == me:
			owner = &"player"
		elif owner == foe:
			owner = &"enemy"
		if z >= 0:
			out[z] = owner
	return out


static func control_name(c: int, viewer: int) -> StringName:
	match c:
		MatchState.CONTROL_CONTESTED:
			return &"contested"
		MatchState.CONTROL_EMPTY:
			return &"empty"
	return &"player" if c == viewer else &"enemy"


static func zone_index(zone_id: Variant) -> int:
	return MapData.ZONE_IDS.find(StringName(zone_id))
