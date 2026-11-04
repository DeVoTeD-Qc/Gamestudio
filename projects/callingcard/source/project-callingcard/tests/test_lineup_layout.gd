# test_lineup_layout.gd
# Purpose: Layout, readability and touch checks for the lineup builder (cc10) on real screens:
#   desktop 1280x720, iPhone 844x390 @3x (with and without notch insets) and iPhone SE 667x375 @2x.
#   Same approach as tests/test_duel_layout.gd (cc07): ScreenProfile gives the logical canvas, the
#   builder is laid out in a SubViewport of that size, and sizes are checked in EFFECTIVE points:
#   - the whole layout fits; key controls are visible, inside the safe area and do not overlap,
#   - every tap target (Buttons + group "tap_target") >= 64 logical px and >= 44 pt,
#   - text >= 11 pt; key numbers (the Clearance read-out, card values) >= 24 px and >= 16 pt,
#   - status text (headline, every reason, notice, loaner offer) shows in full, even in the
#     worst case (five reasons + a notice + the loaner offer), with a collection row still visible,
#   - lineup cards 4:1 and >= 64 px tall; the collection grid has >= 2 columns and >= 1 full row,
#   - nothing is hover-only (no tooltips); the inspector opens inside the safe area.
# Author: UI/UX Agent (cc10)
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_lineup_fixtures.gd")
const MIN_TAP_PT: float = 44.0
const MIN_TAP_PX: float = 64.0
const MIN_BODY_PT: float = 11.0
const MIN_NUMBER_PX: float = 24.0
const MIN_NUMBER_PT: float = 16.0
const EPS: float = 0.5


func test_scene_loads() -> void:
	var scene: PackedScene = load(Fx.BUILDER_SCENE) as PackedScene
	assert_not_null(scene, "LineupBuilder.tscn loads")
	if scene == null:
		return
	var node: Node = scene.instantiate()
	for unique: String in ["%SafeArea", "%BackButton", "%ClearanceMeter", "%ClearanceValue", "%MessagePanel",
			"%Headline", "%Reasons", "%Notice", "%LoanerRow", "%LoanerButton", "%CollectionScroll",
			"%CollectionGrid", "%LineupTitle", "%LegendLabel", "%ClearButton", "%LineupRows", "%SaveButton",
			"%DuelButton", "%CardInspector"]:
		assert_not_null(node.get_node_or_null(unique), "LineupBuilder lacks %s" % unique)
	node.free()
	assert_not_null(load("res://scenes/lineup/LineupRow.tscn"), "LineupRow.tscn loads")


func test_screen_sizes() -> void:
	assert_eq(Fx.logical_size(Fx.DESKTOP), Vector2(1280, 720), "desktop logical")
	assert_eq(Fx.logical_size(Fx.PHONE), Vector2(1168, 540), "phone logical")
	assert_eq(Fx.logical_size(Fx.PHONE_SE), Vector2(960, 540), "iPhone SE logical")


func test_layout_desktop() -> void:
	await _check_all_states(Fx.DESKTOP)


func test_layout_phone() -> void:
	await _check_all_states(Fx.PHONE)


func test_layout_phone_with_notch_insets() -> void:
	await _check_all_states(Fx.PHONE_NOTCH)


func test_layout_iphone_se() -> void:
	await _check_all_states(Fx.PHONE_SE)


func test_nothing_is_hover_only() -> void:
	var f: RefCounted = Fx.new(tree)
	var b: Control = await f.spawn(Fx.PHONE, "lineup_hover", null, {"cards": Fx.VALID_IDS, "signature": &"snow_blind"})
	var tips: Array[String] = []
	for n: Node in b.find_children("*", "Control", true, false):
		if (n as Control).tooltip_text != "":
			tips.append(String(b.get_path_to(n)))
	assert_true(tips.is_empty(), "no tooltips (hover-only info): %s" % [tips])
	assert_eq(b.theme.get_stylebox(&"hover", &"HandCard"), b.theme.get_stylebox(&"normal", &"HandCard"), "card hover == normal")
	f.finish()


func test_inspector_inside_safe_area() -> void:
	for s: Dictionary in Fx.SCREENS:
		var f: RefCounted = Fx.new(tree)
		var b: Control = await f.spawn(s, "lineup_insp")
		for id: StringName in [&"snow_blind", &"chrome_tiger", &"open_channel"]:
			b.inspect_card(CardDB.get_card(id))
			await f.frames()
			var inspector: Control = b.get_inspector()
			assert_true(inspector.is_open(), "%s inspector opens for %s" % [s["name"], id])
			var panel: Rect2 = inspector.get_panel().get_global_rect()
			assert_true(f.safe_rect().encloses(panel), "%s inspector %s inside safe area %s" % [s["name"], panel, f.safe_rect()])
			var close: Control = inspector.get_node("%CloseButton")
			assert_true(minf(close.size.x, close.size.y) >= MIN_TAP_PX - EPS, "%s CLOSE %s" % [s["name"], close.size])
			inspector.close()
		f.finish()


# --- Helpers -------------------------------------------------------------------

func _check_all_states(s: Dictionary) -> void:
	# 1. Empty lineup, starting collection.
	var f: RefCounted = Fx.new(tree)
	await f.spawn(s, "lineup_layout_empty")
	_check(f, "empty")
	f.finish()
	# 2. Saved legal lineup.
	f = Fx.new(tree)
	await f.spawn(s, "lineup_layout_valid", null, {"cards": Fx.VALID_IDS, "signature": &"snow_blind"})
	_check(f, "valid")
	f.finish()
	# 3. Worst reachable by taps, big collection: Legends + over the cap + no Signature + a notice.
	f = Fx.new(tree)
	var all_ids: Array = CardDB.all_cards().map(func(c: CardData) -> StringName: return c.id)
	var b: Control = await f.spawn(s, "lineup_layout_worst_a", all_ids)
	for id: StringName in [&"long_watch", &"city_never_sleeps", &"dead_air", &"honor_roll", &"polar_night"]:
		b.tap_collection_card(id)
	b.tap_signature(0)
	b.tap_collection_card(&"glacier")  # 6th card: the "lineup is full" notice
	await f.frames(3)
	assert_eq((b.get_result()["reasons"] as PackedStringArray).size(), 3, "%s worst A has 3 reasons" % s["name"])
	_check(f, "worst reachable: Legends, cap, Signature")
	f.finish()
	# 4. Worst reachable by taps, tiny collection: loaner offered, loaner edited (unowned cards,
	#    one short, no Signature) and a notice.
	f = Fx.new(tree)
	b = await f.spawn(s, "lineup_layout_worst_b", [&"graveyard_shift", &"chrome_tiger", &"frostbite"])
	b.tap_loaner()
	b.tap_lineup_slot(0)
	b.tap_signature(b.get_lineup_ids().find(b.get_signature_id()))
	await f.frames(3)
	assert_eq((b.get_result()["reasons"] as PackedStringArray).size(), 3, "%s worst B has 3 reasons: %s" % [s["name"], b.get_result()["reasons"]])
	assert_true((b.get_node("%LoanerRow") as Control).is_visible_in_tree(), "%s worst B offers the loaner" % s["name"])
	_check(f, "worst reachable: loaner edited")
	f.finish()
	# 5. Beyond reach by taps (a restored or hand-made lineup): five reasons, a notice and the
	#    loaner offer. The status text may scroll here on the smallest phone, but the headline,
	#    the first reason and a full collection row stay in view.
	f = Fx.new(tree)
	b = await f.spawn(s, "lineup_layout_extreme", [&"graveyard_shift", &"chrome_tiger", &"frostbite"])
	b.set_lineup([&"long_watch", &"city_never_sleeps", &"dead_air", &"honor_roll", &"dead_air"], &"")
	b.tap_collection_card(&"polar_night")  # locked: adds the "how to earn it" notice
	await f.frames(3)
	assert_eq((b.get_result()["reasons"] as PackedStringArray).size(), 5, "%s extreme case has 5 reasons" % s["name"])
	assert_true(b.get_notice_text() != "", "%s extreme case has a notice" % s["name"])
	_check(f, "extreme", true)
	f.finish()


func _check(f: RefCounted, state: String, may_scroll: bool = false) -> void:
	var b: Control = f.builder
	var viewport: SubViewport = f.viewport
	var s: Dictionary = f.screen
	var label: String = "%s [%s]" % [s["name"], state]
	var k: float = Fx.points_per_px(s)
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(EPS)
	var safe: Rect2 = f.safe_rect()

	assert_eq(b.size, Vector2(viewport.size), "%s builder fills the viewport" % label)
	var needed: Vector2 = (b.get_node("%SafeArea") as Control).get_combined_minimum_size()
	assert_true(needed.x <= viewport.size.x + EPS and needed.y <= viewport.size.y + EPS,
			"%s layout needs %s but screen is %s" % [label, needed, viewport.size])

	var keys: Dictionary = b.get_key_controls()
	var names: Array = keys.keys()
	for key: String in names:
		var c: Control = keys[key]
		var r: Rect2 = c.get_global_rect()
		assert_true(c.is_visible_in_tree() and r.size.x > 1.0 and r.size.y > 1.0, "%s %s not visible (%s)" % [label, key, r])
		assert_true(safe.encloses(r), "%s %s outside the safe area: %s not in %s" % [label, key, r, safe])
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var a: Rect2 = (keys[names[i]] as Control).get_global_rect().grow(-EPS)
			var c2: Rect2 = (keys[names[j]] as Control).get_global_rect().grow(-EPS)
			assert_false(a.intersects(c2), "%s %s overlaps %s (%s / %s)" % [label, names[i], names[j], a, c2])

	# Tap targets: group "tap_target" plus every visible Button (inspector is closed).
	var scroll: ScrollContainer = b.get_node("%CollectionScroll")
	var scroll_rect: Rect2 = scroll.get_global_rect()
	var targets: Array[Control] = []
	for n: Node in tree.get_nodes_in_group(&"tap_target"):
		if b.is_ancestor_of(n) and n is Control:
			targets.append(n)
	for n: Node in b.find_children("*", "Button", true, false):
		if not targets.has(n):
			targets.append(n)
	assert_true(targets.size() >= 20 + 5 * 2 + 4, "%s expected >= 34 tap targets, got %d" % [label, targets.size()])
	var min_tap: float = INF
	for c: Control in targets:
		if not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		var side_px: float = minf(r.size.x, r.size.y)
		min_tap = minf(min_tap, side_px)
		assert_true(side_px >= MIN_TAP_PX - EPS, "%s tap target %s is %s (< 64 px)" % [label, b.get_path_to(c), r.size])
		assert_true(side_px * k >= MIN_TAP_PT - 0.01, "%s tap target %s = %.1f pt (< 44 pt)" % [label, b.get_path_to(c), side_px * k])
		if scroll.is_ancestor_of(c):
			continue  # collection cards scroll; the grid checks below cover them
		assert_true(screen_rect.encloses(r), "%s tap target %s off screen" % [label, b.get_path_to(c)])

	# Collection grid: >= 2 columns, at least one full row visible, cards inside the grid width.
	var grid: GridContainer = b.get_node("%CollectionGrid")
	assert_true(grid.columns >= 2, "%s grid has %d columns" % [label, grid.columns])
	var first: Control = b.get_collection_buttons()[0]
	assert_true(scroll_rect.size.y >= first.size.y - EPS, "%s grid shows a full row (%s tall, card %s)" % [label, scroll_rect.size.y, first.size])
	assert_true(scroll_rect.grow(EPS).encloses(first.get_global_rect()), "%s first card inside the scroll view" % label)
	assert_true(grid.get_combined_minimum_size().x <= scroll_rect.size.x + EPS, "%s grid fits the width (%s in %s)" % [label, grid.get_combined_minimum_size().x, scroll_rect.size.x])
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "%s no sideways scroll" % label)

	# Text and key numbers in effective points.
	var min_body: float = INF
	var min_number: float = INF
	for n: Node in b.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree() or not (c is Label or c is Button):
			continue
		if String(c.text).strip_edges().is_empty():
			continue
		var px: int = c.get_theme_font_size(&"font_size")
		min_body = minf(min_body, px * k)
		assert_true(px * k >= MIN_BODY_PT - 0.01, "%s text '%s' (%s) is %.1f pt" % [label, c.text, b.get_path_to(c), px * k])
		if c.is_in_group(&"key_number"):
			min_number = minf(min_number, px * k)
			assert_true(px >= MIN_NUMBER_PX and px * k >= MIN_NUMBER_PT - 0.01, "%s number '%s' is %d px = %.1f pt" % [label, c.text, px, px * k])
	for l: Label in b.get_important_labels():
		if not l.is_visible_in_tree() or l.text.strip_edges().is_empty():
			continue
		var why: String = _clipped(l)
		assert_true(why.is_empty(), "%s '%s' (%s) is cut: %s" % [label, l.text, b.get_path_to(l), why])
	if not may_scroll:
		assert_false(b.status_scrolls(), "%s status text shows in full without scrolling" % label)
	else:
		var status_view: Rect2 = (b.get_node("%MessageScroll") as Control).get_global_rect()
		var headline: Rect2 = (b.get_node("%Headline") as Control).get_global_rect()
		assert_true(status_view.grow(EPS).encloses(headline), "%s headline in view while the status scrolls" % label)
		assert_true(status_view.size.y >= headline.size.y * 2.0, "%s headline and a reason line in view (%s)" % [label, status_view.size])
		if b.status_scrolls():
			print("     [%s] status text scrolls (%.0f px shown)" % [label, status_view.size.y])
	var panel: Rect2 = (b.get_node("%MessagePanel") as Control).get_global_rect()
	assert_true(safe.encloses(panel), "%s status panel fully on screen %s" % [label, panel])

	# Lineup rows: 4:1 cards >= 64 px, stacked, values readable.
	var prev_bottom: float = -INF
	for i: int in 5:
		var row: Node = b.get_row(i)
		var cb: Control = row.get_card_button()
		var r: Rect2 = cb.get_global_rect()
		assert_true(r.size.y >= MIN_TAP_PX - EPS and absf(r.size.x / r.size.y - 4.0) < 0.05, "%s row %d card %s" % [label, i + 1, r.size])
		assert_true(r.position.y >= prev_bottom - EPS, "%s rows stack" % label)
		prev_bottom = r.end.y
		var sig: Control = row.get_signature_toggle()
		assert_true(absf(sig.get_global_rect().size.y - r.size.y) < 1.0, "%s row %d toggle as tall as the card" % [label, i + 1])
		if row.card != null:
			var lay: Dictionary = row.get_card_view().layout_report()
			assert_true(int(lay["numeral_px"]) >= MIN_NUMBER_PX and lay["numeral_px"] * k >= MIN_NUMBER_PT - 0.01,
					"%s row %d values %d px" % [label, i + 1, lay["numeral_px"]])
			min_number = minf(min_number, lay["numeral_px"] * k)
	for gb: Node in b.get_collection_buttons():
		var cv: BannerCard = gb.get_node("Card")
		assert_eq(cv.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s grid card leaves input to its button" % label)
		var lay2: Dictionary = cv.layout_report()
		assert_true(int(lay2["numeral_px"]) >= MIN_NUMBER_PX, "%s grid card values %d px" % [label, lay2["numeral_px"]])
	print("     [%s] canvas %s, %.3f pt/px, %d grid cols of %s, smallest text %.1f pt, number %.1f pt, tap %.1f pt, grid view %.0f px tall" % [
			label, viewport.size, k, grid.columns, b.grid_card_size, min_body, min_number, min_tap * k, scroll_rect.size.y])


## Why a label's text does not fully show ("" when it does). Same rule as test_duel_layout.gd.
func _clipped(l: Label) -> String:
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
		if l.get_visible_line_count() < l.get_line_count():
			return "%d of %d lines visible" % [l.get_visible_line_count(), l.get_line_count()]
		return ""
	var font: Font = l.get_theme_font(&"font")
	var fsize: int = l.get_theme_font_size(&"font_size")
	var text: String = l.text.to_upper() if l.uppercase else l.text
	var need: float = 0.0
	for line: String in text.split("\n"):
		need = maxf(need, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x)
	var box: StyleBox = l.get_theme_stylebox(&"normal")
	var room: float = l.size.x - (box.get_minimum_size().x if box != null else 0.0)
	if need > room + 0.5:
		return "needs %.0f px, has %.0f px" % [need, room]
	if l.size.y + 0.5 < font.get_height(fsize):
		return "needs %.0f px tall, has %.0f px" % [font.get_height(fsize), l.size.y]
	return ""
