# shot_portrait.gd
# Purpose: Dev tool (kc-portrait): iPhone portrait screenshots (public art only): the match at rest,
#   a card raised into the preview well, PLAY HERE (2x crop of the board), the mulligan, the Supply
#   Drop and the run map.
# Usage: xvfb-run -a -s "-screen 0 390x844x24" godot --path . --rendering-driver opengl3 \
#          --resolution 390x844 -s res://tests/tools/shot_portrait.gd -- <out_dir>
# Author: UI/UX Agent (kc-portrait)
extends SceneTree

var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(name: String, crop: Rect2 = Rect2()) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if crop.has_area():
		var k: float = img.get_width() / float(root.get_visible_rect().size.x)
		img = img.get_region(Rect2i(crop.position * k, crop.size * k))
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	img.save_png(_out.path_join(name + ".png"))
	print("shot ", name, " ", img.get_size())


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var settings: Node = root.get_node("Settings")
	settings.persist = false
	NewCard.auto_show = false
	var db: Node = root.get_node("CardDB")
	# --- Match.
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(30)
	await create_timer(1.0).timeout
	var c: Node = m.get_node("%MatchController")
	print("portrait ", m.portrait, " size ", m.size)
	if c.is_mulligan_open():
		await _shot("04_mulligan")
		c.keep_hand()
	var st: MatchState = c.state
	var own: Array = [[&"breacher", 0, &"vanguard"], [&"point_man", 0, &"vanguard"], [&"marksman", 1, &"specops"], [&"gunner", 2, &"heavy"]]
	var rival: Array = [[&"flanker", 0, &"vanguard"], [&"rifleman", 1, &"specops"], [&"combat_medic", 1, &""], [&"si_grunt", 2, &""]]
	for side_list: Array in [[0, own], [1, rival]]:
		for row: Array in side_list[1]:
			var cd: CardData = db.get_card(row[0])
			if cd == null:
				continue
			var u: RulesUnit = st.create_unit(int(side_list[0]), cd)
			if row[2] != &"":
				u.synergy_trait = row[2]
			st.put_in_line(u, int(row[1]))
	c.refresh()
	await create_timer(2.0).timeout
	await _frames(4)
	await _shot("01_match_at_rest")
	var pick: RulesCard = null
	for rc: RulesCard in st.sides[0].hand:
		if rc.card.is_unit() and (pick == null or rc.card.cost < pick.card.cost):
			pick = rc
	if pick != null:
		c.select_card(pick.uid)
	await _frames(8)
	await _shot("02_card_raised")
	var br: Rect2 = m.get_board().get_global_rect()
	await _shot("03_play_here_2x", br)
	c.clear_selection()
	m.queue_free()
	await _frames(4)
	# --- Run: the run map, then a won match's Supply Drop.
	var rs: Node = root.get_node("RunState")
	rs.start_run(4242)
	var lo: Control = (load("res://scenes/run/Loadout.tscn") as PackedScene).instantiate()
	root.add_child(lo)
	await _frames(12)
	await _shot("09_loadout")
	lo.open_starter()
	await _frames(10)
	await _shot("10_starter_squad")
	lo.queue_free()
	await _frames(2)
	rs.begin_run()
	var map: Control = (load("res://scenes/run/RunMap.tscn") as PackedScene).instantiate()
	root.add_child(map)
	await _frames(12)
	await _shot("06_run_map")
	map.queue_free()
	await _frames(2)
	rs.record_result(&"player", {"reason": &"target", "rounds": 6, "player_score": 6, "enemy_score": 3})
	var reward: Control = (load("res://scenes/run/Reward.tscn") as PackedScene).instantiate()
	root.add_child(reward)
	await _frames(12)
	await create_timer(0.8).timeout
	await _frames(4)
	await _shot("05_reward")
	reward.queue_free()
	rs.abandon_run()
	await _frames(2)
	for scene: String in ["res://scenes/Title.tscn"]:
		var n: Control = (load(scene) as PackedScene).instantiate()
		root.add_child(n)
		await _frames(10)
		await _shot("07_" + scene.get_file().get_basename().to_lower())
		if scene.ends_with("Title.tscn"):
			n.open_codex()
			await _frames(8)
			await _shot("08_codex")
		n.queue_free()
		await _frames(2)
	quit()
