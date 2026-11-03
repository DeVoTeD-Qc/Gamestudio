# card_data.gd
# Pattern adapted from Killstreak scripts/data/card_data.gd; the fields are new for Banner Wall.
# Purpose: One calling card (spec §3, §6): Top / Side / Bottom values, Clearance tier, origin
#   (which sets the trait), set, Signature eligibility, store flag, art key, cipher glyph and
#   demo ownership / unlock goal. One card = one .tres in res://data/cards/.
#   Rules that need the whole data set (set sizes, unique glyphs) live in CardDB's cross checks.
# Dependencies: DataEnums, SetData, UnlockGoal, BalanceConfig (via DataValidator), DataValidator.
# Author: Mechanics Developer Agent
class_name CardData
extends Resource

@export_group("Identity")
## Unique id, lowercase snake_case (e.g. graveyard_shift). Used by saves, logs and lineups.
@export var id: StringName = &""
@export var display_name: String = ""
## Set (album page). Same-set neighbors get Set Link.
@export var card_set: SetData = null
## Position on the set's album page, 1 = first. Unique within the set.
@export_range(1, 10) var album_order: int = 0

@export_group("Values (spec §3)")
## Faces the cards above. 1-9.
@export_range(1, 9) var top: int = 0
## Faces the left and right neighbors. 1-9.
@export_range(1, 9) var side: int = 0
## Faces the cards below. 1-9.
@export_range(1, 9) var bottom: int = 0
## 1 Issue, 2 Merit, 3 Distinction, 4 Legend. top + side + bottom must equal its stat budget (13/15/17/19).
@export_range(1, 4) var clearance: int = 0

@export_group("Origin and trait (spec §4.4)")
## How it was earned. Sets the trait: Challenge Steady, Mastery Veteran, Event Ambush,
## Prestige Reclaim, Ranked Clutch, Secret Cipher, Showcase none.
@export var origin: DataEnums.Origin = DataEnums.Origin.CHALLENGE
## Store / bundle card. Must be origin SHOWCASE, Clearance 1, no trait (anti-pay-to-win rule).
@export var is_store: bool = false
## May be marked as a lineup's Signature.
@export var signature_eligible: bool = true

@export_group("Album text")
## "How it's earned" in the live game (original flavor), shown in the inspector and album.
@export var how_earned: String = ""

@export_group("Art")
## Key the art kit (scripts/art) uses to draw this card's poster.
@export var art_key: StringName = &""
## Seed for the procedural duotone poster.
@export var art_seed: int = 0
## Original art brief (for the art kit and later painted art). Not shown in game.
@export_multiline var art_brief: String = ""
## Cipher glyph hidden in the art: 0 none, 1-4 = glyph number (one card per main set).
@export_range(0, 4) var cipher_glyph: int = 0

@export_group("Demo collection (spec §7)")
## Owned when a new demo save starts.
@export var starts_owned: bool = false
## Required when starts_owned is off: what unlocks the card in the demo.
@export var unlock_goal: UnlockGoal = null


## The card's trait, from its origin (spec §4.4).
func card_trait() -> DataEnums.CardTrait:
	return DataEnums.trait_for_origin(origin)


func stat_total() -> int:
	return top + side + bottom


func is_legend() -> bool:
	return clearance >= DataEnums.LEGEND_CLEARANCE


func trait_text() -> String:
	return DataEnums.TRAIT_TEXT[card_trait()]


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	v.check_line("display_name", display_name, 24)
	v.check_ref("card_set", card_set, SetData, true)
	v.check_range("album_order", album_order, 1, 10)
	var b: BalanceConfig = v.balance
	for field: String in ["top", "side", "bottom"]:
		v.check_range(field, get(field), b.stat_min, b.stat_max)
	v.check_range("clearance", clearance, DataEnums.MIN_CLEARANCE, DataEnums.MAX_CLEARANCE)
	var origin_ok: bool = v.check_enum("origin", origin, DataEnums.Origin)
	# Stat budget (spec §3): T + S + B equals the Clearance budget.
	var budget: int = b.budget_for(clearance)
	if budget > 0 and stat_total() != budget:
		v.add(DataValidator.BUDGET_MISMATCH, "clearance",
				"T+S+B = %d+%d+%d = %d, but Clearance %d (%s) needs %d" % [
					top, side, bottom, stat_total(), clearance, DataEnums.clearance_name(clearance), budget])
	# Anti-pay-to-win (spec §3, decision 3): store cards are Clearance 1 with no trait.
	if is_store:
		if clearance != 1:
			v.add(DataValidator.STORE_RULE, "clearance", "store card at Clearance %d; store cards are always Clearance 1" % clearance)
		if origin_ok and origin != DataEnums.Origin.SHOWCASE:
			v.add(DataValidator.STORE_RULE, "origin",
					"store card with origin %s gets a trait; store cards must be origin SHOWCASE (no trait)" % DataEnums.key_of(DataEnums.Origin, origin))
	elif origin_ok and origin == DataEnums.Origin.SHOWCASE:
		v.add(DataValidator.STORE_RULE, "is_store", "origin SHOWCASE is the store origin; set is_store on")
	if card_set != null and card_set is SetData:
		var showcase_set: bool = card_set.kind == DataEnums.SetKind.SHOWCASE
		if showcase_set != is_store:
			v.add(DataValidator.STORE_RULE, "card_set",
					"store cards go in SHOWCASE sets and only there ('%s' is %s)" % [card_set.id, DataEnums.key_of(DataEnums.SetKind, card_set.kind)])
		if cipher_glyph > 0 and card_set.kind != DataEnums.SetKind.STANDARD:
			v.invalid("cipher_glyph", "cipher glyphs go on cards of the main (STANDARD) sets")
	# Text and art.
	v.require_text("how_earned", how_earned)
	v.check_line("how_earned", how_earned, 80)
	if String(art_key).is_empty():
		v.missing("art_key", "art_key is empty (the art kit needs it)")
	v.check_range("cipher_glyph", cipher_glyph, 0, 4)
	# Ownership: owned at start XOR locked behind a goal.
	if starts_owned:
		if unlock_goal != null:
			v.invalid("unlock_goal", "card starts owned; remove the unlock goal or turn starts_owned off")
	else:
		v.check_ref("unlock_goal", unlock_goal, UnlockGoal, true)
