# test_duel_flow.gd
# Purpose: cc08 duel flow on the real rules (scripts/duel/duel_controller.gd behind scenes/Duel.tscn):
#   - full duels to the end screen against every rival, by scripted taps on the real buttons,
#   - one full duel with MOUSE events only and one with TOUCH events only (Input.parse_input_event,
#     touch reaches the GUI through the project's emulate_mouse_from_touch),
#   - capture preview: arrows exactly on the cards WallRules.place() then flips,
#   - illegal moves rejected in words (no card, occupied slot, not your turn, bad Cipher pick),
#   - Cipher pick, Signature choice, coin flip shown, MENU -> leave / keep playing,
#   - EventBus replay order (placed before its captures, one duel_ended), end screen contents.
# Delays are 0 so a duel resolves within a few frames.
# Author: UI/UX Agent (cc08)
extends "res://tests/test_case.gd"

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")
const DuelSetup: GDScript = preload("res://scripts/duel/duel_setup.gd")
const DUEL_SCENE: String = "res://scenes/Duel.tscn"
const PHONE: Dictionary = {"name": "iPhone 844x390 @3x + notch", "pt": Vector2(844, 390), "ratio": 3.0, "insets": Rect2(47, 0, 47, 21)}
const EPS: float = 0.5

var _saved_root_size: Vector2i
var _events: Array = []


# --- Full duels ---------------------------------------------------------------------

func test_full_duel_vs_each_rival_by_taps() -> void:
	var rivals: Array[Dictionary] = DuelSetup.rivals()
	assert_eq(rivals.size(), 3, "three rivals from data/rivals")
	for r: Dictionary in rivals:
		var setup: Array = await _spawn_phone(1234, r["id"])
		var duel: Control = setup[1]
		var ctrl: Node = duel.get_node("%DuelController")
		assert_eq(ctrl.rival["id"], r["id"], "%s preselected" % r["name"])
		assert_true(ctrl.rival["data"] != null, "%s lineup comes from CardDB" % r["name"])
		_listen()
		await _play(duel, &"press")
		_unlisten()
		_assert_finished(duel, ctrl, r["name"])
		_despawn(setup[0])


func test_full_duel_mouse_only() -> void:
	await _full_duel_with_input(&"mouse")


func test_full_duel_touch_only() -> void:
	await _full_duel_with_input(&"touch")


func _full_duel_with_input(mode: StringName) -> void:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var duel: Control = _instance(777, &"")
	tree.root.add_child(duel)
	for i: int in 4:
		await tree.process_frame
	var ctrl: Node = duel.get_node("%DuelController")
	_listen()
	await _play(duel, mode)
	_unlisten()
	_assert_finished(duel, ctrl, "%s only" % mode)
	duel.queue_free()
	await tree.process_frame
	tree.root.size = _saved_root_size


func _assert_finished(duel: Control, ctrl: Node, label: String) -> void:
	assert_eq(ctrl.phase, &"over", "%s duel reaches the end" % label)
	assert_true(ctrl.state.is_game_over(), "%s wall full" % label)
	var overlay: Control = duel.get_overlay()
	assert_eq(overlay.kind(), &"end", "%s end screen open" % label)
	var res: Dictionary = WallRules.final_result(ctrl.state)
	var s: Array = res["score"]
	var score_label: Label = overlay.get_content().get_node("EndScore")
	assert_eq(score_label.text, "%d  –  %d" % [s[0], s[1]], "%s end score" % label)
	var title: String = (overlay.get_node("%OverlayTitle") as Label).text
	var expect: String = "DRAW" if res["winner"] == WallState.NO_PLAYER else ("YOU WIN" if res["winner"] == WallState.P1 else "WINS")
	assert_true(title.ends_with(expect), "%s title '%s' matches result" % [label, title])
	assert_true((overlay.get_content().get_node("EndTriptychs") as Label).text.begins_with("Triptychs:"), "%s Triptych line" % label)
	assert_true((overlay.get_content().get_node("EndRewards") as Label).text.contains("cosmetic"), "%s rewards line" % label)
	var placed: Array = _events.filter(func(e: Array) -> bool: return e[0] == &"placed")
	assert_eq(placed.size(), 10, "%s 10 card_placed events" % label)
	assert_eq(_events.filter(func(e: Array) -> bool: return e[0] == &"ended").size(), 1, "%s one duel_ended" % label)
	assert_eq(_events.filter(func(e: Array) -> bool: return e[0] == &"started").size(), 1, "%s one duel_started" % label)
	# The screen ends on the engine's truth.
	var wall: Dictionary = duel.get_state()["wall"]
	for slot: StringName in ctrl.state.cells:
		assert_eq(wall[slot]["owner"], &"player" if ctrl.state.controller_of(slot) == WallState.P1 else &"rival", "%s %s owner synced" % [label, slot])
	for side: int in 2:
		var b: Button = overlay.get_button(&"again")
		assert_true(b != null and minf(b.size.x, b.size.y) >= 64.0 - EPS, "%s PLAY AGAIN is a 64 px target" % label)


# --- Preview ------------------------------------------------------------------------

func test_preview_arrows_match_the_placement() -> void:
	var setup: Array = await _spawn_phone(42, &"archivist")
	var duel: Control = setup[1]
	var ctrl: Node = duel.get_node("%DuelController")
	await _start(duel)
	var checked: int = 0
	var guard: int = 0
	while ctrl.phase != &"over" and guard < 20:
		guard += 1
		if ctrl.phase != &"player":
			await tree.process_frame
			continue
		# Find a move that captures, else play the first legal one.
		var best: Dictionary = {}
		for m: Dictionary in WallRules.legal_moves(ctrl.state):
			var pr: PlacementResult = WallRules.preview(ctrl.state, WallState.P1, m["card"], m["slot"], m["copy_from"])
			if not pr.all_flipped().is_empty():
				best = m
				break
		var mv: Dictionary = best if not best.is_empty() else WallRules.legal_moves(ctrl.state)[0]
		_tap_hand(duel, (mv["card"] as CardData).id, &"press")
		assert_true((duel.get_node("%PlaceButton") as Button).disabled, "PLACE disabled before a slot is chosen")
		_tap(duel.get_wall().get_slot(mv["slot"]), &"press")
		if mv["copy_from"] != &"":
			_tap(duel.get_wall().get_slot(mv["copy_from"]), &"press")
		await tree.process_frame
		var expected: PlacementResult = WallRules.preview(ctrl.state, WallState.P1, mv["card"], mv["slot"], mv["copy_from"])
		var shown: Array = duel.get_preview().keys()
		shown.sort()
		var want: Array = expected.all_flipped()
		want.sort()
		assert_eq(shown, want, "preview arrows on exactly the cards that would flip")
		for s: Node in duel.get_wall().get_slots():
			if not s.is_empty() and s.slot_id != mv["slot"]:
				assert_eq(s.get_card().preview_flip, want.has(s.slot_id), "%s arrow shown = would flip" % s.slot_id)
				if want.has(s.slot_id):
					var d: Vector2 = s.get_card().preview_dir
					var exp_dir: Vector2 = (duel.slot_center(s.slot_id) - duel.slot_center(mv["slot"])).normalized()
					assert_true(d.distance_to(exp_dir) < 0.01, "%s arrow points away from the placed card" % s.slot_id)
		assert_true(duel.get_wall().get_slot(mv["slot"]).get_card().highlighted, "pending card highlighted")
		assert_false((duel.get_node("%PlaceButton") as Button).disabled, "PLACE enabled after the preview")
		var before: Dictionary = ctrl.state.controllers()
		_tap(duel.get_node("%PlaceButton"), &"press")
		await tree.process_frame
		if not want.is_empty():
			checked += 1
			for slot: StringName in want:
				assert_true(before.get(slot, -1) != WallState.P1 or ctrl.state.controller_of(slot) == WallState.P1,
						"%s flipped as previewed" % slot)
		for s: Node in duel.get_wall().get_slots():
			if not s.is_empty():
				assert_false(s.get_card().preview_flip, "arrows cleared after PLACE")
	assert_true(checked >= 1, "at least one capturing preview was checked (%d)" % checked)
	_despawn(setup[0])


# --- Illegal moves and prompts ----------------------------------------------------------

func test_illegal_moves_are_rejected_in_words() -> void:
	var setup: Array = await _spawn_phone(_seed_where(WallState.P1), &"quartermaster")
	var duel: Control = setup[1]
	var ctrl: Node = duel.get_node("%DuelController")
	ctrl.rival_delay = 30.0  # keep the rival's turn open
	await _start(duel)
	assert_eq(ctrl.phase, &"player", "player moves first with this seed")
	# Empty slot with no card picked.
	_tap(duel.get_wall().get_slot(&"b2"), &"press")
	assert_eq(duel.get_toast_text(), "Pick a card from your hand first.", "no card picked")
	assert_true(ctrl.state.is_empty(&"b2"), "nothing placed")
	# Place a card, then try to act during the rival's turn.
	var first: StringName = (ctrl.state.hands[0][0] as CardData).id
	_tap_hand(duel, first, &"press")
	_tap(duel.get_wall().get_slot(&"b2"), &"press")
	_tap(duel.get_node("%PlaceButton"), &"press")
	await tree.process_frame
	assert_eq(ctrl.phase, &"rival", "rival's turn")
	assert_false(ctrl.state.is_empty(&"b2"), "card placed")
	var second: StringName = (ctrl.state.hands[0][0] as CardData).id
	_tap_hand(duel, second, &"press")
	assert_true(duel.get_toast_text().contains("is playing"), "picking on the rival's turn is refused: %s" % duel.get_toast_text())
	assert_eq(duel.get_picked(), &"", "pick dropped")
	var hint: Label = duel.get_hand().get_node("%HandHint")
	var need: float = hint.get_theme_font(&"font").get_string_size(hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hint.get_theme_font_size(&"font_size")).x
	assert_true(need <= hint.size.x + 0.5, "longest status fits the phone hand header (%.0f / %.0f px)" % [need, hint.size.x])
	assert_eq(WallRules.check_place(ctrl.state, WallState.P1, ctrl.state.hands[0][0], &"a1"), WallRules.ERR_NOT_YOUR_TURN, "engine agrees")
	# Occupied slot through the controller (the screen would inspect it instead).
	ctrl._set_phase(&"player")
	ctrl.state.to_move = WallState.P1
	_tap_hand(duel, second, &"press")
	ctrl._on_slot_chosen(&"b2")
	assert_eq(duel.get_toast_text(), DuelControllerScript.error_text(WallRules.ERR_SLOT_OCCUPIED), "occupied slot refused")
	# A tap on an occupied brick inspects it.
	_tap(duel.get_wall().get_slot(&"b2"), &"press")
	assert_true(duel.get_inspector().is_open(), "tap on a placed card inspects it")
	duel.get_inspector().close()
	# Every error code has words.
	for code: StringName in [WallRules.ERR_GAME_OVER, WallRules.ERR_NOT_YOUR_TURN, WallRules.ERR_INVALID_SLOT,
			WallRules.ERR_SLOT_OCCUPIED, WallRules.ERR_NOT_IN_HAND, WallRules.ERR_NO_CARD,
			WallRules.ERR_CIPHER_PICK_REQUIRED, WallRules.ERR_INVALID_CIPHER_PICK]:
		assert_false(DuelControllerScript.error_text(code).contains("("), "%s has words" % code)
	_despawn(setup[0])


func test_cipher_pick_flow() -> void:
	DuelControllerScript.set_next_duel(&"quartermaster", [&"null_glyph", &"graveyard_shift", &"neon_rain", &"last_train", &"mayday"])
	var setup: Array = await _spawn_phone(_seed_where(WallState.P2), &"quartermaster")
	DuelControllerScript.set_next_duel(&"", [])
	var duel: Control = setup[1]
	var ctrl: Node = duel.get_node("%DuelController")
	assert_eq((ctrl.player_lineup[0] as CardData).id, &"null_glyph", "requested lineup used")
	await _start(duel)
	assert_eq(ctrl.phase, &"player", "rival moved first, now the player")
	var occupied: StringName = ctrl.state.cells.keys()[0]
	var target_slot: StringName = &""
	for s: StringName in ctrl.state.empty_slots():
		if WallRules.cipher_picks(ctrl.state, s).has(occupied):
			target_slot = s
			break
	assert_true(target_slot != &"", "an empty neighbour exists")
	_tap_hand(duel, &"null_glyph", &"press")
	_tap(duel.get_wall().get_slot(target_slot), &"press")
	assert_true(duel.pick_targets.has(occupied), "the neighbour is offered as a Cipher pick")
	assert_true(duel.get_wall().get_slot(occupied).get_card().highlighted, "pick target highlighted")
	assert_true((duel.get_node("%PlaceButton") as Button).disabled, "PLACE waits for the Cipher pick")
	assert_true(duel.get_toast_text().begins_with("Cipher"), "Cipher prompt shown")
	# A non-neighbour pick is refused by the engine.
	var far: StringName = &""
	for s: StringName in ctrl.state.topology.slots:
		if s != target_slot and not WallRules.cipher_picks(ctrl.state, target_slot).has(s):
			far = s
			break
	assert_eq(WallRules.check_place(ctrl.state, WallState.P1, ctrl._card, target_slot, far), WallRules.ERR_INVALID_CIPHER_PICK, "far pick illegal")
	_tap(duel.get_wall().get_slot(occupied), &"press")
	assert_eq(ctrl._copy_from, occupied, "pick recorded")
	assert_false((duel.get_node("%PlaceButton") as Button).disabled, "PLACE enabled after the pick")
	_tap(duel.get_node("%PlaceButton"), &"press")
	await tree.process_frame
	var pc: PlacedCard = ctrl.state.get_card(target_slot)
	assert_not_null(pc, "Cipher placed")
	if pc != null:
		assert_eq(pc.active_trait, WallRules.copied_trait(ctrl.state, occupied), "copied trait applied")
	_despawn(setup[0])


func test_signature_choice_and_coin_flip() -> void:
	var seed_value: int = _seed_where(WallState.P2)
	var setup: Array = await _spawn_phone(seed_value, &"warden")
	var duel: Control = setup[1]
	var ctrl: Node = duel.get_node("%DuelController")
	var overlay: Control = duel.get_overlay()
	assert_eq(overlay.kind(), &"setup", "setup panel first")
	var flow: Node = overlay.get_content().get_node("LineupCards")
	assert_eq(flow.get_child_count(), 5, "5 lineup cards to choose the Signature from")
	var pick: Button = flow.get_child(1)
	_tap(pick, &"press")
	assert_eq(ctrl.player_signature, ctrl.player_lineup[1], "tapped card is the Signature")
	await tree.process_frame
	assert_true((overlay.get_content().get_node("LineupCards").get_child(1).get_node("Card") as BannerCard).signature, "ribbon moves")
	# Rival buttons switch the rival.
	var row_found: bool = false
	for n: Node in overlay.get_content().find_children("Rival_archivist", "Button", true, false):
		_tap(n, &"press")
		row_found = true
	assert_true(row_found, "rival buttons shown")
	assert_eq(ctrl.rival["id"], &"archivist", "rival switched")
	_tap(overlay.get_button(&"start"), &"press")
	assert_eq(overlay.kind(), &"coin", "coin flip shown")
	assert_true((overlay.get_node("%OverlayTitle") as Label).text.ends_with("TAILS"), "this seed: rival first")
	assert_eq(ctrl.state.signature_cards[0], ctrl.player_lineup[1], "Signature in the match")
	assert_eq(ctrl.state.first_player, WallState.coin_flip(seed_value), "coin flip from the seed")
	_tap(overlay.get_button(&"begin"), &"press")
	await tree.process_frame
	assert_eq(overlay.kind(), &"", "overlay closed")
	assert_eq(ctrl.phase, &"player", "rival moved, player's turn")
	assert_eq(ctrl.state.cells.size(), 1, "one rival card on the wall")
	_despawn(setup[0])


func test_menu_offers_leave_or_keep_playing() -> void:
	var setup: Array = await _spawn_phone(5, &"quartermaster")
	var duel: Control = setup[1]
	var ctrl: Node = duel.get_node("%DuelController")
	await _start(duel)
	_tap(duel.get_node("%MenuButton"), &"press")
	assert_eq(duel.get_overlay().kind(), &"leave", "leave prompt")
	_tap(duel.get_overlay().get_button(&"stay"), &"press")
	assert_eq(duel.get_overlay().kind(), &"", "back to the duel")
	assert_eq(ctrl.phase, &"player", "player's turn resumes")
	var router: Node = tree.root.get_node("SceneRouter")
	router.dry_run = true
	_tap(duel.get_node("%MenuButton"), &"press")
	_tap(duel.get_overlay().get_button(&"leave"), &"press")
	assert_eq(router.last_requested, router.SCENE_TITLE, "leave goes to the title")
	router.dry_run = false
	_despawn(setup[0])


func test_end_screen_fits_the_phone() -> void:
	var setup: Array = await _spawn_phone(99, &"archivist")
	var duel: Control = setup[1]
	await _play(duel, &"press")
	await tree.process_frame
	var vp: SubViewport = setup[0]
	var k: float = ScreenProfile.points_per_px(PHONE["pt"] * PHONE["ratio"], PHONE["ratio"])
	var panel: Rect2 = duel.get_overlay().get_panel().get_global_rect()
	var safe: Rect2 = duel.safe_area_override.grow(EPS)
	assert_true(safe.encloses(panel), "end panel %s inside the safe area %s" % [panel, safe])
	for n: Node in duel.get_overlay().find_children("*", "Control", true, false):
		if (n is Label or n is Button) and (n as Control).is_visible_in_tree() and String(n.text) != "":
			assert_true((n as Control).get_theme_font_size(&"font_size") * k >= 11.0 - 0.01, "end text '%s' >= 11 pt" % n.text)
		if n is Button and (n as Control).is_visible_in_tree():
			assert_true(minf((n as Control).size.x, (n as Control).size.y) >= 64.0 - EPS, "end button %s >= 64 px" % n.name)
	_despawn(vp)


# --- Driving ------------------------------------------------------------------------------

## Plays the whole duel from the setup panel to the end screen with taps of `mode`.
func _play(duel: Control, mode: StringName) -> void:
	var ctrl: Node = duel.get_node("%DuelController")
	await _start(duel, mode)
	var guard: int = 0
	while ctrl.phase != &"over" and guard < 60:
		guard += 1
		if ctrl.phase == &"player":
			var hand: Array = ctrl.state.hands[0]
			var card: CardData = hand[0]
			_tap_hand(duel, card.id, mode)
			await _flush(mode)
			var slot: StringName = &""
			for s: Node in duel.get_wall().get_slots():
				if s.target_state == &"valid":
					slot = s.slot_id
					break
			_tap(duel.get_wall().get_slot(slot), mode)
			await _flush(mode)
			if not duel.pick_targets.is_empty():
				_tap(duel.get_wall().get_slot(duel.pick_targets[0]), mode)
				await _flush(mode)
			_tap(duel.get_node("%PlaceButton"), mode)
			await _flush(mode)
		await tree.process_frame
	assert_true(guard < 60, "duel finished within the guard")


func _start(duel: Control, mode: StringName = &"press") -> void:
	var overlay: Control = duel.get_overlay()
	if overlay.kind() != &"setup":
		await tree.process_frame
	_tap(overlay.get_button(&"start"), mode)
	await _flush(mode)
	_tap(overlay.get_button(&"begin"), mode)
	await _flush(mode)
	await tree.process_frame


func _tap_hand(duel: Control, card_id: StringName, mode: StringName) -> void:
	for b: Node in duel.get_hand().get_card_buttons():
		if b.get_meta(&"card_id") == card_id:
			_tap(b, mode)
			return
	failures.append("hand has no %s" % card_id)


## press: the button's own signal (what a tap or click ends in); mouse / touch: real input events.
func _tap(c: Control, mode: StringName) -> void:
	if c == null:
		failures.append("tap on a missing control")
		return
	if mode == &"press":
		(c as BaseButton).pressed.emit()
		return
	var pos: Vector2 = c.get_global_rect().get_center()
	if mode == &"mouse":
		for pressed: bool in [true, false]:
			var e: InputEventMouseButton = InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = pressed
			e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
			e.position = pos
			e.global_position = pos
			Input.parse_input_event(e)
			Input.flush_buffered_events()
	else:
		for pressed: bool in [true, false]:
			var t: InputEventScreenTouch = InputEventScreenTouch.new()
			t.index = 0
			t.pressed = pressed
			t.position = pos
			Input.parse_input_event(t)
			Input.flush_buffered_events()


func _flush(mode: StringName) -> void:
	if mode != &"press":
		await tree.process_frame


func _listen() -> void:
	_events.clear()
	EventBus.card_placed.connect(_on_placed)
	EventBus.duel_ended.connect(_on_ended)
	EventBus.duel_started.connect(_on_started)


func _unlisten() -> void:
	EventBus.card_placed.disconnect(_on_placed)
	EventBus.duel_ended.disconnect(_on_ended)
	EventBus.duel_started.disconnect(_on_started)


func _on_placed(side: StringName, card_id: StringName, slot: StringName, _c: Array) -> void:
	_events.append([&"placed", side, card_id, slot])


func _on_ended(result: StringName, _p: int, _r: int, _t: int, _d: float) -> void:
	_events.append([&"ended", result])


func _on_started(_s: StringName, _r: StringName, _f: StringName) -> void:
	_events.append([&"started"])


## A seed whose coin flip gives `first`.
func _seed_where(first: int) -> int:
	for s: int in range(1, 200):
		if WallState.coin_flip(s) == first:
			return s
	return 1


func _instance(seed_value: int, rival_id: StringName) -> Control:
	DuelControllerScript.set_next_duel(rival_id, DuelControllerScript.next_player_lineup)
	var duel: Control = (load(DUEL_SCENE) as PackedScene).instantiate()
	var ctrl: Node = duel.get_node("%DuelController")
	ctrl.seed_value = seed_value
	ctrl.event_delay = 0.0
	ctrl.rival_delay = 0.0
	return duel


func _spawn_phone(seed_value: int, rival_id: StringName) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var px: Vector2 = PHONE["pt"] * PHONE["ratio"]
	var logical: Vector2 = ScreenProfile.logical_size(px, ScreenProfile.base_size(px, PHONE["ratio"]))
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(logical)
	viewport.disable_3d = true
	tree.root.add_child(viewport)
	var duel: Control = _instance(seed_value, rival_id)
	var k: float = ScreenProfile.points_per_px(px, PHONE["ratio"])
	var insets: Rect2 = PHONE["insets"]
	duel.safe_area_override = Rect2(insets.position / k, logical - insets.position / k - insets.size / k)
	viewport.add_child(duel)
	for i: int in 4:
		await tree.process_frame
	DuelControllerScript.set_next_duel(&"", [])
	return [viewport, duel]


func _despawn(viewport: SubViewport) -> void:
	viewport.queue_free()
	tree.root.size = _saved_root_size
