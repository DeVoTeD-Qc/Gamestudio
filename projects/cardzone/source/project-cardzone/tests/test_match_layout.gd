# test_match_layout.gd
# Adapted from CallingCard tests/test_duel_layout.gd (cc07): the same screen cases (size in points
#   + pixel ratio + optional notch insets -> ScreenProfile logical canvas), the same SubViewport
#   _spawn / _despawn helpers, the safe-rect, tap-target, effective-point and _clipped checks.
# Purpose: Layout, readability and touch checks for the CardZone match screen (cz10,
#   scenes/match/Match.tscn) on the mock states (start, mid, late):
#   - key controls visible, inside the safe area (notch insets too), no overlaps; the layout's
#     minimum size fits the screen,
#   - every tap target (Buttons + group "tap_target") >= 64 logical px and >= 44 pt, on screen;
#     overlapped cards keep an exposed strip >= 64 px / 44 pt,
#   - text >= 11 pt; key numbers >= 24 px; hand cards >= 84x118 pt (art-direction.md §3),
#   - names, health, tags and Zone chips show their whole text; card faces and tile contents fit,
#   - map: 7 tiles in the spec §3 diagram, gas matches the Zone route, pawns differ by shape,
#   - loadout strip: next hand outlined as armour, held cards tagged, Brace summed,
#   - the rival's held cards never reach the screen (only counts),
#   - the inspector opens for every card on every screen and fits the safe area,
#   - nothing is hover-only; tap / hold / right-click / INFO all work.
# Headless note: the headless root window is 64x64; _spawn sizes it to 1280x720 while a test runs.
# Author: UI/UX Agent (cz10)
extends "res://tests/test_case.gd"

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const MatchTheme: GDScript = preload("res://scripts/ui/match_theme.gd")
const MATCH_SCENE: String = "res://scenes/match/Match.tscn"
const MIN_TAP_PT: float = 44.0
const MIN_TAP_PX: float = 64.0
const MIN_BODY_PT: float = 11.0
const MIN_NUMBER_PX: float = 24.0
const EPS: float = 0.5

## Screens: size in points, pixel ratio, safe-area insets in points (left, top, right, bottom).
const DESKTOP: Dictionary = {"name": "desktop 1280x720", "pt": Vector2(1280, 720), "ratio": 1.0}
const PHONE: Dictionary = {"name": "iPhone 844x390 @3x", "pt": Vector2(844, 390), "ratio": 3.0}
const PHONE_NOTCH: Dictionary = {"name": "iPhone 844x390 @3x + notch insets", "pt": Vector2(844, 390),
		"ratio": 3.0, "insets": Rect2(47, 0, 47, 21)}
const PHONE_SMALL: Dictionary = {"name": "iPhone SE 667x375 @2x", "pt": Vector2(667, 375), "ratio": 2.0}
const SCREENS: Array[Dictionary] = [DESKTOP, PHONE, PHONE_NOTCH, PHONE_SMALL]

var _saved_root_size: Vector2i


static func logical_size(screen: Dictionary) -> Vector2:
	var px: Vector2 = screen["pt"] * float(screen["ratio"])
	return ScreenProfile.logical_size(px, ScreenProfile.base_size(px, screen["ratio"]))


static func points_per_px(screen: Dictionary) -> float:
	return ScreenProfile.points_per_px(screen["pt"] * float(screen["ratio"]), screen["ratio"])


static func states() -> Array[Dictionary]:
	return [MockMatchData.start_state(), MockMatchData.mid_state(), MockMatchData.late_state()]


# --- Static checks -------------------------------------------------------------

func test_match_scene_instantiates() -> void:
	var scene: PackedScene = load(MATCH_SCENE) as PackedScene
	assert_not_null(scene, "Match.tscn loads")
	if scene == null:
		return
	var node: Node = scene.instantiate()
	for unique: String in ["%SafeArea", "%TopBar", "%MenuButton", "%YouPanel", "%ZoneTrack", "%RivalPanel", "%InfoButton",
			"%MapPanel", "%MapView", "%LineRow", "%LineCaption", "%LineCards", "%StripRow", "%StripCaption", "%StripCards",
			"%HandCards", "%CardInspector"]:
		assert_not_null(node.get_node_or_null(unique), "Match lacks %s" % unique)
	node.free()


func test_route_to_match() -> void:
	var router: Node = tree.root.get_node("SceneRouter")
	assert_true(router.has_route(&"match"), "SceneRouter has a 'match' route to an existing scene")
	assert_eq(String(router.ROUTES[&"match"]), MATCH_SCENE, "match route path")


func test_screen_profiles() -> void:
	assert_eq(logical_size(DESKTOP), Vector2(1280, 720), "desktop logical")
	assert_eq(logical_size(PHONE), Vector2(1168, 540), "phone logical")
	assert_eq(logical_size(PHONE_SMALL), Vector2(960, 540), "SE logical")
	assert_true(points_per_px(PHONE_SMALL) >= 0.69, "SE pt/px %.3f" % points_per_px(PHONE_SMALL))


func test_theme_defines_every_variation() -> void:
	var t: Theme = MatchTheme.build()
	var used: Dictionary = {}
	var re: RegEx = RegEx.create_from_string('&"([A-Z]\\w+)"')
	for path: String in _ui_files():
		var src: String = FileAccess.get_file_as_string(path)
		for line: String in src.split("\n"):
			if "theme_type_variation" in line or "_label(" in line or "TagChip" in line:
				for m: RegExMatch in re.search_all(line):
					used[StringName(m.get_string(1))] = true
	assert_true(used.size() >= 15, "found the variations the match screen uses (%d)" % used.size())
	for v: StringName in used.keys():
		if v in [&"TopButton", &"InfoPanelButton"] or MatchTheme.USED.has(v):
			continue
		if ClassDB.class_exists(v):
			continue
		assert_true(false, "variation %s is used but not in MatchTheme.USED" % v)
	for v: StringName in MatchTheme.USED:
		assert_eq(t.get_type_variation_base(v), MatchTheme.USED[v], "theme variation %s" % v)
		var styled: bool = not t.get_stylebox_list(v).is_empty() or not t.get_font_size_list(v).is_empty() \
				or not t.get_color_list(v).is_empty()
		assert_true(styled, "theme variation %s has a style" % v)


func test_text_contrast() -> void:
	# WCAG contrast >= 4.5:1 for text pairs the screen uses.
	var pairs: Array = [[MatchTheme.PAPER, MatchTheme.ZONE_VIOLET], [MatchTheme.PAPER, MatchTheme.ZONE_DUSK],
			[MatchTheme.INK, MatchTheme.PAPER], [MatchTheme.INK, MatchTheme.DUNE], [MatchTheme.INK, MatchTheme.HIT_RED],
			[MatchTheme.INK, MatchTheme.GAS_GLOW], [MatchTheme.INK, MatchTheme.GAS_LIME], [MatchTheme.INK, MatchTheme.ZONE_EDGE],
			[MatchTheme.INK, MatchTheme.BRACE_STEEL], [MatchTheme.INK, Color("#FFEE80")], [MatchTheme.INK, Color("#FFB070")]]
	for r: StringName in [&"C", &"U", &"R", &"E", &"L"]:
		var cols: Array = MatchTheme.rarity_colors(r)
		pairs.append([cols[1], cols[0]])
	for p: Array in pairs:
		var ratio: float = _contrast(p[0], p[1])
		assert_true(ratio >= 4.5, "contrast %s on %s is %.2f" % [p[0].to_html(false), p[1].to_html(false), ratio])


func test_mock_state_hides_rival_held_cards() -> void:
	for st: Dictionary in states():
		var rival: Dictionary = st["rival"]
		for key: String in ["held", "hand", "next", "line", "loadout"]:
			assert_false(rival.has(key), "rival state carries no '%s' cards (round %d)" % [key, st["round"]])
		assert_true(rival.has("held_count") and rival.has("loadout_count"), "rival counts present")


# --- Layout --------------------------------------------------------------------

func test_layout_desktop() -> void:
	for st: Dictionary in states():
		await _check_layout(DESKTOP, st)


func test_layout_phone() -> void:
	for st: Dictionary in states():
		await _check_layout(PHONE, st)


func test_layout_phone_with_notch_insets() -> void:
	for st: Dictionary in states():
		await _check_layout(PHONE_NOTCH, st)


func test_layout_small_phone() -> void:
	for st: Dictionary in states():
		await _check_layout(PHONE_SMALL, st)


func test_map_tiles_gas_and_pawns() -> void:
	var setup: Array = await _spawn(PHONE_SMALL, MockMatchData.late_state())
	var m: Control = setup[1]
	var tiles: Dictionary = {}
	for t: Button in m.get_area_tiles():
		tiles[t.area_id] = t
	assert_eq(tiles.size(), 7, "7 areas")
	# Route A after Zone card 12: Docks, Farmstead, Rail Yard, Radio Hill, Quarry, Motel gassed; Core open.
	for id: StringName in [&"docks", &"farmstead", &"rail_yard", &"radio_hill", &"quarry", &"motel"]:
		assert_true(tiles[id].gas, "%s gassed" % id)
	assert_false(tiles[&"old_town"].gas, "Core open")
	assert_true(tiles[&"old_town"].you_here and tiles[&"old_town"].rival_here, "both pawns in the Core")
	var pr: Array[Rect2] = tiles[&"old_town"].pawn_rects()
	assert_eq(pr.size(), 2, "two pawns drawn")
	assert_false(pr[0].intersects(pr[1]), "pawns do not overlap")
	var k: float = points_per_px(PHONE_SMALL)
	assert_true(pr[0].size.x * k >= 28.0 - 0.01, "pawn %.1f pt >= 28 pt" % (pr[0].size.x * k))
	# Diagram: Core in the middle, ring around it, every ring tile touching the Core's row band.
	var core: Rect2 = tiles[&"old_town"].get_global_rect()
	assert_true(tiles[&"rail_yard"].get_global_rect().end.x <= core.position.x + EPS, "Rail Yard left of the Core")
	assert_true(tiles[&"quarry"].get_global_rect().position.x >= core.end.x - EPS, "Quarry right of the Core")
	assert_true(tiles[&"docks"].get_global_rect().end.y <= core.position.y + EPS, "Docks above")
	assert_true(tiles[&"radio_hill"].get_global_rect().position.y >= core.end.y - EPS, "Radio Hill below")
	# Gas is shown by text + hatch, not colour alone.
	for l: Label in tiles[&"docks"].get_labels():
		if l.text == "GAS":
			assert_true(l.is_visible_in_tree(), "GAS tag visible")
	_despawn(setup[0])


func test_loadout_strip_is_armour() -> void:
	var setup: Array = await _spawn(PHONE, MockMatchData.mid_state())
	var m: Control = setup[1]
	var next: Array[Button] = m.get_card_buttons(&"next")
	assert_eq(next.size(), 5, "next hand: 5 cards")
	var held: int = 0
	for b: Button in next:
		assert_true(b.armour, "%s outlined as armour" % b.card_id)
		if b.held:
			held += 1
			assert_eq(b.get_tag().text, "HOLD", "held card tagged")
			assert_true(b.get_tag().is_visible_in_tree(), "HOLD tag visible")
	assert_eq(held, 2, "2 held cards marked")
	var cap: String = (m.get_node("%StripCaption") as Button).text
	assert_true("BRACE 3" in cap, "caption sums Brace (Smoke 2 + Duck 1): %s" % cap)
	assert_true("+4" in cap, "caption counts cards below: %s" % cap)
	assert_eq(m.get_card_buttons(&"hand").size(), 6, "hand: 5 cards + a free Hit")
	assert_eq(m.get_card_buttons(&"line").size(), 2, "line: 2 played")
	# Late: a Hit on top of the loadout is tagged DOWN +1.
	m.show_state(MockMatchData.late_state())
	await tree.process_frame
	var top: Button = m.get_card_buttons(&"next")[0]
	assert_eq(top.card_id, MockMatchData.HIT, "Hit on top")
	assert_eq(top.get_tag().text, "DOWN +1", "Hit tagged Down")
	assert_true(m.get_player_panels()[0].is_down_shown(), "you are Down")
	assert_true(m.get_player_panels()[1].is_bounty_shown(), "rival holds the Bounty")
	_despawn(setup[0])


func test_opponent_panel_counts_only() -> void:
	var setup: Array = await _spawn(PHONE_NOTCH, MockMatchData.mid_state())
	var m: Control = setup[1]
	var rival: Button = m.get_player_panels()[1]
	var texts: PackedStringArray = []
	for l: Label in rival.get_labels():
		if l.is_visible_in_tree():
			texts.append(l.text)
	var all: String = " ".join(texts)
	assert_true("3" in all and "DOWN +1" in all and "Loadout 13" in all and "Held 2" in all, "rival panel: %s" % all)
	assert_false(rival.is_bounty_shown(), "rival has no Bounty in mid state")
	assert_true(m.get_player_panels()[0].is_bounty_shown(), "you hold the Bounty")
	# No rival card anywhere on screen.
	for zone: StringName in [&"line", &"next", &"hand"]:
		for b: Button in m.get_card_buttons(zone):
			assert_false(b.card.get("hidden", false), "no hidden card in your rows")
	rival.tapped.emit()
	await tree.process_frame
	var insp: Control = m.get_inspector()
	assert_true(insp.is_open() and "hidden" in insp.get_body_text(), "rival sheet explains held cards are hidden")
	insp.close()
	_despawn(setup[0])


func test_zone_track_shows_next_cards() -> void:
	for screen: Dictionary in SCREENS:
		var setup: Array = await _spawn(screen, MockMatchData.mid_state())
		var m: Control = setup[1]
		var chips: Array[Label] = m.get_zone_track().get_chip_labels()
		assert_true(chips.size() >= 2, "%s: current + next chips (%d)" % [screen["name"], chips.size()])
		assert_true(chips[0].text.begins_with("NOW 5"), "%s current chip: %s" % [screen["name"], chips[0].text])
		assert_true(chips[1].text.begins_with("6 "), "%s next chip: %s" % [screen["name"], chips[1].text])
		var track: Rect2 = m.get_zone_track().get_global_rect().grow(EPS)
		for c: Label in chips:
			assert_true(track.encloses(c.get_global_rect()), "%s chip '%s' inside the track" % [screen["name"], c.text])
		m.get_zone_track().tapped.emit()
		await tree.process_frame
		assert_true(m.get_inspector().is_open() and "14." in m.get_inspector().get_body_text(), "tap lists all 14 Zone cards")
		_despawn(setup[0])


# --- Inspector -----------------------------------------------------------------

func test_inspector_every_card_every_screen() -> void:
	for screen: Dictionary in SCREENS:
		var setup: Array = await _spawn(screen, MockMatchData.mid_state())
		var viewport: SubViewport = setup[0]
		var m: Control = setup[1]
		var k: float = points_per_px(screen)
		var inspector: Control = m.get_inspector()
		var safe: Rect2 = _safe_rect(m, viewport)
		var cards: Array[Dictionary] = MockMatchData.all_cards()
		cards.append({"id": &"hidden", "hidden": true})
		for c: Dictionary in cards:
			if c.get("hidden", false):
				inspector.open_card({}, {"hidden": true})
			else:
				inspector.open_card(c, {"where": "In your hand"})
			await tree.process_frame
			await tree.process_frame
			var label: String = "%s inspector %s" % [screen["name"], c.get("name", "hidden")]
			assert_true(inspector.is_open(), "%s opens" % label)
			var panel: Rect2 = inspector.get_panel().get_global_rect()
			assert_true(safe.encloses(panel), "%s panel %s inside safe area %s" % [label, panel, safe])
			var big: Rect2 = inspector.get_card_view().get_global_rect()
			assert_true(big.size.x * k >= 200.0 and big.size.y * k >= 280.0, "%s big card %.0fx%.0f pt" % [label, big.size.x * k, big.size.y * k])
			for l: Label in inspector.get_important_labels():
				if l.is_visible_in_tree():
					assert_true(_clipped(l).is_empty(), "%s '%s' is cut: %s" % [label, l.text, _clipped(l)])
			for n: Node in inspector.find_children("*", "Control", true, false):
				if (n is Label or n is Button) and (n as Control).is_visible_in_tree() and not String(n.text).strip_edges().is_empty():
					var px: int = (n as Control).get_theme_font_size(&"font_size")
					assert_true(px * k >= MIN_BODY_PT - 0.01, "%s text '%s' %.1f pt" % [label, n.text, px * k])
			var close: Button = inspector.get_node("%CloseButton") if inspector.has_node("%CloseButton") else inspector.find_child("CloseButton", true, false)
			var cr: Rect2 = close.get_global_rect()
			assert_true(minf(cr.size.x, cr.size.y) >= MIN_TAP_PX - EPS and minf(cr.size.x, cr.size.y) * k >= MIN_TAP_PT - 0.01, "%s CLOSE %s" % [label, cr.size])
			assert_true(safe.encloses(cr), "%s CLOSE inside the safe area" % label)
			inspector.close()
		# Info sheets: areas, Zone deck, players, line, loadout.
		for a: Dictionary in MockMatchData.AREAS:
			m.inspect_area(a["id"])
			await tree.process_frame
			assert_true(safe.encloses(inspector.get_panel().get_global_rect()), "%s area sheet %s inside safe area" % [screen["name"], a["name"]])
			inspector.close()
		for f: Callable in [m.inspect_zone, m.inspect_line, m.inspect_loadout, m.inspect_player.bind(&"you"), m.inspect_player.bind(&"rival")]:
			f.call()
			await tree.process_frame
			await tree.process_frame
			assert_true(safe.encloses(inspector.get_panel().get_global_rect()), "%s sheet '%s' inside safe area" % [screen["name"], inspector.get_title_text()])
			inspector.close()
		_despawn(viewport)


# --- Interaction ---------------------------------------------------------------

func test_nothing_is_hover_only() -> void:
	var setup: Array = await _spawn(PHONE, MockMatchData.mid_state())
	var m: Control = setup[1]
	var tips: Array[String] = []
	for n: Node in m.find_children("*", "Control", true, false):
		if (n as Control).tooltip_text != "":
			tips.append(String(m.get_path_to(n)))
	assert_true(tips.is_empty(), "no tooltips (hover-only info): %s" % [tips])
	var t: Theme = m.theme
	for v: StringName in [&"TopButton", &"CardButton", &"TileButton", &"InfoPanelButton"]:
		assert_eq(t.get_stylebox(&"hover", v), t.get_stylebox(&"normal", v), "%s hover == normal" % v)
	_despawn(setup[0])


func test_tap_hold_right_click_and_info_inspect() -> void:
	var setup: Array = await _spawn(PHONE, MockMatchData.mid_state())
	var m: Control = setup[1]
	var inspector: Control = m.get_inspector()
	var seen: Array = []
	m.card_inspected.connect(func(id: StringName, zone: StringName) -> void: seen.append([id, zone]))
	var hand: Array[Button] = m.get_card_buttons(&"hand")
	# Hold on a hand card: inspector opens, the release does not select.
	var rifle: Button = hand[1]
	rifle.simulate_hold()
	rifle.pressed.emit()
	await tree.process_frame
	assert_true(inspector.is_open(), "hold opens the inspector")
	assert_eq(inspector.get_title_text(), "Hunting Rifle", "held card inspected")
	assert_eq(m.get_selected(), null, "hold does not select")
	inspector.close()
	# Right-click on a line card and on the loadout strip.
	for zone: StringName in [&"line", &"next"]:
		var b: Button = m.get_card_buttons(zone)[0]
		var rc: InputEventMouseButton = InputEventMouseButton.new()
		rc.button_index = MOUSE_BUTTON_RIGHT
		rc.pressed = true
		b._gui_input(rc)
		await tree.process_frame
		assert_true(inspector.is_open(), "right-click opens the inspector (%s)" % zone)
		inspector.close()
	# Long-press an area tile.
	var tile: Button = m.get_area_tiles()[0]
	tile.simulate_hold()
	await tree.process_frame
	assert_true(inspector.is_open() and inspector.get_title_text() == "Docks", "hold on a tile inspects the area")
	assert_true("GAS" in inspector.get_body_text(), "gassed area explains gas")
	inspector.close()
	# Tap selects; INFO then inspects the selection.
	var info: Button = m.get_node("%InfoButton")
	assert_true(info.disabled, "INFO disabled with nothing selected")
	hand[3].pressed.emit()
	await tree.process_frame
	assert_true(hand[3].selected, "tap selects")
	assert_false(info.disabled, "INFO enabled with a selection")
	info.pressed.emit()
	await tree.process_frame
	assert_true(inspector.is_open() and inspector.get_title_text() == "Plate Vest", "INFO inspects the selected card")
	inspector.close()
	# Cancel (Esc / right-click) closes.
	m.inspect_zone()
	var esc: InputEventAction = InputEventAction.new()
	esc.action = &"cancel"
	esc.pressed = true
	inspector._unhandled_input(esc)
	assert_false(inspector.is_open(), "cancel closes the inspector")
	assert_true(seen.size() >= 3, "card_inspected emitted (%d)" % seen.size())
	_despawn(setup[0])


# --- Helpers -------------------------------------------------------------------

func _spawn(screen: Dictionary, state: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var viewport: SubViewport = SubViewport.new()
	var logical: Vector2 = screen.get("logical", logical_size(screen))
	viewport.size = Vector2i(logical)
	viewport.disable_3d = true
	tree.root.add_child(viewport)
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	m.points_per_px_override = points_per_px(screen)
	if screen.has("insets"):
		var k: float = points_per_px(screen)
		var insets: Rect2 = screen["insets"]
		var lt: Vector2 = insets.position / k
		var rb: Vector2 = insets.size / k  # Rect2 size holds (right, bottom) insets here
		m.safe_area_override = Rect2(lt, logical - lt - rb)
	m.show_state(state)
	viewport.add_child(m)
	for i: int in 4:
		await tree.process_frame
	return [viewport, m]


func _despawn(viewport: SubViewport) -> void:
	viewport.queue_free()
	tree.root.size = _saved_root_size


func _safe_rect(m: Control, viewport: SubViewport) -> Rect2:
	if m.safe_area_override.has_area():
		return m.safe_area_override.grow(EPS)
	return Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(EPS)


func _check_layout(screen: Dictionary, state: Dictionary) -> void:
	var setup: Array = await _spawn(screen, state)
	var viewport: SubViewport = setup[0]
	var m: Control = setup[1]
	var label: String = "%s round %d" % [screen["name"], state["round"]]
	var k: float = points_per_px(screen)
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(EPS)
	var safe: Rect2 = _safe_rect(m, viewport)

	assert_eq(m.size, Vector2(viewport.size), "%s Match fills the viewport" % label)
	assert_eq(m.compact, viewport.size.y < ScreenProfile.COMPACT_HEIGHT, "%s compact flag" % label)
	var needed: Vector2 = m.get_node("%SafeArea").get_combined_minimum_size()
	assert_true(needed.x <= viewport.size.x + EPS and needed.y <= viewport.size.y + EPS,
			"%s layout needs %s but screen is %s" % [label, needed, viewport.size])

	# Key controls: visible, inside the safe area, no overlaps.
	var keys: Dictionary = m.get_key_controls()
	var names: Array = keys.keys()
	for key: String in names:
		var c: Control = keys[key]
		var r: Rect2 = c.get_global_rect()
		assert_true(c.is_visible_in_tree() and r.size.x > 1.0 and r.size.y > 1.0, "%s %s not visible (%s)" % [label, key, r])
		assert_true(safe.encloses(r), "%s %s outside the safe area: %s not in %s" % [label, key, r, safe])
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var a: Rect2 = (keys[names[i]] as Control).get_global_rect().grow(-EPS)
			var b: Rect2 = (keys[names[j]] as Control).get_global_rect().grow(-EPS)
			assert_false(a.intersects(b), "%s %s overlaps %s (%s / %s)" % [label, names[i], names[j], a, b])

	# Tap targets.
	var targets: Array[Control] = []
	for n: Node in tree.get_nodes_in_group(&"tap_target"):
		if m.is_ancestor_of(n) and n is Control:
			targets.append(n)
	for n: Node in m.find_children("*", "Button", true, false):
		if not targets.has(n):
			targets.append(n)
	var you: Dictionary = state["you"]
	var expected: int = 7 + 6 + (you["hand"] as Array).size() + (you["line"] as Array).size() + (you["next"] as Array).size()
	assert_true(targets.size() >= expected, "%s expected >= %d tap targets, got %d" % [label, expected, targets.size()])
	var min_tap: float = INF
	for c: Control in targets:
		if not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		var side_px: float = minf(r.size.x, r.size.y)
		min_tap = minf(min_tap, side_px)
		assert_true(side_px >= MIN_TAP_PX - EPS, "%s tap target %s is %s (< 64 px)" % [label, m.get_path_to(c), r.size])
		assert_true(side_px * k >= MIN_TAP_PT - 0.01, "%s tap target %s = %.1f pt (< 44 pt)" % [label, m.get_path_to(c), side_px * k])
		assert_true(screen_rect.encloses(r), "%s tap target %s off screen" % [label, m.get_path_to(c)])

	# Card rows: inside their row, exposed strips >= 64 px / 44 pt, faces fit, numerals >= 24 px.
	var min_number: float = INF
	var art_hand: Vector2 = Vector2(84, 118) / k
	for zone: StringName in [&"line", &"next", &"hand"]:
		var row: Control = m.get_rows()[zone]
		var row_rect: Rect2 = row.get_global_rect().grow(EPS)
		var cards: Array[Button] = m.get_card_buttons(zone)
		for i: int in cards.size():
			var b: Button = cards[i]
			var r: Rect2 = b.get_global_rect()
			assert_true(row_rect.encloses(r), "%s %s card %d %s spills out of its row %s" % [label, zone, i, r, row_rect])
			if i > 0:
				var step: float = r.position.x - cards[i - 1].get_global_rect().position.x
				assert_true(step >= MIN_TAP_PX - EPS and step * k >= MIN_TAP_PT - 0.01, "%s %s card %d exposed strip %.0f px" % [label, zone, i - 1, step])
			if zone == &"hand":
				assert_true(r.size.x >= art_hand.x - 1.0 and r.size.y >= art_hand.y - 1.0, "%s hand card %s >= 84x118 pt (%s px)" % [label, r.size, art_hand])
			var face: Control = b.get_face()
			assert_eq(face.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s face leaves input to its button" % label)
			var need: Vector2 = face.get_combined_minimum_size()
			assert_true(need.x <= r.size.x + EPS and need.y <= r.size.y + EPS, "%s %s card %s face needs %s, has %s" % [label, zone, b.card_id, need, r.size])
			var num: int = int(face.layout_report()["numeral_px"])
			min_number = minf(min_number, num * k)
			assert_true(num >= MIN_NUMBER_PX, "%s %s card numerals %d px" % [label, zone, num])

	# Map: 7 tiles inside the map panel, no overlaps, contents fit.
	var map_rect: Rect2 = m.get_node("%MapPanel").get_global_rect().grow(EPS)
	var tiles: Array[Button] = m.get_area_tiles()
	assert_eq(tiles.size(), 7, "%s 7 area tiles" % label)
	for i: int in tiles.size():
		var r: Rect2 = tiles[i].get_global_rect()
		assert_true(map_rect.encloses(r), "%s tile %s inside the map" % [label, tiles[i].area_id])
		var content: Vector2 = (tiles[i].get_child(0) as Control).get_combined_minimum_size()
		assert_true(content.x <= r.size.x + EPS and content.y <= r.size.y + EPS, "%s tile %s content %s fits %s" % [label, tiles[i].area_id, content, r.size])
		for j: int in range(i + 1, tiles.size()):
			assert_false(r.grow(-EPS).intersects(tiles[j].get_global_rect().grow(-EPS)), "%s tiles %s and %s overlap" % [label, tiles[i].area_id, tiles[j].area_id])

	# Text sizes (all visible labels and buttons).
	var min_body: float = INF
	for n: Node in m.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree() or not (c is Label or c is Button):
			continue
		if String(c.text).strip_edges().is_empty():
			continue
		var px: int = c.get_theme_font_size(&"font_size")
		min_body = minf(min_body, px * k)
		assert_true(px * k >= MIN_BODY_PT - 0.01, "%s text '%s' (%s) is %.1f pt" % [label, c.text, m.get_path_to(c), px * k])
		if c.is_in_group(&"key_number"):
			assert_true(px >= MIN_NUMBER_PX, "%s key number '%s' is %d px" % [label, c.text, px])
	# Whole text shows: panels, Zone track, tiles. Caption buttons fit their text.
	for l: Label in m.get_important_labels():
		if not l.is_visible_in_tree() or l.text.strip_edges().is_empty():
			continue
		var why: String = _clipped(l)
		assert_true(why.is_empty(), "%s '%s' (%s) is cut: %s" % [label, l.text, m.get_path_to(l), why])
	for key: String in ["%LineCaption", "%StripCaption", "%MenuButton", "%InfoButton"]:
		var b: Button = m.get_node(key)
		var need: Vector2 = b.get_minimum_size()
		assert_true(need.x <= b.size.x + EPS and need.y <= b.size.y + EPS, "%s %s text needs %s, has %s" % [label, key, need, b.size])
	print("     [%s] canvas %s, %.3f pt/px, hand %s mini %s: smallest text %.1f pt, numbers %.1f pt, tap %.1f pt" % [
			label, viewport.size, k, m.hand_card, m.mini_card, min_body, min_number, min_tap * k])
	_despawn(viewport)


## Why a label's text does not fully show ("" when it does).
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
	var hbox: float = font.get_height(fsize)
	if l.size.y + 0.5 < hbox:
		return "needs %.0f px tall, has %.0f px" % [hbox, l.size.y]
	# Inside a clipping parent (tile, panel): the label must end inside it.
	var p: Node = l.get_parent()
	while p != null and p is Control:
		if (p as Control).clip_contents:
			var pr: Rect2 = (p as Control).get_global_rect().grow(0.5)
			if not pr.encloses(l.get_global_rect()):
				return "outside its clipping parent %s" % p.name
			break
		p = p.get_parent()
	return ""


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lum(c: Color) -> float:
	var f: Callable = func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


func _ui_files() -> PackedStringArray:
	var out: PackedStringArray = [MATCH_SCENE]
	for f: String in ["match_screen.gd", "card_face.gd", "match_card_button.gd", "area_tile.gd", "zone_track.gd",
			"player_panel.gd", "card_inspector.gd"]:
		out.append("res://scripts/ui/" + f)
	return out
