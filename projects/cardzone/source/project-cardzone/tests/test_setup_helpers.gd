# test_setup_helpers.gd
# Purpose: Shared helpers for the cz13 shell tests (test_title_*.gd, test_setup_*.gd,
#   test_coach_*.gd); it has no tests of its own. Screens run at the root window at phone size
#   (844x390 pt @3x + notch = 1168x540 logical, content scaling off) and are driven by TOUCH
#   only (InputEventScreenTouch through Input.parse_input_event; the project emulates mouse from
#   touch), as tests/test_match_flow.gd (cz11) does. Scene changes: SceneRouter records the
#   request under the test runner (no real change); follow() frees the screen and spawns the
#   requested scene, which is what the real change does.
#   Every test starts from a clean device: SetupPrefs (prefs file), MatchStore, launch request.
# Author: UI/UX Agent (cz13)
extends "res://tests/test_case.gd"

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const SetupPrefs: GDScript = preload("res://scripts/ui/setup_prefs.gd")
const SetupLaunch: GDScript = preload("res://scripts/ui/setup_launch.gd")
const DevOverrides: GDScript = preload("res://scripts/ui/dev_panel_overrides.gd")
const CoachTips: GDScript = preload("res://scripts/ui/coach_tips.gd")
const SetupUI: GDScript = preload("res://scripts/ui/setup_ui.gd")
const PHONE: Dictionary = {"pt": Vector2(844, 390), "ratio": 3.0, "insets": Rect2(47, 0, 47, 21)}

var _saved_root_size: Vector2i
var _saved_scale_mode: int = 0
var _phone_on: bool = false


## Phone-size root and a clean device (prefs, save, launch request). Events play instantly.
func phone_begin() -> void:
	if not _phone_on:
		_saved_root_size = tree.root.size
		_saved_scale_mode = tree.root.content_scale_mode
		_phone_on = true
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	tree.root.size = Vector2i(logical())
	await tree.process_frame
	SetupPrefs.reset_all()
	SetupPrefs.set_value("settings", "event_speed", "instant")
	SetupPrefs.set_value("coach", "how_to_play", true)  # cz-clarity: How to play is tested in test_clarity.gd
	MatchStore.clear()
	SetupLaunch.clear_pending()
	SceneRouter.last_requested = ""


func phone_end(screen: Node = null) -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	await tree.process_frame
	MatchStore.clear()
	SetupLaunch.clear_pending()
	SetupPrefs.reset_all()
	if _phone_on:
		tree.root.size = _saved_root_size
		tree.root.content_scale_mode = _saved_scale_mode
		_phone_on = false


func logical() -> Vector2:
	var px: Vector2 = PHONE["pt"] * PHONE["ratio"]
	return ScreenProfile.logical_size(px, ScreenProfile.base_size(px, PHONE["ratio"]))


func points_per_px() -> float:
	return ScreenProfile.points_per_px(PHONE["pt"] * PHONE["ratio"], PHONE["ratio"])


func safe_rect() -> Rect2:
	var k: float = points_per_px()
	var insets: Rect2 = PHONE["insets"]
	return Rect2(insets.position / k, logical() - insets.position / k - insets.size / k)


## Instantiates a scene at phone size (safe area set) and lets it lay out.
func spawn(path: String) -> Control:
	var c: Control = (load(path) as PackedScene).instantiate()
	if "safe_area_override" in c:
		c.set("safe_area_override", safe_rect())
	if "points_per_px_override" in c:
		c.set("points_per_px_override", points_per_px())
	tree.root.add_child(c)
	for i: int in 4:
		await tree.process_frame
	return c


## Frees `screen` and spawns the scene SceneRouter was last asked for.
func follow(screen: Node, expected: String) -> Control:
	assert_eq(SceneRouter.last_requested, expected, "scene change requested")
	if SceneRouter.last_requested != expected:
		return null
	if screen != null:
		screen.queue_free()
	await tree.process_frame
	SceneRouter.last_requested = ""
	return await spawn(expected)


## A real touch (press + release) at the centre of a control.
func touch(c: Control) -> void:
	if c == null or not c.is_visible_in_tree():
		failures.append("touch on a missing or hidden control (%s)" % c)
		return
	await touch_at(c.get_global_rect().get_center())


func touch_at(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		await touch_edge(pos, pressed)
	await tree.process_frame


func touch_edge(pos: Vector2, pressed: bool) -> void:
	var t: InputEventScreenTouch = InputEventScreenTouch.new()
	t.index = 0
	t.pressed = pressed
	t.position = pos
	Input.parse_input_event(t)
	Input.flush_buffered_events()
	await tree.process_frame


## Holds a touch on a control for `seconds`, then releases.
func long_press(c: Control, seconds: float) -> void:
	var pos: Vector2 = c.get_global_rect().get_center()
	await touch_edge(pos, true)
	await tree.create_timer(seconds).timeout
	await tree.process_frame
	await touch_edge(pos, false)
	await tree.process_frame


## True when r lies inside the phone's safe area (1 px slack).
func in_safe_area(r: Rect2) -> bool:
	return safe_rect().grow(1.0).encloses(r)


## Buttons must be >= 44 pt tall on the phone and fully on screen.
func check_buttons(buttons: Array, where: String) -> void:
	var k: float = points_per_px()
	for b: Variant in buttons:
		var btn: Button = b as Button
		if btn == null or not btn.is_visible_in_tree():
			continue
		var r: Rect2 = btn.get_global_rect()
		assert_true(r.size.y * k >= 44.0 - 0.01, "%s: %s is %.1f pt tall (>= 44)" % [where, btn.text, r.size.y * k])
		assert_true(in_safe_area(r), "%s: %s %s inside the safe area %s" % [where, btn.text, r, safe_rect()])


## Text must be >= 11 pt on the phone.
func check_labels(labels: Array, where: String) -> void:
	var k: float = points_per_px()
	for l: Variant in labels:
		var label: Label = l as Label
		if label == null or not label.is_visible_in_tree() or label.text == "":
			continue
		var fs: int = label.get_theme_font_size(&"font_size")
		assert_true(fs * k >= 11.0 - 0.01, "%s: '%s' is %.1f pt (>= 11)" % [where, label.text.left(24), fs * k])
