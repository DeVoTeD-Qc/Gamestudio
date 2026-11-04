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
#   Determinism: no randomness, no clocks in the decision (the node cap, not a timer, bounds the
#   search), no memory between calls. The same state always gives the same action, whichever
#   instance is asked and whatever it was asked before. `seed` is kept for the factory contract
#   and the logs; neither level draws random numbers.
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
	var action: Dictionary = _decide(world, seat)
	last_stats["ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	return action


## Subclasses: the action for `seat` in the belief world (the only state they may read).
func _decide(_world: MatchState, _seat: int) -> Dictionary:
	return {}


# === Shared policy pieces (both levels) ==================================================

## Sim attach_all, one step: the first loose attachment (hand, then line) onto the strongest
## non-Starter weapon in hand or line that can take it. {} when none.
static func attach_action(w: MatchState, seat: int) -> Dictionary:
	var st: SeatState = w.seats[seat]
	var pool: Array[int] = []
	pool.append_array(st.hand)
	pool.append_array(st.line)
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


## A play action for a Hit as Adrenaline: `mode` if legal, else the other mode, else {}.
static func adrenaline_action(w: MatchState, seat: int, inst: int, mode: String) -> Dictionary:
	for m: String in [mode, "search" if mode == "move" else "move"]:
		var a: Dictionary = {"type": "play", "seat": seat, "card": inst, "adrenaline": m}
		if LoadoutRules.is_legal(w, a):
			return a
	return {}


## The first Hit in hand, or 0.
static func first_hit(w: MatchState, seat: int) -> int:
	for inst: int in w.seats[seat].hand:
		if w.is_hit(inst):
			return inst
	return 0


## Sim want(): loot value of a card for `seat` given what it already owns.
static func want(w: MatchState, seat: int, id: StringName) -> int:
	var c: CardData = w.data.card(id)
	if c == null or c.blast_dmg > 0:
		return 0
	var v: int = CzSim.value_of(id)
	var mine: Array[int] = CzSim.all_cards(w, seat)
	if c.is_weapon():
		var best: int = CzSim.best_weapon(w, mine)
		if best != 0 and CzSim.weapon_power(w, best) >= c.dmg * c.fires_per_turn:
			v -= 6
	elif c.is_attachment():
		var weapons: Array[int] = []
		var owned: bool = false
		for inst: int in mine:
			var mc: CardData = w.def_of(inst)
			if mc.id == id:
				owned = true
			if mc.is_weapon():
				for att: int in w.attachments_of(inst):
					if w.card_id(att) == id:
						owned = true
				if not mc.is_starter():
					weapons.append(inst)
		var all_full: bool = true
		for wpn: int in weapons:
			if w.attachments_of(wpn).size() < 2:
				all_full = false
		if owned or weapons.is_empty() or all_full:
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
