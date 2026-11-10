# duel_rules.gd
# Purpose: kc-duel-impl: the Duel deck rules (duel-mode.md §2.1, §6.4; head D1-D5) and the Duel match
#   setup. Static and node-free:
#   - pool_eligible(card): what may ever be in a Duel deck (never tokens, boss cards, Standard Issue)
#   - validate(deck, config, collection): red lines (block PLAY) and amber lines (advice), with codes,
#     player-facing text and the grid filter that fixes each line
#   - side_setup(deck, config): the SideSetup of a deck: 2 copies per pick, the pick's art gives both
#     copies their trait, the hero as the Operator in its own slot with its kit (D1), the 3 starter
#     killstreaks, no perks / attachments, Doctrine = the deck's doctrine_trait (D5)
#   - create_match(...): a MatchState with the campaign economy, deck size 20, Zone Control to 6, no
#     Terrain (the duel_sim rules, now in real code)
#   API for the screens: documentation/technical/duel-api.md §2, §5.
# Dependencies: DuelDeck, DuelConfig, CardData, LoadoutItem, ArtTraits, SynergyRules, SideSetup,
#   MatchState, MatchHooks, ModeRules, RunConfig, DataEnums.
# Author: Mechanics Developer Agent (kc-duel-impl)
class_name DuelRules
extends RefCounted

# Red (block PLAY).
const E_PICKS_SHORT: StringName = &"picks_short"
const E_PICKS_OVER: StringName = &"picks_over"
const E_DUPLICATE: StringName = &"duplicate_pick"
const E_UNKNOWN_CARD: StringName = &"unknown_card"
const E_NOT_IN_POOL: StringName = &"not_in_pool"
const E_LOCKED: StringName = &"locked_card"
const E_UNIT_MIN: StringName = &"unit_min"
const E_ELITE_MAX: StringName = &"elite_max"
const E_FIELD_MAX: StringName = &"field_max"
const E_NO_HERO: StringName = &"no_hero"
const E_UNKNOWN_HERO: StringName = &"unknown_hero"
const E_BAD_ART: StringName = &"bad_art"
const E_DOCTRINE_INVALID: StringName = &"doctrine_invalid"
const E_DOCTRINE_REQUIRED: StringName = &"doctrine_required"
const E_DOCTRINE_RULE: StringName = &"doctrine_rule"
# Amber (advice).
const W_LOW_CURVE: StringName = &"low_curve"
const W_HEAVY_CURVE: StringName = &"heavy_curve"
const W_NO_SET: StringName = &"no_set"
const W_NO_TACTIC: StringName = &"no_tactic"
const W_DOCTRINE_UNUSED: StringName = &"doctrine_unused"

const STATUS_READY: String = "READY"
const STATUS_ATTENTION: String = "NEEDS ATTENTION"
const TYPE_KEYS: Dictionary = {DataEnums.CardType.UNIT: "unit", DataEnums.CardType.TACTIC: "tactic",
		DataEnums.CardType.EQUIPMENT: "field"}


# =============================================================================
# The pool
# =============================================================================

## True when `card` may ever be in a Duel deck: a collectible unit, tactic or Field. Never a token
## (Sentry, Shambler: the boss cards are tokens too) or a Standard Issue card (D2).
static func pool_eligible(card: CardData) -> bool:
	return card != null and card.collectible and not card.standard_issue and not card.is_token() \
			and TYPE_KEYS.has(card.card_type)


static func type_key(card: CardData) -> String:
	return String(TYPE_KEYS.get(card.card_type, "")) if card != null else ""


static func is_field(card: CardData) -> bool:
	return card != null and card.card_type == DataEnums.CARD_TYPE_FIELD


# =============================================================================
# Validation (duel-mode.md §6.4)
# =============================================================================

## Red and amber lines for `deck`. `collection` = the unlocked card ids (String or StringName keys)
## or null (open pool). Presets never get locked lines (loaners, D3). opts: {open_pool: true}.
## Returns {ok, status, status_text, errors: [LINE], warnings: [LINE], summary} (duel-api.md §2).
static func validate(deck: DuelDeck, cfg: DuelConfig, collection: Variant = null, opts: Dictionary = {}) -> Dictionary:
	var errors: Array[Dictionary] = []
	var warnings: Array[Dictionary] = []
	if cfg == null:
		cfg = DuelConfig.new()
	var check_locks: bool = collection != null and not deck.preset and not bool(opts.get("open_pool", false))
	var units: int = 0
	var tactics: int = 0
	var fields: int = 0
	var elites: Array[String] = []
	var low: int = 0
	var heavy: int = 0
	var curve: Array[int] = [0, 0, 0, 0, 0]
	var traits: Dictionary = {}
	var unit_traits: Dictionary = {}
	var seen: Dictionary = {}
	var cp: int = cfg.copies_per_pick
	for i: int in deck.picks.size():
		var cid: StringName = deck.card_id_at(i)
		var c: CardData = DuelDeck.find_card(cid)
		if c == null:
			errors.append(_line(E_UNKNOWN_CARD, "An unknown card (%s) is in this deck" % cid, {"card_id": cid}, {"card_id": cid}))
			continue
		if seen.has(cid):
			errors.append(_line(E_DUPLICATE, "%s is picked twice: one pick per card" % c.display_name,
					{"card_id": cid}, {"card_id": cid}))
			continue
		seen[cid] = true
		if not pool_eligible(c):
			errors.append(_line(E_NOT_IN_POOL, "%s can't be in a Duel deck" % c.display_name, {"card_id": cid}, {"card_id": cid}))
			continue
		if check_locks and not _has(collection, cid):
			errors.append(_line(E_LOCKED, "%s isn't in your collection: find it in the campaign" % c.display_name,
					{"card_id": cid}, {"card_id": cid}))
		var art: StringName = deck.art_id_at(i)
		if art != &"" and not ArtTraits.belongs(art, c):
			errors.append(_line(E_BAD_ART, "%s: that art isn't one of its arts" % c.display_name, {"card_id": cid}, {"card_id": cid}))
		if c.is_unit():
			units += 1
		elif is_field(c):
			fields += 1
		else:
			tactics += 1
		if c.is_elite:
			elites.append(c.display_name)
		low += int(c.cost <= cfg.low_cost)
		heavy += int(c.cost >= cfg.heavy_cost)
		curve[clampi(c.cost, 1, 5) - 1] += cp
		var t: StringName = deck.trait_of_pick(i)
		if t != &"" and (c.is_unit() or is_field(c)):
			traits[t] = int(traits.get(t, 0)) + cp
		if t != &"" and c.is_unit():
			unit_traits[t] = int(unit_traits.get(t, 0)) + 1
	var n: int = deck.picks.size()
	if n < cfg.picks:
		errors.push_front(_line(E_PICKS_SHORT, "Pick %d more card%s (%d/%d)" % [cfg.picks - n, "" if cfg.picks - n == 1 else "s", n, cfg.picks],
				{}, {"missing": cfg.picks - n}))
	elif n > cfg.picks:
		errors.push_front(_line(E_PICKS_OVER, "Too many picks (%d/%d): remove %d" % [n, cfg.picks, n - cfg.picks], {}, {"extra": n - cfg.picks}))
	if units < cfg.min_unit_picks:
		errors.append(_line(E_UNIT_MIN, "At least %d unit picks (%d/%d)" % [cfg.min_unit_picks, units, cfg.min_unit_picks],
				{"type": "unit"}, {"units": units}))
	if elites.size() > cfg.max_elite_picks:
		errors.append(_line(E_ELITE_MAX, "Only %d Elite ★ pick (%d/%d): remove %s" % [cfg.max_elite_picks, elites.size(),
				cfg.max_elite_picks, " or ".join(elites)], {"elite": true}, {"elites": elites.size()}))
	if fields > cfg.max_field_picks:
		errors.append(_line(E_FIELD_MAX, "At most %d Field picks (%d/%d)" % [cfg.max_field_picks, fields, cfg.max_field_picks],
				{"type": "field"}, {"fields": fields}))
	var hero: LoadoutItem = null
	if deck.hero_id == &"":
		errors.append(_line(E_NO_HERO, "Pick a hero", {"hero": true}))
	else:
		hero = DuelDeck.find_hero(deck.hero_id)
		if hero == null or (not cfg.heroes.is_empty() and deck.hero_id not in cfg.hero_ids()):
			errors.append(_line(E_UNKNOWN_HERO, "Unknown hero (%s): pick a hero" % deck.hero_id, {"hero": true}))
			hero = null
	_doctrine_checks(deck, cfg, unit_traits, errors, warnings)
	# Amber advice (§2.1): only once the deck has picks to judge.
	if n > 0:
		if low < cfg.low_curve_min_picks:
			warnings.append(_line(W_LOW_CURVE, "Round 1 gives 1 Supply. You may have nothing to play.", {"cost_max": cfg.low_cost}))
		if heavy >= cfg.heavy_curve_picks:
			warnings.append(_line(W_HEAVY_CURVE, "Heavy curve: these land from round %d." % cfg.heavy_cost, {"cost_min": cfg.heavy_cost}))
		var has_set: bool = false
		for t: StringName in unit_traits:
			has_set = has_set or int(unit_traits[t]) >= SynergyRules.TIER2
		if not has_set:
			warnings.append(_line(W_NO_SET, "No set: 2 units of one trait give a bonus.", {"type": "unit"}))
		if tactics == 0:
			warnings.append(_line(W_NO_TACTIC, "No tactics: you can't answer a column in one round.", {"type": "tactic"}))
	var ok: bool = errors.is_empty()
	var status: String = STATUS_READY
	var status_text: String = ""
	if ok:
		status_text = "READY: %d cards, hero %s" % [n * cp, hero.display_name if hero != null else ""]
	else:
		status_text = String(errors[0]["text"])
		var only_short: bool = errors.size() == 1 and errors[0]["code"] == E_PICKS_SHORT
		status = ("%d PICK%s TO GO" % [cfg.picks - n, "" if cfg.picks - n == 1 else "S"]) if only_short else STATUS_ATTENTION
	return {"ok": ok, "status": status, "status_text": status_text, "errors": errors, "warnings": warnings,
			"summary": {"picks": n, "picks_max": cfg.picks, "cards": n * cp, "units": units, "tactics": tactics,
				"fields": fields, "elites": elites.size(), "unit_min": cfg.min_unit_picks, "elite_max": cfg.max_elite_picks,
				"field_max": cfg.max_field_picks, "curve": curve, "traits": traits,
				"hero_id": deck.hero_id, "hero_name": hero.display_name if hero != null else "",
				"doctrine_trait": deck.doctrine_trait,
				"doctrine_name": ArtTraits.trait_name(deck.doctrine_trait) if deck.doctrine_trait != &"" else ""}}


## D5 hook: the Doctrine lines. The designer's rule (and any Undead fix that lives in the deck rules)
## goes here; red lines use E_DOCTRINE_RULE, amber ones a W_ code. `unit_traits` = trait -> unit picks.
static func _doctrine_checks(deck: DuelDeck, cfg: DuelConfig, _unit_traits: Dictionary,
		errors: Array[Dictionary], warnings: Array[Dictionary]) -> void:
	var t: StringName = deck.doctrine_trait
	if t == &"":
		if cfg.doctrine_required and cfg.doctrine_enabled:
			errors.append(_line(E_DOCTRINE_REQUIRED, "Pick a Doctrine trait", {"doctrine": true}))
		return
	if t not in SynergyRules.TRAITS:
		errors.append(_line(E_DOCTRINE_INVALID, "Doctrine must be Vanguard, Spec Ops, Heavy or Undead", {"doctrine": true}))
		return
	var wearing: int = 0
	for i: int in deck.picks.size():
		wearing += int(deck.trait_of_pick(i) == t)
	var tname: String = ArtTraits.trait_name(t)
	if cfg.doctrine_min_trait_picks > 0 and wearing < cfg.doctrine_min_trait_picks:
		errors.append(_line(E_DOCTRINE_RULE, "Doctrine %s needs %d %s picks (%d/%d)" % [tname,
				cfg.doctrine_min_trait_picks, tname, wearing, cfg.doctrine_min_trait_picks], {"doctrine": true},
				{"wearing": wearing}))
	elif wearing == 0 and not deck.picks.is_empty():
		warnings.append(_line(W_DOCTRINE_UNUSED, "Doctrine %s: none of your picks wear %s." % [tname, tname], {"doctrine": true}))


## D5: the player-facing Doctrine text for trait `t` (&"" = no Doctrine), for the builder's Doctrine
## strip and the inspect views. Says what the rule does and what the trait's sets give.
static func doctrine_text(t: StringName, cfg: DuelConfig = null) -> String:
	if cfg != null and not cfg.doctrine_enabled:
		return "Doctrine is off in Duel: your trait counts are what your picks wear."
	if t == &"":
		return "No Doctrine: your trait counts are what your picks wear."
	if t not in SynergyRules.TRAITS:
		return ""
	var n: String = ArtTraits.trait_name(t)
	var tiers: Array = SynergyRules.TIER_TEXT.get(t, ["", ""])
	# duel-mode.md §12.3: the Duel Doctrine starts the set (one member counts as two), never completes it.
	var need: int = cfg.doctrine_min_trait_picks if cfg != null else 0
	var out: String = "Doctrine: your first %s in play already turns on the %s 2-set. The 3-set still needs 3 %s." % [n, n, n]
	if need > 0:
		out += " Needs %d %s picks in your deck." % [need, n]
	return out + " 2 %s: %s. 3 %s: %s." % [n, tiers[0], n, tiers[1]]


static func _line(code: StringName, text: String, fix_filter: Dictionary = {}, data: Dictionary = {}) -> Dictionary:
	return {"code": code, "text": text, "fix_filter": fix_filter, "data": data}


static func _has(collection: Variant, cid: StringName) -> bool:
	if typeof(collection) == TYPE_DICTIONARY:
		return (collection as Dictionary).has(String(cid)) or (collection as Dictionary).has(cid)
	if typeof(collection) == TYPE_ARRAY:
		return String(cid) in collection or cid in collection
	return true


## The first red line's text ("" when the deck is legal).
static func first_error(deck: DuelDeck, cfg: DuelConfig, collection: Variant = null, opts: Dictionary = {}) -> String:
	var r: Dictionary = validate(deck, cfg, collection, opts)
	return "" if r["ok"] else String(r["status_text"])


# =============================================================================
# Deck facts
# =============================================================================

## The trait most copies wear (units and Fields; SynergyRules.TRAITS order on a tie), &"" = none.
static func main_trait(deck: DuelDeck) -> StringName:
	var counts: Dictionary = {}
	for i: int in deck.picks.size():
		var c: CardData = DuelDeck.find_card(deck.card_id_at(i))
		var t: StringName = deck.trait_of_pick(i)
		if c != null and t != &"" and (c.is_unit() or is_field(c)):
			counts[t] = int(counts.get(t, 0)) + 1
	var best: StringName = &""
	for t: StringName in SynergyRules.TRAITS:
		if int(counts.get(t, 0)) > int(counts.get(best, 0)):
			best = t
	return best


## "<main trait> · <hero>" (duel-mode.md §6.3), at most `max_len` characters.
static func default_name(deck: DuelDeck, max_len: int = DuelDeck.NAME_MAX) -> String:
	var t: StringName = main_trait(deck)
	var hero: LoadoutItem = DuelDeck.find_hero(deck.hero_id)
	var parts: PackedStringArray = []
	parts.append(ArtTraits.trait_name(t) if t != &"" else "Mixed")
	if hero != null:
		parts.append(hero.display_name)
	return " · ".join(parts).left(max_len)


# =============================================================================
# Match setup
# =============================================================================

## The SideSetup of a Duel deck (duel_sim's _deck, in real code). Deck entries in pick order, 2 copies
## each (shuffled by MatchState); each copy's art and trait come from its pick.
static func side_setup(deck: DuelDeck, cfg: DuelConfig, display_name: String = "") -> SideSetup:
	if cfg == null:
		cfg = DuelConfig.new()
	var s: SideSetup = SideSetup.new()
	s.display_name = display_name if display_name != "" else deck.display_name
	for i: int in deck.picks.size():
		var c: CardData = DuelDeck.find_card(deck.card_id_at(i))
		if c == null or not pool_eligible(c):
			continue
		var t: StringName = deck.trait_of_pick(i)
		if c.has_trait_choice() and not c.can_carry(t):
			t = SynergyRules.TRAIT_DEFAULT
		var art: StringName = deck.resolved_art(i)
		for j: int in cfg.copies_per_pick:
			s.deck.append(c)
			s.deck_traits.append(t if c.has_trait_choice() else SynergyRules.TRAIT_DEFAULT)
			s.deck_arts.append(art)
	# D1: the hero is the Operator in its own slot, with its kit (passive + once-per-match ability).
	s.primary = DuelDeck.find_hero(deck.hero_id)
	s.operator_kit = s.primary != null
	s.opening_hand_bonus_on = true
	s.killstreaks.assign(cfg.killstreaks)
	# D5: the deck's Doctrine trait.
	s.doctrine = deck.doctrine_trait if cfg.doctrine_enabled and deck.doctrine_trait in SynergyRules.TRAITS else &""
	# §12.3: the Duel Doctrine starts a set, never completes one.
	s.doctrine_starts_only = true
	return s


## A Duel MatchState (not started): side 0 plays deck_a, side 1 deck_b. `base` = the campaign's
## RunConfig (same economy). armor = [side 0, side 1] Armor bonus (Recruit: -1). No Terrain.
static func create_match(deck_a: DuelDeck, deck_b: DuelDeck, cfg: DuelConfig, base: RunConfig, seed_value: int,
		names: Array = [], armor: Array = [0, 0], hooks: MatchHooks = null) -> MatchState:
	var mc: RunConfig = cfg.match_config(base)
	var sa: SideSetup = side_setup(deck_a, cfg, String(names[0]) if names.size() > 0 else "")
	var sb: SideSetup = side_setup(deck_b, cfg, String(names[1]) if names.size() > 1 else "")
	sa.armor_bonus = int(armor[0]) if armor.size() > 0 else 0
	sb.armor_bonus = int(armor[1]) if armor.size() > 1 else 0
	var h: MatchHooks = hooks if hooks != null else MatchHooks.new()
	h.mode_rules = ModeRules.create(cfg.game_mode, mc)
	return MatchState.new(mc, cfg.map, sa, sb, seed_value, h)
