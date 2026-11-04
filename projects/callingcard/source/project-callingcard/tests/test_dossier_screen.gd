# test_dossier_screen.gd
# Purpose: cc12 Dossier screen (scenes/Dossier.tscn = the duel screen + DossierController) at the
#   iPhone 844x390 size, driven by taps on the real buttons:
#   - every Dossier's solution by taps (Cipher pick by tapping the copied card), result panel
#     "DOSSIER CLEARED", reward paid once into a test Collection even after RETRY and a second clear,
#   - a wrong line ends on "NOT YET", RETRY resets the wall and hand to the start board,
#   - reserved reply slots (D3 a2, D4 c1) show RESERVED and refuse a drop in words,
#   - HINT: first tap shows the text hint, second tap picks the first solution card and lights its slot,
#   - briefing shows the goal; the goal line stays under the hand during play.
# Delays are 0 so a Dossier resolves in a few frames. The Collection autoload is muted (fixtures).
# Author: Mechanics Developer Agent (cc12)
extends "res://tests/test_case.gd"

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const Fixtures: GDScript = preload("res://tests/test_collection_fixtures.gd")
const DossierControllerScript: GDScript = preload("res://scripts/dossier/dossier_controller.gd")
const SCENE: String = "res://scenes/Dossier.tscn"
const PHONE: Dictionary = {"pt": Vector2(844, 390), "ratio": 3.0, "insets": Rect2(47, 0, 47, 21)}

var _saved_root_size: Vector2i
var _fx: RefCounted = null
var _col: Node = null


func _spawn(dossier_id: StringName, save_name: String) -> Array:
	_fx = Fixtures.new(tree)
	_col = _fx.make(save_name)
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var px: Vector2 = PHONE["pt"] * PHONE["ratio"]
	var logical: Vector2 = ScreenProfile.logical_size(px, ScreenProfile.base_size(px, PHONE["ratio"]))
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(logical)
	viewport.disable_3d = true
	tree.root.add_child(viewport)
	DossierControllerScript.set_next_dossier(dossier_id)
	var screen: Control = (load(SCENE) as PackedScene).instantiate()
	var ctrl: Node = screen.get_node("%DuelController")
	ctrl.event_delay = 0.0
	ctrl.rival_delay = 0.0
	ctrl.collection = _col
	var k: float = ScreenProfile.points_per_px(px, PHONE["ratio"])
	var insets: Rect2 = PHONE["insets"]
	screen.safe_area_override = Rect2(insets.position / k, logical - insets.position / k - insets.size / k)
	viewport.add_child(screen)
	for i: int in 4:
		await tree.process_frame
	DossierControllerScript.set_next_dossier(&"")
	return [viewport, screen, ctrl]


func _despawn(setup: Array) -> void:
	(setup[0] as Node).queue_free()
	await tree.process_frame
	tree.root.size = _saved_root_size
	_fx.finish()
	_fx = null
	_col = null


func _press(b: BaseButton, what: String) -> void:
	if b == null:
		failures.append("missing button: %s" % what)
		return
	assert_false(b.disabled, "%s enabled" % what)
	b.pressed.emit()


func _overlay_button(screen: Control, id: StringName) -> void:
	_press(screen.get_overlay().get_button(id), "overlay %s" % id)


func _tap_hand(screen: Control, card_id: StringName) -> void:
	for b: Node in screen.get_hand().get_card_buttons():
		if b.get_meta(&"card_id") == card_id:
			(b as BaseButton).pressed.emit()
			return
	failures.append("hand has no %s" % card_id)


func _tap_slot(screen: Control, slot: StringName) -> void:
	var s: Node = screen.get_wall().get_slot(slot)
	if s == null:
		failures.append("no slot %s" % slot)
		return
	(s as BaseButton).pressed.emit()


## One placement by taps: card, slot, [copied card], PLACE; waits for the reply to resolve.
func _place(screen: Control, ctrl: Node, card_id: StringName, slot: StringName, copy_from: StringName = &"") -> void:
	_tap_hand(screen, card_id)
	await tree.process_frame
	_tap_slot(screen, slot)
	await tree.process_frame
	if copy_from != &"":
		assert_true(screen.pick_targets.has(copy_from), "Cipher pick offers %s" % copy_from)
		_tap_slot(screen, copy_from)
		await tree.process_frame
	_press(screen.get_key_controls()["PlaceButton"], "PLACE (%s -> %s)" % [card_id, slot])
	for i: int in 6:
		await tree.process_frame


func _play_solution(screen: Control, ctrl: Node) -> void:
	for step: DossierPlacement in ctrl.dossier.solution:
		await _place(screen, ctrl, step.card.id, step.slot, step.copy_from)


# --- Tests -------------------------------------------------------------------------------------

func test_each_dossier_solved_by_taps_pays_once() -> void:
	for id: StringName in [&"dossier_first_contact", &"dossier_same_page", &"dossier_lights_out",
			&"dossier_carded", &"dossier_clean_copy"]:
		var setup: Array = await _spawn(id, "dossier_screen_%s" % id)
		var screen: Control = setup[1]
		var ctrl: Node = setup[2]
		var overlay: Control = screen.get_overlay()
		assert_eq(overlay.kind(), &"briefing", "%s opens on its briefing" % id)
		var goal: Label = overlay.get_content().get_node_or_null("BriefingGoal")
		assert_true(goal != null and goal.text.contains(DossierPuzzle.goal_text(ctrl.dossier)), "%s briefing shows the goal" % id)
		_overlay_button(screen, &"start")
		await tree.process_frame
		assert_eq(ctrl.phase, &"player", "%s play starts" % id)
		var gl: Label = screen.get_goal_label()
		assert_true(gl != null and gl.visible and gl.text.contains(DossierPuzzle.goal_text(ctrl.dossier)), "%s goal shown during play" % id)
		await _play_solution(screen, ctrl)
		assert_eq(ctrl.phase, &"result", "%s reaches the result" % id)
		assert_true(ctrl.last_result.get("success", false), "%s cleared by taps (%s)" % [id, ctrl.last_result.get("reason", "")])
		assert_eq(overlay.kind(), &"dossier_result", "%s result panel open" % id)
		assert_eq((overlay.get_node("%OverlayTitle") as Label).text, "DOSSIER CLEARED", "%s result title" % id)
		assert_true((overlay.get_content().get_node("ResultReward") as Label).text.begins_with("Reward: "), "%s reward named" % id)
		assert_eq(ctrl.paid_via, DossierRewards.VIA_COLLECTION, "%s paid through Collection.complete_dossier" % id)
		assert_true(_col.is_dossier_cleared(id), "%s recorded in Collection" % id)
		var grants: int = _grant_count()
		# RETRY and clear again: nothing more is paid.
		_overlay_button(screen, &"retry")
		await tree.process_frame
		assert_eq(ctrl.phase, &"player", "%s retry from the result" % id)
		await _play_solution(screen, ctrl)
		assert_true(ctrl.last_result.get("success", false), "%s cleared again" % id)
		assert_eq(_grant_count(), grants, "%s second clear grants nothing" % id)
		assert_eq((overlay.get_content().get_node("ResultReward") as Label).text, "Cleared before: no new reward.",
				"%s second clear says so" % id)
		await _despawn(setup)


func _grant_count() -> int:
	return _fx.events_named("card_unlocked").size() + _fx.events_named("title_earned").size() \
			+ _fx.events_named("frame_earned").size()


func test_wrong_line_then_retry_resets_the_board() -> void:
	var setup: Array = await _spawn(&"dossier_first_contact", "dossier_screen_wrong")
	var screen: Control = setup[1]
	var ctrl: Node = setup[2]
	_overlay_button(screen, &"start")
	await tree.process_frame
	var start_wall: Dictionary = screen.get_state()["wall"].duplicate(true)
	var start_hand: Array = screen.get_state()["player"]["hand"].duplicate()
	assert_true(ctrl.get_retry_button().disabled, "RETRY off before any placement")
	await _place(screen, ctrl, &"frostbite", &"b2")
	assert_false(ctrl.get_retry_button().disabled, "RETRY on mid-puzzle")
	_press(ctrl.get_retry_button(), "RETRY mid-puzzle")
	await tree.process_frame
	assert_eq(screen.get_state()["wall"], start_wall, "mid-puzzle RETRY restores the wall")
	await _place(screen, ctrl, &"frostbite", &"b2")
	await _place(screen, ctrl, &"glacier", &"b4")
	assert_eq(ctrl.phase, &"result", "wrong line ends")
	assert_false(ctrl.last_result["success"], "wrong line fails")
	assert_eq((screen.get_overlay().get_node("%OverlayTitle") as Label).text, "NOT YET", "result says NOT YET")
	assert_eq(ctrl.paid_via, &"", "nothing paid on a fail")
	assert_false(_col.is_dossier_cleared(&"dossier_first_contact"), "not recorded")
	_overlay_button(screen, &"retry")
	await tree.process_frame
	assert_eq(screen.get_state()["wall"], start_wall, "RETRY restores the start wall")
	assert_eq(screen.get_state()["player"]["hand"], start_hand, "RETRY restores the hand")
	assert_eq(ctrl.puzzle.state.to_dict(), DossierPuzzle.new(ctrl.dossier).state.to_dict(), "engine state is the start board")
	assert_eq(ctrl.attempts, 3, "START + two RETRYs = 3 attempts")
	await _despawn(setup)


func test_reserved_slots_shown_and_refused() -> void:
	for spec: Array in [[&"dossier_lights_out", &"a2", &"flare_up"], [&"dossier_carded", &"c1", &"honor_roll"]]:
		var setup: Array = await _spawn(spec[0], "dossier_screen_reserved")
		var screen: Control = setup[1]
		var ctrl: Node = setup[2]
		_overlay_button(screen, &"start")
		await tree.process_frame
		var slot: Node = screen.get_wall().get_slot(spec[1])
		var label: Label = slot.get_node("%SlotIdLabel")
		assert_true(label.text.contains("RESERVED"), "%s %s shows RESERVED (%s)" % [spec[0], spec[1], label.text])
		_tap_hand(screen, spec[2])
		await tree.process_frame
		var glow: Array = []
		for s: Node in screen.get_wall().get_slots():
			if s.target_state == &"valid":
				glow.append(s.slot_id)
		assert_false(glow.has(spec[1]), "%s %s not lit as a drop" % [spec[0], spec[1]])
		_tap_slot(screen, spec[1])
		await tree.process_frame
		assert_true(screen.get_toast_text().begins_with("Reserved"), "%s tap on %s explained: %s" % [spec[0], spec[1], screen.get_toast_text()])
		assert_eq(screen.get_pending(), &"", "%s nothing pending in %s" % [spec[0], spec[1]])
		# First solution step -> the reply fills the slot and RESERVED goes away.
		_tap_hand(screen, spec[2])  # unpick
		await tree.process_frame
		var s0: DossierPlacement = ctrl.dossier.solution[0]
		await _place(screen, ctrl, s0.card.id, s0.slot, s0.copy_from)
		assert_eq(ctrl.puzzle.replies_made, 1, "%s reply played" % spec[0])
		assert_true(screen.get_state()["wall"].has(spec[1]), "%s reply card is on the wall at %s" % [spec[0], spec[1]])
		assert_false(label.text.contains("RESERVED"), "%s %s no longer reserved" % [spec[0], spec[1]])
		await _despawn(setup)


func test_hint_text_then_first_move() -> void:
	var setup: Array = await _spawn(&"dossier_clean_copy", "dossier_screen_hint")
	var screen: Control = setup[1]
	var ctrl: Node = setup[2]
	_overlay_button(screen, &"start")
	await tree.process_frame
	_press(ctrl.get_hint_button(), "HINT")
	await tree.process_frame
	assert_true(screen.get_toast_text().contains(ctrl.dossier.hint), "first HINT shows the text hint")
	assert_eq(screen.get_picked(), &"", "first HINT picks nothing")
	_press(ctrl.get_hint_button(), "HINT 2")
	await tree.process_frame
	assert_eq(screen.get_picked(), &"null_glyph", "second HINT picks the first solution card")
	var lit: Array = []
	for s: Node in screen.get_wall().get_slots():
		if s.target_state == &"valid":
			lit.append(s.slot_id)
	assert_eq(lit, [&"c1"], "second HINT lights only the first solution slot")
	assert_true(screen.get_toast_text().contains("C2"), "move hint names the Cipher pick")
	# Following the hint clears the Dossier.
	_tap_slot(screen, &"c1")
	await tree.process_frame
	_tap_slot(screen, &"c2")
	await tree.process_frame
	_press(screen.get_key_controls()["PlaceButton"], "PLACE")
	for i: int in 4:
		await tree.process_frame
	await _place(screen, ctrl, &"gold_leaf", &"a2")
	assert_true(ctrl.last_result.get("success", false), "hinted line clears D5")
	await _despawn(setup)


func test_list_opens_without_a_preset_dossier() -> void:
	var setup: Array = await _spawn(&"", "dossier_screen_list")
	var screen: Control = setup[1]
	var ctrl: Node = setup[2]
	var overlay: Control = screen.get_overlay()
	assert_eq(overlay.kind(), &"dossier_list", "the list opens")
	assert_eq(ctrl.dossiers.size(), 5, "five Dossiers listed")
	var b: Button = overlay.get_content().get_node_or_null("Dossier_dossier_carded")
	_press(b, "D4 in the list")
	await tree.process_frame
	assert_eq(overlay.kind(), &"briefing", "D4 briefing")
	assert_eq(ctrl.dossier.id, &"dossier_carded", "D4 chosen")
	await _despawn(setup)
