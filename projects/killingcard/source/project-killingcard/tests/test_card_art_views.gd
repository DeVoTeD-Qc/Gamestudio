# test_card_art_views.gd
# Purpose: k-art4 painted art on the small card views. Hand chips show the card's art band under
#   the name (stats / keywords on plates, tactic chips trade their cut-off rules line for the art),
#   board unit slots show the unit's art cropped to the slot (enemy mirrored, side in the frame
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
	# Unit slots: art replaces the silhouette, enemy art mirrored, frame variation keeps the side.
	var units: int = 0
	for lane: Node in match_node.get_board().get_lanes():
		for slot: Node in lane.get_enemy_slots() + lane.get_friendly_slots():
			if slot.kind != slot.Kind.UNIT:
				continue
			units += 1
			assert_true(slot.has_art(), "slot %s shows art" % slot.get_path())
			assert_false((slot.get_node("%Figure") as Control).visible, "art replaces the silhouette")
			var under: ArtUnderlay = slot.get_node("ArtUnderlay")
			assert_not_null(under.get_art_texture(), "slot art texture")
			assert_eq(under.flip, slot.side == &"enemy", "enemy art mirrored, own art not")
			var m: Color = under.modulate * under.self_modulate
			assert_true(is_equal_approx(m.r, 1.0) and is_equal_approx(m.g, 1.0) and is_equal_approx(m.b, 1.0), "art never recoloured")
			var variation: StringName = slot.theme_type_variation
			assert_true(variation in [&"SlotFriendly", &"SlotEnemy", &"SlotOperator", &"SlotPending", &"SlotTarget"], "side frame kept (%s)" % variation)
			if slot.side == &"enemy":
				assert_eq(variation, &"SlotEnemy", "enemy frame")
			# Art sits inside the frame, behind the text.
			assert_eq(under.get_index(), 0, "art drawn first")
			assert_true(Rect2(Vector2.ZERO, (slot as Control).size).grow(0.5).encloses(Rect2(under.position, under.size)), "art inside the slot")
	assert_eq(units, 24, "every unit slot checked")
	# Hand chips: art band under the name; units keep stats on plates; tactics show art instead of
	# their rules line.
	var chips: Array[Node] = match_node.get_hand().get_cards()
	assert_eq(chips.size(), HAND_IDS.size(), "full hand")
	for chip: Node in chips:
		var under: ArtUnderlay = chip.find_child("ArtUnderlay", true, false)
		assert_not_null(under, "chip has art")
		if under == null:
			continue
		assert_true(under.visible and under.has_art(), "chip art visible")
		var c: Control = chip
		assert_true(under.size.y > 8.0, "art band has height (%s)" % under.size)
		var band_global: Rect2 = under.get_global_rect()
		assert_true(c.get_global_rect().grow(0.5).encloses(band_global), "art band inside the chip")
		var has_stats: bool = chip.find_child("FpPlate", true, false) != null
		if not has_stats:
			assert_not_null(chip.find_child("ArtBand", true, false), "tactic chip shows art in the rules line's place")
	_reset()
	layout._despawn(viewport)
	await tree.process_frame


func test_no_art_falls_back() -> void:
	_reset()
	# Slot: unknown art key -> silhouette as before.
	var slot: Control = (load("res://scenes/match/UnitSlot.tscn") as PackedScene).instantiate()
	tree.root.add_child(slot)
	await tree.process_frame
	slot.show_unit({"name": "Mystery", "cls": "AR", "fp": 1, "armor": 1, "art": "not_a_card"}, &"player", false)
	assert_false(slot.has_art(), "no art for unknown key")
	assert_true((slot.get_node("%Figure") as Control).visible, "silhouette fallback")
	# Bitmaps off: the procedural SVG card art (still art, never blank).
	CardArt.bitmaps_enabled = false
	CardArt.clear_cache()
	slot.show_unit({"name": "Rifleman", "cls": "AR", "fp": 2, "armor": 2, "art": "rifleman"}, &"enemy", true)
	await tree.process_frame
	assert_true(slot.has_art(), "SVG art when the image is missing")
	var tex: Texture2D = (slot.get_node("ArtUnderlay") as ArtUnderlay).get_art_texture()
	assert_true(tex != null and not CardArt.has_bitmap(CardArt.card_path(&"rifleman")), "procedural texture")
	# INCOMING keeps the card back, no unit art.
	_reset()
	slot.show_incoming()
	assert_false(slot.has_art(), "incoming has no unit art")
	slot.queue_free()
	# Hand chip without a known card (no id, unknown type): rules line as before.
	var hand: Control = (load("res://scenes/match/HandArea.tscn") as PackedScene).instantiate()
	tree.root.add_child(hand)
	await tree.process_frame
	hand.set_hand([{"uid": 1, "name": "Odd", "type": "Thing", "card_type": "nothing", "cost": 1, "text": "Some rules"}])
	await tree.process_frame
	var chip: Node = hand.get_cards()[0]
	var under: Node = chip.find_child("ArtUnderlay", true, false)
	assert_true(under == null or not (under as Control).visible, "no art for an unknown card")
	var texts: Array = chip.find_children("*", "Label", true, false).filter(func(l: Label) -> bool: return l.text == "Some rules")
	assert_eq(texts.size(), 1, "rules line kept without art")
	hand.queue_free()
	await tree.process_frame
	_reset()


func test_mulligan_shows_art() -> void:
	_reset()
	var panel: Control = (load("res://scenes/match/MulliganPanel.tscn") as PackedScene).instantiate()
	tree.root.add_child(panel)
	await tree.process_frame
	panel.open([{"uid": 1, "id": &"rifleman", "name": "Rifleman", "cost": 1, "type": "UNIT"},
			{"uid": 2, "name": "No Art", "cost": 0, "type": "TACTIC"}])
	await tree.process_frame
	var buttons: Array[Node] = panel.get_card_buttons()
	var art: Node = buttons[0].find_child("ArtUnderlay", true, false)
	assert_not_null(art, "mulligan card shows art")
	if art != null:
		assert_true((art as CanvasItem).show_behind_parent, "art behind the button text")
	assert_true(buttons[1].find_child("ArtUnderlay", true, false) == null, "no id: plain button")
	# Toggle keeps the see-through style of the new variation (PUT BACK look).
	(buttons[0] as Button).button_pressed = true
	var sb: StyleBox = (buttons[0] as Button).get_theme_stylebox(&"normal")
	assert_true(sb is StyleBoxFlat and (sb as StyleBoxFlat).bg_color.a <= panel.ART_FILL_ALPHA + 0.001, "see-through over art")
	assert_eq((buttons[0] as Button).theme_type_variation, &"KillstreakButton", "put-back look kept")
	panel.queue_free()
	await tree.process_frame
	_reset()
