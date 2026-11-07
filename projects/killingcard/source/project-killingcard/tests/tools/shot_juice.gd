# shot_juice.gd
# Purpose: Dev tool (kc-juice): a frame sequence of one firefight round on the live match screen
#   (public art only), with the juice on ("after") or with REDUCE MOTION on ("calm": no shake, no
#   hit-stop, no stamp punch / flash), for the before / after comparison. Units are put on the board
#   for both sides, one card is played from the hand (the calling-card stamp + Supply spend), then
#   READY plays the round at x1. Frames are taken at `fps` into <out_dir>/<prefix>_NNNN.png, and
#   each juice moment (hit-stop, shake, card stamp, column win) also gets a named key frame.
# Usage: xvfb-run -a -s "-screen 0 844x390x24" godot --path . --rendering-driver opengl3 \
#          --resolution 844x390 -s res://tests/tools/shot_juice.gd -- <out_dir> <prefix> [after|calm] [fps] [seconds]
# Author: Game Feel Engineer Agent (kc-juice)
extends SceneTree

const CardLandFx: GDScript = preload("res://scripts/fx/card_land_fx.gd")

var _out: String = ""
var _prefix: String = ""
var _n: int = 0
var _keys: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png(_out.path_join("%s_%s.png" % [_prefix, name]))


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://juice"
	_prefix = args[1] if args.size() > 1 else "after"
	var calm: bool = args.size() > 2 and args[2] == "calm"
	var fps: float = float(args[3]) if args.size() > 3 else 12.0
	var seconds: float = float(args[4]) if args.size() > 4 else 14.0
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var settings: Node = root.get_node("Settings")
	settings.persist = false
	settings.set_value(&"fast_animations", false)
	settings.set_value(&"speed_x2", false)
	settings.set_value(&"speed_chosen", true)
	settings.set_value(&"screen_shake", true)
	settings.set_value(&"reduced_motion", calm)
	NewCard.auto_show = false
	var db: Node = root.get_node("CardDB")
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(30)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	var st: MatchState = c.state
	var own: Array = [[&"breacher", 0], [&"gunner", 1], [&"marksman", 1], [&"rifleman", 2]]
	var rival: Array = [[&"si_grunt", 0], [&"rifleman", 1], [&"flanker", 2]]
	for side_list: Array in [[0, own], [1, rival]]:
		for row: Array in side_list[1]:
			var cd: CardData = db.get_card(row[0])
			if cd != null:
				st.put_in_line(st.create_unit(int(side_list[0]), cd), int(row[1]))
	st.sides[0].supply = maxi(st.sides[0].supply, 4)
	c.refresh()
	await _frames(90)
	var fx: Control = m.get_fx()
	fx.fx_started.connect(func(kind: StringName, _node: Object, _d: float) -> void:
		if kind in [&"hitstop", &"shake", &"column_win"]:
			_key(String(kind)))
	# The calling-card stamp: play the first affordable unit card from the hand to column A.
	var stamps0: int = CardLandFx.stamps.size()
	for rc: RulesCard in st.sides[0].hand.duplicate():
		if rc.card.card_type == DataEnums.CardType.UNIT and rc.card.cost <= st.sides[0].supply and not rc.card.arrives_front:
			c.select_card(rc.uid)
			print("play ", rc.card.id, " -> ", c.play_at(0)["ok"])
			break
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900:
		if CardLandFx.stamps.size() > stamps0 and not _keys.has("stamp"):
			_key("stamp")
		await _shoot(fps)
	c.press_ready()
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0) and (c.is_busy() or Time.get_ticks_msec() - t0 < 1000):
		await _shoot(fps)
	print("frames ", _n, " keys ", _keys.keys())
	quit()


## One sequence frame, then waits out the rest of 1/fps.
func _shoot(fps: float) -> void:
	await RenderingServer.frame_post_draw
	_save("%04d" % _n)
	_n += 1
	var wait_until: int = Time.get_ticks_msec() + int(1000.0 / fps)
	while Time.get_ticks_msec() < wait_until:
		await process_frame


## A named key frame of a juice moment (the first one of each kind, two frames in).
func _key(kind: String) -> void:
	if _keys.has(kind):
		return
	_keys[kind] = true
	await process_frame
	await RenderingServer.frame_post_draw
	_save("key_%s" % kind)
