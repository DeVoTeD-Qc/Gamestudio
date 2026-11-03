# test_survey_screens.gd
# Purpose: p16 consent / pre-survey / end-survey screens. Taps drive PlaytestLog (consent
#   gating, answers recorded), and every page fits and stays readable on an 844x390 @3x iPhone
#   in landscape and on a 1280x720 desktop: the layout's minimum size fits the screen, every
#   visible control is on screen, text >= 11 pt, every visible button >= 44 pt both ways.
#   Uses the same screen profile maths as test_board_layout.gd.
# Author: Data Scientist Agent
extends "res://tests/test_case.gd"

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const CONSENT: String = "res://scenes/survey/Consent.tscn"
const PRE: String = "res://scenes/survey/PreSurvey.tscn"
const END: String = "res://scenes/survey/EndSurvey.tscn"
const MIN_TAP_PT: float = 44.0
const MIN_TEXT_PT: float = 11.0
const EPS: float = 0.5
const PHONE: Dictionary = {"name": "iPhone 844x390 @3x", "pt": Vector2(844, 390), "ratio": 3.0}
const DESKTOP: Dictionary = {"name": "desktop 1280x720", "pt": Vector2(1280, 720), "ratio": 1.0}

var _saved: Dictionary = {}
var _saved_root_size: Vector2i


func _plog() -> Node:
	var plog: Node = tree.root.get_node("PlaytestLog")
	_saved = {"log_path": plog.log_path, "consent_path": plog.consent_path}
	var dir: String = "user://test_playtest".path_join("s%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	plog.enabled = false
	plog.consent_answered = false
	plog.pre_survey = {}
	plog.log_path = dir.path_join("playtest_log.jsonl")
	plog.consent_path = dir.path_join("consent.cfg")
	plog.new_session()
	return plog


func _restore(plog: Node) -> void:
	plog.flush()
	plog.delete_log()
	for f: String in DirAccess.get_files_at(plog.log_path.get_base_dir()):
		DirAccess.remove_absolute(plog.log_path.get_base_dir().path_join(f))
	DirAccess.remove_absolute(plog.log_path.get_base_dir())
	plog.enabled = false
	plog.consent_answered = false
	plog.pre_survey = {}
	for key: String in _saved:
		plog.set(key, _saved[key])
	plog.new_session()


func _logical(screen: Dictionary) -> Vector2:
	var px: Vector2 = screen["pt"] * float(screen["ratio"])
	return ScreenProfile.logical_size(px, ScreenProfile.base_size(px, screen["ratio"]))


func _k(screen: Dictionary) -> float:
	return ScreenProfile.points_per_px(screen["pt"] * float(screen["ratio"]), screen["ratio"])


func _spawn(path: String, screen: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(_logical(screen))
	viewport.disable_3d = true
	tree.root.add_child(viewport)
	var node: Control = (load(path) as PackedScene).instantiate()
	node.set("next_scene", "")
	if "pre_survey_scene" in node:
		node.set("pre_survey_scene", "")
	viewport.add_child(node)
	await _settle()
	return [viewport, node]


func _settle() -> void:
	for i: int in 3:
		await tree.process_frame


func _despawn(viewport: SubViewport) -> void:
	viewport.queue_free()
	tree.root.size = _saved_root_size


func _check(node: Control, screen: Dictionary, what: String) -> void:
	var viewport: Viewport = node.get_viewport()
	var k: float = _k(screen)
	var rect: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport.size)).grow(EPS)
	var label: String = "%s %s" % [screen["name"], what]
	var needed: Vector2 = node.get_node("Center").get_combined_minimum_size()
	assert_true(needed.x <= viewport.size.x + EPS and needed.y <= viewport.size.y + EPS,
			"%s needs %s but the screen is %s" % [label, needed, viewport.size])
	var checked: int = 0
	for c: Node in node.find_children("*", "Control", true, false):
		var ctl: Control = c
		if not ctl.is_visible_in_tree():
			continue
		var r: Rect2 = ctl.get_global_rect()
		assert_true(rect.encloses(r), "%s: %s at %s is off screen" % [label, ctl.name, r])
		if ctl is Label and (ctl as Label).text != "":
			var pt: float = ctl.get_theme_font_size("font_size") * k
			assert_true(pt >= MIN_TEXT_PT, "%s: %s text %.1f pt" % [label, ctl.name, pt])
			checked += 1
		elif ctl is Button:
			var b: Button = ctl
			assert_true(b.size.y * k >= MIN_TAP_PT and b.size.x * k >= MIN_TAP_PT,
					"%s: %s tap target %.1fx%.1f pt" % [label, b.name, b.size.x * k, b.size.y * k])
			assert_true(b.get_theme_font_size("font_size") * k >= MIN_TEXT_PT, "%s: %s button text" % [label, b.name])
			checked += 1
		elif ctl is LineEdit or ctl is TextEdit:
			assert_true(ctl.size.y * k >= MIN_TAP_PT, "%s: %s field height" % [label, ctl.name])
			assert_true(ctl.get_theme_font_size("font_size") * k >= MIN_TEXT_PT, "%s: %s field text" % [label, ctl.name])
	assert_true(checked > 3, "%s: checked %d controls" % [label, checked])


func test_consent_yes_enables_logging() -> void:
	var plog: Node = _plog()
	var setup: Array = await _spawn(CONSENT, PHONE)
	var node: Control = setup[1]
	var done: Array = [false]
	node.finished.connect(func() -> void: done[0] = true)
	(node.get_node("%YesButton") as Button).pressed.emit()
	assert_true(plog.enabled, "yes turns logging on")
	assert_true(done[0], "screen finished")
	assert_eq(plog.read_entries().size(), 2, "session_start + consent written")
	_despawn(setup[0])
	_restore(plog)


func test_consent_no_keeps_logging_off() -> void:
	var plog: Node = _plog()
	var setup: Array = await _spawn(CONSENT, PHONE)
	(setup[1].get_node("%NoButton") as Button).pressed.emit()
	assert_false(plog.enabled, "no keeps logging off")
	assert_false(plog.needs_consent(), "answer remembered")
	plog.flush()
	assert_false(FileAccess.file_exists(plog.log_path), "no log file")
	_despawn(setup[0])
	_restore(plog)


func test_pre_survey_taps_record_segment() -> void:
	var plog: Node = _plog()
	plog.set_consent(true)
	var setup: Array = await _spawn(PRE, PHONE)
	var node: Control = setup[1]
	var cont: Button = node.get_node("%ContinueButton")
	assert_true(cont.disabled, "continue disabled until answered")
	var rows: Node = node.get_node("%Rows")
	(rows.get_child(0).get_node("No") as Button).pressed.emit()
	(rows.get_child(1).get_node("Yes") as Button).pressed.emit()
	assert_true(cont.disabled, "still one to go")
	(rows.get_child(2).get_node("Yes") as Button).pressed.emit()
	assert_false(cont.disabled, "all three answered")
	assert_true((rows.get_child(1).get_node("Yes") as Button).button_pressed, "tapped answer shows as pressed")
	cont.pressed.emit()
	assert_eq(plog.segment(), "card", "segment from taps")
	var lines: Array = plog.read_entries().filter(func(e: Dictionary) -> bool: return e["event"] == "pre_survey")
	assert_eq(lines.size(), 1, "pre_survey line")
	_despawn(setup[0])
	_restore(plog)


func test_end_survey_flow_records_answers() -> void:
	var plog: Node = _plog()
	plog.set_consent(true)
	var setup: Array = await _spawn(END, PHONE)
	var node: Control = setup[1]
	var scale: Node = node.get_node("%Scale")
	(scale.get_child(4) as Button).pressed.emit()  # q1 = 5
	(scale.get_child(3) as Button).pressed.emit()  # q2 = 4
	(node.get_node("%BackButton") as Button).pressed.emit()  # back to q2
	assert_true((scale.get_child(3) as Button).button_pressed, "previous answer shown on back")
	(scale.get_child(1) as Button).pressed.emit()  # q2 = 2 (changed)
	(node.get_node("%SkipButton") as Button).pressed.emit()  # q3 skipped
	(scale.get_child(2) as Button).pressed.emit()  # q4 = 3
	(scale.get_child(4) as Button).pressed.emit()  # q5 = 5
	assert_true(node.get_node("%OpenPage").visible, "open question after five statements")
	(node.get_node("%OpenAnswer") as LineEdit).text = "Weapon swapping"
	(node.get_node("%SubmitButton") as Button).pressed.emit()
	assert_true(node.get_node("%DonePage").visible, "log page last")
	var lines: Array = plog.read_entries().filter(func(e: Dictionary) -> bool: return e["event"] == "end_survey")
	assert_eq(lines.size(), 1, "end_survey line")
	if lines.size() == 1:
		var e: Dictionary = lines[0]
		assert_eq([e["q1"], e["q2"], e["q3"], e["q4"], e["q5"]], [5.0, 2.0, null, 3.0, 5.0], "answers")
		assert_eq(e["open"], "Weapon swapping", "open answer")
	var result: Dictionary = node.download_log()
	assert_true(result.get("ok", false), "download (file) ok")
	assert_true(String(node.get_node("%Status").text).contains("Saved to"), "status shows the path")
	if result.get("ok", false):
		DirAccess.remove_absolute(result["path"])
	var text: String = node.copy_summary()
	assert_true(text.contains(plog.session_id), "summary copied")
	assert_true(node.get_node("%SummaryText").visible, "summary shown for manual copy")
	_despawn(setup[0])
	_restore(plog)


func test_end_survey_without_consent_skips_to_log_page() -> void:
	var plog: Node = _plog()
	var setup: Array = await _spawn(END, PHONE)
	var node: Control = setup[1]
	assert_true(node.get_node("%DonePage").visible, "straight to the log page")
	assert_true((node.get_node("%DownloadButton") as Button).disabled, "nothing to download")
	_despawn(setup[0])
	_restore(plog)


func test_end_survey_delete_needs_two_taps() -> void:
	var plog: Node = _plog()
	plog.set_consent(true)
	plog.log_event(&"x")
	plog.flush()
	var setup: Array = await _spawn(END, PHONE)
	var node: Control = setup[1]
	node._show_done(true)
	var del: Button = node.get_node("%DeleteButton")
	del.pressed.emit()
	assert_true(plog.enabled, "first tap only arms")
	del.pressed.emit()
	assert_false(plog.enabled, "second tap withdraws")
	assert_true(plog.log_files().is_empty(), "log deleted")
	_despawn(setup[0])
	_restore(plog)


func test_layout_phone() -> void:
	await _check_all(PHONE)


func test_layout_desktop() -> void:
	await _check_all(DESKTOP)


func _check_all(screen: Dictionary) -> void:
	var plog: Node = _plog()
	var setup: Array = await _spawn(CONSENT, screen)
	_check(setup[1], screen, "consent")
	_despawn(setup[0])
	plog.set_consent(true)
	setup = await _spawn(PRE, screen)
	_check(setup[1], screen, "pre-survey")
	_despawn(setup[0])
	setup = await _spawn(END, screen)
	var node: Control = setup[1]
	var longest: int = 0
	for i: int in plog.END_QUESTIONS.size():
		if plog.END_QUESTIONS[i].length() > plog.END_QUESTIONS[longest].length():
			longest = i
	node._show_statement(longest)
	await _settle()
	_check(node, screen, "statement")
	node._show_open()
	await _settle()
	_check(node, screen, "open question")
	node._show_done(true)
	node.get_node("%Status").text = "Downloading killstreak-playtest-2026-11-03-0123456789ab.jsonl (12 KB). On iPhone: open the Files app, Downloads."
	await _settle()
	_check(node, screen, "log page")
	node.copy_summary()
	await _settle()
	_check(node, screen, "log page with summary")
	_despawn(setup[0])
	_restore(plog)
