# duel_views.gd
# Purpose: kc-duel-ui. The one place the Duel screens read Duel data from (duel-mode.md §2, §5-§7 and
#   the head's decisions of 2026-11-09). Like run_v2_views.gd, it asks the rules API first
#   (documentation/technical/duel-api.md: DuelRules / DuelCollection / DuelDeck under scripts/duel/,
#   the save slots in Settings) and falls back to the spec's own numbers while a part has not landed,
#   so every screen works and can be screenshotted today. Screens never read scripts/duel directly.
#   The head's decisions it follows:
#   - exactly 10 picks, each x2 (20 cards), at least 5 unit picks, at most 1 Elite, at most 3 Fields;
#   - the hero is the Operator in its own slot from round 1, with ONE stat set for both modes (the
#     Operator's LoadoutItem numbers; no "Duel stats" line);
#   - pool: units and tactics open, Fields and Elites found in campaign runs, presets and heroes always
#     playable (loaners);
#   - the player picks a Doctrine trait for the deck (its rule text comes from the rules API).
#   A deck here is a Dictionary:
#     {id: String ("" = unsaved), name, hero: StringName, doctrine: StringName,
#      picks: [{card: StringName, art: StringName}], preset: bool, plan: String}
#   A pick's art decides its trait (art-traits.md); trait_of(pick) reads it.
# Dependencies: CardDB, Settings, ArtTraits, SynergyRules, RunV2Views (Operator kits), BannerArtDB.
# Author: UI/UX Agent (kc-duel-ui)
extends RefCounted

const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")

## The rules API (duel-mode.md §9.1). Missing files = the fallbacks below.
const RULES_PATH: String = "res://scripts/duel/duel_rules.gd"
const COLLECTION_PATH: String = "res://scripts/duel/duel_collection.gd"

const MAX_PICKS: int = 10
const COPIES: int = 2
const MIN_UNITS: int = 5
const MAX_ELITE: int = 1
const MAX_FIELDS: int = 3
const MAX_SLOTS: int = 8
const NAME_MAX: int = 20
## Curve buckets: cost 1 or less, 2, 3, 4, 5+.
const CURVE_LABELS: PackedStringArray = ["1", "2", "3", "4", "5+"]

const HEROES: Array[StringName] = [&"kestrel_ar7", &"longreach_338", &"wasp_9", &"bastion_60"]
## duel-mode.md §3.1 "Plays like".
const PLAYS_LIKE: Dictionary = {&"kestrel_ar7": "The steady all-rounder.", &"longreach_338": "Picks off the backline.",
		&"wasp_9": "Goes where the fight is.", &"bastion_60": "Holds one column."}

const TIERS: Array[StringName] = [&"recruit", &"regular", &"veteran"]
const TIER_NAMES: Dictionary = {&"recruit": "RECRUIT", &"regular": "REGULAR", &"veteran": "VETERAN"}
## duel-mode.md §4.1: shown before the match.
const TIER_LINES: Dictionary = {
	&"recruit": "Its cards have -1 Armor and it makes mistakes. For your first duels.",
	&"regular": "Plays well, ignores sets.",
	&"veteran": "Plays its best, no handicap.",
}

## duel-mode.md §5 (the final lists). [card, trait] with &"" = the chassis' own trait.
const PRESET_DATA: Array[Dictionary] = [
	{"id": "preset_spearhead", "name": "Spearhead", "trait": &"vanguard", "hero": &"kestrel_ar7",
		"plan": "First Shot up front, Cover behind it, take the column early.", "picks": [
		[&"point_man", &"vanguard"], [&"rifleman", &""], [&"breacher", &"vanguard"], [&"shieldman", &"vanguard"],
		[&"flank_route", &""], [&"hold_the_line", &""], [&"brawler", &"undead"], [&"bulwark", &"vanguard"],
		[&"blackout", &""], [&"ammo_resupply", &""]]},
	{"id": "preset_overwatch", "name": "Overwatch", "trait": &"specops", "hero": &"longreach_338",
		"plan": "Pick off the backline, hide your own, finish with Wren.", "picks": [
		[&"rifleman", &"specops"], [&"recon_specialist", &"specops"], [&"marksman", &"specops"], [&"brawler", &"specops"],
		[&"flanker", &"specops"], [&"smoke_screen", &""], [&"sniper_perch", &"specops"], [&"halek_wren", &"specops"],
		[&"breach_and_clear", &""], [&"combat_medic", &"specops"]]},
	{"id": "preset_iron_wall", "name": "Iron Wall", "trait": &"heavy", "hero": &"bastion_60",
		"plan": "Hold one column with Gunners and Anvil; the Mortar does the rest.", "picks": [
		[&"rifleman", &""], [&"breacher", &"heavy"], [&"gunner", &"heavy"], [&"marksman", &"heavy"],
		[&"demolitions_expert", &"heavy"], [&"ammo_resupply", &""], [&"suppressing_fire", &""], [&"mortar_pit", &"heavy"],
		[&"okafor_anvil", &"heavy"], [&"hold_the_line", &""]]},
	{"id": "preset_hollow_ranks", "name": "Hollow Ranks", "trait": &"undead", "hero": &"wasp_9",
		"plan": "Cheap bodies that come back stronger; trap the lane, then clear it.", "picks": [
		[&"rifleman", &"undead"], [&"brawler", &"undead"], [&"point_man", &"undead"], [&"shieldman", &"undead"],
		[&"recon_specialist", &"undead"], [&"flanker", &"undead"], [&"war_standard", &"undead"], [&"breach_and_clear", &""],
		[&"tripwire_charge", &""], [&"sabotage", &""]]},
]

## Tests / previews: card id -> true / false stands in for the collection (owned or locked).
static var owned_override: Dictionary = {}
## Tests / previews: hero id -> true / false stands in for the run profile's unlocks.
static var hero_override: Dictionary = {}
## Saved decks while the Settings save slots have not landed (this session only).
static var _local_decks: Array = []
## Records while the rules have none: key -> {w, l, d}.
static var _local_records: Dictionary = {}
static var _local_seq: int = 0
## Tests: false = ignore the rules API even when it exists (proves the fallbacks).
static var use_rules: bool = true


# =============================================================================
# The rules API (optional)
# =============================================================================

static func _script(path: String) -> GDScript:
	if not use_rules or not ResourceLoader.exists(path):
		return null
	return load(path) as GDScript


## Calls a static method of the rules API (DuelRules, else DuelCollection). null = not there.
static func _ask(method: StringName, args: Array = []) -> Variant:
	for path: String in [RULES_PATH, COLLECTION_PATH]:
		var s: GDScript = _script(path)
		if s == null:
			continue
		for m: Dictionary in s.get_script_method_list():
			if StringName(m["name"]) == method:
				return s.callv(method, args)
	return null


static func _settings() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"/root/Settings") if tree != null else null


static func _db() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"/root/CardDB") if tree != null else null


static func card(id: StringName) -> CardData:
	var db: Node = _db()
	if db != null and db.has_card(id):
		return db.get_card(id)
	var path: String = "res://data/cards/%s.tres" % id
	return load(path) as CardData if ResourceLoader.exists(path) else null


static func hero_item(id: StringName) -> LoadoutItem:
	var db: Node = _db()
	var item: LoadoutItem = db.get_loadout_item(id) if db != null else null
	if item == null and ResourceLoader.exists("res://data/loadout/%s.tres" % id):
		item = load("res://data/loadout/%s.tres" % id) as LoadoutItem
	return item


# =============================================================================
# The card pool
# =============================================================================

static func kind_of(c: CardData) -> StringName:
	if c == null:
		return &""
	return &"unit" if c.is_unit() else (&"field" if c.is_field() else &"tactic")


## True when the card can be in a Duel deck at all (no tokens, no Standard Issue, no boss cards).
static func in_pool(c: CardData) -> bool:
	return c != null and c.collectible and not c.standard_issue and not c.is_token()


## Units and tactics are open from the start; Fields and Elites once found in a campaign run.
static func needs_unlock(c: CardData) -> bool:
	return c != null and (c.is_field() or c.is_elite)


## True when the player owns the card for their own decks.
static func is_owned(c: CardData) -> bool:
	if c == null:
		return false
	if owned_override.has(c.id):
		return bool(owned_override[c.id])
	var v: Variant = _ask(&"is_owned", [c.id])
	if v is bool:
		return v
	if not needs_unlock(c):
		return true
	var st: Node = _settings()
	if st != null:
		var prof: Variant = st.get(&"run_profile")
		if prof is Dictionary:
			var found: Variant = (prof as Dictionary).get("found_cards", [])
			if found is Array or found is Dictionary:
				return String(c.id) in found or StringName(c.id) in found
	return false


## Every Duel card as a grid entry, sorted by cost then name:
## {id, card, kind, cost, name, elite, owned, traits: Array[StringName], keywords: PackedStringArray}.
static func pool() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var db: Node = _db()
	if db == null:
		return out
	for c: CardData in db.all_cards():
		if not in_pool(c):
			continue
		var kws: PackedStringArray = []
		for k: String in [&"first_shot", &"pick", &"flank", &"suppress", &"pierce"]:
			if bool(c.get(k)):
				kws.append(k)
		if c.cover > 0:
			kws.append("cover")
		if c.patch > 0:
			kws.append("patch")
		out.append({"id": c.id, "card": c, "kind": kind_of(c), "cost": c.cost, "name": c.display_name,
				"elite": c.is_elite, "owned": is_owned(c), "traits": c.trait_choices(), "keywords": kws})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["cost"]) != int(b["cost"]):
			return int(a["cost"]) < int(b["cost"])
		return String(a["name"]) < String(b["name"]))
	return out


## Unlock line for a locked card (the head's words).
static func unlock_line(_c: CardData) -> String:
	return "Find it in a campaign run"


# =============================================================================
# Picks, traits, curve
# =============================================================================

## The art a new pick of `c` wears for trait `t` (&"" = the chassis' default option).
static func art_for(c: CardData, t: StringName = &"") -> StringName:
	if c == null:
		return &""
	if not c.has_trait_choice():
		return c.id
	var want: StringName = t if t != &"" and c.can_carry(t) else c.trait_choices()[0]
	return ArtTraits.default_art(c, want)


static func make_pick(id: StringName, t: StringName = &"") -> Dictionary:
	var c: CardData = card(id)
	return {"card": id, "art": art_for(c, t)}


## The trait both copies of a pick wear (&"" = none).
static func trait_of(pick: Dictionary) -> StringName:
	var c: CardData = card(StringName(str(pick.get("card", ""))))
	if c == null or not c.is_unit():
		return &""
	return ArtTraits.trait_of(StringName(str(pick.get("art", ""))), c)


static func pick_ids(deck: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in deck.get("picks", []):
		out.append(StringName(str(p.get("card", ""))))
	return out


static func has_pick(deck: Dictionary, id: StringName) -> bool:
	return id in pick_ids(deck)


## Copies per cost bucket (1 or less, 2, 3, 4, 5+): 5 ints.
static func curve(deck: Dictionary) -> Array[int]:
	var out: Array[int] = [0, 0, 0, 0, 0]
	for id: StringName in pick_ids(deck):
		var c: CardData = card(id)
		if c != null:
			out[clampi(c.cost - 1, 0, 4)] += COPIES
	return out


## Picks per bucket for one cost (curve bar -> grid filter): 1 = "1 or less", 5 = "5+".
static func cost_bucket(cost: int) -> int:
	return clampi(cost, 1, 5)


## {units, tactics, fields, elites (picks), traits: {trait: copies}}.
static func composition(deck: Dictionary) -> Dictionary:
	var out: Dictionary = {"units": 0, "tactics": 0, "fields": 0, "elites": 0, "traits": {}}
	for p: Dictionary in deck.get("picks", []):
		var c: CardData = card(StringName(str(p.get("card", ""))))
		if c == null:
			continue
		match kind_of(c):
			&"unit":
				out["units"] += 1
			&"field":
				out["fields"] += 1
			_:
				out["tactics"] += 1
		if c.is_elite:
			out["elites"] += 1
		var t: StringName = trait_of(p)
		if t != &"":
			out["traits"][t] = int(out["traits"].get(t, 0)) + COPIES
	return out


## The trait with the most copies (&"" = none).
static func main_trait(deck: Dictionary) -> StringName:
	var best: StringName = &""
	var n: int = 0
	var traits: Dictionary = composition(deck)["traits"]
	for t: StringName in traits:
		if int(traits[t]) > n:
			n = int(traits[t])
			best = t
	return best


## "Heavy · Bastion-60" (duel-mode.md §6.3), at most NAME_MAX characters.
static func default_name(deck: Dictionary) -> String:
	var t: StringName = main_trait(deck)
	var hero: LoadoutItem = hero_item(StringName(str(deck.get("hero", ""))))
	var parts: PackedStringArray = []
	parts.append(SynergyGlyphs.trait_name(t) if t != &"" else "New deck")
	if hero != null:
		parts.append(hero.display_name)
	return clip_name(" · ".join(parts))


static func clip_name(s: String) -> String:
	return s.strip_edges().substr(0, NAME_MAX)


# =============================================================================
# Heroes and Doctrine
# =============================================================================

## The four heroes: {id, item, name, fp, armor, passive_name, passive_text, ability_name, ability_text,
## plays_like, unlocked, unlock_text}. One stat set for both modes (the Operator's own numbers).
static func heroes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in HEROES:
		var h: Dictionary = hero(id)
		if not h.is_empty():
			out.append(h)
	return out


static func hero(id: StringName) -> Dictionary:
	var item: LoadoutItem = hero_item(id)
	if item == null:
		return {}
	var kit: Dictionary = RunV2Views.operator_kit(id)
	var unlocked: bool = bool(kit.get("unlocked", true))
	var v: Variant = _ask(&"hero_unlocked", [id])
	if v is bool:
		unlocked = v
	elif item.unlock != &"":
		var st: Node = _settings()
		var prof: Variant = st.get(&"run_profile") if st != null else null
		var rp: GDScript = load("res://scripts/run/run_profile.gd") as GDScript
		if prof is Dictionary and rp != null:
			unlocked = bool(rp.call(&"is_unlocked", prof, item.unlock))
	if hero_override.has(id):
		unlocked = bool(hero_override[id])
	var ability_text: String = String(kit.get("ability_text", ""))
	if item.ability != null and item.ability.text != "":
		ability_text = item.ability.text
	return {"id": id, "item": item, "name": item.display_name, "fp": item.operator_firepower, "armor": item.operator_armor,
			"passive_name": String(kit.get("passive_name", item.passive_name)),
			"passive_text": item.passive_text if item.passive_text != "" else String(kit.get("passive_text", "")),
			"ability_name": String(kit.get("ability_name", item.ability.display_name if item.ability != null else "")),
			"ability_text": ability_text, "plays_like": String(PLAYS_LIKE.get(id, "")),
			"unlocked": unlocked, "unlock_text": String(kit.get("unlock_text", ""))}


## The Doctrine choices: {id, name, text}. The rule text comes from the rules (doctrine_text(t)), else
## the campaign's words (+1 to that trait's count) with its set lines.
static func doctrines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: StringName in SynergyRules.TRAITS:
		out.append({"id": t, "name": SynergyGlyphs.trait_name(t), "text": doctrine_text(t)})
	return out


static func doctrine_text(t: StringName) -> String:
	if t == &"":
		return "No Doctrine picked yet."
	var v: Variant = _ask(&"doctrine_text", [t])
	if v is String and v != "":
		return v
	return "Doctrine %s: your %s count gets +1, so its set lights up one card sooner. %s · %s." % [
			SynergyGlyphs.trait_name(t), SynergyGlyphs.trait_name(t), SynergyGlyphs.tier_line(t, 2), SynergyGlyphs.tier_line(t, 3)]


# =============================================================================
# Decks: presets, saves, rules
# =============================================================================

static func new_deck(hero_id: StringName = &"kestrel_ar7") -> Dictionary:
	return {"id": "", "name": "", "hero": hero_id, "doctrine": &"", "picks": [], "preset": false, "plan": ""}


## The 4 presets (the rules' data when it exists, else duel-mode.md §5). Always playable.
static func presets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var v: Variant = _ask(&"preset_decks")
	if v is Array and not (v as Array).is_empty():
		for d: Variant in v:
			var deck: Dictionary = from_rules(d)
			deck["preset"] = true
			out.append(deck)
		return out
	for p: Dictionary in PRESET_DATA:
		var picks: Array = []
		for pk: Array in p["picks"]:
			picks.append(make_pick(pk[0], pk[1]))
		out.append({"id": p["id"], "name": p["name"], "hero": p["hero"], "doctrine": p["trait"], "picks": picks,
				"preset": true, "plan": p["plan"]})
	return out


static func preset(id: String) -> Dictionary:
	for d: Dictionary in presets():
		if String(d["id"]) == id:
			return d
	return {}


## A copy of `deck` the player can edit ("<name> copy", unsaved).
static func copy_of(deck: Dictionary) -> Dictionary:
	var d: Dictionary = deck.duplicate(true)
	d["id"] = ""
	d["preset"] = false
	d["name"] = clip_name("%s copy" % String(deck.get("name", "Deck")))
	return d


## The player's saved decks (up to MAX_SLOTS).
static func saved_decks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var v: Variant = _ask(&"saved_decks")
	if v == null:
		var st: Node = _settings()
		if st != null and st.has_method(&"duel_decks"):
			v = st.call(&"duel_decks")
	if v is Array:
		for d: Variant in v:
			out.append(from_rules(d))
		return out
	for d: Dictionary in _local_decks:
		out.append(d.duplicate(true))
	return out


## Saves `deck` (new: a free slot; else in place). {ok, id, text}.
static func save_deck(deck: Dictionary) -> Dictionary:
	var d: Dictionary = deck.duplicate(true)
	if String(d.get("name", "")).strip_edges() == "":
		d["name"] = default_name(d)
	d["name"] = clip_name(String(d["name"]))
	var v: Variant = _ask(&"save_deck", [to_rules(d)])
	if v is Dictionary:
		return v
	var at: int = -1
	for i: int in _local_decks.size():
		if String(_local_decks[i]["id"]) == String(d.get("id", "")) and String(d.get("id", "")) != "":
			at = i
	if at < 0:
		if _local_decks.size() >= MAX_SLOTS:
			return {"ok": false, "id": "", "text": "All %d deck slots are full: delete a deck first." % MAX_SLOTS}
		_local_seq += 1
		d["id"] = "deck_%d_%d" % [Time.get_ticks_msec(), _local_seq]
		d["created"] = Time.get_unix_time_from_system()
		_local_decks.append(d)
	else:
		_local_decks[at] = d
	d["edited"] = Time.get_unix_time_from_system()
	return {"ok": true, "id": d["id"], "text": "Saved %s." % d["name"]}


static func delete_deck(id: String) -> bool:
	var v: Variant = _ask(&"delete_deck", [id])
	if v is bool:
		return v
	for i: int in _local_decks.size():
		if String(_local_decks[i]["id"]) == id:
			_local_decks.remove_at(i)
			return true
	return false


static func free_slots() -> int:
	return MAX_SLOTS - saved_decks().size()


## Tests: forget the session's local decks and records.
static func reset_local() -> void:
	_local_decks.clear()
	_local_records.clear()
	owned_override.clear()
	hero_override.clear()


## A rules deck (Dictionary, or an object with to_dict()) -> the screen's deck shape.
static func from_rules(v: Variant) -> Dictionary:
	var d: Dictionary = {}
	if v is Dictionary:
		d = v
	elif v is Object and (v as Object).has_method(&"to_dict"):
		d = (v as Object).call(&"to_dict")
	var picks: Array = []
	for p: Variant in d.get("picks", []):
		if p is Dictionary:
			var id: StringName = StringName(str(p.get("card_id", p.get("card", ""))))
			var art: StringName = StringName(str(p.get("art_id", p.get("art", ""))))
			if art == &"":
				art = art_for(card(id), StringName(str(p.get("trait", ""))))
			picks.append({"card": id, "art": art})
	return {"id": str(d.get("id", "")), "name": str(d.get("name", "")), "hero": StringName(str(d.get("hero_id", d.get("hero", "")))),
			"doctrine": StringName(str(d.get("doctrine", ""))), "picks": picks, "preset": bool(d.get("preset", false)),
			"plan": str(d.get("plan", ""))}


## The screen's deck -> the rules' shape (duel-mode.md §6.5).
static func to_rules(deck: Dictionary) -> Dictionary:
	var picks: Array = []
	for p: Dictionary in deck.get("picks", []):
		picks.append({"card_id": p.get("card", &""), "art_id": p.get("art", &"")})
	return {"id": deck.get("id", ""), "name": deck.get("name", ""), "hero_id": deck.get("hero", &""),
			"doctrine": deck.get("doctrine", &""), "picks": picks}


## The deck rules (duel-mode.md §6.4): {ok, errors: [{code, text, fix}], warnings: [{code, text, fix}],
## ready_text}. errors block PLAY (red); warnings are advice (amber). `fix` is a grid filter
## {kind?, cost_max?, cost_min?} that shows the cards that fix it. loaner = a preset (no ownership check).
static func validate(deck: Dictionary, loaner: bool = false) -> Dictionary:
	var v: Variant = _ask(&"validate", [to_rules(deck), loaner])
	var out: Dictionary = {}
	if v is Dictionary and (v as Dictionary).has("ok"):
		out = v
	else:
		out = _validate_local(deck, loaner or bool(deck.get("preset", false)))
	if not out.has("ready_text"):
		var h: Dictionary = hero(StringName(str(deck.get("hero", ""))))
		out["ready_text"] = "READY: %d cards, hero %s" % [pick_ids(deck).size() * COPIES, h.get("name", "?")]
	return out


static func _validate_local(deck: Dictionary, loaner: bool) -> Dictionary:
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	var ids: Array[StringName] = pick_ids(deck)
	var n: int = ids.size()
	var comp: Dictionary = composition(deck)
	if n < MAX_PICKS:
		errors.append({"code": &"picks_short", "text": "Pick %d more card%s (%d/%d)" % [MAX_PICKS - n, "" if MAX_PICKS - n == 1 else "s", n, MAX_PICKS], "fix": {}})
	elif n > MAX_PICKS:
		errors.append({"code": &"picks_over", "text": "Only %d picks (%d/%d): remove %d" % [MAX_PICKS, n, MAX_PICKS, n - MAX_PICKS], "fix": {}})
	if int(comp["units"]) < MIN_UNITS:
		errors.append({"code": &"units_short", "text": "At least %d unit picks (%d/%d)" % [MIN_UNITS, comp["units"], MIN_UNITS], "fix": {"kind": &"unit"}})
	if int(comp["elites"]) > MAX_ELITE:
		var names: PackedStringArray = []
		for id: StringName in ids:
			var c: CardData = card(id)
			if c != null and c.is_elite:
				names.append(c.display_name)
		errors.append({"code": &"elite_over", "text": "Only %d Elite ★ pick (%d/%d): remove %s" % [MAX_ELITE, comp["elites"], MAX_ELITE, " or ".join(names)], "fix": {}})
	if int(comp["fields"]) > MAX_FIELDS:
		errors.append({"code": &"fields_over", "text": "At most %d Field picks (%d/%d)" % [MAX_FIELDS, comp["fields"], MAX_FIELDS], "fix": {"kind": &"field"}})
	var h: Dictionary = hero(StringName(str(deck.get("hero", ""))))
	if h.is_empty():
		errors.append({"code": &"no_hero", "text": "Pick a hero", "fix": {}})
	elif not loaner and not bool(h.get("unlocked", true)):
		errors.append({"code": &"hero_locked", "text": "%s is locked: %s" % [h["name"], h.get("unlock_text", "")], "fix": {}})
	if StringName(str(deck.get("doctrine", ""))) == &"":
		errors.append({"code": &"no_doctrine", "text": "Pick a Doctrine trait", "fix": {}})
	if not loaner:
		for id: StringName in ids:
			var c: CardData = card(id)
			if c != null and not is_owned(c):
				errors.append({"code": &"not_owned", "text": "%s isn't in your collection: find it in a campaign run" % c.display_name, "fix": {}, "card": id})
	# Advice (duel-mode.md §2.1).
	var cheap: int = 0
	var heavy: int = 0
	for id: StringName in ids:
		var c: CardData = card(id)
		if c == null:
			continue
		if c.cost <= 1:
			cheap += 1
		if c.cost >= 4:
			heavy += 1
	if n > 0 and cheap < 2:
		warnings.append({"code": &"few_cheap", "text": "Round 1 gives 1 Supply. You may have nothing to play.", "fix": {"cost_max": 1}})
	if heavy >= 4:
		warnings.append({"code": &"heavy_curve", "text": "Heavy curve: these land from round 4.", "fix": {"cost_min": 4}})
	var unit_traits: Dictionary = {}
	var has_set: bool = false
	for p: Dictionary in deck.get("picks", []):
		var t: StringName = trait_of(p)
		if t == &"":
			continue
		unit_traits[t] = int(unit_traits.get(t, 0)) + 1
		if int(unit_traits[t]) >= 2:
			has_set = true
	if int(comp["units"]) >= 2 and not has_set:
		warnings.append({"code": &"no_set", "text": "No set: 2 units of one trait give a bonus.", "fix": {"kind": &"unit"}})
	if n >= 6 and int(comp["tactics"]) == 0:
		warnings.append({"code": &"no_tactic", "text": "No tactics: you can't answer a column in one round.", "fix": {"kind": &"tactic"}})
	return {"ok": errors.is_empty(), "errors": errors, "warnings": warnings}


## "READY" or "2 PICKS TO GO" / "NEEDS ATTENTION" for a deck tile (shape + word).
static func status_chip(deck: Dictionary) -> Dictionary:
	var r: Dictionary = validate(deck)
	if bool(r["ok"]):
		return {"ok": true, "text": "READY"}
	var left: int = MAX_PICKS - pick_ids(deck).size()
	if left > 0:
		return {"ok": false, "text": "%d PICK%s TO GO" % [left, "" if left == 1 else "S"]}
	return {"ok": false, "text": "NEEDS ATTENTION"}


# =============================================================================
# Records
# =============================================================================

static func _record_key(kind: String, id: String) -> String:
	return "%s:%s" % [kind, id]


## {w, l, d} for a hero (kind "hero") or a preset opponent (kind "preset") or a tier ("tier").
static func record(kind: String, id: String) -> Dictionary:
	var v: Variant = _ask(&"record", [kind, id])
	if v is Dictionary:
		return v
	return _local_records.get(_record_key(kind, id), {"w": 0, "l": 0, "d": 0})


## Notes a finished duel vs AI (the rules keep the real records once they exist).
static func note_result(result: StringName, hero_id: StringName, opponent_id: String, tier: StringName) -> void:
	var v: Variant = _ask(&"note_result", [result, hero_id, opponent_id, tier])
	if v != null:
		return
	var k: String = "w" if result == &"win" else ("l" if result == &"loss" else "d")
	for key: String in [_record_key("hero", String(hero_id)), _record_key("preset", opponent_id), _record_key("tier", String(tier))]:
		var r: Dictionary = _local_records.get(key, {"w": 0, "l": 0, "d": 0})
		r[k] = int(r[k]) + 1
		_local_records[key] = r


static func record_text(r: Dictionary) -> String:
	var t: String = "%d W · %d L" % [int(r.get("w", 0)), int(r.get("l", 0))]
	if int(r.get("d", 0)) > 0:
		t += " · %d D" % int(r["d"])
	return t
