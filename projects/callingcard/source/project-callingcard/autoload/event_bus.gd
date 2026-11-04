# event_bus.gd
# Pattern adapted from Killstreak autoload/event_bus.gd; the signal list is new for Banner Wall.
# Purpose: EventBus autoload. The single place where gameplay signals are declared.
#   Rules code emits; UI, game feel and PlaytestLog listen. No logic lives here.
#   cc01 declares the contract below so UI/UX and Game Feel can build on mock state;
#   cc05 (rules), cc09 (collection), cc13 (entry points) and cc16 (logger) emit/listen.
# Conventions: ids are StringName; `side` is &"player" or &"rival"; `slot` is a wall slot id
#   (StringName, a1–a3 / b1–b4 / c1–c3, top/middle/bottom rows); rich payloads use Dictionary until cc02's data classes land.
# Dependencies: none.
# Author: Mechanics Developer Agent
extends Node

# --- Screens -----------------------------------------------------------------
## A screen became visible (screen id, e.g. &"title", &"hub", &"album").
signal screen_shown(screen_id: StringName)

# --- Duel flow ---------------------------------------------------------------
## source is &"lobby", &"rival" or &"dossier"; first_player is a side.
signal duel_started(source: StringName, rival_id: StringName, first_player: StringName)
signal turn_started(side: StringName, turn_index: int)
## A card was placed. captures lists the slots that flipped.
signal card_placed(side: StringName, card_id: StringName, slot: StringName, captures: Array)
## One card changed owner (emitted once per flip, after card_placed).
signal card_captured(by_side: StringName, card_id: StringName, slot: StringName)
## An Ambush card was revealed.
signal ambush_sprung(side: StringName, card_id: StringName, slot: StringName)
## A card went back to its own lineup's player through Reclaim (engine event "reclaimed": slot,
## player, card_id). by_side is the Reclaim player. Emitted once per card, after card_placed.
## Not a capture: Collection's capture count ignores it.
signal card_reclaimed(by_side: StringName, card_id: StringName, slot: StringName)
## The placed card got Set Link (cc15 light): linked lists the same-set slots it touched.
## Emitted right after card_placed, before the captures.
signal set_linked(side: StringName, slot: StringName, linked: Array)
## A Signature card was captured ("Carded!"). by_side is the captor.
signal carded(by_side: StringName, card_id: StringName)
signal triptych_scored(side: StringName, triptych_id: StringName, first_time: bool)
signal score_changed(player_score: int, rival_score: int)
## result is &"win", &"loss" or &"draw".
signal duel_ended(result: StringName, player_score: int, rival_score: int, turns: int, duration_s: float)

# --- Collection and album ----------------------------------------------------
signal album_opened(page_id: StringName)
signal card_inspected(card_id: StringName, owned: bool)
signal lineup_saved(card_ids: Array, clearance: int, signature_id: StringName, loaner: bool)
## kind is &"card", &"title" or &"frame".
signal unlocked(kind: StringName, item_id: StringName)
signal set_completed(set_id: StringName)
signal cipher_attempted(correct: bool)
signal dossier_started(dossier_id: StringName)
signal dossier_cleared(dossier_id: StringName, attempts: int, duration_s: float)
## A Dossier's goal was met (cc12). Same effect as dossier_cleared for Collection; emit either one
## (or call Collection.complete_dossier()); a second report of the same clear grants nothing twice.
signal dossier_completed(dossier_id: StringName)

# --- Lobby Duel ----------------------------------------------------------------
signal lobby_wait_started(wait_s: float)
## choice is &"keep" or &"save".
signal lobby_match_found(choice: StringName)
signal duel_resumed(age_s: float)

# --- Collection progress and save (cc09) ---------------------------------------
# Duel code emits duel_lineup_locked; Collection emits everything else in this block.
## The player's lineup for the duel that just started (emit right after duel_started).
## Collection uses it for "no Legend in your lineup" goals and the Lobby Duel save.
signal duel_lineup_locked(card_ids: Array, signature_id: StringName, loaner: bool)
## A locked card became owned. source_id is the UnlockGoal id or the Dossier id that granted it.
signal card_unlocked(card_id: StringName, source_id: StringName)
## A cosmetic title was earned. title_id is stable (e.g. &"set_night_shift"); text is what the UI shows.
signal title_earned(title_id: StringName, text: String)
## A cosmetic frame was earned (e.g. &"set_frame_night_shift", &"gold_cipher").
signal frame_earned(frame_id: StringName)
## Progress toward an unlock goal changed (result screen "1/3", album meters). Not emitted once done.
signal unlock_progress(goal_id: StringName, current: int, target: int)
## An unlock goal was met (card_unlocked follows for the card(s) it unlocks).
signal unlock_goal_completed(goal_id: StringName)
## The player scored a Triptych for the first time: reveal the panorama.
signal triptych_revealed(triptych_id: StringName)
## The Cipher Lock was opened with the right code (after cipher_attempted(true)).
signal cipher_solved()
## Any Collection state changed; screens that show the collection refresh.
signal collection_changed()
## The saved Lobby Duel was written (saved = true) or removed (saved = false).
signal lobby_duel_saved(saved: bool)
## "Reset demo" wiped the collection back to the demo start.
signal collection_reset()
