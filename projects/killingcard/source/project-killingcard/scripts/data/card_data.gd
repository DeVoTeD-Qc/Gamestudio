# card_data.gd
# Purpose: One deck card (Unit, Tactic or Field) from core-rules §5, plus
#   non-collectible tokens such as the Sentry placed by a killstreak.
#   One card design = one .tres in res://data/cards/; copies in a deck reference the same file.
#   "Field" (KillingCard) is the player-facing name of CardType.EQUIPMENT: it stays on your
#   half of a column's objective (one visible Field per side per column, torn down by
#   Overrun), can't be shot and never counts for control (field-cards.md, Model B).
# Dependencies: DataEnums, EffectData, DataValidator.
# Author: Mechanics Developer Agent
class_name CardData
extends Resource

## Max characters of rules text ("one line of text maximum").
const MAX_TEXT_LENGTH: int = 100

@export_group("Identity")
## Unique id, lowercase snake_case (e.g. rifleman). Used by saves, logs and decks.
@export var id: StringName = &""
@export var display_name: String = ""
@export var card_type: DataEnums.CardType = DataEnums.CardType.UNIT
## Elite units (★): named, stronger, reward-pool only.
@export var is_elite: bool = false
## One-line rules text shown on the card.
@export_multiline var text: String = ""
## Optional card art; the UI uses a placeholder frame when empty.
@export var art: Texture2D = null

@export_group("Cost & stats")
@export_range(0, 10) var cost: int = 0
@export var weapon_class: DataEnums.WeaponClass = DataEnums.WeaponClass.NONE
## Units only. Base Firepower before range bonus.
@export_range(0, 10) var firepower: int = 0
## Units only. Max Armor (hit points).
@export_range(0, 20) var armor: int = 0

@export_group("Keywords")
@export var first_shot: bool = false
@export var pick: bool = false
@export var flank: bool = false
## Cover N: each hit on this unit deals N less damage (0 = no Cover).
@export_range(0, 5) var cover: int = 0
@export var suppress: bool = false
## Patch N: after the firefight restore N Armor to the most damaged other friendly here.
@export_range(0, 5) var patch: int = 0
@export var holder: bool = false

@export_group("Synergy (kc-syn)")
## Neighbor keyword of a Trained copy (synergy-system.md §3): &"guard", &"spotter", &"fireteam",
## &"overwatch" or &"" (none). Units only. Recruit copies (level 0) don't have it.
@export var neighbor_keyword: StringName = &""
## Trait of the chassis (§4): &"vanguard", &"specops", &"heavy", &"undead" or &"" (none). Units and
## Fields only. Recruit copies don't count for or receive set bonuses.
@export var card_trait: StringName = &""

@export_group("Special rules")
## Always arrives at the front of the line (Shieldman).
@export var arrives_front: bool = false
## Field stays hidden from the enemy after Reveal (Tripwire Charge). Hidden Fields are
## traps: they don't count toward the one-Field-per-column limit and aren't overrun.
@export var hidden: bool = false
## Field is discarded after its effect fires once (traps).
@export var consumed_on_trigger: bool = false
## Counts for zone control (false for the Sentry).
@export var counts_for_control: bool = true
## The enemy earns elimination/streak credit for killing it (false for the Sentry).
@export var grants_elimination_credit: bool = true
## Can appear in decks and Supply Drops. False for tokens (Sentry).
@export var collectible: bool = true

@export_group("Effects")
@export var effects: Array[EffectData] = []


func is_unit() -> bool:
	return card_type == DataEnums.CardType.UNIT


## Field = CardType.EQUIPMENT (the engine's internal name).
func is_field() -> bool:
	return card_type == DataEnums.CardType.EQUIPMENT


## A Field the enemy can see: limited to one per side per column and subject to Overrun.
func is_visible_field() -> bool:
	return is_field() and not hidden


## Player-facing type name: "Unit", "Tactic" or "Field".
func type_label() -> String:
	return DataEnums.type_label(card_type)


## True when playing the card asks the player to pick a zone.
func requires_zone_choice() -> bool:
	if card_type != DataEnums.CardType.TACTIC:
		return true  # units and Fields are placed in a zone
	for effect: EffectData in effects:
		if effect != null and effect.zone_scope in [DataEnums.ZoneScope.CHOSEN_ZONE, DataEnums.ZoneScope.OPERATOR_OR_ADJACENT]:
			return true
	return false


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	v.check_enum("card_type", card_type, DataEnums.CardType)
	v.check_enum("weapon_class", weapon_class, DataEnums.WeaponClass)
	v.check_range("cost", cost, 0, 10)
	v.check_range("cover", cover, 0, 5)
	v.check_range("patch", patch, 0, 5)
	if text.length() > MAX_TEXT_LENGTH:
		v.out_of_range("text", "rules text is %d characters (max %d, one line)" % [text.length(), MAX_TEXT_LENGTH])
	if text.contains("\n"):
		v.invalid("text", "rules text must be one line")
	if neighbor_keyword != &"" and neighbor_keyword not in SynergyRules.KEYWORDS:
		v.invalid("neighbor_keyword", "unknown neighbor keyword '%s' (one of %s)" % [neighbor_keyword, SynergyRules.KEYWORDS])
	if neighbor_keyword != &"" and not is_unit():
		v.invalid("neighbor_keyword", "only units have a neighbor keyword")
	if card_trait != &"" and card_trait not in SynergyRules.TRAITS:
		v.invalid("card_trait", "unknown trait '%s' (one of %s)" % [card_trait, SynergyRules.TRAITS])
	if card_trait != &"" and card_type == DataEnums.CardType.TACTIC:
		v.invalid("card_trait", "only units and Fields have a trait")
	if is_unit():
		v.check_range("firepower", firepower, 0, 10)
		v.check_range("armor", armor, 1, 20)
	else:
		if firepower != 0 or armor != 0:
			v.invalid("firepower", "only units have Firepower/Armor (got %d/%d)" % [firepower, armor])
		if weapon_class != DataEnums.WeaponClass.NONE:
			v.invalid("weapon_class", "only units have a weapon class")
		if first_shot or pick or flank or cover > 0 or suppress or patch > 0 or holder or arrives_front:
			v.invalid("keywords", "keywords and arrives_front are for units only")
		if is_elite:
			v.invalid("is_elite", "only units can be elite")
		if effects.is_empty():
			v.missing("effects", "a %s needs at least one effect" % DataEnums.key_of(DataEnums.CardType, card_type))
	if card_type != DataEnums.CardType.EQUIPMENT and (hidden or consumed_on_trigger):
		v.invalid("hidden", "hidden / consumed_on_trigger are for Fields only")
	if collectible and not (counts_for_control and grants_elimination_credit):
		v.invalid("collectible", "collectible cards must count for control and give elimination credit (tokens: collectible = false)")
	for i: int in effects.size():
		var effect: EffectData = effects[i]
		var field: String = "effects[%d]" % i
		if effect == null:
			v.broken_reference(field, "empty effect slot")
			continue
		effect.validate(v, field)
		if not is_unit() and effect.trigger in [DataEnums.Trigger.ON_DEPLOY, DataEnums.Trigger.ON_DOWN]:
			v.invalid(field + ".trigger", "ON_DEPLOY / ON_DOWN only make sense on units")
		if effect.trigger == DataEnums.Trigger.ON_ENEMY_ARRIVE and card_type != DataEnums.CardType.EQUIPMENT:
			v.invalid(field + ".trigger", "ON_ENEMY_ARRIVE is for Field traps")
		if is_field() and effect.trigger in [DataEnums.Trigger.PASSIVE, DataEnums.Trigger.END_OF_ROUND] \
				and effect.zone_scope != DataEnums.ZoneScope.THIS_ZONE:
			v.invalid(field + ".zone_scope", "a Field's PASSIVE / END_OF_ROUND effects work in its own column (THIS_ZONE)")
		if card_type == DataEnums.CardType.TACTIC and effect.trigger == DataEnums.Trigger.PASSIVE:
			v.invalid(field + ".trigger", "a Tactic leaves play at Reveal, so it can't have a PASSIVE effect")
