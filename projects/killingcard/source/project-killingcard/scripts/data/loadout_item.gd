# loadout_item.gd
# Purpose: One loadout item (core-rules §3): Primary weapon, weapon attachment,
#   Perk or Killstreak. `slot` decides which fields apply;
#   the others must stay at their defaults (validation says which).
#   One item = one .tres in res://data/loadout/.
#   kc-loadout-cut: the Secondary (P-12 Sidearm), Lethal (Frag Grenade) and Tactical (Flashbang)
#   slots are gone, and with them cooldowns (cooldown_rounds).
# Dependencies: DataEnums, EffectData, DataValidator.
# Author: Mechanics Developer Agent
class_name LoadoutItem
extends Resource

@export_group("Identity")
## Unique id, lowercase snake_case (e.g. kestrel_ar7, grit, recon_drone).
@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: DataEnums.LoadoutSlot = DataEnums.LoadoutSlot.PRIMARY
## Short rules text shown in the loadout screen / tooltip.
@export_multiline var text: String = ""
@export var icon: Texture2D = null

@export_group("Primary (Operator stats)")
@export var weapon_class: DataEnums.WeaponClass = DataEnums.WeaponClass.NONE
@export_range(0, 10) var operator_firepower: int = 0
@export_range(0, 20) var operator_armor: int = 0
## Rotations allowed per round (Wasp-9: 2).
@export_range(0, 3) var rotations_per_round: int = 1
## Attachment pool this weapon draws its level-up choices from (ATTACHMENT items).
## Array[Resource] with a LoadoutItem inspector filter: Array[LoadoutItem] inside
## LoadoutItem is a script self-reference that leaks at exit. Validation checks types.
@export_custom(PROPERTY_HINT_TYPE_STRING, "24/17:LoadoutItem")  # TYPE_OBJECT / PROPERTY_HINT_RESOURCE_TYPE
var attachments: Array[Resource] = []

@export_group("Operator kit (Primary; kc-v2-impl, run-v2.md §7)")
## The passive's name and one line ("Quartermaster" / "Your opening hand has 1 more card.").
@export var passive_name: String = ""
@export_multiline var passive_text: String = ""
## Passive: the Operator has Pierce (Longreach "Overpenetration"). Every LMG has Pierce anyway.
@export var pierce: bool = false
## Passive: cards added to the opening hand (Kestrel "Quartermaster": 1).
@export_range(0, 3) var opening_hand_bonus: int = 0
## The once-per-match ability (an ABILITY LoadoutItem). Resource, not LoadoutItem: a script
## self-reference leaks at exit (see attachments). Null = no ability.
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "LoadoutItem")
var ability: Resource = null
## Profile unlock of this Operator (RunProfile.OPERATOR_UNLOCKS keys: &"" = from the start).
@export var unlock: StringName = &""
## An enemy crew's Primary only (never offered as the player's Operator): wasp_9_crew keeps the pre-v2
## Wasp-9 (Armor 6) on SandViper / the Choir, so head V2's player buff doesn't toughen the crews.
@export var crew_only: bool = false

@export_group("Attachment stat changes")
@export_range(-5, 5) var firepower_bonus: int = 0
@export_range(-5, 10) var armor_bonus: int = 0

@export_group("Keywords (Primary / Attachment)")
@export var first_shot: bool = false
@export var pick: bool = false
@export var flank: bool = false
@export_range(0, 5) var cover: int = 0
@export var suppress: bool = false
@export_range(0, 5) var patch: int = 0
@export var holder: bool = false

@export_group("Use (Killstreak / Perk)")
@export_range(0, 10) var supply_cost: int = 0
## 0 = unlimited. Field Salvage 1 ("first time each round").
@export_range(0, 5) var uses_per_round: int = 0
## 0 = unlimited. Underbarrel Launcher 1, Grit 1.
@export_range(0, 5) var uses_per_match: int = 0

@export_group("Killstreak")
## Streak needed to earn it (2/3/4/5/7).
@export_range(0, 15) var streak_threshold: int = 0

@export_group("Effects")
@export var effects: Array[EffectData] = []

const _ACTIVATED_SLOTS: Array[int] = [DataEnums.LoadoutSlot.KILLSTREAK, DataEnums.LoadoutSlot.ABILITY]


func has_keywords() -> bool:
	return first_shot or pick or flank or cover > 0 or suppress or patch > 0 or holder


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	v.check_enum("slot", slot, DataEnums.LoadoutSlot)
	v.check_enum("weapon_class", weapon_class, DataEnums.WeaponClass)
	v.check_range("cover", cover, 0, 5)
	v.check_range("patch", patch, 0, 5)
	v.check_range("supply_cost", supply_cost, 0, 10)
	v.check_range("uses_per_round", uses_per_round, 0, 5)
	v.check_range("uses_per_match", uses_per_match, 0, 5)
	var is_primary: bool = slot == DataEnums.LoadoutSlot.PRIMARY
	var is_attachment: bool = slot == DataEnums.LoadoutSlot.ATTACHMENT
	var slot_name: String = DataEnums.key_of(DataEnums.LoadoutSlot, slot)

	if is_primary:
		if weapon_class == DataEnums.WeaponClass.NONE:
			v.missing("weapon_class", "a Primary needs a weapon class")
		v.check_range("operator_firepower", operator_firepower, 0, 10)
		v.check_range("operator_armor", operator_armor, 1, 20)
		v.check_range("rotations_per_round", rotations_per_round, 1, 3)
		# get_script() instead of the class name: a script naming itself as a value leaks at exit.
		v.check_ref_array("attachments", attachments, get_script(), 0, 20)
		for i: int in attachments.size():
			var att: Resource = attachments[i]
			if att != null and att.slot != DataEnums.LoadoutSlot.ATTACHMENT:
				v.invalid("attachments[%d]" % i, "'%s' is not an ATTACHMENT" % att.id)
	else:
		if weapon_class != DataEnums.WeaponClass.NONE or operator_firepower != 0 or operator_armor != 0 or not attachments.is_empty():
			v.invalid("weapon_class", "weapon class, Operator stats and attachments are for PRIMARY only (this is %s)" % slot_name)
		if rotations_per_round != 1:
			v.invalid("rotations_per_round", "rotations_per_round is for PRIMARY only")
		if pierce or opening_hand_bonus != 0 or ability != null or passive_text != "":
			v.invalid("passive_text", "the Operator kit (passive, Pierce, opening hand, ability) is for PRIMARY only")
	if is_primary and ability != null:
		if not (ability is LoadoutItem) or (ability as LoadoutItem).slot != DataEnums.LoadoutSlot.ABILITY:
			v.invalid("ability", "a Primary's ability must be an ABILITY LoadoutItem")
	if slot == DataEnums.LoadoutSlot.ABILITY:
		if uses_per_match != 1:
			v.invalid("uses_per_match", "an ability is once per match (uses_per_match = 1)")
		if supply_cost != 0:
			v.out_of_range("supply_cost", "abilities cost 0 Supply (got %d)" % supply_cost)

	if is_attachment:
		v.check_range("firepower_bonus", firepower_bonus, -5, 5)
		v.check_range("armor_bonus", armor_bonus, -5, 10)
		if firepower_bonus == 0 and armor_bonus == 0 and not has_keywords() and effects.is_empty():
			v.missing("effects", "attachment changes nothing (set a bonus, keyword or effect)")
	elif firepower_bonus != 0 or armor_bonus != 0:
		v.invalid("firepower_bonus", "stat bonuses are for ATTACHMENT only")

	if not (is_primary or is_attachment) and has_keywords():
		v.invalid("keywords", "keywords are for PRIMARY / ATTACHMENT only")

	if slot == DataEnums.LoadoutSlot.KILLSTREAK:
		v.check_range("streak_threshold", streak_threshold, 1, 15)
		if supply_cost != 0:
			v.out_of_range("supply_cost", "killstreaks cost 0 Supply (got %d)" % supply_cost)
	elif streak_threshold != 0:
		v.invalid("streak_threshold", "streak_threshold is for KILLSTREAK only")

	if slot in _ACTIVATED_SLOTS or slot == DataEnums.LoadoutSlot.PERK:
		if effects.is_empty():
			v.missing("effects", "a %s needs at least one effect" % slot_name)
	if slot not in _ACTIVATED_SLOTS and supply_cost != 0:
		v.invalid("supply_cost", "supply_cost is for activated items only (this is %s)" % slot_name)

	for i: int in effects.size():
		var effect: EffectData = effects[i]
		var field: String = "effects[%d]" % i
		if effect == null:
			v.broken_reference(field, "empty effect slot")
			continue
		effect.validate(v, field)
		if effect.trigger in [DataEnums.Trigger.ON_DEPLOY, DataEnums.Trigger.ON_DOWN, DataEnums.Trigger.ON_ENEMY_ARRIVE]:
			v.invalid(field + ".trigger", "%s is for deck cards, not loadout items" % DataEnums.key_of(DataEnums.Trigger, effect.trigger))
