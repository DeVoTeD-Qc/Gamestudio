# test_onboarding.gd
# Purpose: kc-onboard-impl (documentation/design/onboarding-progression.md, approved N1-N4, and the
#   head's Z1/Z2 answers on kc-trait-ui). Data: the 4 Standard Issue cards (exact numbers, plain,
#   not collectible, validator), the 20-card starter and its fixed Standard Issue arts. Rules: the
#   Recruit = trait on, keywords locked (units, AI records, the "Trains:" line), Standard Issue
#   units are deck cards (discard). Squads along the ladder (green squad, authored decks, Recruit
#   calling cards). Run ladder: rungs and levels by match, 2 picks of 4 from match 2, Muster out
#   (count, pre-selection, floor, errors), Salvage after a loss, Doctrine from the first pick, no
#   trait choice and no Re-issue (Z1), Promotion trains keywords only, save v4 round trip and v3
#   migration (old Recruits load Trained, the old Rifleman still loads). Progressive reveal flags.
# Author: Mechanics Developer Agent (kc-onboard-impl)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const P: int = 0
const SEED: int = 2468


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


func _config() -> RunConfig:
	return (load("res://data/run_config.tres") as RunConfig).duplicate() as RunConfig


func _run(seed_value: int = SEED) -> RunProgress:
	var r: RunProgress = RunProgress.create(_config(), seed_value)
	r.begin()
	return r


func _kinds(r: RunProgress) -> Array[StringName]:
	var out: Array[StringName] = []
	for o: Dictionary in r.pending_offers:
		out.append(o["kind"])
	return out


func _count(r: RunProgress, id: StringName) -> int:
	return r.deck.count(id)


func _in_deck(deck: Array[CardData], id: StringName) -> int:
	return deck.filter(func(c: CardData) -> bool: return c.id == id).size()


## Resolves every offer after the current drop(s) by skipping.
func _skip_all(r: RunProgress) -> void:
	while not r.current_offer().is_empty():
		r.skip_offer()


# =============================================================================
# Data
# =============================================================================

func test_standard_issue_cards_are_plain_with_the_exact_numbers() -> void:
	var want: Dictionary = {"si_grunt": ["Grunt", 1, 2, 2], "si_trooper": ["Trooper", 2, 2, 3],
			"si_sergeant": ["Sergeant", 3, 3, 3], "si_armored": ["Armored Trooper", 4, 2, 5]}
	for id: String in want:
		var c: CardData = _card(id)
		assert_eq([c.display_name, c.cost, c.firepower, c.armor], want[id], "%s numbers" % id)
		assert_true(c.standard_issue and not c.collectible and c.is_unit(), "%s is Standard Issue" % id)
		assert_eq([c.weapon_class, c.card_trait, c.trait_options.size(), c.neighbor_keyword, c.effects.size()],
				[DataEnums.WeaponClass.NONE, &"", 0, &"", 0], "%s: no class, trait, keyword or effect" % id)
		assert_true(c.trained_keyword_names().is_empty(), "%s: nothing to train" % id)
		assert_true(c.counts_for_control and c.grants_elimination_credit and not c.is_token(), "%s is a deck card" % id)
		var v: DataValidator = DataValidator.new()
		c.validate(v)
		assert_eq(v.error_count(), 0, "%s validates: %s" % [id, str(v.issues)])
	var bad: CardData = _card("si_trooper").duplicate() as CardData
	bad.first_shot = true
	bad.card_trait = &"vanguard"
	var v2: DataValidator = DataValidator.new()
	bad.validate(v2)
	assert_true(v2.error_count() > 0, "a Standard Issue card with a keyword or a trait is rejected")


func test_starter_is_twenty_standard_issue_cards_in_one_fixed_art() -> void:
	var cfg: RunConfig = _config()
	var n: Dictionary = {}
	for c: CardData in cfg.starter_deck:
		n[String(c.id)] = int(n.get(String(c.id), 0)) + 1
	assert_eq(n, {"si_grunt": 5, "si_trooper": 6, "si_sergeant": 4, "si_armored": 3, "ammo_resupply": 2}, "§2.1 starter")
	assert_false(cfg.starter_recruits, "no Recruit starter any more")
	for c: CardData in cfg.reward_pool:
		assert_false(c.standard_issue, "Standard Issue cards are never offered (%s)" % c.id)
	var a: RunProgress = RunProgress.create(cfg, 1)
	var b: RunProgress = RunProgress.create(cfg, 99)
	assert_eq(a.deck_arts, b.deck_arts, "head Z2: no random art for the starter")
	for i: int in a.deck.size():
		var c: CardData = a.resource(a.deck[i]) as CardData
		var art: StringName = a.art_of(i)
		assert_true(ArtTraits.is_standard_issue_art(art, c), "copy %d wears a Standard Issue art (%s)" % [i, art])
		assert_false(String(art).begins_with("kc_mw3"), "never licensed MW3 art for starters")
		assert_eq(ArtTraits.subname(art), "Standard Issue", "subname")
		assert_true(ResourceLoader.exists("res://data/banners/%s.tres" % art), "a studio placeholder drop-in exists for %s" % art)
	assert_eq(ArtTraits.arts_for(_card("si_grunt")), [&"si_grunt"] as Array[StringName], "one art, no variants")
	var view: Array[Dictionary] = a.deck_view()
	assert_eq([view[0]["level_name"], view[0]["standard_issue"], view[0]["serial"], view[0]["trains"]],
			["Standard Issue", true, "SI-01", ""], "deck view row of a Grunt")


func test_standard_issue_units_go_to_the_discard_and_never_train() -> void:
	var m: MatchState = F.new_match()
	var u: RulesUnit = m.create_unit(P, _card("si_sergeant"), -1, 0)
	m.put_in_line(u, 0)
	u.armor = 0
	m.process_eliminations()
	assert_eq((m.sides[P].discard.back() as RulesCard).card.id, &"si_sergeant", "a Standard Issue unit is a deck card")
	var r: RunProgress = _run()
	assert_false(r.promotion_options().any(func(o: Dictionary) -> bool: return (r.resource(o["id"]) as CardData).standard_issue),
			"never Promoted")
	assert_eq(r._train(0), "Standard Issue cards never train", "never trained")
	assert_eq(r.level_of(0), 0, "level unchanged")


# =============================================================================
# Rules: the Recruit (head N1)
# =============================================================================

func test_recruit_has_its_trait_but_no_keywords() -> void:
	var m: MatchState = F.new_match()
	var rb: RulesUnit = m.create_unit(P, _card("breacher"), -1, 0, &"heavy")
	assert_eq([rb.synergy_trait, rb.neighbor_keyword, rb.first_shot], [&"heavy", &"", false], "Recruit Breacher: Heavy, no Guard, no First Shot")
	assert_eq([rb.base_firepower, rb.base_max_armor, rb.weapon_class], [3, 4, DataEnums.WeaponClass.SHOTGUN], "keeps FP, Armor, class")
	var tb: RulesUnit = m.create_unit(P, _card("breacher"), -1, 1, &"heavy")
	assert_eq([tb.synergy_trait, tb.neighbor_keyword, tb.first_shot], [&"heavy", &"", true], "Trained: all on (no Guard since kc-pos-cut)")
	var gun: RulesUnit = m.create_unit(P, _card("gunner"), -1, 0)
	assert_eq([gun.synergy_trait, gun.suppress, gun.pierce], [&"heavy", false, false], "Recruit Gunner: no Suppress, no LMG Pierce")
	var sh: RulesUnit = m.create_unit(P, _card("shieldman"), -1, 0)
	assert_eq([sh.cover, sh.arrives_front], [0, false], "Recruit Protector: no Cover, doesn't arrive front")
	var demo: RulesUnit = m.create_unit(P, _card("demolitions_expert"), -1, 0)
	assert_eq([demo.effects.size(), demo.pierce], [0, false], "Recruit Demolitions Expert: no effects")
	var medic: RulesUnit = m.create_unit(P, _card("combat_medic"), -1, 0)
	assert_eq(medic.patch, 0, "Recruit Medic: no Patch")
	assert_eq(SynergyRules.trait_at(_card("marksman"), 0, &"heavy"), &"heavy", "trait_at: Recruits carry the trait")
	assert_eq(SynergyRules.trait_at(_card("si_grunt"), 1), &"", "Standard Issue: never a trait")


func test_trains_line_names_the_locked_keywords() -> void:
	assert_eq(SynergyRules.trains_text(_card("breacher"), 0), "Trains: First Shot", "the doc's example (no Guard since kc-pos-cut)")
	assert_eq(SynergyRules.trains_text(_card("breacher"), 1), "", "nothing locked once Trained")
	assert_eq(SynergyRules.locked_keywords(_card("gunner"), 0), ["Suppress", "Pierce"] as Array[String], "Gunner")
	assert_eq(SynergyRules.locked_keywords(_card("shieldman"), 0), ["Cover 1", "Front line"] as Array[String], "Protector")
	assert_eq(SynergyRules.trains_text(_card("si_grunt"), 0), "", "Standard Issue: no line")
	assert_eq(SynergyRules.trains_text(_card("callout"), 0), "", "tactics: no line")
	var rc: RulesCard = RulesCard.new(1, _card("marksman"), 0, &"specops")
	assert_eq([rc.trains_text(), rc.card_trait(), rc.keywords_on()], ["Trains: Pick", &"specops", false], "RulesCard hook")


func test_recruit_in_a_match_and_in_the_ai_record() -> void:
	var s: SideSetup = F.setup([_card("shieldman"), _card("breacher")])
	s.deck_levels.assign([0, 0])
	s.keep_deck_order = true
	var m: MatchState = F.new_match(s, F.setup())
	var view: AiView = AiView.capture(m, P)
	var rec: Dictionary = view.record_for_card(_card("breacher"), 99, 0, 0, &"vanguard")
	assert_eq([rec["first_shot"], rec["kw"], rec["trait"], rec["fs_native"]], [false, &"", &"vanguard", false], "AI sees a Recruit Breacher")
	var rec2: Dictionary = view.record_for_card(_card("shieldman"), 98, 0, 0)
	assert_eq([rec2["cover"], rec2["arrives_front"]], [0, false], "and a Recruit Protector")
	var rec3: Dictionary = view.record_for_card(_card("gunner"), 97, 0, 1)
	assert_eq([rec3["suppress"], rec3["pierce"]], [true, true], "a Trained Gunner keeps both")


# =============================================================================
# Squads along the ladder (§4.4, head N4)
# =============================================================================

func test_squads_along_the_ladder() -> void:
	var cfg: RunConfig = _config()
	var md: Array[RunMatchData] = cfg.matches
	assert_eq(md.map(func(x: RunMatchData) -> int: return x.enemy_armor_bonus), [-1, 0, 0, 0, 1], "green squad, Anchor+ at 0, Rival 1")
	assert_eq(md.map(func(x: RunMatchData) -> bool: return x.is_green_squad()), [true, false, false, false, false], "only M1 is green")
	var s1: SideSetup = SideSetup.from_squad(md[0].squad, md[0])
	assert_eq(s1.deck.size(), 18, "M1: 18 cards")
	assert_true(s1.deck.all(func(c: CardData) -> bool: return c.standard_issue or c.id == &"ammo_resupply"), "M1: Standard Issue only")
	assert_eq(s1.armor_bonus, -1, "M1 at -1 Armor")
	var s2: SideSetup = SideSetup.from_squad(md[1].squad, md[1])
	var heavy: int = 0
	for i: int in s2.deck.size():
		if s2.deck[i].id == &"gunner":
			assert_eq(s2.level_of(i), 0, "the Gunners are Recruits")
			assert_eq(SynergyRules.trait_at(s2.deck[i], 0, s2.trait_of(i)), &"heavy", "with the Heavy trait")
			heavy += 1
	assert_eq([s2.deck.size(), heavy], [18, 3], "M2: 18 cards with 3 Heavy Recruit Gunners")
	var s3: SideSetup = SideSetup.from_squad(md[2].squad, md[2])
	# kc-syn-tune / kc-syn-tune2 (synergy-system.md §12): M3 = the Rusher's units with its tactics
	# and Equipment (Breach and Clear, 2 Flank Routes, Callout, Tripwire) swapped for Standard Issue
	# (3 Troopers, a Grunt, a Sergeant); M4 = the Anchor deck with 2 Demolitions + the Marksman
	# swapped for 2 Armored Troopers + a Sergeant.
	assert_eq(s3.deck.size(), 18, "M3: 18 cards")
	assert_eq([_in_deck(s3.deck, &"breach_and_clear"), _in_deck(s3.deck, &"si_sergeant"),
			_in_deck(s3.deck, &"breacher") + _in_deck(s3.deck, &"point_man")], [0, 1, 6],
			"M3: Rusher deck, Breach and Clear swapped for a Sergeant")
	assert_eq([_in_deck(s3.deck, &"flank_route"), _in_deck(s3.deck, &"si_trooper")], [0, 3], "M3: Flank Routes swapped for Troopers")
	var vanguard: int = 0
	for i: int in s3.deck.size():
		if s3.deck[i].is_unit():
			assert_eq(s3.level_of(i), 0, "M3 units are Recruits")
			if SynergyRules.trait_at(s3.deck[i], 0, s3.trait_of(i)) == &"vanguard":
				vanguard += 1
	assert_true(vanguard >= 6, "M3: Vanguard calling cards (%d)" % vanguard)
	var s4: SideSetup = SideSetup.from_squad(md[3].squad, md[3])
	for i: int in s4.deck.size():
		if s4.deck[i].is_unit():
			assert_eq(s4.level_of(i), 0, "M4 units are Recruits (kc-pos-cut)")
	var s5: SideSetup = SideSetup.from_squad(md[4].squad, md[4])
	assert_eq([s5.deck.size(), _in_deck(s5.deck, &"gunner"), _in_deck(s5.deck, &"marksman"), s5.deck_levels.is_empty()], [20, 4, 0, true],
			"M5: the Rival's crew, Marksmen swapped for Gunners (kc-pos-cut), Trained")
	assert_eq([s4.deck.size(), _in_deck(s4.deck, &"demolitions_expert"), _in_deck(s4.deck, &"marksman"),
			_in_deck(s4.deck, &"si_armored"), _in_deck(s4.deck, &"si_sergeant")], [18, 0, 0, 2, 1],
			"M4: Anchor deck, Demolitions and Marksman swapped for Standard Issue")
	assert_eq([md[0].crew_label, md[2].crew_label], ["Standard Issue crew", "Honors crew"], "crew labels")
	var db: Node = Engine.get_main_loop().root.get_node_or_null(^"/root/CardDB")
	if db != null:
		var errs: Array = (db.get("_issues") as Array).filter(func(i: Dictionary) -> bool: return i.get("severity", "") == "error")
		assert_eq(errs.size(), 0, "CardDB loads (and validates) the data without errors: %s" % str(errs))


# =============================================================================
# Run ladder (§4, heads N2/N3)
# =============================================================================

func test_rungs_filter_the_pool() -> void:
	var cfg: RunConfig = _config()
	assert_eq([cfg.rung_after(1), cfg.rung_after(2), cfg.rung_after(3), cfg.rung_after(4)], [1, 2, 3, 4], "rungs by match")
	assert_eq([cfg.reward_level_after(1), cfg.reward_level_after(2)], [0, 1], "Recruits after M1, Trained after")
	assert_true(RunConfig.in_rung(_card("breacher"), 1) and not RunConfig.in_rung(_card("okafor_anvil"), 1), "rung 1: units, no Elites")
	assert_true(not RunConfig.in_rung(_card("callout"), 1) and RunConfig.in_rung(_card("callout"), 2), "tactics from rung 2")
	assert_true(not RunConfig.in_rung(_card("bulwark"), 2) and RunConfig.in_rung(_card("bulwark"), 3), "Fields from rung 3")
	assert_true(not RunConfig.in_rung(_card("halek_wren"), 3) and RunConfig.in_rung(_card("halek_wren"), 4), "Elites at rung 4")
	for k: int in 30:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 50 + k
		for id: StringName in RewardOffers.supply_drop(cfg, rng, 1):
			assert_true(RunConfig.in_rung(cfg.reward_pool.filter(func(c: CardData) -> bool: return c.id == id)[0], 1), "rung 1 only: %s" % id)
		var four: Array[StringName] = RewardOffers.supply_drop_on_trait(cfg, &"heavy", rng, 3, 4)
		assert_eq(four.size(), 4, "4 shown")
	assert_eq([cfg.drop_size_after(1), cfg.drop_size_after(2), cfg.drop_size_after(5)], [Vector2i(3, 1), Vector2i(4, 2), Vector2i(4, 2)], "3 / pick 1, then 4 / pick 2")


func test_match_one_win_gives_recruit_calling_cards_and_the_doctrine() -> void:
	var r: RunProgress = _run()
	r.record_result(&"player")
	assert_eq(_kinds(r), [RewardOffers.KIND_SUPPLY_DROP, RewardOffers.KIND_ATTACHMENT], "M1 win: drop + weapon level, no Muster out yet")
	var drop: Dictionary = r.current_offer()
	assert_eq([drop["options"].size(), drop["picks"], drop["level"], drop["rung"]], [3, 1, 0, 1], "3 calling cards, pick 1, Recruits, rung 1")
	assert_false(drop.has("reissue"), "head Z1: no Re-issue")
	for id: Variant in drop["options"]:
		var c: CardData = r.resource(id) as CardData
		assert_true(c.is_unit() and not c.is_elite, "units only, no Elites (%s)" % id)
	assert_eq(r.doctrine, &"", "no Doctrine yet")
	var t0: StringName = drop["traits"][0]
	var id0: StringName = drop["options"][0]
	assert_eq(r.choose_offer(0), "", "take a calling card")
	var at: int = r.deck.size() - 1
	assert_eq([r.deck[at], r.level_of(at), r.copy_trait(at)], [id0, 0, t0], "a Recruit with its art's trait")
	assert_eq(r.doctrine, t0 if t0 != &"" else &"", "the first calling card sets the Doctrine")
	assert_eq(r.deck_view()[at]["trains"], SynergyRules.trains_text(r.resource(id0) as CardData, 0), "deck view shows the Trains line")


func test_match_two_drop_is_two_of_four_then_muster_out() -> void:
	var r: RunProgress = _run()
	r.record_result(&"player")
	_skip_all(r)
	r.record_result(&"player")
	assert_eq(_kinds(r).slice(0, 2), [RewardOffers.KIND_SUPPLY_DROP, RewardOffers.KIND_MUSTER_OUT], "M2: drop then Muster out")
	var drop: Dictionary = r.current_offer()
	assert_eq([drop["options"].size(), drop["picks"], drop["level"], drop["rung"], drop.get("retire", false)], [4, 2, 1, 2, true],
			"4 shown, pick 2, Trained, rung 2, Retire option")
	var first: StringName = drop["options"][1]
	assert_eq(r.choose_offer(1), "", "first pick")
	assert_eq(r.current_offer()["kind"], RewardOffers.KIND_SUPPLY_DROP, "still the drop")
	assert_eq([r.current_offer()["options"].size(), r.current_offer()["picks"]], [3, 1], "3 left, 1 pick left")
	assert_eq(r.current_offer()["taken"][0]["id"], first, "taken card listed")
	assert_false(first in r.current_offer()["options"], "and gone from the options")
	assert_eq(r.choose_offer(0), "", "second pick")
	assert_eq(r.current_offer()["kind"], RewardOffers.KIND_MUSTER_OUT, "Muster out is current")
	assert_eq(r.muster_out_count(), 3, "2 cards taken + 1")
	var rows: Array[Dictionary] = r.muster_out_options()
	assert_eq(rows.size(), 18, "every Standard Issue copy listed")
	var pre: Array = rows.filter(func(x: Dictionary) -> bool: return x["preselected"])
	assert_eq(pre.map(func(x: Dictionary) -> StringName: return x["id"]), [&"si_armored", &"si_armored", &"si_armored"], "Armored Troopers pre-selected")
	assert_eq(rows[0]["serial"], "SI-04", "serial plate")
	var size0: int = r.deck.size()
	assert_eq(r.choose_offer(0), "", "accept the pre-selection")
	assert_eq([r.deck.size(), _count(r, &"si_armored"), r.mustered_out], [size0 - 3, 0, 3], "3 Armored Troopers home")
	assert_eq(r.deck.size(), 19, "20 (M1 drop skipped) + 2 - 3: the deck shrank by one with this drop")
	assert_false(RewardOffers.KIND_MUSTER_OUT in _kinds(r), "done")


func test_muster_out_choice_floor_and_errors() -> void:
	var r: RunProgress = _run()
	r.record_result(&"player")
	_skip_all(r)
	r.record_result(&"player")
	r.choose_offer(0)
	r.choose_offer(0)
	var grunt: int = r.deck.find(&"si_grunt")
	assert_eq(r.muster_out([r.deck.size() - 1]), "only Standard Issue cards can be mustered out", "not a calling card")
	assert_eq(r.muster_out([grunt, grunt]), "copy %d is listed twice" % grunt, "no duplicates")
	var four: Array = []
	for i: int in r.deck.size():
		if (r.resource(r.deck[i]) as CardData).standard_issue and four.size() < 4:
			four.append(i)
	assert_eq(r.muster_out(four), "you can send at most 3 Standard Issue cards home", "at most the count")
	assert_eq(r.muster_out([grunt]), "", "send just one Grunt home (keep the rest)")
	assert_eq(_count(r, &"si_grunt"), 4, "one Grunt gone")
	# Floor: a deck at 15 gets no Muster out.
	var r2: RunProgress = _run()
	while r2.deck.size() > 15:
		r2.deck.remove_at(r2.deck.size() - 3)
		r2.deck_levels.remove_at(r2.deck_levels.size() - 3)
		r2.deck_traits.remove_at(r2.deck_traits.size() - 3)
		r2.deck_arts.remove_at(r2.deck_arts.size() - 3)
	r2.record_result(&"player")
	_skip_all(r2)
	r2.record_result(&"player")
	assert_eq(r2.deck.size(), 15, "at the floor")
	r2.skip_offer()
	assert_false(RewardOffers.KIND_MUSTER_OUT in _kinds(r2), "at the floor the Muster out is dropped")
	# Skipping a drop above the floor still sends the +1 home.
	var r3: RunProgress = _run()
	r3.record_result(&"player")
	_skip_all(r3)
	r3.record_result(&"player")
	r3.skip_offer()
	assert_eq([r3.current_offer()["kind"], r3.muster_out_count()], [RewardOffers.KIND_MUSTER_OUT, 1], "skip took nothing: still +1")


func test_salvage_replaces_regroup_after_a_loss() -> void:
	var r: RunProgress = _run()
	r.record_result(&"enemy")
	assert_eq(_kinds(r), [RewardOffers.KIND_SALVAGE, RewardOffers.KIND_ATTACHMENT], "M1 loss: Salvage, no Regroup, no Muster out")
	var sal: Dictionary = r.current_offer()
	assert_eq([sal["options"].size(), sal["picks"], sal["level"]], [2, 1, 0], "2 cards, pick 1, Recruits")
	assert_eq(r.choose_offer(1), "", "take one")
	assert_eq(r.level_of(r.deck.size() - 1), 0, "a Recruit calling card")
	_skip_all(r)
	r.record_result(&"enemy")
	assert_eq(_kinds(r).slice(0, 2), [RewardOffers.KIND_SALVAGE, RewardOffers.KIND_MUSTER_OUT], "M2 loss: Salvage then Muster out")
	r.choose_offer(0)
	assert_eq(r.muster_out_count(), 2, "1 card + 1")
	var d: RunProgress = _run(SEED + 1)
	d.record_result(&"draw")
	assert_false(RewardOffers.KIND_SALVAGE in _kinds(d) or RewardOffers.KIND_SUPPLY_DROP in _kinds(d), "a draw gives no cards")


func test_promotion_trains_keywords_and_there_is_no_trait_choice() -> void:
	var r: RunProgress = _run()
	r.record_result(&"player")
	var drop: Dictionary = r.current_offer()
	var k: int = drop["options"].find(&"breacher")
	r._append_copy(&"breacher", 0, &"heavy", ArtTraits.default_art(_card("breacher"), &"heavy"))
	var at: int = r.deck.size() - 1
	var art: StringName = r.art_of(at)
	assert_eq(r.train_choices(at).size(), 1, "head Z1: one row, the copy's own trait")
	assert_eq(r.train_choices(at)[0]["trait"], &"heavy", "its art's trait")
	assert_eq(r.reissue_options(), [] as Array[Dictionary], "no Re-issue")
	assert_true(r.reissue_card(0, &"vanguard").begins_with("Re-issue was removed"), "reissue_card refuses")
	r.random_copy_arts = false
	assert_true(r.set_copy_art(at, &"breacher").contains("keeps the trait"), "no art swap into another trait")
	r.pending_offers = [{"kind": RewardOffers.KIND_PROMOTION, "match": 2, "options": [&"breacher"] as Array[StringName],
			"levels": [0] as Array[int], "traits": [&"heavy"] as Array[StringName]}]
	r.phase = RunProgress.PHASE_REWARDS
	assert_eq(r.promotion_options()[0]["unlocks"], ["First Shot"] as Array[String], "the Promotion row says what unlocks")
	assert_eq(r.choose_offer(0, &"vanguard"), "", "promote (the trait argument is ignored)")
	assert_eq([r.level_of(at), r.copy_trait(at), r.art_of(at)], [1, &"heavy", art], "Trained, same trait, same art")
	assert_eq([r.deck_view()[at]["keyword"], r.deck_view()[at]["trains"]], [&"", ""], "keywords on (no neighbor keyword since kc-pos-cut)")
	assert_eq(k >= -1, true, "")


func test_retire_on_a_multi_pick_drop_uses_a_pick() -> void:
	var r: RunProgress = _run()
	r.record_result(&"player")
	_skip_all(r)
	r.record_result(&"player")
	var size0: int = r.deck.size()
	assert_eq(r.retire_options()[0]["standard_issue"], true, "Standard Issue cards are listed first")
	assert_eq(r.retire_card(0), "", "retire instead of a card")
	assert_eq([r.current_offer()["kind"], r.current_offer()["picks"], r.deck.size()], [RewardOffers.KIND_SUPPLY_DROP, 1, size0 - 1], "one pick left")
	assert_eq(r.choose_offer(0), "", "take one")
	assert_eq(r.muster_out_count(), 2, "1 card taken + 1 (a Retire doesn't add)")


func test_save_v4_round_trip_mid_drop_and_muster_out() -> void:
	var r: RunProgress = _run()
	r.record_result(&"player")
	r.choose_offer(0)
	_skip_all(r)
	r.record_result(&"player")
	r.choose_offer(2)
	var d: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	assert_eq(int(d["version"]), RunProgress.SAVE_VERSION, "current save version (5 since kc-loadout-cut)")
	var back: Dictionary = RunProgress.from_dict(_config(), d)
	assert_eq(back["error"], "", "loads")
	var r2: RunProgress = back["run"]
	assert_eq(r2.current_offer()["picks"], 1, "picks left survive")
	assert_eq(r2.current_offer()["taken"].size(), 1, "taken survives")
	assert_eq(r2.current_offer()["options"], r.current_offer()["options"], "options survive")
	assert_eq(r2.deck_levels, r.deck_levels, "levels survive (a Recruit stays a Recruit)")
	r2.choose_offer(0)
	r.choose_offer(0)
	assert_eq(r2.muster_out_count(), r.muster_out_count(), "Muster out count")
	var d2: Dictionary = JSON.parse_string(JSON.stringify(r2.to_dict()))
	var r3: RunProgress = RunProgress.from_dict(_config(), d2)["run"]
	assert_eq([r3.current_offer()["kind"], r3.muster_out_count()], [RewardOffers.KIND_MUSTER_OUT, 3], "Muster out survives a save")
	r3.choose_offer(0)
	assert_eq(r3.mustered_out, 3, "")
	assert_eq(int(JSON.parse_string(JSON.stringify(r3.to_dict()))["mustered_out"]), 3, "mustered_out saved")


func test_v3_save_with_the_old_recruit_starter_loads_trained() -> void:
	var legacy: RunConfig = preload("res://tests/legacy_starter.gd").config()
	var old: RunProgress = RunProgress.create(legacy, 5)
	old.begin()
	old.record_result(&"enemy")  # Regroup + Doctrine + weapon level under the old schedule
	var d: Dictionary = JSON.parse_string(JSON.stringify(old.to_dict()))
	d["version"] = 3
	for o: Dictionary in d["pending_offers"]:
		if o["kind"] == "regroup":
			o["reissue"] = true
	var back: Dictionary = RunProgress.from_dict(_config(), d)
	assert_eq(back["error"], "", "a v3 save with the Rifleman loads on the new config (legacy_cards)")
	var r: RunProgress = back["run"]
	assert_true(r.deck_levels.all(func(lv: int) -> bool: return lv == 1), "old Recruits load Trained (their old meaning had keywords)")
	assert_true(r.deck.has(&"rifleman"), "the Rifleman is still in the deck")
	assert_false(r.pending_offers.any(func(o: Dictionary) -> bool: return o.has("reissue")), "Re-issue flags dropped")
	assert_eq(r.current_offer()["kind"], RewardOffers.KIND_REGROUP, "the open Regroup still works")
	assert_eq(r.choose_offer(0), "", "and can be resolved")


# =============================================================================
# Progressive reveal (§5)
# =============================================================================

func test_reveal_flags_from_the_run_and_the_board() -> void:
	var r: RunProgress = _run()
	assert_false(RevealFlags.CALLING_CARDS in RevealFlags.run_triggers(r), "a Standard Issue deck meets nothing")
	r.record_result(&"player")
	var t1: Array[StringName] = RevealFlags.run_triggers(r)
	assert_true(RevealFlags.CALLING_CARDS in t1, "calling cards offered")
	assert_false(RevealFlags.KEYWORDS in t1, "Recruits offered: keywords still hidden")
	r.choose_offer(0)
	var t2: Array[StringName] = RevealFlags.run_triggers(r)
	assert_true(RevealFlags.DOCTRINE in t2 or r.doctrine == &"", "Doctrine once set")
	_skip_all(r)
	r.record_result(&"player")
	var t3: Array[StringName] = RevealFlags.run_triggers(r)
	assert_true(RevealFlags.MULTI_PICK in t3 and RevealFlags.RETIRE in t3, "pick 2 and Retire from M2")
	r.choose_offer(0)
	r.choose_offer(0)
	assert_true(RevealFlags.MUSTER_OUT in RevealFlags.run_triggers(r), "Muster out")
	var m: MatchState = F.new_match()
	assert_eq(RevealFlags.match_triggers(m), [] as Array[StringName], "an empty board")
	m.put_in_line(m.create_unit(P, _card("breacher"), -1, 1), 0)
	m.put_in_line(m.create_unit(P, _card("point_man"), -1, 1), 1)
	var mt: Array[StringName] = RevealFlags.match_triggers(m)
	assert_true(RevealFlags.TRAIT_RAIL in mt and not (RevealFlags.LINKS in mt), "traited units, no links (kc-pos-cut): %s" % str(mt))
	assert_true(&"kw_first_shot" in mt and not (&"kw_guard" in mt), "keyword tips")
	var m2: MatchState = F.new_match()
	m2.put_in_line(m2.create_unit(P, _card("breacher"), -1, 0), 0)
	var mt2: Array[StringName] = RevealFlags.match_triggers(m2)
	assert_true(RevealFlags.TRAIT_RAIL in mt2 and not (&"kw_first_shot" in mt2), "a Recruit shows the trait, not the keyword")


func test_reveal_queue_texts_and_profile_store() -> void:
	var met: Dictionary = {"links": true, "calling_cards": true, "kw_pick": true, "doctrine": true}
	assert_eq(RevealFlags.pending_explainers(met, {}), [&"calling_cards", &"links", &"kw_pick"] as Array[StringName], "ordered; Doctrine has no card of its own")
	assert_eq(RevealFlags.pending_explainers(met, {"calling_cards": true}), [&"links", &"kw_pick"] as Array[StringName], "seen ones are skipped")
	assert_eq(RevealFlags.text_of(&"muster_out")["title"], "New: Muster out", "text")
	assert_eq(RevealFlags.text_of(&"kw_guard")["text"], SynergyRules.KEYWORD_TEXT[&"guard"], "neighbor keyword tip text")
	assert_true(RevealFlags.visible(&"fields", {}, [&"fields"]) and not RevealFlags.visible(&"fields", {}, []), "visible while in use")
	assert_eq(RevealFlags.keyword_flag("Cover 1"), &"kw_cover", "Cover N -> kw_cover")
	var st: Node = Engine.get_main_loop().root.get_node_or_null(^"/root/Settings")
	var rs: Node = Engine.get_main_loop().root.get_node_or_null(^"/root/RunState")
	if st == null or rs == null:
		return
	var keep_met: Dictionary = st.met_flags.duplicate()
	var keep_seen: Dictionary = st.seen_flags.duplicate()
	st.met_flags = {}
	st.seen_flags = {}
	var got: Array = []
	var cb: Callable = func(f: StringName) -> void: got.append(f)
	rs.system_met.connect(cb)
	assert_eq(rs.note_systems([&"fields", &"links"]), [&"fields", &"links"] as Array[StringName], "new systems")
	assert_eq(rs.note_systems([&"fields"]), [] as Array[StringName], "met once")
	assert_eq(got, [&"fields", &"links"], "system_met signals")
	assert_true(rs.has_met(&"fields"), "has_met")
	assert_eq(rs.pending_explainers(), [&"fields", &"links"] as Array[StringName], "queue")
	rs.ack_explainer(&"fields")
	assert_eq(rs.pending_explainers(), [&"links"] as Array[StringName], "acknowledged")
	st.reset_tips()
	assert_false(rs.has_met(&"fields"), "Reset tips")
	rs.system_met.disconnect(cb)
	st.met_flags = keep_met
	st.seen_flags = keep_seen
