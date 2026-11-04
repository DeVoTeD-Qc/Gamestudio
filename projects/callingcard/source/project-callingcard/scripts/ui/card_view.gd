# card_view.gd
# Purpose: One calling card drawn as a 4:1 banner (art direction §2) for the wall, the hand and
#   the inspector. Layout (containers only):
#     [S] [T  name ............] [S]      T top-left (faces up), B bottom-right (faces down),
#     [ ] [trait  clearance   B] [ ]      S on both short ends (faces the side neighbours).
#   Compact (phone) cards hide the name and show values, Clearance pips and the trait mark only
#   (plan §7); the full text lives in the inspector.
#   Ownership is never color alone: player cards get a SOLID corner tab, rival cards a NOTCHED
#   tab, plus an owner-colored inner outline. A Signature card gets a pale-gold ribbon.
# Hooks (cc14 art kit, set once at startup, e.g. from an art autoload):
#   CardView.art_factory  : Callable(card: Dictionary) -> Control  - poster art filling the card.
#   CardView.icon_factory : Callable(icon_id: StringName) -> Texture2D - e.g. &"trait_veteran".
#   Frames come from the theme variations CardFrameC1..C4 / CardFrameShowcase.
#   Until set, a seeded duotone placeholder and two-letter trait marks are drawn here.
# Dependencies: wall_palette.gd, card_text.gd.
# Author: UI/UX Agent (cc07)
extends Control

const Palette: GDScript = preload("res://scripts/ui/wall_palette.gd")
const CardText: GDScript = preload("res://scripts/ui/card_text.gd")

static var art_factory: Callable = Callable()
static var icon_factory: Callable = Callable()

const TAB_SIZE: float = 16.0

var card: Dictionary = {}
## &"player", &"rival" or &"" (no owner: album, inspector of an unplaced card).
var owner_side: StringName = &""
var is_signature: bool = false
var face_down: bool = false
var compact: bool = false:
	set(v):
		compact = v
		_refresh_visibility()

@onready var _art: Control = %Art
@onready var _frame: PanelContainer = %Frame
@onready var _face_down: PanelContainer = %FaceDown
@onready var _overlay: Control = %Overlay
@onready var _name: Label = %NameLabel
@onready var _top: Label = %TopLabel
@onready var _bottom: Label = %BottomLabel
@onready var _side_l: Label = %SideLeftLabel
@onready var _side_r: Label = %SideRightLabel
@onready var _trait_mark: Label = %TraitMark
@onready var _trait_icon: TextureRect = %TraitIcon
@onready var _trait_badge: PanelContainer = %TraitBadge
@onready var _clearance: HBoxContainer = %ClearancePips
@onready var _side_pip_r: Control = $Frame/Row/SidePipRight

var _art_node: Control = null
var _text_scale: float = 1.0


func _ready() -> void:
	_art.draw.connect(_draw_placeholder_art)
	_overlay.draw.connect(_draw_overlay)
	resized.connect(_on_resized)
	_side_pip_r.item_rect_changed.connect(_overlay.queue_redraw)
	if not card.is_empty():
		_apply()


## Shows a card. owner: &"player" / &"rival" / &"" ; signature: draw the Signature ribbon.
func show_card(c: Dictionary, owner: StringName = &"", signature: bool = false, is_face_down: bool = false) -> void:
	card = c
	owner_side = owner
	is_signature = signature
	face_down = is_face_down
	if is_node_ready():
		_apply()


## Scales every text and pip (inspector uses ~1.5 on the big card). 1.0 = theme sizes.
func set_text_scale(s: float) -> void:
	_text_scale = s
	if not is_node_ready():
		await ready
	for l: Label in [_name, _top, _bottom, _side_l, _side_r, _trait_mark]:
		l.remove_theme_font_size_override(&"font_size")
		if not is_equal_approx(s, 1.0):
			var base: int = l.get_theme_font_size(&"font_size")
			l.add_theme_font_size_override(&"font_size", int(round(base * s)))
	for p: Control in _clearance.get_children():
		p.custom_minimum_size = Vector2(8, 8) * s
	_trait_icon.custom_minimum_size = Vector2(20, 20) * s


func get_value_labels() -> Array[Label]:
	return [_top, _side_l, _side_r, _bottom]


## Labels whose whole text must show (tests).
func get_important_labels() -> Array[Label]:
	var out: Array[Label] = get_value_labels()
	out.append(_trait_mark)
	return out


func get_name_label() -> Label:
	return _name


func _apply() -> void:
	_name.text = String(card.get("name", ""))
	_top.text = str(card.get("top", ""))
	_bottom.text = str(card.get("bottom", ""))
	_side_l.text = str(card.get("side", ""))
	_side_r.text = _side_l.text
	var clr: int = clampi(int(card.get("clearance", 1)), 1, 4)
	_frame.theme_type_variation = &"CardFrameShowcase" if card.get("origin", &"") == &"showcase" else StringName("CardFrameC%d" % clr)
	for child: Node in _clearance.get_children():
		child.queue_free()
	for i: int in clr:
		var pip: ColorRect = ColorRect.new()
		pip.color = Palette.SIGNATURE if clr == 4 else Palette.TEXT
		pip.custom_minimum_size = Vector2(8, 8) * _text_scale
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clearance.add_child(pip)
	var trait_id: StringName = card.get("trait", &"none")
	var tex: Texture2D = null
	if icon_factory.is_valid() and trait_id != &"none":
		tex = icon_factory.call(StringName("trait_%s" % trait_id))
	_trait_icon.texture = tex
	_trait_icon.visible = tex != null
	_trait_mark.text = CardText.TRAIT_MARKS.get(trait_id, "")
	_trait_mark.visible = tex == null
	_trait_badge.visible = trait_id != &"none"
	_set_art()
	_refresh_visibility()
	_overlay.queue_redraw()
	_art.queue_redraw()


func _set_art() -> void:
	if _art_node != null:
		_art_node.queue_free()
		_art_node = null
	if art_factory.is_valid() and not card.is_empty():
		_art_node = art_factory.call(card)
		if _art_node != null:
			_art_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_art_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_art.add_child(_art_node)


func _refresh_visibility() -> void:
	if not is_node_ready():
		return
	_frame.visible = not face_down
	_face_down.visible = face_down
	_name.visible = not compact
	_overlay.queue_redraw()


func _on_resized() -> void:
	_art.queue_redraw()
	_overlay.queue_redraw()


## Seeded duotone placeholder (art direction §7) - replaced by art_factory when cc14 sets it.
func _draw_placeholder_art() -> void:
	if _art_node != null or card.is_empty():
		return
	var r: Rect2 = Rect2(Vector2.ZERO, _art.size)
	var cols: Array = Palette.set_colors(card.get("set", &""))
	var dark: Color = cols[0]
	var light: Color = cols[1]
	if face_down:
		_art.draw_rect(r, Color("#1B1E25"))
		return
	_art.draw_rect(r, dark.darkened(0.25))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(card.get("art_seed", 1))
	for i: int in 3:
		var c: Vector2 = Vector2(rng.randf_range(0.2, 0.9) * r.size.x, rng.randf_range(0.0, 1.0) * r.size.y)
		_art.draw_circle(c, rng.randf_range(0.15, 0.45) * r.size.y * 2.0, Color(light, 0.22 + 0.1 * i))
	var x: float = rng.randf_range(0.3, 0.7) * r.size.x
	_art.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + r.size.y, 0),
			Vector2(x + r.size.y * 0.4, r.size.y), Vector2(x - r.size.y * 0.6, r.size.y)]), Color(light, 0.35))
	# Darker band behind the text rows keeps values readable on any poster.
	_art.draw_rect(r, Color(Palette.ENAMEL, 0.35))


func _draw_overlay() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, _overlay.size)
	if face_down:
		var rad: float = minf(r.size.y * 0.28, 22.0)
		_draw_closed_eye(Vector2(r.size.x * 0.12 + rad, r.size.y * 0.42), rad)
	if owner_side != &"":
		var col: Color = Palette.owner_color(owner_side)
		_overlay.draw_rect(r.grow(-2.0), col, false, 3.0)
		var t: float = TAB_SIZE * maxf(_text_scale, 1.0)
		if owner_side == &"player":
			# Solid tab.
			_overlay.draw_rect(Rect2(Vector2.ZERO, Vector2(t, t)), col)
		else:
			# Notched tab: a square with a V cut out of its lower edge.
			_overlay.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(t, 0), Vector2(t, t),
					Vector2(t * 0.5, t * 0.45), Vector2(0, t)]), col)
	if is_signature:
		var w: float = 14.0 * maxf(_text_scale, 1.0)
		var h: float = 20.0 * maxf(_text_scale, 1.0)
		# Left of the right-hand Side pip, above the Bottom pip, so it never covers a value.
		var pip_r: Control = _side_pip_r
		var x0: float = (pip_r.get_global_rect().position.x - _overlay.get_global_rect().position.x) - w - 6.0 \
				if _frame.visible else r.size.x - w - 6.0
		_overlay.draw_colored_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x0 + w, 0), Vector2(x0 + w, h),
				Vector2(x0 + w * 0.5, h * 0.7), Vector2(x0, h)]), Palette.SIGNATURE)


func _draw_closed_eye(c: Vector2, rad: float) -> void:
	var pts: PackedVector2Array = []
	for i: int in 13:
		var a: float = PI * float(i) / 12.0
		pts.append(c + Vector2(-cos(a) * rad, sin(a) * rad * 0.55))
	_overlay.draw_polyline(pts, Palette.TEXT_DIM, 3.0, true)
	for i: int in [3, 6, 9]:
		var p: Vector2 = pts[i]
		_overlay.draw_line(p, p + (p - c).normalized() * rad * 0.35, Palette.TEXT_DIM, 2.0, true)
