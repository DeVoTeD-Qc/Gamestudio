# feedback_director.gd
# Purpose: Plays the rules engine's event log as combat feedback, in order (p14). It takes the
#   plain RulesEvent dictionaries (scripts/rules/rules_event.gd) the match controller already
#   has, and for each one starts the matching effect, waits its beat, then moves on:
#     FIREFIGHT_STEP    "FIRST SHOT" / "MAIN" label at the zone (b01: shows which shots are
#                       simultaneous and which come after the First Shot eliminations)
#     SHOT_FIRED        tracer shooter -> target (staggered 60 ms); an other-side unit firing in
#                       the First Shot step also gets a "FIRST SHOT" tag (b01: why it hit you)
#     DAMAGE_DEALT      lock-bracket hit marker + damage number when the tracer lands
#     UNIT_ELIMINATED   ELIMINATED / DOWN stamp, hit-stop, small screen shake, killfeed line,
#                       "+100 ELIMINATION" pop-up for the viewer's credited eliminations,
#                       and a dark veil over the victim's slot until the sequence ends (b01: the
#                       board keeps showing the pre-resolve snapshot, so without it a dead unit
#                       still looks like it is in the fight while the next unit shoots)
#     STREAK_CHANGED    StreakArc fills; on reset it shatters
#     KILLSTREAK_EARNED "<NAME> READY" pop-up at the arc (the notch glows)
#     ITEM_REVEALED     killstreak: full-screen call-in takeover; other items: name tag
#     SUPPRESSED / SURVIVED_LETHAL / PATCHED / EQUIPMENT_TRIGGERED: short tags
#     ZONE_CONTROL / MODE_SCORED: "+50 ZONE SECURED" / "+N POINTS" pop-ups
#   Everything else costs no time. No rules logic: it reads the event fields and nothing else.
#   Events with `private_to` another side are skipped.
#
# Options: Settings.fast_animations halves every duration and beat; Settings.reduced_motion
#   removes shake, hit-stop and travel (see fx_timing.gd). Read at the start of each play().
#
# Use (match controller):
#   director.locator = BoardFxLocator.new(board)   # or any object with unit_rect/zone_rect/anchor_rect
#   director.locator.sync_from_state(state)        # BEFORE resolving, while the board shows it
#   await director.play(new_events)                # then render the new snapshot
#   director.skip()                                # fast-forward (F key / tap)
#
# Scene: res://scenes/fx/FeedbackDirector.tscn: full-rect overlay Control (mouse ignored) that
#   holds the transient effects and the CallInTakeover. Put it last under the match root so it
#   draws on top. The Killfeed and StreakArc live in the HUD and are assigned (or set by path).
# Dependencies: fx_*.gd, killfeed.gd, streak_arc.gd, call_in_takeover.gd, RulesEvent,
#   CardDB autoload (display names, item slots; optional), Settings autoload (optional).
# Author: Game Feel Engineer Agent (p14)
extends Control

## Labels of the firefight steps (FirefightResolver.STEP_*).
const STEP_LABELS: Dictionary = {&"first_shot": "FIRST SHOT", &"main": "MAIN"}

## A sequence started (count = events queued).
signal sequence_started(count: int)
## About to play this event (after the private filter). Controllers may refresh the board here.
signal event_started(event: Dictionary)
## The queue is empty and the last beat has passed.
signal sequence_finished
## An effect started: kind (&"tracer", &"hit_marker", &"damage_number", &"stamp", &"popup",
## &"killfeed", &"streak", &"shatter", &"takeover", &"shake", &"hitstop", &"tag"), node or null.
signal fx_started(kind: StringName, node: Object, duration: float)

const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")
const TracerFx: GDScript = preload("res://scripts/fx/tracer_fx.gd")
const HitMarkerFx: GDScript = preload("res://scripts/fx/hit_marker_fx.gd")
const FloatTextFx: GDScript = preload("res://scripts/fx/float_text_fx.gd")
const ElimStampFx: GDScript = preload("res://scripts/fx/elim_stamp_fx.gd")
const BoardFxLocator: GDScript = preload("res://scripts/fx/board_fx_locator.gd")
const CallInScene: PackedScene = preload("res://scenes/fx/CallInTakeover.tscn")
const CallInTakeover: GDScript = preload("res://scripts/fx/call_in_takeover.gd")

const GROUP_TRANSIENT: StringName = &"fx_transient"
## Killstreak ids, used when CardDB cannot say (tests, previews without data).
const KNOWN_KILLSTREAKS: Array[StringName] = [&"recon_drone", &"mortar_barrage", &"sentry_turret", &"attack_helo", &"gunship"]
const SOURCE_ICONS: Dictionary = {
	&"operator": &"type_operator", &"tactic": &"type_tactic", &"equipment": &"type_equipment",
	&"secondary": &"stat_firepower", &"lethal": &"stat_firepower", &"tactical": &"type_tactic",
	&"on_down": &"trig_on_down", &"perk": &"elite", &"killstreak": &"type_killstreak",
}
const CLASS_ICONS: Array[StringName] = [&"stat_firepower", &"class_smg", &"class_shotgun", &"class_ar", &"class_sniper", &"class_lmg"]

## Pop-up values shown to the viewer (display only; the rules engine has no XP yet).
@export var score_popups: Dictionary = {&"elimination": 100, &"zone": 50}
## The side whose screen this is (&"player"). Its streak drives the StreakArc.
@export var viewer_side: StringName = &"player"
## Optional paths, resolved in _ready (or assign killfeed / streak_arc directly).
@export var killfeed_path: NodePath
@export var streak_arc_path: NodePath
## Read fast_animations / reduced_motion from Settings at each play() (tests can turn it off).
@export var use_settings: bool = true

## kc-board: the first Pick / Flank shot of a match explains itself once (keys &"pick", &"flank").
var _skip_called: Dictionary = {}
var fast: bool = false
var reduced_motion: bool = false
## Object with unit_rect(uid) / zone_rect(zone) / anchor_rect(name) -> Rect2 (global canvas px).
var locator: RefCounted = null
var killfeed: Node = null
var streak_arc: Node = null
var takeover: Control = null
## uid -> display name, for killfeed lines (filled from UNIT_ARRIVED; controllers may add more).
var unit_names: Dictionary = {}
## Every effect started since clear_log(): {kind, duration, type (event type)}.
var fx_log: Array[Dictionary] = []

var _queue: Array = []
var _playing: bool = false
var _skipping: bool = false
var _timing: RefCounted = null
var _wait_tween: Tween = null
var _shake_tween: Tween = null
var _shake_base: Transform2D = Transform2D.IDENTITY
var _clock: float = 0.0
var _arrival: Dictionary = {}     # target uid -> _clock when its last tracer lands
var _zone_of: Dictionary = {}     # uid -> zone it was last seen in
var _current_zone: StringName = &""
var _current_type: StringName = &""
var _hit_count: Dictionary = {}   # uid -> damage numbers shown this sequence (stacking offset)
var _hitstop_on: bool = false
var _step: StringName = &""       # current firefight step (FIREFIGHT_STEP.step)
var _tagged_first_shot: Dictionary = {}  # uid -> true: "FIRST SHOT" tag already shown
var _veils: Dictionary = {}       # victim uid -> DownVeil over its slot (this sequence)


## Dark cover over an eliminated unit's slot. Not transient: it stays until the sequence ends
## (the board is refreshed then) and follows the slot each frame; hidden when the slot is gone
## (e.g. the board switched to the post-Reveal snapshot that no longer has the unit).
class DownVeil:
	extends Control
	var uid: int = -1
	var director: Control = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		follow()

	func follow() -> void:
		var r: Rect2 = director._veil_rect(uid) if director != null else Rect2()
		visible = r.has_area()
		if visible:
			position = r.position
			size = r.size
		queue_redraw()

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(FxStyle.SLATE, 0.62))
		draw_line(r.position + Vector2(6, 6), r.end - Vector2(6, 6), Color(FxStyle.FOG_DIM, 0.5), 2.0)
		draw_line(Vector2(r.end.x - 6, r.position.y + 6), Vector2(r.position.x + 6, r.end.y - 6), Color(FxStyle.FOG_DIM, 0.5), 2.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if killfeed == null and not killfeed_path.is_empty():
		killfeed = get_node_or_null(killfeed_path)
	if streak_arc == null and not streak_arc_path.is_empty():
		streak_arc = get_node_or_null(streak_arc_path)
	takeover = CallInScene.instantiate()
	add_child(takeover)
	_timing = _make_timing()


func _process(delta: float) -> void:
	_clock += delta


## The timing snapshot used for the current (or next) sequence.
func get_timing() -> RefCounted:
	if _timing == null:
		_timing = _make_timing()
	return _timing


func is_playing() -> bool:
	return _playing


## Plays events in order. If a sequence is already running they are appended to it; either way
## this returns when the whole queue has played.
func play(events: Array) -> void:
	_queue.append_array(events)
	if _playing:
		await sequence_finished
		return
	_playing = true
	_skipping = false
	_timing = _make_timing()
	_hit_count.clear()
	_tagged_first_shot.clear()
	_step = &""
	sequence_started.emit(_queue.size())
	while not _queue.is_empty():
		var ev: Dictionary = _queue.pop_front()
		if not _visible_to_viewer(ev):
			continue
		_current_type = ev.get("type", &"")
		event_started.emit(ev)
		var pre: float = _pre_wait(ev)
		if pre > 0.0 and not _skipping:
			await _wait(pre)
		var beat: float = _handle(ev)
		if beat > 0.0 and not _skipping:
			await _wait(beat)
	_playing = false
	_skipping = false
	clear_veils()
	sequence_finished.emit()


## Fast-forward: ends every running effect, plays the rest of the queue without waits or
## transient effects (killfeed lines and the streak still update), then finishes.
func skip() -> void:
	_skipping = true
	_end_hitstop()
	_stop_shake()
	for node: Node in get_tree().get_nodes_in_group(GROUP_TRANSIENT):
		if is_ancestor_of(node):
			node.finish()
	if takeover != null:
		takeover.finish()
	if killfeed != null:
		killfeed.finish_all()
	if streak_arc != null:
		streak_arc.finish()
	if _wait_tween != null and _wait_tween.is_valid():
		_wait_tween.custom_step(1.0e4)


func clear_log() -> void:
	fx_log.clear()


## Kinds started since clear_log(), in order.
func logged_kinds() -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Dictionary in fx_log:
		out.append(e["kind"])
	return out


## Sum of the logged durations of one kind (tests compare normal vs fast).
func logged_duration(kind: StringName) -> float:
	var total: float = 0.0
	for e: Dictionary in fx_log:
		if e["kind"] == kind:
			total += float(e["duration"])
	return total


# --- event handlers --------------------------------------------------------------------

func _pre_wait(ev: Dictionary) -> float:
	if ev.get("type") == RulesEvent.DAMAGE_DEALT:
		var uid: int = int(ev.get("target_uid", -1))
		return maxf(0.0, float(_arrival.get(uid, 0.0)) - _clock)
	return 0.0


## Starts the effects for one event; returns the beat (seconds) before the next event.
func _handle(ev: Dictionary) -> float:
	var t: RefCounted = _timing
	match ev.get("type", &""):
		RulesEvent.UNIT_ARRIVED:
			var card_id: StringName = ev.get("card_id", &"")
			if card_id != &"":
				unit_names[int(ev.get("uid", -1))] = _display_name(card_id)
			_zone_of[int(ev.get("uid", -1))] = ev.get("zone", &"")
			return 0.0
		RulesEvent.FIREFIGHT_STARTED:
			_current_zone = ev.get("zone", &"")
			_step = &""
			return t.get_value(&"step_pause")
		RulesEvent.FIREFIGHT_STEP:
			return _on_step(ev, t)
		RulesEvent.SHOT_FIRED:
			return _on_shot(ev, t)
		RulesEvent.DAMAGE_DEALT:
			return _on_damage(ev, t)
		RulesEvent.UNIT_ELIMINATED:
			return _on_eliminated(ev, t)
		RulesEvent.SUPPRESSED:
			_tag(int(ev.get("target_uid", -1)), "SUPPRESSED", FxStyle.FOG, ev)
			return t.get_value(&"popup_beat") * 0.5
		RulesEvent.SURVIVED_LETHAL:
			_tag(int(ev.get("uid", -1)), "HOLDS", FxStyle.FOG, ev)
			return t.get_value(&"popup_beat")
		RulesEvent.PATCHED:
			var uid: int = int(ev.get("target_uid", -1))
			_number(uid, "+%d" % int(ev.get("amount", 0)), FxStyle.TEAL, false, ev)
			return t.get_value(&"popup_beat")
		RulesEvent.UNIT_HEALED:
			# kc-syn-ui: the Undead set heal (and Aid Station): a green +n on the unit, named.
			var huid: int = int(ev.get("target_uid", -1))
			var undead: bool = StringName(ev.get("source_id", &"")) == &"trait_undead"
			_number(huid, "+%d" % int(ev.get("amount", 0)), Color("#8EDB6A") if undead else FxStyle.TEAL, false, ev)
			if undead:
				_tag(huid, "UNDEAD HEAL", Color("#8EDB6A"), ev)
			return t.get_value(&"popup_beat")
		RulesEvent.SYNERGY_CHANGED:
			# The match screen calls the set out over the trait rail; give it a beat to be read.
			return t.get_value(&"popup_beat") * 0.5
		RulesEvent.STREAK_CHANGED:
			return _on_streak(ev, t)
		RulesEvent.KILLSTREAK_EARNED:
			if ev.get("side") != viewer_side:
				return 0.0
			var name_text: String = "%s READY" % _display_name(ev.get("item_id", &"")).to_upper()
			_popup_at(_arc_point(-1.0), name_text, &"numeric", 22, FxStyle.CYAN, ev)
			return t.get_value(&"earned_beat")
		RulesEvent.ITEM_USED:
			if ev.get("side") == viewer_side and _is_killstreak(ev.get("item_id", &"")):
				_popup_at(_arc_point(-1.0), "UPLINK QUEUED", &"numeric", 20, FxStyle.CYAN, ev)
				return t.get_value(&"popup_beat")
			return 0.0
		RulesEvent.ITEM_REVEALED:
			return _on_item_revealed(ev, t)
		RulesEvent.EQUIPMENT_TRIGGERED:
			var target: int = int(ev.get("target_uid", -1))
			_tag(target, _display_name(ev.get("card_id", &"")).to_upper(), FxStyle.side_color(ev.get("side", &"")), ev)
			return t.get_value(&"popup_beat")
		RulesEvent.ZONE_CONTROL:
			if ev.get("owner") == viewer_side and int(score_popups.get(&"zone", 0)) > 0:
				var r: Rect2 = _zone_rect(ev.get("zone", &""))
				if r.has_area():
					_popup_at(_to_local(r.get_center()),
							"+%d ZONE SECURED" % int(score_popups[&"zone"]), &"heading", 22, FxStyle.AMBER, ev)
					return t.get_value(&"popup_beat")
			return 0.0
		RulesEvent.MODE_SCORED:
			var gained: int = int(ev.get("player_gained" if viewer_side == &"player" else "enemy_gained", 0))
			var anchor: Rect2 = _anchor_rect(&"score")
			if gained > 0 and anchor.has_area():
				_popup_at(_to_local(Vector2(anchor.get_center().x, anchor.end.y - 10.0)),
						"+%d %s" % [gained, "POINT" if gained == 1 else "POINTS"], &"heading", 22, FxStyle.AMBER, ev)
				return t.get_value(&"popup_beat")
			return 0.0
	return 0.0


func _on_shot(ev: Dictionary, t: RefCounted) -> float:
	var side: StringName = ev.get("side", &"player")
	var foe: StringName = _other(side)
	var zone: StringName = ev.get("zone", _current_zone)
	var shooter: int = int(ev.get("shooter_uid", -1))
	var target: int = int(ev.get("target_uid", -1))
	_zone_of[shooter] = zone
	var from: Vector2 = _unit_point(shooter, side, zone)
	var to: Vector2 = _unit_point(target, foe, zone) if target >= 0 else _zone_point(zone, foe)
	if not _skipping:
		# Start at the shooter's edge facing the target, and keep the two sides' tracers on
		# parallel lanes so a trade shows both streaks.
		var dir: Vector2 = (to - from).normalized() if to != from else Vector2.UP
		var lane_off: Vector2 = dir.orthogonal() * (5.0 if side == viewer_side else -5.0)
		var fx: Control = TracerFx.new()
		fx.from = from + dir * 18.0 + lane_off
		fx.to = to - dir * 6.0 + lane_off
		# kc-board: a shot that skips the frontline (Pick, Flank) runs OUTSIDE the column, down the
		# gutter, so it visibly passes the cards in front of its target.
		var skipped: int = _row_of(target)
		if skipped > 0 and locator != null:
			var col: Rect2 = locator.zone_rect(zone)
			if col.has_area():
				var gx: float = _to_local(Vector2(col.end.x + 7.0, 0.0)).x
				fx.from = Vector2(gx, from.y)
				fx.to = Vector2(gx, to.y)
				var flank: bool = false
				for kw: Dictionary in _slot_entry(shooter).get("keywords", []):
					flank = flank or StringName(kw.get("id", &"")) == &"flank"
				var key: StringName = &"flank" if flank else &"pick"
				if not _skip_called.has(key):
					_skip_called[key] = true
					var armor: int = int(_slot_entry(target).get("armor", 0))
					_popup_at(to + Vector2(0, -4.0), "FLANK: OUTERMOST" if flank else "PICK: LOWEST ARMOR (%d)" % armor,
							&"heading", 16, FxStyle.side_color(side), ev, &"tag")
		fx.color = FxStyle.side_color(side)
		fx.wasted = target < 0
		_start(fx, &"tracer", ev)
		if target >= 0:
			_zone_of[target] = zone
			_arrival[target] = maxf(float(_arrival.get(target, 0.0)), _clock + fx.arrival_time())
	# b01: an other-side unit firing in the First Shot step had First Shot too, so its hit lands
	# at the same time as yours. Say so on the shooter, once per sequence.
	if ev.get("step", _step) == &"first_shot" and side != viewer_side and not _tagged_first_shot.has(shooter):
		_tagged_first_shot[shooter] = true
		_popup_at(_unit_point(shooter, side, zone) + Vector2(0, -22.0), "FIRST SHOT", &"heading", 16,
				FxStyle.side_color(side), ev, &"tag")
	return t.get_value(&"shot_stagger")


## Row of a unit on the board (0 = frontline), -1 when unknown (kc-board columns).
func _row_of(uid: int) -> int:
	if uid < 0 or locator == null or not locator.has_method(&"find_slot"):
		return -1
	var slot: Control = locator.find_slot(uid)
	return int(slot.get(&"row")) if slot != null and "row" in slot else -1


func _slot_entry(uid: int) -> Dictionary:
	var slot: Control = locator.find_slot(uid) if locator != null and locator.has_method(&"find_slot") else null
	return slot.get(&"entry") if slot != null and "entry" in slot else {}


## b01: names the step so a trade in the First Shot step and the next unit's return fire in
## the Main step read as two separate moments.
func _on_step(ev: Dictionary, t: RefCounted) -> float:
	_current_zone = ev.get("zone", _current_zone)
	_step = ev.get("step", &"")
	var text: String = String(STEP_LABELS.get(_step, ""))
	var r: Rect2 = _zone_rect(_current_zone)
	if text == "" or not r.has_area() or _skipping:
		return t.get_value(&"step_pause")
	# kc-board: the column centre is the objective tile (its own words); name the step at the
	# column's top edge instead, over the rival's back row.
	_popup_at(_to_local(Vector2(r.get_center().x, r.position.y + minf(28.0, r.size.y * 0.1))), text, &"heading", 20, FxStyle.FOG, ev, &"step")
	return t.get_value(&"step_pause") + t.get_value(&"popup_beat")


func _on_damage(ev: Dictionary, t: RefCounted) -> float:
	var uid: int = int(ev.get("target_uid", -1))
	var target_side: StringName = ev.get("side", &"enemy")
	var amount: int = int(ev.get("amount", 0))
	var lethal: bool = int(ev.get("remaining", 1)) <= 0
	_arrival.erase(uid)
	if _skipping:
		return 0.0
	var rect: Rect2 = _unit_rect_local(uid, target_side)
	var marker: Control = HitMarkerFx.new()
	marker.center = rect.get_center()
	marker.color = FxStyle.side_color(_other(target_side))
	marker.lethal = lethal
	marker.radius = clampf(minf(rect.size.x, rect.size.y) * 0.32, 12.0, 24.0)
	_start(marker, &"hit_marker", ev)
	if amount > 0:
		_number(uid, "-%d" % amount, FxStyle.FOG, lethal, ev)
	else:
		_tag(uid, "BLOCKED", FxStyle.FOG_DIM, ev)
	return 0.05 * t.scale()


func _on_eliminated(ev: Dictionary, t: RefCounted) -> float:
	var victim: int = int(ev.get("victim_uid", -1))
	var victim_side: StringName = ev.get("victim_side", &"enemy")
	var by_side: StringName = ev.get("by_side", _other(victim_side))
	var is_operator: bool = bool(ev.get("is_operator", false))
	if ev.has("zone"):
		_zone_of[victim] = ev["zone"]
	# Killfeed first: it persists, so it also runs while skipping.
	if killfeed != null:
		var line: Control = killfeed.push(_killfeed_entry(ev), _timing)
		_log(&"killfeed", line, float(line.get(&"life")), ev)
	if _skipping:
		return 0.0
	var rect: Rect2 = _unit_rect_local(victim, victim_side)
	var stamp: Control = ElimStampFx.new()
	stamp.center = rect.get_center()
	if is_operator:
		stamp.text = "OPERATOR DOWN"
	elif victim_side == viewer_side:
		stamp.text = "DOWN"
	else:
		stamp.text = "ELIMINATED"
	stamp.color = FxStyle.side_color(victim_side)
	stamp.hazard = victim_side != viewer_side
	stamp.font_size = 20 if rect.size.x < 90.0 else 22
	_veil(victim)
	_start(stamp, &"stamp", ev)
	if by_side == viewer_side and bool(ev.get("credit", true)) and int(score_popups.get(&"elimination", 0)) > 0:
		_popup_at(rect.get_center() + Vector2(0, -rect.size.y * 0.5 - 6.0),
				"+%d ELIMINATION" % int(score_popups[&"elimination"]), &"heading", 22, FxStyle.AMBER, ev)
	_hitstop(t.get_value(&"hitstop"), ev)
	_shake(t.get_value(&"shake_px_big" if is_operator or bool(ev.get("by_killstreak", false)) else &"shake_px"),
			t.get_value(&"shake"), ev)
	return t.get_value(&"elim_beat")


func _on_streak(ev: Dictionary, t: RefCounted) -> float:
	if ev.get("side") != viewer_side or streak_arc == null:
		return 0.0
	if _skipping:
		streak_arc.set_streak(int(ev.get("streak", 0)), _timing)
		streak_arc.finish()
		return 0.0
	var reset: bool = bool(ev.get("reset", false))
	var dur: float = streak_arc.play_change(ev, _timing)
	_log(&"shatter" if reset else &"streak", streak_arc, dur, ev)
	if reset:
		_popup_at(_arc_point(-1.0), "STREAK LOST", &"numeric", 20, FxStyle.FOG, ev)
	return maxf(dur, t.get_value(&"streak_beat"))


func _on_item_revealed(ev: Dictionary, t: RefCounted) -> float:
	var item_id: StringName = ev.get("item_id", &"")
	if _is_killstreak(item_id):
		if _skipping or takeover == null:
			return 0.0
		var dur: float = takeover.show_call_in({"item_id": item_id, "name": _display_name(item_id),
				"side": ev.get("side", &"player"), "zone": ev.get("zone", &"")}, _timing)
		_log(&"takeover", takeover, dur, ev)
		return dur
	var zone: StringName = ev.get("zone", &"")
	_popup_at(_zone_point(zone, ev.get("side", &"player")), _display_name(item_id).to_upper(), &"heading", 20,
			FxStyle.side_color(ev.get("side", &"player")), ev, &"tag")
	return t.get_value(&"popup_beat")


# --- effect helpers -------------------------------------------------------------------------

func _start(fx: Control, kind: StringName, ev: Dictionary) -> void:
	fx.add_to_group(GROUP_TRANSIENT)
	add_child(fx)
	# Keep the takeover on top of everything else.
	if takeover != null:
		move_child(takeover, get_child_count() - 1)
	fx.play(_timing)
	_log(kind, fx, fx.duration, ev)


func _number(uid: int, text: String, color: Color, big: bool, ev: Dictionary) -> void:
	if _skipping:
		return
	var rect: Rect2 = _unit_rect_local(uid, _side_of_target(ev))
	var n: int = int(_hit_count.get(uid, 0))
	_hit_count[uid] = n + 1
	var fx: Control = FloatTextFx.new()
	fx.setup(text, &"numeric", 30 if big else 26, color, &"damage_number")
	fx.anchor = rect.get_center() + Vector2(rect.size.x * 0.22 + n * 6.0, -rect.size.y * 0.18 - n * 14.0)
	fx.rise_key = &"damage_rise"
	fx.duration_key = &"damage_number"
	_start(fx, &"damage_number", ev)


func _tag(uid: int, text: String, color: Color, ev: Dictionary) -> void:
	if _skipping:
		return
	var rect: Rect2 = _unit_rect_local(uid, _side_of_target(ev))
	_popup_at(rect.get_center() + Vector2(0, rect.size.y * 0.25), text, &"heading", 18, color, ev, &"tag")


func _popup_at(point: Vector2, text: String, font: StringName, font_size: int, color: Color,
		ev: Dictionary, kind: StringName = &"popup") -> void:
	if _skipping:
		return
	var fx: Control = FloatTextFx.new()
	fx.setup(text, font, maxi(font_size, FxStyle.MIN_TEXT_PX), color, kind)
	fx.anchor = _clamp_point(point)
	fx.rise_key = &"popup_rise" if kind == &"popup" else &"damage_rise"
	fx.duration_key = &"popup"
	_start(fx, kind, ev)


## Veils the victim's slot (see DownVeil) for the rest of the sequence. Logged as &"veil".
func _veil(uid: int) -> void:
	if uid < 0 or _veils.has(uid) or locator == null:
		return
	var v: DownVeil = DownVeil.new()
	v.uid = uid
	v.director = self
	add_child(v)
	# Below the transient effects (the stamp goes on top of it).
	move_child(v, 0)
	v.follow()
	_veils[uid] = v
	_log(&"veil", v, 0.0, {"type": RulesEvent.UNIT_ELIMINATED})


## Uids veiled in the current sequence (tests).
func veiled_uids() -> Array:
	return _veils.keys()


func clear_veils() -> void:
	for v: Variant in _veils.values():
		if is_instance_valid(v):
			(v as Node).queue_free()
	_veils.clear()


## Overlay-local rect of a unit's slot, Rect2() when the board does not show it.
func _veil_rect(uid: int) -> Rect2:
	if locator == null:
		return Rect2()
	var r: Rect2 = locator.unit_rect(uid)
	return Rect2(_to_local(r.position), r.size) if r.has_area() else Rect2()


func _wait(sec: float) -> void:
	_wait_tween = create_tween()
	_wait_tween.tween_interval(sec)
	await _wait_tween.finished


func _hitstop(sec: float, ev: Dictionary) -> void:
	if sec <= 0.0 or _skipping or _hitstop_on:
		return
	_hitstop_on = true
	process_mode = Node.PROCESS_MODE_DISABLED
	_log(&"hitstop", null, sec, ev)
	get_tree().create_timer(sec, true, false, true).timeout.connect(_end_hitstop)


func _end_hitstop() -> void:
	if not _hitstop_on:
		return
	_hitstop_on = false
	process_mode = Node.PROCESS_MODE_INHERIT


func _shake(px: float, sec: float, ev: Dictionary) -> void:
	if px <= 0.0 or sec <= 0.0 or _skipping:
		return
	var vp: Viewport = get_viewport()
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	else:
		_shake_base = vp.canvas_transform
	_shake_tween = create_tween()
	_shake_tween.tween_method(func(k: float) -> void:
		var amp: float = px * (1.0 - k)
		var off: Vector2 = Vector2(randf_range(-amp, amp), randf_range(-amp, amp)).round()
		vp.canvas_transform = Transform2D(0.0, _shake_base.origin + off), 0.0, 1.0, sec)
	_shake_tween.finished.connect(_stop_shake)
	_log(&"shake", null, sec, ev)


func _stop_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		get_viewport().canvas_transform = _shake_base
	elif _shake_tween != null:
		get_viewport().canvas_transform = _shake_base
	_shake_tween = null


func _log(kind: StringName, node: Object, dur: float, ev: Dictionary) -> void:
	fx_log.append({"kind": kind, "duration": dur, "type": ev.get("type", &"")})
	fx_started.emit(kind, node, dur)


# --- geometry -----------------------------------------------------------------------------

func _to_local(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point


func _unit_rect_local(uid: int, side: StringName) -> Rect2:
	var r: Rect2 = Rect2()
	if locator != null and uid >= 0:
		r = locator.unit_rect(uid)
	if r.has_area():
		return Rect2(_to_local(r.position), r.size)
	var p: Vector2 = _zone_point(_zone_of.get(uid, _current_zone), side)
	return Rect2(p - Vector2(40, 40), Vector2(80, 80))


func _unit_point(uid: int, side: StringName, zone: StringName) -> Vector2:
	if locator != null and uid >= 0:
		var r: Rect2 = locator.unit_rect(uid)
		if r.has_area():
			return _to_local(r.get_center())
	return _zone_point(zone, side)


## Point inside a zone: enemy line in the upper part, the viewer's line in the lower part.
func _zone_point(zone: StringName, side: StringName) -> Vector2:
	var r: Rect2 = _zone_rect(zone)
	if not r.has_area():
		var s: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
		return Vector2(s.x * 0.5, s.y * (0.3 if side != viewer_side else 0.6))
	var g: Vector2 = Vector2(r.get_center().x, r.position.y + r.size.y * (0.35 if side != viewer_side else 0.72))
	return _to_local(g)


func _zone_rect(zone: StringName) -> Rect2:
	if locator == null or zone == &"":
		return Rect2()
	return locator.zone_rect(zone)


func _anchor_rect(anchor: StringName) -> Rect2:
	if locator == null or not locator.has_method(&"anchor_rect"):
		return Rect2()
	return locator.anchor_rect(anchor)


## Where streak pop-ups go: just above the locator's &"streak" anchor (the Operator panel)
## so they never cover its numbers, else just above the StreakArc, else bottom-left.
func _arc_point(y_dir: float) -> Vector2:
	var anchor: Rect2 = _anchor_rect(&"streak")
	if anchor.has_area():
		var x: float = anchor.position.x + anchor.size.x * 0.5
		if streak_arc != null and streak_arc is Control and (streak_arc as Control).is_inside_tree():
			x = (streak_arc as Control).get_global_rect().get_center().x
		return _to_local(Vector2(x, anchor.position.y - 22.0))
	if streak_arc != null and streak_arc is Control and (streak_arc as Control).is_inside_tree():
		var r: Rect2 = (streak_arc as Control).get_global_rect()
		return _to_local(r.get_center() + Vector2(0, y_dir * (r.size.y * 0.5 + 18.0)))
	var s: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
	return Vector2(s.x * 0.2, s.y * 0.7)


## Keeps a pop-up's centre at least 80 / 20 px inside the overlay.
func _clamp_point(p: Vector2) -> Vector2:
	var s: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
	return Vector2(clampf(p.x, 80.0, maxf(80.0, s.x - 80.0)), clampf(p.y, 20.0, maxf(20.0, s.y - 20.0)))


# --- data ---------------------------------------------------------------------------------

func _killfeed_entry(ev: Dictionary) -> Dictionary:
	var by_uid: int = int(ev.get("by_uid", -1))
	var victim: int = int(ev.get("victim_uid", -1))
	var by_id: StringName = ev.get("by_id", &"")
	var kind: StringName = ev.get("source_kind", &"unit")
	var attacker: String = unit_names.get(by_uid, _display_name(by_id)) if by_uid >= 0 else _display_name(by_id)
	if attacker == "":
		attacker = "HOSTILE" if ev.get("by_side") != viewer_side else "SQUAD"
	var icon: StringName = SOURCE_ICONS.get(kind, &"stat_firepower")
	if kind == &"unit":
		icon = _class_icon(by_id)
	elif kind == &"killstreak":
		icon = CallInTakeover.ICONS.get(by_id, &"type_killstreak")
	elif kind in [&"lethal", &"secondary", &"tactical"] and by_uid >= 0 and unit_names.has(by_uid):
		attacker = unit_names[by_uid]
	return {
		"attacker": attacker, "attacker_side": ev.get("by_side", &"player"),
		"victim": unit_names.get(victim, _display_name(ev.get("victim_id", &""))),
		"victim_side": ev.get("victim_side", &"enemy"),
		"icon": icon, "zone": ev.get("zone", &""), "killstreak": bool(ev.get("by_killstreak", false)),
	}


func _class_icon(card_id: StringName) -> StringName:
	var db: Node = _card_db()
	if db != null and db.call(&"has_card", card_id):
		var wc: int = int(db.call(&"get_card", card_id).get(&"weapon_class"))
		if wc >= 0 and wc < CLASS_ICONS.size():
			return CLASS_ICONS[wc]
	return &"stat_firepower"


func _display_name(id: StringName) -> String:
	if id == &"":
		return ""
	var db: Node = _card_db()
	if db != null:
		if db.call(&"has_card", id):
			return String(db.call(&"get_card", id).get(&"display_name"))
		var item: Resource = db.call(&"get_loadout_item", id)
		if item != null and String(item.get(&"display_name")) != "":
			return String(item.get(&"display_name"))
	return String(id).replace("_", " ").capitalize()


func _is_killstreak(id: StringName) -> bool:
	var db: Node = _card_db()
	if db != null:
		var item: Resource = db.call(&"get_loadout_item", id)
		if item != null:
			return int(item.get(&"slot")) == DataEnums.LoadoutSlot.KILLSTREAK
	return id in KNOWN_KILLSTREAKS


func _card_db() -> Node:
	return get_tree().root.get_node_or_null(^"CardDB") if is_inside_tree() else null


func _visible_to_viewer(ev: Dictionary) -> bool:
	return not ev.has("private_to") or ev["private_to"] == viewer_side


func _side_of_target(ev: Dictionary) -> StringName:
	match ev.get("type", &""):
		RulesEvent.DAMAGE_DEALT, RulesEvent.SURVIVED_LETHAL:
			return ev.get("side", &"enemy")
		RulesEvent.PATCHED, RulesEvent.UNIT_HEALED:
			return ev.get("side", viewer_side)
		RulesEvent.SUPPRESSED, RulesEvent.EQUIPMENT_TRIGGERED:
			return _other(ev.get("side", viewer_side))
	return &"enemy"


func _other(side: StringName) -> StringName:
	return &"enemy" if side == &"player" else &"player"


func _make_timing() -> RefCounted:
	if use_settings:
		var s: RefCounted = FxTiming.from_settings()
		fast = s.fast
		reduced_motion = s.reduced_motion
	return FxTiming.create(fast, reduced_motion)
