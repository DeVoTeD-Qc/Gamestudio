# cz_veteran_ai.gd
# Purpose: Veteran, the hard CardZone AI (cz09). It scores whole-turn plans on cloned belief
#   worlds (CzBelief) and plays the first action of the best one.
#   A plan is a few choices for the rest of this turn, made lazily: the executor (plan_step)
#   plays everything the choices don't affect and asks for a choice only when it reaches one:
#     keep   which Brace cards in hand stay unplayed to be Held (subsets up to hold_limit),
#            asked when the next card to play is a Brace card;
#     route  where to end the turn (stay, or any non-gas area this turn's Move and Hits reach),
#            asked once the plays are done;
#     pre    before leaving: 0 nothing, 1 shoot, 2 shoot and loot (hit and run);
#     frag   throw a Frag at the opponent's area (asked only when one can hurt them and no gun
#            shot is left);
#     loot   loot (best by value) or keep the Search for Patch up (asked only when both exist).
#   Between choices the executor is fixed: attach, play the Pull items, the other items (a
#   Heal-only card waits for a Hit to heal), the weapons and the Brace cards not kept; act at the
#   origin; step toward the destination (Move, then Hits as Adrenaline); act there (best shot
#   first, Frag, loot); Hits for Search; Patch up; end_turn holding the kept cards (then Frags and
#   Heal items). Inside a rollout the opponent braces with the greedy rule on its guessed hand.
#   Search: a depth-first walk that branches only at those choices, cloning the state at each
#   branch, plays every branch to the end of the turn (end_turn applied: gas check, Pack, the
#   opponent's draw and any round start) and scores it with evaluate(). When the next action
#   needs no choice it is returned without a search.
#   One plan per segment: a turn's segments start at the turn start and after each shot or Frag
#   (CzAI: segment anchor). The search runs from the segment's anchor (its belief world); every
#   later call in the segment follows the winning plan with the same executor, and searches again
#   (from where it stands, keeping the plan's choices) only if the plan meets a choice it hadn't
#   made. So a turn costs about one search per shot, not one per action.
#   A deterministic node cap bounds each search (after it, branches take their first option);
#   ai_think_budget_ms is only a safety stop for very slow devices.
#   As the defender it scores every legal Brace subset with evaluate().
#   Determinism: options come in a fixed order and ties keep the first, and the anchor is part of
#   the state, so the same state gives the same action from any instance. The only memory is a
#   memo of anchor -> plan (a pure function of the anchor), which never changes an answer.
# Dependencies: CzAI, CzSim, CzBelief, LoadoutRules, MatchState, SeatState, CardData.
# Author: Mechanics Developer Agent
class_name CzVeteranAI
extends CzAI

## Simulated actions per search (the deterministic bound): NODE_CAP for the turn's first
## segment, NODE_CAP / (1 + n)^2 after n shots this turn, never under NODE_MIN. Later segments
## have few options left (fewer cards, less Move), and this keeps a whole turn within budget
## (measured: a 4-shot turn stays under 75 ms on the dev machine, see balance-log entry 2).
const NODE_CAP: int = 120
const NODE_MIN: int = 30
## Deepest rollout (actions) before a branch is scored where it stands.
const MAX_DEPTH: int = 60
## Marks a plan_step result that asks for a choice: {NEED: field, "options": [...]}.
const NEED: String = "need"

## Evaluation weights (see evaluate()). `weights` on an instance starts as a copy, so a tool
## can try other values on one AI without touching the others.
const WEIGHTS: Dictionary = {
	"health": 100.0, "power": 14.0, "value": 6.0, "threat_in": 38.0, "threat_out": 16.0,
	"gas": 60.0, "closing": 30.0, "hand": 3.0, "cards": 3.0, "bounty": 8.0, "next_drop": 6.0,
	"all_guns": 0.6,
}
const WIN: float = 100000.0

var weights: Dictionary = WEIGHTS.duplicate()
## This instance's NODE_CAP (a tool may try another bound).
var cap_base: int = NODE_CAP

var _me: int = 0
var _nodes: int = 0
var _leaves: int = 0
var _cap: int = NODE_CAP
var _deadline_us: int = 0
var _best_score: float = -INF
var _best_first: Dictionary = {}
var _best_plan: Dictionary = {}
# Memo of the pure function anchor -> best plan (see CzAI: segment anchor).
var _plan_key: int = 0
var _plan: Dictionary = {}


func _init(seed_in: int = 0) -> void:
	super(seed_in)
	level = CzAI.VETERAN


func _decide(w: MatchState, me: int) -> Dictionary:
	_me = me
	_nodes = 0
	_leaves = 0
	_deadline_us = Time.get_ticks_usec() + 1000 * w.data.balance.ai_think_budget_ms
	if w.phase == MatchState.PHASE_DROP:
		return CzAI.drop_action(w, me, true)
	if w.pending_brace_seat() == me:
		return _choose_brace(w, me)
	# Inside a segment: follow the plan made at its anchor.
	var plan: Dictionary = {}
	var key: int = anchor_key()
	if key != 0:
		if key != _plan_key:
			var aw: MatchState = anchor_world()
			_search_from(aw, me, {})
			_plan_key = key
			_plan = _best_plan
		plan = _plan
	var r: Dictionary = plan_step(w, me, plan)
	if not r.has(NEED):
		return r
	# A choice is due here: search from this state (keeping the plan's choices so far).
	_search_from(w, me, plan)
	if key == 0:
		# A segment start: this search is the anchor's plan for the calls that follow.
		_plan_key = segment_key()
		_plan = _best_plan
	if _best_first.is_empty():
		return CzAI.end_turn_action(w, me, [], true)
	return _best_first


## Runs the search from `w` with the choices in `seed_plan` fixed; leaves the result in
## _best_first (the first action) and _best_plan (the winning leaf's choices).
func _search_from(w: MatchState, me: int, seed_plan: Dictionary) -> void:
	_me = me
	last_stats["searched"] = true
	_cap = node_cap(w, me, cap_base)
	_best_score = -INF
	_best_first = {}
	_best_plan = {}
	_search(CzSim.clone(w, true), seed_plan, {}, 0)
	last_stats["nodes"] = _nodes
	last_stats["plans"] = _leaves


# === Search =================================================================================

## The node cap for a decision in this state (see NODE_CAP).
static func node_cap(w: MatchState, me: int, base: int = NODE_CAP) -> int:
	var shots: int = 0
	for v: Variant in w.seats[me].fired.values():
		shots += int(v)
	return maxi(NODE_MIN, base / ((1 + shots) * (1 + shots)))


## Plays plan `th` forward from `node` (which this call changes), branching at every choice the
## executor asks for, and keeps the best leaf's first action.
func _search(node: MatchState, th: Dictionary, first: Dictionary, depth: int) -> void:
	var plan: Dictionary = th
	var d: int = depth
	var head: Dictionary = first
	while true:
		var r: Dictionary = plan_step(node, _me, plan)
		if r.has(NEED):
			var opts: Array = r["options"]
			var field: String = r[NEED]
			if opts.size() == 1 or _nodes >= _cap or Time.get_ticks_usec() > _deadline_us:
				plan = plan.duplicate()
				plan[field] = opts[0]
				continue
			for k: int in opts.size():
				var child: MatchState = node if k == opts.size() - 1 else CzSim.clone(node, true)
				var th2: Dictionary = plan.duplicate()
				th2[field] = opts[k]
				_search(child, th2, head, d)
			return
		if r.is_empty() or d >= MAX_DEPTH or not CzSim.step_normalized(node, r):
			_leaf(node, head, plan)
			return
		_nodes += 1
		d += 1
		if head.is_empty():
			head = r
		if node.is_over() or String(r["type"]) == "end_turn":
			_leaf(node, head, plan)
			return


func _leaf(node: MatchState, head: Dictionary, plan: Dictionary) -> void:
	_leaves += 1
	var score: float = evaluate(node, _me, weights)
	if score > _best_score and not head.is_empty():
		_best_score = score
		_best_first = head
		_best_plan = plan


func _choose_brace(w: MatchState, me: int) -> Dictionary:
	var options: Array[Dictionary] = LoadoutRules.legal_actions(w)
	var best: Dictionary = {"type": "brace", "seat": me, "cards": []}
	var best_score: float = -INF
	for a: Dictionary in options:
		var c: MatchState = CzSim.clone(w)
		if not CzSim.step(c, a):
			continue
		_nodes += 1
		var score: float = evaluate(c, me, weights)
		if score > best_score:
			best_score = score
			best = a
	last_stats["nodes"] = _nodes
	return best


# === The executor ===========================================================================

static func _need(field: String, options: Array) -> Dictionary:
	return {NEED: field, "options": options}


## The next action of plan `th` for `me` (or the pending Brace of either seat), or
## {NEED: field, options} when it reaches a choice `th` hasn't made.
static func plan_step(w: MatchState, me: int, th: Dictionary) -> Dictionary:
	var pb: int = w.pending_brace_seat()
	if pb != MatchState.NO_SEAT:
		return CzAI.greedy_brace(w, pb)
	if w.is_over() or w.active != me:
		return {}
	var st: SeatState = w.seats[me]
	# 1. Attach.
	var att: Dictionary = CzAI.attach_action(w, me)
	if not att.is_empty():
		return att
	# 2. Plays: Pull items, other items, weapons, then the Brace cards the plan doesn't keep.
	for inst: int in _plays(w, me):
		var c: CardData = w.def_of(inst)
		if CzSim.is_item(w, inst) and c.brace > 0 and c.pull == 0:
			if not th.has("keep"):
				var keeps: Array = _keep_options(w, me)
				if keeps.size() > 1:
					return _need("keep", keeps)
			elif (th["keep"] as Array).has(inst):
				continue
		return {"type": "play", "seat": me, "card": inst}
	# 3. Route.
	if not th.has("route"):
		var routes: Array = _route_options(w, me)
		if routes.size() > 1:
			return _need("route", routes)
	var route: Dictionary = th.get("route", {"dest": st.area, "origin": st.area})
	var dest: StringName = route["dest"]
	var stuck: bool = false
	if st.area != dest:
		if st.area == route["origin"]:
			var pre: int = 0
			if th.has("pre"):
				pre = int(th["pre"])
			else:
				var pres: Array = [0]
				if _can_shoot(w, me):
					pres.append(1)
				if not _best_loot(w, me, dest).is_empty():
					pres.append(2)
				if pres.size() > 1:
					return _need("pre", pres)
			if pre >= 1:
				var s1: Dictionary = _shot_step(w, me, th)
				if not s1.is_empty():
					return s1
			if pre >= 2:
				var l1: Dictionary = _loot_step(w, me, th, dest)
				if not l1.is_empty():
					return l1
		if st.move >= 1:
			return {"type": "move", "seat": me, "to": String(CzSim.step_toward(w.data, st.area, dest))}
		var hit: int = CzAI.first_hit(w, me)
		if hit != 0:
			var adr: Dictionary = CzAI.adrenaline_action(w, me, hit, "move")
			if not adr.is_empty() and adr["adrenaline"] == "move":
				return adr
		stuck = true
	if st.area == dest or stuck:
		var s2: Dictionary = _shot_step(w, me, th)
		if not s2.is_empty():
			return s2
		var l2: Dictionary = _loot_step(w, me, th, st.area)
		if not l2.is_empty():
			return l2
	# 4. Hits for Search, Patch up.
	var left: int = CzAI.first_hit(w, me)
	if left != 0:
		var adr2: Dictionary = CzAI.adrenaline_action(w, me, left, "search")
		if not adr2.is_empty():
			return adr2
	if CzAI.can_patch_up(w, me):
		return {"type": "patch_up", "seat": me}
	# 5. Pack: hold the kept cards (highest Brace first), then Frags and Heal items.
	var prefer: Array[int] = []
	for x: Variant in th.get("keep", []):
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


## Hand cards to play before acting, in order: Pull items, other useful items (a Heal-only or
## Spent Heal card waits for a Hit to heal), weapons, then Brace items (the plan may keep these).
static func _plays(w: MatchState, me: int) -> Array[int]:
	var st: SeatState = w.seats[me]
	var cards: Dictionary = w.data.cards
	var hit_id: StringName = w.data.hit_id
	var heal_now: bool = false
	for inst: int in st.hand:
		if w.defs.get(inst, &"") == hit_id:
			heal_now = true
	for inst: int in st.line:
		if w.defs.get(inst, &"") == hit_id:
			heal_now = true
	var buckets: Array = [[], [], [], []]
	for inst: int in st.hand:
		var c: CardData = cards.get(w.defs.get(inst, &""))
		if c == null:
			continue
		if c.type == DataEnums.CardType.WEAPON:
			buckets[2].append(inst)
			continue
		if c.type != DataEnums.CardType.ITEM or c.blast_dmg > 0:
			continue
		if c.heal > 0 and not heal_now and (c.move + c.search + c.pull == 0 or c.spent == DataEnums.SpentMode.ON_PLAY):
			continue
		if c.move + c.search + c.pull + c.heal == 0:
			continue
		buckets[0 if c.pull > 0 else (3 if c.brace > 0 else 1)].append(inst)
	var out: Array[int] = []
	for bucket: Array in buckets:
		for inst: Variant in bucket:
			out.append(int(inst))
	return out


## [[]] plus every distinct (by card id) set of Brace items in hand up to hold_limit.
static func _keep_options(w: MatchState, me: int) -> Array:
	var b: BalanceConfig = w.data.balance
	var out: Array = [[]]
	if b.packing_rule == DataEnums.PackingRule.RACK_SWAP:
		return out
	var cards: Array[int] = []
	for inst: int in w.seats[me].hand:
		if CzSim.is_item(w, inst) and w.def_of(inst).brace > 0 and w.def_of(inst).pull == 0:
			cards.append(inst)
	var keys: Array[String] = [""]
	for subset: Array in LoadoutRules.subsets(cards, b.hold_limit):
		if subset.is_empty():
			continue
		var names: Array[String] = []
		for x: Variant in subset:
			names.append(String(w.card_id(int(x))))
		names.sort()
		var key: String = ",".join(names)
		if not keys.has(key):
			keys.append(key)
			out.append(subset)
	return out


## Stay, then every non-gas area within this turn's Move (pool + Hits in hand).
static func _route_options(w: MatchState, me: int) -> Array:
	var st: SeatState = w.seats[me]
	var here: StringName = st.area
	var reach: int = st.move + w.hits_in(st.hand)
	var out: Array = [{"dest": here, "origin": here}]
	for a: StringName in w.data.area_order:
		if a != here and not w.gas.has(a) and w.data.distance(here, a) <= reach:
			out.append({"dest": a, "origin": here})
	return out


static func _can_shoot(w: MatchState, me: int) -> bool:
	return not _best_shot(w, me).is_empty() or not _frag_action(w, me).is_empty()


## The best gun shot; else a Frag when the plan chose (or now chooses) to throw it.
static func _shot_step(w: MatchState, me: int, th: Dictionary) -> Dictionary:
	var s: Dictionary = _best_shot(w, me)
	if not s.is_empty():
		return s
	var f: Dictionary = _frag_action(w, me)
	if f.is_empty():
		return {}
	if not th.has("frag"):
		return _need("frag", [false, true])
	return f if th["frag"] else {}


## The best loot here, or the choice to keep the Search for Patch up when that is possible.
static func _loot_step(w: MatchState, me: int, th: Dictionary, dest: StringName) -> Dictionary:
	var l: Dictionary = _best_loot(w, me, dest)
	if l.is_empty():
		return {}
	if th.has("loot"):
		return l if th["loot"] else {}
	if CzSim.healable_hits(w, me) > 0 or w.hits_in(w.seats[me].hand) > 0:
		return _need("loot", [true, false])
	return l


## The strongest legal gun shot with damage > 0, or {}. Damage as LoadoutRules.shot_profile
## computes it (DMG + attachments - Cover - Down), with Cover and Down worked out once.
static func _best_shot(w: MatchState, me: int) -> Dictionary:
	var st: SeatState = w.seats[me]
	var opp: int = w.opponent_of(me)
	var best: Dictionary = {}
	var best_dmg: int = 0
	if w.seats[opp].eliminated or not LoadoutRules.shooting_open(w):
		return best
	var dist: int = -1
	var down: int = -1
	for inst: int in st.line:
		var c: CardData = w.def_of(inst)
		if not c.is_weapon():
			continue
		if dist < 0:
			dist = w.data.distance(st.area, w.seats[opp].area)
		# R12, R21 (as the engine's shoot check): a shot left and the target in range.
		if int(st.fired.get(inst, 0)) >= LoadoutRules.fire_limit(w, inst) or dist > LoadoutRules.weapon_range(w, inst):
			continue
		if down < 0:
			down = w.data.balance.down_value if w.is_down(opp) else 0
		var dmg: int = CzSim.weapon_dmg(w, inst)
		var cover: int = LoadoutRules.cover_for(w, st.area, opp, c.ignores_cover)
		dmg = maxi(0, dmg - cover - down)
		if dmg > best_dmg:
			best_dmg = dmg
			best = {"type": "shoot", "seat": me, "weapon": inst, "target": opp}
	return best


## A Frag at the opponent's area (never their area when it is mine) that deals damage, or {}.
static func _frag_action(w: MatchState, me: int) -> Dictionary:
	var st: SeatState = w.seats[me]
	var opp: int = w.opponent_of(me)
	var opp_area: StringName = w.seats[opp].area
	if opp_area == st.area or w.seats[opp].eliminated:
		return {}
	for inst: int in st.hand:
		if not CzSim.is_frag(w, inst):
			continue
		var f: Dictionary = {"type": "frag", "seat": me, "card": inst, "area": String(opp_area)}
		if LoadoutRules.is_legal(w, f) and int(LoadoutRules.blast_profile(w, me, inst, opp_area, opp)["damage"]) > 0:
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
	var facts: Dictionary = {}
	for opt: Dictionary in CzSim.loot_options(w, me, st.area, st.search + spare):
		var cost: int = int(opt["cost"])
		var oc: CardData = w.data.card(opt["id"])
		if facts.is_empty() and oc != null and (oc.is_weapon() or oc.is_attachment()):
			facts = CzAI.owned_facts(w, me)
		var v: int = CzAI.want_in(w, opt["id"], facts)
		if v <= 0:
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


# === Evaluation =============================================================================

## Position value for `me` (higher is better). Terminal: +/- WIN. Otherwise: health difference;
## gun power and loot value (all cards); the damage the opponent can likely deal on its next turn
## (after my next hand's Brace and Down) and what I can deal on mine; gas and the area closing
## next round; Move+Search in my next hand; card count (the tiebreak); the Bounty; the next drop.
static func evaluate(w: MatchState, me: int, wt: Dictionary = WEIGHTS) -> float:
	if w.is_over():
		var r: Dictionary = w.match_end
		if String(r.get("result", "")) == "win":
			return WIN - float(w.round_number) if int(r["winner"]) == me else -WIN + float(w.round_number)
		return 0.0
	var opp: int = w.opponent_of(me)
	var a: Dictionary = _seat_facts(w, me)
	var o: Dictionary = _seat_facts(w, opp)
	var s: float = float(wt["health"]) * float(w.health_of(me) - w.health_of(opp))
	s += float(wt["power"]) * float(int(a["power"]) - int(o["power"]))
	s += float(wt["value"]) * float(int(a["value"]) - int(o["value"]))
	var data: RulesData = w.data
	var my_area: StringName = w.seats[me].area
	var opp_area: StringName = w.seats[opp].area
	var threat_in: float = maxf(_threat(data, o["now"], opp_area, my_area, 1, a),
			float(wt["all_guns"]) * _threat(data, o["guns"], opp_area, my_area, 1, a))
	var threat_out: float = maxf(_threat(data, a["next"], my_area, opp_area, mini(int(a["next_move"]), 2), o),
			float(wt["all_guns"]) * _threat(data, a["guns"], my_area, opp_area, 1, o))
	s -= float(wt["threat_in"]) * threat_in
	s += float(wt["threat_out"]) * threat_out
	var closing: StringName = CzSim.closing_next(w)
	if w.gas.has(my_area):
		s -= float(wt["gas"])
	elif my_area == closing:
		s -= float(wt["closing"])
	if w.gas.has(opp_area):
		s += float(wt["gas"])
	elif opp_area == closing:
		s += float(wt["closing"])
	s += float(wt["hand"]) * float(a["next_gain"])
	s += float(wt["cards"]) * float(int(a["cards"]) - int(o["cards"]))
	if w.bounty == me:
		s -= float(wt["bounty"])
	elif w.bounty == opp:
		s += float(wt["bounty"])
	var z: ZoneCardData = data.zone_card(w.zone_card + 1)
	if z != null and z.drop_card != null and z.drop_area_for(w.route) != null:
		var drop_area: StringName = z.drop_area_for(w.route).id
		if data.distance(my_area, drop_area) <= 1:
			s += float(wt["next_drop"])
		if data.distance(opp_area, drop_area) <= 1:
			s -= float(wt["next_drop"])
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
