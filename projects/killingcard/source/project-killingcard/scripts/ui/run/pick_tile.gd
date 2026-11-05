# pick_tile.gd
# Purpose: A one-tap choice tile for the run screens (p11): a Button whose face is a column of
#   Labels (name, tag line, rules text, status) instead of a single text line. The whole tile is
#   the tap target, it takes keyboard / controller focus like any Button, and it grows to fit its
#   wrapped text (Button itself ignores children when it measures, so the tile keeps
#   custom_minimum_size.y in step with its content). Styling: theme variations PickTile /
#   PickTileSelected (hud_theme.tres); set_selected() switches them and the status line, so the
#   picked state never relies on colour alone.
# Usage:
#   var tile := PickTile.new()
#   tile.add_line("RECON DRONE", &"TileName")
#   tile.add_line("Streak 2", &"StreakLabel")
#   tile.add_line(item.text, &"", true)
#   tile.pressed.connect(...)
# Dependencies: hud_theme.tres variations.
# Author: UI/UX Agent (p11)
extends Button

## Holds the tile's labels (and any other content, e.g. a CardView holder).
var content: VBoxContainer = null
var selected: bool = false
## Smallest height (px) the tile keeps even when its text is short.
var min_height: float = 0.0
var _status: Label = null


func _init() -> void:
	theme_type_variation = &"PickTile"
	focus_mode = Control.FOCUS_ALL
	content = VBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override(&"separation", 4)
	add_child(content)
	content.minimum_size_changed.connect(_sync_min_size)


## Adds a Label to the tile face. variation "" = body text.
func add_line(text: String, variation: StringName = &"", wrap: bool = true) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label


## Adds an expanding spacer, so following lines sit at the bottom of the tile.
func add_spacer() -> void:
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)


## The bottom status line ("TAP TO PICK" / "PICKED"); set_selected keeps it current.
func add_status(text: String) -> Label:
	_status = add_line(text, &"HudAccent", false)
	return _status


func set_selected(value: bool, picked_text: String = "PICKED", unpicked_text: String = "") -> void:
	selected = value
	theme_type_variation = &"PickTileSelected" if value else &"PickTile"
	set_pressed_no_signal(value)
	if _status != null:
		if value:
			_status.text = picked_text
		elif unpicked_text != "":
			_status.text = unpicked_text


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_READY:
		_fit()


func _margins() -> Vector4:
	var sb: StyleBox = get_theme_stylebox(&"normal")
	if sb == null:
		return Vector4.ZERO
	return Vector4(sb.get_margin(SIDE_LEFT), sb.get_margin(SIDE_TOP), sb.get_margin(SIDE_RIGHT), sb.get_margin(SIDE_BOTTOM))


func _fit() -> void:
	if content == null:
		return
	var m: Vector4 = _margins()
	content.position = Vector2(m.x, m.y)
	content.size = Vector2(maxf(0.0, size.x - m.x - m.z), maxf(0.0, size.y - m.y - m.w))
	_sync_min_size()


func _sync_min_size() -> void:
	var m: Vector4 = _margins()
	var need: float = maxf(min_height, content.get_combined_minimum_size().y + m.y + m.w)
	if absf(custom_minimum_size.y - need) > 0.5:
		custom_minimum_size.y = need
