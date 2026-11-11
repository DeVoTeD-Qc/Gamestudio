# test_fx_director.gd
# Purpose: FeedbackDirector (p14): engine events -> the expected effects start, in order;
#   fast animations shorten durations; reduced motion drops shake / hit-stop; private events
#   are hidden; skip() fast-forwards; Killfeed caps its lines; StreakArc shatters on reset.
# Author: Game Feel Engineer Agent (p14)
extends "res://tests/test_case.gd"

const DirectorScene: PackedScene = preload("res://scenes/fx/FeedbackDirector.tscn")
const KillfeedScene: PackedScene = preload("res://scenes/fx/Killfeed.tscn")
const StreakArcScene: PackedScene = preload("res://scenes/fx/StreakArc.tscn")
const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")

var _root: Control
var _director: Control


## A locator with fixed slot rects: player units y=500, enemy units y=200.
class FakeLocator:
	extends RefCounted
	var rects: Dictionary = {
		1: Rect2(100, 460, 80, 80), 2: Rect2(500, 460, 80, 80),
		11: Rect2(100, 160, 80, 80), 12: Rect2(500, 160, 80, 80),
	}

	func unit_rect(uid: int) -> Rect2:
		return rects.get(uid, Rect2())

	func zone_rect(_zone: StringName) -> Rect2:
		return Rect2(0, 100, 400, 500)

	func anchor_rect(_name: StringName) -> Rect2:
		return Rect2(20, 10, 300, 60)


func _setup(fast: bool = false, reduced: bool = false) -> void:
	_root = Control.new()
	_root.size = Vector2(1280, 720)
	tree.root.add_child(_root)
	_director = DirectorScene.instantiate()
	_director.use_settings = false
	_director.fast = fast
	_director.reduced_motion = reduced
	_root.add_child(_director)
	var feed: Control = KillfeedScene.instantiate()
	_root.add_child(feed)
	feed.set_anchors_preset(Control.PRESET_TOP_LEFT)
	feed.size = Vector2(400, 72)
	_director.killfeed = feed
	var arc: Control = StreakArcScene.instantiate()
	_root.add_child(arc)
	arc.position = Vector2(40, 600)
	arc.size = Vector2(140, 34)
	arc.configure(5, [2, 3, 5], 1)
	_director.streak_arc = arc
	_director.locator = FakeLocator.new()


func _teardown() -> void:
	if _director != null and _director.is_playing():
		_director.skip()
	_root.queue_free()
	await tree.process_frame


func _ev(type: StringName, fields: Dictionary) -> Dictionary:
	return RulesEvent.make(type, 3, fields)


func _firefight() -> Array:
	return [
		_ev(RulesEvent.FIREFIGHT_STARTED, {"zone": &"mid"}),
		_ev(RulesEvent.SHOT_FIRED, {"side": &"player", "shooter_uid": 1, "target_uid": 11, "zone": &"mid", "damage": 3, "step": &"main"}),
		_ev(RulesEvent.SHOT_FIRED, {"side": &"enemy", "shooter_uid": 11, "target_uid": 1, "zone": &"mid", "damage": 2, "step": &"main"}),
		_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 11, "side": &"enemy", "amount": 3, "remaining": 0, "source_id": &"rifleman"}),
		_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 1, "side": &"player", "amount": 2, "remaining": 1, "source_id": &"marksman"}),
		_ev(RulesEvent.UNIT_ELIMINATED, {"victim_uid": 11, "victim_side": &"enemy", "victim_id": &"marksman", "is_operator": false,
				"by_uid": 1, "by_side": &"player", "by_id": &"rifleman", "zone": &"mid", "source_kind": &"unit",
				"by_killstreak": false, "credit": true}),
	]


func _count(kinds: Array[StringName], kind: StringName) -> int:
	var n: int = 0
	for k: StringName in kinds:
		if k == kind:
			n += 1
	return n


func test_firefight_events_start_expected_effects_in_order() -> void:
	_setup()
	var feed: Control = _director.killfeed
	await _director.play(_firefight())
	var kinds: Array[StringName] = _director.logged_kinds()
	assert_eq(_count(kinds, &"tracer"), 2, "one tracer per shot")
	assert_eq(_count(kinds, &"hit_marker"), 2, "one hit marker per damage event")
	assert_eq(_count(kinds, &"damage_number"), 2, "one damage number per damage event")
	assert_eq(_count(kinds, &"stamp"), 1, "ELIMINATED stamp")
	assert_eq(_count(kinds, &"killfeed"), 1, "one killfeed line")
	assert_eq(_count(kinds, &"popup"), 1, "+100 ELIMINATION pop-up for the player's kill")
	assert_eq(_count(kinds, &"hitstop"), 1, "hit-stop on the elimination")
	assert_eq(_count(kinds, &"shake"), 1, "screen shake on the elimination")
	assert_true(kinds.find(&"tracer") < kinds.find(&"hit_marker"), "tracers start before hit markers")
	assert_true(kinds.find(&"hit_marker") < kinds.find(&"stamp"), "hits land before the stamp")
	assert_eq(feed.get_entries().size(), 1, "killfeed shows the line")
	var line: Control = feed.get_entries()[0]
	assert_eq(String(line.entry["victim"]), "Marksman", "killfeed victim name from CardDB")
	assert_eq(line.entry["attacker_side"], &"player", "attacker side")
	assert_eq(tree.root.canvas_transform, Transform2D.IDENTITY, "shake restores the canvas")
	await _teardown()


func test_fast_animations_setting_halves_durations() -> void:
	var settings: Node = tree.root.get_node("Settings")
	assert_true("reduced_motion" in settings, "Settings has reduced_motion")
	var was_fast: bool = settings.fast_animations
	var durations: Array[Dictionary] = []
	for fast: bool in [false, true]:
		settings.set_value(&"fast_animations", fast)
		_setup()
		_director.use_settings = true
		await _director.play(_firefight() + [
			_ev(RulesEvent.ITEM_REVEALED, {"side": &"enemy", "item_id": &"mortar_barrage", "zone": &"left"}),
			_ev(RulesEvent.KILLSTREAK_STRIKE, {"side": &"enemy", "item_id": &"mortar_barrage", "zone": &"left", "zones": [&"left"], "pass": 1, "passes": 1}),
		])
		var d: Dictionary = {}
		for kind: StringName in [&"tracer", &"hit_marker", &"damage_number", &"stamp", &"killfeed", &"ks_banner", &"shells", &"shake", &"hitstop"]:
			d[kind] = _director.logged_duration(kind)
		assert_eq(_director.fast, fast, "director read fast_animations from Settings")
		durations.append(d)
		await _teardown()
	settings.set_value(&"fast_animations", was_fast)
	for kind: StringName in durations[0]:
		var normal: float = durations[0][kind]
		var quick: float = durations[1][kind]
		assert_true(normal > 0.0, "%s ran at normal speed" % kind)
		assert_true(absf(quick - normal * FxTiming.FAST_SCALE) < 0.001,
				"%s: fast %.3f should be half of %.3f" % [kind, quick, normal])
	assert_true(absf(float(durations[0][&"ks_banner"]) - 1.7) < 0.001, "kc-ks-seq: the compact banner stays 1.7 s")


func test_reduced_motion_drops_shake_and_hitstop_but_keeps_feedback() -> void:
	_setup(false, true)
	await _director.play(_firefight())
	var kinds: Array[StringName] = _director.logged_kinds()
	assert_eq(_count(kinds, &"shake"), 0, "no shake with reduced motion")
	assert_eq(_count(kinds, &"hitstop"), 0, "no hit-stop with reduced motion")
	assert_eq(_count(kinds, &"stamp"), 1, "stamp still shown")
	assert_eq(_count(kinds, &"killfeed"), 1, "killfeed still shown")
	var t: RefCounted = FxTiming.create(false, true)
	assert_eq(t.get_value(&"popup_rise"), 0.0, "pop-ups do not travel")
	assert_true(t.get_value(&"stamp") > 0.0, "durations are kept")
	await _teardown()


func test_private_events_of_the_other_side_are_skipped() -> void:
	_setup(true)
	var seen: Array = []
	_director.event_started.connect(func(ev: Dictionary) -> void: seen.append(ev["type"]))
	await _director.play([
		_ev(RulesEvent.ITEM_USED, {"side": &"enemy", "item_id": &"attack_helo", "zone": &"mid", "private_to": &"enemy"}),
		_ev(RulesEvent.ITEM_USED, {"side": &"player", "item_id": &"recon_drone", "zone": &"left", "private_to": &"player"}),
	])
	assert_eq(seen.size(), 1, "only the viewer's private event plays")
	assert_eq(_director.logged_kinds(), [&"ks_banner", &"scan"] as Array[StringName], "own Recon Drone: CALLED IN banner + scan")
	assert_eq(_director.ks.last_banner.get("mode"), &"called", "called-in banner")
	await _teardown()


func test_killstreak_reveal_plays_its_banner_and_other_items_do_not() -> void:
	_setup(true)
	var ks: Control = _director.ks
	_director.play([
		_ev(RulesEvent.ITEM_REVEALED, {"side": &"player", "item_id": &"some_item", "zone": &"mid"}),
		_ev(RulesEvent.ITEM_REVEALED, {"side": &"enemy", "item_id": &"mortar_barrage", "zone": &"left"}),
	])
	assert_eq(_director.logged_kinds(), [&"tag"] as Array[StringName], "a non-killstreak item: name tag only")
	await _director.sequence_finished
	assert_eq(_director.logged_kinds(), [&"tag", &"ks_banner"] as Array[StringName], "mortar: its compact banner, no takeover")
	assert_true(String(ks.last_banner.get("name", "")).to_lower().contains("mortar"), "the banner names the killstreak")
	assert_eq(ks.last_banner.get("mode"), &"revealed", "a rival killstreak is HOSTILE")
	assert_true(ks.banner.size.y <= 56.0, "compact: one strip, not a full-screen band")
	await _teardown()


func test_streak_rises_then_shatters_on_reset() -> void:
	_setup(true)
	var arc: Control = _director.streak_arc
	await _director.play([
		_ev(RulesEvent.STREAK_CHANGED, {"side": &"player", "streak": 3, "before": 1, "gained": 2, "reset": false, "earned": [&"recon_drone"]}),
	])
	assert_eq(arc.streak, 3, "arc shows streak 3")
	assert_true(arc.is_threshold_lit(2) and arc.is_threshold_lit(3), "notches 2 and 3 lit")
	assert_false(arc.is_threshold_lit(5), "notch 5 not lit")
	var shattered: Array = [false]
	arc.shattered.connect(func() -> void: shattered[0] = true)
	_director.play([
		_ev(RulesEvent.STREAK_CHANGED, {"side": &"player", "streak": 0, "before": 3, "gained": 1, "reset": true, "earned": []}),
	])
	assert_true(_director.logged_kinds().has(&"shatter"), "reset logs a shatter")
	await _director.sequence_finished
	for i: int in 10:  # the shatter tween may end a frame after the director's beat
		if shattered[0]:
			break
		await tree.process_frame
	assert_true(shattered[0], "arc emitted shattered")
	assert_eq(arc.streak, 0, "arc empty after the reset")
	assert_eq(arc.shard_count(), 0, "shards cleaned up")
	# The enemy's streak never drives the player's arc.
	await _director.play([_ev(RulesEvent.STREAK_CHANGED, {"side": &"enemy", "streak": 4, "before": 2, "gained": 2, "reset": false, "earned": []})])
	assert_eq(arc.streak, 0, "enemy streak ignored")
	await _teardown()


func test_skip_fast_forwards_and_keeps_persistent_state() -> void:
	_setup()
	var events: Array = _firefight()
	events.append(_ev(RulesEvent.STREAK_CHANGED, {"side": &"player", "streak": 2, "before": 1, "gained": 1, "reset": false, "earned": []}))
	var done: Array = [false]
	_director.sequence_finished.connect(func() -> void: done[0] = true)
	_director.play(events)
	await tree.process_frame
	var start: int = Time.get_ticks_msec()
	_director.skip()
	for i: int in 5:
		if done[0]:
			break
		await tree.process_frame
	assert_true(done[0], "sequence finished right after skip()")
	assert_true(Time.get_ticks_msec() - start < 500, "skip does not wait out the beats")
	assert_eq(_director.killfeed.get_entries().size(), 1, "killfeed line still added when skipping")
	assert_eq(_director.streak_arc.streak, 2, "streak still updated when skipping")
	await tree.process_frame
	assert_eq(tree.get_nodes_in_group(&"fx_transient").size(), 0, "no transient effects left")
	assert_eq(tree.root.canvas_transform, Transform2D.IDENTITY, "canvas restored")
	assert_eq(_director.process_mode, Node.PROCESS_MODE_INHERIT, "hit-stop released")
	await _teardown()


func test_killfeed_caps_lines_to_its_height() -> void:
	_setup()
	var feed: Control = _director.killfeed
	for i: int in 5:
		feed.push({"attacker": "A%d" % i, "attacker_side": &"player", "victim": "V", "victim_side": &"enemy", "zone": &"mid"})
	await tree.process_frame
	assert_eq(feed.get_entries().size(), 3, "72 px feed keeps 3 lines")
	assert_eq(String(feed.get_entries()[2].entry["attacker"]), "A4", "newest line at the bottom")
	feed.size = Vector2(400, 50)
	feed.push({"attacker": "B", "attacker_side": &"enemy", "victim": "V", "victim_side": &"player"})
	await tree.process_frame
	assert_eq(feed.get_entries().size(), 2, "compact 50-64 px feed keeps 2 lines")
	await _teardown()


func test_fx_timing_table() -> void:
	var normal: RefCounted = FxTiming.create(false, false)
	var fast: RefCounted = FxTiming.create(true, false)
	assert_eq(normal.get_value(&"shot_stagger"), 0.06, "60 ms tracer stagger")
	assert_eq(fast.get_value(&"feed_life"), 2.0, "killfeed life halves")
	assert_eq(fast.get_value(&"shake_px"), 3.0, "distances are not scaled")
	assert_true(normal.get_value(&"shake_px") >= 2.0 and normal.get_value(&"shake_px_big") <= 4.0, "shake 2-4 px")


# --- kc-ks-seq: per-killstreak sequences ------------------------------------------------------

func _mortar_round() -> Array:
	return [
		_ev(RulesEvent.ITEM_REVEALED, {"side": &"player", "item_id": &"mortar_barrage", "zone": &"mid"}),
		_ev(RulesEvent.KILLSTREAK_QUEUED, {"side": &"player", "item_id": &"mortar_barrage", "zone": &"mid", "zones": [&"mid"], "fights": 1, "resolves": &"firefight"}),
		_ev(RulesEvent.PHASE_CHANGED, {"phase": &"firefight"}),
		_ev(RulesEvent.KILLSTREAK_STRIKE, {"side": &"player", "item_id": &"mortar_barrage", "zone": &"mid", "zones": [&"mid"], "pass": 1, "passes": 1}),
		_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 11, "side": &"enemy", "amount": 2, "remaining": 0, "source_id": &"mortar_barrage"}),
		_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 12, "side": &"enemy", "amount": 2, "remaining": 2, "source_id": &"mortar_barrage"}),
		_ev(RulesEvent.UNIT_ELIMINATED, {"victim_uid": 11, "victim_side": &"enemy", "victim_id": &"rifleman", "is_operator": false,
				"by_uid": -1, "by_side": &"player", "by_id": &"mortar_barrage", "zone": &"mid", "source_kind": &"killstreak",
				"by_killstreak": true, "credit": true}),
		_ev(RulesEvent.KILLSTREAK_RESOLVED, {"side": &"player", "item_id": &"mortar_barrage", "zone": &"mid", "zones": [&"mid"],
				"pass": 1, "passes": 1, "kills": [11], "hits": [
					{"uid": 11, "side": &"enemy", "amount": 2, "remaining": 0, "name": "Rifleman"},
					{"uid": 12, "side": &"enemy", "amount": 2, "remaining": 2, "name": "Gunner"}]}),
	]


func test_mortar_marks_its_column_then_strikes_with_numbers_on_impact() -> void:
	_setup(true)
	var ks: Control = _director.ks
	var events: Array = _mortar_round()
	var marked_at_strike: Array = []
	var number_t: Array = []
	var strike_t: Array = [0.0]
	var captions_seen: Array = []
	_director.caption_changed.connect(func(lines: Array) -> void: captions_seen.append_array(lines))
	_director.event_started.connect(func(ev: Dictionary) -> void:
		if ev["type"] == RulesEvent.KILLSTREAK_STRIKE:
			marked_at_strike.append(ks.pending_keys().size())
			strike_t[0] = Time.get_ticks_msec() / 1000.0)
	_director.fx_started.connect(func(kind: StringName, _n: Object, _d: float) -> void:
		if kind == &"damage_number":
			number_t.append(Time.get_ticks_msec() / 1000.0 - strike_t[0]))
	await _director.play(events)
	var kinds: Array[StringName] = _director.logged_kinds()
	assert_true(kinds.has(&"ks_queued"), "INCOMING marker when queued")
	assert_eq(marked_at_strike, [1], "the marker stood until the strike")
	assert_eq(ks.pending_keys().size(), 0, "and went away with it")
	assert_true(kinds.find(&"shells") >= 0 and kinds.find(&"shells") < kinds.find(&"damage_number"), "shells before the numbers")
	assert_eq(_count(kinds, &"damage_number"), 2, "a number on each hit unit")
	assert_true(number_t.size() == 2 and float(number_t[0]) > 0.2, "numbers wait for the shells (%s)" % str(number_t))
	assert_false(kinds.has(&"takeover"), "no full-screen takeover")
	var feed: Control = _director.killfeed
	var lines: Array = feed.get_entries().map(func(l: Control) -> String: return "%s > %s" % [l.entry["attacker"], l.entry["victim"]])
	assert_true(lines.has("Mortar Barrage > 2 HIT · 1 DOWN"), "killfeed summary: %s" % str(lines))
	assert_eq(_director.ks_line(events[-1]), "Mortar Barrage hit column B: Rifleman −2 (down), Gunner −2", "the plain log line")
	assert_true(captions_seen.has("Mortar Barrage hit column B: Rifleman −2 (down), Gunner −2"), "and it is the caption: %s" % str(captions_seen))
	await _teardown()


func test_each_killstreak_has_its_own_look() -> void:
	# kc-da-ui: the kind is told by its icon and sequence; the colour is the owner's (one per side).
	var seqs: Dictionary = {}
	var icons: Dictionary = {}
	var colors: Dictionary = {}
	for id: StringName in [&"recon_drone", &"mortar_barrage", &"sentry_turret", &"attack_helo"]:
		var look: Dictionary = KillstreakFx.look(id)
		seqs[look["seq"]] = true
		icons[look["icon"]] = true
		colors[KillstreakFx.color_of(id, &"enemy", &"player").to_html()] = true
		assert_true(IconSheet.has_icon(look["icon"]), "%s has its icon" % id)
		assert_true(String(look["effect"]) != "" and String(look["when"]) != "", "%s says what and when" % id)
	assert_eq(seqs.size(), 4, "four different sequences")
	assert_eq(icons.size(), 4, "four different icons")
	assert_eq(colors.size(), 1, "one colour per owner")


func test_helo_strafe_and_sentry_drop_and_reduced_motion_banner() -> void:
	_setup(true, true)
	await _director.play([
		_ev(RulesEvent.ITEM_REVEALED, {"side": &"enemy", "item_id": &"sentry_turret", "zone": &"mid"}),
		_ev(RulesEvent.KILLSTREAK_STRIKE, {"side": &"enemy", "item_id": &"attack_helo", "zone": &"", "zones": [&"left", &"mid", &"right"], "pass": 2, "passes": 2}),
		_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 1, "side": &"player", "amount": 2, "remaining": 3, "source_id": &"attack_helo"}),
		_ev(RulesEvent.KILLSTREAK_RESOLVED, {"side": &"enemy", "item_id": &"attack_helo", "zone": &"", "zones": [&"left", &"mid", &"right"],
				"pass": 2, "passes": 2, "kills": [], "hits": [{"uid": 1, "side": &"player", "amount": 2, "remaining": 3, "name": "Rifleman", "zone": &"left"}]}),
	])
	var kinds: Array[StringName] = _director.logged_kinds()
	assert_true(kinds.has(&"drop"), "the Sentry drops in")
	assert_true(kinds.has(&"strafe"), "the helo strafes")
	assert_true(kinds.has(&"ks_banner"), "the rival's Sentry gets a HOSTILE banner")
	assert_eq(_director.ks.banner.position.y, 6.0, "reduced motion: the banner fades in place, no slide")
	await _teardown()


func test_pending_markers_follow_the_snapshot_and_are_inspectable() -> void:
	_setup(true)
	var ks: Control = _director.ks
	_director.set_pending_strikes([{"item_id": &"attack_helo", "side": &"enemy", "zones": [&"left", &"mid", &"right"], "label": "AT FIGHT"}])
	assert_eq(ks.pending_keys().size(), 3, "a helo marks every column")
	var got: Array = []
	ks.inspect_requested.connect(func(id: StringName, side: StringName) -> void: got.append([id, side]))
	var chip: Control = (ks.markers.values()[0] as Control).get(&"chip")
	assert_true(chip != null and chip.mouse_filter == Control.MOUSE_FILTER_STOP, "the chip takes input")
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	chip.gui_input.emit(right)
	assert_eq(got, [[&"attack_helo", &"enemy"]], "right click inspects it")
	_director.set_pending_strikes([])
	await tree.process_frame
	assert_eq(ks.pending_keys().size(), 0, "cleared with the snapshot")
	await _teardown()


## kc-ks-pop (head S2): a strike's kill shows "MORTAR KILL" in the mortar's colour, inspectable, and no
## "+100 ELIMINATION"; a normal kill keeps the +100.
func test_strike_kill_shows_its_own_inspectable_popup() -> void:
	_setup(true)
	var ks: Control = _director.ks
	var tags: Array = []
	_director.fx_started.connect(func(kind: StringName, node: Object, _d: float) -> void:
		if kind == &"ks_kill":
			tags.append(node))
	_director.play(_mortar_round())
	while tags.is_empty() and _director.is_playing():
		await tree.process_frame
	assert_eq(tags.size(), 1, "one strike kill tag")
	var tag: Control = tags[0]
	assert_eq(String(tag.get_meta(&"text")), "MORTAR KILL", "names the streak")
	assert_eq(tag.mouse_filter, Control.MOUSE_FILTER_STOP, "inspectable")
	var got: Array = []
	ks.inspect_requested.connect(func(id: StringName, side: StringName) -> void: got.append([id, side]))
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	tag.gui_input.emit(right)
	assert_eq(got, [[&"mortar_barrage", &"player"]], "right click opens the mortar's rules")
	await _director.sequence_finished
	var kinds: Array[StringName] = _director.logged_kinds()
	assert_eq(_count(kinds, &"popup"), 0, "no +100 ELIMINATION for a strike kill")
	assert_eq(_count(kinds, &"streak"), 0, "no streak tick")
	assert_eq(_count(kinds, &"killfeed"), 2, "the kill line and the strike's line stay")
	# kc-da-ui: killstreaks are coloured by owner (teal yours, red the rival's), never per kind.
	assert_eq(KillstreakFx.color_of(&"mortar_barrage", &"player", &"player"), Color("#2EC4B6"), "your mortar is teal")
	assert_eq(KillstreakFx.color_of(&"mortar_barrage", &"enemy", &"player"), Color("#E5383B"), "the rival's mortar is red")
	assert_eq(KillstreakFx.color_of(&"attack_helo", &"enemy", &"player"), KillstreakFx.color_of(&"mortar_barrage", &"enemy", &"player"),
			"one colour for every kind of the same owner")
	for id: StringName in KillstreakFx.LOOKS:
		assert_false((KillstreakFx.LOOKS[id] as Dictionary).has("color"), "%s has no per-kind hue" % id)
	await _teardown()
	_setup(true)
	await _director.play(_firefight())
	assert_eq(_count(_director.logged_kinds(), &"popup"), 1, "a normal kill keeps +100 ELIMINATION")
	assert_eq(_count(_director.logged_kinds(), &"ks_kill"), 0, "and no strike tag")
	await _teardown()
