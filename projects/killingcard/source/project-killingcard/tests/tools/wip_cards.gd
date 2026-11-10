# wip_cards.gd
# Purpose: kc-wip-design (documentation/design/wip-set.md). The head's 19 "Wip" cards from the Card Editor
#   export (documentation/design/wip-set.json), built IN MEMORY as CardData for the sims. Nothing in data/
#   or scripts/ changes. register() caches each card at res://data/cards/<id>.tres (take_over_path), so the
#   existing harnesses (run_v2_check starter=..., duel_sim pdeck=...) load them by id like real cards.
#   Cards whose rules the engine already has use real EffectData. The four NEW mechanics are listed in the
#   constants below and played by wip_match.gd (a sim-only MatchState):
#     Suppress N (Riot Shield, N = 1), Agile (Runner), Supply next round (Hacker), Beam (Laser Gunner).
#   WIP_TRAITS=1 gives each unit its proposed trait (PROPOSED_TRAIT); otherwise they have none.
#   Tweaks for what-ifs: the WIP_SET environment variable, "card.prop=value;card.prop=value"
#   (e.g. WIP_SET="sniper.firepower=4;private_1.armor=2").
# Author: Sr Game Designer Agent (kc-wip-design)
extends RefCounted

const K := DataEnums.EffectKind
const T := DataEnums.Target
const Z := DataEnums.ZoneScope
const TR := DataEnums.Trigger

## Card id -> Suppress amount (new: Suppress N; the shipped keyword is a fixed -2).
const SUPPRESS_N: Dictionary = {&"riot_shield": 1}
## Agile: once per round it may move to another column (wip_match.gd plays a greedy version).
const AGILE: Array[StringName] = [&"runner"]
## On Deploy: +N Supply next round only.
const SUPPLY_NEXT: Dictionary = {&"hacker": 1}
## Beam: its shot hits every unit in front of it in its column, friend and foe.
const BEAM: Array[StringName] = [&"laser_gunner"]

## The export's order. [id, name, type, cost, fp, armor, copies]
const LIST: Array = [
	[&"private_1", "Private I", 0, 1, 1, 1, 2],
	[&"private_2", "Private II", 0, 2, 2, 2, 1],
	[&"private_3", "Private III", 0, 3, 3, 3, 1],
	[&"private_4", "Private IV", 0, 4, 4, 4, 1],
	[&"scout", "Scout", 0, 1, 0, 3, 1],
	[&"medic", "Medic", 0, 2, 2, 3, 1],
	[&"sharpshooter", "Sharpshooter", 0, 3, 3, 2, 1],
	[&"flag_bearer", "Flag Bearer", 0, 4, 2, 2, 1],
	[&"hacker", "Hacker", 0, 2, 1, 1, 1],
	[&"kamikaze", "Kamikaze", 0, 3, 1, 1, 1],
	[&"runner", "Runner", 0, 3, 2, 4, 1],
	[&"sniper", "Sniper", 0, 4, 5, 2, 1],
	[&"juggernaut", "Juggernaut", 0, 5, 4, 5, 1],
	[&"riot_shield", "Riot Shield", 0, 4, 1, 3, 1],
	[&"fast_learner", "Fast Learner", 0, 5, 3, 4, 1],
	[&"laser_gunner", "Laser Gunner", 0, 5, 2, 2, 1],
	[&"war_shout", "War Shout", 1, 2, 0, 0, 1],
	[&"barrage", "Barrage", 1, 3, 0, 0, 1],
	[&"premium_loadout", "Premium Loadout", 1, 1, 0, 0, 1],
]

## The proposed trait per unit (wip-set.md §3.3); WIP_TRAITS=1 prints them on the sim cards.
const PROPOSED_TRAIT: Dictionary = {&"scout": &"vanguard", &"medic": &"undead", &"sharpshooter": &"specops",
		&"flag_bearer": &"vanguard", &"hacker": &"specops", &"kamikaze": &"heavy", &"runner": &"specops",
		&"sniper": &"specops", &"juggernaut": &"heavy", &"riot_shield": &"vanguard", &"fast_learner": &"undead",
		&"laser_gunner": &"heavy"}

## Cards whose every rule the shipped engine already plays (safe in run_v2_check's plain MatchState).
const ENGINE_READY: Array[StringName] = [&"private_1", &"private_2", &"private_3", &"private_4", &"scout",
		&"medic", &"sharpshooter", &"flag_bearer", &"kamikaze", &"sniper", &"juggernaut", &"fast_learner",
		&"war_shout", &"barrage", &"premium_loadout"]


static func fx(trigger: int, kind: int, target: int, scope: int, amount: int, duration: int = 0) -> EffectData:
	var e: EffectData = EffectData.new()
	e.trigger = trigger
	e.kind = kind
	e.target = target
	e.zone_scope = scope
	e.amount = amount
	e.duration_rounds = duration
	return e


## Builds the 19 cards. any_trait: units may wear any trait (the swap test gives a Wip card the trait of
## the pick it replaces, so it measures the chassis, not the lost set bonus).
static func build(any_trait: bool = false) -> Dictionary:
	var out: Dictionary = {}
	for row: Array in LIST:
		var c: CardData = CardData.new()
		c.id = row[0]
		c.display_name = row[1]
		c.card_type = row[2]
		c.cost = row[3]
		c.firepower = row[4]
		c.armor = row[5]
		c.collectible = true
		if String(c.id).begins_with("private_"):
			# The Private ladder is a plain starter ladder (wip-set.md §3): Standard Issue, never offered.
			c.collectible = false
			c.standard_issue = true
		match c.id:
			&"scout":
				c.arrives_front = true
			&"medic":
				c.patch = 1
			&"sharpshooter":
				c.first_shot = true
			&"sniper":
				c.pick = true
			&"juggernaut":
				c.pierce = true
			&"riot_shield":
				c.cover = 1  # Suppress 1 is played by wip_match.gd (suppress stays false: no -2)
			&"flag_bearer":
				c.effects.append(fx(TR.ON_DEPLOY, K.MODIFY_FIREPOWER, T.ALL_FRIENDLIES, Z.THIS_ZONE, 1))
				c.effects.append(fx(TR.ON_DEPLOY, K.MODIFY_ARMOR, T.ALL_FRIENDLIES, Z.THIS_ZONE, 1))
			&"kamikaze":
				c.effects.append(fx(TR.ON_DOWN, K.DAMAGE, T.ALL_ENEMIES, Z.THIS_ZONE, 1))
			&"fast_learner":
				c.effects.append(fx(TR.END_OF_ROUND, K.MODIFY_FIREPOWER, T.SELF, Z.THIS_ZONE, 1))
				c.effects.append(fx(TR.END_OF_ROUND, K.MODIFY_ARMOR, T.SELF, Z.THIS_ZONE, 1))
			&"war_shout":
				c.effects.append(fx(TR.ON_PLAY, K.MODIFY_FIREPOWER, T.ALL_FRIENDLIES, Z.ALL_ZONES, 2, 1))
			&"barrage":
				c.effects.append(fx(TR.ON_PLAY, K.DAMAGE, T.ENEMY_POINT_MAN, Z.ALL_ZONES, 1))
			&"premium_loadout":
				# The rule: +1/+1 to a chosen friendly unit (CHOSEN_FRIENDLY, permanent). The AI has no
				# candidate for a CHOSEN_FRIENDLY buff (AiPlanner._effect_candidates), so the sim card carries
				# a stand-in the AI can value (+1 FP to your units in a chosen column this round) and
				# wip_match.gd resolves it as +1/+1 for good on your front unit in that column.
				c.effects.append(fx(TR.ON_PLAY, K.MODIFY_FIREPOWER, T.ALL_FRIENDLIES, Z.CHOSEN_ZONE, 1, 1))
		if OS.get_environment("WIP_TRAITS") == "1" and PROPOSED_TRAIT.has(c.id):
			c.card_trait = PROPOSED_TRAIT[c.id]
		if any_trait and c.is_unit() and not c.standard_issue:
			var opts: Array[StringName] = [c.card_trait]  # the default (printed) trait first
			for t: StringName in [&"", &"vanguard", &"specops", &"heavy", &"undead"]:
				if t != c.card_trait:
					opts.append(t)
			c.trait_options.assign(opts)
		out[c.id] = c
	_apply_env(out)
	return out


## WIP_SET="card.prop=value;..." what-ifs (ints and bools).
static func _apply_env(cards: Dictionary) -> void:
	var raw: String = OS.get_environment("WIP_SET")
	if raw == "":
		return
	for item: String in raw.split(";"):
		var a: PackedStringArray = item.split(".", true, 1)
		var b: PackedStringArray = a[1].split("=", true, 1)
		var c: CardData = cards.get(StringName(a[0]))
		if c == null:
			push_error("wip_cards: unknown card " + a[0])
			continue
		var cur: Variant = c.get(b[0])
		c.set(b[0], (b[1] == "true" or b[1] == "1") if typeof(cur) == TYPE_BOOL else int(b[1]))


## Builds the cards and caches them at res://data/cards/<id>.tres so load() by id returns them.
static func register(any_trait: bool = false) -> Dictionary:
	var cards: Dictionary = build(any_trait)
	for id: StringName in cards:
		(cards[id] as CardData).take_over_path("res://data/cards/%s.tres" % id)
	return cards


## The export's full list (copies as exported: 20 cards).
static func export_deck(cards: Dictionary) -> Array[CardData]:
	var out: Array[CardData] = []
	for row: Array in LIST:
		for i: int in int(row[6]):
			out.append(cards[row[0]])
	return out
