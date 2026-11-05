# side_setup.gd
# Purpose: Everything one side brings into a match: deck, Operator loadout, perks,
#   killstreaks and stat scaling. Built from RunState (player) or SquadData (enemy),
#   or by hand in tests. Plain data; MatchState copies what it needs.
# Dependencies: CardData, LoadoutItem, SquadData.
# Author: Mechanics Developer Agent
class_name SideSetup
extends RefCounted

var display_name: String = ""
var deck: Array[CardData] = []
## Display only (card-system §4.6, kc-cod2): one banner art id per deck entry, parallel to `deck`
## (&"" or missing = the chassis' default art). MatchState copies it into art_by_uid; rules never read it.
var deck_arts: Array[StringName] = []
## kc-syn §5.2: per-copy level, parallel to `deck` (SynergyRules.LEVEL_*: 0 Recruit, 1 Trained,
## 2 Veteran, 3 Elite). A missing entry = Trained (the full chassis).
var deck_levels: Array[int] = []
## kc-syn §5.2 Doctrine: this trait's set count is +1 while the side has a member in play (&"" = none).
var doctrine: StringName = &""
## Defines the Operator (class, FP, Armor, keywords). Null = no Operator (tests only).
var primary: LoadoutItem = null
var attachments: Array[LoadoutItem] = []
var secondary: LoadoutItem = null
var lethal: LoadoutItem = null
var tactical: LoadoutItem = null
var perks: Array[LoadoutItem] = []
var killstreaks: Array[LoadoutItem] = []
## Added to every unit and the Operator of this side (Bracket 2: enemy +0 FP / +1 Armor).
var firepower_bonus: int = 0
var armor_bonus: int = 0
## Tests: skip the shuffle and draw the deck in list order (deck[0] is drawn first).
var keep_deck_order: bool = false


## Enemy side from a squad and the match's scaling.
static func from_squad(squad: SquadData, match_data: RunMatchData = null) -> SideSetup:
	var s: SideSetup = SideSetup.new()
	s.display_name = squad.display_name
	s.deck = squad.deck.duplicate()
	s.primary = squad.primary
	s.attachments = squad.attachments.duplicate()
	s.secondary = squad.secondary
	s.lethal = squad.lethal
	s.tactical = squad.tactical
	s.perks = squad.perks.duplicate()
	s.killstreaks = squad.killstreaks.duplicate()
	if match_data != null:
		s.firepower_bonus = match_data.enemy_firepower_bonus
		s.armor_bonus = match_data.enemy_armor_bonus
		# kc-syn §5.1: Bracket-1 squads play Recruit copies of their units (Fields stay Trained).
		if match_data.enemy_recruits:
			for c: CardData in s.deck:
				s.deck_levels.append(SynergyRules.LEVEL_RECRUIT if c != null and c.is_unit() else SynergyRules.LEVEL_TRAINED)
	return s


## Level of deck entry i (Trained when deck_levels has no entry for it).
func level_of(i: int) -> int:
	return clampi(deck_levels[i], SynergyRules.LEVEL_RECRUIT, SynergyRules.LEVEL_MAX) \
			if i >= 0 and i < deck_levels.size() else SynergyRules.LEVEL_TRAINED
