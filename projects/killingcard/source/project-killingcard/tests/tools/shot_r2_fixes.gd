# shot_r2_fixes.gd
# Purpose: Dev tool (kc-r2-fixes): screenshots of the playtest round 2 fixes at the window size it is
#   started with, public art only: the title (drill offer gone, buttons in place), the loadout after
#   a swap, a match hand before / after a play, a FAST firefight (column results only, SPEED + FAST),
#   the round recap with a "no losses" reason and the STREAK / killstreak rail words, and an inspector.
# Usage: xvfb-run -a -s "-screen 0 2000x1200x24" godot --path . --rendering-driver opengl3 \
#          --resolution 844x390 -s res://tests/tools/shot_r2_fixes.gd -- <out_dir> <prefix>
# Author: UI/UX Agent (kc-r2-fixes)
extends SceneTree

var _out: String = ""
var _prefix: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_out.path_join(_prefix + name + ".png"))
	print("shot ", _prefix + name, " ", img.get_size())


func _open(path: String) -> Control:
	var s: Control = (load(path) as PackedScene).instantiate()
	root.add_child(s)
	await _frames(12)
	await create_timer(0.5).timeout
	return s


func _close(s: Node) -> void:
	root.remove_child(s)
	s.queue_free()
	await _frames(2)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var settings: Node = root.get_node("Settings")
	settings.persist = false
	NewCard.auto_show = false
	var rs: Node = root.get_node("RunState")
	rs.autosave = false
	var router: Node = root.get_node("SceneRouter")
	router.dry_run = true
	var t: Control = await _open("res://scenes/Title.tscn")
	if t.is_offering_tutorial():
		await _shot("01a_title_offer")
		t.call(&"_on_not_now_pressed")
		await _frames(6)
	await _shot("01b_title")
	await _close(t)
	rs.start_run(4242)
	var lo: Control = await _open("res://scenes/run/Loadout.tscn")
	if lo.get_starter() != null:
		lo.get_starter().close()
	await _frames(6)
	for id: StringName in [&"sentry_turret", &"attack_helo", &"gunship"]:
		if not id in lo.picked and lo.toggle(id):
			break
	await _frames(6)
	await _shot("02_loadout_swap")
	await _close(lo)
	await _match()
	quit(0)


func _match() -> void:
	settings_fast(false)
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(30)
	await create_timer(1.0).timeout
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	if m.get_match_intro() != null and m.get_match_intro().visible:
		m.get_match_intro().close()
		await create_timer(0.6).timeout
	var st: MatchState = c.state
	var me: RulesSide = st.sides[0]
	me.supply = 10
	c.refresh()
	await _frames(6)
	await _shot("03a_hand_before")
	for rc: RulesCard in me.hand:
		if rc.card.is_unit():
			c.select_card(rc.uid)
			c.play_at(1)
			break
	await _frames(4)
	await create_timer(0.4).timeout
	await _shot("03b_hand_after_play")
	c.undo()
	# Stage: A trades, B is a Cover stand-off (no losses, and why), C one each.
	for s: RulesSide in st.sides:
		for z: int in 3:
			s.line(z).clear()
		s.plays.clear()
	st.sides[1].ready = false
	st.put_in_line(st.create_unit(0, root.get_node("CardDB").get_card(&"rifleman")), 0)
	st.put_in_line(st.create_unit(1, root.get_node("CardDB").get_card(&"rifleman")), 0)
	var weak: RulesUnit = st.create_unit(0, root.get_node("CardDB").get_card(&"rifleman"))
	weak.base_firepower = 1
	st.put_in_line(weak, 1)
	var dug: RulesUnit = st.create_unit(1, root.get_node("CardDB").get_card(&"rifleman"))
	dug.cover = 1
	dug.base_firepower = 0
	st.put_in_line(dug, 1)
	st.put_in_line(st.create_unit(0, root.get_node("CardDB").get_card(&"rifleman")), 2)
	c.refresh()
	await _frames(4)
	m.get_fast_button().button_pressed = true
	c.press_ready()
	await create_timer(0.9).timeout
	await _shot("04_fast_firefight")
	for i: int in 40:
		await create_timer(0.25).timeout
		if not c.is_busy():
			break
	await create_timer(0.3).timeout
	await _shot("05_recap_and_rail")
	m.get_fast_button().button_pressed = false
	var pick_uid: int = me.hand[0].uid if not me.hand.is_empty() else -1
	if pick_uid >= 0:
		c.call(&"_on_card_inspected", pick_uid)
		await _frames(10)
		await _shot("06_inspector")
		m.get_inspector().close()
	c.call(&"_on_rail_inspected", &"streak")
	await _frames(10)
	await _shot("07_streak_info")
	await _close(m)


func settings_fast(on: bool) -> void:
	root.get_node("Settings").set(&"fast_fights", on)
