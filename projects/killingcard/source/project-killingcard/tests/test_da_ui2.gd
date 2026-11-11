# test_da_ui2.gd
# Purpose: UI tests for the art-direction batch 2 (kc-da-ui2, art-direction.md §12 #4 #7 #8 #9 #10):
#   the inspector is one big card + a paper rules sheet; the after-action is a debrief with a stamp,
#   an MVP card and real stats only; the Codex is a binder (finish, owned / unowned, alt-art count);
#   the title shows a stencil wordmark and the equipped card with one amber button; the run map is
#   a briefing map (paper, pins, string, a red-circled boss target, no white NEXT box).
# Author: UI/UX Agent (kc-da-ui2)
extends "res://tests/test_case.gd"

const INSPECTOR_SCENE: String = "res://scenes/match/CardInspector.tscn"
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _host(size: Vector2) -> Control:
	var host: Control = Control.new()
	host.size = size
	tree.root.add_child(host)
	return host


func _free(n: Node) -> void:
	n.get_parent().remove_child(n)
	n.queue_free()


func test_inspector_is_one_card_and_a_paper_sheet() -> void:
	var db: Node = tree.root.get_node("CardDB")
	var card: CardData = db.get_card(&"marksman")
	assert_not_null(card, "marksman")
	if card == null:
		return
	for sz: Vector2 in [Vector2(844, 390), Vector2(1440, 900)]:
		var host: Control = _host(sz)
		var insp: Control = (load(INSPECTOR_SCENE) as PackedScene).instantiate()
		host.add_child(insp)
		insp.size = sz
		await _frames(2)
		var view: Dictionary = CardInfo.view_dict(card, "friend")
		insp.open({"view": view, "title": card.display_name, "type": "unit", "text": card.text,
				"keywords": CardInfo.keywords(card), "status": "", "banner": {"name": card.display_name, "fp": 2, "armor": 2},
				"side": 0, "art_line": "Art: Marksman · 1 of 5 · all in the Codex", "is_unit": true})
		await _frames(4)
		assert_true(insp.get_card_view().is_visible_in_tree(), "%s: the card shows" % sz)
		assert_true(insp.get_banner() == null, "%s: no banner copy beside the card" % sz)
		assert_true(insp.is_paper(), "%s: rules on paper" % sz)
		var all_text: String = ""
		for l: Node in insp.find_children("*", "Label", true, false):
			if (l as Label).is_visible_in_tree():
				all_text += (l as Label).text + " "
		assert_false(all_text.to_lower().contains("placeholder"), "%s: no placeholder words" % sz)
		var link: Button = insp.find_child("GlossaryLink", true, false) as Button
		if link != null:
			assert_true(link.icon != null and link.text == "", "%s: the glossary link is an icon, not a blank ?" % sz)
		assert_true(Rect2(Vector2.ZERO, sz).encloses(insp.get_node("%InfoPanel").get_global_rect()), "%s: sheet on screen" % sz)
		if sz.x >= 1440.0:
			assert_true(insp.get_card_view().get_global_rect().size.x >= 400.0, "desktop: one big card (%.0f px)" % insp.get_card_view().get_global_rect().size.x)
		# No card (a token, a rail box): the banner is the picture.
		insp.close()
		insp.open({"view": {}, "title": "Sentry Turret", "type": "token", "text": "FP 1.",
				"banner": {"name": "Sentry Turret", "fp": 1, "armor": 2, "armor_max": 2, "banner": "sentry_turret"}, "side": 0})
		await _frames(3)
		assert_true(insp.get_banner() != null, "%s: a token keeps its banner" % sz)
		insp.close()
		_free(host)
		await _frames(1)
