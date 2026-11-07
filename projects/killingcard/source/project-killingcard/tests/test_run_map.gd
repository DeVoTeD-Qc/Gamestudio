# test_run_map.gd
# Purpose: kc-v2-impl run map (run-v2.md §2, §5, §6.2): generation (run 2+ and the fixed first run),
#   links, Terrain counts, the flow (move, fight, offers by rung, elites, REQ, tickets, the boss),
#   modifiers, the save v7 round trip and the v6 migration onto a first-run-shaped map.
# Author: Mechanics Developer Agent (kc-v2-impl)
extends "res://tests/test_case.gd"

const SEED: int = 4711


func _config() -> RunConfig:
	return load("res://data/run_config.tres") as RunConfig


func _run(first: bool = false, mods: Array = [], boss: StringName = &"meridian", seed_value: int = SEED) -> RunProgress:
	var r: RunProgress = RunProgress.create_map_run(_config(), seed_value, {"first_run": first, "boss": boss, "modifiers": mods})
	return r


func _skip_offers(r: RunProgress) -> void:
	var guard: int = 0
	while not r.current_offer().is_empty() and guard < 30:
		guard += 1
		if r.choose_offer(0) != "":
			r.skip_offer()


## Moves on to the first reachable node of `type` (else the first reachable) and resolves it.
func _step(r: RunProgress, prefer: StringName = &"", result: StringName = &"player") -> Dictionary:
	var reach: Array[StringName] = r.map.reachable()
	var pick: StringName = reach[0]
	for id: StringName in reach:
		if r.map.node(id)["type"] == prefer:
			pick = id
	assert_eq(r.move_to(pick), "", "move to %s" % pick)
	var n: Dictionary = r.map.node(pick)
	_resolve(r, result)
	return n


## Resolves the node the run is on: fights with `result`, events with their first available option,
## shops left, rests +ticket or Drill; then the offers.
func _resolve(r: RunProgress, result: StringName = &"player") -> void:
	match r.phase:
		RunProgress.PHASE_EVENT:
			var v: Dictionary = RunEvents.view(r)
			for o: Dictionary in v["options"]:
				if o["available"] and o["needs"] == &"":
					RunEvents.choose(r, int(o["index"]))
					break
		RunProgress.PHASE_SHOP:
			r.leave_node()
		RunProgress.PHASE_REST:
			var rv: Dictionary = RunShop.rest_view(r)
			if rv["options"][0]["available"]:
				RunShop.rest_choose(r, RunShop.REST_TICKET)
			else:
				RunShop.rest_choose(r, RunShop.REST_DRILL, {"deck_indices": [0]})
		RunProgress.PHASE_MATCH:
			r.record_result(result)
	_skip_offers(r)


func test_run_two_map_shape_links_and_terrain() -> void:
	var cfg: RunConfig = _config()
	for s: int in 12:
		var m: RunMap = RunMap.generate(cfg, 100 + s, false)
		assert_eq(m.step_nodes(0).size(), 1, "one F1")
		assert_eq(m.step_nodes(8)[0]["type"], RunMap.TYPE_BOSS, "the boss on step 9")
		var counts: Dictionary = {}
		for n: Dictionary in m.nodes:
			counts[n["type"]] = int(counts.get(n["type"], 0)) + 1
			if int(n["step"]) < 8:
				assert_true(not (n["links"] as Array).is_empty(), "%s leads on" % n["id"])
			for l: StringName in n["links"]:
				assert_eq(int(m.node(l)["step"]), int(n["step"]) + 1, "links go one step on")
			if n["type"] in RunMap.FIGHT_TYPES:
				var f: Dictionary = n["fight"]
				var tc: int = TerrainRules.count_of(f["terrain"])
				if bool(f["boss"]):
					assert_eq(tc, 0, "the boss has no Terrain")
				elif bool(f["elite"]):
					assert_eq(tc, 2, "elites: 2 Terrains")
				else:
					var want: Array = [[1], [1], [1, 2], [2]][int(f["ladder"]) - 1]
					assert_true(tc in want, "%s: %d Terrain" % [f["label"], tc])
				if int(f["mode"]) != DataEnums.GameMode.ZONE_CONTROL:
					assert_false(TerrainRules.HOT_ZONE in f["terrain"], "no Hot Zone in Firefight")
		assert_eq(counts[RunMap.TYPE_ELITE], 2, "two optional elites")
		assert_eq(int(counts[RunMap.TYPE_FIGHT]), 7, "F1, 2x F2, 2x F3, 2x F4")
		var evs: Array = m.nodes.filter(func(n: Dictionary) -> bool: return n["type"] == RunMap.TYPE_EVENT).map(
				func(n: Dictionary) -> StringName: return n["event"])
		for e: StringName in evs:
			assert_eq(evs.count(e), 1, "events without repeats")
	var a: RunMap = RunMap.generate(cfg, 5, false)
	var b: RunMap = RunMap.generate(cfg, 5, false)
	assert_eq(a.to_dict(), b.to_dict(), "seeded: the same map")


func test_first_run_map_is_fixed_with_one_fork() -> void:
	var m: RunMap = RunMap.generate(_config(), SEED, true)
	var types: Array = []
	for step: int in RunMap.STEPS:
		types.append(m.step_nodes(step).map(func(n: Dictionary) -> StringName: return n["type"]))
	assert_eq(types, [[&"fight"], [&"event"], [&"fight"], [&"elite", &"rest"], [&"fight"], [&"shop"], [&"fight"], [&"rest"], [&"boss"]],
			"F1 - Audit - F2 - Elite|Rest - F3 - Shop - F4 - Rest - Boss")
	assert_eq(m.step_nodes(1)[0]["event"], &"audit", "Quartermaster's Audit")
	var tc: Array = []
	for step: int in [0, 2, 4, 6]:
		tc.append(TerrainRules.count_of(m.step_nodes(step)[0]["fight"]["terrain"]))
	assert_eq(tc, [0, 0, 1, 1], "no Terrain before F3, then 1")
	assert_eq(TerrainRules.count_of(m.step_nodes(3)[0]["fight"]["terrain"]), 1, "Elite I: 1")


func test_flow_fight_offers_req_and_the_map() -> void:
	var r: RunProgress = _run()
	assert_eq(r.phase, RunProgress.PHASE_LOADOUT, "loadout first")
	assert_eq(r.move_to(&"s1_m"), "finish this step first", "no move before the run begins")
	r.begin()
	assert_eq(r.phase, RunProgress.PHASE_MAP, "begin: the map")
	assert_eq(r.map.reachable(), [&"s1_m"] as Array[StringName], "F1 only")
	assert_eq(r.move_to(&"s1_m"), "", "move")
	assert_eq(r.phase, RunProgress.PHASE_MATCH, "a fight")
	assert_eq(r.map_view()["nodes"].size(), r.map.nodes.size(), "map_view works outside the map phase (UI bug report)")
	assert_false(r.node_view(&"s1_m")["reachable"], "nothing reachable mid-fight")
	var m: MatchState = r.create_match()
	m.start_match()
	assert_eq(m.terrain, r.map.node(&"s1_m")["fight"]["terrain"], "the node's Terrain is on the board")
	assert_true(m.sides[0].kit_on, "run 2+: the Operator kit from F1")
	var res: Dictionary = r.record_result(&"player")
	assert_eq([res["req_gained"], r.req], [3, 3], "+3 REQ for a win")
	assert_eq(r.current_offer()["kind"], RewardOffers.KIND_SUPPLY_DROP, "a Supply Drop")
	assert_eq(int(r.current_offer()["rung"]), 1, "rung 1 after F1")
	_skip_offers(r)
	assert_eq(r.phase, RunProgress.PHASE_MAP, "back to the map")
	assert_eq(r.map.reachable().size(), 2, "the step-2 fork")
	assert_eq(r.map_view()["nodes"].size(), r.map.nodes.size(), "map_view lists every node")
	var row: Dictionary = r.node_view(r.map.reachable()[0])
	assert_true(row["reachable"] and row["gives"] != "", "node rows carry reach and the inspect lines")


func test_loss_draw_elite_and_boss() -> void:
	var r: RunProgress = _run()
	r.begin()
	_step(r)                                  # F1 won
	_step(r, RunMap.TYPE_SHOP)                # step 2
	var f2: Dictionary = _step(r, RunMap.TYPE_FIGHT, &"enemy")  # F2 lost
	assert_eq(r.tickets, 2, "a loss costs a ticket")
	assert_eq(r.history.back()["req_gained"], 1, "+1 REQ on a loss")
	assert_eq(r.map.fights_done(), 2, "the ladder moves on after a loss")
	assert_eq(f2["fight"]["ladder"], 2, "F2")
	# Elite I
	assert_eq(r.move_to(_of_type(r, RunMap.TYPE_ELITE)), "", "Elite I")
	var md: RunMatchData = r.current_match()
	assert_eq(md.enemy_armor_bonus, _config().matches[2].enemy_armor_bonus + 1, "the F3 crew at +1 Armor")
	var res: Dictionary = r.record_result(&"player")
	assert_eq(res["req_gained"], 5, "+5 REQ for an elite")
	var cache: Dictionary = r.current_offer()
	assert_true(bool(cache.get("elite_cache", false)), "an Elite Cache")
	assert_eq([int(cache["rung"]), int(cache["picks"]), (cache["options"] as Array).size()], [3, 2, 4], "one rung ahead, 2 of 4")
	var kinds: Array = r.pending_offers.map(func(o: Dictionary) -> StringName: return o["kind"])
	assert_true(RewardOffers.KIND_MUSTER_OUT in kinds, "Muster out after the cache")
	assert_false(RewardOffers.KIND_ATTACHMENT in kinds or RewardOffers.KIND_PERK in kinds, "no weapon level / Perk after an elite")
	_skip_offers(r)
	assert_eq(r.map.fights_done(), 2, "elites don't move the ladder")
	while r.map.current_step() < 7 and not r.is_over():
		_step(r)
	assert_eq(r.move_to(&"s9_m"), "", "the boss")
	assert_true(r.is_rival_match(), "the boss is the rival match")
	var bm: MatchState = r.create_match()
	assert_eq([bm.boss_rule, bm.boss_id], [&"reinforcements", &"meridian"], "the boss rule is on the match")
	assert_eq(TerrainRules.count_of(bm.terrain), 0, "no Terrain on the boss")
	r.record_result(&"player")
	assert_true(r.is_over() and r.is_victory(), "beating the boss wins the run")


func _of_type(r: RunProgress, type: StringName) -> StringName:
	for id: StringName in r.map.reachable():
		if r.map.node(id)["type"] == type:
			return id
	return &""


func test_first_run_kit_switches_on_at_f2() -> void:
	var r: RunProgress = _run(true)
	r.begin()
	r.move_to(&"s1_m")
	assert_false(r.player_setup().operator_kit, "F1: no Operator kit (new player M1 unchanged)")
	r.record_result(&"player")
	_skip_offers(r)
	_step(r)  # the Audit
	r.move_to(&"s3_m")
	assert_true(r.player_setup().operator_kit, "F2: the kit is on")


func test_modifiers() -> void:
	var r: RunProgress = _run(false, [RunModifiers.HARDCORE, RunModifiers.HOT_GROUND, RunModifiers.VETERANS, RunModifiers.FOG])
	assert_eq([r.tickets, r.max_tickets()], [2, 2], "Hardcore: 2 tickets, max 2")
	assert_eq(r.threat(), 5, "Threat 3 + 0 + 1 + 1")
	var f1: Dictionary = r.map.node(&"s1_m")["fight"]
	assert_eq(TerrainRules.count_of(f1["terrain"]), 2, "Hot Ground: F1 gets 2")
	assert_eq(TerrainRules.count_of(r.map.node(&"s9_m")["fight"]["terrain"]), 1, "Hot Ground: the boss gets 1")
	var f4: Dictionary = r.map.step_nodes(6)[0]["fight"]
	assert_eq(int(f4["armor"]), 2, "F4: +1 map Armor, +1 Veteran Crews")
	r.begin()
	r.move_to(&"s1_m")
	assert_true(r.create_match().fog_of_war, "Fog of War on the match")
	var a: RunProgress = _run(false, [RunModifiers.AUSTERITY])
	a.begin()
	_step(a)
	_step(a)
	a.move_to(_of_type(a, RunMap.TYPE_FIGHT))
	a.record_result(&"player")
	assert_eq(int(a.current_offer()["picks"]), 1, "Austerity: take 1 card instead of 2")
	var fr: RunProgress = _run(true)
	assert_true(fr.set_modifiers([RunModifiers.HARDCORE]) != "", "the first run has no modifiers")
	var lk: RunProgress = _run()
	assert_true(lk.set_modifiers([RunModifiers.FOG], [RunModifiers.HARDCORE]) != "", "a locked modifier is refused")
	assert_eq(lk.set_modifiers([RunModifiers.HARDCORE], [RunModifiers.HARDCORE]), "", "an unlocked one")
	assert_eq(lk.tickets, 2, "set_modifiers applies Hardcore")


func test_save_v7_round_trip_each_map_phase() -> void:
	var r: RunProgress = _run(false, [RunModifiers.VETERANS], &"choir")
	r.begin()
	var checks: Array = []
	for i: int in 10:
		var d: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
		assert_eq(int(d["version"]), 7, "v7")
		var loaded: Dictionary = RunProgress.from_dict(_config(), d)
		assert_eq(loaded["error"], "", "loads (%s)" % r.phase)
		var l: RunProgress = loaded["run"]
		if l != null:
			assert_eq(l.map_view(), r.map_view(), "same map view (%s)" % r.phase)
			assert_eq([l.req, l.boss, l.modifiers, l.phase, l.shop], [r.req, r.boss, r.modifiers, r.phase, r.shop], "same run state")
		checks.append(r.phase)
		if r.phase == RunProgress.PHASE_MAP:
			var shop_id: StringName = _of_type(r, RunMap.TYPE_SHOP)
			r.move_to(shop_id if shop_id != &"" else r.map.reachable()[0])
		else:
			_resolve(r)
	assert_true(RunProgress.PHASE_SHOP in checks, "a shop was saved and loaded")


func test_v6_save_continues_on_a_first_run_map() -> void:
	var cfg: RunConfig = _config()
	var old: RunProgress = RunProgress.create(cfg, SEED)
	old.begin()
	old.record_result(&"player")
	_skip_offers(old)
	old.record_result(&"enemy")
	_skip_offers(old)
	assert_eq([old.phase, old.match_index], [RunProgress.PHASE_MATCH, 2], "a v6-style run before match 3")
	var d: Dictionary = JSON.parse_string(JSON.stringify(old.to_dict()))
	d["version"] = 6
	d.erase("v2")
	var plain: Dictionary = RunProgress.from_dict(cfg, d)
	assert_true(plain["run"] != null and (plain["run"] as RunProgress).map == null, "without the option: the old ladder")
	var res: Dictionary = RunProgress.from_dict(cfg, d, {"map": true})
	assert_eq(res["error"], "", "migrates")
	var r: RunProgress = res["run"]
	assert_true(r.map != null and r.first_run, "a first-run-shaped map")
	assert_eq(r.map.current, &"s5_m", "standing on F3")
	assert_eq(r.phase, RunProgress.PHASE_MATCH, "ready to play it")
	assert_eq(r.map.fights_done(), 2, "F1 and F2 done")
	assert_eq([r.tickets, r.deck.size()], [old.tickets, old.deck.size()], "tickets and deck kept")
	assert_eq(r.current_match().squad, cfg.matches[2].squad, "the F3 crew")
	r.record_result(&"player")
	_skip_offers(r)
	assert_eq(r.phase, RunProgress.PHASE_MAP, "then the map")
	assert_eq(r.map.reachable(), [&"s6_m"] as Array[StringName], "the first run's shop is next")


func test_bad_v7_saves_are_refused() -> void:
	var r: RunProgress = _run()
	r.begin()
	var d: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	var bad: Dictionary = d.duplicate(true)
	bad["v2"]["boss"] = "nobody"
	assert_true(RunProgress.from_dict(_config(), bad)["error"] != "", "unknown boss")
	var bad2: Dictionary = d.duplicate(true)
	bad2["v2"]["map"]["current"] = "nowhere"
	assert_true(RunProgress.from_dict(_config(), bad2)["error"] != "", "unknown current node")
	var bad3: Dictionary = d.duplicate(true)
	bad3.erase("v2")
	assert_true(RunProgress.from_dict(_config(), bad3)["error"] != "", "a map phase without a map")
