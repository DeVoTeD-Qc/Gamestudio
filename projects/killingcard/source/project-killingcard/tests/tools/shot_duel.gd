# shot_duel.gd
# Purpose: Dev tool (kc-duel-ui): screenshots of every Duel screen (public art only) at the window size it
#   is started with: the Title (DUEL entry), the hub (My decks, Presets), the VS AI and Pass & Play
#   setups, the deck builder (empty, mid-build with red / amber lines, full READY, the tray open in
#   portrait, a locked card, the hero and Doctrine pickers, a card inspector), the pass-and-play cover
#   and the result screen.
# Usage: xvfb-run -a -s "-screen 0 1280x1024x24" godot --path . --rendering-driver opengl3 \
#          --resolution 844x390 -s res://tests/tools/shot_duel.gd -- <out_dir> [prefix] [only]
# Author: UI/UX Agent (kc-duel-ui)
extends SceneTree

const DuelViews: GDScript = preload("res://scripts/ui/duel/duel_views.gd")
const DuelFlow: GDScript = preload("res://scripts/ui/duel/duel_flow.gd")

var _out: String = ""
var _prefix: String = ""
var _only: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_out.path_join(_prefix + name + ".png"))
	print("shot ", _prefix + name, " ", img.get_size())


func _want(key: String) -> bool:
	return _only == "" or _only.split(",").has(key)


func _open(path: String) -> Control:
	var s: Control = (load(path) as PackedScene).instantiate()
	root.add_child(s)
	await _frames(10)
	await create_timer(0.3).timeout
	return s


func _close(s: Control) -> void:
	root.remove_child(s)
	s.queue_free()
	await _frames(2)


func _sample_deck(n: int) -> Dictionary:
	var d: Dictionary = DuelViews.new_deck(&"bastion_60")
	d["name"] = "Iron Wall copy"
	var ids: Array = [&"rifleman", &"breacher", &"gunner", &"marksman", &"demolitions_expert", &"ammo_resupply",
			&"suppressing_fire", &"mortar_pit", &"okafor_anvil", &"hold_the_line"]
	for i: int in n:
		d["picks"].append(DuelViews.make_pick(ids[i], &"heavy"))
	d["doctrine"] = &"heavy"
	return d


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else ""
	_only = args[2] if args.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var router: Node = root.get_node("SceneRouter")
	router.dry_run = true
	DuelFlow.set_dry_run(true)
	DuelViews.set_local_saves(true)
	DuelViews.reset_local()
	# A fresh player: Fields and Elites not found yet, except Mortar Pit.
	for e: Dictionary in DuelViews.pool():
		var c: CardData = e["card"]
		if DuelViews.needs_unlock(c):
			DuelViews.owned_override[c.id] = c.id == &"mortar_pit"
	DuelViews.owned_override[&"okafor_anvil"] = true
	# kc-da-ui3: `-- <out> <prefix> <only> demo` shows a fresh profile with the demo collection instead.
	if args.size() > 3 and args[3] == "demo":
		DuelViews.owned_override.clear()
		var st: Node = root.get_node("Settings")
		st.persist = false
		st.run_profile = RunProfile.blank()
		st.found_arts = {}
		root.get_node("RunState").apply_demo_collection()
	DuelViews.save_deck(_sample_deck(10))
	var part: Dictionary = _sample_deck(8)
	part["name"] = "Night shift"
	part["hero"] = &"wasp_9"
	DuelViews.save_deck(part)
	if _want("title"):
		var t: Control = await _open("res://scenes/Title.tscn")
		await _shot("01_title_duel_entry")
		await _close(t)
	if _want("hub"):
		DuelFlow.set_hub_tab("mine")
		var h: Control = await _open(DuelFlow.SCENE_HUB)
		await _shot("02_hub_my_decks")
		h.call(&"set_tab", "presets")
		await _shot("03_hub_presets")
		h.call(&"open_vs_ai", "preset_none")
		await _frames(4)
		await _shot("04_hub_vs_ai_setup")
		h.call(&"open_hot_seat")
		await _frames(4)
		await _shot("05_hub_pass_and_play_setup")
		await _close(h)
	if _want("builder"):
		DuelFlow.set_edit_deck(DuelViews.new_deck())
		var b: Control = await _open(DuelFlow.SCENE_BUILDER)
		await _shot("06_builder_empty")
		await _close(b)
		var mid: Dictionary = _sample_deck(6)
		mid["picks"].append(DuelViews.make_pick(&"halek_wren", &""))
		DuelFlow.set_edit_deck(mid)
		b = await _open(DuelFlow.SCENE_BUILDER)
		b.call(&"add_card", &"breach_and_clear")
		await _frames(4)
		await _shot("07_builder_mid_red_amber")
		if b.get(&"portrait"):
			b.call(&"set_tray_open", true)
			await _frames(4)
			await _shot("08_builder_tray_open")
		await _close(b)
		DuelFlow.set_edit_deck(_sample_deck(10))
		b = await _open(DuelFlow.SCENE_BUILDER)
		await _shot("09_builder_ready")
		b.call(&"add_card", &"war_standard")
		await _frames(2)
		await _shot("10_builder_locked_refused")
		b.call(&"open_hero_picker")
		await _frames(4)
		await _shot("11_builder_hero_picker")
		for c: Node in b.get_children():
			if c.name == "HeroPicker":
				c.free()
		b.call(&"open_doctrine_picker")
		await _frames(4)
		await _shot("12_builder_doctrine_picker")
		for c: Node in b.get_children():
			if c.name == "DoctrinePicker":
				c.free()
		b.call(&"inspect_card", &"gunner")
		await _frames(6)
		await _shot("13_builder_inspect_card")
		await _close(b)
	if _want("match"):
		var r1: Dictionary = DuelFlow.start_match({"mode": DuelFlow.MODE_VS_AI, "decks": [DuelViews.preset("spearhead"), DuelViews.preset("iron_wall")],
				"names": ["You", "Iron Wall"], "tier": &"recruit", "opponent_id": "iron_wall", "seed": 7})
		print("vs ai: ", r1)
		var ms: Control = await _open("res://scenes/Match.tscn")
		var mc: Node = ms.get_node("MatchController")
		if mc.is_mulligan_open():
			mc.keep_hand()
		await _frames(6)
		await _shot("16_match_vs_ai_recruit")
		await _close(ms)
		var r2: Dictionary = DuelFlow.start_match({"mode": DuelFlow.MODE_HOT_SEAT, "decks": [DuelViews.preset("overwatch"), DuelViews.preset("hollow_ranks")],
				"names": ["Alex", "Dana"], "seed": 11})
		print("hot seat: ", r2)
		ms = await _open("res://scenes/Match.tscn")
		mc = ms.get_node("MatchController")
		await _shot("17_match_hot_seat_cover")
		mc.get_cover().accept()
		await _frames(4)
		if mc.is_mulligan_open():
			mc.keep_hand()
		await _frames(4)
		await _shot("18_match_hot_seat_first_deploy")
		await mc.press_ready()
		await _frames(4)
		await _shot("19_match_hot_seat_pass_cover")
		await _close(ms)
	if _want("cover"):
		var m: Control = await _open("res://scenes/duel/PassCover.tscn")
		m.call(&"show_for", 1, "Dana", {"round": 3, "other_name": "Alex", "other_orders": 3,
				"last": "Round 2: you took column B (4-3); Alex leads Zone Control 3-2."})
		await _frames(4)
		await _shot("14_pass_cover")
		await _close(m)
	if _want("result"):
		var setup: Dictionary = {"mode": DuelFlow.MODE_VS_AI, "decks": [_sample_deck(10), DuelViews.preset("spearhead")],
				"names": ["You", "Spearhead"], "tier": &"regular", "opponent_id": "spearhead"}
		DuelFlow.set_setup(setup)
		var last: Dictionary = {"ok": true, "result": {"kind": &"ai", "tier": &"regular", "ended": true, "winner_side": 0,
				"reason": &"target", "rounds": 6, "scores": [6, 4], "names": ["You", "Spearhead"],
				"deck_names": ["Iron Wall copy", "Spearhead"], "heroes": [&"bastion_60", &"kestrel_ar7"], "human_won": true,
				"winner_name": "You"}, "records": {"heroes": {&"bastion_60": {"w": 3, "l": 1, "d": 0}},
				"vs_ai": {"spearhead": {&"regular": {"w": 2, "l": 1, "d": 0}}}, "hot_seat_games": 1,
				"duelist_frames": [&"bastion_60"], "veteran_stamps": []},
				"new_cosmetics": [{"kind": &"duelist_frame", "id": &"bastion_60", "name": "Duelist frame: Bastion-60", "text": "Your first duel win with Bastion-60."}],
				"setup": setup}
		DuelFlow.set_last_result(last)
		var r: Control = await _open(DuelFlow.SCENE_RESULT)
		await _shot("15_result_win")
		await _close(r)
	quit(0)
