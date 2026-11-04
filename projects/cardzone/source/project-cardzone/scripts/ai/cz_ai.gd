# cz_ai.gd
# Purpose: The CardZone AI opponent (cz09): base class, factory and the shared policy pieces.
#     CzAI.for_level(&"rookie" | &"veteran", seed)   factory
#     choose_action(state, seat) -> Dictionary
#       One action for `seat` in the shapes LoadoutRules.apply() takes (drop, play, move, loot,
#       shoot, frag, attach, patch_up, end_turn with its hold choice, and brace when the seat is
#       the pending defender). {} when `seat` does not have to act (not its turn, match over).
#       Never undoes (U6) or concedes. Never changes `state`.
#   Fairness wall (spec §16.2 P18): choose_action builds CzBelief.world(state, seat) first and the
#   brain (_decide) only ever reads that world: the opponent's private cards in it are a guess made
#   from view(state, seat) alone. tests/test_ai.gd proves it: states that differ only in the
#   opponent's hidden cards give identical worlds and identical moves.
#   Segment anchor: a turn is split into segments by the commit points (U3: the turn start and
#   each declared shot or Frag, after which the opponent may reveal cards). The real state already
#   records where the current segment began: its undo snapshots (state.undo_stack[0], the state
#   before the segment's first undoable action). anchor_world() is the belief world of that state
#   (built through the same wall, so it holds no private opponent card either). The Veteran plans
#   once per segment from the anchor and follows that plan, which keeps a whole turn cheap.
#   Determinism: no randomness, no clocks in the decision (the node cap, not a timer, bounds the
#   search). The action is a pure function of the state (including its undo snapshots, which
#   replay() and load_text() rebuild exactly), whichever instance is asked and whatever it was
#   asked before. A brain may memoise a pure result by the anchor's hash; that never changes an
#   answer. `seed` is kept for the factory contract and the logs; no level draws random numbers.
#   Levels:
#     Rookie  (CzRookieAI)  the sim bots' greedy policy (tools/loadout_sim.py Game.do_turn).
#     Veteran (CzVeteranAI) scores whole-turn plans on cloned belief worlds.
# Dependencies: CzBelief, CzSim, LoadoutRules, MatchState, SeatState, CardData, BalanceConfig.
# Author: Mechanics Developer Agent
class_name CzAI
extends RefCounted

const ROOKIE: StringName = &"rookie"
const VETERAN: StringName = &"veteran"
const LEVELS: Array[StringName] = [ROOKIE, VETERAN]

var level: StringName = ROOKIE
var seed_value: int = 0
## Statistics of the last choose_action: {nodes, plans, ms, searched}.
var last_stats: Dictionary = {}

# The current segment's anchor (see the header). Private to this base class: brains read it only
# through anchor_key() and anchor_world().
var _anchor_snapshot: Dictionary = {}
var _anchor_data: RulesData = null
var _anchor_seat: int = -1
var _anchor_hash: int = 0
var _asked: MatchState = null


func _init(seed_in: int = 0) -> void:
	seed_value = seed_in


## The AI for a level (&"rookie" or &"veteran"). Unknown levels give the Rookie.
static func for_level(level_name: StringName, seed_in: int = 0) -> CzAI:
	var ai: CzAI
	if level_name == VETERAN:
		ai = CzVeteranAI.new(seed_in)
	else:
		ai = CzRookieAI.new(seed_in)
	return ai


## The next action for `seat`, or {} when `seat` has nothing to decide.
func choose_action(state: MatchState, seat: int) -> Dictionary:
	last_stats = {"nodes": 0, "plans": 0, "ms": 0.0, "searched": false}
	if state == null or state.is_over() or state.deciding_seat() != seat:
		return {}
	var started: int = Time.get_ticks_usec()
	var world: MatchState = CzBelief.world(state, seat)
	_anchor_snapshot = {}
	_anchor_hash = 0
	if state.active == seat and state.pending.is_empty() and not state.undo_stack.is_empty():
		_anchor_snapshot = state.undo_stack[0]["state"]
		_anchor_data = state.data
		_anchor_seat = seat
		_anchor_hash = _anchor_snapshot.hash()
	_asked = state
	var action: Dictionary = _decide(world, seat)
	_asked = null
	_anchor_snapshot = {}
	last_stats["ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	return action


## A hash identifying the current segment's anchor, or 0 when the state is itself a segment
## start (no undoable action yet since the turn start or the last shot).
func anchor_key() -> int:
	return _anchor_hash


## At a segment start: the key the NEXT call will see as anchor_key() if this call's action is
## undoable (the hash of this state's snapshot, which apply() stores). 0 otherwise.
func segment_key() -> int:
	if _asked == null or not _anchor_snapshot.is_empty():
		return 0
	return _asked.to_dict().hash()


## The belief world (CzBelief.world) of the current segment's anchor, or null at a segment start.
func anchor_world() -> MatchState:
	if _anchor_snapshot.is_empty():
		return null
	var a: MatchState = MatchState.new()
	a.data = _anchor_data
	a.load_dict(_anchor_snapshot)
	return CzBelief.world(a, _anchor_seat)


## Subclasses: the action for `seat` in the belief world (the only state they may read).
func _decide(_world: MatchState, _seat: int) -> Dictionary:
	return {}


# === Shared policy pieces (both levels) ==================================================

## Sim attach_all, one step: the first loose attachment (hand, then line) onto the strongest
## non-Starter weapon in hand or line that can take it. {} when none.
static func attach_action(w: MatchState, seat: int) -> Dictionary:
	var st: SeatState = w.seats[seat]
	var cards: Dictionary = w.data.cards
	var pool: Array[int] = []
	var any_att: bool = false
	for list: Array[int] in [st.hand, st.line]:
		for inst: int in list:
			pool.append(inst)
			var c: CardData = cards.get(w.defs.get(inst, &""))
			if c != null and c.type == DataEnums.CardType.ATTACHMENT:
				any_att = true
	if not any_att:
		return {}
	var weapons: Array[int] = []
	for inst: int in pool:
		var c: CardData = w.def_of(inst)
		if c != null and c.is_weapon() and not c.is_starter():
			weapons.append(inst)
	if weapons.is_empty():
		return {}
	weapons.sort_custom(func(x: int, y: int) -> bool:
		var dx: int = CzSim.weapon_dmg(w, x)
		var dy: int = CzSim.weapon_dmg(w, y)
		return dx > dy if dx != dy else x < y)
	for att: int in pool:
		var ac: CardData = w.def_of(att)
		if ac == null or not ac.is_attachment():
			continue
		for wpn: int in weapons:
			var a: Dictionary = {"type": "attach", "seat": seat, "attachment": att, "weapon": wpn}
			if LoadoutRules.is_legal(w, a):
				return a
	return {}


## The sim's Brace: highest Brace first until the damage is covered (none when nothing helps).
static func greedy_brace(w: MatchState, seat: int) -> Dictionary:
	var rec: Dictionary = w.last_shot["targets"][seat]
	var damage: int = int(rec["damage_before_brace"])
	var eligible: Array[int] = LoadoutRules._brace_candidates(w, seat)
	eligible.sort_custom(func(x: int, y: int) -> bool:
		var bx: int = w.def_of(x).brace
		var by: int = w.def_of(y).brace
		return bx > by if bx != by else x < y)
	var cards: Array = []
	var total: int = 0
	for inst: int in eligible:
		if total >= damage:
			break
		cards.append(inst)
		total += w.def_of(inst).brace
	return {"type": "brace", "seat": seat, "cards": cards}


## End turn: hold `prefer` first (in that order), then the hand's other Brace cards by Brace,
## up to hold_limit. Rack swap: no hold, no rack move.
static func end_turn_action(w: MatchState, seat: int, prefer: Array[int], brace_fill: bool) -> Dictionary:
	var b: BalanceConfig = w.data.balance
	if b.packing_rule == DataEnums.PackingRule.RACK_SWAP:
		return {"type": "end_turn", "seat": seat, "hold": []}
	var st: SeatState = w.seats[seat]
	var hold: Array = []
	for inst: int in prefer:
		if hold.size() < b.hold_limit and st.hand.has(inst) and not w.is_hit(inst) and not hold.has(inst):
			hold.append(inst)
	if brace_fill:
		var rest: Array[int] = []
		for inst: int in st.hand:
			var c: CardData = w.def_of(inst)
			if c != null and not c.is_hit() and c.brace > 0 and not hold.has(inst):
				rest.append(inst)
		rest.sort_custom(func(x: int, y: int) -> bool:
			var bx: int = w.def_of(x).brace
			var by: int = w.def_of(y).brace
			return bx > by if bx != by else st.hand.find(x) < st.hand.find(y))
		for inst: int in rest:
			if hold.size() < b.hold_limit:
				hold.append(inst)
	return {"type": "end_turn", "seat": seat, "hold": hold}


## A play action for a Hit as Adrenaline: `mode` if allowed, else the other mode, else {}
## (R6: the Adrenaline cap, and move_only mode). Mirrors LoadoutRules._check_play for a Hit.
static func adrenaline_action(w: MatchState, seat: int, inst: int, mode: String) -> Dictionary:
	var b: BalanceConfig = w.data.balance
	var st: SeatState = w.seats[seat]
	if inst == 0 or not st.hand.has(inst):
		return {}
	if b.adrenaline_cap_per_turn > 0 and st.adrenaline_played >= b.adrenaline_cap_per_turn:
		return {}
	var m: String = mode
	if m == "search" and b.adrenaline_mode == DataEnums.AdrenalineMode.MOVE_ONLY:
		m = "move"
	return {"type": "play", "seat": seat, "card": inst, "adrenaline": m}


## The first Hit in hand, or 0.
static func first_hit(w: MatchState, seat: int) -> int:
	var hit_id: StringName = w.data.hit_id
	for inst: int in w.seats[seat].hand:
		if w.defs.get(inst, &"") == hit_id:
			return inst
	return 0


## Patch up is legal (R18): Search 2 and a Hit in hand or line.
static func can_patch_up(w: MatchState, seat: int) -> bool:
	var st: SeatState = w.seats[seat]
	return st.search >= LoadoutRules.PATCH_UP_COST and CzSim.healable_hits(w, seat) > 0


## Sim want(): loot value of a card for `seat` given what it already owns.
static func want(w: MatchState, seat: int, id: StringName) -> int:
	return want_in(w, id, owned_facts(w, seat))


## What want() needs to know about a seat's cards, computed once:
## {power (best weapon DMG x fires), guns (non-Starter weapons), full (all guns carry 2
## attachments), ids (card ids owned, attachments included)}.
static func owned_facts(w: MatchState, seat: int) -> Dictionary:
	var power: int = 0
	var guns: int = 0
	var full: bool = true
	var ids: Dictionary = {}
	for inst: int in CzSim.all_cards(w, seat):
		var c: CardData = w.def_of(inst)
		if c == null:
			continue
		ids[c.id] = true
		if c.is_weapon():
			power = maxi(power, CzSim.weapon_power(w, inst))
			var atts: Array[int] = w.attachments_of(inst)
			for att: int in atts:
				ids[w.card_id(att)] = true
			if not c.is_starter():
				guns += 1
				if atts.size() < 2:
					full = false
	return {"power": power, "guns": guns, "full": full, "ids": ids}


## want() with the owner's facts precomputed (owned_facts).
static func want_in(w: MatchState, id: StringName, facts: Dictionary) -> int:
	var c: CardData = w.data.card(id)
	if c == null or c.blast_dmg > 0:
		return 0
	var v: int = CzSim.value_of(id)
	if (c.is_weapon() or c.is_attachment()) and facts.is_empty():
		return v
	if c.is_weapon():
		if int(facts["power"]) > 0 and int(facts["power"]) >= c.dmg * c.fires_per_turn:
			v -= 6
	elif c.is_attachment():
		if (facts["ids"] as Dictionary).has(id) or int(facts["guns"]) == 0 or facts["full"]:
			v -= 6
	return v


## Drop (S5): a pure function of the route, the seat, the opponent's drop (if placed) and the
## level. Scores each outer area; ties go to the lower area number.
static func drop_action(w: MatchState, seat: int, veteran: bool) -> Dictionary:
	var data: RulesData = w.data
	var opp: int = w.opponent_of(seat)
	var opp_area: StringName = w.seats[opp].area
	var best: StringName = &""
	var best_score: float = -INF
	var opening_search: int = 4
	for area_id: StringName in data.area_order:
		if not data.is_outer(area_id):
			continue
		var score: float = 0.0
		var area: AreaData = data.area(area_id)
		for c: CardData in area.piles:
			if c.cost <= opening_search:
				score = maxf(score, float(CzSim.value_of(c.id)))
		if veteran:
			# Neighbours' loot (turn 1 has Move 1 at hand 5), the gas order, the first drop.
			var near: float = 0.0
			for other: StringName in data.area_order:
				if data.is_adjacent(area_id, other):
					for c: CardData in data.area(other).piles:
						if c.cost <= opening_search:
							near = maxf(near, float(CzSim.value_of(c.id)))
			score += 0.4 * near
			score += 0.3 * float(_rounds_until_gas(w, area_id))
			var first_drop: StringName = _first_drop_area(w)
			if first_drop != &"":
				score += 2.0 if data.distance(area_id, first_drop) <= 1 else 0.0
			if opp_area != &"":
				var d: int = data.distance(area_id, opp_area)
				score += -6.0 if d == 0 else (-1.0 if d == 1 else 0.5)
		elif opp_area == area_id:
			score -= 6.0
		if score > best_score:
			best_score = score
			best = area_id
	return {"type": "drop", "seat": seat, "area": String(best)}


static func _rounds_until_gas(w: MatchState, area_id: StringName) -> int:
	for k: int in range(1, w.data.balance.zone_hard_end_card + 1):
		var z: ZoneCardData = w.data.zone_card(k)
		if z != null and z.close_for(w.route) != null and z.close_for(w.route).id == area_id:
			return k
	return w.data.balance.zone_hard_end_card + 1


static func _first_drop_area(w: MatchState) -> StringName:
	for k: int in range(1, w.data.balance.zone_hard_end_card + 1):
		var z: ZoneCardData = w.data.zone_card(k)
		if z != null and z.drop_card != null and z.drop_area_for(w.route) != null:
			return z.drop_area_for(w.route).id
	return &""
