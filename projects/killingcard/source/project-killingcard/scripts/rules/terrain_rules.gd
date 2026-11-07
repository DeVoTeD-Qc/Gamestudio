# terrain_rules.gd
# Purpose: Terrain (run-v2.md §6, head V1: the player-facing name; internally "map Fields"): the
#   10 one-line column rules a run-map fight deals to 1-2 columns. Both sides get them; they are
#   never shot, Sabotaged, Overrun or replaced in a match and never count for traits. Nothing here
#   flips a unit's own flags: MatchState asks explicit helpers (has_first_shot, can_pick, can_flank,
#   has_pierce, revealed_red_dots, ModeRules.points_for_round) that read MatchState.terrain.
#     Rooftops       whoever holds the column at the start of the round has First Shot there
#     Smoke          no Pick or Flank there: every shot hits the front unit
#     Dust Storm     no First Shot there
#     Breach Point   every unit there has Pierce
#     Floodlights    red dots there are shown face-up to both sides
#     Comms Tower    hold it at the end of the round: +1 streak
#     Supply Cache   hold it at the end of the round: +1 Supply next round
#     Hot Zone       (Zone Control only) holding it scores 1 extra point
#     Minefield      each round, the first unit each side brings there takes 1 damage
#     Field Hospital end of round: each side's most damaged unit there heals 1
#   "Hold" = control of the column after the Firefight (the same test as Overrun).
#   Static and stateless; the per-match state (terrain, held_at_start, terrain_supply_next) lives on
#   MatchState so MatchClone copies it.
# Dependencies: TerrainData, DataEnums, RulesUnit, RulesEvent, EffectResolver (MatchState passed in).
# Author: Mechanics Developer Agent (kc-v2-impl)
class_name TerrainRules
extends RefCounted

const ROOFTOPS: StringName = &"rooftops"
const SMOKE: StringName = &"smoke"
const DUST_STORM: StringName = &"dust_storm"
const BREACH_POINT: StringName = &"breach_point"
const FLOODLIGHTS: StringName = &"floodlights"
const COMMS_TOWER: StringName = &"comms_tower"
const SUPPLY_CACHE: StringName = &"supply_cache"
const HOT_ZONE: StringName = &"hot_zone"
const MINEFIELD: StringName = &"minefield"
const FIELD_HOSPITAL: StringName = &"field_hospital"
## The pool, in Dossier order.
const ALL: Array[StringName] = [ROOFTOPS, SMOKE, DUST_STORM, BREACH_POINT, FLOODLIGHTS, COMMS_TOWER,
		SUPPLY_CACHE, HOT_ZONE, MINEFIELD, FIELD_HOSPITAL]
const ZONE_CONTROL_ONLY: Array[StringName] = [HOT_ZONE]
const DATA_DIR: String = "res://data/terrain"
## Source kind of Terrain damage (Minefield): uncredited, never counts for a streak.
const SRC_TERRAIN: StringName = &"terrain"

static var _cache: Dictionary = {}


# =============================================================================
# Data
# =============================================================================

## The TerrainData of `id` (null for &"" or an unknown id).
static func data(id: StringName) -> TerrainData:
	if id == &"" or id not in ALL:
		return null
	if not _cache.has(id):
		_cache[id] = load("%s/%s.tres" % [DATA_DIR, id]) as TerrainData
	return _cache[id]


static func all() -> Array[TerrainData]:
	var out: Array[TerrainData] = []
	for id: StringName in ALL:
		var t: TerrainData = data(id)
		if t != null:
			out.append(t)
	return out


static func name_of(id: StringName) -> String:
	var t: TerrainData = data(id)
	return t.display_name if t != null else ""


static func text_of(id: StringName) -> String:
	var t: TerrainData = data(id)
	return t.text if t != null else ""


## One Terrain row for the UI: {zone, zone_name, id, name, text, detail}.
static func row(zone: int, id: StringName) -> Dictionary:
	var t: TerrainData = data(id)
	return {"zone": zone, "zone_name": MapData.ZONE_IDS[zone] if zone >= 0 and zone < 3 else &"", "id": id,
			"name": t.display_name if t != null else "", "text": t.text if t != null else "",
			"detail": t.detail if t != null else ""}


## `count` distinct Terrains on distinct random columns (3 entries, &"" = none), seeded. Hot Zone
## only in Zone Control. `exclude` = ids not to deal. Same algorithm as the kc-v2-design sim.
static func deal(rng: RandomNumberGenerator, count: int, mode: int, exclude: Array = []) -> Array[StringName]:
	var out: Array[StringName] = [&"", &"", &""]
	if count <= 0:
		return out
	var pool: Array[StringName] = []
	for id: StringName in ALL:
		if id in exclude:
			continue
		if id in ZONE_CONTROL_ONLY and mode != DataEnums.GameMode.ZONE_CONTROL:
			continue
		pool.append(id)
	var cols: Array[int] = [0, 1, 2]
	for i: int in mini(count, 3):
		if pool.is_empty():
			break
		var t: StringName = pool[rng.randi_range(0, pool.size() - 1)]
		pool.erase(t)
		var c: int = cols[rng.randi_range(0, cols.size() - 1)]
		cols.erase(c)
		out[c] = t
	return out


static func count_of(terrain: Array) -> int:
	var n: int = 0
	for t: Variant in terrain:
		if StringName(t) != &"":
			n += 1
	return n


# =============================================================================
# Rules (called by MatchState; `state` untyped to keep the scripts acyclic)
# =============================================================================

## Briefing, after Supply and draws: who holds each column now (Rooftops reads it all round).
static func on_briefing(state) -> void:
	for z: int in 3:
		state.held_at_start[z] = state.control_of(z)


## First Shot by Terrain: false = Dust Storm takes it away, true = Rooftops gives it, null = no say.
static func first_shot_override(state, u: RulesUnit) -> Variant:
	if u.zone < 0:
		return null
	match state.terrain[u.zone]:
		DUST_STORM:
			return false
		ROOFTOPS:
			if int(state.held_at_start[u.zone]) == u.side:
				return true
	return null


static func blocks_pick_flank(state, zone: int) -> bool:
	return zone >= 0 and zone < 3 and state.terrain[zone] == SMOKE


static func grants_pierce(state, zone: int) -> bool:
	return zone >= 0 and zone < 3 and state.terrain[zone] == BREACH_POINT


## Minefield: after Reveal, the first unit each side brought into a Minefield column this round takes
## 1 damage (Cover doesn't apply; the damage is the unit's own side's, so it is never credited).
## `start` = events.size() when the Reveal began.
static func after_reveal(state, start: int) -> void:
	if not state.terrain.has(MINEFIELD):
		return
	var hit: Dictionary = {}
	var victims: Array = []
	for i: int in range(start, state.events.size()):
		var ev: Dictionary = state.events[i]
		if ev["type"] != RulesEvent.UNIT_ARRIVED:
			continue
		var u: RulesUnit = state.find_unit(int(ev["uid"]))
		if u == null or u.zone < 0 or state.terrain[u.zone] != MINEFIELD:
			continue
		var key: String = "%d:%d" % [u.side, u.zone]
		if hit.has(key):
			continue
		hit[key] = true
		victims.append(u)
	for u: RulesUnit in victims:
		var zone: int = u.zone
		var dmg: int = state.deal_damage(u, 1, {"side": u.side, "uid": -1, "source_id": MINEFIELD,
				"source_kind": SRC_TERRAIN}, false)
		state.emit_event(RulesEvent.TERRAIN_TRIGGERED, {"terrain": MINEFIELD, "zone": state.zone_name(zone),
				"side": state.side_name(u.side), "uid": u.uid, "amount": dmg,
				"what": "Minefield: %s takes %d" % [_unit_name(u), dmg]})
	if not victims.is_empty():
		state.process_eliminations()


## Field Hospital (Score step, after the Undead heal): each side's most damaged unit there heals 1.
static func field_hospital(state) -> void:
	for z: int in 3:
		if state.terrain[z] != FIELD_HOSPITAL:
			continue
		for si: int in state.side_order():
			var worst: RulesUnit = null
			var lost: int = 0
			for u: RulesUnit in state.sides[si].line(z):
				var miss: int = u.max_armor(state.round_number) - u.armor
				if u.is_alive() and miss > lost:
					worst = u
					lost = miss
			if worst == null:
				continue
			worst.armor += 1
			state.emit_event(RulesEvent.UNIT_HEALED, {"side": state.side_name(si), "source_id": FIELD_HOSPITAL,
					"source_uid": -1, "target_uid": worst.uid, "amount": 1, "remaining": worst.armor,
					"zone": state.zone_name(z)})
			state.emit_event(RulesEvent.TERRAIN_TRIGGERED, {"terrain": FIELD_HOSPITAL, "zone": state.zone_name(z),
					"side": state.side_name(si), "uid": worst.uid, "amount": 1,
					"what": "Field Hospital: %s heals 1" % _unit_name(worst)})


## Comms Tower (Score step, before the streak): the side holding it now gets +1 streak this round.
static func comms_tower(state, side: int) -> void:
	for z: int in 3:
		if state.terrain[z] == COMMS_TOWER and state.control_of(z) == side:
			state.sides[side].streak_bonus_this_round += 1
			state.emit_event(RulesEvent.TERRAIN_TRIGGERED, {"terrain": COMMS_TOWER, "zone": state.zone_name(z),
					"side": state.side_name(side), "amount": 1, "what": "Comms Tower: +1 streak"})


## Supply Cache and Hot Zone (Score step, after the mode score): +1 Supply next round for the holder;
## Hot Zone's extra point is scored by ModeRules.points_for_round (this only logs it).
static func after_mode_score(state, control: Array) -> void:
	for z: int in 3:
		var t: StringName = state.terrain[z]
		if t == SUPPLY_CACHE:
			var c: int = state.control_of(z)
			if c == 0 or c == 1:
				state.terrain_supply_next[c] += 1
				state.emit_event(RulesEvent.TERRAIN_TRIGGERED, {"terrain": SUPPLY_CACHE, "zone": state.zone_name(z),
						"side": state.side_name(c), "amount": 1, "what": "Supply Cache: +1 Supply next round"})
		elif t == HOT_ZONE:
			var hc: int = int(control[z])
			var rules = state.hooks.mode_rules if state.hooks != null else null
			if (hc == 0 or hc == 1) and rules != null and rules.score_source == ModeRules.ScoreSource.CONTROLLED_ZONES:
				state.emit_event(RulesEvent.TERRAIN_TRIGGERED, {"terrain": HOT_ZONE, "zone": state.zone_name(z),
						"side": state.side_name(hc), "amount": 1, "what": "Hot Zone: +1 point"})


## Extra mode points Terrain gives `side` this round (Hot Zone; Zone Control scoring only).
static func extra_points(state, side: int, control: Array) -> int:
	if not ("terrain" in state):
		return 0
	var n: int = 0
	for z: int in mini(3, control.size()):
		if int(control[z]) == side and state.terrain[z] == HOT_ZONE:
			n += 1
	return n


## Floodlights: the card ids behind `viewer`'s red dots in `zone` are face-up (both sides).
static func floodlit(state, zone: int) -> bool:
	return zone >= 0 and zone < 3 and state.terrain[zone] == FLOODLIGHTS


static func _unit_name(u: RulesUnit) -> String:
	if u.card != null:
		return u.card.display_name
	return String(u.source_id).capitalize()
