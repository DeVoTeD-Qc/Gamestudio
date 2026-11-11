# test_card_art_views.gd
# Purpose: k-art4 painted art on the small card views. Hand chips show the card's art band under
#   the name (stats / keywords on plates, tactic chips trade their cut-off rules line for the art),
#   board unit slots show the unit's art cropped to the slot (never mirrored since kc-pitch-art, side in the frame
#   and tab, silhouette only as the no-art fallback), mulligan buttons carry art too (the Loadout
#   killstreak tiles are covered by test_run_screens' layout checks). The full-board layout and legibility checks of test_board_layout.gd
#   (tap targets, text >= 11 pt, key numbers >= 14 pt, nothing cut or spilling) run on a board
#   where every unit and card has art, on the 844x390 iPhone (with and without notch insets) and
#   the 667x375 iPhone SE. With bitmaps off, every view falls back to the procedural SVG art.
# Author: Technical Artist Agent (k-art4)
extends "res://tests/test_case.gd"

const BoardLayout: GDScript = preload("res://tests/test_board_layout.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const PHONE_SE: Dictionary = {"name": "iPhone SE 667x375 @2x", "pt": Vector2(667, 375), "ratio": 2.0}
const HAND_IDS: Array[String] = ["suppressing_fire", "callout", "gunner", "marksman", "combat_medic", "rifleman", "hold_the_line"]
const UNIT_IDS: Array[String] = ["demolitions_expert", "combat_medic", "breacher", "shieldman"]


func _reset() -> void:
	CardArt.bitmaps_enabled = true
	CardArt.missing_paths.clear()
	CardArt.clear_cache()


## The board layout test's worst case (4 units per line, 7-card hand) with art on everything.
func _art_board() -> Dictionary:
	var snap: Dictionary = BoardLayout.new()._full_board()
	for lane: Dictionary in snap["lanes"]:
		for key: String in ["friendly", "enemy"]:
			for i: int in (lane[key] as Array).size():
				lane[key][i]["art"] = UNIT_IDS[i % UNIT_IDS.size()]
	var hand: Array = []
	for i: int in HAND_IDS.size():
		hand.append(CardInfo.chip(i + 1, load("res://data/cards/%s.tres" % HAND_IDS[i])))
	snap["hand"] = hand
	return snap


## Runs test_board_layout's full checks on the art board; returns its failure messages.
func _layout_failures(screen: Dictionary, art: bool) -> Array:
	CardArt.bitmaps_enabled = true
	CardArt.clear_cache()
	var t: RefCounted = BoardLayout.new()
	t.set("tree", tree)
	var snap: Dictionary = _art_board()
	# Plain = the same board with the small-view art switched off (the pre-k-art4 look).
	ArtUnderlay.enabled = art
	await t._check_layout(screen, snap)
	ArtUnderlay.enabled = true
	assertions += int(t.get("assertions"))
	return t.get("failures")


func _layout(screen: Dictionary) -> void:
	for f: Variant in await _layout_failures(screen, true):
		failures.append("[art board] %s" % f)


func test_layout_phone_art_board() -> void:
	_reset()
	await _layout(BoardLayout.PHONE)


func test_layout_phone_notch_art_board() -> void:
	_reset()
	await _layout(BoardLayout.PHONE_NOTCH)


## iPhone SE (667x375, 960x540 canvas at 0.694 pt/px): the board was never sized for it, and the
## plain board already misses some phone rules there (13.9 pt numbers, cut POINT tags and long
## names, 32 pt hand strips; reported to UI/UX). The art must not add a single new failure.
func test_layout_iphone_se_art_adds_no_failures() -> void:
	_reset()
	var plain: Array = await _layout_failures(PHONE_SE, false)
	var with_art: Array = await _layout_failures(PHONE_SE, true)
	var norm := func(msgs: Array) -> Dictionary:
		var d: Dictionary = {}
		for m: Variant in msgs:
			d[String(m)] = true
		return d
	var before: Dictionary = norm.call(plain)
	for m: Variant in with_art:
		assert_true(before.has(String(m)), "art adds a failure at SE: %s" % m)
	assert_true(with_art.size() <= plain.size(), "art board: %d SE issues, plain board: %d" % [with_art.size(), plain.size()])
	print("     [iPhone SE] plain board %d pre-existing issues, art board %d" % [plain.size(), with_art.size()])


func test_board_shows_art() -> void:
	_reset()
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE, _art_board())
	var viewport: SubViewport = setup[0]
	var match_node: Control = setup[1]
	await tree.process_frame
	# Let the arrival slides (lane.gd motion) settle.
	await tree.create_timer(2.0).timeout
	# kc-board: unit slots show their 4:1 banner (BannerArtDB), never mirrored (kc-pitch-art), never recoloured
	# (back rows are only darker: r == g == b).
	var units: int = 0
	for lane: Node in match_node.get_board().get_lanes():
		for slot: Node in lane.get_enemy_slots() + lane.get_friendly_slots():
			if slot.kind != slot.Kind.UNIT:
				continue
			units += 1
			assert_true(slot.has_art(), "slot %s shows art" % slot.get_path())
			var art: TextureRect = slot.banner.get_node("Art")
			assert_not_null(art.texture, "slot banner texture")
			assert_false(art.flip_h, "kc-pitch-art: card art is never mirrored, either side")
			var m: Color = art.modulate * art.self_modulate
			assert_true(is_equal_approx(m.r, m.g) and is_equal_approx(m.g, m.b), "art never recoloured")
			var tex_size: Vector2 = art.texture.get_size()
			assert_true(absf(tex_size.x / tex_size.y - 4.0) < 0.05, "banner crop is 4:1 (%s)" % tex_size)
			assert_true(Rect2(Vector2.ZERO, (slot as Control).size).grow(0.5).encloses(Rect2(slot.banner.position, slot.banner.size)), "banner inside the slot")
	assert_eq(units, 24, "every unit slot checked")
	# kc-ui4: hand cards are the board's banner: the same 4:1 art band (cover-cropped), inside the card.
	var chips: Array[Node] = match_node.get_hand().get_cards()
	assert_eq(chips.size(), HAND_IDS.size(), "full hand")
	for chip: Node in chips:
		var art2: TextureRect = chip.find_child("Art", true, false)
		assert_not_null(art2, "card has an art window")
		if art2 == null:
			continue
		assert_not_null(art2.texture, "card art visible")
		var ts: Vector2 = art2.texture.get_size()
		assert_true(absf(ts.x / ts.y - 4.0) < 0.05, "hand art is the banner's 4:1 band (%s)" % ts)
		assert_true((chip as Control).get_global_rect().grow(0.5).encloses(art2.get_global_rect()), "art window inside the card")
	_reset()
	layout._despawn(viewport)
	await tree.process_frame


func test_no_art_falls_back() -> void:
	_reset()
	BannerArtDB.clear_cache()
	# kc-board: an art id with no banner and no Killstreak art still gets a generated placeholder.
	var slot: Control = (load("res://scenes/match/UnitSlot.tscn") as PackedScene).instantiate()
	tree.root.add_child(slot)
	await tree.process_frame
	slot.show_unit({"name": "Mystery", "cls": "AR", "fp": 1, "armor": 1, "banner": "not_a_card"}, &"player", false)
	assert_true(slot.has_art(), "generated placeholder for an unknown art id")
	assert_true(BannerArtDB.get_art(&"not_a_card").placeholder, "marked as placeholder")
	# Bitmaps off: the procedural SVG card art, cropped (still art, never blank).
	CardArt.bitmaps_enabled = false
	CardArt.clear_cache()
	BannerArtDB.clear_cache()
	# (kc-da-import1, kc-da-import2: a card with no data/banners drop-in, so the Killstreak art path is the one tested.)
	slot.show_unit({"name": "Sentry", "cls": "AR", "fp": 2, "armor": 2, "banner": "sentry"}, &"enemy", true)
	await tree.process_frame
	assert_true(slot.has_art(), "SVG art when the image is missing")
	assert_false(CardArt.has_bitmap(CardArt.card_path(&"sentry")), "procedural texture")
	# INCOMING shows the face-down back, no unit art.
	_reset()
	slot.show_incoming()
	assert_false(slot.has_art(), "incoming has no unit art")
	assert_eq(slot.banner.mode, BannerView.Mode.INCOMING, "incoming back")
	slot.queue_free()
	# Hand card without any art id: no art window texture, the name still shows.
	var hand: Control = (load("res://scenes/match/HandArea.tscn") as PackedScene).instantiate()
	tree.root.add_child(hand)
	await tree.process_frame
	hand.set_hand([{"uid": 1, "name": "Odd", "type": "Thing", "card_type": "nothing", "cost": 1, "text": "Some rules"}])
	await tree.process_frame
	var chip: Node = hand.get_cards()[0]
	var art: TextureRect = chip.find_child("Art", true, false)
	assert_true(art == null or art.texture == null, "no art for a card without an id")
	var names: Array = chip.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text.to_upper() == "ODD")  # kc-cards-impl: the title style is UPPERCASE
	assert_eq(names.size(), 1, "name kept without art")
	hand.queue_free()
	await tree.process_frame
	_reset()
	BannerArtDB.clear_cache()


func test_mulligan_shows_art() -> void:
	_reset()
	var panel: Control = (load("res://scenes/match/MulliganPanel.tscn") as PackedScene).instantiate()
	tree.root.add_child(panel)
	await tree.process_frame
	panel.open([{"uid": 1, "id": &"rifleman", "name": "Rifleman", "cost": 1, "type": "UNIT"},
			{"uid": 2, "name": "No Art", "cost": 0, "type": "TACTIC"}])
	await tree.process_frame
	var buttons: Array[Node] = panel.get_card_buttons()
	# kc-ui3: each mulligan card is the full CardView (its art window included).
	assert_true(panel.has_full_card(buttons[0]), "mulligan card shows the full card")
	var view: Control = buttons[0].get_meta(&"card_view")
	assert_true(view is CardView and String((view as CardView).data.get("name", "")) == "Rifleman", "the card's own face")
	assert_true(buttons[1].get_meta(&"card_view") != null, "no id: still a card face (placeholder art)")
	(buttons[0] as Button).button_pressed = true
	assert_eq((buttons[0] as Button).theme_type_variation, &"KillstreakButton", "put-back look")
	assert_true((buttons[0].get_node("PutBack") as Control).visible, "PUT BACK plate")
	panel.queue_free()
	await tree.process_frame
	_reset()
