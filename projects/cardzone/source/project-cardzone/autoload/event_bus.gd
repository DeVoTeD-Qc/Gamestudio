# event_bus.gd
# Pattern adapted from CallingCard autoload/event_bus.gd; the signal list is new for CardZone.
# Purpose: EventBus autoload. The single place where gameplay signals are declared.
#   Rules code emits; UI, game feel and PlaytestLog listen. No logic lives here.
#   cz03 declares the starting contract (plan section 9) so UI/UX and Game Feel can build on mock
#   state; cz07 (rules), cz11-cz13 (UI) and cz18 (logger) extend it as they land.
# Conventions: ids are StringName; `seat` is an int (0 or 1); rich payloads use Dictionary until
#   cz05 / cz07's data classes (RulesEvent) land.
# Dependencies: none.
# Author: Mechanics Developer Agent
extends Node

# --- Screens -----------------------------------------------------------------
## A screen became visible (screen id, e.g. &"title", &"match", &"match_end").
signal screen_shown(screen_id: StringName)

# --- Match flow --------------------------------------------------------------
## opponent is &"rookie", &"veteran" or &"hotseat".
signal match_started(opponent: StringName, first_seat: int)
signal round_started(round_index: int)
signal turn_started(seat: int, turn_index: int)
## One engine event in play order (cz07 RulesEvent as a Dictionary: {type, seat, ...}).
signal rules_event(event: Dictionary)
## A shot was resolved after Cover, Down and Brace. hits is the damage taken.
signal shot_resolved(shooter: int, target: int, card_id: StringName, hits: int)
## The defender must choose Brace cards; incoming is the damage before bracing.
signal brace_requested(seat: int, incoming: int)
## winner is a seat or -1 for a draw; reason e.g. &"elimination", &"final_circle".
signal match_ended(winner: int, reason: StringName, rounds: int, duration_s: float)

# --- Playtest log (cz18) -------------------------------------------------------
# Additive: emitted for PlaytestLog (autoload/playtest_log.gd); anyone may listen.
## The match controller started or resumed a match. Only setup facts the human may know:
## {resumed: bool, mode: "ai"|"hotseat", ai_level, human_seat, first_seat, route ("A".."C"),
##  hand_size, tunables_hash, tunables: BalanceConfig.snapshot(), actions (logged so far),
##  round, age_s (resumed: seconds since the save, -1 when unknown)}.
signal match_context(info: Dictionary)
## The human's view (LoadoutRules.view(state, human)) after every applied action, emitted right
## before that action's events are announced through rules_event. Nothing the human can't see.
signal match_view_changed(view: Dictionary)
## The first-match coach showed a step (skipped = false) or the player skipped it (true).
## cz13's coach emits it; PlaytestLog logs coach_step.
signal coach_step(step: StringName, skipped: bool)
