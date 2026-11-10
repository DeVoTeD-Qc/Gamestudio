# shot_bands.gd
# Purpose: Dev tool (kc-ui-bands): a phone-size (844x390) sheet of the level bands as strips, swatches
#   and the OPERATOR badge disc, plus the Operator inspector line that names the band. In a tree
#   without scripts/ui/mastery_bands.gd (before kc-ui-bands) it draws the old copy-level bands
#   (SynergyGlyphs.draw_band) and the old badge, for a before / after pair.
# Usage: xvfb-run -a -s "-screen 0 1280x1024x24" godot --path . --rendering-driver opengl3 \
#          --resolution 844x390 -s res://tests/tools/shot_bands.gd -- <out_dir> [prefix]
# Author: UI/UX Agent (kc-ui-bands)
extends SceneTree

const BANDS_PATH: String = "res://scripts/ui/mastery_bands.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shots"
	var prefix: String = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var bands: GDScript = load(BANDS_PATH) as GDScript if ResourceLoader.exists(BANDS_PATH) else null
	var glyphs: GDScript = load("res://scripts/ui/synergy_glyphs.gd")
	var ids: Array = bands.get(&"IDS") if bands != null else [&"", &"gilded", &"forged", &"priceless"]
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#14181C")
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var canvas: Control = Control.new()
	bg.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font: Font = ThemeDB.fallback_font
	canvas.draw.connect(func() -> void:
		canvas.draw_string(font, Vector2(16, 26), "LEVEL BANDS · %s" % ("original finishes (kc-ui-bands)" if bands != null else "before: copy-level camo"),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#D8DEE3"))
		for i: int in ids.size():
			var id: StringName = ids[i]
			var y: float = 48.0 + i * 66.0
			var nm: String = bands.call(&"display_name", id) if bands != null else (String(id).capitalize() if id != &"" else "Base (badge blobs)")
			canvas.draw_string(font, Vector2(16, y + 20), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#D8DEE3"))
			var strip: Rect2 = Rect2(150, y + 4, 420, 22)
			var swatch: Rect2 = Rect2(590, y - 6, 52, 52)
			if bands != null:
				bands.call(&"draw", canvas, strip, id)
				bands.call(&"draw", canvas, swatch, id)
				var c: Vector2 = Vector2(700, y + 20)
				bands.call(&"draw", canvas, Rect2(c - Vector2(24, 24), Vector2(48, 48)), id, bands.call(&"disc", c, 22.0))
				canvas.draw_arc(c, 24, 0, TAU, 28, Color("#0d1014"), 6.0)
				canvas.draw_arc(c, 22, 0, TAU, 28, Color("#e7c56a"), 2.0)
				var earn: String = String(bands.get(&"EARN").get(id, ""))
				canvas.draw_multiline_string(font, Vector2(150, y + 40), earn, HORIZONTAL_ALIGNMENT_LEFT, 425, 10, 2, Color("#9AA5AE"))
			elif id != &"":
				glyphs.call(&"draw_band", canvas, strip, id)
				glyphs.call(&"draw_band", canvas, swatch, id)
			else:
				var cols: Array = [Color("#6b5a2a"), Color("#c9a548"), Color("#3d3a1c"), Color("#e7c56a")]
				var c2: Vector2 = Vector2(700, y + 20)
				for k: int in 4:
					canvas.draw_circle(c2 + Vector2(cos(k * PI * 0.5 + 0.6), sin(k * PI * 0.5 + 0.6)) * 8.0, 14.0, cols[k])
				canvas.draw_arc(c2, 24, 0, TAU, 28, Color("#0d1014"), 7.0)
				canvas.draw_arc(c2, 21, 0, TAU, 28, cols[3], 2.0))
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(prefix + "10_bands.png"))
	print("shot ", prefix, "10_bands")
	quit(0)
