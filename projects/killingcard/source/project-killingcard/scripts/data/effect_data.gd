# effect_data.gd
# Purpose: One structured rules effect on a card or loadout item. Embedded as a
#   sub-resource (no id, no file of its own). Several effects on one card share the
#   same player choices (chosen zone / unit) and resolve in list order.
# Dependencies: DataEnums, CardData (summon_card), DataValidator.
# Author: Mechanics Developer Agent
class_name EffectData
extends Resource

@export var trigger: DataEnums.Trigger = DataEnums.Trigger.ON_PLAY
@export var kind: DataEnums.EffectKind = DataEnums.EffectKind.NONE
@export var target: DataEnums.Target = DataEnums.Target.CHOSEN_ENEMY
@export var zone_scope: DataEnums.ZoneScope = DataEnums.ZoneScope.CHOSEN_ZONE
## Only units of this class are affected (NONE = any class). E.g. "your Sniper units".
@export var target_class: DataEnums.WeaponClass = DataEnums.WeaponClass.NONE
## Size of the effect: damage, FP change (may be negative), cards drawn, Cover N...
@export_range(-10, 10) var amount: int = 0
## Added to amount when bonus_condition holds ("2 damage (3 if Close)": amount 2, bonus 1, ZONE_IS_CLOSE).
@export_range(-10, 10) var bonus_amount: int = 0
@export var bonus_condition: DataEnums.Condition = DataEnums.Condition.ALWAYS
## The whole effect only happens while this holds.
@export var condition: DataEnums.Condition = DataEnums.Condition.ALWAYS
## 0 = instant / permanent, 1 = this round, 2 = this round and next (or next 2 firefights).
@export_range(0, 5) var duration_rounds: int = 0
## Rounds to wait before it applies (0 = now, 1 = next round).
@export_range(0, 3) var delay_rounds: int = 0
## Unit placed by SUMMON_UNIT (e.g. the Sentry token card). Typed as Resource with a
## CardData inspector filter: a CardData-typed field here forms a script cycle
## (CardData -> EffectData -> CardData) that leaks at exit. Validation checks the type.
@export_custom(PROPERTY_HINT_RESOURCE_TYPE, "CardData") var summon_card: Resource = null

const _NEEDS_POSITIVE_AMOUNT: Array[int] = [
	DataEnums.EffectKind.DAMAGE, DataEnums.EffectKind.GRANT_COVER, DataEnums.EffectKind.DRAW,
	DataEnums.EffectKind.STREAK_BONUS, DataEnums.EffectKind.DESTROY_EQUIPMENT,
	DataEnums.EffectKind.SURVIVE_LETHAL, DataEnums.EffectKind.HEAL,
]
const _NEEDS_NONZERO_AMOUNT: Array[int] = [
	DataEnums.EffectKind.MODIFY_FIREPOWER, DataEnums.EffectKind.MODIFY_ARMOR,
	DataEnums.EffectKind.STREAK_THRESHOLD_MOD,
]


## Checks this effect; field names are prefixed with `prefix` (e.g. "effects[1]").
func validate(v: DataValidator, prefix: String) -> void:
	v.check_enum(prefix + ".trigger", trigger, DataEnums.Trigger)
	v.check_enum(prefix + ".kind", kind, DataEnums.EffectKind)
	v.check_enum(prefix + ".target", target, DataEnums.Target)
	v.check_enum(prefix + ".zone_scope", zone_scope, DataEnums.ZoneScope)
	v.check_enum(prefix + ".target_class", target_class, DataEnums.WeaponClass)
	v.check_enum(prefix + ".bonus_condition", bonus_condition, DataEnums.Condition)
	v.check_enum(prefix + ".condition", condition, DataEnums.Condition)
	v.check_range(prefix + ".amount", amount, -10, 10)
	v.check_range(prefix + ".bonus_amount", bonus_amount, -10, 10)
	v.check_range(prefix + ".duration_rounds", duration_rounds, 0, 5)
	v.check_range(prefix + ".delay_rounds", delay_rounds, 0, 3)
	if kind == DataEnums.EffectKind.NONE:
		v.missing(prefix + ".kind", "effect kind is NONE; pick what the effect does")
	if kind == DataEnums.EffectKind.COOLDOWN_MOD:
		v.invalid(prefix + ".kind", "COOLDOWN_MOD is retired (kc-loadout-cut: no item has a cooldown)")
	if kind in _NEEDS_POSITIVE_AMOUNT and amount <= 0:
		v.out_of_range(prefix + ".amount", "%s needs amount >= 1 (got %d)" % [DataEnums.key_of(DataEnums.EffectKind, kind), amount])
	if kind in _NEEDS_NONZERO_AMOUNT and amount == 0:
		v.out_of_range(prefix + ".amount", "%s needs a non-zero amount" % DataEnums.key_of(DataEnums.EffectKind, kind))
	if bonus_amount != 0 and bonus_condition == DataEnums.Condition.ALWAYS:
		v.invalid(prefix + ".bonus_condition", "bonus_amount is set but bonus_condition is ALWAYS; add it to amount instead")
	if kind == DataEnums.EffectKind.SUMMON_UNIT:
		v.check_unit_ref(prefix + ".summon_card", summon_card)
	elif summon_card != null:
		v.invalid(prefix + ".summon_card", "summon_card is only used by SUMMON_UNIT")
