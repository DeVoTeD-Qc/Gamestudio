# duel_collection.gd
# Purpose: kc-duel-impl (duel-mode.md §7, head D3): the Duel card pool and what is unlocked. Units and
#   tactics are open from the start; Fields and Elites ★ unlock once a campaign run has shown them
#   (taken or offered: RunProfile found_cards, fed by RunState). The presets and all 4 heroes are always
#   playable (loaners). Pure static functions over a RunProfile dictionary.
#   API for the screens: documentation/technical/duel-api.md §3.
# Dependencies: DuelRules, DuelDeck, DuelConfig, CardData, ArtTraits, RunProfile, CardDB (optional).
# Author: Mechanics Developer Agent (kc-duel-impl)
class_name DuelCollection
extends RefCounted

const UNLOCK_TEXT: String = "Find it in the campaign"


## Every Duel-eligible card (CardDB when it runs, else data/cards/), sorted by cost then name.
static func pool_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	var db: Node = DuelDeck._db()
	var all: Array[CardData] = []
	if db != null and db.has_method(&"all_cards"):
		all = db.all_cards()
	if all.is_empty():
		for f: String in DirAccess.get_files_at("res://data/cards"):
			var name: String = f.trim_suffix(".remap")
			if name.ends_with(".tres"):
				var c: CardData = load("res://data/cards/" + name) as CardData
				if c != null:
					all.append(c)
	for c: CardData in all:
		if DuelRules.pool_eligible(c):
			out.append(c)
	out.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.cost < b.cost if a.cost != b.cost else a.display_name < b.display_name)
	return out


## True when the card needs to be found in the campaign first (Fields and Elites).
static func needs_unlock(card: CardData) -> bool:
	return card != null and (card.is_elite or DuelRules.is_field(card))


static func is_unlocked(card: CardData, profile: Dictionary) -> bool:
	if card == null or not DuelRules.pool_eligible(card):
		return false
	if not needs_unlock(card):
		return true
	return String(card.id) in (RunProfile.normalised(profile)["found_cards"] as Array)


## The unlocked card ids as a set (String -> true): DuelRules.validate's `collection`.
static func unlocked_set(profile: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for c: CardData in pool_cards():
		if is_unlocked(c, profile):
			out[String(c.id)] = true
	return out


## Pool rows for the deck builder grid (duel-api.md §3). opts: {open_pool, include_locked (default true)}.
static func pool_view(profile: Dictionary, cfg: DuelConfig, opts: Dictionary = {}) -> Array[Dictionary]:
	var open: bool = bool(opts.get("open_pool", false))
	var include_locked: bool = bool(opts.get("include_locked", true))
	var in_presets: Dictionary = {}
	if cfg != null:
		for d: DuelDeck in cfg.presets:
			if d == null:
				continue
			for i: int in d.picks.size():
				var k: String = String(d.card_id_at(i))
				if not in_presets.has(k):
					in_presets[k] = [] as Array[StringName]
				(in_presets[k] as Array[StringName]).append(d.id)
	var out: Array[Dictionary] = []
	for c: CardData in pool_cards():
		var locked: bool = not open and not is_unlocked(c, profile)
		if locked and not include_locked:
			continue
		out.append(card_row(c, locked, in_presets.get(String(c.id), [] as Array[StringName])))
	return out


static func card_row(c: CardData, locked: bool = false, presets: Array = []) -> Dictionary:
	var tk: String = DuelRules.type_key(c)
	return {"id": c.id, "name": c.display_name, "type": tk, "type_label": tk.capitalize(), "cost": c.cost,
			"elite": c.is_elite, "fp": c.firepower if c.is_unit() else 0, "armor": c.armor if c.is_unit() else 0,
			"weapon": String(DataEnums.key_of(DataEnums.WeaponClass, c.weapon_class)) if c.is_unit() else "",
			"keywords": c.keyword_names(), "text": c.text, "trait": c.card_trait,
			"trait_name": ArtTraits.trait_name(c.card_trait) if c.card_trait != &"" else "",
			"trait_options": ArtTraits.options(c), "locked": locked, "unlock_text": UNLOCK_TEXT if locked else "",
			"in_presets": presets}


## Profile v1 -> v2 (kc-duel-impl): the card ids a v1 player has already met, from the arts their run
## copies wore (Settings.found_arts: "<chassis>~<look>" or a licensed id) and the current run's deck.
static func backfill_ids(found_arts: Dictionary, run_deck: Array) -> Array[String]:
	var out: Array[String] = []
	for a: Variant in found_arts.keys():
		var s: String = String(a)
		var chassis: String = s.get_slice(ArtTraits.SEP, 0) if s.contains(ArtTraits.SEP) else ""
		if chassis == "":
			var row: Dictionary = ArtTraits.licensed_row(StringName(s))
			chassis = String(row.get("chassis", row.get("card", s)))
		if chassis != "" and chassis not in out:
			out.append(chassis)
	for id: Variant in run_deck:
		if String(id) != "" and String(id) not in out:
			out.append(String(id))
	return out
