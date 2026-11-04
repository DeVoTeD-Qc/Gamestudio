# consent_prompt.gd
# Adapted from Killstreak scripts/survey/consent_screen.gd (the wording rules; built in code here).
# Purpose: Playtest consent prompt (cc16). An overlay PlaytestLog opens over the first screen of a
#   launch while the tester has not answered. Explains in plain words what the anonymous log holds
#   and asks yes / no. Default is off: closing without YES keeps logging off. The answer is
#   remembered on this device; the hub's PLAYTEST screen can turn logging on or off later.
# Dependencies: PlaytestLog (or plog for tests), duel_theme.gd, hub_ui.gd.
# Author: Data Scientist Agent
extends CanvasLayer

const DuelTheme: GDScript = preload("res://scripts/ui/duel_theme.gd")
const HubUi: GDScript = preload("res://scripts/hub/hub_ui.gd")

const TITLE_TEXT: String = "HELP US TEST BANNER WALL?"
const BODY_TEXT: String = "With your OK, this demo keeps an anonymous log of how you play: screens, duels, cards, album visits and timings, plus your survey answers. It stays on this device. No names, accounts or location, and nothing is sent. At the end, open PLAYTEST in the hub, answer 4 quick questions and press Download log to send us the file yourself. You can stop and delete the log there at any time."

## Emitted once with the tester's answer, right before the prompt frees itself.
signal answered(given: bool)

## The PlaytestLog to answer to (tests pass their own); null = the autoload.
var plog: Node = null

var _root: Control
var _yes: Button
var _no: Button
var _session: Label


func _ready() -> void:
	layer = 90
	if plog == null:
		plog = get_node_or_null("/root/PlaytestLog")
	_build()
	print("ConsentPrompt: ready")


## YES (true) turns logging on, NO (false) keeps it off. Either answer is remembered.
func answer(given: bool) -> void:
	if plog != null:
		plog.set_consent(given)
	answered.emit(given)
	queue_free()


func get_button(given: bool) -> Button:
	return _yes if given else _no


func get_root() -> Control:
	return _root


func _build() -> void:
	_root = Control.new()
	_root.name = "ConsentRoot"
	_root.theme = DuelTheme.build()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.72)
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "SafeArea"
	_root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m: Array[Vector2] = HubUi.safe_margins(_root)
	HubUi.apply_margins(margin, m[0], m[1])
	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	margin.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ConsentPanel"
	panel.theme_type_variation = &"InspectorPanel"
	panel.custom_minimum_size = Vector2(minf(760.0, _root.get_viewport_rect().size.x - m[0].x - m[1].x), 0)
	center.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override(&"separation", 10 if HubUi.is_compact(_root) else 16)
	panel.add_child(col)
	col.add_child(HubUi.label("ConsentTitle", TITLE_TEXT, &"InspectorHeading"))
	var body: Label = HubUi.label("ConsentBody", BODY_TEXT, &"InspectorBody")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ButtonRow"
	row.add_theme_constant_override(&"separation", 12)
	col.add_child(row)
	_no = HubUi.button("NoButton", "NO THANKS", &"ActionButton")
	_no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_no.pressed.connect(answer.bind(false))
	row.add_child(_no)
	_yes = HubUi.button("YesButton", "YES, LOG MY SESSION", &"PrimaryButton")
	_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_yes.pressed.connect(answer.bind(true))
	row.add_child(_yes)
	_session = HubUi.label("SessionLabel", "", &"Caption")
	if plog != null:
		_session.text = "Anonymous session %s · log format v%d" % [plog.session_id, plog.SCHEMA_VERSION]
	col.add_child(_session)
