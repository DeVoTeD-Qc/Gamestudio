# duel_views.gd
# Purpose: kc-duel-ui. The one place the Duel screens read Duel data from (duel-mode.md §2, §5-§7 and
#   documentation/technical/duel-api.md). Like run_v2_views.gd, it asks the rules first and falls back
#   when a part has not landed, so every screen works and can be screenshotted in any build:
#     1. the DuelState autoload (duel-api.md §2-§7: card_pool, heroes, presets, decks, validate,
#        start_vs_ai / start_hot_seat, finish, records);
#     2. the rules classes it is built on (DuelRules.validate / create_match, DuelCollection,
#        DuelDeck, CardDB.get_duel_config / get_duel_deck);
#     3. the spec's own numbers (this file), for previews and for the tests of the fallbacks.
#   The head's decisions it follows (duel-api.md §0): exactly 10 picks x2 (20 cards), >= 5 units,
#   <= 1 Elite, <= 3 Fields; the hero is the Operator in its own slot from round 1 with ONE stat set for
#   both modes (the loadout file's numbers); units and tactics open, Fields and Elites found in campaign
#   runs, presets and heroes always playable; the player picks a Doctrine trait (optional unless
#   DuelConfig.doctrine_required).
#   A deck here is a Dictionary (the screens' shape; to_rules / from_rules convert):
#     {id: String ("" = unsaved), name, hero: StringName, doctrine: StringName,
#      picks: [{card: StringName, art: StringName}], preset: bool, plan: String}
#   A pick's art decides its trait (art-traits.md); trait_of(pick) reads it.
# Dependencies: CardDB, Settings, ArtTraits, SynergyRules, RunV2Views (Operator kits), DuelState (optional).
# Author: UI/UX Agent (kc-duel-ui)
extends RefCounted

const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const SynergyGlyphs: GDScript = preload("res://scripts/ui/synergy_glyphs.gd")

## The rules classes (duel-api.md "Implementation map"). Missing files = the fallbacks below.
const RULES_PATH: String = "res://scripts/rules/duel_rules.gd"
const DECK_PATH: String = "res://scripts/data/duel_deck.gd"
const COLLECTION_PATH: String = "res://scripts/run/duel_collection.gd"

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
	&"recruit": "Its cards have −1 Armor and it makes mistakes. For your first duels.",
	&"regular": "Plays well, ignores sets.",
	&"veteran": "Plays its best, no handicap.",
}

## duel-mode.md §5 (the final lists; the rules' presets replace these). [card, trait], &"" = own trait.
const PRESET_DATA: Array[Dictionary] = [
	{"id": "spearhead", "name": "Spearhead", "trait": &"vanguard", "hero": &"kestrel_ar7",
		"plan": "First Shot up front, Cover behind it, take the column early.", "picks": [
		[&"point_man", &"vanguard"], [&"rifleman", &""], [&"breacher", &"vanguard"], [&"shieldman", &"vanguard"],
		[&"flank_route", &""], [&"hold_the_line", &""], [&"brawler", &"undead"], [&"bulwark", &"vanguard"],
		[&"blackout", &""], [&"ammo_resupply", &""]]},
	{"id": "overwatch", "name": "Overwatch", "trait": &"specops", "hero": &"longreach_338",
		"plan": "Pick off the backline, hide your own, finish with Wren.", "picks": [
		[&"rifleman", &"specops"], [&"recon_specialist", &"specops"], [&"marksman", &"specops"], [&"brawler", &"specops"],
		[&"flanker", &"specops"], [&"smoke_screen", &""], [&"sniper_perch", &"specops"], [&"halek_wren", &"specops"],
		[&"breach_and_clear", &""], [&"combat_medic", &"specops"]]},
	{"id": "iron_wall", "name": "Iron Wall", "trait": &"heavy", "hero": &"bastion_60",
		"plan": "Hold one column with Gunners and Anvil; the Mortar does the rest.", "picks": [
		[&"rifleman", &""], [&"breacher", &"heavy"], [&"gunner", &"heavy"], [&"marksman", &"heavy"],
		[&"demolitions_expert", &"heavy"], [&"ammo_resupply", &""], [&"suppressing_fire", &""], [&"mortar_pit", &"heavy"],
		[&"okafor_anvil", &"heavy"], [&"hold_the_line", &""]]},
	{"id": "hollow_ranks", "name": "Hollow Ranks", "trait": &"undead", "hero": &"wasp_9",
		"plan": "Cheap bodies that come back stronger; trap the lane, then clear it.", "picks": [
		[&"rifleman", &"undead"], [&"brawler", &"undead"], [&"point_man", &"undead"], [&"shieldman", &"undead"],
		[&"recon_specialist", &"undead"], [&"flanker", &"undead"], [&"war_standard", &"undead"], [&"breach_and_clear", &""],
		[&"tripwire_charge", &""], [&"sabotage", &""]]},
]
const PRESET_IDS: Array[StringName] = [&"spearhead", &"overwatch", &"iron_wall", &"hollow_ranks"]

## Tests / previews: card id -> true / false stands in for the collection (owned or locked).
static var owned_override: Dictionary = {}
## Tests / previews: hero id -> true / false (D3: every hero is playable, so this is for previews only).
static var hero_override: Dictionary = {}
## Saved decks while DuelState is missing (this session only).
static var _local_decks: Array = []
## Records while DuelState is missing: key -> {w, l, d}.
static var _local_records: Dictionary = {}
static var _local_seq: int = 0
## Tests: false = ignore DuelState and the rules classes (proves the fallbacks).
static var use_rules: bool = true
## Tests: true = keep saves in this session (never write the real profile).
static var local_saves: bool = false


# =============================================================================
# The rules (optional)
# =============================================================================

static func _root() -> Window:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


## The DuelState autoload, or null (not in this build, or use_rules off).
static func state() -> Node:
	var r: Window = _root()
	return r.get_node_or_null(^"/root/DuelState") if use_rules and r != null else null


## DuelState.<method>(args), or null when DuelState / the method is missing.
static func _ask(method: StringName, args: Array = []) -> Variant:
	var s: Node = state()
	if s == null or not s.has_method(method):
		return null
	return s.callv(method, args)


static func _script(path: String) -> GDScript:
	if not use_rules or not ResourceLoader.exists(path):
		return null
	return load(path) as GDScript


static func _settings() -> Node:
	var r: Window = _root()
	return r.get_node_or_null(^"/root/Settings") if r != null else null


static func _db() -> Node:
	var r: Window = _root()
	return r.get_node_or_null(^"/root/CardDB") if r != null else null


## The DuelConfig (CardDB), or null.
static func config() -> Resource:
	var db: Node = _db()
	if not use_rules or db == null or not db.has_method(&"get_duel_config"):
		return null
	return db.call(&"get_duel_config")


static func _profile() -> Dictionary:
	var st: Node = _settings()
	var p: Variant = st.get(&"run_profile") if st != null else null
	return p if p is Dictionary else {}


static func card(id: StringName) -> CardData:
	var db: Node = _db()
	if db != null and db.has_card(id):
		return db.get_card(id)
	var path: String = "res://data/cards/%s.tres" % id
	return load(path) as CardData if ResourceLoader.exists(path) else null


static func hero_item(id: StringName) -> LoadoutItem:
	var db: Node = _db()
	var item: LoadoutItem = db.get_loadout_item(id) if db != null else null
	if item == null and id != &"" and ResourceLoader.exists("res://data/loadout/%s.tres" % id):
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
	if c == null:
		return false
	var rules: GDScript = _script(RULES_PATH)
	if rules != null:
		return bool(rules.call(&"pool_eligible", c))
	return c.collectible and not c.standard_issue and not c.is_token()


## Units and tactics are open from the start; Fields and Elites once found in a campaign run.
static func needs_unlock(c: CardData) -> bool:
	return c != null and (c.is_field() or c.is_elite)


## True when the player owns the card for their own decks.
static func is_owned(c: CardData) -> bool:
	if c == null:
		return false
	if owned_override.has(c.id):
		return bool(owned_override[c.id])
	var v: Variant = _ask(&"is_card_unlocked", [c.id])
	if v is bool:
		return v
	var coll: GDScript = _script(COLLECTION_PATH)
	if coll != null:
		return bool(coll.call(&"is_unlocked", c, _profile()))
	if not needs_unlock(c):
		return true
	var found: Variant = _profile().get("found_cards", [])
	return found is Array and (String(c.id) in found or StringName(c.id) in found)


## The owned card ids as a set (String -> true): the validator's collection.
static func collection() -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in pool():
		if bool(e["owned"]):
			out[String(e["id"])] = true
	return out


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
		for k: String in ["first_shot", "pick", "flank", "suppress", "pierce"]:
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
	return {"card": id, "art": art_for(card(id), t)}


## The trait both copies of a pick wear (&"" = none). Units and Fields carry traits.
static func trait_of(pick: Dictionary) -> StringName:
	var c: CardData = card(StringName(str(pick.get("card", ""))))
	if c == null or not (c.is_unit() or c.is_field()):
		return &""
	var art: StringName = StringName(str(pick.get("art", "")))
	return ArtTraits.trait_of(art if art != &"" else c.id, c)


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


## The curve bucket of a cost: 1 = "1 or less", 5 = "5+".
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
	for t: StringName in SynergyRules.TRAITS:
		if int(traits.get(t, 0)) > n:
			n = int(traits[t])
			best = t
	return best


## "Heavy · Bastion-60" (duel-mode.md §6.3), at most NAME_MAX characters.
static func default_name(deck: Dictionary) -> String:
	var v: Variant = _ask(&"default_name", [to_deck(deck)])
	if v is String and v != "":
		return v
	var t: StringName = main_trait(deck)
	var hero: LoadoutItem = hero_item(StringName(str(deck.get("hero", ""))))
	var parts: PackedStringArray = []
	parts.append(SynergyGlyphs.trait_name(t) if t != &"" else "Mixed")
	if hero != null:
		parts.append(hero.display_name)
	return clip_name(" · ".join(parts))


static func clip_name(s: String) -> String:
	return s.strip_edges().substr(0, NAME_MAX)


# =============================================================================
# Heroes, Doctrine, AI tiers
# =============================================================================

## The four heroes: {id, item, name, fp, armor, passive_name, passive_text, ability_name, ability_text,
## plays_like, unlocked, unlock_text}. D4: the Operator's own numbers (one set for both modes).
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
	var row: Dictionary = {}
	var v: Variant = _ask(&"heroes")
	if v is Array:
		for r: Variant in v:
			if r is Dictionary and StringName(str((r as Dictionary).get("id", ""))) == id:
				row = r
	var cfg: Resource = config()
	var plays: String = String(row.get("plays_like", ""))
	if plays == "" and cfg != null:
		plays = String((cfg.get(&"hero_plays_like") as Dictionary).get(id, (cfg.get(&"hero_plays_like") as Dictionary).get(String(id), "")))
	if plays == "":
		plays = String(PLAYS_LIKE.get(id, ""))
	var ability: Resource = item.ability
	var ability_text: String = String(row.get("ability_text", ""))
	if ability_text == "":
		ability_text = String(ability.get(&"text")) if ability != null and String(ability.get(&"text")) != "" else String(kit.get("ability_text", ""))
	var unlocked: bool = bool(row.get("unlocked", true))
	if hero_override.has(id):
		unlocked = bool(hero_override[id])
	return {"id": id, "item": item, "name": String(row.get("name", item.display_name)),
			"fp": int(row.get("fp", item.operator_firepower)), "armor": int(row.get("armor", item.operator_armor)),
			"passive_name": String(row.get("passive_name", kit.get("passive_name", item.passive_name))),
			"passive_text": String(row.get("passive_text", item.passive_text if item.passive_text != "" else String(kit.get("passive_text", "")))),
			"ability_name": String(row.get("ability_name", kit.get("ability_name", String(ability.get(&"display_name")) if ability != null else ""))),
			"ability_text": ability_text, "plays_like": plays,
			"unlocked": unlocked, "unlock_text": String(kit.get("unlock_text", ""))}


## True when the deck may have no Doctrine (DuelConfig.doctrine_required off).
static func doctrine_optional() -> bool:
	var cfg: Resource = config()
	return cfg == null or not bool(cfg.get(&"doctrine_required"))


## The Doctrine choices: {id, name, text} (the four traits). The rule text is the rules' when they give
## one (DuelState.doctrine_text), else the campaign's words with the set lines.
static func doctrines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: StringName in SynergyRules.TRAITS:
		out.append({"id": t, "name": SynergyGlyphs.trait_name(t), "text": doctrine_text(t)})
	return out


static func doctrine_text(t: StringName) -> String:
	if t == &"":
		return "No Doctrine: your trait counts are what your picks wear."
	var v: Variant = _ask(&"doctrine_text", [t])
	if v is String and v != "":
		return v
	return "Doctrine %s: your %s count gets +1, so its set lights up one card sooner. %s · %s." % [
			SynergyGlyphs.trait_name(t), SynergyGlyphs.trait_name(t), SynergyGlyphs.tier_line(t, 2), SynergyGlyphs.tier_line(t, 3)]


## The AI tiers: [{id, name, text}] (DuelState.tier_views, else the spec's lines).
static func tiers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var v: Variant = _ask(&"tier_views")
	if v is Array and not (v as Array).is_empty():
		for r: Variant in v:
			if r is Dictionary:
				var id: StringName = StringName(str(r.get("id", "")))
				out.append({"id": id, "name": String(r.get("name", TIER_NAMES.get(id, String(id)))).to_upper(),
						"text": String(r.get("text", TIER_LINES.get(id, "")))})
		return out
	for id: StringName in TIERS:
		out.append({"id": id, "name": TIER_NAMES[id], "text": TIER_LINES[id]})
	return out


# =============================================================================
# Decks: presets, saves, rules
# =============================================================================

static func new_deck(hero_id: StringName = &"kestrel_ar7") -> Dictionary:
	return {"id": "", "name": "", "hero": hero_id, "doctrine": &"", "picks": [], "preset": false, "plan": ""}


## The 4 presets (always playable). DuelState.presets(), else the preset resources, else §5.
static func presets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var v: Variant = _ask(&"presets")
	if v is Array and not (v as Array).is_empty():
		for d: Variant in v:
			out.append(_as_preset(from_rules(d), d))
		return out
	var db: Node = _db()
	if use_rules and db != null and db.has_method(&"get_duel_deck"):
		for id: StringName in PRESET_IDS:
			var res: Resource = db.call(&"get_duel_deck", id)
			if res != null:
				out.append(_as_preset(from_rules(res), res))
		if out.size() == PRESET_IDS.size():
			return out
		out.clear()
	for p: Dictionary in PRESET_DATA:
		var picks: Array = []
		for pk: Array in p["picks"]:
			picks.append(make_pick(pk[0], pk[1]))
		out.append({"id": p["id"], "name": p["name"], "hero": p["hero"], "doctrine": &"", "picks": picks,
				"preset": true, "plan": p["plan"]})
	return out


static func _as_preset(d: Dictionary, src: Variant) -> Dictionary:
	d["preset"] = true
	if String(d.get("plan", "")) == "" and src is Object:
		d["plan"] = String((src as Object).get(&"plan"))
	if String(d.get("name", "")) == "" and src is Object:
		d["name"] = String((src as Object).get(&"display_name"))
	return d


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


## The player's saved decks (up to MAX_SLOTS), in slot order.
static func saved_decks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var v: Variant = null if local_saves else _ask(&"decks")
	if v is Array:
		for d: Variant in v:
			out.append(from_rules(d))
		return out
	for d: Dictionary in _local_decks:
		out.append(d.duplicate(true))
	return out


static func saved_deck(id: String) -> Dictionary:
	for d: Dictionary in saved_decks():
		if String(d["id"]) == id:
			return d
	return {}


## Saves `deck` (new: a free slot; else in place). {ok, id, text}.
static func save_deck(deck: Dictionary) -> Dictionary:
	var d: Dictionary = deck.duplicate(true)
	if String(d.get("name", "")).strip_edges() == "":
		d["name"] = default_name(d)
	d["name"] = clip_name(String(d["name"]))
	if not local_saves and state() != null and state().has_method(&"save_deck"):
		var r: Dictionary = state().call(&"save_deck", to_deck(d))
		return {"ok": bool(r.get("ok", false)), "id": String(r.get("id", "")), "text": String(r.get("reason", "")) if not bool(r.get("ok", false)) else "Saved %s." % d["name"]}
	var at: int = -1
	for i: int in _local_decks.size():
		if String(d.get("id", "")) != "" and String(_local_decks[i]["id"]) == String(d["id"]):
			at = i
	if at < 0:
		if _local_decks.size() >= MAX_SLOTS:
			return {"ok": false, "id": "", "text": "%d decks saved: delete one first" % MAX_SLOTS}
		_local_seq += 1
		d["id"] = "deck_%d" % _local_seq
		d["created"] = int(Time.get_unix_time_from_system())
		_local_decks.append(d)
	else:
		_local_decks[at] = d
	d["edited"] = int(Time.get_unix_time_from_system())
	return {"ok": true, "id": d["id"], "text": "Saved %s." % d["name"]}


static func delete_deck(id: String) -> bool:
	if not local_saves and state() != null and state().has_method(&"delete_deck"):
		return bool(state().call(&"delete_deck", StringName(id)))
	for i: int in _local_decks.size():
		if String(_local_decks[i]["id"]) == id:
			_local_decks.remove_at(i)
			return true
	return false


## COPY on a tile: saves a copy ("<name> copy"). {ok, id, text, deck}.
static func copy_deck(deck: Dictionary) -> Dictionary:
	var c: Dictionary = copy_of(deck)
	var r: Dictionary = save_deck(c)
	c["id"] = r.get("id", "")
	r["deck"] = c
	return r


static func free_slots() -> int:
	return MAX_SLOTS - saved_decks().size()


## Tests: forget the session's local decks, records and overrides.
static func reset_local() -> void:
	_local_decks.clear()
	_local_records.clear()
	owned_override.clear()
	hero_override.clear()
	_local_seq = 0


## A rules deck (DuelDeck, its to_dict(), or a DuelState deck view) -> the screen's deck shape.
static func from_rules(v: Variant) -> Dictionary:
	var d: Dictionary = {}
	if v is Dictionary:
		d = v
	elif v is Object and (v as Object).has_method(&"to_dict"):
		d = (v as Object).call(&"to_dict")
		d["preset"] = bool((v as Object).get(&"preset"))
		d["plan"] = String((v as Object).get(&"plan"))
	var picks: Array = []
	for p: Variant in d.get("picks", []):
		if p is Dictionary:
			var id: StringName = StringName(str(p.get("card_id", p.get("card", ""))))
			var art: StringName = StringName(str(p.get("art_id", p.get("art", ""))))
			if art == &"":
				art = art_for(card(id), StringName(str(p.get("trait", ""))))
			picks.append({"card": id, "art": art})
	return {"id": str(d.get("id", "")), "name": str(d.get("name", d.get("display_name", ""))),
			"hero": StringName(str(d.get("hero_id", d.get("hero", "")))),
			"doctrine": StringName(str(d.get("doctrine_trait", d.get("doctrine", "")))), "picks": picks,
			"preset": bool(d.get("preset", false)), "plan": str(d.get("plan", ""))}


## The screen's deck -> the save format (duel-api.md §1 to_dict).
static func to_rules(deck: Dictionary) -> Dictionary:
	var picks: Array = []
	for p: Dictionary in deck.get("picks", []):
		var c: CardData = card(StringName(str(p.get("card", ""))))
		var art: StringName = StringName(str(p.get("art", "")))
		# The chassis' own art is the default art (&"").
		if c != null and art == c.id:
			art = &""
		picks.append({"card_id": String(p.get("card", "")), "art_id": String(art)})
	return {"id": String(deck.get("id", "")), "name": String(deck.get("name", "")), "hero_id": String(deck.get("hero", "")),
			"doctrine_trait": String(deck.get("doctrine", "")), "picks": picks}


## The screen's deck as a DuelDeck (null without the rules classes).
static func to_deck(deck: Dictionary) -> Resource:
	var s: GDScript = _script(DECK_PATH)
	if s == null:
		return null
	var res: Resource = s.call(&"from_dict", to_rules(deck))
	if res != null:
		res.set(&"preset", bool(deck.get("preset", false)))
	return res


## The deck rules (duel-api.md §2): {ok, errors: [LINE], warnings: [LINE], ready_text, status}, LINE =
## {code, text, fix: {kind?, elite?, cost_max?, cost_min?, hero?, doctrine?}, card?}. errors block PLAY
## (red); warnings are advice (amber). loaner = a preset or an open pool (no lock check).
static func validate(deck: Dictionary, loaner: bool = false) -> Dictionary:
	var opts: Dictionary = {"open_pool": true} if loaner else {}
	var raw: Variant = null
	var dd: Resource = to_deck(deck)
	if dd != null:
		var s: Node = state()
		if s != null and s.has_method(&"validate") and owned_override.is_empty():
			raw = s.call(&"validate", dd, opts)
		else:
			# A preview's collection override (or no DuelState): the rules' validator with the screen's collection.
			var rules: GDScript = _script(RULES_PATH)
			if rules != null:
				raw = rules.call(&"validate", dd, config(), collection(), opts)
	var out: Dictionary = {}
	if raw is Dictionary and (raw as Dictionary).has("ok"):
		out = {"ok": bool(raw["ok"]), "errors": _lines(raw.get("errors", [])), "warnings": _lines(raw.get("warnings", [])),
				"status": String(raw.get("status", "")), "ready_text": String(raw.get("status_text", ""))}
		if not bool(out["ok"]):
			out.erase("ready_text")
	else:
		out = _validate_local(deck, loaner or bool(deck.get("preset", false)))
	if not out.has("ready_text") or String(out["ready_text"]) == "":
		var h: Dictionary = hero(StringName(str(deck.get("hero", ""))))
		out["ready_text"] = "READY: %d cards, hero %s" % [pick_ids(deck).size() * COPIES, h.get("name", "?")]
	return out


static func _lines(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not raw is Array:
		return out
	for l: Variant in raw:
		if not l is Dictionary:
			continue
		var ff: Dictionary = (l as Dictionary).get("fix_filter", {})
		var fix: Dictionary = {}
		if ff.has("type"):
			fix["kind"] = StringName(str(ff["type"]))
		for k: String in ["cost_max", "cost_min"]:
			if ff.has(k):
				fix[k] = int(ff[k])
		for k: String in ["elite", "hero", "doctrine"]:
			if bool(ff.get(k, false)):
				fix[k] = true
		var line: Dictionary = {"code": StringName(str(l.get("code", ""))), "text": String(l.get("text", "")), "fix": fix}
		if ff.has("card_id"):
			line["card"] = StringName(str(ff["card_id"]))
		out.append(line)
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
		errors.append({"code": &"picks_over", "text": "Too many picks (%d/%d): remove %d" % [n, MAX_PICKS, n - MAX_PICKS], "fix": {}})
	if not loaner:
		for id: StringName in ids:
			var c: CardData = card(id)
			if c != null and not is_owned(c):
				errors.append({"code": &"locked_card", "text": "%s isn't in your collection: find it in the campaign" % c.display_name, "fix": {}, "card": id})
	if int(comp["units"]) < MIN_UNITS:
		errors.append({"code": &"unit_min", "text": "At least %d unit picks (%d/%d)" % [MIN_UNITS, comp["units"], MIN_UNITS], "fix": {"kind": &"unit"}})
	if int(comp["elites"]) > MAX_ELITE:
		var names: PackedStringArray = []
		for id: StringName in ids:
			var c: CardData = card(id)
			if c != null and c.is_elite:
				names.append(c.display_name)
		errors.append({"code": &"elite_max", "text": "Only %d Elite ★ pick (%d/%d): remove %s" % [MAX_ELITE, comp["elites"], MAX_ELITE, " or ".join(names)], "fix": {"elite": true}})
	if int(comp["fields"]) > MAX_FIELDS:
		errors.append({"code": &"field_max", "text": "At most %d Field picks (%d/%d)" % [MAX_FIELDS, comp["fields"], MAX_FIELDS], "fix": {"kind": &"field"}})
	if hero(StringName(str(deck.get("hero", "")))).is_empty():
		errors.append({"code": &"no_hero", "text": "Pick a hero", "fix": {"hero": true}})
	# Advice (duel-mode.md §2.1).
	var cheap: int = 0
	var heavy: int = 0
	for id: StringName in ids:
		var c: CardData = card(id)
		if c == null:
			continue
		cheap += 1 if c.cost <= 1 else 0
		heavy += 1 if c.cost >= 4 else 0
	if cheap < 2:
		warnings.append({"code": &"low_curve", "text": "Round 1 gives 1 Supply. You may have nothing to play.", "fix": {"cost_max": 1}})
	if heavy >= 4:
		warnings.append({"code": &"heavy_curve", "text": "Heavy curve: these land from round 4.", "fix": {"cost_min": 4}})
	var unit_traits: Dictionary = {}
	var has_set: bool = false
	for p: Dictionary in deck.get("picks", []):
		var c: CardData = card(StringName(str(p.get("card", ""))))
		var t: StringName = trait_of(p)
		if t == &"" or c == null or not c.is_unit():
			continue
		unit_traits[t] = int(unit_traits.get(t, 0)) + 1
		has_set = has_set or int(unit_traits[t]) >= 2
	if not has_set:
		warnings.append({"code": &"no_set", "text": "No set: 2 units of one trait give a bonus.", "fix": {"kind": &"unit"}})
	if int(comp["tactics"]) == 0:
		warnings.append({"code": &"no_tactic", "text": "No tactics: you can't answer a column in one round.", "fix": {"kind": &"tactic"}})
	var doc: StringName = StringName(str(deck.get("doctrine", "")))
	if doc != &"" and n > 0 and not comp["traits"].has(doc):
		warnings.append({"code": &"doctrine_unused", "text": "Doctrine %s: none of your picks wear %s." % [SynergyGlyphs.trait_name(doc), SynergyGlyphs.trait_name(doc)], "fix": {"doctrine": true}})
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
# Starting a duel (duel-api.md §5)
# =============================================================================

## vs AI: {ok, reason, match (DuelMatch or null), state (MatchState or null)}.
static func start_vs_ai(deck: Dictionary, opponent: StringName, tier: StringName, seed_value: int = -1) -> Dictionary:
	var s: Node = state()
	if s != null and s.has_method(&"start_vs_ai"):
		var r: Dictionary = s.call(&"start_vs_ai", to_deck(deck), opponent, tier, seed_value)
		return {"ok": bool(r.get("ok", false)), "reason": String(r.get("reason", "")), "match": r.get("match", null), "state": null}
	return _create_match(deck, preset(String(opponent)) if opponent != &"random" else presets()[absi(seed_value) % 4], ["You", ""],
			[0, -1 if tier == &"recruit" else 0], seed_value)


## Pass & Play: {ok, reason, match, state}.
static func start_hot_seat(deck_a: Dictionary, deck_b: Dictionary, names: Array, opts: Dictionary = {}) -> Dictionary:
	var s: Node = state()
	if s != null and s.has_method(&"start_hot_seat"):
		var r: Dictionary = s.call(&"start_hot_seat", to_deck(deck_a), to_deck(deck_b), names, opts)
		return {"ok": bool(r.get("ok", false)), "reason": String(r.get("reason", "")), "match": r.get("match", null), "state": null}
	return {"ok": false, "reason": "Pass & Play needs DuelState (duel-api.md §5): not in this build yet.", "match": null, "state": null}


## Without DuelState: a plain MatchState from DuelRules.create_match (vs AI only; no tier AI).
static func _create_match(deck_a: Dictionary, deck_b: Dictionary, names: Array, armor: Array, seed_value: int) -> Dictionary:
	var rules: GDScript = _script(RULES_PATH)
	var db: Node = _db()
	if rules == null or db == null or deck_b.is_empty():
		return {"ok": false, "reason": "Duel matches need the rules (DuelState): not in this build yet.", "match": null, "state": null}
	var m: Variant = rules.call(&"create_match", to_deck(deck_a), to_deck(deck_b), config(), db.get_run_config(),
			seed_value if seed_value >= 0 else 20261110, [names[0], String(deck_b.get("name", ""))], armor)
	return {"ok": m != null, "reason": "" if m != null else "The rules could not build the match.", "match": null, "state": m}


# =============================================================================
# Records
# =============================================================================

## DuelState.records() or the session's: {heroes: {id: {w, l, d}}, vs_ai: {preset: {tier: {w, l, d}}},
## hot_seat_games, duelist_frames, veteran_stamps}.
static func records() -> Dictionary:
	var v: Variant = _ask(&"records")
	if v is Dictionary:
		return v
	return _local_records if not _local_records.is_empty() else {"heroes": {}, "vs_ai": {}, "hot_seat_games": 0, "duelist_frames": [], "veteran_stamps": []}


## A hero's record {w, l, d}.
static func hero_record(id: StringName) -> Dictionary:
	var h: Dictionary = records().get("heroes", {})
	return h.get(id, h.get(String(id), {"w": 0, "l": 0, "d": 0}))


## The record against a preset at a tier {w, l, d}; tier &"" = every tier added up.
static func preset_record(preset_id: String, tier: StringName = &"") -> Dictionary:
	var by_tier: Dictionary = (records().get("vs_ai", {}) as Dictionary).get(preset_id, (records().get("vs_ai", {}) as Dictionary).get(StringName(preset_id), {}))
	if tier != &"":
		return by_tier.get(tier, by_tier.get(String(tier), {"w": 0, "l": 0, "d": 0}))
	var out: Dictionary = {"w": 0, "l": 0, "d": 0}
	for t: Variant in by_tier:
		for k: String in ["w", "l", "d"]:
			out[k] = int(out[k]) + int((by_tier[t] as Dictionary).get(k, 0))
	return out


## Without DuelState: notes a finished duel vs AI in this session's records.
static func note_local(result: StringName, hero_id: StringName, opponent_id: String, tier: StringName) -> void:
	var rec: Dictionary = records().duplicate(true) if not _local_records.is_empty() else {"heroes": {}, "vs_ai": {}, "hot_seat_games": 0, "duelist_frames": [], "veteran_stamps": []}
	var k: String = "w" if result == &"win" else ("l" if result == &"loss" else "d")
	var h: Dictionary = rec["heroes"].get(hero_id, {"w": 0, "l": 0, "d": 0})
	h[k] = int(h[k]) + 1
	rec["heroes"][hero_id] = h
	var p: Dictionary = rec["vs_ai"].get(opponent_id, {})
	var t: Dictionary = p.get(tier, {"w": 0, "l": 0, "d": 0})
	t[k] = int(t[k]) + 1
	p[tier] = t
	rec["vs_ai"][opponent_id] = p
	_local_records = rec


static func record_text(r: Dictionary) -> String:
	var t: String = "%d W · %d L" % [int(r.get("w", 0)), int(r.get("l", 0))]
	if int(r.get("d", 0)) > 0:
		t += " · %d D" % int(r["d"])
	return t


## Setters for tests and tools (a script preloaded as a const can't assign its static vars).
static func set_local_saves(on: bool) -> void:
	local_saves = on


static func set_use_rules(on: bool) -> void:
	use_rules = on
