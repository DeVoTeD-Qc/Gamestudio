# test_ui4.gd
# Purpose: kc-ui4 (the head: hand / codex cards like their board form, codex alternate arts with
#   EQUIP, the starter deck + Operator choice, the same stat-icon place on both sides, the glossary,
#   the card name = chassis with the art's subname under it).
#   Runs with or without the git-ignored licensed art folder (alt_arts falls back to our variants).
# Author: UI/UX Agent (kc-ui4)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const CodexView: GDScript = preload("res://scripts/ui/codex/codex_view.gd")
const Glossary: GDScript = preload("res://scripts/ui/codex/glossary.gd")
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const MatchController: GDScript = preload("res://scripts/ui/match_controller.gd")
const StarterPanel: GDScript = preload("res://scripts/ui/run/starter_panel.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const TITLE_SCENE: String = "res://scenes/Title.tscn"
const SCRATCH: String = "user://kc_ui4_settings_test.cfg"
const EPS: float = 0.6

var _saved_root_size: Vector2i = Vector2i.ZERO


func _settings() -> Node:
	return tree.root.get_node("Settings")


func _reset_settings() -> void:
	var st: Node = _settings()
	st.persist = false
	st.equipped_arts = {}
	st.operator_primary = ""


# =============================================================================
# 4. Stat icons in the same place on both sides
# =============================================================================

func test_stat_icons_same_place_for_both_sides() -> void:
	var entry: Dictionary = {"name": "Rifleman", "cls": "AR", "fp": 3, "armor": 4, "armor_max": 4, "banner": "rifleman", "cost": 2,
			"keywords": [{"id": &"pick"}], "trait": "vanguard", "kw": "spotter", "band": "gilded"}
	for sz: Vector2 in [Vector2(228, 57), Vector2(304, 76), Vector2(208, 52), Vector2(512, 128)]:
		var mine: BannerView = BannerView.new()
		var theirs: BannerView = BannerView.new()
		for b: BannerView in [mine, theirs]:
			tree.root.add_child(b)
			b.size = sz
		mine.show_unit(entry, &"player", true)
		theirs.show_unit(entry, &"enemy", true)
		var a: Dictionary = mine.stat_rects()
		var e: Dictionary = theirs.stat_rects()
		assert_eq([a["fp"], a["armor"]], [e["fp"], e["armor"]], "%s: FP and Armor badges at the same place on both sides" % sz)
		_check_anatomy(mine, "%s player" % sz)
		_check_anatomy(theirs, "%s rival" % sz)
		assert_eq(mine.anatomy_now(), theirs.anatomy_now(), "%s: every slot identical on both sides" % sz)
		var op: Dictionary = entry.duplicate()
		op.erase("cost")
		op["operator"] = true
		mine.show_unit(op, &"player", true)
		theirs.show_unit(op, &"enemy", true)
		assert_eq(mine.stat_rects(), theirs.stat_rects(), "%s: the Operator's badges match too" % sz)
		mine.free()
		theirs.free()
	# Live board, both screens: every friendly and rival banner puts them at the same banner-local place.
	for screen: Dictionary in [Layout.PHONE, Layout.DESKTOP]:
		var s: Array = await _spawn(screen)
		var m: Control = s[1]
		var label: String = screen["name"]
		var c: Node = s[2]
		var st: MatchState = c.state
		var lanes: Array[Node] = m.get_board().get_lanes()
		# Put a unit in row 1 of column A on both sides.
		for side: int in 2:
			var card: CardData = CardDB.get_card(&"rifleman")
			var u: RulesUnit = st.create_unit(side, card)
			st.put_in_line(u, 0)
		c.refresh()
		await _frames(3)
		var fr: Node = lanes[0].get_friendly_slots()[0]
		var er: Node = lanes[0].get_enemy_slots()[0]
		assert_eq(fr.banner.mode, BannerView.Mode.UNIT, "%s friendly banner" % label)
		assert_eq(er.banner.mode, BannerView.Mode.UNIT, "%s rival banner" % label)
		var a2: Dictionary = fr.banner.stat_rects()
		var e2: Dictionary = er.banner.stat_rects()
		assert_eq([a2["fp"], a2["armor"]], [e2["fp"], e2["armor"]], "%s live board: same badge places (%s / %s)" % [label, a2, e2])
		# Hand cards are the same banner: FP bottom-left, Armor bottom-right, the board's badge size.
		var hand: Control = m.get_hand()
		var unit_chip: Control = null
		for chip: Node in hand.get_cards():
			var bv: BannerView = hand.get_banner(chip)
			if bv != null and bv.entry.has("fp"):
				unit_chip = chip
				break
		assert_not_null(unit_chip, "%s a unit in hand" % label)
		if unit_chip != null:
			var hb: BannerView = hand.get_banner(unit_chip)
			var hr: Dictionary = hb.stat_rects()
			_check_anatomy(hb, "%s hand card" % label)
			# kc-cards-impl (X1): the banner draws the cost hex top-left (always shown in the hand).
			var hc: Rect2 = hb.anatomy_now()["cost"]
			assert_true(hb.full_info and hc.position.x < hb.size.x * 0.2 and hc.position.y < hb.size.y * 0.3, "%s hand: cost top-left" % label)
			# kc-ipad-cards: the X1 card draws its own badges (BannerCard.layout_for), at least the board's size.
			var hl: Dictionary = BannerCard.layout_for((unit_chip.get_node("Face") as Control).size, hb.entry)
			assert_true((hl["fp"] as Rect2).size.x >= (a2["fp"] as Rect2).size.x - 1.0 or hb.size.y < fr.banner.size.y,
					"%s hand badges are at least the board's size" % label)
			var name_l: Label = unit_chip.find_child("NameLabel", true, false)
			var rc_name: String = ""
			for rc: RulesCard in st.sides[0].hand:
				if rc.uid == int(unit_chip.get_meta(&"uid")):
					rc_name = rc.card.display_name
			# kc-onboard-ui: a Standard Issue name is stencil capitals; still the chassis name.
			assert_eq(name_l.text.to_upper(), rc_name.to_upper(), "%s hand card named by its chassis" % label)
		# Board banners show the cost top-left too (anatomy on every form); the inspector banner.
		_check_anatomy(fr.banner, "%s board (yours)" % label)
		_check_anatomy(er.banner, "%s board (rival)" % label)
		_despawn(s[0])
		await tree.process_frame
	# Full card face (inspector / mulligan CardView): FP and Armor side by side, bottom-right.
	assert_true(CardView.FP_RECT.position.x > CardView.BASE_SIZE.x * 0.4 and CardView.ARMOR_RECT.position.x > CardView.FP_RECT.end.x - 1.0,
			"CardView: FP then Armor, bottom-right")
	assert_true(CardView.FP_RECT.end.y > CardView.BASE_SIZE.y * 0.8 and CardView.ARMOR_RECT.end.y > CardView.BASE_SIZE.y * 0.8, "CardView: on the bottom")


## The head's card anatomy on one banner (kc-trait-ui, 2026-11-06): cost + name top-left, abilities
## top-right, trait + weapon-type bottom-left, FP + Armor side by side bottom-right.
## kc-cards-impl: the head's C1+ anatomy on one banner: the cost top-left (peek), traits bottom-left,
## FP reticle + Armor plate bottom-right; no name. kc-ipad-cards: abilities bottom-centre.
func _check_anatomy(b: BannerView, label: String) -> void:
	var a: Dictionary = b.anatomy_now()
	var sz: Vector2 = b.size
	var fp: Rect2 = a["fp"]
	var ar: Rect2 = a["armor"]
	assert_true(fp.position.x > sz.x * 0.5 and ar.position.x >= fp.end.x and ar.end.x > sz.x * 0.95, "%s: FP then Armor in the bottom-right (%s / %s)" % [label, fp, ar])
	assert_true(fp.end.y >= sz.y * 0.88 and ar.end.y >= sz.y * 0.88, "%s: stats on the bottom edge" % label)
	for key: String in ["cost", "level", "class"]:
		if a.has(key) and (a[key] as Rect2).size.x > 0.0:
			assert_true((a[key] as Rect2).position.x < sz.x * 0.5 and (a[key] as Rect2).position.y < sz.y * 0.3, "%s: %s top-left" % [label, key])
	assert_eq((a["name"] as Rect2).size.x, 0.0, "%s: no name on the banner" % label)
	if a.has("trait"):
		assert_true((a["trait"] as Rect2).position.x < sz.x * 0.5 and (a["trait"] as Rect2).end.y > sz.y * 0.6, "%s: trait bottom-left" % label)
	# kc-ipad-cards: abilities bottom-centre, between the trait and FP, as big as FP.
	for ab: Array in a["abilities"]:
		var r: Rect2 = ab[1]
		assert_true(r.position.x >= (a["trait"] as Rect2).end.x - 0.5 if a.has("trait") else r.position.x > 0.0, "%s: abilities right of the trait" % label)
		assert_true(r.end.x <= fp.position.x + 0.5 and r.end.y >= sz.y * 0.88, "%s: abilities bottom-centre" % label)
		if a.has("class"):
			assert_true((a["class"] as Rect2).end.x <= (ab[1] as Rect2).position.x + 0.5 or (ab[1] as Rect2).position.x > sz.x * 0.6,
					"%s: the peek group stops before the abilities" % label)


# =============================================================================
# 2. Codex: one tile per card, its arts with their traits (a viewer: no EQUIP, kc-trait-ui)
# =============================================================================

func test_codex_is_a_viewer_with_trait_slots() -> void:
	_reset_settings()
	var entries: Array[Dictionary] = CodexView.build_entries()
	var mk: Dictionary = {}
	for e: Dictionary in entries:
		if e["id"] == &"marksman":
			mk = e
	assert_false(mk.is_empty(), "Marksman in the codex")
	var card: CardData = CardDB.get_card(&"marksman")
	var arts: Array = mk["arts"]
	assert_eq(arts.size(), ArtTraits.arts_for(card).size(), "the codex lists ArtTraits.arts_for")
	var heavy_art: StringName = ArtTraits.default_art(card, &"heavy")
	assert_true(heavy_art in arts, "the Heavy option's art is listed (%s)" % heavy_art)
	# Grouped by the trait they give: the default option first.
	var seen_alt: bool = false
	for a: Variant in arts:
		var t: StringName = ArtTraits.trait_of(StringName(String(a)), card)
		if t != card.card_trait:
			seen_alt = true
		assert_false(seen_alt and t == card.card_trait, "arts grouped by trait (%s)" % a)
	var t0: Array = await _spawn_title(Layout.PHONE)
	var vp: SubViewport = t0[0]
	var title: Control = t0[1]
	title.open_codex()
	await _frames(3)
	var codex: Control = title.get_codex()
	var tile: Control = null
	for n: Node in codex.get_tiles():
		if n.get_meta(&"entry")["id"] == &"marksman":
			tile = n
	assert_not_null(tile, "a Marksman tile")
	# kc-cards-impl: Codex tiles are Y2+ cards (no art subname on them).
	var cv0: CardView = tile.find_child("Card", true, false) as CardView
	assert_true(cv0 != null and not cv0.data.has("subname"), "a Y2+ card without the subname")
	var k: float = Layout.points_per_px(Layout.PHONE)
	await _tap(vp, tile.get_global_rect().get_center())
	await _frames(2)
	assert_true(codex.is_art_panel_open(), "tap opens the ART panel")
	assert_eq(codex.get_art_tiles().size(), arts.size(), "one tile per art")
	assert_false(codex.has_method(&"get_equip_button"), "no EQUIP (head: the Codex is a viewer)")
	for at: Node in codex.get_art_tiles():
		var art: StringName = at.get_meta(&"art")
		var slot: Node = at.find_child("TraitSlot", true, false)
		assert_not_null(slot, "every art tile has a trait slot")
		assert_eq(slot.get_meta(&"trait"), ArtTraits.trait_of(art, card), "%s: the slot shows the trait the art gives" % art)
		var cv: CardView = at.find_child("Card", true, false) as CardView
		assert_eq(StringName(String(cv.data.get("trait", ""))), ArtTraits.trait_of(art, card), "%s: the card's trait chip" % art)
		assert_eq(bool(cv.data.get("not_found", false)), not codex.is_found(codex.art_entry, art), "%s: NOT FOUND YET when not found" % art)
		assert_true(minf((at as Control).size.x, (at as Control).size.y) * k >= 44.0 - EPS, "art tile 44 pt+")
	# Preview the Heavy art: GIVES HEAVY; the subname is in the more-info line, not on the card.
	for at: Node in codex.get_art_tiles():
		if at.get_meta(&"art") == heavy_art:
			await _tap(vp, (at as Control).get_global_rect().get_center())
	await _frames(2)
	assert_eq(codex.selected_art, heavy_art, "tap previews that art")
	assert_eq(codex.get_gives_label().text, "GIVES HEAVY", "the preview says what it gives")
	assert_true(String((codex.find_child("ArtTrait", true, false) as Label).text).contains("Can be: Spec Ops"), "the options line")
	for at: Node in codex.get_art_tiles():
		if ArtTraits.trait_of(at.get_meta(&"art"), card) == &"specops":
			await _tap(vp, (at as Control).get_global_rect().get_center())
			break
	await _frames(2)
	assert_eq(codex.get_gives_label().text, "GIVES SPEC OPS", "the Spec Ops art gives Spec Ops")
	# Found marks: the default art is found; an art a run copy wore becomes FOUND.
	assert_true(CodexView.is_found(mk, StringName(String(mk["art"]))), "the default art counts as found")
	_settings().found_arts = {}
	assert_false(CodexView.is_found(mk, heavy_art), "not found yet")
	_settings().mark_found([heavy_art])
	assert_true(CodexView.is_found(mk, heavy_art), "found after a run copy wore it")
	_settings().found_arts = {}
	# The inspector (long-press) names the chassis and carries the subname in its type line.
	codex.open_entry(mk, heavy_art)
	assert_eq(String((codex.get_inspector().get_node("%TitleLabel") as Label).text), "Marksman", "inspector title is the card name")
	var sub: String = BannerArtDB.subname(heavy_art)
	if sub != "":
		assert_true(String((codex.get_inspector().get_node("%TypeLabel") as Label).text).contains(sub.to_upper()), "inspector type line has the subname")
	codex.get_inspector().close()
	_despawn(vp)
	await tree.process_frame
	# Codex EQUIP (an old setting) no longer dresses matches: the rival and you wear arts of the copy's trait.
	_settings().equipped_arts = {"rifleman": "rifleman~night"}
	var cfg: RunConfig = CardDB.get_run_config()
	var player: SideSetup = SideSetup.new()
	for i: int in 3:
		player.deck.append(CardDB.get_card(&"rifleman"))
	var enemy: SideSetup = SideSetup.new()
	enemy.deck.append(card)
	enemy.deck_traits.append(&"heavy")
	var m: MatchState = MatchState.new(cfg, CardDB.get_map(&"port_vasel"), player, enemy, 7)
	MatchController._assign_copy_arts(m)
	assert_false(&"rifleman~night" in player.deck_arts, "EQUIP is not applied")
	assert_eq(ArtTraits.trait_of(enemy.deck_arts[0], card), &"heavy", "the rival's Heavy Marksman wears a Heavy art (%s)" % enemy.deck_arts[0])
	_reset_settings()


# =============================================================================
# 3. Starter deck screen + Operator choice used by the run
# =============================================================================

func test_starter_screen_and_operator_choice_used_by_the_run() -> void:
	_reset_settings()
	var rs: Node = tree.root.get_node("RunState")
	var saved_autosave: bool = rs.autosave
	rs.autosave = false
	rs.run_map_enabled = false  # kc-v2-impl: any Operator on the old ladder (map runs lock them: test_run_map.gd)
	var run: RunProgress = rs.start_run(4242)
	var cfg: RunConfig = run.config
	var options: Array[LoadoutItem] = RunProgress.operator_options(cfg)
	assert_true(options.size() >= 2, "more than one Operator to pick (%d)" % options.size())
	assert_eq(options[0], cfg.starter_primary, "today's Operator is the default, first")
	assert_eq(run.primary, cfg.starter_primary.id, "a new run starts with it")
	var other: LoadoutItem = options[1]
	var panel: Control = StarterPanel.new()
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(Layout.PHONE))
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	vp.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.setup(run, true, "NEXT: KILLSTREAKS")
	await _frames(3)
	# The starter deck, grouped with counts.
	var total: int = 0
	var ids: Dictionary = {}
	for tile: Control in panel.get_deck_tiles():
		total += int(tile.get_meta(&"count"))
		assert_false(ids.has(tile.get_meta(&"id")), "one tile per card")
		ids[tile.get_meta(&"id")] = true
		assert_not_null(tile.find_child("CountLabel", true, false), "a count on %s" % tile.get_meta(&"id"))
	assert_eq(total, cfg.starter_deck.size(), "the grouped deck adds up to the starter")
	assert_true(ids.size() < total, "copies are grouped")
	assert_eq(panel.get_operator_tiles().size(), options.size(), "a tile per Operator")
	var k: float = Layout.points_per_px(Layout.PHONE)
	for id: StringName in panel.get_operator_tiles():
		var b: Control = panel.get_operator_tiles()[id]
		assert_true(minf(b.size.x, b.size.y) * k >= 44.0 - EPS, "Operator tile %s is 44 pt+" % id)
	# Tap another Operator.
	var tile2: Control = panel.get_operator_tiles()[other.id]
	await _tap(vp, tile2.get_global_rect().get_center())
	assert_eq(run.primary, other.id, "the run starts with the picked Operator")
	assert_eq(String(_settings().operator_primary), String(other.id), "remembered for the next run")
	assert_true(tile2.find_child("SelectedTag", true, false).visible, "SELECTED on the pick")
	var side: SideSetup = run.player_setup()
	assert_eq(side.primary.id, other.id, "the player's side uses it")
	assert_eq(run.begin(), "", "the run begins")
	var md: MatchState = run.create_match()
	md.start_match()
	assert_eq(md.sides[0].operator_unit.weapon_class, other.weapon_class, "the match's Operator is the pick (class)")
	assert_eq(md.sides[0].operator_unit.base_max_armor, other.operator_armor + side.armor_bonus + other.armor_bonus, "the match's Operator is the pick (Armor)")
	var squad_primary: LoadoutItem = run.current_match().squad.primary if run.current_match() != null and run.current_match().squad != null else null
	assert_eq(md.sides[1].setup.primary, squad_primary, "the rival's Operator is unchanged")
	# A save keeps it.
	var loaded: Dictionary = RunProgress.from_dict(cfg, JSON.parse_string(JSON.stringify(run.to_dict())))
	assert_eq(loaded["error"], "", "the save loads")
	if loaded["run"] != null:
		assert_eq((loaded["run"] as RunProgress).primary, other.id, "the save keeps the Operator")
	# Long-press an Operator = its rules.
	panel.get_inspector().open(panel.operator_info(other))
	assert_eq(String((panel.get_inspector().get_node("%TitleLabel") as Label).text), other.display_name, "Operator rules")
	panel.get_inspector().close()
	vp.queue_free()
	await tree.process_frame
	# Only before the first match.
	assert_true(run.set_primary(options[0].id) != "", "no Operator change after the run began")
	# A new run starts with the remembered Operator; the quick match too.
	var run2: RunProgress = rs.start_run(4243)
	assert_eq(run2.primary, other.id, "the next run defaults to the last pick")
	var s: Array = await _spawn(Layout.DESKTOP)
	var c: Node = s[2]
	assert_eq(c.state.sides[0].setup.primary.id, other.id, "the quick match uses the pick")
	_despawn(s[0])
	await tree.process_frame
	rs.reset()
	rs.autosave = saved_autosave
	rs.run_map_enabled = true
	_reset_settings()


func test_codex_starter_button_opens_the_starter_deck() -> void:
	_reset_settings()
	var t: Array = await _spawn_title(Layout.PHONE)
	var vp: SubViewport = t[0]
	var title: Control = t[1]
	title.open_codex()
	await _frames(3)
	var codex: Control = title.get_codex()
	await _tap(vp, codex.get_starter_button().get_global_rect().get_center())
	await _frames(3)
	var starter: Control = codex.get_starter()
	assert_not_null(starter, "STARTER opens the starter deck from the codex")
	if starter != null:
		assert_true(starter.get_deck_tiles().size() > 0, "deck shown")
		await _tap(vp, starter.get_close_button().get_global_rect().get_center())
		await _frames(2)
		assert_true(codex.get_starter() == null, "BACK closes it")
	_despawn(vp)
	await tree.process_frame


# =============================================================================
# Glossary
# =============================================================================

func test_every_keyword_in_data_has_a_glossary_entry_and_icon() -> void:
	var all: Array[Dictionary] = Glossary.entries()
	var by_key: Dictionary = {}
	for e: Dictionary in all:
		by_key[e["key"]] = e
		assert_true(String(e["text"]) != "" and String(e["name"]) != "", "%s has words" % e["key"])
	var used: Dictionary = {}
	for card: CardData in CardDB.all_cards():
		for k: Dictionary in CardInfo.keywords(card):
			used[k["id"]] = true
		if card.neighbor_keyword != &"":
			used[StringName("kw_" + String(card.neighbor_keyword))] = true
		if card.card_trait != &"":
			used[StringName("trait_" + String(card.card_trait))] = true
		if card.is_field():
			used[&"field"] = true
	assert_true(used.size() >= 8, "keywords found in the data (%d)" % used.size())
	for id: StringName in used:
		var key: StringName = Glossary.key_for(id)
		assert_true(key != &"", "%s has a glossary entry" % id)
		if key == &"":
			continue
		var e: Dictionary = by_key[key]
		assert_true(e["icon"] != &"" or e["drawn"] != &"" or e.has("kw") or e.has("trait"), "%s has an icon" % id)
	for k: StringName in CardInfo.KEYWORD_RULES:
		assert_true(by_key.has(k), "KEYWORD_RULES %s is in the glossary" % k)
	# kc-pos-cut: the neighbour keywords are retired: none in the glossary.
	for kw: StringName in SynergyRules.KEYWORDS:
		assert_false(by_key.has(StringName("kw_" + String(kw))), "no neighbor keyword %s" % kw)
	for tr: StringName in SynergyRules.TRAITS:
		assert_true(String(by_key[StringName("trait_" + String(tr))]["text"]).contains(SynergyRules.TIER_TEXT[tr][1]), "trait %s tier texts" % tr)
	for k: StringName in [&"firepower", &"armor", &"cover_stat", &"supply", &"stat_colours", &"control", &"set_callout", &"doctrine"]:
		assert_true(by_key.has(k), "%s entry" % k)


func test_glossary_from_menu_codex_and_inspector() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	c.open_pause_menu()
	await _frames(2)
	var pause: Control = m.get_pause_menu()
	var gb: Button = pause.get_glossary_button()
	var screen_r: Rect2 = Rect2(Vector2.ZERO, Vector2(vp.size)).grow(EPS)
	assert_true(gb.is_visible_in_tree() and screen_r.encloses(gb.get_global_rect()), "MENU has GLOSSARY on screen")
	await _tap(vp, gb.get_global_rect().get_center())
	await _frames(3)
	var g: Control = pause.get_glossary()
	assert_not_null(g, "GLOSSARY opens")
	var k: float = Layout.points_per_px(Layout.PHONE)
	if g != null:
		for b: Control in [g.get_back_button(), g.get_search(), g.get_category_button(&"synergy")]:
			assert_true(minf(b.size.x, b.size.y) * k >= 44.0 - EPS, "%s 44 pt+" % b.name)
		var n_all: int = g.filtered().size()
		g.set_category(&"synergy")
		assert_true(g.filtered().size() < n_all and g.filtered().size() >= 8, "SYNERGY category")
		g.set_category(&"all")
		g.set_query("pick")
		assert_true(g.filtered().size() >= 1 and g.get_row(&"pick") != null, "search finds Pick")
		g.close()
		await _frames(2)
	c.close_pause_menu()
	# Inspector: "?" on a keyword line opens the glossary at it.
	var chosen: RulesCard = null
	for rc: RulesCard in c.state.sides[0].hand + c.state.sides[0].deck:
		if not CardInfo.keywords(rc.card).is_empty():
			chosen = rc
			break
	assert_not_null(chosen, "a card with a keyword")
	if chosen != null:
		var info: Dictionary = CodexView.inspector_info({"kind": &"unit" if chosen.card.is_unit() else &"tactic", "card": chosen.card,
				"id": chosen.card.id, "art": chosen.card.id, "arts": [chosen.card.id]})
		var insp: Control = m.get_inspector()
		insp.open(info)
		await _frames(3)
		var link: Button = insp.find_child("GlossaryLink", true, false) as Button
		assert_not_null(link, "a ? on the keyword line")
		if link != null:
			assert_true(minf(link.size.x, link.size.y) * k >= 44.0 - EPS, "? is 44 pt+")
			link.pressed.emit()
			await _frames(3)
			var g2: Node = insp.get_node_or_null(^"Glossary")
			assert_not_null(g2, "? opens the glossary")
			if g2 != null:
				assert_not_null(g2.get_row(StringName(link.get_meta(&"glossary_key"))), "at that entry")
				g2.close()
		insp.close()
	_despawn(vp)
	await tree.process_frame


# =============================================================================
# Helpers
# =============================================================================

func _spawn(screen: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	return [vp, m, c]


func _spawn_title(screen: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var t: Control = (load(TITLE_SCENE) as PackedScene).instantiate()
	vp.add_child(t)
	await _frames(4)
	return [vp, t]


func _despawn(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _mouse(vp: SubViewport, pos: Vector2, pressed: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	vp.push_input(e)


func _tap(vp: SubViewport, pos: Vector2) -> void:
	_mouse(vp, pos, true)
	await _frames(1)
	_mouse(vp, pos, false)
	await _frames(3)
