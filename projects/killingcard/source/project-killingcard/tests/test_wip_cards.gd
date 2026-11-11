# test_wip_cards.gd
# Purpose: kc-wip-impl (documentation/design/wip-set.md §5.3). The studio head's 19 "Wip" cards and
#   the engine items they need: Suppress N, Agile, +Supply next round (GAIN_SUPPLY_NEXT_ROUND), Beam,
#   the AI's chosen-friendly buff (Premium Loadout), the Operator's Armor reset (E6), and the data:
#   card files, the Private ladder starter, the reward pool, the Duel pool, keyword and inspect texts.
# Author: Mechanics Developer Agent (kc-wip-impl)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const Glossary: GDScript = preload("res://scripts/ui/codex/glossary.gd")
const P: int = 0
const E: int = 1
const L: int = 0
const M: int = 1
const R: int = 2
const WIP: Array[String] = ["private_1", "private_2", "private_3", "private_4", "scout", "medic", "sharpshooter",
		"flag_bearer", "hacker", "kamikaze", "runner", "sniper", "juggernaut", "riot_shield", "fast_learner",
		"laser_gunner", "war_shout", "barrage", "premium_loadout"]
## wip-set.md §3.3 (the head's W4 (a): one home trait per card).
const TRAITS: Dictionary = {"scout": &"vanguard", "medic": &"undead", "sharpshooter": &"specops",
		"flag_bearer": &"vanguard", "hacker": &"specops", "kamikaze": &"heavy", "runner": &"specops",
		"sniper": &"specops", "juggernaut": &"heavy", "riot_shield": &"vanguard", "fast_learner": &"undead",
		"laser_gunner": &"heavy"}


func _card(key: String) -> CardData:
	return load("res://data/cards/kc_wip_%s.tres" % key) as CardData


func _u(id: String, fp: int, ar: int, kw: Dictionary = {}) -> CardData:
	return F.unit(id, fp, ar, F.W.NONE, kw)


## A started match where the player holds `cards` (in order) with plenty of Supply.
func _match_with_hand(cards: Array, enemy_cards: Array = []) -> MatchState:
	var m: MatchState = F.new_match(F.setup(cards), F.setup(enemy_cards))
	m.sides[P].supply = 10
	m.sides[E].supply = 10
	return m


func _uid_of(m: MatchState, side: int, card: CardData) -> int:
	for c: RulesCard in m.sides[side].hand:
		if c.card == card:
			return c.uid
	return -1


# =============================================================================
# Data
# =============================================================================

func test_the_nineteen_cards_load_and_validate() -> void:
	for key: String in WIP:
		var c: CardData = _card(key)
		assert_not_null(c, "kc_wip_%s exists" % key)
		if c == null:
			continue
		assert_eq(c.id, StringName("kc_wip_" + key), "id kc_wip_<name>")
		var v: DataValidator = DataValidator.new()
		c.validate(v)
		assert_eq(v.error_count(), 0, "%s validates: %s" % [c.id, str(v.issues)])
		assert_true(c.text.length() <= CardData.MAX_TEXT_LENGTH, "%s: one line of text" % c.id)
		assert_true(CardDB.has_card(c.id), "%s is in CardDB" % c.id)
	assert_true(CardDB.is_valid(), "CardDB still valid: %s" % str(CardDB.get_errors()))


func test_numbers_follow_the_heads_answers() -> void:
	# W2 (a): Private I 2/1, Private II 2/3; W3 (a): Kamikaze costs 2.
	var want: Dictionary = {"private_1": [1, 2, 1], "private_2": [2, 2, 3], "private_3": [3, 3, 3], "private_4": [4, 4, 4],
			"scout": [1, 0, 3], "medic": [2, 2, 3], "sharpshooter": [3, 3, 2], "flag_bearer": [4, 2, 2], "hacker": [2, 1, 1],
			"kamikaze": [2, 1, 1], "runner": [3, 2, 4], "sniper": [4, 5, 2], "juggernaut": [5, 4, 5], "riot_shield": [4, 1, 3],
			"fast_learner": [5, 3, 4], "laser_gunner": [5, 2, 2], "war_shout": [2, 0, 0], "barrage": [3, 0, 0],
			"premium_loadout": [1, 0, 0]}
	for key: String in want:
		var c: CardData = _card(key)
		assert_eq([c.cost, c.firepower, c.armor], want[key], "%s cost / FP / Armor" % key)


func test_privates_are_standard_issue_and_the_rest_carry_one_home_trait() -> void:
	for key: String in WIP:
		var c: CardData = _card(key)
		if key.begins_with("private_"):
			assert_true(c.standard_issue and not c.collectible, "%s is Standard Issue" % key)
			assert_eq([c.card_trait, c.trait_options.size(), c.keyword_names().size(), c.effects.size()], [&"", 0, 0, 0],
					"%s: plain" % key)
		elif c.is_unit():
			assert_true(c.collectible and not c.is_elite, "%s: collectible, not Elite" % key)
			assert_eq([c.card_trait, c.trait_options], [TRAITS[key], [TRAITS[key]] as Array[StringName]], "%s: home trait" % key)
		else:
			assert_eq(c.card_trait, &"", "%s: tactics have no trait" % key)
	assert_eq(_card("juggernaut").weapon_class, DataEnums.WeaponClass.LMG, "Juggernaut is the LMG (Pierce printed)")
	assert_eq(_card("laser_gunner").weapon_class, DataEnums.WeaponClass.NONE, "the Laser Gunner is not an LMG (no Pierce on a Beam)")
	assert_eq(_card("kamikaze").weapon_class, DataEnums.WeaponClass.NONE, "nor the Kamikaze")


func test_starter_is_the_private_ladder_and_the_old_one_stays_loadable() -> void:
	var cfg: RunConfig = CardDB.get_run_config()
	var n: Dictionary = {}
	for c: CardData in cfg.starter_deck:
		n[c.id] = int(n.get(c.id, 0)) + 1
	assert_eq(n, {&"kc_wip_private_1": 3, &"kc_wip_private_2": 3, &"kc_wip_private_3": 2, &"kc_wip_private_4": 1,
			&"ammo_resupply": 1}, "W2 (a): Private I x3, II x3, III x2, IV x1, Ammo Resupply")
	var legacy: Array = cfg.legacy_cards.map(func(c: CardData) -> StringName: return c.id)
	for id: StringName in [&"si_grunt", &"si_trooper", &"si_sergeant", &"si_armored"]:
		assert_true(id in legacy, "%s stays loadable (legacy_cards)" % id)
		assert_true(CardDB.has_card(id), "%s file kept" % id)


func test_the_fifteen_join_the_reward_pool_once_and_the_duel_pool() -> void:
	var cfg: RunConfig = CardDB.get_run_config()
	var pool: Dictionary = {}
	for c: CardData in cfg.reward_pool:
		pool[c.id] = int(pool.get(c.id, 0)) + 1
		assert_true(c.collectible and not c.standard_issue, "%s may be offered" % c.id)
	var duel: Array = DuelCollection.pool_cards().map(func(c: CardData) -> StringName: return c.id)
	for key: String in WIP:
		var id: StringName = StringName("kc_wip_" + key)
		if key.begins_with("private_"):
			assert_false(pool.has(id), "%s is never a reward" % id)
			assert_false(id in duel, "%s is not in the Duel pool" % id)
		else:
			assert_eq(int(pool.get(id, 0)), 1, "%s: one copy in the reward pool" % id)
			assert_true(id in duel, "%s is in the Duel Basic pool" % id)
	assert_true(RunConfig.in_rung(_card("runner"), 1), "units on rung 1")
	assert_false(RunConfig.in_rung(_card("war_shout"), 1), "tactics from rung 2")
	assert_true(RunConfig.in_rung(_card("war_shout"), 2), "tactics on rung 2")


func test_keyword_names_and_inspect_texts_in_plain_words() -> void:
	assert_eq(_card("riot_shield").keyword_names(), ["Cover 1", "Suppress 1"] as Array[String], "Riot Shield")
	assert_eq(CardDB.get_card(&"gunner").keyword_names(), ["Suppress 2", "Pierce"] as Array[String], "the Gunner is Suppress 2")
	assert_eq(CardDB.get_card(&"gunner").text, "Suppress 2. Pierce", "Gunner text")
	assert_eq(_card("runner").keyword_names(), ["Agile"] as Array[String], "Runner")
	assert_eq(_card("laser_gunner").keyword_names(), ["Beam"] as Array[String], "Laser Gunner")
	assert_eq(_card("fast_learner").keyword_names(), ["End of round"] as Array[String], "Fast Learner")
	assert_eq(_card("kamikaze").keyword_names(), ["On Down"] as Array[String], "Kamikaze")
	assert_eq(_card("flag_bearer").keyword_names(), ["On Deploy"] as Array[String], "Flag Bearer")
	# Every keyword the Wip cards carry has an inspector line (right click / long press) in plain words.
	var want: Dictionary = {"runner": &"agile", "laser_gunner": &"beam", "fast_learner": &"end_of_round",
			"riot_shield": &"suppress", "kamikaze": &"on_down", "flag_bearer": &"on_deploy", "hacker": &"on_deploy"}
	for key: String in want:
		var found: Dictionary = {}
		for k: Dictionary in CardInfo.keywords(_card(key)):
			if k["id"] == want[key]:
				found = k
		assert_false(found.is_empty(), "%s: inspector explains %s" % [key, want[key]])
		if not found.is_empty():
			assert_true(String(found["text"]).length() > 20, "%s: %s has a rule text" % [key, want[key]])
	var sup: Array[Dictionary] = CardInfo.keywords(_card("riot_shield")).filter(func(k: Dictionary) -> bool: return k["id"] == &"suppress")
	assert_eq([sup[0]["name"], String(sup[0]["text"]).contains("-1 FP")], ["Suppress 1", true], "Suppress N in the inspector")
	assert_true(String(CardInfo.keywords(_card("laser_gunner"))[0]["text"]).contains("your own units"), "Beam says it hits friends")
	# The Codex glossary lists the new words (it reads CardInfo.KEYWORD_RULES), each with an icon.
	var keys: Array = Glossary.entries().map(func(e: Dictionary) -> StringName: return e["key"])
	for k: StringName in [&"agile", &"beam", &"end_of_round", &"suppress"]:
		assert_true(k in keys, "glossary has %s" % k)
	# The card face (view dict) carries Suppress with its number.
	var view: Dictionary = CardInfo.view_dict(_card("riot_shield"))
	assert_true({"id": "suppress", "value": 1} in view["keywords"], "card face: Suppress 1")
	assert_eq(RevealFlags.keyword_flag("Suppress 1"), &"kw_suppress", "the first-play tip matches Suppress N")
	assert_eq(RevealFlags.keyword_flag("Agile"), &"kw_agile", "Agile has a first-play tip")


# =============================================================================
# Suppress N
# =============================================================================

func test_suppress_n_and_stacking() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, _card("riot_shield"), M)
	F.place(m, P, CardDB.get_card(&"gunner"), M)
	var foe: RulesUnit = F.place(m, E, _u("foe", 6, 30), M)
	m.firefight()
	var amounts: Array = F.events_of(m, RulesEvent.SUPPRESSED).map(func(e: Dictionary) -> int: return int(e["amount"]))
	amounts.sort()
	assert_eq(amounts, [1, 2], "Riot Shield Suppress 1, Gunner Suppress 2")
	var shot: Dictionary = F.events_of(m, RulesEvent.SHOT_FIRED).filter(func(e: Dictionary) -> bool: return int(e["shooter_uid"]) == foe.uid)[0]
	assert_eq(int(shot["damage"]), 6 - 3 - 1, "the front enemy fires at 6 - 3 FP into the Riot Shield's Cover 1")
	# Suppress 1 alone.
	var m2: MatchState = F.new_match()
	F.place(m2, P, _card("riot_shield"), L)
	var foe2: RulesUnit = F.place(m2, E, _u("foe", 4, 30), L)
	m2.firefight()
	var shot2: Dictionary = F.events_of(m2, RulesEvent.SHOT_FIRED).filter(func(e: Dictionary) -> bool: return int(e["shooter_uid"]) == foe2.uid)[0]
	assert_eq(int(shot2["damage"]), 4 - 1 - 1, "Suppress 1: -1 FP")
	# An Operator part keeps the shipped 2 unless it says otherwise.
	assert_eq(LoadoutItem.new().suppress_amount, 2, "default Suppress 2")
	assert_eq(CardData.new().suppress_amount, 2, "default Suppress 2 on cards (old saves)")


# =============================================================================
# Agile
# =============================================================================

func test_agile_order_rules_and_undo() -> void:
	var m: MatchState = F.new_match()
	var runner: RulesUnit = F.place(m, P, _card("runner"), L)
	var plain: RulesUnit = F.place(m, P, _u("plain", 1, 3), L)
	assert_eq(m.can_submit(P, RulesIntent.move_unit(runner.uid, R))["code"], &"not_adjacent", "adjacent only")
	assert_eq(m.can_submit(P, RulesIntent.move_unit(runner.uid, L))["code"], &"same_zone", "not its own column")
	assert_eq(m.can_submit(P, RulesIntent.move_unit(plain.uid, M))["code"], &"not_agile", "only Agile units")
	var supply: int = m.sides[P].supply
	assert_true(m.submit(P, RulesIntent.move_unit(runner.uid, M))["ok"], "Runner ordered to B")
	assert_eq(m.sides[P].supply, supply, "free")
	assert_eq(m.can_submit(P, RulesIntent.move_unit(runner.uid, M))["code"], &"already_moved", "once per round")
	assert_eq(m.projected_occupancy(P, M), 1, "counts for B's capacity")
	assert_eq(m.projected_occupancy(P, L), 1, "and leaves A")
	assert_eq(m.red_dots(E), PackedInt32Array([0, 1, 0]), "the enemy sees a red dot arriving in B")
	assert_true(m.undo_last(P)["ok"], "undo in Deploy")
	assert_eq(m.sides[P].hand.size(), 0, "undo gives nothing back to the hand")
	assert_true(m.submit(P, RulesIntent.move_unit(runner.uid, M))["ok"], "ordered again after the undo")
	F.place(m, P, _u("anchor", 0, 9), M)
	m.resolve_round()
	assert_eq(F.line_ids(m, P, M), [&"anchor", &"kc_wip_runner"] as Array[StringName], "moved at Reveal to the back of B")
	assert_eq(F.line_ids(m, P, L), [&"plain"] as Array[StringName], "left A")
	var ev: Array[Dictionary] = F.events_of(m, RulesEvent.AGILE_MOVED)
	assert_eq([ev.size(), ev[0]["moved"], ev[0]["from_zone"], ev[0]["zone"]], [1, true, &"left", &"mid"], "AGILE_MOVED")
	assert_eq(F.events_of(m, RulesEvent.UNIT_MOVED).size(), 1, "UNIT_MOVED for the board")
	# Next round it may move again.
	m.begin_round()
	assert_true(m.can_submit(P, RulesIntent.move_unit(runner.uid, L))["ok"], "a new round, a new order")


func test_agile_fizzles_when_full_and_trips_traps() -> void:
	var m: MatchState = F.new_match()
	var runner: RulesUnit = F.place(m, P, _card("runner"), L)
	for i: int in 3:
		F.place(m, P, _u("b%d" % i, 0, 9), M)
	assert_true(m.submit(P, RulesIntent.move_unit(runner.uid, M))["ok"], "room for one (projected)")
	F.place(m, P, _u("late", 0, 9), M)  # B fills up before Reveal
	m.resolve_round()
	assert_eq(runner.zone, L, "the move fizzles: it stays")
	var ev: Array[Dictionary] = F.events_of(m, RulesEvent.AGILE_MOVED)
	assert_eq([ev.size(), ev[0]["moved"]], [1, false], "AGILE_MOVED moved=false")
	# Tripwire in the destination.
	var m2: MatchState = F.new_match()
	var r2: RulesUnit = F.place(m2, P, _card("runner"), L)
	F.place_field(m2, E, CardDB.get_card(&"tripwire_charge"), M)
	assert_true(m2.submit(P, RulesIntent.move_unit(r2.uid, M))["ok"], "ordered into the trap")
	m2.resolve_round()
	var trips: Array[Dictionary] = F.events_of(m2, RulesEvent.EQUIPMENT_TRIGGERED)
	assert_eq([trips.size(), int(trips[0]["target_uid"]) if not trips.is_empty() else -1], [1, r2.uid], "the Tripwire goes off on the Runner")


func test_ai_offers_and_can_play_an_agile_move() -> void:
	var m: MatchState = F.new_match()
	var runner: RulesUnit = F.place(m, E, _card("runner"), L)
	F.place(m, E, _u("holder", 1, 9), L)
	F.place(m, P, _u("target", 1, 1), M)
	var planner: AiPlanner = AiPlanner.new()
	planner._begin(AiView.capture(m, E))
	var moves: Array = planner._candidates(planner._root_plan()).filter(func(c: Dictionary) -> bool: return c["kind"] == &"agile")
	assert_eq(moves.map(func(c: Dictionary) -> int: return int(c["dest_zone"])), [M], "the AI offers the Runner's move to B")
	var ai: AiPlayer = AiPlayer.new()
	var intents: Array[Dictionary] = ai.take_turn(m, E)
	var agile: Array = intents.filter(func(i: Dictionary) -> bool: return i["type"] == RulesIntent.MOVE_UNIT)
	assert_eq(agile.size(), 1, "the AI moves its Runner onto the lone 1-Armor enemy (A stays held)")
	assert_true(ai.last_rejected.is_empty(), "nothing refused: %s" % str(ai.last_rejected))
	assert_eq(int(agile[0]["uid"]) if not agile.is_empty() else -1, runner.uid, "its Runner")


# =============================================================================
# Supply next round (the Hacker)
# =============================================================================

func test_hacker_gives_supply_next_round_only_and_stacks() -> void:
	var hacker: CardData = _card("hacker")
	var m: MatchState = _match_with_hand([hacker, hacker])
	var uids: Array[int] = []
	for c: RulesCard in m.sides[P].hand:
		uids.append(c.uid)
	assert_true(m.submit(P, RulesIntent.play_card(uids[0], L))["ok"], "Hacker A")
	assert_true(m.submit(P, RulesIntent.play_card(uids[1], M))["ok"], "Hacker B")
	m.resolve_round()
	assert_eq(m.terrain_supply_next[P], 2, "two Hackers stack")
	m.begin_round()
	var gained: Dictionary = F.events_of(m, RulesEvent.SUPPLY_GAINED).filter(func(e: Dictionary) -> bool: return e["side"] == &"player").back()
	assert_eq([m.sides[P].supply, int(gained["extra"])], [m.config.supply_for_round(2) + 2, 2], "round 2: +2, shown as extra")
	m.resolve_round()
	m.begin_round()
	assert_eq(m.sides[P].supply, m.config.supply_for_round(3), "round 3: back to normal")


func test_hacker_supply_can_pass_the_cap_and_needs_the_arrival() -> void:
	var m: MatchState = _match_with_hand([_card("hacker")])
	assert_true(m.submit(P, RulesIntent.play_card(m.sides[P].hand[0].uid, L))["ok"], "Hacker")
	m.resolve_round()
	m.round_number = 9
	m.begin_round()
	assert_eq(m.sides[P].supply, m.config.supply_cap + 1, "over the cap for that round")
	# A Hacker whose column is full at Reveal goes back to hand and gives nothing.
	var m2: MatchState = _match_with_hand([_card("hacker")])
	assert_true(m2.submit(P, RulesIntent.play_card(m2.sides[P].hand[0].uid, L))["ok"], "Hacker queued")
	for i: int in 4:
		F.place(m2, P, _u("f%d" % i, 0, 9), L)
	m2.resolve_round()
	assert_eq(m2.terrain_supply_next[P], 0, "no arrival, no Supply")


# =============================================================================
# Beam (the Laser Gunner)
# =============================================================================

func test_beam_hits_friends_ahead_and_every_enemy() -> void:
	var m: MatchState = F.new_match()
	var ahead: RulesUnit = F.place(m, P, _u("ahead", 0, 9), M)
	var laser: RulesUnit = F.place(m, P, _card("laser_gunner"), M)
	var behind: RulesUnit = F.place(m, P, _u("behind", 0, 9), M)
	var x: RulesUnit = F.place(m, E, _u("x", 0, 9, {"cover": 1}), M)
	var y: RulesUnit = F.place(m, E, _u("y", 0, 9), M)
	m.firefight()
	assert_eq([ahead.armor, behind.armor, laser.armor], [7, 9, 2], "your unit ahead takes 2, behind it none")
	assert_eq([x.armor, y.armor], [8, 7], "every enemy: 2 minus its Cover")
	var beams: Array[Dictionary] = F.events_of(m, RulesEvent.BEAM_FIRED)
	assert_eq(beams.size(), 1, "one beam (it fires once, in its own beat)")
	var hits: Array = beams[0]["hits"]
	assert_eq(hits.map(func(h: Dictionary) -> Array: return [int(h["uid"]), int(h["damage"]), bool(h["friendly"])]),
			[[ahead.uid, 2, true], [x.uid, 1, false], [y.uid, 2, false]], "hits in order, friends first")
	assert_eq(int(beams[0]["beat"]), 2, "its own beat (the units ahead traded first)")


func test_front_beam_hits_only_enemies_and_friendly_downs_give_no_credit() -> void:
	var m: MatchState = F.new_match()
	F.place(m, P, _card("laser_gunner"), L)
	var foe: RulesUnit = F.place(m, E, _u("foe", 0, 9), L)
	m.firefight()
	assert_eq(F.events_of(m, RulesEvent.BEAM_FIRED)[0]["hits"].size(), 1, "front: only the enemy")
	assert_eq(foe.armor, 7, "2 to it")
	# A friend in front at 2 Armor is downed by the beam: nobody gets credit.
	var m2: MatchState = F.new_match()
	var weak: RulesUnit = F.place(m2, P, _u("weak", 0, 2), M)
	F.place(m2, P, _card("laser_gunner"), M)
	F.place(m2, E, _u("foe", 0, 9), M)
	m2.firefight()
	assert_false(weak.is_alive(), "the friend in front went down")
	var el: Array[Dictionary] = F.events_of(m2, RulesEvent.UNIT_ELIMINATED)
	assert_eq([el.size(), el[0]["credit"], el[0]["by_side"]], [1, false, &"player"], "a friendly down: no credit")
	assert_eq([m2.sides[P].eliminations, m2.sides[E].eliminations], [0, 0], "nobody counts it")
	assert_eq(StreakTracker.counts_for_streak(m2, el[0]), false, "and it is no streak")


# =============================================================================
# On Deploy / On Down / end of round
# =============================================================================

func test_flag_bearer_buffs_the_column_on_arrival_for_good() -> void:
	var fb: CardData = _card("flag_bearer")
	var m: MatchState = _match_with_hand([fb], [])
	var there: RulesUnit = F.place(m, P, _u("there", 2, 2), M)
	var away: RulesUnit = F.place(m, P, _u("away", 2, 2), L)
	assert_true(m.submit(P, RulesIntent.play_card(_uid_of(m, P, fb), M))["ok"], "Flag Bearer to B")
	m.resolve_round()
	var bearer: RulesUnit = m.sides[P].line(M)[1]
	assert_eq([m.firepower_of(there), there.max_armor(m.round_number), there.armor], [3, 3, 3], "the unit there: +1/+1")
	assert_eq([m.firepower_of(bearer), bearer.armor], [3, 3], "itself included")
	assert_eq([m.firepower_of(away), away.armor], [2, 2], "other columns: no")
	m.begin_round()
	var late: RulesUnit = F.place(m, P, _u("late", 2, 2), M)
	assert_eq([m.firepower_of(there), m.firepower_of(late)], [3, 2], "it stays; later arrivals don't get it")


func test_operator_armor_resets_when_it_goes_down() -> void:
	# E6: a permanent +Armor (Flag Bearer) raised the Operator's base_max_armor for good; it resets on down.
	var fb: CardData = _card("flag_bearer")
	var m: MatchState = F.new_match(F.setup([fb], F.kestrel()), F.setup())
	m.sides[P].supply = 10
	var op: RulesUnit = F.place_operator(m, P, M)
	var kit: int = op.base_max_armor
	assert_true(m.submit(P, RulesIntent.play_card(_uid_of(m, P, fb), M))["ok"], "Flag Bearer next to the Operator")
	m.resolve_round()
	assert_eq([op.base_max_armor, m.firepower_of(op)], [kit + 1, op.base_firepower + 1], "the Operator got +1/+1")
	m.deal_damage(op, 99, {"side": E, "uid": -1, "source_id": &"test", "source_kind": MatchState.SRC_UNIT}, false)
	m.process_eliminations()
	assert_eq([op.base_max_armor, op.kit_max_armor, op.mods.size()], [kit, kit, 0], "back to its kit Armor, no FP buff")


func test_kamikaze_hits_every_enemy_here_when_it_goes_down() -> void:
	var m: MatchState = F.new_match()
	var kami: RulesUnit = F.place(m, P, _card("kamikaze"), M)
	var a: RulesUnit = F.place(m, E, _u("a", 0, 5), M)
	var b: RulesUnit = F.place(m, E, _u("b", 0, 5, {"cover": 1}), M)
	var c: RulesUnit = F.place(m, E, _u("c", 0, 5), M)
	var other: RulesUnit = F.place(m, E, _u("other", 0, 5), L)
	m.deal_damage(kami, 5, {"side": E, "uid": a.uid, "source_id": &"a", "source_kind": MatchState.SRC_UNIT})
	m.process_eliminations()
	assert_eq([a.armor, b.armor, c.armor, other.armor], [4, 5, 4, 5], "1 to each enemy here (Cover applies), none elsewhere")


func test_fast_learner_grows_every_round_including_its_first() -> void:
	var fl: CardData = _card("fast_learner")
	var m: MatchState = _match_with_hand([fl])
	assert_true(m.submit(P, RulesIntent.play_card(_uid_of(m, P, fl), R))["ok"], "Fast Learner")
	m.resolve_round()
	var u: RulesUnit = m.sides[P].line(R)[0]
	assert_eq([m.firepower_of(u), u.max_armor(m.round_number), u.armor], [4, 5, 5], "round 1: +1/+1 at the Score step")
	m.begin_round()
	m.deal_damage(u, 2, {"side": E, "uid": -1, "source_id": &"t", "source_kind": MatchState.SRC_UNIT}, false)
	m.resolve_round()
	assert_eq([m.firepower_of(u), u.max_armor(m.round_number), u.armor], [5, 6, 4], "round 2: +1/+1 again, the Armor point heals 1")


# =============================================================================
# Tactics: War Shout, Barrage, Premium Loadout
# =============================================================================

func test_war_shout_every_column_this_round_including_arrivals() -> void:
	var ws: CardData = _card("war_shout")
	var newbie: CardData = _u("newbie", 1, 3)
	var m: MatchState = _match_with_hand([ws, newbie])
	var a: RulesUnit = F.place(m, P, _u("a", 1, 3), L)
	var c: RulesUnit = F.place(m, P, _u("c", 1, 3), R)
	var foe: RulesUnit = F.place(m, E, _u("foe", 1, 30), L)
	assert_true(m.submit(P, RulesIntent.play_card(_uid_of(m, P, newbie), M))["ok"], "a unit arriving this Reveal")
	assert_true(m.submit(P, RulesIntent.play_card(_uid_of(m, P, ws)))["ok"], "War Shout needs no column")
	m.resolve_round()
	var buffed: Array = F.events_of(m, RulesEvent.EFFECT_APPLIED).filter(func(e: Dictionary) -> bool: return e["source_id"] == &"kc_wip_war_shout")
	assert_eq(buffed.size(), 3, "every unit of mine in every column, the new one too")
	assert_eq(30 - foe.armor, 3, "A's unit shot at 1 + 2")
	assert_eq([m.firepower_of(a), m.firepower_of(c)], [1, 1], "it ends with the round")


func test_barrage_hits_only_enemy_front_units() -> void:
	var b: CardData = _card("barrage")
	var m: MatchState = _match_with_hand([b])
	var f1: RulesUnit = F.place(m, E, _u("f1", 0, 5), L)
	var f2: RulesUnit = F.place(m, E, _u("f2", 0, 5), M)
	var back: RulesUnit = F.place(m, E, _u("back", 0, 5), M)
	var mine: RulesUnit = F.place(m, P, _u("mine", 0, 5), R)
	assert_true(m.submit(P, RulesIntent.play_card(_uid_of(m, P, b)))["ok"], "Barrage")
	m.reveal()
	assert_eq([f1.armor, f2.armor, back.armor, mine.armor], [4, 4, 5, 5], "each enemy front unit: 1")


func test_premium_loadout_is_permanent_on_a_chosen_unit() -> void:
	var pl: CardData = _card("premium_loadout")
	var m: MatchState = _match_with_hand([pl])
	var u: RulesUnit = F.place(m, P, _u("u", 2, 3), M)
	assert_eq(m.needs_unit_target(P, _uid_of(m, P, pl)), &"friendly", "it asks for one of your units")
	assert_true(m.submit(P, RulesIntent.play_card(_uid_of(m, P, pl), -1, u.uid))["ok"], "no column needed")
	m.resolve_round()
	m.begin_round()
	m.resolve_round()
	assert_eq([m.firepower_of(u), u.max_armor(m.round_number), u.armor], [3, 4, 4], "+1/+1 for good")


func test_ai_plays_premium_loadout_on_its_unit() -> void:
	var pl: CardData = _card("premium_loadout")
	var m: MatchState = F.new_match(F.setup(), F.setup([pl]))
	m.sides[E].supply = 1
	var mine: RulesUnit = F.place(m, E, _u("mine", 2, 2), M)
	F.place(m, P, _u("foe", 2, 2), M)
	var ai: AiPlayer = AiPlayer.new()
	var intents: Array[Dictionary] = ai.take_turn(m, E)
	assert_eq(intents.size(), 1, "the AI plays it (E5): %s / refused %s" % [str(intents), str(ai.last_rejected)])
	if intents.is_empty():
		return
	assert_eq(int(intents[0]["target_uid"]), mine.uid, "on its own unit")
	m.resolve_round()
	assert_eq([m.firepower_of(mine) if mine.is_alive() else 3, mine.max_armor(m.round_number)], [3, 3], "its unit got +1/+1")


func test_ai_records_carry_the_new_keywords() -> void:
	var m: MatchState = F.new_match()
	F.place(m, E, _card("riot_shield"), L)
	F.place(m, E, _card("laser_gunner"), M)
	F.place(m, E, _card("runner"), R)
	F.place(m, E, _card("kamikaze"), R)
	var v: AiView = AiView.capture(m, E)
	assert_eq([v.lines[AiView.ME][L][0]["suppress_amount"], v.lines[AiView.ME][M][0]["beam"], v.lines[AiView.ME][R][0]["agile"],
			v.lines[AiView.ME][R][1]["on_down_all"]], [1, true, true, 1], "Suppress 1, Beam, Agile, Kamikaze On Down")
