# fight_playback.gd
# Purpose: The board as it stands at each moment of the firefight playback (kc-fight-ui,
#   firefight-order.md §8 / §10.2). The match controller resolves the whole round at once, so the
#   live MatchState is already at the end of the round while the FeedbackDirector plays it. This
#   keeps a throw-away copy (MatchClone) of the state as it was when the firefight started and
#   applies the event stream to it, one event at a time, in the order the director lands them:
#     SHOT_FIRED        the shooter has fired this round (RulesUnit.fired)
#     DAMAGE_DEALT      the target's Armor = `remaining`
#     SURVIVED_LETHAL   the unit holds at `armor`
#     UNIT_ELIMINATED   the victim leaves its line (the units behind it are now one row up)
#     PATCHED / UNIT_HEALED  Armor restored (capped at the unit's max)
#   snapshot() is MatchSnapshot.build() of that copy, so links, auras, sets and the trait rail are
#   the real synergy code's answer for the board at that moment (they react as units die and the
#   line moves up). Effects the copy cannot replay from the events (On Down buffs, summons) appear
#   when the round ends and the live state is shown again; the final board always comes from the
#   live state (a skip lands exactly there).
#   needs_refresh(ev): the moments the board is redrawn: a line advance (the dead leave and the line
#   slides up), the next beat / the column end (a dead unit with nobody behind it leaves), Grit and
#   Patch. Damage alone does not redraw: the damage number says it, the Armor badge follows at the
#   next of those moments.
# Dependencies: MatchClone, MatchState, RulesUnit, RulesEvent, match_snapshot.gd.
# Author: UI/UX Agent (kc-fight-ui)
extends RefCounted

const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")

var state: MatchState = null
var map: MapData = null
var viewer: int = MatchState.PLAYER
## Events applied so far (tests: they must come in the stream's order).
var applied: Array[Dictionary] = []
## uid -> true: fired this round.
var fired: Dictionary = {}
## uids eliminated so far.
var eliminated: Array[int] = []
var _dirty: bool = false


## A playback board for the firefight that is about to play from `live` (not changed).
static func start(live: MatchState, p_map: MapData, p_viewer: int = MatchState.PLAYER) -> RefCounted:
	var pb: RefCounted = (load("res://scripts/ui/fight_playback.gd") as GDScript).new()
	pb.state = MatchClone.copy(live)
	pb.map = p_map
	pb.viewer = p_viewer
	for s: RulesSide in pb.state.sides:
		for u: RulesUnit in s.units_on_board():
			u.fired = false
	return pb


## Applies one event (as it lands). Returns true if the board on screen should be redrawn now.
func apply(ev: Dictionary) -> bool:
	applied.append(ev)
	match ev.get("type", &""):
		RulesEvent.SHOT_FIRED:
			var shooter: int = int(ev.get("shooter_uid", -1))
			fired[shooter] = true
			var su: RulesUnit = _unit(shooter)
			if su != null:
				su.fired = true
		RulesEvent.DAMAGE_DEALT:
			var u: RulesUnit = _unit(int(ev.get("target_uid", -1)))
			if u != null:
				u.armor = maxi(0, int(ev.get("remaining", u.armor)))
				_dirty = true
		RulesEvent.SURVIVED_LETHAL:
			var g: RulesUnit = _unit(int(ev.get("uid", -1)))
			if g != null:
				g.armor = maxi(1, int(ev.get("armor", 1)))
				_dirty = true
		RulesEvent.UNIT_ELIMINATED:
			var victim: int = int(ev.get("victim_uid", -1))
			for s: RulesSide in state.sides:
				var v: RulesUnit = s.find_unit(victim)
				if v != null:
					s.line(v.zone).erase(v)
					v.zone = MatchState.NO_ZONE
					v.armor = 0
			if not eliminated.has(victim):
				eliminated.append(victim)
			_dirty = true
		RulesEvent.PATCHED, RulesEvent.UNIT_HEALED:
			var h: RulesUnit = _unit(int(ev.get("target_uid", -1)))
			if h != null:
				h.armor = mini(h.max_armor(state.round_number), h.armor + int(ev.get("amount", 0)))
				_dirty = true
	return needs_refresh(ev)


## True when the board should be redrawn after `ev` landed (see the header).
func needs_refresh(ev: Dictionary) -> bool:
	match ev.get("type", &""):
		RulesEvent.LINE_ADVANCED, RulesEvent.SURVIVED_LETHAL, RulesEvent.PATCHED, RulesEvent.UNIT_HEALED:
			return true
		RulesEvent.FIREFIGHT_BEAT, RulesEvent.FIREFIGHT_COLUMN_ENDED:
			return _dirty
	return false


## The match snapshot of the board at this moment (the firefight phase, deploy closed).
func snapshot(killfeed: Array = []) -> Dictionary:
	_dirty = false
	var snap: Dictionary = MatchSnapshot.build(state, map, viewer, killfeed)
	snap["phase"] = "FIREFIGHT"
	snap["deploy_open"] = false
	return snap


## uid -> row index (0 = front) of every unit on the copy's board, for one side and column.
func line_uids(side: int, zone: int) -> Array[int]:
	var out: Array[int] = []
	for u: RulesUnit in state.sides[side].line(zone):
		out.append(u.uid)
	return out


func _unit(uid: int) -> RulesUnit:
	if uid < 0:
		return null
	for s: RulesSide in state.sides:
		var u: RulesUnit = s.find_unit(uid)
		if u != null:
			return u
	return null
