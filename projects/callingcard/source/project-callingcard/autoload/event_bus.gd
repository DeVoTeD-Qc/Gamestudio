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

# --- Lobby Duel ----------------------------------------------------------------
signal lobby_wait_started(wait_s: float)
## choice is &"keep" or &"save".
signal lobby_match_found(choice: StringName)
signal duel_resumed(age_s: float)
