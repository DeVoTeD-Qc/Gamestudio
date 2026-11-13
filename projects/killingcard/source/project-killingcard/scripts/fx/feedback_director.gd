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
#     kc-ks-seq, killstreaks (killstreak_fx.gd banner + markers, strike_fx.gd sequences; the old
#     full-screen call-in takeover is retired):
#     KILLSTREAK_EARNED   compact "<NAME> READY" banner in the streak's colour, with its one-line effect
#     ITEM_USED (yours)   "CALLED IN" banner; Recon Drone scans the rival half at once
#     ITEM_REVEALED       the rival's killstreak: HOSTILE banner; Sentry: the drop sequence (both
#                         sides); the rival's Recon Drone scans your half; other items: name tag
#     KILLSTREAK_QUEUED   INCOMING / AT FIGHT marker on the half-column(s) the strike will hit
#     KILLSTREAK_STRIKE   (Firefight step 0) the marker goes, the streak's sequence plays: mortar
#                         shells arc in and burst on each unit, the helo strafes each front unit;
#                         the DAMAGE_DEALT numbers that follow land with each impact
#     UNIT_ELIMINATED by a strike: "MORTAR KILL" / "HELO KILL" tag in the streak's colour (kc-ks-pop),
#                         inspectable, instead of "+100 ELIMINATION"
#     KILLSTREAK_RESOLVED the plain log line ("Mortar Barrage hit column C: Rifleman -2 (down)") as a
#                         caption and a killfeed line, then the fight goes on
#     SUPPRESSED / SURVIVED_LETHAL / PATCHED / EQUIPMENT_TRIGGERED: short tags
#     ZONE_CONTROL / MODE_SCORED: "+50 ZONE SECURED" / "+N POINTS" pop-ups
#   Everything else costs no time. No rules logic: it reads the event fields and nothing else.
#   Events with `private_to` another side are skipped.
#
#   kc-fight-ui, step-by-step firefight (firefight-order.md §8 / §10.2), paced on the §5 model:
#     FIREFIGHT_STARTED       "COLUMN A" at the column, it stays bright and the others dim (0.4 s)
#     FIREFIGHT_BEAT          the beat's shooters lift (banner nudged toward the enemy) with a thick
#                             side-coloured outline; the First Shot half of a split exchange tags
#                             its shooter "FIRST SHOT"; each beat lasts at least fight_beat (0.8 s)
#     SHOT_FIRED              tracer (0.35 s travel inside a beat); the shooter gets a "fired" pip
#     PIERCE_CARRIED          a thinner tracer continues from the target to the unit behind once
#                             the first one lands; its damage number is smaller ("-1 PIERCE")
#     DAMAGE_DEALT (amount 0) "-0" + "COVER" (the hit was absorbed)
#     LINE_ADVANCED           waits for the stamp, then the board slides (the controller refreshes
#                             the board on event_landed), 0.35 s
#     FIREFIGHT_COLUMN_ENDED  column summary ("COLUMN A: 2 KILLS · 1 LOST")
#   The overlay (fight_overlay.gd) holds the dim, the outlines and the pips; pips clear at Score.
#
#   kc-juice (the head's "8. Juice pass"):
#     hit-stop            on every elimination, by importance: a unit 60 ms, a killstreak kill 75 ms,
#                         the Operator 90 ms. It pauses this overlay only (its waits, tracers and
#                         numbers), so the playback is late by exactly that much and never more; the
#                         timer follows Engine.time_scale (SPEED x2) and fast animations halve it.
#     screen shake        directional (along the shot that caused it), capped at 4 px: eliminations
#                         (3 px; Operator / killstreak 4 px) and big hits that do not kill (Damage
#                         >= BIG_HIT or on the Operator: 2 px). Settings.screen_shake off: none.
#     sound cues          (sfx_bank.gd) each round step (Reveal / Firefight / Score: step_1..3,
#                         rising), each beat of a column (beat_1..4: a minor third higher and one
#                         more layer per beat; beats past 4 keep rising in pitch), hit / hit_big /
#                         kill / block (Cover or no damage), column_win. `sfx_log` lists them.
#     column-win flourish ZONE_CONTROL for the viewer: an outline sweeps out of the column
#                         (column_flourish_fx.gd) under the "+50 ZONE SECURED" pop-up.
#
# Options: Settings.fast_animations halves every duration and beat; Settings.reduced_motion
#   removes shake, hit-stop and travel (see fx_timing.gd); Settings.screen_shake off removes the
#   shake. Read at the start of each play().
#
# Use (match controller):
#   director.locator = BoardFxLocator.new(board)   # or any object with unit_rect/zone_rect/anchor_rect
#   director.locator.sync_from_state(state)        # BEFORE resolving, while the board shows it
#   await director.play(new_events)                # then render the new snapshot
#   director.skip()                                # fast-forward (F key / tap)
#
# Scene: res://scenes/fx/FeedbackDirector.tscn: full-rect overlay Control (mouse ignored) that
#   holds the transient effects and the KillstreakFx layer. Put it last under the match root so it
#   draws on top. The Killfeed and StreakArc live in the HUD and are assigned (or set by path).
# Dependencies: fx_*.gd, killfeed.gd, streak_arc.gd, killstreak_fx.gd, strike_fx.gd, RulesEvent,
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
## kc-fight-ui: this event lands now (after its pre-wait, before its effects): the controller applies
## it to the playback board here (a LINE_ADVANCED refresh slides the line after the stamp was read).
signal event_landed(event: Dictionary)
## kc-fight-ui (head: "way too fast, I can't understand what happens"): the plain-words caption of
## what is happening now, one line per shot of the beat ("Gunner (A1) hits Rival Rifleman for 2 —
## destroyed"), or the rival card being revealed. [] = nothing to say.
signal caption_changed(lines: Array)
## An effect started: kind (&"tracer", &"hit_marker", &"damage_number", &"stamp", &"popup",
## &"killfeed", &"streak", &"shatter", &"ks_banner", &"ks_queued", &"shells", &"strafe", &"scan", &"drop",
## &"shake", &"hitstop", &"tag"), node or null.
signal fx_started(kind: StringName, node: Object, duration: float)

const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const ScoreRace: GDScript = preload("res://scripts/ui/score_race.gd")
const FxStyle: GDScript = preload("res://scripts/fx/fx_style.gd")
const TracerFx: GDScript = preload("res://scripts/fx/tracer_fx.gd")
const HitMarkerFx: GDScript = preload("res://scripts/fx/hit_marker_fx.gd")
const FloatTextFx: GDScript = preload("res://scripts/fx/float_text_fx.gd")
const ElimStampFx: GDScript = preload("res://scripts/fx/elim_stamp_fx.gd")
const BoardFxLocator: GDScript = preload("res://scripts/fx/board_fx_locator.gd")
const StrikeFx: GDScript = preload("res://scripts/fx/strike_fx.gd")
const FightOverlay: GDScript = preload("res://scripts/fx/fight_overlay.gd")
const ColumnFlourishFx: GDScript = preload("res://scripts/fx/column_flourish_fx.gd")
const SfxBank: GDScript = preload("res://scripts/fx/sfx_bank.gd")
## kc-juice: a hit of at least this much Damage that does not kill shakes the screen a little.
const BIG_HIT: int = 4
## kc-juice: round step -> its cue (rising: Reveal, Firefight, Score).
const STEP_CUES: Dictionary = {&"reveal": &"step_1", &"firefight": &"step_2", &"score": &"step_3"}
const ZONE_LETTERS: Dictionary = {&"left": "A", &"mid": "B", &"right": "C"}
## Px a shooter's banner lifts toward the enemy while it fires.
const LIFT_PX: float = 5.0

const GROUP_TRANSIENT: StringName = &"fx_transient"
## Killstreak ids, used when CardDB cannot say (tests, previews without data).
const KNOWN_KILLSTREAKS: Array[StringName] = [&"recon_drone", &"mortar_barrage", &"sentry_turret", &"attack_helo", &"gunship"]
const SOURCE_ICONS: Dictionary = {
	&"operator": &"type_operator", &"tactic": &"type_tactic", &"equipment": &"type_equipment",
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
## kc-juice: Settings.screen_shake (read with the others in _make_timing()).
var screen_shake: bool = true
## kc-juice: tests turn hit-stop off to measure what it costs; the game always has it on.
var hitstop_enabled: bool = true
## kc-juice: the cues this director asked for since clear_log() (also when the SFX bank is missing).
var sfx_log: Array[StringName] = []
## Object with unit_rect(uid) / zone_rect(zone) / anchor_rect(name) -> Rect2 (global canvas px).
var locator: RefCounted = null
var killfeed: Node = null
var streak_arc: Node = null
## kc-ks-seq: the killstreak banner and the pending-strike markers (killstreak_fx.gd).
var ks: KillstreakFx = null
## uid -> display name, for killfeed lines (filled from UNIT_ARRIVED; controllers may add more).
var unit_names: Dictionary = {}
## Every effect started since clear_log(): {kind, duration, type (event type)}.
var fx_log: Array[Dictionary] = []

var _queue: Array = []
var _playing: bool = false
var _skipping: bool = false
## kc-r2-fixes (playtest r2 FAST): play a sequence as its column results only: everything else is
## skipped, each column's summary shows for SUMMARY_ONLY_BEAT s (a firefight in about 3 s).
var summary_only: bool = false
## A real skip (tap / F) during a summary-only sequence: the column results go too.
var _hard_skip: bool = false
const SUMMARY_ONLY_BEAT: float = 0.8
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
## kc-fight-ui: uid -> &"player" / &"enemy" (the controller fills it before play; shots add to it).
var unit_sides: Dictionary = {}
## Dim / now-firing outline / fired pips (fight_overlay.gd), created in _ready.
var overlay: Control = null
var _beat_t0: float = -1.0        # _clock when the current beat started (-1 = not in a beat)
var _lifted: Dictionary = {}      # uid -> BannerView nudged toward the enemy
var _pierce_hit: Dictionary = {}  # target uid -> true: its next DAMAGE_DEALT is a Pierce carry
var _summary: Dictionary = {}     # current column: {kills, lost}
var _shot_dir: Dictionary = {}    # kc-juice: target uid -> screen direction of the last shot at it
## The caption lines on screen now (caption_changed).
var captions: Array[String] = []


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
	ks = KillstreakFx.new()
	ks.name = "KillstreakFx"
	ks.viewer_side = viewer_side
	ks.zone_rect_fn = _zone_rect_local
	add_child(ks)
	overlay = FightOverlay.new()
	overlay.name = "FightOverlay"
	add_child(overlay)
	move_child(overlay, 0)
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
	_skipping = summary_only
	_hard_skip = false
	_timing = _make_timing()
	_hit_count.clear()
	_tagged_first_shot.clear()
	_step = &""
	_beat_t0 = -1.0
	_pierce_hit.clear()
	if overlay != null:
		overlay.clear()
		overlay.locator = locator
		overlay.viewer_side = viewer_side
	if ks != null:
		ks.viewer_side = viewer_side
	set_meta(&"qa_seen", [])
	_set_captions([])
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
		_before_land(ev)
		_qa_note(ev)
		event_landed.emit(ev)
		var beat: float = _handle(ev)
		if beat > 0.0 and (not _skipping or _summary_beat(ev)):
			await _wait(beat)
	_playing = false
	_skipping = false
	_hard_skip = false
	_end_fight()
	clear_veils()
	_set_captions([])
	sequence_finished.emit()


## QA (?qa=1 smoke tests read it through qa_bridge.gd): the last event landed and the types seen.
func _qa_note(ev: Dictionary) -> void:
	var t: String = String(ev.get("type", &""))
	set_meta(&"qa_last", t)
	var seen: Array = get_meta(&"qa_seen", [])
	if not seen.has(t):
		seen.append(t)


## True while skip() fast-forwards the rest of the sequence (the board is not refreshed per beat).
func is_skipping() -> bool:
	return _skipping


## Fast-forward: ends every running effect, plays the rest of the queue without waits or
## transient effects (killfeed lines and the streak still update), then finishes.
func skip() -> void:
	_skipping = true
	_hard_skip = true
	_end_hitstop()
	_stop_shake()
	_unlift(true)
	if overlay != null:
		overlay.clear()
	for node: Node in get_tree().get_nodes_in_group(GROUP_TRANSIENT):
		if is_ancestor_of(node):
			node.finish()
	if ks != null:
		ks.finish_banner()
	if killfeed != null:
		killfeed.finish_all()
	if streak_arc != null:
		streak_arc.finish()
	if _wait_tween != null and _wait_tween.is_valid():
		_wait_tween.custom_step(1.0e4)


## Summary-only playback (FAST): only the column results wait (until a real skip).
func _summary_beat(ev: Dictionary) -> bool:
	return summary_only and not _hard_skip and ev.get("type", &"") == RulesEvent.FIREFIGHT_COLUMN_ENDED


## FAST switched on or off. On while a sequence plays: the rest plays as column results only.
func set_summary_only(on: bool) -> void:
	summary_only = on
	if on and _playing and not _skipping:
		_end_hitstop()
		_stop_shake()
		_unlift(true)
		if overlay != null:
			overlay.clear()
		for node: Node in get_tree().get_nodes_in_group(GROUP_TRANSIENT):
			if is_ancestor_of(node):
				node.finish()
		_skipping = true
		if _wait_tween != null and _wait_tween.is_valid():
			_wait_tween.custom_step(1.0e4)


func clear_log() -> void:
	fx_log.clear()
	sfx_log.clear()


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
	match ev.get("type"):
		RulesEvent.DAMAGE_DEALT:
			var uid: int = int(ev.get("target_uid", -1))
			return maxf(0.0, float(_arrival.get(uid, 0.0)) - _clock)
		RulesEvent.FIREFIGHT_BEAT, RulesEvent.FIREFIGHT_COLUMN_ENDED:
			# A beat lasts at least fight_beat: what its effects did not use is waited here.
			if _beat_t0 >= 0.0:
				return maxf(0.0, _beat_t0 + _timing.get_value(&"fight_beat") + _timing.get_value(&"fight_beat_gap") - _clock)
		RulesEvent.LINE_ADVANCED:
			return _timing.get_value(&"fight_advance_hold")
	return 0.0


## Before an event lands: a new beat, a line advance or the column end puts the lifted banners
## back at once (the board may refresh and slide them right after).
func _before_land(ev: Dictionary) -> void:
	match ev.get("type"):
		RulesEvent.FIREFIGHT_BEAT, RulesEvent.LINE_ADVANCED, RulesEvent.FIREFIGHT_COLUMN_ENDED:
			_unlift(true)


## Starts the effects for one event; returns the beat (seconds) before the next event.
func _handle(ev: Dictionary) -> float:
	var t: RefCounted = _timing
	match ev.get("type", &""):
		RulesEvent.UNIT_ARRIVED:
			var card_id: StringName = ev.get("card_id", &"")
			if card_id != &"" and not unit_names.has(int(ev.get("uid", -1))):
				unit_names[int(ev.get("uid", -1))] = _display_name(card_id)
			_zone_of[int(ev.get("uid", -1))] = ev.get("zone", &"")
			unit_sides[int(ev.get("uid", -1))] = ev.get("side", &"")
			return _on_arrived(ev, t)
		RulesEvent.FIREFIGHT_STARTED:
			return _on_column_started(ev, t)
		RulesEvent.FIREFIGHT_BEAT:
			return _on_beat(ev, t)
		RulesEvent.PIERCE_CARRIED:
			return _on_pierce(ev, t)
		RulesEvent.LINE_ADVANCED:
			return t.get_value(&"fight_advance")
		RulesEvent.FIREFIGHT_COLUMN_ENDED:
			return _on_column_ended(ev, t)
		RulesEvent.PHASE_CHANGED:
			# The fired pips clear at the Score step.
			if StringName(ev.get("phase", &"")) != &"firefight":
				_end_fight()
			var step_cue: StringName = STEP_CUES.get(StringName(ev.get("phase", &"")), &"")
			if step_cue != &"":
				_sfx(step_cue)
			return 0.0
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
			if not _summary.is_empty():
				_summary["held"] = int(_summary.get("held", 0)) + 1
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
			return maxf(_ks_banner(ev, &"earned"), t.get_value(&"earned_beat"))
		RulesEvent.ITEM_USED:
			if ev.get("side") == viewer_side and _is_killstreak(ev.get("item_id", &"")):
				var beat: float = _ks_banner(ev, &"called")
				if StringName(ev.get("item_id", &"")) == &"recon_drone":
					beat = maxf(beat, _ks_scan(ev, _other(viewer_side)))
				return beat
			return 0.0
		RulesEvent.KILLSTREAK_QUEUED:
			return _on_ks_queued(ev, t)
		RulesEvent.KILLSTREAK_STRIKE:
			return _on_ks_strike(ev, t)
		RulesEvent.KILLSTREAK_RESOLVED:
			return _on_ks_resolved(ev, t)
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
					_column_flourish(Rect2(_to_local(r.position), r.size), ev)
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
	unit_sides[shooter] = side
	if target >= 0:
		unit_sides[target] = foe
	_note_shot(ev)
	var in_beat: bool = _beat_t0 >= 0.0
	if overlay != null and not _skipping:
		overlay.mark_fired(shooter)
	if in_beat and not _skipping:
		var lines: Array[String] = captions.duplicate()
		lines.append(shot_caption(ev))
		_set_captions(lines)
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
		if in_beat:
			fx.travel_key = &"fight_tracer"
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
			_shot_dir[target] = dir
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
	# The shots of the beat have all left: the shooters settle back.
	_unlift(false)
	var pierced: bool = _pierce_hit.has(uid)
	_pierce_hit.erase(uid)
	var rect: Rect2 = _unit_rect_local(uid, target_side)
	var marker: Control = HitMarkerFx.new()
	marker.center = rect.get_center()
	marker.color = FxStyle.side_color(_other(target_side))
	marker.lethal = lethal
	marker.radius = clampf(minf(rect.size.x, rect.size.y) * (0.24 if pierced else 0.32), 10.0, 24.0)
	_start(marker, &"hit_marker", ev)
	var on_operator: bool = bool(_slot_entry(uid).get("operator", false))
	if pierced:
		# kc-fight-ui: the carried damage is drawn smaller and named.
		_number(uid, "-%d PIERCE" % amount, FxStyle.FOG, false, ev, FxStyle.MIN_NUMBER_PX)
		_sfx(&"hit", 1.12, -4.0)
	elif amount > 0:
		_number(uid, "-%d" % amount, FxStyle.FOG, lethal, ev)
		var big: bool = amount >= BIG_HIT or on_operator
		_sfx(&"hit_big" if big else &"hit", randf_range(0.97, 1.03))
		# kc-juice: a big hit that does not kill nudges the screen along the shot (a kill shakes on
		# its own UNIT_ELIMINATED).
		if big and not lethal:
			_shake(t.get_value(&"shake_hit_px"), t.get_value(&"shake_hit"), ev, _shot_dir.get(uid, Vector2.ZERO))
	else:
		# No damage: "-0" and why (Cover when the target has some, else the hit was too weak).
		_number(uid, "-0", FxStyle.FOG_DIM, false, ev)
		_tag(uid, "COVER" if int(_slot_entry(uid).get("cover", 0)) > 0 else "NO DAMAGE", FxStyle.FOG_DIM, ev)
		_sfx(&"block")
	return 0.05 * t.scale()


func _on_eliminated(ev: Dictionary, t: RefCounted) -> float:
	var victim: int = int(ev.get("victim_uid", -1))
	var victim_side: StringName = ev.get("victim_side", &"enemy")
	var by_side: StringName = ev.get("by_side", _other(victim_side))
	var is_operator: bool = bool(ev.get("is_operator", false))
	if ev.has("zone"):
		_zone_of[victim] = ev["zone"]
	if not _summary.is_empty():
		_summary["lost" if victim_side == viewer_side else "kills"] = int(_summary["lost" if victim_side == viewer_side else "kills"]) + 1
	if overlay != null:
		overlay.shooters.erase(victim)
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
	if bool(ev.get("by_killstreak", false)) and String(ev.get("source_kind", &"killstreak")) == "killstreak" and ks != null:
		# kc-ks-pop (head S2): a strike's kill says which streak made it ("MORTAR KILL"), in its
		# owner's colour (kc-da-ui: teal yours, red the rival's), inspectable; no "+100 ELIMINATION" (and it never ticks the streak).
		var tag: Control = ks.show_kill_tag(rect.get_center() + Vector2(0, -rect.size.y * 0.5 - 6.0),
				StringName(ev.get("by_id", &"")), by_side, _timing)
		_log(&"ks_kill", tag, _timing.get_value(&"popup"), ev)
	elif by_side == viewer_side and bool(ev.get("credit", true)) and int(score_popups.get(&"elimination", 0)) > 0:
		_popup_at(rect.get_center() + Vector2(0, -rect.size.y * 0.5 - 6.0),
				"+%d ELIMINATION" % int(score_popups[&"elimination"]), &"heading", 22, FxStyle.AMBER, ev)
	var by_ks: bool = bool(ev.get("by_killstreak", false))
	_sfx(&"kill", 0.86 if is_operator else randf_range(0.97, 1.03))
	_hitstop(t.get_value(hitstop_key(ev)), ev)
	_shake(t.get_value(&"shake_px_big" if is_operator or by_ks else &"shake_px"),
			t.get_value(&"shake"), ev, _shot_dir.get(victim, Vector2.ZERO))
	return t.get_value(&"fight_elim" if _beat_t0 >= 0.0 else &"elim_beat")


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
		if _skipping:
			return 0.0
		var side: StringName = ev.get("side", &"player")
		var beat: float = 0.0
		if side != viewer_side:
			beat = _ks_banner(ev, &"revealed")
		match StringName(KillstreakFx.look(item_id)["seq"]):
			&"drop":
				beat = maxf(beat, _ks_drop(ev))
			&"scan":
				if side != viewer_side:
					beat = maxf(beat, _ks_scan(ev, viewer_side))
		return beat
	var zone: StringName = ev.get("zone", &"")
	_popup_at(_zone_point(zone, ev.get("side", &"player")), _display_name(item_id).to_upper(), &"heading", 20,
			FxStyle.side_color(ev.get("side", &"player")), ev, &"tag")
	return t.get_value(&"popup_beat")


# --- killstreaks (kc-ks-seq) ------------------------------------------------------------------

## The compact banner for an event with item_id / side. Returns the playback's wait for it.
func _ks_banner(ev: Dictionary, mode: StringName) -> float:
	if _skipping or ks == null:
		return 0.0
	var item_id: StringName = ev.get("item_id", &"")
	var wait: float = ks.show_banner({"item_id": item_id, "side": ev.get("side", &"player"), "mode": mode,
			"name": _display_name(item_id)}, _timing)
	_log(&"ks_banner", ks.banner, _timing.get_value(&"ks_banner"), ev)
	if mode == &"earned":
		_sfx(&"reward", 1.1, -4.0)
	return wait


func _on_ks_queued(ev: Dictionary, t: RefCounted) -> float:
	var side: StringName = ev.get("side", &"player")
	var item_id: StringName = ev.get("item_id", &"")
	var fights: int = int(ev.get("fights", 1))
	var added: int = ks.add_pending(item_id, side, ev.get("zones", []), "AT FIGHT" if fights <= 1 else "%d FIGHTS" % fights) if ks != null else 0
	if _skipping:
		return 0.0
	var zones: Array = ev.get("zones", [])
	var where: String = "every column" if zones.size() == 3 else "column %s" % ZONE_LETTERS.get(StringName(zones[0]) if not zones.is_empty() else &"", "?")
	_set_captions(["%s%s: incoming on %s. It strikes when the fight starts." % ["Rival " if side != viewer_side else "Your ",
			_display_name(item_id), where]])
	if added > 0:
		_log(&"ks_queued", ks, t.get_value(&"ks_queued"), ev)
		return t.get_value(&"ks_queued")
	return 0.0


## Firefight step 0: the strike's own sequence. The DAMAGE_DEALT events that follow (up to its
## KILLSTREAK_RESOLVED) are its hits; each waits for its own impact (see _pre_wait / _arrival).
func _on_ks_strike(ev: Dictionary, t: RefCounted) -> float:
	var side: StringName = ev.get("side", &"player")
	var item_id: StringName = ev.get("item_id", &"")
	if ks != null:
		ks.clear_pending(item_id, side)
	var hits: Array[int] = []
	for next: Variant in _queue:
		var nev: Dictionary = next
		if nev.get("type") == RulesEvent.KILLSTREAK_RESOLVED:
			break
		if nev.get("type") == RulesEvent.DAMAGE_DEALT and StringName(nev.get("source_id", &"")) == item_id:
			var uid: int = int(nev.get("target_uid", -1))
			if uid >= 0 and uid not in hits:
				hits.append(uid)
	if _skipping:
		return 0.0
	var zones: Array = ev.get("zones", [])
	var where: String = "every column" if zones.size() == 3 else "column %s" % ZONE_LETTERS.get(StringName(zones[0]) if not zones.is_empty() else &"", "?")
	var pass_text: String = " (fight %d of %d)" % [int(ev.get("pass", 1)), int(ev.get("passes", 1))] if int(ev.get("passes", 1)) > 1 else ""
	_set_captions(["Killstreak: %s%s strikes %s%s." % ["rival " if side != viewer_side else "your ", _display_name(item_id), where, pass_text]])
	var foe: StringName = _other(side)
	var fx: Control = StrikeFx.new()
	fx.style = KillstreakFx.look(item_id)["seq"]
	fx.color = KillstreakFx.owner_color(StringName(ev.get("side", &"player")), viewer_side)
	fx.icon = KillstreakFx.icon_of(item_id)
	fx.reduced = t.reduced_motion
	var targets: Array[Vector2] = []
	for uid: int in hits:
		var z: StringName = _zone_of.get(uid, StringName(zones[0]) if not zones.is_empty() else &"")
		targets.append(_unit_point(uid, foe, z))
		unit_sides[uid] = foe
	var all: Rect2 = Rect2()
	for z: Variant in zones:
		var r: Rect2 = _zone_rect_local(StringName(z))
		all = r if not all.has_area() else all.merge(r)
	if not all.has_area():
		all = Rect2(Vector2.ZERO, size if size.x > 0.0 else get_viewport_rect().size)
	if targets.is_empty():
		for z: Variant in zones:
			targets.append(_zone_point(StringName(z), foe))
	fx.targets = targets
	fx.area = all
	if fx.style == &"strafe":
		# Enters from the caster's left (yours) or right (the rival's).
		fx.origin = Vector2(all.position.x if side == viewer_side else all.end.x, all.position.y)
		_sfx(&"ks_rotor")
	else:
		fx.style = &"shells"
		# Shells leave from the caster's edge of the screen, below (yours) or above (the rival's).
		var s: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
		fx.origin = Vector2(all.get_center().x - 60.0, s.y + 10.0) if side == viewer_side else Vector2(all.get_center().x + 60.0, -10.0)
		_sfx(&"ks_whistle")
	_start(fx, fx.style, ev)
	var impacts: Array[float] = fx.impact_times(t)
	for i: int in hits.size():
		_arrival[hits[i]] = maxf(float(_arrival.get(hits[i], 0.0)), _clock + impacts[i])
		_shot_dir[hits[i]] = Vector2.DOWN if side == viewer_side else Vector2.UP
	if hits.is_empty():
		return fx.duration
	# The numbers wait for their impacts; the sequence's tail plays under them.
	return 0.0


func _on_ks_resolved(ev: Dictionary, t: RefCounted) -> float:
	var side: StringName = ev.get("side", &"player")
	var item_id: StringName = ev.get("item_id", &"")
	var line: String = ks_line(ev)
	if killfeed != null:
		# The killfeed has room for names only: "MORTAR BARRAGE > 3 HIT · 2 DOWN"; the caption and the
		# match log carry the full line.
		var n_hits: int = (ev.get("hits", []) as Array).size()
		var n_down: int = (ev.get("kills", []) as Array).size()
		var summary: String = "NO TARGET" if n_hits == 0 else ("%d HIT" % n_hits + (" · %d DOWN" % n_down if n_down > 0 else ""))
		var entry: Control = killfeed.push({"attacker": _display_name(item_id), "attacker_side": side,
				"victim": summary, "victim_side": _other(side),
				"icon": KillstreakFx.look(item_id)["icon"], "zone": ev.get("zone", &""), "killstreak": true}, _timing)
		_log(&"killfeed", entry, float(entry.get(&"life")), ev)
	if _skipping:
		return 0.0
	_set_captions([line])
	if not (ev.get("hits", []) as Array).is_empty():
		_sfx(&"hit_big", 0.9)
		_shake(t.get_value(&"shake_hit_px"), t.get_value(&"shake_hit"), ev, Vector2.DOWN if side == viewer_side else Vector2.UP)
	return t.get_value(&"ks_resolved")


## The plain log line of a KILLSTREAK_RESOLVED, with the names the board shows (unit_names).
func ks_line(ev: Dictionary) -> String:
	var hits: Array = []
	for h: Variant in ev.get("hits", []):
		var hd: Dictionary = (h as Dictionary).duplicate()
		var uid: int = int(hd.get("uid", -1))
		if unit_names.has(uid) and String(unit_names[uid]) != "":
			hd["name"] = unit_names[uid]
		hits.append(hd)
	var zones: Array[int] = []
	for z: Variant in ev.get("zones", []):
		zones.append(MapData.ZONE_IDS.find(StringName(z)))
	if hits.is_empty() and String(ev.get("what", "")) != "" and zones.is_empty():
		return String(ev["what"])
	return KillstreakStrikes.log_line(_display_name(ev.get("item_id", &"")), zones, hits, ev.get("kills", []))


## Recon Drone: a scan over the `scanned` side's half of the board.
func _ks_scan(ev: Dictionary, scanned: StringName) -> float:
	if _skipping:
		return 0.0
	var item_id: StringName = ev.get("item_id", &"recon_drone")
	var all: Rect2 = Rect2()
	for z: StringName in [&"left", &"mid", &"right"]:
		var r: Rect2 = _zone_rect_local(z)
		if r.has_area():
			all = r if not all.has_area() else all.merge(r)
	if not all.has_area():
		all = Rect2(Vector2.ZERO, size if size.x > 0.0 else get_viewport_rect().size)
	var half: Rect2 = Rect2(all.position + Vector2(0, 0 if scanned != viewer_side else all.size.y * 0.5), Vector2(all.size.x, all.size.y * 0.5))
	var fx: Control = StrikeFx.new()
	fx.style = &"scan"
	fx.color = KillstreakFx.owner_color(StringName(ev.get("side", &"player")), viewer_side)
	fx.icon = KillstreakFx.icon_of(item_id)
	fx.area = half
	fx.reduced = _timing.reduced_motion
	_sfx(&"ks_scan")
	_start(fx, &"scan", ev)
	return fx.duration


## Sentry Turret: drops in at the back of the caster's line in its column.
func _ks_drop(ev: Dictionary) -> float:
	if _skipping:
		return 0.0
	var item_id: StringName = ev.get("item_id", &"sentry_turret")
	var side: StringName = ev.get("side", &"player")
	var col: Rect2 = _zone_rect_local(ev.get("zone", &""))
	if not col.has_area():
		var p: Vector2 = _zone_point(ev.get("zone", &""), side)
		col = Rect2(p - Vector2(60, 120), Vector2(120, 240))
	var fx: Control = StrikeFx.new()
	fx.style = &"drop"
	fx.color = KillstreakFx.owner_color(StringName(ev.get("side", &"player")), viewer_side)
	fx.icon = KillstreakFx.icon_of(item_id)
	fx.area = col
	fx.end_point = Vector2(col.get_center().x, col.position.y + col.size.y * (0.88 if side == viewer_side else 0.12))
	fx.targets = [fx.end_point] as Array[Vector2]
	fx.reduced = _timing.reduced_motion
	_sfx(&"card_land", 0.8)
	_start(fx, &"drop", ev)
	_popup_at(fx.end_point + Vector2(0, -34.0 if side == viewer_side else 34.0), "SENTRY ONLINE", &"heading", 16,
			fx.color, ev, &"tag")
	return fx.duration


func _zone_rect_local(zone: StringName) -> Rect2:
	var r: Rect2 = _zone_rect(zone)
	return Rect2(_to_local(r.position), r.size) if r.has_area() else Rect2()


## kc-ks-seq: the strikes still waiting for a fight, as markers (the controller calls it each refresh).
func set_pending_strikes(list: Array) -> void:
	if ks != null:
		ks.set_pending(list)


# --- step-by-step firefight (kc-fight-ui) --------------------------------------------------

func _on_column_started(ev: Dictionary, t: RefCounted) -> float:
	_current_zone = ev.get("zone", &"")
	_step = &""
	_beat_t0 = -1.0
	_summary = {"zone": _current_zone, "kills": 0, "lost": 0}
	if _skipping:
		return 0.0
	_set_captions(["Column %s fights: front to back, one shot each." % ZONE_LETTERS.get(_current_zone, "?")])
	if overlay != null:
		overlay.set_active_zone(_current_zone)
		overlay.set_shooters({})
	var r: Rect2 = _zone_rect(_current_zone)
	if r.has_area():
		# Over the rival's back row (the objective tile keeps its own words).
		_popup_at(_to_local(Vector2(r.get_center().x, r.position.y + minf(30.0, r.size.y * 0.1))),
				"COLUMN %s" % ZONE_LETTERS.get(_current_zone, "?"), &"heading", 22, FxStyle.AMBER, ev, &"column")
	return t.get_value(&"fight_column")


func _on_beat(ev: Dictionary, t: RefCounted) -> float:
	_current_zone = ev.get("zone", _current_zone)
	_beat_t0 = _clock
	if _skipping:
		return 0.0
	_set_captions([])
	# kc-juice: one tick per beat, rising with the beat (beat_1..4, then the pitch keeps climbing).
	var beat_n: int = maxi(1, int(ev.get("beat", 1)))
	_sfx(StringName("beat_%d" % mini(beat_n, 4)), 1.0 + 0.06 * float(maxi(0, beat_n - 4)))
	var by_uid: Dictionary = {}
	for uid_v: Variant in ev.get("shooters", []):
		var uid: int = int(uid_v)
		var side: StringName = _side_of_uid(uid)
		by_uid[uid] = side
		_lift(uid, side)
	if overlay != null:
		overlay.set_shooters(by_uid)
	# The First Shot half of a split exchange: say why this one fires alone.
	if int(ev.get("exchange", 0)) == 1:
		for uid: int in by_uid:
			if _tagged_first_shot.has(uid):
				continue
			_tagged_first_shot[uid] = true
			var side2: StringName = by_uid[uid]
			_popup_at(_unit_point(uid, side2, _current_zone) + Vector2(0, -22.0), "FIRST SHOT", &"heading", 16,
					FxStyle.side_color(side2), ev, &"beat_tag")
	return t.get_value(&"fight_lift")


func _on_pierce(ev: Dictionary, _t: RefCounted) -> float:
	var side: StringName = ev.get("side", &"player")
	var zone: StringName = ev.get("zone", _current_zone)
	var src: int = int(ev.get("from_uid", -1))
	var target: int = int(ev.get("target_uid", -1))
	if target < 0:
		return 0.0
	unit_sides[target] = _other(side)
	_zone_of[target] = zone
	if int(ev.get("damage", 0)) > 0:
		_pierce_hit[target] = true
	if _skipping:
		return 0.0
	var from: Vector2 = _unit_point(src, _other(side), zone)
	var to: Vector2 = _unit_point(target, _other(side), zone)
	var dir: Vector2 = (to - from).normalized() if to != from else Vector2.UP
	var fx: Control = TracerFx.new()
	fx.from = from
	fx.to = to - dir * 6.0
	fx.width = 2.0
	fx.color = FxStyle.side_color(side)
	# It leaves when the shot it continues reaches its first target.
	fx.start_delay = maxf(0.0, float(_arrival.get(src, _clock)) - _clock)
	_start(fx, &"pierce_tracer", ev)
	_arrival[target] = maxf(float(_arrival.get(target, 0.0)), _clock + fx.arrival_time())
	return 0.0


func _on_column_ended(ev: Dictionary, t: RefCounted) -> float:
	_beat_t0 = -1.0
	var zone: StringName = ev.get("zone", _current_zone)
	if overlay != null:
		overlay.set_shooters({})
	var summary_now: bool = summary_only and not _hard_skip
	if _skipping and not summary_now:
		return 0.0
	var text: String = column_summary_text(_summary, zone)
	var why: String = no_losses_reason(_summary)
	var r: Rect2 = _zone_rect(zone)
	if r.has_area():
		var was: bool = _skipping
		_skipping = false  # FAST: the column result is the one thing shown
		_popup_at(_to_local(r.get_center()), text, &"heading", 18, FxStyle.FOG, ev, &"summary")
		_skipping = was
	# kc-r2-fixes (playtest r2 "Column C had no losses and I can't say why"): the log says why.
	_set_captions([text] if why == "" else [text, why])
	return SUMMARY_ONLY_BEAT if summary_now else t.get_value(&"fight_summary")


## "COLUMN A: 2 KILLS · 1 LOST" / "COLUMN C: NO LOSSES" for one column's summary.
static func column_summary_text(summary: Dictionary, zone: StringName) -> String:
	var kills: int = int(summary.get("kills", 0))
	var lost: int = int(summary.get("lost", 0))
	var parts: PackedStringArray = []
	if kills > 0:
		parts.append("%d %s" % [kills, "KILL" if kills == 1 else "KILLS"])
	if lost > 0:
		parts.append("%d LOST" % lost)
	return "COLUMN %s: %s" % [ZONE_LETTERS.get(zone, "?"), " · ".join(parts) if not parts.is_empty() else "NO LOSSES"]


## kc-r2-fixes: why a column ended with nobody eliminated (ScoreRace words it for the recap too).
static func no_losses_reason(summary: Dictionary) -> String:
	return ScoreRace.no_losses_reason(summary)


## Notes one shot in the column summary (for the "no losses" reason). Runs while skipping too.
func _note_shot(ev: Dictionary) -> void:
	if _summary.is_empty() or int(ev.get("target_uid", -1)) < 0:
		return
	_summary["shots"] = int(_summary.get("shots", 0)) + 1
	if int(ev.get("damage", 0)) <= 0:
		_summary["zero"] = int(_summary.get("zero", 0)) + 1
	var cover: int = int(ev.get("cover", 0))
	if cover > 0:
		_summary["covered"] = int(_summary.get("covered", 0)) + 1
		var from: Dictionary = _summary.get("cover_from", {})
		for n: Variant in ev.get("cover_from", []):
			from[String(n)] = true
		_summary["cover_from"] = from


func _set_captions(lines: Array) -> void:
	var out: Array[String] = []
	for l: Variant in lines:
		out.append(String(l))
	if out == captions:
		return
	captions = out
	set_meta(&"qa_caption", " / ".join(out))
	caption_changed.emit(out.duplicate())


## A rival card turned over at Reveal: one at a time, named ("Rival reveals Point Man: column B").
func _on_arrived(ev: Dictionary, t: RefCounted) -> float:
	if _skipping:
		return 0.0
	var uid: int = int(ev.get("uid", -1))
	var side: StringName = ev.get("side", &"")
	var letter: String = ZONE_LETTERS.get(StringName(ev.get("zone", &"")), "?")
	var nm: String = String(unit_names.get(uid, _display_name(ev.get("card_id", &""))))
	if side != viewer_side:
		_set_captions(["Rival reveals %s: column %s" % [nm, letter]])
		return t.get_value(&"reveal_rival")
	_set_captions(["%s arrives in column %s" % [nm, letter]])
	return t.get_value(&"reveal_own")


## One shot in plain words, from this SHOT_FIRED and what follows it in the same beat (the queue):
## "Gunner (A1) hits Rival Rifleman for 2 — destroyed; Pierce 1 into Rival Point Man".
func shot_caption(ev: Dictionary) -> String:
	var side: StringName = ev.get("side", &"player")
	var shooter: int = int(ev.get("shooter_uid", -1))
	var target: int = int(ev.get("target_uid", -1))
	var zone: StringName = ev.get("zone", _current_zone)
	var who: String = _caption_name(shooter, side)
	var row: int = _row_of(shooter)
	var at: String = "%s%s" % [ZONE_LETTERS.get(zone, ""), str(row + 1) if row >= 0 else ""]
	if target < 0:
		return "%s (%s) has no target" % [who, at]
	var dmg: int = int(ev.get("damage", 0))
	var text: String = "%s (%s) hits %s for %d" % [who, at, _caption_name(target, _other(side)), dmg]
	var dead: Dictionary = {}
	var held: Dictionary = {}
	var pierce: Array[String] = []
	for nx: Dictionary in _queue:
		var nt: StringName = nx.get("type", &"")
		if nt == RulesEvent.FIREFIGHT_BEAT or nt == RulesEvent.FIREFIGHT_COLUMN_ENDED:
			break
		if nt == RulesEvent.UNIT_ELIMINATED:
			dead[int(nx.get("victim_uid", -1))] = true
		elif nt == RulesEvent.SURVIVED_LETHAL:
			held[int(nx.get("uid", -1))] = true
		elif nt == RulesEvent.PIERCE_CARRIED and int(nx.get("shooter_uid", -1)) == shooter and int(nx.get("damage", 0)) > 0:
			pierce.append("%d|%d" % [int(nx.get("damage", 0)), int(nx.get("target_uid", -1))])
	# kc-r2-fixes: a hit softened by Cover names where the Cover comes from (Bulwark, a tactic...).
	var cov: int = int(ev.get("cover", _slot_entry(target).get("cover", 0)))
	var cov_from: PackedStringArray = []
	for n: Variant in ev.get("cover_from", []):
		if String(n) != "its own Cover":
			cov_from.append(String(n))
	var cov_note: String = ("Cover %d from %s" % [cov, " and ".join(cov_from)]) if cov > 0 and not cov_from.is_empty() \
			else ("Cover %d" % cov if cov > 0 else "")
	if dmg <= 0:
		text += (" — %s stops it" % cov_note) if cov > 0 else " — no damage"
	elif cov_note != "":
		text += " (%s)" % cov_note
	if dmg <= 0:
		pass
	elif dead.has(target):
		text += " — eliminated"
	elif held.has(target):
		text += " — it holds (Grit)"
	for p: String in pierce:
		var parts: PackedStringArray = p.split("|")
		var pu: int = int(parts[1])
		text += "; Pierce %s into %s%s" % [parts[0], _caption_name(pu, _other(side)), " — eliminated" if dead.has(pu) else ""]
	return text


func _caption_name(uid: int, side: StringName) -> String:
	var nm: String = String(unit_names.get(uid, "Unit"))
	return nm if side == viewer_side else "Rival " + nm


## The firefight is over (Score, the end of the sequence, or a skip): no dim, no outline, no pips.
func _end_fight() -> void:
	_unlift(true)
	_beat_t0 = -1.0
	if overlay != null:
		overlay.clear()


func _side_of_uid(uid: int) -> StringName:
	if unit_sides.has(uid):
		return StringName(unit_sides[uid])
	if locator != null and locator.has_method(&"find_slot"):
		var slot: Control = locator.find_slot(uid)
		if slot != null and "side" in slot:
			return StringName(slot.get(&"side"))
	return viewer_side


## Nudges a shooter's banner toward the enemy (the viewer's rows sit under the objective: up).
func _lift(uid: int, side: StringName) -> void:
	if reduced_motion or locator == null or not locator.has_method(&"find_slot"):
		return
	var slot: Control = locator.find_slot(uid)
	if slot == null or not "banner" in slot:
		return
	var b: Control = slot.get(&"banner") as Control
	if b == null:
		return
	# Leave a banner alone while the column still moves it (arrival / slide).
	if b.has_meta(&"motion"):
		var mt: Tween = b.get_meta(&"motion") as Tween
		if mt != null and mt.is_valid() and mt.is_running():
			return
	var dy: float = -LIFT_PX if side == viewer_side else LIFT_PX
	var tw: Tween = b.create_tween()
	tw.tween_property(b, "position:y", dy, maxf(0.05, _timing.get_value(&"fight_lift") * 0.7)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	b.set_meta(&"lift", tw)
	_lifted[uid] = b


## Puts lifted banners back: at once (snap) or with a short ease.
func _unlift(snap: bool) -> void:
	for uid: Variant in _lifted.keys():
		var b: Control = _lifted[uid] as Control
		if b == null or not is_instance_valid(b):
			continue
		if b.has_meta(&"lift"):
			var old: Tween = b.get_meta(&"lift") as Tween
			if old != null and old.is_valid():
				old.kill()
			b.remove_meta(&"lift")
		if snap or reduced_motion:
			b.position.y = 0.0
		else:
			var tw: Tween = b.create_tween()
			tw.tween_property(b, "position:y", 0.0, 0.1)
			b.set_meta(&"lift", tw)
	# Settling banners stay listed so a snap (before the board refreshes) can stop their ease.
	if snap:
		_lifted.clear()


## Uids whose banners are lifted right now (tests).
func lifted_uids() -> Array:
	return _lifted.keys()


# --- effect helpers -------------------------------------------------------------------------

func _start(fx: Control, kind: StringName, ev: Dictionary) -> void:
	fx.add_to_group(GROUP_TRANSIENT)
	add_child(fx)
	# Keep the killstreak banner and markers on top of everything else.
	if ks != null:
		move_child(ks, get_child_count() - 1)
	fx.play(_timing)
	_log(kind, fx, fx.duration, ev)


func _number(uid: int, text: String, color: Color, big: bool, ev: Dictionary, font_px: int = 0) -> void:
	if _skipping:
		return
	var rect: Rect2 = _unit_rect_local(uid, _side_of_target(ev))
	var n: int = int(_hit_count.get(uid, 0))
	_hit_count[uid] = n + 1
	var fx: Control = FloatTextFx.new()
	fx.setup(text, &"numeric", font_px if font_px > 0 else (30 if big else 26), color, &"damage_number")
	fx.anchor = rect.get_center() + Vector2(rect.size.x * 0.22 + n * 6.0, -rect.size.y * 0.18 - n * 14.0)
	fx.rise_key = &"damage_rise"
	fx.duration_key = &"fight_number" if _beat_t0 >= 0.0 else &"damage_number"
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


## kc-juice: the hit-stop of an elimination, by importance (see the header).
static func hitstop_key(ev: Dictionary) -> StringName:
	if bool(ev.get("is_operator", false)):
		return &"hitstop_big"
	if bool(ev.get("by_killstreak", false)):
		return &"hitstop_mid"
	return &"hitstop"


func _hitstop(sec: float, ev: Dictionary) -> void:
	if sec <= 0.0 or _skipping or _hitstop_on or not hitstop_enabled:
		return
	_hitstop_on = true
	process_mode = Node.PROCESS_MODE_DISABLED
	_log(&"hitstop", null, sec, ev)
	# kc-juice: the timer follows Engine.time_scale, so at SPEED x2 the freeze is as short as the rest.
	get_tree().create_timer(sec, true, false, false).timeout.connect(_end_hitstop)


func _end_hitstop() -> void:
	if not _hitstop_on:
		return
	_hitstop_on = false
	process_mode = Node.PROCESS_MODE_INHERIT


## kc-juice: dir (screen space, the shot's direction) makes the shake a recoil along it: the canvas
## kicks that way and springs back, with a little sideways jitter. No dir: a random jitter. Never
## more than FxTiming.SHAKE_CAP_PX, whatever is asked.
func _shake(px: float, sec: float, ev: Dictionary, dir: Vector2 = Vector2.ZERO) -> void:
	px = minf(px, FxTiming.SHAKE_CAP_PX)
	if px <= 0.0 or sec <= 0.0 or _skipping:
		return
	var vp: Viewport = get_viewport()
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	else:
		_shake_base = vp.canvas_transform
	var d: Vector2 = dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	_shake_tween = create_tween()
	_shake_tween.tween_method(func(k: float) -> void:
		var off: Vector2 = shake_offset(px, k, d, randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		vp.canvas_transform = Transform2D(0.0, _shake_base.origin + off.round()), 0.0, 1.0, sec)
	_shake_tween.finished.connect(_stop_shake)
	_log(&"shake", null, sec, ev)
	set_meta(&"last_shake", {"px": px, "dir": d})


## The shake offset at progress k (0..1) for a peak of px; r1, r2 in -1..1 (the jitter). Its length
## never exceeds px. dir = ZERO: a random jitter; else a recoil along dir (1.5 swings, decaying)
## with a sideways jitter of at most 25%.
static func shake_offset(px: float, k: float, dir: Vector2, r1: float, r2: float) -> Vector2:
	var amp: float = px * (1.0 - k) * (1.0 - k)
	if dir == Vector2.ZERO:
		return Vector2(r1, r2) * amp * 0.7071
	var along: float = cos(k * TAU * 1.5) * amp * 0.96
	return dir * along + dir.orthogonal() * r1 * amp * 0.25


func _stop_shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		get_viewport().canvas_transform = _shake_base
	elif _shake_tween != null:
		get_viewport().canvas_transform = _shake_base
	_shake_tween = null


## kc-juice: a sound cue (not while skipping). Logged in sfx_log, played by the SFX bank if any.
func _sfx(id: StringName, pitch: float = 1.0, db: float = 0.0) -> void:
	if _skipping:
		return
	sfx_log.append(id)
	SfxBank.cue(id, pitch, db)


## kc-juice: the column-win flourish over `local_rect` (overlay px). Logged as &"column_win".
func _column_flourish(local_rect: Rect2, ev: Dictionary) -> void:
	if _skipping:
		return
	_sfx(&"column_win")
	var fx: Control = ColumnFlourishFx.new()
	fx.rect = local_rect
	fx.color = FxStyle.side_color(viewer_side)
	_start(fx, &"column_win", ev)


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
		icon = KillstreakFx.look(by_id)["icon"]
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
		screen_shake = s.shake_on
	return FxTiming.create(fast, reduced_motion, screen_shake)
