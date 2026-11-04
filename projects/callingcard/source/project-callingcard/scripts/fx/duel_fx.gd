# duel_fx.gd
# Purpose: DuelFx (cc15), the duel's feedback layer: placement drop, capture colour wipe, Ambush
#   flip, Set Link light, the skippable "Carded!" stamp and the Triptych merge. A full-rect Control
#   on top of the duel screen (scenes/fx/DuelFx.tscn, child "FX" of scenes/Duel.tscn) that never
#   takes input (mouse_filter IGNORE). Everything is driven by EventBus:
#     card_placed      -> drop: the card falls drop_px, squashes on the mortar, dust puff, thud;
#                         set-complete cards pulse their edge light (BannerCard.pulse)
#     card_captured    -> BannerCard.capture_to(captor, 0.25 s) colour wipe + thunk
#     card_reclaimed   -> the same wipe in the Reclaim player's colour (higher thunk)
#     ambush_sprung    -> squash flip of the card back + eye-open flash + click
#     set_linked       -> a thin light in the set's edge colour runs to each linked card + chime
#     carded           -> jagged crack over the captured Signature, "CARDED!" stamp slam, light
#                         screen shake, stamp sting. About 0.8 s; a tap / click / confirm skips it.
#     triptych_scored  -> the three banners slide together and merge into the panorama (1.5 s,
#                         skippable); several Triptychs play one after another.
#   Options (fx_timing.gd): Settings.fast_animations halves durations; Settings.reduced_motion
#   removes shake and travel (cards fade in place, the stamp fades without the slam, the link light
#   fades instead of running, the Triptych cross-fades without sliding).
# Hooks for the duel controller:
#   busy / wait_idle(): the controller's replay pause awaits the running animation (capped at
#     MAX_WAIT_S so a stuck tween can never stall a duel). wait_idle() returns at once when idle.
#   stage_changes: when true (the controller paces events, event_delay > 0) the wipe and the flip
#     start from the card's previous owner / face, because the screen has already applied the
#     change; when false (tests, instant replays) the screen's state is never touched.
#   skip(): ends the "Carded!" stamp or Triptych merge now.
# Dependencies: EventBus, Settings (optional), BannerCard / CardArt / ArtKit (cc14, API only),
#   fx_timing.gd, fx_sfx.gd, duel_setup.gd (Triptych card lists), the duel screen (parent:
#   get_wall(), get_state()).
# Author: Game Feel Engineer Agent (cc15)
class_name DuelFx
extends Control

## An effect began (tests and the benchmark): kind is drop, capture, reclaim, flip, link, carded, triptych.
signal effect_started(kind: StringName, slot: StringName, duration: float)
## The stamp or merge ended (skipped = cut short by a tap).
signal moment_finished(kind: StringName, skipped: bool)

const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const FxSfx: GDScript = preload("res://scripts/fx/fx_sfx.gd")
const DuelSetup: GDScript = preload("res://scripts/duel/duel_setup.gd")
## wait_idle() never waits longer than this.
const MAX_WAIT_S: float = 2.5
const DUST_POOL: int = 3

## Set by the duel controller: start wipes / flips from the previous owner / face (see header).
var stage_changes: bool = false
## Control moved by the "Carded!" shake (default: the screen's %SafeArea).
var shake_target: Control = null
## Recent effects, newest last: {kind, slot, duration} (tests, benchmark).
var history: Array[Dictionary] = []

## True while an effect that holds the replay runs: a timed hold, a tracked tween, or a moment.
var busy: bool:
	get:
		if _moment != null or Time.get_ticks_msec() < _busy_until_ms:
			return true
		_tweens = _tweens.filter(func(t: Tween) -> bool: return t.is_valid() and t.is_running())
		return not _tweens.is_empty()

var _busy_until_ms: int = 0
var _tweens: Array[Tween] = []
var _screen: Control = null
var _sfx: Node = null
var _dust: Array[CPUParticles2D] = []
var _dust_next: int = 0
var _links: Array[Dictionary] = []
var _last_captured: Dictionary = {}
var _moment: Control = null
var _moment_kind: StringName = &""
var _moment_tween: Tween = null
var _moment_extras: Array[Node] = []
var _tri_queue: Array[Array] = []
var _shake_tween: Tween = null
var _shake_origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p: Node = get_parent()
	if p is Control and p.has_method(&"get_wall"):
		_screen = p
	_sfx = FxSfx.new()
	_sfx.name = "Sfx"
	add_child(_sfx)
	for i: int in DUST_POOL:
		_dust.append(_make_dust())
	set_process(false)
	_prewarm.call_deferred()
	# Deferred: the screen's own EventBus handlers (connected in its _ready, after ours) must run
	# first, so the cards already show the new state when an effect starts.
	_connect_bus.call_deferred()


## Draws an invisible stamp for two frames so the big display glyphs are rasterised before the
## first "Carded!" (no hitch on the slam frame).
func _prewarm() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var warm: Control = _build_stamp(&"player", "Card")
	warm.name = "Prewarm"
	warm.modulate.a = 0.01
	for i: int in 2:
		await get_tree().process_frame
	if is_instance_valid(warm):
		warm.queue_free()


func _connect_bus() -> void:
	var bus: Node = get_node_or_null(^"/root/EventBus")
	if bus == null or not is_inside_tree():
		return
	bus.card_placed.connect(_on_card_placed)
	bus.card_captured.connect(_on_card_captured)
	bus.ambush_sprung.connect(_on_ambush_sprung)
	bus.carded.connect(_on_carded)
	bus.triptych_scored.connect(_on_triptych_scored)
	if bus.has_signal(&"card_reclaimed"):
		bus.card_reclaimed.connect(_on_card_reclaimed)
	if bus.has_signal(&"set_linked"):
		bus.set_linked.connect(_on_set_linked)


func _exit_tree() -> void:
	_restore_shake()


## Waits until the running animation ends (at most max_s). Returns at once when idle.
func wait_idle(max_s: float = MAX_WAIT_S) -> void:
	var deadline: int = Time.get_ticks_msec() + int(max_s * 1000.0)
	while is_inside_tree() and busy and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


## Ends the "Carded!" stamp or Triptych merge now (also clears queued Triptychs).
func skip() -> void:
	if _moment == null:
		return
	_tri_queue.clear()
	_end_moment(true)
	_busy_until_ms = Time.get_ticks_msec()
	_tweens.clear()


func is_moment_active() -> bool:
	return _moment != null


func get_moment() -> Control:
	return _moment


func _input(event: InputEvent) -> void:
	# Never consumes the event: the tap that skips still reaches the screen.
	if _moment == null:
		return
	var press: bool = (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventScreenTouch and event.pressed) \
			or event.is_action_pressed(&"confirm")
	if press:
		skip()


# --- EventBus handlers ---------------------------------------------------------------------------

func _on_card_placed(_side: StringName, _card_id: StringName, slot: StringName, _captures: Array) -> void:
	var card: BannerCard = _card(slot)
	if card == null:
		return
	var t: RefCounted = FxTiming.from_settings()
	var fall: float = t.get_value(&"drop_fall")
	var settle: float = t.get_value(&"drop_settle")
	var px: float = t.get_value(&"drop_px")
	_reset_card(card)
	var tw: Tween = card.create_tween()
	card.set_meta(&"fx_tween", tw)
	_tweens.append(tw)
	if px <= 0.0:
		card.modulate.a = 0.35
		tw.tween_property(card, "modulate:a", 1.0, fall + settle)
		_sfx.play(&"drop")
	else:
		card.pivot_offset = Vector2(card.size.x * 0.5, card.size.y)
		card.position = Vector2(0.0, -px)
		card.scale = Vector2(1.04, 1.04)
		tw.tween_property(card, "position", Vector2.ZERO, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(card, "scale", Vector2.ONE, fall)
		tw.tween_callback(_impact.bind(slot))
		tw.tween_property(card, "scale", Vector2(1.03, 0.93), settle * 0.4)
		tw.tween_property(card, "scale", Vector2.ONE, settle * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card.pulse()
	_started(&"drop", slot, fall + settle)


func _on_card_captured(by_side: StringName, card_id: StringName, slot: StringName) -> void:
	_last_captured[card_id] = slot
	_wipe(slot, by_side, &"capture")


func _on_card_reclaimed(by_side: StringName, _card_id: StringName, slot: StringName) -> void:
	_wipe(slot, by_side, &"reclaim")


func _on_ambush_sprung(_side: StringName, _card_id: StringName, slot: StringName) -> void:
	var card: BannerCard = _card(slot)
	if card == null:
		return
	var t: RefCounted = FxTiming.from_settings()
	var half: float = t.get_value(&"flip_half")
	var flash: float = t.get_value(&"flash")
	_reset_card(card)
	var dur: float = flash
	if half > 0.0:
		if stage_changes:
			card.face_down = true
		card.pivot_offset = card.size * 0.5
		var tw: Tween = card.create_tween()
		card.set_meta(&"fx_tween", tw)
		_tweens.append(tw)
		tw.tween_property(card, "scale:x", 0.0, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			card.face_down = false
			_flash(card, flash)
			_sfx.play(&"flip"))
		tw.tween_property(card, "scale:x", 1.0, half * 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		dur = half + maxf(half * 1.4, flash)
	else:
		card.face_down = false
		_flash(card, flash)
		_sfx.play(&"flip")
	_started(&"flip", slot, dur)


func _on_set_linked(_side: StringName, slot: StringName, linked: Array) -> void:
	var from_slot: Control = _slot(slot)
	var card: BannerCard = _card(slot)
	if from_slot == null or card == null or linked.is_empty():
		return
	var t: RefCounted = FxTiming.from_settings()
	var dur: float = t.get_value(&"link")
	var col: Color = ArtKit.set_palette(card.set_id).get("edge", ArtKit.AMBER)
	var a: Vector2 = _local_rect(from_slot).get_center()
	for s: Variant in linked:
		var other: Control = _slot(StringName(str(s)))
		if other == null:
			continue
		_links.append({"from": a, "to": _local_rect(other).get_center(), "color": col,
				"t": 0.0, "dur": maxf(dur, 0.05), "run": not t.reduced_motion})
		var oc: BannerCard = _card(StringName(str(s)))
		if oc != null:
			oc.pulse()
	_sfx.play(&"link")
	set_process(true)
	queue_redraw()
	# Decorative: runs alongside the captures, never holds the replay.
	effect_started.emit(&"link", slot, dur)
	_log(&"link", slot, dur)


func _on_carded(by_side: StringName, card_id: StringName) -> void:
	var slot: StringName = _last_captured.get(card_id, _find_slot(card_id))
	var card: BannerCard = _card(slot)
	var t: RefCounted = FxTiming.from_settings()
	var dur: float = t.get_value(&"carded")
	var t_in: float = t.get_value(&"stamp_in")
	var t_out: float = t.get_value(&"stamp_out")
	if _moment != null:
		_end_moment(true)
	var name_text: String = card.card_name if card != null else String(card_id).capitalize()
	var root: Control = _build_stamp(by_side, name_text)
	_begin_moment(&"carded", root)
	if card != null:
		var crack: Control = CrackLine.new()
		crack.name = "FxCrack"
		crack.color = ArtKit.side_color(by_side)
		crack.seed_value = hash(card_id)
		card.add_child(crack)
		crack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_moment_extras.append(crack)
		var ct: Tween = crack.create_tween()
		ct.tween_property(crack, "progress", 1.0, t.get_value(&"crack"))
	var stamp: Control = root.get_node("Stamp")
	var tw: Tween = create_tween()
	_moment_tween = tw
	if t.reduced_motion:
		stamp.modulate.a = 0.0
		tw.tween_property(stamp, "modulate:a", 1.0, t_in)
		tw.tween_callback(func() -> void: _sfx.play(&"stamp"))
	else:
		stamp.scale = Vector2(1.9, 1.9)
		stamp.modulate.a = 0.0
		tw.tween_property(stamp, "scale", Vector2.ONE, t_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(stamp, "modulate:a", 1.0, t_in * 0.6)
		tw.tween_callback(func() -> void:
			_sfx.play(&"stamp")
			shake(t.get_value(&"shake_px"), t.get_value(&"shake")))
	tw.tween_interval(maxf(dur - t_in - t_out, 0.0))
	tw.tween_property(root, "modulate:a", 0.0, t_out)
	tw.tween_callback(_end_moment.bind(false))
	_started(&"carded", slot, dur)


func _on_triptych_scored(side: StringName, triptych_id: StringName, _first_time: bool) -> void:
	var t: RefCounted = FxTiming.from_settings()
	var dur: float = t.get_value(&"triptych")
	if _moment != null:
		_tri_queue.append([side, triptych_id])
		_busy_until_ms = maxi(_busy_until_ms, Time.get_ticks_msec()) + int(dur * 1000.0)
		return
	_play_triptych(side, triptych_id)


# --- Effects ------------------------------------------------------------------------------------

func _wipe(slot: StringName, by_side: StringName, kind: StringName) -> void:
	var card: BannerCard = _card(slot)
	if card == null:
		return
	var dur: float = FxTiming.from_settings().get_value(&"wipe")
	if stage_changes:
		card.side = &"rival" if by_side == &"player" else &"player"
	var wipe: Tween = card.capture_to(by_side, dur)
	if wipe != null:
		_tweens.append(wipe)
	_sfx.play(&"thunk", 1.0 if kind == &"capture" else 1.3)
	_started(kind, slot, dur)


## Light shake of the screen content (none with reduced motion: px or seconds come in as 0).
func shake(px: float, seconds: float) -> void:
	var target: Control = _shake_control()
	if target == null or px <= 0.0 or seconds <= 0.0:
		return
	if _shake_tween == null or not _shake_tween.is_valid():
		_shake_origin = target.position
	else:
		_shake_tween.kill()
	_shake_tween = create_tween()
	_shake_tween.tween_method(func(k: float) -> void:
		target.position = _shake_origin + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * px * k, 1.0, 0.0, seconds)
	_shake_tween.tween_callback(_restore_shake)


func _restore_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	var target: Control = _shake_control()
	if target != null and is_instance_valid(target):
		target.position = _shake_origin


func _shake_control() -> Control:
	if shake_target == null and _screen != null:
		shake_target = _screen.get_node_or_null(^"%SafeArea") as Control
	return shake_target


func _impact(slot: StringName) -> void:
	_sfx.play(&"drop")
	var s: Control = _slot(slot)
	if s == null:
		return
	var r: Rect2 = _local_rect(s)
	var p: CPUParticles2D = _dust[_dust_next]
	_dust_next = (_dust_next + 1) % _dust.size()
	p.position = Vector2(r.get_center().x, r.end.y - 2.0)
	p.emission_rect_extents = Vector2(r.size.x * 0.45, 2.0)
	p.lifetime = maxf(FxTiming.from_settings().get_value(&"dust"), 0.1)
	p.restart()


func _make_dust() -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.name = "Dust%d" % _dust.size()
	p.emitting = false
	p.one_shot = true
	p.amount = 14
	p.explosiveness = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(0, -1)
	p.spread = 75.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(0, 90)
	p.damping_min = 60.0
	p.damping_max = 90.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0.62, 0.6, 0.56, 0.7))
	g.set_color(1, Color(0.62, 0.6, 0.56, 0.0))
	p.color_ramp = g
	add_child(p)
	return p


func _flash(card: BannerCard, seconds: float) -> void:
	if seconds <= 0.0:
		return
	var f: ColorRect = ColorRect.new()
	f.name = "FxFlash"
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.color = Color(1.0, 0.96, 0.85, 0.8)
	card.add_child(f)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw: Tween = f.create_tween()
	tw.tween_property(f, "color:a", 0.0, seconds).set_ease(Tween.EASE_OUT)
	tw.tween_callback(f.queue_free)


func _build_stamp(by_side: StringName, card_name: String) -> Control:
	var root: Control = Control.new()
	root.name = "CardedMoment"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(ArtKit.WALL, 0.35)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var col: Color = ArtKit.side_color(by_side)
	var vh: float = get_viewport_rect().size.y
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Stamp"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(ArtKit.ENAMEL, 0.9)
	sb.border_color = col
	sb.set_border_width_all(maxi(4, roundi(vh * 0.009)))
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 8
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(col, 0.35)
	sb.shadow_size = 12
	panel.add_theme_stylebox_override(&"panel", sb)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 0)
	panel.add_child(box)
	var big: Label = Label.new()
	big.name = "Title"
	big.text = "CARDED!"
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_override(&"font", ArtKit.font_display())
	big.add_theme_font_size_override(&"font_size", clampi(roundi(vh * 0.15), 56, 120))
	big.add_theme_color_override(&"font_color", col)
	big.add_theme_color_override(&"font_outline_color", ArtKit.ENAMEL)
	big.add_theme_constant_override(&"outline_size", 6)
	box.add_child(big)
	var sub: Label = Label.new()
	sub.name = "Caption"
	var rival_name: String = "The rival"
	if _screen != null and _screen.has_method(&"get_state"):
		rival_name = str(_screen.get_state().get("rival_name", rival_name))
	sub.text = ("You took their Signature, %s." % card_name) if by_side == &"player" \
			else ("%s took your Signature, %s." % [rival_name, card_name])
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override(&"font", ArtKit.font_body())
	sub.add_theme_font_size_override(&"font_size", clampi(roundi(vh * 0.035), 18, 26))
	sub.add_theme_color_override(&"font_color", ArtKit.TEXT)
	box.add_child(sub)
	root.add_child(panel)
	var ms: Vector2 = panel.get_combined_minimum_size()
	panel.size = ms
	panel.position = (get_viewport_rect().size - ms) * 0.5
	panel.pivot_offset = ms * 0.5
	panel.rotation = deg_to_rad(-6.0)
	return root


func _play_triptych(side: StringName, triptych_id: StringName) -> void:
	var t: RefCounted = FxTiming.from_settings()
	var dur: float = t.get_value(&"triptych")
	var slide: float = 0.0 if t.reduced_motion else t.get_value(&"tri_slide")
	var merge: float = t.get_value(&"tri_merge")
	var t_out: float = t.get_value(&"tri_out")
	var info: Dictionary = _triptych_info(triptych_id)
	var rects: Array[Rect2] = _triptych_rects(side, info.get("cards", []))
	var root: Control = Control.new()
	root.name = "TriptychMoment"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_begin_moment(&"triptych", root)
	var piece: Vector2 = rects[1].size
	var strip: Rect2 = Rect2(Vector2(rects[1].get_center().x - piece.x * 1.5, rects[1].position.y), Vector2(piece.x * 3.0, piece.y))
	var view: Rect2 = get_viewport_rect()
	if strip.position.x < 0.0 or strip.end.x > view.size.x:
		strip.position.x = clampf(strip.position.x, 0.0, maxf(view.size.x - strip.size.x, 0.0))
	var key: StringName = info.get("key", triptych_id)
	var tw: Tween = create_tween()
	_moment_tween = tw
	var pieces: Array[Control] = []
	for i: int in 3:
		var clip: Control = Control.new()
		clip.name = "Piece%d" % i
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(clip)
		clip.position = rects[i].position
		clip.size = piece
		var art: CardArt = CardArt.new()
		art.triptych = key
		art.material = CardArt.grain_material()
		clip.add_child(art)
		art.position = Vector2(-i * piece.x, 0.0)
		art.size = Vector2(piece.x * 3.0, piece.y)
		clip.modulate.a = 0.0
		pieces.append(clip)
	var pano: Control = Control.new()
	pano.name = "Panorama"
	pano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pano)
	pano.position = strip.position
	pano.size = strip.size
	pano.pivot_offset = strip.size * 0.5
	pano.modulate.a = 0.0
	var full: CardArt = CardArt.new()
	full.name = "Art"
	full.triptych = key
	full.show_seams = false
	full.material = CardArt.grain_material()
	pano.add_child(full)
	full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame: Panel = Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = ArtKit.SIGNATURE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(ArtKit.side_color(side), 0.5)
	sb.shadow_size = 10
	frame.add_theme_stylebox_override(&"panel", sb)
	pano.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title: Label = Label.new()
	title.name = "Title"
	title.text = "%s  ·  TRIPTYCH +1%s" % [String(info.get("name", String(triptych_id).capitalize())).to_upper(),
			"" if side == &"player" else "  (RIVAL)"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override(&"font", ArtKit.font_display())
	title.add_theme_font_size_override(&"font_size", clampi(roundi(view.size.y * 0.05), 24, 40))
	title.add_theme_color_override(&"font_color", ArtKit.SIGNATURE)
	title.add_theme_color_override(&"font_outline_color", ArtKit.ENAMEL)
	title.add_theme_constant_override(&"outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	title.size = Vector2(strip.size.x, title.get_combined_minimum_size().y)
	title.position = Vector2(strip.position.x, maxf(strip.position.y - title.size.y - 6.0, 0.0))
	title.modulate.a = 0.0
	# 1) the three banners lift and slide together, 2) they merge into one panorama.
	for i: int in 3:
		var target: Vector2 = Vector2(strip.position.x + i * piece.x, strip.position.y)
		if slide > 0.0:
			tw.parallel().tween_property(pieces[i], "modulate:a", 1.0, slide * 0.3)
			tw.parallel().tween_property(pieces[i], "position", target, slide).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		else:
			pieces[i].position = target
	tw.tween_callback(func() -> void: _sfx.play(&"triptych"))
	tw.tween_property(pano, "modulate:a", 1.0, merge)
	tw.parallel().tween_property(title, "modulate:a", 1.0, merge)
	for p: Control in pieces:
		tw.parallel().tween_property(p, "modulate:a", 0.0, merge)
	if not t.reduced_motion:
		tw.parallel().tween_property(pano, "scale", Vector2(1.06, 1.06), merge).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(dur - slide - merge - t_out, 0.0))
	tw.tween_property(root, "modulate:a", 0.0, t_out)
	tw.tween_callback(_end_moment.bind(false))
	_started(&"triptych", StringName(triptych_id), dur)


## {name, key, cards: [card ids]} for a Triptych id (CardDB through DuelSetup).
func _triptych_info(triptych_id: StringName) -> Dictionary:
	for td: TriptychData in DuelSetup.triptychs():
		if td.id == triptych_id:
			var ids: Array = td.cards.map(func(c: CardData) -> StringName: return c.id if c != null else &"")
			return {"name": td.display_name, "key": td.panorama_key if td.panorama_key != &"" else td.id, "cards": ids}
	return {"name": String(triptych_id).capitalize(), "key": triptych_id, "cards": []}


## Rects (layer coordinates) of the three banners, left to right. Falls back to the wall's middle
## row when the cards can't be found (mock state, bench).
func _triptych_rects(side: StringName, card_ids: Array) -> Array[Rect2]:
	var wall: Dictionary = _screen.get_state().get("wall", {}) if _screen != null else {}
	var rows: Dictionary = {}
	for slot: StringName in wall:
		var e: Dictionary = wall[slot]
		if card_ids.has(e.get("card_id", &"")) and e.get("owner", &"") == side:
			var row: String = String(slot).left(1)
			if not rows.has(row):
				rows[row] = []
			rows[row].append(slot)
	var slots: Array = []
	for row: String in rows:
		if (rows[row] as Array).size() >= 3:
			slots = rows[row]
	if slots.size() < 3:
		slots = [&"b2", &"b3", &"b4"] if wall.size() > 0 else []
	slots.sort_custom(func(x: Variant, y: Variant) -> bool: return String(x) < String(y))  # StringName sorts by pointer
	var out: Array[Rect2] = []
	for s: StringName in slots.slice(0, 3):
		var c: Control = _slot(s)
		if c != null:
			out.append(_local_rect(c))
	if out.size() < 3:
		var vs: Vector2 = get_viewport_rect().size
		var w: float = minf(vs.x * 0.26, 288.0)
		out.clear()
		for i: int in 3:
			out.append(Rect2(Vector2(vs.x * 0.5 + (i - 1.5) * (w + 10.0), vs.y * 0.45), Vector2(w, w / 4.0)))
	return out


func _begin_moment(kind: StringName, root: Control) -> void:
	_moment = root
	_moment_kind = kind


func _end_moment(skipped: bool) -> void:
	if _moment_tween != null and _moment_tween.is_valid():
		_moment_tween.kill()
	_moment_tween = null
	var kind: StringName = _moment_kind
	if _moment != null and is_instance_valid(_moment):
		_moment.queue_free()
	_moment = null
	_moment_kind = &""
	for n: Node in _moment_extras:
		if is_instance_valid(n):
			n.queue_free()
	_moment_extras.clear()
	if skipped:
		_restore_shake()
		_log(&"skip", &"", 0.0)
	moment_finished.emit(kind, skipped)
	if not _tri_queue.is_empty():
		var next: Array = _tri_queue.pop_front()
		_play_triptych(next[0], next[1])


func _process(delta: float) -> void:
	# Game time (scaled), so the light follows Engine.time_scale like the tweens do.
	var keep: Array[Dictionary] = []
	for l: Dictionary in _links:
		l["t"] = float(l["t"]) + delta
		if float(l["t"]) < float(l["dur"]):
			keep.append(l)
	_links = keep
	queue_redraw()
	if _links.is_empty():
		set_process(false)


func _draw() -> void:
	for l: Dictionary in _links:
		var p: float = clampf(float(l["t"]) / float(l["dur"]), 0.0, 1.0)
		var a: Vector2 = l["from"]
		var b: Vector2 = l["to"]
		var col: Color = l["color"]
		if l["run"]:
			var head: float = ease(p, 0.6)
			var tail: float = maxf(head - 0.45, 0.0)
			var h: Vector2 = a.lerp(b, head)
			draw_line(a, b, Color(col, 0.22 * (1.0 - p)), 2.0, true)
			draw_line(a.lerp(b, tail), h, Color(col, 0.3 * (1.0 - p * 0.5)), 8.0, true)
			draw_line(a.lerp(b, tail), h, Color(col.lightened(0.4), 1.0 - p * 0.4), 2.5, true)
			draw_circle(h, 4.0, Color(col.lightened(0.6), 1.0 - p * 0.4))
		else:
			var k: float = sin(p * PI)
			draw_line(a, b, Color(col, 0.25 * k), 8.0, true)
			draw_line(a, b, Color(col.lightened(0.4), k), 2.5, true)


# --- Helpers ------------------------------------------------------------------------------------

func _started(kind: StringName, slot: StringName, seconds: float) -> void:
	_busy_until_ms = maxi(_busy_until_ms, Time.get_ticks_msec() + int(seconds * 1000.0))
	_log(kind, slot, seconds)
	effect_started.emit(kind, slot, seconds)


func _log(kind: StringName, slot: StringName, seconds: float) -> void:
	history.append({"kind": kind, "slot": slot, "duration": seconds})
	if history.size() > 64:
		history.remove_at(0)


func _slot(slot_id: StringName) -> Control:
	if _screen == null or slot_id == &"":
		return null
	return _screen.get_wall().get_slot(slot_id) as Control


func _card(slot_id: StringName) -> BannerCard:
	var s: Control = _slot(slot_id)
	if s == null or not s.has_method(&"get_card") or s.is_empty():
		return null
	return s.get_card()


func _find_slot(card_id: StringName) -> StringName:
	var wall: Dictionary = _screen.get_state().get("wall", {}) if _screen != null else {}
	for slot: StringName in wall:
		if wall[slot].get("card_id", &"") == card_id:
			return slot
	return &""


func _local_rect(c: Control) -> Rect2:
	return get_global_transform().affine_inverse() * c.get_global_rect()


## Stops a card's running drop / flip and puts its transform back.
func _reset_card(card: BannerCard) -> void:
	if card.has_meta(&"fx_tween"):
		var old: Tween = card.get_meta(&"fx_tween")
		if old != null and old.is_valid():
			old.kill()
	card.position = Vector2.ZERO
	card.scale = Vector2.ONE
	card.modulate.a = 1.0


## Jagged crack across the captured Signature, drawn left to right as progress goes 0 -> 1.
class CrackLine:
	extends Control
	var color: Color = Color.WHITE
	var seed_value: int = 0
	var progress: float = 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var pts: PackedVector2Array = PackedVector2Array()
		var n: int = 9
		for i: int in n + 1:
			var x: float = size.x * (0.04 + 0.92 * float(i) / n)
			var y: float = size.y * (0.5 + rng.randf_range(-0.38, 0.38))
			pts.append(Vector2(x, y))
		var upto: int = clampi(int(ceil(progress * n)), 1, n)
		var part: PackedVector2Array = pts.slice(0, upto + 1)
		draw_polyline(part, Color(0, 0, 0, 0.55), 6.0, true)
		draw_polyline(part, Color(color.lightened(0.5), 1.0), 2.5, true)
