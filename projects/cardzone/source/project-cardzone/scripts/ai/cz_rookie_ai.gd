# cz_rookie_ai.gd
# Purpose: Rookie, the easy CardZone AI (cz09): the sim bots' greedy policy from
#   tools/loadout_sim.py (Game.do_turn, attach_all, want, shoot), one action at a time.
#   Each call re-derives the next step of that turn from the belief world, so it is a pure
#   function of the state. Turn order, as in the sim:
#     1. attach loose attachments to the strongest non-Starter weapon;
#     2. play every item with no Brace (Brace cards are the "reserve"); Frags are never used;
#     3. pick a destination: out of gas / the area closing next round (nearest safe area, the
#        Core on ties); from round 4 with a non-Starter gun, the nearest area in range of the
#        opponent (Cover preferred); otherwise the area with the best affordable loot (value -
#        0.5 x distance) within this turn's Move and Search budget;
#     4. pay the steps from Move, then reserve items with the most Move, then Hits as Adrenaline
#        (Move); stop where the Move runs out. Leftover Hits become Search;
#     5. shoot every weapon in range, strongest first (a weapon in hand is played first);
#     6. loot the best wanted card it can afford, playing reserve items for Search if needed
#        (a looted weapon fires at once: step 5 runs again);
#     7. Patch up while Search >= 2 and a Hit is in hand or line;
#     8. end the turn holding the hand's Brace cards, highest first, up to hold_limit.
#   As the defender it braces highest-first until the damage is covered (the sim's rule).
#   Moving stops once it has shot or looted this turn (the sim moves before it acts).
# Dependencies: CzAI, CzSim, LoadoutRules, MatchState, SeatState, CardData.
# Author: Mechanics Developer Agent
class_name CzRookieAI
extends CzAI


func _init(seed_in: int = 0) -> void:
	super(seed_in)
	level = CzAI.ROOKIE


func _decide(w: MatchState, me: int) -> Dictionary:
	if w.phase == MatchState.PHASE_DROP:
		return CzAI.drop_action(w, me, false)
	if w.pending_brace_seat() == me:
		return CzAI.greedy_brace(w, me)
	return next_action(w, me)


## The Rookie's next action in a world where `me` is active.
static func next_action(w: MatchState, me: int) -> Dictionary:
	var st: SeatState = w.seats[me]
	# 1. Attach.
	var att: Dictionary = CzAI.attach_action(w, me)
	if not att.is_empty():
		return att
	# 2. Items with no Brace.
	for inst: int in st.hand:
		var c: CardData = w.def_of(inst)
		if CzSim.is_item(w, inst) and c.brace == 0:
			var a: Dictionary = {"type": "play", "seat": me, "card": inst}
			if LoadoutRules.is_legal(w, a):
				return a
	# 3-4. Move (only before the first shot or loot of the turn).
	var acted: bool = not st.fired.is_empty() or not st.looted.is_empty()
	if not acted:
		var dest: StringName = destination(w, me)
		if dest != st.area:
			if st.move >= 1:
				return {"type": "move", "seat": me, "to": String(CzSim.step_toward(w.data, st.area, dest))}
			var reserve: int = _best_reserve(w, me, "move")
			if reserve != 0:
				return {"type": "play", "seat": me, "card": reserve}
			var hit: int = CzAI.first_hit(w, me)
			if hit != 0:
				var adr: Dictionary = CzAI.adrenaline_action(w, me, hit, "move")
				if not adr.is_empty() and adr["adrenaline"] == "move":
					return adr
		# Leftover Adrenaline becomes Search.
		var left: int = CzAI.first_hit(w, me)
		if left != 0:
			var adr2: Dictionary = CzAI.adrenaline_action(w, me, left, "search")
			if not adr2.is_empty():
				return adr2
	# 5. Shoot, strongest first.
	var shot: Dictionary = _shot(w, me)
	if not shot.is_empty():
		return shot
	# 6. Loot.
	var loot: Dictionary = _loot(w, me)
	if not loot.is_empty():
		return loot
	# 7. Patch up.
	if CzAI.can_patch_up(w, me):
		return {"type": "patch_up", "seat": me}
	# 8. Pack.
	return CzAI.end_turn_action(w, me, [], true)


## Sim "Decide destination" from the current state.
static func destination(w: MatchState, me: int) -> StringName:
	var st: SeatState = w.seats[me]
	var opp: int = w.opponent_of(me)
	var data: RulesData = w.data
	var order: Array[StringName] = CzSim.sim_area_order(data)
	var closing: StringName = CzSim.closing_next(w)
	var here: StringName = st.area
	var pool: Array[int] = []
	pool.append_array(st.hand)
	pool.append_array(st.line)
	var weapon: int = CzSim.best_weapon(w, pool)
	if w.gas.has(here) or here == closing:
		var best: StringName = here
		var best_key: Vector2i = Vector2i(999, 999)
		for a: StringName in order:
			if w.gas.has(a) or a == closing:
				continue
			var key: Vector2i = Vector2i(data.distance(here, a), 1 if data.is_outer(a) else 0)
			if key < best_key:
				best_key = key
				best = a
		return best
	if weapon != 0 and not w.def_of(weapon).is_starter() and w.round_number >= 4 and not w.seats[opp].eliminated:
		var rng: int = LoadoutRules.weapon_range(w, weapon)
		var tgt: StringName = w.seats[opp].area
		var spot: StringName = here
		var spot_key: Vector2i = Vector2i(999, 999)
		for a: StringName in order:
			if w.gas.has(a) or data.distance(a, tgt) > rng:
				continue
			var key: Vector2i = Vector2i(data.distance(here, a), 1 if data.cover_of(a) == 0 else 0)
			if key < spot_key:
				spot_key = key
				spot = a
		return spot
	# Loot-seeking within this turn's budget.
	var adren: int = w.hits_in(st.hand)
	var reserve_move: int = 0
	var reserve_search: int = 0
	for inst: int in st.hand:
		if CzSim.is_item(w, inst):
			reserve_move += w.def_of(inst).move
			reserve_search += w.def_of(inst).search
	var budget_m: int = st.move + adren + reserve_move
	var budget_s: int = st.search + adren + reserve_search
	var best_area: StringName = here
	var best_score: float = -1.0
	var facts: Dictionary = CzAI.owned_facts(w, me)
	for a: StringName in order:
		var d: int = data.distance(here, a)
		if d > budget_m or w.gas.has(a) or a == closing:
			continue
		var top: int = 0
		for opt: Dictionary in CzSim.loot_options(w, me, a):
			if int(opt["cost"]) <= budget_s - maxi(0, d - st.move - reserve_move):
				top = maxi(top, CzAI.want_in(w, opt["id"], facts))
		var score: float = float(top) - float(d) * 0.5
		if score > best_score:
			best_score = score
			best_area = a
	return best_area


## The reserve (Brace) item in hand with the most of `pool` ("move" or "search"); for Search,
## ties go to the lower Brace. 0 when none gives any.
static func _best_reserve(w: MatchState, me: int, pool: String) -> int:
	var best: int = 0
	var best_key: Vector2i = Vector2i(0, 0)
	for inst: int in w.seats[me].hand:
		if not CzSim.is_item(w, inst):
			continue
		var c: CardData = w.def_of(inst)
		var gain: int = c.move if pool == "move" else c.search
		if gain <= 0:
			continue
		var key: Vector2i = Vector2i(gain, -c.brace if pool == "search" else 0)
		if best == 0 or key > best_key:
			best_key = key
			best = inst
	return best


static func _shot(w: MatchState, me: int) -> Dictionary:
	var st: SeatState = w.seats[me]
	var opp: int = w.opponent_of(me)
	var weapons: Array[int] = []
	for inst: int in st.hand + st.line:
		if w.def_of(inst).is_weapon():
			weapons.append(inst)
	weapons.sort_custom(func(x: int, y: int) -> bool:
		var dx: int = CzSim.weapon_dmg(w, x)
		var dy: int = CzSim.weapon_dmg(w, y)
		return dx > dy if dx != dy else x < y)
	for wpn: int in weapons:
		if w.data.distance(st.area, w.seats[opp].area) > LoadoutRules.weapon_range(w, wpn):
			continue
		if st.hand.has(wpn):
			return {"type": "play", "seat": me, "card": wpn}
		var a: Dictionary = {"type": "shoot", "seat": me, "weapon": wpn, "target": opp}
		if LoadoutRules.is_legal(w, a):
			return a
	return {}


static func _loot(w: MatchState, me: int) -> Dictionary:
	var st: SeatState = w.seats[me]
	var extra: int = 0
	for inst: int in st.hand:
		if CzSim.is_item(w, inst):
			extra += w.def_of(inst).search
	var best: Dictionary = {}
	var best_key: Vector2i = Vector2i(0, 0)
	var facts: Dictionary = CzAI.owned_facts(w, me)
	for opt: Dictionary in CzSim.loot_options(w, me, st.area):
		var v: int = CzAI.want_in(w, opt["id"], facts)
		var cost: int = int(opt["cost"])
		if v <= 0 or cost > st.search + extra:
			continue
		var key: Vector2i = Vector2i(v, -cost)
		if best.is_empty() or key > best_key:
			best_key = key
			best = opt
	if best.is_empty():
		return {}
	if st.search < int(best["cost"]):
		var r: int = _best_reserve(w, me, "search")
		if r != 0:
			return {"type": "play", "seat": me, "card": r}
		return {}
	return CzSim.loot_action(me, best)
