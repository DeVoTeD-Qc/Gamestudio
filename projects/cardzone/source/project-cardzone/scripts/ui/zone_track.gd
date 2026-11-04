# zone_track.gd
# Purpose: Zone track for the match top bar (cz10). The Zone deck is public (spec §4.3), so the
#   track shows: round and route, a 14-step progress strip (past cards filled, current card
#   marked), and chips for the current card and the next ones ("5 Calm", "6 Gas+Drop", "7 Gas")
#   as many as fit (at least current + next). Gas chips are lime AND say "Gas" (never colour alone).
#   Tap or long-press opens the inspector with all 14 cards and this route's effects.
# Dependencies: tap_hold_button.gd, match_theme.gd, mock_match_data.gd (ZONE table, until cz06).
# Author: UI/UX Agent (cz10)
extends "res://scripts/ui/tap_hold_button.gd"

const MatchTheme: GDScript = preload("res://scripts/ui/match_theme.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const MAX_CHIPS: int = 4
const TRACK_H: float = 6.0

var zone_index: int = 1
var route: StringName = &"A"
var round_index: int = 1

var _title: Label
var _chips: HBoxContainer
var _chip_labels: Array[Label] = []
var _track: Control


func _init() -> void:
	super._init()
	theme_type_variation = &"InfoPanelButton"
	add_to_group(&"tap_target")
	clip_contents = true
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 6 if side in [&"margin_top", &"margin_bottom"] else 8)
	add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 3)
	margin.add_child(col)
	_title = Label.new()
	_title.theme_type_variation = &"CaptionStrong"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_title)
	_track = Control.new()
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.custom_minimum_size.y = TRACK_H
	_track.draw.connect(_draw_track)
	col.add_child(_track)
	_chips = HBoxContainer.new()
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chips.add_theme_constant_override(&"separation", 4)
	col.add_child(_chips)
	for i: int in MAX_CHIPS:
		var l: Label = Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chips.add_child(l)
		_chip_labels.append(l)
	resized.connect(_fit_chips)


func setup(zone_i: int, rt: StringName, rnd: int) -> void:
	zone_index = zone_i
	route = rt
	round_index = rnd
	_title.text = "ROUND %d · ZONE %d/14 · ROUTE %s" % [rnd, zone_i, String(rt)]
	for i: int in MAX_CHIPS:
		var n: int = zone_i + i
		var l: Label = _chip_labels[i]
		if n > MockMatchData.ZONE.size():
			l.text = ""
			l.visible = false
			continue
		var z: Dictionary = MockMatchData.zone_card(n)
		var kind: StringName = z["kind"]
		l.text = ("%d %s" % [n, MockMatchData.KIND_SHORT[kind]]) if i > 0 else ("NOW %d %s" % [n, MockMatchData.KIND_SHORT[kind]])
		l.theme_type_variation = &"TagChipNow" if i == 0 else (&"TagChipGas" if kind in [&"gas", &"gas_drop", &"final"] else &"TagChip")
		l.visible = true
	_fit_chips()
	_track.queue_redraw()


## Shortest title for narrow screens.
func set_short_title(short: bool) -> void:
	_title.text = ("R%d · ZONE %d/14 · %s" if short else "ROUND %d · ZONE %d/14 · ROUTE %s") % [round_index, zone_index, String(route)]


func get_title_label() -> Label:
	return _title


func get_chip_labels() -> Array[Label]:
	var out: Array[Label] = []
	for l: Label in _chip_labels:
		if l.visible:
			out.append(l)
	return out


## Hides trailing chips that do not fit (current and next always stay).
func _fit_chips() -> void:
	var room: float = size.x - 16.0
	var used: float = 0.0
	for i: int in MAX_CHIPS:
		var l: Label = _chip_labels[i]
		if l.text == "":
			l.visible = false
			continue
		var w: float = l.get_minimum_size().x + (4.0 if i > 0 else 0.0)
		l.visible = i < 2 or used + w <= room
		if l.visible:
			used += w


func _draw_track() -> void:
	var w: float = _track.size.x
	var cell: float = w / 14.0
	for i: int in 14:
		var r: Rect2 = Rect2(i * cell + 1.0, 0, cell - 2.0, TRACK_H)
		var n: int = i + 1
		if n < zone_index:
			_track.draw_rect(r, Color(MatchTheme.ZONE_EDGE, 0.8))
		elif n == zone_index:
			_track.draw_rect(r.grow_individual(0, 0, 0, 0), MatchTheme.PAPER)
		else:
			_track.draw_rect(r, Color(MatchTheme.ZONE_EDGE, 0.8), false, 1.0)
