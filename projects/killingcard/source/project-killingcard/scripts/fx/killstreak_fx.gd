# killstreak_fx.gd
# Purpose: kc-ks-seq. The killstreak layer of the FeedbackDirector, replacing the full-screen call-in
#   takeover that looked the same for every streak (studio head: "a huge flash popup that is the same
#   for all killstreaks... hard to follow"). Three parts, each in its OWNER's colour (teal yours, red
#   the rival's; kc-da-ui, art direction v1 §2.2) with the streak's own icon telling the kind:
#   - BANNER: a compact strip at the top centre (about 50 px tall at 844x390) when a killstreak is
#     earned (READY), called (yours, in Deploy) or revealed (the rival's, at Reveal): icon, name, a
#     state word and its one-line effect. No dim, no flash, it never takes the board: the playback
#     waits ks_banner_beat (0.45 s) while it slides in and stays ks_banner (1.7 s) in all.
#   - PENDING MARKERS: a strike that has not landed yet (Mortar, Attack Helo) marks the half-column it
#     will hit with ONE telegraph style: a faint hatch in the owner's colour and an "INCOMING" pin chip
#     (kc-da-ui: no dashed box on top of the stripes). Yours appear when
#     you call it in Deploy, the rival's when it is revealed; a helo's second fight stays marked
#     through the next Deploy. They go away when the strike starts (Firefight step 0).
#   - SEQUENCES (strike_fx.gd): the mortar's shells, the helo's strafing pass, the drone's scan, the
#     sentry's drop. Started by the director, which pairs them with the damage numbers.
#   Every banner and chip is inspectable: tap, long-press or right-click emits inspect_requested
#   (the match controller opens the killstreak's rules: name, what it does, when it resolves).
#   Fast animations halve every duration; reduced motion slides nothing (fades in place).
# Dependencies: fx_style.gd, fx_timing.gd, press_gesture.gd, IconSheet, UiKit (optional pieces).
# Author: Game Feel Engineer Agent (kc-ks-seq)
class_name KillstreakFx
extends Control

## Tap / long-press / right-click on the banner or a pending chip.
signal inspect_requested(item_id: StringName, side: StringName)

const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")
const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const PressGesture: GDScript = preload("res://scripts/ui/press_gesture.gd")

## Per killstreak: icon, the state words, a one-line effect (banner), what it does and when it
## resolves (inspector), and its sequence (strike_fx.gd style). No per-kind colour (kc-da-ui): the
## kind is told by the icon and name, the colour by the owner (owner_color).
const LOOKS: Dictionary = {
	&"recon_drone": {"icon": &"ks_recon_drone", "seq": &"scan", "short": "DRONE",
		"effect": "Rival plays face-up, rival Cover off: 2 rounds",
		"when": "Resolves at once when you call it in Deploy (the rival's at Reveal)."},
	&"mortar_barrage": {"icon": &"ks_mortar", "seq": &"shells", "short": "MORTAR",
		"effect": "2 damage to every enemy in one column",
		"when": "Strikes at the start of the fight, before column A."},
	&"sentry_turret": {"icon": &"ks_sentry", "seq": &"drop", "short": "SENTRY",
		"effect": "A Sentry (FP 2, Armor 4, Cover 1) at the back of a column",
		"when": "Deploys at Reveal, then fights from the back of the column."},
	&"attack_helo": {"icon": &"ks_attack_helo", "seq": &"strafe", "short": "HELO",
		"effect": "2 damage to each enemy front unit, this fight and next",
		"when": "Strikes at the start of this round's fight and the next, before column A."},
	&"gunship": {"icon": &"ks_gunship", "seq": &"strafe", "short": "GUNSHIP",
		"effect": "Heavy fire on the enemy lines",
		"when": "Strikes at the start of the fight."},
}
const DEFAULT_LOOK: Dictionary = {"icon": &"type_killstreak", "seq": &"shells", "short": "STRIKE",
		"effect": "", "when": "Resolves at Reveal."}
## Banner state words.
const MODE_WORDS: Dictionary = {&"earned": "READY", &"called": "CALLED IN", &"revealed": "HOSTILE"}
const BANNER_H: float = 50.0
const BANNER_MAX_W: float = 470.0

var banner: Control = null
## The banner's last data ({item_id, side, mode, name, effect}), for tests.
var last_banner: Dictionary = {}
## Pending markers by key ("<side>:<item_id>:<zone>").
var markers: Dictionary = {}
var _banner_tween: Tween = null
var _banner_gesture: RefCounted = null
## Callable(zone: StringName) -> Rect2 (overlay-local column rect); set by the director.
var zone_rect_fn: Callable = Callable()
var viewer_side: StringName = &"player"


static func look(item_id: StringName) -> Dictionary:
	return LOOKS.get(item_id, DEFAULT_LOOK)


## kc-da-ui: a killstreak's colour is its owner's: teal when `side` is the viewer's, red for the rival.
## The item id is kept for callers; it no longer changes the colour (the icon tells the kind).
static func color_of(_item_id: StringName, side: StringName = &"player", viewer: StringName = &"player") -> Color:
	return owner_color(side, viewer)


static func owner_color(side: StringName, viewer: StringName = &"player") -> Color:
	return FxStyle.TEAL if side == viewer else FxStyle.RED


static func icon_of(item_id: StringName) -> Texture2D:
	var name: StringName = look(item_id)["icon"]
	return IconSheet.get_icon(name) if IconSheet.has_icon(name) else null


## "When it resolves", for the inspector.
static func when_text(item_id: StringName) -> String:
	return String(look(item_id)["when"])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner = Control.new()
	banner.name = "KillstreakBanner"
	banner.visible = false
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.draw.connect(_draw_banner)
	add_child(banner)
	_banner_gesture = PressGesture.new(banner)
	_banner_gesture.drag_enabled = false
	banner.gui_input.connect(func(ev: InputEvent) -> void:
		if _banner_gesture.handle(ev):
			banner.accept_event())
	var inspect: Callable = func(_p: Vector2) -> void:
		inspect_requested.emit(StringName(last_banner.get("item_id", &"")), StringName(last_banner.get("side", &"player")))
	_banner_gesture.tapped.connect(inspect)
	_banner_gesture.long_pressed.connect(inspect)


# --- banner -----------------------------------------------------------------------------

## Shows the banner. data: {item_id, side, mode (&"earned" / &"called" / &"revealed"), name, effect?}.
## Returns how long the playback should wait for it (ks_banner_beat), not its full length.
func show_banner(data: Dictionary, timing: RefCounted = null) -> float:
	if timing == null:
		timing = FxTiming.from_settings()
	finish_banner()
	var item_id: StringName = data.get("item_id", &"")
	last_banner = data.duplicate()
	if not last_banner.has("effect") or String(last_banner["effect"]) == "":
		last_banner["effect"] = look(item_id)["effect"]
	var s: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
	# Centred over the board (the three columns) when it is known, else over the screen.
	var board: Rect2 = Rect2()
	if zone_rect_fn.is_valid():
		for z: StringName in [&"left", &"mid", &"right"]:
			var zr: Rect2 = zone_rect_fn.call(z)
			if zr.has_area():
				board = zr if not board.has_area() else board.merge(zr)
	if not board.has_area():
		board = Rect2(Vector2(16, 0), Vector2(s.x - 32.0, s.y))
	var w: float = minf(BANNER_MAX_W, board.size.x - 8.0)
	banner.size = Vector2(w, BANNER_H)
	var x: float = roundf(board.position.x + (board.size.x - w) * 0.5)
	var y: float = 6.0
	banner.visible = true
	banner.mouse_filter = Control.MOUSE_FILTER_STOP
	banner.tooltip_text = "%s: %s. %s" % [last_banner.get("name", ""), last_banner["effect"], when_text(item_id)]
	banner.queue_redraw()
	var total: float = maxf(0.2, timing.get_value(&"ks_banner"))
	var t_in: float = minf(timing.get_value(&"ks_banner_in"), total * 0.3)
	var t_out: float = minf(timing.get_value(&"ks_banner_out"), total * 0.3)
	_banner_tween = create_tween()
	if timing.reduced_motion:
		banner.position = Vector2(x, y)
		banner.modulate.a = 0.0
		_banner_tween.tween_property(banner, ^"modulate:a", 1.0, t_in)
		_banner_tween.tween_interval(total - t_in - t_out)
		_banner_tween.tween_property(banner, ^"modulate:a", 0.0, t_out)
	else:
		banner.modulate.a = 1.0
		banner.position = Vector2(x, -BANNER_H - 4.0)
		_banner_tween.tween_property(banner, ^"position:y", y, t_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_banner_tween.tween_interval(total - t_in - t_out)
		_banner_tween.tween_property(banner, ^"position:y", -BANNER_H - 4.0, t_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_banner_tween.tween_callback(_hide_banner)
	return minf(total, timing.get_value(&"ks_banner_beat"))


func banner_showing() -> bool:
	return banner != null and banner.visible


func finish_banner() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_hide_banner()


func _hide_banner() -> void:
	if banner != null:
		banner.visible = false
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw_banner() -> void:
	var item_id: StringName = last_banner.get("item_id", &"")
	var hostile: bool = StringName(last_banner.get("side", &"player")) != viewer_side
	# kc-da-ui: a steel banner with its owner's rim (teal yours, red hazard rim the rival's). Amber
	# only while the streak is READY to call.
	var c: Color = owner_color(StringName(last_banner.get("side", &"player")), viewer_side)
	var mode: StringName = StringName(last_banner.get("mode", &"called"))
	var word_c: Color = FxStyle.AMBER if mode == &"earned" and not hostile else (FxStyle.RED.lightened(0.2) if hostile else c)
	var r: Rect2 = Rect2(Vector2.ZERO, banner.size)
	banner.draw_rect(r, Color(FxStyle.SLATE, 0.95))
	banner.draw_rect(r, Color(c, 0.9), false, 2.0)
	# Icon on a dark socket with the owner's rim (art direction §5.6).
	var icon_r: Rect2 = Rect2(4, 4, BANNER_H - 8.0, BANNER_H - 8.0)
	banner.draw_rect(icon_r, FxStyle.GUNMETAL)
	banner.draw_rect(icon_r, Color(c, 0.9), false, 1.0)
	var tex: Texture2D = icon_of(item_id)
	if tex != null:
		banner.draw_texture_rect(tex, icon_r.grow(-6.0), false, FxStyle.FOG)
	if hostile:
		for i: int in 4:
			var x0: float = r.end.x - 10.0 - i * 9.0
			banner.draw_line(Vector2(x0, r.end.y - 3.0), Vector2(x0 + 6.0, 3.0), Color(FxStyle.RED, 0.55), 3.0)
	var head: Font = FxStyle.font_for(&"heading")
	var body: Font = FxStyle.font_for(&"body")
	var x: float = icon_r.end.x + 10.0
	var word: String = String(MODE_WORDS.get(mode, ""))
	if hostile and word != "HOSTILE":
		word = "HOSTILE " + word
	var name_text: String = String(last_banner.get("name", "")).to_upper()
	var name_w: float = head.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	banner.draw_string(head, Vector2(x, 22.0), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, FxStyle.FOG)
	banner.draw_string(head, Vector2(x + name_w + 10.0, 22.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, word_c)
	var room: float = r.size.x - x - (44.0 if hostile else 10.0)
	banner.draw_string(body, Vector2(x, 42.0), String(last_banner.get("effect", "")), HORIZONTAL_ALIGNMENT_LEFT, room, 15,
			Color(FxStyle.FOG, 0.86))


# --- strike kill tag (kc-ks-pop) -------------------------------------------------------------

## "MORTAR KILL" over a unit a strike eliminated, in its owner's colour (kc-da-ui: teal / red); rises and fades over the
## popup time (in place with reduced motion). Tap / long-press / right-click inspects the killstreak.
## `point` is overlay-local (the tag's centre). Returns the tag (it frees itself).
func show_kill_tag(point: Vector2, item_id: StringName, side: StringName, timing: RefCounted = null) -> Control:
	if timing == null:
		timing = FxTiming.from_settings()
	var text: String = "%s KILL" % look(item_id)["short"]
	var font: Font = FxStyle.font_for(&"heading")
	var fs: int = 20
	var c: Color = owner_color(side, viewer_side)
	var tag: Control = Control.new()
	tag.name = "KillTag_%s" % item_id
	tag.set_meta(&"text", text)
	tag.set_meta(&"item_id", item_id)
	tag.mouse_filter = Control.MOUSE_FILTER_STOP
	tag.tooltip_text = "%s: a killstreak kill (no streak). %s" % [text.capitalize(), when_text(item_id)]
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30.0
	tag.size = Vector2(w, 26.0)
	var s: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
	tag.position = Vector2(clampf(point.x - w * 0.5, 2.0, maxf(2.0, s.x - w - 2.0)), clampf(point.y - 13.0, 2.0, maxf(2.0, s.y - 28.0)))
	var tex: Texture2D = icon_of(item_id)
	tag.draw.connect(func() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, tag.size)
		tag.draw_rect(r, Color(FxStyle.SLATE, 0.9))
		tag.draw_rect(r, c, false, 2.0)
		if tex != null:
			tag.draw_texture_rect(tex, Rect2(4, 4, 18, 18), false, c)
		tag.draw_string(font, Vector2(25, 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c))
	var g: RefCounted = PressGesture.new(tag)
	g.drag_enabled = false
	tag.set_meta(&"gesture", g)
	tag.gui_input.connect(func(ev: InputEvent) -> void:
		if g.handle(ev):
			tag.accept_event())
	var inspect: Callable = func(_p: Vector2) -> void: inspect_requested.emit(item_id, side)
	g.tapped.connect(inspect)
	g.long_pressed.connect(inspect)
	add_child(tag)
	var life: float = maxf(0.2, timing.get_value(&"popup")) * 1.4
	var tw: Tween = tag.create_tween()
	tw.set_parallel(true)
	if not timing.reduced_motion:
		tw.tween_property(tag, ^"position:y", tag.position.y - 18.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(tag, ^"modulate:a", 0.0, life * 0.3).set_delay(life * 0.7)
	tw.chain().tween_callback(tag.queue_free)
	return tag


# --- pending markers ------------------------------------------------------------------------

## A strike waiting for the fight on one column: dashed half-column outline + an inspectable chip.
class PendingMarker:
	extends Control
	var item_id: StringName = &""
	var side: StringName = &"player"
	var zone: StringName = &""
	var label: String = "AT FIGHT"
	var owner_fx: Control = null
	var chip: Control = null
	var _t: float = 0.0
	var _gesture: RefCounted = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup() -> void:
		chip = Control.new()
		chip.name = "Chip"
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.add_to_group(&"tap_target")
		chip.tooltip_text = "%s: incoming. %s" % [String(item_id).replace("_", " ").capitalize(), KillstreakFx.when_text(item_id)]
		chip.draw.connect(_draw_chip)
		add_child(chip)
		_gesture = PressGesture.new(chip)
		_gesture.drag_enabled = false
		chip.gui_input.connect(func(ev: InputEvent) -> void:
			if _gesture.handle(ev):
				chip.accept_event())
		var inspect: Callable = func(_p: Vector2) -> void:
			owner_fx.inspect_requested.emit(item_id, side)
		_gesture.tapped.connect(inspect)
		_gesture.long_pressed.connect(inspect)

	func _process(delta: float) -> void:
		_t += delta
		follow()

	## The half of the column the strike hits (the caster's enemy's half).
	func target_rect() -> Rect2:
		var col: Rect2 = owner_fx.zone_rect_fn.call(zone) if owner_fx != null and owner_fx.zone_rect_fn.is_valid() else Rect2()
		if not col.has_area():
			return Rect2()
		var hits_top: bool = side == owner_fx.viewer_side
		return Rect2(col.position + Vector2(0, 0 if hits_top else col.size.y * 0.5), Vector2(col.size.x, col.size.y * 0.5))

	func follow() -> void:
		var r: Rect2 = target_rect()
		visible = r.has_area()
		if not visible:
			return
		position = r.position
		size = r.size
		var cw: float = minf(r.size.x - 8.0, 150.0)
		chip.size = Vector2(cw, 36.0)
		var hits_top: bool = side == owner_fx.viewer_side
		chip.position = Vector2((r.size.x - cw) * 0.5, 4.0 if hits_top else r.size.y - 40.0)
		queue_redraw()
		chip.queue_redraw()

	func _draw() -> void:
		# kc-da-ui: one telegraph style: a faint hatch in the owner's colour (no dashed box), with the
		# pin chip on top. It breathes gently unless reduced motion is on.
		var c: Color = KillstreakFx.owner_color(side, owner_fx.viewer_side if owner_fx != null else &"player")
		var r: Rect2 = Rect2(Vector2.ZERO, size).grow(-3.0)
		var pulse: float = 1.0 if _reduced() else 0.8 + 0.2 * sin(_t * 3.0)
		var step: float = 16.0
		var x: float = -r.size.y
		while x < r.size.x:
			var a: Vector2 = Vector2(r.position.x + maxf(0.0, x), r.position.y + maxf(0.0, -x))
			var b_x: float = minf(r.end.x, r.position.x + x + r.size.y)
			var b: Vector2 = Vector2(b_x, r.position.y + (b_x - (r.position.x + x)))
			draw_line(a, b, Color(c, 0.16 * pulse), 3.0)
			x += step

	func _reduced() -> bool:
		var settings: Node = get_node_or_null(^"/root/Settings")
		return settings != null and bool(settings.get(&"reduced_motion"))

	func _draw_chip() -> void:
		var c: Color = KillstreakFx.owner_color(side, owner_fx.viewer_side if owner_fx != null else &"player")
		var r: Rect2 = Rect2(Vector2.ZERO, chip.size)
		chip.draw_rect(r, Color(FxStyle.SLATE, 0.92))
		chip.draw_rect(r, c, false, 2.0)
		var ir: Rect2 = Rect2(3, 3, r.size.y - 6.0, r.size.y - 6.0)
		chip.draw_rect(ir, FxStyle.GUNMETAL)
		chip.draw_rect(ir, Color(c, 0.9), false, 1.0)
		var tex: Texture2D = KillstreakFx.icon_of(item_id)
		if tex != null:
			chip.draw_texture_rect(tex, ir.grow(-3.0), false, FxStyle.FOG)
		var head: Font = FxStyle.font_for(&"heading")
		var x: float = ir.end.x + 5.0
		var room: float = r.size.x - x - 3.0
		chip.draw_string(head, Vector2(x, 16.0), "%s INCOMING" % KillstreakFx.look(item_id)["short"], HORIZONTAL_ALIGNMENT_LEFT, room, 15, c)
		var when: String = "resolves at fight" if label == "AT FIGHT" else "next %s" % label.to_lower()
		chip.draw_string(FxStyle.font_for(&"body"), Vector2(x, 32.0), when, HORIZONTAL_ALIGNMENT_LEFT, room, 13, FxStyle.FOG)


## Replaces every marker with `list`: [{item_id, side, zones: [StringName], label?}].
func set_pending(list: Array) -> void:
	var want: Dictionary = {}
	for e: Dictionary in list:
		for z: Variant in e.get("zones", []):
			want[_key(e["side"], e["item_id"], StringName(z))] = e
	for key: String in markers.keys():
		if not want.has(key):
			remove_marker(key)
	for key: String in want:
		var e: Dictionary = want[key]
		if markers.has(key):
			(markers[key] as Control).set(&"label", String(e.get("label", "AT FIGHT")))
			continue
		_add_marker(key, e, StringName(key.get_slice(":", 2)))


## Adds markers for one strike (one per zone). Returns how many were added.
func add_pending(item_id: StringName, side: StringName, zones: Array, label: String = "AT FIGHT") -> int:
	var n: int = 0
	for z: Variant in zones:
		var key: String = _key(side, item_id, StringName(z))
		if not markers.has(key):
			_add_marker(key, {"item_id": item_id, "side": side, "label": label}, StringName(z))
			n += 1
	return n


## Removes every marker of one strike (all its zones).
func clear_pending(item_id: StringName, side: StringName) -> void:
	for key: String in markers.keys():
		if key.begins_with("%s:%s:" % [side, item_id]):
			remove_marker(key)


func remove_marker(key: String) -> void:
	var m: Control = markers.get(key)
	markers.erase(key)
	if m != null and is_instance_valid(m):
		m.queue_free()


func pending_keys() -> Array:
	var keys: Array = markers.keys()
	keys.sort()
	return keys


func _key(side: Variant, item_id: Variant, zone: StringName) -> String:
	return "%s:%s:%s" % [side, item_id, zone]


func _add_marker(key: String, e: Dictionary, zone: StringName) -> void:
	var m: PendingMarker = PendingMarker.new()
	m.name = "Pending_%s" % key.replace(":", "_")
	m.item_id = StringName(e["item_id"])
	m.side = StringName(e["side"])
	m.zone = zone
	m.label = String(e.get("label", "AT FIGHT"))
	m.owner_fx = self
	add_child(m)
	move_child(m, 0)
	m.setup()
	m.follow()
	markers[key] = m
