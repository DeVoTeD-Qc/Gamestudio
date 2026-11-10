# duel_match.gd
# Purpose: kc-duel-impl (duel-mode.md §4.1, §4.2): one Duel match and who plays which side.
#   Owns a MatchState (DuelRules.create_match) plus the Duel turn flow on top of it:
#   - vs AI: side 0 is the human, side 1 the tier's AiPlayer, which commits first every round (as in
#     the campaign) and is READY before the human's Deploy opens.
#   - Pass & Play (hot seat): two human sides. Deploys stay simultaneous by being private: each one
#     opens behind a cover (cover_needed -> accept_cover -> deploy_started), only the active side may
#     submit, and private events / views belong to the active side only. Who deploys first alternates
#     every round (round 1: seat 0). The board between covers shows public information only.
#   The screens keep using MatchState for plays and their own Reveal / Firefight / Score playback, then
#   call round_done(). The rules engine itself needed no change.
#   API for the screens: documentation/technical/duel-api.md §6.
# Dependencies: MatchState, RulesEvent, ModeRules, AiPlayer, DuelDeck, DuelConfig, DuelRules, RunConfig.
# Author: Mechanics Developer Agent (kc-duel-impl)
class_name DuelMatch
extends RefCounted

## Show the cover for `side` ("PLAYER 2 — take the device ..."); the board shows public info only.
signal cover_needed(side: int, player_name: String)
## `side`'s private Deploy is open (its hand, its round-1 mulligan).
signal deploy_started(side: int)
## `side` tapped READY.
signal side_ready(side: int)
## Both sides are ready: play Reveal / Firefight / Score, then call round_done().
signal round_ready
## The match is over (result()).
signal match_ended(result: Dictionary)

const KIND_AI: StringName = &"ai"
const KIND_HOT_SEAT: StringName = &"hot_seat"
const CODE_NOT_YOUR_TURN: StringName = &"not_your_turn"
const REASON_FORFEIT: StringName = &"forfeit"

var kind: StringName = KIND_AI
var state: MatchState = null
var config: DuelConfig = null
var decks: Array[DuelDeck] = [null, null]
var names: Array[String] = ["", ""]
var humans: Array[bool] = [true, false]
var tier: StringName = &""
var ai: AiPlayer = null
## The side whose private Deploy is open (-1: a cover is up, or both are ready).
var active_side: int = -1
## The side the cover waits for (-1: no cover).
var cover_side: int = -1
## Hot seat: which player (0 = Player 1, 1 = Player 2) sits on side 0 after the coin flip.
var seat0_player: int = 0
var _last_viewer: int = 0
var _ended: bool = false


## A vs-AI duel: `deck` (side 0, the human) against `opponent` (side 1) at `tier`. Not started.
static func vs_ai(deck: DuelDeck, opponent: DuelDeck, p_tier: StringName, cfg: DuelConfig, base: RunConfig,
		seed_value: int, player_name: String = "You") -> DuelMatch:
	var dm: DuelMatch = DuelMatch.new()
	dm.kind = KIND_AI
	dm.config = cfg
	dm.tier = p_tier
	dm.decks = [deck, opponent]
	dm.names = [player_name, opponent.display_name]
	dm.humans = [true, false]
	var armor: Array = [0, cfg.recruit_armor_bonus if p_tier == &"recruit" else 0]
	dm.state = DuelRules.create_match(deck, opponent, cfg, base, seed_value, dm.names, armor)
	var sb: float = {&"recruit": cfg.recruit_second_best, &"regular": cfg.regular_second_best}.get(p_tier, cfg.veteran_second_best)
	dm.ai = AiPlayer.for_duel_tier(p_tier, sb)
	return dm


## A Pass & Play duel. A seeded coin flip puts Player 1 or Player 2 on side 0 (seat 0). Not started.
static func hot_seat(deck_p1: DuelDeck, deck_p2: DuelDeck, p_names: Array, cfg: DuelConfig, base: RunConfig,
		seed_value: int) -> DuelMatch:
	var dm: DuelMatch = DuelMatch.new()
	dm.kind = KIND_HOT_SEAT
	dm.config = cfg
	dm.humans = [true, true]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([seed_value, 4231])
	dm.seat0_player = rng.randi_range(0, 1)
	var by_player: Array = [deck_p1, deck_p2]
	var n: Array = [String(p_names[0]) if p_names.size() > 0 else "Player 1", String(p_names[1]) if p_names.size() > 1 else "Player 2"]
	dm.decks = [by_player[dm.seat0_player], by_player[1 - dm.seat0_player]]
	dm.names = [n[dm.seat0_player], n[1 - dm.seat0_player]]
	dm.state = DuelRules.create_match(dm.decks[0], dm.decks[1], cfg, base, seed_value, dm.names, [0, 0])
	return dm


# =============================================================================
# Flow
# =============================================================================

## Starts the match (round 1 Briefing) and opens the first Deploy.
func start() -> void:
	if state == null or state.phase != MatchState.Phase.SETUP:
		return
	state.start_match()
	_open_deploy()


## Hot seat: the side that deploys first in `round` (seat 0 in round 1, then alternating).
func first_deployer(round: int = -1) -> int:
	var r: int = round if round > 0 else maxi(1, state.round_number if state != null else 1)
	return (r - 1) % 2


## The player tapped through the cover: `side`'s private Deploy opens.
func accept_cover(side: int) -> String:
	if kind != KIND_HOT_SEAT:
		return "No cover in this match"
	if side != cover_side:
		return "Wait for your turn"
	cover_side = -1
	active_side = side
	_last_viewer = side
	deploy_started.emit(side)
	return ""


## READY for `side`. Hot seat: the other side's cover comes up, or round_ready once both are ready.
func finish_deploy(side: int) -> String:
	if state == null or state.phase != MatchState.Phase.DEPLOY:
		return "Not in a Deploy"
	if side != active_side or not humans[side]:
		return "Wait for your turn"
	state.set_ready(side)
	side_ready.emit(side)
	active_side = -1
	var other: int = 1 - side
	if not state.sides[other].ready:
		if kind == KIND_HOT_SEAT:
			cover_side = other
			cover_needed.emit(other, names[other])
			return ""
		state.set_ready(other)  # the AI passes (it always planned before the human)
	round_ready.emit()
	return ""


## Reveal + Firefight + Score in one call (tests / tools). The screens may split it; either way, call
## round_done() after the round has played.
func resolve_round() -> Array[Dictionary]:
	if state == null or not state.both_ready():
		return []
	return state.resolve_round()


## After the round played: the match ends (match_ended) or the next round's Deploy opens.
func round_done() -> void:
	if state == null:
		return
	if state.phase == MatchState.Phase.ENDED:
		_end()
		return
	if state.phase == MatchState.Phase.SCORE or state.phase == MatchState.Phase.FIREFIGHT:
		state.begin_round()
	if state.phase == MatchState.Phase.ENDED:
		_end()
		return
	_open_deploy()


## `side` concedes: the other side wins (reason &"forfeit").
func forfeit(side: int) -> bool:
	if state == null or state.phase == MatchState.Phase.ENDED:
		return false
	var winner: StringName = ModeRules.RESULT_ENEMY if side == MatchState.PLAYER else ModeRules.RESULT_PLAYER
	var mr: ModeRules = state.hooks.mode_rules if state.hooks != null else null
	var outcome: Dictionary = {"result": winner, "winner": winner, "is_draw": false, "reason": REASON_FORFEIT,
			"rounds": int(state.round_number), "player_score": int(state.sides[0].score),
			"enemy_score": int(state.sides[1].score), "target": mr.target if mr != null else 0}
	if mr != null:
		mr.outcome = outcome
	state.result = winner
	state.phase = MatchState.Phase.ENDED
	state.emit_event(RulesEvent.PHASE_CHANGED, {"phase": "ended"})
	var details: Dictionary = outcome.duplicate()
	details["forfeit"] = true
	state.emit_event(RulesEvent.MATCH_ENDED, details)
	active_side = -1
	cover_side = -1
	_end()
	return true


func _open_deploy() -> void:
	if state.phase == MatchState.Phase.ENDED:
		_end()
		return
	if kind == KIND_AI:
		ai.take_turn(state, MatchState.ENEMY)
		cover_side = -1
		active_side = MatchState.PLAYER
		_last_viewer = MatchState.PLAYER
		deploy_started.emit(MatchState.PLAYER)
	else:
		active_side = -1
		cover_side = first_deployer()
		cover_needed.emit(cover_side, names[cover_side])


func _end() -> void:
	if _ended:
		return
	_ended = true
	active_side = -1
	cover_side = -1
	match_ended.emit(result())


# =============================================================================
# Guards and private views
# =============================================================================

func _guard(side: int) -> Dictionary:
	if state == null or side < 0 or side > 1 or not humans[side] or side != active_side:
		return {"ok": false, "code": CODE_NOT_YOUR_TURN, "reason": "Wait for your turn", "data": {}}
	return {}


## MatchState.submit, only for the side whose Deploy is open.
func submit(side: int, intent: Dictionary) -> Dictionary:
	var g: Dictionary = _guard(side)
	return g if not g.is_empty() else state.submit(side, intent)


func undo_last(side: int) -> Dictionary:
	var g: Dictionary = _guard(side)
	return g if not g.is_empty() else state.undo_last(side)


## The round-1 mulligan, in the side's own private Deploy.
func mulligan(side: int, card_uids: Array) -> Dictionary:
	var g: Dictionary = _guard(side)
	return g if not g.is_empty() else state.mulligan(side, card_uids)


## True when `side`'s hand, deck order, face-down plays, red dots and intel may be on screen.
func can_view_private(side: int) -> bool:
	if kind == KIND_AI:
		return side == MatchState.PLAYER
	return side == active_side and side >= 0


## The side the board is drawn for now (hot seat: the active side, else the last one that deployed;
## private information only when can_view_private(viewer())).
func viewer() -> int:
	if kind == KIND_AI:
		return MatchState.PLAYER
	return active_side if active_side >= 0 else _last_viewer


## `events` without the ones private to the side other than `p_viewer` (-1 = public only).
func visible_events(events: Array, p_viewer: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var me: StringName = state.side_name(p_viewer) if p_viewer >= 0 else &""
	for e: Dictionary in events:
		var priv: Variant = e.get("private_to", null)
		if priv == null or StringName(priv) == me:
			out.append(e)
	return out


func armor_bonus(side: int) -> int:
	return state.sides[side].setup.armor_bonus if state != null else 0


## Hot seat: the side Player `i` (0 = Player 1) plays. vs AI: the human is side 0.
func seat_of_player(i: int) -> int:
	return i if kind == KIND_AI else (0 if i == seat0_player else 1)


func player_of_side(side: int) -> int:
	return side if kind == KIND_AI else (seat0_player if side == 0 else 1 - seat0_player)


# =============================================================================
# Result
# =============================================================================

func result() -> Dictionary:
	var ended: bool = state != null and state.phase == MatchState.Phase.ENDED
	var res: StringName = state.result if state != null else &""
	var winner: int = 0 if res == &"player" else (1 if res == &"enemy" else -1)
	var outcome: Dictionary = {}
	if state != null and state.hooks != null and state.hooks.mode_rules != null:
		outcome = state.hooks.mode_rules.outcome
	var ids: Array = []
	var dnames: Array = []
	var heroes: Array = []
	for d: DuelDeck in decks:
		ids.append(d.id if d != null else &"")
		dnames.append(d.display_name if d != null else "")
		heroes.append(d.hero_id if d != null else &"")
	return {"kind": kind, "tier": tier, "ended": ended, "winner_side": winner, "result": res,
			"reason": StringName(outcome.get("reason", &"")), "rounds": state.round_number if state != null else 0,
			"scores": [state.sides[0].score, state.sides[1].score] if state != null else [0, 0],
			"names": names.duplicate(), "decks": ids, "deck_names": dnames, "heroes": heroes,
			"human_won": kind == KIND_AI and winner == 0,
			"winner_name": names[winner] if winner >= 0 else ""}
