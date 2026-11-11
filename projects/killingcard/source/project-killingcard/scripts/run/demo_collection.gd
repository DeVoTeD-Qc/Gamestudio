# demo_collection.gd
# Purpose: kc-da-ui3 (head, D2 (a): "simulate a usual collection of a CoD player by having all starter
#   but also a few dozen unlocked cards"). A deterministic demo collection for the prototype: every
#   starter card plus DEMO_CARDS collectible cards, picked round-robin across groups (Elites, Fields,
#   Tactics, and Units by their first trait) so traits and rarities are spread, and a share of their
#   alternate arts (some cards with every art found, so the Codex shows Gold Leaf finishes). Pure: it
#   reads cards and arts and returns ids; RunState.apply_demo_collection() merges them into the
#   profile once (real progress keeps adding on top). Switched by RunConfig.demo_collection.
# Usage: var demo: Dictionary = DemoCollection.pick(config, cards)   # {cards: [String], arts: [String]}
# Dependencies: CardData, RunConfig, BannerArtDB (alt arts).
# Author: UI/UX Agent (kc-da-ui3)
extends RefCounted

## Bump to merge a changed demo set into profiles that already took an older one.
const DEMO_VERSION: int = 1
## Collectible cards unlocked on top of the starter ("a few dozen").
const DEMO_CARDS: int = 30
const SEED: int = 4417
## Share of demo cards with one extra art found, and with every art found (Gold Leaf).
const ONE_EXTRA_ART: float = 0.45
const ALL_ARTS: float = 0.15


static func group_of(c: CardData) -> String:
	if c.is_elite:
		return "elite"
	if c.is_field():
		return "field"
	if not c.is_unit():
		return "tactic"
	var ts: Array[StringName] = c.trait_choices()
	return "unit:" + (String(ts[0]) if not ts.is_empty() else "none")


## The demo collection for `cfg` over `cards` (every CardData; only collectible, non-token ones count).
static func pick(cfg: RunConfig, cards: Array) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var starter: Array[String] = []
	if cfg != null:
		for c: CardData in cfg.starter_deck:
			if c != null and String(c.id) not in starter:
				starter.append(String(c.id))
	var groups: Dictionary = {}
	var pool: Array = cards.filter(func(c: Variant) -> bool:
		return c is CardData and (c as CardData).collectible and not (c as CardData).is_token() and String((c as CardData).id) not in starter)
	pool.sort_custom(func(a: CardData, b: CardData) -> bool: return String(a.id) < String(b.id))
	for c: CardData in pool:
		var g: String = group_of(c)
		if not groups.has(g):
			groups[g] = []
		(groups[g] as Array).append(c)
	var keys: Array = groups.keys()
	keys.sort()
	var chosen: Array[CardData] = []
	while chosen.size() < DEMO_CARDS:
		var took: bool = false
		for g: String in keys:
			var left: Array = groups[g]
			if left.is_empty() or chosen.size() >= DEMO_CARDS:
				continue
			chosen.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
			took = true
		if not took:
			break
	var out_cards: Array[String] = starter.duplicate()
	var out_arts: Array[String] = []
	for c: CardData in chosen:
		out_cards.append(String(c.id))
		# Public arts only (never the private pitch's licensed images), default art first.
		var arts: Array[StringName] = BannerArtDB.alt_arts(c.id).filter(func(a: StringName) -> bool:
			return not BannerArtDB.get_art(a).licensed)
		if arts.size() < 2:
			continue
		var roll: float = rng.randf()
		if roll < ALL_ARTS:
			for a: StringName in arts:
				out_arts.append(String(a))
		elif roll < ALL_ARTS + ONE_EXTRA_ART:
			out_arts.append(String(arts[rng.randi_range(1, arts.size() - 1)]))
	return {"cards": out_cards, "arts": out_arts}
