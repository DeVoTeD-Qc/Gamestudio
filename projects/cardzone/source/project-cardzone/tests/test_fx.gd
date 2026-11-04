# test_fx.gd
# Purpose: cz17 looting and shooting feel (scripts/fx), on the real match screen at phone size:
#   - the timing table: fast animations halve the beats (with floors), reduced motion removes
#     travel / shake, loot pops grow with rarity, every beat is short (<= 1.1 s at normal speed);
#   - the placeholder sfx synthesise; the FAST ANIMATIONS toggle persists and follows Event speed
#     until set;
#   - every beat starts from its rules event (tracer + hit marker, Hit slam, Brace burn, loot pop,
#     supply drop, gas sweep, Down pulse, Bounty heal, elimination stamp, move mark) and a tap ends
#     them all (ghosts freed, hidden strip cards shown again);
#   - pacing: at a real Event speed the controller waits on the FX through hold_playback (never past
#     MAX_HOLD_S), SKIP on the playback panel skips the FX too, and delay 0 never holds;
#   - reduced motion: the tracer is drawn whole, nothing falls or shakes, no particles.
# Author: Game Feel Engineer Agent (cz17)
extends "res://tests/test_match_flow_kit.gd"

const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const FxSfx: GDScript = preload("res://scripts/fx/fx_sfx.gd")
const FxSettings: GDScript = preload("res://scripts/fx/fx_settings.gd")
const SetupPrefs: GDScript = preload("res://scripts/ui/setup_prefs.gd")

const ALL_BEATS: Array[StringName] = [&"shot", &"frag", &"slam", &"down", &"burn", &"loot", &"drop", &"gas",
		&"heal", &"stamp", &"move"]


## A scripted rival: plays its non-Hit cards, walks to Rail Yard, loots there, ends the turn.
class Walker extends RefCounted:
	var kind: String = "Walker"

	func choose_action(state: MatchState, seat: int) -> Dictionary:
		var legal: Array[Dictionary] = LoadoutRules.legal_actions(state)
		for t: String in ["brace", "play", "move", "loot"]:
			for a: Dictionary in legal:
				if a["type"] != t or int(a.get("seat", -1)) != seat:
					continue
				if t == "play" and a.has("adrenaline"):
					continue
				if t == "move" and String(a["to"]) != "rail_yard":
					continue
				return a
		for a: Dictionary in legal:
			if a["type"] == "end_turn" and int(a["seat"]) == seat and (a["hold"] as Array).is_empty():
				return a
		return legal[0] if not legal.is_empty() else {}


func _walk_fixture() -> MatchState:
	return _fixture({
		"P1": {"area": "motel", "health": 5, "hand": ["scavenge", "duck"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]},
		"P2": {"area": "docks", "health": 5, "loadout": ["dash", "scavenge", "scavenge", "medkit", "duck", "plate_vest", "dash"]}})


func _fx(m: Control) -> CzMatchFx:
	return m.get_node("%FX") as CzMatchFx


func _card_of_rarity(letter: String) -> StringName:
	for c: CardData in CardDB.all_cards():
		if c.rarity_letter() == letter and not c.is_hit():
			return c.id
	return &""


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


# --- Table, sfx, toggle ------------------------------------------------------------------------

func test_timing_table_options_and_rarity() -> void:
	var normal: RefCounted = FxTiming.create(false, false)
	var fast: RefCounted = FxTiming.create(true, false)
	var calm: RefCounted = FxTiming.create(false, true)
	for k: StringName in [&"shot", &"frag", &"slam", &"burn", &"drop", &"gas", &"down", &"heal", &"stamp", &"move"]:
		var n: float = normal.beat_length(k)
		assert_true(n > 0.0 and n <= 1.1, "%s lasts %.2f s at normal speed (0 < t <= 1.1)" % [k, n])
		assert_true(fast.beat_length(k) < n, "fast animations shorten %s (%.2f < %.2f)" % [k, fast.beat_length(k), n])
	assert_eq(fast.get_value(&"marker_hold"), 0.12, "fast keeps the marker's floor")
	assert_eq(fast.get_value(&"slam_px"), normal.get_value(&"slam_px"), "distances are not scaled by fast")
	for k: StringName in FxTiming.MOTION_ONLY:
		assert_eq(calm.get_value(k), 0.0, "reduced motion removes %s" % k)
	assert_true(calm.get_value(&"marker_hold") > 0.0 and calm.get_value(&"burn") > 0.0, "reduced motion keeps colour / text beats")
	var last: float = 0.0
	for r: StringName in [&"C", &"U", &"R", &"E", &"L"]:
		var v: float = normal.loot_total(r)
		assert_true(v > last, "loot pop of %s (%.2f s) longer than the rarity below" % [r, v])
		last = v
		assert_true(float(FxTiming.LOOT_SCALE[r]) >= float(FxTiming.LOOT_SCALE[&"C"]), "pop scale grows with rarity")
	assert_true(int(FxTiming.LOOT_FLECKS[&"L"]) > int(FxTiming.LOOT_FLECKS[&"R"]), "more flecks for Legendary")
	# Slides are 120-180 ms (art direction: short, mechanical, no bounce).
	for k: StringName in [&"tracer", &"slam_fall", &"loot_in", &"loot_fly", &"stamp_in", &"drop_fall"]:
		var v2: float = normal.get_value(k)
		assert_true(v2 >= 0.12 and v2 <= 0.18, "%s slide %.2f s within 0.12-0.18" % [k, v2])


func test_sfx_synthesise_and_play() -> void:
	for id: StringName in FxSfx.IDS:
		var s: AudioStreamWAV = FxSfx.stream(id) as AudioStreamWAV
		assert_true(s != null and s.data.size() > 1000, "%s synthesised (%d bytes)" % [id, s.data.size() if s != null else 0])
		var want: int = int(float(FxSfx.LENGTH[id]) * FxSfx.RATE) * 2
		assert_eq(s.data.size(), want, "%s is %.2f s" % [id, FxSfx.LENGTH[id]])
	var sfx: Node = FxSfx.new()
	tree.root.add_child(sfx)
	sfx.play(&"shot")
	sfx.play(&"loot", 1.2)
	assert_eq(sfx.history, [&"shot", &"loot"] as Array[StringName], "history records the sounds")
	sfx.queue_free()


func test_fast_animations_toggle() -> void:
	SetupPrefs.reset_all()
	var settings: Node = tree.root.get_node("Settings")
	var was: bool = settings.fast_animations
	settings.fast_animations = true
	assert_true(FxSettings.fast_animations(), "unset: follows Settings.fast_animations (Event speed)")
	settings.fast_animations = false
	assert_false(FxSettings.fast_animations(), "unset: off with normal Event speed")
	assert_false(FxSettings.is_set(), "nothing saved yet")
	FxSettings.set_fast_animations(true)
	settings.fast_animations = false  # e.g. Event speed back to normal
	assert_true(FxSettings.fast_animations(), "the player's choice wins")
	assert_true(FxTiming.from_settings().fast, "FX timing reads the toggle")
	assert_eq(SetupPrefs.get_value("settings", "fast_animations"), true, "saved in [settings]")
	FxSettings.set_fast_animations(false)
	assert_false(FxTiming.from_settings().fast, "toggled off")
	SetupPrefs.reset_all()
	settings.fast_animations = was


# --- Beats from rules events -------------------------------------------------------------------

func test_every_beat_starts_from_its_event_and_a_tap_ends_them() -> void:
	var m: Control = await _spawn(_walk_fixture(), Walker.new())
	var fx: CzMatchFx = _fx(m)
	var ctrl: Node = m.get_controller()
	assert_not_null(fx, "Match.tscn has the FX layer")
	assert_false(m.get_tracer().visible, "the cz12 tracer placeholder is hidden (the FX layer replaces it)")
	assert_true(fx.get_index() > m.get_inspector().get_index(), "FX draws over the screen")
	var me: int = int(ctrl.human)
	var strip: Array = m.get_state()["you"]["next"]
	var started: Array = []
	fx.effect_started.connect(func(kind: StringName, _info: Dictionary, s: float) -> void: started.append([kind, s]))
	var bus: Node = tree.root.get_node("EventBus")
	var safe_origin: Vector2 = (m.get_node("%SafeArea") as Control).position
	var events: Array[Dictionary] = [
		{"type": "moved", "seat": 1 - me, "from": "docks", "to": "farmstead"},
		{"type": "shot_declared", "seat": 1 - me, "weapon_id": "pump_shotgun", "target": me, "damage": 2, "suppressed": false},
		{"type": "frag_thrown", "seat": 1 - me, "area": "motel", "targets": {}},
		{"type": "braced", "seat": me, "cards": [], "card_ids": [strip[0]], "total": 1, "hits": 1},
		{"type": "hits_landed", "seat": me, "count": 2, "source": "shot", "down": true},
		{"type": "hits_landed", "seat": 1 - me, "count": 1, "source": "shot", "down": true},
		{"type": "looted", "seat": me, "card_id": String(_card_of_rarity("L")), "source": "pile", "area": "motel"},
		{"type": "looted", "seat": 1 - me, "card_id": String(_card_of_rarity("C")), "source": "pile", "area": "docks"},
		{"type": "drop_landed", "card_id": String(_card_of_rarity("E")), "area": "quarry"},
		{"type": "gas_closed", "area": "radio_hill"},
		{"type": "bounty_claimed", "seat": me, "from": 1 - me, "healed": 1},
		{"type": "eliminated", "seat": 1 - me, "cause": "shot"},
	]
	for e: Dictionary in events:
		bus.rules_event.emit(e)
	var wait: int = 0
	while not started.any(func(x: Array) -> bool: return x[0] == &"down") and wait < 600:
		wait += 1
		await tree.process_frame
	var kinds: Array = started.map(func(x: Array) -> StringName: return x[0])
	for k: StringName in ALL_BEATS:
		assert_true(kinds.has(k), "%s beat started (%s)" % [k, kinds])
	assert_false(fx.is_holding(), "no hold while the controller is idle")
	assert_true(fx.is_busy(), "beats running")
	var ghosts: Array = fx.find_children("*", "CzCard", true, false)
	assert_true(ghosts.size() >= 5, "ghost cards on screen (slam x3, burn, loot x2): %d" % ghosts.size())
	var hidden: Array = m.get_cards(&"next").filter(func(c: Control) -> bool: return c.modulate.a < 0.5)
	# Mid-beat: a Hit slam hides the real top card only if it is a Hit; the burn ghost carries the shader.
	var burned: bool = ghosts.any(func(g: CzCard) -> bool: return g.material is ShaderMaterial)
	assert_true(burned, "the Brace card burns with burn.gdshader")
	# A tap ends every beat; it is not consumed.
	var tap: InputEventScreenTouch = InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(5, 5)
	fx._input(tap)
	assert_false(fx.is_busy(), "a tap ends every beat")
	await _frames(2)
	assert_eq(fx.find_children("Beat_*", "", false, false).size(), 0, "beat nodes freed")
	for c: Control in m.get_cards(&"next"):
		assert_eq(c.modulate.a, 1.0, "strip cards shown again after the skip")
	assert_true(hidden.size() <= 2, "at most the landed Hits were hidden (%d)" % hidden.size())
	assert_eq((m.get_node("%SafeArea") as Control).position, safe_origin, "the skip put the shaken screen back")
	_despawn(m)


func test_beats_play_out_and_end_by_themselves() -> void:
	var m: Control = await _spawn(_walk_fixture(), Walker.new())
	var fx: CzMatchFx = _fx(m)
	var safe: Control = m.get_node("%SafeArea")
	var origin: Vector2 = safe.position
	var ended: Array = []
	fx.effect_finished.connect(func(kind: StringName, skipped: bool) -> void: ended.append([kind, skipped]))
	tree.root.get_node("EventBus").rules_event.emit({"type": "eliminated", "seat": 1, "cause": "gas"})
	tree.root.get_node("EventBus").rules_event.emit({"type": "hits_landed", "seat": 0, "count": 1, "source": "shot", "down": false})
	var t0: int = Time.get_ticks_msec()
	await fx.wait_idle(3.0)
	var took: float = (Time.get_ticks_msec() - t0) / 1000.0
	assert_false(fx.is_busy(), "beats end by themselves (%.2f s)" % took)
	assert_true(took < 1.5, "the stamp ends in about its 1.1 s (%.2f s)" % took)
	assert_true(ended.size() == 2 and ended.all(func(x: Array) -> bool: return not bool(x[1])), "finished, not skipped: %s" % [ended])
	await _frames(2)
	assert_eq(safe.position, origin, "the shake put the screen back")
	_despawn(m)


# --- Pacing through the controller hooks --------------------------------------------------------

func test_playback_waits_on_fx_capped() -> void:
	# The rival draws a Pump Shotgun, plays it and fires at you at Normal event speed: the shot
	# beat holds the loop until it ends.
	var s: MatchState = _fixture({
		"P1": {"area": "quarry", "health": 5, "hand": ["scavenge"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash", "duck"]},
		"P2": {"area": "quarry", "health": 5, "loadout": ["pump_shotgun", "dash", "scavenge", "scavenge", "medkit", "duck", "dash"]}})
	var m: Control = await _spawn(s, Shooter.new())
	var fx: CzMatchFx = _fx(m)
	var ctrl: Node = m.get_controller()
	ctrl.event_delay = 0.45
	ctrl.opponent_delay = 0.05
	var held_ms: Array = []
	var since: Array = [0]
	var holding_seen: Array = [false]
	var kinds: Array = []
	fx.effect_started.connect(func(kind: StringName, _i: Dictionary, _s: float) -> void: kinds.append(kind))
	await _touch(m.get_corner_buttons()[&"end_turn"])
	await _touch_dock(m, &"end_turn")
	var guard: int = 0
	while guard < 20000 and (ctrl.busy or guard < 3):
		guard += 1
		await tree.process_frame
		if fx.is_holding() and not holding_seen[0]:
			holding_seen[0] = true
			since[0] = Time.get_ticks_msec()
		elif not fx.is_holding() and holding_seen[0] and since[0] > 0:
			held_ms.append(Time.get_ticks_msec() - since[0])
			since[0] = 0
			holding_seen[0] = false
		if ctrl.phase == &"brace":
			break
	assert_true(kinds.has(&"shot"), "the rival's shot played its beat (%s)" % [kinds])
	assert_true(not held_ms.is_empty() or holding_seen[0], "the FX held the playback at least once")
	for ms: int in held_ms:
		assert_true(ms <= int(CzMatchFx.MAX_HOLD_S * 1000.0) + 100, "a hold lasted %d ms (<= MAX_HOLD_S)" % ms)
	# A stuck beat can never stall the match: the FX releases after MAX_HOLD_S.
	ctrl.busy = true  # pretend a paced step is playing
	fx._paced = true
	fx._hold()
	assert_true(fx.is_holding(), "held")
	var stuck: Dictionary = fx._begin(&"shot", 99.0, {})
	(stuck["tween"] as Tween).tween_interval(99.0)
	var t0: int = Time.get_ticks_msec()
	while fx.is_holding() and Time.get_ticks_msec() - t0 < 4000:
		await tree.process_frame
	var waited: float = (Time.get_ticks_msec() - t0) / 1000.0
	assert_false(fx.is_holding(), "released despite the running beat")
	assert_true(waited <= CzMatchFx.MAX_HOLD_S + 0.2, "after about MAX_HOLD_S (%.2f s)" % waited)
	assert_eq(int(ctrl._holds), 0, "the controller has no hold left")
	fx.skip_all()
	ctrl.busy = false
	_despawn(m)


func test_skip_on_playback_skips_fx_and_delay_zero_never_holds() -> void:
	var m: Control = await _spawn(_walk_fixture(), Walker.new())
	var fx: CzMatchFx = _fx(m)
	var ctrl: Node = m.get_controller()
	ctrl.event_delay = 0.45
	ctrl.opponent_delay = 0.2
	var kinds: Array = []
	fx.effect_started.connect(func(kind: StringName, _i: Dictionary, _s: float) -> void: kinds.append(kind))
	await _touch(m.get_corner_buttons()[&"end_turn"])
	await _touch_dock(m, &"end_turn")
	var guard: int = 0
	while not (kinds.has(&"move") or kinds.has(&"loot")) and guard < 20000:
		guard += 1
		await tree.process_frame
	assert_true(fx.is_busy(), "a beat is running in the rival's turn (%s)" % [kinds])
	await _touch_playback(m, &"skip")
	var frames: int = 0
	while (ctrl.busy or fx.is_busy()) and frames < 600:
		frames += 1
		await tree.process_frame
	assert_false(fx.is_busy(), "SKIP ended the FX")
	assert_false(ctrl.busy, "SKIP finished the playback")
	assert_true(frames < 30, "within a few frames (%d)" % frames)
	assert_false(fx.is_holding(), "no hold left")
	_despawn(m)
	# Delay 0 (Instant, tests): the FX never hold, the turn is done at once.
	m = await _spawn(_walk_fixture(), Walker.new())
	fx = _fx(m)
	ctrl = m.get_controller()
	var holds: Array = [0]
	var orig_holds: int = int(ctrl._holds)
	fx.effect_started.connect(func(_k: StringName, _i: Dictionary, _s: float) -> void:
		holds[0] += int(fx.is_holding()))
	await _touch(m.get_corner_buttons()[&"end_turn"])
	await _touch_dock(m, &"end_turn")
	assert_false(ctrl.busy, "instant: the rival's turn is done at once")
	assert_eq(holds[0], 0, "no FX hold at delay 0")
	assert_eq(int(ctrl._holds), orig_holds, "the controller saw no hold")
	_despawn(m)


func test_reduced_motion_draws_in_place() -> void:
	var settings: Node = tree.root.get_node("Settings")
	var was: bool = settings.reduced_motion
	settings.reduced_motion = true
	var m: Control = await _spawn(_walk_fixture(), Walker.new())
	var fx: CzMatchFx = _fx(m)
	var safe: Control = m.get_node("%SafeArea")
	var origin: Vector2 = safe.position
	var bus: Node = tree.root.get_node("EventBus")
	bus.rules_event.emit({"type": "shot_declared", "seat": 1, "weapon_id": "pump_shotgun", "target": 0, "damage": 2, "suppressed": false})
	bus.rules_event.emit({"type": "hits_landed", "seat": 0, "count": 1, "source": "shot", "down": true})
	bus.rules_event.emit({"type": "looted", "seat": 0, "card_id": String(_card_of_rarity("L")), "source": "pile", "area": "motel"})
	bus.rules_event.emit({"type": "eliminated", "seat": 1, "cause": "shot"})
	await _frames(3)
	var tracers: Array = fx.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.get(&"kind") == &"shot" and n.get(&"head") != null)
	assert_true(not tracers.is_empty() and tracers.all(func(n: Node) -> bool: return float(n.get(&"head")) == 1.0), "the tracer is drawn whole (no travel)")
	var strip_top: Rect2 = fx._local(m.get_cards(&"next")[0])
	for g: Node in fx.find_children("*", "CzCard", true, false):
		var card: CzCard = g as CzCard
		if card.info.get("type", &"") == &"hit":
			assert_eq(card.position.y, strip_top.position.y, "the Hit does not fall (it fades in place)")
	for p: Node in fx.find_children("*", "CPUParticles2D", true, false):
		assert_false((p as CPUParticles2D).emitting, "no particles under reduced motion (%s)" % p.name)
	for i: int in 10:
		await tree.process_frame
		assert_eq(safe.position, origin, "no shake under reduced motion")
	fx.skip_all()
	settings.reduced_motion = was
	_despawn(m)
