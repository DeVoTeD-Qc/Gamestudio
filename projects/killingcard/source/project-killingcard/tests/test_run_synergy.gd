# test_run_synergy.gd
# Purpose: kc-syn-impl run layer (synergy-system.md §5): the Recruit starter and Trained rewards,
#   levels into the match, the main trait and the on-trait Supply Drop slot, Doctrine, Promotion
#   (the ladder to Elite), Retire (4th Supply Drop option, Regroup after a loss, the 15-card
#   floor, twin training, the Honor Roll), offer refresh, the engine summary / deck view hooks,
#   save version 2 round trips and version 1 migration, and RunState.retire_card.
# Author: Mechanics Developer Agent (kc-syn-impl)
extends "res://tests/test_case.gd"

const SEED: int = 777


## kc-onboard: these tests pin the kc-syn / kc-art-traits mechanics on the old Recruit starter with
## the onboarding ladder off (tests/legacy_starter.gd); the shipped ladder is test_onboarding.gd's.
func _config(offers: bool = true) -> RunConfig:
	return preload("res://tests/legacy_starter.gd").config(offers)


func _run(offers: bool = true, seed_value: int = SEED) -> RunProgress:
	var r: RunProgress = RunProgress.create(_config(offers), seed_value)
	r.begin()
	return r


func _kinds(r: RunProgress) -> Array[StringName]:
	var out: Array[StringName] = []
	for o: Dictionary in r.pending_offers:
		out.append(o["kind"])
	return out


func _skip_all(r: RunProgress) -> void:
	while not r.current_offer().is_empty():
		r.skip_offer()


func _first(r: RunProgress, id: StringName) -> int:
	return r.deck.find(id)


func test_starter_is_recruits_and_rewards_come_trained() -> void:
	var r: RunProgress = _run(false)
	assert_eq(r.deck.size(), 20, "20 cards")
	assert_eq(r.deck_levels, r.deck.map(func(_id: StringName) -> int: return 0), "all Recruits")
	var s: SideSetup = r.player_setup()
	assert_eq(s.deck_levels.size(), 20, "levels go into the match")
	var m: MatchState = r.create_match()
	m.start_match()
	var all: Array[RulesCard] = []
	all.append_array(m.sides[0].hand)
	all.append_array(m.sides[0].deck)
	assert_true(all.all(func(rc: RulesCard) -> bool: return rc.level == 0), "the player's copies are Recruits in the match")
	r.record_result(&"player")
	assert_eq(r.current_offer()["kind"], RewardOffers.KIND_SUPPLY_DROP, "Supply Drop")
	assert_false(r.current_offer().has("retire"), "no Retire option with synergy_offers off")
	var id: StringName = r.current_offer()["options"][0]
	assert_eq(r.choose_offer(0), "", "take it")
	assert_eq([r.deck.back(), r.deck_levels.back()], [id, 1], "the reward card is Trained")
	assert_eq(_kinds(r), [RewardOffers.KIND_ATTACHMENT], "synergy offers off: no Doctrine")


func test_main_trait_and_the_on_trait_slot() -> void:
	# kc-onboard: Recruits carry their trait now, so this starts from the shipped Standard Issue deck
	# (no trait at all) with the ladder off.
	var plain: RunConfig = (load("res://data/run_config.tres") as RunConfig).duplicate() as RunConfig
	plain.synergy_offers = false
	plain.reward_rungs = PackedInt32Array()
	var r: RunProgress = RunProgress.create(plain, SEED)
	r.begin()
	assert_eq(r.main_trait(), &"", "Standard Issue only: no main trait")
	r.deck.append(&"gunner")
	r.deck_levels.append(1)
	assert_eq(r.main_trait(), &"heavy", "one Trained Gunner")
	r.deck.append(&"breacher")
	r.deck_levels.append(1)
	assert_eq(r.main_trait(), &"vanguard", "tie: TRAITS order without a last pick")
	r.last_pick_trait = &"heavy"
	assert_eq(r.main_trait(), &"heavy", "tie: the trait of the last pick")
	for n: int in 6:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 100 + n
		var picks: Array[StringName] = RewardOffers.supply_drop_on_trait(r.config, &"undead", rng)
		assert_eq(picks.size(), 3, "3 cards")
		assert_true((r.resource(picks[0]) as CardData).can_carry(&"undead"), "slot 1 can carry the trait: %s" % str(picks))
		assert_eq(picks.size(), {picks[0]: 0, picks[1]: 0, picks[2]: 0}.size(), "3 different designs")
	r.record_result(&"player")
	var drop: Dictionary = r.current_offer()
	assert_eq(drop.get("on_trait", &""), &"heavy", "the run's Supply Drop marks the on-trait slot")
	assert_true((r.resource(drop["options"][0]) as CardData).can_carry(&"heavy"), "and it is slot 1")
	assert_eq(drop["traits"][0], &"heavy", "slot 1 comes in the main trait's art (kc-art-traits)")


func test_doctrine_after_match_one_goes_into_the_match() -> void:
	var r: RunProgress = _run()
	r.record_result(&"enemy")
	assert_eq(_kinds(r), [RewardOffers.KIND_REGROUP, RewardOffers.KIND_DOCTRINE, RewardOffers.KIND_ATTACHMENT], "loss: Regroup, Doctrine, weapon level")
	r.skip_offer()
	var doc: Dictionary = r.current_offer()
	assert_eq(doc["options"].size(), 2, "2 emblems")
	assert_eq(doc["options"][0], &"vanguard", "best trait first (the starter's chassis are mostly Vanguard)")
	assert_true(doc["options"][1] in SynergyRules.TRAITS and doc["options"][1] != &"vanguard", "one other trait")
	assert_eq(r.choose_offer(1), "", "pick the other")
	assert_eq(r.doctrine, doc["options"][1], "doctrine set")
	assert_eq(r.player_setup().doctrine, r.doctrine, "into the match")
	assert_eq(r.main_trait(), &"vanguard", "kc-onboard: the Recruits' own traits count (mostly Vanguard)")
	_skip_all(r)
	r.record_result(&"player")
	assert_false(RewardOffers.KIND_DOCTRINE in _kinds(r), "only once")


func test_promotion_ladder_to_elite() -> void:
	var r: RunProgress = _run()
	r.record_result(&"player")
	_skip_all(r)
	r.record_result(&"player")
	assert_eq(_kinds(r), [RewardOffers.KIND_SUPPLY_DROP, RewardOffers.KIND_PROMOTION, RewardOffers.KIND_PERK], "after match 2")
	r.skip_offer()
	var promo: Dictionary = r.current_offer()
	assert_eq(promo["levels"].size(), promo["options"].size(), "levels parallel to options")
	assert_true(promo["levels"].all(func(lv: int) -> bool: return lv == 0), "Recruits first (all Recruits now)")
	assert_false(promo["options"].has(&"ammo_resupply") or promo["options"].has(&"hold_the_line"), "tactics are never promoted")
	var at: int = promo["options"].find(&"point_man")
	assert_eq(r.choose_offer(at), "", "promote a Point Man")
	var i: int = _first(r, &"point_man")
	assert_eq(r.level_of(i), 1, "Recruit -> Trained")
	for want: int in [2, 3]:
		var opts: Array[Dictionary] = r.promotion_options()
		var k: int = -1
		for j: int in opts.size():
			if opts[j]["index"] == i:
				k = j
		r.pending_offers.push_front({"kind": RewardOffers.KIND_PROMOTION, "match": 2, "options": [opts[k]["id"]] as Array[StringName], "levels": [opts[k]["level"]] as Array[int]})
		r.phase = RunProgress.PHASE_REWARDS
		assert_eq(r.choose_offer(0), "", "promote again")
		assert_eq(r.level_of(i), want, "level %d" % want)
	assert_false(r.promotion_options().any(func(o: Dictionary) -> bool: return o["index"] == i), "Elite is the top")
	var m: MatchState = r.create_match() if r.phase == RunProgress.PHASE_MATCH else null
	if m != null:
		m.start_match()
		var found: bool = false
		for rc: RulesCard in m.sides[0].hand + m.sides[0].deck:
			if rc.level == 3:
				found = true
		assert_true(found, "the Elite copy plays as Elite")


func test_retire_floor_twin_training_and_honor_roll() -> void:
	var r: RunProgress = _run()
	r.record_result(&"player")
	var drop: Dictionary = r.current_offer()
	assert_true(drop.get("retire", false), "Retire is the 4th option")
	var opts: Array[Dictionary] = r.retire_options()
	assert_eq(opts[0]["level"], 0, "Recruits first")
	var pm: int = -1
	for j: int in opts.size():
		if opts[j]["id"] == &"point_man":
			pm = j
	assert_eq(opts[pm]["twin_index"], -1, "kc-onboard: twin training is retired")
	var before: int = r.deck.size()
	assert_eq(r.retire_card(pm), "", "retire a Point Man instead of a card")
	assert_eq(r.deck.size(), before - 1, "one card fewer")
	var trained: int = 0
	for i: int in r.deck.size():
		if r.deck[i] == &"point_man" and r.level_of(i) == 1:
			trained += 1
	assert_eq(trained, 0, "no twin is trained")
	assert_eq(r.honor_roll.size(), 1, "Honor Roll")
	assert_eq([r.honor_roll[0]["id"], r.honor_roll[0]["trained_twin"]], [&"point_man", false], "Honor Roll entry")
	assert_true(r.current_offer().get("kind", &"") != RewardOffers.KIND_SUPPLY_DROP, "the Supply Drop is resolved")
	# A Recruit tactic has nothing to train; a lone Recruit has no twin.
	for o: Dictionary in r.retire_options():
		if o["id"] == &"ammo_resupply" or o["id"] == &"gunner":
			assert_eq(o["twin_index"], -1, "%s: no twin training" % o["id"])
	# Floor: never below 15.
	while r.deck.size() > r.config.deck_floor:
		r.deck.pop_back()
		r.deck_levels.pop_back()
	assert_false(r.can_retire(), "at the floor")
	assert_true(r.retire_options().is_empty(), "no Retire choices at the floor")
	_skip_all(r)
	r.record_result(&"enemy")
	assert_false(RewardOffers.KIND_REGROUP in _kinds(r), "no Regroup at the floor")
	_skip_all(r)
	r.record_result(&"player")
	if r.current_offer().get("kind", &"") == RewardOffers.KIND_SUPPLY_DROP:
		assert_eq(r.retire_card(0), "no Retire option 0", "Retire refused at the floor")


func test_regroup_after_a_loss_only() -> void:
	var r: RunProgress = _run()
	r.record_result(&"draw")
	assert_false(RewardOffers.KIND_REGROUP in _kinds(r), "a draw gives nothing")
	_skip_all(r)
	r.record_result(&"enemy")
	assert_eq(_kinds(r)[0], RewardOffers.KIND_REGROUP, "a loss: Regroup first")
	var offer: Dictionary = r.current_offer()
	var before: int = r.deck.size()
	assert_eq(r.choose_offer(0), "", "Retire the first option")
	assert_eq(r.deck.size(), before - 1, "removed")
	assert_eq(r.retire_card(0), "this offer has no Retire option" if not r.current_offer().is_empty() else "no offer to choose from", "Retire only on a Supply Drop / Regroup")
	assert_eq(offer["levels"][0], 0, "options carry levels")


func test_offers_refresh_when_they_become_current() -> void:
	var r: RunProgress = _run()
	r.record_result(&"player")
	_skip_all(r)
	r.record_result(&"player")
	# Supply Drop first, Promotion queued behind it: retiring the only Gunner removes it from the Promotion.
	var promo_before: Array = r.pending_offers[1]["options"].duplicate()
	assert_true(&"gunner" in promo_before, "Gunner promotable")
	var gi: int = -1
	var opts: Array[Dictionary] = r.retire_options()
	for j: int in opts.size():
		if opts[j]["id"] == &"gunner":
			gi = j
	assert_eq(r.retire_card(gi), "", "retire the Gunner")
	assert_eq(r.current_offer()["kind"], RewardOffers.KIND_PROMOTION, "Promotion now")
	assert_false(&"gunner" in r.current_offer()["options"], "the Promotion lists the deck as it is now")


func test_engine_summary_and_deck_view() -> void:
	var r: RunProgress = _run()
	r.deck.append(&"brawler")
	r.deck_levels.append(2)
	var e: Dictionary = r.engine_summary()
	assert_eq(e["traits"], {&"vanguard": 8, &"specops": 2, &"undead": 3, &"heavy": 1}, "trait counts (kc-onboard: Recruits count)")
	assert_eq(e["keywords"], {&"fireteam": 1}, "Trained keyword counts")
	assert_eq(e["recruits"], 16, "Recruits with something to train (tactics left out)")
	var dv: Array[Dictionary] = r.deck_view()
	assert_eq([dv.back()["level_name"], dv.back()["band"], dv.back()["trait"]], ["Veteran", &"forged", &"undead"], "deck view row")
	assert_eq([dv[0]["keyword"], dv[0]["band"]], [&"", &""], "a Recruit row")


func test_save_v2_round_trip_and_v1_migration() -> void:
	var r: RunProgress = _run()
	r.record_result(&"enemy")
	r.choose_offer(0)  # Regroup
	r.choose_offer(0)  # Doctrine
	r.deck_levels[0] = 3
	var d: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	assert_eq(int(d["version"]), RunProgress.SAVE_VERSION, "current save version (5 since kc-loadout-cut)")
	var back: Dictionary = RunProgress.from_dict(r.config, d)
	assert_eq(back["error"], "", "loads")
	var r2: RunProgress = back["run"]
	assert_eq([r2.deck, r2.deck_levels, r2.doctrine, r2.honor_roll.size()], [r.deck, r.deck_levels, r.doctrine, 1], "levels, doctrine, Honor Roll")
	assert_eq(r2.pending_offers.size(), r.pending_offers.size(), "pending offers")
	assert_eq(JSON.stringify(r2.to_dict()), JSON.stringify(r.to_dict()), "identical after a round trip")
	# Offers with levels / doctrine options survive too.
	var r3: RunProgress = _run()
	r3.record_result(&"enemy")
	var d3: Dictionary = JSON.parse_string(JSON.stringify(r3.to_dict()))
	var b3: Dictionary = RunProgress.from_dict(r3.config, d3)
	assert_eq(b3["error"], "", "Regroup / Doctrine offers load")
	assert_eq(JSON.stringify(b3["run"].to_dict()), JSON.stringify(r3.to_dict()), "same offers")
	# Version 1: no levels -> every copy Trained.
	var v1: Dictionary = d.duplicate(true)
	v1["version"] = 1
	v1.erase("deck_levels")
	v1.erase("doctrine")
	v1.erase("honor_roll")
	v1.erase("last_pick_trait")
	var b1: Dictionary = RunProgress.from_dict(r.config, v1)
	assert_eq(b1["error"], "", "a version 1 save still loads")
	assert_true(b1["run"].deck_levels.all(func(lv: int) -> bool: return lv == 1), "v1 decks are Trained")
	var bad: Dictionary = d.duplicate(true)
	bad["deck_levels"] = [0]
	assert_true(RunProgress.from_dict(r.config, bad)["error"] != "", "levels must match the deck")
	var bad2: Dictionary = d.duplicate(true)
	bad2["doctrine"] = "robots"
	assert_true(RunProgress.from_dict(r.config, bad2)["error"] != "", "unknown doctrine")


func test_run_state_retire_card() -> void:
	var rs: Node = tree.root.get_node("RunState")
	var saved_path: String = rs.save_path
	var saved_cfg: RunConfig = rs.config
	rs.save_path = "user://test_run_synergy_save.json"
	rs.config = _config()
	rs.start_run(SEED)
	rs.begin_run()
	rs.record_result(&"player")
	var before: int = rs.run.deck.size()
	assert_eq(rs.retire_card(0), "", "RunState.retire_card")
	assert_eq(rs.run.deck.size(), before - 1, "retired")
	rs.abandon_run()
	rs.save_path = saved_path
	rs.config = saved_cfg
