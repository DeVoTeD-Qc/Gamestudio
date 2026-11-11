# test_text_icons.gd
# Purpose: kc-text: the text hierarchy and the icon rules (documentation/design/text-and-icons.md):
#   short keyword lines for the inspector, the full ones in the glossary, one icon per concept
#   inline (IconText), one name per concept in card texts, and a unique lore line per vanilla card.
# Author: Mid Game Designer Agent (kc-text)
extends "res://tests/test_case.gd"

const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const Glossary: GDScript = preload("res://scripts/ui/codex/glossary.gd")


func test_keyword_lines_are_short_and_the_glossary_has_the_full_rule() -> void:
	for id: StringName in CardInfo.KEYWORD_RULES:
		var row: Array = CardInfo.KEYWORD_RULES[id]
		assert_eq(row.size(), 3, "%s: [name, short, full]" % id)
		assert_true(String(row[1]).length() <= 70, "%s: the inspector line fits one line (%d chars)" % [id, String(row[1]).length()])
		assert_true(String(row[2]).length() >= String(row[1]).length(), "%s: the glossary text is the full one" % id)
	var by_key: Dictionary = {}
	for e: Dictionary in Glossary.entries():
		by_key[e["key"]] = e
	assert_eq(String(by_key[&"agile"]["text"]), String(CardInfo.KEYWORD_RULES[&"agile"][2]), "glossary reads the full rule")


func test_every_concept_has_one_icon() -> void:
	for c: StringName in IconText.concepts():
		assert_true(IconText.texture(c) != null, "%s has an icon" % c)
	# The same word always maps to the same concept.
	assert_eq(IconText.concept_of("Supply"), &"supply", "Supply")
	assert_eq(IconText.concept_of("FP"), &"fp", "FP")
	assert_eq(IconText.concept_of("Firepower"), &"fp", "Firepower is FP")
	assert_eq(IconText.concept_of("killstreak"), &"killstreak", "killstreak, not streak")
	assert_eq(IconText.concept_of("REQ"), &"req", "REQ")


func test_icon_text_keeps_the_words() -> void:
	var r: RichTextLabel = IconText.make("Costs 2 Supply. Your units get +2 FP. 3 Supply more.", 16)
	assert_eq(IconText.plain(r), "Costs 2 Supply. Your units get +2 FP. 3 Supply more.", "plain words kept")
	var parsed: String = r.get_parsed_text()
	assert_true(parsed.contains("Supply") and parsed.contains("FP"), "the label still reads the words: %s" % parsed)
	r.free()


func test_card_texts_use_one_name_per_concept() -> void:
	for card: CardData in CardDB.all_cards():
		var t: String = card.text
		assert_false(t.contains("zone"), "%s: 'column', not 'zone'" % card.id)
		assert_false(t.contains("point man") or t.contains("frontline unit"), "%s: 'front unit'" % card.id)
		assert_false(t.contains("red dots"), "%s: 'incoming', not 'red dots'" % card.id)
		assert_false(t.contains("+1/+1"), "%s: '+1 FP and +1 Armor', not '+1/+1'" % card.id)


func test_every_vanilla_card_has_its_own_lore() -> void:
	var seen: Dictionary = {}
	for card: CardData in CardDB.all_cards():
		if not card.is_unit() or card.text != "" or not CardInfo.keywords(card).is_empty():
			continue
		assert_true(CardLore.LINES.has(card.id), "%s: a lore line of its own" % card.id)
		var line: String = CardLore.line(card.id, card.standard_issue)
		assert_true(line.split(" ", false).size() <= 12, "%s: at most 12 words" % card.id)
		assert_false(seen.has(line), "%s: not shared with %s" % [card.id, seen.get(line, "")])
		seen[line] = card.id
		var low: String = line.to_lower()
		assert_false(low.contains("call of duty") or low.contains("modern warfare") or low.contains("price"), "%s: original" % card.id)
	assert_true(seen.size() >= 10, "the Privates, Standard Issue and vanilla calling cards (%d)" % seen.size())


func test_inspector_flavour_only_where_the_face_has_none() -> void:
	assert_eq(CardLore.flavour(&"kc_wip_private_1", true), "", "vanilla: the card face shows it")
	assert_eq(CardLore.flavour(&"marksman", false), String(CardLore.LINES[&"marksman"]), "a keyword card: the inspector shows it")
	assert_eq(CardLore.flavour(&"kc_wip_barrage", false), "", "no filler line")


func test_stats_line_and_keyword_sentences() -> void:
	var sniper: CardData = CardDB.get_card(&"kc_wip_sniper")
	assert_eq(CardInfo.stats_line(sniper), "%d Supply · %d FP · %d Armor" % [sniper.cost, sniper.firepower, sniper.armor], "cost, FP, Armor")
	assert_eq(CardInfo.rules_without_keywords("Pick. Its eliminations give +1 streak.", PackedStringArray(["pick"])),
			"Its eliminations give +1 streak.", "a keyword-only sentence drops (its line says it)")
	assert_eq(CardInfo.rules_without_keywords("Cover 1. Front line.", PackedStringArray(["cover 1", "front line"])), "", "all keywords")
