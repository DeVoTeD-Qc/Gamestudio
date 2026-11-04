# match_state.gd
# Purpose: The whole state of a 1v1 CardZone match as plain, node-free data (spec §16): both
#   seats, every card as an instance id (defs maps id -> CardData id; attachments tucked under a
#   weapon live in `attachments`), the map (gas, piles, supply drops, crates), the Zone deck
#   position, the Bounty, the pending Brace step, the result, and the action log that replays
#   the match exactly (U1). Built by new_match() (real matches, setup action `drop`, RQ-04) or by
#   from_fixture() (QA's mid-turn fixtures, RQ-11). All rules live in LoadoutRules; what each
#   seat may see lives in MatchView.
# Dependencies: RulesData, SeatState, CardData, AreaData, BalanceConfig, DataEnums.
# Author: Mechanics Developer Agent
class_name MatchState
extends RefCounted

const P1: int = 0
const P2: int = 1
const NO_SEAT: int = -1
const PHASE_DROP: StringName = &"drop"
const PHASE_PLAY: StringName = &"play"
const PHASE_OVER: StringName = &"over"

## Serialised match-level fields (seats are added as "seats"). actions/undo_stack/origin are kept apart.
const FIELDS: Array[String] = [
	"phase", "round_number", "zone_card", "route", "active", "defs", "owners", "attachments", "next_id",
	"gas", "drops", "drop_round", "piles", "crates", "bounty", "removed", "pending", "last_shot",
	"match_end",
]

## Content and tunables (shared, never serialised as state; a match owns its balance copy).
var data: RulesData = null

var phase: StringName = PHASE_PLAY
## Round number = the last Zone card flipped (0 before round 1).
var round_number: int = 0
var zone_card: int = 0
## DataEnums.Route (A, B, C).
var route: int = DataEnums.Route.A
## Seat whose turn it is (during the drop: the seat that drops next).
var active: int = P1
var seats: Array[SeatState] = []
## Instance id -> card id (StringName).
var defs: Dictionary = {}
## Instance id -> owning seat (starters and Hits), or -1 for loot.
var owners: Dictionary = {}
## Weapon instance id -> Array of attachment instance ids, in the order they were tucked.
var attachments: Dictionary = {}
var next_id: int = 1
## Gas areas, kept sorted.
var gas: Array[StringName] = []
## Area id -> Array of supply-drop instance ids (an area keeps its key once a drop landed).
var drops: Dictionary = {}
## Supply-drop instance id -> round it landed (R10a).
var drop_round: Dictionary = {}
## Area id -> {card id: Array of instance ids, the last is the top}.
var piles: Dictionary = {}
## [{owner, area, cards: Array[int], free_picks, picker}] (R46).
var crates: Array = []
## Seat holding the Bounty, or -1 (set aside).
var bounty: int = NO_SEAT
## Cards removed from the game face up (ditched, Spent), in order.
var removed: Array[int] = []
## The shot or Frag waiting for a Brace ({} when none). See LoadoutRules.
var pending: Dictionary = {}
## The last shot or Frag (public result): see LoadoutRules._new_shot_record.
var last_shot: Dictionary = {}
## {} while playing, else {result: win|draw, winner (seat, wins only), cause}.
var match_end: Dictionary = {}

## Logged actions since the start (setup) of this state: replaying them reproduces it (U1).
var actions: Array[Dictionary] = []
## Undo snapshots of the current turn (U2, U3): [{state, log_size}].
var undo_stack: Array[Dictionary] = []
## to_dict() at creation (new_match / from_fixture): the replay start.
var origin: Dictionary = {}


func _init() -> void:
	seats = [SeatState.new(), SeatState.new()]


# --- Construction -------------------------------------------------------------------

## A fresh match at the drop (S3, S4): piles filled, Standard pack loadouts, full health
## stacks. P2 drops first (S5); round 1 starts after P1's drop (RQ-04).
static func new_match(content: RulesData, route_value: int = DataEnums.Route.A) -> MatchState:
	var s: MatchState = MatchState.new()
	s.data = content.with_balance()
	s.phase = PHASE_DROP
	s.route = route_value
	s.active = P2
	var b: BalanceConfig = s.data.balance
	for area_id: StringName in s.data.area_order:
		var a: AreaData = s.data.area(area_id)
		var area_piles: Dictionary = {}
		for c: CardData in a.piles:
			var stack: Array[int] = []
			for i: int in a.pile_size(b):
				stack.append(s.new_card(c.id, NO_SEAT))
			area_piles[c.id] = stack
		s.piles[area_id] = area_piles
	for seat: int in [P1, P2]:
		var st: SeatState = s.seats[seat]
		for id: StringName in s.data.start_pack():
			st.loadout.append(s.new_card(id, seat))
		for i: int in b.health:
			st.health.append(s.new_card(s.data.hit_id, seat))
	s.mark_origin()
	return s


## Builds a state from a QA fixture (rules-test-cases.json `setup`, RQ-11). Cards are written as
## tokens (a weapon with tucked attachments is "HRF+RDS"); each part is looked up in code_map
## (code -> card id) and used as a card id when it isn't there. Seats are "P1"/"P2".
## Accepts: round, zone_card, route, active, balance, gas, drops, drop_round, bounty, piles,
## crates, players {P1, P2: area, health, loadout, held, hand, line, move, search, fired,
## looted_this_turn, adrenaline_played, ditched}; or {new_match: true, route, balance}.
## Errors (unknown cards or balance values) are appended to `errors`.
static func from_fixture(setup: Dictionary, content: RulesData, code_map: Dictionary = {},
		errors: Array = []) -> MatchState:
	var overrides: Dictionary = balance_overrides_from_json(setup.get("balance", {}))
	var fixture_data: RulesData = content.with_balance(overrides, errors)
	var route_value: int = route_from_letter(String(setup.get("route", "A")))
	if setup.get("new_match", false):
		var fresh: MatchState = new_match(fixture_data, route_value)
		fresh.data = fixture_data
		return fresh
	var s: MatchState = MatchState.new()
	s.data = fixture_data
	s.phase = PHASE_PLAY
	s.route = route_value
	s.round_number = int(setup.get("round", 1))
	s.zone_card = int(setup.get("zone_card", s.round_number))
	s.active = seat_from_name(setup.get("active", "P1"))
	s.bounty = seat_from_name(setup.get("bounty", null))
	for g: Variant in setup.get("gas", []):
		s.gas.append(StringName(g))
	s.gas.sort()
	var piles_in: Dictionary = setup.get("piles", {})
	for area_id: StringName in s.data.area_order:
		var area_piles: Dictionary = {}
		var given: Dictionary = piles_in.get(String(area_id), {})
		for code: Variant in given.keys():
			var id: StringName = _map_code(String(code), code_map)
			if s.data.card(id) == null:
				errors.append("unknown pile card %s" % code)
				continue
			var stack: Array[int] = []
			for i: int in int(given[code]):
				stack.append(s.new_card(id, NO_SEAT))
			area_piles[id] = stack
		s.piles[area_id] = area_piles
	var players: Dictionary = setup.get("players", {})
	for seat: int in [P1, P2]:
		var p: Dictionary = players.get(seat_name(seat), {})
		var st: SeatState = s.seats[seat]
		st.area = StringName(p.get("area", ""))
		for i: int in int(p.get("health", 0)):
			st.health.append(s.new_card(s.data.hit_id, seat))
		for token: Variant in p.get("loadout", []):
			st.loadout.append(s._fixture_card(String(token), seat, code_map, errors))
		for i: int in mini(int(p.get("held", 0)), st.loadout.size()):
			st.held.append(st.loadout[i])
		for token: Variant in p.get("hand", []):
			st.hand.append(s._fixture_card(String(token), seat, code_map, errors))
		for token: Variant in p.get("line", []):
			st.line.append(s._fixture_card(String(token), seat, code_map, errors))
		st.move = int(p.get("move", 0))
		st.search = int(p.get("search", 0))
		st.adrenaline_played = int(p.get("adrenaline_played", 0))
		st.ditched = int(p.get("ditched", 0))
		var fired_in: Dictionary = p.get("fired", {})
		for code: Variant in fired_in.keys():
			var inst: int = s.find_token(st.line, String(code), code_map)
			if inst > 0:
				st.fired[inst] = int(fired_in[code])
		for code: Variant in p.get("looted_this_turn", []):
			var inst: int = s.find_token(st.line, String(code), code_map, st.looted)
			if inst > 0:
				st.looted.append(inst)
	var drops_in: Dictionary = setup.get("drops", {})
	var rounds_in: Dictionary = setup.get("drop_round", {})
	for area_id: Variant in drops_in.keys():
		var list: Array[int] = []
		for code: Variant in drops_in[area_id]:
			var inst: int = s._fixture_card(String(code), NO_SEAT, code_map, errors)
			list.append(inst)
			s.drop_round[inst] = int(rounds_in.get(String(code), s.round_number))
		s.drops[StringName(area_id)] = list
	var crates_in: Dictionary = setup.get("crates", {})
	for area_id: Variant in crates_in.keys():
		var cards_list: Array[int] = []
		for token: Variant in crates_in[area_id]:
			cards_list.append(s._fixture_card(String(token), NO_SEAT, code_map, errors))
		s.crates.append({"owner": NO_SEAT, "area": StringName(area_id), "cards": cards_list,
				"free_picks": 0, "picker": NO_SEAT})
	s.mark_origin()
	return s


## JSON-style balance overrides (numbers as floats, enum names as text) -> typed values.
static func balance_overrides_from_json(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in raw.keys():
		var value: Variant = raw[key]
		match String(key):
			"packing_rule":
				out[key] = DataEnums.PackingRule.RACK_SWAP if String(value) in ["rack_swap", "RACK_SWAP", "1"] \
						else DataEnums.PackingRule.HOLD_AND_STOW
			"adrenaline_mode":
				out[key] = DataEnums.AdrenalineMode.MOVE_ONLY if String(value) in ["move_only", "MOVE_ONLY", "1"] \
						else DataEnums.AdrenalineMode.MOVE_OR_SEARCH
			"final_circle_hits":
				var list: Array = []
				for n: Variant in value:
					list.append(int(n))
				out[key] = list
			_:
				if value is bool:
					out[key] = value
				elif value is float or value is int:
					out[key] = int(value)
				else:
					out[key] = value
	return out


## Starts the replay record here (the current state, with an empty log).
func mark_origin() -> void:
	actions.clear()
	undo_stack.clear()
	origin = to_dict()


# --- Cards ----------------------------------------------------------------------------

## Registers a new card instance and returns its id.
func new_card(card_id: StringName, owner: int) -> int:
	var inst: int = next_id
	next_id += 1
	defs[inst] = card_id
	owners[inst] = owner
	return inst


func card_id(inst: int) -> StringName:
	return defs.get(inst, &"")


func def_of(inst: int) -> CardData:
	return data.card(card_id(inst))


func is_hit(inst: int) -> bool:
	var c: CardData = def_of(inst)
	return c != null and c.is_hit()


func attachments_of(inst: int) -> Array[int]:
	var out: Array[int] = []
	out.assign(attachments.get(inst, []))
	return out


## "hunting_rifle+red_dot_sight" (debug and logs).
func label(inst: int) -> String:
	var parts: PackedStringArray = [String(card_id(inst))]
	for a: int in attachments_of(inst):
		parts.append(String(card_id(a)))
	return "+".join(parts)


## The first instance in `list` matching a token ("HRF" any HRF; "HRF+RDS" exactly), skipping
## `exclude`. 0 when none.
func find_token(list: Array, token: String, code_map: Dictionary = {}, exclude: Array = []) -> int:
	var parts: PackedStringArray = token.split("+")
	var want_base: StringName = _map_code(parts[0], code_map)
	var want_atts: Array[StringName] = []
	for i: int in range(1, parts.size()):
		want_atts.append(_map_code(parts[i], code_map))
	for inst: Variant in list:
		var id: int = int(inst)
		if exclude.has(id) or card_id(id) != want_base:
			continue
		if parts.size() > 1:
			var have: Array[StringName] = []
			for a: int in attachments_of(id):
				have.append(card_id(a))
			if have != want_atts:
				continue
		return id
	return 0


## Every card instance in a place (for conservation checks): {inst: "where"}.
func locate_all() -> Dictionary:
	var where: Dictionary = {}
	for seat: int in [P1, P2]:
		var st: SeatState = seats[seat]
		for zone: String in ["health", "loadout", "hand", "line"]:
			for inst: int in st.get(zone):
				_place(where, inst, "%s.%s" % [seat_name(seat), zone])
	for area_id: Variant in piles.keys():
		for cid: Variant in piles[area_id].keys():
			for inst: Variant in piles[area_id][cid]:
				_place(where, int(inst), "pile.%s" % area_id)
	for area_id: Variant in drops.keys():
		for inst: Variant in drops[area_id]:
			_place(where, int(inst), "drop.%s" % area_id)
	for crate: Dictionary in crates:
		for inst: Variant in crate["cards"]:
			_place(where, int(inst), "crate.%s" % crate["area"])
	for inst: int in removed:
		_place(where, inst, "removed")
	for weapon: Variant in attachments.keys():
		for inst: Variant in attachments[weapon]:
			_place(where, int(inst), "attached.%d" % int(weapon))
	return where


# --- Derived facts (D3-D6) -------------------------------------------------------------

func get_seat(i: int) -> SeatState:
	return seats[i]


func opponent_of(i: int) -> int:
	return P2 if i == P1 else P1


func health_of(i: int) -> int:
	return seats[i].health.size()


## D4: from the top until hand_size non-Hit cards (or the loadout ends), Hits included.
func next_draw(i: int) -> Array[int]:
	return draw_from(seats[i].loadout, data.balance.hand_size)


## The first cards of `list` up to `count` non-Hit cards (Hits met on the way included).
func draw_from(list: Array[int], count: int) -> Array[int]:
	var out: Array[int] = []
	var real: int = 0
	for inst: int in list:
		if real >= count:
			break
		out.append(inst)
		if not is_hit(inst):
			real += 1
	return out


## D5: the non-Hit cards of the next draw (the Brace window).
func next_hand(i: int) -> Array[int]:
	var out: Array[int] = []
	for inst: int in next_draw(i):
		if not is_hit(inst):
			out.append(inst)
	return out


## Hits in the next draw (the Down badge number, P4).
func next_draw_hits(i: int) -> int:
	var n: int = 0
	for inst: int in next_draw(i):
		if is_hit(inst):
			n += 1
	return n


## D6.
func is_down(i: int) -> bool:
	return data.balance.down_enabled and next_draw_hits(i) > 0


func hits_in(list: Array[int]) -> int:
	var n: int = 0
	for inst: int in list:
		if is_hit(inst):
			n += 1
	return n


## D1, D2: non-Hit cards in loadout + hand + line (a weapon with attachments is 1).
func nonhit_count(i: int) -> int:
	var st: SeatState = seats[i]
	var n: int = 0
	for list: Array[int] in [st.loadout, st.hand, st.line]:
		n += list.size() - hits_in(list)
	return n


## The seat that must send `brace` now, or -1.
func pending_brace_seat() -> int:
	if pending.is_empty():
		return NO_SEAT
	var queue: Array = pending["queue"]
	var idx: int = int(pending["index"])
	return int(queue[idx]) if idx < queue.size() else NO_SEAT


func is_over() -> bool:
	return phase == PHASE_OVER


## The seat that must act next: the pending defender, else the active seat; -1 when over.
func deciding_seat() -> int:
	if is_over():
		return NO_SEAT
	var p: int = pending_brace_seat()
	return p if p != NO_SEAT else active


## {area id: {card id: count}} (piles as the table shows them).
func pile_counts() -> Dictionary:
	var out: Dictionary = {}
	for area_id: Variant in piles.keys():
		var counts: Dictionary = {}
		for cid: Variant in piles[area_id].keys():
			counts[cid] = (piles[area_id][cid] as Array).size()
		out[area_id] = counts
	return out


# --- Serialisation, cloning -------------------------------------------------------------

## Every state field (not the action log, undo snapshots or origin) as plain data.
func to_dict() -> Dictionary:
	var d: Dictionary = {}
	for f: String in FIELDS:
		var value: Variant = get(f)
		d[f] = value.duplicate(true) if (value is Array or value is Dictionary) else value
	d["seats"] = [seats[P1].to_dict(), seats[P2].to_dict()]
	d["balance"] = data.balance.snapshot() if data != null else {}
	return d


func load_dict(d: Dictionary) -> void:
	for f: String in FIELDS:
		if not d.has(f):
			continue
		var value: Variant = d[f]
		var current: Variant = get(f)
		if current is Array and (current as Array).is_typed():
			(current as Array).assign((value as Array).duplicate(true))
		elif value is Array or value is Dictionary:
			set(f, value.duplicate(true))
		else:
			set(f, value)
	var seat_dicts: Array = d.get("seats", [])
	for i: int in mini(seat_dicts.size(), 2):
		seats[i].load_dict(seat_dicts[i])


## A deep copy sharing the content (action log, undo snapshots and origin are copied too).
func clone() -> MatchState:
	var s: MatchState = MatchState.new()
	s.data = data
	s.load_dict(to_dict())
	s.actions.assign(actions.duplicate(true))
	s.undo_stack.assign(undo_stack.duplicate(true))
	s.origin = origin
	return s


## Save text: the origin plus the action log (U1), as Godot variant text (keeps ints and ids).
func save_text() -> String:
	return var_to_str({"version": 1, "origin": origin, "actions": actions})


## Rebuilds a match from save_text() by replaying its actions on `content`. Null when the text
## is not a save or an action no longer applies (the errors say which).
static func load_text(text: String, content: RulesData, errors: Array = []) -> MatchState:
	var parsed: Variant = str_to_var(text)
	if not (parsed is Dictionary) or not parsed.has("origin") or not parsed.has("actions"):
		errors.append("not a CardZone match save")
		return null
	var s: MatchState = LoadoutRules.replay(parsed["origin"], parsed["actions"], content, errors)
	return s if errors.is_empty() else null


## Stable text of the state (replay and fairness comparisons).
func fingerprint() -> String:
	return JSON.stringify(to_dict(), "", true)


# --- Names ------------------------------------------------------------------------------

static func seat_name(i: int) -> String:
	return "P1" if i == P1 else ("P2" if i == P2 else "")


## "P1"/"P2" (or 0/1) -> seat; anything else -> -1.
static func seat_from_name(value: Variant) -> int:
	if value == null:
		return NO_SEAT
	if value is int or value is float:
		return int(value) if int(value) in [P1, P2] else NO_SEAT
	match String(value):
		"P1":
			return P1
		"P2":
			return P2
	return NO_SEAT


static func route_from_letter(letter: String) -> int:
	var i: int = DataEnums.ROUTE_LETTERS.find(letter.to_upper())
	return i if i >= 0 else DataEnums.Route.A


static func route_letter(value: int) -> String:
	return DataEnums.ROUTE_LETTERS[value] if value >= 0 and value < DataEnums.ROUTE_LETTERS.size() else "?"


# --- Internals --------------------------------------------------------------------------

static func _map_code(code: String, code_map: Dictionary) -> StringName:
	return StringName(code_map.get(code, code))


func _fixture_card(token: String, owner: int, code_map: Dictionary, errors: Array) -> int:
	var parts: PackedStringArray = token.split("+")
	var base: StringName = _map_code(parts[0], code_map)
	if data.card(base) == null:
		errors.append("unknown card %s" % parts[0])
	var inst: int = new_card(base, owner)
	for i: int in range(1, parts.size()):
		var att: StringName = _map_code(parts[i], code_map)
		if data.card(att) == null:
			errors.append("unknown card %s" % parts[i])
		var list: Array = attachments.get(inst, [])
		list.append(new_card(att, owner))
		attachments[inst] = list
	return inst


static func _place(where: Dictionary, inst: int, zone: String) -> void:
	if where.has(inst):
		where[inst] = String(where[inst]) + "|DUPLICATE:" + zone
	else:
		where[inst] = zone
