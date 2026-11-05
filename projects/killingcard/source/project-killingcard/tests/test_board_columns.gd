# test_board_columns.gd
# Purpose: kc-board (board-and-cards-ux.md, approved): the vertical 3-column board, 4:1 banners,
#   the BannerArt data path, option A hand cards, landing ghosts, Protector slide, tap snapping,
#   Field chips with the Overrun warning, the inspector's 512x128 banner and the QA bridge.
#   Layout numbers are the spec's: phone 844x390 -> canvas 1168x540, banners 176x44, columns at
#   x 300 / 496 / 692; desktop 1440x900 -> canvas 1280x800, banners 256x64, columns at 232 / 512 / 792.
# Author: Mechanics Developer Agent (kc-board)
extends "res://tests/test_case.gd"

const BoardLayout: GDScript = preload("res://tests/test_board_layout.gd")
const BoardMetrics: GDScript = preload("res://scripts/ui/board_metrics.gd")
const MockMatchData: GDScript = preload("res://scripts/ui/mock_match_data.gd")
const QaBridge: GDScript = preload("res://scripts/qa/qa_bridge.gd")
const DESKTOP_1440: Dictionary = {"name": "desktop 1440x900", "pt": Vector2(1440, 900), "ratio": 1.0}
const EPS: float = 0.6


func test_metrics_match_the_spec() -> void:
	# Phone: safe area = canvas minus the 12 px side margins.
	var m: Dictionary = BoardMetrics.compute(Vector2(1168 - 24, 540), true)
	assert_eq([m["bw"], m["bh"]], [176.0, 44.0], "phone banner 176x44")
	assert_eq((m["board"] as Rect2).position.x + 12.0, 300.0, "phone column A at x 300")
	assert_eq(float(m["col_x"][1]) + (m["board"] as Rect2).position.x + 12.0, 496.0, "column B at 496")
	assert_eq(float(m["col_x"][2]) + (m["board"] as Rect2).position.x + 12.0, 692.0, "column C at 692")
	assert_eq((m["hand"] as Rect2).position.y, 442.0, "phone hand row at y 442")
	assert_eq(m["obj_h"], 66.0, "phone objective tile 66 px (kc-polish)")
	assert_eq((m["hand"] as Rect2).end.y, 540.0, "hand reaches the bottom")
	assert_eq(BoardMetrics.row_y(m, &"enemy", 3) + (m["board"] as Rect2).position.y, 2.0, "rival back row at y 2")
	assert_eq(BoardMetrics.row_y(m, &"enemy", 0) + (m["board"] as Rect2).position.y, 140.0, "rival front row at y 140")
	assert_eq(BoardMetrics.objective_y(m) + (m["board"] as Rect2).position.y, 187.0, "objective at y 187")
	assert_eq(BoardMetrics.row_y(m, &"player", 0) + (m["board"] as Rect2).position.y, 256.0, "your front row at y 256")
	assert_eq(BoardMetrics.row_y(m, &"player", 3) + (m["board"] as Rect2).position.y, 394.0, "your back row at y 394")
	var d: Dictionary = BoardMetrics.compute(Vector2(1280 - 24, 800), false)
	assert_eq([d["bw"], d["bh"]], [256.0, 64.0], "desktop banner 256x64")
	assert_eq((d["board"] as Rect2).position.x + 12.0, 232.0, "desktop column A at x 232")
	assert_eq(BoardMetrics.row_y(d, &"player", 0) + (d["board"] as Rect2).position.y, 384.0, "desktop front row at y 384")
	assert_eq(d["obj_h"], 92.0, "desktop objective tile 92 px")
	assert_eq((d["hand"] as Rect2).position.y, 660.0, "desktop hand at y 660")
	# Narrow safe area (notch): banners shrink but keep 4:1 and rails keep their minimum.
	var n: Dictionary = BoardMetrics.compute(Vector2(900, 540), true)
	assert_true(is_equal_approx(n["bw"], n["bh"] * 4.0), "4:1 kept")
	assert_true((n["left"] as Rect2).size.x >= 204.0 - EPS, "rail minimum kept")


func test_board_numbers_readable() -> void:
	# Badges / numbers / plates (phone 22/16/18, desktop 28/20/22), >= 11.6 pt on the phone.
	var p: Dictionary = BannerView.metrics(44.0)
	assert_eq([p["badge"], p["number"], p["plate"]], [22.0, 16.0, 18.0], "phone banner metrics")
	var d: Dictionary = BannerView.metrics(64.0)
	assert_eq([d["badge"], d["number"], d["plate"]], [28.0, 20.0, 22.0], "desktop banner metrics")
	var k: float = BoardLayout.points_per_px(BoardLayout.PHONE)
	assert_true(float(p["number"]) * k >= 11.5, "phone stat numbers %.1f pt" % (float(p["number"]) * k))


func test_live_layout_columns_and_rows() -> void:
	for screen: Dictionary in [BoardLayout.PHONE, DESKTOP_1440]:
		var layout: RefCounted = BoardLayout.new()
		layout.set("tree", tree)
		var setup: Array = await layout._spawn(screen)
		var vp: SubViewport = setup[0]
		var m: Control = setup[1]
		var label: String = screen["name"]
		var lanes: Array[Node] = m.get_board().get_lanes()
		var want_bh: float = 44.0 if m.compact else 64.0
		for z: int in 3:
			var lane: Node = lanes[z]
			var tile: Rect2 = (lane.get_objective_tile() as Control).get_global_rect()
			for i: int in 4:
				var fr: Rect2 = (lane.get_friendly_slots()[i] as Control).get_global_rect()
				var er: Rect2 = (lane.get_enemy_slots()[i] as Control).get_global_rect()
				assert_true(absf(fr.size.y - want_bh) < EPS and absf(fr.size.x - want_bh * 4.0) < EPS, "%s 4:1 banner slot %s" % [label, fr.size])
				assert_true(fr.position.y >= tile.end.y - EPS, "%s your rows below the objective" % label)
				assert_true(er.end.y <= tile.position.y + EPS, "%s rival rows above it" % label)
				if i > 0:
					var prev: Rect2 = (lane.get_friendly_slots()[i - 1] as Control).get_global_rect()
					assert_true(fr.position.y > prev.position.y, "%s your row %d further from the objective" % [label, i + 1])
					var eprev: Rect2 = (lane.get_enemy_slots()[i - 1] as Control).get_global_rect()
					assert_true(er.position.y < eprev.position.y, "%s rival row %d further up" % [label, i + 1])
		# Hand cards (option A) under the board, inside the hand row, art window on top.
		var hand: Control = m.get_hand()
		assert_true(hand.get_global_rect().position.y >= m.get_board().get_global_rect().end.y - EPS, "%s hand under the board" % label)
		var card: Control = hand.get_cards()[0]
		var want: Vector2 = Vector2(78, 98) if m.compact else Vector2(108, 140)
		assert_true(card.size.distance_to(want) < 1.0, "%s hand card %s" % [label, card.size])
		layout._despawn(vp)
		await tree.process_frame


func test_banner_art_path_and_crops() -> void:
	var was_enabled: bool = BannerArtDB.licensed_enabled
	BannerArtDB.licensed_enabled = false  # a dev machine may have the private licensed folder
	BannerArtDB.clear_cache()
	# Killstreak card art placeholder: 4:1 band and 2:3 column of the same master.
	var art: BannerArt = BannerArtDB.get_art(&"marksman")
	assert_true(art.placeholder and art.texture != null, "placeholder from card art")
	var b: Texture2D = BannerArtDB.banner_texture(&"marksman")
	var p: Texture2D = BannerArtDB.portrait_texture(&"marksman")
	assert_true(absf(float(b.get_width()) / b.get_height() - 4.0) < 0.05, "banner 4:1 (%s)" % b.get_size())
	assert_true(absf(float(p.get_width()) / p.get_height() - 2.0 / 3.0) < 0.02, "portrait 2:3 (%s)" % p.get_size())
	# Crop centres move the regions, clamped inside the image.
	var img: Vector2 = Vector2(1536, 1024)
	assert_eq(BannerArt.band_rect(img, 0.47), Rect2(0, 289, 1536, 384), "art direction default band")
	assert_eq(BannerArt.band_rect(img, 0.0).position.y, 0.0, "band clamped at the top")
	assert_eq(BannerArt.column_rect(img, 0.5), Rect2(427, 0, 683, 1024), "hand column 683x1024")
	# A card with no art at all still gets a distinct generated banner.
	var g1: BannerArt = BannerArtDB.get_art(&"war_standard")
	var g2: BannerArt = BannerArtDB.get_art(&"aid_station")
	assert_true(g1.placeholder and g1.texture != null and g2.texture != null, "generated placeholders")
	assert_true(g1.texture.get_image().get_pixel(10, 10) != g2.texture.get_image().get_pixel(10, 10), "distinct per id")
	# Drop-in: a BannerArt in data/banners/<id>.tres wins over the placeholder.
	var drop := BannerArt.new()
	drop.id = &"kc_test_drop"
	drop.texture = ImageTexture.create_from_image(Image.create(1152, 768, false, Image.FORMAT_RGB8))
	drop.banner_y = 0.4
	var path: String = "res://data/banners/kc_test_drop.tres"
	DirAccess.make_dir_recursive_absolute("res://data/banners")
	assert_eq(ResourceSaver.save(drop, path), OK, "save drop-in banner")
	BannerArtDB.clear_cache()
	var got: BannerArt = BannerArtDB.get_art(&"kc_test_drop")
	assert_false(got.placeholder, "drop-in art used")
	assert_eq(BannerArtDB.banner_texture(&"kc_test_drop").get_size(), Vector2(1152, 288), "1152x288 band of a 1152x768 master")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if DirAccess.get_files_at("res://data/banners").is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://data/banners"))
	BannerArtDB.licensed_enabled = was_enabled
	BannerArtDB.clear_cache()


## kc-cod hook: an optional licensed folder with a manifest is used when present, ignored when not.
func test_licensed_manifest_optional() -> void:
	var saved: String = BannerArtDB.licensed_dir
	var was_enabled: bool = BannerArtDB.licensed_enabled
	BannerArtDB.licensed_enabled = true
	BannerArtDB.licensed_dir = "user://kc_licensed_test/"
	BannerArtDB.clear_cache()
	assert_true(BannerArtDB.licensed_rows().is_empty(), "no folder: no rows")
	assert_true(BannerArtDB.get_art(&"rifleman").placeholder, "no folder: placeholder")
	DirAccess.make_dir_recursive_absolute(BannerArtDB.licensed_dir)
	var img: Image = Image.create(300, 200, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.4, 0.6))
	img.save_png(BannerArtDB.licensed_dir + "card_a.png")
	var f: FileAccess = FileAccess.open(BannerArtDB.licensed_dir + "manifest.csv", FileAccess.WRITE)
	f.store_line("file,kind,chassis,title")
	f.store_line("card_a.png,unit,rifleman,Test Card")
	f.close()
	BannerArtDB.clear_cache()
	var art: BannerArt = BannerArtDB.get_art(&"rifleman")
	assert_false(art.placeholder, "manifest art used")
	assert_eq(art.title, "Test Card", "title from the manifest")
	assert_eq(BannerArtDB.banner_texture(&"rifleman").get_size(), Vector2(300, 75), "4:1 band of the licensed image")
	assert_true(BannerArtDB.get_art(&"marksman").placeholder, "chassis not in the manifest keep placeholders")
	for file: String in DirAccess.get_files_at(BannerArtDB.licensed_dir):
		DirAccess.remove_absolute(BannerArtDB.licensed_dir + file)
	DirAccess.remove_absolute(BannerArtDB.licensed_dir)
	BannerArtDB.licensed_dir = saved
	BannerArtDB.licensed_enabled = was_enabled
	BannerArtDB.clear_cache()


## kc-cod2: the pitch-set manifest (ids, frame sheets, Operator mastery ladder) drives per-copy art,
## the Operator's mastery banner and camo, the hand strip and the focus-only flipbook. Uses a scratch
## folder with generated images (no licensed art in tests).
func test_pitch_set_per_copy_art_mastery_and_flipbook() -> void:
	var saved: String = BannerArtDB.licensed_dir
	var was_enabled: bool = BannerArtDB.licensed_enabled
	BannerArtDB.licensed_enabled = true
	BannerArtDB.licensed_dir = "user://kc_pitch_test/"
	DirAccess.make_dir_recursive_absolute(BannerArtDB.licensed_dir)
	var colors: Dictionary = {"r1": Color.RED, "r2": Color.GREEN, "m1": Color.BLUE, "g1": Color.GOLD, "g2": Color.SILVER}
	for key: String in colors:
		var img: Image = Image.create(64, 16, false, Image.FORMAT_RGB8)
		img.fill(colors[key])
		img.save_png(BannerArtDB.licensed_dir + key + ".png")
	var sheet: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)  # 4 frames of 64x16
	for i: int in 4:
		sheet.fill_rect(Rect2i(0, i * 16, 64, 16), Color(i / 4.0, 0, 0))
	sheet.save_png(BannerArtDB.licensed_dir + "r2_frames.png")
	var f: FileAccess = FileAccess.open(BannerArtDB.licensed_dir + "manifest.csv", FileAccess.WRITE)
	f.store_line("file,kind,card,title,id,animated,frames_file,frames,frame_ms,mastery_family,tier_rank")
	f.store_line("r1.png,unit,rifleman,Rifle One,kc_t_r1,no,,,,,")
	f.store_line("r2.png,unit,rifleman,Rifle Two,kc_t_r2,yes,r2_frames.png,4,50,,")
	f.store_line("m1.png,unit,marksman,Mark One,kc_t_m1,no,,,,,")
	f.store_line("g1.png,operator,kestrel_ar7,MCW Gilded,kc_t_g1,no,,,,wm_mcw,1")
	f.store_line("g2.png,operator,kestrel_ar7,MCW Forged,kc_t_g2,no,,,,wm_mcw,2")
	f.close()
	BannerArtDB.clear_cache()
	assert_true(BannerArtDB.has_licensed(), "pitch manifest loaded")
	assert_eq(BannerArtDB.licensed_pool(&"rifleman"), [&"kc_t_r1", &"kc_t_r2"] as Array[StringName], "rifleman pool in order")
	# Per-copy art: copies of a chassis cycle through the pool, across both sides.
	var arts: Array = BannerArtDB.copy_arts([[&"rifleman", &"rifleman", &"marksman", &"callout"], [&"rifleman"]])
	assert_eq(arts[0], [&"kc_t_r1", &"kc_t_r2", &"kc_t_m1", &""], "player copies get different arts")
	assert_eq(arts[1], [&"kc_t_r1"], "rival copies continue the cycle (wraps)")
	var art: BannerArt = BannerArtDB.get_art(&"kc_t_r2")
	assert_true(art.licensed and not art.placeholder, "art reachable by its own id")
	assert_eq(art.frame_count, 4, "frame sheet rows")
	assert_not_null(BannerArtDB.frames_texture(art), "frame sheet loads")
	# Licensed art: the hand "portrait" is the whole 4:1 strip, not a 2:3 column.
	var p: Texture2D = BannerArtDB.portrait_texture(&"kc_t_r1")
	assert_true(absf(float(p.get_width()) / p.get_height() - 4.0) < 0.05, "hand shows the strip (%s)" % p.get_size())
	# Operator mastery ladder: Base = tier 1, the dev override previews higher tiers.
	assert_eq(BannerArtDB.operator_art_id(&"kestrel_ar7", 1), &"kc_t_g1", "Base = first mastery tier")
	assert_eq(BannerArtDB.camo_for_tier(1), &"base", "tier 1 wears the Base camo")
	BannerArtDB.operator_tier_override = 2
	assert_eq(BannerArtDB.operator_art_id(&"kestrel_ar7", 1), &"kc_t_g2", "dev toggle shows tier 2")
	assert_eq(BannerArtDB.camo_for_tier(1), &"forged", "camo follows the tier")
	BannerArtDB.operator_tier_override = 4
	assert_eq(BannerArtDB.operator_art_id(&"kestrel_ar7", 1), &"kc_t_g2", "clamped to the ladder")
	BannerArtDB.operator_tier_override = 0
	assert_eq(BannerArtDB.operator_art_id(&"wasp_9", 1), &"wasp_9", "no ladder: weapon id")
	# MatchState keeps the copy's art by uid (display only; clones carry it).
	var setup := SideSetup.new()
	var rifle: CardData = CardDB.get_card(&"rifleman")
	if rifle != null:
		setup.deck.assign([rifle, rifle])
		setup.deck_arts.assign([&"kc_t_r1", &"kc_t_r2"])
		setup.keep_deck_order = true
		var m := MatchState.new(null, null, setup, SideSetup.new(), 7)
		m.start_match()
		var uids: Array = m.art_by_uid.keys()
		assert_eq(uids.size(), 2, "both copies mapped")
		assert_eq(MatchClone.copy(m).art_by_uid, m.art_by_uid, "clone keeps the art map")
	# BannerView: flipbook only while focused, still art otherwise; safety net needs licensed art.
	var view := BannerView.new()
	view.size = Vector2(256, 64)
	tree.root.add_child(view)
	view.show_unit({"name": "Rifleman", "cls": "AR", "fp": 2, "armor": 2, "banner": "kc_t_r2"}, &"player", true)
	assert_false(view.is_flipbook_playing(), "still until focused")
	view.set_focus(true)
	assert_true(view.is_flipbook_playing(), "focus plays the frame sheet")
	view.set_focus(false)
	assert_false(view.is_flipbook_playing(), "unfocus stops it")
	assert_eq(view.get_node("Art").texture, BannerArtDB.banner_texture(&"kc_t_r2"), "back to the still")
	view.show_unit({"name": "Rifleman", "cls": "AR", "fp": 2, "armor": 2, "banner": "kc_t_r1"}, &"player", true)
	view.set_focus(true)
	assert_false(view.is_flipbook_playing(), "still art shimmers instead")
	assert_true(view.is_focused(), "but is focused")
	view.queue_free()
	for file: String in DirAccess.get_files_at(BannerArtDB.licensed_dir):
		DirAccess.remove_absolute(BannerArtDB.licensed_dir + file)
	DirAccess.remove_absolute(BannerArtDB.licensed_dir)
	BannerArtDB.licensed_dir = saved
	BannerArtDB.licensed_enabled = was_enabled
	BannerArtDB.clear_cache()


func test_ghost_protector_slide_and_snap() -> void:
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE)
	var vp: SubViewport = setup[0]
	var m: Control = setup[1]
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	await tree.process_frame
	var st: MatchState = c.state
	var me: RulesSide = st.sides[0]
	# Two units already in column A, then a Protector selected: its ghost is in row 1.
	var lane: Node = m.get_board().get_lanes()[0]
	var a: RulesUnit = st.create_unit(0, CardDB.get_card(&"rifleman"))
	st.put_in_line(a, 0)
	var b: RulesUnit = st.create_unit(0, CardDB.get_card(&"gunner"))
	st.put_in_line(b, 0)
	var prot := RulesCard.new(st.new_uid(), CardDB.get_card(&"shieldman"))
	me.hand.append(prot)
	me.supply = 10
	c.refresh()
	await tree.create_timer(1.5).timeout  # the two new units finish entering
	c.select_card(prot.uid)
	await tree.process_frame
	var ghost: BannerView = lane.get_ghost()
	assert_not_null(ghost, "landing ghost shown")
	if ghost != null:
		assert_eq(ghost.position.y, BoardMetrics.row_y(lane.metrics, &"player", 0), "Protector ghost in row 1")
	assert_eq(lane.target_text, "TAKES THE FRONT", "Protector badge")
	await tree.create_timer(0.4).timeout
	assert_true(lane.is_ghost_shift(), "your cards preview their shift back (B1)")
	assert_true(lane.get_friendly_slots()[0].banner.position.y > 10.0, "front card moved out from under the ghost")
	# A normal unit's ghost goes to the first free row.
	var rif := RulesCard.new(st.new_uid(), CardDB.get_card(&"rifleman"))
	me.hand.append(rif)
	c.refresh()
	c.select_card(rif.uid)
	await tree.process_frame
	ghost = lane.get_ghost()
	assert_true(ghost != null and is_equal_approx(ghost.position.y, BoardMetrics.row_y(lane.metrics, &"player", 2)), "unit ghost in row 3")
	c.clear_selection()
	await tree.process_frame
	assert_false(lane.is_ghost_shift(), "shift undone when the selection clears")
	await tree.create_timer(0.3).timeout
	# Play the Protector: it lands in row 1 (PLAN); its banner starts away from row 1 and slides.
	c.select_card(prot.uid)
	var res: Dictionary = c.play_at(0)
	assert_true(res["ok"], "Protector planned")
	await tree.process_frame
	# The PLAN entry is the queued arrival behind the line; at Reveal the engine puts it in front.
	st.set_ready(0)
	st.set_ready(1)
	st.reveal()
	c.refresh()
	await tree.process_frame
	var front: Node = lane.get_friendly_slots()[0]
	assert_eq(front.slot_uid, prot.uid, "Protector is the frontline after Reveal")
	assert_true(front.banner.position.y > 1.0, "Protector banner still sliding toward row 1 (%s)" % front.banner.position)
	assert_true(lane.get_friendly_slots()[1].banner.position.y < -1.0, "passed card shifts back later (starts at its old row)")
	await tree.create_timer(2.0).timeout
	assert_true(absf(front.banner.position.y) < 0.5, "settled in row 1")
	# Tap snapping: with enemy units offered as targets, a tap on an empty spot of the rival half
	# picks the nearest target in that half.
	var foe: RulesUnit = st.create_unit(1, CardDB.get_card(&"rifleman"))
	st.put_in_line(foe, 0)
	c.refresh()
	await tree.process_frame
	lane.set_unit_targets([foe.uid])
	var empty_slot: Control = lane.get_enemy_slots()[3]
	var hit: Array = lane._slot_hit(empty_slot.get_global_rect().get_center())
	assert_eq(hit, [&"enemy", foe.uid], "tap snaps to the nearest target in the half")
	var hit2: Array = lane._slot_hit(empty_slot.get_global_rect().get_center(), true)
	assert_eq(hit2[1], -1, "inspect never snaps")
	lane.set_unit_targets([])
	layout._despawn(vp)
	await tree.process_frame


func test_fields_on_the_objective_tile_and_overrun() -> void:
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE)
	var vp: SubViewport = setup[0]
	var m: Control = setup[1]
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	await tree.process_frame
	var st: MatchState = c.state
	# A visible Field of yours in column B, the rival holding B: Overrun risk.
	var field := RulesCard.new(st.new_uid(), CardDB.get_card(&"listening_post"))
	st.sides[0].equipment[1].append({"card": field, "round": st.round_number})
	var foe: RulesUnit = st.create_unit(1, CardDB.get_card(&"rifleman"))
	st.put_in_line(foe, 1)
	c.refresh()
	await tree.process_frame
	var lane: Node = m.get_board().get_lanes()[1]
	var tile: Control = lane.get_objective_tile()
	var mine: Array = tile.fields.get("player", [])
	assert_eq(mine.size(), 1, "your Field is on your half of the tile")
	assert_true(bool(mine[0].get("overrun_risk", false)), "overrun risk flagged")
	assert_true(tile.is_processing(), "the OVERRUN tab pulses")
	await tree.process_frame
	# Long-press the chip: the inspector names the Field and explains Overrun in plain words.
	var chip: Array = tile._chip_rects[0] if not tile._chip_rects.is_empty() else []
	assert_false(chip.is_empty(), "chip drawn")
	if not chip.is_empty():
		var at: Vector2 = tile.get_global_transform() * (chip[0] as Rect2).get_center()
		var hit: Array = lane._slot_hit(at, true)
		assert_eq(hit, [&"field_player", field.uid], "chip hit")
		c._on_lane_long_pressed(1, hit[0], hit[1])
		await tree.process_frame
		var insp: Control = m.get_inspector()
		assert_true(insp.is_open(), "field inspector")
		var rules: String = (insp.get_node("%RulesLabel") as Label).text
		assert_true(rules.contains("Overrun: at the end of each round, if the enemy controls this column, this Field is destroyed (hidden traps are exempt)."), "Overrun in plain words: %s" % rules)
		assert_true((insp.get_node("%StatusLabel") as Label).text.contains("OVERRUN RISK"), "status warns")
		insp.close()
	# Objective tile and incoming backs are inspectable too.
	c._on_lane_long_pressed(1, &"objective", -1)
	assert_true(m.get_inspector().is_open(), "objective inspector")
	m.get_inspector().close()
	# The FIELD OVERRUN callout when the engine tears it down.
	c._board_callout({"type": RulesEvent.EQUIPMENT_DESTROYED, "zone": &"mid", "side": &"player", "reason": RulesEvent.FIELD_GONE_OVERRUN})
	var texts: Array = lane.get_node("%FxLayer").find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_true(texts.has("FIELD OVERRUN"), "on-board callout %s" % [texts])
	layout._despawn(vp)
	await tree.process_frame


func test_inspector_shows_the_512_banner_and_rails_inspect() -> void:
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE)
	var vp: SubViewport = setup[0]
	var m: Control = setup[1]
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	await tree.process_frame
	var rc: RulesCard = c.state.sides[0].hand[0]
	c._on_card_inspected(rc.uid)
	await tree.process_frame
	var insp: Control = m.get_inspector()
	var banner: BannerView = insp.get_banner()
	assert_not_null(banner, "inspector banner")
	if banner != null:
		assert_eq(banner.size, Vector2(512, 128), "512x128 banner")
		assert_true(banner.has_art(), "banner art")
		assert_true(banner.is_focused(), "animated while focused")
		assert_true(Rect2(Vector2.ZERO, Vector2(vp.size)).encloses(banner.get_global_rect()), "on screen")
	insp.close()
	if banner != null:
		assert_false(banner.is_focused(), "stops when closed")
	for key: StringName in [&"score", &"deck", &"intel", &"supply"]:
		m.rail_inspected.emit(key)
		await tree.process_frame
		assert_true(insp.is_open(), "rail box %s inspectable" % key)
		insp.close()
	layout._despawn(vp)
	await tree.process_frame


func test_qa_bridge_snapshot() -> void:
	var layout: RefCounted = BoardLayout.new()
	layout.set("tree", tree)
	var setup: Array = await layout._spawn(BoardLayout.PHONE)
	var vp: SubViewport = setup[0]
	var bridge: Node = QaBridge.new()
	tree.root.add_child(bridge)
	var d: Dictionary = bridge.snapshot(setup[1])
	assert_true((d["buttons"] as Array).size() > 10, "buttons listed")
	assert_true(d.has("match"), "match block")
	if d.has("match"):
		assert_eq((d["match"]["columns"] as Array).size(), 3, "3 columns")
		assert_true((d["match"]["hand"] as Array).size() > 0, "hand listed")
	bridge.queue_free()
	layout._despawn(vp)
	await tree.process_frame
