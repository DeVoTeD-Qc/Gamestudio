# shot_wire2.gd
# Purpose: Dev tool (kc-ui-wire2): phone-size (844x390) screenshots of the screens the UI kit batch 2
#   pieces reach, public art only: title, pause menu, match board, hand (H1 selected), inspector,
#   run map, Loadout, Codex, After-Action. Run it once with the kit and once without
#   (`-- <out> <prefix> nokit` sets UiKit.enabled = false) to compare.
# Usage: xvfb-run -a -s "-screen 0 1280x1024x24" godot --path . --rendering-driver opengl3 \
#          --resolution 844x390 -s res://tests/tools/shot_wire2.gd -- <out_dir> [prefix] [nokit]
# Author: UI/UX Agent (kc-ui-wire2)
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
	if args.size() > 2 and args[2] == "nokit":
		UiKit.enabled = false
		UiKit.clear_cache()
		KitTheme.restore(ThemeDB.get_project_theme())
		KitTheme.clear_cache()
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var settings: Node = root.get_node("Settings")
	settings.persist = false
	NewCard.auto_show = false
	root.get_node("SceneRouter").dry_run = true
	var rs: Node = root.get_node("RunState")
	rs.autosave = false
	# --- Title and Codex.
	var title: Control = await _open("res://scenes/Title.tscn")
	await _shot("01_title")
	title.open_codex()
	await _frames(10)
	await _shot("08_codex")
	await _close(title)
	# --- Match: board, hand, inspector, pause menu.
	var db: Node = root.get_node("CardDB")
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(30)
	await create_timer(1.0).timeout
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		await _shot("02b_mulligan")
		c.keep_hand()
	var st: MatchState = c.state
	var own: Array = [[&"breacher", 0], [&"point_man", 0], [&"marksman", 1], [&"gunner", 2]]
	var rival: Array = [[&"flanker", 0], [&"rifleman", 1], [&"combat_medic", 1], [&"si_grunt", 2]]
	for side_list: Array in [[0, own], [1, rival]]:
		for row: Array in side_list[1]:
			var cd: CardData = db.get_card(row[0])
			if cd != null:
				st.put_in_line(st.create_unit(int(side_list[0]), cd), int(row[1]))
	c.refresh()
	await create_timer(2.0).timeout
	await _frames(4)
	await _shot("02_match_board")
	var pick: RulesCard = null
	for rc: RulesCard in st.sides[0].hand:
		if rc.card.is_unit() and (pick == null or rc.card.cost < pick.card.cost):
			pick = rc
	if pick != null:
		c.select_card(pick.uid)
	await _frames(8)
	await _shot("03_hand_selected")
	if pick != null:
		c.play_at(0)
		await _frames(8)
		await _shot("03b_planned")
		c.undo()
	c.clear_selection()
	await _frames(4)
	var mk: CardData = db.get_card(&"marksman")
	if mk != null:
		c.open_card_inspector(mk, "player", "")
		await _frames(8)
		await _shot("04_inspector")
		m.get_inspector().close()
		await _frames(4)
	c.open_pause_menu()
	await _frames(10)
	await _shot("01b_pause_menu")
	await _close(m)
	# --- Run map, Loadout, After-Action.
	rs.start_run(4242)
	var lo: Control = await _open("res://scenes/run/Loadout.tscn")
	await _shot("06_loadout")
	var st0: Control = lo.get_starter() if lo.has_method(&"get_starter") else null
	if st0 != null:
		st0.close()
		await _frames(6)
		await _shot("06b_loadout_modifiers")
	await _close(lo)
	rs.begin_run()
	var rm: Control = await _open("res://scenes/run/RunMap.tscn")
	await _shot("05_run_map")
	await _close(rm)
	if rs.run.map != null:
		var reach: Array = rs.run.map.reachable()
		for id: StringName in reach:
			if rs.run.map.node(id)["type"] == &"fight" or id == reach[-1]:
				rs.move_to(id)
				break
	var res: Dictionary = rs.record_result(&"player", {"reason": &"target", "rounds": 6, "player_score": 6, "enemy_score": 3})
	print("record_result: ", res.get("ok"), " ", res.get("reason", ""))
	var aa: Control = await _open("res://scenes/run/AfterAction.tscn")
	await _shot("09_after_action")
	await _close(aa)
	rs.abandon_run()
	quit(0)
