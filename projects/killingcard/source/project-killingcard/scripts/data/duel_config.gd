# duel_config.gd
# Purpose: kc-duel-impl: every tunable number of Duel mode (duel-mode.md §2-§4; head D1-D5) in one
#   resource, data/duel/duel_config.tres (id duel_default). The economy itself is the campaign's
#   (data/run_config.tres); match_config() copies it and applies only the Duel overrides (deck size,
#   Zone Control target), so a campaign economy change reaches Duel without touching this file.
#   D4: there is NO hero stat table here. The heroes are the campaign's Operator files; the final
#   numbers are a data-only change to data/loadout/<hero>.tres.
# Dependencies: LoadoutItem, MapData, DuelDeck, RunConfig, DataEnums, DataValidator, SynergyRules.
# Author: Mechanics Developer Agent (kc-duel-impl)
class_name DuelConfig
extends Resource

@export var id: StringName = &"duel_default"
@export var display_name: String = "Duel"

@export_group("Deck rules (D2)")
## Exactly this many picks.
@export_range(1, 20) var picks: int = 10
## Copies per pick (always 2: the head's rule).
@export_range(1, 4) var copies_per_pick: int = 2
@export_range(0, 20) var min_unit_picks: int = 5
@export_range(0, 20) var max_elite_picks: int = 1
@export_range(0, 20) var max_field_picks: int = 3
## Saved player decks per profile (the 4 presets come on top).
@export_range(1, 32) var max_saved_decks: int = 8
@export_range(4, 40) var name_max_length: int = 20

@export_group("Advice lines (amber, never block)")
## "Round 1 gives 1 Supply": fewer than this many picks cost <= low_cost.
@export var low_curve_min_picks: int = 2
@export var low_cost: int = 1
## "Heavy curve": at least this many picks cost >= heavy_cost.
@export var heavy_curve_picks: int = 4
@export var heavy_cost: int = 4

@export_group("Match (same economy as the campaign)")
@export var game_mode: DataEnums.GameMode = DataEnums.GameMode.ZONE_CONTROL
@export_range(1, 20) var zone_control_target: int = 6
@export var map: MapData = null
## Both sides: the 3 starter killstreaks. No perks, attachments or weapon levels.
@export var killstreaks: Array[LoadoutItem] = []
## The heroes (Operators), picker order. D3: all always playable. D4: the campaign's own files.
@export var heroes: Array[LoadoutItem] = []
## Hero picker "Plays like" lines, hero id (String) -> line.
@export var hero_plays_like: Dictionary = {}
## The 4 presets (one per trait and hero), My Decks order.
@export var presets: Array[DuelDeck] = []

@export_group("Doctrine (D5)")
## The deck's doctrine_trait applies in Duel matches (SideSetup.doctrine).
@export var doctrine_enabled: bool = true
## A deck must pick a Doctrine trait (red "Pick a Doctrine trait").
@export var doctrine_required: bool = false
## The Doctrine trait must be worn by at least this many picks (0 = any trait; else red doctrine_rule).
@export_range(0, 10) var doctrine_min_trait_picks: int = 0

@export_group("AI tiers (duel-mode.md §4.1)")
## Recruit: Armor added to its units and Operator (shown as a green -1).
@export_range(-3, 3) var recruit_armor_bonus: int = -1
## Recruit plays its 2nd-best plan this often (casual personality, synergy-blind).
@export_range(0.0, 1.0) var recruit_second_best: float = 0.6
## Regular: the competent planner, synergy-blind, 2nd-best this often.
@export_range(0.0, 1.0) var regular_second_best: float = 0.6
## Veteran: the competent planner, synergy-aware, always its best plan.
@export_range(0.0, 1.0) var veteran_second_best: float = 0.0


func cards_per_deck() -> int:
	return picks * copies_per_pick


## The match RunConfig for a Duel: a copy of the campaign's `base` with the Duel overrides.
func match_config(base: RunConfig) -> RunConfig:
	var c: RunConfig = (base.duplicate(false) as RunConfig) if base != null else RunConfig.new()
	c.deck_size = cards_per_deck()
	c.zone_control_target = zone_control_target
	c.starter_killstreaks.assign(killstreaks)
	return c


func hero_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for h: LoadoutItem in heroes:
		if h != null:
			out.append(h.id)
	return out


func preset(p_id: StringName) -> DuelDeck:
	for d: DuelDeck in presets:
		if d != null and d.id == p_id:
			return d
	return null


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	v.check_range("picks", picks, 1, DuelDeck.MAX_PICKS)
	v.check_range("copies_per_pick", copies_per_pick, 1, 4)
	v.check_range("min_unit_picks", min_unit_picks, 0, picks)
	v.check_range("max_elite_picks", max_elite_picks, 0, picks)
	v.check_range("max_field_picks", max_field_picks, 0, picks)
	v.check_enum("game_mode", game_mode, DataEnums.GameMode)
	v.check_ref("map", map, MapData, true)
	v.check_slot_array("killstreaks", killstreaks, DataEnums.LoadoutSlot.KILLSTREAK, 0, 5)
	v.check_slot_array("heroes", heroes, DataEnums.LoadoutSlot.PRIMARY, 1, 8)
	v.check_ref_array("presets", presets, DuelDeck, 0, 16)
	for i: int in presets.size():
		var d: DuelDeck = presets[i]
		if d != null and not d.preset:
			v.invalid("presets[%d]" % i, "'%s' must have preset = true" % d.id)
		if d != null and d.hero_id not in hero_ids():
			v.invalid("presets[%d]" % i, "'%s' uses hero '%s', which is not in heroes" % [d.id, d.hero_id])
