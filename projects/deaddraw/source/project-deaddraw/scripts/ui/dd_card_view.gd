# dd_card_view.gd
# Purpose: One tappable, inspectable card tile (street cards, weapon slot, deck counter, finale,
#   perks, survivors, unlocks). Left click / tap emits `tapped`; right click or a long press
#   (touch is emulated as the left mouse button) emits `inspected` with the zoom payload.
#   dd-feel: spec "art" (a Texture2D from dd_art.gd) shows the card art. Full tiles use the art
#   direction's frame (ART_LAYOUT "frame": the art fills the window, the number sits in an ink badge
#   in the art's quiet top-left corner, kind + name + preview in an ink name bar); compact tiles
#   put the art behind a scrim. Map nodes ("bg_art") show the district banner with a small finale
#   card. Without art the tile looks exactly as before. big_label / line_labels / art_rect are
#   exposed for the feedback animations.
# Dependencies: DDUi.
# Author: Mechanics Developer Agent
class_name DDCardView
extends PanelContainer

signal tapped(view: DDCardView)
signal inspected(payload: Dictionary)

const LONG_PRESS_MS: int = 450
const MOVE_CANCEL_PX: float = 28.0

## Zoom payload: {kind, tag, title, big, body}. See DDInspect.open().
var payload: Dictionary = {}
var kind: String = "D"
var index: int = -1

var _pressing: bool = false
var _long_fired: bool = false
var _press_ms: int = 0
var _press_pos: Vector2 = Vector2.ZERO
var _box: VBoxContainer
var _selected: bool = false
var _dim: bool = false
## dd-feel: nodes the feedback animations touch (null / empty when the spec has none).
var big_label: Label = null
var line_labels: Array[Label] = []
var art_rect: TextureRect = null
var has_art: bool = false
var _frame: bool = false
var _badge_panel: PanelContainer = null
var _corner_chip: Control = null

## dd-feel: how a non-compact tile with art is laid out. "frame" = art direction section 4 (number
## badge over full art, name bar below); anything else = the plain tile with the art behind a scrim.
const ART_LAYOUT: String = "frame"
const INK: Color = Color("151214")
const BONE: Color = Color("ece6d6")


## spec keys: kind, tag (top-left small), badge (top-right), big, title, lines: [[text, color]...],
## big_size, compact, selected, dim, payload.
## dd-feel art keys: art (Texture2D), art_fit ("cover" | "contain" for icons), art_dim (darken the
## art window to 45%: won't heal / no effect), holdover (corner tab), bg_art (Texture2D banner behind
## a "district" tile, which then shows `art` as a small finale card with the number badge).
func setup(spec: Dictionary) -> DDCardView:
	kind = str(spec.get("kind", "D"))
	payload = spec.get("payload", {})
	_selected = bool(spec.get("selected", false))
	_dim = bool(spec.get("dim", false))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var compact: bool = bool(spec.get("compact", false))
	var art: Variant = spec.get("art", null)
	has_art = art is Texture2D
	if spec.get("bg_art", null) is Texture2D:
		has_art = true
		_frame = true
		_build_district(spec)
	elif has_art and not compact and ART_LAYOUT == "frame":
		_frame = true
		_build_framed(spec, art)
	else:
		_build_plain(spec, art if has_art else null, compact)
	_apply_style()
	DDUi.ignore_mouse(self)
	tooltip_text = ""
	return self


## The original tile: tag row, big number, title, lines. With art (compact tiles): the art fills
## the tile under a scrim in the type colour and the text gets a dark outline.
func _build_plain(spec: Dictionary, art: Variant, compact: bool) -> void:
	if art != null:
		_add_art(self, art, "cover")
		var scrim: ColorRect = ColorRect.new()
		scrim.color = Color(DDUi.card_bg(kind), 0.55)
		add_child(scrim)
	_box = DDUi.vbox(2 if compact else 4)
	add_child(_box)
	var top: HBoxContainer = DDUi.hbox(4)
	_box.add_child(top)
	var tag: String = str(spec.get("tag", ""))
	var tl: Label = DDUi.label(tag, DDUi.FONT_S - (2 if compact else 0), DDUi.accent(kind))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.clip_text = true
	top.add_child(tl)
	_add_badge(top, spec)
	var big: String = str(spec.get("big", ""))
	if big != "":
		var bl: Label = DDUi.label(big, int(spec.get("big_size", DDUi.BIG_NUMBER)), DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		bl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if art != null:
			_outline(bl, 12)
		big_label = bl
		_box.add_child(bl)
	var title: String = str(spec.get("title", ""))
	if title != "":
		var tt: Label = DDUi.label(title, DDUi.FONT_M - (6 if compact else 0), DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER, true)
		if art != null:
			_outline(tt, 6)
		_box.add_child(tt)
	_add_lines(_box, spec, art != null)


## Art direction section 4: the art fills the window, the number sits in an ink badge in the art's
## quiet top-left corner, kind + name + preview live in an ink name bar under the art.
func _build_framed(spec: Dictionary, art: Texture2D) -> void:
	_box = DDUi.vbox(0)
	add_child(_box)
	var window: Control = Control.new()
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.custom_minimum_size = Vector2(0, 40)
	window.clip_contents = true
	_box.add_child(window)
	var fit: String = str(spec.get("art_fit", "cover"))
	if fit == "contain":
		var under: ColorRect = ColorRect.new()
		under.color = DDUi.card_bg(kind)
		under.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		window.add_child(under)
	var tr: TextureRect = _add_art(window, art, fit)
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if bool(spec.get("art_dim", false)):
		tr.self_modulate = Color(0.45, 0.45, 0.45)
	var big: String = str(spec.get("big", ""))
	if big != "":
		_badge_panel = _number_badge(big)
		window.add_child(_badge_panel)
	var badge: String = str(spec.get("badge", ""))
	if badge != "" or bool(spec.get("holdover", false)):
		var chip: PanelContainer = DDUi.panel(Color(spec.get("badge_color", DDUi.WARN)) if badge != "" else DDUi.TEXT, 3)
		chip.add_child(DDUi.label(badge if badge != "" else "HOLDOVER", DDUi.FONT_S - 5, DDUi.BG))
		window.add_child(chip)
		window.resized.connect(func() -> void:
			if is_instance_valid(chip):
				chip.size = chip.get_combined_minimum_size()
				chip.position = Vector2(window.size.x - chip.size.x - 4.0, 4.0))
		_corner_chip = chip
	var bar: PanelContainer = DDUi.panel(INK, 5)
	var bst: StyleBoxFlat = DDUi.box(INK, Color(0, 0, 0, 0), 0, 0, 5)
	bst.corner_radius_bottom_left = 10
	bst.corner_radius_bottom_right = 10
	bar.add_theme_stylebox_override("panel", bst)
	_box.add_child(bar)
	var bv: VBoxContainer = DDUi.vbox(0)
	bar.add_child(bv)
	var name_row: HBoxContainer = DDUi.hbox(6)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_child(name_row)
	var tag: String = str(spec.get("tag", ""))
	if tag != "":
		var kl: Label = DDUi.label(tag.to_upper(), DDUi.FONT_S - 5, DDUi.accent(kind))
		kl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		name_row.add_child(kl)
	var title: String = str(spec.get("title", ""))
	if title != "":
		var tt: Label = DDUi.label(title, DDUi.FONT_S, BONE)
		tt.clip_text = true
		tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if tag == "" else HORIZONTAL_ALIGNMENT_LEFT
		name_row.add_child(tt)
	_add_lines(bv, spec, false)


## Map node: the district banner as the background, a small finale card (art + number badge) on
## the left, the text on the right.
func _build_district(spec: Dictionary) -> void:
	_add_art(self, spec["bg_art"], "cover")
	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(INK, 0.45)
	add_child(scrim)
	var h: HBoxContainer = DDUi.hbox(10)
	add_child(h)
	var art: Variant = spec.get("art", null)
	if art is Texture2D:
		var mini: PanelContainer = PanelContainer.new()
		var st: StyleBoxFlat = DDUi.box(DDUi.card_bg(kind), DDUi.accent(kind), 3, 10, 0)
		mini.add_theme_stylebox_override("panel", st)
		mini.custom_minimum_size = Vector2(108, 0)
		h.add_child(mini)
		var window: Control = Control.new()
		window.clip_contents = true
		mini.add_child(window)
		var tr: TextureRect = _add_art(window, art, "cover")
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var big: String = str(spec.get("big", ""))
		if big != "":
			_badge_panel = _number_badge(big)
			window.add_child(_badge_panel)
	_box = DDUi.vbox(2)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_box)
	var top: HBoxContainer = DDUi.hbox(4)
	_box.add_child(top)
	var tl: Label = DDUi.label(str(spec.get("tag", "")), DDUi.FONT_S, DDUi.accent(kind))
	_outline(tl, 6)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.clip_text = true
	top.add_child(tl)
	_add_badge(top, spec)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(spacer)
	var tt: Label = DDUi.label(str(spec.get("title", "")), DDUi.FONT_M, BONE, HORIZONTAL_ALIGNMENT_LEFT, true)
	_outline(tt, 6)
	_box.add_child(tt)
	_add_lines(_box, spec, true, HORIZONTAL_ALIGNMENT_LEFT)


func _add_art(parent: Control, tex: Texture2D, fit: String) -> TextureRect:
	var tr: TextureRect = TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if fit == "contain" else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.custom_minimum_size = Vector2.ZERO
	parent.add_child(tr)
	if art_rect == null:
		art_rect = tr
	return tr


func _add_badge(row: HBoxContainer, spec: Dictionary) -> void:
	var badge: String = str(spec.get("badge", ""))
	var col: Color = Color(spec.get("badge_color", DDUi.WARN))
	if badge == "" and bool(spec.get("holdover", false)):
		badge = "HOLDOVER"
		col = DDUi.TEXT_DIM
	if badge != "":
		var bp: PanelContainer = DDUi.panel(col, 3)
		bp.add_child(DDUi.label(badge, DDUi.FONT_S - 3, DDUi.BG))
		row.add_child(bp)


func _add_lines(parent: Container, spec: Dictionary, outline: bool, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> void:
	for ln: Variant in spec.get("lines", []):
		var arr: Array = ln
		var l: Label = DDUi.label(str(arr[0]), int(arr[2]) if arr.size() > 2 else DDUi.FONT_S, arr[1] if arr.size() > 1 else DDUi.TEXT_DIM, align, true)
		if outline:
			_outline(l, 6)
		line_labels.append(l)
		parent.add_child(l)


## Ink disc (a pill for long numbers like "9/11") with a 3 px type-accent ring and bone numerals.
## Sized to ~30% of the tile width in _fit_badge().
func _number_badge(text: String) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var st: StyleBoxFlat = DDUi.box(INK, DDUi.accent(kind), 3, 999, 4)
	p.add_theme_stylebox_override("panel", st)
	p.position = Vector2(6, 6)
	var l: Label = DDUi.label(text, DDUi.BIG_NUMBER, BONE, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	big_label = l
	return p


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _badge_panel != null:
		_fit_badge.call_deferred()


func _fit_badge() -> void:
	if _badge_panel == null or not is_instance_valid(_badge_panel) or big_label == null:
		return
	var host: Control = _badge_panel.get_parent() as Control
	var d: float = clampf(size.x * 0.3, 38.0, 96.0)
	if host != null and host.size.y > 0.0:
		d = minf(d, maxf(34.0, host.size.y - 12.0))
	if host != null and host.size.x > 0.0 and host != _box:
		d = minf(d, host.size.x * 0.55)
	var digits: int = big_label.text.length()
	var fs: int = int(d * (0.56 if digits <= 2 else 0.4))
	big_label.add_theme_font_size_override("font_size", fs)
	var w: float = maxf(d, big_label.get_minimum_size().x + 16.0)
	_badge_panel.custom_minimum_size = Vector2(w, d)
	_badge_panel.size = Vector2(w, d)
	_badge_panel.pivot_offset = _badge_panel.size * 0.5


func _outline(l: Label, px: int) -> void:
	l.add_theme_constant_override("outline_size", px)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.04, 0.92))


func set_selected(v: bool) -> void:
	_selected = v
	_apply_style()


func _apply_style() -> void:
	var bg: Color = DDUi.card_bg(kind)
	var border: Color = DDUi.SELECT if _selected else DDUi.accent(kind)
	var st: StyleBoxFlat = DDUi.box(bg, border, 5 if _selected else (3 if _frame else 2), 14 if not _frame else 12, 10 if not _frame else 3)
	if _selected:
		st.shadow_color = Color(DDUi.SELECT, 0.35)
		st.shadow_size = 10
	add_theme_stylebox_override("panel", st)
	modulate = Color(1, 1, 1, 0.55) if _dim else Color(1, 1, 1, 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_pressing = false
			_open_inspect()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_long_fired = false
				_press_ms = Time.get_ticks_msec()
				_press_pos = mb.position
				set_process(true)
			else:
				if _pressing and not _long_fired:
					tapped.emit(self)
				_pressing = false
				set_process(false)
			accept_event()
	elif event is InputEventMouseMotion and _pressing:
		if (event as InputEventMouseMotion).position.distance_to(_press_pos) > MOVE_CANCEL_PX:
			_pressing = false


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if _pressing and not _long_fired and Time.get_ticks_msec() - _press_ms >= LONG_PRESS_MS:
		_long_fired = true
		_pressing = false
		set_process(false)
		_open_inspect()


func _open_inspect() -> void:
	if not payload.is_empty():
		inspected.emit(payload)
