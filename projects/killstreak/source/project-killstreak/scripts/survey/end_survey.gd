# end_survey.gd
# Purpose: End-of-run survey and log hand-off (p16, metrics plan). Five 1-5 agreement
#   statements (one per page, a tap answers and moves on), the open question, then the
#   "send us your log" page: Download log (browser download on the web, a file under user://
#   elsewhere), Copy summary (clipboard, and shown on screen to select by hand), Done, and
#   "Stop logging & delete" (two taps). When logging is off it goes straight to that page.
# Dependencies: survey_screen.gd, PlaytestLog.
# Author: Data Scientist Agent
extends "res://scripts/survey/survey_screen.gd"

enum Page { STATEMENT, OPEN, DONE }

## q1..q5 -> 1-5, "open" -> String.
var answers: Dictionary = {}
var page: Page = Page.STATEMENT
## Index of the statement showing (0-4).
var statement_index: int = 0
var _delete_armed: bool = false
var _scale_buttons: Array[Button] = []

@onready var _statement_page: Control = %StatementPage
@onready var _open_page: Control = %OpenPage
@onready var _done_page: Control = %DonePage
@onready var _progress: Label = %Progress
@onready var _statement: Label = %Statement
@onready var _scale: HBoxContainer = %Scale
@onready var _back_button: Button = %BackButton
@onready var _skip_button: Button = %SkipButton
@onready var _open_progress: Label = %OpenProgress
@onready var _open_question: Label = %OpenQuestion
@onready var _open_answer: LineEdit = %OpenAnswer
@onready var _open_back_button: Button = %OpenBackButton
@onready var _submit_button: Button = %SubmitButton
@onready var _done_title: Label = %DoneTitle
@onready var _done_text: Label = %DoneText
@onready var _download_button: Button = %DownloadButton
@onready var _copy_button: Button = %CopyButton
@onready var _folder_button: Button = %FolderButton
@onready var _status: Label = %Status
@onready var _summary_text: TextEdit = %SummaryText
@onready var _delete_button: Button = %DeleteButton
@onready var _done_button: Button = %DoneButton


func _ready() -> void:
	var group: ButtonGroup = ButtonGroup.new()
	group.allow_unpress = true
	for i: int in _scale.get_child_count():
		var b: Button = _scale.get_child(i)
		b.button_group = group
		b.pressed.connect(choose.bind(i + 1))
		_scale_buttons.append(b)
	_back_button.pressed.connect(back)
	_skip_button.pressed.connect(choose.bind(0))
	_open_back_button.pressed.connect(back)
	_submit_button.pressed.connect(submit)
	_open_answer.text_submitted.connect(func(_t: String) -> void: submit())
	_download_button.pressed.connect(download_log)
	_copy_button.pressed.connect(copy_summary)
	_folder_button.pressed.connect(_open_folder)
	_delete_button.pressed.connect(_on_delete_pressed)
	_done_button.pressed.connect(func() -> void: finish())
	var plog: Node = playtest_log()
	_open_question.text = plog.OPEN_QUESTION if plog != null else ""
	_open_answer.max_length = plog.MAX_TEXT_CHARS if plog != null else 500
	_folder_button.visible = OS.has_feature("pc") and not OS.has_feature("web")
	if plog == null or not plog.enabled:
		_show_done(false)
	else:
		_show_statement(0)


## Answers the current statement (1-5, 0 = skipped) and moves to the next page.
func choose(value: int) -> void:
	if page != Page.STATEMENT:
		return
	var key: String = "q%d" % (statement_index + 1)
	if value >= 1:
		answers[key] = value
	else:
		answers.erase(key)
	if statement_index + 1 < _statement_count():
		_show_statement(statement_index + 1)
	else:
		_show_open()


func back() -> void:
	if page == Page.OPEN:
		_show_statement(_statement_count() - 1)
	elif page == Page.STATEMENT and statement_index > 0:
		_show_statement(statement_index - 1)


## Records the survey and shows the log page.
func submit() -> void:
	if page != Page.OPEN:
		return
	answers["open"] = _open_answer.text
	var plog: Node = playtest_log()
	if plog != null:
		plog.record_end_survey(answers)
	_show_done(true)


func download_log() -> Dictionary:
	var plog: Node = playtest_log()
	if plog == null:
		return {}
	var result: Dictionary = plog.export_log()
	if not result["ok"]:
		_status.text = "Could not save the log: %s" % result["error"]
	elif result["method"] == "download":
		_status.text = "Downloading %s (%d KB). On iPhone: open the Files app, Downloads." % [result["path"], ceili(result["bytes"] / 1024.0)]
	else:
		_status.text = "Saved to %s" % result["path"]
	return result


func copy_summary() -> String:
	var plog: Node = playtest_log()
	if plog == null:
		return ""
	var text: String = plog.copy_summary()
	_summary_text.text = text
	_summary_text.visible = true
	_done_text.visible = false
	_status.text = "Summary copied. If pasting does not work, select the text below."
	return text


func _show_statement(i: int) -> void:
	page = Page.STATEMENT
	statement_index = i
	var plog: Node = playtest_log()
	_statement.text = plog.END_QUESTIONS[i] if plog != null else ""
	_progress.text = "Question %d of %d" % [i + 1, _statement_count() + 1]
	var current: int = int(answers.get("q%d" % (i + 1), 0))
	for b: int in _scale_buttons.size():
		mark_selected(_scale_buttons[b], b + 1 == current)
	_back_button.disabled = i == 0
	_set_page(_statement_page)
	announce(StringName("end_survey_q%d" % (i + 1)))


func _show_open() -> void:
	page = Page.OPEN
	_open_progress.text = "Question %d of %d (optional)" % [_statement_count() + 1, _statement_count() + 1]
	_set_page(_open_page)
	announce(&"end_survey_open")


func _show_done(answered: bool) -> void:
	page = Page.DONE
	var plog: Node = playtest_log()
	var on: bool = plog != null and plog.enabled
	_done_title.text = "Thanks for playing!" if answered or on else "Playtest logging is off"
	if on:
		_done_text.text = "Last step: press Download log and send the file to the playtest organiser. Nothing is sent automatically."
	else:
		_done_text.text = "Nothing was recorded on this device, so there is no log to send."
	_download_button.disabled = not on
	_delete_button.visible = on
	_summary_text.visible = false
	_done_text.visible = true
	_status.text = ""
	_set_page(_done_page)
	announce(&"log_export")
	(_download_button if on else _done_button).grab_focus()


func _set_page(shown: Control) -> void:
	for p: Control in [_statement_page, _open_page, _done_page]:
		p.visible = p == shown


func _statement_count() -> int:
	var plog: Node = playtest_log()
	return plog.END_QUESTIONS.size() if plog != null else 5


func _on_delete_pressed() -> void:
	if not _delete_armed:
		_delete_armed = true
		_delete_button.text = "Tap again to delete"
		return
	var plog: Node = playtest_log()
	if plog != null:
		plog.withdraw()
	_delete_armed = false
	_delete_button.text = "Stop logging & delete"
	_show_done(false)
	_status.text = "Logging stopped and the log was deleted."


func _open_folder() -> void:
	var plog: Node = playtest_log()
	if plog != null:
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(String(plog.log_path).get_base_dir()))
