# card_view.gd
# Purpose: Reusable placeholder card face (scenes/match/CardView.tscn). Shows cost (or killstreak
#   threshold), name, type/class, keyword icons, one rules line, range strip and FP/Armor badges.
#   The frame is drawn in _draw() as flat vector shapes, so it stays crisp at any scale:
#     unit = ID badge with lanyard slot; tactic = cut corners + "radio order" header bar;
#     equipment = gear tag with clipped corner and eyelet; killstreak = cyan tablet + scanlines;
#     operator = dog tag (round corners, chain hole).
#   Friend / enemy is shown by SHAPE as well as colour (colour-blind safe):
#     friend = chevron spine on the left edge + chevron notch cut into the bottom edge (teal);
#     enemy  = hazard-stripe spine on the left edge + hazard-stripe band along the bottom (red).
#   Text auto-shrinks to fit its slot; at 50% scale the readouts are cost, name, stats and
#   keyword icons, and full text is for the inspector (long-press).
# Usage:
#   var card := preload("res://scenes/match/CardView.tscn").instantiate()
#   card.set_card_data({"name": "Breacher", "type": "unit", "weapon_class": "shotgun", "cost": 3,
#       "firepower": 3, "armor": 4, "keywords": [{"id": "first_shot"}], "side": "friend"})
#   card.set_card(card_resource)  # reads the same field names from a Resource (see _from_resource)
# Dependencies: assets/ui/card_theme.tres, scripts/ui/icon_sheet.gd, assets/shaders/scanlines.gdshader
# Author: Technical Artist Agent (p13)
class_name CardView
extends Control

signal card_changed

const BASE_SIZE: Vector2 = Vector2(250, 350)
const SPINE_W: float = 10.0
const EDGE_H: float = 14.0
const NOTCH_W: float = 56.0
const NOTCH_DEPTH: float = 14.0
const COST_RECT: Rect2 = Rect2(16, 10, 46, 46)
const FP_RECT: Rect2 = Rect2(16, 296, 74, 36)
const ARMOR_RECT: Rect2 = Rect2(162, 296, 74, 36)
const KEYWORD_ROW_W: float = 222.0
const BODY_TOP: float = 228.0
const BODY_BOTTOM_UNIT: float = 274.0
const BODY_BOTTOM_OTHER: float = 330.0

## Weapon class -> [close, mid, long] Firepower modifiers (core-rules.md §1).
const RANGE_MODS: Dictionary = {
	&"smg": [1, 0, 0], &"shotgun": [2, 0, -1], &"ar": [0, 1, 0], &"sniper": [-1, 0, 2], &"lmg": [0, 0, 0],
}
const RANGE_NAMES: PackedStringArray = ["CLOSE", "MID", "LONG"]
const KEYWORD_LABELS: Dictionary = {
	&"first_shot": "FIRST SHOT", &"pick": "PICK", &"flank": "FLANK", &"cover": "COVER",
	&"suppress": "SUPPRESS", &"patch": "PATCH", &"holder": "HOLDER",
	&"on_deploy": "ON DEPLOY", &"on_down": "ON DOWN",
}

## Placeholder shown in the editor and when no data is set.
const PLACEHOLDER: Dictionary = {
	"name": "Breacher", "type": "unit", "weapon_class": "shotgun", "cost": 3, "firepower": 3,
	"armor": 4, "keywords": [{"id": "first_shot"}], "text": "", "side": "friend",
}

## "friend" or "enemy". Drives the shape cues and the spine colour.
@export_enum("friend", "enemy") var side: String = "friend":
	set(value):
		side = value
		queue_redraw()

var data: Dictionary = {}

@onready var _cost_label: Label = %CostLabel
@onready var _elite_icon: TextureRect = %EliteIcon
@onready var _name_label: Label = %NameLabel
@onready var _type_icon: TextureRect = %TypeIcon
@onready var _type_label: Label = %TypeLabel
@onready var _art_icon: TextureRect = %ArtIcon
@onready var _scanlines: ColorRect = %Scanlines
@onready var _keyword_row: HBoxContainer = %KeywordRow
@onready var _body_label: Label = %BodyLabel
@onready var _range_row: HBoxContainer = %RangeRow
@onready var _range_icon: TextureRect = %RangeIcon
@onready var _range_label: Label = %RangeLabel
@onready var _fp_badge: Control = %FirepowerBadge
@onready var _fp_label: Label = %FirepowerLabel
@onready var _fp_icon: TextureRect = %FirepowerIcon
@onready var _armor_badge: Control = %ArmorBadge
@onready var _armor_label: Label = %ArmorLabel
@onready var _armor_icon: TextureRect = %ArmorIcon


func _ready() -> void:
	_fp_icon.texture = IconSheet.get_icon(&"stat_firepower")
	_armor_icon.texture = IconSheet.get_icon(&"stat_armor")
	_elite_icon.texture = IconSheet.get_icon(&"elite")
	if data.is_empty():
		data = PLACEHOLDER.duplicate(true)
	_refresh()


## Shows a card from a plain Dictionary. Keys: name, type (unit|tactic|equipment|killstreak|operator),
## weapon_class (smg|shotgun|ar|sniper|lmg|""), cost, firepower, armor, keywords (Array of ids or
## {id, value}), text, side (friend|enemy), elite (bool), threshold (killstreaks), art_icon (icon name).
func set_card_data(card: Dictionary) -> void:
	data = card.duplicate(true)
	side = String(data.get("side", side))
	if is_node_ready():
		_refresh()


## Shows a card Resource (p02 data classes). Reads fields by name, so it does not depend on the class.
func set_card(card: Resource, card_side: String = "friend") -> void:
	var d: Dictionary = _from_resource(card)
	d["side"] = card_side
	set_card_data(d)


## Names of labels whose text does not fit inside its slot (empty = everything fits).
func get_overflowing_labels() -> PackedStringArray:
	var out: PackedStringArray = []
	for label: Label in _text_labels():
		if not label.is_visible_in_tree() or label.text.is_empty():
			continue
		var slot: Vector2 = label.get_meta(&"slot_size", label.size)
		var need: Vector2 = _text_size(label)
		if need.x > slot.x + 0.5 or need.y > slot.y + 0.5:
			out.append("%s (%s needs %s, slot %s)" % [label.name, label.text, need, slot])
	var labels: Array[Label] = []
	for child: Node in _keyword_row.get_children():
		if child is Label:
			labels.append(child)
	if _keyword_row_width(labels) > KEYWORD_ROW_W + 0.5 or _keyword_row.size.x > KEYWORD_ROW_W + 0.5:
		out.append("KeywordRow (%d px > %d px)" % [maxf(_keyword_row_width(labels), _keyword_row.size.x), KEYWORD_ROW_W])
	return out


## Smallest effective on-screen font size of the given role labels, after this card's scale.
func get_min_effective_font_size(label_names: PackedStringArray) -> float:
	var smallest: float = INF
	for label: Label in _text_labels():
		if label_names.has(label.name) and label.is_visible_in_tree() and not label.text.is_empty():
			smallest = minf(smallest, label.get_theme_font_size(&"font_size") * get_global_transform().get_scale().y)
	return smallest


func _from_resource(card: Resource) -> Dictionary:
	var d: Dictionary = {}
	var props: Array = []
	for p: Dictionary in card.get_property_list():
		props.append(p["name"])
	var pick := func(names: Array, fallback: Variant) -> Variant:
		for n: String in names:
			if props.has(n) and card.get(n) != null:
				return card.get(n)
		return fallback
	d["name"] = str(pick.call(["display_name", "name", "title", "id"], "Card"))
	d["type"] = str(pick.call(["card_type", "type"], "unit")).to_lower()
	d["weapon_class"] = str(pick.call(["weapon_class", "class_tag", "klass"], "")).to_lower()
	d["cost"] = int(pick.call(["cost"], 0))
	d["firepower"] = int(pick.call(["firepower", "fp"], 0))
	d["armor"] = int(pick.call(["armor", "max_armor"], 0))
	d["keywords"] = pick.call(["keywords"], [])
	d["text"] = str(pick.call(["rules_text", "text"], ""))
	d["elite"] = bool(pick.call(["elite", "is_elite"], false))
	d["threshold"] = int(pick.call(["threshold"], 0))
	return d


func _card_type() -> String:
	return String(data.get("type", "unit"))


func _has_stats() -> bool:
	return _card_type() in ["unit", "operator"]


func _refresh() -> void:
	var type_name: String = _card_type()
	var weapon: StringName = StringName(String(data.get("weapon_class", "")).to_lower())
	# Cost or threshold badge.
	if type_name == "killstreak":
		_cost_label.text = str(int(data.get("threshold", 0)))
		_cost_label.theme_type_variation = &"CardThreshold"
	else:
		_cost_label.text = str(int(data.get("cost", 0)))
		_cost_label.theme_type_variation = &"CardCost"
	_cost_label.visible = type_name != "operator"
	_elite_icon.visible = bool(data.get("elite", false))
	# Name and type line.
	_name_label.text = String(data.get("name", "")).replace("★", "").strip_edges()
	var name_right: float = 206.0 if type_name == "equipment" else 238.0
	var name_left: float = 20.0 if type_name == "operator" else 70.0
	_set_slot(_name_label, Rect2(name_left, 12, name_right - name_left, 26))
	_type_icon.texture = IconSheet.get_icon(StringName("type_" + type_name))
	var tag: String = type_name.to_upper()
	if weapon != &"":
		tag += " · " + String(weapon).to_upper()
	_type_label.text = tag
	_type_label.set_meta(&"slot_size", Vector2(238.0 - (name_left + 20.0) - 12.0, 20.0))
	_range_label.set_meta(&"slot_size", Vector2(200.0, 18.0))
	_type_icon.position.x = name_left
	var chip: Control = _type_label.get_parent()
	chip.position.x = name_left + 20
	chip.size = Vector2.ZERO  # shrink the chip back to its text
	# Art window silhouette: killstreak/class/type icon.
	var art: StringName = StringName(String(data.get("art_icon", "")))
	if art == &"" or not IconSheet.has_icon(art):
		art = StringName("class_" + String(weapon)) if weapon != &"" else StringName("type_" + type_name)
	_art_icon.texture = IconSheet.get_icon(art)
	_scanlines.visible = type_name == "killstreak"
	# Keywords.
	_rebuild_keywords()
	# Body text.
	_body_label.text = String(data.get("text", ""))
	var body_bottom: float = BODY_BOTTOM_UNIT if _has_stats() else BODY_BOTTOM_OTHER
	var body_top: float = BODY_TOP if _keyword_row.get_child_count() > 0 else 204.0
	_set_slot(_body_label, Rect2(16, body_top, 222, body_bottom - body_top))
	# Range strip and stats.
	_range_row.visible = _has_stats() and RANGE_MODS.has(weapon)
	if _range_row.visible:
		_range_label.text = _range_text(weapon)
		var best: int = _best_band(weapon)
		_range_icon.texture = IconSheet.get_icon(StringName("range_" + RANGE_NAMES[best].to_lower()) if best >= 0 else &"range_mid")
	_fp_badge.visible = _has_stats()
	_armor_badge.visible = _has_stats()
	_fp_label.text = str(int(data.get("firepower", 0)))
	_armor_label.text = str(int(data.get("armor", 0)))
	_tint_icons()
	_fit_all()
	queue_redraw()
	card_changed.emit()


func _rebuild_keywords() -> void:
	for child: Node in _keyword_row.get_children():
		_keyword_row.remove_child(child)
		child.queue_free()
	var keywords: Array = data.get("keywords", [])
	for entry: Variant in keywords:
		var id: StringName
		var value: int = 0
		if entry is Dictionary:
			id = StringName(String(entry.get("id", "")))
			value = int(entry.get("value", 0))
		else:
			id = StringName(String(entry))
		var icon_rect := TextureRect.new()
		icon_rect.texture = IconSheet.get_keyword_icon(id)
		icon_rect.custom_minimum_size = Vector2(22, 22)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.modulate = get_theme_color(&"accent", &"Card")
		_keyword_row.add_child(icon_rect)
		var label := Label.new()
		label.name = "Keyword%d" % _keyword_row.get_child_count()
		label.theme_type_variation = &"CardKeyword"
		label.text = String(KEYWORD_LABELS.get(id, String(id).to_upper()))
		if value > 0:
			label.text += " %d" % value
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_keyword_row.add_child(label)
	# With 3+ keywords, icons carry the meaning and labels shorten to fit the row.
	_keyword_row.add_theme_constant_override(&"separation", 4 if keywords.size() > 1 else 6)


func _range_text(weapon: StringName) -> String:
	var mods: Array = RANGE_MODS[weapon]
	var parts: PackedStringArray = []
	for i: int in 3:
		if int(mods[i]) != 0:
			parts.append("%s %s%d" % [RANGE_NAMES[i], "+" if int(mods[i]) > 0 else "−", absi(int(mods[i]))])
	return "NO RANGE MOD" if parts.is_empty() else " · ".join(parts)


func _best_band(weapon: StringName) -> int:
	var mods: Array = RANGE_MODS[weapon]
	var best: int = -1
	var best_value: int = 0
	for i: int in 3:
		if int(mods[i]) > best_value:
			best_value = int(mods[i])
			best = i
	return best


func _tint_icons() -> void:
	var text_dim: Color = get_theme_color(&"text_dim", &"Card")
	var art_tint: Color = get_theme_color(&"special", &"Card") if _card_type() == "killstreak" else get_theme_color(&"concrete", &"Card")
	_art_icon.modulate = Color(art_tint, 0.55)
	_type_icon.modulate = get_theme_color(&"text", &"Card")
	_range_icon.modulate = text_dim
	_fp_icon.modulate = get_theme_color(&"text", &"Card")
	_armor_icon.modulate = get_theme_color(&"text", &"Card")
	_elite_icon.modulate = get_theme_color(&"elite", &"Card")


# --- Text fitting -------------------------------------------------------------------------

func _set_slot(label: Label, rect: Rect2) -> void:
	label.position = rect.position
	label.size = rect.size
	label.set_meta(&"slot_size", rect.size)


func _text_labels() -> Array[Label]:
	var out: Array[Label] = [_cost_label, _name_label, _type_label, _body_label, _range_label, _fp_label, _armor_label]
	for child: Node in _keyword_row.get_children():
		if child is Label:
			out.append(child)
	return out


func _text_size(label: Label) -> Vector2:
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var text: String = label.text.to_upper() if label.uppercase else label.text
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		var slot: Vector2 = label.get_meta(&"slot_size", label.size)
		var s: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, slot.x, font_size)
		var lines: int = maxi(1, roundi(s.y / font.get_height(font_size)))
		return Vector2(s.x, lines * (font.get_height(font_size) + label.get_theme_constant(&"line_spacing")))
	return Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, font.get_height(font_size))


func _fit(label: Label, min_size: int) -> void:
	label.remove_theme_font_size_override(&"font_size")
	var font_size: int = label.get_theme_font_size(&"font_size")
	var slot: Vector2 = label.get_meta(&"slot_size", label.size)
	while font_size > min_size:
		var need: Vector2 = _text_size(label)
		if need.x <= slot.x and need.y <= slot.y:
			break
		font_size -= 1
		label.add_theme_font_size_override(&"font_size", font_size)


func _fit_all() -> void:
	_fit(_name_label, 13)
	_fit(_type_label, 10)
	_fit(_body_label, 10)
	# Keyword row: shrink labels together until the row fits its width.
	var labels: Array[Label] = []
	for child: Node in _keyword_row.get_children():
		if child is Label:
			labels.append(child)
			child.remove_theme_font_size_override(&"font_size")
	var font_size: int = 15
	while font_size > 10 and _keyword_row_width(labels) > KEYWORD_ROW_W:
		font_size -= 1
		for l: Label in labels:
			l.add_theme_font_size_override(&"font_size", font_size)
	# Still too wide: icons carry the meaning, labels hide (full text lives in the inspector).
	if _keyword_row_width(labels) > KEYWORD_ROW_W:
		for l: Label in labels:
			l.visible = false
	for l: Label in labels:
		l.set_meta(&"slot_size", Vector2(_text_size(l).x, _keyword_row.size.y))


func _keyword_row_width(labels: Array[Label]) -> float:
	var sep: int = _keyword_row.get_theme_constant(&"separation")
	var w: float = 0.0
	if labels.is_empty():
		return 0.0
	for l: Label in labels:
		w += 22.0 + sep
		if l.visible:
			w += _text_size(l).x + sep
	return w - sep


# --- Frame drawing ------------------------------------------------------------------------

func _draw() -> void:
	var type_name: String = _card_type()
	var is_friend: bool = side != "enemy"
	var side_color: Color = get_theme_color(&"friend" if is_friend else &"enemy", &"Card")
	var bg: Color = get_theme_color(&"background", &"Card")
	var face: Color = get_theme_color(StringName("face_" + type_name), &"Card")
	var frame: Color = get_theme_color(&"frame_standard", &"Card")
	if bool(data.get("elite", false)):
		frame = get_theme_color(&"elite", &"Card")
	elif type_name == "killstreak":
		frame = get_theme_color(&"special", &"Card")
	var outline: PackedVector2Array = _outline(type_name, is_friend)
	draw_colored_polygon(outline, face)
	# Type decorations.
	match type_name:
		"tactic":
			var header: PackedVector2Array = _clip(outline, Rect2(0, 0, BASE_SIZE.x, 58))
			draw_colored_polygon(header, face.lightened(0.08))
			_draw_waveform(Rect2(150, 40, 86, 14), Color(get_theme_color(&"text", &"Card"), 0.25))
		"equipment":
			draw_rect(Rect2(16, 199, 222, 4), get_theme_color(&"sand", &"Card"))  # solid tape (not hazard)
			draw_circle(Vector2(224, 22), 7.0, bg)
			draw_arc(Vector2(224, 22), 7.0, 0, TAU, 20, frame, 2.0, true)
		"unit":
			_draw_slot(Rect2(BASE_SIZE.x * 0.5 - 18, 3, 36, 6), bg)
		"operator":
			draw_circle(Vector2(BASE_SIZE.x * 0.5, 9), 4.0, bg)
	# Side cue: spine on the left edge.
	var spine: PackedVector2Array = _clip(outline, Rect2(0, 0, SPINE_W, BASE_SIZE.y))
	if is_friend:
		draw_colored_polygon(spine, side_color)
		var y: float = 66.0
		while y < BASE_SIZE.y - 40.0:
			draw_polyline(PackedVector2Array([Vector2(1.5, y + 6), Vector2(SPINE_W * 0.5, y), Vector2(SPINE_W - 1.5, y + 6)]), bg, 2.0, true)
			y += 22.0
	else:
		_draw_hazard(spine, side_color, bg, 9.0)
	# Side cue: bottom edge (friend = notch, the outline already has it; enemy = hazard band).
	var band: PackedVector2Array = _clip(outline, Rect2(0, BASE_SIZE.y - EDGE_H, BASE_SIZE.x, EDGE_H))
	if is_friend:
		draw_colored_polygon(band, Color(side_color, 0.85))
	else:
		_draw_hazard(band, side_color, bg, 11.0)
	draw_polyline(_closed(outline), frame, 3.0 if type_name == "killstreak" or bool(data.get("elite", false)) else 2.0, true)
	# Cost / threshold hex badge.
	if type_name != "operator":
		var badge_color: Color = get_theme_color(&"special" if type_name == "killstreak" else &"accent", &"Card")
		var hex: PackedVector2Array = _hex(COST_RECT)
		draw_colored_polygon(hex, badge_color)
		draw_polyline(_closed(hex), badge_color.darkened(0.35), 2.0, true)
	# Stat plates.
	if _has_stats():
		for r: Rect2 in [FP_RECT, ARMOR_RECT]:
			var plate: PackedVector2Array = _chamfer_rect(r, [6.0, 6.0, 6.0, 6.0])
			draw_colored_polygon(plate, bg)
			draw_polyline(_closed(plate), Color(frame, 0.8), 1.5, true)


func _outline(type_name: String, is_friend: bool) -> PackedVector2Array:
	var r := Rect2(Vector2.ZERO, BASE_SIZE)
	var pts: PackedVector2Array
	match type_name:
		"tactic":
			pts = _chamfer_rect(r, [20.0, 20.0, 20.0, 20.0])
		"equipment":
			pts = _chamfer_rect(r, [6.0, 34.0, 6.0, 6.0])
		"killstreak":
			pts = _chamfer_rect(r, [4.0, 4.0, 4.0, 4.0])
		"operator":
			pts = _rounded_rect(r, 30.0)
		_:
			pts = _chamfer_rect(r, [8.0, 8.0, 8.0, 8.0])
	if is_friend:
		pts = _with_notch(pts)
	return pts


## Rectangle with cut corners. Corner order: top-left, top-right, bottom-right, bottom-left.
func _chamfer_rect(r: Rect2, c: Array) -> PackedVector2Array:
	var a: Vector2 = r.position
	var b: Vector2 = r.end
	return PackedVector2Array([
		Vector2(a.x + c[0], a.y), Vector2(b.x - c[1], a.y), Vector2(b.x, a.y + c[1]),
		Vector2(b.x, b.y - c[2]), Vector2(b.x - c[2], b.y), Vector2(a.x + c[3], b.y),
		Vector2(a.x, b.y - c[3]), Vector2(a.x, a.y + c[0]),
	])


func _rounded_rect(r: Rect2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var centers: Array[Vector2] = [
		r.position + Vector2(radius, radius), Vector2(r.end.x - radius, r.position.y + radius),
		r.end - Vector2(radius, radius), Vector2(r.position.x + radius, r.end.y - radius),
	]
	for i: int in 4:
		var start: float = PI + i * PI * 0.5
		for s: int in 9:
			pts.append(centers[i] + Vector2.from_angle(start + s * PI * 0.5 / 8.0) * radius)
	return pts


## Inserts the friendly chevron notch into the bottom edge of a clockwise outline.
func _with_notch(pts: PackedVector2Array) -> PackedVector2Array:
	var bottom: float = BASE_SIZE.y
	var cx: float = BASE_SIZE.x * 0.5
	var notch := PackedVector2Array([
		Vector2(cx + NOTCH_W * 0.5, bottom), Vector2(cx, bottom - NOTCH_DEPTH), Vector2(cx - NOTCH_W * 0.5, bottom),
	])
	var out := PackedVector2Array()
	var inserted: bool = false
	for i: int in pts.size():
		out.append(pts[i])
		var nxt: Vector2 = pts[(i + 1) % pts.size()]
		if not inserted and absf(pts[i].y - bottom) < 0.01 and absf(nxt.y - bottom) < 0.01 \
				and pts[i].x > cx and nxt.x < cx:
			out.append_array(notch)
			inserted = true
	return out


func _hex(r: Rect2) -> PackedVector2Array:
	var c: Vector2 = r.get_center()
	var rad: float = r.size.x * 0.5
	var pts := PackedVector2Array()
	for i: int in 6:
		pts.append(c + Vector2.from_angle(PI / 6.0 + i * PI / 3.0) * rad)
	return pts


func _clip(poly: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	var rect_poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var result: Array[PackedVector2Array] = Geometry2D.intersect_polygons(poly, rect_poly)
	return result[0] if not result.is_empty() else PackedVector2Array()


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	if not pts.is_empty():
		out.append(pts[0])
	return out


func _draw_hazard(area: PackedVector2Array, stripe: Color, gap: Color, pitch: float) -> void:
	if area.is_empty():
		return
	draw_colored_polygon(area, stripe)
	var bounds := Rect2(area[0], Vector2.ZERO)
	for p: Vector2 in area:
		bounds = bounds.expand(p)
	var x: float = bounds.position.x - bounds.size.y
	while x < bounds.end.x:
		var band := PackedVector2Array([
			Vector2(x, bounds.end.y), Vector2(x + pitch * 0.5, bounds.end.y),
			Vector2(x + pitch * 0.5 + bounds.size.y, bounds.position.y), Vector2(x + bounds.size.y, bounds.position.y),
		])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(area, band):
			draw_colored_polygon(piece, gap)
		x += pitch


func _draw_slot(r: Rect2, color: Color) -> void:
	draw_rect(Rect2(r.position + Vector2(r.size.y * 0.5, 0), r.size - Vector2(r.size.y, 0)), color)
	draw_circle(r.position + Vector2(r.size.y * 0.5, r.size.y * 0.5), r.size.y * 0.5, color)
	draw_circle(r.position + Vector2(r.size.x - r.size.y * 0.5, r.size.y * 0.5), r.size.y * 0.5, color)


func _draw_waveform(r: Rect2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 25:
		var t: float = i / 24.0
		var amp: float = sin(t * PI) * (0.5 if i % 2 == 0 else -0.5) * (0.4 + 0.6 * absf(sin(i * 1.7)))
		pts.append(Vector2(r.position.x + t * r.size.x, r.get_center().y + amp * r.size.y))
	draw_polyline(pts, color, 1.5, true)
