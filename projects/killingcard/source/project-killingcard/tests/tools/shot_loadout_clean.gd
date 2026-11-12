# shot_loadout_clean.gd
# Purpose: Dev tool (kc-loadout-clean): screenshots of the screens the head flagged, at the window
#   size it is started with: the LOADOUT (killstreak picks, operator line, boss line, modifiers), the
#   run map's YOUR DECK view, and the battle HUD with the Operator deployed (its hand card is the
#   ability button), an Agile unit that can move (move icon) and READY / UNDO in the bottom row.
#   Public art only unless "pitch" is passed (BannerArtDB.licensed_enabled stays as the build has it).
# Usage: xvfb-run -a -s "-screen 0 2000x1200x24" godot --path . --rendering-driver opengl3 \
#          --resolution 1366x1024 -s res://tests/tools/shot_loadout_clean.gd -- <out_dir> <prefix> [only] [pitch]
#   only: comma list of loadout, deck, hud (default all).
# Author: UI/UX Agent (kc-loadout-clean)
extends SceneTree

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
	_only = args[2] if args.size() > 2 and args[2] != "all" else ""
	var pitch: bool = args.size() > 3 and args[3] == "pitch"
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	if not pitch:
		BannerArtDB.licensed_enabled = false
		BannerArtDB.clear_cache()
	var settings: Node = root.get_node("Settings")
	settings.persist = false
	NewCard.auto_show = false
	var rs: Node = root.get_node("RunState")
	rs.autosave = false
	rs.start_run(4242)
	root.get_node("SceneRouter").dry_run = true
	if _want("loadout"):
		var lo: Control = await _open("res://scenes/run/Loadout.tscn")
		var st0: Control = lo.get_starter()
		if st0 != null:
			await _frames(4)
			await _shot("starter")
			st0.close()
		await _frames(8)
		await _shot("loadout")
		await _close(lo)
	if _want("deck"):
		var m: Control = await _open("res://scenes/run/RunMap.tscn")
		var dv: Control = m.get_engine_view()
		if dv != null:
			dv.open(rs.run)
			await _frames(10)
			await create_timer(0.3).timeout
			await _shot("deck")
		await _close(m)
	if _want("hud"):
		await _hud()
	quit(0)


func _hud() -> void:
	var db: Node = root.get_node("CardDB")
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(30)
	await create_timer(1.0).timeout
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	var st: MatchState = c.state
	var me: RulesSide = st.sides[0]
	var runner: RulesUnit = null
	for row: Array in [[0, &"kc_wip_runner", 0], [0, &"marksman", 2], [1, &"rifleman", 1], [1, &"flanker", 0]]:
		var cd: CardData = db.get_card(row[1])
		if cd != null:
			var u: RulesUnit = st.create_unit(int(row[0]), cd)
			st.put_in_line(u, int(row[2]))
			if row[1] == &"kc_wip_runner":
				runner = u
	# The Operator on the board (column B), with a once-per-match ability ready.
	if me.operator_unit != null:
		st.put_in_line(me.operator_unit, 1)
		me.operator_can_deploy = false
	me.kit_on = true
	if ResourceLoader.exists("res://data/loadout/ab_dig_in.tres"):
		me.ability = load("res://data/loadout/ab_dig_in.tres")
	m.set(&"_intro_shown", true)
	c.refresh()
	await create_timer(1.0).timeout
	await _frames(6)
	if m.get_match_intro() != null and m.get_match_intro().visible:
		m.get_match_intro().close()
		await create_timer(0.6).timeout
	await _shot("hud")
	# A drag of the Agile Runner (MOVE chip) over column B: the legal columns light up.
	if runner != null and c.has_method(&"_on_unit_drag_started"):
		var lanes: Array = m.get_board().get_lanes()
		var from: Vector2 = (lanes[0] as Control).get_global_rect().get_center()
		var over: Vector2 = (lanes[1] as Control).get_global_rect().get_center()
		c._on_unit_drag_started(0, runner.uid, from)
		c._on_drag_moved(-1, over)
		await _frames(6)
		await _shot("hud_drag")
		c._on_drag_ended(over)
		await _frames(4)
	root.remove_child(m)
	m.queue_free()
