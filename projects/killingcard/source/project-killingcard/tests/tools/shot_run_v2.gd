# shot_run_v2.gd
# Purpose: Dev tool (kc-v2-ui): screenshots of every Run v2 screen (public art only) at the window size
#   it is started with: the run map (path choice, boss plate), a node inspect, the Event, the Shop,
#   the Rest, the Loadout (Operator select with kits and modifiers), the match with Terrain on the
#   columns, the ability button (ready, targeting, used), the match intro (Terrain and the boss).
#   Run v2 views come from the rules when they exist, else the spec's sample views (run_v2_views.gd).
# Usage: xvfb-run -a -s "-screen 0 1280x1024x24" godot --path . --rendering-driver opengl3 \
#          --resolution 844x390 -s res://tests/tools/shot_run_v2.gd -- <out_dir> [prefix] [only]
# Author: UI/UX Agent (kc-v2-ui)
extends SceneTree

const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")

var _out: String = ""
var _prefix: String = ""
var _only: String = ""


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


func _want(key: String) -> bool:
	return _only == "" or _only.split(",").has(key)


func _open(path: String) -> Control:
	var s: Control = (load(path) as PackedScene).instantiate()
	root.add_child(s)
	await _frames(12)
	await create_timer(0.4).timeout
	return s


func _close(s: Control) -> void:
	root.remove_child(s)
	s.queue_free()
	await _frames(2)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else ""
	_only = args[2] if args.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var settings: Node = root.get_node("Settings")
	settings.persist = false
	NewCard.auto_show = false
	var rs: Node = root.get_node("RunState")
	rs.autosave = false
	rs.start_run(4242)
	root.get_node("SceneRouter").dry_run = true
	RunV2Views.preview_map(RunV2Views.sample_map_view(2, 0))
	if _want("map"):
		var m: Control = await _open("res://scenes/run/RunMap.tscn")
		await _shot("01_run_map")
		var v: Control = m.get_map_view()
		v.select("s9l1")
		await _frames(4)
		await _shot("02_run_map_boss_brief")
		m.get_inspector().open(v.node_info(v.map, RunV2Views.node_by_id(v.map, "s3l0")))
		await _frames(6)
		await _shot("03_run_map_inspect_node")
		await _close(m)
	if _want("event"):
		RunV2Views.preview_event(RunV2Views.sample_event_view())
		var e: Control = await _open("res://scenes/run/Event.tscn")
		e.pick(0)
		await _frames(4)
		await _shot("04_event_picked")
		e.confirm()
		await create_timer(0.5).timeout
		await _shot("05_event_result")
		await _close(e)
	if _want("shop"):
		RunV2Views.preview_shop(RunV2Views.sample_shop_view())
		var s: Control = await _open("res://scenes/run/Shop.tscn")
		await _shot("06_shop")
		s.buy(0)
		await create_timer(0.5).timeout
		await _shot("07_shop_bought")
		s.get_service_tile(&"muster").pressed.emit()
		await _frames(6)
		var pk: Control = s.get_picker()
		var shown: int = 0
		for idx: int in range(0, 40):
			if pk.get_tile(idx) != null and shown < 2:
				pk.toggle(idx)
				shown += 1
		await _frames(4)
		await _shot("08_shop_muster_picker")
		await _close(s)
	if _want("rest"):
		RunV2Views.preview_rest(RunV2Views.sample_rest_options())
		var rr: Control = await _open("res://scenes/run/Rest.tscn")
		rr.pick(0)
		await _frames(4)
		await _shot("09_rest_picked")
		await _close(rr)
	if _want("leave"):
		RunV2Views.clear_overrides()
		RunV2Views.preview_event({"id": &"memorial", "title": "Memorial Wall", "scene": "Names in marker on a blast wall, someone's tags hung on a nail.",
				"options": [{"index": 0, "label": "PAY RESPECTS", "result": "+1 ticket (max 3).", "ok": false, "reason": "Tickets are full"},
					{"index": 1, "label": "CARRY THEIR TAGS", "result": "Copy one calling card in your deck (same trait).", "ok": false, "reason": "No calling card in your deck"}]})
		var le: Control = await _open("res://scenes/run/Event.tscn")
		await create_timer(0.5).timeout
		await _shot("19_event_leave")
		await _close(le)
	RunV2Views.clear_overrides()
	if _want("loadout"):
		var lo: Control = await _open("res://scenes/run/Loadout.tscn")
		await _frames(6)
		await _shot("10_loadout_operator_select")
		var st0: Control = lo.get_starter()
		if st0 != null:
			st0.close()
		await _frames(6)
		await _shot("11_loadout_modifiers_boss")
		await _close(lo)
	if _want("match"):
		await _match_shots()
	quit(0)


func _match_shots() -> void:
	var db: Node = root.get_node("CardDB")
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(30)
	await create_timer(1.0).timeout
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	var st: MatchState = c.state
	var own: Array = [[&"breacher", 0], [&"point_man", 0], [&"marksman", 1], [&"gunner", 2]]
	var rival: Array = [[&"flanker", 0], [&"rifleman", 1], [&"combat_medic", 1], [&"si_grunt", 2]]
	for side_list: Array in [[0, own], [1, rival]]:
		for row: Array in side_list[1]:
			var cd: CardData = db.get_card(row[0])
			if cd != null:
				st.put_in_line(st.create_unit(int(side_list[0]), cd), int(row[1]))
	# Run v2: Terrain on A and C, Kestrel's Dig In, the Meridian_Six boss rule.
	st.terrain[0] = &"smoke"
	st.terrain[2] = &"supply_cache"
	var me: RulesSide = st.sides[0]
	me.kit_on = true
	if ResourceLoader.exists("res://data/loadout/ab_dig_in.tres"):
		me.ability = load("res://data/loadout/ab_dig_in.tres")
	st.boss_id = &"meridian"
	st.boss_rule = &"reinforcements"
	st.boss_name = "Meridian_Six"
	st.boss_rule_name = "Reinforcements"
	st.boss_rule_text = "From round 4, gains 1 extra Supply every round."
	m.intro_node = {"type": &"boss", "crew": "Meridian_Six"}
	m.set(&"_intro_shown", false)
	c.refresh()
	await create_timer(0.8).timeout
	await _shot("12_match_intro_boss_terrain")
	m.get_match_intro().close()
	await create_timer(1.0).timeout
	await _frames(4)
	await _shot("13_match_terrain_ability_ready")
	c.use_ability()
	await _frames(6)
	await _shot("14_ability_aim")
	c.play_at(1)
	await _frames(6)
	await _shot("15_ability_planned")
	c.undo()
	me.uses_this_match[me.ability.id if me.ability != null else &"x"] = 1
	c.refresh()
	await _frames(6)
	await _shot("16_ability_used")
	c.call(&"_open_terrain", 0)
	await _frames(8)
	await _shot("17_terrain_inspect")
	m.get_inspector().close()
	c.open_ability_inspector()
	await _frames(8)
	await _shot("18_ability_inspect")
	m.get_inspector().close()
	root.remove_child(m)
	m.queue_free()
