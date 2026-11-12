# test_cards_v2.gd
# Purpose: kc-cards-impl (the head's picks, documentation/ux/card-design-options.html):
#   - C1+ board card: at rest vs peek (the cost only on hover, hold, in the hand or
#     with Settings > Cards > "Always show all card info"); faint vs lit traits; the damaged plate
#     (amber, the number left, the bottom edge + crack); the FP reticle in team colour; no spine, no
#     serial plate; full-strength art;
#   - the synergy rail highlight (hover / tap pins a trait: the matching cards glow, the rest dim);
#   - H1: tap a card (it lifts, the Y2+ preview docks with CANCEL, legal slots say PLAY HERE), tap a
#     slot to place; cancel by the card again, CANCEL or the empty board;
#   - O2: the Operator card bottom-left of the tray, UNDO (icon) over READY, its states;
#   - Y2+ / T1 frames (layout, tactic chevron cut, no stats bar, NOT FOUND YET; kc-ipad-cards: no Trains line);
#   - one title style everywhere (Barlow Condensed Bold 16 px, UPPERCASE, #F2F5F7);
#   - the new Pick icon (not the sheet's crosshair, UiKit first).
# Author: UI/UX Agent (kc-cards-impl)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const BoardMetrics: GDScript = preload("res://scripts/ui/board_metrics.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const CARD_SCENE: String = "res://scenes/match/CardView.tscn"
const EPS: float = 0.6

var _saved_root_size: Vector2i = Vector2i.ZERO


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


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


func _despawn(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size


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


func _banner(entry: Dictionary, sz: Vector2 = Vector2(228, 57), side: StringName = &"player") -> BannerView:
	var b: BannerView = BannerView.new()
	tree.root.add_child(b)
	b.size = sz
	b.show_unit(entry, side, false)
	return b


const UNIT: Dictionary = {"name": "Rifleman", "cls": "AR", "fp": 3, "armor": 4, "armor_max": 4, "banner": "rifleman", "cost": 2,
		"keywords": [{"id": &"pick"}], "trait": "vanguard", "trait_tier": 1}


# =============================================================================
# C1+ board card
# =============================================================================

func test_at_rest_vs_peek() -> void:
	var b: BannerView = _banner(UNIT)
	BannerView.show_all = false
	var a: Dictionary = b.anatomy_now()
	assert_false(b.is_peeking(), "a board card is quiet at rest")
	assert_true(a.has("cost") and (a["cost"] as Rect2).size.x > 0.0, "the cost slot exists (shown on peek)")
	assert_true((a["cost"] as Rect2).position.x < 228.0 * 0.5 and (a["cost"] as Rect2).position.y < 57.0 * 0.3, "cost top-left")
	# kc-ipad-cards: no level coin, no weapon pill.
	assert_false(a.has("level") or a.has("class"), "no level coin or weapon pill slot")
	assert_eq((a["name"] as Rect2).size.x, 0.0, "no name on the board card")
	var fr: Rect2 = a["fp"]
	var tr: Rect2 = a["trait"]
	assert_false(a["abilities"].is_empty(), "the unit shows its ability")
	for ab: Array in a["abilities"]:
		var r: Rect2 = ab[1]
		assert_true(r.size.x >= fr.size.x - 0.5, "kc-ipad-cards: the ability icon is as big as the FP reticle (%s vs %s)" % [r.size, fr.size])
		assert_true(r.position.x >= tr.end.x and r.end.x <= fr.position.x and absf(r.end.y - fr.end.y) < 1.0,
				"abilities bottom-centre, between the trait and the stats")
	assert_true(fr.size.x >= 25.0 and (a["armor"] as Rect2).position.x > fr.position.x, "FP reticle then Armor bottom-right")
	assert_true(tr.position.x < 20.0 and tr.end.y > 50.0, "trait bottom-left")
	assert_true(tr.size.x >= fr.size.x - 0.5, "kc-ipad-cards: the trait chip is as big as the FP reticle")
	assert_false(tr.intersects(a["cost"]), "the cost hex stays clear of the trait")
	# The top-right placement still works (the comparison shots).
	BannerView.ABILITIES_BOTTOM = false
	var a2: Dictionary = b.anatomy_now()
	BannerView.ABILITIES_BOTTOM = true
	for ab: Array in a2["abilities"]:
		assert_true((ab[1] as Rect2).position.x > 228.0 * 0.5 and (ab[1] as Rect2).position.y < 10.0, "abilities top-right when switched")
	b.peek = true
	assert_true(b.is_peeking(), "hover / hold peeks")
	b.peek = false
	b.full_info = true
	assert_true(b.is_peeking(), "hand cards always show everything")
	b.full_info = false
	BannerView.show_all = true
	assert_true(b.is_peeking(), "Settings > Cards > Always show all card info")
	BannerView.show_all = false
	# Desktop banner scales the same layout (k = 76 / 57).
	var d: BannerView = _banner(UNIT, Vector2(304, 76))
	var ad: Dictionary = d.anatomy_now()
	assert_true(absf((ad["abilities"][0][1] as Rect2).size.x - 40.0) <= 1.0, "desktop abilities 40 px (30k, kc-ipad-cards)")
	b.free()
	d.free()


func test_show_all_setting_persists_and_redraws() -> void:
	var st: Node = tree.root.get_node("Settings")
	var was: bool = st.show_all_card_info
	assert_true(&"show_all_card_info" in st.PERSISTED_KEYS, "the setting is saved between sessions")
	st.set_value(&"show_all_card_info", true)
	assert_true(BannerView.show_all, "the setting reaches every banner")
	st.set_value(&"show_all_card_info", false)
	assert_false(BannerView.show_all, "and off again")
	st.show_all_card_info = was
	# The MENU sheet's toggle.
	var pm: Control = (load("res://scenes/match/PauseMenu.tscn") as PackedScene).instantiate()
	tree.root.add_child(pm)
	await _frames(2)
	pm.open({})
	var btn: Button = pm.get_card_info_button()
	assert_not_null(btn, "MENU has ALL CARD INFO")
	assert_true(btn.text.begins_with("ALL CARD INFO"), "labelled")
	btn.button_pressed = true
	assert_true(st.show_all_card_info and BannerView.show_all, "the toggle sets it")
	btn.button_pressed = false
	pm.free()
	st.show_all_card_info = was


func test_traits_faint_vs_lit_and_no_spine_or_serial() -> void:
	var b: BannerView = _banner(UNIT)
	assert_false(b.trait_lit(), "tier 1: faint")
	assert_eq(CardLook.TRAIT_FAINT, 0.45, "faint = 45%")
	var lit: Dictionary = UNIT.duplicate()
	lit["trait_tier"] = 2
	b.show_unit(lit, &"player", false)
	assert_true(b.trait_lit(), "tier 2: lit")
	assert_eq(b.trait_list(), [&"vanguard"] as Array[StringName], "its trait")
	# Standard Issue: no serial plate in the abilities; no spine (metrics).
	var si: Dictionary = UNIT.duplicate()
	si["standard_issue"] = true
	si["serial"] = "SI-02"
	for k: Variant in BannerView.ability_kinds(si):
		assert_false(k is Array and k[0] == &"serial", "no serial plate on cards")
	assert_eq(BannerView.metrics(57.0)["spine"], 0.0, "no side spine")
	assert_true(b.get_art_modulate().r > 0.99, "the art is never dimmed")
	b.free()


func test_damaged_plate_and_team_reticle() -> void:
	var dmg: Dictionary = UNIT.duplicate()
	dmg["armor"] = 2
	var b: BannerView = _banner(dmg)
	assert_true(int(b.entry["armor"]) < int(b.entry["armor_max"]), "damaged")
	assert_eq(CardLook.AR_DMG_EDGE, Color("#F2A33A"), "amber, never red")
	assert_eq(CardLook.team_of(&"player"), &"player", "yours: teal")
	assert_eq(CardLook.team_of(&"enemy"), &"enemy", "the rival's: red")
	assert_eq((CardLook.TEAM[&"player"] as Array)[0], Color("#2EC4B6"), "teal reticle")
	assert_eq((CardLook.TEAM[&"enemy"] as Array)[0], Color("#FF5A5D"), "red reticle")
	assert_eq(CardLook.trend_color(1), CardLook.UP, "buffed = green")
	# The banner draws the damage edge + crack and an amber plate (CardLook), at rest and on peek.
	assert_true(b.anatomy_now().has("armor"), "the plate is drawn bottom-right")
	b.free()


func test_rail_highlight_glows_matching_and_dims_the_rest() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var st: MatchState = c.state
	var mk: RulesUnit = st.create_unit(0, CardDB.get_card(&"rifleman"))
	st.put_in_line(mk, 0)
	var other: RulesUnit = st.create_unit(0, CardDB.get_card(&"breacher"))
	st.put_in_line(other, 1)
	mk.synergy_trait = &"vanguard"
	other.synergy_trait = &"heavy"
	c.refresh()
	await _frames(3)
	var rail: Control = m.get_trait_rail()
	var fr: BannerView = m.get_board().get_lanes()[0].get_friendly_slots()[0].banner
	var br: BannerView = m.get_board().get_lanes()[1].get_friendly_slots()[0].banner
	var t: StringName = StringName(String(fr.entry.get("trait", "")))
	assert_true(t != &"", "the Rifleman has a trait")
	rail.pin(t)
	await _frames(2)
	assert_eq(fr.syn_focus, t, "the board gets the highlight")
	assert_true(fr.get_art_modulate().r > 0.99, "a matching card keeps full art (and glows)")
	if StringName(String(br.entry.get("trait", ""))) != t:
		assert_true(br.get_art_modulate().r < 0.6, "the rest dim (%.2f)" % br.get_art_modulate().r)
	# Tap the pinned chip again: off.
	rail.pin(&"")
	await _frames(1)
	assert_eq(fr.syn_focus, &"", "unpinned")
	assert_true(br.get_art_modulate().r > 0.99, "nothing dimmed")
	_despawn(vp)
	await tree.process_frame


# =============================================================================
# H1 + O2
# =============================================================================

func test_h1_select_place_and_cancel() -> void:
	for screen: Dictionary in [Layout.PHONE, Layout.DESKTOP]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		var label: String = screen["name"]
		var hand: Control = m.get_hand()
		var chip: Control = null
		var rc0: RulesCard = null
		afford_a_unit(c)
		await _frames(2)
		for rc: RulesCard in c.state.sides[0].hand:
			if rc.card.is_unit() and rc.card.cost <= c.state.sides[0].supply:
				chip = hand.get_card(rc.uid)
				rc0 = rc
				break
		assert_not_null(chip, "%s: a playable unit" % label)
		if chip == null:
			_despawn(vp)
			continue
		var y0: float = chip.position.y
		await _tap(vp, chip.get_global_rect().get_center())
		await _frames(2)
		assert_eq(c.selection.get("uid", -1), rc0.uid, "%s: tap selects" % label)
		assert_true(chip.position.y < y0, "%s: the card lifts" % label)
		var dock: Control = m.get_card_dock()
		assert_not_null(dock, "%s: the Y2+ preview docks over the tray" % label)
		assert_eq(m.get_dock_card().data.get("name"), rc0.card.display_name, "%s: the selected card" % label)
		assert_true(m.get_dock_cancel_button().is_visible_in_tree(), "%s: CANCEL" % label)
		var k: float = Layout.points_per_px(screen)
		assert_true(m.get_dock_cancel_button().size.y * k >= 44.0 - EPS, "%s: CANCEL >= 44 pt" % label)
		var play_here: int = 0
		for lane: Node in m.get_board().get_lanes():
			if lane.get_play_here() != null:
				play_here += 1
		assert_true(play_here > 0, "%s: the legal slots say PLAY HERE" % label)
		# Cancel by tapping the card again.
		await _tap(vp, chip.get_global_rect().get_center())
		await _frames(2)
		assert_true(c.selection.is_empty(), "%s: tap again cancels" % label)
		assert_true(m.get_card_dock() == null, "%s: the dock closes" % label)
		# CANCEL.
		c.select_card(rc0.uid)
		await _frames(2)
		await _tap(vp, m.get_dock_cancel_button().get_global_rect().get_center())
		await _frames(2)
		assert_true(c.selection.is_empty(), "%s: CANCEL cancels" % label)
		# The empty board.
		c.select_card(rc0.uid)
		await _frames(2)
		m.get_board().empty_tapped.emit()
		await _frames(2)
		assert_true(c.selection.is_empty(), "%s: the empty board cancels" % label)
		# Place: select, then tap a PLAY HERE slot.
		c.select_card(rc0.uid)
		await _frames(2)
		var target: Label = null
		for lane: Node in m.get_board().get_lanes():
			if lane.get_play_here() != null:
				target = lane.get_play_here()
				break
		await _tap(vp, target.get_global_rect().get_center())
		await _frames(3)
		var planned: bool = false
		for p: Dictionary in c.state.sides[0].plays:
			planned = planned or (p.get("card") != null and (p["card"] as RulesCard).uid == rc0.uid)
		assert_true(planned, "%s: a tap on PLAY HERE places the card" % label)
		assert_true(m.get_card_dock() == null, "%s: placed: the dock closes" % label)
		_despawn(vp)
		await tree.process_frame


func test_hand_x1_cards_fit_and_operator_row() -> void:
	for screen: Dictionary in [Layout.PHONE, Layout.DESKTOP]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var label: String = screen["name"]
		var met: Dictionary = m.metrics
		var k: float = Layout.points_per_px(screen)
		var grid: Rect2 = met["grid"]
		var hand: Control = m.get_hand()
		var fit: Dictionary = hand.hand_fit
		var card: Vector2 = fit["card"]
		var cols: int = int(fit["cols"])
		var n: int = hand.get_cards().size() + 1  # kc-layout-a: + the Operator card
		var rows: int = ceili(float(n) / cols)
		assert_true(rows * card.y + (rows - 1) * float(met["card_gap"]) <= grid.size.y + EPS, "%s: %d cards fit" % [label, n])
		for chip: Node in hand.get_cards():
			var bv: BannerView = hand.get_banner(chip)
			assert_true(bv.full_info, "%s: hand banners show everything" % label)
			# kc-ipad-cards: X1 = the banner (cover-cropped, between 2.4:1 and ~5:1) + the name plate.
			var ratio: float = bv.size.x / bv.size.y
			assert_true(ratio >= BannerCard.BANNER_MAX_RATIO - 0.1 and ratio <= BannerCard.BANNER_MIN_RATIO + 0.1, "%s: banner %s" % [label, bv.size])
			var plate: Control = chip.find_child("NamePlate", true, false)
			assert_true(plate.position.y >= bv.position.y + bv.size.y - EPS, "%s: the name plate under the banner" % label)
			var nl: Label = chip.find_child("NameLabel", true, false)
			assert_true(nl.has_meta(&"title_style"), "%s: the name plate in the title style" % label)
			assert_true((chip as Control).size.y * k >= 44.0 - EPS, "%s: hand card >= 44 pt" % label)
		# kc-layout-a (the head's L3): the Operator card is the hand grid's first card; UNDO (icon) and
		# READY share the bottom row under the grid.
		var op: Control = hand.get_operator_card()
		assert_not_null(op, "%s: the Operator card" % label)
		var undo: Button = m.get_undo_button()
		var ready: Button = m.get_ready_button()
		var orr: Rect2 = op.get_global_rect()
		for chip2: Node in hand.get_cards():
			assert_true(orr.position.y <= (chip2 as Control).get_global_rect().position.y + 7.0, "%s: the Operator in the grid's top row" % label)
		assert_true(absf(orr.size.x - card.x) < 1.0 and absf(orr.size.y - card.y) < 1.0, "%s: the Operator the size of a hand card" % label)
		assert_true(undo.get_global_rect().end.x <= ready.get_global_rect().position.x + EPS, "%s: UNDO left of READY" % label)
		assert_true(absf(undo.get_global_rect().position.y - ready.get_global_rect().position.y) < 1.0, "%s: UNDO and READY share a row" % label)
		assert_true(orr.end.y <= undo.get_global_rect().position.y + EPS, "%s: the grid above UNDO / READY" % label)
		assert_eq(undo.text, "", "%s: UNDO is an icon" % label)
		assert_true(undo.size.y * k >= 44.0 - EPS and ready.size.y * k >= 44.0 - EPS, "%s: 44 pt+" % label)
		var status: Label = op.find_child("OperatorStatus", true, false)
		assert_true(status.text in ["DEPLOY", "ON BOARD", "DOWN"] or status.text.begins_with("NEED") or status.text.begins_with("PLAN")
				or status.text.begins_with("ON BOARD"), "%s: a state (%s)" % [label, status.text])
		assert_true((op.find_child("NameLabel", true, false) as Label).has_meta(&"title_style"), "%s: Operator name in the title style" % label)
		_despawn(vp)
		await tree.process_frame


func test_operator_states() -> void:
	var MatchScreen: GDScript = load("res://scripts/ui/match_screen.gd")
	var base: Dictionary = {"operator": {"name": "Kestrel", "fp": 3, "armor": 7, "armor_max": 7, "zone": "OFF BOARD"}, "deploy_open": true}
	var snap: Dictionary = base.duplicate(true)
	snap["operator_can_deploy"] = true
	assert_eq(MatchScreen.operator_card_entry(snap)["state"], &"deploy", "Deploy")
	var on: Dictionary = base.duplicate(true)
	on["operator"]["on_board"] = true
	on["operator"]["zone_label"] = "B"
	# kc-loadout-clean: on the board the card is DEPLOYED (the ability button).
	assert_eq(MatchScreen.operator_card_entry(on)["state"], &"deployed", "On board = deployed")
	assert_eq(MatchScreen.operator_card_entry(on)["status"], "DEPLOYED · B", "says where")
	var down: Dictionary = base.duplicate(true)
	assert_eq(MatchScreen.operator_card_entry(down)["state"], &"down", "Down")
	var hand: Control = (load("res://scenes/match/HandArea.tscn") as PackedScene).instantiate()
	tree.root.add_child(hand)
	await _frames(1)
	for pair: Array in [[{"state": &"deploy", "can_afford": false, "cost": 1}, "NEED 1 SUPPLY"], [{"state": &"board", "zone_label": "B", "row": 1}, "ON BOARD · B1"], [{"state": &"deployed", "status": "DEPLOYED · B"}, "DEPLOYED · B"],
			[{"state": &"down"}, "DOWN"], [{"state": &"deploy", "cost": 1}, "DEPLOY"]]:
		var e: Dictionary = {"name": "Kestrel", "fp": 3, "armor": 7, "armor_max": 7}
		e.merge(pair[0])
		hand.set_operator(e)
		hand.set_hand([])
		await _frames(1)
		var st: Label = hand.get_operator_card().find_child("OperatorStatus", true, false)
		assert_eq(st.text, pair[1], "Operator state %s" % pair[1])
		if pair[1] == "NEED 1 SUPPLY":
			assert_true(bool(hand.get_operator_card().get_meta(&"operator_short")), "need supply: red cost hex")
	hand.free()


# =============================================================================
# Y2+ / T1 and the one title style
# =============================================================================

func _card_view(view: Dictionary, w: float) -> CardView:
	var cv: CardView = (load(CARD_SCENE) as PackedScene).instantiate()
	tree.root.add_child(cv)
	cv.set_card_data(view)
	cv.set_card_width(w)
	return cv


func test_y2plus_and_t1_frames() -> void:
	var unit: CardView = _card_view(CardView.view_for_card(CardDB.get_card(&"marksman")), 196)
	await _frames(1)
	assert_eq(unit.size, CardView.size_for(196), "laid out at its width")
	var rg: Dictionary = unit.regions()
	var art: Rect2 = rg["art"]
	assert_eq(art.size.y, roundf((196.0 - 8.0) / 4.0), "the art is 4:1")
	assert_true(art.position.y >= (rg["title"] as Rect2).end.y - 0.5, "nothing over the art: the title is above it")
	assert_true((rg["type"] as Rect2).position.y >= art.end.y, "type line under the art")
	assert_true((rg["bar"] as Rect2).size.y > 0.0, "units have the stats bar")
	assert_true((rg["traits"] as Rect2).position.x < 40.0 and (rg["fp"] as Rect2).position.x > 120.0, "traits bottom-left, FP / Armor bottom-right")
	assert_false(unit.get_text_lines().is_empty(), "keyword lines in the text box")
	var tac: CardView = _card_view(CardView.view_for_card(CardDB.get_card(&"suppressing_fire")), 196)
	await _frames(1)
	assert_true(tac.is_tactic(), "a Tactic")
	assert_false(tac.has_stats_bar(), "T1: no stats bar")
	assert_true((tac.regions()["text"] as Rect2).size.y > (rg["text"] as Rect2).size.y + 20.0, "T1: a bigger text box")
	var cut: PackedVector2Array = CardView.outline(Rect2(0, 0, 196, 200), CardView.T1_CUT)
	assert_true(cut.has(Vector2(196.0 - CardView.T1_CUT, 0.0)) and cut.has(Vector2(196.0, CardView.T1_CUT)), "T1: the chevron-cut top-right corner")
	assert_eq(tac._frame_colors()[0], CardView.FRAME_T1, "T1: khaki orders frame")
	# kc-no-training: no Recruit, so no greyed Trains line on any card.
	for id: StringName in [&"breacher", &"marksman", &"flanker", &"gunner"]:
		var cd: CardData = CardDB.get_card(id)
		if cd != null:
			var cv2: CardView = _card_view(CardView.view_for_card(cd), 196)
			await _frames(1)
			assert_false(cv2.get_text_lines().any(func(l: Dictionary) -> bool: return l["name"] == "Trains:"), "%s: no Trains line" % id)
			cv2.free()
	# NOT FOUND YET (Codex).
	var nf: Dictionary = CardView.view_for_card(CardDB.get_card(&"marksman"))
	nf["not_found"] = true
	var nfv: CardView = _card_view(nf, 172)
	await _frames(1)
	assert_true((nfv.find_child("NotFoundLabel", true, false) as Label).visible, "NOT FOUND YET over the art")
	for v: CardView in [unit, tac, nfv]:
		v.free()


func test_single_title_style_everywhere() -> void:
	assert_eq(CardLook.TITLE_FONT.resource_path, "res://assets/fonts/BarlowCondensed-Bold.ttf", "Barlow Condensed Bold")
	assert_true(FileAccess.file_exists("res://assets/fonts/OFL-BarlowCondensed.txt"), "its OFL licence is bundled")
	var titles: Array[Label] = []
	var cv: CardView = _card_view(CardView.view_for_card(CardDB.get_card(&"marksman")), 196)
	await _frames(1)
	titles.append(cv.find_child("NameLabel", true, false))
	var x1: PanelContainer = BannerCard.build(BannerCard.entry_for_card(CardDB.get_card(&"si_grunt")), BoardMetrics.x1_size(177))
	tree.root.add_child(x1)
	await _frames(1)
	titles.append(x1.find_child("NameLabel", true, false))
	for l: Label in titles:
		assert_eq(l.get_theme_font(&"font"), CardLook.TITLE_FONT, "%s: Barlow Condensed Bold" % l.get_path())
		assert_eq(l.get_theme_font_size(&"font_size"), 16, "16 px canvas")
		assert_eq(l.get_theme_color(&"font_color"), CardLook.TITLE_COLOR, "#F2F5F7")
		assert_true(l.uppercase or l.text == l.text.to_upper(), "UPPERCASE")
		assert_true(l.get_theme_font(&"font") != StandardIssueLook.stencil(), "no stencil title")
	cv.free()
	x1.free()


func test_pick_icon_is_not_a_crosshair() -> void:
	var t: Texture2D = IconSheet.get_keyword_icon(&"pick")
	assert_not_null(t, "Pick has an icon")
	assert_true(t != IconSheet.get_sheet_icon(&"kw_pick"), "not the old sheet crosshair")
	assert_eq(t, IconSheet.get_icon(&"kw_pick"), "the same icon everywhere (glossary, inspector, cards)")
	assert_true(t.get_width() >= 32, "a real texture")


# =============================================================================
# Coordinator follow-up: the objective row and the mulligan faces
# =============================================================================

func test_objective_row_clear_of_banners_and_front_tabs() -> void:
	for screen: Dictionary in [Layout.PHONE, Layout.DESKTOP]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		var label: String = screen["name"]
		var st: MatchState = c.state
		for side: int in 2:
			for z: int in 3:
				st.put_in_line(st.create_unit(side, CardDB.get_card(&"rifleman")), z)
		c.refresh()
		await tree.create_timer(1.0).timeout
		await _frames(2)
		for lane: Node in m.get_board().get_lanes():
			var tile: Rect2 = (lane.get_objective_tile() as Control).get_rect()
			var tabs: Dictionary = lane.front_tab_rects()
			assert_eq(tabs.size(), 2, "%s: both FRONT tabs" % label)
			for slot: Node in lane.get_friendly_slots() + lane.get_enemy_slots():
				var sr: Rect2 = (slot as Control).get_global_rect()
				var b: Rect2 = (slot.get(&"banner") as BannerView).get_global_rect()
				assert_true(b.is_equal_approx(sr), "%s: the banner rests in its slot (%s / %s)" % [label, b, sr])
				var local: Rect2 = Rect2((slot as Control).position, (slot as Control).size)
				assert_false(local.intersects(tile), "%s: no banner over the objective tile" % label)
				for t: Rect2 in tabs.values():
					assert_false(local.intersects(t), "%s: no FRONT tab over a banner" % label)
			var fa: Rect2 = (lane.get_objective_tile() as Control).field_area()
			fa.position += tile.position
			for t: Rect2 in tabs.values():
				assert_true(tile.encloses(t), "%s: the FRONT tab sits inside the tile's margin" % label)
				assert_false(t.intersects(fa), "%s: kc-abc-labels: the FRONT tab stays off the Field chips" % label)
				# The tile's words / mark live in the middle band; the tab stays in the margin.
				var mid: float = tile.size.y * 0.5
				assert_true(absf(t.get_center().y - (tile.position.y + mid)) >= mid - (16.0 if m.compact else 30.0),
						"%s: the tab is in the tile's top / bottom margin" % label)
		_despawn(vp)
		await tree.process_frame


func test_mulligan_faces_show_type_and_text() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var c: Node = s[2]
	var views: Array = []
	for rc: RulesCard in c.state.sides[0].hand:
		views.append([rc, c.card_view_for(rc)])
	assert_false(views.is_empty(), "a hand")
	for pair: Array in views:
		var rc: RulesCard = pair[0]
		var cv: CardView = _card_view(pair[1], 196)
		await _frames(1)
		var tl: Label = cv.find_child("TypeLabel", true, false)
		assert_true(tl.text != "", "%s: a type line" % rc.card.display_name)
		if rc.card.standard_issue:
			assert_true(tl.text.contains("STANDARD ISSUE"), "%s: STANDARD ISSUE tag" % rc.card.display_name)
			assert_true(cv.get_lore_text() != "", "%s: a vanilla card shows its lore line" % rc.card.display_name)
		var body: Label = cv.find_child("BodyLabel", true, false)
		var has_text: bool = (body.visible and body.text != "" and body.size.y >= 16.0) or not cv.get_text_lines().is_empty() \
				or cv.get_lore_text() != ""
		assert_true(has_text, "%s: the text box says something" % rc.card.display_name)
		cv.free()
	_despawn(vp)
	await tree.process_frame


# =============================================================================
# kc-hand-y2: lore for cards with no effect
# =============================================================================

func test_lore_line_only_without_effect() -> void:
	var grunt: CardView = _card_view(CardView.view_for_card(CardDB.get_card(&"si_grunt")), 196)
	await _frames(1)
	assert_eq(grunt.get_lore_text(), CardLore.line(&"si_grunt"), "a vanilla Standard Issue card: its lore line")
	var lore: Label = grunt.find_child("LoreLabel", true, false)
	assert_eq(lore.get_theme_font(&"font"), CardLook.LORE_FONT, "Barlow Condensed Medium Italic")
	assert_eq(lore.get_theme_color(&"font_color"), Color("#8A949C"), "dark grey")
	assert_eq(lore.vertical_alignment, VERTICAL_ALIGNMENT_BOTTOM, "at the bottom of the text box")
	var box: Rect2 = grunt.regions()["text"]
	var lr: Rect2 = Rect2(lore.position, lore.size)
	assert_true(lr.end.y <= box.end.y + 0.5 and lr.position.x >= box.position.x and lr.end.x <= box.end.x, "bottom of the text box (%s in %s)" % [lr, box])
	assert_false(grunt.find_child("BodyLabel", true, false).visible, "no effect text")
	var mk: CardView = _card_view(CardView.view_for_card(CardDB.get_card(&"marksman")), 196)
	var tac: CardView = _card_view(CardView.view_for_card(CardDB.get_card(&"ammo_resupply")), 196)
	await _frames(1)
	assert_eq(mk.get_lore_text(), "", "a card with a keyword: no lore")
	assert_eq(tac.get_lore_text(), "", "a Tactic with an effect: no lore")
	for id: StringName in CardLore.LINES:
		assert_true(CardDB.get_card(id) != null, "%s: a real card" % id)
		assert_true(String(CardLore.LINES[id]).length() <= 70, "%s: short" % id)
	for v: CardView in [grunt, mk, tac]:
		v.free()
