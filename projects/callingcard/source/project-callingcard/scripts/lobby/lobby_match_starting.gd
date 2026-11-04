# lobby_match_starting.gd
# Purpose: Placeholder "Match starting..." screen (cc13). In the live game the real match would load
#   here; the demo counts down and goes back to the hub (where a saved Lobby Duel can be continued).
#   Generic wording only.
# Dependencies: SceneRouter, EventBus, Collection (only to mention a saved duel), hub_ui.gd.
# Author: Mechanics Developer Agent
extends Control

const DuelTheme: GDScript = preload("res://scripts/ui/duel_theme.gd")
const HubUi: GDScript = preload("res://scripts/hub/hub_ui.gd")

## Seconds before going back to the hub on its own (0 = only by the button).
static var auto_return_s: float = 4.0

var safe_area_override: Rect2 = Rect2()
var remaining_s: float = 0.0

var _margin: MarginContainer
var _title: Label
var _body: Label
var _count: Label
var _back: Button


func _ready() -> void:
	theme = DuelTheme.build()
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	remaining_s = auto_return_s
	var col: Node = get_node_or_null("/root/Collection")
	var saved: bool = col != null and col.has_saved_lobby_duel()
	_body.text = "Your match is ready." + (" Your quick duel is saved: continue it from the menu later." if saved else "")
	_update_count()
	EventBus.screen_shown.emit(&"match_starting")


func _process(delta: float) -> void:
	if remaining_s <= 0.0:
		return
	remaining_s -= delta
	_update_count()
	if remaining_s <= 0.0:
		back_to_hub()


func back_to_hub() -> void:
	remaining_s = 0.0
	var router: Node = get_node_or_null("/root/SceneRouter")
	if router != null:
		router.goto_route(&"hub")


func _update_count() -> void:
	_count.text = "This demo returns to the menu in %d" % ceili(remaining_s) if remaining_s > 0.0 else "This demo returns to the menu."


func _build() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.0784, 0.0863, 0.106)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin = MarginContainer.new()
	_margin.name = "SafeArea"
	add_child(_margin)
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	_margin.add_child(center)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override(&"separation", 16)
	center.add_child(col)
	_title = HubUi.label("StartingTitle", "MATCH STARTING...", &"InspectorName", HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_title)
	_body = HubUi.label("StartingBody", "", &"InspectorBody", HORIZONTAL_ALIGNMENT_CENTER)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 520
	col.add_child(_body)
	_count = HubUi.label("StartingCount", "", &"Caption", HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_count)
	_back = HubUi.button("BackButton", "BACK TO MENU", &"PrimaryButton", Vector2(260, 64))
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(back_to_hub)
	col.add_child(_back)


func _relayout() -> void:
	var m: Array[Vector2] = HubUi.safe_margins(self, safe_area_override)
	HubUi.apply_margins(_margin, m[0], m[1])


func get_key_controls() -> Dictionary:
	return {"StartingTitle": _title, "StartingBody": _body, "StartingCount": _count, "BackButton": _back}
