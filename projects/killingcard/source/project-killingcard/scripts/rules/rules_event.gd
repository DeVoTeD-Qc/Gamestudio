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
## kc-wip-impl Agile: an Agile move order resolved at Reveal (UNIT_MOVED also fires) or fizzled (moved false).
const AGILE_MOVED: StringName = &"agile_moved"                ## side, uid, card_id, from_zone, zone, moved
# "Equipment" events are the Field events (Field = CardType.EQUIPMENT, kc-field-impl).
const EQUIPMENT_PLACED: StringName = &"equipment_placed"      ## side, card_uid, card_id, zone, hidden
const EQUIPMENT_TRIGGERED: StringName = &"equipment_triggered" ## side, card_uid, card_id, zone, target_uid
const EQUIPMENT_DESTROYED: StringName = &"equipment_destroyed" ## side, card_uid, card_id, zone, reason (FIELD_GONE_*)
## EQUIPMENT_DESTROYED reasons: an enemy effect (Sabotage), a newer Field of yours in the
## same column, or Overrun (the enemy controls the column at the end of the Score step).
const FIELD_GONE_DESTROYED: StringName = &"destroyed"
const FIELD_GONE_REPLACED: StringName = &"replaced"
const FIELD_GONE_OVERRUN: StringName = &"overrun"
const RED_DOTS_REVEALED: StringName = &"red_dots_revealed"    ## side (viewer), zone, card_ids (private)

# --- Effects / combat -------------------------------------------------------------
const EFFECT_APPLIED: StringName = &"effect_applied"          ## side, source_id, kind, target_uid, amount
const EFFECT_WASTED: StringName = &"effect_wasted"            ## side, source_id, kind, reason
const FIREFIGHT_STARTED: StringName = &"firefight_started"    ## zone
const FIREFIGHT_STEP: StringName = &"firefight_step"          ## (no longer emitted: the old First Shot / Main steps; kc-fight-impl uses FIREFIGHT_BEAT)
## kc-fight-impl (firefight-order.md, Implementation notes): one beat of a column. shooters = uids firing
## in it (1 or 2); exchange 0 = together, 1 = the First Shot half of a split, 2 = its partner's reply.
const FIREFIGHT_BEAT: StringName = &"firefight_beat"          ## zone, beat (1-based in the column), shooters [uid], exchange, first_shot_split
const PIERCE_CARRIED: StringName = &"pierce_carried"          ## side (shooter's), shooter_uid, from_uid, target_uid, carried (damage left before Cover), damage, zone, beat
const LINE_ADVANCED: StringName = &"line_advanced"            ## side, zone, moves [{uid, from_row, to_row}] (after removals: the line closed up)
const FIREFIGHT_COLUMN_ENDED: StringName = &"firefight_column_ended" ## zone, beats (after Patch)
## kc-wip-impl Beam (Laser Gunner): one beam shot; hits in order (its own units ahead first, then every
## enemy in the column). friendly = the hit unit is on the shooter's side. DAMAGE_DEALT follows per hit.
const BEAM_FIRED: StringName = &"beam_fired"                  ## side, shooter_uid, zone, beat, hits [{uid, side, damage, friendly}]
const SUPPRESSED: StringName = &"suppressed"                  ## side (suppressor's), uid (shooter), target_uid, amount
const SHOT_FIRED: StringName = &"shot_fired"                  ## side, shooter_uid, target_uid (-1 = no target), zone, damage, step (&"first_shot" if the shooter has First Shot, else &"beat"), beat, overkill, pierce
const DAMAGE_DEALT: StringName = &"damage_dealt"              ## target_uid, side (target's), amount, remaining, source_id
const SURVIVED_LETHAL: StringName = &"survived_lethal"        ## side, uid, armor
const UNIT_ELIMINATED: StringName = &"unit_eliminated"        ## victim_uid, victim_side, by_uid, by_side, zone, source_kind, by_killstreak, credit
const OPERATOR_DOWN: StringName = &"operator_down"            ## side, uid
const PATCHED: StringName = &"patched"                        ## side, uid (medic), target_uid, amount
const UNIT_HEALED: StringName = &"unit_healed"                ## side (healed unit's), source_id, source_uid, target_uid, amount, remaining, zone (HEAL effects: Aid Station; source_id &"trait_undead" = the Undead set heal)
## kc-syn: a side's active neighbor links or trait set tiers changed (after Reveal, the Firefight, the Score step).
const SYNERGY_CHANGED: StringName = &"synergy_changed"        ## side, links [{kind, from_uid, to_uid}], counts {trait: n}, sets {trait: tier}

# --- Score -----------------------------------------------------------------------
const ZONE_CONTROL: StringName = &"zone_control"              ## zone, owner (&"player" / &"enemy" / &"contested" / &"empty"), player_units, enemy_units, player_holder, enemy_holder
const MODE_SCORED: StringName = &"mode_scored"                ## mode, player_gained, enemy_gained, player_score, enemy_score, target
const STREAK_CHANGED: StringName = &"streak_changed"          ## side, streak, before, gained, reset, earned
const KILLSTREAK_EARNED: StringName = &"killstreak_earned"    ## side, item_id, streak, threshold (into the Streak Tray)
## kc-ks-seq (killstreak_strikes.gd): a damage killstreak revealed at Reveal waits for Firefight step 0.
const KILLSTREAK_QUEUED: StringName = &"killstreak_queued"    ## side, item_id, zone, zones [zone], fights (firefights it strikes), resolves (&"firefight")
## Firefight step 0: one strike starts; its DAMAGE_DEALT / UNIT_ELIMINATED follow, then KILLSTREAK_RESOLVED.
const KILLSTREAK_STRIKE: StringName = &"killstreak_strike"    ## side, item_id, zone, zones, pass, passes
const KILLSTREAK_RESOLVED: StringName = &"killstreak_resolved" ## side, item_id, zone, zones, pass, passes, hits [{uid, side, amount, remaining, card_id, name, zone}], kills [uid], what (log line)

# --- Loadout (p05) -------------------------------------------------------------------
const PERK_TRIGGERED: StringName = &"perk_triggered"          ## side, item_id (Field Salvage ...)
const CARD_RETURNED: StringName = &"card_returned"            ## side, card_uid, card_id, zone, reason: zone still full at Reveal

# --- Run v2 (kc-v2-impl) ----------------------------------------------------------------
## A Terrain did something (Minefield damage, Field Hospital heal, Comms Tower streak, Supply Cache Supply,
## Hot Zone point). `what` is a ready log line ("Minefield: Grunt takes 1").
const TERRAIN_TRIGGERED: StringName = &"terrain_triggered"    ## terrain, zone, side, uid?, amount?, what
## The boss rule did something (Reinforcements Supply, a Horde Shambler, Dug In's pits at the start).
const BOSS_RULE_TRIGGERED: StringName = &"boss_rule_triggered" ## rule, side, amount?, uid?, zone?, card_uid?, what
## (ITEM_USED / ITEM_REVEALED of an Operator ability carry `ability: true`.)


static func make(type: StringName, round_number: int, fields: Dictionary = {}) -> Dictionary:
	var event: Dictionary = {"type": type, "round": round_number}
	event.merge(fields)
	return event
