# end_screen.gd
# Purpose: CardZone end screen (cz13), shown over the finished match (scenes/end/EndScreen.tscn).
#   It says who won and how the match ended (ELIMINATION, GAS, FINAL CIRCLE, HARD END or CONCEDE,
#   as a tag with a word, never colour alone), one sentence on what happened, a short stats line,
#   and NEW MATCH (the same setup again: Alternate and Pick-for-me advance) / TITLE. SEE BOARD
#   hides it so the final board can be read; MENU brings it back.
#   summary(view, stats) is pure, so tests check the words for every cause.
# Signals: new_match_pressed, title_pressed, board_pressed.
# Dependencies: setup_ui.gd.
# Author: UI/UX Agent (cz13)
extends Control

const SetupUI: GDScript = preload("res://scripts/ui/setup_ui.gd")

signal new_match_pressed
signal title_pressed
signal board_pressed

## rules-engine cause -> tag shown on the end screen.
const CAUSE_TAG: Dictionary = {"shot": "ELIMINATION", "frag": "ELIMINATION", "gas": "GAS",
		"final_circle": "FINAL CIRCLE", "hard_end": "HARD END", "concede": "CONCEDE"}

var _panel: PanelContainer
var _result: Label
var _tag: Label
var _detail: Label
var _stats: Label
var _buttons: Dictionary = {}
var _last: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(SetupUI.dim_layer(0.8))
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "EndPanel"
	_panel.theme_type_variation = &"ShellPanel"
	center.add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	_panel.add_child(col)
	_result = SetupUI.label("", &"ShellTitle")
	_result.name = "ResultLabel"
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_result)
	var tag_row: CenterContainer = CenterContainer.new()
	col.add_child(tag_row)
	_tag = SetupUI.label("", &"ShellTag")
	_tag.name = "CauseTag"
	tag_row.add_child(_tag)
	_detail = SetupUI.label("", &"ShellBody", true)
	_detail.name = "DetailLabel"
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_detail)
	_stats = SetupUI.label("", &"ShellMuted", true)
	_stats.name = "StatsLabel"
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_stats)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	col.add_child(row)
	for spec: Array in [[&"board", "SEE BOARD", &"Button"], [&"title", "TITLE", &"Button"], [&"new_match", "NEW MATCH", &"DockButton"]]:
		var b: Button = SetupUI.button(spec[1], spec[2])
		b.name = "End_%s" % spec[0]
		var key: StringName = spec[0]
		b.pressed.connect(func() -> void: _on_button(key))
		row.add_child(b)
		_buttons[key] = b
	resized.connect(_fit)
	_fit()


## Fills the screen from the human's final view and MatchController.stats().
func show_result(view: Dictionary, stats: Dictionary) -> void:
	_last = summary(view, stats)
	_result.text = _last["title"]
	_tag.text = _last["tag"]
	_detail.text = _last["detail"]
	_stats.text = _last["stats"]
	visible = true
	_fit()
	(_buttons[&"new_match"] as Button).grab_focus.call_deferred()


## {title, tag, detail, stats, cause, won} for a finished match (pure: tests use it).
static func summary(view: Dictionary, stats: Dictionary) -> Dictionary:
	var me: int = int(view.get("seat", 0))
	var r: Dictionary = view.get("match_end", {})
	var cause: String = String(r.get("cause", ""))
	var draw: bool = String(r.get("result", "")) == "draw"
	var won: bool = not draw and int(r.get("winner", -1)) == me
	var title: String = "DRAW" if draw else ("YOU WIN" if won else "THE RIVAL WINS")
	if not draw and bool(stats.get("hotseat", false)):  # hot-seat: name the seat, not "you"
		title = "PLAYER %d WINS" % (int(r.get("winner", 0)) + 1)
	var detail: String = ""
	match cause:
		"shot", "frag":
			var how: String = "a shot" if cause == "shot" else "a Frag"
			if draw:
				detail = "You both went out to %s at the same time." % how
			else:
				detail = ("You eliminated the rival with %s." if won else "The rival eliminated you with %s.") % how
		"gas":
			if draw:
				detail = "The gas took you both out."
			else:
				detail = "The rival was caught in the gas." if won else "You were caught in the gas."
		"final_circle":
			if draw:
				detail = "The final circle took you both out."
			else:
				detail = "The rival didn't survive the final circle." if won else "You didn't survive the final circle."
		"hard_end":
			if draw:
				detail = "The Zone ran out with the scores level: a draw."
			else:
				detail = "The Zone ran out. %s more health, so %s." % ["You had" if won else "The rival had", "you win" if won else "the rival wins"]
		"concede":
			detail = "The rival conceded." if won else "You conceded."
		_:
			detail = "The match is over."
	var me_v: Dictionary = view.get("me", {})
	var opp_v: Dictionary = view.get("opponent", {})
	var parts: PackedStringArray = []
	parts.append("Round %d" % int(view.get("round", stats.get("rounds", 0))))
	parts.append("%d turns" % int(stats.get("turns", 0)))
	parts.append("health: you %d, rival %d" % [int(me_v.get("health", 0)), int(opp_v.get("health", 0))])
	parts.append("Hits landed: on the rival %d, on you %d" % [int(stats.get("hits_on_rival", 0)), int(stats.get("hits_on_me", 0))])
	var secs: int = int(stats.get("seconds", 0.0))
	parts.append("%d:%02d" % [secs / 60, secs % 60])
	return {"title": title, "tag": CAUSE_TAG.get(cause, cause.to_upper()), "detail": detail,
			"stats": " · ".join(parts), "cause": cause, "won": won}


func get_button(key: StringName) -> Button:
	return _buttons.get(key)


func get_summary() -> Dictionary:
	return _last


func get_text_labels() -> Array[Label]:
	return [_result, _tag, _detail, _stats]


func _on_button(key: StringName) -> void:
	match key:
		&"new_match":
			new_match_pressed.emit()
		&"title":
			title_pressed.emit()
		&"board":
			visible = false
			board_pressed.emit()


func _fit() -> void:
	if _panel == null:
		return
	var w: float = minf(680.0, size.x - 48.0)
	_panel.custom_minimum_size.x = w
	_detail.custom_minimum_size.x = w - 48.0
	_stats.custom_minimum_size.x = w - 48.0
