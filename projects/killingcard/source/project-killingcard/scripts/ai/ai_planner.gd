# ai_planner.gd
# Purpose: Chooses the enemy's whole Deploy for a round (core-rules §7) from an AiView
#   only. It never receives MatchState, so it cannot see the player's hand, deck or
#   face-down plays (fairness by construction; tests/test_ai_player.gd checks the source).
#
#   Scoring (per personality, AiPersonality weights):
#     value = w_dealt * (damage dealt + 2/kill + 3/Operator kill)
#           - w_taken * (damage taken + 2/loss + 3/own Operator lost)
#           + w_zone  * zone-control swing   (Zone Control; Firefight: elimination swing)
#           + w_deny  * deny-the-player's-streak (down their Operator, don't feed kills)
#           + personality habits (preferred zones, pushing, Operator home, keep costs)
#   The board after a plan is scored with a small deterministic firefight estimator
#   (_eval_zone: Attack Helo, Suppress, beats front to back with the First Shot exchange,
#   Pick / Flank / Cover / Pierce, On Down damage, Patch, control with Holder; kc-fight-impl)
#   that mirrors FirefightResolver on the
#   public board. The player's response is unknown, so it is not predicted.
#   Search: the Operator placement is forced first (free and always useful), then
#   greedy: add the candidate (card x zone, Rotation, Secondary / Lethal / Tactical,
#   killstreak) with the best gain until nothing gains. A second plan starts from the
#   second-best first step; with `second_best_chance` (seeded) that one is played.
#   Each zone's score is cached and only zones an action touches are re-simulated.
#   Fields (kc-field-impl): the estimator applies Field auras by position (frontline auras go
#   to whoever is in front at each step, class auras to that class), then the END_OF_ROUND
#   Field effects (Mortar Pit damage, Aid Station heal). A Field's later rounds are valued in
#   _field_future (rounds left x the chance it survives Overrun); a plan that loses a column
#   pays for the Field it would lose there, replacing a standing Field pays for the old one,
#   and overrunning an enemy Field is worth its future value to the AI.
#   Synergy (kc-syn, synergy-system.md §8): records carry the neighbor keyword / trait / level of
#   each unit. With synergy_aware (default) every unit / Operator / Field / move candidate
#   re-computes the links and set bonuses of all three columns (side links cross columns) with
#   SynergyRules, swaps them into the records and adds their value for the rounds left
#   (future_weight per point x the share of rounds left, like a Field's future value). Blind
#   planners only see the bonuses already on the board. Placing the Operator costs
#   AiView.operator_cost Supply.
#   Deterministic: the only randomness is an RNG seeded from (match seed, round, side).
# Dependencies: AiView, AiPersonality, DataEnums, CardData, EffectData, LoadoutItem, RulesIntent.
# Author: Mechanics Developer Agent
class_name AiPlanner
extends RefCounted

const ME: int = AiView.ME
const FOE: int = AiView.FOE
const KILL_VALUE: float = 2.0
const OP_KILL_VALUE: float = 3.0
## Smallest gain worth adding another play for.
const MIN_GAIN: float = 0.05
## Safety cap on plays per round.
const MAX_STEPS: int = 14
## Value of one card drawn (if the hand has room).
const DRAW_VALUE: float = 1.1
const K := DataEnums.EffectKind
const T := DataEnums.Target
const Z := DataEnums.ZoneScope
const TR := DataEnums.Trigger

var personality: AiPersonality = null
## kc-syn: plan links and trait sets (false = only see the bonuses already on the board).
var synergy_aware: bool = true
## kc-syn: value per point of link / set bonus for the rounds after this one (x share of rounds left).
var synergy_future_weight: float = 1.5
## Plans scored during the last plan() call (for profiling and tests).
var evaluations: int = 0

var _view: AiView = null
var _pref: Array[int] = []
var _next_fake_uid: int = -1000
## Effect traits per card / item resource (static data, kept across plans).
var _traits: Dictionary = {}


## A partial plan: the projected board plus what the plan has spent. Zone arrays are
## shared between plans until an action touches that zone (copy on write).
class Plan:
	var lines: Array = [[[], [], []], [[], [], []]]
	var supply: int = 0
	var used_cards: Dictionary = {}
	var used_items: Dictionary = {}
	var op_zone: int = -1
	var op_placed: bool = false
	var op_locked: bool = false
	var rotations_left: int = 0
	var my_fp_buff: Array[int] = [0, 0, 0]
	var my_cover_buff: Array[int] = [0, 0, 0]
	var callout: Array[int] = [0, 0, 0]
	## Units a Flank Route moves out at Reveal still count for Deploy capacity (MatchState
	## projected_occupancy does not see moves).
	var moved_out: Array[int] = [0, 0, 0]
	var equip_new: Array = [[], [], []]
	## kc-syn: traits of the new Trained visible Fields per zone (they count for my sets).
	var field_traits_new: Array = [[], [], []]
	## kc-syn: synergy value of the plan's board (for the future-value delta).
	var syn_total: float = 0.0
	## A new visible Field in this zone replaces my standing one (one per side per column).
	var field_replaced: Array[bool] = [false, false, false]
	var foe_cover_removed: bool = false
	var my_ff_damage: int = 0
	var flat: float = 0.0
	var draws: int = 0
	var zone_scores: Array[float] = [0.0, 0.0, 0.0]
	## The plan this one extends and the action added (the action list is this chain).
	var parent: Plan = null
	var action: Dictionary = {}

	func clone(zones: Array) -> Plan:
		var p: Plan = Plan.new()
		for si: int in 2:
			for z: int in 3:
				if z in zones:
					var copy: Array = []
					for rec: Dictionary in lines[si][z]:
						copy.append(rec.duplicate())
					p.lines[si][z] = copy
				else:
					p.lines[si][z] = lines[si][z]
		p.supply = supply
		p.used_cards = used_cards.duplicate()
		p.used_items = used_items.duplicate()
		p.op_zone = op_zone
		p.op_placed = op_placed
		p.op_locked = op_locked
		p.rotations_left = rotations_left
		p.my_fp_buff = my_fp_buff.duplicate()
		p.my_cover_buff = my_cover_buff.duplicate()
		p.callout = callout.duplicate()
		p.moved_out = moved_out.duplicate()
		p.equip_new = [equip_new[0].duplicate(), equip_new[1].duplicate(), equip_new[2].duplicate()]
		p.field_traits_new = [field_traits_new[0].duplicate(), field_traits_new[1].duplicate(), field_traits_new[2].duplicate()]
		p.syn_total = syn_total
		p.field_replaced = field_replaced.duplicate()
		p.foe_cover_removed = foe_cover_removed
		p.my_ff_damage = my_ff_damage
		p.flat = flat
		p.draws = draws
		p.zone_scores = zone_scores.duplicate()
		return p

	func score() -> float:
		return zone_scores[0] + zone_scores[1] + zone_scores[2] + flat


func _init(p_personality: AiPersonality = null) -> void:
	personality = p_personality if p_personality != null else AiPersonality.new()


# =============================================================================
# Public API
# =============================================================================

## The round's plan. Returns {intents: Array[Dictionary] (RulesIntent, in submit order),
## score: float, alt_score: float, second_best: bool, replan: bool}. replan = true means
## the intents are just a "Resolves immediately" draw: submit it, re-capture and plan again.
func plan(view: AiView) -> Dictionary:
	_begin(view)
	var root: Plan = _root_plan()
	if _view.op_exists and _view.op_can_deploy and _view.op_zone < 0:
		var best: Plan = null
		for c: Dictionary in _candidates(root):
			if c["kind"] == &"place":
				var child: Plan = _child(root, c)
				if best == null or child.score() > best.score():
					best = child
		if best != null:
			root = best
	# First step over every candidate; its gains seed both greedy runs (lazy greedy).
	var gains: Dictionary = {}
	var ranked: Array = []
	for c: Dictionary in _candidates(root):
		var g: float = _gain(root, c, gains)
		ranked.append([g, c])
	ranked.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	# The seeded roll comes first, so the alternative plan is only searched when it is played.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([_view.seed_value, _view.round_number, _view.side, 7307])
	var want_second: bool = rng.randf() < personality.second_best_chance
	var a: Plan = root
	if not ranked.is_empty() and float(ranked[0][0]) > MIN_GAIN:
		a = _greedy(_child(root, ranked[0][1]), gains.duplicate(), ranked[0][1]["zones"])
	var chosen: Plan = a
	var second: bool = false
	var alt_score: float = -INF
	if want_second and ranked.size() > 1 and float(ranked[1][0]) > MIN_GAIN:
		var b: Plan = _greedy(_child(root, ranked[1][1]), gains.duplicate(), ranked[1][1]["zones"])
		alt_score = b.score()
		second = true
		if b.score() <= a.score():
			chosen = b  # the second-best plan; if b is better after all, a is the second best
	return _to_result(chosen, a.score(), alt_score, second)


## Round 1 mulligan (Ruling 3): card uids to put back. Expensive cards that can't be
## played in the first rounds go back; with no cheap unit at all, cheap non-units go too.
func plan_mulligan(view: AiView) -> Array[int]:
	var back: Array[int] = []
	if view.mulligans_left <= 0:
		return back
	var max_keep_cost: int = 3 if personality.kind == DataEnums.Personality.RUSHER else 4
	var cheap_units: int = 0
	for h: Dictionary in view.hand:
		var card: CardData = h["card"]
		if card.card_type == DataEnums.CardType.UNIT and card.cost <= 3:
			cheap_units += 1
	var kept_expensive: bool = false
	for h: Dictionary in view.hand:
		var card: CardData = h["card"]
		if card.cost > max_keep_cost:
			back.append(int(h["uid"]))
		elif card.cost == max_keep_cost and kept_expensive:
			back.append(int(h["uid"]))
		elif card.cost == max_keep_cost:
			kept_expensive = true
		elif cheap_units == 0 and card.card_type != DataEnums.CardType.UNIT:
			back.append(int(h["uid"]))
	return back


# =============================================================================
# Search
# =============================================================================

func _begin(view: AiView) -> void:
	_view = view
	_pref = personality.preferred_zones(view.zone_ranges)
	evaluations = 0
	_next_fake_uid = -1000


func _root_plan() -> Plan:
	var p: Plan = Plan.new()
	for si: int in 2:
		for z: int in 3:
			p.lines[si][z] = _view.lines[si][z]
	p.supply = _view.supply
	p.op_zone = _view.op_zone
	p.rotations_left = _view.op_rotations_left
	for z: int in 3:
		p.zone_scores[z] = _eval_zone(p, z)
	if synergy_aware:
		p.syn_total = _synergy_total(p)
	return p


## Greedy: keep adding the candidate with the best gain. Gains are zone-local, so a
## cached gain stays valid unless the last chosen play touched one of its zones
## (`dirty`); only those candidates are simulated again.
func _greedy(start: Plan, gains: Dictionary, dirty: Array) -> Plan:
	var p: Plan = start
	for i: int in MAX_STEPS:
		var best_c: Dictionary = {}
		var best_gain: float = -INF
		for c: Dictionary in _candidates(p):
			var key: String = _key(c)
			var g: float = 0.0
			if gains.has(key) and not _overlaps(c["zones"], dirty):
				g = gains[key]
			else:
				g = _gain(p, c, gains)
			if g > best_gain:
				best_gain = g
				best_c = c
		if best_c.is_empty() or best_gain <= MIN_GAIN:
			break
		p = _child(p, best_c)
		dirty = best_c["zones"]
	return p


## Score gain of adding candidate c to p (cached under the candidate's key).
func _gain(p: Plan, c: Dictionary, gains: Dictionary) -> float:
	var g: float = _child(p, c).score() - p.score()
	gains[_key(c)] = g
	return g


## Identity of a candidate for the gain cache: copies of one card design share it.
func _key(c: Dictionary) -> String:
	var src: String = ""
	if c["card"] != null:
		src = "%s@%d@%s" % [(c["card"] as CardData).id, int(c.get("level", 1)), c.get("trait", SynergyRules.TRAIT_DEFAULT)]
	elif c["item"] != null:
		src = (c["item"] as LoadoutItem).id
	return "%s|%s|%d|%d|%d" % [c["kind"], src, c["zone"], c["target_uid"], c["dest_zone"]]


func _overlaps(zones: Array, dirty: Array) -> bool:
	for z: int in zones:
		if z in dirty:
			return true
	return false


func _child(p: Plan, action: Dictionary) -> Plan:
	var touched: Array = action["zones"]
	var c: Plan = p.clone(touched)
	_apply(c, action)
	for z: int in touched:
		c.zone_scores[z] = _eval_zone(c, z)
	c.parent = p
	c.action = action
	evaluations += 1
	return c


# =============================================================================
# Candidates
# =============================================================================

func _candidates(p: Plan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cap: int = _view.zone_capacity
	# Operator placement (off board, may deploy) / Rotation.
	if _view.op_exists:
		if _view.op_can_deploy and _view.op_zone < 0 and not p.op_placed:
			for z: int in (3 if p.supply >= _view.operator_cost else 0):
				if _occupancy(p, z) < cap:
					out.append(_action(&"place", z, _syn_zones([z])))
		elif _view.op_zone >= 0 and p.op_zone >= 0 and p.rotations_left > 0 and not p.op_locked:
			for z: int in [p.op_zone - 1, p.op_zone + 1]:
				if z >= 0 and z < 3 and _occupancy(p, z) < cap:
					out.append(_action(&"rotate", z, _syn_zones([p.op_zone, z])))
	# Deck cards (one candidate set per distinct card design).
	var seen: Dictionary = {}
	for h: Dictionary in _view.hand:
		var uid: int = h["uid"]
		var card: CardData = h["card"]
		var level: int = int(h.get("level", SynergyRules.LEVEL_TRAINED))
		var chosen: StringName = h.get("trait", SynergyRules.TRAIT_DEFAULT)
		# A Recruit and a Trained copy plan differently, and so do two copies with different traits
		# (kc-art-traits: the trait comes from the copy's art).
		var design: String = "%s@%d@%s" % [card.id, level, SynergyRules.trait_at(card, level, chosen)]
		if p.used_cards.has(uid) or card.cost > p.supply or seen.has(design):
			continue
		seen[design] = true
		match card.card_type:
			DataEnums.CardType.UNIT:
				for z: int in 3:
					if _occupancy(p, z) < cap:
						var a: Dictionary = _action(&"unit", z, _syn_zones([z]))
						a["card"] = card
						a["uid"] = uid
						a["level"] = level
						a["trait"] = chosen
						out.append(a)
			DataEnums.CardType.EQUIPMENT:  # Fields
				for z: int in 3:
					if card.is_visible_field() and not _field_slot_open(p, card, z):
						continue
					var a: Dictionary = _action(&"equipment", z, _syn_zones([z]) if SynergyRules.trait_at(card, level) != &"" else [z])
					a["card"] = card
					a["uid"] = uid
					a["level"] = level
					out.append(a)
			DataEnums.CardType.TACTIC:
				for a: Dictionary in _effect_candidates(p, card, card.effects):
					a["card"] = card
					a["uid"] = uid
					a["level"] = level
					out.append(a)
	# Loadout items and earned killstreaks.
	for entry: Dictionary in _view.items:
		var item: LoadoutItem = entry["item"]
		if not entry["ready"] or p.used_items.has(item.id) or item.supply_cost > p.supply:
			continue
		for a: Dictionary in _effect_candidates(p, item, item.effects):
			a["item"] = item
			out.append(a)
	return out


## Choices (zone / target) for a tactic or item, filtered to ones that can matter.
func _effect_candidates(p: Plan, owner: Resource, effects: Array[EffectData]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tr: Dictionary = _traits_of(owner, effects)
	var needs_zone: bool = tr["needs_zone"]
	var op_bound: bool = tr["op_bound"]
	var op_zone_only: bool = tr["op_zone_only"]
	var chosen_enemy: bool = tr["chosen_enemy"]
	var move: bool = tr["move"]
	var global: bool = tr["global"]
	var hits_enemies: bool = tr["hits_enemies"]
	var summons: bool = tr["summons"]
	if op_bound and p.op_zone < 0:
		return out
	if move:
		for z: int in 3:
			for rec: Dictionary in p.lines[ME][z]:
				# A unit moves at most once per Deploy: the engine checks a move against the
				# unit's board zone, so a second Flank Route on it would be refused (p18 bug 001).
				if rec["new"] or rec["is_op"] or int(rec["armor"]) <= 0 or rec.get("moved", false):
					continue
				for dest: int in [z - 1, z + 1]:
					if dest >= 0 and dest < 3 and _occupancy(p, dest) < _view.zone_capacity:
						var a: Dictionary = _action(&"tactic", z, _syn_zones([z, dest]))
						a["target_uid"] = rec["uid"]
						a["dest_zone"] = dest
						a["op_bound"] = false
						out.append(a)
		return out
	if chosen_enemy:
		var zones: Array[int] = [0, 1, 2]
		if op_zone_only:
			zones = [p.op_zone]
		for z: int in zones:
			for rec: Dictionary in p.lines[FOE][z]:
				if int(rec["armor"]) > 0:
					var a: Dictionary = _action(&"item", z, [z])
					a["target_uid"] = rec["uid"]
					a["op_bound"] = op_bound
					out.append(a)
		return out
	if needs_zone:
		for z: int in 3:
			if op_bound and absi(z - p.op_zone) > 1:
				continue
			if hits_enemies and _alive_count(p, FOE, z) == 0:
				continue
			if summons and _occupancy(p, z) >= _view.zone_capacity:
				continue
			var a: Dictionary = _action(&"tactic", z, [0, 1, 2] if global else [z])
			a["op_bound"] = op_bound
			out.append(a)
		return out
	if op_zone_only:
		var a: Dictionary = _action(&"tactic", p.op_zone, [p.op_zone])
		a["op_bound"] = true
		out.append(a)
		return out
	var single: Dictionary = _action(&"tactic", -1, [0, 1, 2] if global else [])
	single["op_bound"] = false
	out.append(single)
	return out


## What a card's / item's effects need (zone, Operator, target...); cached per resource.
func _traits_of(owner: Resource, effects: Array[EffectData]) -> Dictionary:
	var key: int = owner.get_instance_id()
	if _traits.has(key):
		return _traits[key]
	var tr: Dictionary = {"needs_zone": false, "op_bound": false, "op_zone_only": false, "chosen_enemy": false,
			"move": false, "global": false, "hits_enemies": false, "summons": false}
	for e: EffectData in effects:
		if e == null:
			continue
		match e.zone_scope:
			Z.CHOSEN_ZONE:
				tr["needs_zone"] = true
			Z.OPERATOR_OR_ADJACENT:
				tr["needs_zone"] = true
				tr["op_bound"] = true
			Z.OPERATOR_ZONE:
				tr["op_zone_only"] = true
				tr["op_bound"] = true
			Z.ALL_ZONES:
				tr["global"] = true
		if e.trigger == TR.START_OF_FIREFIGHT:
			tr["global"] = true
		if e.target == T.CHOSEN_ENEMY:
			tr["chosen_enemy"] = true
		if e.kind == K.MOVE_UNIT:
			tr["move"] = true
		if e.kind == K.SUMMON_UNIT:
			tr["summons"] = true
		if e.target in [T.ALL_ENEMIES, T.ENEMY_POINT_MAN, T.ENEMY_SECOND_IN_LINE, T.CHOSEN_ENEMY]:
			tr["hits_enemies"] = true
	_traits[key] = tr
	return tr


func _action(kind: StringName, zone: int, zones: Array) -> Dictionary:
	return {"kind": kind, "zone": zone, "zones": zones, "card": null, "item": null,
			"uid": -1, "target_uid": -1, "dest_zone": -1, "op_bound": false}


## Units counted against zone capacity at Deploy (as MatchState.projected_occupancy).
func _occupancy(p: Plan, z: int) -> int:
	return (p.lines[ME][z] as Array).size() + p.moved_out[z]


func _alive_count(p: Plan, who: int, z: int) -> int:
	var n: int = 0
	for rec: Dictionary in p.lines[who][z]:
		if int(rec["armor"]) > 0:
			n += 1
	return n


# =============================================================================
# Applying actions to a plan
# =============================================================================

func _apply(p: Plan, a: Dictionary) -> void:
	var z: int = a["zone"]
	match a["kind"]:
		&"place":
			var rec: Dictionary = _view.op_by_zone[z].duplicate()
			rec["new"] = true
			p.lines[ME][z].append(rec)
			p.op_zone = z
			p.op_placed = true
			p.supply -= _view.operator_cost
		&"rotate":
			var from: int = p.op_zone
			var line: Array = p.lines[ME][from]
			var old: Dictionary = {}
			for i: int in line.size():
				if line[i]["is_op"]:
					old = line[i]
					line.remove_at(i)
					break
			var rec: Dictionary = _view.op_by_zone[z].duplicate()
			if not old.is_empty():
				rec["armor"] = old["armor"]
				rec["armor0"] = old["armor0"]
			p.lines[ME][z].append(rec)
			p.op_zone = z
			p.rotations_left -= 1
		&"unit":
			var card: CardData = a["card"]
			var rec: Dictionary = _view.record_for_card(card, a["uid"], z, int(a.get("level", SynergyRules.LEVEL_TRAINED)),
					a.get("trait", SynergyRules.TRAIT_DEFAULT))
			if bool(rec["arrives_front"]):
				p.lines[ME][z].insert(0, rec)
			else:
				p.lines[ME][z].append(rec)
			_spend_card(p, a, card.cost)
		&"equipment":
			var card: CardData = a["card"]
			p.equip_new[z].append(card)
			if card.is_visible_field() and _view.my_visible_field(z) != null:
				p.field_replaced[z] = true
			if card.is_visible_field():
				var ft: StringName = SynergyRules.trait_at(card, int(a.get("level", SynergyRules.LEVEL_TRAINED)))
				if ft != &"":
					p.field_traits_new[z].append(ft)
			_apply_effects(p, card.effects, z, -1, -1)
			_spend_card(p, a, card.cost)
		_:
			if a["card"] != null:
				var card: CardData = a["card"]
				_apply_effects(p, card.effects, z, a["target_uid"], a["dest_zone"])
				_spend_card(p, a, card.cost)
			else:
				var item: LoadoutItem = a["item"]
				_apply_effects(p, item.effects, z, a["target_uid"], a["dest_zone"])
				p.supply -= item.supply_cost
				p.used_items[item.id] = true
				if item.slot == DataEnums.LoadoutSlot.KILLSTREAK:
					var left: float = clampf(float(_view.round_cap - _view.round_number) / maxf(1.0, _view.round_cap), 0.0, 1.0)
					p.flat -= personality.killstreak_keep_cost * left
				elif item.cooldown_rounds > 0:
					p.flat -= personality.cooldown_keep_cost
			if a["op_bound"]:
				p.op_locked = true
	if synergy_aware and (a["zones"] as Array).size() == 3 and a["kind"] in [&"place", &"rotate", &"unit", &"equipment", &"tactic"]:
		_resync(p)


## kc-syn: zones an action touches when links are planned (side links cross columns: all three).
func _syn_zones(zones: Array) -> Array:
	return [0, 1, 2] if synergy_aware else zones


## kc-syn: my projected board as SynergyRules slots + the traits of my visible Fields after the plan.
func _synergy_of_plan(p: Plan) -> Dictionary:
	var lines: Array = [[], [], []]
	for z: int in 3:
		for rec: Dictionary in p.lines[ME][z]:
			lines[z].append(SynergyRules.slot(int(rec["uid"]), rec.get("kw", &""), rec.get("trait", &"")))
	var fields: Array = []
	for z: int in 3:
		if not p.field_replaced[z]:
			fields.append_array(_view.my_field_traits[z])
		fields.append_array(p.field_traits_new[z])
	return SynergyRules.compute(lines, fields, _view.my_doctrine)


func _synergy_total(p: Plan) -> float:
	return SynergyRules.total_value(_synergy_of_plan(p))


## kc-syn: puts the links / set bonuses of the plan's board into my records (replacing the part
## each record carried) and adds the value of the change for the rounds after this one.
func _resync(p: Plan) -> void:
	var res: Dictionary = _synergy_of_plan(p)
	var total: float = SynergyRules.total_value(res)
	var left: float = clampf(float(_view.round_cap - _view.round_number) / maxf(1.0, _view.round_cap), 0.0, 1.0)
	p.flat += synergy_future_weight * left * (total - p.syn_total)
	p.syn_total = total
	for z: int in 3:
		var line: Array = p.lines[ME][z]
		for i: int in line.size():
			var rec: Dictionary = line[i]
			var syn: Dictionary = res["zones"][z][i]
			var fp_new: int = int(syn["fp"])
			var cov_new: int = 0 if _view.my_cover_removed else int(syn["cover"])
			var fs_new: bool = bool(syn["fs"])
			if fp_new == int(rec.get("syn_fp", 0)) and cov_new == int(rec.get("syn_cover", 0)) and fs_new == bool(rec.get("syn_fs", false)):
				continue
			rec["fp"] = maxi(0, int(rec["fp"]) + fp_new - int(rec.get("syn_fp", 0)))
			rec["cover"] = maxi(0, int(rec["cover"]) + cov_new - int(rec.get("syn_cover", 0)))
			rec["first_shot"] = bool(rec.get("fs_native", rec["first_shot"])) or fs_new
			rec["syn_fp"] = fp_new
			rec["syn_cover"] = cov_new
			rec["syn_fs"] = fs_new


func _spend_card(p: Plan, a: Dictionary, cost: int) -> void:
	p.supply -= cost
	p.used_cards[a["uid"]] = true
	p.flat -= personality.card_keep_cost


## Applies the Deploy / Reveal effects of one play to the projected board. All effects
## of one play read the lines as they were when the play began (Rulings part 2 #7).
func _apply_effects(p: Plan, effects: Array[EffectData], zone: int, target_uid: int, dest_zone: int) -> void:
	var snap: Array = [null, null, null]
	for e: EffectData in effects:
		if e == null:
			continue
		if e.trigger == TR.START_OF_FIREFIGHT:
			if e.kind == K.DAMAGE:
				p.my_ff_damage += e.amount
				if e.duration_rounds > 1:  # next round's firefight too
					p.flat += personality.weight_damage_dealt * e.amount * _zones_with_foes(p) * 0.6
			continue
		if e.trigger not in [TR.ON_PLAY, TR.IMMEDIATE]:
			continue
		var zones: Array[int] = []
		match e.zone_scope:
			Z.CHOSEN_ZONE, Z.OPERATOR_OR_ADJACENT, Z.THIS_ZONE:
				zones = [zone]
			Z.OPERATOR_ZONE:
				zones = [p.op_zone]
			Z.ALL_ZONES:
				zones = [0, 1, 2]
			_:
				zones = [-1]
		for z: int in zones:
			if e.condition != DataEnums.Condition.ALWAYS and not _condition(e.condition, z):
				continue
			var amount: int = e.amount
			if e.bonus_amount != 0 and _condition(e.bonus_condition, z):
				amount += e.bonus_amount
			if z >= 0 and snap[z] == null:
				var alive: Array = []
				for rec: Dictionary in p.lines[FOE][z]:
					if int(rec["armor"]) > 0:
						alive.append(rec)
				snap[z] = alive
			_apply_effect(p, e, z, amount, snap[z] if z >= 0 else [], target_uid, dest_zone)


func _apply_effect(p: Plan, e: EffectData, z: int, amount: int, foes: Array, target_uid: int, dest_zone: int) -> void:
	match e.kind:
		K.DAMAGE:
			for rec: Dictionary in _enemy_targets(p, e, z, foes, target_uid):
				var dmg: int = maxi(0, amount - (0 if p.foe_cover_removed else int(rec["cover"])))
				_hurt(rec, dmg)
		K.MODIFY_FIREPOWER:
			match e.target:
				T.NEXT_FRIENDLY_ARRIVING:
					if z >= 0:
						p.callout[z] += amount
				T.ALL_FRIENDLIES:
					if z >= 0:
						p.my_fp_buff[z] += amount
				T.CHOSEN_FRIENDLY:
					var rec: Dictionary = _find_mine(p, target_uid)
					if not rec.is_empty():
						rec["fp"] = int(rec["fp"]) + amount
				_:
					for rec: Dictionary in _enemy_targets(p, e, z, foes, target_uid):
						rec["fp"] = int(rec["fp"]) + amount
		K.REMOVE_FIRST_SHOT:
			for rec: Dictionary in _enemy_targets(p, e, z, foes, target_uid):
				rec["first_shot"] = false
		K.GRANT_COVER:
			if e.target == T.ALL_FRIENDLIES and z >= 0:
				p.my_cover_buff[z] += amount
			elif e.target == T.CHOSEN_FRIENDLY:
				var rec: Dictionary = _find_mine(p, target_uid)
				if not rec.is_empty():
					rec["cover"] = int(rec["cover"]) + amount
		K.REMOVE_COVER:
			if e.target == T.ALL_ENEMIES:
				if e.zone_scope == Z.ALL_ZONES:
					if not p.foe_cover_removed:
						p.foe_cover_removed = true
						p.flat += 0.3 * personality.weight_damage_dealt  # lasts into next round
				else:
					for rec: Dictionary in foes:
						rec["cover"] = 0
		K.GRANT_FIRST_SHOT:
			if e.target == T.CHOSEN_FRIENDLY:
				var rec: Dictionary = _find_mine(p, target_uid)
				if not rec.is_empty():
					rec["first_shot"] = true
		K.MOVE_UNIT:
			var from: int = z
			for zz: int in 3:
				for rec: Dictionary in p.lines[ME][zz]:
					if int(rec["uid"]) == target_uid:
						from = zz
			if from < 0 or dest_zone < 0:
				return
			var line: Array = p.lines[ME][from]
			for i: int in line.size():
				if int(line[i]["uid"]) == target_uid:
					var rec: Dictionary = line[i]
					line.remove_at(i)
					rec["moved"] = true
					p.moved_out[from] += 1
					var fp_shift: int = int(_view.range_bonus[_class_of(rec)][dest_zone]) - int(_view.range_bonus[_class_of(rec)][from])
					rec["fp"] = maxi(0, int(rec["fp"]) + fp_shift)
					if rec["arrives_front"]:
						p.lines[ME][dest_zone].insert(0, rec)
					else:
						p.lines[ME][dest_zone].append(rec)
					return
		K.DRAW:
			var room: int = maxi(0, _view.hand_cap - (_view.hand.size() - p.used_cards.size()) + 1)
			p.flat += DRAW_VALUE * mini(amount, room)
			p.draws += amount
		K.SUMMON_UNIT:
			if z >= 0 and e.summon_card != null and _occupancy(p, z) < _view.zone_capacity:
				_next_fake_uid -= 1
				var rec: Dictionary = _view.record_for_card(e.summon_card as CardData, _next_fake_uid, z)
				rec["card_unit"] = false
				p.lines[ME][z].append(rec)
		K.REVEAL_RED_DOTS, K.REVEAL_DEPLOYMENTS:
			p.flat += 0.05
		K.STREAK_BONUS:
			p.flat += 0.5 * amount


func _enemy_targets(p: Plan, e: EffectData, z: int, foes: Array, target_uid: int) -> Array:
	match e.target:
		T.ALL_ENEMIES:
			return foes
		T.ENEMY_POINT_MAN:
			return foes.slice(0, 1)
		T.ENEMY_SECOND_IN_LINE:
			return foes.slice(1, 2)
		T.CHOSEN_ENEMY:
			for zz: int in 3:
				if z >= 0 and zz != z:
					continue
				for rec: Dictionary in p.lines[FOE][zz]:
					if int(rec["uid"]) == target_uid and int(rec["armor"]) > 0:
						return [rec]
	return []


func _find_mine(p: Plan, uid: int) -> Dictionary:
	for z: int in 3:
		for rec: Dictionary in p.lines[ME][z]:
			if int(rec["uid"]) == uid:
				return rec
	return {}


func _hurt(rec: Dictionary, dmg: int) -> void:
	var armor: int = int(rec["armor"]) - dmg
	if armor <= 0 and int(rec["survive"]) > 0:
		armor = int(rec["survive"])
		rec["survive"] = 0
	rec["armor"] = armor


func _class_of(rec: Dictionary) -> int:
	return int(rec["class"])


func _zones_with_foes(p: Plan) -> int:
	var n: int = 0
	for z: int in 3:
		if _alive_count(p, FOE, z) > 0:
			n += 1
	return n


func _condition(c: int, z: int) -> bool:
	match c:
		DataEnums.Condition.ALWAYS:
			return true
		DataEnums.Condition.ZONE_IS_CLOSE:
			return z >= 0 and _view.zone_ranges[z] == DataEnums.RangeTag.CLOSE
		DataEnums.Condition.ZONE_IS_MID:
			return z >= 0 and _view.zone_ranges[z] == DataEnums.RangeTag.MID
		DataEnums.Condition.ZONE_IS_LONG:
			return z >= 0 and _view.zone_ranges[z] == DataEnums.RangeTag.LONG
	return true  # control conditions: assume the plan aims for them


# =============================================================================
# Firefight estimator (per zone)
# =============================================================================

## Score of zone z after the plan: Reveal damage already sits in the records' Armor;
## this runs the firefight on the public board and turns the outcome into value.
func _eval_zone(p: Plan, z: int) -> float:
	var sides: Array = [p.lines[ME][z], p.lines[FOE][z]]
	var n: Array[int] = [(sides[0] as Array).size(), (sides[1] as Array).size()]
	var armor: Array = [[], []]
	var fp: Array = [[], []]
	var cover: Array = [[], []]
	var fs: Array = [[], []]
	var survive: Array = [[], []]
	# Auras: units already on the board include the old auras in their fp.
	var aura_old: int = 0
	var aura_new: int = 0
	for rec: Dictionary in sides[0]:
		if rec["new"]:
			aura_new += int(rec["aura"])
		else:
			aura_old += int(rec["aura"])
	var callout_used: bool = false
	for si: int in 2:
		for rec: Dictionary in sides[si]:
			armor[si].append(int(rec["armor"]))
			survive[si].append(int(rec["survive"]))
			fs[si].append(bool(rec["first_shot"]))
			var f: int = int(rec["fp"])
			var c: int = int(rec["cover"])
			if si == ME:
				f += p.my_fp_buff[z] + aura_new - (int(rec["aura"]) if rec["new"] else 0)
				if rec["new"]:
					f += aura_old
				if rec["card_unit"] and not callout_used and p.callout[z] != 0:
					f += p.callout[z]
					callout_used = true
				if not _view.my_cover_removed:
					c += p.my_cover_buff[z]
			elif p.foe_cover_removed:
				c = 0
			fp[si].append(f)
			cover[si].append(c)
	# Field auras: class / all auras now, frontline auras per step (they follow the line).
	var auras: Array = [_field_aura(_my_fields_after(p, z)), _field_aura(_view.foe_fields[z])]
	var cover_off: Array[bool] = [_view.my_cover_removed, p.foe_cover_removed or _view.foe_cover_removed]
	for si: int in 2:
		var au: Dictionary = auras[si]
		for i: int in n[si]:
			fp[si][i] = int(fp[si][i]) + int(au["all_fp"]) + int(au["class_fp"][_class_of(sides[si][i])])
			if not cover_off[si]:
				cover[si][i] = int(cover[si][i]) + int(au["all_cover"])
	var front_fp: Array[int] = [int(auras[ME]["front_fp"]), int(auras[FOE]["front_fp"])]
	var front_cover: Array[int] = [0 if cover_off[ME] else int(auras[ME]["front_cover"]),
			0 if cover_off[FOE] else int(auras[FOE]["front_cover"])]
	var foe_present_at_start: bool = _any_alive(armor[FOE])
	# 0. Start-of-firefight damage (Attack Helo) on each point man.
	if p.my_ff_damage > 0:
		_hit_point_man(armor[FOE], cover[FOE], survive[FOE], p.my_ff_damage, front_cover[FOE])
	if _view.foe_firefight_damage > 0:
		_hit_point_man(armor[ME], cover[ME], survive[ME], _view.foe_firefight_damage, front_cover[ME])
	if _any_alive(armor[ME]) and _any_alive(armor[FOE]):
		# 1. Suppress.
		for si: int in 2:
			for i: int in n[si]:
				if armor[si][i] > 0 and sides[si][i]["suppress"]:
					var pm: int = _first_alive(armor[1 - si])
					if pm >= 0:
						fp[1 - si][pm] = int(fp[1 - si][pm]) - 2
		# 2. Beats front to back, First Shot exchange, Pierce (FirefightResolver._run_beats).
		_fight(sides, n, armor, fp, cover, fs, survive, front_fp, front_cover)
		# 3. Patch.
		for si: int in 2:
			for i: int in n[si]:
				var patch: int = int(sides[si][i]["patch"])
				if patch <= 0 or armor[si][i] <= 0:
					continue
				var best: int = -1
				var best_missing: int = 0
				for j: int in n[si]:
					if j == i or armor[si][j] <= 0:
						continue
					var missing: int = int(sides[si][j]["max_armor"]) - int(armor[si][j])
					if missing > best_missing:
						best = j
						best_missing = missing
				if best >= 0:
					armor[si][best] = int(armor[si][best]) + mini(patch, best_missing)
	# 4. END_OF_ROUND Field effects (Score step): Mortar Pit chip, Aid Station heal.
	for si: int in 2:
		var au: Dictionary = auras[si]
		if int(au["eor_damage"]) > 0:
			_hit_point_man(armor[1 - si], cover[1 - si], survive[1 - si], int(au["eor_damage"]), front_cover[1 - si])
		if int(au["eor_heal"]) > 0:
			var best: int = -1
			var best_missing: int = 0
			for j: int in n[si]:
				var missing: int = int(sides[si][j]["max_armor"]) - int(armor[si][j])
				if armor[si][j] > 0 and missing > best_missing:
					best = j
					best_missing = missing
			if best >= 0:
				armor[si][best] = int(armor[si][best]) + mini(int(au["eor_heal"]), best_missing)
	return _zone_value(p, z, sides, armor, foe_present_at_start)


## Step 2 of the estimator: FirefightResolver's beat order on records (firefight-order.md §2.2-2.3).
## Each beat the front-most living unfired unit of each side fires; when exactly one of the two has
## First Shot it fires first and a partner it kills never fires. Damage lands after every beat;
## Pierce carries overkill down the line. Arrays are indexed by line position.
func _fight(sides: Array, n: Array[int], armor: Array, fp: Array, cover: Array, fs: Array, survive: Array,
		front_fp: Array[int], front_cover: Array[int]) -> void:
	var fired: Array = [[], []]
	for si: int in 2:
		for i: int in n[si]:
			fired[si].append(false)
	var guard: int = 0
	while guard < 16:
		guard += 1
		if not (_any_alive(armor[ME]) and _any_alive(armor[FOE])):
			return
		var shooters: Array = []
		for si: int in 2:
			for i: int in n[si]:
				if armor[si][i] > 0 and not fired[si][i]:
					shooters.append([si, i])
					break
		if shooters.is_empty():
			return
		if shooters.size() == 2 and bool(fs[0][shooters[0][1]]) != bool(fs[1][shooters[1][1]]):
			var a: Array = shooters[0] if bool(fs[0][shooters[0][1]]) else shooters[1]
			var b: Array = shooters[1] if a == shooters[0] else shooters[0]
			_beat(sides, n, armor, fp, cover, survive, front_fp, front_cover, fired, [a])
			if int(armor[b[0]][b[1]]) > 0 and _any_alive(armor[a[0]]):
				_beat(sides, n, armor, fp, cover, survive, front_fp, front_cover, fired, [b])
			continue
		_beat(sides, n, armor, fp, cover, survive, front_fp, front_cover, fired, shooters)


## One beat on records: the shooters fire at once, then damage lands (Grit), then On Down.
func _beat(sides: Array, n: Array[int], armor: Array, fp: Array, cover: Array, survive: Array,
		front_fp: Array[int], front_cover: Array[int], fired: Array, shooters: Array) -> void:
	var dmg: Array = [[], []]
	for si: int in 2:
		for i: int in n[si]:
			dmg[si].append(0)
	var front: Array[int] = [_first_alive(armor[ME]), _first_alive(armor[FOE])]
	for sh: Array in shooters:
		var si: int = sh[0]
		var i: int = sh[1]
		var o: int = 1 - si
		fired[si][i] = true
		var assigned: Array[int] = []
		assigned.resize(n[o])
		var t: int = _target(sides[si][i], sides[o], armor[o], assigned)
		if t < 0:
			continue
		var shot: int = int(fp[si][i]) + (front_fp[si] if i == front[si] else 0)
		var d: int = maxi(0, maxi(0, shot) - int(cover[o][t]) - (front_cover[o] if t == front[o] else 0))
		dmg[o][t] = int(dmg[o][t]) + d
		if bool(sides[si][i].get("pierce", false)):
			var left: int = d - int(armor[o][t])
			var j: int = t
			while left > 0 and j + 1 < n[o]:
				j += 1
				if int(armor[o][j]) <= 0:
					continue
				var d2: int = mini(maxi(0, left - int(cover[o][j])), int(armor[o][j]))
				dmg[o][j] = int(dmg[o][j]) + d2
				left -= int(cover[o][j]) + int(armor[o][j])
	var died: Array = [[], []]
	for si: int in 2:
		for i: int in n[si]:
			if int(dmg[si][i]) <= 0 or armor[si][i] <= 0:
				continue
			armor[si][i] = int(armor[si][i]) - int(dmg[si][i])
			if armor[si][i] <= 0:
				if survive[si][i] > 0:
					armor[si][i] = survive[si][i]
					survive[si][i] = 0
				else:
					died[si].append(i)
	# On Down damage (Demolitions Expert) on the enemy point man as it stands now.
	for si: int in 2:
		for i: int in died[si]:
			var od: int = int(sides[si][i]["on_down_damage"])
			if od > 0:
				_hit_point_man(armor[1 - si], cover[1 - si], survive[1 - si], od, front_cover[1 - si])

func _zone_value(p: Plan, z: int, sides: Array, armor: Array, foe_present_at_start: bool) -> float:
	var P: AiPersonality = personality
	var dealt: float = 0.0
	var taken: float = 0.0
	var kills: int = 0
	var op_kills: int = 0
	var losses: int = 0
	var op_lost: int = 0
	var present: Array[bool] = [false, false]
	var holder: Array[bool] = [false, false]
	for si: int in 2:
		for i: int in (sides[si] as Array).size():
			var rec: Dictionary = sides[si][i]
			var a0: int = int(rec["armor0"])
			var af: int = maxi(0, int(armor[si][i]))
			var lost_armor: int = maxi(0, a0 - af)
			var dead: bool = int(armor[si][i]) <= 0 and a0 > 0
			if si == FOE:
				dealt += lost_armor
				if dead:
					if rec["is_op"]:
						op_kills += 1
					elif rec["credit"]:
						kills += 1
			else:
				taken += lost_armor
				if dead:
					if rec["is_op"]:
						op_lost += 1
					elif rec["credit"]:
						losses += 1
			if int(armor[si][i]) > 0 and rec["control"]:
				present[si] = true
				holder[si] = holder[si] or bool(rec["holder"])
	var control: int = 0
	if present[ME] and not present[FOE]:
		control = 1
	elif present[FOE] and not present[ME]:
		control = -1
	elif present[ME] and present[FOE]:
		if holder[ME] and not holder[FOE]:
			control = 1
		elif holder[FOE] and not holder[ME]:
			control = -1
	var preferred: bool = z in _pref
	var zone_mult: float = P.preferred_control_mult if preferred else 1.0
	var v: float = P.weight_damage_dealt * (dealt + KILL_VALUE * kills + OP_KILL_VALUE * op_kills)
	v -= P.weight_damage_taken * (taken + KILL_VALUE * losses + OP_KILL_VALUE * op_lost)
	if _view.mode == DataEnums.GameMode.FIREFIGHT:
		v += P.weight_zone_control * (kills + op_kills - losses - op_lost) + 0.3 * P.weight_zone_control * zone_mult * control
	else:
		v += P.weight_zone_control * zone_mult * control
	# Deny the player's streak: down their Operator (resets it), don't feed them kills.
	if op_kills > 0:
		v += P.weight_deny_streak * 0.5 * (_view.foe_streak + 1)
	v -= P.weight_deny_streak * 0.35 * (losses + op_lost)
	v -= P.weight_deny_streak * 0.25 * _view.my_streak * op_lost
	# Personality habits.
	var mine: Array = sides[ME]
	for i: int in mine.size():
		var rec: Dictionary = mine[i]
		if rec["is_op"]:
			if preferred and int(armor[ME][i]) > 0:
				v += P.operator_home_bonus
			continue
		if not rec["new"]:
			continue
		if preferred:
			v += P.preferred_zone_bonus + P.sturdy_bonus * int(rec["max_armor"])
			if rec["holder"] and P.sturdy_bonus > 0.0:
				v += 0.4
		if foe_present_at_start:
			v += P.push_bonus
	for card: CardData in p.equip_new[z]:
		v += _equipment_value(card, control, present[ME], preferred, sides[ME])
	# Fields already standing: Overrun takes mine in a column the foe ends up controlling,
	# a replaced one is gone, and overrunning a foe Field denies its later rounds.
	var standing: CardData = _view.my_visible_field(z)
	if standing != null and (control == -1 or p.field_replaced[z]):
		v -= _field_future(standing, 1, sides[ME])
	var foe_field: CardData = _foe_visible_field(z)
	if foe_field != null and control == 1:
		v += 0.8 * _field_future(foe_field, 1, sides[FOE])
	return v


## Value of a new Field: this round's aura / END_OF_ROUND effects are already in the zone
## estimate; this adds the streak / trap parts and the rounds after this one.
func _equipment_value(card: CardData, control: int, mine_present: bool, preferred: bool, mine: Array = []) -> float:
	var v: float = 0.2
	for e: EffectData in card.effects:
		if e == null:
			continue
		if e.trigger == TR.END_OF_ROUND and e.kind == K.STREAK_BONUS:
			v += (personality.weight_deny_streak * 0.4 + 0.8) * e.amount if control == 1 else 0.1
		elif e.trigger == TR.ON_ENEMY_ARRIVE and e.kind == K.DAMAGE:
			v += personality.weight_damage_dealt * e.amount * (0.55 if mine_present or preferred else 0.25)
	if card.is_visible_field():
		v += _field_future(card, control, mine)
	return v


## Expected value of a visible Field's rounds after this one: per-round value x the rounds
## left (at most 3 counted) x the chance it survives Overrun (control after this round:
## 1 mine, 0 contested / empty, -1 the foe's: torn down now, so 0).
func _field_future(card: CardData, control: int, mine: Array) -> float:
	if control < 0:
		return 0.0
	var rounds: int = clampi(_view.round_cap - _view.round_number, 0, 3)
	var keep: float = 0.6 if control == 1 else 0.3
	return _field_round_value(card, mine) * rounds * keep


## Rough value of one round of a Field's effects (weights of this personality).
func _field_round_value(card: CardData, mine: Array) -> float:
	var P: AiPersonality = personality
	var v: float = 0.0
	# Auras need my units in the column: worth much less while it is empty.
	var alive: int = 0
	for rec: Dictionary in mine:
		if int(rec["armor"]) > 0:
			alive += 1
	var presence: float = 1.0 if alive > 0 else 0.25
	for e: EffectData in card.effects:
		if e == null:
			continue
		match e.kind:
			K.MODIFY_FIREPOWER:
				if e.trigger != TR.PASSIVE:
					continue
				var hits: float = 1.0
				if e.target_class != DataEnums.WeaponClass.NONE:
					hits = 0.0
					for rec: Dictionary in mine:
						if _class_of(rec) == e.target_class:
							hits += 1.0
					hits = maxf(hits, 0.3)  # more of that class may come
				elif e.target == T.ALL_FRIENDLIES:
					hits = maxf(1.0, mine.size())
				v += P.weight_damage_dealt * e.amount * hits * 0.8 * presence
			K.GRANT_COVER:
				if e.trigger == TR.PASSIVE:
					v += P.weight_damage_taken * e.amount * 1.6 * presence
			K.DAMAGE:
				if e.trigger == TR.END_OF_ROUND:
					v += P.weight_damage_dealt * e.amount * 0.8
			K.HEAL:
				v += P.weight_damage_taken * e.amount * 0.7 * presence
			K.STREAK_BONUS:
				v += 0.5 * e.amount
			K.REVEAL_RED_DOTS:
				v += 0.1
	return v


## The visible Fields I would have in zone z after the plan (a new visible one replaces the old).
func _my_fields_after(p: Plan, z: int) -> Array:
	var out: Array = []
	for c: CardData in _view.my_fields[z]:
		if not (p.field_replaced[z] and c.is_visible_field()):
			out.append(c)
	out.append_array(p.equip_new[z])
	return out


func _foe_visible_field(z: int) -> CardData:
	for c: CardData in _view.foe_fields[z]:
		if c.is_visible_field():
			return c
	return null


## Rules allow one visible Field per side per column per Deploy, and replacing a Field with
## another copy of itself gains nothing.
func _field_slot_open(p: Plan, card: CardData, z: int) -> bool:
	for c: CardData in p.equip_new[z]:
		if c.is_visible_field():
			return false
	var standing: CardData = _view.my_visible_field(z)
	return standing == null or standing.id != card.id


## Field aura totals of a list of Field cards (PASSIVE and END_OF_ROUND kinds the estimator models).
static func _field_aura(cards: Array) -> Dictionary:
	var class_fp: Array[int] = []
	class_fp.resize(DataEnums.WeaponClass.size())
	var out: Dictionary = {"front_fp": 0, "front_cover": 0, "all_fp": 0, "all_cover": 0, "class_fp": class_fp,
			"eor_damage": 0, "eor_heal": 0}
	for c: CardData in cards:
		for e: EffectData in c.effects:
			if e == null or e.condition != DataEnums.Condition.ALWAYS:
				continue
			if e.trigger == TR.PASSIVE:
				var front: bool = e.target == T.FRIENDLY_POINT_MAN
				if not (front or e.target == T.ALL_FRIENDLIES):
					continue
				if e.kind == K.MODIFY_FIREPOWER:
					if front:
						out["front_fp"] = int(out["front_fp"]) + e.amount
					elif e.target_class != DataEnums.WeaponClass.NONE:
						class_fp[e.target_class] += e.amount
					else:
						out["all_fp"] = int(out["all_fp"]) + e.amount
				elif e.kind == K.GRANT_COVER and e.target_class == DataEnums.WeaponClass.NONE:
					var key: String = "front_cover" if front else "all_cover"
					out[key] = int(out[key]) + e.amount
			elif e.trigger == TR.END_OF_ROUND:
				if e.kind == K.DAMAGE and e.target == T.ENEMY_POINT_MAN:
					out["eor_damage"] = int(out["eor_damage"]) + e.amount
				elif e.kind == K.HEAL:
					out["eor_heal"] = int(out["eor_heal"]) + e.amount
	return out


func _hit_point_man(armor: Array, cover: Array, survive: Array, amount: int, front_cover: int = 0) -> void:
	var pm: int = _first_alive(armor)
	if pm < 0:
		return
	armor[pm] = int(armor[pm]) - maxi(0, amount - int(cover[pm]) - front_cover)
	if armor[pm] <= 0 and survive[pm] > 0:
		armor[pm] = survive[pm]
		survive[pm] = 0


func _first_alive(armor: Array) -> int:
	for i: int in armor.size():
		if int(armor[i]) > 0:
			return i
	return -1


func _any_alive(armor: Array) -> bool:
	return _first_alive(armor) >= 0


## FirefightResolver.pick_target on records: skip doomed units (none in the beat order); Pick = lowest remaining
## Armor (ties front-most), Flank = back-most, both skip untargetable units.
func _target(shooter: Dictionary, foes: Array, armor: Array, assigned: Array[int]) -> int:
	var first: int = -1
	var pick: bool = shooter["pick"]
	var flank: bool = shooter["flank"]
	var best: int = -1
	var best_left: int = 0
	for i: int in foes.size():
		var left: int = int(armor[i]) - assigned[i]
		if int(armor[i]) <= 0 or left <= 0:
			continue
		if first < 0:
			first = i
		if not (pick or flank) or foes[i]["untargetable"]:
			continue
		if pick:
			if best < 0 or left < best_left:
				best = i
				best_left = left
		else:
			best = i
	if best >= 0:
		return best
	return first


# =============================================================================
# Result
# =============================================================================

func _to_result(p: Plan, best_score: float, alt_score: float, second: bool) -> Dictionary:
	var chain: Array[Dictionary] = []
	var at: Plan = p
	while at != null and not at.action.is_empty():
		chain.push_front(at.action)
		at = at.parent
	var moves: Array[Dictionary] = []
	var units: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for a: Dictionary in chain:
		match a["kind"]:
			&"place", &"rotate":
				moves.append(_intent_for(a))
			&"unit":
				units.append(_intent_for(a))
			_:
				if _is_draw(a):
					var only: Array[Dictionary] = [_intent_for(a)]
					return {"intents": only, "score": p.score(), "best_score": best_score, "alt_score": alt_score,
							"second_best": second, "replan": true}
				rest.append(_intent_for(a))
	var intents: Array[Dictionary] = []
	intents.append_array(moves)
	intents.append_array(units)
	intents.append_array(rest)
	return {"intents": intents, "score": p.score(), "best_score": best_score, "alt_score": alt_score,
			"second_best": second, "replan": false}


func _intent_for(a: Dictionary) -> Dictionary:
	match a["kind"]:
		&"place":
			return RulesIntent.place_operator(a["zone"])
		&"rotate":
			return RulesIntent.rotate(a["zone"])
	if a["item"] != null:
		return RulesIntent.use_item((a["item"] as LoadoutItem).id, a["zone"], a["target_uid"], a["dest_zone"])
	return RulesIntent.play_card(a["uid"], a["zone"], a["target_uid"], a["dest_zone"])


## A card whose "Resolves immediately" effect draws: the hand changes, so plan again after it.
func _is_draw(a: Dictionary) -> bool:
	var effects: Array[EffectData] = []
	if a["card"] != null:
		effects = (a["card"] as CardData).effects
	elif a["item"] != null:
		effects = (a["item"] as LoadoutItem).effects
	for e: EffectData in effects:
		if e != null and e.trigger == TR.IMMEDIATE and e.kind == K.DRAW:
			return true
	return false
