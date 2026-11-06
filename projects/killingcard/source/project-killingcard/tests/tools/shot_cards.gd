# shot_cards.gd
# Purpose: Dev tool (kc-cards-impl): phone-size screenshots of the new cards, public art only:
#   board at rest, board peek, rail highlight, H1 selected with PLAY HERE, mulligan, reward (Supply
#   Drop), Codex, a Tactic (the T1 orders frame next to units).
# Usage: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1168x540 \
#          -s res://tests/tools/shot_cards.gd -- <out_dir>
# Author: UI/UX Agent (kc-cards-impl)
extends SceneTree

var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("shot ", name)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	# PUBLIC art only (screenshots go into the public repo).
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var settings: Node = root.get_node("Settings")
	settings.persist = false
	NewCard.auto_show = false  # no "New:" explainer over the shots
	# --- Match: mulligan, then a few rounds so both sides have units.
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(30)
	await create_timer(1.0).timeout
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		await _shot("05_mulligan")
		c.keep_hand()
	# A staged board (public art): both sides, a lit set (Vanguard x2), a damaged unit, a Recruit.
	var st: MatchState = c.state
	var db: Node = root.get_node("CardDB")
	var own: Array = [[&"breacher", 0, &"vanguard"], [&"point_man", 0, &"vanguard"], [&"marksman", 1, &"specops"], [&"gunner", 2, &"heavy"],
			[&"si_trooper", 1, &""]]
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
	await _frames(4)
	# One damaged unit (yours, column C) and one damaged rival.
	for lane_units: Array in [st.sides[0].line(2), st.sides[1].line(1)]:
		if not lane_units.is_empty():
			(lane_units[0] as RulesUnit).armor = maxi(1, (lane_units[0] as RulesUnit).armor - 2)
	c.refresh()
	# Let the placement slides finish (they run on timers, not frames).
	await create_timer(2.0).timeout
	await _frames(4)
	await _shot("01_board_at_rest")
	# Peek: the first friendly unit and one rival.
	var board: Control = m.get_board()
	for lane: Node in board.get_lanes():
		for slot: Node in lane.get_friendly_slots() + lane.get_enemy_slots():
			if slot.kind == slot.Kind.UNIT:
				(slot.get(&"banner") as BannerView).peek = true
				break
	await _frames(3)
	await _shot("02_board_peek")
	for lane: Node in board.get_lanes():
		lane.set_peek(null)
		for slot: Node in lane.get_friendly_slots() + lane.get_enemy_slots():
			(slot.get(&"banner") as BannerView).peek = false
	# Rail highlight: pin the first trait of the rail.
	var rail: Control = m.get_trait_rail()
	var t: StringName = &""
	for e: Dictionary in rail.rails.get(&"player", []):
		t = StringName(e.get("trait", &""))
		break
	if t == &"":
		t = &"vanguard"
	rail.pin(t)
	await _frames(3)
	await _shot("03_rail_highlight")
	rail.pin(&"")
	await _frames(2)
	# H1: select a unit you can pay for.
	var me2: RulesSide = c.state.sides[0]
	var pick: RulesCard = null
	for rc: RulesCard in me2.hand:
		if rc.card.is_unit() and (pick == null or rc.card.cost < pick.card.cost):
			pick = rc
	if pick != null:
		c.select_card(pick.uid)
	await _frames(6)
	await _shot("04_h1_selected_play_here")
	c.clear_selection()
	m.queue_free()
	await _frames(4)
	# --- Reward: a run with a won match (Supply Drop).
	var rs: Node = root.get_node("RunState")
	rs.start_run(4242)
	rs.begin_run()
	rs.record_result(&"player", {"reason": &"target", "rounds": 6, "player_score": 6, "enemy_score": 3})
	var reward: Control = (load("res://scenes/run/Reward.tscn") as PackedScene).instantiate()
	root.add_child(reward)
	await _frames(12)
	await _shot("06_reward")
	reward.queue_free()
	rs.abandon_run()
	await _frames(4)
	# --- Codex.
	var title: Control = (load("res://scenes/Title.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await _frames(10)
	title.open_codex()
	await _frames(10)
	await _shot("07_codex")
	title.queue_free()
	await _frames(4)
	# --- A Tactic (T1 orders frame) between units, at the reward size.
	var bg := ColorRect.new()
	bg.color = Color("#14181C")
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cards: Array[Dictionary] = []
	for id: StringName in [&"marksman", &"ammo_resupply", &"breacher"]:
		var cd: CardData = root.get_node("CardDB").get_card(id)
		if cd != null:
			cards.append(CardView.view_for_card(cd, &"", 0 if id == &"breacher" else 1))
	var x: float = 40.0
	for v: Dictionary in cards:
		var cv: CardView = (load("res://scenes/match/CardView.tscn") as PackedScene).instantiate()
		bg.add_child(cv)
		cv.set_card_data(v)
		cv.set_card_width(250)
		cv.position = Vector2(x, 120)
		x += 270.0
	var lbl := Label.new()
	lbl.text = "Y2+ cards: a unit, a Tactic in the T1 orders frame, a Recruit (Trains: line)"
	lbl.position = Vector2(40, 60)
	lbl.add_theme_font_size_override(&"font_size", 20)
	bg.add_child(lbl)
	await _frames(6)
	await _shot("08_tactic_t1")
	quit()
