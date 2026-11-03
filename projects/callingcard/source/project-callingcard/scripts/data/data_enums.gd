# data_enums.gd
# Pattern adapted from Killstreak scripts/data/data_enums.gd; the enums are new for Banner Wall.
# Purpose: Shared enums and fixed tables for every Banner Wall data Resource (spec §3, §4.4, §5, §7, §9).
#   Values are stored as ints in .tres files, so ONLY APPEND new values at the end
#   of an enum; never reorder or remove, or existing data changes meaning.
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name DataEnums
extends RefCounted

## How a card was earned (spec §3). Sets the card's trait (see TRAIT_BY_ORIGIN).
enum Origin { CHALLENGE, MASTERY, EVENT, PRESTIGE, RANKED, SECRET, SHOWCASE }

## Card trait (spec §4.4). NONE = Showcase (store) cards. Derived from Origin, never stored.
enum CardTrait { NONE, STEADY, VETERAN, AMBUSH, RECLAIM, CLUTCH, CIPHER }

## Kind of set (album page). SHOWCASE holds store cards only; CIPHER holds the Secret cards.
enum SetKind { STANDARD, CIPHER, SHOWCASE }

## Rival AI level (spec §7).
enum Difficulty { EASY, NORMAL, HARD }

## Who wins a tied score (spec §4.5, §9).
enum TieWinner { FIRST_PLAYER, DRAW }

## What an unlock goal counts (spec §6 "Demo start", plan cc09).
enum UnlockKind {
	WIN_STREAK,           ## Win target_count duels in a row.
	CAPTURES_TOTAL,       ## Capture target_count cards in total.
	WINS_TOTAL,           ## Win target_count duels in total.
	BEAT_RIVAL,           ## Beat the rival named by target_id.
	BEAT_RIVAL_NO_LEGEND, ## Beat the rival target_id with no Clearance 4 card in your lineup.
	DOSSIER_CLEAR,        ## Clear the Dossier named by target_id.
	CIPHER_LOCK,          ## Solve the album's Cipher Lock.
}

## Dossier goal (spec §5.2). goal_count meaning is listed in data/README.md.
enum DossierGoal {
	CAPTURE_N,               ## Capture goal_count cards within max_placements placements.
	WIN_IN_PLACEMENTS,       ## Win using exactly max_placements placements.
	CAPTURE_N_WITH_SPRING,   ## Capture goal_count cards with one Ambush spring.
	CAPTURE_SIGNATURE_AND_WIN, ## Capture the rival Signature and win.
	WIN_BY_COPYING_TRAIT,    ## Win after a Cipher copies a rival card's trait.
}

## Owner of a pre-placed card in a Dossier.
enum Side { PLAYER, RIVAL }

## Origin -> trait (spec §4.4). Indexed by Origin.
const TRAIT_BY_ORIGIN: Array[CardTrait] = [
	CardTrait.STEADY, CardTrait.VETERAN, CardTrait.AMBUSH, CardTrait.RECLAIM,
	CardTrait.CLUTCH, CardTrait.CIPHER, CardTrait.NONE,
]

## Clearance tier names (spec §3). Index = Clearance (0 unused).
const CLEARANCE_NAMES: PackedStringArray = ["", "Issue", "Merit", "Distinction", "Legend"]
const MIN_CLEARANCE: int = 1
const MAX_CLEARANCE: int = 4
## Clearance of a Legend (lineups may hold at most BalanceConfig.max_legends of them).
const LEGEND_CLEARANCE: int = 4

## Rule text shown on the card (spec §4.4). Indexed by CardTrait.
const TRAIT_TEXT: PackedStringArray = [
	"Premium animated frame. Clearance 1.",
	"Can't be captured by a card with lower Clearance.",
	"Also captures on ties.",
	"Placed face-down: it captures nothing and can't be captured. At the start of your next turn it flips face-up and captures with +1 to all values. If the wall fills first, it flips before scoring.",
	"On placement, takes back every adjacent card from your own lineup, whatever the values.",
	"If you're behind on score when you place it, +2 to all values for this placement.",
	"On placement, copies the trait of one adjacent card (your pick).",
]


static func trait_for_origin(origin: Origin) -> CardTrait:
	if origin < 0 or origin >= TRAIT_BY_ORIGIN.size():
		return CardTrait.NONE
	return TRAIT_BY_ORIGIN[origin]


static func clearance_name(clearance: int) -> String:
	if clearance < MIN_CLEARANCE or clearance > MAX_CLEARANCE:
		return "?"
	return CLEARANCE_NAMES[clearance]


## Enum key for a value, for readable validation messages ("CHALLENGE" or "<9?>").
static func key_of(enum_dict: Dictionary, value: int) -> String:
	var key: Variant = enum_dict.find_key(value)
	return String(key) if key != null else "<%d?>" % value
