# run_v2_check.gd
# Purpose: kc-v2 balance harness on the SHIPPED Run v2 (kc-v2-impl port of the kc-v2-design sim): real
#   RunProgress map runs (RunMap, RunEvents, RunShop, REQ, elites, bosses, modifiers), real MatchState
#   Terrain / boss rules / Operator kits, the real Terrain-aware AiView / AiPlanner on both sides. The
#   design-time subclasses (V2Match, V2Hooks, V2View, V2Ai) are gone: everything they prototyped now
#   lives in scripts/. What the proxies decide (path, events, shop, rest, offers) is the design sim's
#   rule set (run-v2.md §2.6, §10).
#     runs    run win, per-node win (the ramp), by Operator and boss; end-of-run decks kept
#     ops     Operator head to head on late decks
#     late    traits round robin (Kestrel on both sides), aware vs blind, seat 0 mirrors (random Terrain)
#   Options: exps=runs,ops,late  runs=N  proxies=competent,casual  first=1 (the first-run map)
#     op=kestrel_ar7|longreach_338|wasp_9|bastion_60|rotate  boss=meridian|prime|choir|rotate
#     mods=hardcore,austerity,hot_ground,veterans,fog  terrain=0 (no Terrain anywhere)
#     slot=N.prop=value[;...] (kc-econ: RunMatchData N, 1-5 = F1-F4 + the old M5, 6-8 = the bosses)
#     lset=loadout.prop=value[;...] (kc-econ: e.g. lset=wasp_9.operator_armor=8)
#     sdeck=N:card*count,...[;N:...] (kc-econ: slot N's authored enemy deck)
#     starter=card*n,... (kc-econ: the run starter, sets deck_size) edeck=0.5|10 (kc-econ: enemy decks scaled to a share or to N cards, composition kept)
#     eset=loadout.effect_index.prop=value (kc-duel-tune: e.g. eset=ab_marked_shot.0.amount=2)
#     cfg=prop=value[;...] (RunConfig, e.g. cfg=price_muster_out=1)  set=card.prop=value  tune=trait.tier.key=value
#     late=N (aware-vs-blind decks) mirror=N tn=N (trait games per pairing) hn=N (head-to-head games per pair)
#   Run: godot --headless --path . -s res://tests/tools/run_v2_check.gd -- exps=runs runs=400
# Author: Sr Game Designer Agent (kc-v2-design); ported to the shipped code by the Mechanics Developer Agent (kc-v2-impl)
extends SceneTree

var runs: int = 100
var late_n: int = 80
var mirror_n: int = 400
var trait_n: int = 60
var h2h_n: int = 240
var proxies: Array[String] = ["competent", "casual"]
var exps: Array[String] = ["runs"]
var first_run: bool = false
var op_mode: String = "rotate"
var boss_mode: String = "rotate"
var mods: Array = []
var terrain_on: bool = true
## kc-econ what-ifs: enemy decks scaled to this share of their size (composition kept; 0 = as authored).
var edeck_scale: float = 0.0

## kc-duel-tune: Doctrine-rule what-ifs (docrule=2only|3only).
const DocMatch: GDScript = preload("res://tests/tools/doctrine_match.gd")
var docrule: String = ""
const OPS: Array[StringName] = [&"kestrel_ar7", &"longreach_338", &"wasp_9", &"bastion_60"]
const BOSSES: Array[StringName] = [&"meridian", &"prime", &"choir"]

var config: RunConfig = null
var late: Array[SideSetup] = []
var late_trait: Array[StringName] = []
var late_op: Array[StringName] = []
var init_stats: Array[int] = [0, 0, 0]


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	await process_frame
	config = (load("res://data/run_config.tres") as RunConfig).duplicate(false) as RunConfig
	for arg: String in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		match kv[0]:
			"runs": runs = int(kv[1])
			"late": late_n = int(kv[1])
			"mirror": mirror_n = int(kv[1])
			"tn": trait_n = int(kv[1])
			"hn": h2h_n = int(kv[1])
			"first": first_run = kv[1] == "1"
			"op": op_mode = kv[1]
			"boss": boss_mode = kv[1]
			"terrain": terrain_on = kv[1] != "0"
			"edeck": edeck_scale = float(kv[1])
			"sdeck":
				# kc-econ: sdeck=N:card*count,... sets slot N's authored enemy_deck (1-based, as slot=).
				for item: String in kv[1].split(";"):
					var a3: PackedStringArray = item.split(":", true, 1)
					var ix3: int = int(a3[0]) - 1
					var md3: RunMatchData = config.matches[ix3] if ix3 < config.matches.size() else config.bosses[ix3 - config.matches.size()]
					var ed: Array[CardData] = []
					for part: String in a3[1].split(","):
						var pc3: PackedStringArray = part.split("*")
						for j: int in (int(pc3[1]) if pc3.size() > 1 else 1):
							ed.append(load("res://data/cards/%s.tres" % pc3[0]) as CardData)
					md3.enemy_deck = ed
			"slot":
				# kc-econ: slot=N.prop=value[;...] edits RunMatchData N (1-based; 6-8 = the bosses).
				for item: String in kv[1].split(";"):
					var a2: PackedStringArray = item.split(".", true, 1)
					var b2: PackedStringArray = a2[1].split("=", true, 1)
					var ix: int = int(a2[0]) - 1
					var md2: RunMatchData = config.matches[ix] if ix < config.matches.size() else config.bosses[ix - config.matches.size()]
					_assign(md2, b2[0], b2[1])
			"starter":
				# kc-econ: starter=si_grunt*3,si_trooper*3,... (also sets deck_size).
				var sd: Array[CardData] = []
				for part: String in kv[1].split(","):
					var pc: PackedStringArray = part.split("*")
					for j: int in (int(pc[1]) if pc.size() > 1 else 1):
						sd.append(load("res://data/cards/%s.tres" % pc[0]) as CardData)
				config.starter_deck = sd
				config.deck_size = sd.size()
			"proxies":
				proxies.clear()
				for p: String in kv[1].split(","):
					proxies.append(p)
			"exps":
				exps.clear()
				for e: String in kv[1].split(","):
					exps.append(e)
			"mods":
				mods.clear()
				for m: String in kv[1].split(","):
					if m != "":
						mods.append(StringName(m))
			"cfg":
				for item: String in kv[1].split(";"):
					var p2: PackedStringArray = item.split("=", true, 1)
					_assign(config, p2[0], p2[1])
			"set":
				for item: String in kv[1].split(";"):
					var a: PackedStringArray = item.split(".", true, 1)
					var b: PackedStringArray = a[1].split("=", true, 1)
					_assign(load("res://data/cards/%s.tres" % a[0]), b[0], b[1])
			"lset":
				# kc-econ: lset=loadout_id.prop=value[;...] edits a LoadoutItem (an Operator) in memory.
				for item: String in kv[1].split(";"):
					var la: PackedStringArray = item.split(".", true, 1)
					var lb: PackedStringArray = la[1].split("=", true, 1)
					_assign(load("res://data/loadout/%s.tres" % la[0]), lb[0], lb[1])
			"docrule": docrule = kv[1]
			"eset":
				# kc-duel-tune: eset=loadout_id.effect_index.prop=value[;...] edits an ability's effect (Marked Shot amount).
				for item: String in kv[1].split(";"):
					var ea: PackedStringArray = item.split(".", true, 2)
					var eb: PackedStringArray = ea[2].split("=", true, 1)
					var eli: LoadoutItem = load("res://data/loadout/%s.tres" % ea[0]) as LoadoutItem
					_assign(eli.effects[int(ea[1])], eb[0], eb[1])
			"tune":
				for item: String in kv[1].split(";"):
					var tv: PackedStringArray = item.split("=", true, 1)
					var tk: PackedStringArray = tv[0].split(".")
					var val: Variant = str_to_var(tv[1]) if str_to_var(tv[1]) != null else tv[1]
					var tiers: Array = SynergyRules.trait_bonus[StringName(tk[0])]
					if val is String and val == "none":
						(tiers[int(tk[1])] as Dictionary).erase(tk[2])
					else:
						(tiers[int(tk[1])] as Dictionary)[tk[2]] = val
			_: push_error("run_v2_check: unknown option " + arg)
	# kc-duel-tune sanity line: the Operator numbers this run really uses.
	var ops_line: Array[String] = []
	for opid: String in ["kestrel_ar7", "longreach_338", "wasp_9", "bastion_60"]:
		var li: LoadoutItem = load("res://data/loadout/%s.tres" % opid) as LoadoutItem
		ops_line.append("%s %d/%d qm%d" % [opid, li.operator_firepower, li.operator_armor, li.opening_hand_bonus])
	var ms: LoadoutItem = load("res://data/loadout/ab_marked_shot.tres") as LoadoutItem
	print("  operators: %s · marked shot %d" % [", ".join(ops_line), (ms.effects[0] as EffectData).amount])
	var t0: int = Time.get_ticks_msec()
	print("run_v2_check (shipped): runs=%d first=%s op=%s boss=%s mods=%s terrain=%s args=%s" % [runs, first_run,
			op_mode, boss_mode, mods, terrain_on, OS.get_cmdline_user_args()])
	print("  trait bonus: %s" % SynergyRules.trait_bonus)
	for k: int in proxies.size():
		_runs(proxies[k], k == 0)
	if "ops" in exps:
		_ops_h2h()
	if "late" in exps:
		_traits()
		_duel_late()
		_mirrors()
	print("\nrun_v2_check done in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit(0)


func _assign(obj: Object, prop: String, raw: String) -> void:
	var cur: Variant = obj.get(prop)
	var val: Variant = raw
	match typeof(cur):
		TYPE_INT: val = int(raw)
		TYPE_FLOAT: val = float(raw)
		TYPE_BOOL: val = raw == "true" or raw == "1"
		TYPE_STRING_NAME: val = StringName(raw)
		TYPE_PACKED_INT32_ARRAY:
			var pa: PackedInt32Array = PackedInt32Array()
			for x: String in raw.split(","):
				pa.append(int(x))
			val = pa
		TYPE_NIL: push_error("run_v2_check: %s has no property %s" % [obj, prop])
	obj.set(prop, val)


# =============================================================================
# Proxies
# =============================================================================

func _ai(proxy: String, aware: bool = true) -> AiPlayer:
	var p: AiPersonality = AiPersonality.new()
	p.preferred_ranges.clear()
	p.preferred_zone_bonus = 0.0
	p.operator_home_bonus = 0.0
	p.second_best_chance = 0.0
	p.weight_damage_dealt = 2.0
	p.weight_damage_taken = 0.5
	p.push_bonus = 0.6
	if proxy == "casual":
		p.weight_damage_dealt = 1.5
		p.weight_damage_taken = 0.8
		p.push_bonus = 0.3
		p.second_best_chance = 0.6
		p.card_keep_cost = 0.6
		p.killstreak_keep_cost = 1.2
		p.weight_deny_streak = 1.0
	var ai: AiPlayer = AiPlayer.new(p)
	ai.planner.synergy_aware = aware
	return ai


func _squad_ai(squad: SquadData) -> AiPlayer:
	var ai: AiPlayer = AiPlayer.new(AiPersonality.from_squad(squad))
	ai.planner.synergy_aware = true
	return ai


func _play(m: MatchState, a: AiPlayer, b: AiPlayer, track: bool = false) -> void:
	while m.phase != MatchState.Phase.ENDED and m.round_number <= 14:
		b.take_turn(m, MatchState.ENEMY)
		a.take_turn(m, MatchState.PLAYER, false)
		m.set_ready(MatchState.PLAYER)
		if track:
			init_stats[0] += 1
		m.resolve_round()
		if track and m.initiative == 0:
			init_stats[1] += 1
		m.begin_round()


## The design sim's offer rule: on-trait slot 1 unless it's a tactic, else the most expensive unit.
func _choose(r: RunProgress) -> int:
	var offer: Dictionary = r.current_offer()
	if offer["kind"] not in RewardOffers.CARD_DROPS:
		return 0
	if offer.has("on_trait"):
		var c0: CardData = r.resource(offer["options"][0]) as CardData
		if c0 != null and c0.card_type != DataEnums.CardType.TACTIC:
			return 0
	var best: int = 0
	var best_cost: int = -1
	for i: int in offer["options"].size():
		var c: CardData = r.resource(offer["options"][i]) as CardData
		if c != null and c.is_unit() and c.cost > best_cost:
			best = i
			best_cost = c.cost
	return best


func _offers(r: RunProgress) -> void:
	var guard: int = 0
	while not r.current_offer().is_empty() and guard < 40:
		guard += 1
		if r.choose_offer(_choose(r)) != "":
			r.skip_offer()


## The design sim's path rule (§2.6).
func _pick_node(r: RunProgress, competent: bool, rng: RandomNumberGenerator) -> StringName:
	var reach: Array[StringName] = r.map.reachable()
	if reach.size() == 1:
		return reach[0]
	if not competent:
		return reach[rng.randi_range(0, reach.size() - 1)]
	var full: bool = r.tickets >= r.max_tickets()
	var rich: bool = r.req >= config.price_unit
	var prio: Array = []
	if full:
		prio = [RunMap.TYPE_ELITE, RunMap.TYPE_SHOP, RunMap.TYPE_EVENT, RunMap.TYPE_REST] if rich else [RunMap.TYPE_ELITE, RunMap.TYPE_EVENT, RunMap.TYPE_SHOP, RunMap.TYPE_REST]
	elif r.tickets == 1:
		prio = [RunMap.TYPE_REST, RunMap.TYPE_EVENT, RunMap.TYPE_SHOP, RunMap.TYPE_ELITE]
	else:
		prio = [RunMap.TYPE_SHOP, RunMap.TYPE_REST, RunMap.TYPE_EVENT, RunMap.TYPE_ELITE] if rich else [RunMap.TYPE_REST, RunMap.TYPE_SHOP, RunMap.TYPE_EVENT, RunMap.TYPE_ELITE]
	prio.append(RunMap.TYPE_FIGHT)
	prio.append(RunMap.TYPE_BOSS)
	for t: StringName in prio:
		var cands: Array[StringName] = []
		for id: StringName in reach:
			if r.map.node(id)["type"] == t:
				cands.append(id)
		if cands.is_empty():
			continue
		# Look one step ahead (the design sim's proxy saw every option of the next step): keep the
		# best-ranked next node type open.
		var best: StringName = cands[0]
		var best_rank: int = 99
		for id: StringName in cands:
			var rank: int = 99
			for l: StringName in r.map.node(id)["links"]:
				rank = mini(rank, prio.find(r.map.node(l)["type"]) if prio.has(r.map.node(l)["type"]) else 98)
			if rank < best_rank:
				best_rank = rank
				best = id
		return best
	return reach[0]


func _opt(v: Dictionary, id: StringName) -> Dictionary:
	for o: Dictionary in v.get("options", []):
		if o["id"] == id:
			return o
	return {}


func _try(r: RunProgress, v: Dictionary, id: StringName, args: Dictionary = {}) -> bool:
	var o: Dictionary = _opt(v, id)
	if o.is_empty() or not o["available"]:
		return false
	return RunEvents.choose(r, int(o["index"]), args)["ok"]


func _event(r: RunProgress, competent: bool, rng: RandomNumberGenerator, st: Dictionary) -> void:
	st["events"] += 1
	var v: Dictionary = RunEvents.view(r)
	var coin: bool = competent or rng.randf() < 0.5
	var done: bool = false
	match v["id"]:
		&"supply_truck":
			done = _try(r, v, &"crack" if competent or rng.randf() < 0.5 else &"radio")
		&"audit":
			done = _try(r, v, &"hand_in" if (r.standard_issue_count() >= 4 or not competent) else &"forms")
		&"wounded_scout":
			done = coin and _try(r, v, &"escort")
			if not done:
				done = _try(r, v, &"kit")
		&"fixer":
			var at: int = r.deck.find(&"si_armored")
			if at < 0:
				at = r.deck.find(&"si_sergeant")
			if at >= 0 and coin:
				done = _try(r, v, &"swap", {"deck_index": at})
		&"radio_chatter":
			done = _try(r, v, &"sell")
		&"memorial":
			done = _try(r, v, &"respects")
			if not done:
				var choices: Array = _opt(v, &"tags").get("choices", [])
				if not choices.is_empty():
					done = _try(r, v, &"tags", {"deck_index": int(choices[rng.randi_range(0, choices.size() - 1)]["index"])})
		&"rival_message":
			done = r.tickets >= r.max_tickets() and coin and _try(r, v, &"accept")
			if not done:
				done = _try(r, v, &"ignore")
		&"range_day":
			done = _try(r, v, &"zero")
			if not done:
				done = _try(r, v, &"drills")
		&"night_drop":
			done = r.tickets >= r.max_tickets() and coin and _try(r, v, &"go")
	if not done:
		# The "nothing" option, else the first available one.
		for o: Dictionary in v["options"]:
			if o["available"] and o["needs"] == &"" and RunEvents.choose(r, int(o["index"]))["ok"]:
				done = true
				break
	if not done:
		r.leave_node()


func _shop(r: RunProgress, competent: bool, rng: RandomNumberGenerator, st: Dictionary) -> void:
	st["shops"] += 1
	var req0: int = r.req
	var v: Dictionary = RunShop.view(r)
	var main: StringName = r.main_trait()
	var order: Array = range(v["cards"].size())
	if competent:
		order.sort_custom(func(a: int, b: int) -> bool:
			var ca: CardData = r.resource(v["cards"][a]["id"]) as CardData
			var cb: CardData = r.resource(v["cards"][b]["id"]) as CardData
			var va: int = (10 if a == 0 and main != &"" and ca.can_carry(main) else 0) + (ca.cost if ca.is_unit() else 0)
			var vb: int = (10 if b == 0 and main != &"" and cb.can_carry(main) else 0) + (cb.cost if cb.is_unit() else 0)
			return va > vb)
	else:
		var o2: Array = []
		while not order.is_empty():
			o2.append(order.pop_at(rng.randi_range(0, order.size() - 1)))
		order = o2
	var bought: int = 0
	for i: int in order:
		var row: Dictionary = v["cards"][i]
		var c: CardData = r.resource(row["id"]) as CardData
		if int(row["price"]) > r.req:
			continue
		if competent and not c.is_unit() and bought > 0:
			continue
		if RunShop.buy(r, i) == "":
			bought += 1
			st["bought"] += 1
		if not competent:
			break
	while competent and r.req >= config.price_muster_out and r.standard_issue_count() > 0 and r.deck.size() > config.deck_floor:
		var si: int = _first_si(r)
		if si < 0 or RunShop.muster_out(r, si) != "":
			break
	st["req_spent"] += req0 - r.req
	r.leave_node()


## The design sim's Standard Issue removal order: Armored, Sergeant, Trooper, Grunt.
func _first_si(r: RunProgress) -> int:
	for id: StringName in [&"si_armored", &"si_sergeant", &"si_trooper", &"si_grunt"]:
		var at: int = r.deck.find(id)
		if at >= 0:
			return at
	return -1


func _rest(r: RunProgress, competent: bool, st: Dictionary) -> void:
	st["rests"] += 1
	if r.tickets < r.max_tickets() and RunShop.rest_choose(r, RunShop.REST_TICKET) == "":
		return
	if competent and r.standard_issue_count() > 0 and r.deck.size() > config.deck_floor:
		var picks: Array = []
		for id: StringName in [&"si_armored", &"si_sergeant", &"si_trooper", &"si_grunt"]:
			for i: int in r.deck.size():
				if r.deck[i] == id and picks.size() < mini(2, r.deck.size() - config.deck_floor) and i not in picks:
					picks.append(i)
		if not picks.is_empty() and RunShop.rest_choose(r, RunShop.REST_DRILL, {"deck_indices": picks}) == "":
			return
	if RunShop.rest_choose(r, RunShop.REST_FIELD_STRIP) == "":
		_offers(r)
		return
	if RunShop.rest_choose(r, RunShop.REST_DRILL, {"deck_indices": [r.deck.size() - 1]}) != "":
		r.leave_node()


# =============================================================================
# Runs
# =============================================================================

func _runs(proxy: String, keep_late: bool) -> void:
	var competent: bool = proxy == "competent"
	var wins: int = 0
	var keys: Array[String] = ["F1", "F2", "Elite I", "F3", "Elite II", "F4", "Boss"]
	var reach: Dictionary = {}
	var won: Dictionary = {}
	for k: String in keys:
		reach[k] = 0
		won[k] = 0
	var by_op: Dictionary = {}
	var by_boss: Dictionary = {}
	var boss_fight: Dictionary = {}
	var nodes: Dictionary = {}
	var totals: Dictionary = {"req_spent": 0, "bought": 0, "si_out": 0, "deck": 0, "end": 0, "events": 0, "shops": 0, "rests": 0, "req": 0}
	var t0: int = Time.get_ticks_msec()
	for s: int in runs:
		var seed_v: int = 900000 + s
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_v * 31 + 7
		var op: StringName = OPS[s % OPS.size()] if op_mode == "rotate" else StringName(op_mode)
		var boss: StringName = BOSSES[(s / OPS.size()) % BOSSES.size()] if boss_mode == "rotate" else StringName(boss_mode)
		if first_run:
			op = &"kestrel_ar7"
			boss = &"meridian"
		var r: RunProgress = RunProgress.create_map_run(config, seed_v, {"first_run": first_run, "boss": boss, "modifiers": mods})
		r.set_primary(op)
		r.begin()
		var st: Dictionary = {"shops": 0, "bought": 0, "events": 0, "rests": 0, "req_spent": 0, "req": 0}
		var si0: int = r.standard_issue_count()
		var guard: int = 0
		while not r.is_over() and guard < 40:
			guard += 1
			if r.phase == RunProgress.PHASE_REWARDS:
				_offers(r)
				continue
			if r.phase != RunProgress.PHASE_MAP:
				push_error("run_v2_check: unexpected phase %s" % r.phase)
				break
			var id: StringName = _pick_node(r, competent, rng)
			var n: Dictionary = r.map.node(id)
			nodes[n["type"]] = int(nodes.get(n["type"], 0)) + 1
			r.move_to(id)
			match r.phase:
				RunProgress.PHASE_EVENT:
					_event(r, competent, rng, st)
				RunProgress.PHASE_SHOP:
					_shop(r, competent, rng, st)
				RunProgress.PHASE_REST:
					_rest(r, competent, st)
				RunProgress.PHASE_MATCH:
					var f: Dictionary = n["fight"]
					var key: String = String(f["label"])
					if keep_late and bool(f["boss"]):
						late.append(r.player_setup())
						late_trait.append(r.main_trait())
						late_op.append(op)
					reach[key] = int(reach.get(key, 0)) + 1
					var m: MatchState = _create_match(r)
					if edeck_scale > 0.0:
						_scale_deck(m.sides[MatchState.ENEMY].setup, edeck_scale)
					if not terrain_on:
						m.terrain = [&"", &"", &""] as Array[StringName]
					m.start_match()
					var md: RunMatchData = r.current_match()
					_play(m, _ai(proxy), _squad_ai(md.squad))
					var w: bool = m.result == &"player"
					if w:
						won[key] = int(won.get(key, 0)) + 1
					if bool(f["boss"]):
						var bf: Array = boss_fight.get(boss, [0, 0])
						bf[0] += 1
						bf[1] += int(w)
						boss_fight[boss] = bf
					var res: Dictionary = r.record_match(m)
					st["req"] += int(res.get("req_gained", 0))
			_offers(r)
		var v: bool = r.is_victory()
		wins += int(v)
		for pair: Array in [[by_op, op], [by_boss, boss]]:
			var t: Array = (pair[0] as Dictionary).get(pair[1], [0, 0])
			t[0] += 1
			t[1] += int(v)
			pair[0][pair[1]] = t
		totals["bought"] += int(st["bought"])
		totals["si_out"] += si0 - r.standard_issue_count()
		totals["deck"] += r.deck.size()
		totals["end"] += 1
		totals["events"] += int(st["events"])
		totals["shops"] += int(st["shops"])
		totals["rests"] += int(st["rests"])
		totals["req_spent"] += int(st["req_spent"])
		totals["req"] += int(st["req"])
	print("\n---- %s: %d shipped v2 runs%s (%.1f s) ----" % [proxy.to_upper(), runs, " (first-run map)" if first_run else "",
			(Time.get_ticks_msec() - t0) / 1000.0])
	print("  RUN WIN %.1f%% (%d/%d)" % [100.0 * wins / maxf(1, runs), wins, runs])
	var line: String = "  per node (reached -> win%%):"
	for k: String in keys:
		if int(reach.get(k, 0)) > 0:
			line += "  %s %d -> %.1f%%" % [k, reach[k], 100.0 * won[k] / maxf(1, reach[k])]
	print(line)
	var lo: String = "  run win by Operator:"
	for k: StringName in by_op:
		lo += "  %s %.1f%% (n=%d)" % [k, 100.0 * by_op[k][1] / maxf(1, by_op[k][0]), by_op[k][0]]
	print(lo)
	var lb: String = "  run win by boss:"
	for k: StringName in by_boss:
		var bf: Array = boss_fight.get(k, [0, 0])
		lb += "  %s %.1f%% (n=%d; boss fight %.1f%% of %d)" % [k, 100.0 * by_boss[k][1] / maxf(1, by_boss[k][0]), by_boss[k][0],
				100.0 * bf[1] / maxf(1, bf[0]), bf[0]]
	print(lb)
	var n_end: float = maxf(1, totals["end"])
	print("  nodes taken: %s" % nodes)
	print("  per run: REQ from fights %.1f, REQ spent in shops %.1f, shop cards %.2f, SI sent home %.2f, end deck %.1f, events %.2f, shops %.2f, rests %.2f" % [
			totals["req"] / n_end, totals["req_spent"] / n_end, totals["bought"] / n_end, totals["si_out"] / n_end,
			totals["deck"] / n_end, totals["events"] / n_end, totals["shops"] / n_end, totals["rests"] / n_end])


## kc-econ: keeps round(share * size) cards, each design's count scaled (largest remainder), in order.
func _scale_deck(s: SideSetup, share: float) -> void:
	var n: int = s.deck.size()
	var target: int = mini(n, int(share)) if share >= 2.0 else maxi(1, roundi(n * share))
	var counts: Dictionary = {}
	for c: CardData in s.deck:
		counts[c.id] = int(counts.get(c.id, 0)) + 1
	var keep: Dictionary = {}
	var rema: Array = []
	var total: int = 0
	for id: StringName in counts:
		var exact: float = counts[id] * float(target) / n
		keep[id] = int(floor(exact))
		total += int(keep[id])
		rema.append([exact - floor(exact), id])
	rema.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for k: int in target - total:
		keep[rema[k % rema.size()][1]] += 1
	var deck: Array[CardData] = []
	var traits: Array[StringName] = []
	var arts: Array[StringName] = []
	for i: int in n:
		var id: StringName = s.deck[i].id
		if int(keep[id]) <= 0:
			continue
		keep[id] -= 1
		deck.append(s.deck[i])
		if i < s.deck_traits.size():
			traits.append(s.deck_traits[i])
		if i < s.deck_arts.size():
			arts.append(s.deck_arts[i])
	s.deck = deck
	if not s.deck_traits.is_empty():
		s.deck_traits = traits
	if not s.deck_arts.is_empty():
		s.deck_arts = arts


# =============================================================================
# Late-deck checks
# =============================================================================

func _copy(s: SideSetup) -> SideSetup:
	var c: SideSetup = SideSetup.new()
	for f: String in ["display_name", "primary", "doctrine", "operator_kit"]:
		c.set(f, s.get(f))
	c.deck = s.deck.duplicate()
	c.deck_traits = s.deck_traits.duplicate()
	c.deck_arts = s.deck_arts.duplicate()
	c.attachments = s.attachments.duplicate()
	c.perks = s.perks.duplicate()
	c.killstreaks = s.killstreaks.duplicate()
	return c


func _with_op(s: SideSetup, op: StringName) -> SideSetup:
	var c: SideSetup = _copy(s)
	c.primary = load("res://data/loadout/%s.tres" % op) as LoadoutItem
	c.operator_kit = true
	return c


func _rand_terrain(k: int, mode: int) -> Array[StringName]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242 + k * 977
	if not terrain_on:
		return [&"", &"", &""] as Array[StringName]
	return TerrainRules.deal(rng, 1 + (k % 2), mode)


func _duel(sa: SideSetup, aware_a: bool, sb: SideSetup, aware_b: bool, seed_value: int, mode: int,
		ter: Array[StringName], track: bool = false) -> int:
	var md: RunMatchData = config.matches[0]
	var h: MatchHooks = MatchHooks.new()
	h.mode_rules = ModeRules.create(mode, config)
	var m: MatchState = DocMatch.new(config, md.map, _copy(sa), _copy(sb), seed_value, h)
	m.set("rule", docrule)
	m.terrain = ter.duplicate()
	m.start_match()
	_play(m, _ai("competent", aware_a), _ai("competent", aware_b), track)
	return 0 if m.result == &"player" else (1 if m.result == &"enemy" else -1)


func _pair(a: SideSetup, aware_a: bool, b: SideSetup, aware_b: bool, count: int, salt: int, track: bool = false) -> Array:
	var aw: int = 0
	var s0: int = 0
	var s1: int = 0
	for k: int in count:
		var a_seat: int = k % 2
		var mode: int = DataEnums.GameMode.ZONE_CONTROL if (k / 2) % 2 == 0 else DataEnums.GameMode.FIREFIGHT
		var ter: Array[StringName] = _rand_terrain(salt + k / 2, mode)
		var w: int = _duel(a if a_seat == 0 else b, aware_a if a_seat == 0 else aware_b,
				b if a_seat == 0 else a, aware_b if a_seat == 0 else aware_a, 9000 + k * 7919 + salt, mode, ter, track)
		s0 += int(w == 0)
		s1 += int(w == 1)
		aw += int(w == a_seat)
	return [aw, s0, count, s1]


func _ops_h2h() -> void:
	print("\n---- Operators head to head: late decks, aware (%d per pair) ----" % h2h_n)
	var total: Dictionary = {}
	for a: int in OPS.size():
		for b: int in range(a + 1, OPS.size()):
			var aw: int = 0
			var games: int = 0
			for k: int in h2h_n / 2:
				var base: SideSetup = late[(k * 3) % late.size()]
				var r: Array = _pair(_with_op(base, OPS[a]), true, _with_op(base, OPS[b]), true, 2, a * 1000 + b * 100 + k * 13)
				aw += int(r[0])
				games += int(r[2])
			print("  %-14s vs %-14s %5.1f%% (n=%d)" % [OPS[a], OPS[b], 100.0 * aw / maxf(1, games), games])
			for pr: Array in [[OPS[a], aw], [OPS[b], games - aw]]:
				var t: Array = total.get(pr[0], [0, 0])
				t[0] += int(pr[1])
				t[1] += games
				total[pr[0]] = t
	for k: StringName in total:
		print("  %-14s overall %5.1f%% (n=%d)" % [k, 100.0 * total[k][0] / maxf(1, total[k][1]), total[k][1]])


func _traits() -> void:
	var groups: Dictionary = {}
	for i: int in late.size():
		var t: StringName = late_trait[i]
		if t == &"":
			continue
		if not groups.has(t):
			groups[t] = []
		(groups[t] as Array).append(i)
	var keys: Array = groups.keys()
	var total: Dictionary = {}
	print("\n---- traits: v2 end-of-run decks by main trait, aware round robin (%d per pairing), Kestrel both sides, random Terrain ----" % trait_n)
	for a: int in keys.size():
		for b: int in range(a + 1, keys.size()):
			var ga: Array = groups[keys[a]]
			var gb: Array = groups[keys[b]]
			var aw: int = 0
			var games: int = 0
			for k: int in trait_n / 2:
				var ia: int = ga[k % ga.size()]
				var ib: int = gb[(k * 7 + 3) % gb.size()]
				var r: Array = _pair(_with_op(late[ia], &"kestrel_ar7"), true, _with_op(late[ib], &"kestrel_ar7"), true, 2,
						a * 1000 + b * 100 + k * 13)
				aw += int(r[0])
				games += int(r[2])
			print("  %-9s vs %-9s %5.1f%% (n=%d)" % [keys[a], keys[b], 100.0 * aw / maxf(1, games), games])
			for pr: Array in [[keys[a], aw], [keys[b], games - aw]]:
				var t: Array = total.get(pr[0], [0, 0])
				t[0] += int(pr[1])
				t[1] += games
				total[pr[0]] = t
	for k: StringName in total:
		print("  %-9s overall %5.1f%% (n=%d, decks %d)" % [k, 100.0 * total[k][0] / maxf(1, total[k][1]), total[k][1], (groups[k] as Array).size()])


func _duel_late() -> void:
	var k: int = mini(late.size(), late_n)
	var d: Array = [0, 0]
	for i: int in k:
		var r: Array = _pair(late[i], true, late[i], false, 4, i * 17 + 5)
		d[0] += r[0]
		d[1] += r[2]
	print("\n  duel:   synergy-aware vs blind, same late deck   %5.1f%% (n=%d)" % [100.0 * d[0] / maxf(1, d[1]), d[1]])


func _mirrors() -> void:
	var k: int = mini(late.size(), late_n)
	var ml: Array = [0, 0, 0]
	init_stats = [0, 0, 0]
	var reps: int = maxi(2, mirror_n / maxi(1, k))
	reps += reps % 2
	for i: int in k:
		var r3: Array = _pair(late[i], true, late[i], true, reps, i * 17 + 9, true)
		ml[0] += r3[1]
		ml[1] += r3[2]
	var starter: SideSetup = _with_op(RunProgress.create(config, 1).player_setup(), &"kestrel_ar7")
	var r4: Array = _pair(starter, true, starter, true, mirror_n, 77, true)
	print("  mirror: seat 0, late decks (Terrain random)       %5.1f%% (n=%d)" % [100.0 * ml[0] / maxf(1, ml[1]), ml[1]])
	print("  mirror: seat 0, Standard Issue starter            %5.1f%% (n=%d)" % [100.0 * r4[1] / maxf(1, r4[2]), r4[2]])


## kc-duel-tune: RunProgress.create_match with the Doctrine-rule MatchState (same setup and configure_match).
func _create_match(r: RunProgress) -> MatchState:
	var md: RunMatchData = r.current_match()
	var h: MatchHooks = MatchHooks.new()
	h.mode_rules = ModeRules.create(md.mode, config)
	var m: MatchState = DocMatch.new(config, md.map, r.player_setup(), r.enemy_setup(), r.match_seed(), h)
	m.set("rule", docrule)
	r.configure_match(m)
	return m
