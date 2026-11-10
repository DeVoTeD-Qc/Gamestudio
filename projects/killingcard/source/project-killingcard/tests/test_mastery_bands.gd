# test_mastery_bands.gd
# Purpose: kc-ui-bands. The level bands are original finishes drawn in code (Base, Gold Leaf, Machined,
#   Prism, Starfield) with no camo-ladder names: the retired ids migrate (saved profiles, run saves,
#   views), every band draws on a rect and on a disc, the tiers / copy levels map to the new ids, the
#   inspector says the name and how it is earned, and no game script or data still uses an old id.
# Author: UI/UX Agent (kc-ui-bands)
extends "res://tests/test_case.gd"

const OLD: Array[String] = ["gilded", "forged", "priceless", "interstellar"]


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func test_ids_names_and_legacy_map() -> void:
	assert_eq(MasteryBands.IDS, [&"base", &"gold_leaf", &"machined", &"prism", &"starfield"] as Array[StringName], "the five bands")
	assert_eq(MasteryBands.migrate_id(&"gilded"), &"gold_leaf", "gilded -> gold_leaf")
	assert_eq(MasteryBands.migrate_id("Forged"), &"machined", "Forged -> machined (any case)")
	assert_eq(MasteryBands.migrate_id(&"priceless"), &"prism", "priceless -> prism")
	assert_eq(MasteryBands.migrate_id(&"interstellar"), &"starfield", "interstellar -> starfield")
	assert_eq(MasteryBands.migrate_id(&"prism"), &"prism", "new ids pass through")
	assert_eq(MasteryBands.display_name(&"forged"), "Machined", "old ids show the new name")
	for n: String in MasteryBands.NAMES.values():
		for o: String in OLD:
			assert_false(o in n.to_lower(), "%s is not a camo-ladder name" % n)


func test_tiers_and_copy_levels() -> void:
	assert_eq(MasteryBands.band_for_tier(1), &"base", "tier 1 shows the Base band (head B3)")
	assert_eq(MasteryBands.band_for_tier(4), &"starfield", "tier 4: Starfield")
	assert_eq(BannerArtDB.camo_for_tier(2), &"machined", "BannerArtDB follows the new ids")
	assert_eq(BannerArtDB.MASTERY_TIERS[0], "Gold Leaf", "tier names renamed")
	assert_eq(MasteryBands.COPY_BANDS[&"elite"], &"prism", "Elite copies wear Prism")


func test_saved_profile_migrates_old_ids() -> void:
	var old: Dictionary = {"version": 2, "runs_finished": 3, "operator_band": {"band": "gilded"},
			"duel_decks": [{"id": "d1", "name": "Mine", "picks": [{"card": "rifleman", "band": "priceless", "camo": &"forged"}]}],
			"note": "gilded stays as plain text outside band keys"}
	var n: int = MasteryBands.migrate(old)
	assert_eq(n, 3, "three band values rewritten")
	assert_eq(old["operator_band"]["band"], "gold_leaf", "nested band: gilded -> gold_leaf (still a String)")
	assert_eq(old["duel_decks"][0]["picks"][0]["band"], "prism", "a deck pick's band migrates")
	assert_eq(old["duel_decks"][0]["picks"][0]["camo"], &"machined", "a StringName stays a StringName")
	assert_eq(old["note"], "gilded stays as plain text outside band keys", "only band keys change")
	# Loading through RunProfile migrates the stored profile too.
	var stored: Dictionary = {"version": 2, "runs_finished": 1, "duel_decks": [{"id": "d1", "band": "interstellar"}]}
	var p: Dictionary = RunProfile.normalised(stored)
	assert_eq(p["duel_decks"][0]["band"], "starfield", "RunProfile.normalised migrates old band ids")
	assert_eq(MasteryBands.migrate(p), 0, "migration is idempotent")


func test_every_band_draws_on_a_rect_and_a_disc() -> void:
	var ci: Control = Control.new()
	ci.size = Vector2(300, 120)
	tree.root.add_child(ci)
	var drawn: Array = []
	ci.draw.connect(func() -> void:
		for i: int in MasteryBands.IDS.size():
			var id: StringName = MasteryBands.IDS[i]
			var r: Rect2 = Rect2(Vector2(i * 58, 0), Vector2(54, 24))
			var a: bool = MasteryBands.draw(ci, r, id)
			var b: bool = MasteryBands.draw(ci, Rect2(Vector2(i * 58, 40), Vector2(40, 40)), id,
					MasteryBands.disc(Vector2(i * 58 + 20, 60), 20.0))
			drawn.append(a and b)
		drawn.append(MasteryBands.draw(ci, Rect2(0, 90, 50, 20), &"forged"))
		drawn.append(not MasteryBands.draw(ci, Rect2(0, 90, 50, 20), &"nope")))
	ci.queue_redraw()
	await _frames(2)
	assert_eq(drawn.size(), MasteryBands.IDS.size() + 2, "the draw pass ran")
	assert_false(drawn.has(false), "every band draws on a rect and a disc; old ids draw; unknown ids don't")
	ci.queue_free()
	await tree.process_frame


func test_band_inspector_says_name_and_how_earned() -> void:
	for id: StringName in MasteryBands.IDS:
		var info: Dictionary = MasteryBands.info(id)
		assert_true(String(info["title"]).begins_with(MasteryBands.NAMES[id]), "%s: title names the band" % id)
		assert_true(String(info["text"]).length() > 20, "%s: says how it is earned" % id)
	var line: String = (load("res://scripts/ui/match_controller.gd") as GDScript).call(&"_mastery_line", {"mastery_tier": 1, "camo": "base"})
	assert_true("Base" in line, "the Operator inspector names the band (%s)" % line)


func test_operator_badge_draws_the_band_and_inspects() -> void:
	var badge: Control = (load("res://scripts/ui/strip_badge.gd") as GDScript).new()
	badge.glyph = &"camo"
	badge.band = &"forged"
	assert_eq(badge.band, &"machined", "the badge migrates an old id on set")
	assert_true(badge.has_signal(&"inspected"), "the badge is inspectable (right click / long press)")
	badge.free()


func test_no_old_ids_in_game_code_or_data() -> void:
	var hits: Array[String] = []
	for root: String in ["res://scripts/", "res://data/", "res://autoload/", "res://scenes/"]:
		_scan(root, hits)
	assert_eq(hits, [] as Array[String], "no old band id in game code or data")


func _scan(dir: String, hits: Array[String]) -> void:
	for d: String in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), hits)
	for f: String in DirAccess.get_files_at(dir):
		if not (f.ends_with(".gd") or f.ends_with(".tres") or f.ends_with(".tscn")):
			continue
		var path: String = dir.path_join(f)
		var text: String = FileAccess.get_file_as_string(path).to_lower()
		if path.ends_with("mastery_bands.gd"):
			continue  # the migration table names the old ids on purpose
		for o: String in OLD:
			if o in text:
				hits.append("%s: %s" % [path, o])
