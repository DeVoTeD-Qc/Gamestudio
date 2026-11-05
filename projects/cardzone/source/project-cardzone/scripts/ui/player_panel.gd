# player_panel.gd
# Purpose: Health panel for you or the rival in the match top bar (cz10).
#   You:   name, BOUNTY tag (if held), health "4/5" (key number), DOWN +1 tag.
#   Rival: name + AI level, BOUNTY tag, health, DOWN +1, loadout count, held count. The rival's
#          held cards and loadout order are private in the prototype (spec §16, scope §4
#          held_cards_public = false): only counts are shown, never the cards.
#   Every state is text in a shaped tag, never colour alone. Tap / long-press opens the inspector
#   with the full explanation (Down, Bounty, hidden held cards, the rival's last line).
# Dependencies: tap_hold_button.gd.
# Author: UI/UX Agent (cz10)
extends "res://scripts/ui/tap_hold_button.gd"

var side: StringName = &"you"
var data: Dictionary = {}

var _name: Label
var _bounty: Label
var _health: Label
var _health_max: Label
var _down: Label
## cz-clarity: "0/5 HP" while still playing read as a bug; at 0 health the next Hit puts you out.
var _last: Label
var _loadout: Label
var _held_label: Label
var _margin: MarginContainer
## Smallest width the screen wants (MatchScreen); the panel grows to fit its text.
var base_width: float = 150.0
## cz-clarity: the rival's deck and kept-card counts moved behind inspect in a live match (they are
## in the panel's long-press sheet); the cz10 mock layout still shows them.
var show_counts: bool = true
## Live match (MatchScreen): enables the NEXT HIT = OUT tag.
var live_mode: bool = false


func _init() -> void:
	super._init()
	theme_type_variation = &"InfoPanelButton"
	add_to_group(&"tap_target")
	clip_contents = true
	var margin: MarginContainer = MarginContainer.new()
	_margin = margin
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s: StringName in [&"margin_left", &"margin_right"]:
		margin.add_theme_constant_override(s, 8)
	for s: StringName in [&"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(s, 3)
	add_child(margin)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 0)
	margin.add_child(col)
	var row1: HBoxContainer = _row(col)
	_name = _label(row1, &"CaptionStrong")
	_bounty = _label(row1, &"TagBounty")
	_bounty.text = "BOUNTY"
	var row2: HBoxContainer = _row(col)
	_health = _label(row2, &"KeyNumber")
	_health.add_to_group(&"key_number")
	_health_max = _label(row2, &"Caption")
	_down = _label(row2, &"TagDown")
	_down.text = "DOWN +1"
	_last = _label(row2, &"TagDown")
	_last.text = "NEXT HIT = OUT"
	_loadout = _label(row2, &"Caption")
	_held_label = _label(row2, &"Caption")


func setup(which: StringName, d: Dictionary) -> void:
	side = which
	data = d
	_name.text = "YOU" if which == &"you" else "RIVAL · %s" % String(d.get("kind", "AI")).to_upper()
	_bounty.visible = d.get("bounty", false)
	_health.text = str(int(d.get("health", 0)))
	_health_max.text = "/%d HP" % int(d.get("max_health", 5))
	_down.visible = d.get("down", false)
	_last.visible = int(d.get("health", 0)) <= 0 and not bool(d.get("eliminated", false)) and live_mode
	var rival: bool = which == &"rival"
	_loadout.visible = rival and show_counts
	_held_label.visible = rival and show_counts
	if rival:
		_loadout.text = "Loadout %d" % int(d.get("loadout_count", 0))
		_held_label.text = "Held %d" % int(d.get("held_count", 0))
	fit_width()


## Grows the panel to its content (a Button's minimum size ignores its children).
func fit_width() -> void:
	var need: float = _margin.get_combined_minimum_size().x if is_inside_tree() else 0.0
	custom_minimum_size.x = maxf(base_width, ceilf(need))


func get_health_label() -> Label:
	return _health


func get_labels() -> Array[Label]:
	return [_name, _bounty, _health, _health_max, _down, _last, _loadout, _held_label]


func is_down_shown() -> bool:
	return _down.visible


func is_bounty_shown() -> bool:
	return _bounty.visible


func _row(parent: Control) -> HBoxContainer:
	var r: HBoxContainer = HBoxContainer.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_constant_override(&"separation", 6)
	r.alignment = BoxContainer.ALIGNMENT_BEGIN
	parent.add_child(r)
	return r


func _label(parent: Control, variation: StringName) -> Label:
	var l: Label = Label.new()
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l
