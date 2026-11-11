# test_pitch_art.gd
# Purpose: kc-pitch-art (head's art requests): the Operator mark on every card view, card art never
#   mirrored for the rival, sharp text on a grown (scaled-up) card, and the pitch mapping keeps weapon
#   cards on Operators only. Licensed images are never needed: the mapping test reads the id list.
# Author: Technical Artist Agent (kc-pitch-art)
extends "res://tests/test_case.gd"

const CARD_SCENE: String = "res://scenes/match/CardView.tscn"
const PITCH_CSV: String = "res://../../documentation/art/mw3-pitch-set.csv"


func _card(d: Dictionary) -> CardView:
	var card: CardView = (load(CARD_SCENE) as PackedScene).instantiate()
	tree.root.add_child(card)
	card.set_card_data(d)
	return card


func test_operator_mark_on_the_card_only_for_operators() -> void:
	var op: CardView = _card({"name": "Kestrel AR-7", "type": "operator", "side": "friend", "firepower": 3, "armor": 8})
	await tree.process_frame
	var mark: Control = op.get_node("OperatorMark")
	assert_true(mark.visible, "the Operator wears the mark")
	assert_eq(op.get_child(op.get_child_count() - 1), mark, "the mark is drawn over the art")
	op.set_card_data({"name": "Rifleman", "type": "unit", "side": "friend", "firepower": 2, "armor": 2})
	await tree.process_frame
	assert_false(mark.visible, "a unit has no Operator mark")
	op.queue_free()


func test_operator_tab_shrinks_to_the_chevron_badge() -> void:
	var full: Vector2 = CardLook.operator_tab_size(18.0, true)
	var badge: Vector2 = CardLook.operator_tab_size(18.0, false)
	assert_true(full.x > badge.x * 2.0, "the word makes the tab wider (%s / %s)" % [full, badge])
	assert_eq(full.y, 18.0, "tab height as asked")


func test_rival_art_is_never_mirrored() -> void:
	var c: CardView = _card({"name": "X", "type": "unit", "side": "enemy", "id": "rifleman"})
	await tree.process_frame
	assert_false((c.get_node("%ArtIcon") as TextureRect).flip_h, "rival card art faces the same way")
	c.queue_free()


func test_grown_card_text_uses_oversampled_fonts() -> void:
	var c: CardView = _card({"name": "Rifleman", "type": "unit", "side": "friend", "firepower": 2, "armor": 2})
	await tree.process_frame
	var name_label: Label = c.get_node("%NameLabel")
	var plain: Font = name_label.get_theme_font(&"font")
	c.scale = Vector2(1.5, 1.5)
	c.set_text_scale(1.5)
	var sharp: Font = name_label.get_theme_font(&"font")
	assert_true(sharp != plain, "the grown card swaps in a sharp copy")
	assert_eq(CardLook.plain_font(sharp), plain, "the copy maps back to the shared font")
	assert_true(sharp is FontFile and (sharp as FontFile).oversampling > 0.0, "the copy has its own oversampling")
	c.set_text_scale(1.0)
	assert_eq(name_label.get_theme_font(&"font"), plain, "scale 1 restores the shared font")
	c.queue_free()


func test_weapon_cards_map_to_operators_only() -> void:
	var path: String = ProjectSettings.globalize_path(PITCH_CSV)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		assert_true(true, "no id list next to this copy of the project: skipped")
		return  # the id list lives outside the Godot project (a bare copy of it skips this)
	var head: PackedStringArray = f.get_csv_line()
	var col: Dictionary = {}
	for i: int in head.size():
		col[head[i].strip_edges()] = i
	var rows: int = 0
	var private_titles: Dictionary = {}
	while not f.eof_reached():
		var r: PackedStringArray = f.get_csv_line()
		if r.size() < head.size():
			continue
		rows += 1
		var kind: String = r[col["kind"]]
		var title: String = r[col["title"]]
		if kind != "operator":
			assert_false("Mastery:" in title, "%s: a weapon-mastery card on a %s" % [title, kind])
			assert_eq(r[col["mastery_family"]], "", "%s: no mastery ladder off the Operator" % title)
		if r[col["card"]].begins_with("kc_wip_private_"):
			private_titles[r[col["card"]]] = title
	assert_true(rows > 100, "the pitch list was read (%d rows)" % rows)
	assert_eq([private_titles.get("kc_wip_private_1"), private_titles.get("kc_wip_private_2"),
			private_titles.get("kc_wip_private_3"), private_titles.get("kc_wip_private_4")],
			["Anything That Moves", "Helo Support", "Landing Party", "Grid And Grit"], "head: the Privates wear the starter's earlier art")
