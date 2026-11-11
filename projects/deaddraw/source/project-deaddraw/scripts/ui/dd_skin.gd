# dd_skin.gd
# Purpose: dd-art2-import: the painted UI kit (art pack 2, assets/art/painted/ui/*.webp) as StyleBoxes.
#   Each image is a 9-slice piece saved at 2x its in-game size (tools/art/import_ui.py); Nine draws it at
#   half scale so the painted edges stay crisp on 2x screens, and shrinks the corners when a box is
#   smaller than its margins (88x32 tags, thin bars). SPEC holds the margins in TEXTURE px.
#   Every helper returns null when the image is missing, so callers keep their StyleBoxFlat fallback.
# Dependencies: none. Loaded with preload() (no class_name, so no class-cache rescan).
# Author: Technical Artist Agent (dd-art2-import)
extends RefCounted

const DIR: String = "res://assets/art/painted/ui/"

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

## Off switch for tests / before-after shots (DDSkin.enabled = false -> every helper returns null).
static var enabled: bool = true
static var _tex: Dictionary = {}


static func tex(file: String) -> Texture2D:
	if not enabled:
		return null
	if _tex.has(file):
		return _tex[file]
	var p: String = DIR + file + ".webp"
	var t: Texture2D = load(p) as Texture2D if ResourceLoader.exists(p) else null
	_tex[file] = t
	return t


static func spec(file: String) -> Array:
	for k: String in SPEC:
		if file.begins_with(k):
			return SPEC[k]
	return [[32, 32, 32, 32], "half"]


## A painted 9-slice box (or null when the image is missing). `pad` = content margins (game px).
static func box(file: String, pad: float = 10.0, tint: Color = Color.WHITE) -> Nine:
	var t: Texture2D = tex(file)
	if t == null:
		return null
	var sp: Array = spec(file)
	var n: Nine = Nine.new()
	n.texture = t
	var m: Array = sp[0]
	n.margins = Vector4(m[0], m[1], m[2], m[3])
	n.fit_h = sp[1] == "fit_h"
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
	var n: Nine = box("dd_btn_%s_normal" % fam, pad)
	var p: Nine = box("dd_btn_%s_pressed" % fam, pad)
	var d: Nine = box("dd_btn_disabled", pad)
	if n == null or p == null or d == null:
		return false
	var h: Nine = box("dd_btn_%s_normal" % fam, pad, Color(1.12, 1.12, 1.12))
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.set_meta(&"painted", fam)
	return true


## Applies one plate to every button state (hover brightened, pressed darkened). False when missing.
static func skin_plate(b: Button, file: String, pad: float = 6.0, lift: float = 1.0) -> bool:
	var n: Nine = box(file, pad, Color(lift, lift, lift))
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
static func card_body(bg: Color, pad: float, radius: float = 12.0) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
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
	var t: Texture2D = tex(file)
	var ov: RimOverlay = host.get_node_or_null(^"PaintedRim") as RimOverlay
	if t == null:
		if ov != null:
			ov.queue_free()
		return null
	if ov == null:
		ov = RimOverlay.new()
		ov.name = "PaintedRim"
		host.add_child(ov)
		# stay the last child (drawn on top) when the host adds more content later
		host.child_entered_tree.connect(ov._on_sibling)
	ov.nine = box(file, 0.0, Color.WHITE if selected else tint)
	ov.outset = outset
	ov.queue_redraw()
	host.move_child(ov, -1)
	return ov


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
	var nine: Nine = null
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
		nine.corner_px = clampf(minf(r.size.x, r.size.y) * 0.09, 9.0, 15.0)
		draw_style_box(nine, r)
