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

@export_group("Synergy run layer (kc-syn §5)")
## The starter deck's copies are Recruits (level 0: no neighbor keyword, no trait). Off = Trained.
@export var starter_recruits: bool = false
## Supply Drop slot 1 is always a card of the deck's main trait (§5.2).
@export var supply_drop_on_trait: bool = false
## The run offers of §5.2 / §5.4: Doctrine (after doctrine_after_matches), Promotion (after
## promotion_after_matches), Retire as the Supply Drop's 4th option and Regroup (a free Retire)
## after a loss. Their screens are a UI task; until they land the data keeps this off.
@export var synergy_offers: bool = false
@export var doctrine_after_matches: PackedInt32Array = PackedInt32Array([1])
@export var promotion_after_matches: PackedInt32Array = PackedInt32Array([2, 4])
## Doctrine offer: pick 1 of this many trait emblems (the deck's best trait + random others).
@export_range(1, 4) var doctrine_choices: int = 2
## Retire never takes the deck below this many cards (the option greys out).
@export_range(1, 40) var deck_floor: int = 15

@export_group("Onboarding ladder (kc-onboard §4, approved N1-N4)")
## Rung of the Supply Drop / Salvage after match n (entry n-1): RUNG_UNITS 1 (units, no Elites),
## RUNG_TACTICS 2 (+ tactics), RUNG_FIELDS 3 (+ Fields), RUNG_FULL 4 (the whole pool). Empty or a
## missing / 0 entry = the whole pool (the pre-kc-onboard behaviour).
@export var reward_rungs: PackedInt32Array = PackedInt32Array()
## Level of the cards a Supply Drop / Salvage gives after match n (entry n-1): 0 Recruit calling card
## (trait on, keywords locked), 1 Trained. Empty or a missing entry = Trained.
@export var reward_levels: PackedInt32Array = PackedInt32Array()
## From this match on, a Supply Drop shows multi_pick_choices cards and you take multi_picks of them
## (N3: 2 of 4 from match 2). 0 = never (always pick 1 of supply_drop_choices).
@export_range(0, 5) var multi_pick_from_match: int = 0
@export_range(1, 6) var multi_pick_choices: int = 4
@export_range(1, 3) var multi_picks: int = 2
## Muster out (N2) after each Supply Drop / Salvage from this match on: every card taken sends one
## Standard Issue card home, plus muster_out_extra, never below deck_floor. 0 = off.
@export_range(0, 5) var muster_out_from_match: int = 0
@export_range(0, 3) var muster_out_extra: int = 1
## Salvage (N2) replaces Regroup after a loss: a salvage_choices-card drop of the current rung, pick 1.
@export var salvage_after_loss: bool = false
@export_range(1, 5) var salvage_choices: int = 2
## The first calling card you take sets the Doctrine (no Doctrine screen; doctrine_after_matches empty).
@export var doctrine_from_first_pick: bool = false
## Cards only older saves can still hold (the kc-syn Recruit starter's Rifleman): loadable, never offered.
@export var legacy_cards: Array[CardData] = []

@export_group("Starter kit")
## Exactly deck_size card references (copies = repeated entries).
@export var starter_deck: Array[CardData] = []
@export var starter_primary: LoadoutItem = null
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
## kc-syn §6.3: Supply to place the Operator (round 1 and every respawn), both sides, all modes.
## 0 = free (RunConfig.new() default, so hand-built test configs keep the old rule).
@export_range(0, 3) var operator_cost: int = 0

@export_group("Mode targets")
@export_range(1, 20) var zone_control_target: int = 6
@export_range(1, 20) var firefight_target: int = 7
@export_range(1, 20) var round_cap: int = 8
## Overtime still tied after this round -> draw (no ticket lost).
@export_range(1, 30) var overtime_draw_round: int = 10
## Detonator: rounds the Charge must stay armed.
@export_range(1, 5) var detonator_arm_rounds: int = 2

## Retired (kc-pos-cut, synergy-system.md §13): no Firepower bonus by column range any more. The
## fields stay so older .tres files load; the rules no longer read them and range_bonus() is 0.
@export_group("Range bonuses (retired)")
@export var range_bonus_smg: PackedInt32Array = PackedInt32Array([0, 0, 0])
@export var range_bonus_shotgun: PackedInt32Array = PackedInt32Array([0, 0, 0])
@export var range_bonus_ar: PackedInt32Array = PackedInt32Array([0, 0, 0])
@export var range_bonus_sniper: PackedInt32Array = PackedInt32Array([0, 0, 0])
@export var range_bonus_lmg: PackedInt32Array = PackedInt32Array([0, 0, 0])

const _RANGE_FIELDS: Dictionary = {
	DataEnums.WeaponClass.SMG: "range_bonus_smg",
	DataEnums.WeaponClass.SHOTGUN: "range_bonus_shotgun",
	DataEnums.WeaponClass.AR: "range_bonus_ar",
	DataEnums.WeaponClass.SNIPER: "range_bonus_sniper",
	DataEnums.WeaponClass.LMG: "range_bonus_lmg",
}


## Retired (kc-pos-cut): always 0. Kept for callers (UI) until they drop the range display.
func range_bonus(_weapon_class: DataEnums.WeaponClass, _range_tag: DataEnums.RangeTag) -> int:
	return 0


## Supply gained in round `round_number` (1-based).
func supply_for_round(round_number: int) -> int:
	return mini(round_number + supply_round_offset, supply_cap)


## kc-syn: copy levels of the starter deck (parallel to starter_deck): all Recruits (0) with
## starter_recruits, else all Trained (1). kc-onboard: Standard Issue cards are always 0 (they never
## train; their level has no effect).
func starter_levels() -> Array[int]:
	var out: Array[int] = []
	for c: CardData in starter_deck:
		out.append(0 if starter_recruits or (c != null and c.standard_issue) else 1)
	return out


const RUNG_FULL: int = 4
const RUNG_UNITS: int = 1
const RUNG_TACTICS: int = 2
const RUNG_FIELDS: int = 3
const RUNG_NAMES: Array[String] = ["Full", "Calling cards", "Keywords", "Fields", "Full"]


## kc-onboard §4.2: the reward rung after match n (1-based). RUNG_FULL when unset.
func rung_after(n: int) -> int:
	var r: int = reward_rungs[n - 1] if n >= 1 and n <= reward_rungs.size() else 0
	return r if r >= RUNG_UNITS and r <= RUNG_FULL else RUNG_FULL


## kc-onboard §4.2: the level of reward cards after match n (Trained when unset).
func reward_level_after(n: int) -> int:
	return clampi(reward_levels[n - 1], 0, 1) if n >= 1 and n <= reward_levels.size() else 1


## True when `card` is offered at `rung` (1 units without Elites, 2 + tactics, 3 + Fields, 4 all).
static func in_rung(card: CardData, rung: int) -> bool:
	if card == null:
		return false
	if rung >= RUNG_FULL:
		return true
	if card.is_unit():
		return not card.is_elite
	if card.card_type == DataEnums.CardType.TACTIC:
		return rung >= RUNG_TACTICS
	return rung >= RUNG_FIELDS


## (choices shown, picks) of the Supply Drop after match n.
func drop_size_after(n: int) -> Vector2i:
	if multi_pick_from_match > 0 and n >= multi_pick_from_match:
		return Vector2i(multi_pick_choices, mini(multi_picks, multi_pick_choices))
	return Vector2i(supply_drop_choices, 1)


## True when the drop / Salvage after match n is followed by Muster out.
func muster_out_after(n: int) -> bool:
	return muster_out_from_match > 0 and n >= muster_out_from_match


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
	v.check_range("doctrine_choices", doctrine_choices, 1, 4)
	v.check_range("deck_floor", deck_floor, 1, deck_size)
	v.check_range("operator_cost", operator_cost, 0, 3)
	for i: int in reward_rungs.size():
		v.check_range("reward_rungs[%d]" % i, reward_rungs[i], 0, RUNG_FULL)
	for i: int in reward_levels.size():
		v.check_range("reward_levels[%d]" % i, reward_levels[i], 0, 1)
	v.check_range("multi_pick_from_match", multi_pick_from_match, 0, maxi(matches.size(), 1))
	v.check_range("muster_out_from_match", muster_out_from_match, 0, maxi(matches.size(), 1))
	for i: int in legacy_cards.size():
		if legacy_cards[i] == null:
			v.broken_reference("legacy_cards[%d]" % i, "empty slot")
	for field: String in ["weapon_level_after_matches", "perk_offer_after_matches", "doctrine_after_matches", "promotion_after_matches"]:
		var list: PackedInt32Array = get(field)
		for i: int in list.size():
			v.check_range("%s[%d]" % [field, i], list[i], 1, maxi(matches.size(), 1))
	# Starter kit
	if v.check_ref_array("starter_deck", starter_deck, CardData, deck_size, deck_size):
		for i: int in starter_deck.size():
			if starter_deck[i] != null and starter_deck[i].is_token():
				v.invalid("starter_deck[%d]" % i, "'%s' is a token and can't be in a deck" % starter_deck[i].id)
	v.check_slot_ref("starter_primary", starter_primary, DataEnums.LoadoutSlot.PRIMARY, true)
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
