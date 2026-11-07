# data_enums.gd
# Purpose: Shared enums for every data Resource (cards, loadout, squads, run config).
#   Values are stored as ints in .tres files, so ONLY APPEND new values at the end
#   of an enum; never reorder or remove, or existing data changes meaning.
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name DataEnums
extends RefCounted

## What kind of deck card this is (core-rules §5 "Type").
## EQUIPMENT is shown to players as **Field** (KillingCard, field-cards.md decision F2):
## a card that stays on your half of a column's objective, gives an effect and is not a
## unit. The enum key stays EQUIPMENT (stored as an int in .tres); use CARD_TYPE_FIELD /
## type_label() in new code.
enum CardType { UNIT, TACTIC, EQUIPMENT }

## Player-facing alias of CardType.EQUIPMENT.
const CARD_TYPE_FIELD: int = CardType.EQUIPMENT
## Player-facing names of the card types.
const CARD_TYPE_LABELS: Dictionary = {CardType.UNIT: "Unit", CardType.TACTIC: "Tactic", CardType.EQUIPMENT: "Field"}

## Weapon class of a unit or Primary (core-rules §1 range table). NONE = "—".
enum WeaponClass { NONE, SMG, SHOTGUN, AR, SNIPER, LMG }

## Range tag of a zone (core-rules §1).
enum RangeTag { CLOSE, MID, LONG }

## Which loadout slot a LoadoutItem fills (core-rules §3). kc-loadout-cut: Secondary (2), Lethal (3)
## and Tactical (4) are gone; the values stay fixed so the saved .tres slot numbers keep their meaning.
## kc-v2-impl (run-v2.md §7): ABILITY = an Operator's once-per-match ability (LoadoutItem.ability of a
## Primary; free, usable from round 1, never in the Streak Tray).
enum LoadoutSlot { PRIMARY = 0, ATTACHMENT = 1, PERK = 5, KILLSTREAK = 6, ABILITY = 7 }

## Match win condition (core-rules §4).
enum GameMode { ZONE_CONTROL, FIREFIGHT, DETONATOR }

## Enemy AI personality (core-rules §7).
enum Personality { RUSHER, ANCHOR, SNIPER_NEST }

## When an effect fires. The owner decides the context: on a unit card ON_ELIMINATE
## means "when THIS unit eliminates"; on a perk it means "when any of your units/Operator eliminates".
enum Trigger {
	ON_PLAY,            ## Played/activated in Deploy, resolves at Reveal (tactics, killstreaks...).
	IMMEDIATE,          ## "Resolves immediately" during Deploy (intel, draw).
	ON_DEPLOY,          ## Unit revealed/arrives.
	ON_DOWN,            ## Unit eliminated.
	ON_ELIMINATE,       ## Owner eliminates an enemy.
	PASSIVE,            ## Always on while the source is in play / equipped.
	START_OF_FIREFIGHT, ## Start of each firefight (for duration_rounds firefights).
	END_OF_ROUND,       ## Score & Streak step.
	ON_ENEMY_ARRIVE,    ## Field trap: next enemy unit to arrive in this zone.
}

## What an effect does. The rules engine (p04/p05) implements each kind once.
enum EffectKind {
	NONE,                       ## Invalid; validation rejects it.
	DAMAGE,                     ## amount damage to each target.
	MODIFY_FIREPOWER,           ## +/- amount FP (negative allowed).
	MODIFY_ARMOR,               ## +/- amount max Armor.
	GRANT_COVER,                ## Cover amount.
	REMOVE_COVER,               ## Targets lose Cover.
	GRANT_FIRST_SHOT,
	REMOVE_FIRST_SHOT,
	UNTARGETABLE_BY_PICK_FLANK, ## Pick/Flank cannot target these units.
	DRAW,                       ## Owner draws amount cards.
	REVEAL_RED_DOTS,            ## Show what the enemy red dots in the zone are.
	REVEAL_DEPLOYMENTS,         ## Enemy deployments face-up during Deploy.
	HIDE_FROM_INTEL,            ## Never shown as a red dot; immune to enemy recon.
	MOVE_UNIT,                  ## Move target to a zone (zone_scope says where).
	STREAK_BONUS,               ## Owner's streak +amount.
	STREAK_THRESHOLD_MOD,       ## Owner's killstreak thresholds +amount (min 1).
	COOLDOWN_MOD,               ## Retired (kc-loadout-cut: no item has a cooldown); kept so later values keep their numbers.
	DESTROY_EQUIPMENT,          ## Destroy amount enemy Equipment card(s) in the zone.
	SUMMON_UNIT,                ## Place summon_card as a unit.
	SURVIVE_LETHAL,             ## Target survives lethal damage with amount Armor.
	HEAL,                       ## Each target regains up to amount lost Armor (never above max).
}

## Who an effect hits. CHOSEN_* targets are picked by the player once per play
## and shared by every effect of that play.
enum Target {
	SELF,                    ## The unit / Operator that owns the effect.
	OPERATOR,                ## Owner's Operator.
	OWNER,                   ## The owning side itself (draw, streak).
	CHOSEN_ENEMY,
	CHOSEN_FRIENDLY,
	ENEMY_POINT_MAN,
	ENEMY_SECOND_IN_LINE,    ## The unit behind the point man.
	ALL_ENEMIES,
	ALL_FRIENDLIES,
	OTHER_FRIENDLIES,        ## All friendlies except SELF.
	NEXT_FRIENDLY_ARRIVING,  ## Next friendly unit to arrive in the zone this round.
	ARRIVING_ENEMY,          ## The enemy unit that set off an ON_ENEMY_ARRIVE trap.
	ENEMY_EQUIPMENT,
	FRIENDLY_POINT_MAN,      ## Your frontline unit (index 0 of your line) in the zone; follows the line.
	MOST_DAMAGED_FRIENDLY,   ## Your unit with the most lost Armor in the zone (ties: front-most); none if unhurt.
}

## Which zone(s) an effect looks at.
enum ZoneScope {
	THIS_ZONE,            ## Zone of the source unit / equipment.
	CHOSEN_ZONE,          ## Player picks any zone.
	OPERATOR_ZONE,        ## Owner's Operator's zone.
	OPERATOR_OR_ADJACENT, ## Player picks the Operator's zone or one adjacent to it.
	ADJACENT_ZONE,        ## Player picks a zone adjacent to the target's zone (MOVE_UNIT).
	ALL_ZONES,
	ANY,                  ## Not zone-bound (draw, streak, thresholds).
}

## Gate for an effect (condition) or for its bonus_amount (bonus_condition).
enum Condition {
	ALWAYS,
	ZONE_IS_CLOSE,
	ZONE_IS_MID,
	ZONE_IS_LONG,
	YOU_CONTROL_ZONE,
	YOU_CONTROL_2_PLUS_ZONES,
}


## Player-facing name of a CardType value ("Unit" / "Tactic" / "Field").
static func type_label(card_type: int) -> String:
	return String(CARD_TYPE_LABELS.get(card_type, key_of(CardType, card_type)))


## Enum key for a value, for readable validation messages ("ZONE_CONTROL" or "<7?>").
static func key_of(enum_dict: Dictionary, value: int) -> String:
	var key: Variant = enum_dict.find_key(value)
	return String(key) if key != null else "<%d?>" % value
