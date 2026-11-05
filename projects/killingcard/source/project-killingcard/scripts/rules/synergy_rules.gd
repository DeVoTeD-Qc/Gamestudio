# synergy_rules.gd
# Purpose: The synergy layer of documentation/design/synergy-system.md (kc-syn, approved): neighbor
#   keywords (Guard, Spotter, Fireteam, Overwatch, §3) and trait set bonuses (Vanguard, Spec Ops,
#   Heavy, Undead at 2 / 3 in play, §4), plus the per-copy levels (Recruit / Trained / Veteran /
#   Elite, §5.2). Pure and static: it works on plain "slot" dictionaries, so MatchState (real units)
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
#   (front first), field_traits = traits of the side's visible Trained Fields, doctrine = the
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
const TRAIT_NAMES: Dictionary = {VANGUARD: "Vanguard", SPECOPS: "Spec Ops", HEAVY: "Heavy", UNDEAD: "Undead"}

## Per-copy levels (§5.2; the camo band shows them: plain / Gilded / Forged / Priceless).
const LEVEL_RECRUIT: int = 0
const LEVEL_TRAINED: int = 1
const LEVEL_VETERAN: int = 2
const LEVEL_ELITE: int = 3
const LEVEL_MAX: int = LEVEL_ELITE
const LEVEL_NAMES: Array[String] = ["Recruit", "Trained", "Veteran", "Elite"]
const LEVEL_BANDS: Array[StringName] = [&"", &"gilded", &"forged", &"priceless"]

## Keyword amounts (each keyword counts once per receiving unit).
const GUARD_COVER: int = 1
const SPOTTER_FP: int = 1
const FIRETEAM_FP: int = 1
const OVERWATCH_COVER: int = 1
## Set thresholds.
const TIER2: int = 2
const TIER3: int = 3
## Trait bonuses (v1.1): [tier 2, tier 3], each {fp, cover, fs, heal, where}. where: "all" or
## "front" (row 1 only). Tier 3 includes tier 2.
const TRAIT_BONUS: Dictionary = {
	VANGUARD: [{"fp": 1, "where": "front"}, {"cover": 1, "where": "all"}],
	SPECOPS: [{"fp": 1, "where": "all"}, {"fs": true, "where": "all"}],
	HEAVY: [{"cover": 1, "where": "all"}, {"fp": 1, "where": "all"}],
	UNDEAD: [{"heal": 1, "where": "all"}, {"fp": 1, "where": "all"}],
}
## The table compute() reads (balance tools may tune a copy in memory; the game uses TRAIT_BONUS).
static var trait_bonus: Dictionary = TRAIT_BONUS.duplicate(true)
## One-line tier texts for callouts / the inspector.
const TIER_TEXT: Dictionary = {
	VANGUARD: ["Vanguard in row 1 get +1 FP", "Vanguard get Cover +1"],
	SPECOPS: ["Spec Ops get +1 FP", "Spec Ops have First Shot"],
	HEAVY: ["Heavy units have Cover +1", "Heavy units get +1 FP"],
	UNDEAD: ["Undead heal 1 at the end of the round", "Undead get +1 FP"],
}
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


## Stat bonus of a copy's level: Veteran +1 Armor, Elite +1 Armor +1 FP. {fp, armor}.
static func level_stats(level: int) -> Dictionary:
	return {"fp": 1 if level >= LEVEL_ELITE else 0, "armor": 1 if level >= LEVEL_VETERAN else 0}


## Keyword / trait a copy of `card` carries at `level` (Recruits have neither).
static func keyword_at(card: CardData, level: int) -> StringName:
	return card.neighbor_keyword if card != null and level >= LEVEL_TRAINED else &""


static func trait_at(card: CardData, level: int) -> StringName:
	return card.card_trait if card != null and level >= LEVEL_TRAINED else &""


static func tier_for(count: int) -> int:
	if count >= TIER3:
		return 3
	if count >= TIER2:
		return 2
	return 0


## Trait counts of one side: units in the lines plus visible Trained Fields, + Doctrine.
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


static func _at(lines: Array, z: int, i: int) -> Dictionary:
	if z < 0 or z > 2 or i < 0 or i >= (lines[z] as Array).size():
		return {}
	return lines[z][i]


## Synergy of one side's whole board (see the header for the shapes).
static func compute(lines: Array, field_traits: Array = [], doctrine: StringName = &"") -> Dictionary:
	var counts: Dictionary = trait_counts(lines, field_traits, doctrine) if enabled else {}
	var tiers: Dictionary = {}
	for t: StringName in counts:
		tiers[t] = tier_for(int(counts[t]))
	var zones: Array = [[], [], []]
	var pairs: Array[Dictionary] = []
	for z: int in 3:
		for i: int in (lines[z] as Array).size():
			var me: Dictionary = lines[z][i]
			var uid: int = int(me.get("uid", -1))
			var r: Dictionary = {"fp": 0, "cover": 0, "fs": false, "heal": 0, "links": [], "sets": []}
			if not enabled:
				zones[z].append(r)
				continue
			# Spotter behind me: +1 FP to me (the card in front of the Spotter).
			var back: Dictionary = _at(lines, z, i + 1)
			if not back.is_empty() and back.get("kw", &"") == SPOTTER:
				r["fp"] += SPOTTER_FP
				_link(r, pairs, SPOTTER, int(back.get("uid", -1)), uid)
			# Guard in front of me: Cover +1 to me (the card behind the Guard).
			var front: Dictionary = _at(lines, z, i - 1)
			if not front.is_empty() and front.get("kw", &"") == GUARD:
				r["cover"] += GUARD_COVER
				_link(r, pairs, GUARD, int(front.get("uid", -1)), uid)
			var left: Dictionary = _at(lines, z - 1, i)
			var right: Dictionary = _at(lines, z + 1, i)
			# Fireteam: +1 FP to itself while a friendly card is beside it (max +1).
			if me.get("kw", &"") == FIRETEAM and not (left.is_empty() and right.is_empty()):
				r["fp"] += FIRETEAM_FP
				var mate: Dictionary = left if not left.is_empty() else right
				_link(r, pairs, FIRETEAM, int(mate.get("uid", -1)), uid)
			# Overwatch beside me: Cover +1 to me (max +1 even with two).
			var ow: Dictionary = {}
			if not left.is_empty() and left.get("kw", &"") == OVERWATCH:
				ow = left
			elif not right.is_empty() and right.get("kw", &"") == OVERWATCH:
				ow = right
			if not ow.is_empty():
				r["cover"] += OVERWATCH_COVER
				_link(r, pairs, OVERWATCH, int(ow.get("uid", -1)), uid)
			# Trait set bonus.
			var t: StringName = me.get("trait", &"")
			if t != &"" and trait_bonus.has(t):
				var tier: int = int(tiers.get(t, 0))
				var tb: Array = trait_bonus[t]
				for k: int in 2:
					if tier < [TIER2, TIER3][k]:
						continue
					var b: Dictionary = tb[k]
					if String(b.get("where", "all")) == "front" and i != 0:
						continue
					r["fp"] += int(b.get("fp", 0))
					r["cover"] += int(b.get("cover", 0))
					r["heal"] += int(b.get("heal", 0))
					if bool(b.get("fs", false)):
						r["fs"] = true
					r["sets"].append([t, [TIER2, TIER3][k]])
			zones[z].append(r)
	return {"zones": zones, "counts": counts, "tiers": tiers, "links": pairs}


static func _link(r: Dictionary, pairs: Array[Dictionary], kind: StringName, from_uid: int, to_uid: int) -> void:
	r["links"].append({"kind": kind, "from_uid": from_uid})
	pairs.append({"kind": kind, "from_uid": from_uid, "to_uid": to_uid})


## Sum of a compute() result as one number per bonus point (the AI's future value).
static func total_value(result: Dictionary) -> float:
	var total: float = 0.0
	for z: int in 3:
		for r: Dictionary in result["zones"][z]:
			total += float(r["fp"]) + float(r["cover"]) + (1.0 if r["fs"] else 0.0) + 0.5 * float(r["heal"])
	return total
