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
## kc-art-traits (art-traits.md §2): the trait each copy's art gives it, parallel to `deck`
## (SynergyRules.TRAIT_DEFAULT or a missing entry = the chassis' default trait; &"" = a plain art).
## Resolved by the run / UI layer (ArtTraits.trait_of); the rules only check it against the option list.
## kc-no-training: exactly one entry (one trait at most) per copy.
var deck_traits: Array[StringName] = []
## kc-syn §5.2 Doctrine: this trait's set count is +1 while the side has a member in play (&"" = none).
var doctrine: StringName = &""
## kc-duel-impl (duel-mode.md §12.3): the Duel Doctrine only starts a set (+1 while exactly one member
## is in play). DuelRules.side_setup sets it; the campaign keeps false (+1 while any member is in play).
var doctrine_starts_only: bool = false
## Defines the Operator (class, FP, Armor, keywords). Null = no Operator (tests only).
var primary: LoadoutItem = null
var attachments: Array[LoadoutItem] = []
var perks: Array[LoadoutItem] = []
var killstreaks: Array[LoadoutItem] = []
## Added to every unit and the Operator of this side (Bracket 2: enemy +0 FP / +1 Armor).
var firepower_bonus: int = 0
var armor_bonus: int = 0
## Tests: skip the shuffle and draw the deck in list order (deck[0] is drawn first).
var keep_deck_order: bool = false
## kc-v2-impl (run-v2.md §7): the Primary's kit is on: its passive (Pierce, opening hand) and its
## once-per-match ability. Off by default (enemies, quick matches, the first run's F1, old tests).
var operator_kit: bool = false
## kc-v2-tune: false = the kit's opening-hand bonus is held back this match (Kestrel in F1).
var opening_hand_bonus_on: bool = true


## Enemy side from a squad and the match's scaling.
static func from_squad(squad: SquadData, match_data: RunMatchData = null) -> SideSetup:
	var s: SideSetup = SideSetup.new()
	s.display_name = squad.display_name
	s.deck = match_data.deck_for_squad() if match_data != null else squad.deck.duplicate()
	s.deck = s.deck.duplicate()
	s.primary = squad.primary
	s.attachments = squad.attachments.duplicate()
	s.perks = squad.perks.duplicate()
	s.killstreaks = squad.killstreaks.duplicate()
	if match_data != null:
		s.firepower_bonus = match_data.enemy_firepower_bonus
		s.armor_bonus = match_data.enemy_armor_bonus
	# kc-art-traits §7 (head T4): the squad's fixed art identity.
	s.deck_traits = identity_traits(s.deck, squad.identity_trait)
	return s


## kc-art-traits §7: per-copy traits of a squad deck with art identity `identity`: every copy whose
## options include it carries it; the rest go to the trait most of them can share (TRAITS order on a
## tie); copies that fit neither keep their default. &"" identity = every copy on its default.
static func identity_traits(deck: Array[CardData], identity: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: CardData in deck:
		out.append(SynergyRules.TRAIT_DEFAULT)
	if identity == &"":
		return out
	var rest: Array[int] = []
	for i: int in deck.size():
		var c: CardData = deck[i]
		if c == null or not c.has_trait_choice():
			continue
		if c.can_carry(identity):
			out[i] = identity
		else:
			rest.append(i)
	var best: StringName = &""
	var best_n: int = 0
	for t: StringName in SynergyRules.TRAITS:
		var cnt: int = 0
		for i: int in rest:
			if deck[i].can_carry(t):
				cnt += 1
		if t != identity and cnt > best_n:
			best_n = cnt
			best = t
	if best != &"":
		for i: int in rest:
			if deck[i].can_carry(best):
				out[i] = best
	return out


## Chosen trait of deck entry i (TRAIT_DEFAULT when deck_traits has no entry for it).
func trait_of(i: int) -> StringName:
	return deck_traits[i] if i >= 0 and i < deck_traits.size() else SynergyRules.TRAIT_DEFAULT

