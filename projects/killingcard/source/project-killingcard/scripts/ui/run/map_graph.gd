# map_graph.gd
# Purpose: The Run v2 map graph (run-v2.md §2.1, kc-v2-ui): 9 steps on 3 lanes, the links between
#   them and one MapNode per node. Landscape: steps run left to right (the boss at the right end).
#   Portrait: steps run bottom to top (step 1 at the bottom, the boss at the top), lanes left to
#   right, so the thumb starts where the run starts.
#   What each node shows (clarity: what the path choice needs): its pictogram, its word (FIGHT 2,
#   ELITE, EVENT, SHOP, REST, BOSS), the crew's name on fights, and one icon per Terrain. Its state is
#   in shape and words, never colour only: played nodes carry WON / LOST / DONE and dim, the node
#   you stand on gets YOU, the nodes you can step to next get an amber frame and a "NEXT" tag, the
#   others are plain. The boss node is bigger with a red skull plate and its rule's name.
#   Links: grey; the path you walked solid; the links you can take now amber.
#   Input: tap = node_tapped (the screen selects it / steps on it), long press / right click =
#   node_inspected (the full node: crew deck, mode, Terrain rules, what it gives and risks).
# Dependencies: run_glyphs.gd, run_v2_views.gd, press_gesture.gd, hud_theme.tres (fonts, colours).
# Author: UI/UX Agent (kc-v2-ui)
extends Control

signal node_tapped(id: String)
signal node_inspected(id: String)

const RunGlyphs: GDScript = preload("res://scripts/ui/run/run_glyphs.gd")
const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")

var map: Dictionary = {}
var portrait: bool = false
var compact: bool = false
var selected_id: String = ""
var _nodes: Dictionary = {}   # id -> MapNode


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false
	resized.connect(_layout)


func set_map(p_map: Dictionary, p_portrait: bool, p_compact: bool) -> void:
	map = p_map
	portrait = p_portrait
	compact = p_compact
	for c: Node in get_children():
		remove_child(c)
		c.queue_free()
	_nodes.clear()
	for n: Dictionary in map.get("nodes", []):
		var mn: MapNode = MapNode.new()
		mn.graph = self
		mn.node = n
		mn.name = "Node_%s" % String(n["id"])
		add_child(mn)
		_nodes[String(n["id"])] = mn
		var id: String = String(n["id"])
		mn.gesture.tapped.connect(func(_p: Vector2) -> void: node_tapped.emit(id))
		mn.gesture.long_pressed.connect(func(_p: Vector2) -> void: node_inspected.emit(id))
		mn.pressed_by_key.connect(func() -> void: node_tapped.emit(id))
	_layout()


func set_selected(id: String) -> void:
	selected_id = id
	for k: String in _nodes:
		(_nodes[k] as MapNode).queue_redraw()
	queue_redraw()


func get_map_node(id: String) -> Control:
	return _nodes.get(id)


func get_map_nodes() -> Array:
	return _nodes.values()


## Node tile size (px): 64 on the phone (46 pt), 72 on bigger canvases; the boss is 1.3x.
func tile_px() -> float:
	var steps: int = int(map.get("steps", 9))
	var along: float = (size.y if portrait else size.x) / maxf(1.0, float(steps))
	var across: float = (size.x if portrait else size.y) / 3.0
	var px: float = 64.0 if compact else 76.0
	return clampf(minf(px, minf(along - (14.0 if portrait else 12.0), across - 56.0)), 48.0, 84.0)


## Centre of the node's tile in graph space for (step 1..steps, lane 0..2).
func cell_center(step: int, lane: int) -> Vector2:
	var steps: int = int(map.get("steps", 9))
	if portrait:
		var sh: float = size.y / float(steps)
		var lw: float = size.x / 3.0
		return Vector2(lw * (lane + 0.5), size.y - sh * (step - 0.5) - label_h() * 0.5)
	var sw: float = size.x / float(steps)
	var lh: float = size.y / 3.0
	return Vector2(sw * (step - 0.5), lh * (lane + 0.5) - label_h() * 0.5)


## Height of the words under a tile.
func label_h() -> float:
	return 36.0 if portrait else 40.0


func _layout() -> void:
	if size.x <= 0.0:
		return
	var px: float = tile_px()
	for k: String in _nodes:
		var mn: MapNode = _nodes[k]
		var n: Dictionary = mn.node
		var boss: bool = n["type"] == &"boss"
		var tp: float = px * (1.3 if boss else 1.0)
		var c: Vector2 = cell_center(int(n["step"]), int(n["lane"]))
		var w: float = maxf(tp, (size.x / 3.0 - 8.0) if portrait else (size.x / float(int(map.get("steps", 9))) - 4.0))
		if boss:
			w = maxf(w, tp + 40.0)
		mn.tile = tp
		mn.position = Vector2(c.x - w * 0.5, c.y - tp * 0.5)
		mn.size = Vector2(w, tp + label_h())
		mn.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var walked: Dictionary = {}
	for n: Dictionary in map.get("nodes", []):
		if bool(n.get("done", false)) or bool(n.get("current", false)):
			walked[String(n["id"])] = true
	var cur: String = ""
	for n: Dictionary in map.get("nodes", []):
		if bool(n.get("current", false)):
			cur = String(n["id"])
	var accent: Color = get_theme_color(&"accent", &"Hud")
	for l: Array in map.get("links", []):
		var a: MapNode = _nodes.get(String(l[0]))
		var b: MapNode = _nodes.get(String(l[1]))
		if a == null or b == null:
			continue
		var pa: Vector2 = a.position + Vector2(a.size.x * 0.5, a.tile * 0.5)
		var pb: Vector2 = b.position + Vector2(b.size.x * 0.5, b.tile * 0.5)
		var col: Color = Color("#3A444D")
		var wdt: float = 2.0
		if walked.has(String(l[0])) and walked.has(String(l[1])):
			col = Color("#8D979F")
			wdt = 4.0
		elif String(l[0]) == cur and bool(b.node.get("reachable", false)):
			col = accent
			wdt = 4.0
		var d: Vector2 = (pb - pa).normalized()
		var from: Vector2 = pa + d * a.tile * 0.55
		var to: Vector2 = pb - d * b.tile * 0.55
		if col == Color("#3A444D"):
			_dashed(from, to, col, wdt)
		else:
			draw_line(from, to, col, wdt, true)


func _dashed(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	# kc-ui-wire2: the kit's dashed path (runmap_path, white dashes) tiled along the link, tinted; else code.
	var tex: Texture2D = UiKit.piece(&"runmap_path")
	if tex != null and a.distance_to(b) > 1.0:
		var h: float = maxf(4.0, w * 2.5)
		draw_set_transform(a, (b - a).angle())
		UiKit.draw_tiled(self, &"runmap_path", Rect2(0.0, -h * 0.5, a.distance_to(b), h), c.lightened(0.25), h / tex.get_size().y)
		draw_set_transform(Vector2.ZERO)
		return
	var len: float = a.distance_to(b)
	var d: Vector2 = (b - a) / maxf(1.0, len)
	var t: float = 0.0
	while t < len:
		draw_line(a + d * t, a + d * minf(len, t + 7.0), c, w)
		t += 12.0


# =============================================================================
# One node
# =============================================================================

class MapNode extends Button:
	signal pressed_by_key
	var graph: Control = null
	var node: Dictionary = {}
	var tile: float = 64.0
	var gesture: RefCounted = null

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		add_to_group(&"tap_target")
		set_meta(&"inspectable", true)
		gesture = (load("res://scripts/ui/press_gesture.gd") as GDScript).new(self)
		gesture.drag_enabled = false

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton or e is InputEventMouseMotion:
			if gesture.handle(e):
				accept_event()
			return
		if e.is_action_pressed(&"ui_accept"):
			accept_event()
			pressed_by_key.emit()

	func _draw() -> void:
		var t: StringName = node.get("type", &"fight")
		var boss: bool = t == &"boss"
		var done: bool = bool(node.get("done", false)) and not bool(node.get("current", false))
		var cur: bool = bool(node.get("current", false))
		var reach: bool = bool(node.get("reachable", false))
		var sel: bool = graph != null and graph.selected_id == String(node.get("id", ""))
		var accent: Color = get_theme_color(&"accent", &"Hud")
		var friend: Color = get_theme_color(&"friend", &"Hud")
		var enemy: Color = get_theme_color(&"enemy", &"Hud")
		var tr: Rect2 = Rect2(Vector2((size.x - tile) * 0.5, 0), Vector2(tile, tile))
		var fill: Color = Color("#5A1A1C") if boss else Color("#1C2228")
		# kc-ui-wire2: with the kit's node ring (runmap_node, a hexagon) the tile is a filled hexagon and
		# the ring carries the state colour; the square tile and frame are the fallback.
		var hex: bool = UiKit.has_piece(&"runmap_node")
		if hex:
			var hp: PackedVector2Array = []
			for i: int in 6:
				hp.append(tr.get_center() + Vector2.from_angle(PI / 3.0 * i) * tile * 0.47)
			draw_colored_polygon(hp, Color(fill, 0.55 if done else 0.95))
		else:
			draw_rect(tr, Color(fill, 0.55 if done else 0.95))
		var glyph_c: Color = RunGlyphs.node_tint(t)
		if done:
			glyph_c = Color(glyph_c, 0.45)
		RunGlyphs.draw_node(self, tr.grow(-tile * 0.16), t, glyph_c)
		# Frame: shape carries the state.
		if hex:
			var ring_c: Color = friend if cur else accent if reach else enemy if boss else Color("#5A646D")
			UiKit.draw_piece(self, &"runmap_node", tr.grow(2.0 if reach and not cur else 0.0), ring_c)
		elif cur:
			draw_rect(tr, friend, false, 3.0)
		elif reach:
			draw_rect(tr.grow(2.0), accent, false, 3.0)
		elif boss:
			draw_rect(tr, enemy, false, 2.5)
		else:
			draw_rect(tr, Color("#3A444D"), false, 1.5)
		if sel:
			draw_rect(tr.grow(6.0), Color.WHITE, false, 2.0)
		if has_focus():
			draw_rect(tr.grow(9.0), Color(accent, 0.7), false, 1.5)
		# Terrain icons on the tile's bottom edge.
		var ts: Array = node.get("terrain", [])
		var ip: float = clampf(tile * 0.32, 18.0, 26.0)
		var x0: float = tr.end.x - ip * ts.size() - 2.0
		for i: int in ts.size():
			var tid: StringName = StringName(str((ts[i] as Dictionary).get("id", "")))
			var ir: Rect2 = Rect2(Vector2(x0 + ip * i, tr.end.y - ip - 2.0), Vector2(ip, ip))
			draw_rect(ir, Color(RunGlyphs.terrain_tint(tid), 0.95 if not done else 0.5))
			RunGlyphs.draw_terrain(self, ir.grow(-ip * 0.14), tid, RunGlyphs.INK)
		# State tag on the tile's top edge.
		var tag: String = ""
		var tag_bg: Color = Color(0, 0, 0, 0)
		var tag_fg: Color = Color.WHITE
		if cur:
			tag = "YOU"
			tag_bg = friend
			tag_fg = RunGlyphs.INK
		elif done:
			tag = {&"player": "WON", &"enemy": "LOST", &"draw": "DRAW"}.get(StringName(str(node.get("result", ""))), "DONE")
			tag_bg = Color("#2E3439")
		elif reach:
			tag = "NEXT"
			tag_bg = accent
			tag_fg = RunGlyphs.INK
		if tag != "":
			_tag(Vector2(tr.position.x, tr.position.y), tag, tag_fg, tag_bg)
		# Words under the tile.
		var font: Font = get_theme_font(&"font", &"HudHeader")
		var fs: int = 16
		var word: String = _word()
		var y: float = tr.end.y + 4.0 + font.get_ascent(fs)
		var wc: Color = Color("#D8DEE3") if not done else Color("#8D979F")
		if boss:
			wc = enemy
		_centered(font, word, y, fs, wc)
		var sub: String = _sub()
		if sub != "":
			var f2: Font = get_theme_font(&"font", &"HudSubtle")
			_centered(f2, sub, y + 17.0, 16, Color("#B9C2C9") if not done else Color("#6E7880"))

	func _word() -> String:
		var t: StringName = node.get("type", &"fight")
		match t:
			&"fight":
				var f: int = int(node.get("fight", 0))
				return "FIGHT %d" % f if f > 0 else "FIGHT"
			&"boss":
				return "BOSS"
		return String(RunV2Views.NODE_WORDS.get(t, ["?"])[0])

	func _sub() -> String:
		var t: StringName = node.get("type", &"fight")
		if t == &"boss":
			var b: Dictionary = graph.map.get("boss", {}) if graph != null else {}
			return String(b.get("name", node.get("crew", "")))
		if t == &"fight" or t == &"elite":
			var crew: String = String(node.get("crew", ""))
			var close: int = crew.find("] ")
			if close >= 0:
				crew = crew.substr(close + 2)
			var plus: int = crew.find(" +")
			return crew.substr(0, plus) if plus > 0 else crew
		return ""

	func _centered(font: Font, text: String, y: float, fs: int, c: Color) -> void:
		var room: float = size.x - 2.0
		var s: String = BannerView.fit_text(text, font, fs, room)
		var w: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(font, Vector2((size.x - w) * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, RunGlyphs.INK)
		draw_string(font, Vector2((size.x - w) * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

	func _tag(at: Vector2, text: String, fg: Color, bg: Color) -> void:
		var font: Font = get_theme_font(&"font", &"HudHeader")
		var fs: int = 14
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0
		var r: Rect2 = Rect2(at + Vector2(-2, -8), Vector2(w, 18))
		draw_rect(r, bg)
		draw_string(font, Vector2(r.position.x + 4.0, r.position.y + 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
