# test_layout_a.gd
# Purpose: kc-layout-a (ux-layout-v2.html, direction A; the head picked the recommended option on
#   L1-L5). On the iPhone 844x390, the iPhone in Safari 750x390, the SE 667x375, the portrait
#   390x844 and desktop 1440x900, with 4, 6 and 7 cards in hand:
#   - the hand never scrolls ("n MORE" hints hidden) and no two cards (the Operator included) overlap;
#   - every card, UNDO, READY, the Supply box and the killstreak sockets sit inside the screen, the
#     cards inside the hand grid and the tray;
#   - the Operator card is the hand grid's first card;
#   - the face: full / mid at 4 cards where there is room (a rule line), compact at 6-7 (no rule line);
#   - right click on a hand card and on the Operator card opens the inspector;
#   - the killstreak sockets sit in the icon strip, under the STREAK counter (landscape: stacked).
#   Plus: the objective tile's control plates (L5), the icon fixes (Pick brackets; Pierce, Front line
#   and Agile icons) and no SUPPLY word beside the hex.
# Author: UI/UX Agent (kc-layout-a)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const BoardMetrics: GDScript = preload("res://scripts/ui/board_metrics.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const SCREENS: Array[Dictionary] = [
	{"name": "iPhone 844x390", "pt": Vector2(844, 390), "ratio": 3.0},
	{"name": "iPhone Safari 750x390", "pt": Vector2(750, 390), "ratio": 3.0},
	{"name": "iPhone SE 667x375", "pt": Vector2(667, 375), "ratio": 2.0},
	{"name": "portrait 390x844", "pt": Vector2(390, 844), "ratio": 3.0},
	{"name": "desktop 1440x900", "pt": Vector2(1440, 900), "ratio": 1.0},
]
const HAND_IDS: Array[StringName] = [&"marksman", &"gunner", &"breacher", &"combat_medic", &"flanker", &"rifleman", &"point_man", &"ammo_resupply"]
const EPS: float = 0.75

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
	tree.root.add_child(vp)
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	return [vp, m, c]


func _despawn(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size


func _set_hand(c: Node, n: int) -> void:
	var st: MatchState = c.state
	var hand: Array = st.sides[0].hand
	hand.clear()
	for i: int in n:
		hand.append(RulesCard.new(st.new_uid(), CardDB.get_card(HAND_IDS[i % HAND_IDS.size()])))
	c.refresh()
	await _frames(4)


func _mouse(vp: SubViewport, pos: Vector2, pressed: bool, button: MouseButton) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = (MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT) if pressed else 0
	vp.push_input(e)


func test_hand_never_scrolls_or_overlaps_at_every_size() -> void:
	for screen: Dictionary in SCREENS:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		for n: int in [4, 6, 7]:
			await _set_hand(c, n)
			await _check(vp, m, "%s, %d cards" % [screen["name"], n], n)
		_despawn(vp)
		await _frames(2)


func _check(vp: SubViewport, m: Control, label: String, n: int) -> void:
	var screen_r: Rect2 = Rect2(Vector2.ZERO, Vector2(vp.size)).grow(EPS)
	var tray: Rect2 = m.get_tray().get_global_rect().grow(EPS)
	var hand: Control = m.get_hand()
	var grid: Rect2 = hand.get_grid_rect()
	var g: Rect2 = Rect2(hand.get_global_rect().position + grid.position, grid.size).grow(EPS)
	assert_false(hand.is_scrolling(), "%s: the hand does not scroll" % label)
	assert_false(bool(hand.hand_fit.get("scroll", true)), "%s: hand_fit never scrolls" % label)
	for hint: String in ["MoreUp", "MoreDown"]:
		var l: Label = hand.find_child(hint, false, false) as Label
		assert_true(l == null or not l.visible, "%s: no '%s' hint" % [label, hint])
	var cards: Array[Node] = hand.get_cards()
	assert_eq(cards.size(), n, "%s: %d cards in hand" % [label, n])
	var op: Control = hand.get_operator_card()
	assert_true(op != null and op.visible, "%s: the Operator card shows" % label)
	var items: Array[Control] = [op]
	for card: Node in cards:
		items.append(card as Control)
	for i: int in items.size():
		var r: Rect2 = items[i].get_global_rect()
		assert_true(items[i].visible, "%s: item %d visible" % [label, i])
		assert_true(g.encloses(r), "%s: item %d inside the hand grid (%s in %s)" % [label, i, r, g])
		assert_true(tray.encloses(r), "%s: item %d inside the tray" % [label, i])
		assert_true(screen_r.encloses(r), "%s: item %d on screen" % [label, i])
		for j: int in range(i + 1, items.size()):
			assert_false(r.grow(-EPS).intersects(items[j].get_global_rect().grow(-EPS)), "%s: items %d / %d overlap" % [label, i, j])
	# L3: the Operator is the first card (top row, leftmost).
	var orr: Rect2 = op.get_global_rect()
	for card: Node in cards:
		var cr: Rect2 = (card as Control).get_global_rect()
		assert_true(orr.position.y <= cr.position.y + 7.0, "%s: the Operator in the top row" % label)
		if absf(cr.position.y - orr.position.y) < 8.0:
			assert_true(orr.position.x < cr.position.x, "%s: the Operator left of the top row's cards" % label)
	# L2: the face. 6-7 cards: compact (no rule line); 4 cards: a rule line where there is room.
	var face: StringName = StringName(hand.hand_fit.get("face", &""))
	var first: Control = cards[0] as Control
	var rule: RichTextLabel = BannerCard.rule_of(first)
	if n >= 6:
		assert_eq(face, BoardMetrics.FACE_COMPACT, "%s: compact faces" % label)
		assert_true(rule == null or not rule.is_visible_in_tree(), "%s: no rule line on a compact face" % label)
	elif face != BoardMetrics.FACE_COMPACT:
		assert_true(rule != null and rule.is_visible_in_tree() and IconText.plain(rule) != "", "%s: the %s face shows a rule line" % [label, face])
	# UNDO, READY, the Supply box and the killstreak sockets on screen; the sockets in the strip.
	for ctl: Control in [m.get_ready_button(), m.get_undo_button()]:
		assert_true(tray.encloses(ctl.get_global_rect()) and screen_r.encloses(ctl.get_global_rect()), "%s: %s inside the tray" % [label, ctl.name])
		assert_false(ctl.get_global_rect().grow(-EPS).intersects(g.grow(-2.0 * EPS)), "%s: %s below the hand grid" % [label, ctl.name])
	var ks: Control = m.get_killstreak_row()
	var strip: Rect2 = m.get_node("%IconStrip").get_global_rect().grow(EPS) if m.has_node("%IconStrip") else Rect2()
	if strip.has_area():
		assert_true(strip.encloses(ks.get_global_rect()), "%s: killstreak sockets in the icon strip" % label)
	for tile: Control in ks.get_tiles():
		assert_true(screen_r.encloses(tile.get_global_rect()), "%s: killstreak socket on screen" % label)
	var streak: Control = m.get_badge(&"streak")
	if not bool(m.metrics.get("portrait", false)):
		assert_true(ks.get_global_rect().position.y >= streak.get_global_rect().end.y - EPS, "%s: sockets under STREAK" % label)
		for tile: Control in ks.get_tiles():
			assert_true(tile.size.y >= 44.0, "%s: socket %s tall enough to tap" % [label, tile.size])
	# Inspect: right click on the last card and on the Operator.
	var insp: Control = m.get_inspector()
	for target: Control in [cards[cards.size() - 1] as Control, op]:
		var p: Vector2 = target.get_global_rect().get_center()
		_mouse(vp, p, true, MOUSE_BUTTON_RIGHT)
		await _frames(2)
		_mouse(vp, p, false, MOUSE_BUTTON_RIGHT)
		await _frames(3)
		assert_true(insp.is_open(), "%s: right click on %s opens the inspector" % [label, target.name])
		insp.close()
		await _frames(3)


func test_control_plates_letter_only() -> void:
	var t: Control = load("res://scripts/ui/objective_tile.gd").new()
	t.size = Vector2(228, 52)
	t.letter = "B"
	for ctl: StringName in [&"player", &"enemy", &"contested", &"none"]:
		t.control = ctl
		assert_true(t.mark_size() >= 30.0, "%s: a plate big enough for the letter" % ctl)
	var src: String = (load("res://scripts/ui/objective_tile.gd") as GDScript).source_code
	assert_false(src.contains("draw_colored_polygon(pts, Color(\"#5A1A1C\"))"), "the rival's red diamond is gone (the diamond means Field only)")
	assert_true(src.contains("_hatch("), "the rival's plate is hatched")
	t.free()


func test_icon_table_fixes() -> void:
	# Pick: lock-on brackets (no shield / Armor shape).
	assert_true(IconSheet.PICK_SVG.contains("M2 2h7v2.8"), "Pick is lock-on brackets")
	assert_true(IconSheet.get_icon(&"kw_pick") != null, "Pick has an icon")
	# Pierce, Front line and Agile have icons inline (IconText) and on the keyword line.
	for c: StringName in [&"pierce", &"front_line", &"agile"]:
		assert_true(IconText.texture(c) != null, "%s has an icon" % c)
	assert_eq(IconText.first_concept("Agile: once a round"), &"agile", "Agile is an IconText concept")
	var e: Dictionary = {"fp": 1, "armor": 1, "keywords": [{"id": &"agile"}]}
	assert_true(BannerView.ability_kinds(e).has(&"agile"), "Agile shows as an ability icon on the card")


func test_no_supply_word_beside_the_hex() -> void:
	var s: Array = await _spawn(SCREENS[0])
	var m: Control = s[1]
	var box: Control = m.get_node("%SupplyCounter")
	for l: Node in box.find_children("*", "Label", true, false):
		assert_false((l as Label).visible and (l as Label).text.to_upper().contains("SUPPLY"), "no SUPPLY word in the Supply box")
	assert_true(box.find_child("SupplyIcon", true, false) != null, "the Supply hex is there")
	_despawn(s[0])
	await _frames(2)


func test_metrics_tray_first() -> void:
	# The tray gets its 346 px on every phone; the board shrinks instead (844: unchanged 57 px banners).
	for a: Vector2 in [Vector2(1156, 540), Vector2(1038, 540), Vector2(960, 540)]:
		var mm: Dictionary = BoardMetrics.compute(a, true)
		assert_true((mm["tray"] as Rect2).size.x >= 346.0 - EPS, "%s: the tray keeps 346 px (%s)" % [a, mm["tray"]])
		assert_eq(int(mm["hand_cols"]), 2, "%s: a 2-column hand" % a)
		assert_true((mm["board"] as Rect2).end.x <= (mm["tray"] as Rect2).position.x, "%s: the board left of the tray" % a)
	assert_eq(float(BoardMetrics.compute(Vector2(1156, 540), true)["bh"]), 57.0, "844: the board keeps its 57 px banners")
	for n: int in range(1, 9):
		var f: Dictionary = BoardMetrics.hand_fit(Vector2(346, 404), n + 1, 8.0, BoardMetrics.X1_MIN_H, n)
		assert_false(bool(f["scroll"]), "SE grid, %d cards: no scroll" % n)
		var rows: int = ceili(float(maxi(n + 1, BoardMetrics.HAND_FIT_MIN_N)) / int(f["cols"]))
		assert_true(rows * (f["card"] as Vector2).y + (rows - 1) * 8.0 <= 404.0 - 6.0 + EPS, "SE grid, %d cards: the rows fit" % n)
