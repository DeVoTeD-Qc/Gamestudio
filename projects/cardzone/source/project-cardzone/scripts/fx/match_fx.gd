# match_fx.gd
# Pattern adapted from CallingCard scripts/fx/duel_fx.gd (cc15): one full-rect feedback layer that
#   never takes input, driven by events, with timed beats, a skip and a capped wait.
# Purpose: CzMatchFx (cz17), CardZone's looting and shooting feel. The node "FX" in
#   scenes/match/Match.tscn (scenes/fx/MatchFx.tscn), drawn over the whole match screen. Every beat
#   comes from EventBus.rules_event (already filtered to the human's view: the rival's private cards
#   never reach it) plus the controller's playback hooks (cz12):
#     shot_declared  -> tracer shooter area -> target area, then the hit marker + damage tag
#     frag_thrown    -> lobbed arc, blast ring and marker on the area
#     hits_landed    -> the Hit card(s) slam onto the top of the loadout (yours: the NEXT HAND strip;
#     gas_hit           the rival's: its panel), a short shake, "N HITS" tag; then the Down pulse
#                       on the panel when that seat has just gone Down
#     braced         -> the Brace cards burn away (burn.gdshader) where they were, embers, BRACE tag
#     looted         -> loot pop by rarity on the area: the card pops out (bigger and longer for
#                       rarer cards), its rarity tag and flecks; yours then flies to your line
#     drop_landed    -> the supply crate falls onto its area, dust, settles
#     gas_closed     -> the gas sweeps across the closing area (lime: gas only)
#     bounty_claimed -> Bounty heal: "+N HEALTH" rises from the shooter's panel, outline flash
#     eliminated     -> the elimination stamp (a moment: dim + slam + shake)
#     moved          -> a dashed move mark (decorative: never holds playback)
#   The cz12 TracerLayer placeholder is hidden (visible = false: it still records its mark).
# Skipping: any tap / click / confirm ends every running beat at once (the tap is not consumed);
#   SKIP on the playback panel (controller.playback_skip) does the same; FAST (playback_fast) runs
#   the beats 2.5x faster.
# Pacing (controller hooks): when a beat starts while the controller is playing a paced step at a
#   real Event speed (event_delay >= MIN_PACED_DELAY), the layer calls hold_playback() once and
#   release_playback() when its last holding beat ends, or after MAX_HOLD_S at most, so an effect
#   can never stall a match (the controller also caps a hold, HOLD_CAP_S). Instant speed and the
#   delay-0 tests never hold.
# Options (fx_timing.gd): FAST ANIMATIONS (fx_settings.gd) halves the beats; Settings.reduced_motion
#   removes travel, shake and particles (beats appear and fade in place).
# Signals: effect_started(kind, info, seconds), effect_finished(kind, skipped).
# Dependencies: EventBus, Settings (optional), CardDB, CzCard / CzArtKit / CzIcons / CzMap (cz16 API
#   only), the match screen (parent: get_controller(), get_map(), get_cards(), get_player_panels(),
#   get_tracer(), card_px), fx_timing.gd, fx_sfx.gd, fx_pieces.gd, fx_settings.gd, burn.gdshader.
# Author: Game Feel Engineer Agent (cz17)
class_name CzMatchFx
extends Control

signal effect_started(kind: StringName, info: Dictionary, seconds: float)
signal effect_finished(kind: StringName, skipped: bool)

const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const FxSfx: GDScript = preload("res://scripts/fx/fx_sfx.gd")
const P: GDScript = preload("res://scripts/fx/fx_pieces.gd")
const BURN_SHADER: Shader = preload("res://scripts/fx/burn.gdshader")
const CARD_SCENE: PackedScene = preload("res://scenes/card/CzCard.tscn")

## One hold never keeps the controller on a step longer than this.
const MAX_HOLD_S: float = 1.6
## Holds only at real Event speeds (Normal 0.45 s, Fast 0.2 s); below this nobody can watch a beat.
const MIN_PACED_DELAY: float = 0.1
## FAST on the playback panel: beats run this much faster (1 / the controller's FAST_FACTOR 0.4).
const FAST_SPEED: float = 2.5
## Beats that never hold the controller.
const DECORATIVE: Array[StringName] = [&"move"]
const LOOT_PITCH: Dictionary = {&"": 1.0, &"C": 1.0, &"U": 1.08, &"R": 1.16, &"E": 1.26, &"L": 1.38}
const PARTICLE_POOL: int = 3

## Off = no beats at all (bench baseline, tests).
var enabled: bool = true
## Recent beats, newest last: {kind, seconds, info} (tests, bench).
var history: Array[Dictionary] = []
## Control shaken by slams and the stamp (default: the screen's %SafeArea).
var shake_target: Control = null

var _screen: Control = null
var _ctrl: Node = null
var _sfx: Node = null
## Running beats: {kind, tween, root, holds, cleanup (Callable), started_ms}.
var _beats: Array[Dictionary] = []
var _pending: int = 0
var _holding: bool = false
var _hold_since_ms: int = 0
var _paced: bool = false
var _speed: float = 1.0
## The NEXT HAND strip as it was drawn last frame: [{card_id, rect}] (layer coordinates).
var _strip_snap: Array[Dictionary] = []
var _down_now: Array[bool] = [false, false]
var _down_before: Array[bool] = [false, false]
var _shake_tween: Tween = null
var _shake_origin: Vector2 = Vector2.ZERO
var _particles: Dictionary = {}  # kind -> Array[CPUParticles2D]
var _particle_next: Dictionary = {}
## Follow-up beats waiting to start (the Down pulse after a slam): killed by a skip.
var _later: Array[Tween] = []


func _ready() -> void:
	name = "FX" if name == "" else name
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sfx = FxSfx.new()
	_sfx.name = "Sfx"
	add_child(_sfx)
	for kind: StringName in [&"fleck", &"dust", &"ember"]:
		var pool: Array[CPUParticles2D] = []
		for i: int in PARTICLE_POOL:
			pool.append(_make_particles(kind, i))
		_particles[kind] = pool
		_particle_next[kind] = 0
	var p: Node = get_parent()
	if p is Control and p.has_method(&"get_controller"):
		_screen = p
	# Deferred: the screen builds its overlays (the tracer) in its own _ready, after ours.
	_bind.call_deferred()
	_prewarm.call_deferred()


func _bind() -> void:
	if not is_inside_tree():
		return
	var bus: Node = get_node_or_null(^"/root/EventBus")
	if bus != null:
		bus.rules_event.connect(_on_rules_event)
		bus.match_view_changed.connect(_on_view)
	if _screen != null:
		_ctrl = _screen.call(&"get_controller")
		var tracer: Control = _screen.call(&"get_tracer") if _screen.has_method(&"get_tracer") else null
		if tracer != null:
			tracer.visible = false  # replaced by this layer; it still records its mark (cz12 tests)
	if _ctrl != null:
		_ctrl.playback_step.connect(_on_step)
		_ctrl.busy_changed.connect(_on_busy)
		if _ctrl.has_signal(&"cover_changed"):  # cz14 hot-seat: nothing plays behind the cover
			_ctrl.connect(&"cover_changed", func(up: bool, _info: Dictionary) -> void:
				if up:
					skip_all())


## Draws an invisible burning card and stamp for two frames so the burn shader compiles and the big
## stamp glyphs are rasterised before the first real beat (no hitch on that frame).
func _prewarm() -> void:
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	var warm: Control = Control.new()
	warm.name = "Prewarm"
	warm.modulate.a = 0.01
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(warm)
	var card: CzCard = _ghost(CardDB.hit_card().id if CardDB.hit_card() != null else &"", Rect2(Vector2.ZERO, Vector2(40, 56)), warm)
	if card != null:
		card.material = _burn_material(card.size, 0.4)
	var st: P.Stamp = P.Stamp.new()
	st.title_px = _stamp_px()
	st.fit()
	warm.add_child(st)
	for i: int in 2:
		await get_tree().process_frame
	if is_instance_valid(warm):
		warm.queue_free()


func _exit_tree() -> void:
	skip_all()


# --- Public ------------------------------------------------------------------------------------

## True while any beat runs.
func is_busy() -> bool:
	return not _beats.is_empty() or _pending > 0


func active_kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for b: Dictionary in _beats:
		out.append(b["kind"])
	return out


## True while this layer holds the controller's playback.
func is_holding() -> bool:
	return _holding


## Ends every running beat now (a tap, SKIP, leaving the screen).
func skip_all() -> void:
	for lt: Tween in _later:
		if lt != null and lt.is_valid():
			lt.kill()
	_later.clear()
	for b: Dictionary in _beats.duplicate():
		var tw: Tween = b["tween"]
		if tw != null and tw.is_valid():
			tw.kill()
		_finish(b, true)
	_restore_shake()
	_release()


## Waits until every beat has ended (at most max_s). Returns at once when idle.
func wait_idle(max_s: float = MAX_HOLD_S) -> void:
	var deadline: int = Time.get_ticks_msec() + int(max_s * 1000.0)
	while is_inside_tree() and is_busy() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


# --- Input: a tap ends the beats ---------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Never consumes the event: the tap that skips still reaches the screen.
	if _beats.is_empty():
		return
	var press: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
			or event.is_action_pressed(&"confirm")
	if press:
		skip_all()


# --- Controller hooks ----------------------------------------------------------------------------

func _on_step(step: Dictionary) -> void:
	_paced = float(step.get("duration", 0.0)) > 0.0


func _on_busy(is_busy: bool) -> void:
	if not is_busy:
		_paced = false
		_release()


func _on_view(v: Dictionary) -> void:
	if _ctrl == null or not v.has("me"):
		return
	var me: int = int(_ctrl.get(&"human"))
	_down_before = _down_now.duplicate()
	_down_now[me] = bool(v["me"].get("down", false))
	_down_now[1 - me] = bool(v.get("opponent", {}).get("down", false))


func _process(_delta: float) -> void:
	_snapshot_strip()
	if _beats.is_empty() and _pending == 0:
		if _holding:
			_release()
		return
	if _ctrl != null:
		if bool(_ctrl.get(&"playback_skip")):
			skip_all()
			return
		var want: float = FAST_SPEED if bool(_ctrl.get(&"playback_fast")) else 1.0
		if want != _speed:
			_speed = want
			for b: Dictionary in _beats:
				var tw: Tween = b["tween"]
				if tw != null and tw.is_valid():
					tw.set_speed_scale(_speed)
	if _holding:
		var any_hold: bool = _pending > 0
		for b: Dictionary in _beats:
			any_hold = any_hold or bool(b["holds"])
		if not any_hold or Time.get_ticks_msec() - _hold_since_ms > int(MAX_HOLD_S * 1000.0):
			_release()


func _hold() -> void:
	if _holding or _ctrl == null or not is_inside_tree():
		return
	if not bool(_ctrl.get(&"busy")) or not _paced or bool(_ctrl.get(&"playback_skip")):
		return
	if float(_ctrl.get(&"event_delay")) < MIN_PACED_DELAY:
		return
	_ctrl.call(&"hold_playback")
	_holding = true
	_hold_since_ms = Time.get_ticks_msec()


func _release() -> void:
	if not _holding:
		return
	_holding = false
	if _ctrl != null and is_instance_valid(_ctrl):
		_ctrl.call(&"release_playback")


# --- Events ------------------------------------------------------------------------------------

func _on_rules_event(e: Dictionary) -> void:
	if not enabled or not is_inside_tree() or _screen == null:
		return
	if _ctrl != null and _ctrl.has_method(&"is_covered") and bool(_ctrl.call(&"is_covered")):
		return
	if _ctrl != null and bool(_ctrl.get(&"playback_skip")):
		return  # SKIP: the rest of this playback happens at once, with no beats
	var t: String = String(e.get("type", ""))
	var kind: StringName = &""
	match t:
		"shot_declared": kind = &"shot"
		"frag_thrown": kind = &"frag"
		"hits_landed", "gas_hit":
			if int(e.get("count", 0)) > 0:
				kind = &"slam"
		"braced":
			if not (e.get("card_ids", []) as Array).is_empty():
				kind = &"burn"
		"looted": kind = &"loot"
		"drop_landed": kind = &"drop"
		"gas_closed": kind = &"gas"
		"bounty_claimed": kind = &"heal"
		"eliminated": kind = &"stamp"
		"moved": kind = &"move"
	if kind == &"":
		return
	if not DECORATIVE.has(kind):
		_hold()
	# Start next in this frame's deferred queue: the screen has just re-rendered (view_changed comes
	# before the events) and its containers sort first, so card and tile rects are final.
	_pending += 1
	_start.call_deferred(kind, e.duplicate(true), _strip_snap.duplicate(true), _down_before.duplicate())


func _start(kind: StringName, e: Dictionary, snap: Array, down_before: Array) -> void:
	_pending = maxi(0, _pending - 1)
	if not is_inside_tree() or not enabled:
		return
	var t: RefCounted = FxTiming.from_settings()
	match kind:
		&"shot": _fx_shot(e, t)
		&"frag": _fx_frag(e, t)
		&"slam": _fx_slam(e, t, down_before)
		&"burn": _fx_burn(e, t, snap)
		&"loot": _fx_loot(e, t)
		&"drop": _fx_drop(e, t)
		&"gas": _fx_gas(e, t)
		&"heal": _fx_heal(e, t)
		&"stamp": _fx_stamp(e, t)
		&"move": _fx_move(e, t)


# --- Beats ---------------------------------------------------------------------------------------

## Tracer from the shooter's area to the target's, then the hit marker and the damage tag.
func _fx_shot(e: Dictionary, t: RefCounted) -> void:
	var seat: int = int(e.get("seat", 0))
	var from_r: Rect2 = _tile_rect(_area_of(seat))
	var to_r: Rect2 = _tile_rect(_area_of(int(e.get("target", 1 - seat))))
	if not to_r.has_area():
		return
	var dmg: int = int(e.get("damage", 0))
	var live: bool = dmg > 0 and not bool(e.get("suppressed", false))
	var beat: Dictionary = _begin(&"shot", t.beat_length(&"shot"), {"seat": seat, "damage": dmg})
	var root: Control = beat["root"]
	var tw: Tween = beat["tween"]
	var trc: P.Tracer = P.Tracer.new()
	trc.kind = &"shot"
	trc.width = maxf(3.0, to_r.size.y * 0.05)
	trc.a = (from_r if from_r.has_area() else to_r).get_center()
	trc.b = to_r.get_center()
	root.add_child(trc)
	var mk: P.Marker = P.Marker.new()
	mk.box = to_r.grow(-to_r.size.y * 0.08)
	mk.color = CzArtKit.HIT_RED if live else CzArtKit.BRACE_STEEL
	mk.width = maxf(3.0, to_r.size.y * 0.06)
	mk.modulate.a = 0.0
	root.add_child(mk)
	var tag: Control = _tag("%d DMG" % dmg if live else ("SUPPRESSED" if bool(e.get("suppressed", false)) else "NO DAMAGE"),
			&"damage", CzArtKit.HIT_RED if live else CzArtKit.BRACE_STEEL, CzArtKit.PAPER if live else CzArtKit.INK, to_r.size.y * 0.3)
	tag.position = Vector2(to_r.get_center().x - tag.size.x * 0.5, to_r.end.y - tag.size.y * 0.4)
	tag.modulate.a = 0.0
	root.add_child(tag)
	_sfx.play(&"shot")
	var travel: float = t.get_value(&"tracer")
	if travel > 0.0 and trc.a.distance_to(trc.b) > 4.0:
		trc.head = 0.0
		tw.tween_property(trc, "head", 1.0, travel).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _sfx.play(&"marker"))
	var snap_in: float = t.get_value(&"marker_in")
	mk.snap = 1.0 if t.reduced_motion else 1.5
	tw.tween_property(mk, "modulate:a", 1.0, snap_in)
	tw.parallel().tween_property(tag, "modulate:a", 1.0, snap_in)
	if not t.reduced_motion:
		tw.parallel().tween_property(mk, "snap", 1.0, snap_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(t.get_value(&"marker_hold"))
	tw.tween_property(root, "modulate:a", 0.0, t.get_value(&"marker_out"))
	_end_with(beat)


## Frag: an arc to the area, a blast ring and a marker.
func _fx_frag(e: Dictionary, t: RefCounted) -> void:
	var seat: int = int(e.get("seat", 0))
	var from_r: Rect2 = _tile_rect(_area_of(seat))
	var to_r: Rect2 = _tile_rect(StringName(str(e.get("area", ""))))
	if not to_r.has_area():
		return
	var beat: Dictionary = _begin(&"frag", t.beat_length(&"frag"), {"seat": seat, "area": e.get("area", "")})
	var root: Control = beat["root"]
	var tw: Tween = beat["tween"]
	var trc: P.Tracer = P.Tracer.new()
	trc.kind = &"frag"
	trc.width = maxf(3.0, to_r.size.y * 0.05)
	trc.a = (from_r if from_r.has_area() else to_r).get_center()
	trc.b = to_r.get_center()
	root.add_child(trc)
	var bl: P.Blast = P.Blast.new()
	bl.center = to_r.get_center()
	bl.radius = to_r.size.y * 0.75
	bl.modulate.a = 0.0
	root.add_child(bl)
	var mk: P.Marker = P.Marker.new()
	mk.box = to_r.grow(-to_r.size.y * 0.08)
	mk.width = maxf(3.0, to_r.size.y * 0.06)
	mk.modulate.a = 0.0
	root.add_child(mk)
	_sfx.play(&"move", 1.4)
	var arc: float = t.get_value(&"frag_arc")
	if arc > 0.0 and trc.a.distance_to(trc.b) > 4.0:
		trc.head = 0.0
		tw.tween_property(trc, "head", 1.0, arc)
	tw.tween_callback(func() -> void: _sfx.play(&"frag"))
	tw.tween_property(trc, "fade", 0.0, 0.08)
	tw.parallel().tween_property(bl, "modulate:a", 1.0, 0.04)
	tw.parallel().tween_property(mk, "modulate:a", 1.0, 0.06)
	if t.reduced_motion:
		bl.grow = 0.6
		tw.tween_interval(t.get_value(&"blast"))
	else:
		tw.tween_property(bl, "grow", 1.0, t.get_value(&"blast")).set_ease(Tween.EASE_OUT)
	tw.tween_interval(t.get_value(&"marker_hold") * 0.5)
	tw.tween_property(root, "modulate:a", 0.0, t.get_value(&"marker_out"))
	_end_with(beat)


## Hits slam onto the top of the loadout: yours onto the NEXT HAND strip, the rival's onto its
## panel. Then the Down pulse when the seat has just gone Down.
func _fx_slam(e: Dictionary, t: RefCounted, down_before: Array) -> void:
	var seat: int = int(e.get("seat", 0))
	var count: int = int(e.get("count", 1))
	var gas: bool = String(e.get("type", "")) == "gas_hit"
	var mine: bool = _ctrl != null and seat == int(_ctrl.get(&"human"))
	var n: int = clampi(count, 1, 3)
	var length: float = t.beat_length(&"slam", {"count": n})
	var beat: Dictionary = _begin(&"slam", length, {"seat": seat, "count": count, "gas": gas, "mine": mine})
	var root: Control = beat["root"]
	var tw: Tween = beat["tween"]
	var card_px: Vector2 = _card_px()
	var target: Rect2
	var hidden: Array[Control] = []
	# cz-clarity: the next hand may be tucked away (DECK row): the Hits then land on the DECK row.
	var next_shown: bool = not _screen.has_method(&"is_next_shown") or bool(_screen.call(&"is_next_shown"))
	if mine and not next_shown and _screen.has_method(&"get_deck_button") and _screen.call(&"get_deck_button") != null:
		var deck: Rect2 = _local(_screen.call(&"get_deck_button"))
		target = Rect2(Vector2(deck.position.x + 8.0, deck.position.y), card_px * 0.55)
	elif mine:
		var cards: Array = _screen.call(&"get_cards", &"next")
		if not cards.is_empty():
			target = _local(cards[0])
			for i: int in mini(count, cards.size()):
				var c: CzCard = cards[i] as CzCard
				if c != null and c.info.get("type", &"") == &"hit":
					c.modulate.a = 0.0  # the ghost lands on it, then it shows again
					hidden.append(c)
		else:
			target = _local(_screen.get_node(^"%StripCards"))
			target = Rect2(target.position, card_px)
	else:
		var panel: Control = _panel(seat)
		var pr: Rect2 = _local(panel) if panel != null else Rect2(size * 0.5, Vector2.ONE)
		var s: Vector2 = card_px * 0.55
		target = Rect2(Vector2(pr.get_center().x - s.x * 0.5, pr.end.y - s.y * 0.35), s)
	beat["cleanup"] = func() -> void:
		for c: Control in hidden:
			if is_instance_valid(c):
				c.modulate.a = 1.0
	var fall: float = t.get_value(&"slam_fall")
	var drop_px: float = t.get_value(&"slam_px")
	var stagger: float = t.get_value(&"slam_stagger")
	var hit_id: StringName = CardDB.hit_card().id if CardDB.hit_card() != null else &"hit"
	var ghosts: Array[CzCard] = []
	for i: int in n:
		var g: CzCard = _ghost(hit_id, target, root)
		if g == null:
			continue
		g.position.y -= drop_px
		g.modulate.a = 0.0
		ghosts.append(g)
	var tag: Control = _tag("%d HIT%s%s" % [count, "" if count == 1 else "S", " · GAS" if gas else ""], &"gas" if gas else &"hit",
			CzArtKit.GAS_GLOW if gas else CzArtKit.HIT_RED, CzArtKit.INK if gas else CzArtKit.PAPER, maxf(20.0, card_px.y * 0.16))
	# On the landed card's lower half (the Brace tag, if any, sits above the strip).
	tag.position = Vector2(target.get_center().x - tag.size.x * 0.5, target.position.y + target.size.y * 0.62)
	tag.position = tag.position.clamp(Vector2.ZERO, size - tag.size)
	tag.modulate.a = 0.0
	root.add_child(tag)
	for i: int in ghosts.size():
		var g: CzCard = ghosts[i]
		var at: float = stagger * i
		tw.parallel().tween_property(g, "modulate:a", 1.0, maxf(fall * 0.4, 0.03)).set_delay(at)
		if drop_px > 0.0:
			tw.parallel().tween_property(g, "position:y", target.position.y, fall).set_delay(at) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		_sfx.play(&"slam", 0.9 if gas else 1.0)
		for c: Control in hidden:
			if is_instance_valid(c):
				c.modulate.a = 1.0
		shake(t.get_value(&"slam_shake_px"), t.get_value(&"slam_shake")))
	tw.tween_property(tag, "modulate:a", 1.0, 0.06)
	if not mine:
		for g: CzCard in ghosts:
			g.pivot_offset = Vector2(g.size.x * 0.5, g.size.y)
			tw.parallel().tween_property(g, "scale", Vector2(1.0, 0.0), t.get_value(&"slam_settle") * 0.7)
	tw.tween_interval(t.get_value(&"slam_settle") * (0.6 if not mine else 0.75))
	tw.tween_property(root, "modulate:a", 0.0, t.get_value(&"slam_settle") * 0.25)
	_end_with(beat)
	var down_now: bool = bool(e.get("down", false)) if e.has("down") else _down_now[seat]
	if down_now and not bool(down_before[seat]) and not gas:
		var later: Tween = create_tween()
		later.set_speed_scale(_speed)
		later.tween_interval(fall + stagger * (n - 1))
		later.tween_callback(_fx_down.bind(seat))
		_later = _later.filter(func(x: Tween) -> bool: return x != null and x.is_valid())
		_later.append(later)


## The Down pulse on a player panel (two pulses + DOWN +1 tag).
func _fx_down(seat: int) -> void:
	if not is_inside_tree() or not enabled:
		return
	var t: RefCounted = FxTiming.from_settings()
	var panel: Control = _panel(seat)
	if panel == null:
		return
	var dur: float = t.get_value(&"down_pulse")
	var beat: Dictionary = _begin(&"down", dur, {"seat": seat})
	var root: Control = beat["root"]
	var tw: Tween = beat["tween"]
	var pr: Rect2 = _local(panel)
	var pulse: P.PanelPulse = P.PanelPulse.new()
	pulse.box = pr
	pulse.color = CzArtKit.HIT_RED
	pulse.spread = t.get_value(&"down_scale") * 2.0
	root.add_child(pulse)
	var tag: Control = _tag("DOWN +1", &"down", CzArtKit.HIT_RED, CzArtKit.PAPER, maxf(18.0, pr.size.y * 0.32))
	tag.position = Vector2(pr.get_center().x - tag.size.x * 0.5, pr.end.y + 4.0)
	tag.position = tag.position.clamp(Vector2.ZERO, size - tag.size)
	root.add_child(tag)
	_sfx.play(&"down")
	tw.tween_property(pulse, "pulse", 1.999, dur)
	tw.parallel().tween_property(tag, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.6)
	_end_with(beat)


## The Brace cards burn away where they were (yours: the NEXT HAND strip a frame ago; the rival's:
## a row under its panel), embers rise, and a BRACE tag shows the total.
func _fx_burn(e: Dictionary, t: RefCounted, snap: Array) -> void:
	var seat: int = int(e.get("seat", 0))
	var ids: Array = e.get("card_ids", [])
	var mine: bool = _ctrl != null and seat == int(_ctrl.get(&"human"))
	var beat: Dictionary = _begin(&"burn", t.beat_length(&"burn"), {"seat": seat, "cards": ids.size(), "mine": mine})
	var root: Control = beat["root"]
	var tw: Tween = beat["tween"]
	var card_px: Vector2 = _card_px()
	var rects: Array[Rect2] = []
	var left: Array = snap.duplicate()
	if mine:
		for id: Variant in ids:
			var found: int = -1
			for i: int in left.size():
				if StringName(str(left[i]["card_id"])) == StringName(str(id)):
					found = i
					break
			if found >= 0:
				rects.append(left[found]["rect"])
				left.remove_at(found)
			else:
				var strip_node: Control = _screen.get_node(^"%StripCards")
				if not strip_node.is_visible_in_tree() and _screen.has_method(&"get_deck_button") and _screen.call(&"get_deck_button") != null:
					strip_node = _screen.call(&"get_deck_button")  # cz-clarity: next hand tucked away
				var base: Rect2 = rects.back() if not rects.is_empty() else _local(strip_node)
				rects.append(Rect2(base.position + Vector2(card_px.x * 0.5 if not rects.is_empty() else 0.0, 0), card_px))
	else:
		var panel: Control = _panel(seat)
		var pr: Rect2 = _local(panel) if panel != null else Rect2(Vector2(size.x * 0.6, 0), Vector2(200, 60))
		var s: Vector2 = card_px * 0.6
		var step: float = s.x + 6.0
		var x0: float = clampf(pr.get_center().x - step * ids.size() * 0.5, 4.0, maxf(4.0, size.x - step * ids.size()))
		for i: int in ids.size():
			rects.append(Rect2(Vector2(x0 + i * step, pr.end.y + 8.0), s))
	var dur: float = t.get_value(&"burn")
	var mats: Array[ShaderMaterial] = []
	for i: int in ids.size():
		var g: CzCard = _ghost(StringName(str(ids[i])), rects[i], root)
		if g == null:
			continue
		var m: ShaderMaterial = _burn_material(g.size, float(i) * 1.7)
		g.material = m
		mats.append(m)
		if not t.reduced_motion:
			_emit(&"ember", Vector2(rects[i].get_center().x, rects[i].end.y - 6.0), Vector2(rects[i].size.x * 0.42, 3.0),
					CzArtKit.RUST, 10, dur)
	var total: int = int(e.get("total", 0))
	var hits: int = int(e.get("hits", 0))
	var bounds: Rect2 = rects[0] if not rects.is_empty() else Rect2()
	for r: Rect2 in rects:
		bounds = bounds.merge(r)
	var tag: Control = _tag("BRACE %d · %d HIT%s" % [total, hits, "" if hits == 1 else "S"], &"brace",
			CzArtKit.BRACE_STEEL, CzArtKit.INK, maxf(18.0, card_px.y * 0.15))
	tag.position = Vector2(bounds.get_center().x - tag.size.x * 0.5, bounds.position.y - tag.size.y - 4.0)
	tag.position = tag.position.clamp(Vector2.ZERO, size - tag.size)
	root.add_child(tag)
	_sfx.play(&"burn")
	if mats.is_empty():
		tw.tween_interval(dur)
	for i: int in mats.size():
		tw.parallel().tween_property(mats[i], "shader_parameter/progress", 1.0, dur).set_delay(0.04 * i)
	tw.tween_property(tag, "modulate:a", 0.0, maxf(t.get_value(&"burn_tag") - dur, 0.08))
	_end_with(beat)


## Loot pop by rarity: the card pops out of the area (bigger, longer and with more flecks for rarer
## cards) with its rarity tag; yours then flies to your line.
func _fx_loot(e: Dictionary, t: RefCounted) -> void:
	var seat: int = int(e.get("seat", 0))
	var id: StringName = StringName(str(e.get("card_id", "")))
	var c: CardData = CardDB.get_card(id)
	var tile: Rect2 = _tile_rect(StringName(str(e.get("area", _area_of(seat)))))
	if c == null or not tile.has_area():
		return
	var rk: StringName = StringName(c.rarity_letter())
	if not FxTiming.LOOT_TIME.has(rk):
		rk = &""
	var mine: bool = _ctrl != null and seat == int(_ctrl.get(&"human"))
	var total: float = t.loot_total(rk)
	var beat: Dictionary = _begin(&"loot", total, {"seat": seat, "card_id": id, "rarity": rk, "mine": mine})
	var root: Control = beat["root"]
	var tw: Tween = beat["tween"]
	var k: float = float(FxTiming.LOOT_SCALE[rk])
	var s: Vector2 = (_card_px() * k).round()
	var rise: float = t.get_value(&"loot_rise_px")
	var rect: Rect2 = Rect2(tile.get_center() - s * 0.5 - Vector2(0, s.y * 0.25 + rise), s)
	rect.position = rect.position.clamp(Vector2(2, 2), size - s - Vector2(2, 2))
	var g: CzCard = _ghost(id, rect, root)
	if g == null:
		_end_with(beat)
		return
	g.glint_enabled = true  # Epic / Legendary keep their glint (static under reduced motion)
	g.pivot_offset = s * 0.5
	var rd: Dictionary = CzArtKit.rarity(rk) if rk != &"" else {}
	var tag: Control
	if not rd.is_empty():
		tag = _tag(String(rd["name"]), &"", rd["color"], rd["text"], maxf(16.0, s.y * 0.17), int(rd["ticks"]))
	else:
		tag = _tag("STARTER", &"", CzArtKit.PAPER, CzArtKit.INK, maxf(16.0, s.y * 0.17))
	tag.position = Vector2(rect.get_center().x - tag.size.x * 0.5, rect.end.y + 2.0)
	tag.position = tag.position.clamp(Vector2.ZERO, size - tag.size)
	root.add_child(tag)
	var pop: float = t.get_value(&"loot_in")
	g.scale = Vector2(0.25, 0.25)
	g.modulate.a = 0.0
	tag.modulate.a = 0.0
	if rise > 0.0:
		g.position.y += rise
		tw.tween_property(g, "position:y", rect.position.y, pop).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_interval(0.0)
	tw.parallel().tween_property(g, "scale", Vector2.ONE, pop).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g, "modulate:a", 1.0, pop * 0.6)
	tw.parallel().tween_property(tag, "modulate:a", 1.0, pop)
	var flecks: int = int(FxTiming.LOOT_FLECKS[rk])
	tw.tween_callback(func() -> void:
		_sfx.play(&"loot", float(LOOT_PITCH[rk]))
		if rk == &"E" or rk == &"L":
			_sfx.play(&"loot_rare")
		if flecks > 0 and not t.reduced_motion:
			_emit(&"fleck", rect.get_center(), s * 0.4, rd.get("color", CzArtKit.PAPER), flecks, 0.45))
	var fly: float = t.get_value(&"loot_fly")
	var dest: Rect2 = _line_target() if mine else Rect2()
	var hold_s: float = maxf(total - pop - (fly if dest.has_area() and fly > 0.0 else 0.12), 0.05)
	tw.tween_interval(hold_s)
	if dest.has_area() and fly > 0.0:
		tw.tween_property(tag, "modulate:a", 0.0, fly * 0.5)
		tw.parallel().tween_property(g, "position", dest.get_center() - s * 0.25, fly).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(g, "scale", Vector2(0.5, 0.5), fly)
		tw.parallel().tween_property(g, "modulate:a", 0.0, fly).set_ease(Tween.EASE_IN)
	else:
		tw.tween_property(root, "modulate:a", 0.0, 0.12)
	_end_with(beat)


## Supply drop: the crate falls onto its area, dust puffs, it settles and fades (the tile keeps its
## drop pip).
func _fx_drop(e: Dictionary, t: RefCounted) -> void:
	var tile: Rect2 = _tile_rect(StringName(str(e.get("area", ""))))
	if not tile.has_area():
		return
	var c: CardData = CardDB.get_card(StringName(str(e.get("card_id", ""))))
	var beat: Dictionary = _begin(&"drop", t.beat_length(&"drop"), {"area": e.get("area", ""), "card_id": e.get("card_id", "")})
	var root: Control = beat["root"]
	var tw: Tween = beat["tween"]
	var h: float = tile.size.y * 0.78
	var s: Vector2 = Vector2(h * 0.95, h).round()
	var land: Vector2 = Vector2(tile.get_center().x - s.x * 0.5, tile.get_center().y - s.y * 0.55)
	var crate: P.Crate = P.Crate.new()
	crate.size = s
	crate.rarity = StringName(c.rarity_letter()) if c != null else &""
	root.add_child(crate)
	var fall: float = t.get_value(&"drop_fall")
	var drop_px: float = t.get_value(&"drop_px")
	var ground: Vector2 = land + Vector2(s.x * 0.5, s.y + 2.0)
	_sfx.play(&"drop")
	if drop_px > 0.0:
		var set_y: Callable = func(y: float) -> void:
			crate.position = Vector2(land.x, y)
			crate.ground = ground - crate.position
			crate.shadow = 1.0 - clampf((land.y - y) / drop_px, 0.0, 1.0) * 0.7
		set_y.call(land.y - drop_px)
		tw.tween_method(set_y, land.y - drop_px, land.y, fall).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			_emit(&"dust", ground, Vector2(s.x * 0.55, 2.0), CzArtKit.DUNE, 14, 0.4))
		crate.pivot_offset = Vector2(s.x * 0.5, s.y)
		tw.tween_property(crate, "scale", Vector2(1.06, 0.92), 0.05)
		tw.tween_property(crate, "scale", Vector2.ONE, 0.08)
	else:
		crate.position = land
		crate.ground = ground - land
		crate.modulate.a = 0.0
		tw.tween_property(crate, "modulate:a", 1.0, 0.18)
	tw.tween_interval(t.get_value(&"drop_settle"))
	tw.tween_property(root, "modulate:a", 0.0, t.get_value(&"drop_out"))
	_end_with(beat)


## The gas sweeps across the closing area (lime with the gas hatch, a gas_glow leading edge), then
## fades into the tile's own gassed look.
func _fx_gas(e: Dictionary, t: RefCounted) -> void:
	var area: StringName = StringName(str(e.get("area", "")))
	var tile: Rect2 = _tile_rect(area)
	if not tile.has_area():
		return
	var beat: Dictionary = _begin(&"gas", t.beat_length(&"gas"), {"area": area})
	var root: Control = beat["root"]
	var tw: Tween = beat["tween"]
	var map: CzMap = _screen.call(&"get_map")
	var k: float = map.px_per_pt() if map != null else 1.0
	var sw: P.GasSweep = P.GasSweep.new()
	sw.box = tile
	sw.cut = CzAreaTile.CUT_PT * k
	sw.pitch = 6.0 * k * 1.4
	root.add_child(sw)
	var tag: Control = _tag("GAS CLOSES", &"gas", CzArtKit.GAS_GLOW, CzArtKit.INK, maxf(16.0, tile.size.y * 0.24))
	tag.position = Vector2(tile.get_center().x - tag.size.x * 0.5, tile.position.y - tag.size.y * 0.6)
	tag.position = tag.position.clamp(Vector2.ZERO, size - tag.size)
	root.add_child(tag)
	_sfx.play(&"gas")
	var sweep: float = t.get_value(&"gas_sweep")
	if t.reduced_motion:
		sw.sweep = 1.0
		root.modulate.a = 0.0
		tw.tween_property(root, "modulate:a", 1.0, sweep * 0.5)
		tw.tween_interval(sweep * 0.5)
	else:
		tw.tween_property(sw, "sweep", 1.0, sweep)
	tw.tween_property(sw, "modulate:a", 0.0, t.get_value(&"gas_out"))
	tw.parallel().tween_property(tag, "modulate:a", 0.0, t.get_value(&"gas_out"))
	_end_with(beat)


## Bounty heal: "+N HEALTH · BOUNTY" rises from the shooter's panel, its outline flashes paper.
func _fx_heal(e: Dictionary, t: RefCounted) -> void:
	var seat: int = int(e.get("seat", 0))
	var panel: Control = _panel(seat)
	if panel == null:
		return
	var healed: int = int(e.get("healed", 0))
	var dur: float = t.get_value(&"heal")
	var beat: Dictionary = _begin(&"heal", dur, {"seat": seat, "healed": healed})
	var root: Control = beat["root"]
	var tw: Tween = beat["tween"]
	var pr: Rect2 = _local(panel)
	var flash: P.PanelPulse = P.PanelPulse.new()
	flash.box = pr
	flash.color = CzArtKit.PAPER
	flash.spread = 0.0
	root.add_child(flash)
	var tag: Control = _tag("+%d HEALTH · BOUNTY" % healed if healed > 0 else "BOUNTY · FULL HEALTH", &"heal",
			CzArtKit.SHOAL, CzArtKit.PAPER, maxf(18.0, pr.size.y * 0.32))
	tag.position = Vector2(pr.get_center().x - tag.size.x * 0.5, pr.end.y + 4.0)
	tag.position = tag.position.clamp(Vector2.ZERO, size - tag.size)
	root.add_child(tag)
	_sfx.play(&"heal")
	var rise: float = t.get_value(&"heal_rise_px")
	tw.tween_property(flash, "pulse", 0.999, dur * 0.6)
	if rise > 0.0:
		var y0: float = tag.position.y
		tag.position.y += rise
		tw.parallel().tween_property(tag, "position:y", y0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(tag, "modulate:a", 0.0, dur * 0.4)
	_end_with(beat)


## The elimination stamp: dim, the ELIMINATED plate slams in, light shake, holds, fades. A moment:
## a tap ends it.
func _fx_stamp(e: Dictionary, t: RefCounted) -> void:
	var seat: int = int(e.get("seat", 0))
	var mine: bool = _ctrl != null and seat == int(_ctrl.get(&"human"))
	var dur: float = t.get_value(&"stamp")
	var beat: Dictionary = _begin(&"stamp", dur, {"seat": seat, "mine": mine, "cause": e.get("cause", "")})
	var root: Control = beat["root"]
	var tw: Tween = beat["tween"]
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(CzArtKit.INK, 0.45)
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var st: P.Stamp = P.Stamp.new()
	st.name = "Stamp"
	st.title = "ELIMINATED"
	var cause: String = {"shot": "by a shot", "frag": "by a Frag", "gas": "in the gas", "final_circle": "by the final circle"}.get(
			String(e.get("cause", "")), "")
	st.caption = ("You are out%s." if mine else "The rival is out%s.") % ((" " + cause) if cause != "" else "")
	st.title_px = _stamp_px()
	st.caption_px = clampi(roundi(size.y * 0.045), 18, 28)
	st.fit()
	st.position = ((size - st.size) * 0.5).round()
	st.rotation = deg_to_rad(-4.0)
	root.add_child(st)
	var t_in: float = t.get_value(&"stamp_in")
	var t_out: float = t.get_value(&"stamp_out")
	st.modulate.a = 0.0
	dim.modulate.a = 0.0
	tw.tween_property(dim, "modulate:a", 1.0, t_in)
	if t.reduced_motion:
		tw.parallel().tween_property(st, "modulate:a", 1.0, t_in)
		tw.tween_callback(func() -> void: _sfx.play(&"stamp"))
	else:
		st.scale = Vector2(1.5, 1.5)
		tw.parallel().tween_property(st, "scale", Vector2.ONE, t_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(st, "modulate:a", 1.0, t_in * 0.6)
		tw.tween_callback(func() -> void:
			_sfx.play(&"stamp")
			shake(t.get_value(&"stamp_shake_px"), t.get_value(&"stamp_shake")))
	tw.tween_interval(maxf(dur - t_in - t_out, 0.0))
	tw.tween_property(root, "modulate:a", 0.0, t_out)
	_end_with(beat)


## A dashed move mark from area to area (decorative: never holds playback).
func _fx_move(e: Dictionary, t: RefCounted) -> void:
	var a: Rect2 = _tile_rect(StringName(str(e.get("from", ""))))
	var b: Rect2 = _tile_rect(StringName(str(e.get("to", ""))))
	if not a.has_area() or not b.has_area():
		return
	var dur: float = t.get_value(&"move_mark")
	var beat: Dictionary = _begin(&"move", dur, {"seat": int(e.get("seat", 0)), "to": e.get("to", "")})
	var root: Control = beat["root"]
	var tw: Tween = beat["tween"]
	var trc: P.Tracer = P.Tracer.new()
	trc.kind = &"move"
	trc.width = maxf(3.0, b.size.y * 0.045)
	trc.a = a.get_center()
	trc.b = b.get_center()
	root.add_child(trc)
	_sfx.play(&"move")
	if not t.reduced_motion:
		trc.head = 0.0
		tw.tween_property(trc, "head", 1.0, minf(0.16, dur * 0.4)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(dur * 0.3)
	tw.tween_property(trc, "fade", 0.0, dur * 0.3)
	_end_with(beat)


# --- Beat bookkeeping ----------------------------------------------------------------------------

func _begin(kind: StringName, seconds: float, info: Dictionary) -> Dictionary:
	var root: Control = Control.new()
	root.name = "Beat_%s" % kind
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw: Tween = create_tween()
	tw.set_speed_scale(_speed)
	var beat: Dictionary = {"kind": kind, "tween": tw, "root": root, "holds": not DECORATIVE.has(kind),
			"cleanup": Callable(), "started_ms": Time.get_ticks_msec()}
	_beats.append(beat)
	history.append({"kind": kind, "seconds": seconds, "info": info})
	if history.size() > 64:
		history.remove_at(0)
	effect_started.emit(kind, info, seconds)
	return beat


func _end_with(beat: Dictionary) -> void:
	var tw: Tween = beat["tween"]
	tw.tween_callback(_finish.bind(beat, false))


func _finish(beat: Dictionary, skipped: bool) -> void:
	var i: int = _beats.find(beat)
	if i < 0:
		return
	_beats.remove_at(i)
	var cleanup: Callable = beat["cleanup"]
	if cleanup.is_valid():
		cleanup.call()
	var root: Control = beat["root"]
	if is_instance_valid(root):
		root.queue_free()
	if skipped:
		for kind: StringName in _particles:
			for p: CPUParticles2D in _particles[kind]:
				p.emitting = false
	effect_finished.emit(beat["kind"], skipped)


# --- Shake ---------------------------------------------------------------------------------------

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
		if is_instance_valid(target):
			target.position = _shake_origin + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * px * k, 1.0, 0.0, seconds)
	_shake_tween.tween_callback(_restore_shake)


func _restore_shake() -> void:
	if _shake_tween == null:
		return
	if _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	var target: Control = _shake_control()
	if target != null and is_instance_valid(target):
		target.position = _shake_origin


func _shake_control() -> Control:
	if shake_target == null and _screen != null:
		shake_target = _screen.get_node_or_null(^"%SafeArea") as Control
	return shake_target


# --- Helpers -------------------------------------------------------------------------------------

func _snapshot_strip() -> void:
	if _screen == null or not _screen.has_method(&"get_cards"):
		return
	_strip_snap.clear()
	if _screen.has_method(&"is_next_shown") and not bool(_screen.call(&"is_next_shown")):
		return  # cz-clarity: the next hand is tucked away; burns play on the DECK row instead
	for c: Control in _screen.call(&"get_cards", &"next"):
		if c.size.x > 1.0 and c.has_meta(&"card_id"):
			_strip_snap.append({"card_id": c.get_meta(&"card_id"), "rect": _local(c)})


func _local(c: Control) -> Rect2:
	if c == null:
		return Rect2()
	return get_global_transform().affine_inverse() * c.get_global_rect()


func _tile_rect(area: StringName) -> Rect2:
	if area == &"" or _screen == null:
		return Rect2()
	var map: CzMap = _screen.call(&"get_map")
	var t: Control = map.tile(area) if map != null else null
	return _local(t) if t != null else Rect2()


func _area_of(seat: int) -> StringName:
	if _ctrl == null or _ctrl.get(&"state") == null or seat < 0 or seat > 1:
		return &""
	return (_ctrl.get(&"state") as MatchState).seats[seat].area


func _panel(seat: int) -> Control:
	if _screen == null or _ctrl == null:
		return null
	var panels: Array = _screen.call(&"get_player_panels")
	return panels[0] if seat == int(_ctrl.get(&"human")) else panels[1]


func _card_px() -> Vector2:
	var v: Variant = _screen.get(&"card_px") if _screen != null else null
	return v if v is Vector2 else Vector2(117, 164)


## Where a looted card of yours lands: your newest line chip (or the line area).
func _line_target() -> Rect2:
	if _screen == null:
		return Rect2()
	var chips: Array = _screen.call(&"get_cards", &"line")
	if not chips.is_empty():
		return _local(chips.back())
	var line: Control = _screen.get_node_or_null(^"%LineScroll") as Control
	return _local(line)


func _stamp_px() -> int:
	return clampi(roundi(size.y * 0.15), 52, 110)


## A ghost CzCard (compact, no input) at `rect` under `parent`.
func _ghost(card_id: StringName, rect: Rect2, parent: Control) -> CzCard:
	var c: CardData = CardDB.get_card(card_id)
	if c == null:
		return null
	var g: CzCard = CARD_SCENE.instantiate()
	g.layout_mode_override = "compact"
	g.glint_enabled = false
	g.configure(c)
	parent.add_child(g)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.position = rect.position
	g.size = rect.size
	return g


func _burn_material(card_size: Vector2, seed_value: float) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = BURN_SHADER
	m.set_shader_parameter(&"size", card_size)
	m.set_shader_parameter(&"progress", 0.0)
	m.set_shader_parameter(&"seed", seed_value)
	m.set_shader_parameter(&"char_color", CzArtKit.RUST)
	m.set_shader_parameter(&"ash_color", CzArtKit.INK)
	return m


func _tag(text: String, icon: StringName, fill: Color, ink: Color, px: float, ticks: int = 0) -> Control:
	var tg: P.Tag = P.Tag.new()
	tg.text = text
	tg.icon = icon if icon != &"" and CzIcons.has_icon(icon) else &""
	tg.fill = fill
	tg.ink = ink
	tg.line = CzArtKit.INK
	tg.font_px = clampi(roundi(px), 14, 40)
	tg.ticks = ticks
	tg.fit()
	return tg


func _make_particles(kind: StringName, i: int) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.name = "%s%d" % [String(kind).capitalize(), i]
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.85
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.amount = 12
	match kind:
		&"fleck":  # flat paper squares in the rarity colour, popping up and falling
			p.direction = Vector2(0, -1)
			p.spread = 70.0
			p.initial_velocity_min = 80.0
			p.initial_velocity_max = 160.0
			p.gravity = Vector2(0, 380)
			p.scale_amount_min = 3.0
			p.scale_amount_max = 5.0
			p.angular_velocity_min = -180.0
			p.angular_velocity_max = 180.0
		&"dust":
			p.direction = Vector2(0, -1)
			p.spread = 80.0
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 80.0
			p.gravity = Vector2(0, 90)
			p.damping_min = 60.0
			p.damping_max = 90.0
			p.scale_amount_min = 3.0
			p.scale_amount_max = 6.0
		&"ember":  # small rust / dune squares drifting up from the burn front
			p.explosiveness = 0.2
			p.direction = Vector2(0, -1)
			p.spread = 25.0
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 70.0
			p.gravity = Vector2(0, -20)
			p.scale_amount_min = 2.0
			p.scale_amount_max = 3.5
	add_child(p)
	return p


func _emit(kind: StringName, at: Vector2, extents: Vector2, color: Color, amount: int, lifetime: float) -> void:
	var pool: Array = _particles.get(kind, [])
	if pool.is_empty() or amount <= 0:
		return
	var i: int = int(_particle_next[kind])
	_particle_next[kind] = (i + 1) % pool.size()
	var p: CPUParticles2D = pool[i]
	p.position = at
	p.emission_rect_extents = extents
	if p.amount != amount:
		p.amount = amount
	p.lifetime = maxf(lifetime, 0.1)
	var g: Gradient = Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color, 0.0) if kind != &"ember" else Color(CzArtKit.INK, 0.0))
	p.color_ramp = g
	p.restart()
	p.emitting = true
