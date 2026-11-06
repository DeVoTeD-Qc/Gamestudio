# trait_rail.gd
# Purpose: The trait rail (kc-syn-ui; synergy-system.md §9) in the icon strip, between PREVIEW and
#   DECK. One chip per trait in play (max 4, TRAITS order): the trait's icon (a shape: chevrons,
#   mask, gear, hand), its count over the next threshold ("2/3"; just "3" at the top tier). The icon
#   plate lights at tier 2 and gets a white ring at tier 3; the Doctrine trait has a small emblem
#   notch; a set that just switched off shows a crack for a moment. Desktop has room for both sides
#   (rival on top in red, yours below in teal); the phone shows yours (the rival's is in the flyout).
#   Tap = the SETS flyout (both sides, every tier text); long-press / right-click on a chip = that
#   trait's rules (chip_inspected), elsewhere = the rail's rules (inspected).
# Dependencies: press_gesture.gd, synergy_glyphs.gd, hud_theme.tres (Hud colours, HudNumber font).
# Author: UI/UX Agent (kc-syn-ui)
extends Control

signal tapped
signal inspected
signal chip_inspected(side: StringName, trait_id: StringName)

const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")

## [{trait, name, count, tier, next, doctrine}] per side (MatchState.synergy_view rail).
var rails: Dictionary = {&"player": [], &"enemy": []}
var show_enemy: bool = false
## trait -> msec until which a crack tick shows (per side key "side:trait").
var _cracks: Dictionary = {}
var _gesture: RefCounted = null
## Last drawn chip rects: [{rect, side, trait}].
var _chips: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_gesture = PressGesture.new(self)
	_gesture.drag_enabled = false
	_gesture.tapped.connect(func(_p: Vector2) -> void: tapped.emit())
	_gesture.long_pressed.connect(func(p: Vector2) -> void:
		var hit: Dictionary = chip_at(get_global_transform().affine_inverse() * p)
		if hit.is_empty():
			inspected.emit()
		else:
			chip_inspected.emit(hit["side"], hit["trait"]))
	resized.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	if _gesture.handle(event):
		accept_event()


func set_rails(player_rail: Array, enemy_rail: Array, with_enemy: bool) -> void:
	rails = {&"player": player_rail.duplicate(true), &"enemy": enemy_rail.duplicate(true)}
	show_enemy = with_enemy
	queue_redraw()


## A set that switched off (crack tick for ~2 s).
func crack(side: StringName, trait_id: StringName) -> void:
	_cracks["%s:%s" % [side, trait_id]] = Time.get_ticks_msec() + 2000
	queue_redraw()
	get_tree().create_timer(2.1).timeout.connect(queue_redraw)


## Chip under a rail-local point: {side, trait, rect} or {}.
func chip_at(local: Vector2) -> Dictionary:
	for c: Dictionary in _chips:
		if (c["rect"] as Rect2).grow(2.0).has_point(local):
			return c
	return {}


func get_chips() -> Array:
	return _chips


## Words for tests / QA: "Vanguard 2/3" per chip of a side.
func chip_texts(side: StringName) -> PackedStringArray:
	var out: PackedStringArray = []
	for e: Dictionary in rails.get(side, []):
		out.append("%s %s" % [String(e.get("name", "")), _count_text(e)])
	return out


static func _count_text(e: Dictionary) -> String:
	var nxt: int = int(e.get("next", 0))
	return "%d/%d" % [int(e.get("count", 0)), nxt] if nxt > 0 else str(int(e.get("count", 0)))


func _draw() -> void:
	_chips.clear()
	var r: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.07, 0.085, 0.1, 0.92))
	draw_rect(r, Color(1, 1, 1, 0.12), false, 1.0)
	var groups: Array = []
	if show_enemy:
		groups.append(&"enemy")
	groups.append(&"player")
	var font: Font = get_theme_font(&"font", &"HudNumber")
	var cap_font: Font = get_theme_font(&"font", &"HudHeader")
	var any: bool = false
	for side: StringName in groups:
		any = any or not (rails.get(side, []) as Array).is_empty()
	if not any:
		var fs0: int = 16
		var t0: String = "SETS"
		var sz0: Vector2 = cap_font.get_string_size(t0, HORIZONTAL_ALIGNMENT_LEFT, -1, fs0)
		draw_string(cap_font, Vector2((size.x - sz0.x) * 0.5, size.y * 0.5 - 2.0), t0, HORIZONTAL_ALIGNMENT_LEFT, -1, fs0, Color("#7E8890"))
		var t1: String = "none"
		var sz1: Vector2 = cap_font.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(cap_font, Vector2((size.x - sz1.x) * 0.5, size.y * 0.5 + 18.0), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#6A747C"))
		return
	var block_h: float = size.y / groups.size()
	for gi: int in groups.size():
		var side: StringName = groups[gi]
		var top: float = gi * block_h
		var side_c: Color = get_theme_color(&"friend" if side == &"player" else &"enemy", &"Hud")
		var list: Array = rails.get(side, [])
		var cap_h: float = 0.0
		if show_enemy:
			cap_h = 16.0
			var cap: String = "YOU" if side == &"player" else "RIVAL"
			draw_string(cap_font, Vector2(4, top + 13.0), cap, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0, 13, side_c)
		var n: int = list.size()
		if n == 0:
			draw_string(cap_font, Vector2(4, top + cap_h + 14.0), "none", HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0, 16, Color("#6A747C"))
			continue
		var avail: float = block_h - cap_h - 2.0
		var cols: int = 1
		var row_h: float = floorf(avail / n)
		if row_h < 22.0:
			cols = 2
			row_h = floorf(avail / ceilf(n / 2.0))
		row_h = minf(row_h, 34.0)
		var col_w: float = (size.x - 4.0) / cols
		for i: int in n:
			var e: Dictionary = list[i]
			var t: StringName = StringName(e.get("trait", &""))
			var cx: float = 2.0 + (i % cols) * col_w
			var cy: float = top + cap_h + 1.0 + (i / cols) * row_h
			var chip: Rect2 = Rect2(cx, cy, col_w - 1.0, row_h - 2.0)
			var icon_s: float = minf(chip.size.y, 22.0 if cols == 1 else 16.0)
			var ir: Rect2 = Rect2(chip.position + Vector2(1.0, (chip.size.y - icon_s) * 0.5), Vector2(icon_s, icon_s))
			var tier: int = int(e.get("tier", 0))
			SynergyGlyphs.draw_trait_plate(self, ir, t, tier >= 2, tier >= 3)
			if bool(e.get("doctrine", false)):
				# Doctrine emblem: a small notch flag on the plate's top-right corner.
				draw_colored_polygon(PackedVector2Array([ir.position + Vector2(ir.size.x - 7, 0), ir.position + Vector2(ir.size.x + 2, 0),
						ir.position + Vector2(ir.size.x + 2, 9)]), Color.WHITE)
			var txt: String = _count_text(e) if cols == 1 else str(int(e.get("count", 0)))
			var fs: int = 16
			var tc: Color = SynergyGlyphs.trait_color(t) if tier >= 2 else Color("#C8D0D6")
			draw_string(font, Vector2(ir.end.x + 3.0, chip.get_center().y + font.get_ascent(fs) * 0.5 - 2.0), txt,
					HORIZONTAL_ALIGNMENT_LEFT, chip.end.x - ir.end.x - 3.0, fs, tc)
			var ck: String = "%s:%s" % [side, t]
			if int(_cracks.get(ck, 0)) > Time.get_ticks_msec():
				draw_line(ir.position + Vector2(ir.size.x * 0.2, 0), ir.position + Vector2(ir.size.x * 0.55, ir.size.y * 0.5), SynergyGlyphs.DOWN, 2.0)
				draw_line(ir.position + Vector2(ir.size.x * 0.55, ir.size.y * 0.5), ir.position + Vector2(ir.size.x * 0.35, ir.size.y), SynergyGlyphs.DOWN, 2.0)
			_chips.append({"rect": chip, "side": side, "trait": t})
