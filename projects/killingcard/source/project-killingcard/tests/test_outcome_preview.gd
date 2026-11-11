# test_outcome_preview.gd
# Purpose: p12 outcome preview overlay in the live match screen (scenes/Match.tscn), at desktop
#   1280x720 and iPhone 844x390 @3x: the PREVIEW button / P key toggle it and emit
#   EventBus.preview_toggled; the cards show exactly OutcomeForecast's numbers, follow plays and
#   UNDO live, hide while the round plays and come back for the next Deploy; taps pass through
#   the cards to the lanes; text >= 11 pt, the toggle >= 44 pt, nothing clipped or off screen.
# Author: UI/UX Agent (p12)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const OutcomePreviewScript: GDScript = preload("res://scripts/ui/outcome_preview.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"

var _saved_root_size: Vector2i = Vector2i.ZERO
var _toggles: Array[bool] = []


func test_toggle_and_readability_desktop() -> void:
	await _toggle_and_readability(Layout.DESKTOP)


func test_toggle_and_readability_phone() -> void:
	await _toggle_and_readability(Layout.PHONE)


func test_live_updates_and_round_flow_phone() -> void:
	await _live_updates(Layout.PHONE)


func test_live_updates_and_round_flow_desktop() -> void:
	await _live_updates(Layout.DESKTOP)


func test_card_lines_wording() -> void:
	var lines: PackedStringArray = OutcomePreviewScript.card_lines({"dealt": 5, "taken": 3, "kills": 2, "losses": 1,
			"fight": true, "control": &"player", "unknown": 2})
	assert_eq(lines, PackedStringArray(["DEAL 5 · TAKE 3", "ENDS YOURS", "KILLS 2 · LOST 1", "+2 UNKNOWN"]), "busy zone")
	lines = OutcomePreviewScript.card_lines({"control": &"empty", "unknown": 0})
	assert_eq(lines, PackedStringArray(["NO FIREFIGHT", "ENDS OPEN", "NO LOSSES", "NO INCOMING"]), "quiet zone")
	var hud: Theme = load("res://assets/ui/hud_theme.tres")
	var font: Font = hud.get_font(&"font", &"PreviewText")
	for ch: String in ["·", "+"]:
		assert_true(font.has_char(ch.unicode_at(0)), "preview font has '%s'" % ch)


# --- scenarios --------------------------------------------------------------------------

func _toggle_and_readability(screen: Dictionary) -> void:
	var s: Array = await _spawn(screen)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var label: String = screen["name"]
	var preview: Control = m.get_preview()
	var button: Button = m.get_preview_button()
	var k: float = Layout.points_per_px(screen)
	assert_false(preview.visible, "%s preview starts off" % label)
	assert_eq(button.text.strip_edges(), "OFF", "%s strip badge says OFF (kc-board2: eye glyph over the word)" % label)
	# Tap the toggle (real input).
	await _tap(vp, button.get_global_rect().get_center())
	assert_true(preview.enabled and preview.visible, "%s tap turns the preview on" % label)
	assert_eq(button.text.strip_edges(), "ON", "%s strip badge says ON" % label)
	assert_true(button.button_pressed, "%s button shows its pressed (on) frame" % label)
	assert_eq(_toggles, [true] as Array[bool], "%s EventBus.preview_toggled(true)" % label)
	# The numbers are the engine's.
	var fc: Dictionary = OutcomeForecast.forecast(c.state)
	assert_eq(var_to_str(preview.last_forecast), var_to_str(fc), "%s shows OutcomeForecast" % label)
	var cards: Array[Control] = preview.get_cards()
	var lanes: Array[Node] = m.get_board().get_lanes()
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(vp.size)).grow(0.5)
	for z: int in 3:
		var lines: PackedStringArray = OutcomePreviewScript.card_lines(fc["zones"][z])
		var labels: Array[Label] = preview.get_important_labels().slice(z * 4, z * 4 + 4)
		assert_eq(PackedStringArray(labels.map(func(l: Label) -> String: return l.text)), lines, "%s zone %d text" % [label, z])
		var card_r: Rect2 = cards[z].get_global_rect()
		var lane_r: Rect2 = (lanes[z] as Control).get_global_rect().grow(0.5)
		assert_true(lane_r.encloses(card_r), "%s card %d inside its lane (%s in %s)" % [label, z, card_r, lane_r])
		assert_true(screen_rect.encloses(card_r), "%s card %d on screen" % [label, z])
		var friendly: Rect2 = (lanes[z].get_node("%FriendlyRow") as Control).get_global_rect()
		assert_true(card_r.end.y <= friendly.position.y + 0.5, "%s card %d leaves the deploy row free" % [label, z])
	var min_pt: float = INF
	for l: Label in preview.get_important_labels():
		var pt: float = l.get_theme_font_size(&"font_size") * k
		min_pt = minf(min_pt, pt)
		assert_true(pt >= Layout.MIN_BODY_PT - 0.01, "%s '%s' is %.1f pt" % [label, l.text, pt])
		assert_eq(_clipped(l), "", "%s '%s' fits" % [label, l.text])
	# The worst-case wording also fits (two-digit numbers, CONTESTED, unknown arrivals).
	_fill_worst_case(preview)
	await _frames(2)
	for l: Label in preview.get_important_labels():
		assert_eq(_clipped(l), "", "%s worst case '%s' fits" % [label, l.text])
	for z: int in 3:
		var need: float = cards[z].get_combined_minimum_size().x
		var room: float = (lanes[z].get_objective_tile() as Control).size.x
		assert_true(need <= room + 0.5, "%s worst-case card %d needs %.0f px, lane header has %.0f" % [label, z, need, room])
	var tap_pt: float = minf(button.size.x, button.size.y) * k
	assert_true(tap_pt >= Layout.MIN_TAP_PT - 0.01, "%s toggle is %.1f pt" % [label, tap_pt])
	print("     [%s] preview text >= %.1f pt, toggle %.1f pt" % [label, min_pt, tap_pt])
	# P key turns it off again.
	await _key(vp, KEY_P)
	assert_false(preview.enabled or preview.visible, "%s P turns it off" % label)
	assert_eq(_toggles, [true, false] as Array[bool], "%s EventBus.preview_toggled(false)" % label)
	assert_false(button.button_pressed, "%s button released" % label)
	_despawn(vp)


func _live_updates(screen: Dictionary) -> void:
	var s: Array = await _spawn(screen)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var label: String = screen["name"]
	var preview: Control = m.get_preview()
	preview.set_enabled(true)
	await _frames(1)
	var before: String = var_to_str(preview.last_forecast)
	assert_true(preview.visible, "%s on" % label)
	# Deploy the Operator by tapping a lane THROUGH the forecast card (mouse passes through).
	c.select_operator()
	await _frames(1)
	var card_r: Rect2 = preview.get_cards()[1].get_global_rect()
	await _tap(vp, card_r.get_center())
	assert_eq(c.state.sides[0].plays.size(), 1, "%s tap on the card reached the Mid lane" % label)
	assert_eq(var_to_str(preview.last_forecast), var_to_str(OutcomeForecast.forecast(c.state)), "%s updated after the play" % label)
	var mid_lines: PackedStringArray = OutcomePreviewScript.card_lines(OutcomeForecast.forecast(c.state)["zones"][1])
	assert_eq(preview.get_important_labels()[5].text, mid_lines[1], "%s Mid card text refreshed" % label)
	c.undo()
	await _frames(1)
	assert_eq(var_to_str(preview.last_forecast), before, "%s UNDO restores the forecast" % label)
	# READY: hidden while the round plays, back (with the next round's numbers) at the next Deploy.
	c.select_operator()
	c.play_at(1)
	c.press_ready()
	await _frames(2)
	assert_false(preview.visible, "%s hidden while the round plays" % label)
	await _until_presented(c)
	if c.state.phase == MatchState.Phase.DEPLOY:
		assert_true(preview.visible, "%s back for the next Deploy" % label)
		assert_eq(int(preview.last_forecast.get("zones", [{}])[0].get("unknown", -1)), c.state.red_dots(0)[0], "%s red dots of the new round" % label)
	_despawn(vp)


# --- helpers ----------------------------------------------------------------------------

func _fill_worst_case(preview: Control) -> void:
	var labels: Array[Label] = preview.get_important_labels()
	var lines: PackedStringArray = OutcomePreviewScript.card_lines({"dealt": 88, "taken": 88, "kills": 8, "losses": 8,
			"fight": true, "control": &"contested", "unknown": 8})
	for z: int in 3:
		for i: int in 4:
			labels[z * 4 + i].text = lines[i]
		labels[z * 4 + 1].theme_type_variation = &"PreviewContested"
		labels[z * 4 + 3].theme_type_variation = &"PreviewUnknown"


func _on_toggled(enabled: bool) -> void:
	_toggles.append(enabled)


func _spawn(screen: Dictionary) -> Array:
	_toggles.clear()
	var bus: Node = tree.root.get_node("EventBus")
	if not bus.preview_toggled.is_connected(_on_toggled):
		bus.preview_toggled.connect(_on_toggled)
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
	assert_not_null(c.state, "%s live match started" % screen["name"])
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	return [vp, m, c]


func _despawn(vp: SubViewport) -> void:
	var bus: Node = tree.root.get_node("EventBus")
	if bus.preview_toggled.is_connected(_on_toggled):
		bus.preview_toggled.disconnect(_on_toggled)
	vp.queue_free()
	tree.root.size = _saved_root_size


func _until_presented(c: Node, max_s: float = 30.0) -> void:
	var t0: int = Time.get_ticks_msec()
	while c.is_busy() and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await _frames(1)
	await _frames(2)


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _tap(vp: SubViewport, pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		vp.push_input(e)
		await _frames(2 if pressed else 3)


func _key(vp: SubViewport, key: Key) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = pressed
		vp.push_input(e)
		await _frames(2)


## "" when the label shows its whole text, else why not (same rule as test_board_layout.gd).
func _clipped(l: Label) -> String:
	var font: Font = l.get_theme_font(&"font")
	var size: int = l.get_theme_font_size(&"font_size")
	var need: float = 0.0
	for line: String in l.text.split("\n"):
		need = maxf(need, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	if need > l.size.x + 0.5:
		return "needs %.0f px, has %.0f px" % [need, l.size.x]
	return ""
