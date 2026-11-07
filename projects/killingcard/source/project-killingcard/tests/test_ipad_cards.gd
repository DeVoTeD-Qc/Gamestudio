# test_ipad_cards.gd
# Purpose: kc-ipad-cards (the head's iPad landscape playtest: the hand was one narrow column of five
#   small banners with empty space under it, READY read "READ"; "leave out the gun type", "only 1
#   trait", "remove all the training thing", "ability icons and trait big too along with the stats",
#   "text on card should just be keyword icons and name"). Checks:
#   - iPad 1024x768 and iPad Pro 1366x1024 (and desktop 1440x900): with 5..8 hand cards the X1 cards
#     cover >= 80% of the hand grid, nothing spills or overlaps, READY / UNDO / the Operator card sit
#     inside the tray, READY's whole word fits;
#   - BannerCard.layout_for: ROW on a tall banner (abilities bottom-centre), SPLIT on the phone,
#     every badge the same size, no two badges overlap, the cost hex top-left;
#   - the SE (667x375) hand scrolls one readable column (13 pt digits; head RQ1);
#   - the Y2+ card: type line UNIT (no weapon), keyword lines with icon + name only, the stats bar's
#     ability icons and trait as big as FP.
# Author: UI/UX Agent (kc-ipad-cards)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const BoardMetrics: GDScript = preload("res://scripts/ui/board_metrics.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const IPAD: Dictionary = {"name": "iPad 1024x768 @2x", "pt": Vector2(1024, 768), "ratio": 2.0}
const IPAD_PRO: Dictionary = {"name": "iPad Pro 1366x1024 @2x", "pt": Vector2(1366, 1024), "ratio": 2.0}
const DESKTOP_900: Dictionary = {"name": "desktop 1440x900", "pt": Vector2(1440, 900), "ratio": 1.0}
const PHONE_SE: Dictionary = {"name": "iPhone SE 667x375 @2x", "pt": Vector2(667, 375), "ratio": 2.0}
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


## Sets the player's hand to `n` cards and refreshes the screen.
func _set_hand(c: Node, n: int) -> void:
	var st: MatchState = c.state
	var hand: Array = st.sides[0].hand
	hand.clear()
	for i: int in n:
		hand.append(RulesCard.new(st.new_uid(), CardDB.get_card(HAND_IDS[i % HAND_IDS.size()])))
	c.refresh()
	await _frames(4)


func _check_tray(m: Control, label: String) -> void:
	var tray: Rect2 = m.get_tray().get_global_rect().grow(EPS)
	var hand: Control = m.get_hand()
	var grid: Rect2 = hand.get_grid_rect()
	var g: Rect2 = Rect2(hand.get_global_rect().position + grid.position, grid.size)
	var cards: Array[Node] = hand.get_cards()
	var area: float = 0.0
	for i: int in cards.size():
		var r: Rect2 = (cards[i] as Control).get_global_rect()
		if not (cards[i] as Control).visible:
			continue
		area += r.get_area()
		assert_true(g.grow(EPS).encloses(r), "%s: card %d inside the hand grid (%s in %s)" % [label, i, r, g])
		for j: int in range(i + 1, cards.size()):
			if (cards[j] as Control).visible:
				assert_false(r.grow(-EPS).intersects((cards[j] as Control).get_global_rect().grow(-EPS)), "%s: cards %d / %d overlap" % [label, i, j])
	var cover: float = area / maxf(1.0, g.get_area())
	assert_true(cover >= 0.8, "%s: %d cards cover %.0f%% of the hand grid (>= 80%%)" % [label, cards.size(), cover * 100.0])
	var ready: Button = m.get_ready_button()
	var undo: Button = m.get_undo_button()
	var op: Control = hand.get_operator_card()
	for ctl: Control in [ready, undo, op]:
		assert_true(tray.encloses(ctl.get_global_rect()), "%s: %s inside the tray" % [label, ctl.name])
	assert_false(op.get_global_rect().grow(-EPS).intersects(g), "%s: the Operator row under the grid" % label)
	var font: Font = ready.get_theme_font(&"font")
	var fs: int = ready.get_theme_font_size(&"font_size")
	var sb: StyleBox = ready.get_theme_stylebox(&"normal")
	var room: float = ready.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT)
	var need: float = font.get_string_size(ready.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	assert_true(need <= room + 0.5, "%s: '%s' fits its button (%.0f <= %.0f px)" % [label, ready.text, need, room])
	assert_true(op.size.x >= m.get_tray().size.x * 0.6, "%s: the Operator card spans the tray (%s)" % [label, op.size])
	print("     [%s] %d cards: %s x %d cols, cover %.0f%%, READY %s" % [label, cards.size(), hand.hand_fit.get("card"),
			int(hand.hand_fit.get("cols", 0)), cover * 100.0, ready.size])


func test_large_landscape_hand_fills_the_tray() -> void:
	for screen: Dictionary in [IPAD, IPAD_PRO, DESKTOP_900]:
		var s: Array = await _spawn(screen)
		var m: Control = s[1]
		assert_false(m.compact, "%s: the desktop layout" % screen["name"])
		for n: int in [5, 6, 7, 8]:
			await _set_hand(s[2], n)
			_check_tray(m, "%s, %d cards" % [screen["name"], n])
		_despawn(s[0])
		await tree.process_frame


func test_phone_landscape_keeps_two_columns() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var m: Control = s[1]
	for n: int in [5, 7]:
		await _set_hand(s[2], n)
		var fit: Dictionary = m.get_hand().hand_fit
		assert_eq(int(fit["cols"]), 2, "844x390, %d cards: 2 columns" % n)
		assert_false(bool(fit["scroll"]), "844x390: every card shows")
		assert_true(float(fit["s"]) * 0.7 * Layout.points_per_px(Layout.PHONE) >= 13.0, "844x390: badges reach 13 pt digits (%s)" % fit["s"])
	_despawn(s[0])
	await tree.process_frame


func test_se_hand_scrolls_a_readable_column() -> void:
	var s: Array = await _spawn(PHONE_SE)
	var m: Control = s[1]
	var hand: Control = m.get_hand()
	await _set_hand(s[2], 7)
	var fit: Dictionary = hand.hand_fit
	assert_true(bool(fit["scroll"]), "SE: 7 cards scroll")
	assert_eq(int(fit["cols"]), 1, "SE: one column")
	var k: float = Layout.points_per_px(PHONE_SE)
	assert_true(roundf(float(fit["s"]) * 0.7) * k >= 13.0, "SE: digits >= 13 pt (%.1f)" % (roundf(float(fit["s"]) * 0.7) * k))
	var shown: Array = hand.get_cards().filter(func(c: Node) -> bool: return (c as Control).visible)
	assert_eq(shown.size(), int(fit["visible"]), "SE: %d cards shown" % shown.size())
	var down: Label = hand.find_child("MoreDown", false, false)
	assert_true(down.visible and down.text.contains("MORE"), "SE: '▼ n MORE' hint")
	var first_uid: int = int(shown[0].get_meta(&"uid"))
	hand.scroll_hand(1)
	assert_false(hand.get_card(first_uid).visible, "SE: scrolling hides the first card")
	assert_true((hand.find_child("MoreUp", false, false) as Label).visible, "SE: '▲ n MORE' once scrolled")
	# Selecting a hidden card scrolls it into view.
	hand.set_selected(first_uid)
	assert_true(hand.get_card(first_uid).visible, "SE: the selected card scrolls into view")
	hand.set_selected(-1)
	_despawn(s[0])
	await tree.process_frame


func test_x1_layouts_keep_badges_one_size() -> void:
	var e: Dictionary = BannerCard.entry_for_card(CardDB.get_card(&"marksman"), &"marksman~mastery")
	for face: Vector2 in [Vector2(220, 109), Vector2(173, 94), Vector2(173, 68), Vector2(220, 60), Vector2(288, 89)]:
		var lay: Dictionary = BannerCard.layout_for(face, e)
		var s: float = float(lay["s"])
		var fp: Rect2 = lay["fp"]
		var rects: Array[Rect2] = [lay["cost"], lay["trait"], fp, lay["armor"]]
		for ab: Array in lay["abilities"]:
			assert_true(absf((ab[1] as Rect2).size.x - s) < 0.5, "%s: ability icon = the badge size %s" % [face, s])
			rects.append(ab[1])
		assert_true(absf((lay["trait"] as Rect2).size.x - s) < 0.5, "%s: trait chip = the badge size" % face)
		assert_true(absf(fp.size.x - s) < 0.5, "%s: FP = the badge size" % face)
		for i: int in rects.size():
			assert_true(Rect2(Vector2.ZERO, face).grow(0.5).encloses(rects[i]), "%s: badge %d on the card" % [face, i])
			for j: int in range(i + 1, rects.size()):
				assert_false(rects[i].intersects(rects[j]), "%s: badges %d / %d overlap" % [face, i, j])
		assert_true((lay["cost"] as Rect2).position.x < face.x * 0.3 and (lay["cost"] as Rect2).position.y < 6.0, "%s: cost top-left" % face)
		var name_r: Rect2 = lay["name"]
		assert_true(name_r.position.y >= (lay["banner"] as Rect2).end.y - 0.5, "%s: the name in the plate under the banner" % face)
		if lay["mode"] == &"row":
			for ab: Array in lay["abilities"]:
				assert_true((ab[1] as Rect2).position.x >= (lay["trait"] as Rect2).end.x and (ab[1] as Rect2).end.x <= fp.position.x,
						"%s: ROW abilities bottom-centre" % face)
	assert_eq(BannerCard.layout_for(Vector2(220, 109), e)["mode"], &"row", "iPad 5-card size: ROW")
	assert_eq(BannerCard.layout_for(Vector2(173, 68), e)["mode"], &"split", "phone 8-card size: SPLIT")


func test_y2_card_type_line_and_icon_names_only() -> void:
	var cv: CardView = (load("res://scenes/match/CardView.tscn") as PackedScene).instantiate()
	tree.root.add_child(cv)
	cv.set_card_data(CardView.view_for_card(CardDB.get_card(&"marksman")))
	cv.set_card_width(196)
	await _frames(1)
	var tl: String = (cv.get_node("%TypeLabel") as Label).text
	assert_eq(tl, "UNIT", "the type line says UNIT, no weapon")
	assert_false(cv.get_text_lines().is_empty(), "the Marksman lists its keywords")
	for l: Dictionary in cv.get_text_lines():
		assert_eq(String(l["rule"]), "", "%s: icon + name only, no definition" % l["name"])
	var rg: Dictionary = cv.regions()
	assert_false((rg["abilities"] as Array).is_empty(), "the stats bar shows the ability icons")
	for ab: Array in rg["abilities"]:
		var r: Rect2 = ab[1]
		assert_true(r.size.x >= (rg["fp"] as Rect2).size.x - 0.5, "ability icon as big as FP")
		assert_true(r.position.x >= (rg["traits"] as Rect2).end.x and r.end.x <= (rg["fp"] as Rect2).position.x, "abilities bottom-centre")
	assert_true((rg["traits"] as Rect2).size.x >= (rg["fp"] as Rect2).size.x - 0.5, "trait chip as big as FP")
	# A Tactic keeps its rules text.
	cv.set_card_data(CardView.view_for_card(CardDB.get_card(&"ammo_resupply")))
	await _frames(1)
	assert_true((cv.get_node("%BodyLabel") as Label).text != "", "a Tactic keeps its effect text")
	assert_true((cv.get_node("%TypeLabel") as Label).text.contains("TACTIC"), "TACTIC type line")
	cv.queue_free()
