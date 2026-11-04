# cz_veteran_ai.gd
# Purpose: Veteran, the hard CardZone AI (cz09). It scores whole-turn plans on cloned belief
#   worlds (CzBelief) and plays the first action of the best one.
#   A plan (theta) is a small set of choices for the rest of this turn:
#     keep  which Brace cards in hand to keep unplayed and Hold (subsets up to hold_limit);
#     dest  where to end the turn (every non-gas area the turn's Move can reach, or stay);
#     pre   what to do before leaving: 0 nothing, 1 shoot, 2 shoot and loot (hit and run);
#     loot  loot (greedy by value) or keep the Search for Patch up;
#     frag  throw a Frag at the opponent's area when it reaches and deals damage.
#   One deterministic executor (plan_step) turns (state, plan) into the next concrete action:
#   attach, play the items the plan doesn't keep, play weapons, act at the origin, step toward
#   dest (Move, then Hits as Adrenaline), act at dest (shoot best-first, Frag, loot), Hits for
#   Search, Patch up, end_turn holding the kept cards. The opponent's Brace inside a rollout is
#   the greedy rule on its guessed next hand.
#   Search: every plan is rolled out to the end of the turn (end_turn applied, so the gas check,
#   the Pack and the opponent's draw happen) and scored by evaluate(). Plans that share actions
#   share the work (a trie: the state is cloned only where plans part ways). When every plan
#   starts with the same action (attach, plays), that action is returned without a search.
#   A node cap (NODE_CAP simulated actions per decision) bounds the work deterministically; the
#   ai_think_budget_ms tunable is only a safety stop for very slow devices.
#   As the defender it scores every legal Brace subset with evaluate().
#   Determinism: plans are enumerated in a fixed order and ties keep the first, so the same
#   state gives the same action.
# Dependencies: CzAI, CzSim, CzBelief, LoadoutRules, MatchState, SeatState, CardData.
# Author: Mechanics Developer Agent
class_name CzVeteranAI
extends CzAI

## Simulated actions per decision (the deterministic search bound).
const NODE_CAP: int = 900
## Deepest rollout (actions) before a plan is cut and scored where it stands.
const MAX_DEPTH: int = 60

# Evaluation weights (see evaluate()).
const W_HEALTH: float = 100.0
const W_POWER: float = 14.0
const W_VALUE: float = 2.0
const W_THREAT_IN: float = 38.0
const W_THREAT_OUT: float = 16.0
const W_GAS: float = 60.0
const W_CLOSING: float = 30.0
const W_HAND: float = 3.0
const W_CARDS: float = 3.0
const W_BOUNTY: float = 8.0
const W_NEXT_DROP: float = 6.0
const WIN: float = 100000.0

var _me: int = 0
var _nodes: int = 0
var _deadline_us: int = 0


func _init(seed_in: int = 0) -> void:
	super(seed_in)
	level = CzAI.VETERAN


func _decide(w: MatchState, me: int) -> Dictionary:
	_me = me
	_nodes = 0
	_deadline_us = Time.get_ticks_usec() + 1000 * w.data.balance.ai_think_budget_ms
	if w.phase == MatchState.PHASE_DROP:
		return CzAI.drop_action(w, me, true)
	if w.pending_brace_seat() == me:
		return _choose_brace(w, me)
	var plans: Array[Dictionary] = plans_for(w, me)
	last_stats["plans"] = plans.size()
	var firsts: Array[Dictionary] = []
	var same: bool = true
	var memo: Dictionary = {}
	for th: Dictionary in plans:
		var a: Dictionary = plan_step(w, me, th, memo)
		firsts.append(a)
		if same and str(a) != str(firsts[0]):
			same = false
	if same:
		return firsts[0]
	last_stats["searched"] = true
	var scores: Array[float] = []
	scores.resize(plans.size())
	scores.fill(-INF)
	var idxs: Array[int] = []
	for i: int in plans.size():
		idxs.append(i)
	_expand(CzSim.clone(w), plans, idxs, scores, 0)
	last_stats["nodes"] = _nodes
	var best: int = 0
	for i: int in plans.size():
		if scores[i] > scores[best]:
			best = i
	return firsts[best]


# === Plans ==================================================================================

## Every plan for `me` from this state, in a fixed order.
static func plans_for(w: MatchState, me: int) -> Array[Dictionary]:
	var st: SeatState = w.seats[me]
	var b: BalanceConfig = w.data.balance
	var opp: int = w.opponent_of(me)
	var origin: StringName = st.area
	var opp_area: StringName = w.seats[opp].area
	# Keep sets: distinct Brace-card combinations (by card id) up to hold_limit.
	var brace_cards: Array[int] = []
	for inst: int in st.hand:
		if CzSim.is_item(w, inst) and w.def_of(inst).brace > 0:
			brace_cards.append(inst)
	var keeps: Array = [[]]
	if b.packing_rule != DataEnums.PackingRule.RACK_SWAP:
		var keys: Array[String] = [""]
		for subset: Array in LoadoutRules._subsets(brace_cards, b.hold_limit):
			if subset.is_empty():
				continue
			var names: Array[String] = []
			for x: Variant in subset:
				names.append(String(w.card_id(int(x))))
			names.sort()
			var key: String = ",".join(names)
			if keys.has(key):
				continue
			keys.append(key)
			keeps.append(subset)
	var has_frag: bool = false
	for inst: int in st.hand:
		if CzSim.is_frag(w, inst):
			has_frag = true
	var can_heal: bool = CzSim.healable_hits(w, me) > 0
	var shoot_here: bool = _can_shoot_from(w, me, origin, has_frag)
	var loot_here: bool = false
	for opt: Dictionary in CzSim.loot_options(w, me, origin):
		if CzAI.want(w, me, opt["id"]) > 0:
			loot_here = true
	var out: Array[Dictionary] = []
	for keep: Array in keeps:
		var max_move: int = st.move + w.hits_in(st.hand)
		for inst: int in st.hand:
			if CzSim.is_item(w, inst) and not keep.has(inst):
				max_move += w.def_of(inst).move
		var dests: Array[StringName] = [origin]
		for a: StringName in w.data.area_order:
			if a != origin and not w.gas.has(a) and w.data.distance(origin, a) <= max_move:
				dests.append(a)
		for dest: StringName in dests:
			var pres: Array[int] = [0]
			if dest != origin:
				if shoot_here:
					pres.append(1)
				if loot_here:
					pres.append(2)
			var frag_opts: Array[bool] = [false]
			if has_frag and not w.seats[opp].eliminated and (w.data.distance(origin, opp_area) <= 1 \
					or w.data.distance(dest, opp_area) <= 1):
				frag_opts.append(true)
			for pre: int in pres:
				for loot: bool in ([true, false] if can_heal or w.hits_in(st.hand) > 0 else [true]):
					for frag: bool in frag_opts:
						out.append({"keep": keep, "dest": dest, "origin": origin, "pre": pre, "loot": loot,
								"frag": frag})
	return out


static func _can_shoot_from(w: MatchState, me: int, area: StringName, has_frag: bool) -> bool:
	var st: SeatState = w.seats[me]
	var opp_area: StringName = w.seats[w.opponent_of(me)].area
	var d: int = w.data.distance(area, opp_area)
	if has_frag and d <= 1 and area != opp_area:
		return true
	for inst: int in st.hand + st.line:
		if w.def_of(inst).is_weapon() and LoadoutRules.weapon_range(w, inst) >= d:
			return true
	return false


## The executor: the next action of plan `th` for `me` (or the pending Brace of either seat).
## `memo` caches the plan-independent parts for this exact state (pass {} for a one-off call;
## share one Dictionary between the plans asked about the same state).
static func plan_step(w: MatchState, me: int, th: Dictionary, memo: Dictionary = {}) -> Dictionary:
	if not memo.has("pending"):
		var pb: int = w.pending_brace_seat()
		memo["pending"] = CzAI.greedy_brace(w, pb) if pb != MatchState.NO_SEAT else {}
	if not (memo["pending"] as Dictionary).is_empty():
		return memo["pending"]
	if w.is_over() or w.active != me:
		return {}
	var st: SeatState = w.seats[me]
	var keep: Array = th["keep"]
	# 1. Attach.
	if not memo.has("attach"):
		memo["attach"] = CzAI.attach_action(w, me)
	if not (memo["attach"] as Dictionary).is_empty():
		return memo["attach"]
	# 2. Items the plan doesn't keep (Pull cards first), 3. weapons to the line.
	if not memo.has("plays"):
		memo["plays"] = _plays(w, me)
	for inst: int in memo["plays"]:
		if not keep.has(inst):
			return {"type": "play", "seat": me, "card": inst}
	# 4. Act at the origin, move, act at the destination.
	var dest: StringName = th["dest"]
	var stuck: bool = false
	if st.area != dest:
		if st.area == th["origin"] and int(th["pre"]) >= 1:
			var s1: Dictionary = _memo_shot(w, me, th["frag"], memo)
			if not s1.is_empty():
				return s1
			if int(th["pre"]) >= 2 and th["loot"]:
				var l1: Dictionary = _memo_loot(w, me, dest, memo)
				if not l1.is_empty():
					return l1
		if st.move >= 1:
			return {"type": "move", "seat": me, "to": String(CzSim.step_toward(w.data, st.area, dest))}
		var adr: Dictionary = _memo_adrenaline(w, me, "move", memo)
		if not adr.is_empty() and adr["adrenaline"] == "move":
			return adr
		stuck = true
	if st.area == dest or stuck:
		var s2: Dictionary = _memo_shot(w, me, th["frag"], memo)
		if not s2.is_empty():
			return s2
		if th["loot"]:
			var l2: Dictionary = _memo_loot(w, me, st.area, memo)
			if not l2.is_empty():
				return l2
	# 5. Hits for Search, Patch up.
	var adr2: Dictionary = _memo_adrenaline(w, me, "search", memo)
	if not adr2.is_empty():
		return adr2
	if not memo.has("patch"):
		memo["patch"] = LoadoutRules.is_legal(w, {"type": "patch_up", "seat": me})
	if memo["patch"]:
		return {"type": "patch_up", "seat": me}
	# 6. Pack: hold the kept cards (highest Brace first), then Frags and Heal items.
	var prefer: Array[int] = []
	for x: Variant in keep:
		prefer.append(int(x))
	prefer.sort_custom(func(x: int, y: int) -> bool:
		var bx: int = w.def_of(x).brace
		var by: int = w.def_of(y).brace
		return bx > by if bx != by else x < y)
	for inst: int in st.hand:
		if CzSim.is_frag(w, inst):
			prefer.append(inst)
	for inst: int in st.hand:
		var c: CardData = w.def_of(inst)
		if CzSim.is_item(w, inst) and c.heal > 0 and c.brace == 0:
			prefer.append(inst)
	return CzAI.end_turn_action(w, me, prefer, false)


## Hand cards a plan plays before acting, in order: Pull items, other useful items (a Heal-only
## or Spent Heal card waits for a Hit to heal), then weapons. A plan skips the ones it keeps.
static func _plays(w: MatchState, me: int) -> Array[int]:
	var st: SeatState = w.seats[me]
	var out: Array[int] = []
	var heal_now: bool = CzSim.healable_hits(w, me) > 0
	# Pass 0: Pull items; 1: other items without Brace; 2: weapons; 3: Brace items (the ones a
	# plan may keep come last, so plans agree on everything before them).
	for pass_no: int in 4:
		for inst: int in st.hand:
			var c: CardData = w.def_of(inst)
			if pass_no == 2:
				if c.is_weapon():
					out.append(inst)
				continue
			if not CzSim.is_item(w, inst):
				continue
			var p: int = 0 if c.pull > 0 else (3 if c.brace > 0 else 1)
			if p != pass_no:
				continue
			if c.heal > 0 and not heal_now and (c.move + c.search + c.pull == 0 or c.spent == DataEnums.SpentMode.ON_PLAY):
				continue
			if c.move + c.search + c.pull + c.heal == 0:
				continue
			out.append(inst)
	return out


static func _memo_shot(w: MatchState, me: int, frag: bool, memo: Dictionary) -> Dictionary:
	var key: String = "shot1" if frag else "shot0"
	if not memo.has(key):
		memo[key] = _best_shot(w, me, frag)
	return memo[key]


static func _memo_loot(w: MatchState, me: int, dest: StringName, memo: Dictionary) -> Dictionary:
	var key: String = "loot:" + String(dest)
	if not memo.has(key):
		memo[key] = _best_loot(w, me, dest)
	return memo[key]


static func _memo_adrenaline(w: MatchState, me: int, mode: String, memo: Dictionary) -> Dictionary:
	var key: String = "adr:" + mode
	if not memo.has(key):
		var hit: int = CzAI.first_hit(w, me)
		memo[key] = CzAI.adrenaline_action(w, me, hit, mode) if hit != 0 else {}
	return memo[key]


## The strongest legal shot with damage > 0 (weapons by damage), then a Frag at the opponent's
## area when allowed and it hurts only them. {} when none.
static func _best_shot(w: MatchState, me: int, allow_frag: bool) -> Dictionary:
	var st: SeatState = w.seats[me]
	var opp: int = w.opponent_of(me)
	var best: Dictionary = {}
	var best_dmg: int = 0
	for inst: int in st.line:
		if not w.def_of(inst).is_weapon():
			continue
		var a: Dictionary = {"type": "shoot", "seat": me, "weapon": inst, "target": opp}
		if not LoadoutRules.is_legal(w, a):
			continue
		var dmg: int = int(LoadoutRules.shot_profile(w, me, inst, opp)["damage"])
		if dmg > best_dmg:
			best_dmg = dmg
			best = a
	if not best.is_empty():
		return best
	if allow_frag:
		var opp_area: StringName = w.seats[opp].area
		if opp_area != st.area:
			for inst: int in st.hand:
				if not CzSim.is_frag(w, inst):
					continue
				var f: Dictionary = {"type": "frag", "seat": me, "card": inst, "area": String(opp_area)}
				if LoadoutRules.is_legal(w, f) and \
						int(LoadoutRules.blast_profile(w, me, inst, opp_area, opp)["damage"]) > 0:
					return f
	return {}


## The best wanted loot here (value, then cheaper), paying with Hits not needed to reach `dest`.
static func _best_loot(w: MatchState, me: int, dest: StringName) -> Dictionary:
	var st: SeatState = w.seats[me]
	var need_move: int = maxi(0, w.data.distance(st.area, dest) - st.move)
	var spare: int = maxi(0, w.hits_in(st.hand) - need_move)
	if w.data.balance.adrenaline_mode == DataEnums.AdrenalineMode.MOVE_ONLY:
		spare = 0
	var best: Dictionary = {}
	var best_key: Vector2i = Vector2i(0, 0)
	for opt: Dictionary in CzSim.loot_options(w, me, st.area):
		var v: int = CzAI.want(w, me, opt["id"])
		var cost: int = int(opt["cost"])
		if v <= 0 or cost > st.search + spare:
			continue
		var key: Vector2i = Vector2i(v, -cost)
		if best.is_empty() or key > best_key:
			best_key = key
			best = opt
	if best.is_empty():
		return {}
	if st.search < int(best["cost"]):
		var hit: int = CzAI.first_hit(w, me)
		var adr: Dictionary = CzAI.adrenaline_action(w, me, hit, "search")
		if not adr.is_empty() and adr["adrenaline"] == "search":
			return adr
		return {}
	return CzSim.loot_action(me, best)


# === Search =================================================================================

## Rolls the plans `idxs` forward from `node` (which this call may change), sharing common
## actions, and writes each plan's score.
func _expand(node: MatchState, plans: Array[Dictionary], idxs: Array[int], scores: Array[float], depth: int) -> void:
	var order: Array[String] = []
	var groups: Dictionary = {}
	var actions: Dictionary = {}
	var memo: Dictionary = {}
	for i: int in idxs:
		var a: Dictionary = plan_step(node, _me, plans[i], memo)
		var key: String = str(a)
		if not groups.has(key):
			var fresh: Array[int] = []
			groups[key] = fresh
			actions[key] = a
			order.append(key)
		(groups[key] as Array[int]).append(i)
	for g: int in order.size():
		var key: String = order[g]
		var members: Array[int] = groups[key]
		var child: MatchState = node if g == order.size() - 1 else CzSim.clone(node)
		var a: Dictionary = actions[key]
		var score: float
		if a.is_empty() or not CzSim.step(child, a):
			score = evaluate(child, _me)
		else:
			_nodes += 1
			if child.is_over() or String(a["type"]) == "end_turn" or depth >= MAX_DEPTH:
				score = evaluate(child, _me)
			elif _nodes >= NODE_CAP or Time.get_ticks_usec() > _deadline_us:
				score = _rollout(child, plans[members[0]], depth + 1)
			else:
				_expand(child, plans, members, scores, depth + 1)
				continue
		for i: int in members:
			scores[i] = score


## Past the cap: plays one plan to the end without branching and scores it.
func _rollout(s: MatchState, th: Dictionary, depth: int) -> float:
	var d: int = depth
	while d < MAX_DEPTH:
		var a: Dictionary = plan_step(s, _me, th, {})
		if a.is_empty() or not CzSim.step(s, a):
			break
		_nodes += 1
		d += 1
		if s.is_over() or String(a["type"]) == "end_turn":
			break
	return evaluate(s, _me)


func _choose_brace(w: MatchState, me: int) -> Dictionary:
	var options: Array[Dictionary] = LoadoutRules.legal_actions(w)
	var best: Dictionary = {"type": "brace", "seat": me, "cards": []}
	var best_score: float = -INF
	for a: Dictionary in options:
		var c: MatchState = CzSim.clone(w)
		if not CzSim.step(c, a):
			continue
		_nodes += 1
		var score: float = evaluate(c, me)
		if score > best_score:
			best_score = score
			best = a
	last_stats["nodes"] = _nodes
	return best


# === Evaluation =============================================================================

## Position value for `me` (higher is better). Terminal: +/- WIN. Otherwise: health difference;
## gun power and loot value (all cards); the damage the opponent can likely deal on its next turn
## (after my next hand's Brace and Down) and what I can deal on mine; gas and the area closing
## next round; Move+Search in my next hand; card count (the tiebreak); the Bounty; the next drop.
static func evaluate(w: MatchState, me: int) -> float:
	if w.is_over():
		var r: Dictionary = w.match_end
		if String(r.get("result", "")) == "win":
			return WIN - float(w.round_number) if int(r["winner"]) == me else -WIN + float(w.round_number)
		return 0.0
	var opp: int = w.opponent_of(me)
	var a: Dictionary = _seat_facts(w, me)
	var o: Dictionary = _seat_facts(w, opp)
	var s: float = W_HEALTH * float(w.health_of(me) - w.health_of(opp))
	s += W_POWER * float(int(a["power"]) - int(o["power"]))
	s += W_VALUE * float(int(a["value"]) - int(o["value"]))
	var data: RulesData = w.data
	var my_area: StringName = w.seats[me].area
	var opp_area: StringName = w.seats[opp].area
	var threat_in: float = maxf(_threat(data, o["now"], opp_area, my_area, 1, a),
			0.6 * _threat(data, o["guns"], opp_area, my_area, 1, a))
	var threat_out: float = maxf(_threat(data, a["next"], my_area, opp_area, mini(int(a["next_move"]), 2), o),
			0.6 * _threat(data, a["guns"], my_area, opp_area, 1, o))
	s -= W_THREAT_IN * threat_in
	s += W_THREAT_OUT * threat_out
	var closing: StringName = CzSim.closing_next(w)
	if w.gas.has(my_area):
		s -= W_GAS
	elif my_area == closing:
		s -= W_CLOSING
	if w.gas.has(opp_area):
		s += W_GAS
	elif opp_area == closing:
		s += W_CLOSING
	s += W_HAND * float(a["next_gain"])
	s += W_CARDS * float(int(a["cards"]) - int(o["cards"]))
	if w.bounty == me:
		s -= W_BOUNTY
	elif w.bounty == opp:
		s += W_BOUNTY
	var z: ZoneCardData = data.zone_card(w.zone_card + 1)
	if z != null and z.drop_card != null and z.drop_area_for(w.route) != null:
		var drop_area: StringName = z.drop_area_for(w.route).id
		if data.distance(my_area, drop_area) <= 1:
			s += W_NEXT_DROP
		if data.distance(opp_area, drop_area) <= 1:
			s -= W_NEXT_DROP
	return s


## One pass over a seat's cards: {power (best DMG x fires), value (loot value), cards (non-Hit
## count), guns (every weapon), now (weapons in hand and line), next (weapons in the next draw),
## next_move (Move + Hits in the next draw), next_gain (Move + Search of the next hand),
## brace (Brace of the next hand), down}. A gun is [dmg, fires, rng, ignores_cover].
static func _seat_facts(w: MatchState, seat: int) -> Dictionary:
	var st: SeatState = w.seats[seat]
	var b: BalanceConfig = w.data.balance
	var hit_id: StringName = w.data.hit_id
	var power: int = 0
	var value: int = 0
	var cards: int = 0
	var guns: Array = []
	var now: Array = []
	var nxt: Array = []
	var next_move: int = 0
	var next_gain: int = 0
	var brace: int = 0
	var next_hits: int = 0
	# Next draw (D4): from the top until hand_size non-Hit cards.
	var real: int = 0
	var in_next: Dictionary = {}
	for inst: int in st.loadout:
		if real >= b.hand_size:
			break
		in_next[inst] = true
		if w.defs.get(inst, &"") == hit_id:
			next_hits += 1
		else:
			real += 1
	var lists: Array = [st.loadout, st.hand, st.line]
	for li: int in 3:
		for inst: int in lists[li]:
			var c: CardData = w.data.cards.get(w.defs.get(inst, &""))
			if c == null or c.is_hit():
				continue
			cards += 1
			value += int(CzSim.VALUE.get(c.id, 0))
			var nx: bool = li == 0 and in_next.has(inst)
			if nx:
				next_move += c.move
				next_gain += c.move + c.search
				if not st.braced.has(inst):
					brace += c.brace
			if c.is_weapon():
				var dmg: int = c.dmg
				var fires: int = c.fires_per_turn
				var rng: int = c.rng
				for att: Variant in w.attachments.get(inst, []):
					var ac: CardData = w.data.cards.get(w.defs.get(int(att), &""))
					if ac != null:
						dmg += ac.attach_dmg
						fires += ac.attach_extra_fire
						rng += ac.attach_rng
						value += int(CzSim.VALUE.get(ac.id, 0))
				var gun: Array = [dmg, fires, mini(rng, DataEnums.MAX_RANGE), c.ignores_cover]
				power = maxi(power, dmg * fires)
				guns.append(gun)
				if li > 0:
					now.append(gun)
				elif nx:
					nxt.append(gun)
	return {"power": power, "value": value, "cards": cards, "guns": guns, "now": now, "next": nxt,
			"next_move": next_move + next_hits, "next_gain": next_gain, "brace": brace,
			"down": b.down_enabled and next_hits > 0}


## Hits the guns can likely land next turn from `from` on a target in `target`, moving up to
## `moves` steps first: per gun, the best spot (Cover only from another area) times its shots,
## minus Down per shot, then minus the Brace in the defender's next hand. 0 when out of reach.
static func _threat(data: RulesData, guns: Array, from: StringName, target: StringName, moves: int,
		defender: Dictionary) -> float:
	if guns.is_empty():
		return 0.0
	var down: int = data.balance.down_value if defender["down"] else 0
	var cover: int = data.cover_of(target)
	var dist: int = data.distance(from, target)
	var best: int = 0
	for gun: Array in guns:
		var reach: int = -1
		if dist <= moves:
			reach = int(gun[0])
		elif dist - moves <= int(gun[2]):
			reach = int(gun[0]) if gun[3] else int(gun[0]) - cover
		if reach < 0:
			continue
		best = maxi(best, int(gun[1]) * maxi(0, reach - down))
	return float(maxi(0, best - int(defender["brace"])))
