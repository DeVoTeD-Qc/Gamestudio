# operator_panel.gd
# Purpose: Operator panel (bottom-left): Operator name, zone, Firepower/Armor,
#   a segmented streak meter next to the streak number (placeholder for the StreakArc of p14; taller
#   segments mark killstreak thresholds), 3 Perk slots, and two rows of tap buttons:
#   Secondary / Lethal / Tactical, then the 3 killstreaks (locked until earned,
#   threshold printed on the button so nothing is hover-only).
#   Buttons only emit signals; what they do arrives with p05/p09.
#   p09: the panel itself is the Operator's handle: tap = select it (place it in Round 1 or after
#   a respawn, or Rotate it), drag = drag it to a lane, long-press / right-click = inspect.
#   The buttons keep their own taps.
#   Compact (phone) profile: narrower info column and 64x64 buttons.
# Dependencies: hud_theme.tres variations (HudButton, KillstreakButton, StreakSegment...).
# Author: UI/UX Agent
extends PanelContainer

signal ability_pressed(ability_id: StringName)
signal killstreak_pressed(killstreak_id: StringName)
signal operator_tapped
signal operator_inspected
signal operator_drag_started(pos: Vector2)
signal operator_drag_moved(pos: Vector2)
signal operator_drag_ended(pos: Vector2)

const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")

const BUTTON_SIZE: Vector2 = Vector2(76, 72)
const BUTTON_SIZE_COMPACT: Vector2 = Vector2(64, 64)
const INFO_WIDTH: float = 170.0
const INFO_WIDTH_COMPACT: float = 140.0
const PERK_SIZE: float = 26.0

var compact: bool = false
var selected: bool = false
var _gesture: RefCounted = null

@onready var _caption: Label = %CaptionLabel
@onready var _name: Label = %NameLabel
@onready var _stats: Label = %StatsLabel
@onready var _streak_value: Label = %StreakValue
@onready var _segments: HBoxContainer = %StreakSegments
@onready var _perk_row: HBoxContainer = %PerkRow
@onready var _buttons: GridContainer = %Buttons
@onready var _info: VBoxContainer = %Info


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(&"tap_target")
	_gesture = PressGesture.new(self)
	_gesture.tapped.connect(func(_p: Vector2) -> void: operator_tapped.emit())
	_gesture.long_pressed.connect(func(_p: Vector2) -> void: operator_inspected.emit())
	_gesture.drag_started.connect(func(p: Vector2) -> void: operator_drag_started.emit(p))
	_gesture.drag_moved.connect(func(p: Vector2) -> void: operator_drag_moved.emit(p))
	_gesture.drag_ended.connect(func(p: Vector2) -> void: operator_drag_ended.emit(p))
	_pass_through()


## Everything but the buttons passes taps up to the panel (the Operator handle).
func _pass_through() -> void:
	for n: Node in find_children("*", "Control", true, false):
		if not n is BaseButton and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			(n as Control).mouse_filter = Control.MOUSE_FILTER_PASS


func _gui_input(event: InputEvent) -> void:
	if _gesture.handle(event):
		accept_event()


func set_selected(value: bool) -> void:
	selected = value
	theme_type_variation = &"OperatorSelected" if selected else &"HudPanelDark"


func set_compact(value: bool) -> void:
	compact = value
	_info.custom_minimum_size.x = INFO_WIDTH_COMPACT if compact else INFO_WIDTH
	_info.get_parent().add_theme_constant_override(&"separation", 8 if compact else 12)
	# Key number floor is 20 px (14.4 pt on the phone); 20 keeps "FP 3  AR 5/7" in 140 px.
	_stats.add_theme_font_size_override(&"font_size", 20 if compact else 22)
	for b: Node in _buttons.get_children():
		(b as Control).custom_minimum_size = _button_size()


## Labels whose whole text must stay visible.
func get_important_labels() -> Array[Label]:
	return [_caption, _name, _stats, _streak_value]


func set_operator(snapshot: Dictionary) -> void:
	var op: Dictionary = snapshot.get("operator", {})
	_caption.text = "OPERATOR · %s" % op.get("zone", "OFF BOARD")
	_name.text = String(op.get("name", ""))
	_stats.text = "FP %d  AR %d/%d" % [op.get("fp", 0), op.get("armor", 0), op.get("armor_max", 0)]
	var streak: int = snapshot.get("streak", 0)
	_streak_value.text = str(streak)
	var thresholds: Array[int] = []
	for ks: Dictionary in snapshot.get("killstreaks", []):
		thresholds.append(int(ks.get("threshold", 0)))
	_build_segments(streak, int(snapshot.get("streak_max", 5)), thresholds)
	_build_perks(snapshot.get("perks", []), int(snapshot.get("perk_slots", 3)))
	_build_buttons(snapshot.get("abilities", []), snapshot.get("killstreaks", []))
	_pass_through()


func get_buttons() -> Array[Node]:
	return _buttons.get_children()


func _build_segments(streak: int, count: int, thresholds: Array[int]) -> void:
	_clear(_segments)
	for i: int in range(1, count + 1):
		var seg: Panel = Panel.new()
		seg.theme_type_variation = &"StreakSegmentLit" if i <= streak else &"StreakSegment"
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_vertical = Control.SIZE_SHRINK_END
		seg.custom_minimum_size = Vector2(0, 18 if i in thresholds else 10)
		_segments.add_child(seg)


func _build_perks(perks: Array, slots: int) -> void:
	for child: Node in _perk_row.get_children():
		if child is Panel:
			_perk_row.remove_child(child)
			child.queue_free()
	for i: int in slots:
		var slot: Panel = Panel.new()
		slot.theme_type_variation = &"PerkSlot"
		slot.custom_minimum_size = Vector2(PERK_SIZE, PERK_SIZE)
		# Earned perks get an icon (p13) and tap-to-inspect (p09); empty slots stay outlined.
		slot.set_meta(&"perk", perks[i] if i < perks.size() else &"")
		_perk_row.add_child(slot)


func _build_buttons(abilities: Array, killstreaks: Array) -> void:
	_clear(_buttons)
	for ability: Dictionary in abilities:
		var b: Button = _make_button("%s\n%s" % [ability.get("name", ""), ability.get("state", "")], &"HudButton")
		var ability_id: StringName = ability.get("id", &"")
		b.pressed.connect(func() -> void: ability_pressed.emit(ability_id))
		_buttons.add_child(b)
	for ks: Dictionary in killstreaks:
		var earned: bool = ks.get("earned", false)
		var b: Button = _make_button("%s\n%s" % [ks.get("name", ""),
				"CALL IN" if earned else "AT %d" % int(ks.get("threshold", 0))], &"KillstreakButton")
		b.disabled = not earned
		var ks_id: StringName = ks.get("id", &"")
		b.pressed.connect(func() -> void: killstreak_pressed.emit(ks_id))
		_buttons.add_child(b)


func _make_button(text: String, variation: StringName) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = _button_size()
	b.add_to_group(&"tap_target")
	b.focus_mode = Control.FOCUS_ALL
	return b


func _button_size() -> Vector2:
	return BUTTON_SIZE_COMPACT if compact else BUTTON_SIZE


func _clear(node: Node) -> void:
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()
