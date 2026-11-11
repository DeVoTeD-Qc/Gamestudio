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
#   kc-da-ui2 (art direction #8, "a paper map pinned to the briefing table"): the graph is drawn on
#   light orders paper (fibre, a faint coordinate grid, one fold); nodes are paper tags held by a pin
#   (teal where you stand, steel for the next steps, khaki for the rest, red for the boss); links are
#   strings with a slight sag (ink where you walked, deep teal for the steps you can take now, a thin
#   twine otherwise); the boss is a target mark ringed with a red marker circle, never a skull. The
#   NEXT tag is a steel tag and the selection is a steel-and-paper double rule (no white box, no amber).
# Dependencies: run_glyphs.gd, run_v2_views.gd, press_gesture.gd, paper_sheet.gd, hud_theme.tres (fonts).
# Author: UI/UX Agent (kc-v2-ui)
extends Control

signal node_tapped(id: String)
signal node_inspected(id: String)

const RunGlyphs: GDScript = preload("res://scripts/ui/run/run_glyphs.gd")
const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const PaperSheet: GDScript = preload("res://scripts/ui/paper_sheet.gd")
## Briefing-map inks (on PaperSheet.PAPER).
const TWINE: Color = Color("#8A7B5A")
const PIN_TEAL: Color = Color("#2EC4B6")
const PIN_STEEL: Color = Color("#4A535B")
const PIN_KHAKI: Color = Color("#B8913A")
const MARKER_RED: Color = Color("#C0262B")
const TAG_STEEL: Color = Color("#3A444D")
## The paper's margin around the graph (px).
const PAPER_PAD: float = 6.0

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
	_draw_paper()
	var walked: Dictionary = {}
	for n: Dictionary in map.get("nodes", []):
		if bool(n.get("done", false)) or bool(n.get("current", false)):
			walked[String(n["id"])] = true
	var cur: String = ""
	for n: Dictionary in map.get("nodes", []):
		if bool(n.get("current", false)):
			cur = String(n["id"])
	# Strings: twine first, then the walked path, then the steps you can take now (on top).
	for pass_i: int in 3:
		for l: Array in map.get("links", []):
			var a: MapNode = _nodes.get(String(l[0]))
			var b: MapNode = _nodes.get(String(l[1]))
			if a == null or b == null:
				continue
			var kind: int = 0
			if walked.has(String(l[0])) and walked.has(String(l[1])):
				kind = 1
			elif String(l[0]) == cur and bool(b.node.get("reachable", false)):
				kind = 2
			if kind != pass_i:
				continue
			var pa: Vector2 = a.position + Vector2(a.size.x * 0.5, a.tile * 0.5)
			var pb: Vector2 = b.position + Vector2(b.size.x * 0.5, b.tile * 0.5)
			var d: Vector2 = (pb - pa).normalized()
			var from: Vector2 = pa + d * a.tile * 0.5
			var to: Vector2 = pb - d * b.tile * 0.5
			match kind:
				0:
					_string(from, to, Color(TWINE, 0.75), 1.5)
				1:
					_string(from, to, PaperSheet.INK, 3.0)
				2:
					_string(from, to, PaperSheet.STAMP_WIN, 3.5)


## kc-da-ui2: the paper sheet under the graph: paper, fibre, a faint coordinate grid, one fold.
func _draw_paper() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size).grow(PAPER_PAD)
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.4))
	draw_rect(r, PaperSheet.PAPER)
	PaperSheet.draw_fibre(self, r, 31)
	var grid: float = 48.0
	var gc: Color = Color(PaperSheet.INK, 0.06)
	var x: float = r.position.x + grid
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), gc, 1.0)
		x += grid
	var y: float = r.position.y + grid
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), gc, 1.0)
		y += grid
	# One fold across the sheet: a soft shadow line and its highlight.
	var fx: float = r.position.x + r.size.x * (0.5 if not portrait else 0.0)
	if not portrait:
		draw_line(Vector2(fx, r.position.y), Vector2(fx, r.end.y), Color(PaperSheet.INK, 0.08), 2.0)
		draw_line(Vector2(fx + 2.0, r.position.y), Vector2(fx + 2.0, r.end.y), Color(1, 1, 1, 0.25), 1.0)
	else:
		var fy: float = r.position.y + r.size.y * 0.5
		draw_line(Vector2(r.position.x, fy), Vector2(r.end.x, fy), Color(PaperSheet.INK, 0.08), 2.0)
		draw_line(Vector2(r.position.x, fy + 2.0), Vector2(r.end.x, fy + 2.0), Color(1, 1, 1, 0.25), 1.0)
	draw_rect(r, PaperSheet.KHAKI, false, 1.5)


## A string from a to b with a slight sag (a quadratic curve), drawn as a polyline.
func _string(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	var len: float = a.distance_to(b)
	if len < 1.0:
		return
	var mid: Vector2 = (a + b) * 0.5 + Vector2(0, minf(10.0, len * 0.06))
	var pts: PackedVector2Array = []
	for i: int in 13:
		var t: float = float(i) / 12.0
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	draw_polyline(pts, c, w, true)


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
		var ink: Color = PaperSheet.INK
		var tr: Rect2 = Rect2(Vector2((size.x - tile) * 0.5, 0), Vector2(tile, tile))
		# kc-da-ui2: a paper tag pinned to the map (a shadow, the tag, an ink rule).
		var tag_r: Rect2 = tr.grow(-tile * 0.06)
		draw_rect(Rect2(tag_r.position + Vector2(2, 3), tag_r.size), Color(0, 0, 0, 0.18))
		draw_rect(tag_r, PaperSheet.PAPER_SHADE if not done else Color(PaperSheet.PAPER_SHADE, 0.7))
		var glyph_c: Color = MARKER_RED if boss else (Color(ink, 0.4) if done else ink)
		RunGlyphs.draw_node(self, tag_r.grow(-tile * 0.14), t, glyph_c)
		# Frame: shape carries the state (teal = you, steel double rule = next, thin ink = the rest).
		if cur:
			draw_rect(tag_r.grow(1.0), PIN_TEAL, false, 3.0)
		elif reach:
			draw_rect(tag_r, TAG_STEEL, false, 3.0)
			draw_rect(tag_r.grow(-4.0), Color(TAG_STEEL, 0.6), false, 1.0)
		else:
			draw_rect(tag_r, Color(ink, 0.45 if done else 0.7), false, 1.5)
		if boss:
			# The red marker circle round the target (two strokes, slightly off, like a hand ring).
			var ctr: Vector2 = tr.get_center()
			var rad: float = tile * 0.6
			_ellipse(ctr, Vector2(rad * 1.02, rad * 0.94), Color(MARKER_RED, 0.9), 3.0, -0.2)
			_ellipse(ctr + Vector2(1.5, -1.0), Vector2(rad * 1.06, rad * 0.96), Color(MARKER_RED, 0.55), 2.0, 0.15)
		if sel:
			# Steel and paper: a steel rule with a paper rule inside, round the selected tag.
			draw_rect(tr.grow(7.0), TAG_STEEL, false, 3.0)
			draw_rect(tr.grow(4.0), PaperSheet.PAPER, false, 1.5)
		if has_focus():
			draw_rect(tr.grow(10.0), Color(PIN_TEAL, 0.8), false, 1.5)
		# The pin at the tag's top: teal where you stand, steel for next, red for the boss, khaki else.
		var pin_c: Color = PIN_TEAL if cur else MARKER_RED if boss else PIN_STEEL if reach else PIN_KHAKI
		var pin_at: Vector2 = Vector2(tr.get_center().x, tag_r.position.y + 2.0)
		var pr: float = clampf(tile * 0.09, 4.0, 8.0)
		draw_circle(pin_at + Vector2(1.5, 2.0), pr, Color(0, 0, 0, 0.35))
		draw_circle(pin_at, pr, pin_c if not done else Color(pin_c, 0.6))
		draw_circle(pin_at - Vector2(pr, pr) * 0.3, pr * 0.35, Color(1, 1, 1, 0.55))
		# Terrain icons on the tile's bottom edge.
		var ts: Array = node.get("terrain", [])
		var ip: float = clampf(tile * 0.32, 18.0, 26.0)
		var x0: float = tr.end.x - ip * ts.size() - 2.0
		for i: int in ts.size():
			var tid: StringName = StringName(str((ts[i] as Dictionary).get("id", "")))
			var ir: Rect2 = Rect2(Vector2(x0 + ip * i, tr.end.y - ip - 2.0), Vector2(ip, ip))
			draw_rect(ir, Color(RunGlyphs.terrain_tint(tid), 0.95 if not done else 0.5))
			RunGlyphs.draw_terrain(self, ir.grow(-ip * 0.14), tid, RunGlyphs.INK)
		# State tag on the tile's top-left: YOU (teal), NEXT (steel tag), WON / LOST / DONE (ink stamp).
		var tag: String = ""
		var tag_bg: Color = Color(0, 0, 0, 0)
		var tag_fg: Color = Color.WHITE
		if cur:
			tag = "YOU"
			tag_bg = PIN_TEAL
			tag_fg = RunGlyphs.INK
		elif done:
			tag = {&"player": "WON", &"enemy": "LOST", &"draw": "DRAW"}.get(StringName(str(node.get("result", ""))), "DONE")
			tag_fg = PaperSheet.STAMP_LOSS if tag == "LOST" else PaperSheet.INK
		elif reach:
			tag = "NEXT"
			tag_bg = TAG_STEEL
			tag_fg = PaperSheet.PAPER
		if tag != "":
			_tag(Vector2(tr.position.x, tr.position.y), tag, tag_fg, tag_bg)
		# Words under the tile, in ink on the paper.
		var font: Font = get_theme_font(&"font", &"HudHeader")
		var fs: int = 16
		var word: String = _word()
		var y: float = tr.end.y + 4.0 + font.get_ascent(fs)
		var wc: Color = ink if not done else PaperSheet.INK_MUTED
		if boss:
			wc = PaperSheet.STAMP_LOSS
		_centered(font, word, y, fs, wc)
		var sub: String = _sub()
		if sub != "":
			var f2: Font = get_theme_font(&"font", &"HudSubtle")
			_centered(f2, sub, y + 17.0, 16, PaperSheet.INK_MUTED)

	func _ellipse(c: Vector2, r: Vector2, col: Color, w: float, rot: float) -> void:
		var pts: PackedVector2Array = []
		for i: int in 41:
			var a: float = TAU * float(i) / 40.0
			pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
		draw_polyline(pts, col, w, true)

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
		draw_string(font, Vector2((size.x - w) * 0.5, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

	func _tag(at: Vector2, text: String, fg: Color, bg: Color) -> void:
		var font: Font = get_theme_font(&"font", &"HudHeader")
		var fs: int = 14
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0
		var r: Rect2 = Rect2(at + Vector2(-2, -8), Vector2(w, 18))
		if bg.a > 0.0:
			draw_rect(r, bg)
		else:
			# An ink stamp on the paper (no fill): a rule round the word.
			draw_rect(r, Color(fg, 0.85), false, 1.5)
		draw_string(font, Vector2(r.position.x + 4.0, r.position.y + 14.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
