# card_data.gd
# Pattern adapted from CallingCard scripts/data/card_data.gd (typed Resource + validate(v));
#   the fields are new for CardZone.
# Purpose: One CardZone card (spec §6, §10, §11): weapons, attachments, items, starters, the Hit
#   card and the shared Bounty. One card = one .tres in res://data/cards/. Copies (4 Scavenge
#   in a pack, 3 cards in a pile, 5 Hits per health stack) are made by the rules from this one
#   definition. Rules that need several files (unique codes, one Hit card, pile placement) live
#   in CardDB's cross checks.
# Dependencies: DataEnums, DataValidator.
# Author: Mechanics Developer Agent
class_name CardData
extends Resource

## No range set (every card that isn't a weapon, and cards with no blast).
const NO_RANGE: int = -1

@export_group("Identity")
## Unique id, lowercase snake_case (e.g. pump_shotgun). Used by rules, saves and logs.
@export var id: StringName = &""
## Printed card number, CZ-000 (spec §6 "card id for sorting"). Unique.
@export var code: String = ""
@export var display_name: String = ""
@export var type: DataEnums.CardType = DataEnums.CardType.ITEM
@export var rarity: DataEnums.Rarity = DataEnums.Rarity.NONE
## Search to loot it from a pile (1-9). 0 for starters, Hit, Bounty and supply drops
## (a drop costs BalanceConfig.supply_drop_cost).
@export_range(0, 9) var cost: int = 0
## A supply-drop card (spec §8): placed by a Zone card, never in a pile.
@export var supply_drop: bool = false

@export_group("Play effects (keywords, spec §6)")
## Brace N: shield value while in your next hand (0 = none).
@export_range(0, 9) var brace: int = 0
## Move N on play.
@export_range(0, 9) var move: int = 0
## Search N on play.
@export_range(0, 9) var search: int = 0
## Heal N on play (R15).
@export_range(0, 9) var heal: int = 0
## Pull N on play (R3).
@export_range(0, 9) var pull: int = 0
## Spent: when the card leaves the game (Bandage on play, Smoke Grenade on Brace).
@export var spent: DataEnums.SpentMode = DataEnums.SpentMode.NONE

@export_group("Weapon (spec §7)")
## DMG. Weapons need 1+; every other card 0.
@export_range(0, 9) var dmg: int = 0
## RNG 0 (same area), 1 (adjacent) or 2 (anywhere). -1 = not set (only weapons set it).
@export_range(-1, 2) var rng: int = NO_RANGE
## Shots per turn (Twin-Drum LMG 2). Weapons only.
@export_range(1, 3) var fires_per_turn: int = 1
## Ignores the target area's Cover (Marksman Rifle, Longshot .50, Frag Grenade).
@export var ignores_cover: bool = false

@export_group("Blast (Frag Grenade, R31-R35)")
## Damage of the shot resolved against every player in the chosen area (0 = no blast).
@export_range(0, 9) var blast_dmg: int = 0
## How far the blast area may be (Frag: 1). -1 when blast_dmg is 0.
@export_range(-1, 2) var blast_rng: int = NO_RANGE

@export_group("Attachment bonus (spec §6, R11-R13)")
## +DMG to the weapon (Red-dot Sight).
@export_range(0, 3) var attach_dmg: int = 0
## +RNG to the weapon, capped at RNG 2 (Long Scope).
@export_range(0, 2) var attach_rng: int = 0
## Extra shots per turn (Extended Mag).
@export_range(0, 2) var attach_extra_fire: int = 0
## Targets can't Brace with cards against this weapon (Suppressor).
@export var attach_no_brace: bool = false

@export_group("Text and art")
## Effect text as printed (keywords in plain text). One line, max 120.
@export var rules_text: String = ""
## Key the art kit (scripts/art) uses for this card. Defaults to the id when empty.
@export var art_key: StringName = &""


func is_weapon() -> bool:
	return type == DataEnums.CardType.WEAPON


func is_attachment() -> bool:
	return type == DataEnums.CardType.ATTACHMENT


func is_hit() -> bool:
	return type == DataEnums.CardType.HIT


func is_starter() -> bool:
	return rarity == DataEnums.Rarity.STARTER


## Loot: a card that sits in a pile or lands as a supply drop.
func is_loot() -> bool:
	return DataEnums.is_loot_rarity(rarity)


func has_attach_bonus() -> bool:
	return attach_dmg > 0 or attach_rng > 0 or attach_extra_fire > 0 or attach_no_brace


func has_play_effect() -> bool:
	return move > 0 or search > 0 or heal > 0 or pull > 0 or blast_dmg > 0


func rarity_letter() -> String:
	return DataEnums.rarity_letter(rarity)


func art_key_or_id() -> StringName:
	return art_key if not String(art_key).is_empty() else id


## Compact dictionary for UI mocks and logs.
func to_dict() -> Dictionary:
	return {
		"id": id, "code": code, "name": display_name,
		"type": StringName(DataEnums.key_of(DataEnums.CardType, type).to_lower()),
		"rarity": rarity_letter(), "starter": is_starter(), "cost": cost, "supply_drop": supply_drop,
		"brace": brace, "move": move, "search": search, "heal": heal, "pull": pull,
		"dmg": dmg, "rng": rng, "fires": fires_per_turn, "ignores_cover": ignores_cover,
		"text": rules_text, "art_key": art_key_or_id(),
	}


func validate(v: DataValidator) -> void:
	v.require_id(id)
	if code.is_empty():
		v.missing("code", "code is empty (printed number, e.g. CZ-014)")
	elif RegEx.create_from_string("^CZ-[0-9]{3}$").search(code) == null:
		v.invalid("code", "'%s' must look like CZ-014" % code)
	v.require_text("display_name", display_name)
	v.check_line("display_name", display_name, 24)
	v.check_line("rules_text", rules_text, 120)
	var type_ok: bool = v.check_enum("type", type, DataEnums.CardType)
	var rarity_ok: bool = v.check_enum("rarity", rarity, DataEnums.Rarity)
	for field: String in ["brace", "move", "search", "heal", "pull", "dmg", "blast_dmg"]:
		v.check_range(field, get(field), 0, 9)
	v.check_enum("spent", spent, DataEnums.SpentMode)
	if spent == DataEnums.SpentMode.ON_BRACE and brace <= 0:
		v.invalid("spent", "ON_BRACE needs a Brace value")
	if not type_ok or not rarity_ok:
		return
	_validate_rarity_and_cost(v)
	_validate_weapon_fields(v)
	_validate_blast(v)
	_validate_attachment_fields(v)
	match type:
		DataEnums.CardType.ITEM:
			if not has_play_effect() and brace == 0:
				v.missing("move", "an item needs an effect: Move, Search, Heal, Pull, a blast or Brace")
		DataEnums.CardType.HIT, DataEnums.CardType.MARKER:
			for field: String in ["brace", "move", "search", "heal", "pull"]:
				v.require_zero(field, get(field), "the Hit and the Bounty work through rules, not printed values")
			if spent != DataEnums.SpentMode.NONE:
				v.invalid("spent", "the Hit and the Bounty are never Spent")
	if type != DataEnums.CardType.HIT:
		v.require_text("rules_text", rules_text)


func _validate_rarity_and_cost(v: DataValidator) -> void:
	var no_chip: bool = type == DataEnums.CardType.HIT or type == DataEnums.CardType.MARKER
	if no_chip != (rarity == DataEnums.Rarity.NONE):
		v.invalid("rarity", "rarity NONE is for the Hit and the Bounty only (type %s, rarity %s)"
				% [DataEnums.key_of(DataEnums.CardType, type), DataEnums.key_of(DataEnums.Rarity, rarity)])
	if supply_drop:
		if not is_loot():
			v.invalid("supply_drop", "a supply drop needs a loot rarity (C, U, R, E, L)")
		v.require_zero("cost", cost, "a supply drop costs BalanceConfig.supply_drop_cost")
	elif is_loot():
		v.check_range("cost", cost, 1, DataEnums.MAX_COST)
	else:
		v.require_zero("cost", cost, "starters, the Hit and the Bounty are never looted")


func _validate_weapon_fields(v: DataValidator) -> void:
	if is_weapon():
		if dmg <= 0:
			v.missing("dmg", "a weapon needs DMG 1 or more")
		if rng == NO_RANGE:
			v.missing("rng", "a weapon needs RNG (0 same area, 1 adjacent, 2 anywhere)")
		else:
			v.check_range("rng", rng, 0, DataEnums.MAX_RANGE)
		v.check_range("fires_per_turn", fires_per_turn, 1, 3)
		return
	if dmg != 0:
		v.invalid("dmg", "only weapons have DMG (use blast_dmg for a grenade)")
	if rng != NO_RANGE:
		v.invalid("rng", "only weapons have RNG; leave it at -1")
	if fires_per_turn != 1:
		v.invalid("fires_per_turn", "only weapons fire")
	if ignores_cover and blast_dmg == 0:
		v.invalid("ignores_cover", "only weapons and blasts deal damage")


func _validate_blast(v: DataValidator) -> void:
	if blast_dmg > 0:
		if is_weapon():
			v.invalid("blast_dmg", "a weapon shoots; a blast is an item (Frag Grenade)")
		if blast_rng == NO_RANGE:
			v.missing("blast_rng", "a blast needs a range (Frag: 1)")
		else:
			v.check_range("blast_rng", blast_rng, 0, DataEnums.MAX_RANGE)
	elif blast_rng != NO_RANGE:
		v.invalid("blast_rng", "blast_rng is set but blast_dmg is 0")


func _validate_attachment_fields(v: DataValidator) -> void:
	v.check_range("attach_dmg", attach_dmg, 0, 3)
	v.check_range("attach_rng", attach_rng, 0, DataEnums.MAX_RANGE)
	v.check_range("attach_extra_fire", attach_extra_fire, 0, 2)
	if is_attachment():
		if not has_attach_bonus():
			v.missing("attach_dmg", "an attachment needs a bonus: attach_dmg, attach_rng, attach_extra_fire or attach_no_brace")
		if has_play_effect():
			v.invalid("move", "an attachment has no play effect (R14)")
	elif has_attach_bonus():
		v.invalid("attach_dmg", "only attachments carry attach bonuses")
