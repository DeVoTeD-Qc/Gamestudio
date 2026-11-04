# test_fx.gd
# Purpose: cc15 duel feedback layer (scripts/fx/duel_fx.gd, %FX in scenes/Duel.tscn):
#   - every effect starts from its EventBus signal (drop, capture wipe, reclaim, Ambush flip,
#     Set Link light, "Carded!" stamp, Triptych merge) and ends with the card in its final state,
#   - stage_changes: the wipe / flip start from the previous owner / face and end on the new one,
#   - "Carded!" is skippable by a tap, shakes the screen lightly and puts it back,
#   - reduced motion: no shake, no drop travel, no slide; fast animations halve durations,
#   - wait_idle() returns at once when idle and never outlives its cap,
#   - the duel controller's hooks: duel_lineup_locked, card_reclaimed (after card_placed),
#     set_linked, and a full paced duel (small delays, fast animations) still reaches the end.
# Author: Game Feel Engineer Agent (cc15)
extends "res://tests/test_case.gd"

const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const MockDuelData: GDScript = preload("res://scripts/ui/mock_duel_data.gd")
const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")
const DuelSetup: GDScript = preload("res://scripts/duel/duel_setup.gd")
const DUEL_SCENE: String = "res://scenes/Duel.tscn"

var _saved_root_size: Vector2i
var _saved_settings: Array = []
var _events: Array = []


# --- Effects from EventBus -----------------------------------------------------------------------

func test_drop_and_capture_wipe() -> void:
	var setup: Array = await _spawn(MockDuelData.mid_state())
	var duel: Control = setup[1]
	var fx: DuelFx = duel.get_node("%FX")
	assert_not_null(fx, "Duel.tscn has the FX layer")
	assert_eq(fx.mouse_filter, Control.MOUSE_FILTER_IGNORE, "FX layer never takes input")
	assert_false(fx.busy, "idle at start")
	EventBus.card_placed.emit(&"player", &"neon_rain", &"a2", [])
	var card: BannerCard = duel.get_wall().get_slot(&"a2").get_card()
	assert_true(card.position.y < 0.0, "card starts above the brick (weight drop)")
	assert_true(fx.busy, "busy while the card drops")
	assert_eq(_last(fx)["kind"], &"drop", "drop logged")
	await fx.wait_idle()
	await tree.process_frame
	assert_eq(card.position, Vector2.ZERO, "card lands on the brick")
	assert_eq(card.scale, Vector2.ONE, "squash settles")
	EventBus.card_captured.emit(&"player", &"brass_tacks", &"b2")
	assert_eq(_last(fx)["kind"], &"capture", "capture wipe")
	assert_eq(float(_last(fx)["duration"]), 0.25, "wipe is 0.25 s")
	await fx.wait_idle()
	await tree.process_frame
	assert_eq(duel.get_wall().get_slot(&"b2").get_card().side, &"player", "frame ends in the captor's colour")
	assert_false(fx.busy, "idle again")
	_despawn(setup[0])


func test_staged_wipe_and_flip_start_from_the_old_state() -> void:
	var setup: Array = await _spawn(MockDuelData.mid_state())
	var duel: Control = setup[1]
	var fx: DuelFx = duel.get_node("%FX")
	fx.stage_changes = true
	EventBus.card_captured.emit(&"player", &"brass_tacks", &"b2")
	var b2: BannerCard = duel.get_wall().get_slot(&"b2").get_card()
	assert_eq(b2.side, &"rival", "staged wipe starts on the old owner")
	assert_eq(duel.get_state()["wall"][&"b2"]["owner"], &"player", "screen state already has the new owner")
	await fx.wait_idle()
	await tree.process_frame
	assert_eq(b2.side, &"player", "wipe ends on the new owner")
	EventBus.ambush_sprung.emit(&"rival", &"flare_up", &"b3")
	var b3: BannerCard = duel.get_wall().get_slot(&"b3").get_card()
	assert_true(b3.face_down, "staged flip starts face-down")
	assert_eq(_last(fx)["kind"], &"flip", "flip logged")
	await fx.wait_idle()
	await tree.process_frame
	assert_false(b3.face_down, "flip ends face-up")
	assert_eq(b3.scale, Vector2.ONE, "flip restores the scale")
	EventBus.card_reclaimed.emit(&"player", &"frostbite", &"c2")
	assert_eq(_last(fx)["kind"], &"reclaim", "Reclaim uses the wipe")
	await fx.wait_idle()
	_despawn(setup[0])


func test_set_link_light() -> void:
	var setup: Array = await _spawn(MockDuelData.mid_state())
	var duel: Control = setup[1]
	var fx: DuelFx = duel.get_node("%FX")
	EventBus.set_linked.emit(&"player", &"c1", [&"c2"])
	assert_eq(_last(fx)["kind"], &"link", "link light starts")
	assert_eq(fx._links.size(), 1, "one light per linked card")
	assert_false(fx.busy, "the light never holds the replay")
	await tree.create_timer(0.6).timeout
	await tree.process_frame
	assert_true(fx._links.is_empty(), "light gone after 0.45 s")
	_despawn(setup[0])


func test_carded_stamp_is_skippable_and_shakes() -> void:
	var setup: Array = await _spawn(MockDuelData.mid_state())
	var duel: Control = setup[1]
	var fx: DuelFx = duel.get_node("%FX")
	var safe: Control = duel.get_node("%SafeArea")
	var origin: Vector2 = safe.position
	EventBus.card_captured.emit(&"player", &"brass_tacks", &"b2")
	EventBus.carded.emit(&"player", &"brass_tacks")
	assert_true(fx.is_moment_active(), "stamp shown")
	var moment: Control = fx.get_moment()
	assert_eq(_find_title(moment), "CARDED!", "stamp reads CARDED!")
	assert_eq(float(_last(fx)["duration"]), 0.8, "about 0.8 s")
	assert_true(duel.get_wall().get_slot(&"b2").get_card().has_node("FxCrack"), "crack over the Signature")
	await tree.create_timer(0.2).timeout
	var shook: bool = false
	for i: int in 3:
		await tree.process_frame
		shook = shook or safe.position != origin
	assert_true(shook, "light screen shake after the slam")
	assert_true(fx.busy, "busy while the stamp holds")
	var tap: InputEventMouseButton = InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = Vector2(10, 10)
	(setup[0] as SubViewport).push_input(tap)
	assert_false(fx.is_moment_active(), "a tap skips the stamp")
	assert_false(fx.busy, "skip ends the hold at once")
	assert_eq(safe.position, origin, "shake put back")
	await tree.process_frame
	assert_false(duel.get_wall().get_slot(&"b2").get_card().has_node("FxCrack"), "crack cleared")
	_despawn(setup[0])


func test_carded_rival_caption_and_auto_end() -> void:
	_set_settings(true, false)
	var setup: Array = await _spawn(MockDuelData.mid_state())
	var duel: Control = setup[1]
	var fx: DuelFx = duel.get_node("%FX")
	EventBus.carded.emit(&"rival", &"graveyard_shift")
	var caption: Label = fx.get_moment().find_child("Caption", true, false)
	assert_true(caption.text.contains("took your Signature"), "rival caption: %s" % caption.text)
	assert_eq(float(_last(fx)["duration"]), 0.4, "fast animations: 0.4 s")
	var t0: int = Time.get_ticks_msec()
	await fx.wait_idle()
	assert_true(Time.get_ticks_msec() - t0 < 700, "wait_idle returns when the stamp ends")
	await tree.process_frame
	assert_false(fx.is_moment_active(), "stamp removes itself")
	_restore_settings()
	_despawn(setup[0])


func test_reduced_motion_has_no_shake_or_travel() -> void:
	_set_settings(false, true)
	var setup: Array = await _spawn(MockDuelData.mid_state())
	var duel: Control = setup[1]
	var fx: DuelFx = duel.get_node("%FX")
	var safe: Control = duel.get_node("%SafeArea")
	var origin: Vector2 = safe.position
	EventBus.card_placed.emit(&"player", &"neon_rain", &"a2", [])
	var card: BannerCard = duel.get_wall().get_slot(&"a2").get_card()
	assert_eq(card.position, Vector2.ZERO, "no drop travel")
	assert_true(card.modulate.a < 1.0, "card fades in instead")
	EventBus.carded.emit(&"player", &"brass_tacks")
	var stamp: Control = fx.get_moment().get_node("Stamp")
	assert_eq(stamp.scale, Vector2.ONE, "no stamp slam")
	var moved: bool = false
	for i: int in 30:
		await tree.process_frame
		moved = moved or safe.position != origin
	assert_false(moved, "no screen shake")
	EventBus.ambush_sprung.emit(&"rival", &"flare_up", &"b3")
	assert_eq(duel.get_wall().get_slot(&"b3").get_card().scale, Vector2.ONE, "no flip squash")
	fx.skip()
	_restore_settings()
	_despawn(setup[0])


func test_triptych_merge() -> void:
	var trip: TriptychData = null
	for t: TriptychData in DuelSetup.triptychs():
		if t.id == &"midnight_run":
			trip = t
	assert_not_null(trip, "midnight_run in CardDB")
	if trip == null:
		return
	var state: Dictionary = MockDuelData.mid_state()
	state["wall"] = {}
	for i: int in 3:
		state["wall"][StringName("c%d" % (i + 1))] = {"card_id": trip.cards[i].id, "owner": &"player", "face_down": false}
	var setup: Array = await _spawn(state)
	var duel: Control = setup[1]
	var fx: DuelFx = duel.get_node("%FX")
	EventBus.triptych_scored.emit(&"player", &"midnight_run", true)
	assert_true(fx.is_moment_active(), "merge shown")
	var moment: Control = fx.get_moment()
	assert_eq(moment.name, &"TriptychMoment", "Triptych moment")
	var art: CardArt = moment.get_node("Panorama/Art")
	assert_eq(art.triptych, trip.panorama_key if trip.panorama_key != &"" else &"midnight_run", "panorama from CardArt")
	assert_true(absf(art.size.x / art.size.y - 12.0) < 0.6, "panorama at 12:1 (%s)" % art.size)
	var c1: Rect2 = fx._local_rect(duel.get_wall().get_slot(&"c1"))
	var piece0: Control = moment.get_node("Piece0")
	assert_eq(piece0.position, c1.position, "pieces start on the banners")
	assert_eq(float(_last(fx)["duration"]), 1.5, "merge is 1.5 s")
	EventBus.triptych_scored.emit(&"rival", &"cold_signal", true)
	assert_eq(fx.get_moment(), moment, "a second Triptych waits its turn")
	await tree.create_timer(0.5).timeout
	assert_true(piece0.position.x > c1.position.x + 1.0, "left piece slides right, closing the gaps (%s -> %s)" % [c1.position, piece0.position])
	fx.skip()
	assert_false(fx.is_moment_active(), "skip clears the merge and the queue")
	assert_false(fx.busy, "idle after skip")
	_despawn(setup[0])


func test_timing_options() -> void:
	var normal: RefCounted = FxTiming.create(false, false)
	var fast: RefCounted = FxTiming.create(true, false)
	var reduced: RefCounted = FxTiming.create(false, true)
	assert_eq(normal.get_value(&"carded"), 0.8, "Carded! 0.8 s")
	assert_eq(normal.get_value(&"triptych"), 1.5, "Triptych 1.5 s")
	assert_eq(normal.get_value(&"wipe"), 0.25, "wipe 0.25 s")
	assert_eq(fast.get_value(&"carded"), 0.4, "fast halves the stamp")
	assert_eq(fast.get_value(&"triptych"), 0.75, "fast halves the merge")
	assert_eq(fast.get_value(&"wipe"), 0.15, "wipe keeps a floor")
	assert_eq(fast.get_value(&"shake_px"), 5.0, "distances unscaled")
	assert_eq(reduced.get_value(&"shake_px"), 0.0, "reduced: no shake")
	assert_eq(reduced.get_value(&"drop_px"), 0.0, "reduced: no drop travel")
	assert_eq(reduced.get_value(&"carded"), 0.8, "reduced keeps the stamp's time")


func test_wait_idle_is_instant_when_idle_and_capped() -> void:
	var setup: Array = await _spawn(MockDuelData.mid_state())
	var fx: DuelFx = setup[1].get_node("%FX")
	var f0: int = Engine.get_process_frames()
	await fx.wait_idle()
	assert_eq(Engine.get_process_frames(), f0, "no frame waited when idle")
	fx._busy_until_ms = Time.get_ticks_msec() + 60000
	var t0: int = Time.get_ticks_msec()
	await fx.wait_idle(0.1)
	assert_true(Time.get_ticks_msec() - t0 < 400, "cap honoured")
	fx._busy_until_ms = 0
	_despawn(setup[0])


## Perf smoke: the FX handlers' own CPU cost per event (headless, screen handlers excluded).
func test_fx_handler_cost() -> void:
	var setup: Array = await _spawn(MockDuelData.mid_state())
	var fx: DuelFx = setup[1].get_node("%FX")
	var cost: Dictionary = {}
	var calls: Dictionary = {
		&"drop": func() -> void: fx._on_card_placed(&"player", &"graveyard_shift", &"a1", []),
		&"capture": func() -> void: fx._on_card_captured(&"player", &"frostbite", &"c2"),
		&"flip": func() -> void: fx._on_ambush_sprung(&"rival", &"flare_up", &"b3"),
		&"link": func() -> void: fx._on_set_linked(&"player", &"c1", [&"c2"]),
		&"carded": func() -> void:
			fx._on_carded(&"player", &"brass_tacks")
			fx.skip(),
		&"triptych": func() -> void:
			fx._on_triptych_scored(&"player", &"midnight_run", true)
			fx.skip(),
	}
	for k: StringName in calls:
		var t0: int = Time.get_ticks_usec()
		for i: int in 20:
			(calls[k] as Callable).call()
		cost[k] = (Time.get_ticks_usec() - t0) / 20.0
		assert_true(cost[k] < 4000.0, "%s handler %.0f us" % [k, cost[k]])
	print("     FX handler cost (us/event): %s" % str(cost))
	await tree.process_frame
	_despawn(setup[0])


func test_sfx_streams_are_generated() -> void:
	var sfx: GDScript = preload("res://scripts/fx/fx_sfx.gd")
	for id: StringName in sfx.IDS:
		var s: AudioStreamWAV = sfx.stream(id)
		assert_true(s != null and s.data.size() > 1000, "%s synthesised" % id)
		assert_true(s.get_length() < 1.0, "%s shorter than 1 s" % id)


# --- Controller hooks ----------------------------------------------------------------------------

func test_controller_emits_lineup_reclaim_and_set_link() -> void:
	var setup: Array = await _spawn_duel(4321, 0.0)
	var duel: Control = setup[1]
	var ctrl: Node = duel.get_node("%DuelController")
	_events.clear()
	EventBus.duel_lineup_locked.connect(_on_lineup)
	duel.get_overlay().get_button(&"start").pressed.emit()
	duel.get_overlay().get_button(&"begin").pressed.emit()
	EventBus.duel_lineup_locked.disconnect(_on_lineup)
	assert_eq(_events.size(), 1, "duel_lineup_locked once")
	if _events.size() == 1:
		var ids: Array = ctrl.player_lineup.map(func(c: CardData) -> StringName: return c.id)
		assert_eq(_events[0][1], ids, "lineup ids")
		assert_eq(_events[0][2], ctrl.player_signature.id, "signature id")
		assert_eq(_events[0][3], true, "no lineup asked for: loaner")
	assert_false(duel.get_node("%FX").stage_changes, "instant replay: no staging")
	# A hand-made result: placement with Set Link, then a Reclaim.
	var card: CardData = ctrl.player_lineup[0]
	var r: PlacementResult = PlacementResult.new()
	r.ok = true
	r.player = WallState.P1
	r.card = card
	r.slot = &"b2"
	r.set_link = true
	r.events = [
		{"type": &"placed", "slot": &"b2", "player": WallState.P1, "card_id": card.id},
		{"type": &"reclaimed", "slot": &"b1", "player": WallState.P1, "card_id": &"mayday"},
	]
	_events.clear()
	EventBus.card_placed.connect(_on_placed)
	EventBus.set_linked.connect(_on_linked)
	EventBus.card_reclaimed.connect(_on_reclaimed)
	await ctrl._replay(r)
	EventBus.card_placed.disconnect(_on_placed)
	EventBus.set_linked.disconnect(_on_linked)
	EventBus.card_reclaimed.disconnect(_on_reclaimed)
	var kinds: Array = _events.map(func(e: Array) -> StringName: return e[0])
	assert_eq(kinds, [&"placed", &"linked", &"reclaimed"], "order: placed, set_linked, card_reclaimed")
	if kinds.size() == 3:
		assert_eq(_events[2], [&"reclaimed", &"player", &"mayday", &"b1"], "card_reclaimed payload")
	_despawn(setup[0])


func test_paced_duel_awaits_fx_and_finishes() -> void:
	_set_settings(true, false)
	var setup: Array = await _spawn_duel(2024, 0.03)
	var duel: Control = setup[1]
	var ctrl: Node = duel.get_node("%DuelController")
	var fx: DuelFx = duel.get_node("%FX")
	duel.get_overlay().get_button(&"start").pressed.emit()
	duel.get_overlay().get_button(&"begin").pressed.emit()
	assert_true(fx.stage_changes, "paced replay stages changes")
	var t0: int = Time.get_ticks_msec()
	while ctrl.phase != &"over" and Time.get_ticks_msec() - t0 < 30000:
		if ctrl.phase == &"player":
			var c: CardData = ctrl.state.hands[0][0]
			for b: Node in duel.get_hand().get_card_buttons():
				if b.get_meta(&"card_id") == c.id:
					b.pressed.emit()
			for s: Node in duel.get_wall().get_slots():
				if s.target_state == &"valid":
					s.pressed.emit()
					break
			if not duel.pick_targets.is_empty():
				duel.get_wall().get_slot(duel.pick_targets[0]).pressed.emit()
			duel.get_node("%PlaceButton").pressed.emit()
		await tree.process_frame
	assert_eq(ctrl.phase, &"over", "paced duel reaches the end")
	# The end screen opens once the Triptych merge (if any) has played.
	while duel.get_overlay().kind() != &"end" and Time.get_ticks_msec() - t0 < 30000:
		await tree.process_frame
	assert_eq(duel.get_overlay().kind(), &"end", "end screen after the FX")
	var kinds: Dictionary = {}
	for h: Dictionary in fx.history:
		kinds[h["kind"]] = true
	assert_true(kinds.has(&"drop"), "drops played")
	print("     paced duel: %.1f s, effects %s" % [(Time.get_ticks_msec() - t0) / 1000.0, kinds.keys()])
	_restore_settings()
	_despawn(setup[0])


# --- Helpers -------------------------------------------------------------------------------------

func _on_lineup(ids: Array, sig: StringName, loaner: bool) -> void:
	_events.append([&"lineup", ids, sig, loaner])


func _on_placed(side: StringName, card_id: StringName, slot: StringName, _c: Array) -> void:
	_events.append([&"placed", side, card_id, slot])


func _on_linked(side: StringName, slot: StringName, _linked: Array) -> void:
	_events.append([&"linked", side, slot])


func _on_reclaimed(side: StringName, card_id: StringName, slot: StringName) -> void:
	_events.append([&"reclaimed", side, card_id, slot])


func _last(fx: DuelFx) -> Dictionary:
	return fx.history[-1] if not fx.history.is_empty() else {}


func _find_title(moment: Control) -> String:
	var l: Label = moment.find_child("Title", true, false)
	return l.text if l != null else ""


func _set_settings(fast: bool, reduced: bool) -> void:
	var s: Node = tree.root.get_node("Settings")
	_saved_settings = [s.fast_animations, s.reduced_motion]
	s.fast_animations = fast
	s.reduced_motion = reduced


func _restore_settings() -> void:
	var s: Node = tree.root.get_node("Settings")
	if _saved_settings.size() == 2:
		s.fast_animations = _saved_settings[0]
		s.reduced_motion = _saved_settings[1]


func _spawn(state: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = true
	tree.root.add_child(viewport)
	DuelControllerScript.set_autostart(false)
	var duel: Control = (load(DUEL_SCENE) as PackedScene).instantiate()
	viewport.add_child(duel)
	DuelControllerScript.set_autostart(true)
	duel.show_state(state)
	for i: int in 4:
		await tree.process_frame
	return [viewport, duel]


func _spawn_duel(seed_value: int, delay: float) -> Array:
	_saved_root_size = tree.root.size
	var col: Node = tree.root.get_node_or_null("Collection")
	var autosave: Variant = col.get("autosave") if col != null and "autosave" in col else null
	if autosave != null:
		col.autosave = false
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.disable_3d = true
	viewport.set_meta(&"autosave", autosave)
	tree.root.add_child(viewport)
	DuelControllerScript.set_next_duel(&"", [])
	var duel: Control = (load(DUEL_SCENE) as PackedScene).instantiate()
	var ctrl: Node = duel.get_node("%DuelController")
	ctrl.seed_value = seed_value
	ctrl.event_delay = delay
	ctrl.rival_delay = delay
	viewport.add_child(duel)
	for i: int in 4:
		await tree.process_frame
	return [viewport, duel]


func _despawn(viewport: SubViewport) -> void:
	var col: Node = tree.root.get_node_or_null("Collection")
	if viewport.has_meta(&"autosave") and viewport.get_meta(&"autosave") != null and col != null:
		col.autosave = viewport.get_meta(&"autosave")
	viewport.queue_free()
	tree.root.size = _saved_root_size
