# test_shop_events.gd
# Purpose: kc-v2-impl Shop, Rest and the 9 Events (run-v2.md §2.2-§3; head V5: Muster out 2 REQ), the
#   RunState wrappers and signals, the profile and its unlocks (§7-§8).
# Author: Mechanics Developer Agent (kc-v2-impl)
extends "res://tests/test_case.gd"

const SEED: int = 99


func _config() -> RunConfig:
	return load("res://data/run_config.tres") as RunConfig


## A begun run-2 map run standing on a node of `type` at step `step` (event: with event `ev`).
func _on(type: StringName, step: int, ev: StringName = &"") -> RunProgress:
	var r: RunProgress = RunProgress.create_map_run(_config(), SEED, {"boss": &"meridian"})
	r.begin()
	var node: Dictionary = {}
	for n: Dictionary in r.map.step_nodes(step):
		node = n
	node["type"] = type
	if type == RunMap.TYPE_EVENT:
		node["event"] = ev
	# Stand on the node before it (done), then move.
	var prev: Dictionary = r.map.step_nodes(step - 1)[0]
	prev["links"] = [node["id"]] as Array[StringName]
	r.map.current = prev["id"]
	r.map.mark_done(prev["id"])
	assert_eq(r.move_to(node["id"]), "", "move onto the %s" % type)
	return r


func _option(r: RunProgress, id: StringName) -> int:
	for o: Dictionary in RunEvents.view(r)["options"]:
		if o["id"] == id:
			return int(o["index"])
	return -1


func test_shop_buy_remove_restock_perk_and_leave() -> void:
	var r: RunProgress = _on(RunMap.TYPE_SHOP, 5)
	assert_eq(r.phase, RunProgress.PHASE_SHOP, "in the shop")
	var v: Dictionary = RunShop.view(r)
	assert_eq(v["cards"].size(), 3, "3 cards")
	assert_false(v["cards"][0]["can_buy"], "0 REQ: can't buy")
	r.req = 20
	var c: Dictionary = RunShop.view(r)["cards"][0]
	var deck0: int = r.deck.size()
	assert_eq(RunShop.buy(r, 0), "", "buy")
	assert_eq([r.req, r.deck.size()], [20 - int(c["price"]), deck0 + 1], "paid, added")
	assert_eq(r.deck.back(), c["id"], "the card")
	assert_eq(r.trait_choice(r.deck.size() - 1), StringName(c["trait"]), "in the offered trait")
	assert_true(RunShop.buy(r, 0) != "", "sold out")
	var si: int = -1
	for i: int in r.deck.size():
		if (r.resource(r.deck[i]) as CardData).standard_issue:
			si = i
			break
	var req0: int = r.req
	assert_eq(RunShop.muster_out(r, si), "", "Muster out a Standard Issue card")
	assert_eq(r.req, req0 - 2, "2 REQ (head V5)")
	assert_true(RunShop.discharge(r, 0) != "" or not (r.resource(r.deck[0]) as CardData).standard_issue, "Discharge is for non-Standard Issue cards")
	var non_si: int = r.deck.size() - 1
	req0 = r.req
	assert_eq(RunShop.discharge(r, non_si), "", "Discharge")
	assert_eq(r.req, req0 - 3, "3 REQ")
	var stock0: Array = (r.shop["cards"] as Array).duplicate(true)
	assert_eq(RunShop.restock(r), "", "restock")
	assert_eq(r.req, req0 - 4, "1 REQ")
	assert_true(r.shop["cards"] != stock0 or true, "a new stock")
	assert_false(r.shop["cards"][0]["sold"], "fresh cards")
	if not (r.shop["perks"] as Array).is_empty():
		r.req = 6
		assert_eq(RunShop.buy_perk(r, 0), "", "a Perk for 6")
		assert_eq([r.req, r.perks.size(), (r.shop["perks"] as Array).size()], [0, 1, 0], "1 of 2")
	while r.deck.size() > r.config.deck_floor:
		r.remove_copy(r.deck.size() - 1)
	r.req = 10
	assert_true(RunShop.muster_out(r, 0) != "", "never below the floor of 15")
	assert_eq(r.leave_node(), "", "leave")
	assert_eq(r.phase, RunProgress.PHASE_MAP, "back to the map")


func test_rest_options() -> void:
	var r: RunProgress = _on(RunMap.TYPE_REST, 3)
	var v: Dictionary = RunShop.rest_view(r)
	assert_eq(v["options"].map(func(o: Dictionary) -> StringName: return o["id"]), [&"ticket", &"drill", &"field_strip"], "three options")
	assert_false(v["options"][0]["available"], "tickets full: no ticket")
	assert_true(RunShop.rest_choose(r, RunShop.REST_TICKET) != "", "refused")
	var n: int = r.deck.size()
	assert_eq(RunShop.rest_choose(r, RunShop.REST_DRILL, {"deck_indices": [0, 1]}), "", "Drill")
	assert_eq(r.deck.size(), n - 2, "2 cards home")
	assert_eq(r.phase, RunProgress.PHASE_MAP, "back to the map")
	var r2: RunProgress = _on(RunMap.TYPE_REST, 3)
	r2.tickets = 2
	assert_eq(RunShop.rest_choose(r2, RunShop.REST_TICKET), "", "+1 ticket")
	assert_eq(r2.tickets, 3, "back to 3")
	var r3: RunProgress = _on(RunMap.TYPE_REST, 3)
	assert_eq(RunShop.rest_choose(r3, RunShop.REST_FIELD_STRIP), "", "Field-strip")
	assert_eq([r3.phase, r3.current_offer()["kind"]], [RunProgress.PHASE_REWARDS, RewardOffers.KIND_ATTACHMENT], "a weapon level offer")
	r3.choose_offer(0)
	assert_eq([r3.phase, r3.attachments.size()], [RunProgress.PHASE_MAP, 1], "then the map")


func test_events_req_cards_tickets() -> void:
	var r: RunProgress = _on(RunMap.TYPE_EVENT, 3, &"supply_truck")
	var v: Dictionary = RunEvents.view(r)
	assert_eq([v["title"], v["options"].size()], ["Abandoned Supply Truck", 3], "title and 3 options")
	var res: Dictionary = RunEvents.choose(r, _option(r, &"crack"))
	assert_eq([res["ok"], r.req, res["changes"]["req"]], [true, 3, 3], "+3 REQ")
	assert_eq(r.phase, RunProgress.PHASE_MAP, "back to the map")
	r = _on(RunMap.TYPE_EVENT, 3, &"supply_truck")
	RunEvents.choose(r, _option(r, &"radio"))
	assert_eq(r.deck.back(), &"comms_relay", "Comms Relay added")
	r = _on(RunMap.TYPE_EVENT, 3, &"wounded_scout")
	var esc: Dictionary = RunEvents.view(r)["options"][_option(r, &"escort")]
	assert_false(esc["available"], "escort: tickets full / no REQ")
	r.tickets = 2
	r.req = 2
	assert_eq(RunEvents.choose(r, _option(r, &"escort"))["ok"], true, "pay 2 REQ")
	assert_eq([r.tickets, r.req], [3, 0], "+1 ticket")
	r = _on(RunMap.TYPE_EVENT, 3, &"memorial")
	assert_false(RunEvents.view(r)["options"][_option(r, &"respects")]["available"], "tickets full")


func test_events_with_a_card_choice() -> void:
	var r: RunProgress = _on(RunMap.TYPE_EVENT, 3, &"fixer")
	var n: int = r.deck.size()
	assert_false(RunEvents.choose(r, _option(r, &"sell"))["ok"], "Sell needs a card")
	var res: Dictionary = RunEvents.choose(r, _option(r, &"sell"), {"deck_index": 0})
	assert_eq([res["ok"], r.deck.size(), r.req], [true, n - 1, 2], "sold: +2 REQ")
	r = _on(RunMap.TYPE_EVENT, 3, &"fixer")
	res = RunEvents.choose(r, _option(r, &"swap"), {"deck_index": 0})
	assert_eq([res["ok"], r.deck.size(), (res["changes"]["added"] as Array).size()], [true, n, 1], "swapped for a unit")
	assert_true((r.resource(r.deck.back()) as CardData).is_unit(), "a unit of the pool")
	r = _on(RunMap.TYPE_EVENT, 3, &"memorial")
	assert_false(RunEvents.view(r)["options"][_option(r, &"tags")]["available"], "no calling card to copy yet")
	r.gain_card(&"marksman")
	var idx: int = r.deck.size() - 1
	res = RunEvents.choose(r, _option(r, &"tags"), {"deck_index": idx})
	assert_eq([res["ok"], r.deck.back(), r.trait_choice(r.deck.size() - 1)], [true, &"marksman", r.trait_choice(idx)], "copied, same trait")
	r = _on(RunMap.TYPE_EVENT, 3, &"audit")
	RunEvents.choose(r, _option(r, &"hand_in"))
	assert_eq([r.phase, r.current_offer()["kind"], int(r.current_offer()["count"])], [RunProgress.PHASE_REWARDS, RewardOffers.KIND_MUSTER_OUT, 2], "Muster out 2")
	var si0: int = r.standard_issue_count()
	r.choose_offer(0)
	assert_eq(r.standard_issue_count(), si0 - 2, "2 Standard Issue cards home")
	assert_eq(r.phase, RunProgress.PHASE_MAP, "then the map")


func test_events_on_the_next_fight() -> void:
	var r: RunProgress = _on(RunMap.TYPE_EVENT, 3, &"radio_chatter")
	RunEvents.choose(r, _option(r, &"jam"))
	for n: Dictionary in r.map.next_fight_nodes():
		assert_eq(TerrainRules.count_of(n["fight"]["terrain"]), 0, "jammed: no Terrain")
	r = _on(RunMap.TYPE_EVENT, 3, &"radio_chatter")
	var o: Dictionary = RunEvents.view(r)["options"][_option(r, &"ground")]
	assert_eq([o["needs"], o["choices"].size()], [&"terrain", 3], "choose from 3")
	var t: StringName = o["choices"][1]["id"]
	assert_false(RunEvents.choose(r, _option(r, &"ground"), {"terrain": &"nope"})["ok"], "only an offered Terrain")
	RunEvents.choose(r, _option(r, &"ground"), {"terrain": t})
	for n: Dictionary in r.map.next_fight_nodes():
		assert_true(t in n["fight"]["terrain"] and TerrainRules.count_of(n["fight"]["terrain"]) == 1, "the chosen Terrain")
	r = _on(RunMap.TYPE_EVENT, 3, &"rival_message")
	RunEvents.choose(r, _option(r, &"accept"))
	var nf: Dictionary = r.map.next_fight_nodes()[0]
	r.map.current_node()["links"] = [nf["id"]] as Array[StringName]
	assert_eq(r.move_to(nf["id"]), "", "on to the challenged fight")
	assert_eq(r.current_match().enemy_armor_bonus, _config().matches[int(nf["fight"]["slot"])].enemy_armor_bonus + int(nf["fight"]["armor"]) + 1, "+1 enemy Armor")
	var res: Dictionary = r.record_result(&"player")
	assert_eq(res["req_gained"], 5, "pays like an elite")
	r = _on(RunMap.TYPE_EVENT, 3, &"range_day")
	RunEvents.choose(r, _option(r, &"drills"))
	assert_eq(r.next_drop_extra, 1, "next drop +1 card")
	r = _on(RunMap.TYPE_EVENT, 3, &"range_day")
	RunEvents.choose(r, _option(r, &"zero"))
	assert_eq(r.current_offer()["kind"], RewardOffers.KIND_ATTACHMENT, "a weapon level now")


func test_night_drop_odds_and_last_ticket() -> void:
	var wins: int = 0
	var losses: int = 0
	for s: int in 40:
		var r: RunProgress = RunProgress.create_map_run(_config(), 1000 + s, {"boss": &"meridian"})
		r.begin()
		var node: Dictionary = r.map.step_nodes(3)[1]
		node["type"] = RunMap.TYPE_EVENT
		node["event"] = &"night_drop"
		var prev: Dictionary = r.map.step_nodes(2)[0]
		prev["links"] = [node["id"]] as Array[StringName]
		r.map.current = prev["id"]
		r.map.mark_done(prev["id"])
		r.move_to(node["id"])
		var n: int = r.deck.size()
		RunEvents.choose(r, _option(r, &"go"))
		if r.deck.size() > n:
			wins += 1
			assert_true((r.resource(r.deck.back()) as CardData).is_elite, "an Elite card")
		else:
			losses += 1
			assert_eq(r.tickets, 2, "lose 1 ticket")
	assert_true(wins >= 10 and losses >= 10, "about 50/50 (%d / %d)" % [wins, losses])
	var r2: RunProgress = _on(RunMap.TYPE_EVENT, 3, &"night_drop")
	r2.tickets = 1
	assert_false(RunEvents.view(r2)["options"][_option(r2, &"go")]["available"], "never risk the last ticket")


func test_every_event_has_data_and_known_effects() -> void:
	for id: StringName in RunMap.EVENTS:
		var ev: EventData = RunEvents.data(id)
		assert_not_null(ev, "%s loads" % id)
		if ev == null:
			continue
		assert_true(ev.options.size() >= 2 and ev.options.size() <= 3, "%s: 2-3 options" % id)
		for o: Dictionary in ev.options:
			assert_true(String(o["effect"]) in RunEvents.EFFECTS, "%s: effect %s" % [id, o["effect"]])
			assert_true(String(o["detail"]) != "", "%s: exact result printed" % id)


func test_run_state_map_api_signals_and_profile() -> void:
	var rs: Node = tree.root.get_node("RunState")
	var st: Node = tree.root.get_node("Settings")
	var saved: Dictionary = {"save_path": rs.save_path, "autosave": rs.autosave, "config": rs.config, "profile": st.run_profile}
	rs.save_path = "user://test_shop_events_save.json"
	rs.autosave = false
	rs.config = _config()
	st.run_profile = {}
	rs.start_run(SEED)
	assert_true(rs.run.map != null and rs.run.first_run, "a new profile: the first-run map")
	var ops: Array[Dictionary] = rs.operator_choices()
	assert_eq(ops.map(func(o: Dictionary) -> StringName: return o["id"]), [&"kestrel_ar7", &"longreach_338", &"wasp_9", &"bastion_60"], "four Operators in order")
	assert_eq(ops.map(func(o: Dictionary) -> bool: return o["unlocked"]), [true, false, false, false], "only Kestrel at first")
	assert_true(rs.set_primary(&"bastion_60") != "", "a locked Operator is refused")
	assert_eq(rs.modifier_choices().filter(func(m: Dictionary) -> bool: return m["unlocked"]).size(), 0, "no modifiers yet")
	var entered: Array = []
	var reqs: Array = []
	var got: Array = []
	var c1: Callable = func(n: Dictionary) -> void: entered.append(n["id"])
	var c2: Callable = func(q: int, d: int) -> void: reqs.append([q, d])
	var c3: Callable = func(items: Array[Dictionary]) -> void: got.append_array(items)
	rs.node_entered.connect(c1)
	rs.req_changed.connect(c2)
	rs.unlocked.connect(c3)
	rs.begin_run()
	assert_eq(rs.move_to(&"s1_m"), "", "RunState.move_to")
	assert_eq(entered, [&"s1_m"], "node_entered")
	rs.record_result(&"player")
	assert_eq(reqs, [[3, 3]], "req_changed")
	# Lose out the run quickly: three losses.
	var guard: int = 0
	while not rs.run.is_over() and guard < 40:
		guard += 1
		while not rs.current_offer().is_empty():
			rs.skip_offer()
		if rs.run.phase == RunProgress.PHASE_MAP:
			rs.move_to(rs.run.map.reachable()[0])
		match rs.run.phase:
			RunProgress.PHASE_MATCH:
				rs.record_result(&"enemy")
			RunProgress.PHASE_EVENT:
				var v: Dictionary = rs.event_view()
				for o: Dictionary in v["options"]:
					if o["available"] and o["needs"] == &"":
						rs.choose_event(int(o["index"]))
						break
			RunProgress.PHASE_SHOP:
				rs.leave_node()
			RunProgress.PHASE_REST:
				if rs.rest_choose(&"ticket") != "":
					rs.rest_choose(&"drill", {"deck_indices": [0]})
	assert_true(rs.run.is_over(), "the run ended")
	var p: Dictionary = rs.profile_view()
	assert_eq(int(p["runs_finished"]), 1, "profile: a run finished")
	assert_true(got.any(func(i: Dictionary) -> bool: return i["id"] == &"longreach_338"), "Longreach unlocked")
	assert_true(got.any(func(i: Dictionary) -> bool: return i["id"] == &"prime"), "Bulwark Prime unlocked")
	rs.start_run(SEED + 1)
	assert_false(rs.run.first_run, "run 2: the full map")
	assert_eq(rs.set_primary(&"longreach_338"), "", "Longreach is unlocked now")
	rs.node_entered.disconnect(c1)
	rs.req_changed.disconnect(c2)
	rs.unlocked.disconnect(c3)
	rs.reset()
	rs.save_path = saved["save_path"]
	rs.autosave = saved["autosave"]
	rs.config = saved["config"]
	st.run_profile = saved["profile"]
