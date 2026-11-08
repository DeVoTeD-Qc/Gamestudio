# synergy_rules.gd
# Purpose: The synergy layer of documentation/design/synergy-system.md (kc-syn, approved): trait set
#   bonuses (whole-set since kc-pos-cut §13; the neighbor keywords Guard, Spotter, Fireteam, Overwatch
#   of §3 are retired and compute() returns no links) and trait set bonuses (Vanguard, Spec Ops,
#   Heavy, Undead at 2 / 3 in play, §4). kc-no-training: the per-copy levels (Recruit / Trained /
#   Veteran / Elite) are removed; every copy has its keywords and effects from the start and carries
#   at most one trait. Pure and static: it works on plain "slot" dictionaries, so MatchState (real units)
#   and AiPlanner (its projected records) read exactly the same numbers. The reference model was
#   the designer's sim (tests/tools/synergy_rules.gd); the numbers here are its v1.1.
#
#   Board geometry (engine terms): column = zone 0..2 (A/B/C), row = index in the side's line
#   (0 = row 1, next to the objective). "In front" = index - 1, "behind" = index + 1, "beside" =
#   the same index in an adjacent zone (A-B, B-C; A and C are not adjacent). Only your own units
#   are neighbors; the Operator and tokens are neighbors without keyword or trait. Links are read
#   live from the lines, so they follow arrivals, slides, moves and eliminations.
#
#   Input of compute(): lines = 3 zones x Array of slots {uid: int, kw: StringName, trait: StringName}
#   (front first), field_traits = traits of the side's visible Fields, doctrine = the
#   side's Doctrine trait (&"" = none; +1 to that trait's count while it has at least one member).
#   Output: {zones: 3 x Array of per-slot results parallel to the input, counts: {trait: n},
#   tiers: {trait: 0/2/3}, links: [{kind, from_uid, to_uid}]} where a per-slot result is
#   {fp, cover, fs, heal, links: [{kind, from_uid}], sets: [[trait, tier]]}.
# Dependencies: none (plain data in, plain data out).
# Author: Mechanics Developer Agent (kc-syn-impl)
class_name SynergyRules
extends RefCounted

const GUARD: StringName = &"guard"
const SPOTTER: StringName = &"spotter"
const FIRETEAM: StringName = &"fireteam"
const OVERWATCH: StringName = &"overwatch"
const KEYWORDS: Array[StringName] = [GUARD, SPOTTER, FIRETEAM, OVERWATCH]

const VANGUARD: StringName = &"vanguard"
const SPECOPS: StringName = &"specops"
const HEAVY: StringName = &"heavy"
const UNDEAD: StringName = &"undead"
const TRAITS: Array[StringName] = [VANGUARD, SPECOPS, HEAVY, UNDEAD]
## Sentinel for "the chassis' default trait" (a missing SideSetup.deck_traits entry, kc-art-traits).
const TRAIT_DEFAULT: StringName = &"~default"
const TRAIT_NAMES: Dictionary = {VANGUARD: "Vanguard", SPECOPS: "Spec Ops", HEAVY: "Heavy", UNDEAD: "Undead"}

## Keyword amounts (each keyword counts once per receiving unit).
const GUARD_COVER: int = 1
const SPOTTER_FP: int = 1
const FIRETEAM_FP: int = 1
const OVERWATCH_COVER: int = 1
## Set thresholds.
const TIER2: int = 2
const TIER3: int = 3
## Trait bonuses (v2.0, kc-pos-cut, synergy-system.md §13; v1.5 kc-specops3: Spec Ops 3 = Cover +1
## instead of First Shot): [tier 2, tier 3], each {fp, cover, fs, heal}. No trait gives "fs" now; the key stays
## for balance what-ifs (tune_check tune=...).
## Whole-set bonuses: every unit of the trait gets them, wherever it stands (no row or column
## condition any more). Tier 3 includes tier 2. An empty entry = no bonus at that tier.
## v2.1 (kc-v2-impl, head V6: trait pass on Run v2 decks, run_v2_check exps=late): Vanguard's 3-set no
## longer adds Cover +1 (v2 decks complete sets twice as often; Vanguard read 64%), Heavy gets Cover +1
## at 2 and +1 FP at 3 (the same total at 3 as before; Heavy read 37%). Measured: 46-52% each.
## v2.2 (kc-econ: 1 Supply in round 1, 1 draw per round, 10-card decks): cheap bodies come out first and
## 4-drops late, so Heavy read 24% and Undead 64%. Vanguard's +1 FP moves from the 2-set to the 3-set,
## Heavy's 2-set is Cover +1 and +1 FP (+1 FP more at 3), Undead's 3-set loses Cover +1.
## Measured (run_v2_check exps=late, n = 270 each): Undead 44.1 · Vanguard 47.4 · Heavy 54.4 · Spec Ops 54.1.
const TRAIT_BONUS: Dictionary = {
	VANGUARD: [{}, {"fp": 1}],
	SPECOPS: [{"fp": 1}, {"cover": 1}],  # v1.5 (kc-specops3): tier 3 Cover +1 (was First Shot)
	HEAVY: [{"cover": 1, "fp": 1}, {"fp": 1}],
	UNDEAD: [{"heal": 1}, {"fp": 1}],
}
## The table compute() reads (balance tools may tune a copy in memory; the game uses TRAIT_BONUS).
static var trait_bonus: Dictionary = TRAIT_BONUS.duplicate(true)
## One-line tier texts for callouts / the inspector.
const TIER_TEXT: Dictionary = {
	VANGUARD: ["no bonus yet (Vanguard pays off at 3)", "Vanguard get +1 FP"],
	SPECOPS: ["Spec Ops get +1 FP", "Spec Ops get Cover +1"],
	HEAVY: ["Heavy units get Cover +1 and +1 FP", "Heavy units get +1 more FP"],
	UNDEAD: ["Undead heal 1 at the end of the round", "Undead also get +1 FP"],
}
## kc-pos-cut (§13): the four neighbor keywords are retired (no card carries one, compute() makes no
## links). The names and texts stay until the UI drops its link views.
const KEYWORD_TEXT: Dictionary = {
	GUARD: "Guard: the card behind this one has Cover +1.",
	SPOTTER: "Spotter: the card in front of this one gets +1 FP.",
	FIRETEAM: "Fireteam: +1 FP while a friendly card is beside this one.",
	OVERWATCH: "Overwatch: cards beside this one have Cover +1.",
}


## Master switch for control runs (balance tools only; the game never turns it off). Off = no
## links and no sets anywhere (compute() returns zero bonuses).
static var enabled: bool = true


## Plain slot for compute().
static func slot(uid: int, kw: StringName = &"", p_trait: StringName = &"") -> Dictionary:
	return {"uid": uid, "kw": kw, "trait": p_trait}


## Neighbor keyword a copy of `card` carries.
## kc-pos-cut (§13): neighbor keywords are retired, so no copy carries one (always &"").
static func keyword_at(_card: CardData) -> StringName:
	return &""


## kc-art-traits (art-traits.md §1, head T1/T2): the ONE trait a copy carries (kc-no-training: at
## most one trait per copy, never a list). `chosen` is the copy's trait as picked through its art
## (SideSetup.deck_traits / RulesCard.chosen_trait); TRAIT_DEFAULT = the chassis' default
## (CardData.card_trait = trait_options[0]). A chosen trait that is not on the chassis' option list
## makes the copy plain (&""). Printed cards (one option or none: Elites, Fields, tactics, the
## Sentry) always carry their printed trait, whatever is chosen. The rules never read arts: the
## run / UI layer resolves art -> trait (ArtTraits).
static func trait_at(card: CardData, chosen: StringName = TRAIT_DEFAULT) -> StringName:
	if card == null or card.standard_issue:
		return &""
	if chosen == TRAIT_DEFAULT or not card.has_trait_choice():
		return card.card_trait
	return chosen if card.can_carry(chosen) else &""


## kc-no-training: true when `t` names at most one trait: &"" (none) or exactly one of TRAITS.
## A combined value ("vanguard,undead", "heavy|specops", ...) is never a trait.
static func is_single_trait(t: StringName) -> bool:
	return t == &"" or t in TRAITS


static func tier_for(count: int) -> int:
	if count >= TIER3:
		return 3
	if count >= TIER2:
		return 2
	return 0


## kc-art-traits §5: the tier of trait `t` that gives a bonus at `count` in play (Heavy at 2 = 0:
## its tier 2 is empty). This is what compute() reports in `tiers`.
static func active_tier(t: StringName, count: int) -> int:
	var tier: int = tier_for(count)
	var tb: Array = trait_bonus.get(t, [])
	if tier == TIER3 and (tb.size() < 2 or _empty_bonus(tb[1])):
		tier = TIER2
	if tier == TIER2 and (tb.size() < 1 or _empty_bonus(tb[0])):
		tier = 0
	return tier


## The next set size that gives `t` a bonus above active tier `tier` (0 = none left). Heavy at 0 -> 3.
static func next_tier(t: StringName, tier: int) -> int:
	var tb: Array = trait_bonus.get(t, [])
	if tier < TIER2 and tb.size() >= 1 and not _empty_bonus(tb[0]):
		return TIER2
	if tier < TIER3 and tb.size() >= 2 and not _empty_bonus(tb[1]):
		return TIER3
	return 0


static func _empty_bonus(b: Variant) -> bool:
	if typeof(b) != TYPE_DICTIONARY:
		return true
	var d: Dictionary = b
	return int(d.get("fp", 0)) == 0 and int(d.get("cover", 0)) == 0 and int(d.get("heal", 0)) == 0 and not bool(d.get("fs", false))


## Trait counts of one side: units in the lines plus visible Fields, + Doctrine.
static func trait_counts(lines: Array, field_traits: Array, doctrine: StringName = &"") -> Dictionary:
	var counts: Dictionary = {}
	for z: int in 3:
		for s: Dictionary in lines[z]:
			var t: StringName = s.get("trait", &"")
			if t != &"":
				counts[t] = int(counts.get(t, 0)) + 1
	for t: Variant in field_traits:
		if StringName(t) != &"":
			counts[StringName(t)] = int(counts.get(StringName(t), 0)) + 1
	if doctrine != &"" and int(counts.get(doctrine, 0)) > 0:
		counts[doctrine] = int(counts[doctrine]) + 1
	return counts


## Synergy of one side's whole board (see the header for the shapes).
static func compute(lines: Array, field_traits: Array = [], doctrine: StringName = &"") -> Dictionary:
	var counts: Dictionary = trait_counts(lines, field_traits, doctrine) if enabled else {}
	var tiers: Dictionary = {}
	for t: StringName in counts:
		tiers[t] = active_tier(t, int(counts[t]))
	var zones: Array = [[], [], []]
	var pairs: Array[Dictionary] = []  # kc-pos-cut: no neighbor links any more (always empty)
	for z: int in 3:
		for i: int in (lines[z] as Array).size():
			var me: Dictionary = lines[z][i]
			var r: Dictionary = {"fp": 0, "cover": 0, "fs": false, "heal": 0, "links": [], "sets": []}
			if not enabled:
				zones[z].append(r)
				continue
			# Trait set bonus.
			var t: StringName = me.get("trait", &"")
			if t != &"" and trait_bonus.has(t):
				var tier: int = int(tiers.get(t, 0))
				var tb: Array = trait_bonus[t]
				for k: int in 2:
					if tier < [TIER2, TIER3][k]:
						continue
					var b: Dictionary = tb[k]
					if _empty_bonus(b):
						continue
					r["fp"] += int(b.get("fp", 0))
					r["cover"] += int(b.get("cover", 0))
					r["heal"] += int(b.get("heal", 0))
					if bool(b.get("fs", false)):
						r["fs"] = true
					r["sets"].append([t, [TIER2, TIER3][k]])
			zones[z].append(r)
	return {"zones": zones, "counts": counts, "tiers": tiers, "links": pairs}


## Sum of a compute() result as one number per bonus point (the AI's future value).
static func total_value(result: Dictionary) -> float:
	var total: float = 0.0
	for z: int in 3:
		for r: Dictionary in result["zones"][z]:
			total += float(r["fp"]) + float(r["cover"]) + (1.0 if r["fs"] else 0.0) + 0.5 * float(r["heal"])
	return total
