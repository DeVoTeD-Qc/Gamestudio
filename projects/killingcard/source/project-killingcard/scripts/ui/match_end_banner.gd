# match_end_banner.gd
# Purpose: Match result banner (f03). A modal over the board once the match has ended:
#   VICTORY / DEFEAT / DRAW, the final score, why it ended and one big button. It only shows
#   the result and emits `continue_pressed` (once per open); MatchController decides where it
#   goes (SceneRouter.finish_run_match for a run match, the title for a local match).
#   Phone sizes: every text >= 16 px and the button >= 64 px tall (11.6 pt / 46 pt at the
#   iPhone's 0.722 pt per px).
# Scene: res://scenes/match/MatchEndBanner.tscn (full-rect, hidden until open()).
# Dependencies: hud_theme.tres variations (Scrim, HudPanelDark, ResultWin / ResultLoss /
#   ResultDraw, HudBig, HudSubtle, ReadyButton).
# Author: Mechanics Developer Agent (f03)
extends Control

## The player tapped the button (CONTINUE / BACK TO TITLE). Emitted at most once per open().
signal continue_pressed

const REASON_WORDS: Dictionary = {
	&"target": "Reached the target score",
	&"round_cap": "Most points after the last round",
	&"overtime": "Decided in overtime",
	&"overtime_draw": "Still tied after overtime",
	&"forfeit": "You forfeited the match",
}

var compact: bool = false
var _sent: bool = false

@onready var _result: Label = %ResultLabel
@onready var _score: Label = %ScoreLabel
@onready var _reason: Label = %ReasonLabel
@onready var _context: Label = %ContextLabel
@onready var _button: Button = %ContinueButton


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# kc-ui-wire2: the kit's modal plate behind the result (code look without the kit).
	KitTheme.style_panel(get_node_or_null(^"Center/Box") as Control, &"pnl_modal")
	_button.pressed.connect(_on_pressed)


## Shows the result. info: {result (&"player" / &"enemy" / &"draw"), player_score,
## enemy_score, reason (ModeRules reason or &"forfeit"), rounds, context (e.g. "MATCH 1 OF 5"),
## button ("CONTINUE" / "BACK TO TITLE")}.
func open(info: Dictionary) -> void:
	var res: StringName = StringName(info.get("result", &"draw"))
	_result.text = {&"player": "VICTORY", &"enemy": "DEFEAT"}.get(res, "DRAW")
	_result.theme_type_variation = {&"player": &"ResultWin", &"enemy": &"ResultLoss"}.get(res, &"ResultDraw")
	_score.text = "YOU %d  -  %d ENEMY" % [int(info.get("player_score", 0)), int(info.get("enemy_score", 0))]
	var why: String = String(REASON_WORDS.get(StringName(info.get("reason", &"")), ""))
	var rounds: int = int(info.get("rounds", 0))
	if rounds > 0:
		why = "%s · Round %d" % [why, rounds] if why != "" else "Round %d" % rounds
	_reason.text = why
	_reason.visible = why != ""
	_context.text = String(info.get("context", ""))
	_context.visible = _context.text != ""
	_button.text = String(info.get("button", "CONTINUE"))
	_button.disabled = false
	_sent = false
	show()
	_button.grab_focus.call_deferred()


func close() -> void:
	hide()


func is_open() -> bool:
	return visible


func set_compact(value: bool) -> void:
	compact = value
	_button.custom_minimum_size = Vector2(260, 64) if compact else Vector2(300, 80)


func get_continue_button() -> Button:
	return _button


func get_result_text() -> String:
	return _result.text


func get_score_text() -> String:
	return _score.text


func get_reason_text() -> String:
	return _reason.text if _reason.visible else ""


func _on_pressed() -> void:
	if _sent:
		return
	_sent = true
	_button.disabled = true
	continue_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"confirm"):
		get_viewport().set_input_as_handled()
		_on_pressed()
