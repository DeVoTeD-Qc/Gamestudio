# squad_data.gd
# Purpose: An enemy squad (core-rules §7): fixed deck, loadout, AI personality and
#   AI scoring weights. One squad = one .tres in res://data/squads/.
# Dependencies: DataEnums, CardData, LoadoutItem, DataValidator.
# Author: Mechanics Developer Agent
class_name SquadData
extends Resource

const MIN_DECK: int = 15
const MAX_DECK: int = 20

@export_group("Identity")
## Unique id, lowercase snake_case (e.g. squad_rusher).
@export var id: StringName = &""
## Gamertag-style name shown in the HUD (e.g. "SandViper_07").
@export var display_name: String = ""
## Clan tag shown in brackets (e.g. "DSRT"), 2-5 characters, may be empty.
@export var clan_tag: String = ""
@export var personality: DataEnums.Personality = DataEnums.Personality.RUSHER

@export_group("Deck")
## 15-20 card references; add the same card several times for copies.
@export var deck: Array[CardData] = []

## kc-art-traits §7 (head T4): the squad's fixed art identity. Its deck is dressed in arts of this
## trait's family, so every copy that can carry the trait does; the rest go to the trait most of
## them share (SideSetup.identity_traits). &"" = every copy on its default trait. Recruit copies
## (Bracket 1) show no trait either way.
@export var identity_trait: StringName = &""

@export_group("Loadout")
@export var primary: LoadoutItem = null
## Attachments the squad's Operator already has (from primary.attachments).
@export var attachments: Array[LoadoutItem] = []
@export var perks: Array[LoadoutItem] = []
@export var killstreaks: Array[LoadoutItem] = []

@export_group("AI weights (core-rules §7)")
@export_range(0.0, 10.0) var weight_damage_dealt: float = 1.0
@export_range(0.0, 10.0) var weight_damage_taken: float = 1.0
@export_range(0.0, 10.0) var weight_zone_control: float = 2.0
@export_range(0.0, 10.0) var weight_deny_streak: float = 3.0
## Chance (0-1) of playing the second-best plan instead of the best.
@export_range(0.0, 1.0) var second_best_chance: float = 0.1
## Zone ranges this squad prefers (Rusher: CLOSE; Sniper Nest: LONG). Empty = no preference.
@export var preferred_ranges: Array[DataEnums.RangeTag] = []


func validate(v: DataValidator, perk_slots: int = 3, killstreak_slots: int = 3) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	v.check_enum("personality", personality, DataEnums.Personality)
	if clan_tag.length() > 5:
		v.out_of_range("clan_tag", "clan tag is %d characters (max 5)" % clan_tag.length())
	if v.check_ref_array("deck", deck, CardData, MIN_DECK, MAX_DECK):
		for i: int in deck.size():
			if deck[i] != null and deck[i].is_token():
				v.invalid("deck[%d]" % i, "'%s' is a token (collectible = false) and can't be in a deck" % deck[i].id)
	if identity_trait != &"" and identity_trait not in SynergyRules.TRAITS:
		v.invalid("identity_trait", "unknown trait '%s' (one of %s)" % [identity_trait, SynergyRules.TRAITS])
	v.check_slot_ref("primary", primary, DataEnums.LoadoutSlot.PRIMARY, true)
	v.check_slot_array("attachments", attachments, DataEnums.LoadoutSlot.ATTACHMENT, 0, 4)
	v.check_slot_array("perks", perks, DataEnums.LoadoutSlot.PERK, 0, perk_slots)
	v.check_slot_array("killstreaks", killstreaks, DataEnums.LoadoutSlot.KILLSTREAK, 0, killstreak_slots)
	if primary != null:
		for i: int in attachments.size():
			if attachments[i] != null and attachments[i] not in primary.attachments:
				v.invalid("attachments[%d]" % i, "'%s' is not in %s's attachment pool" % [attachments[i].id, primary.id])
	for f: String in ["weight_damage_dealt", "weight_damage_taken", "weight_zone_control", "weight_deny_streak"]:
		v.check_range_f(f, get(f), 0.0, 10.0)
	v.check_range_f("second_best_chance", second_best_chance, 0.0, 1.0)
	for i: int in preferred_ranges.size():
		v.check_enum("preferred_ranges[%d]" % i, preferred_ranges[i], DataEnums.RangeTag)
