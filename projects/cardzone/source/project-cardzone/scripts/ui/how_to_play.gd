# how_to_play.gd
# Purpose: "How to play" (cz-clarity): seven short bullets and an annotated screenshot of the match
#   screen. Shown once before the first match (MatchShell, SetupPrefs [coach] how_to_play), and on
#   demand from HELP on the match screen (INFO with nothing selected) and the pause menu (HOW TO
#   PLAY). CLOSE, a tap on the dimmed backdrop, or Esc closes it. The bullets are static so the
#   pause menu and the tests can use them too.
# Dependencies: match_theme.gd variations (InspectorPanel, InspectorTitle, InspectorBody, DockButton),
#   setup_prefs.gd, assets/ui/how_to_play.webp (optional: the bullets work without it).
# Author: UI/UX Agent (cz-clarity)
extends Control

signal closed

const SetupPrefs: GDScript = preload("res://scripts/ui/setup_prefs.gd")
const IMAGE_PATH: String = "res://assets/ui/how_to_play.webp"
const SECTION: String = "coach"
const KEY: String = "how_to_play"
## [title, text]: the whole game in seven lines.
const BULLETS: Array = [
	["GOAL", "Be the last one standing. You have 5 health and every Hit costs 1. The match lasts 14 rounds at most, and the gas closes areas as it goes."],
	["YOUR TURN", "You draw 5 cards. Tap a card, then PLAY: it gives Move (boot icon) and Search (magnifier icon) for this turn."],
	["MOVE AND LOOT", "Tap a neighbouring area, then MOVE HERE (1 Move). Tap your own area, then LOOT: spend Search to take a gun, armour or a kit."],
	["FIGHT", "A gun you play or loot sits in your played row. Tap it there, then FIRE. Range 0 reaches your own area; range 1 also the next one."],
	["END TURN", "Keep up to 2 hand cards for next turn. Everything else goes under your deck and comes round again, loot included."],
	["DEFEND", "Cards with a shield in your NEXT HAND block damage when you're shot. Tap the DECK row to see your next hand."],
	["READ ANYTHING", "Long-press (phone) or right-click (computer) any card, area, panel or button to see what it is and what it gives you."],
]

var _scrim: ColorRect
var _panel: PanelContainer
var _image: TextureRect
var _bullets: VBoxContainer
var _scroll: ScrollContainer
var _ok: Button
var _title: Label


static func is_seen() -> bool:
	return bool(SetupPrefs.get_value(SECTION, KEY, false))


static func mark_seen() -> void:
	SetupPrefs.set_value(SECTION, KEY, true)


## The bullets as one text (pause menu, tests).
static func as_text() -> String:
	var out: PackedStringArray = []
	for b: Array in BULLETS:
		out.append("%s  %s" % [b[0], b[1]])
	return "\n".join(out)


static func image() -> Texture2D:
	return load(IMAGE_PATH) as Texture2D if ResourceLoader.exists(IMAGE_PATH) else null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_scrim = ColorRect.new()
	_scrim.name = "Scrim"
	_scrim.color = Color(0.05, 0.02, 0.08, 0.86)
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			close())
	add_child(_scrim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "HowPanel"
	_panel.theme_type_variation = &"InspectorPanel"
	center.add_child(_panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	_panel.add_child(col)
	_title = Label.new()
	_title.name = "HowTitle"
	_title.text = "HOW TO PLAY"
	_title.theme_type_variation = &"InspectorTitle"
	col.add_child(_title)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	_image = TextureRect.new()
	_image.name = "HowImage"
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_image.texture = image()
	row.add_child(_image)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_scroll)
	_bullets = VBoxContainer.new()
	_bullets.name = "HowBullets"
	_bullets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bullets.add_theme_constant_override(&"separation", 6)
	_scroll.add_child(_bullets)
	for i: int in BULLETS.size():
		var l: Label = Label.new()
		l.name = "Bullet_%d" % i
		l.theme_type_variation = &"InspectorBody"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text = "%d. %s: %s" % [i + 1, BULLETS[i][0], BULLETS[i][1]]
		_bullets.add_child(l)
	_ok = Button.new()
	_ok.name = "HowClose"
	_ok.text = "GOT IT"
	_ok.theme_type_variation = &"DockButton"
	_ok.custom_minimum_size = Vector2(200, 64)
	_ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	_ok.pressed.connect(close)
	col.add_child(_ok)


func _ready() -> void:
	resized.connect(_fit)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"cancel"):
		close()
		get_viewport().set_input_as_handled()


## Opens the sheet. first = shown before the first match (the button says PLAY).
func open(first: bool = false) -> void:
	_ok.text = "LET'S PLAY" if first else "GOT IT"
	visible = true
	_fit()
	_scroll.scroll_vertical = 0
	mark_seen()
	if is_inside_tree():
		(func() -> void: if is_instance_valid(_ok) and _ok.is_inside_tree(): _ok.grab_focus()).call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func get_close_button() -> Button:
	return _ok


func get_bullet_labels() -> Array[Label]:
	var out: Array[Label] = []
	for c: Node in _bullets.get_children():
		out.append(c as Label)
	return out


func has_image() -> bool:
	return _image.texture != null


func _fit() -> void:
	var avail: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1168, 540)
	# Clear of notches and the home bar (landscape phones inset ~47 pt at the sides, ~21 pt below).
	var w: float = minf(1180.0, avail.x - 150.0)
	var h: float = minf(640.0, avail.y - 64.0)
	_panel.custom_minimum_size = Vector2(w, h)
	var inner_h: float = h - 24.0 - _title.get_combined_minimum_size().y - 64.0 - 24.0
	if _image.texture != null:
		var tex: Vector2 = _image.texture.get_size()
		var iw: float = floorf(minf(w * 0.46, inner_h * tex.x / maxf(tex.y, 1.0)))
		_image.custom_minimum_size = Vector2(iw, floorf(iw * tex.y / maxf(tex.x, 1.0)))
		_image.visible = true
	else:
		_image.visible = false
	_scroll.custom_minimum_size = Vector2(0, maxf(120.0, inner_h))
