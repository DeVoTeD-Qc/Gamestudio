# event_bus.gd
# Purpose: EventBus autoload. The single place where gameplay signals are declared.
#   Rules code emits, UI / game feel / PlaytestLog listen. No logic lives here.
# Dependencies: none.
# Author: Mechanics Developer Agent
#
# Conventions: ids are StringName; `side` is &"player" or &"enemy";
# `zone` is &"left", &"mid" or &"right"; rich payloads use Dictionary until the
# typed data classes land in p02/p04.
extends Node

# --- Run flow -------------------------------------------------------------
## A new run started (loadout and killstreak picks are in RunState).
signal run_started(seed_value: int)
## The run ended. result is &"win" or &"loss".
signal run_ended(result: StringName, matches_played: int, duration_s: float)
## Remaining tickets changed.
signal tickets_changed(tickets: int)

# --- Match flow -----------------------------------------------------------
signal match_started(mode: StringName, map_id: StringName, match_index: int)
## result is &"win", &"loss" or &"draw".
signal match_ended(result: StringName, rounds: int, duration_s: float)
signal round_started(round_number: int)
## phase is one of &"briefing", &"deploy", &"reveal", &"firefight", &"score".
signal phase_changed(phase: StringName)
signal round_ended(round_number: int, player_score: int, enemy_score: int)
signal score_changed(player_score: int, enemy_score: int)
## The player's end-of-round numbers for the playtest log (p16). Emit it just before
## round_ended so the log can put them on the same round_end line.
signal round_summary(round_number: int, supply_unspent: int, hand_size: int)
## Which side acts first this round.
signal initiative_changed(side: StringName)

# --- Cards and deployment ---------------------------------------------------
signal card_drawn(card_id: StringName)
signal card_deployed(side: StringName, card_id: StringName, zone: StringName)
## Simultaneous reveal: one emission per revealed card.
signal card_revealed(side: StringName, card_id: StringName, zone: StringName)
## Red-dot intel: number of enemy units committed to a zone before deployment.
signal intel_updated(zone: StringName, enemy_count: int)

# --- Firefight ------------------------------------------------------------
signal shot_fired(shooter_uid: int, target_uid: int, zone: StringName)
signal damage_dealt(target_uid: int, amount: int, remaining_hp: int)
## by_killstreak is true when a killstreak scored it (does not add to the streak).
signal unit_eliminated(victim_uid: int, by_uid: int, zone: StringName, by_killstreak: bool)
signal operator_down(side: StringName, round_number: int)
signal operator_respawned(side: StringName)

# --- Streaks, killstreaks, abilities --------------------------------------------
signal streak_changed(streak: int)
signal killstreak_earned(killstreak_id: StringName, round_number: int)
signal killstreak_used(killstreak_id: StringName, round_number: int)
signal ability_used(ability_id: StringName, zone: StringName)

# --- Rewards --------------------------------------------------------------
signal reward_offered(kind: StringName, offered_ids: Array[StringName])
signal reward_picked(kind: StringName, chosen_id: StringName)

# --- UI / meta --------------------------------------------------------------
signal preview_toggled(enabled: bool)
signal tutorial_step(step: int)
## The player asked for the next match on the after-action screen (p16: "one more match" KPI).
signal next_match_requested
## A screen or overlay became the one the player sees, e.g. &"reward_pick" (p16: quit(screen)).
## Full scene changes are also picked up from SceneRouter.scene_change_finished.
signal screen_shown(screen: StringName)
