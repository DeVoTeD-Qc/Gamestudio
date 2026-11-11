# shot_layout_a.gd
# Purpose: Dev tool (kc-layout-a): one picture of the parts that are hard to catch in a match shot:
#   the objective tile's control plates (yours / rival / even / open, the head's L5) and the icon-table
#   fixes (Pick brackets; Pierce, Front line and Agile icons; the Supply hex) inline and on card plates.
# Usage: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 900x420 \
#          -s res://tests/tools/shot_layout_a.gd -- <out_dir>
# Author: UI/UX Agent (kc-layout-a)
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var bg := Panel.new()
	bg.theme = load("res://assets/ui/hud_theme.tres") as Theme
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#12161A")
	bg.add_theme_stylebox_override(&"panel", sb)
	bg.size = Vector2(900, 420)
	root.add_child(bg)
	var Tile: GDScript = load("res://scripts/ui/objective_tile.gd")
	var marks: Array = [[&"player", "A"], [&"enemy", "B"], [&"contested", "C"], [&"none", "A"]]
	for i: int in marks.size():
		var t: Control = Tile.new()
		t.compact = true
		t.control = marks[i][0]
		t.letter = marks[i][1]
		t.position = Vector2(16 + (i % 2) * 244, 16 + (i / 2) * 64)
		t.size = Vector2(228, 52)
		bg.add_child(t)
	var y: float = 160.0
	for line: String in ["Pick: Shoots the enemy with the lowest Armor.", "Pierce: Extra damage carries to the next enemy behind.",
			"Front line: Arrives as the front unit of its column.", "Agile: Once a round: move it to an adjacent column.",
			"Costs 2 Supply. Suppress 1, Cover 1, First Shot, Flank."]:
		var r: RichTextLabel = IconText.make(line, 22, Color("#D8DEE3"))
		r.position = Vector2(16, y)
		r.size = Vector2(560, 30)
		r.add_theme_font_size_override(&"normal_font_size", 20)
		bg.add_child(r)
		y += 36.0
	# The ability plates as the cards draw them.
	var plates := Control.new()
	plates.position = Vector2(600, 160)
	plates.size = Vector2(280, 200)
	bg.add_child(plates)
	plates.draw.connect(func() -> void:
		var kinds: Array = [&"kw_pick", &"pierce", &"protector", &"agile", &"kw_first_shot", &"kw_cover"]
		for i: int in kinds.size():
			var rr: Rect2 = Rect2((i % 3) * 64, (i / 3) * 64, 52, 52)
			CardLook.draw_ability(plates, rr, kinds[i], Color("#FFB020"), true))
	for i: int in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out_dir.path_join("plates_icons.png"))
	print("shot plates_icons")
	quit()
