# shot_ks.gd
# Purpose: Dev tool (kc-ks-seq): a frame sequence of the killstreak flow on the live match screen
#   (public art only) for the before / after comparison. Round 1 Deploy: the player calls Mortar
#   Barrage on column B (banner + INCOMING marker), the rival has an Attack Helo and a Sentry Turret
#   called; READY plays Reveal (rival banners, the Sentry drop), then Firefight step 0 (helo strafe,
#   mortar shells, damage numbers, the log line) and the fight. Frames at `fps` go to
#   <out_dir>/<prefix>_NNNN.png; the first frame of each killstreak moment is also saved as
#   <prefix>_key_<kind>.png. Works on the pre-kc-ks-seq build too (it only uses the controller API).
# Usage: xvfb-run -a -s "-screen 0 844x390x24" godot --path . --rendering-driver opengl3 \
#          --resolution 844x390 -s res://tests/tools/shot_ks.gd -- <out_dir> <prefix> [fps] [seconds] [fast]
# Author: Game Feel Engineer Agent (kc-ks-seq)
extends SceneTree

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
	_out = args[0] if args.size() > 0 else "user://ks"
	_prefix = args[1] if args.size() > 1 else "after"
	var fps: float = float(args[2]) if args.size() > 2 else 8.0
	var seconds: float = float(args[3]) if args.size() > 3 else 16.0
	var fast: bool = args.size() > 4 and args[4] == "fast"
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	var settings: Node = root.get_node("Settings")
	settings.persist = false
	settings.set_value(&"fast_animations", fast)
	settings.set_value(&"speed_x2", false)
	settings.set_value(&"speed_chosen", true)
	settings.set_value(&"reduced_motion", false)
	NewCard.auto_show = false
	var db: Node = root.get_node("CardDB")
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await _frames(30)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	var st: MatchState = c.state
	var own: Array = [[&"breacher", 0], [&"gunner", 1], [&"rifleman", 2]]
	var rival: Array = [[&"si_grunt", 0], [&"rifleman", 1], [&"si_trooper", 1], [&"flanker", 2]]
	for side_list: Array in [[0, own], [1, rival]]:
		for row: Array in side_list[1]:
			var cd: CardData = db.get_card(row[0])
			if cd != null:
				st.put_in_line(st.create_unit(int(side_list[0]), cd), int(row[1]))
	# Killstreaks: the player's Mortar is earned; the rival calls an Attack Helo and a Sentry Turret.
	StreakTracker.grant(st, 0, &"mortar_barrage")
	var foe: RulesSide = st.sides[1]
	for id: StringName in [&"attack_helo", &"sentry_turret"]:
		var item: LoadoutItem = db.get_loadout_item(id)
		if item != null and item not in foe.setup.killstreaks:
			foe.setup.killstreaks.append(item)
		StreakTracker.grant(st, 1, id)
	var was_ready: bool = foe.ready
	foe.ready = false
	print("rival helo ", st.submit(1, RulesIntent.use_item(&"attack_helo"))["ok"])
	print("rival sentry ", st.submit(1, RulesIntent.use_item(&"sentry_turret", 2))["ok"])
	foe.ready = was_ready
	c.refresh()
	await _frames(60)
	var fx: Control = m.get_fx()
	fx.fx_started.connect(func(kind: StringName, _node: Object, _d: float) -> void:
		if kind in [&"ks_banner", &"ks_queued", &"shells", &"strafe", &"drop", &"scan", &"takeover", &"killfeed", &"damage_number"]:
			_key(String(kind)))
	_save("deploy")
	c.select_item(&"mortar_barrage")
	await _frames(10)
	_save("targeting")
	print("mortar -> ", c.play_at(1)["ok"])
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2200:
		await _shoot(fps)
	_save("called")
	c.press_ready()
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0) and (c.is_busy() or Time.get_ticks_msec() - t0 < 1000):
		await _shoot(fps)
	await _frames(20)
	_save("after_round")
	print("frames ", _n, " keys ", _keys.keys())
	quit()


func _shoot(fps: float) -> void:
	await RenderingServer.frame_post_draw
	_save("%04d" % _n)
	_n += 1
	var wait_until: int = Time.get_ticks_msec() + int(1000.0 / fps)
	while Time.get_ticks_msec() < wait_until:
		await process_frame


## The first frame of each moment, a few frames in.
func _key(kind: String) -> void:
	if _keys.has(kind):
		return
	_keys[kind] = true
	await _frames(6)
	await RenderingServer.frame_post_draw
	_save("key_%s" % kind)
