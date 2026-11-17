# concept_registry.gd
# Purpose: kc-ui-pass (head, Nov 2026: "a list of concepts, and the first time the player sees one we
#   explain it, otherwise we don't talk about it"). The ONE list of things a new player has to learn:
#   the core concepts of a match and of a run, every card keyword (CardInfo.KEYWORD_RULES plus the
#   special rules a card can carry), every trait (SynergyRules) and every Terrain (TerrainRules).
#   Each concept: {id, title, text (1-2 plain beginner sentences), group, trigger (when it is first
#   explained: a short note for the Codex and for designers)}.
#   Ids match the old progressive-reveal flags (RevealFlags: run_map, event, kw_pick, terrain_smoke ...)
#   so a tip dismissed before this pass counts as seen (they share Settings.seen_flags).
#   The callouts (ConceptGuide autoload), the Codex glossary and the drill all read this file.
#   Keyword texts are not copied here: they come from CardInfo.KEYWORD_RULES (the callout uses the
#   one-line rule the card and inspector print, "detail" the full rule the Glossary shows), so a
#   keyword never reads one way in a tip and another way on the card.
# Dependencies: card_info.gd, SynergyRules, TerrainRules, CardData, DataEnums.
# Author: UI/UX Agent (kc-ui-pass)
class_name ConceptRegistry
extends RefCounted

const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")

const GROUP_MATCH: StringName = &"match"
const GROUP_RUN: StringName = &"run"
const GROUP_KEYWORD: StringName = &"keyword"
const GROUP_TRAIT: StringName = &"trait"
const GROUP_TERRAIN: StringName = &"terrain"
const GROUP_WORDS: Dictionary = {GROUP_MATCH: "THE MATCH", GROUP_RUN: "THE RUN", GROUP_KEYWORD: "KEYWORDS",
		GROUP_TRAIT: "TRAITS", GROUP_TERRAIN: "TERRAIN"}
const GROUP_ORDER: Array[StringName] = [GROUP_MATCH, GROUP_RUN, GROUP_KEYWORD, GROUP_TRAIT, GROUP_TERRAIN]

## Core concepts in the order a first run meets them: [title, text, trigger].
## Text rule: at most 2 short sentences, no jargon that is not itself a concept, numbers as digits.
const CORE: Dictionary = {
	# --- the match ---
	&"goal": ["Win the match", "Score points by holding columns. The bars over the board fill as you score: first to reach the middle wins.",
			"First Deploy of the first match (anchored to the score race over the board)."],
	&"mulligan": ["Swap your hand", "Tap the cards you don't want, then REDRAW. Free, once per match.",
			"The first mulligan panel."],
	&"hand": ["Your cards", "Drag a card onto a column to play it, or tap it, then tap a column. Right click or hold any card to read it.",
			"First Deploy (anchored to the hand)."],
	&"operator": ["Your Operator", "Your hero card, always in your hand. Free in round 1. If it goes down, you can send it again next round.",
			"The Operator card, first time it can be deployed."],
	&"supply": ["Supply", "Pays for cards: the number in a card's corner is its cost. You get 1 more each round (up to 7).",
			"First Deploy (anchored to the Supply counter)."],
	&"ready": ["READY", "When your plan is set, tap READY. Both sides' cards go off at the same time (nobody goes first), then the columns fight.",
			"First Deploy, after a card is played (anchored to READY)."],
	&"stats": ["Firepower and Armor", "The teal ring is the damage it deals per shot. The plate is its health: at 0 it is eliminated.",
			"The first unit on the board."],
	&"incoming": ["Incoming", "The rival played a card face down here. You see what it is when the round starts.",
			"The first INCOMING marker."],
	&"spotted": ["Spotted", "Your recon revealed this rival card: it lands here when the round starts. Long press it to read it.",
			"The first SPOTTED card (Recon Drone, Callout, Recon Specialist, Floodlights)."],
	&"firefight": ["The firefight", "The front units of each column shoot each other. When a front unit falls, the one behind steps up.",
			"From round 2, the first Deploy with a column where both sides have units (anchored to their front units)."],
	&"control": ["Holding a column", "After the fight, a column where only you have units is yours. Each column you hold scores its +1.",
			"First Deploy after a column was taken (anchored to that column's tile)."],
	&"streak": ["Streak", "Each enemy you eliminate adds 1. If your Operator goes down, it goes back to 0.",
			"Round 2 (anchored to the streak counter)."],
	&"killstreak": ["Killstreaks", "Rewards for your streak. When one lights up, tap it to call it in. Free.",
			"Round 2, or the first time one is ready (anchored to the killstreak sockets)."],
	&"operator_ability": ["Operator ability", "Once your Operator is on the board, its card is a button: one free ability per match.",
			"The first Deploy with the Operator on the board."],
	&"move": ["Move", "The four-way arrow means this unit can move to any other column this round. Drag it there.",
			"The first unit that can move."],
	&"tactic": ["Tactics", "A one-time order. Play it in a column; it goes off when the round starts, then it is gone.",
			"The first Tactic in hand."],
	&"field": ["Fields", "Stays in its column and keeps working. If the rival holds that column at round end, it is destroyed.",
			"The first Field in hand or in play."],
	&"elites": ["Elites", "One of a kind, stronger than the rest, with a printed trait.",
			"The first Elite card offered or in hand."],
	&"damaged": ["Damaged", "An amber Armor plate means it has lost Armor. Armor does not come back unless a card heals it.",
			"The first damaged unit."],
	&"preview": ["Forecast", "Tap the eye to preview how this round's fight goes, from what you can see now.",
			"From the second run, when the eye shows in the left strip."],
	&"trait_rail": ["Sets", "2 or 3 cards of the same trait in play give a bonus. The rail on the left shows your sets.",
			"The first traited unit in play."],
	# --- the run ---
	&"starter": ["Your squad", "Pick an Operator. Your starting deck is 10 plain cards; you add better ones as you go.",
			"The starting squad screen."],
	&"loadout": ["Loadout", "Pick 3 killstreaks to bring. You earn them in matches with your streak.",
			"The loadout screen."],
	&"run_map": ["The run map", "Pick your next stop. Every path ends at the boss; win there to win the run.",
			"The first run map."],
	&"node_fight": ["Fights", "A match. Win it for a Supply Drop (new cards) and REQ.",
			"The first fight stop selected on the map."],
	&"elite_fight": ["Elite fights", "A tougher crew for a better reward. Optional; a loss costs a ticket.",
			"The first elite stop selected."],
	&"event": ["Events", "A short story with choices. Each choice says exactly what it gives or costs.",
			"The first event stop selected, then the event screen."],
	&"shop": ["Shop", "Spend REQ on cards, or pay to remove cards you don't want.",
			"The first shop stop selected, then the shop."],
	&"rest": ["Rest", "Pick one: a ticket back, remove 2 cards, or a weapon level.",
			"The first rest stop selected, then the rest screen."],
	&"boss_rule": ["The boss", "The last fight. The boss plays with one extra rule, shown from the start.",
			"The first run map (anchored to the boss panel)."],
	&"tickets": ["Tickets", "Your lives for this run. A lost match costs 1; at 0 the run is over.",
			"The first run map (anchored to the tickets)."],
	&"requisition": ["REQ", "Money for this run. Earn it in fights and events, spend it in the shop.",
			"The first time you have REQ."],
	&"supply_drop": ["Supply Drop", "Your reward: take a card for your deck. Right click or hold a card to read it first.",
			"The first Supply Drop."],
	&"calling_cards": ["Calling cards", "Better cards, each with a trait. Your first one's trait is your Doctrine: it counts 1 extra.",
			"The first calling card offered."],
	&"doctrine": ["Doctrine", "Your run's favourite trait: its sets count 1 extra while one of its cards is in play.",
			"The first calling card taken."],
	&"multi_pick": ["Pick 2", "This drop lets you take 2 of the cards.", "The first drop with two picks."],
	&"retire": ["Retire", "Instead of a new card, remove one you don't want.", "The first drop that offers Retire."],
	&"salvage": ["Salvage", "Lost a match? You still salvage a card from the field.", "The first Salvage."],
	&"muster_out": ["Muster out", "Remove Standard Issue cards from your deck so your good cards come up more often.",
			"The first Muster out."],
	&"deck": ["Your deck", "Every card you own. Each round you draw from it; a smaller, stronger deck draws its best cards more.",
			"The first deck view."],
	&"engine_panel": ["Deck summary", "What your deck adds up to: its traits and its strongest plays.",
			"The first deck view with a calling card."],
	&"terrain": ["Terrain", "Terrain changes one rule in its column, for both sides.", "The first Terrain in play."],
	&"modifiers": ["Modifiers", "Optional challenges for a harder run. They unlock looks, never power.",
			"The first time modifiers are on offer."],
	&"duel": ["Duel", "A single match with a deck you build, against a bot.", "The duel hub."],
}

## Keyword concepts beyond CardInfo.KEYWORD_RULES (special rules a card can carry): [title, text].
const EXTRA_KEYWORDS: Dictionary = {
	&"one_use": ["One use", "Goes away after it goes off once."],
	&"no_streak": ["No streak credit", "Eliminating it does not add to the streak."],
}

## CardData properties in its "Keywords" and "Special rules" groups -> the keyword concept a card
## with a non-default value teaches. "" = not shown to players (a data flag, not a rule).
## test_concepts.gd fails when a new property in those groups is missing here.
const PROPERTY_CONCEPTS: Dictionary = {
	&"first_shot": &"kw_first_shot", &"pick": &"kw_pick", &"flank": &"kw_flank", &"cover": &"kw_cover",
	&"suppress": &"kw_suppress", &"suppress_amount": &"kw_suppress", &"pierce": &"kw_pierce", &"patch": &"kw_patch",
	&"holder": &"kw_holder", &"agile": &"kw_agile", &"beam": &"kw_beam",
	&"arrives_front": &"kw_arrives_front", &"hidden": &"kw_hidden", &"consumed_on_trigger": &"kw_one_use",
	&"counts_for_control": &"kw_no_control", &"grants_elimination_credit": &"kw_no_streak",
	&"collectible": &"", &"standard_issue": &"",
}
## Old progressive-reveal flag -> concept id (the same concept under an older name).
const ALIASES: Dictionary = {&"kw_front": &"kw_arrives_front", &"requisition": &"requisition", &"killstreaks": &"killstreak",
		&"fields": &"field", &"keywords": &"hand"}

static var _all: Dictionary = {}


## Every concept: id -> {id, title, text, group, trigger}. Built once.
static func all() -> Dictionary:
	if _all.is_empty():
		_build()
	return _all


static func has(id: StringName) -> bool:
	return all().has(resolve(id))


## The concept {id, title, text, group, trigger} ({} when unknown).
static func get_concept(id: StringName) -> Dictionary:
	return all().get(resolve(id), {})


static func resolve(id: StringName) -> StringName:
	return ALIASES.get(id, id)


## Ids in Codex order (group, then the order above).
static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for g: StringName in GROUP_ORDER:
		for id: StringName in all():
			if all()[id]["group"] == g:
				out.append(id)
	return out


static func ids_in(group: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ids():
		if all()[id]["group"] == group:
			out.append(id)
	return out


## The keyword concept of a CardInfo keyword entry id (&"pick" -> &"kw_pick").
static func keyword_concept(kw_id: StringName) -> StringName:
	return StringName("kw_" + String(kw_id))


## The concepts a card teaches when a player first sees it: its keywords, its type (Tactic / Field),
## Elite, and its trait. In the order they should be explained.
static func for_card(card: CardData) -> Array[StringName]:
	var out: Array[StringName] = []
	if card == null:
		return out
	if card.card_type == DataEnums.CardType.TACTIC:
		out.append(&"tactic")
	elif card.card_type == DataEnums.CardType.EQUIPMENT:
		out.append(&"field")
	for k: Dictionary in CardInfo.keywords(card):
		var c: StringName = keyword_concept(k["id"])
		if not out.has(c):
			out.append(c)
	if card.is_unit() and not card.grants_elimination_credit:
		out.append(&"kw_no_streak")
	if card.consumed_on_trigger:
		out.append(&"kw_one_use")
	if card.is_elite:
		out.append(&"elites")
	var tr: StringName = card.card_trait
	if tr != &"" and SynergyRules.is_single_trait(tr) and tr != &"~default":
		out.append(StringName("trait_" + String(tr)))
	return out


## The keyword concepts of a unit on the board (its live keywords plus its card's triggers).
static func for_unit(u: RulesUnit) -> Array[StringName]:
	var out: Array[StringName] = []
	if u == null:
		return out
	for k: Dictionary in CardInfo.unit_keywords(u):
		out.append(keyword_concept(k["id"]))
	if u.synergy_trait != &"" and SynergyRules.is_single_trait(u.synergy_trait):
		out.append(StringName("trait_" + String(u.synergy_trait)))
	return out


static func _build() -> void:
	var d: Dictionary = {}
	for id: StringName in CORE:
		if id == &"preview" and not UiFeatures.FORECAST_EYE:
			continue  # the PREVIEW eye is parked: never explained, not in the Glossary
		var row: Array = CORE[id]
		d[id] = {"id": id, "title": row[0], "text": row[1], "trigger": row[2],
				"group": GROUP_RUN if _is_run(id) else GROUP_MATCH}
	for kw: StringName in CardInfo.KEYWORD_RULES:
		var row: Array = CardInfo.KEYWORD_RULES[kw]
		var cid: StringName = keyword_concept(kw)
		d[cid] = {"id": cid, "title": String(row[0]).replace(" %d", "").replace("%d", "N"),
				"text": String(row[1]).replace("%d", "N"), "detail": String(row[2]).replace("%d", "N"), "group": GROUP_KEYWORD,
				"trigger": "The first card with %s you see (hand, reward or a rival unit)." % String(row[0]).replace(" %d", "")}
	for kw: StringName in EXTRA_KEYWORDS:
		var cid: StringName = keyword_concept(kw)
		d[cid] = {"id": cid, "title": EXTRA_KEYWORDS[kw][0], "text": EXTRA_KEYWORDS[kw][1], "group": GROUP_KEYWORD,
				"trigger": "The first card with this rule you see."}
	for tr: StringName in SynergyRules.TRAITS:
		var tiers: Array = SynergyRules.TIER_TEXT.get(tr, ["", ""])
		var cid: StringName = StringName("trait_" + String(tr))
		d[cid] = {"id": cid, "title": String(SynergyRules.TRAIT_NAMES.get(tr, tr)),
				"text": "A trait. 2 in play: %s. 3 in play: %s." % [String(tiers[0]), String(tiers[1]).trim_prefix("3 %s: " % SynergyRules.TRAIT_NAMES.get(tr, ""))],
				"group": GROUP_TRAIT, "trigger": "The first card of this trait you see."}
	for t: StringName in TerrainRules.ALL:
		var cid: StringName = StringName("terrain_" + String(t))
		d[cid] = {"id": cid, "title": TerrainRules.name_of(t), "text": TerrainRules.text_of(t) + " Both sides.",
				"group": GROUP_TERRAIN, "trigger": "The first time this Terrain is on a column."}
	_all = d


static func _is_run(id: StringName) -> bool:
	return id in [&"starter", &"loadout", &"run_map", &"node_fight", &"elite_fight", &"event", &"shop", &"rest", &"boss_rule",
			&"tickets", &"requisition", &"supply_drop", &"calling_cards", &"doctrine", &"multi_pick", &"retire", &"salvage",
			&"muster_out", &"deck", &"engine_panel", &"modifiers", &"duel"]
