# test_juice.gd
# Purpose: kc-juice (the head's "8. Juice pass"): the effects fire on the right events (sound cues per
#   round step / beat, hit / kill / block, the column-win flourish, the card-land stamp, the Supply
#   spend, the reward reveal, button presses); hit-stop is 60-90 ms by importance, never changes the
#   fight and costs no more than its budget; the shake is directional and capped; reduced motion
#   and Screen shake OFF disable shake (and, for reduced motion, hit-stop and flashes); the
#   SOUND · MOTION settings write Settings and the audio buses; the audio files exist and stay
#   under the web size budget.
# Author: Game Feel Engineer Agent (kc-juice)
extends "res://tests/test_case.gd"

const DirectorScene: PackedScene = preload("res://scenes/fx/FeedbackDirector.tscn")
const FxTiming: GDScript = preload("res://scripts/fx/fx_timing.gd")
const SfxSynth: GDScript = preload("res://scripts/fx/sfx_synth.gd")
const SfxBank: GDScript = preload("res://scripts/fx/sfx_bank.gd")
const CardLandFx: GDScript = preload("res://scripts/fx/card_land_fx.gd")
const RewardRevealFx: GDScript = preload("res://scripts/fx/reward_reveal_fx.gd")
const BoardLayout: GDScript = preload("res://tests/test_board_layout.gd")
const FeedbackDirector: GDScript = preload("res://scripts/fx/feedback_director.gd")
const SFX_DIR: String = "res://assets/audio/sfx"
## The whole set of new audio must stay under this (web build: ~300 KB).
const AUDIO_BUDGET_BYTES: int = 300 * 1024

var _root: Control
var _director: Control


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


func _setup(fast: bool = true, reduced: bool = false, shake: bool = true) -> void:
	_root = Control.new()
	_root.size = Vector2(1280, 720)
	tree.root.add_child(_root)
	_director = DirectorScene.instantiate()
	_director.use_settings = false
	_director.fast = fast
	_director.reduced_motion = reduced
	_director.screen_shake = shake
	_root.add_child(_director)
	_director.locator = FakeLocator.new()


func _teardown() -> void:
	if _director != null and _director.is_playing():
		_director.skip()
	_root.queue_free()
	await tree.process_frame


func _ev(type: StringName, fields: Dictionary) -> Dictionary:
	return RulesEvent.make(type, 3, fields)


func _elim(victim: int, victim_side: StringName, by: int, extra: Dictionary = {}) -> Dictionary:
	var f: Dictionary = {"victim_uid": victim, "victim_side": victim_side, "victim_id": &"marksman", "is_operator": false,
			"by_uid": by, "by_side": &"player" if victim_side == &"enemy" else &"enemy", "by_id": &"rifleman", "zone": &"mid",
			"source_kind": &"unit", "by_killstreak": false, "credit": true}
	f.merge(extra, true)
	return _ev(RulesEvent.UNIT_ELIMINATED, f)


## A round with every juiced moment: the three round steps, beats 1, 2 and 5, a normal hit, a Cover
## block, a big hit that does not kill, a kill, and the viewer's column secured.
func _round() -> Array:
	return [
		_ev(RulesEvent.PHASE_CHANGED, {"phase": &"reveal"}),
		_ev(RulesEvent.PHASE_CHANGED, {"phase": &"firefight"}),
		_ev(RulesEvent.FIREFIGHT_STARTED, {"zone": &"mid"}),
		_ev(RulesEvent.FIREFIGHT_BEAT, {"zone": &"mid", "beat": 1, "shooters": [1], "exchange": 0}),
		_ev(RulesEvent.SHOT_FIRED, {"side": &"player", "shooter_uid": 1, "target_uid": 11, "zone": &"mid", "damage": 2, "step": &"beat"}),
		_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 11, "side": &"enemy", "amount": 2, "remaining": 3, "source_id": &"rifleman"}),
		_ev(RulesEvent.FIREFIGHT_BEAT, {"zone": &"mid", "beat": 2, "shooters": [11], "exchange": 0}),
		_ev(RulesEvent.SHOT_FIRED, {"side": &"enemy", "shooter_uid": 11, "target_uid": 1, "zone": &"mid", "damage": 0, "step": &"beat"}),
		_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 1, "side": &"player", "amount": 0, "remaining": 3, "source_id": &"marksman"}),
		_ev(RulesEvent.FIREFIGHT_BEAT, {"zone": &"mid", "beat": 5, "shooters": [2], "exchange": 0}),
		_ev(RulesEvent.SHOT_FIRED, {"side": &"player", "shooter_uid": 2, "target_uid": 11, "zone": &"mid", "damage": 5, "step": &"beat"}),
		_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 11, "side": &"enemy", "amount": 5, "remaining": 1, "source_id": &"gunner"}),
		_ev(RulesEvent.SHOT_FIRED, {"side": &"player", "shooter_uid": 1, "target_uid": 11, "zone": &"mid", "damage": 3, "step": &"beat"}),
		_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 11, "side": &"enemy", "amount": 3, "remaining": 0, "source_id": &"rifleman"}),
		_elim(11, &"enemy", 1),
		_ev(RulesEvent.FIREFIGHT_COLUMN_ENDED, {"zone": &"mid", "beats": 3}),
		_ev(RulesEvent.PHASE_CHANGED, {"phase": &"score"}),
		_ev(RulesEvent.ZONE_CONTROL, {"zone": &"mid", "owner": &"player"}),
	]


func _count(list: Array, item: Variant) -> int:
	var n: int = 0
	for x: Variant in list:
		if x == item:
			n += 1
	return n


# --- audio files ------------------------------------------------------------------------------

func test_audio_files_exist_and_stay_under_budget() -> void:
	var total: int = 0
	for id: StringName in SfxSynth.CUES:
		var path: String = SFX_DIR.path_join("%s.wav" % id)
		assert_true(FileAccess.file_exists(path), "%s exists" % path)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		total += bytes.size()
		assert_true(bytes.size() > 44 and bytes.decode_u32(0) == 0x46464952, "%s is a RIFF wav" % id)
		assert_true(bytes.size() < 32 * 1024, "%s is short (%d bytes)" % [id, bytes.size()])
		assert_true(ResourceLoader.exists(path), "%s is imported" % id)
		assert_true(load(path) is AudioStream, "%s loads as an AudioStream" % id)
	# Every file in the folder is one of ours (nothing downloaded slipped in).
	for f: String in DirAccess.get_files_at(SFX_DIR):
		if f.ends_with(".wav"):
			assert_true(StringName(f.get_basename()) in SfxSynth.CUES, "%s is a generated cue" % f)
	assert_true(total < AUDIO_BUDGET_BYTES, "all sound effects together %d bytes < %d" % [total, AUDIO_BUDGET_BYTES])
	# The files are exactly what the synth makes (so they are the original, generated sounds).
	assert_eq(FileAccess.get_file_as_bytes(SFX_DIR.path_join("hit.wav")), SfxSynth.wav_bytes(&"hit"), "hit.wav = SfxSynth output")


func test_sfx_bank_buses_and_volumes() -> void:
	var settings: Node = tree.root.get_node("Settings")
	var bank: Node = SfxBank.bank()
	assert_not_null(bank, "the SFX bank lives under Settings")
	var sfx_bus: int = AudioServer.get_bus_index(&"SFX")
	assert_true(sfx_bus > 0, "SFX bus exists")
	assert_eq(AudioServer.get_bus_send(sfx_bus), &"Master", "SFX goes to Master")
	var was_master: float = settings.master_volume
	var was_sfx: float = settings.sfx_volume
	settings.set_value(&"master_volume", 0.5)
	settings.set_value(&"sfx_volume", 0.0)
	assert_true(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.01, "master volume applied")
	assert_true(AudioServer.is_bus_mute(sfx_bus), "SFX 0 mutes the SFX bus")
	settings.set_value(&"sfx_volume", 1.0)
	assert_false(AudioServer.is_bus_mute(sfx_bus), "SFX back on")
	settings.set_value(&"master_volume", was_master)
	settings.set_value(&"sfx_volume", was_sfx)
	bank.clear_log()
	assert_true(bank.play(&"kill"), "a cue plays")
	assert_false(bank.play(&"kill"), "the same cue on the same frame is dropped")
	assert_true(bank.play(&"hit"), "another cue still plays")
	assert_false(bank.play(&"no_such_cue"), "unknown cue")
	assert_eq(bank.played_ids(), [&"kill", &"hit"] as Array[StringName], "played log")


# --- director ---------------------------------------------------------------------------------

func test_cues_and_effects_fire_on_the_right_events() -> void:
	_setup()
	var events: Array = _round()
	await _director.play(events)
	var cues: Array[StringName] = _director.sfx_log
	assert_eq(cues.slice(0, 2), [&"step_1", &"step_2"] as Array[StringName], "Reveal, then Firefight cue")
	assert_eq(cues.back(), &"column_win", "column secured cue last")
	assert_eq(_count(cues, &"step_3"), 1, "Score cue")
	assert_true(cues.find(&"beat_1") < cues.find(&"beat_2") and cues.find(&"beat_2") < cues.find(&"beat_4"), "beat ticks rise in order")
	assert_eq(_count(cues, &"hit"), 2, "two normal hits (2 and the killing 3)")
	assert_eq(_count(cues, &"hit_big"), 1, "the 5-damage hit is big")
	assert_eq(_count(cues, &"block"), 1, "the 0-damage hit blocks")
	assert_eq(_count(cues, &"kill"), 1, "one kill")
	assert_true(cues.find(&"block") < cues.find(&"hit_big") and cues.find(&"hit_big") < cues.find(&"kill"), "cues in event order")
	var kinds: Array[StringName] = _director.logged_kinds()
	assert_eq(_count(kinds, &"hitstop"), 1, "hit-stop on the kill only")
	assert_eq(_count(kinds, &"shake"), 2, "shake on the big hit and on the kill")
	assert_eq(_count(kinds, &"column_win"), 1, "column-win flourish")
	assert_eq(tree.root.canvas_transform, Transform2D.IDENTITY, "shake restores the canvas")
	# The bank actually played them (beats past 4 climb in pitch).
	var bank: Node = SfxBank.bank()
	var beat5: Array = bank.played.filter(func(e: Dictionary) -> bool: return e["id"] == &"beat_4")
	assert_true(not beat5.is_empty() and float(beat5.back()["pitch"]) > 1.0, "beat 5 = beat_4 cue at a higher pitch")
	await _teardown()


func test_hitstop_by_importance_within_60_to_90_ms() -> void:
	var t: RefCounted = FxTiming.create(false, false)
	var unit: Dictionary = _elim(11, &"enemy", 1)
	var ks: Dictionary = _elim(11, &"enemy", -1, {"by_killstreak": true, "source_kind": &"killstreak"})
	var op: Dictionary = _elim(11, &"enemy", 1, {"is_operator": true})
	var values: Array[float] = []
	for ev: Dictionary in [unit, ks, op]:
		values.append(t.get_value(FeedbackDirector.hitstop_key(ev)))
	assert_eq(values[0], 0.06, "a unit: 60 ms")
	assert_true(values[0] < values[1] and values[1] < values[2], "killstreak > unit, Operator > killstreak (%s)" % [values])
	assert_eq(values[2], 0.09, "the Operator: 90 ms")
	_setup(false)
	await _director.play([op])
	assert_true(absf(_director.logged_duration(&"hitstop") - 0.09) < 0.0001, "Operator kill logs 90 ms of hit-stop")
	assert_eq(_director.process_mode, Node.PROCESS_MODE_INHERIT, "hit-stop released")
	await _teardown()


func test_hitstop_keeps_the_fight_and_costs_only_its_budget() -> void:
	var events: Array = [
		_ev(RulesEvent.FIREFIGHT_STARTED, {"zone": &"mid"}),
		_ev(RulesEvent.FIREFIGHT_BEAT, {"zone": &"mid", "beat": 1, "shooters": [1, 11], "exchange": 0}),
		_ev(RulesEvent.SHOT_FIRED, {"side": &"player", "shooter_uid": 1, "target_uid": 11, "zone": &"mid", "damage": 3, "step": &"beat"}),
		_ev(RulesEvent.SHOT_FIRED, {"side": &"enemy", "shooter_uid": 11, "target_uid": 1, "zone": &"mid", "damage": 3, "step": &"beat"}),
		_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 11, "side": &"enemy", "amount": 3, "remaining": 0, "source_id": &"rifleman"}),
		_ev(RulesEvent.DAMAGE_DEALT, {"target_uid": 1, "side": &"player", "amount": 3, "remaining": 0, "source_id": &"marksman"}),
		_elim(11, &"enemy", 1),
		_elim(1, &"player", 11, {"is_operator": true}),
		_ev(RulesEvent.FIREFIGHT_COLUMN_ENDED, {"zone": &"mid", "beats": 1}),
	]
	var before: Array = events.duplicate(true)
	var runs: Array[Dictionary] = []
	for on: bool in [false, true]:
		_setup(false)
		_director.hitstop_enabled = on
		var landed: Array = []
		_director.event_landed.connect(func(ev: Dictionary) -> void: landed.append(ev.duplicate(true)))
		var t0: int = Time.get_ticks_usec()
		await _director.play(events)
		runs.append({"ms": (Time.get_ticks_usec() - t0) / 1000.0, "landed": landed, "stop": _director.logged_duration(&"hitstop")})
		await _teardown()
	assert_eq(events, before, "the events are never changed")
	assert_eq(runs[0]["landed"], runs[1]["landed"], "same events land in the same order with hit-stop")
	assert_eq(float(runs[0]["stop"]), 0.0, "off: no hit-stop")
	var budget_ms: float = float(runs[1]["stop"]) * 1000.0
	assert_true(budget_ms > 0.0 and budget_ms <= 2 * 90.0, "hit-stop budget %.0f ms (<= 90 ms per kill)" % budget_ms)
	var extra: float = float(runs[1]["ms"]) - float(runs[0]["ms"])
	print("     [kc-juice] playback %.0f ms without hit-stop, %.0f ms with (budget %.0f ms)" % [runs[0]["ms"], runs[1]["ms"], budget_ms])
	assert_true(extra <= budget_ms + 120.0, "hit-stop costs %.0f ms, budget %.0f ms (+ frame slack)" % [extra, budget_ms])
	assert_true(extra >= -120.0, "and the playback is not shortened (%.0f ms)" % extra)


func test_shake_is_directional_and_capped() -> void:
	var px: float = 4.0
	var dir: Vector2 = Vector2.RIGHT
	var along: float = 0.0
	var side: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 50:
		var k: float = float(i) / 50.0
		for d: Vector2 in [Vector2.ZERO, dir]:
			var off: Vector2 = FeedbackDirector.shake_offset(px, k, d, rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			assert_true(off.length() <= px + 0.001, "offset %.2f within %.1f px" % [off.length(), px])
			if d != Vector2.ZERO:
				along += absf(off.x)
				side += absf(off.y)
	assert_true(along > side * 3.0, "the shake follows the shot (along %.1f vs side %.1f)" % [along, side])
	_setup(false)
	_director._shake(12.0, 0.1, {}, Vector2.UP)
	var last: Dictionary = _director.get_meta(&"last_shake", {})
	assert_eq(float(last.get("px", 0.0)), FxTiming.SHAKE_CAP_PX, "a 12 px request is capped at 4 px")
	assert_eq(last.get("dir"), Vector2.UP, "direction kept")
	await tree.create_timer(0.2).timeout
	assert_eq(tree.root.canvas_transform, Transform2D.IDENTITY, "canvas restored")
	await _teardown()


func test_shake_off_and_reduced_motion() -> void:
	# Screen shake OFF: no shake, the hit-stop stays.
	_setup(true, false, false)
	await _director.play(_round())
	var kinds: Array[StringName] = _director.logged_kinds()
	assert_eq(_count(kinds, &"shake"), 0, "Screen shake off: no shake")
	assert_eq(_count(kinds, &"hitstop"), 1, "Screen shake off keeps the hit-stop")
	assert_true(_director.sfx_log.has(&"kill"), "sounds still play")
	await _teardown()
	# Reduced motion: no shake, no hit-stop, the flourish fades in place, the cues stay.
	_setup(true, true, true)
	await _director.play(_round())
	kinds = _director.logged_kinds()
	assert_eq(_count(kinds, &"shake"), 0, "reduced motion: no shake")
	assert_eq(_count(kinds, &"hitstop"), 0, "reduced motion: no hit-stop")
	assert_true(_director.sfx_log.has(&"kill") and _director.sfx_log.has(&"column_win"), "reduced motion keeps the sounds")
	await _teardown()
	# Timing table and the Settings path.
	var off: RefCounted = FxTiming.create(false, false, false)
	for key: StringName in FxTiming.SHAKE_KEYS:
		assert_eq(off.get_value(key), 0.0, "%s is 0 with shake off" % key)
	assert_true(off.get_value(&"land_flash") > 0.0 and off.get_value(&"hitstop") > 0.0, "shake off keeps flash and hit-stop")
	var calm: RefCounted = FxTiming.create(false, true, true)
	for key: StringName in [&"shake_px", &"shake_hit_px", &"land_flash", &"land_scale", &"land_punch_in", &"hitstop_big"]:
		assert_eq(calm.get_value(key), 0.0, "%s is 0 with reduced motion" % key)
	var settings: Node = tree.root.get_node("Settings")
	var was: bool = settings.screen_shake
	settings.set_value(&"screen_shake", false)
	assert_false(FxTiming.from_settings().shake_on, "FxTiming reads Settings.screen_shake")
	_setup(false)
	_director.use_settings = true
	await _director.play([_elim(11, &"enemy", 1)])
	assert_eq(_count(_director.logged_kinds(), &"shake"), 0, "the director follows Settings.screen_shake")
	await _teardown()
	settings.set_value(&"screen_shake", was)


# --- card land stamp ------------------------------------------------------------------------------

func test_card_land_stamp_punches_flashes_and_clears() -> void:
	var host: Control = Control.new()
	tree.root.add_child(host)
	var banner: Control = Control.new()
	banner.size = Vector2(228, 57)
	host.add_child(banner)
	var bank: Node = SfxBank.bank()
	bank.clear_log()
	var dur: float = CardLandFx.stamp(banner, &"player", FxTiming.create(false, false))
	assert_true(dur > 0.0 and dur <= 0.25, "stamp within 250 ms (%.3f)" % dur)
	assert_not_null(banner.get_node_or_null("LandFlash"), "flash over the banner")
	assert_true(bank.played_ids().has(&"card_land"), "stamp sound")
	await tree.create_timer(0.08).timeout
	assert_true(banner.scale.x > 1.01, "scale punch (%.3f)" % banner.scale.x)
	await tree.create_timer(0.3).timeout
	assert_true(banner.scale.is_equal_approx(Vector2.ONE), "settled at scale 1 (%s)" % banner.scale)
	assert_null_flash(banner, "nothing left over the stats once settled")
	assert_eq(banner.position, Vector2.ZERO, "the banner's place is not touched")
	# Reduced motion: the sound only.
	bank.clear_log()
	var d2: float = CardLandFx.stamp(banner, &"enemy", FxTiming.create(false, true))
	assert_eq(d2, 0.0, "reduced motion: no punch, no flash")
	assert_null_flash(banner, "reduced motion: no flash")
	assert_true(banner.scale.is_equal_approx(Vector2.ONE), "reduced motion: no punch")
	assert_true(bank.played_ids().has(&"card_land"), "reduced motion keeps the stamp sound")
	assert_true(FxTiming.create(true, false).get_value(&"land_flash") < FxTiming.create(false, false).get_value(&"land_flash"), "fast animations shorten it")
	host.queue_free()
	await tree.process_frame


func assert_null_flash(banner: Control, message: String) -> void:
	var f: Node = banner.get_node_or_null("LandFlash")
	assert_true(f == null or f.is_queued_for_deletion(), message)


func test_card_landing_on_the_board_stamps_once() -> void:
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE)
	var vp: SubViewport = setup[0]
	var m: Control = setup[1]
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	await tree.process_frame
	var st: MatchState = c.state
	var n0: int = CardLandFx.stamps.size()
	var a: RulesUnit = st.create_unit(0, CardDB.get_card(&"rifleman"))
	st.put_in_line(a, 1)
	c.refresh()
	await tree.create_timer(1.0).timeout
	var new_stamps: Array = CardLandFx.stamps.slice(n0)
	assert_eq(new_stamps.size(), 1, "one stamp for the one card that landed (%s)" % [new_stamps])
	if new_stamps.size() == 1:
		assert_eq(new_stamps[0]["side"], &"player", "your card")
	var slot: Node = m.get_board().get_lanes()[1].get_friendly_slots()[0]
	assert_true(slot.banner.scale.is_equal_approx(Vector2.ONE), "banner settled at scale 1")
	assert_null_flash(slot.banner, "no flash left on the landed banner")
	# A plain refresh with nothing new does not stamp again.
	c.refresh()
	await tree.create_timer(0.4).timeout
	assert_eq(CardLandFx.stamps.size(), n0 + 1, "no stamp without a new card")
	# Supply spend: the hexes just spent burst.
	m._set_supply(5, 5)
	m._set_supply(3, 5)
	assert_eq(m.last_supply_spent, [3, 4] as Array[int], "pips 4 and 5 just spent")
	m._set_supply(3, 5)
	assert_true(m.last_supply_spent.is_empty(), "no burst without a spend")
	m._set_supply(6, 6)
	assert_true(m.last_supply_spent.is_empty(), "a new round's refill does not burst")
	layout._despawn(vp)
	await tree.process_frame


# --- small wins ----------------------------------------------------------------------------------

func test_reward_reveal_and_button_press_feedback() -> void:
	var host: Control = Control.new()
	tree.root.add_child(host)
	var tiles: Array = []
	for i: int in 3:
		var t: Control = Control.new()
		host.add_child(t)
		tiles.append(t)
	var total: float = RewardRevealFx.reveal(tiles, FxTiming.create(false, false))
	assert_true(total > 0.0 and total < 0.5, "staggered reveal under half a second (%.2f)" % total)
	await tree.process_frame
	assert_true((tiles[2] as Control).modulate.a < 0.5, "the last card is still fading in")
	await tree.create_timer(total + 0.1).timeout
	for t: Control in tiles:
		assert_eq(t.modulate.a, 1.0, "every card fully shown")
	(tiles[0] as Control).modulate.a = 1.0
	assert_eq(RewardRevealFx.reveal(tiles, FxTiming.create(false, true)), 0.0, "reduced motion: shown at once")
	assert_eq((tiles[1] as Control).modulate.a, 1.0, "reduced motion: no fade")
	# Any button gets a click and a brighten on press (colour only).
	var bank: Node = SfxBank.bank()
	bank.clear_log()
	var b: Button = Button.new()
	b.text = "OK"
	host.add_child(b)
	var size_before: Vector2 = b.size
	b.button_down.emit()
	assert_true(bank.played_ids().has(&"click"), "press click")
	assert_true(b.self_modulate.r > 1.0, "press brighten")
	assert_eq(b.size, size_before, "no layout change")
	await tree.create_timer(0.2).timeout
	assert_eq(b.self_modulate, Color.WHITE, "back to normal")
	host.queue_free()
	await tree.process_frame


func test_sound_motion_settings_panel() -> void:
	var settings: Node = tree.root.get_node("Settings")
	var saved: Dictionary = {}
	for k: StringName in [&"master_volume", &"sfx_volume", &"screen_shake", &"reduced_motion", &"motion_chosen"]:
		saved[k] = settings.get(k)
	var pm: Control = (load("res://scenes/match/PauseMenu.tscn") as PackedScene).instantiate()
	tree.root.add_child(pm)
	pm.open({})
	await tree.process_frame
	assert_eq(pm.get_sound_button().text, "SOUND", "pause sheet offers SOUND")
	assert_true(pm.get_sound_button().tooltip_text != "", "SOUND has a tooltip")
	var panel: Control = pm.open_sound()
	await tree.process_frame
	assert_eq(pm.get_sound_panel(), panel, "SOUND · MOTION open over the sheet")
	assert_true(panel.get_shake_button().text.begins_with("SCREEN SHAKE: ON"), "Screen shake defaults on")
	panel.get_shake_button().button_pressed = false
	assert_false(settings.screen_shake, "toggle writes Settings.screen_shake")
	panel.get_master_slider().value = 40.0
	panel.get_sfx_slider().value = 60.0
	assert_true(is_equal_approx(settings.master_volume, 0.4) and is_equal_approx(settings.sfx_volume, 0.6), "sliders write the volumes")
	panel.get_motion_button().button_pressed = true
	assert_true(settings.reduced_motion and settings.motion_chosen, "REDUCE MOTION on (and remembered as chosen)")
	assert_true(panel.get_shake_button().disabled, "reduce motion turns the shake toggle off")
	for b: Button in [panel.get_shake_button(), panel.get_motion_button(), panel.get_back_button()]:
		assert_true(b.custom_minimum_size.y >= 64.0, "%s is a 64 px tap target" % b.text)
		assert_true(b.tooltip_text != "", "%s has a tooltip" % b.text)
	pm.back()
	assert_true(pm.is_open(), "Esc on the sheet waits for the panel")
	panel.get_back_button().pressed.emit()
	await tree.process_frame
	assert_null(pm.get_sound_panel(), "BACK closes the panel")
	for k: StringName in saved:
		settings.set_value(k, saved[k])
	pm.queue_free()
	await tree.process_frame


func assert_null(value: Variant, message: String) -> void:
	assert_true(value == null, message)
