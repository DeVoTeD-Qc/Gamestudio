# dd_skin.gd
# Purpose: dd-art2-import: the painted UI kit (art pack 2, assets/art/painted/ui/*.webp) as StyleBoxes.
#   Each image is a 9-slice piece saved at 2x its in-game size (tools/art/import_ui.py); Nine draws it at
#   half scale so the painted edges stay crisp on 2x screens, and shrinks the corners when a box is
#   smaller than its margins (88x32 tags, thin bars). SPEC holds the margins in TEXTURE px.
#   Every helper returns null when the image is missing, so callers keep their StyleBoxFlat fallback.
#   dd-ui-clean: three switchable skins (setting "ui_skin", web query &skin=a|b|c, Settings > UI style):
#     a "Clean painted": the kit re-cut without bolts / rivets, small corners, calm edges
#       (assets/art/painted/ui_clean, made by tools/art/clean_ui.py); panels drawn thinner;
#     b "Flat ink": flat type-colour fill, thick ink outline, a one-step bevel, 6 px corners (vector);
#     c "Minimal frame": dark translucent fill, 2 px coloured rim, an accent bar on primary actions (vector).
#   "old" (the first bolted kit) stays reachable with &skin=old for before / after shots.
#   Badges and pills stay painted in every skin. Text never touches decoration: box() keeps the content
#   margins of buttons, chips, door plates and panels at least inset() + GAP px from every edge.
# Dependencies: none. Loaded with preload() (no class_name, so no class-cache rescan).
# Author: Technical Artist Agent (dd-art2-import, dd-ui-clean)
extends RefCounted

const DIR: String = "res://assets/art/painted/ui/"
const DIR_CLEAN: String = "res://assets/art/painted/ui_clean/"

## dd-ui-clean: the skins the player can pick, their names, and the default.
const SKINS: PackedStringArray = ["a", "b", "c"]
const SKIN_NAMES: Dictionary = {"a": "Clean painted", "b": "Flat ink", "c": "Minimal frame", "old": "Bolted kit"}
const DEFAULT_SKIN: String = "b"
## the clear space (game px) between any corner / rim decoration and the content
const GAP: float = 6.0
## the pieces whose content (labels) box() keeps clear of the decoration
const GUARDED: PackedStringArray = ["dd_btn_", "dd_chip_filter_", "dd_plate_door_", "dd_panel_"]
const INK: Color = Color("0b0a09")

## name prefix -> [left, top, right, bottom] margins in texture px, scale mode.
## "half": drawn at 0.5 (the 2x files); "fit_h": the height fits the box and only the middle
## stretches sideways (pills, bars, tags, the Full set plate: their ends are round).
const SPEC: Dictionary = {
	"dd_btn_": [[40, 40, 40, 40], "half"],
	"dd_chip_filter_": [[40, 40, 40, 40], "half"],
	"dd_plate_door_": [[40, 40, 40, 40], "half"],
	"dd_plate_fullset_": [[64, 0, 64, 0], "fit_h"],
	"dd_tag_": [[64, 0, 64, 0], "fit_h"],
	"dd_pill_": [[64, 0, 64, 0], "fit_h"],
	"dd_bar_name": [[32, 16, 32, 16], "half"],
	"dd_bar_": [[16, 0, 16, 0], "fit_h"],
	"dd_panel_": [[80, 80, 80, 80], "half"],
	"dd_frame_": [[80, 80, 80, 80], "half"],
	"dd_socket_": [[16, 16, 16, 16], "half"],
}

## Button colours (the old StyleBoxFlat fills) -> painted button family.
const BUTTON_FAMILY: Dictionary = {
	"7a2d27": "red", "6b1f1a": "red", "5a2a1a": "rust", "245236": "green", "1f3a4f": "blue", "2f2f5a": "indigo",
}
## dd-ui-clean: skin b fills (bone text on each is 4.5:1 or better, hover included) and skin c rims.
const FLAT_FILL: Dictionary = {
	"red": Color("9c3128"), "rust": Color("87451c"), "green": Color("2a623e"), "blue": Color("23597f"),
	"indigo": Color("45458a"), "dark": Color("2b3338"), "gold": Color("72540f"),
}
const RIM_COLOR: Dictionary = {
	"red": Color("e2574c"), "rust": Color("e08a45"), "green": Color("6fd08a"), "blue": Color("5bb0e0"),
	"indigo": Color("9aa8ff"), "dark": Color("6b7880"), "gold": Color("e0b04a"),
}
const TAG_FILL: Dictionary = {"yellow": Color("f2c14e"), "red": Color("e2574c"), "bone": Color("d8cfb8"), "boss": Color("5a2d7a")}

## Off switch for tests / before-after shots (DDSkin.enabled = false -> every helper returns null).
static var enabled: bool = true
static var skin: String = DEFAULT_SKIN
static var _tex: Dictionary = {}


## Switches the skin ("" or unknown -> the default). Widgets built afterwards use it. Returns the skin.
static func set_skin(s: String) -> String:
	var k: String = s.strip_edges().to_lower()
	if not (SKINS.has(k) or k == "old"):
		k = DEFAULT_SKIN
	if k != skin:
		skin = k
		_tex.clear()
	return skin


## b and c draw their boxes as vectors (no texture).
static func vector() -> bool:
	return skin == "b" or skin == "c"


## True for the pieces a skin replaces (everything but the number badges and pills).
static func skinned(file: String) -> bool:
	return not (file.begins_with("dd_badge_") or file.begins_with("dd_pill_"))


static func _guarded(file: String) -> bool:
	for g: String in GUARDED:
		if file.begins_with(g):
			return true
	return false


## How deep (game px) the piece's rim / corner decoration reaches in from its edges in this skin.
static func inset(file: String) -> float:
	var panel: bool = file.begins_with("dd_panel_") or file.begins_with("dd_frame_")
	match skin:
		"a":
			# clean plates: 16 tex px band at 0.5; panels: 40 tex px band drawn at PANEL_SCALE_A
			return 40.0 * PANEL_SCALE_A if panel else 8.0
		"b", "c":
			return 6.0
	# the first kit: bolts at 22 +- 9 tex px (buttons), 40 +- 16 (panels), drawn at 0.5
	return 28.0 if panel else 16.0


## dd-ui-clean: skin a draws its panels and frames thinner (the calmer edge).
const PANEL_SCALE_A: float = 0.35


## Corner radius (game px) for flat boxes in this skin (old keeps what it was asked for).
static func radius(r: float) -> int:
	match skin:
		"a":
			return int(minf(r, 8.0))
		"b", "c":
			return int(minf(r, 6.0))
	return int(r)


static func tex(file: String) -> Texture2D:
	if not enabled:
		return null
	if vector() and skinned(file):
		return null
	if _tex.has(file):
		return _tex[file]
	var p: String = DIR + file + ".webp"
	if skin == "a" and ResourceLoader.exists(DIR_CLEAN + file + ".webp"):
		p = DIR_CLEAN + file + ".webp"
	var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_tex[file] = t
	return t


static func spec(file: String) -> Array:
	for k: String in SPEC:
		if file.begins_with(k):
			return SPEC[k]
	return [[32, 32, 32, 32], "half"]


## A painted 9-slice box (or null when the image is missing). `pad` = content margins (game px).
## dd-ui-clean: in skins b / c a vector box (or null where the flat fallback is the look); the content
## margins of guarded pieces never come closer than inset() + GAP to an edge.
static func box(file: String, pad: float = 10.0, tint: Color = Color.WHITE) -> StyleBox:
	if not enabled:
		return null
	if skin != "old" and _guarded(file):
		pad = maxf(pad, inset(file) + GAP)
	if vector() and skinned(file):
		return _vector_box(file, pad, tint)
	var t: Texture2D = tex(file)
	if t == null:
		return null
	var sp: Array = spec(file)
	var n: Nine = Nine.new()
	n.texture = t
	var m: Array = sp[0]
	n.margins = Vector4(m[0], m[1], m[2], m[3])
	n.fit_h = sp[1] == "fit_h"
	if skin == "a" and (file.begins_with("dd_panel_") or file.begins_with("dd_frame_")):
		n.scale = PANEL_SCALE_A
	n.tint = tint
	n.set_content_margin_all(pad)
	return n


## The painted button family for an old button fill colour.
static func family(c: Color) -> String:
	var hex: String = c.to_html(false)
	if BUTTON_FAMILY.has(hex):
		return BUTTON_FAMILY[hex]
	# other fills (sheet choices: equip blue, scrap / take brown, machine olive) by hue
	if c.s < 0.25:
		return "dark"
	var h: float = c.h * 360.0
	if h < 15.0 or h >= 330.0:
		return "red"
	if h < 55.0:
		return "rust"
	if h < 170.0:
		return "green"
	if h < 230.0:
		return "blue"
	return "indigo"


## Applies the painted normal / hover (normal x1.12) / pressed / disabled plates to b. False when missing.
static func skin_button(b: Button, fam: String, pad: float = 12.0) -> bool:
	var n: StyleBox = box("dd_btn_%s_normal" % fam, pad)
	var p: StyleBox = box("dd_btn_%s_pressed" % fam, pad)
	var d: StyleBox = box("dd_btn_disabled", pad)
	if n == null or p == null or d == null:
		return false
	var h: StyleBox = box("dd_btn_%s_normal" % fam, pad, Color(1.12, 1.12, 1.12))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.set_meta(&"painted", fam)
	return true


## Applies one plate to every button state (hover brightened, pressed darkened). False when missing.
static func skin_plate(b: Button, file: String, pad: float = 6.0, lift: float = 1.0) -> bool:
	var n: StyleBox = box(file, pad, Color(lift, lift, lift))
	if n == null:
		return false
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_stylebox_override("hover", box(file, pad, Color(lift * 1.12, lift * 1.12, lift * 1.12)))
	b.add_theme_stylebox_override("pressed", box(file, pad, Color(0.8, 0.8, 0.8)))
	b.add_theme_stylebox_override("hover_pressed", box(file, pad, Color(0.8, 0.8, 0.8)))
	return true


## A card / chip frame: the type's body colour under a painted rim tinted to the type accent.
## The rim is drawn over the content by a RimOverlay (see rim()), so this box only paints the body.
static func card_body(bg: Color, pad: float, rad: float = 12.0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius(rad))
	s.anti_aliasing = true
	s.set_content_margin_all(pad)
	# the painted rim sits ~4 px inside the box edge: keep the body inside its outer contour
	s.expand_margin_left = -2.0
	s.expand_margin_right = -2.0
	s.expand_margin_top = -2.0
	s.expand_margin_bottom = -2.0
	return s


## Adds (or updates) the painted rim drawn on top of a card's content. Returns the overlay or null.
static func rim(host: Control, tint: Color, selected: bool = false, chip: bool = false, outset: float = 0.0) -> Control:
	var file: String = "dd_frame_card_selected" if selected else ("dd_frame_chip_rim" if chip else "dd_frame_card_rim")
	var st: StyleBox = null
	if enabled and vector():
		st = _vector_rim(tint, selected, chip)
	elif tex(file) != null:
		st = box(file, 0.0, Color.WHITE if selected else tint)
	var ov: RimOverlay = host.get_node_or_null(^"PaintedRim") as RimOverlay
	if st == null:
		if ov != null:
			ov.queue_free()
		return null
	if ov == null:
		ov = RimOverlay.new()
		ov.name = "PaintedRim"
		host.add_child(ov)
		# stay the last child (drawn on top) when the host adds more content later
		host.child_entered_tree.connect(ov._on_sibling)
	ov.nine = st
	ov.outset = outset
	ov.queue_redraw()
	host.move_child(ov, -1)
	return ov



# ================================================================ dd-ui-clean: vector skins b / c
static func _flat(bg: Color, rad: float, border: Color = Color(0, 0, 0, 0), bw: int = 0, center: bool = true) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.draw_center = center
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(int(rad))
	s.anti_aliasing = true
	return s


## Skin b: ink outline, a dark step under the fill (the bevel), a light top edge. pressed: pushed down.
static func _ink_box(fill: Color, pressed: bool = false, dim: bool = false) -> Layers:
	var l: Layers = Layers.new()
	var ink: Color = Color(INK, 0.6) if dim else INK
	l.add(_flat(ink, 6.0), Vector4.ZERO)
	l.add(_flat(fill.darkened(0.45), 3.0), Vector4(3, 3, 3, 3))
	if pressed:
		l.add(_flat(fill.darkened(0.12), 3.0), Vector4(3, 5, 3, 3))
	else:
		var top: StyleBoxFlat = _flat(fill, 3.0)
		if not dim:
			top.border_color = fill.lightened(0.22)
			top.border_width_top = 2
		l.add(top, Vector4(3, 3, 3, 6))
	return l


## Skin c: dark translucent body, 2 px rim; `bar`: the accent bar of a primary action.
static func _min_box(rim_c: Color, bar: bool = false, pressed: bool = false, dim: bool = false) -> Layers:
	var l: Layers = Layers.new()
	var body: Color = Color(rim_c, 0.26) if pressed else Color(0.045, 0.052, 0.06, 0.6 if dim else 0.88)
	l.add(_flat(body, 6.0, Color(rim_c, 0.35) if dim else rim_c, 2), Vector4.ZERO)
	if bar and not dim:
		var b: StyleBoxFlat = _flat(rim_c, 0.0)
		b.corner_radius_bottom_left = 4
		b.corner_radius_bottom_right = 4
		l.add(b, Vector4(2, -4, 2, 2))
	return l


## A solid state plate (door USE / afford, tags): the colour is the meaning, dark words on it.
static func _solid(fill: Color, edge: Color, ink_line: bool, rad: float = 6.0) -> Layers:
	var l: Layers = Layers.new()
	if ink_line:
		l.add(_flat(INK, rad), Vector4.ZERO)
		l.add(_flat(fill, maxf(0.0, rad - 2.0), edge, 0), Vector4(2, 2, 2, 2))
	else:
		l.add(_flat(fill, rad, edge, 2), Vector4.ZERO)
	return l


static func _vector_box(file: String, pad: float, tint: Color) -> StyleBox:
	var ink: bool = skin == "b"
	var l: Layers = null
	if file == "dd_btn_disabled":
		l = _ink_box(Color("262b2e"), false, true) if ink else _min_box(RIM_COLOR["dark"], false, false, true)
	elif file.begins_with("dd_btn_"):
		var parts: PackedStringArray = file.trim_prefix("dd_btn_").split("_")
		var fam: String = parts[0] if FLAT_FILL.has(parts[0]) else "dark"
		var pressed: bool = parts.size() > 1 and parts[1] == "pressed"
		l = _ink_box(FLAT_FILL[fam], pressed) if ink else _min_box(RIM_COLOR[fam], fam != "dark", pressed)
	elif file.begins_with("dd_chip_filter_"):
		var on: bool = file.ends_with("_on")
		var fam2: String = "gold" if on else "dark"
		l = _ink_box(FLAT_FILL[fam2]) if ink else _min_box(RIM_COLOR[fam2], on)
	elif file.begins_with("dd_plate_door_"):
		match file.trim_prefix("dd_plate_door_"):
			"afford":
				l = _solid(Color("f2c14e"), Color("fff2b0"), ink)
			"use":
				l = _solid(Color("6fd08a"), Color("c9f5d4"), ink)
			"used":
				l = _ink_box(Color("1a1818"), false, true) if ink else _min_box(Color("555555"), false, false, true)
			_:
				l = _ink_box(Color("0e0c0c")) if ink else _min_box(Color("8a7a52"))
	elif file.begins_with("dd_panel_"):
		var role: String = file.trim_prefix("dd_panel_")
		if ink:
			l = Layers.new()
			l.add(_flat(INK, 6.0), Vector4.ZERO)
			l.add(_flat(Color("20262a") if role != "tooltip" else Color("1b2024"), 3.0, Color("3a454c"), 1), Vector4(3, 3, 3, 3))
		else:
			l = Layers.new()
			l.add(_flat(Color(0.045, 0.052, 0.06, 0.93), 6.0, Color("7d8c94") if role == "tooltip" else Color("56636b"), 2), Vector4.ZERO)
	elif file.begins_with("dd_tag_"):
		var key: String = file.trim_prefix("dd_tag_")
		l = _solid(TAG_FILL.get(key, TAG_FILL["bone"]), Color(0, 0, 0, 0), ink, 4.0)
	if l == null:
		return null
	l.tint = tint
	if not tint.is_equal_approx(Color.WHITE):
		l.apply_tint(tint)
	l.set_content_margin_all(pad)
	return l


static func _vector_rim(tint: Color, selected: bool, chip: bool) -> Layers:
	var col: Color = Color("fff2b0") if selected else tint
	var w: int = (4 if selected else 3) if skin == "b" else (3 if selected else 2)
	var rad: float = 4.0 if chip else 6.0
	var l: Layers = Layers.new()
	if skin == "b":
		l.add(_flat(Color(0, 0, 0, 0), rad, INK, 2, false), Vector4.ZERO)
		l.add(_flat(Color(0, 0, 0, 0), maxf(0.0, rad - 2.0), col, w, false), Vector4(2, 2, 2, 2))
	else:
		l.add(_flat(Color(0, 0, 0, 0), rad, col, w, false), Vector4.ZERO)
	return l


## Flat boxes drawn in order, each inset (left, top, right, bottom) px from the rect; a negative top
## means "this many px tall, sitting on the bottom inset" (the accent bar).
class Layers:
	extends StyleBox
	var parts: Array[StyleBoxFlat] = []
	var insets: Array[Vector4] = []
	var tint: Color = Color.WHITE

	func add(s: StyleBoxFlat, ins: Vector4) -> void:
		parts.append(s)
		insets.append(ins)

	func apply_tint(t: Color) -> void:
		for s: StyleBoxFlat in parts:
			s.bg_color = _tinted(s.bg_color, t)
			s.border_color = _tinted(s.border_color, t)

	static func _tinted(c: Color, t: Color) -> Color:
		# hover (t > 1) lifts dark colours too; pressed (t < 1) darkens
		if t.r > 1.0:
			# a gentle lift (bone text keeps 4.5:1 on the hovered fill)
			var k: float = 1.0 + (t.r - 1.0) * 0.4
			return Color(minf(1.0, c.r * k + 0.012), minf(1.0, c.g * k + 0.012), minf(1.0, c.b * k + 0.012), c.a)
		return Color(c.r * t.r, c.g * t.g, c.b * t.b, c.a)

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		for i: int in parts.size():
			var ins: Vector4 = insets[i]
			var r: Rect2
			if ins.y < 0.0:
				r = Rect2(rect.position.x + ins.x, rect.end.y - ins.w + ins.y, rect.size.x - ins.x - ins.z, -ins.y)
			else:
				r = Rect2(rect.position + Vector2(ins.x, ins.y), rect.size - Vector2(ins.x + ins.z, ins.y + ins.w))
			if r.size.x > 0.5 and r.size.y > 0.5:
				parts[i].draw(to_canvas_item, r)


# ================================================================ the 9-slice stylebox
class Nine:
	extends StyleBox
	var texture: Texture2D = null
	## margins in texture px (left, top, right, bottom)
	var margins: Vector4 = Vector4(32, 32, 32, 32)
	## true: the height fits the box, only the middle stretches sideways
	var fit_h: bool = false
	## game px per texture px for "half" pieces (0.5: the files are 2x)
	var scale: float = 0.5
	## when > 0: the corner size in game px (overrides scale; card rims)
	var corner_px: float = 0.0
	var tint: Color = Color.WHITE

	func _draw(to_canvas_item: RID, rect: Rect2) -> void:
		if texture == null or rect.size.x <= 1.0 or rect.size.y <= 1.0:
			return
		var ts: Vector2 = texture.get_size()
		var l: float = margins.x
		var t: float = margins.y
		var r: float = margins.z
		var b: float = margins.w
		var sx: float
		var sy: float
		if fit_h:
			sy = rect.size.y / ts.y
			sx = minf(sy, rect.size.x / maxf(1.0, l + r))
		else:
			var s: float = scale if corner_px <= 0.0 else corner_px / maxf(1.0, l)
			var k: float = 1.0
			if l + r > 0.0:
				k = minf(k, rect.size.x / ((l + r) * s))
			if t + b > 0.0:
				k = minf(k, rect.size.y / ((t + b) * s))
			sx = s * k
			sy = s * k
		var src_x: Array[float] = [0.0, l, ts.x - r, ts.x]
		var src_y: Array[float] = [0.0, t, ts.y - b, ts.y]
		var dst_x: Array[float] = [rect.position.x, rect.position.x + l * sx, rect.end.x - r * sx, rect.end.x]
		var dst_y: Array[float] = [rect.position.y, rect.position.y + t * sy, rect.end.y - b * sy, rect.end.y]
		var rid: RID = texture.get_rid()
		for j: int in 3:
			for i: int in 3:
				var sw: float = src_x[i + 1] - src_x[i]
				var sh: float = src_y[j + 1] - src_y[j]
				var dw: float = dst_x[i + 1] - dst_x[i]
				var dh: float = dst_y[j + 1] - dst_y[j]
				if sw <= 0.0 or sh <= 0.0 or dw <= 0.0 or dh <= 0.0:
					continue
				RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, Rect2(dst_x[i], dst_y[j], dw, dh), rid,
					Rect2(src_x[i], src_y[j], sw, sh), tint, false, true)


## Draws a Nine over its parent's whole rect (plus `outset`), on top of the parent's content.
class RimOverlay:
	extends Control
	var nine: StyleBox = null
	var outset: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED or what == NOTIFICATION_ENTER_TREE:
			queue_redraw()

	func _on_sibling(n: Node) -> void:
		if n != self:
			_raise.call_deferred()

	func _raise() -> void:
		var p: Node = get_parent()
		if p != null and not is_queued_for_deletion() and get_index() != p.get_child_count() - 1:
			p.move_child(self, -1)

	func _draw() -> void:
		var p: Control = get_parent() as Control
		if nine == null or p == null:
			return
		# a Container lays this child out in its content rect: draw over the parent's full rect
		var r: Rect2 = Rect2(-position - Vector2(outset, outset), p.size + Vector2(outset, outset) * 2.0)
		# rim corner size: thinner on small chips so the art keeps its room
		if nine is Nine:
			(nine as Nine).corner_px = clampf(minf(r.size.x, r.size.y) * 0.09, 9.0, 15.0)
		draw_style_box(nine, r)
