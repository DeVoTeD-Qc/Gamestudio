# synergy_rules.gd
# Purpose: kc-syn PROPOSAL model (design sim only, not game code). Pure functions that
#   compute the neighbor-keyword and trait set bonuses of documentation/design/synergy-system.md
#   from a board described as card ids per side / column / row. Used by tests/tools/synergy_sim.gd
#   both inside a MatchState subclass (the rules the engine would apply) and inside a planner
#   subclass (the "synergy-aware" policy), so both read exactly the same numbers.
#   Board geometry (engine terms): column = zone 0..2 (A/B/C), row = index in the side's line
#   (0 = row 1 = frontline, next to the objective). "Behind" = index + 1, "in front" = index - 1,
#   "beside" = same index in an adjacent zone (A-B, B-C; A and C are not adjacent).
#   Tunable at runtime (static vars) so the sim can sweep numbers without editing files.
# Author: Sr Game Designer Agent (kc-syn)
extends RefCounted

## Master switch (false = the engine exactly as today).
static var enabled: bool = true

## Neighbor keywords by chassis id. guard: the unit behind gets Cover +1. spotter: the unit in
## front gets +1 FP. fireteam: +1 FP while a friendly unit is beside it. overwatch: units beside
## it get Cover +1. Each keyword counts once per receiving unit (no stacking of the same keyword).
static var keywords: Dictionary = {
	&"rifleman": &"fireteam",
	&"point_man": &"fireteam",
	&"brawler": &"fireteam",
	&"breacher": &"guard",
	&"shieldman": &"guard",
	&"gunner": &"overwatch",
	&"recon_specialist": &"spotter",
	&"marksman": &"spotter",
}

## Trait by chassis id (units and Fields; one trait per chassis; tactics have none).
static var traits: Dictionary = {
	&"point_man": &"vanguard", &"breacher": &"vanguard", &"shieldman": &"vanguard", &"bulwark": &"vanguard",
	&"flanker": &"specops", &"recon_specialist": &"specops", &"marksman": &"specops", &"halek_wren": &"specops",
	&"listening_post": &"specops",
	&"gunner": &"heavy", &"demolitions_expert": &"heavy", &"okafor_anvil": &"heavy", &"mortar_pit": &"heavy",
	&"brawler": &"undead", &"combat_medic": &"undead", &"war_standard": &"undead", &"aid_station": &"undead",
}

## Recruit copies (plain starter cards, kc-syn §5.1) carry the chassis id + RECRUIT_SUFFIX:
## no neighbor keyword and no trait until a Promotion trains them.
const RECRUIT_SUFFIX: String = "_r"


static func is_recruit(id: StringName) -> bool:
	return String(id).ends_with(RECRUIT_SUFFIX)


static func base_id(id: StringName) -> StringName:
	return StringName(String(id).trim_suffix(RECRUIT_SUFFIX)) if is_recruit(id) else id

## Keyword amounts (sweepable).
static var guard_cover: int = 1
static var spotter_fp: int = 1
static var fireteam_fp: int = 1
static var overwatch_cover: int = 1
## Set thresholds.
static var tier2: int = 2
static var tier3: int = 3
## Trait bonuses: [tier2 effect, tier3 effect], each {fp, cover, fs, heal, where}.
## where: "all", "front" (row 1 only), "back" (rows 2-4).
static var trait_bonus: Dictionary = {
	&"vanguard": [{"fp": 1, "where": "front"}, {"cover": 1, "where": "all"}],
	&"specops": [{"fp": 1, "where": "back"}, {"fs": true, "where": "all"}],
	&"heavy": [{"cover": 1, "where": "all"}, {"fp": 1, "where": "all"}],
	&"undead": [{"heal": 1, "where": "all"}, {"fp": 1, "where": "all"}],
}


static func set_number(key: String, value: Variant) -> void:
	# e.g. "guard_cover=0", "trait.vanguard.0.fp=0", "kw.rifleman=none"
	if key.begins_with("trait."):
		var parts: PackedStringArray = key.split(".")
		var tb: Array = trait_bonus[StringName(parts[1])]
		(tb[int(parts[2])] as Dictionary)[parts[3]] = value
	elif key.begins_with("kw."):
		var id: StringName = StringName(key.substr(3))
		if str(value) == "none":
			keywords.erase(id)
		else:
			keywords[id] = StringName(str(value))
	elif key.begins_with("tr."):
		var id2: StringName = StringName(key.substr(3))
		if str(value) == "none":
			traits.erase(id2)
		else:
			traits[id2] = StringName(str(value))
	else:
		match key:
			"enabled": enabled = bool(value)
			"guard_cover": guard_cover = int(value)
			"spotter_fp": spotter_fp = int(value)
			"fireteam_fp": fireteam_fp = int(value)
			"overwatch_cover": overwatch_cover = int(value)
			"tier2": tier2 = int(value)
			"tier3": tier3 = int(value)
			_: push_error("synergy_rules: unknown number " + key)


## Trait counts of one side: units on its board plus its visible Fields (any column).
## unit_ids: Array (3 zones) of Array[StringName]; field_ids: Array[StringName].
static func trait_counts(unit_ids: Array, field_ids: Array) -> Dictionary:
	var counts: Dictionary = {}
	for z: int in 3:
		for id: StringName in unit_ids[z]:
			var t: StringName = traits.get(id, &"")
			if t != &"":
				counts[t] = int(counts.get(t, 0)) + 1
	for id: StringName in field_ids:
		var t: StringName = traits.get(id, &"")
		if t != &"":
			counts[t] = int(counts.get(t, 0)) + 1
	return counts


static func _keyword(ids: Array, z: int, i: int) -> StringName:
	if z < 0 or z > 2 or i < 0 or i >= (ids[z] as Array).size():
		return &""
	return keywords.get(ids[z][i], &"")


static func _occupied(ids: Array, z: int, i: int) -> bool:
	return z >= 0 and z <= 2 and i >= 0 and i < (ids[z] as Array).size()


## Synergy for one side's whole board: Array (3 zones) of Array of {fp, cover, fs, heal,
## links: Array[String]} parallel to unit_ids. Ids of the Operator / tokens are &"" or any id
## not in the tables: they count as friendly neighbors but carry no keyword or trait.
static func compute(unit_ids: Array, field_ids: Array) -> Array:
	var out: Array = [[], [], []]
	var counts: Dictionary = trait_counts(unit_ids, field_ids) if enabled else {}
	for z: int in 3:
		for i: int in (unit_ids[z] as Array).size():
			var r: Dictionary = {"fp": 0, "cover": 0, "fs": false, "heal": 0, "links": []}
			if enabled:
				var me: StringName = unit_ids[z][i]
				# Up / down.
				if _keyword(unit_ids, z, i + 1) == &"spotter":
					r["fp"] += spotter_fp
					r["links"].append("spotter")
				if _keyword(unit_ids, z, i - 1) == &"guard":
					r["cover"] += guard_cover
					r["links"].append("guard")
				# Left / right (same row in an adjacent column).
				var beside: bool = _occupied(unit_ids, z - 1, i) or _occupied(unit_ids, z + 1, i)
				if beside and keywords.get(me, &"") == &"fireteam":
					r["fp"] += fireteam_fp
					r["links"].append("fireteam")
				if _keyword(unit_ids, z - 1, i) == &"overwatch" or _keyword(unit_ids, z + 1, i) == &"overwatch":
					r["cover"] += overwatch_cover
					r["links"].append("overwatch")
				# Trait set bonus.
				var t: StringName = traits.get(me, &"")
				if t != &"" and trait_bonus.has(t):
					var n: int = int(counts.get(t, 0))
					var tiers: Array = trait_bonus[t]
					for k: int in 2:
						if n < [tier2, tier3][k]:
							continue
						var b: Dictionary = tiers[k]
						var where: String = String(b.get("where", "all"))
						if where == "front" and i != 0:
							continue
						if where == "back" and i == 0:
							continue
						r["fp"] += int(b.get("fp", 0))
						r["cover"] += int(b.get("cover", 0))
						r["heal"] += int(b.get("heal", 0))
						if bool(b.get("fs", false)):
							r["fs"] = true
						r["links"].append("%s%d" % [t, [tier2, tier3][k]])
			out[z].append(r)
	return out
