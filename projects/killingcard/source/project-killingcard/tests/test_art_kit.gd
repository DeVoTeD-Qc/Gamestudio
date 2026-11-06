# test_art_kit.gd
# Purpose: p13 art kit checks. Themes and icon sheet load, CardView instantiates for every card
#   type and side, and card text fits its slots at 100% and 50% scale (no clipping/overflow).
# Author: Technical Artist Agent (p13)
extends "res://tests/test_case.gd"

const SAMPLES := preload("res://scripts/ui/card_samples.gd")
const CARD_SCENE: String = "res://scenes/match/CardView.tscn"
## At 50% (hand view) these must stay at or above this on-screen pixel size.
const MIN_HAND_VIEW_PX: Dictionary = {"CostLabel": 12.0, "FirepowerLabel": 12.0, "ArmorLabel": 12.0, "NameLabel": 6.5}


func test_themes_load() -> void:
	for path: String in ["res://assets/ui/hud_theme.tres", "res://assets/ui/card_theme.tres"]:
		var theme: Theme = load(path) as Theme
		assert_not_null(theme, "%s did not load as Theme" % path)
		if theme == null:
			continue
		for color_name: String in ["friend", "enemy", "accent", "special", "elite"]:
			var type_name: String = "Card" if path.ends_with("card_theme.tres") else "Hud"
			assert_true(theme.has_color(color_name, type_name), "%s lacks %s/%s" % [path, type_name, color_name])
	var hud: Theme = load("res://assets/ui/hud_theme.tres")
	assert_true(hud.has_stylebox("normal", "ReadyButton"), "hud theme ReadyButton")
	assert_true(hud.get_color("accent", "Hud").is_equal_approx(Color("#FFB020")), "amber accent")
	var card: Theme = load("res://assets/ui/card_theme.tres")
	assert_true(card.get_type_variation_base("CardName") == &"Label", "CardName is a Label variation")


func test_icon_sheet_covers_rules() -> void:
	var sheet: Texture2D = load(IconSheet.SHEET_PATH)
	assert_not_null(sheet, "icon sheet loads")
	if sheet != null:
		@warning_ignore("integer_division")
		var rows: int = (IconSheet.NAMES.size() + IconSheet.COLUMNS - 1) / IconSheet.COLUMNS
		assert_eq(sheet.get_size(), Vector2(IconSheet.COLUMNS * IconSheet.CELL, rows * IconSheet.CELL), "sheet size")
	var svg: String = FileAccess.get_file_as_string(IconSheet.SHEET_PATH)
	for icon_name: String in IconSheet.NAMES:
		assert_true(svg.contains('id="%s"' % icon_name), "svg has group %s" % icon_name)
		assert_not_null(IconSheet.get_icon(StringName(icon_name)), "icon %s" % icon_name)
	for kw: StringName in [&"first_shot", &"pick", &"flank", &"cover", &"suppress", &"patch", &"holder", &"on_deploy", &"on_down"]:
		assert_not_null(IconSheet.get_keyword_icon(kw), "keyword icon %s" % kw)
	for needed: String in ["range_close", "range_mid", "range_long", "streak", "supply", "type_operator",
			"ks_recon_drone", "ks_mortar", "ks_sentry", "ks_attack_helo", "ks_gunship"]:
		assert_true(IconSheet.has_icon(StringName(needed)), "needed icon %s" % needed)


func test_card_view_instantiates() -> void:
	var scene: PackedScene = load(CARD_SCENE) as PackedScene
	assert_not_null(scene, "CardView.tscn loads")
	if scene == null:
		return
	var card: Control = scene.instantiate()
	assert_eq(card.name, &"CardView", "root name")
	tree.root.add_child(card)
	await tree.process_frame
	assert_eq(card.size, CardView.BASE_SIZE, "base size (kc-cards-impl: the Y2+ card at 250 px)")
	assert_false((card.get_node("%NameLabel") as Label).text.is_empty(), "placeholder name shown")
	assert_true((card.get_node("%FirepowerBadge") as Control).visible, "placeholder shows stats")
	card.queue_free()
	await tree.process_frame


## The headless window is 64x64, so the viewport sets font oversampling to 0.05 and font metrics
## come back inflated by rounding. Measure text as a real 1280x720 window would (oversampling 1).
func _real_font_metrics() -> float:
	var ts: TextServer = TextServerManager.get_primary_interface()
	var previous: float = ts.font_get_global_oversampling()
	ts.font_set_global_oversampling(1.0)
	return previous


func test_card_text_fits_at_full_and_half_scale() -> void:
	var previous_oversampling: float = _real_font_metrics()
	var card: Control = (load(CARD_SCENE) as PackedScene).instantiate()
	tree.root.add_child(card)
	# kc-cards-impl: the Y2+ card is laid out at its width (never scaled): the preview's 250 and the
	# Codex's 172 px keep the same text sizes.
	for scale: float in [1.0, 0.5]:
		card.set_card_width(250.0 if scale == 1.0 else 172.0)
		for side: String in ["friend", "enemy"]:
			for data: Dictionary in SAMPLES.CARDS:
				var d: Dictionary = data.duplicate(true)
				d["side"] = side
				TextServerManager.get_primary_interface().font_set_global_oversampling(1.0)
				card.set_card_data(d)
				await tree.process_frame
				var label: String = "%s/%s@%d%%" % [d["name"], side, int(scale * 100)]
				var overflow: PackedStringArray = card.get_overflowing_labels()
				assert_true(overflow.is_empty(), "%s clips: %s" % [label, ", ".join(overflow)])
				if scale == 0.5:
					for label_name: String in MIN_HAND_VIEW_PX:
						var px: float = card.get_min_effective_font_size(PackedStringArray([label_name]))
						if px != INF:
							assert_true(px >= MIN_HAND_VIEW_PX[label_name], "%s %s only %.1f px" % [label, label_name, px])
	card.queue_free()
	await tree.process_frame
	TextServerManager.get_primary_interface().font_set_global_oversampling(previous_oversampling)


## kc-cards-impl (Y2+): the side shows in the FP reticle's team colour (teal / red) and the rival's
## art faces the other way; Tactics are the only cut-corner frame (T1).
func test_friend_and_enemy_differ_by_shape() -> void:
	var card: CardView = (load(CARD_SCENE) as PackedScene).instantiate()
	tree.root.add_child(card)
	await tree.process_frame
	assert_true((CardLook.TEAM[&"player"] as Array)[0] != (CardLook.TEAM[&"enemy"] as Array)[0], "team reticles differ")
	card.set_card_data({"name": "X", "type": "unit", "side": "enemy", "id": "rifleman"})
	assert_true((card.get_node("%ArtIcon") as TextureRect).flip_h, "the rival's art is mirrored")
	for type_name: String in ["unit", "tactic", "equipment", "killstreak", "operator"]:
		card.set_card_data({"name": "X", "type": type_name, "side": "friend"})
		assert_eq(card.is_tactic(), type_name == "tactic", "%s: T1 frame only on tactics" % type_name)
		assert_eq(card.has_stats_bar(), type_name in ["unit", "operator"], "%s: stats bar" % type_name)
	card.queue_free()
	await tree.process_frame
