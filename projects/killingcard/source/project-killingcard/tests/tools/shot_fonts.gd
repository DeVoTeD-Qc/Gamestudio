# shot_fonts.gd
# Purpose: Dev tool (kc-readability): the two number-font candidates side by side on hand-card art
#   (Oswald Bold vs Barlow Condensed ExtraBold), at the phone sizes. Public art only.
# Usage: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 700x260 \
#          -s res://tests/tools/shot_fonts.gd -- <out.png>
# Author: UI/UX Agent (kc-readability)
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	BannerArtDB.licensed_enabled = false
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://fonts.png"
	var bg := ColorRect.new()
	bg.color = Color("#14181C")
	bg.size = Vector2(700, 260)
	root.add_child(bg)
	var fonts: Array = [["OSWALD BOLD (chosen)", load("res://assets/fonts/card_numbers_oswald.tres")],
			["BARLOW CONDENSED EXTRABOLD", load("res://assets/fonts/card_numbers_barlow.tres")]]
	for i: int in 2:
		var y: float = 20.0 + i * 120.0
		var l := Label.new()
		l.text = fonts[i][0]
		l.position = Vector2(16, y - 16)
		root.add_child(l)
		var art := TextureRect.new()
		art.texture = BannerArtDB.banner_texture(&"gunner")
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.position = Vector2(16, y + 8)
		art.size = Vector2(380, 95)
		root.add_child(art)
		var ink := Control.new()
		ink.position = art.position
		ink.size = art.size
		root.add_child(ink)
		var f: Font = fonts[i][1]
		ink.draw.connect(func() -> void:
			for j: int in 3:
				var x: float = 10.0 + j * 120.0
				var s: float = [26.0, 30.0, 34.0][j]
				CardLook.draw_chip(ink, Rect2(x - 3, 30 - 3, s * 2 + 9, s + 6), 6.0)
				ink.draw_set_transform(Vector2.ZERO)
				_num(ink, Rect2(x, 30, s, s), "%d" % (j + 2), f, true)
				_num(ink, Rect2(x + s + 3, 30, s, s), "1%d" % j, f, false))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()


func _num(ci: CanvasItem, r: Rect2, txt: String, f: Font, ring: bool) -> void:
	if ring:
		CardLook.draw_reticle(ci, r, 0, &"player", 0, false)
	else:
		CardLook.draw_armor(ci, r, 0, false, false)
	var fs: int = int(roundf(r.size.x * (0.62 if txt.length() > 1 else 0.72)))
	var sz: Vector2 = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos: Vector2 = Vector2(r.get_center().x - sz.x * 0.5, r.get_center().y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	ci.draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, CardLook.INK)
	ci.draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
