# setup_screen.gd
# Purpose: CardZone Match setup (cz13, spec §16.3 S1-S2). Three rows of choices, each a row of
#   big segmented buttons (the chosen one is a light plate with a check mark):
#     OPPONENT     ROOKIE AI · VETERAN AI · HOT-SEAT (cz14: two players, one device)
#     FIRST TURN   ME · OPPONENT · ALTERNATE (swap from the last match on this device)
#     ROUTE        A · B · C · PICK FOR ME (A, B, C in rotation per match on this device)
#   Under the rows: what the chosen opponent and route mean (the route's gas order, from the
#   Zone deck), and "Next match: route B, you take the first turn." START MATCH leaves a launch
#   request (setup_launch.gd) and goes to the match screen, where the drop happens as cz11 does
#   it. BACK returns to the Title. The last choices are remembered on this device.
#   A saved match is replaced by a new one: a note says so before START.
#   cz14 hot-seat (spec §16.3): FIRST TURN is fixed (Player 1 is P1: the row is greyed and a tap
#   says why) and the ROUTE row becomes "P2 PICKS ROUTE": Player 2 chooses it (S2).
# Dependencies: setup_launch.gd, setup_ui.gd, dev_panel_overrides.gd, CardDB, MatchStore,
#   SceneRouter, EventBus.
# Author: UI/UX Agent (cz13)
extends Control

const SetupLaunch: GDScript = preload("res://scripts/ui/setup_launch.gd")
const SetupUI: GDScript = preload("res://scripts/ui/setup_ui.gd")
const DevOverrides: GDScript = preload("res://scripts/ui/dev_panel_overrides.gd")

## [choice key, row label, [[value, button text], ...]]
const ROWS: Array = [
	["opponent", "OPPONENT", [["rookie", "ROOKIE AI"], ["veteran", "VETERAN AI"], ["hotseat", "HOT-SEAT"]]],
	["first", "FIRST TURN", [["me", "ME"], ["opponent", "OPPONENT"], ["alternate", "ALTERNATE"]]],
	["route", "ROUTE", [["A", "A"], ["B", "B"], ["C", "C"], ["rotate", "PICK FOR ME"]]],
]
const OPPONENT_TEXT: Dictionary = {
	"rookie": "Rookie: plays straight and greedy. Good for a first match.",
	"veteran": "Veteran: plans whole turns and reads the board. A real fight.",
	"hotseat": "Hot-seat: two players, one device. Pass it when the screen says so: a cover hides each player's cards from the other.",
}

## Tests / screenshots: the safe rect in logical px (empty = from the display).
var safe_area_override: Rect2 = Rect2()
## The choices on screen: {opponent, first, route}.
var choices: Dictionary = {}
var last_notice: String = ""

var _safe: MarginContainer
var _buttons: Dictionary = {}   # "key:value" -> Button, plus &"start", &"back"
var _about: Label
var _next: Label
var _notice: Label
var _dev_tag: Label
var _heading: Label
var _row_labels: Dictionary = {}  # cz14: "route" -> its row label


func _ready() -> void:
	theme = SetupUI.build_theme()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#2B1840")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_safe = MarginContainer.new()
	_safe.name = "SafeArea"
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override(&"separation", 8)
	_safe.add_child(col)
	# Header: BACK · MATCH SETUP · dev tag
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 16)
	col.add_child(head)
	var back: Button = SetupUI.button("BACK", &"Button")
	back.name = "BackButton"
	back.custom_minimum_size.x = 120.0
	back.pressed.connect(_on_back)
	head.add_child(back)
	_buttons[&"back"] = back
	_heading = SetupUI.label("MATCH SETUP", &"ShellHeading")
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_heading)
	_dev_tag = SetupUI.label("DEV SETTINGS ACTIVE", &"ShellTag")
	_dev_tag.name = "DevTag"
	_dev_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_dev_tag)
	# Choice rows
	choices = SetupLaunch.last_choices()
	for r: Array in ROWS:
		col.add_child(_choice_row(String(r[0]), String(r[1]), r[2]))
	_about = SetupUI.label("", &"ShellMuted", true)
	_about.name = "AboutLabel"
	col.add_child(_about)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	# Footer: next-match line and notices · START MATCH
	var foot: HBoxContainer = HBoxContainer.new()
	foot.add_theme_constant_override(&"separation", 16)
	col.add_child(foot)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(texts)
	_next = SetupUI.label("", &"ShellBody", true)
	_next.name = "NextLabel"
	texts.add_child(_next)
	_notice = SetupUI.label("", &"ShellWarn", true)
	_notice.name = "NoticeLabel"
	texts.add_child(_notice)
	var start: Button = SetupUI.button("START MATCH", &"DockButton")
	start.name = "StartButton"
	start.custom_minimum_size = Vector2(240, SetupUI.TAP_PX)
	start.size_flags_vertical = Control.SIZE_SHRINK_END
	start.pressed.connect(_on_start)
	foot.add_child(start)
	_buttons[&"start"] = start
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	_refresh()
	start.grab_focus.call_deferred()
	EventBus.screen_shown.emit(&"match_setup")
	print("MatchSetup: ready")


func get_button(key: Variant) -> Button:
	return _buttons.get(key)


## The button for a choice ("route", "B").
func get_choice_button(key: String, value: String) -> Button:
	return _buttons.get("%s:%s" % [key, value])


func get_next_text() -> String:
	return _next.text


func get_text_labels() -> Array[Label]:
	var out: Array[Label] = []
	for l: Node in find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			out.append(l)
	return out


func _choice_row(key: String, text: String, opts: Array) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row_%s" % key
	row.add_theme_constant_override(&"separation", 8)
	var l: Label = SetupUI.label(text, &"CaptionStrong")
	l.custom_minimum_size.x = 150.0
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	_row_labels[key] = l
	for o: Array in opts:
		var value: String = o[0]
		var b: Button = SetupUI.button(o[1], &"SegOff")
		b.name = "Choice_%s_%s" % [key, value]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 0.0
		b.pressed.connect(func() -> void: _on_choice(key, value))
		row.add_child(b)
		_buttons["%s:%s" % [key, value]] = b
	return row


func _on_choice(key: String, value: String) -> void:
	if key == "first" and _hotseat():
		_say("Hot-seat: Player 1 always takes the first turn; Player 2 picks the route and drops first.")
		return
	choices[key] = value
	_say("")
	_refresh()


func _refresh() -> void:
	for r: Array in ROWS:
		var key: String = r[0]
		for o: Array in r[2]:
			var b: Button = _buttons["%s:%s" % [key, o[0]]]
			var available: bool = not (key == "first" and _hotseat())  # cz14: S1 fixes P1
			SetupUI.set_seg(b, available and String(choices.get(key, "")) == String(o[0]), available)
	(_row_labels["route"] as Label).text = "P2 PICKS ROUTE" if _hotseat() else "ROUTE"
	var about: PackedStringArray = [OPPONENT_TEXT.get(String(choices["opponent"]), "")]
	if _hotseat():
		about.append("Player 2: pick the route. " + _route_text(String(choices["route"])))
	else:
		about.append(_route_text(String(choices["route"])))
	_about.text = "\n".join(about)
	_next.text = SetupLaunch.preview_text(choices)
	_dev_tag.visible = DevOverrides.is_active()
	if last_notice == "":
		var saved: bool = MatchStore.has_saved_match()
		_notice.text = "Starting a new match replaces your saved match." if saved else ""
	_notice.visible = _notice.text != ""


## "Route B: gas closes Docks, Farmstead, … · supply drops land in …" from the Zone deck.
func _route_text(choice: String) -> String:
	if choice == "rotate":
		return "Pick for me: routes A, B and C take turns, one per match."
	var r: int = MatchState.route_from_letter(choice)
	var closes: PackedStringArray = []
	for z: ZoneCardData in CardDB.all_zone_cards():
		var a: AreaData = z.close_for(r)
		if a != null:
			closes.append(a.display_name)
	if closes.is_empty():
		return "Route %s." % choice
	return "Route %s: the gas closes %s, in that order." % [choice, ", ".join(closes)]


func _hotseat() -> bool:
	return String(choices.get("opponent", "")) == "hotseat"


func _say(text: String) -> void:
	last_notice = text
	_notice.text = text
	_notice.visible = text != ""
	if text == "":
		_refresh()


func _on_start() -> void:
	var why: String = SetupLaunch.why_not(choices)
	if why != "":
		_say(why)
		return
	SetupLaunch.request_new(choices)
	SceneRouter.goto_route(&"match")


func _on_back() -> void:
	SetupLaunch.clear_pending()
	SceneRouter.goto_route(&"title")


func _relayout() -> void:
	SetupUI.apply_margins(_safe, get_viewport_rect().size, safe_area_override)
