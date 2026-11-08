# dd-feel: settings saved in the profile, the card-art hook and its fallback, the generated sounds,
# the v3 feedback director (deal / kill onto a stack / collect / challenge / shuffle-in / reduce
# motion), the medkit-at-full-HP warning, the rule lock and the gun card's kill stack.
extends "res://tests/dd_test_case.gd"

const Art: GDScript = preload("res://scripts/ui/dd_art.gd")
const Synth: GDScript = preload("res://scripts/fx/dd_sfx_synth.gd")
const Sfx: GDScript = preload("res://scripts/fx/dd_sfx.gd")

var _paths: Array[String] = []


func _tmp(name: String) -> String:
	var p: String = "user://dd_test_feel_%d_%s" % [Time.get_ticks_usec(), name]
	_paths.append(p)
	return p


func _cleanup() -> void:
	for p: String in _paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_paths.clear()


# ---------------------------------------------------------------- settings
func test_settings_defaults_and_save_roundtrip() -> void:
	var path: String = _tmp("prof.json")
	var a: DDProfile = DDProfile.new(bal(), path)
	eq(float(a.setting("master_volume")), 0.8, "default master volume")
	eq(a.setting("screen_shake"), true, "shake on by default")
	eq(a.setting("reduce_motion"), false, "reduce motion off by default")
	check(a.set_setting("master_volume", 0.35), "set master")
	a.set_setting("sfx_volume", 1.7)
	a.set_setting("screen_shake", false)
	a.set_setting("reduce_motion", true)
	check(not a.set_setting("nonsense", 1), "unknown key refused")
	var b: DDProfile = DDProfile.new(bal(), path)
	check(b.load_profile(), "profile reloads")
	eq(float(b.setting("master_volume")), 0.35, "master volume saved")
	eq(float(b.setting("sfx_volume")), 1.0, "sfx volume clamped to 1 and saved")
	eq(b.setting("screen_shake"), false, "shake saved")
	eq(b.setting("reduce_motion"), true, "reduce motion saved")
	eq(b.setting("motion_chosen"), true, "choosing reduce motion is remembered")
	_cleanup()


func test_old_profile_without_settings_gets_defaults() -> void:
	var path: String = _tmp("old.json")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "cleared": ["maple_row"], "runs": 3, "settings": {"master_volume": "loud", "screen_shake": 0}}))
	f.close()
	var p: DDProfile = DDProfile.new(bal(), path)
	check(p.load_profile(), "loads")
	check(p.has_cleared("maple_row"), "progress kept")
	eq(float(p.setting("master_volume")), 0.0, "junk volume coerced, not a crash")
	eq(p.setting("screen_shake"), false, "int coerced to bool")
	eq(float(p.setting("sfx_volume")), 0.8, "missing key keeps its default")
	_cleanup()


func test_game_applies_settings_to_buses() -> void:
	var g: Node = tree.root.get_node_or_null("Game")
	if g == null:
		check(false, "Game autoload missing")
		return
	var keep: DDProfile = g.get("profile")
	g.set("profile", DDProfile.new(bal(), _tmp("bus.json")))
	g.call("set_setting", "sfx_volume", 0.5)
	var idx: int = AudioServer.get_bus_index(&"SFX")
	check(idx >= 0, "SFX bus exists")
	check(absf(AudioServer.get_bus_volume_db(idx) - linear_to_db(0.5)) < 0.01, "SFX bus volume follows the setting")
	g.call("set_setting", "master_volume", 0.0)
	check(AudioServer.is_bus_mute(0), "master 0 mutes")
	g.call("set_setting", "master_volume", 0.8)
	check(not AudioServer.is_bus_mute(0), "master back on")
	g.call("set_setting", "reduce_motion", true)
	check(bool(g.call("reduce_motion")), "reduce motion on")
	check(not bool(g.call("screen_shake")), "reduce motion also stops shake")
	g.set("profile", keep)
	g.call("apply_settings")
	_cleanup()


# ---------------------------------------------------------------- art hook
func test_art_fallback_without_manifest() -> void:
	Art.use_manifest("user://no_such_manifest.json")
	eq(Art.entry_count(), 0, "no manifest, no entries")
	check(Art.texture_for(Art.card_keys(DDCard.parse("Z9"))) == null, "no texture")
	var v: DDCardView = DDCardView.new()
	var spec: Dictionary = {"kind": "Z", "tag": "ZOMBIE", "big": "9", "title": "Bruiser", "lines": [["Bare -9", DDUi.BAD]], "payload": {"title": "x"}}
	v.setup(spec)
	check(not v.has_art, "plain tile")
	check(v.art_rect == null, "no art node")
	check(v.big_label != null and v.big_label.text == "9", "big number still there")
	v.free()
	Art.use_manifest(Art.DEFAULT_MANIFEST)


func test_art_from_a_manifest_and_missing_files() -> void:
	var svg: String = _tmp("z.svg")
	var f: FileAccess = FileAccess.open(svg, FileAccess.WRITE)
	f.store_string('<svg xmlns="http://www.w3.org/2000/svg" width="240" height="180"><rect width="240" height="180" fill="#5c302a"/></svg>')
	f.close()
	var man: String = _tmp("manifest.json")
	f = FileAccess.open(man, FileAccess.WRITE)
	f.store_string(JSON.stringify({"by_kind_value": {"zombie": {"9": svg}}, "survivors": {"rosa": {"file": svg}},
		"cards": [{"id": "W5", "file": "missing/nothing.svg"}]}))
	f.close()
	Art.use_manifest(man)
	check(Art.entry_count() > 0, "entries read")
	check(Art.texture_for(Art.card_keys(DDCard.parse("Z9"))) != null, "grouped kind/value entry found")
	check(Art.texture_for(Art.survivor_keys("rosa")) != null, "dictionary entry with file found")
	check(Art.texture_for(Art.card_keys(DDCard.parse("W:nothing"))) == null, "missing file falls back (null)")
	check(Art.texture_for(Art.card_keys(DDCard.parse("M3"))) == null, "no entry falls back (null)")
	var v: DDCardView = DDCardView.new()
	v.setup({"kind": "Z", "tag": "ZOMBIE", "big": "9", "title": "Bruiser", "art": Art.texture_for(Art.card_keys(DDCard.parse("Z9"))), "payload": {"title": "x"}})
	check(v.has_art and v.art_rect != null, "tile shows the art")
	check(v.big_label != null and v.big_label.text == "9", "number kept on top (badge)")
	v.free()
	Art.use_manifest(Art.DEFAULT_MANIFEST)
	_cleanup()


func test_real_manifest_covers_the_cards() -> void:
	Art.use_manifest(Art.DEFAULT_MANIFEST)
	if Art.entry_count() == 0:
		check(true, "no art shipped yet (fallback look)")
		return
	for code: String in ["Z1", "Z6", "Z11", "M3", "M6", "C2", "C4"]:
		check(Art.texture_for(Art.card_keys(DDCard.parse(code))) != null, "art for " + code)
	for wid: Variant in bal().weapons().keys():
		check(Art.texture_for(Art.weapon_keys(str(wid), bal().weapon_name(str(wid)))) != null, "art for gun " + str(wid))
		check(Art.texture_for(Art.rule_keys(bal().weapon_rule(str(wid)))) != null, "rule icon for " + str(wid))
	for di: int in 3:
		for r: Variant in bal().rooms(di):
			var m: Dictionary = (r as Dictionary)["machine"]
			check(Art.texture_for(Art.machine_keys(m)) != null, "machine art " + str(m["kind"]))
			check(Art.texture_for(Art.room_keys(str(bal().district(di)["id"]), str((r as Dictionary)["name"]))) != null, "room art " + str((r as Dictionary)["name"]))
	for p: String in bal().patches():
		check(Art.texture_for(Art.patch_keys(p)) != null, "Patch art " + p)
	check(Art.file_for("patches_thick_jacket") != Art.file_for("thick_jacket") or Art.file_for("thick_jacket") == "", "the v3 Patch art, not the v2 perk icon")
	for b2: String in ["challenge", "challenge_open", "no_escape"]:
		check(Art.texture_for(Art.badge_keys(b2)) != null, "badge " + b2)
	for k: String in ["wave", "pile", "room"]:
		check(Art.texture_for(Art.deck_back_keys(k)) != null, "deck back " + k)
	for ph: int in 3:
		var pz: DDCard = DDCard.boss([8, 10, 12][ph], "phases", "Patient Zero", ph + 1)
		check(Art.texture_for(Art.card_keys(pz, "st_agnes")) != null, "Patient Zero phase %d" % (ph + 1))
	for d: Variant in bal().districts():
		check(Art.texture_for(Art.district_keys(d)) != null, "banner for " + str((d as Dictionary).get("id")))
		check(Art.texture_for(Art.finale_keys(d)) != null, "boss art for " + str((d as Dictionary).get("id")))
	for s: String in bal().survivor_ids():
		check(Art.texture_for(Art.survivor_keys(s)) != null, "portrait for " + s)
	check(Art.texture_for(Art.back_keys()) != null, "card back")


# ---------------------------------------------------------------- sound
func test_generated_sounds() -> void:
	check(Synth.CUES.size() >= 16 and Synth.CUES.size() <= 20, "16-20 cues (%d)" % Synth.CUES.size())
	for id: StringName in Synth.CUES:
		var s: PackedFloat32Array = Synth.samples(id)
		check(s.size() > 0, "%s has samples" % id)
		check(float(s.size()) / Synth.RATE <= 0.8, "%s is short" % id)
		var peak: float = 0.0
		for x: float in s:
			peak = maxf(peak, absf(x))
		check(peak > 0.05 and peak <= Synth.PEAK + 0.001, "%s level ok (%.2f)" % [id, peak])
		check(FileAccess.file_exists("res://assets/audio/sfx/%s.wav" % id), "%s.wav shipped" % id)


# ---------------------------------------------------------------- feedback
func _main() -> Control:
	var game: Node = tree.root.get_node_or_null("Game")
	game.set("profile", DDProfile.new(bal(), _tmp("ui.json")))
	game.set("run_save", DDRunSave.new(_tmp("run.json")))
	var m: Control = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	tree.root.add_child(m)
	return m


func _frames(n: int) -> void:
	for k: int in n:
		await tree.process_frame


func test_feedback_kill_collect_and_reduce_motion() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	if game == null:
		check(false, "Game autoload missing")
		return
	tree.root.size = Vector2i(390, 844)
	var keep: DDProfile = game.get("profile")
	var m: Control = _main()
	await tree.process_frame
	var bank: Node = Sfx.bank()
	check(bank != null, "sound bank under Game")
	m.call("_start_run")
	await tree.process_frame
	var run: DDRun = game.get("run")
	run.setup_street(["Z5", "W:rifle", "M3", "Z4"] + filler(8, "Z3"))
	run.slot(0).stack = [1, 2, 3] as Array[int]
	m.set("hints_enabled", false)
	m.set("_pending_fx", {"type": "deal", "snap": {}, "ev": {}})
	m.set("screen", 2)
	m.call("_render")
	await _frames(3)
	var fb: Node = m.get("feedback")
	check((fb.get("last_played") as Array).has("deal"), "street deal animation")
	await tree.create_timer(0.8).timeout
	check(bank.played.has(&"deal") and bank.played.has(&"flip"), "deal and flip cues")
	# a gun kill that finishes the pistol: kill onto the stack, collect, Mixed Bag stamp
	bank.clear_log()
	m.call("tap_street", idx(run, "Z5"))
	await _frames(3)
	var lp: Array = fb.get("last_played")
	check(lp.has("kill_stack"), "the zombie flies onto the stack (%s)" % str(lp))
	check(lp.has("collect"), "collect animation (%s)" % str(lp))
	check(lp.has("challenge"), "challenge moment (%s)" % str(lp))
	check(lp.has("hit"), "damage feedback")
	await tree.create_timer(0.7).timeout
	check(bank.played.has(&"kill"), "kill cue on landing")
	# equip the rifle: it flies into slot 1
	m.call("do_resolve", idx(run, "W:rifle"), DDRun.EQUIP1)
	await _frames(3)
	check((fb.get("last_played") as Array).has("equip"), "equip feedback")
	# reduce motion: no shake, nothing moves the content
	game.call("set_setting", "reduce_motion", true)
	check(bool(fb.get("reduce")), "feedback follows reduce motion")
	run.set_active(DDRun.SLOT1)
	m.call("tap_street", idx(run, "Z4") if idx(run, "Z4") >= 0 else 0)
	await _frames(3)
	var content: Control = m.get("_content")
	eq(content.position, Vector2.ZERO, "no shake with reduce motion")
	await tree.create_timer(2.6).timeout
	var ghosts: int = 0
	for c: Node in (m.get("_fx") as Control).get_children():
		if c.has_meta(&"ghost"):
			ghosts += 1
	eq(ghosts, 0, "ghosts are cleaned up")
	m.queue_free()
	await tree.process_frame
	game.set("profile", keep)
	game.call("apply_settings")
	_cleanup()


func test_shuffle_in_animations() -> void:
	var game: Node = tree.root.get_node_or_null("Game")
	tree.root.size = Vector2i(844, 390)
	var keep: DDProfile = game.get("profile")
	var m: Control = _main()
	await tree.process_frame
	m.call("apply_debug", {"screen": "street", "seed": "3", "points": "40"})
	m.call("_render")
	await _frames(2)
	m.call("do_open_room", 0)
	await _frames(3)
	await tree.create_timer(1.0).timeout
	var fb: Node = m.get("feedback")
	check((fb.get("last_played") as Array).has("room_open"), "room cards fly into the pile (%s)" % str(fb.get("last_played")))
	var run: DDRun = game.get("run")
	run.setup_street(["Z1", "Z1", "Z1", "Z1", "Z1"])
	run.set_active(DDRun.MELEE)
	m.call("_render")
	await _frames(2)
	m.call("tap_street", 0)
	await _frames(2)
	m.call("tap_street", 0)
	await _frames(2)
	m.call("tap_street", 0)
	await _frames(3)
	check((fb.get("last_played") as Array).has("wave_shuffle"), "the next wave deck flies into the pile (%s)" % str(fb.get("last_played")))
	await tree.create_timer(2.0).timeout
	check(str(m.get("last_banner")).begins_with("WAVE 2"), "wave banner shown: " + str(m.get("last_banner")))
	m.queue_free()
	await tree.process_frame
	game.set("profile", keep)
	_cleanup()


func test_medkit_at_full_hp_warns() -> void:
	var r: DDRun = make_run("rosa", ["M4", "C2", "C2", "C2"] + filler(8))
	r.hp = r.max_hp
	var i: int = idx(r, "M4")
	eq(int(r.card_preview(i, DDRun.USE)["heal"]), 0, "heals 0 at full HP")
	var spec: Dictionary = DDPayloads.street_card_spec(r.street[i], i, r)
	eq(str(spec["badge"]), "FULL HP", "tile badge warns")


## The active gun's rule forbids a zombie: the tile says LOCK with the reason, art darkened,
## the number stays bright.
func test_rule_lock_on_the_tile() -> void:
	var r: DDRun = plain_run(["Z7", "Z3", "C2", "C2"] + filler(8))
	r.slots[0] = r.make_gun("rifle")
	r.slot(0).stack = [5] as Array[int]
	var hi: int = idx(r, "Z7")
	var lo: int = idx(r, "Z3")
	var blocked: Dictionary = DDPayloads.street_card_spec(r.street[hi], hi, r)
	var fine: Dictionary = DDPayloads.street_card_spec(r.street[lo], lo, r)
	eq(str(blocked["badge"]), "LOCK", "LOCK chip before the tap")
	check(str(blocked["lock"]).contains("lower than 5"), "with the rule's reason")
	check(bool(blocked["art_dim"]), "darkened")
	eq(str(fine["badge"]), "0", "damage chip (3 - power 4 = 0)")
	var v: DDCardView = DDCardView.new()
	var tex: Texture2D = Art.texture_for(Art.card_keys(r.street[hi]))
	if tex == null:
		tex = ImageTexture.create_from_image(Image.create(8, 6, false, Image.FORMAT_RGB8))
	blocked["art"] = tex
	v.setup(blocked)
	check(v.art_rect != null and v.art_rect.self_modulate.r < 0.5, "art darkened to 45%")
	check(v.big_label != null and v.big_label.text == "7", "number shown")
	v.free()
	r.set_active(DDRun.MELEE)
	eq(str(DDPayloads.street_card_spec(r.street[hi], hi, r)["badge"]), "-5", "melee: 7 - 2 = 5, never locked")


func test_gun_card_shows_the_kill_stack() -> void:
	var r: DDRun = plain_run(filler(8))
	r.slots[0] = r.make_gun("rifle")
	r.slot(0).stack = [9, 6, 5] as Array[int]
	var spec: Dictionary = DDPayloads.gun_spec(r, 0)
	spec["mini"] = Vector2(60, 78)
	var gv: DDGunView = DDGunView.new()
	gv.setup_gun(spec)
	tree.root.add_child(gv)
	gv.size = Vector2(260, 220)
	await tree.process_frame
	eq(gv.stack_cards.size(), 3, "3 stack cards")
	eq(gv.stack_cards[2].big_label.text, "5", "top kill's number")
	check(not gv.stack_cards[0].payload.is_empty(), "each stack card is inspectable")
	check(gv.stack_cards[1].position.y > gv.stack_cards[0].position.y, "portrait: each kill is laid lower, over the one before")
	check(absf(gv.stack_cards[1].position.y - gv.stack_cards[0].position.y) < 78 * 0.5, "overlapping, but the earlier number (top-left) stays visible")
	check(gv.stack_cards[2].get_index() > gv.stack_cards[1].get_index(), "later kills drawn on top")
	check(not gv.payload.is_empty() and str(gv.payload["title"]) == "Hunting Rifle", "gun zoom")
	gv.queue_free()
	var e: Dictionary = DDPayloads.gun_spec(r, 1)
	var ev: DDGunView = DDGunView.new()
	ev.setup_gun(e)
	check(not ev.payload.is_empty(), "empty slot is inspectable")
	ev.free()
