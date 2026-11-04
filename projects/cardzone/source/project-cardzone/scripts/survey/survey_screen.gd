# survey_screen.gd
# Adapted from CallingCard scripts/survey/survey_screen.gd (pages, Download log, two-tap delete;
#   five statements, CardZone theme, back to the title).
# Purpose: PLAYTEST screen (cz18, scenes/survey/Survey.tscn, opened from the title's PLAYTEST
#   button or PlaytestLog.open_survey()). Pages:
#   OFF       logging is off: what the log holds, TURN ON LOGGING (opt-in), TITLE.
#   QUESTION  the 5 plan section 8 statements, one per page, 1-5 (a tap answers and moves on;
#             SKIP leaves it blank); after a hot-seat-only session "The AI played fair." is left
#             out (logged as null, cz19b),
#   OPEN      the optional open question,
#   DONE      thanks, DOWNLOAD LOG (browser download on the web, a file under user:// elsewhere),
#             ANSWER AGAIN, STOP LOGGING & DELETE (two taps), TITLE.
#   Submitting writes the "survey" line through PlaytestLog.record_survey(), which also keeps the
#   answers on this device. Opening the screen again after answering starts on DONE.
# Dependencies: PlaytestLog (or plog for tests), SceneRouter, EventBus, match_theme.gd, survey_ui.gd.
# Author: Data Scientist Agent
extends Control

const MatchTheme: GDScript = preload("res://scripts/ui/match_theme.gd")
const SurveyUi: GDScript = preload("res://scripts/survey/survey_ui.gd")
const TITLE_SCENE: String = "res://scenes/Title.tscn"

enum Page { OFF, QUESTION, OPEN, DONE }

## The PlaytestLog used (tests pass their own); null = the autoload.
var plog: Node = null
## Safe area in logical px (tests / previews). Empty = the device's.
var safe_area_override: Rect2 = Rect2()
## q1..q5 -> 1-5, "open" -> String.
var answers: Dictionary = {}
var page: Page = Page.OFF
## Index of the statement showing (0-4).
var question_index: int = 0

var _margin: MarginContainer
var _column: VBoxContainer
var _progress: Label
var _back_title: Button
var _pages: Dictionary = {}  # Page -> Control
var _off_text: Label
var _consent_button: Button
var _statement: Label
var _scale_buttons: Array[Button] = []
var _prev_button: Button
var _skip_button: Button
var _open_question: Label
var _open_answer: LineEdit
var _open_back: Button
var _submit_button: Button
var _done_title: Label
var _done_text: Label
var _download_button: Button
var _again_button: Button
var _delete_button: Button
var _status: Label
var _summary: Label
var _delete_armed: bool = false


func _ready() -> void:
	theme = MatchTheme.build()
	if plog == null:
		plog = get_node_or_null("/root/PlaytestLog")
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	if plog != null and plog.enabled and not (plog.survey_answers as Dictionary).is_empty():
		_show_done(false)
	else:
		_start()
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.screen_shown.emit(&"survey")
	print("Survey: ready")


func _start() -> void:
	if plog == null or not plog.enabled:
		_show_off()
	else:
		answers = {}
		_show_question(0)


# --- Actions ----------------------------------------------------------------------------------

## OFF page: opt in (the same answer as YES on the consent prompt), then the questions.
func turn_on_logging() -> void:
	if plog != null:
		plog.set_consent(true)
	_start()


## Answers the current statement (1-5, 0 = skipped) and moves to the next page.
func choose(value: int) -> void:
	if page != Page.QUESTION:
		return
	var key: String = _question(question_index)["id"]
	if value >= 1 and value <= 5:
		answers[key] = value
	else:
		answers.erase(key)
	if question_index + 1 < _question_count():
		_show_question(question_index + 1)
	else:
		_show_open()


func back() -> void:
	if page == Page.OPEN:
		_show_question(_question_count() - 1)
	elif page == Page.QUESTION and question_index > 0:
		_show_question(question_index - 1)


## Records the survey (PlaytestLog.record_survey) and shows the DONE page.
func submit() -> Dictionary:
	if page != Page.OPEN:
		return {}
	answers["open"] = _open_answer.text
	var saved: Dictionary = plog.record_survey(answers) if plog != null else {}
	_show_done(true)
	return saved


## DOWNLOAD LOG. Returns PlaytestLog.export_log()'s result ({} without a log).
func download_log() -> Dictionary:
	if plog == null:
		return {}
	var result: Dictionary = plog.export_log()
	if not result["ok"]:
		_status.text = "Could not save the log: %s" % result["error"]
	elif result["method"] == "download":
		_status.text = "Downloading %s (%d KB). On a phone: check your Downloads (iPhone: Files app)." % [
				result["path"], ceili(result["bytes"] / 1024.0)]
	else:
		_status.text = "Saved to %s" % result["path"]
	return result


func answer_again() -> void:
	_start()


func go_title() -> void:
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null:
		router.goto_scene(TITLE_SCENE)


func get_page_name() -> String:
	return Page.keys()[page]


func get_button(button_name: String) -> Button:
	return find_child(button_name, true, false) as Button


func get_scale_button(value: int) -> Button:
	return _scale_buttons[value - 1] if value >= 1 and value <= _scale_buttons.size() else null


func get_open_answer() -> LineEdit:
	return _open_answer


## Controls a layout test checks on the page showing.
func get_key_controls() -> Dictionary:
	var out: Dictionary = {"SurveyTitle": find_child("SurveyTitle", true, false), "BackTitleButton": _back_title}
	match page:
		Page.OFF:
			out["ConsentButton"] = _consent_button
		Page.QUESTION:
			out["Statement"] = _statement
			for b: Button in _scale_buttons:
				out[b.name] = b
			out["SkipButton"] = _skip_button
		Page.OPEN:
			out["OpenAnswer"] = _open_answer
			out["SubmitButton"] = _submit_button
		Page.DONE:
			out["DownloadButton"] = _download_button
			out["AgainButton"] = _again_button
	return out


# --- Pages --------------------------------------------------------------------------------------

func _show_off() -> void:
	page = Page.OFF
	_progress.text = "Logging is off"
	_set_page(Page.OFF)
	_consent_button.grab_focus()


func _show_question(i: int) -> void:
	page = Page.QUESTION
	question_index = i
	_statement.text = _question(i)["text"]
	_progress.text = "Question %d of %d" % [i + 1, _question_count() + 1]
	var current: int = int(answers.get(_question(i)["id"], 0))
	for b: int in _scale_buttons.size():
		_scale_buttons[b].button_pressed = b + 1 == current
	_prev_button.disabled = i == 0
	_set_page(Page.QUESTION)


func _show_open() -> void:
	page = Page.OPEN
	_progress.text = "Question %d of %d (optional)" % [_question_count() + 1, _question_count() + 1]
	_open_answer.text = str(answers.get("open", ""))
	_set_page(Page.OPEN)


func _show_done(just_answered: bool) -> void:
	page = Page.DONE
	var on: bool = plog != null and plog.enabled
	_progress.text = "Survey saved" if just_answered or on else ""
	_done_title.text = "THANKS FOR PLAYING!"
	_done_text.text = "Last step: press DOWNLOAD LOG and send the file to the playtest organiser. Nothing is sent automatically." \
			if on else "Logging is off, so there is no log to send."
	_download_button.disabled = not on
	_delete_button.visible = on
	_delete_armed = false
	_delete_button.text = "STOP LOGGING & DELETE"
	_status.text = ""
	_summary.text = plog.summary_line() if plog != null else ""
	_set_page(Page.DONE)
	(_download_button if on else _back_title).grab_focus()
	print("Survey: done page")


func _set_page(shown: Page) -> void:
	for p: Page in _pages:
		(_pages[p] as Control).visible = p == shown


func _on_delete_pressed() -> void:
	if not _delete_armed:
		_delete_armed = true
		_delete_button.text = "TAP AGAIN TO DELETE"
		return
	if plog != null:
		plog.withdraw()
	_show_done(false)
	_status.text = "Logging stopped and the log was deleted."


## The statements asked this time: PlaytestLog.survey_questions() leaves out "The AI played
## fair." after a hot-seat-only session (cz19b BUG-08).
func _questions() -> Array:
	if plog == null:
		return []
	return plog.survey_questions() if plog.has_method("survey_questions") else plog.SURVEY_QUESTIONS


func _question(i: int) -> Dictionary:
	var qs: Array = _questions()
	return qs[i] if i < qs.size() else {"id": "q%d" % (i + 1), "text": ""}


func _question_count() -> int:
	return _questions().size() if plog != null else 5


# --- Layout -------------------------------------------------------------------------------------

func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.0824, 0.0941, 0.1137)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin = MarginContainer.new()
	_margin.name = "SafeArea"
	add_child(_margin)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_margin.add_child(_column)

	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override(&"separation", 16)
	_column.add_child(header)
	var title: Label = SurveyUi.label("SurveyTitle", "PLAYTEST", &"InspectorTitle")
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	_progress = SurveyUi.label("Progress", "", &"Caption")
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_progress)
	_back_title = SurveyUi.button("BackTitleButton", "TITLE", &"Button", Vector2(120, 64))
	_back_title.pressed.connect(go_title)
	header.add_child(_back_title)

	# OFF
	var off: VBoxContainer = _page(Page.OFF, "OffPage")
	_off_text = SurveyUi.label("OffText", "Playtest logging is off. Turn it on to answer the survey and send us your log. "
			+ "The log is anonymous (screens, matches, cards played and held, shots, Brace choices, timings; never the AI's hidden cards), stays on this device and is only sent if you download it and pass it on.", &"InspectorBody")
	_off_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	off.add_child(_off_text)
	_consent_button = SurveyUi.button("ConsentButton", "TURN ON LOGGING", &"DockButton")
	_consent_button.pressed.connect(turn_on_logging)
	off.add_child(_consent_button)

	# QUESTION
	var q: VBoxContainer = _page(Page.QUESTION, "QuestionPage")
	_statement = SurveyUi.label("Statement", "", &"InspectorTitle")
	_statement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_child(_statement)
	var scale_row: HBoxContainer = HBoxContainer.new()
	scale_row.name = "Scale"
	scale_row.add_theme_constant_override(&"separation", 12)
	q.add_child(scale_row)
	for v: int in range(1, 6):
		var b: Button = SurveyUi.button("Scale%d" % v, str(v), &"Button")
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(choose.bind(v))
		scale_row.add_child(b)
		_scale_buttons.append(b)
	var legend: HBoxContainer = HBoxContainer.new()
	legend.name = "ScaleLegend"
	q.add_child(legend)
	var low: Label = SurveyUi.label("ScaleLow", "1 = %s" % (plog.SCALE_LOW if plog != null else "Strongly disagree"), &"Caption")
	low.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend.add_child(low)
	legend.add_child(SurveyUi.label("ScaleHigh", "5 = %s" % (plog.SCALE_HIGH if plog != null else "Strongly agree"),
			&"Caption", HORIZONTAL_ALIGNMENT_RIGHT))
	var qnav: HBoxContainer = _nav_row(q)
	_prev_button = SurveyUi.button("PrevButton", "BACK", &"Button")
	_prev_button.pressed.connect(back)
	qnav.add_child(_prev_button)
	_skip_button = SurveyUi.button("SkipButton", "SKIP", &"Button")
	_skip_button.pressed.connect(choose.bind(0))
	qnav.add_child(_skip_button)

	# OPEN
	var o: VBoxContainer = _page(Page.OPEN, "OpenPage")
	_open_question = SurveyUi.label("OpenQuestion", plog.OPEN_QUESTION if plog != null else "", &"InspectorTitle")
	_open_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	o.add_child(_open_question)
	_open_answer = LineEdit.new()
	_open_answer.name = "OpenAnswer"
	_open_answer.placeholder_text = "Optional"
	_open_answer.max_length = plog.MAX_TEXT_CHARS if plog != null else 500
	_open_answer.custom_minimum_size = Vector2(0, SurveyUi.TAP)
	_open_answer.text_submitted.connect(func(_t: String) -> void: submit())
	o.add_child(_open_answer)
	var onav: HBoxContainer = _nav_row(o)
	_open_back = SurveyUi.button("OpenBackButton", "BACK", &"Button")
	_open_back.pressed.connect(back)
	onav.add_child(_open_back)
	_submit_button = SurveyUi.button("SubmitButton", "SUBMIT", &"DockButton")
	_submit_button.pressed.connect(submit)
	onav.add_child(_submit_button)

	# DONE
	var d: VBoxContainer = _page(Page.DONE, "DonePage")
	_done_title = SurveyUi.label("DoneTitle", "", &"InspectorTitle")
	d.add_child(_done_title)
	_done_text = SurveyUi.label("DoneText", "", &"InspectorBody")
	_done_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_child(_done_text)
	var drow: HBoxContainer = _nav_row(d)
	_download_button = SurveyUi.button("DownloadButton", "DOWNLOAD LOG", &"DockButton")
	_download_button.pressed.connect(download_log)
	drow.add_child(_download_button)
	_again_button = SurveyUi.button("AgainButton", "ANSWER AGAIN", &"Button")
	_again_button.pressed.connect(answer_again)
	drow.add_child(_again_button)
	_delete_button = SurveyUi.button("DeleteButton", "STOP LOGGING & DELETE", &"Button")
	_delete_button.pressed.connect(_on_delete_pressed)
	drow.add_child(_delete_button)
	_status = SurveyUi.label("Status", "", &"Caption")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_child(_status)
	_summary = SurveyUi.label("Summary", "", &"Caption")
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_child(_summary)


func _page(p: Page, node_name: String) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.name = node_name
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 14)
	box.visible = false
	_column.add_child(box)
	_pages[p] = box
	return box


func _nav_row(parent: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "%sNav" % parent.name
	row.add_theme_constant_override(&"separation", 12)
	parent.add_child(row)
	return row


func _relayout() -> void:
	var m: Array[Vector2] = SurveyUi.safe_margins(self, safe_area_override)
	SurveyUi.apply_margins(_margin, m[0], m[1])
	var compact: bool = SurveyUi.is_compact(self)
	_column.add_theme_constant_override(&"separation", 8 if compact else 16)
	for p: Page in _pages:
		(_pages[p] as VBoxContainer).add_theme_constant_override(&"separation", 8 if compact else 14)
