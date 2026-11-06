# test_trait_ui.gd
# Purpose: kc-trait-ui (art-traits.md §8 + the head's 2026-11-06 direction). Per-copy art and trait:
#   a run's copies keep the art they were found with (random art of their trait, no swaps, no Codex
#   EQUIP), that art and its trait reach the match (hand and board), rival squads wear arts of their
#   identity trait; our public placeholder option arts (<chassis>~honors|operators|mastery|horde)
#   render with the family tint + emblem and are listed; banner entries and the card anatomy show
#   the copy's own trait. The reward-screen flows (offers, TRAIN AS, Re-issue) are in
#   test_run_screens.gd (test_trait_ui_reward_flows). Runs with or without assets/licensed.
# Author: UI/UX Agent (kc-trait-ui)
extends "res://tests/test_case.gd"

const MatchController: GDScript = preload("res://scripts/ui/match_controller.gd")
const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")
const SEED: int = 777


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


func _run(seed_value: int = SEED) -> RunProgress:
	var c: RunConfig = (load("res://data/run_config.tres") as RunConfig).duplicate() as RunConfig
	var r: RunProgress = RunProgress.create(c, seed_value)
	r.begin()
	return r


func test_option_placeholder_arts_render_and_are_listed() -> void:
	var mk: CardData = _card("marksman")
	var lic: bool = BannerArtDB.licensed_enabled
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	ArtTraits.clear_cache()
	var base: BannerArt = BannerArtDB.get_art(&"marksman")
	for fam: StringName in [ArtTraits.HONORS, ArtTraits.OPERATORS, ArtTraits.MASTERY, ArtTraits.HORDE]:
		var id := StringName("marksman~%s" % fam)
		var art: BannerArt = BannerArtDB.get_art(id)
		assert_true(art.placeholder and not art.is_default, "%s is a placeholder alternate" % id)
		assert_eq(art.tags.get("family", ""), String(fam), "%s carries its family" % id)
		assert_eq(BannerArtDB.subname(id), String(ArtTraits.OPTION_VARIANTS[fam][0]), "%s subname" % id)
		assert_not_null(art.texture, "%s has a texture" % id)
		if art.texture != null and base.texture != null:
			assert_true(art.texture != base.texture, "%s is regraded, not the chassis art" % id)
			var img: Image = art.texture.get_image()
			var band: Rect2 = art.banner_region(Vector2(img.get_size()))
			var es: int = maxi(16, int(band.size.y * 0.5))
			var ctr: Vector2i = Vector2i(int(band.position.x + band.size.x * 0.64), int(band.position.y + band.size.y * 0.5))
			assert_true(img.get_pixelv(ctr).a > 0.9, "%s: the emblem sits in the band (%d px)" % [id, es])
		var em: Image = BannerArtDB.option_emblem(StringName(String(ArtTraits.OPTION_VARIANTS[fam][2])), 40)
		assert_true(em.get_pixel(20, 20).a > 0.5 and em.get_pixel(0, 0).a == 0.0, "%s emblem is a roundel" % fam)
	# Listed: the Codex reads BannerArtDB.alt_arts = ArtTraits.arts_for (every option has an art).
	var arts: Array[StringName] = BannerArtDB.alt_arts(&"marksman")
	assert_eq(arts, ArtTraits.arts_for(mk), "alt_arts = ArtTraits.arts_for")
	assert_true(&"marksman~mastery" in arts, "the Heavy option's placeholder is listed")
	assert_eq(BannerArtDB.art_trait(&"marksman~mastery"), &"heavy", "art_trait reads ArtTraits.trait_of")
	assert_eq(BannerArtDB.art_trait(&"marksman~horde"), &"", "Undead is not a Marksman option: plain")
	assert_eq(BannerArtDB.art_trait(&"marksman~night"), &"specops", "a home look keeps the home trait")
	BannerArtDB.licensed_enabled = lic
	BannerArtDB.clear_cache()
	ArtTraits.clear_cache()


func test_run_copies_keep_the_art_they_were_found_with() -> void:
	var r: RunProgress = _run()
	assert_true(r.random_copy_arts, "the default (head)")
	for i: int in r.deck.size():
		var c: CardData = r.resource(r.deck[i]) as CardData
		if c.has_trait_choice():
			assert_eq(ArtTraits.trait_of(r.art_of(i), c), r.trait_choice(i), "starter copy %d: its art gives its trait" % i)
	assert_eq(_run().deck_arts, r.deck_arts, "same seed, same arts")
	# Supply Drops: a random art of the slot's trait.
	r.record_result(&"player")
	var drop: Dictionary = r.current_offer()
	assert_eq(drop["kind"], RewardOffers.KIND_SUPPLY_DROP, "a Supply Drop")
	for k: int in (drop["options"] as Array).size():
		var c2: CardData = r.resource(drop["options"][k]) as CardData
		if c2.has_trait_choice():
			assert_eq(ArtTraits.trait_of(drop["arts"][k], c2), drop["traits"][k], "offer %d: the art gives the offered trait" % k)
	# No swaps; no Re-issue (head Z1): the copy keeps the art (and trait) it was found with.
	var g: int = r.deck.size()
	r._append_copy(&"gunner", 1, &"heavy", r._random_art(_card("gunner"), &"heavy"))
	assert_true(r.set_copy_art(g, &"gunner~operators") != "", "no art swaps in a run")
	var draws: int = r.art_draws
	assert_true(r.reissue_card(0, &"specops") != "", "no Re-issue")
	assert_eq([r.copy_trait(g), r.art_draws], [&"heavy", draws], "no new art drawn")
	r.choose_offer(0)
	assert_true(r.art_draws > 0, "Supply Drop cards drew random arts")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(r.to_dict()))
	var back: RunProgress = RunProgress.from_dict(r.config, saved)["run"]
	assert_eq(back.art_draws, r.art_draws, "the draw counter is saved")
	# Training keeps the art: train_choices has one row, never a random draw.
	var rec: int = r.deck.size() - 1
	assert_eq(r.level_of(rec), SynergyRules.LEVEL_RECRUIT, "the M1 drop gave a Recruit")
	for o: Dictionary in r.train_choices(rec):
		assert_false(bool(o["random"]), "%s: training keeps the art" % o["name"])


func test_per_copy_art_and_trait_reach_the_board() -> void:
	var r: RunProgress = _run()
	var mk: CardData = _card("marksman")
	r._append_copy(&"marksman", 1, &"specops", r._random_art(mk, &"specops"))
	r._append_copy(&"marksman", 1, &"heavy", r._random_art(mk, &"heavy"))
	var m: MatchState = r.create_match()
	var want: Array[StringName] = r.player_setup().deck_arts.duplicate()
	MatchController._assign_copy_arts(m)
	assert_eq(m.sides[0].setup.deck_arts, want, "a run's copies keep their own arts in the match")
	m.start_match()
	var seen: Dictionary = {}
	for rc: RulesCard in m.sides[0].deck + m.sides[0].hand:
		if rc.card.id != &"marksman" or rc.level < SynergyRules.LEVEL_TRAINED:
			continue
		var art: StringName = StringName(String(m.art_by_uid.get(rc.uid, rc.card.id)))
		assert_eq(ArtTraits.trait_of(art, mk), rc.card_trait(), "copy %d: art %s gives its trait %s" % [rc.uid, art, rc.card_trait()])
		seen[rc.card_trait()] = true
		# The banner entry the hand / board draws: the copy's own trait and art, no subname on the card.
		var e: Dictionary = {}
		MatchSnapshot._banner_fields(e, rc.card, null, m.sides[0], m, rc.uid)
		assert_eq(StringName(String(e["banner"])), art, "copy %d wears its art" % rc.uid)
		var be: Dictionary = BannerCard.entry_for_card(rc.card, art, rc.level, rc.chosen_trait)
		assert_eq(StringName(String(be.get("trait", ""))), rc.card_trait(), "copy %d banner trait" % rc.uid)
	assert_eq(seen.size(), 2, "two Marksmen with two different traits on the board side")
	# The rival squad: every copy's art gives its identity trait.
	for rc: RulesCard in m.sides[1].deck + m.sides[1].hand:
		if not rc.card.has_trait_choice() or rc.level < SynergyRules.LEVEL_TRAINED:
			continue
		var art2: StringName = StringName(String(m.art_by_uid.get(rc.uid, rc.card.id)))
		assert_eq(ArtTraits.trait_of(art2, rc.card), rc.card_trait(), "rival %s: art matches trait" % rc.card.id)


func test_banner_entry_trait_follows_the_art() -> void:
	var mk: CardData = _card("marksman")
	assert_eq(BannerCard.entry_for_card(mk, &"marksman")["trait"], "specops", "default art: home trait")
	assert_eq(BannerCard.entry_for_card(mk, &"marksman~mastery")["trait"], "heavy", "Mastery art: Heavy")
	assert_false(BannerCard.entry_for_card(mk, &"marksman~horde").has("trait"), "a plain art: no trait plate")
	assert_eq(BannerCard.entry_for_card(mk, &"marksman", 1, &"heavy")["trait"], "heavy", "an explicit copy trait wins")
	assert_eq(BannerCard.entry_for_card(mk, &"marksman~mastery", 0).get("trait", ""), "heavy", "kc-onboard (N1): Recruits show their trait")
	# Anatomy: trait + weapon-type bottom-left, abilities top-right, name top-left (both sides alike).
	var e: Dictionary = BannerCard.entry_for_card(mk, &"marksman~mastery")
	var m: Dictionary = BannerView.metrics(57.0)
	var a: Dictionary = BannerView.anatomy(Vector2(228, 57), m, e)
	assert_true((a["trait"] as Rect2).position.x < 60.0 and (a["trait"] as Rect2).end.y > 40.0, "trait bottom-left")
	assert_true((a["class"] as Rect2).position.x > (a["trait"] as Rect2).end.x - 0.5, "weapon-type after the trait")
	for ab: Array in a["abilities"]:
		assert_true((ab[1] as Rect2).end.x > 150.0 and (ab[1] as Rect2).position.y < 20.0, "abilities top-right")
