# test_duel_rules.gd
# Purpose: kc-duel-impl: the Duel deck rules (duel-mode.md §2.1, §6.4; head D1-D5): validation codes
#   (red / amber), the pool, 2 copies per pick, art -> trait, the hero in its own slot with the shared
#   stats (D4), Doctrine plumbing (D5), the presets' legality and the Duel match setup.
# Author: Mechanics Developer Agent (kc-duel-impl)
extends "res://tests/test_case.gd"


func _cfg() -> DuelConfig:
	return load("res://data/duel/duel_config.tres") as DuelConfig


func _codes(lines: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for l: Dictionary in lines:
		out.append(StringName(l["code"]))
	return out


## A legal 10-pick deck (Kestrel): 6 units, 3 tactics, 1 Field.
func _legal() -> DuelDeck:
	var d: DuelDeck = DuelDeck.new()
	d.display_name = "Test"
	d.hero_id = &"kestrel_ar7"
	for id: StringName in [&"rifleman", &"point_man", &"breacher", &"shieldman", &"brawler", &"gunner",
			&"flank_route", &"hold_the_line", &"blackout", &"bulwark"]:
		assert_eq(d.add_pick(id), "", "add %s" % id)
	return d


func test_config_data_matches_the_head_decisions() -> void:
	var c: DuelConfig = _cfg()
	assert_eq(c.picks, 10, "D2: exactly 10 picks")
	assert_eq(c.copies_per_pick, 2, "D2: 2 copies each")
	assert_eq(c.cards_per_deck(), 20, "20 cards")
	assert_eq(c.min_unit_picks, 5, "at least 5 units")
	assert_eq(c.max_elite_picks, 1, "at most 1 Elite")
	assert_eq(c.max_field_picks, 3, "at most 3 Fields")
	assert_eq(c.max_saved_decks, 8, "8 saved decks")
	assert_eq(c.zone_control_target, 6, "Zone Control to 6")
	assert_eq(c.game_mode, DataEnums.GameMode.ZONE_CONTROL, "Zone Control")
	assert_eq(c.hero_ids(), [&"kestrel_ar7", &"longreach_338", &"wasp_9", &"bastion_60"] as Array[StringName], "4 heroes")
	var ks: Array[StringName] = []
	for k: LoadoutItem in c.killstreaks:
		ks.append(k.id)
	assert_eq(ks, [&"recon_drone", &"mortar_barrage", &"attack_helo"] as Array[StringName], "the 3 starter killstreaks")
	assert_eq(c.presets.size(), 4, "4 presets")


func test_pool_excludes_tokens_standard_issue_and_counts_30() -> void:
	var pool: Array[CardData] = DuelCollection.pool_cards()
	var ids: Array[StringName] = []
	for c: CardData in pool:
		ids.append(c.id)
	assert_eq(pool.size(), 30, "30 collectible chassis")
	for bad: StringName in [&"sentry", &"shambler", &"si_grunt", &"si_trooper", &"si_sergeant", &"si_armored"]:
		assert_false(bad in ids, "%s is never in the Duel pool" % bad)
	var units: int = 0
	var elites: int = 0
	var fields: int = 0
	var tactics: int = 0
	for c: CardData in pool:
		if c.is_elite:
			elites += 1
		elif c.is_unit():
			units += 1
		elif DuelRules.is_field(c):
			fields += 1
		else:
			tactics += 1
	assert_eq([units, elites, tactics, fields], [11, 2, 9, 8], "11 units, 2 Elites, 9 tactics, 8 Fields")


func test_legal_deck_is_ready() -> void:
	var r: Dictionary = DuelRules.validate(_legal(), _cfg())
	assert_true(r["ok"], "legal: %s" % str(r["errors"]))
	assert_eq(r["status"], "READY", "status chip")
	assert_eq(r["status_text"], "READY: 20 cards, hero Kestrel AR-7", "green line")
	assert_eq(r["summary"]["cards"], 20, "20 cards")
	var curve: Array = r["summary"]["curve"]
	var total: int = 0
	for v: int in curve:
		total += v
	assert_eq(total, 20, "the curve counts copies")


func test_red_lines() -> void:
	var c: DuelConfig = _cfg()
	var d: DuelDeck = DuelDeck.new()
	var r: Dictionary = DuelRules.validate(d, c)
	assert_false(r["ok"], "empty deck")
	assert_true(&"picks_short" in _codes(r["errors"]), "picks short")
	assert_true(&"no_hero" in _codes(r["errors"]), "no hero")
	assert_eq(r["errors"][0]["text"], "Pick 10 more cards (0/10)", "first red line")
	# 8 picks, then the "2 PICKS TO GO" chip once the hero is in and the rest is fine.
	d = _legal()
	d.remove_pick(&"bulwark")
	d.remove_pick(&"blackout")
	r = DuelRules.validate(d, c)
	assert_eq(r["status"], "2 PICKS TO GO", "only picks missing")
	assert_eq(r["errors"][0]["text"], "Pick 2 more cards (8/10)", "the spec's wording")
	# Units under 5.
	d = DuelDeck.new()
	d.hero_id = &"wasp_9"
	for id: StringName in [&"rifleman", &"point_man", &"breacher", &"shieldman", &"flank_route", &"hold_the_line",
			&"blackout", &"ammo_resupply", &"sabotage", &"callout"]:
		d.add_pick(id)
	r = DuelRules.validate(d, c)
	var line: Dictionary = _find(r["errors"], &"unit_min")
	assert_eq(line.get("text", ""), "At least 5 unit picks (4/5)", "unit min")
	assert_eq(line.get("fix_filter", {}), {"type": "unit"}, "fix filter")
	assert_eq(r["status"], "NEEDS ATTENTION", "a rule other than picks")
	# Two Elites, four Fields.
	d = _legal()
	d.remove_pick(&"gunner")
	d.remove_pick(&"brawler")
	d.add_pick(&"okafor_anvil")
	d.add_pick(&"halek_wren")
	d.remove_pick(&"flank_route")
	d.remove_pick(&"hold_the_line")
	d.remove_pick(&"blackout")
	d.add_pick(&"mortar_pit")
	d.add_pick(&"war_standard")
	d.add_pick(&"sniper_perch")
	r = DuelRules.validate(d, c)
	assert_eq(_find(r["errors"], &"elite_max").get("text", ""), "Only 1 Elite ★ pick (2/1): remove %s or %s" % [(load("res://data/cards/okafor_anvil.tres") as CardData).display_name, (load("res://data/cards/halek_wren.tres") as CardData).display_name], "Elite line (display names)")
	assert_eq(_find(r["errors"], &"field_max").get("text", ""), "At most 3 Field picks (4/3)", "Field line")
	# Unknown hero, bad art, not-in-pool, duplicate (forced past add_pick).
	d = _legal()
	d.hero_id = &"recon_drone"
	d.picks[0] = {"card_id": &"rifleman", "art_id": &"gunner~mastery"}
	d.picks.append({"card_id": &"sentry", "art_id": &""})
	d.picks.append({"card_id": &"point_man", "art_id": &""})
	r = DuelRules.validate(d, c)
	for code: StringName in [&"unknown_hero", &"bad_art", &"not_in_pool", &"duplicate_pick", &"picks_over"]:
		assert_true(code in _codes(r["errors"]), "red %s" % code)


func _find(lines: Array, code: StringName) -> Dictionary:
	for l: Dictionary in lines:
		if l["code"] == code:
			return l
	return {}


func test_amber_lines_never_block() -> void:
	var c: DuelConfig = _cfg()
	var d: DuelDeck = DuelDeck.new()
	d.hero_id = &"bastion_60"
	# No tactic, heavy curve, one cheap pick, no unit set (every unit a different trait or plain).
	for id_art: Array in [[&"rifleman", &""], [&"point_man", &""], [&"brawler", &""], [&"gunner", &""],
			[&"demolitions_expert", &"demolitions_expert~horde"], [&"marksman", &"marksman~mastery"],
			[&"okafor_anvil", &""], [&"mortar_pit", &""], [&"bulwark", &""], [&"war_standard", &""]]:
		assert_eq(d.add_pick(id_art[0], id_art[1]), "", "add %s" % id_art[0])
	var r: Dictionary = DuelRules.validate(d, c)
	var w: Array[StringName] = _codes(r["warnings"])
	assert_true(&"no_tactic" in w, "no tactic advice")
	assert_true(&"low_curve" in w, "round-1 advice")
	assert_eq(_find(r["warnings"], &"no_tactic").get("text", ""), "No tactics: you can't answer a column in one round.", "wording")
	assert_true(r["ok"], "advice never blocks: %s" % str(r["errors"]))
	# The presets carry the spec's one amber line: Hollow Ranks has a single 1-cost pick.
	var hr: Dictionary = DuelRules.validate(c.preset(&"hollow_ranks"), c)
	assert_true(hr["ok"], "Hollow Ranks: legal (§12.4 list)")


func test_editing_refusals() -> void:
	var d: DuelDeck = _legal()
	assert_eq(d.add_pick(&"marksman"), "10/10: remove a pick first", "full deck")
	d.remove_pick(&"gunner")
	assert_eq(d.add_pick(&"rifleman"), "Already in your deck (x2)", "one pick per card")
	assert_eq(d.add_pick(&"nope"), "Unknown card", "unknown")
	assert_eq(d.add_pick(&"marksman", &"rifleman~horde"), "That art isn't one of Marksman's arts", "foreign art")
	assert_eq(d.set_doctrine(&"heavy"), "", "doctrine")
	assert_eq(d.set_doctrine(&"pirates"), "Doctrine must be a trait", "bad doctrine")
	var p: DuelDeck = _cfg().preset(&"spearhead")
	assert_eq(p.add_pick(&"gunner"), "Preset: copy to edit", "presets are read-only")
	var cp: DuelDeck = p.copy()
	assert_false(cp.preset, "a copy is editable")
	assert_eq(cp.id, &"", "a copy has no id yet")
	assert_eq(cp.pick_count(), 10, "same picks")
	assert_eq(d.rename("A very long deck name that goes on"), "", "rename")
	assert_eq(d.display_name.length(), 20, "20 characters at most")


func test_locked_cards_red_for_own_decks_never_for_presets() -> void:
	var c: DuelConfig = _cfg()
	var fresh: Dictionary = DuelCollection.unlocked_set(RunProfile.blank())
	assert_true(fresh.has("rifleman") and fresh.has("flank_route"), "units and tactics open")
	assert_false(fresh.has("mortar_pit") or fresh.has("okafor_anvil"), "Fields and Elites locked")
	var iw: DuelDeck = c.preset(&"iron_wall")
	assert_true(DuelRules.validate(iw, c, fresh)["ok"], "a preset is a loaner")
	var copy: DuelDeck = iw.copy()
	var r: Dictionary = DuelRules.validate(copy, c, fresh)
	assert_eq(_find(r["errors"], &"locked_card").get("text", ""), "Mortar Pit isn't in your collection: find it in the campaign", "copied preset")
	assert_true(DuelRules.validate(copy, c, fresh, {"open_pool": true})["ok"], "hot seat open pool")
	var prof: Dictionary = RunProfile.add_found_cards(RunProfile.blank(), ["mortar_pit", "okafor_anvil"])
	assert_true(DuelRules.validate(copy, c, DuelCollection.unlocked_set(prof))["ok"], "found in a run: unlocked")


func test_presets_are_legal_with_their_heroes_and_traits() -> void:
	var c: DuelConfig = _cfg()
	var want: Dictionary = {&"spearhead": [&"kestrel_ar7", &"vanguard"], &"overwatch": [&"longreach_338", &"specops"],
			&"iron_wall": [&"bastion_60", &"heavy"], &"hollow_ranks": [&"wasp_9", &"undead"]}
	for id: StringName in want:
		var d: DuelDeck = c.preset(id)
		assert_not_null(d, "preset %s" % id)
		var r: Dictionary = DuelRules.validate(d, c, DuelCollection.unlocked_set(RunProfile.blank()))
		assert_true(r["ok"], "%s legal: %s" % [id, str(r["errors"])])
		assert_eq(d.hero_id, want[id][0], "%s hero" % id)
		assert_eq(DuelRules.main_trait(d), want[id][1], "%s main trait" % id)
		assert_true(d.preset, "%s read-only" % id)
	# The spec's unit / tactic / Field counts (copies).
	var counts: Dictionary = {&"spearhead": [10, 8, 2], &"overwatch": [14, 4, 2], &"iron_wall": [12, 6, 2], &"hollow_ranks": [12, 2, 6]}
	for id: StringName in counts:
		var s: Dictionary = DuelRules.validate(c.preset(id), c)["summary"]
		assert_eq([s["units"] * 2, s["tactics"] * 2, s["fields"] * 2], counts[id], "%s composition" % id)


func test_side_setup_two_copies_art_trait_hero_no_doctrine_by_default() -> void:
	var c: DuelConfig = _cfg()
	var d: DuelDeck = c.preset(&"overwatch")
	var s: SideSetup = DuelRules.side_setup(d, c)
	assert_eq(s.deck.size(), 20, "20 cards")
	assert_eq(s.deck_traits.size(), 20, "a trait per copy")
	assert_eq(s.deck_arts.size(), 20, "an art per copy")
	var by_id: Dictionary = {}
	for i: int in s.deck.size():
		by_id[s.deck[i].id] = int(by_id.get(s.deck[i].id, 0)) + 1
	for id: StringName in by_id:
		assert_eq(by_id[id], 2, "%s: exactly 2 copies" % id)
	var ri: int = s.deck.find(load("res://data/cards/rifleman.tres"))
	assert_eq(s.deck_traits[ri], &"specops", "the Spec Ops art gives Rifleman Spec Ops")
	assert_eq(s.deck_arts[ri], &"rifleman~operators", "both copies wear it")
	assert_eq(s.deck_traits[ri + 1], &"specops", "second copy too")
	assert_eq(s.primary.id, &"longreach_338", "the hero is the Operator (own slot)")
	assert_true(s.operator_kit, "kit on: passive + ability")
	assert_eq(s.killstreaks.size(), 3, "3 starter killstreaks")
	assert_true(s.perks.is_empty() and s.attachments.is_empty(), "no perks / attachments")
	assert_eq(s.doctrine, &"specops", "§12.4: each preset's Doctrine is its own trait")
	assert_true(s.doctrine_starts_only, "§12.3: the Duel Doctrine only starts a set")
	d = d.copy()
	d.set_doctrine(&"")
	assert_eq(DuelRules.side_setup(d, c).doctrine, &"", "None is allowed")
	d.set_doctrine(&"specops")
	assert_eq(DuelRules.side_setup(d, c).doctrine, &"specops", "D5: the deck's Doctrine applies")
	var off: DuelConfig = c.duplicate() as DuelConfig
	off.doctrine_enabled = false
	assert_eq(DuelRules.side_setup(d, off).doctrine, &"", "switchable in data")


func test_doctrine_validation_hooks() -> void:
	var c: DuelConfig = (_cfg().duplicate() as DuelConfig)
	c.doctrine_min_trait_picks = 0
	var d: DuelDeck = _legal()
	assert_true(DuelRules.validate(d, c)["ok"], "no Doctrine is fine by default")
	c.doctrine_required = true
	assert_true(&"doctrine_required" in _codes(DuelRules.validate(d, c)["errors"]), "required")
	d.set_doctrine(&"specops")
	var r: Dictionary = DuelRules.validate(d, c)
	assert_true(r["ok"], "picked")
	assert_true(&"doctrine_unused" in _codes(r["warnings"]), "amber: no pick wears Spec Ops")
	c.doctrine_min_trait_picks = 3
	d.set_doctrine(&"vanguard")
	r = DuelRules.validate(d, c)
	# Spearhead-like: point_man, breacher, shieldman wear Vanguard by default; bulwark is printed Vanguard.
	assert_true(r["ok"], "4 Vanguard picks meet a minimum of 3: %s" % str(r["errors"]))
	c.doctrine_min_trait_picks = 5
	r = DuelRules.validate(d, c)
	assert_eq(_find(r["errors"], &"doctrine_rule").get("text", ""), "Doctrine Vanguard needs 5 Vanguard picks (4/5)", "red rule")


func test_duel_heroes_use_campaign_stats() -> void:
	# D4: one stat set. The Duel Operator is built from the campaign's loadout file, unchanged.
	var c: DuelConfig = _cfg()
	for h: LoadoutItem in c.heroes:
		var file: LoadoutItem = load("res://data/loadout/%s.tres" % h.id) as LoadoutItem
		assert_true(h == file, "%s: the campaign's own resource" % h.id)
	var d: DuelDeck = c.preset(&"spearhead")
	var m: MatchState = DuelRules.create_match(d, c.preset(&"iron_wall"), c, load("res://data/run_config.tres"), 5)
	m.start_match()
	var k: LoadoutItem = load("res://data/loadout/kestrel_ar7.tres") as LoadoutItem
	assert_eq(m.sides[0].operator_unit.base_max_armor, k.operator_armor, "Duel Kestrel Armor = loadout file")


func test_match_setup_economy_and_mode() -> void:
	var c: DuelConfig = _cfg()
	var base: RunConfig = load("res://data/run_config.tres") as RunConfig
	var mc: RunConfig = c.match_config(base)
	assert_eq(mc.deck_size, 20, "deck size 20")
	assert_eq(mc.zone_control_target, 6, "ZC to 6")
	assert_eq(mc.draws_per_round, base.draws_per_round, "same draws as the campaign")
	assert_eq(mc.operator_cost, 1, "D1: respawn costs 1")
	assert_true(mc.operator_free_round1, "D1: free in round 1")
	assert_eq(base.deck_size, 10, "the campaign config is untouched")
	var m: MatchState = DuelRules.create_match(c.preset(&"overwatch"), c.preset(&"hollow_ranks"), c, base, 77, ["A", "B"], [0, -1])
	assert_eq(m.hooks.mode_rules.mode, DataEnums.GameMode.ZONE_CONTROL, "Zone Control")
	m.start_match()
	assert_eq(m.terrain, [&"", &"", &""] as Array[StringName], "no Terrain")
	assert_eq(m.round_number, 1, "round 1")
	assert_eq(m.sides[0].supply, 1, "round 1 gives 1 Supply")
	assert_true(m.sides[0].operator_can_deploy, "D1: the hero is placeable from round 1")
	assert_eq(m.sides[1].setup.armor_bonus, -1, "armor bonus per side")
	assert_eq(m.sides[0].hand.size() + m.sides[0].deck.size(), 20, "20 cards in play")


## duel-mode.md §12.3 / §12.6: a Doctrine needs 4 picks wearing its trait (red line otherwise), None is
## allowed, and the presets' Doctrines meet it.
func test_doctrine_needs_four_picks() -> void:
	var c: DuelConfig = _cfg()
	assert_eq(c.doctrine_min_trait_picks, 4, "shipped minimum: 4 picks")
	assert_true(c.doctrine_enabled and not c.doctrine_required, "on, None allowed")
	var d: DuelDeck = _legal()
	assert_true(DuelRules.validate(d, c)["ok"], "None is legal")
	d.set_doctrine(&"vanguard")  # Point Man, Breacher, Shieldman (default Vanguard) + Bulwark (printed)
	assert_true(DuelRules.validate(d, c)["ok"], "4 Vanguard picks: legal")
	d.remove_pick(&"bulwark")
	d.add_pick(&"sabotage")
	var r: Dictionary = DuelRules.validate(d, c)
	var line: Dictionary = _find(r["errors"], &"doctrine_rule")
	assert_eq(line.get("text", ""), "Doctrine Vanguard needs 4 Vanguard picks (3/4)", "the spec's red line")
	assert_eq(line.get("fix_filter", {}), {"doctrine": true}, "opens the Doctrine picker")
	assert_false(r["ok"], "blocks PLAY")
	d.set_art(&"brawler", &"")  # Brawler stays Undead: still 3
	d.remove_pick(&"brawler")
	assert_eq(d.add_pick(&"marksman"), "", "add Marksman")
	assert_false(DuelRules.validate(d, c)["ok"], "Marksman (Spec Ops) doesn't count for Vanguard")
	d.set_doctrine(&"")
	assert_true(DuelRules.validate(d, c)["ok"], "None again: legal")
	var txt: String = DuelRules.doctrine_text(&"undead", c)
	assert_true(txt.contains("Needs 4 Undead picks"), "the Doctrine text explains the minimum: %s" % txt)
	assert_true(txt.begins_with("Doctrine: your first Undead in play already turns on the Undead 2-set."), "the spec's card text")
	var want: Dictionary = {&"spearhead": &"vanguard", &"overwatch": &"specops", &"iron_wall": &"heavy", &"hollow_ranks": &"undead"}
	for id: StringName in want:
		assert_eq(c.preset(id).doctrine_trait, want[id], "%s Doctrine" % id)


## §12.4 preset content: Overwatch Smoke Screen -> Ammo Resupply, Hollow Ranks Sabotage -> Listening Post.
func test_tuned_preset_lists() -> void:
	var c: DuelConfig = _cfg()
	var ow: DuelDeck = c.preset(&"overwatch")
	assert_false(ow.has_pick(&"smoke_screen"), "Overwatch: no Smoke Screen")
	assert_true(ow.has_pick(&"ammo_resupply"), "Overwatch: Ammo Resupply")
	var hr: DuelDeck = c.preset(&"hollow_ranks")
	assert_false(hr.has_pick(&"sabotage"), "Hollow Ranks: no Sabotage")
	assert_true(hr.has_pick(&"listening_post"), "Hollow Ranks: Listening Post")
	assert_eq(c.preset(&"spearhead").hero_id, &"kestrel_ar7", "heroes unchanged")
	assert_eq(hr.hero_id, &"wasp_9", "heroes unchanged")
