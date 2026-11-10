# operator_panel.gd
# Purpose: Operator panel (bottom-left): Operator name, zone, Firepower/Armor,
#   a segmented streak meter next to the streak number (placeholder for the StreakArc of p14; taller
#   segments mark killstreak thresholds), 3 Perk slots, and a row of tap buttons: the 3
#   killstreaks (locked until earned, threshold printed on the button so nothing is hover-only).
#   kc-loadout-cut: the Secondary / Lethal / Tactical buttons are gone.
#   Buttons only emit signals. f02: the entries come from the engine (match_snapshot.item_entry):
#   the second line shows the state (USED, NO OP, AT 3, CALL IN), a blocked item's
#   button is disabled and a tap on it still emits its signal so the controller can say why;
#   the item being targeted stays pressed (set_selected_item). p14: StreakArc replaces the
#   segment row (configure() on every snapshot; FeedbackDirector animates it during Reveal).
#   p09: the panel itself is the Operator's handle: tap = select it (place it in Round 1 or after
#   a respawn, or Rotate it), drag = drag it to a lane, long-press / right-click = inspect.
#   The buttons keep their own taps.
#   Compact (phone) profile: narrower info column and 64x64 buttons.
# Dependencies: hud_theme.tres variations (HudButton, KillstreakButton, StreakSegment...).
# Author: UI/UX Agent
extends PanelContainer

signal killstreak_pressed(killstreak_id: StringName)
signal operator_tapped
signal operator_inspected
signal operator_drag_started(pos: Vector2)
signal operator_drag_moved(pos: Vector2)
signal operator_drag_ended(pos: Vector2)

const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")

const BUTTON_SIZE: Vector2 = Vector2(64, 64)
const BUTTON_SIZE_COMPACT: Vector2 = Vector2(64, 64)
const INFO_WIDTH: float = 170.0
const INFO_WIDTH_COMPACT: float = 140.0
const PERK_SIZE: float = 26.0
## Perk patch texture width (px): 26 canvas px at up to ~3.7 screen px each.
const PERK_PATCH_PX: int = 96
## Text on a selected (filled) item button: the HUD's background ink.
const SELECTED_TEXT: Color = Color(0.0705882, 0.0862745, 0.101961, 1)

var compact: bool = false
var selected: bool = false
## &"all", &"operator" or &"streak" (set_section).
var section: StringName = &"all"
var _gesture: RefCounted = null
## Item id whose button shows as pressed (being targeted), &"" = none.
var selected_item: StringName = &""

@onready var _caption: Label = %CaptionLabel
@onready var _name: Label = %NameLabel
@onready var _stats: Label = %StatsLabel
@onready var _streak_value: Label = %StreakValue
@onready var _arc: Control = %StreakArc
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
	# kc-board2: in the STREAK flyout the panel is only the killstreak tiles, not the Operator handle.
	if section == &"streak":
		return
	if _gesture.handle(event):
		accept_event()


## kc-board2 flyouts (board-layout-v2.md §3): &"operator" shows the Operator's info (name, FP / AR,
## position, streak, perks), &"streak" the streak meter and the killstreak tiles,
## &"all" everything (the v1 rail panel).
func set_section(value: StringName) -> void:
	section = value
	var info_only: bool = value == &"operator"
	var streak_only: bool = value == &"streak"
	_buttons.visible = not info_only
	_buttons.columns = 3
	for n: Control in [_caption, _name, _stats, _perk_row]:
		n.visible = not streak_only
	_info.visible = true


func set_selected(value: bool) -> void:
	selected = value
	theme_type_variation = &"OperatorSelected" if selected else &"HudPanelDark"


func set_compact(value: bool) -> void:
	compact = value
	_info.get_parent().add_theme_constant_override(&"separation", 6 if compact else 8)
	# Key number floor is 20 px (14.4 pt on the phone).
	_stats.add_theme_font_size_override(&"font_size", 20 if compact else 22)
	for b: Node in _buttons.get_children():
		(b as Control).custom_minimum_size = _button_size()


## kc-board: the panel sits in the left rail; 3 buttons per row when the rail is wide enough
## (phone 844x390), else 2 (desktop's 202 px rail, notched phones).
func fit_rail_width(width: float) -> void:
	var sb: StyleBox = get_theme_stylebox(&"panel")
	var inner: float = width - (sb.get_minimum_size().x if sb != null else 16.0)
	var sep: int = _buttons.get_theme_constant(&"h_separation")
	var bw: float = _button_size().x
	_buttons.columns = 3 if inner >= 3.0 * bw + 2.0 * sep else 2


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
	_arc.configure(int(snapshot.get("streak_max", 5)), thresholds, streak)
	_build_perks(snapshot.get("perks", []), int(snapshot.get("perk_slots", 3)))
	_build_buttons(snapshot.get("killstreaks", []))
	_pass_through()


func get_buttons() -> Array[Node]:
	return _buttons.get_children()


## The StreakArc (p14) that FeedbackDirector animates.
func get_streak_arc() -> Control:
	return _arc


## Shows the item being targeted as pressed (&"" = none).
func set_selected_item(item_id: StringName) -> void:
	selected_item = item_id
	for b: Node in _buttons.get_children():
		var button: Button = b as Button
		var on: bool = item_id != &"" and b.get_meta(&"item_id", &"") == item_id
		button.set_pressed_no_signal(on)
		_mark_selected(button, on)


## The theme's pressed style is only a shade darker than normal, so the item being targeted is
## filled with its own border colour (amber / cyan) and dark text. Same margins and font as the
## theme style, so the button keeps its size.
func _mark_selected(button: Button, on: bool) -> void:
	for st: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		button.remove_theme_stylebox_override(st)
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		button.remove_theme_color_override(c)
	if not on:
		return
	var base: StyleBox = button.get_theme_stylebox(&"pressed")
	if not base is StyleBoxFlat:
		return
	var fill: StyleBoxFlat = (base as StyleBoxFlat).duplicate()
	fill.bg_color = fill.border_color
	for st: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		button.add_theme_stylebox_override(st, fill)
	var dark: Color = SELECTED_TEXT
	for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		button.add_theme_color_override(c, dark)


## The button of an item id, or null.
func get_item_button(item_id: StringName) -> Button:
	for b: Node in _buttons.get_children():
		if b.get_meta(&"item_id", &"") == item_id:
			return b as Button
	return null


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
		var perk: StringName = StringName(perks[i]) if i < perks.size() else &""
		slot.set_meta(&"perk", perk)
		# k-art3: an earned perk shows its patch, masked to a circle inside the ring.
		var patch: TextureRect = CardArt.perk_patch(perk, PERK_PATCH_PX) if perk != &"" else null
		if patch != null:
			patch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 1)
			slot.add_child(patch)
		elif perk == &"":
			# kc-ui-wire2: an empty slot shows the kit's faint perk-slot mark (ico_perk_slot); else outlined only.
			var mark: TextureRect = UiKit.icon_rect(&"perk_slot", PERK_SIZE * 0.6, Color(1, 1, 1, 0.35))
			if mark != null:
				slot.add_child(mark)
				mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
		_perk_row.add_child(slot)


func _build_buttons(killstreaks: Array) -> void:
	_clear(_buttons)
	for ks: Dictionary in killstreaks:
		var earned: bool = ks.get("earned", false)
		var ks_id: StringName = ks.get("id", &"")
		var state_text: String = String(ks.get("state", "CALL IN" if earned else "AT %d" % int(ks.get("threshold", 0))))
		var b: Button = _make_button("%s\n%s" % [ks.get("name", ""), state_text], &"KillstreakButton")
		_wire(b, ks_id, not bool(ks.get("ready", earned)), String(ks.get("reason", "")),
				func() -> void: killstreak_pressed.emit(ks_id))
		_buttons.add_child(b)
	set_selected_item(selected_item)


## Tap -> emit. A disabled button still reports a tap (so the controller can toast the reason).
func _wire(b: Button, item_id: StringName, blocked: bool, reason: String, emit: Callable) -> void:
	b.set_meta(&"item_id", item_id)
	b.toggle_mode = true
	b.disabled = blocked
	b.tooltip_text = reason
	b.pressed.connect(emit)
	b.gui_input.connect(func(e: InputEvent) -> void:
		if b.disabled and e is InputEventMouseButton and not e.pressed \
				and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			emit.call())


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
