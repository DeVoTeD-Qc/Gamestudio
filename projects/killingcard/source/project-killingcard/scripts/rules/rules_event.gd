# rules_event.gd
# Purpose: Event vocabulary of the rules engine. The engine never talks to nodes:
#   every state change is appended to MatchState.events as a Dictionary
#   {type: StringName, round: int, ...fields}. Scenes translate these into EventBus
#   signals and animations; the AI / outcome preview can read them directly.
#   Fields use EventBus conventions: side = &"player" / &"enemy",
#   zone = &"left" / &"mid" / &"right", units are referenced by integer uid.
#   Events with a `private_to` field (a side name) must only be shown to that side
#   (e.g. the enemy's face-down plays or draws).
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name RulesEvent
extends RefCounted

# --- Flow ----------------------------------------------------------------------
const MATCH_STARTED: StringName = &"match_started"
const ROUND_STARTED: StringName = &"round_started"            ## round
const PHASE_CHANGED: StringName = &"phase_changed"            ## phase
const INITIATIVE: StringName = &"initiative"                  ## side
const ROUND_ENDED: StringName = &"round_ended"                ## player_score, enemy_score
const MATCH_ENDED: StringName = &"match_ended"                ## result, winner, is_draw, reason, mode, rounds, overtime, player_score, enemy_score, target, player_eliminations, enemy_eliminations (ModeRules outcome)
const OVERTIME_STARTED: StringName = &"overtime_started"      ## player_score, enemy_score, last_round (round cap ended tied)

# --- Cards / deck ----------------------------------------------------------------
const SUPPLY_GAINED: StringName = &"supply_gained"            ## side, supply
const CARD_DRAWN: StringName = &"card_drawn"                  ## side, card_uid, card_id (private)
const CARD_BURNED: StringName = &"card_burned"                ## side, card_uid, card_id: drawn with a full hand -> discarded
const DECK_RESHUFFLED: StringName = &"deck_reshuffled"        ## side, count
const MULLIGAN: StringName = &"mulligan"                      ## side, count
const CARD_PLAYED: StringName = &"card_played"                ## side, card_uid, card_id, zone (private: face-down)
const ITEM_USED: StringName = &"item_used"                    ## side, item_id, zone (private until Reveal)
const PLAY_UNDONE: StringName = &"play_undone"                ## side, order (private)
const CARD_REVEALED: StringName = &"card_revealed"            ## side, card_uid, card_id, zone
const ITEM_REVEALED: StringName = &"item_revealed"            ## side, item_id, zone
const CARD_DISCARDED: StringName = &"card_discarded"          ## side, card_uid, card_id

# --- Board ---------------------------------------------------------------------
const UNIT_ARRIVED: StringName = &"unit_arrived"              ## side, uid, card_id, zone, index
const UNIT_MOVED: StringName = &"unit_moved"                  ## side, uid, from_zone, zone
const OPERATOR_PLACED: StringName = &"operator_placed"        ## side, uid, zone
const OPERATOR_ROTATED: StringName = &"operator_rotated"      ## side, uid, from_zone, zone
const EQUIPMENT_PLACED: StringName = &"equipment_placed"      ## side, card_uid, card_id, zone, hidden
const EQUIPMENT_TRIGGERED: StringName = &"equipment_triggered" ## side, card_uid, card_id, zone, target_uid
const EQUIPMENT_DESTROYED: StringName = &"equipment_destroyed" ## side, card_uid, card_id, zone
const RED_DOTS_REVEALED: StringName = &"red_dots_revealed"    ## side (viewer), zone, card_ids (private)

# --- Effects / combat -------------------------------------------------------------
const EFFECT_APPLIED: StringName = &"effect_applied"          ## side, source_id, kind, target_uid, amount
const EFFECT_WASTED: StringName = &"effect_wasted"            ## side, source_id, kind, reason
const FIREFIGHT_STARTED: StringName = &"firefight_started"    ## zone
const FIREFIGHT_STEP: StringName = &"firefight_step"          ## zone, step (&"first_shot" / &"main")
const SUPPRESSED: StringName = &"suppressed"                  ## side (suppressor's), uid (shooter), target_uid, amount
const SHOT_FIRED: StringName = &"shot_fired"                  ## side, shooter_uid, target_uid (-1 = wasted), zone, damage, step
const DAMAGE_DEALT: StringName = &"damage_dealt"              ## target_uid, side (target's), amount, remaining, source_id
const SURVIVED_LETHAL: StringName = &"survived_lethal"        ## side, uid, armor
const UNIT_ELIMINATED: StringName = &"unit_eliminated"        ## victim_uid, victim_side, by_uid, by_side, zone, source_kind, by_killstreak, credit
const OPERATOR_DOWN: StringName = &"operator_down"            ## side, uid
const PATCHED: StringName = &"patched"                        ## side, uid (medic), target_uid, amount

# --- Score -----------------------------------------------------------------------
const ZONE_CONTROL: StringName = &"zone_control"              ## zone, owner (&"player" / &"enemy" / &"contested" / &"empty")
const MODE_SCORED: StringName = &"mode_scored"                ## mode, player_gained, enemy_gained, player_score, enemy_score, target
const STREAK_CHANGED: StringName = &"streak_changed"          ## side, streak, before, gained, reset, earned
const KILLSTREAK_EARNED: StringName = &"killstreak_earned"    ## side, item_id, streak, threshold (into the Streak Tray)

# --- Loadout (p05) -------------------------------------------------------------------
const ITEM_READY: StringName = &"item_ready"                  ## side, item_id: cooldown reached 0 at Briefing
const PERK_TRIGGERED: StringName = &"perk_triggered"          ## side, item_id (Field Salvage ...)
const CARD_RETURNED: StringName = &"card_returned"            ## side, card_uid, card_id, zone, reason: zone still full at Reveal


static func make(type: StringName, round_number: int, fields: Dictionary = {}) -> Dictionary:
	var event: Dictionary = {"type": type, "round": round_number}
	event.merge(fields)
	return event
