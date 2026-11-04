# test_duel_layout.gd
# Purpose: Layout, readability and touch checks for the duel screen (cc07: scenes/Duel.tscn with
#   Wall, Slot, Hand, ScoreCounter and CardInspector; cards are cc14 BannerCards). Approach from Killstreak
#   tests/test_board_layout.gd: each case is a real screen (size in points + pixel ratio + optional
#   notch insets); ScreenProfile gives the logical canvas; the screen is laid out in a SubViewport
#   of that size, then:
#   - key controls are visible, on screen, inside the safe area and do not overlap,
#   - the wall is 3-4-3 with rows B offset by half a brick, bricks >= 64 px tall, about 4:1,
#   - EFFECTIVE sizes (logical px * pt per px): text >= 11 pt, key numbers >= 24 px and >= 17 pt,
#     every tap target (Buttons + group "tap_target") >= 64 logical px and >= 44 pt,
#   - names, scores and values show their whole text; hand cards stay inside the hand,
#   - the inspector fits every card (all 20) on every screen, CLOSE >= 64 px,
#   - nothing is hover-only (no tooltips), tap / hold / right-click / INFO all inspect,
#   - EventBus signals drive the view (placement, capture, Ambush, Carded, score, turn).
# Headless note: the headless root window is 64x64; _spawn sizes it to 1280x720 while a test runs
#   so font oversampling and line heights match a real window (as in Killstreak).
# Author: UI/UX Agent (cc07)
extends "res://tests/test_case.gd"

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const MockDuelData: GDScript = preload("res://scripts/ui/mock_duel_data.gd")
const DuelTheme: GDScript = preload("res://scripts/ui/duel_theme.gd")
const DuelScreenScript: GDScript = preload("res://scripts/ui/duel_screen.gd")
const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")
const DUEL_SCENE: String = "res://scenes/Duel.tscn"
const MIN_TAP_PT: float = 44.0
const MIN_TAP_PX: float = 64.0
const MIN_BODY_PT: float = 11.0
const MIN_NUMBER_PX: float = 24.0
const MIN_NUMBER_PT: float = 16.0
const EPS: float = 0.5

## Screens: size in points, pixel ratio, safe-area insets in points (left, top, right, bottom).
const DESKTOP: Dictionary = {"name": "desktop 1280x720", "pt": Vector2(1280, 720), "ratio": 1.0}
const PHONE: Dictionary = {"name": "iPhone 844x390 @3x", "pt": Vector2(844, 390), "ratio": 3.0}
const PHONE_NOTCH: Dictionary = {"name": "iPhone 844x390 @3x + notch insets", "pt": Vector2(844, 390),
		"ratio": 3.0, "insets": Rect2(47, 0, 47, 21)}
const PHONE_SMALL: Dictionary = {"name": "iPhone SE 667x375 @2x", "pt": Vector2(667, 375), "ratio": 2.0}
const TABLET: Dictionary = {"name": "iPad 1024x768 @2x", "pt": Vector2(1024, 768), "ratio": 2.0}
const SCREENS: Array[Dictionary] = [DESKTOP, PHONE, PHONE_NOTCH, PHONE_SMALL, TABLET]

var _saved_root_size: Vector2i


static func logical_size(screen: Dictionary) -> Vector2:
	var px: Vector2 = screen["pt"] * float(screen["ratio"])
	return ScreenProfile.logical_size(px, ScreenProfile.base_size(px, screen["ratio"]))


static func points_per_px(screen: Dictionary) -> float:
	return ScreenProfile.points_per_px(screen["pt"] * float(screen["ratio"]), screen["ratio"])


# --- Static checks -------------------------------------------------------------

func test_duel_scene_instantiates() -> void:
	var scene: PackedScene = load(DUEL_SCENE) as PackedScene
	assert_not_null(scene, "Duel.tscn loads")
	if scene == null:
		return
	var node: Node = scene.instantiate()
	for unique: String in ["%DuelController", "%DuelOverlay", "%Toast", "%SafeArea", "%MenuButton", "%PlayerCounter", "%RivalCounter", "%TurnPanel",
			"%Wall", "%Hand", "%InfoButton", "%PlaceButton", "%CardInspector"]:
		assert_not_null(node.get_node_or_null(unique), "Duel lacks %s" % unique)
	node.free()
	for path: String in _scene_files():
		assert_not_null(load(path), "%s loads" % path)


func test_screen_profiles() -> void:
	assert_eq(logical_size(DESKTOP), Vector2(1280, 720), "desktop logical")
	assert_eq(logical_size(PHONE), Vector2(1168, 540), "phone logical")
	assert_true(absf(points_per_px(PHONE) - 0.7222) < 0.001, "phone pt/px")
	assert_true(logical_size(PHONE).y < ScreenProfile.COMPACT_HEIGHT, "phone is compact")
	assert_false(logical_size(DESKTOP).y < ScreenProfile.COMPACT_HEIGHT, "desktop is not compact")


func test_brick_size_rule() -> void:
	assert_eq(DuelScreenScript.brick_size_for(1280 - 64 - 28), Vector2(288, 72), "desktop brick capped at 288x72")
	for w: float in [900.0, 1000.0, 1014.0, 1112.0, 1200.0]:  # SE, notch phone, phone, desktop
		var b: Vector2 = DuelScreenScript.brick_size_for(w)
		assert_true(b.y >= MIN_TAP_PX, "brick for %d px is %s (>= 64 tall)" % [w, b])
		assert_true(b.x / b.y >= 3.3 and b.x / b.y <= 4.05, "brick for %d px keeps ~4:1 (%s)" % [w, b])
		assert_true(b.x * 4.0 + 30.0 <= w + EPS, "4 bricks fit %d px" % w)


func test_theme_defines_every_variation() -> void:
	var t: Theme = DuelScreenScript.pick_theme()
	assert_not_null(t, "theme")
	var wall: Theme = load(DuelTheme.WALL_THEME_PATH) as Theme
	assert_not_null(wall, "cc14 wall_theme.tres loads")
	if wall != null:
		assert_eq(t.default_font, wall.default_font, "duel theme keeps cc14's default font")
	var used: Array[StringName] = []
	var re: RegEx = RegEx.create_from_string('theme_type_variation = &"(\\w+)"')
	for path: String in _scene_files():
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(path)):
			used.append(StringName(m.get_string(1)))
	for path: String in ["res://scripts/ui/wall_slot.gd", "res://scripts/ui/hand_view.gd", "res://scripts/ui/score_counter.gd"]:
		var re2: RegEx = RegEx.create_from_string('theme_type_variation = &"(\\w+)"')
		for m: RegExMatch in re2.search_all(FileAccess.get_file_as_string(path)):
			used.append(StringName(m.get_string(1)))
	for path: String in ["res://scripts/ui/wall_slot.gd", "res://scripts/ui/score_counter.gd"]:
		var re3: RegEx = RegEx.create_from_string('else &"(\\w+)"')
		for m: RegExMatch in re3.search_all(FileAccess.get_file_as_string(path)):
			used.append(StringName(m.get_string(1)))
	assert_true(used.size() > 15, "found the variations the scenes use (%d)" % used.size())
	for v: StringName in used:
		assert_true(DuelTheme.USED.has(v), "DuelTheme.USED lists %s" % v)
	for v: StringName in DuelTheme.USED:
		assert_eq(t.get_type_variation_base(v), DuelTheme.USED[v], "theme variation %s" % v)
		var styled: bool = not t.get_stylebox_list(v).is_empty() or not t.get_font_size_list(v).is_empty() \
				or not t.get_color_list(v).is_empty()
		assert_true(styled, "theme variation %s has a style" % v)


func test_mock_cards_match_budget() -> void:
	var budgets: Array[int] = [0, 13, 15, 17, 19]
	var cards: Array[Dictionary] = MockDuelData.all_cards()
	assert_eq(cards.size(), 20, "20 mock cards")
	for c: Dictionary in cards:
		assert_eq(int(c["top"]) + int(c["side"]) + int(c["bottom"]), budgets[int(c["clearance"])], "%s T+S+B" % c["name"])
		if c["origin"] == &"showcase":
			assert_true(c["clearance"] == 1 and c["trait"] == &"none", "%s Showcase rule" % c["name"])


# --- Layout --------------------------------------------------------------------

func test_layout_desktop() -> void:
	for state: Dictionary in [MockDuelData.start_state(), MockDuelData.mid_state(), MockDuelData.full_state()]:
		await _check_layout(DESKTOP, state)


func test_layout_phone() -> void:
	for state: Dictionary in [MockDuelData.start_state(), MockDuelData.mid_state(), MockDuelData.full_state()]:
		await _check_layout(PHONE, state)


func test_layout_phone_with_notch_insets() -> void:
	for state: Dictionary in [MockDuelData.start_state(), MockDuelData.mid_state(), MockDuelData.full_state()]:
		await _check_layout(PHONE_NOTCH, state)


func test_layout_small_phone_and_tablet() -> void:
	await _check_layout(PHONE_SMALL, MockDuelData.start_state())
	await _check_layout(TABLET, MockDuelData.mid_state())


## A screen too short for two hand rows falls back to the one-row scrolling strip.
func test_hand_strip_on_short_screen() -> void:
	var screen: Dictionary = {"name": "short 1168x470 (forced)", "pt": Vector2(1168, 470), "ratio": 1.0, "logical": Vector2(1168, 470)}
	var setup: Array = await _spawn(screen, MockDuelData.start_state())
	var viewport: SubViewport = setup[0]
	var duel: Control = setup[1]
	assert_true(duel.hand_strip, "short screen uses the hand strip")
	var scroll: ScrollContainer = duel.get_hand().get_scroll()
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "strip scrolls sideways")
	var cards: Array[Node] = duel.get_hand().get_card_buttons()
	assert_eq(cards.size(), 5, "5 cards in the strip")
	var y0: float = (cards[0] as Control).get_global_rect().position.y
	for c: Node in cards:
		var r: Rect2 = (c as Control).get_global_rect()
		assert_true(absf(r.position.y - y0) < EPS, "strip is one row")
		assert_true(minf(r.size.x, r.size.y) >= MIN_TAP_PX - EPS, "strip card %s >= 64 px" % r.size)
	var needed: Vector2 = duel.get_node("%SafeArea").get_combined_minimum_size()
	assert_true(needed.y <= viewport.size.y + EPS, "short layout fits (%s in %s)" % [needed, viewport.size])
	_despawn(viewport)


# --- Inspector -----------------------------------------------------------------

func test_inspector_every_card_every_screen() -> void:
	for screen: Dictionary in [DESKTOP, PHONE, PHONE_NOTCH, PHONE_SMALL]:
		var setup: Array = await _spawn(screen, MockDuelData.mid_state())
		var viewport: SubViewport = setup[0]
		var duel: Control = setup[1]
		var k: float = points_per_px(screen)
		var inspector: Control = duel.get_inspector()
		var screen_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(EPS)
		var safe: Rect2 = _safe_rect(duel, viewport)
		var worst_text: float = INF
		for c: Dictionary in MockDuelData.all_cards():
			for ctx: Dictionary in [{"owner": &"player", "where": "hand"}, {"owner": &"rival", "where": "wall", "face_down": true}]:
				inspector.open_card(c, ctx)
				await tree.process_frame
				await tree.process_frame
				var label: String = "%s inspector %s %s" % [screen["name"], c["name"], ctx["owner"]]
				assert_true(inspector.is_open(), "%s opens" % label)
				var panel: Rect2 = inspector.get_panel().get_global_rect()
				assert_true(safe.encloses(panel), "%s panel %s inside safe area %s" % [label, panel, safe])
				var big: BannerCard = inspector.get_card_view()
				var card_rect: Rect2 = big.get_global_rect()
				assert_true(card_rect.size.x >= 520.0 and card_rect.size.y >= 130.0, "%s big card %s" % [label, card_rect.size])
				assert_true(big.is_full_detail(), "%s big card shows name and trait word" % label)
				var lay: Dictionary = big.layout_report()
				assert_true(lay["name_fits"], "%s card name fits on the big card" % label)
				for l: Label in inspector.get_important_labels():
					assert_true(_clipped(l).is_empty(), "%s '%s' is cut: %s" % [label, l.text, _clipped(l)])
				for n: Node in inspector.find_children("*", "Control", true, false):
					if (n is Label or n is Button) and (n as Control).is_visible_in_tree() and not String(n.text).strip_edges().is_empty():
						var pt: float = (n as Control).get_theme_font_size(&"font_size") * k
						worst_text = minf(worst_text, pt)
						assert_true(pt >= MIN_BODY_PT - 0.01, "%s text '%s' %.1f pt" % [label, n.text, pt])
				var close: Control = inspector.get_node("%CloseButton")
				assert_true(minf(close.size.x, close.size.y) >= MIN_TAP_PX - EPS, "%s CLOSE %s" % [label, close.size])
				assert_true(screen_rect.encloses(close.get_global_rect()), "%s CLOSE on screen" % label)
				inspector.close()
		print("     [%s] inspector: smallest text %.1f pt" % [screen["name"], worst_text])
		_despawn(viewport)


func test_inspector_hides_rival_face_down_card() -> void:
	var setup: Array = await _spawn(DESKTOP, MockDuelData.mid_state())
	var duel: Control = setup[1]
	duel.inspect_slot(&"b3")  # rival's face-down Flare Up
	await tree.process_frame
	var inspector: Control = duel.get_inspector()
	assert_true(inspector.is_open(), "face-down card opens the inspector")
	assert_eq((inspector.get_node("%InspectorNameLabel") as Label).text, "Face-down card", "name hidden")
	assert_eq((inspector.get_node("%TopValue") as Label).text, "?", "values hidden")
	inspector.close()
	duel.inspect_slot(&"a1")  # own Graveyard Shift
	await tree.process_frame
	assert_eq((inspector.get_node("%InspectorNameLabel") as Label).text, "Graveyard Shift", "own card named")
	assert_true((inspector.get_node("%TraitRule") as Label).text.begins_with("Can't be captured"), "Steady rule text")
	assert_true((inspector.get_node("%EarnedLabel") as Label).text != "", "how it's earned")
	inspector.close()
	_despawn(setup[0])


# --- Interaction ---------------------------------------------------------------

func test_nothing_is_hover_only() -> void:
	var setup: Array = await _spawn(PHONE, MockDuelData.mid_state())
	var duel: Control = setup[1]
	var tips: Array[String] = []
	for n: Node in duel.find_children("*", "Control", true, false):
		if (n as Control).tooltip_text != "":
			tips.append(String(duel.get_path_to(n)))
	assert_true(tips.is_empty(), "no tooltips (hover-only info): %s" % [tips])
	# Card and slot buttons: hover style == normal style (hover never carries information).
	var t: Theme = duel.theme
	for v: StringName in [&"SlotButton", &"SlotButtonValid", &"HandCard"]:
		assert_eq(t.get_stylebox(&"hover", v), t.get_stylebox(&"normal", v), "%s hover == normal" % v)
	_despawn(setup[0])


func test_tap_hold_and_right_click_inspect() -> void:
	var setup: Array = await _spawn(PHONE, MockDuelData.mid_state())
	var duel: Control = setup[1]
	var inspector: Control = duel.get_inspector()
	var seen: Array = []
	var on_inspected: Callable = func(id: StringName, owned: bool) -> void: seen.append([id, owned])
	EventBus.card_inspected.connect(on_inspected)
	var hand_cards: Array[Node] = duel.get_hand().get_card_buttons()
	assert_eq(hand_cards.size(), 3, "mid-duel hand has 3 cards")
	# Hold on a hand card: inspector opens, and the release does not pick the card.
	var first: Button = hand_cards[0]
	first.simulate_hold()
	first.pressed.emit()
	await tree.process_frame
	assert_true(inspector.is_open(), "hold opens the inspector")
	assert_eq(duel.get_hand().picked_id, &"", "hold does not pick")
	inspector.close()
	# Right-click on a wall card.
	var slot: Button = duel.get_wall().get_slot(&"b2")
	var rc: InputEventMouseButton = InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	slot._gui_input(rc)
	await tree.process_frame
	assert_true(inspector.is_open(), "right-click opens the inspector")
	assert_eq(String((inspector.get_node("%InspectorNameLabel") as Label).text), "Brass Tacks", "right-clicked card")
	inspector.close()
	# Tap on an occupied wall slot inspects it.
	(duel.get_wall().get_slot(&"c1") as Button).pressed.emit()
	await tree.process_frame
	assert_true(inspector.is_open(), "tap on a wall card inspects")
	inspector.close()
	# Tap a hand card picks it; INFO then inspects it.
	first.pressed.emit()
	await tree.process_frame
	assert_eq(duel.get_hand().picked_id, &"neon_rain", "tap picks")
	var info: Button = duel.get_node("%InfoButton")
	assert_false(info.disabled, "INFO enabled with a picked card")
	info.pressed.emit()
	await tree.process_frame
	assert_true(inspector.is_open(), "INFO inspects the picked card")
	assert_eq(String((inspector.get_node("%InspectorNameLabel") as Label).text), "Neon Rain", "INFO card")
	inspector.close()
	assert_true(seen.size() >= 4, "card_inspected emitted (%d)" % seen.size())
	assert_true(seen.has([&"neon_rain", true]), "own card reported as owned")
	assert_true(seen.has([&"brass_tacks", false]), "rival card reported as not owned")
	EventBus.card_inspected.disconnect(on_inspected)
	_despawn(setup[0])


func test_pick_slot_place_flow_on_mock() -> void:
	var setup: Array = await _spawn(PHONE_NOTCH, MockDuelData.mid_state())
	var duel: Control = setup[1]
	var placed: Array = []
	var on_placed: Callable = func(side: StringName, card_id: StringName, slot: StringName, captures: Array) -> void:
		placed.append([side, card_id, slot, captures.size()])
	EventBus.card_placed.connect(on_placed)
	var place: Button = duel.get_node("%PlaceButton")
	assert_true(place.disabled, "PLACE starts disabled")
	(duel.get_hand().get_card_buttons()[2] as Button).pressed.emit()  # Snow Blind (Signature)
	await tree.process_frame
	var valid: int = 0
	for s: Node in duel.get_wall().get_slots():
		valid += 1 if s.target_state == &"valid" else 0
		if not s.is_empty():
			assert_eq(s.target_state, &"none", "occupied %s not a drop target" % s.slot_id)
	assert_eq(valid, 5, "5 empty slots glow")
	assert_true(place.disabled, "PLACE needs a slot")
	(duel.get_wall().get_slot(&"b4") as Button).pressed.emit()
	await tree.process_frame
	assert_false(place.disabled, "PLACE enabled with card + slot")
	assert_false(duel.get_wall().get_slot(&"b4").is_empty(), "pending card shown in the slot")
	place.pressed.emit()
	await tree.process_frame
	assert_eq(placed, [[&"player", &"snow_blind", &"b4", 0]], "card_placed emitted")
	var st: Dictionary = duel.get_state()
	assert_eq(st["wall"][&"b4"]["owner"], &"player", "wall updated from EventBus")
	assert_true(st["wall"][&"b4"]["face_down"], "Ambush card placed face-down")
	assert_eq((st["player"]["hand"] as Array).size(), 2, "hand shrank")
	assert_eq(duel.get_hand().get_card_buttons().size(), 2, "hand view shrank")
	assert_eq(st["turn_side"], &"rival", "rival's turn")
	assert_eq(String((duel.get_node("%TurnTitle") as Label).text), "ARCHIVIST'S TURN", "turn banner")
	assert_true(place.disabled, "PLACE disabled again")
	EventBus.card_placed.disconnect(on_placed)
	_despawn(setup[0])


func test_event_bus_drives_view() -> void:
	var setup: Array = await _spawn(DESKTOP, MockDuelData.mid_state())
	var duel: Control = setup[1]
	EventBus.card_captured.emit(&"player", &"brass_tacks", &"b2")
	EventBus.carded.emit(&"player", &"brass_tacks")
	EventBus.ambush_sprung.emit(&"rival", &"flare_up", &"b3")
	EventBus.score_changed.emit(6, 1)
	await tree.process_frame
	var b2: Node = duel.get_wall().get_slot(&"b2")
	assert_eq(b2.content["owner"], &"player", "capture flips the brick")
	assert_eq(b2.get_card().side, &"player", "card shows new owner")
	assert_true(b2.get_card().signature, "Signature ribbon on the card")
	assert_false(duel.get_wall().get_slot(&"b3").get_card().face_down, "Ambush flipped face-up")
	var counters: Array[Control] = duel.get_counters()
	assert_eq(String(counters[0].get_score_label().text), "6", "player score")
	assert_eq(String(counters[1].get_score_label().text), "1", "rival score")
	assert_true((counters[1].get_node("%SignatureState") as Label).visible, "rival ribbon says CARDED")
	EventBus.turn_started.emit(&"player", 7)
	await tree.process_frame
	assert_eq(String((duel.get_node("%TurnSub") as Label).text), "Turn 7 of 10", "turn counter")
	_despawn(setup[0])


func test_ownership_not_by_color_alone() -> void:
	var setup: Array = await _spawn(DESKTOP, MockDuelData.full_state())
	var duel: Control = setup[1]
	var owners: Dictionary = {}
	for s: Node in duel.get_wall().get_slots():
		owners[s.get_card().side] = true
	assert_true(owners.has(&"player") and owners.has(&"rival"), "both owners on the full wall")
	# The tab shape is drawn from owner_side (solid vs notched); the counters carry the same tabs.
	for c: Control in duel.get_counters():
		assert_true(c.side in [&"player", &"rival"], "counter side")
	assert_true(duel.get_wall().get_slot(&"a3").get_card().signature, "own Signature marked")
	assert_true(duel.get_wall().get_slot(&"b2").get_card().signature, "captured rival Signature marked")
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
	# Layout checks run on the cc07 mock states: no duel controller (cc08 has its own tests).
	DuelControllerScript.set_autostart(false)
	var duel: Control = (load(DUEL_SCENE) as PackedScene).instantiate()
	if screen.has("insets"):
		var k: float = points_per_px(screen)
		var insets: Rect2 = screen["insets"]
		var lt: Vector2 = insets.position / k
		var rb: Vector2 = insets.size / k  # Rect2 size holds (right, bottom) insets here
		duel.safe_area_override = Rect2(lt, logical - lt - rb)
	viewport.add_child(duel)
	DuelControllerScript.set_autostart(true)
	duel.show_state(state)
	for i: int in 4:
		await tree.process_frame
	return [viewport, duel]


func _despawn(viewport: SubViewport) -> void:
	viewport.queue_free()
	tree.root.size = _saved_root_size


func _safe_rect(duel: Control, viewport: SubViewport) -> Rect2:
	if duel.safe_area_override.has_area():
		return duel.safe_area_override.grow(EPS)
	return Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(EPS)


func _check_layout(screen: Dictionary, state: Dictionary) -> void:
	var setup: Array = await _spawn(screen, state)
	var viewport: SubViewport = setup[0]
	var duel: Control = setup[1]
	var label: String = "%s turn %d (%d on wall)" % [screen["name"], state["turn_index"], (state["wall"] as Dictionary).size()]
	var k: float = points_per_px(screen)
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(EPS)
	var safe: Rect2 = _safe_rect(duel, viewport)

	assert_eq(duel.size, Vector2(viewport.size), "%s Duel fills the viewport" % label)
	assert_eq(duel.compact, viewport.size.y < ScreenProfile.COMPACT_HEIGHT, "%s compact flag" % label)
	assert_false(duel.hand_strip, "%s all 5 hand cards fit in rows (no strip)" % label)
	var needed: Vector2 = duel.get_node("%SafeArea").get_combined_minimum_size()
	assert_true(needed.x <= viewport.size.x + EPS and needed.y <= viewport.size.y + EPS,
			"%s layout needs %s but screen is %s" % [label, needed, viewport.size])

	var keys: Dictionary = duel.get_key_controls()
	var names: Array = keys.keys()
	for key: String in names:
		var c: Control = keys[key]
		var r: Rect2 = c.get_global_rect()
		assert_true(c.is_visible_in_tree() and r.size.x > 1.0 and r.size.y > 1.0, "%s %s not visible (%s)" % [label, key, r])
		assert_true(safe.encloses(r), "%s %s outside the safe area: %s" % [label, key, r])
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var a: Rect2 = (keys[names[i]] as Control).get_global_rect().grow(-EPS)
			var b: Rect2 = (keys[names[j]] as Control).get_global_rect().grow(-EPS)
			assert_false(a.intersects(b), "%s %s overlaps %s (%s / %s)" % [label, names[i], names[j], a, b])

	# Wall geometry: 3-4-3, rows A and C offset by half a brick, no overlaps, inside the wall.
	var wall: Control = duel.get_wall()
	var wall_rect: Rect2 = wall.get_global_rect().grow(EPS)
	var rects: Dictionary = {}
	for s: Node in wall.get_slots():
		rects[s.slot_id] = (s as Control).get_global_rect()
		assert_true(wall_rect.encloses(rects[s.slot_id]), "%s %s inside the wall" % [label, s.slot_id])
	var brick: Vector2 = rects[&"b1"].size
	assert_true(brick.y >= MIN_TAP_PX - EPS and brick.x / brick.y >= 3.3, "%s brick %s (>= 64 tall, ~4:1)" % [label, brick])
	for row: Array in [[&"a1", &"a2", &"a3"], [&"b1", &"b2", &"b3", &"b4"], [&"c1", &"c2", &"c3"]]:
		for i: int in row.size():
			assert_true(absf(rects[row[i]].position.y - rects[row[0]].position.y) < EPS, "%s %s in its row" % [label, row[i]])
			if i > 0:
				assert_true(rects[row[i]].position.x >= rects[row[i - 1]].end.x - EPS, "%s %s overlaps its neighbour" % [label, row[i]])
	var half: float = (rects[&"b2"].position.x - rects[&"b1"].position.x) * 0.5
	assert_true(absf(rects[&"a1"].position.x - rects[&"b1"].position.x - half) < 1.0, "%s a1 sits between b1 and b2" % label)
	assert_true(absf(rects[&"c3"].position.x - rects[&"b3"].position.x - half) < 1.0, "%s c3 sits between b3 and b4" % label)
	assert_true(rects[&"a1"].end.y <= rects[&"b1"].position.y + EPS and rects[&"b1"].end.y <= rects[&"c1"].position.y + EPS, "%s rows stack" % label)

	# Tap targets: group "tap_target" plus every Button.
	var targets: Array[Control] = []
	for n: Node in tree.get_nodes_in_group(&"tap_target"):
		if duel.is_ancestor_of(n) and n is Control:
			targets.append(n)
	for n: Node in duel.find_children("*", "Button", true, false):
		if not targets.has(n):
			targets.append(n)
	var hand_count: int = (state["player"]["hand"] as Array).size()
	assert_true(targets.size() >= 13 + hand_count, "%s expected >= %d tap targets, got %d" % [label, 13 + hand_count, targets.size()])
	var min_tap: float = INF
	for c: Control in targets:
		if not c.is_visible_in_tree():
			continue
		var r: Rect2 = c.get_global_rect()
		var side_px: float = minf(r.size.x, r.size.y)
		min_tap = minf(min_tap, side_px)
		assert_true(side_px >= MIN_TAP_PX - EPS, "%s tap target %s is %s (< 64 px)" % [label, duel.get_path_to(c), r.size])
		assert_true(side_px * k >= MIN_TAP_PT - 0.01, "%s tap target %s = %.1f pt (< 44 pt)" % [label, duel.get_path_to(c), side_px * k])
		assert_true(screen_rect.encloses(r), "%s tap target %s off screen" % [label, duel.get_path_to(c)])

	# Text and key numbers in effective points.
	var min_body: float = INF
	var min_number: float = INF
	for n: Node in duel.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree() or not (c is Label or c is Button):
			continue
		if String(c.text).strip_edges().is_empty():
			continue
		var px: int = c.get_theme_font_size(&"font_size")
		min_body = minf(min_body, px * k)
		assert_true(px * k >= MIN_BODY_PT - 0.01, "%s text '%s' (%s) is %.1f pt" % [label, c.text, duel.get_path_to(c), px * k])
		if c.is_in_group(&"key_number"):
			min_number = minf(min_number, px * k)
			assert_true(px >= MIN_NUMBER_PX and px * k >= MIN_NUMBER_PT - 0.01, "%s number '%s' (%s) is %d px = %.1f pt" % [label, c.text, duel.get_path_to(c), px, px * k])

	# Whole text shows: counters and turn banner.
	for l: Label in duel.get_important_labels():
		if not l.is_visible_in_tree() or l.text.strip_edges().is_empty():
			continue
		var why: String = _clipped(l)
		assert_true(why.is_empty(), "%s '%s' (%s) is cut: %s" % [label, l.text, duel.get_path_to(l), why])
	# Cards (BannerCard draws its own text): values >= 24 px, filling the brick / hand button.
	var cards: Array[BannerCard] = []
	for s: Node in wall.get_slots():
		if not s.is_empty():
			cards.append(s.get_card())
	for b: Node in duel.get_hand().get_card_buttons():
		cards.append(b.get_node("Card"))
	for cv: BannerCard in cards:
		var lay: Dictionary = cv.layout_report()
		assert_true(int(lay["numeral_px"]) >= MIN_NUMBER_PX and lay["numeral_px"] * k >= MIN_NUMBER_PT - 0.01,
				"%s card %s values %d px = %.1f pt" % [label, cv.card_id, lay["numeral_px"], lay["numeral_px"] * k])
		assert_true(cv.size.is_equal_approx(brick), "%s card %s is %s, brick %s" % [label, cv.card_id, cv.size, brick])
		assert_eq(cv.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s card %s leaves input to its button" % [label, cv.card_id])
		min_number = minf(min_number, lay["numeral_px"] * k)

	# Hand: every card inside the hand, same size as a brick, 5 cards in at most 2 rows.
	var hand_rect: Rect2 = duel.get_hand().get_global_rect().grow(EPS)
	var rows: Dictionary = {}
	for b: Node in duel.get_hand().get_card_buttons():
		var r: Rect2 = (b as Control).get_global_rect()
		assert_true(hand_rect.encloses(r), "%s hand card %s spills out of the hand %s" % [label, r, hand_rect])
		assert_true(r.size.is_equal_approx(brick), "%s hand card %s is brick-sized %s" % [label, r.size, brick])
		rows[roundi(r.position.y)] = true
	assert_true(rows.size() <= 2, "%s hand uses %d rows" % [label, rows.size()])
	print("     [%s] canvas %s, %.3f pt/px, brick %s: smallest text %.1f pt, smallest number %.1f pt, smallest tap %.1f pt" % [
			label, viewport.size, k, brick, min_body, min_number, min_tap * k])
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
	return ""


func _scene_files() -> PackedStringArray:
	var out: PackedStringArray = [DUEL_SCENE]
	for f: String in DirAccess.get_files_at("res://scenes/duel"):
		if f.ends_with(".tscn"):
			out.append("res://scenes/duel".path_join(f))
	return out
