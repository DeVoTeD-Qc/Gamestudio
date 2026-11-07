# shot_ipad.gd
# Purpose: Dev tool (kc-ipad-cards): before / after shots of the match (public art only) at any
#   window size: the full screen, the hand tray (2x), a Y2+ card from the hand (the dock) and the board.
# Usage: xvfb-run -a -s "-screen 0 1024x768x24" godot --path . --rendering-driver opengl3 \
#          --resolution 1024x768 -s res://tests/tools/shot_ipad.gd -- <out_dir> <prefix> [n_hand] [top]
#   `top`: board abilities top-right (BannerView.ABILITIES_BOTTOM = false) for the comparison shots.
# Author: UI/UX Agent (kc-ipad-cards)
extends SceneTree

var _out: String = ""
var _prefix: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(name: String, crop: Rect2 = Rect2(), zoom: int = 1) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if crop.has_area():
		var k: float = img.get_width() / float(root.get_visible_rect().size.x)
		img = img.get_region(Rect2i(crop.position * k, crop.size * k))
		img.resize(img.get_width() * zoom, img.get_height() * zoom, Image.INTERPOLATE_LANCZOS)
	img.save_png(_out.path_join("%s_%s.png" % [_prefix, name]))
	print("shot ", name, " ", img.get_size())


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else "shot"
	var n_hand: int = int(args[2]) if args.size() > 2 else 7
	if args.size() > 3 and args[3] == "top":
		BannerView.ABILITIES_BOTTOM = false
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	root.get_node("Settings").persist = false
	NewCard.auto_show = false
	var db: Node = root.get_node("CardDB")
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(30)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
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
	# Calling cards in hand too (the starter is all Standard Issue), up to n_hand cards.
	# Calling cards first (the Marksman, the Gunner ...), then the starter's cards, n_hand in all.
	var extra: Array[StringName] = [&"marksman", &"gunner", &"breacher", &"combat_medic", &"flanker"]
	var hand: Array = st.sides[0].hand
	var starters: Array = hand.duplicate()
	hand.clear()
	for id: StringName in extra:
		var cd2: CardData = db.get_card(id)
		if cd2 != null and hand.size() < n_hand - 2:
			hand.append(RulesCard.new(st.new_uid(), cd2))
	for rc0: RulesCard in starters:
		if hand.size() < n_hand:
			hand.append(rc0)
	c.refresh()
	await create_timer(2.0).timeout
	await _frames(4)
	await _shot("full")
	await _shot("tray_2x", m.get_tray().get_global_rect(), 2)
	await _shot("board_2x", m.get_board().get_global_rect(), 2)
	# Select a unit (the Marksman when in hand): its Y2+ card docks over the tray.
	var pick: RulesCard = null
	for rc: RulesCard in hand:
		if rc.card.is_unit() and (pick == null or rc.card.id == &"marksman"):
			pick = rc
	if pick != null:
		c.select_card(pick.uid)
	await _frames(20)
	await _shot("dock")
	quit()
