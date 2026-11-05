# run_config.gd
# Purpose: All tunable run and match parameters (core-rules §1, §2, §4, §10 and the
#   prototype milestone plan): run structure (5 matches, 3 tickets, rewards), the
#   starter deck and loadout, offer pools, and match rules (Supply, hand, targets).
#   Lives at res://data/run_config.tres (id run_default).
# Dependencies: DataEnums, CardData, LoadoutItem, RunMatchData, DataValidator.
# Author: Mechanics Developer Agent
class_name RunConfig
extends Resource

@export_group("Identity")
## Unique id; the main run is run_default.
@export var id: StringName = &"run_default"
@export var display_name: String = ""

@export_group("Run structure")
## Matches in play order (prototype: Bracket 1 x2, Bracket 2 x2, Rival).
@export var matches: Array[RunMatchData] = []
## Reinforcement tickets: a lost match costs 1; the run ends at 0.
@export_range(1, 10) var tickets: int = 3
## Supply Drop after each won match: pick 1 of this many cards.
@export_range(1, 5) var supply_drop_choices: int = 3
## Weapon levels up after these match numbers (1-based; core-rules Ruling 1); choose 1 of attachment_choices.
@export var weapon_level_after_matches: PackedInt32Array = PackedInt32Array([1, 3, 4])
@export_range(1, 4) var attachment_choices: int = 2
## A Perk offer comes after these match numbers (1-based); choose 1 of perk_choices.
@export var perk_offer_after_matches: PackedInt32Array = PackedInt32Array([2, 4])
@export_range(1, 5) var perk_choices: int = 2

@export_group("Starter kit")
## Exactly deck_size card references (copies = repeated entries).
@export var starter_deck: Array[CardData] = []
@export var starter_primary: LoadoutItem = null
@export var starter_secondary: LoadoutItem = null
@export var starter_lethal: LoadoutItem = null
@export var starter_tactical: LoadoutItem = null
## Killstreaks pre-selected on the loadout screen (the player may change them).
@export var starter_killstreaks: Array[LoadoutItem] = []

@export_group("Offer pools")
## Cards offered by Supply Drops (copies raise the odds).
@export var reward_pool: Array[CardData] = []
## Killstreaks the player chooses killstreak_slots from at run start.
@export var killstreak_pool: Array[LoadoutItem] = []
## Perks offered during the run.
@export var perk_pool: Array[LoadoutItem] = []

@export_group("Loadout slots")
@export_range(0, 5) var perk_slots: int = 3
@export_range(1, 5) var killstreak_slots: int = 3

@export_group("Match rules")
@export_range(10, 40) var deck_size: int = 20
@export_range(1, 7) var opening_hand: int = 4
## Extra cards drawn in Round 1 Briefing on top of the opening hand.
@export_range(0, 3) var round1_extra_draw: int = 1
@export_range(0, 3) var free_mulligans: int = 1
@export_range(1, 5) var draws_per_round: int = 2
@export_range(3, 10) var hand_cap: int = 7
## Round N gives N + supply_round_offset Supply, capped at supply_cap.
@export_range(0, 5) var supply_round_offset: int = 1
@export_range(1, 15) var supply_cap: int = 7
@export_range(1, 6) var zone_capacity: int = 4
## Lethal/Tactical cooldown used when an item leaves cooldown_rounds at 0.
@export_range(0, 10) var default_cooldown: int = 3

@export_group("Mode targets")
@export_range(1, 20) var zone_control_target: int = 6
@export_range(1, 20) var firefight_target: int = 7
@export_range(1, 20) var round_cap: int = 8
## Overtime still tied after this round -> draw (no ticket lost).
@export_range(1, 30) var overtime_draw_round: int = 10
## Detonator: rounds the Charge must stay armed.
@export_range(1, 5) var detonator_arm_rounds: int = 2

@export_group("Range bonuses (Firepower by zone range: Close, Mid, Long)")
@export var range_bonus_smg: PackedInt32Array = PackedInt32Array([1, 0, 0])
@export var range_bonus_shotgun: PackedInt32Array = PackedInt32Array([2, 0, -1])
@export var range_bonus_ar: PackedInt32Array = PackedInt32Array([0, 1, 0])
@export var range_bonus_sniper: PackedInt32Array = PackedInt32Array([-1, 0, 2])
@export var range_bonus_lmg: PackedInt32Array = PackedInt32Array([0, 0, 0])

const _RANGE_FIELDS: Dictionary = {
	DataEnums.WeaponClass.SMG: "range_bonus_smg",
	DataEnums.WeaponClass.SHOTGUN: "range_bonus_shotgun",
	DataEnums.WeaponClass.AR: "range_bonus_ar",
	DataEnums.WeaponClass.SNIPER: "range_bonus_sniper",
	DataEnums.WeaponClass.LMG: "range_bonus_lmg",
}


## Firepower modifier for a weapon class in a zone of the given range (0 for NONE).
func range_bonus(weapon_class: DataEnums.WeaponClass, range_tag: DataEnums.RangeTag) -> int:
	if not _RANGE_FIELDS.has(weapon_class):
		return 0
	var row: PackedInt32Array = get(_RANGE_FIELDS[weapon_class])
	return row[range_tag]


## Supply gained in round `round_number` (1-based).
func supply_for_round(round_number: int) -> int:
	return mini(round_number + supply_round_offset, supply_cap)


func match_count() -> int:
	return matches.size()


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	# Run structure
	if matches.is_empty():
		v.missing("matches", "a run needs at least one match")
	for i: int in matches.size():
		if matches[i] == null:
			v.broken_reference("matches[%d]" % i, "empty match slot")
		else:
			matches[i].validate(v, "matches[%d]" % i)
	v.check_range("tickets", tickets, 1, 10)
	v.check_range("supply_drop_choices", supply_drop_choices, 1, 5)
	v.check_range("attachment_choices", attachment_choices, 1, 4)
	v.check_range("perk_choices", perk_choices, 1, 5)
	for field: String in ["weapon_level_after_matches", "perk_offer_after_matches"]:
		var list: PackedInt32Array = get(field)
		for i: int in list.size():
			v.check_range("%s[%d]" % [field, i], list[i], 1, maxi(matches.size(), 1))
	# Starter kit
	if v.check_ref_array("starter_deck", starter_deck, CardData, deck_size, deck_size):
		for i: int in starter_deck.size():
			if starter_deck[i] != null and not starter_deck[i].collectible:
				v.invalid("starter_deck[%d]" % i, "'%s' is a token and can't be in a deck" % starter_deck[i].id)
	v.check_slot_ref("starter_primary", starter_primary, DataEnums.LoadoutSlot.PRIMARY, true)
	v.check_slot_ref("starter_secondary", starter_secondary, DataEnums.LoadoutSlot.SECONDARY, true)
	v.check_slot_ref("starter_lethal", starter_lethal, DataEnums.LoadoutSlot.LETHAL, true)
	v.check_slot_ref("starter_tactical", starter_tactical, DataEnums.LoadoutSlot.TACTICAL, true)
	v.check_slot_array("starter_killstreaks", starter_killstreaks, DataEnums.LoadoutSlot.KILLSTREAK, killstreak_slots, killstreak_slots)
	# Pools
	if v.check_ref_array("reward_pool", reward_pool, CardData, supply_drop_choices, 200):
		for i: int in reward_pool.size():
			if reward_pool[i] != null and not reward_pool[i].collectible:
				v.invalid("reward_pool[%d]" % i, "'%s' is a token and can't be a reward" % reward_pool[i].id)
	v.check_slot_array("killstreak_pool", killstreak_pool, DataEnums.LoadoutSlot.KILLSTREAK, killstreak_slots, 20)
	v.check_slot_array("perk_pool", perk_pool, DataEnums.LoadoutSlot.PERK, perk_choices if not perk_offer_after_matches.is_empty() else 0, 20)
	for i: int in starter_killstreaks.size():
		if starter_killstreaks[i] != null and starter_killstreaks[i] not in killstreak_pool:
			v.invalid("starter_killstreaks[%d]" % i, "'%s' is not in killstreak_pool" % starter_killstreaks[i].id)
	if v.has_duplicates(starter_killstreaks):
		v.invalid("starter_killstreaks", "the same killstreak is listed twice")
	# Match rules
	v.check_range("perk_slots", perk_slots, 0, 5)
	v.check_range("killstreak_slots", killstreak_slots, 1, 5)
	v.check_range("deck_size", deck_size, 10, 40)
	v.check_range("opening_hand", opening_hand, 1, hand_cap)
	v.check_range("round1_extra_draw", round1_extra_draw, 0, 3)
	v.check_range("free_mulligans", free_mulligans, 0, 3)
	v.check_range("draws_per_round", draws_per_round, 1, 5)
	v.check_range("hand_cap", hand_cap, 3, 10)
	v.check_range("supply_round_offset", supply_round_offset, 0, 5)
	v.check_range("supply_cap", supply_cap, 1, 15)
	v.check_range("zone_capacity", zone_capacity, 1, 6)
	v.check_range("default_cooldown", default_cooldown, 0, 10)
	v.check_range("zone_control_target", zone_control_target, 1, 20)
	v.check_range("firefight_target", firefight_target, 1, 20)
	v.check_range("round_cap", round_cap, 1, 20)
	v.check_range("overtime_draw_round", overtime_draw_round, round_cap, 30)
	v.check_range("detonator_arm_rounds", detonator_arm_rounds, 1, 5)
	for field: String in _RANGE_FIELDS.values():
		var row: PackedInt32Array = get(field)
		if row.size() != 3:
			v.out_of_range(field, "needs 3 values: Close, Mid, Long (got %d)" % row.size())
		for i: int in row.size():
			v.check_range("%s[%d]" % [field, i], row[i], -5, 5)
