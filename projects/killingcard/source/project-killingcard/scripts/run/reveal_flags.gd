# reveal_flags.gd
# Purpose: kc-onboard §5 (onboarding-progression.md, approved): progressive reveal. The systems a
#   player meets one at a time (traits, keywords, links, Fields, killstreak loadout, Promotion,
#   Muster out, Retire, Engine panel, Elites, per-keyword tips ...) as FLAGS, the moments that
#   trigger them, and the one-time "New: X" explainer texts.
#   Two profile sets live in the Settings autoload (they are per player, not per run):
#     met_flags  - systems the player has met (the UI shows an element once it is met, or while
#                  something in play uses it right now: "hidden doesn't mean off", §5.1),
#     seen_flags - "New: X" explainers the player has dismissed ("Got it").
#   This file is pure: it reads a RunProgress / MatchState and returns flag lists. RunState feeds
#   run_triggers() in after every run change and the match screen feeds match_triggers() in after
#   Reveal / the Firefight (UI hook); RunState.note_systems() records them and queues explainers.
# Dependencies: RunProgress, RewardOffers, MatchState, SynergyRules, CardData.
# Author: Mechanics Developer Agent (kc-onboard-impl)
class_name RevealFlags
extends RefCounted

## Calling cards & traits (trait icon on cards, subname with the art title; covers Doctrine).
const CALLING_CARDS: StringName = &"calling_cards"
## The trait rail and set callouts (the first traited unit in play, either side).
const TRAIT_RAIL: StringName = &"trait_rail"
## The Doctrine emblem on the Operator plate (the first calling card taken).
const DOCTRINE: StringName = &"doctrine"
## Keyword pips and stat deltas (the first Trained card offered, or the first Promotion).
const KEYWORDS: StringName = &"keywords"
## Link ticks and placement preview (the first time a neighbor keyword links, either side).
const LINKS: StringName = &"links"
## Camo band and the Promotion screen (the first Promotion).
const PROMOTION: StringName = &"promotion"
## The Engine panel in the deck view (the first Promotion).
const ENGINE_PANEL: StringName = &"engine_panel"
## The Muster out step (the first Muster out).
const MUSTER_OUT: StringName = &"muster_out"
## Salvage after a loss (the first Salvage).
const SALVAGE: StringName = &"salvage"
## Retire as the Supply Drop's 4th option (under "More"; the first drop from match 2 on).
const RETIRE: StringName = &"retire"
## Pick 2 of 4 on a Supply Drop.
const MULTI_PICK: StringName = &"multi_pick"
## The Field strip on the objective (the first Field offered or in play, either side).
const FIELDS: StringName = &"fields"
## The Elite frame (the first Elite offered).
const ELITES: StringName = &"elites"
## The killstreak choice on the Loadout screen (from run 2: run 1 keeps the defaults).
const LOADOUT: StringName = &"loadout"
## Coach marks the first time the Operator's Lethal / Tactical is ready.
const LETHAL: StringName = &"lethal"
const TACTICAL: StringName = &"tactical"
## A killstreak earned (the streak arc's first payoff; taught in the tutorial).
const KILLSTREAKS: StringName = &"killstreaks"
## Per-keyword first-play tips: "kw_" + the keyword id (kw_first_shot, kw_pick, kw_flank, kw_cover,
## kw_suppress, kw_pierce, kw_patch, kw_holder, kw_front, kw_on_deploy, kw_on_down, kw_guard, ...).
const KW_PREFIX: String = "kw_"

## Order of the "New:" queue when several trigger at once (one per screen, §5.1).
const ORDER: Array[StringName] = [CALLING_CARDS, DOCTRINE, TRAIT_RAIL, KEYWORDS, PROMOTION, ENGINE_PANEL, MUSTER_OUT,
		SALVAGE, MULTI_PICK, RETIRE, FIELDS, LINKS, ELITES, LOADOUT, LETHAL, TACTICAL, KILLSTREAKS]
## Flags that open with a "New:" card (the others just appear). Keyword tips have their own text.
const EXPLAINED: Array[StringName] = [CALLING_CARDS, TRAIT_RAIL, KEYWORDS, PROMOTION, MUSTER_OUT, SALVAGE, FIELDS,
		LINKS, ELITES, LOADOUT, LETHAL, TACTICAL]
## "New: X" texts (§5.2): {title, text}. The UI adds the icon and the mini example.
const TEXTS: Dictionary = {
	CALLING_CARDS: {"title": "New: Calling cards", "text": "Calling cards bring a trait. 2 or 3 of a trait in play give a bonus. Your first one's trait is your Doctrine: it counts +1."},
	TRAIT_RAIL: {"title": "New: Traits", "text": "Traits in play add up. The rail shows each set and its next bonus."},
	KEYWORDS: {"title": "New: Keywords", "text": "Trained cards have keywords. A Recruit's keywords unlock when it trains."},
	PROMOTION: {"title": "New: Promotion", "text": "Promotion trains a card. Gilded > Forged > Priceless."},
	MUSTER_OUT: {"title": "New: Muster out", "text": "The quartermaster takes back Standard Issue kit: one card per new card, plus one."},
	SALVAGE: {"title": "New: Salvage", "text": "Lost a match? You still salvage a card from the field."},
	FIELDS: {"title": "New: Fields", "text": "Fields sit on the objective and change the whole column."},
	LINKS: {"title": "New: Links", "text": "Some keywords link neighbors: Guard gives the card behind it Cover +1."},
	ELITES: {"title": "New: Elites", "text": "One of a kind, with a printed trait."},
	LOADOUT: {"title": "New: Loadout", "text": "Pick your three killstreaks before a run."},
	LETHAL: {"title": "New: Frag Grenade", "text": "Your Operator's grenade: 2 damage at the front. It recharges."},
	TACTICAL: {"title": "New: Tactical", "text": "Your Operator's tactical gear is ready. It recharges after use."},
}
## Keyword tip ids -> the player-facing keyword (CardData.trained_keyword_names) they explain.
const KEYWORD_TIPS: Dictionary = {
	&"kw_first_shot": "First Shot", &"kw_pick": "Pick", &"kw_flank": "Flank", &"kw_cover": "Cover",
	&"kw_suppress": "Suppress", &"kw_pierce": "Pierce", &"kw_patch": "Patch", &"kw_holder": "Holder",
	&"kw_front": "Front line", &"kw_on_deploy": "On Deploy", &"kw_on_down": "On Down",
	&"kw_guard": "Guard", &"kw_spotter": "Spotter", &"kw_fireteam": "Fireteam", &"kw_overwatch": "Overwatch",
}


## "New:" text of a flag ({} when it has none). Keyword tips: {title: "New: First Shot", text:
## SynergyRules.KEYWORD_TEXT (neighbor keywords) or "" (the UI uses the card's own rules line)}.
static func text_of(flag: StringName) -> Dictionary:
	if TEXTS.has(flag):
		return TEXTS[flag]
	if KEYWORD_TIPS.has(flag):
		var kw: StringName = StringName(String(flag).trim_prefix(KW_PREFIX))
		return {"title": "New: " + String(KEYWORD_TIPS[flag]), "text": String(SynergyRules.KEYWORD_TEXT.get(kw, ""))}
	return {}


## True when the flag opens a one-time "New:" explainer.
static func is_explained(flag: StringName) -> bool:
	return flag in EXPLAINED or KEYWORD_TIPS.has(flag)


## The UI rule (§5.1): an element shows once its system is met, or while something uses it now.
static func visible(flag: StringName, met: Dictionary, now: Array = []) -> bool:
	return met.has(String(flag)) or met.has(flag) or flag in now


## Explainers to show, in ORDER (keyword tips after), for flags in `met` not yet in `seen`.
static func pending_explainers(met: Dictionary, seen: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var keys: Array[StringName] = []
	for k: Variant in met:
		keys.append(StringName(String(k)))
	for f: StringName in ORDER:
		if f in keys and is_explained(f) and not seen.has(String(f)):
			out.append(f)
	for f: StringName in keys:
		if f not in ORDER and is_explained(f) and not seen.has(String(f)) and f not in out:
			out.append(f)
	return out


## Tip flag of a player-facing keyword name ("First Shot" -> &"kw_first_shot", "Cover 1" -> kw_cover).
static func keyword_flag(name: String) -> StringName:
	var base: String = name
	for prefix: String in ["Cover", "Patch"]:
		if name.begins_with(prefix):
			base = prefix
	for f: StringName in KEYWORD_TIPS:
		if KEYWORD_TIPS[f] == base:
			return f
	return StringName(KW_PREFIX + base.to_snake_case())


# =============================================================================
# Triggers
# =============================================================================

## Flags the run state implies right now: the current offer (calling cards / Trained cards / Fields /
## Elites offered, Promotion, Muster out, Salvage, pick 2, Retire) and the deck (a calling card owned
## = calling cards + Doctrine; a Trained copy = keywords). A finished first run unlocks LOADOUT.
static func run_triggers(run: RunProgress) -> Array[StringName]:
	var out: Array[StringName] = []
	if run == null:
		return out
	for i: int in run.deck.size():
		var c: CardData = run.resource(run.deck[i]) as CardData
		if c == null or c.standard_issue:
			continue
		if c.is_unit() and run.copy_trait(i) != &"":
			_add(out, CALLING_CARDS)
		if c.is_unit() and SynergyRules.keywords_on(c, run.level_of(i)) and not c.trained_keyword_names().is_empty():
			_add(out, KEYWORDS)
		if c.is_field():
			_add(out, FIELDS)
	if run.doctrine != &"":
		_add(out, DOCTRINE)
	if run.is_over():
		_add(out, LOADOUT)
	var offer: Dictionary = run.current_offer()
	if offer.is_empty():
		return out
	var kind: StringName = offer["kind"]
	if kind in RewardOffers.CARD_DROPS:
		if kind == RewardOffers.KIND_SALVAGE:
			_add(out, SALVAGE)
		if int(offer.get("picks", 1)) > 1 or (offer.get("taken", []) as Array).size() > 0:
			_add(out, MULTI_PICK)
		if bool(offer.get("retire", false)) and run.config.muster_out_after(int(offer.get("match", 0))):
			_add(out, RETIRE)
		var lv: int = int(offer.get("level", SynergyRules.LEVEL_TRAINED))
		for id: Variant in offer["options"]:
			var c: CardData = run.resource(StringName(id)) as CardData
			if c == null:
				continue
			if c.is_unit() and not c.trait_choices().is_empty():
				_add(out, CALLING_CARDS)
			if c.is_unit() and SynergyRules.keywords_on(c, lv) and not c.trained_keyword_names().is_empty():
				_add(out, KEYWORDS)
			if c.is_field():
				_add(out, FIELDS)
			if c.is_elite:
				_add(out, ELITES)
	elif kind == RewardOffers.KIND_PROMOTION:
		for f: StringName in [PROMOTION, ENGINE_PANEL, KEYWORDS]:
			_add(out, f)
	elif kind == RewardOffers.KIND_MUSTER_OUT:
		_add(out, MUSTER_OUT)
	return out


## Flags the board implies right now (either side): a traited unit in play (TRAIT_RAIL), a neighbor
## link (LINKS), a visible Field (FIELDS), every keyword a unit in play has (kw_* tips). LETHAL /
## TACTICAL / KILLSTREAKS are fed by the UI itself (it knows when a button is first ready).
static func match_triggers(state: MatchState) -> Array[StringName]:
	var out: Array[StringName] = []
	if state == null:
		return out
	for si: int in 2:
		var side: RulesSide = state.sides[si]
		for u: RulesUnit in side.units_on_board():
			if u.is_operator:
				continue
			if u.synergy_trait != &"":
				_add(out, TRAIT_RAIL)
			for kw: String in _unit_keywords(u):
				_add(out, keyword_flag(kw))
		for z: int in 3:
			for entry: Dictionary in side.equipment[z]:
				var rc: RulesCard = entry["card"]
				if rc != null and rc.card.is_visible_field():
					_add(out, FIELDS)
		var syn: Dictionary = SynergyRules.compute(state.synergy_lines(si), state.synergy_field_traits(si), side.setup.doctrine)
		if not (syn["links"] as Array).is_empty():
			_add(out, LINKS)
	return out


## Player-facing keywords a unit in play has (its own flags; locked ones on a Recruit don't count).
static func _unit_keywords(u: RulesUnit) -> Array[String]:
	var out: Array[String] = []
	if u.first_shot:
		out.append("First Shot")
	if u.pick:
		out.append("Pick")
	if u.flank:
		out.append("Flank")
	if u.cover > 0:
		out.append("Cover")
	if u.suppress:
		out.append("Suppress")
	if u.pierce:
		out.append("Pierce")
	if u.patch > 0:
		out.append("Patch")
	if u.holder:
		out.append("Holder")
	if u.arrives_front:
		out.append("Front line")
	for e: EffectData in u.effects:
		if e != null and e.trigger == DataEnums.Trigger.ON_DEPLOY and "On Deploy" not in out:
			out.append("On Deploy")
		elif e != null and e.trigger == DataEnums.Trigger.ON_DOWN and "On Down" not in out:
			out.append("On Down")
	if u.neighbor_keyword != &"":
		out.append(String(u.neighbor_keyword).capitalize())
	return out


static func _add(list: Array[StringName], f: StringName) -> void:
	if f not in list:
		list.append(f)
