# test_run_synergy.gd
# Purpose: kc-syn-impl run layer (synergy-system.md §5): the starter and rewards (kc-no-training:
#   no copy levels, every copy plays its full chassis), the main trait and the on-trait Supply Drop
#   slot, Doctrine, Retire (4th Supply Drop option, Regroup after a loss, the 15-card floor, the
#   Honor Roll), offer refresh, the engine summary / deck view hooks, save round trips and version 1
#   migration, and RunState.retire_card. (Promotion was removed by kc-no-training.)
# Author: Mechanics Developer Agent (kc-syn-impl)
extends "res://tests/test_case.gd"

const SEED: int = 777


## kc-onboard: these tests pin the kc-syn / kc-art-traits mechanics on the old kc-syn starter with
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


func test_starter_and_rewards_play_their_full_chassis() -> void:
	var r: RunProgress = _run(false)
	assert_eq(r.deck.size(), 20, "20 cards")
	assert_false("deck_levels" in r, "kc-no-training: no copy levels")
	var s: SideSetup = r.player_setup()
	assert_eq(s.deck_traits.size(), 20, "one trait entry per copy goes into the match")
	var m: MatchState = r.create_match()
	m.start_match()
	var all: Array[RulesCard] = []
	all.append_array(m.sides[0].hand)
	all.append_array(m.sides[0].deck)
	var pm: RulesCard = all.filter(func(rc: RulesCard) -> bool: return rc.card.id == &"point_man")[0]
	var u: RulesUnit = m.create_unit(0, pm.card, pm.uid, pm.chosen_trait)
	assert_true(u.first_shot, "a starter Point Man has First Shot from the start")
	r.record_result(&"player")
	assert_eq(r.current_offer()["kind"], RewardOffers.KIND_SUPPLY_DROP, "Supply Drop")
	assert_false(r.current_offer().has("retire"), "no Retire option with synergy_offers off")
	var id: StringName = r.current_offer()["options"][0]
	assert_eq(r.choose_offer(0), "", "take it")
	assert_eq(r.deck.back(), id, "the reward card is in the deck")
	assert_eq(_kinds(r), [RewardOffers.KIND_ATTACHMENT], "synergy offers off: no Doctrine")


func test_main_trait_and_the_on_trait_slot() -> void:
	# Starts from the shipped Standard Issue deck (no trait at all) with the ladder off.
	var plain: RunConfig = (load("res://data/run_config.tres") as RunConfig).duplicate() as RunConfig
	plain.synergy_offers = false
	plain.reward_rungs = PackedInt32Array()
	var r: RunProgress = RunProgress.create(plain, SEED)
	r.begin()
	assert_eq(r.main_trait(), &"", "Standard Issue only: no main trait")
	r.deck.append(&"gunner")
	assert_eq(r.main_trait(), &"heavy", "one Gunner")
	r.deck.append(&"breacher")
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
	assert_eq(r.main_trait(), &"vanguard", "the starter's own traits count (mostly Vanguard)")
	_skip_all(r)
	r.record_result(&"player")
	assert_false(RewardOffers.KIND_DOCTRINE in _kinds(r), "only once")


func test_no_promotion_after_any_match() -> void:
	var r: RunProgress = _run()
	for n: int in 4:
		if r.is_over():
			break
		r.record_result(&"player")
		assert_false(_kinds(r).any(func(k: StringName) -> bool: return String(k) == "promotion"), "no Promotion after M%d" % (n + 1))
		_skip_all(r)


func test_retire_floor_and_honor_roll() -> void:
	var r: RunProgress = _run()
	r.record_result(&"player")
	var drop: Dictionary = r.current_offer()
	assert_true(drop.get("retire", false), "Retire is the 4th option")
	var opts: Array[Dictionary] = r.retire_options()
	assert_false(opts[0].has("level") or opts[0].has("twin_index"), "rows carry no level / twin")
	assert_true(int(opts[0]["cost"]) <= 1, "1-cost cards first")
	var pm: int = -1
	for j: int in opts.size():
		if opts[j]["id"] == &"point_man":
			pm = j
	var before: int = r.deck.size()
	assert_eq(r.retire_card(pm), "", "retire a Point Man instead of a card")
	assert_eq(r.deck.size(), before - 1, "one card fewer")
	assert_eq(r.honor_roll.size(), 1, "Honor Roll")
	assert_eq([r.honor_roll[0]["id"], r.honor_roll[0].has("level")], [&"point_man", false], "Honor Roll entry (no level)")
	assert_true(r.current_offer().get("kind", &"") != RewardOffers.KIND_SUPPLY_DROP, "the Supply Drop is resolved")
	# Floor: never below 15.
	while r.deck.size() > r.config.deck_floor:
		r.deck.pop_back()
	assert_false(r.can_retire(), "at the floor")
	assert_true(r.retire_options().is_empty(), "no Retire choices at the floor")
	_skip_all(r)
	r.record_result(&"enemy")
	assert_false(RewardOffers.KIND_REGROUP in _kinds(r), "no Regroup at the floor")
	_skip_all(r)
	r.record_result(&"player")
	if r.current_offer().get("kind", &"") == RewardOffers.KIND_SUPPLY_DROP:
		assert_eq(r.retire_card(0), "no Muster out option 0", "Retire refused at the floor")


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
	assert_eq(r.retire_card(0), "this offer has no Muster out option" if not r.current_offer().is_empty() else "no offer to choose from", "Retire only on a Supply Drop / Regroup")
	assert_false(offer.has("levels"), "options carry no levels")


func test_offers_refresh_when_they_become_current() -> void:
	var r: RunProgress = _run()
	r.record_result(&"enemy")
	assert_eq(r.current_offer()["kind"], RewardOffers.KIND_REGROUP, "loss: Regroup")
	assert_true(&"gunner" in r.current_offer()["options"], "the only Gunner can be retired")
	# A Supply Drop in front of the Regroup: retiring the only Gunner there removes it from the Regroup.
	r.pending_offers.push_front({"kind": RewardOffers.KIND_SUPPLY_DROP, "match": 1, "options": [&"breacher"] as Array[StringName],
			"picks": 1, "taken": [] as Array[Dictionary], "retire": true, "traits": [&"vanguard"] as Array[StringName],
			"arts": [&"breacher"] as Array[StringName]})
	var gi: int = -1
	var opts: Array[Dictionary] = r.retire_options()
	for j: int in opts.size():
		if opts[j]["id"] == &"gunner":
			gi = j
	assert_eq(r.retire_card(gi), "", "retire the Gunner")
	assert_eq(r.current_offer()["kind"], RewardOffers.KIND_REGROUP, "Regroup now")
	assert_false(&"gunner" in r.current_offer()["options"], "the Regroup lists the deck as it is now")


func test_engine_summary_and_deck_view() -> void:
	var r: RunProgress = _run()
	r.deck.append(&"brawler")
	var e: Dictionary = r.engine_summary()
	assert_eq(e["traits"], {&"vanguard": 8, &"specops": 2, &"undead": 3, &"heavy": 1}, "trait counts")
	assert_eq(e["keywords"], {}, "no neighbor keywords (kc-pos-cut)")
	assert_false(e.has("recruits"), "kc-no-training: no Recruit count")
	var dv: Array[Dictionary] = r.deck_view()
	assert_eq([dv.back()["trait"], dv.back().has("level"), dv.back().has("band"), dv.back().has("trains")], [&"undead", false, false, false], "deck view row (no level, band or Trains line)")
	assert_eq(dv[0]["keyword"], &"", "no neighbor keyword")


func test_save_round_trip_and_v1_migration() -> void:
	var r: RunProgress = _run()
	r.record_result(&"enemy")
	r.choose_offer(0)  # Regroup
	r.choose_offer(0)  # Doctrine
	var d: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	assert_eq(int(d["version"]), RunProgress.SAVE_VERSION, "current save version (6 since kc-no-training)")
	var back: Dictionary = RunProgress.from_dict(r.config, d)
	assert_eq(back["error"], "", "loads")
	var r2: RunProgress = back["run"]
	assert_eq([r2.deck, r2.deck_traits, r2.doctrine, r2.honor_roll.size()], [r.deck, r.deck_traits, r.doctrine, 1], "deck, traits, doctrine, Honor Roll")
	assert_eq(r2.pending_offers.size(), r.pending_offers.size(), "pending offers")
	assert_eq(JSON.stringify(r2.to_dict()), JSON.stringify(r.to_dict()), "identical after a round trip")
	# Regroup / doctrine offers survive too.
	var r3: RunProgress = _run()
	r3.record_result(&"enemy")
	var d3: Dictionary = JSON.parse_string(JSON.stringify(r3.to_dict()))
	var b3: Dictionary = RunProgress.from_dict(r3.config, d3)
	assert_eq(b3["error"], "", "Regroup / Doctrine offers load")
	assert_eq(JSON.stringify(b3["run"].to_dict()), JSON.stringify(r3.to_dict()), "same offers")
	# Version 1 (no traits, no doctrine): loads with every copy on its default trait.
	var v1: Dictionary = d.duplicate(true)
	v1["version"] = 1
	v1.erase("deck_traits")
	v1.erase("deck_arts")
	v1.erase("doctrine")
	v1.erase("honor_roll")
	v1.erase("last_pick_trait")
	var b1: Dictionary = RunProgress.from_dict(r.config, v1)
	assert_eq(b1["error"], "", "a version 1 save still loads")
	assert_eq((b1["run"] as RunProgress).deck_traits.size(), r.deck.size(), "v1: one trait per copy")
	var bad: Dictionary = d.duplicate(true)
	bad["deck_traits"] = ["vanguard"]
	assert_true(RunProgress.from_dict(r.config, bad)["error"] != "", "traits must match the deck")
	var bad2: Dictionary = d.duplicate(true)
	bad2["doctrine"] = "robots"
	assert_true(RunProgress.from_dict(r.config, bad2)["error"] != "", "unknown doctrine")


func test_run_state_retire_card() -> void:
	var rs: Node = tree.root.get_node("RunState")
	var saved_path: String = rs.save_path
	var saved_cfg: RunConfig = rs.config
	rs.save_path = "user://test_run_synergy_save.json"
	rs.run_map_enabled = false  # kc-v2-impl: the old ladder
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
	rs.run_map_enabled = true
