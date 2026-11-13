# killstreak_row.gd
# Purpose: kc-ui3 (head: "killstreaks need their icons visible and get highlighted when ready"). The
#   killstreak sockets (kc-layout-a, the head's L4: in the icon strip under the STREAK counter,
#   stacked; in portrait at the right end of the rail row), always visible: one tile per killstreak of the
#   loadout, its icon (IconSheet ks_*) inside a charge ring that fills with the streak toward its
#   threshold, and one plain word under it: "1/3" while charging, READY when it can be called in
#   (amber glow, pulsing), its state (USED, NO OP...) when earned but blocked. The killstreak
#   being targeted is filled amber. kc-ks-seq: a strike called this Deploy (or an Attack Helo with a
#   fight still to come) is marked pending: kc-da-ui: a teal frame and hatch (the row is always
#   yours; killstreaks are coloured by owner, the icon tells the kind) and its word says when it
#   lands (AT FIGHT / 2 FIGHTS); the long-press rules say so too.
#   Tap = use (the controller selects it, as the flyout's buttons did); long-press / right-click =
#   its rules. Display + gestures only: match_screen.gd forwards the signals.
# Dependencies: press_gesture.gd, icon_sheet.gd, hud_theme.tres (HudPanelDark, Hud colours, HudTag font).
# Author: UI/UX Agent (kc-ui3)
extends Control

signal killstreak_tapped(id: StringName)
signal killstreak_inspected(id: StringName)

const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")
const AMBER: Color = Color(0.961, 0.722, 0.239)
## kc-da-ui: "you" teal (art direction §2.2): earned rings and pending strikes.
const TEAL: Color = Color("#2EC4B6")
const MUTED: Color = Color("#7d8790")
const DARK: Color = Color(0.0705882, 0.0862745, 0.101961)
## Killstreak id -> icon name on the sheet.
const ICONS: Dictionary = {&"recon_drone": &"ks_recon_drone", &"mortar_barrage": &"ks_mortar",
		&"sentry_turret": &"ks_sentry", &"attack_helo": &"ks_attack_helo", &"gunship": &"ks_gunship"}
## Tiles laid out for this many killstreaks (a loadout has up to 3).
const SLOTS: int = 3
const GAP: float = 4.0

var entries: Array = []
var streak: int = 0
## kc-layout-a: stacked top to bottom (the landscape icon strip) instead of side by side.
var vertical: bool = false:
	set(v):
		if v != vertical:
			vertical = v
			_layout()
var selected_id: StringName = &""
var _tiles: Array[Control] = []
var _pulse: float = 1.0
var _pulse_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)


## entries: snapshot["killstreaks"] ({id, name, full_name, threshold, earned, ready, state, reason}).
func set_killstreaks(list: Array, current_streak: int) -> void:
	streak = current_streak
	var ids: Array = list.map(func(e: Dictionary) -> StringName: return StringName(e.get("id", &"")))
	var old: Array = entries.map(func(e: Dictionary) -> StringName: return StringName(e.get("id", &"")))
	entries = list.duplicate(true)
	if ids != old or _tiles.size() != entries.size():
		_rebuild()
	for i: int in _tiles.size():
		_tiles[i].set_meta(&"entry", entries[i])
		_tiles[i].tooltip_text = _tooltip(entries[i])
		_tiles[i].queue_redraw()
	_update_pulse()


func set_selected(id: StringName) -> void:
	selected_id = id
	for t: Control in _tiles:
		t.queue_redraw()


## Tiles in loadout order (tests, QA).
func get_tiles() -> Array[Control]:
	return _tiles


func get_tile(id: StringName) -> Control:
	for t: Control in _tiles:
		if StringName((t.get_meta(&"entry", {}) as Dictionary).get("id", &"")) == id:
			return t
	return null


## True when this killstreak can be called in now (the glow).
static func is_ready(e: Dictionary) -> bool:
	return bool(e.get("earned", false)) and bool(e.get("ready", false))


## The word under the icon: 1/3 (charging), READY, AT FIGHT (a strike waiting for the fight), or the
## blocked state (USED, NO OP...).
func word_for(e: Dictionary) -> String:
	if bool(e.get("pending", false)):
		return String(e.get("pending_text", "AT FIGHT"))
	if is_ready(e):
		return "READY"
	if not bool(e.get("earned", false)):
		return "%d/%d" % [mini(streak, int(e.get("threshold", 0))), int(e.get("threshold", 0))]
	var st: String = String(e.get("state", "")).to_upper()
	return st if st != "" and st != "CALL IN" else "WAIT"


## "DRONE 1/2": the killstreak's short name and the streak toward it.
static func charge_word(e: Dictionary, current_streak: int) -> String:
	var t: int = int(e.get("threshold", 0))
	return "%s %d/%d" % [String(KillstreakFx.look(StringName(e.get("id", &"")))["short"]), mini(current_streak, t), t]


func _tooltip(e: Dictionary) -> String:
	var name_text: String = String(e.get("full_name", e.get("name", "")))
	if bool(e.get("pending", false)):
		return "%s: incoming. %s" % [name_text, KillstreakFx.when_text(StringName(e.get("id", &"")))]
	if is_ready(e):
		return "%s: ready. Tap to call it in." % name_text
	if not bool(e.get("earned", false)):
		return "%s: streak %d of %d (eliminations in a row)." % [name_text, mini(streak, int(e.get("threshold", 0))), int(e.get("threshold", 0))]
	return "%s: %s" % [name_text, String(e.get("reason", ""))]


func _rebuild() -> void:
	for t: Control in _tiles:
		remove_child(t)
		t.queue_free()
	_tiles.clear()
	for e: Dictionary in entries:
		var tile: Control = Control.new()
		tile.name = "Killstreak_%s" % String(e.get("id", ""))
		tile.mouse_filter = Control.MOUSE_FILTER_STOP
		tile.add_to_group(&"tap_target")
		tile.set_meta(&"entry", e)
		var id: StringName = StringName(e.get("id", &""))
		var g: RefCounted = PressGesture.new(tile)
		g.drag_enabled = false
		tile.set_meta(&"gesture", g)
		tile.gui_input.connect(func(ev: InputEvent) -> void:
			if g.handle(ev):
				tile.accept_event())
		g.tapped.connect(func(_p: Vector2) -> void: killstreak_tapped.emit(id))
		g.long_pressed.connect(func(_p: Vector2) -> void: killstreak_inspected.emit(id))
		tile.draw.connect(_draw_tile.bind(tile))
		add_child(tile)
		_tiles.append(tile)
	_layout()


func _layout() -> void:
	var n: int = maxi(SLOTS, _tiles.size())
	if vertical:
		# kc-layout-a (the head's L4): stacked in the icon strip, under the STREAK counter.
		var vg: float = 2.0
		var th: float = floorf((size.y - vg * (n - 1)) / n)
		for i: int in _tiles.size():
			_tiles[i].position = Vector2(0, roundf(i * (th + vg)))
			_tiles[i].size = Vector2(size.x, th)
			_tiles[i].queue_redraw()
		return
	var w: float = floorf((size.x - GAP * (n - 1)) / n)
	# Right-aligned: the first killstreak sits nearest the Supply row's value.
	var x0: float = size.x - (w * _tiles.size() + GAP * maxi(0, _tiles.size() - 1))
	for i: int in _tiles.size():
		_tiles[i].position = Vector2(roundf(x0 + i * (w + GAP)), 0)
		_tiles[i].size = Vector2(w, size.y)
		_tiles[i].queue_redraw()


func _update_pulse() -> void:
	var any_ready: bool = entries.any(func(e: Dictionary) -> bool: return is_ready(e))
	if any_ready and _pulse_tween == null and not _reduced_motion():
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_method(_set_pulse, 1.0, 0.4, 0.7).set_trans(Tween.TRANS_SINE)
		_pulse_tween.tween_method(_set_pulse, 0.4, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	elif not any_ready and _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
		_pulse = 1.0


func _set_pulse(v: float) -> void:
	_pulse = v
	for t: Control in _tiles:
		if is_ready(t.get_meta(&"entry", {})):
			t.queue_redraw()


func _reduced_motion() -> bool:
	var settings: Node = get_node_or_null(^"/root/Settings")
	return settings != null and bool(settings.get(&"reduced_motion"))


func _draw_tile(tile: Control) -> void:
	var e: Dictionary = tile.get_meta(&"entry", {})
	var r: Rect2 = Rect2(Vector2.ZERO, tile.size)
	var ready_now: bool = is_ready(e)
	var selected: bool = selected_id != &"" and StringName(e.get("id", &"")) == selected_id
	var sb: StyleBox = get_theme_stylebox(&"panel", &"HudPanelDark")
	if selected:
		tile.draw_rect(r, AMBER)
	elif UiKit.draw_piece(tile, &"pnl_ks_tile", r):
		pass  # kc-ui-wire2: the kit's killstreak tile backer (pnl_ks_tile, recessed ring well).
	elif sb != null:
		tile.draw_style_box(sb, r)
	else:
		tile.draw_rect(r, Color(0.09, 0.11, 0.13, 0.95))
	if bool(e.get("pending", false)) and not selected:
		# kc-da-ui: pending strike: the one telegraph style (a faint teal hatch) with a teal frame.
		var pr: Rect2 = r.grow(-2.0)
		var x: float = -pr.size.y
		while x < pr.size.x:
			var a: Vector2 = Vector2(pr.position.x + maxf(0.0, x), pr.position.y + maxf(0.0, -x))
			var b_x: float = minf(pr.end.x, pr.position.x + x + pr.size.y)
			tile.draw_line(a, Vector2(b_x, pr.position.y + (b_x - (pr.position.x + x))), Color(TEAL, 0.14), 3.0)
			x += 12.0
		tile.draw_rect(pr, TEAL, false, 2.0)
	if ready_now and not selected:
		# Ready: amber frame with a soft outer glow that pulses.
		tile.draw_rect(r.grow(-1.5), Color(AMBER, 0.55 + 0.45 * _pulse), false, 3.0)
		tile.draw_rect(r.grow(-5.0), Color(AMBER, 0.18 * _pulse), false, 4.0)
	var font: Font = get_theme_font(&"font", &"HudTag")
	# kc-layout-a: the strip's sockets are short (phone 62x50): a 14 px word and a tighter ring.
	var fs: int = 16 if tile.size.y >= 60.0 else 14
	var word: String = word_for(e)
	# kc-r2-fixes (playtest r2: "0/2, 0/3, 0/5 mean nothing"): a charging tile names its killstreak in
	# words ("DRONE 1/2") when that fits at 12 px or more; else the count alone.
	if not bool(e.get("earned", false)) and not bool(e.get("pending", false)):
		var named: String = charge_word(e, streak)
		var nfs: int = fs
		while nfs > 12 and font.get_string_size(named, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > tile.size.x - 6.0:
			nfs -= 1
		if font.get_string_size(named, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x <= tile.size.x - 6.0:
			word = named
			fs = nfs
	var text_h: float = font.get_height(fs)
	# Charge ring + icon.
	var ring_d: float = minf(tile.size.x - 10.0, tile.size.y - text_h - (8.0 if fs == 16 else 4.0))
	if word != word_for(e):
		ring_d -= 4.0  # kc-r2-fixes: the named word is wider than the ring; keep it clear of the arc
	var c: Vector2 = Vector2(tile.size.x * 0.5, (4.0 if fs == 16 else 2.0) + ring_d * 0.5)
	var thr: int = maxi(1, int(e.get("threshold", 1)))
	var frac: float = 1.0 if bool(e.get("earned", false)) else clampf(float(streak) / thr, 0.0, 1.0)
	var ring_c: Color = AMBER if ready_now else (TEAL if bool(e.get("earned", false)) else Color(0.55, 0.62, 0.68))
	if selected:
		ring_c = DARK
	# kc-ui-wire2: the kit's segmented ring track (ring_track) under the code fill arc; else a faint arc.
	if not UiKit.draw_piece(tile, &"ring_track", Rect2(c - Vector2(ring_d, ring_d) * 0.5, Vector2(ring_d, ring_d)), Color(ring_c, 0.5)):
		tile.draw_arc(c, ring_d * 0.5 - 2.0, 0.0, TAU, 40, Color(ring_c, 0.22), 3.0, true)
	if frac > 0.0:
		tile.draw_arc(c, ring_d * 0.5 - 2.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 40, ring_c, 3.0, true)
	var icon_name: StringName = ICONS.get(StringName(e.get("id", &"")), &"type_killstreak")
	var tex: Texture2D = IconSheet.get_icon(icon_name)
	if tex != null:
		var s: float = ring_d * 0.62
		var icon_c: Color = DARK if selected else (Color.WHITE if ready_now or bool(e.get("earned", false)) else MUTED)
		tile.draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, icon_c)
	var word_c: Color = DARK if selected else (AMBER if ready_now else MUTED)
	if bool(e.get("pending", false)) and not selected:
		word_c = TEAL
	var tw: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	tile.draw_string(font, Vector2((tile.size.x - tw) * 0.5, tile.size.y - 4.0 - font.get_descent(fs)), word,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, word_c)
