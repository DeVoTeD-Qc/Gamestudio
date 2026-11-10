# pass_cover.gd
# Purpose: kc-duel-ui. The Pass & Play cover screen (scenes/duel/PassCover.tscn, duel-mode.md §4.2): fully
#   opaque, over the whole match screen, between the two private Deploys (and before each player's first
#   Deploy with its mulligan). It hides every hand, the deck order and the face-down plays:
#     PASS TO <NAME>  ·  "Take the device. Tap when only you can see the screen."
#     Round 3 · Alex placed 3 orders (hidden)            <- public info only
#     "Round 2: you took column B ..."                     <- what just happened (public)
#     [ I'M DANA: SHOW MY HAND ]
#   The button is the only way through (Enter / Space too); a stray tap on the cover does nothing.
#   DuelMatch flow (duel-api.md §6): cover_needed(side, name) -> show_for(side, name, info) -> the
#   player taps -> accepted(side) -> the controller calls match.accept_cover(side).
# Usage: var cover := PassCover.instantiate(); screen.add_child(cover); cover.show_for(1, "Dana", {...})
# Dependencies: duel_widgets.gd, run_screen.gd builders, sfx_bank.gd.
# Author: UI/UX Agent (kc-duel-ui)
extends Control

signal accepted(side: int)

const W: GDScript = preload("res://scripts/ui/duel/duel_widgets.gd")
const RunScreen: GDScript = preload("res://scripts/ui/run/run_screen.gd")

var side: int = -1
var player_name: String = ""
var _title: Label = null
var _sub: Label = null
var _info: Label = null
var _last: Label = null
var _button: Button = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: ColorRect = ColorRect.new()
	bg.name = "Opaque"
	bg.color = Color("#0B0E11")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stripes: Control = Control.new()
	stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stripes)
	stripes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stripes.draw.connect(func() -> void:
		var s: Vector2 = stripes.size
		var x: float = -s.y
		while x < s.x:
			stripes.draw_line(Vector2(x, s.y), Vector2(x + s.y, 0), Color(1, 0.69, 0.13, 0.035), 18.0)
			x += 64.0)
	resized.connect(stripes.queue_redraw)
	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Column"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 14)
	center.add_child(col)
	var lock_row: HBoxContainer = HBoxContainer.new()
	lock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lock_row.add_theme_constant_override(&"separation", 8)
	col.add_child(lock_row)
	lock_row.add_child(W.Mark.new(&"lock", W.AMBER, 24))
	lock_row.add_child(W.label("HANDS HIDDEN", &"HudTag", 18, W.AMBER))
	_title = W.label("", &"TitleWordmark", 0)
	_title.name = "CoverTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)
	_sub = W.label("Take the device. Tap the button when only you can see the screen.", &"HudHeader", 20, W.FOG, true)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_sub)
	var info_panel: PanelContainer = W.panel(Color("#161B20"), W.PANEL_RIM, 10.0)
	col.add_child(info_panel)
	var ic: VBoxContainer = VBoxContainer.new()
	ic.add_theme_constant_override(&"separation", 6)
	info_panel.add_child(ic)
	_info = W.label("", &"UnitName", 18, W.FOG, true)
	_info.name = "CoverInfo"
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.add_child(_info)
	_last = W.label("", &"", 17, Color("#BFC7CE"), true)
	_last.name = "CoverLast"
	_last.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.add_child(_last)
	_button = RunScreen.make_button("", &"ReadyButton", 360)
	_button.name = "RevealButton"
	_button.add_to_group(&"tap_target")
	_button.custom_minimum_size.y = 80
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(accept)
	col.add_child(_button)
	resized.connect(_fit)
	_fit()
	if side < 0:
		hide()


func _fit() -> void:
	var w: float = minf(size.x - 32.0, 760.0)
	for c: Control in [_title, _sub, _info, _last]:
		if c != null:
			c.custom_minimum_size.x = w
	if _title != null:
		_title.add_theme_font_size_override(&"font_size", 44 if size.x < 700.0 else 60)


## Shows the cover for `p_side` (its player's name). info: {round, other_name, other_orders, last, mulligan}.
func show_for(p_side: int, p_name: String, info: Dictionary = {}) -> void:
	side = p_side
	player_name = p_name
	_title.text = "PASS TO %s" % p_name.to_upper()
	var parts: PackedStringArray = []
	parts.append("Round %d" % int(info.get("round", 1)))
	var other: String = String(info.get("other_name", ""))
	if other != "" and int(info.get("other_orders", -1)) >= 0:
		parts.append("%s placed %d order%s (hidden until the Reveal)" % [other, int(info["other_orders"]), "" if int(info["other_orders"]) == 1 else "s"])
	elif other != "":
		parts.append("%s deploys after you" % other)
	if bool(info.get("mulligan", false)):
		parts.append("you'll see your opening hand and may mulligan")
	_info.text = " · ".join(parts)
	_last.text = String(info.get("last", ""))
	_last.visible = _last.text != ""
	_button.text = "I'M %s: SHOW MY HAND" % p_name.to_upper()
	show()
	move_to_front()
	_button.grab_focus.call_deferred()


func accept() -> void:
	if not visible or side < 0:
		return
	var s: int = side
	hide()
	(load("res://scripts/fx/sfx_bank.gd") as GDScript).call(&"cue", &"click")
	accepted.emit(s)


func get_button() -> Button:
	return _button


func get_title_text() -> String:
	return _title.text
