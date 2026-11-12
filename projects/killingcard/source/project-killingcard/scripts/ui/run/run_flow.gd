# run_flow.gd
# Purpose: Screen-side helpers for the run flow (p11). Decides which run screen comes next from
#   the run's phase, records a finished match and builds the After-Action report, and turns run
#   data (RunMatchData, LoadoutItem, history) into the words the run screens show. Node-free:
#   it reads the RunState / SceneRouter autoloads and never edits RunState.run directly.
#
#   Screen order:
#     Title -> (Consent once) -> Loadout -> RunMap -> Match -> AfterAction -> Reward x N -> RunMap ...
#     ... the last match / out of tickets -> AfterAction -> RunEnd -> (EndSurvey) -> Title
# Dependencies: RunState, SceneRouter (autoloads), RunProgress, RunMatchData, RewardOffers,
#   LoadoutItem, MatchState, RulesEvent, DataEnums.
# Author: UI/UX Agent (p11)
extends RefCounted

const SCENE_TITLE: String = "res://scenes/Title.tscn"
const SCENE_LOADOUT: String = "res://scenes/run/Loadout.tscn"
const SCENE_RUN_MAP: String = "res://scenes/run/RunMap.tscn"
const SCENE_MATCH: String = "res://scenes/Match.tscn"
const SCENE_AFTER_ACTION: String = "res://scenes/run/AfterAction.tscn"
const SCENE_REWARD: String = "res://scenes/run/Reward.tscn"
const SCENE_RUN_END: String = "res://scenes/run/RunEnd.tscn"
## kc-v2-ui: the Run v2 node screens.
const SCENE_EVENT: String = "res://scenes/run/Event.tscn"
const SCENE_SHOP: String = "res://scenes/run/Shop.tscn"
const SCENE_REST: String = "res://scenes/run/Rest.tscn"
const SCENE_CONSENT: String = "res://scenes/survey/Consent.tscn"
const SCENE_END_SURVEY: String = "res://scenes/survey/EndSurvey.tscn"

const MODE_WORDS: Dictionary = {
	DataEnums.GameMode.ZONE_CONTROL: "Zone Control",
	DataEnums.GameMode.FIREFIGHT: "Firefight",
	DataEnums.GameMode.DETONATOR: "Detonator",
}
const MODE_GOALS: Dictionary = {
	DataEnums.GameMode.ZONE_CONTROL: "First to %d points",
	DataEnums.GameMode.FIREFIGHT: "First to %d eliminations",
	DataEnums.GameMode.DETONATOR: "Arm the Charge for %d rounds",
}
const END_WORDS: Dictionary = {
	RunProgress.END_RIVAL_WON: "You beat the Rival squad.",
	RunProgress.END_RIVAL_LOST: "The Rival squad beat you.",
	RunProgress.END_RIVAL_DRAW: "The Rival match ended in a draw.",
	RunProgress.END_NO_TICKETS: "You ran out of Reinforcement Tickets.",
}
const SLOT_WORDS: Dictionary = {
	DataEnums.LoadoutSlot.PRIMARY: "Primary", DataEnums.LoadoutSlot.ATTACHMENT: "Attachment",
	DataEnums.LoadoutSlot.PERK: "Perk",
	DataEnums.LoadoutSlot.KILLSTREAK: "Killstreak",
}
const CLASS_WORDS: Dictionary = {
	DataEnums.WeaponClass.NONE: "", DataEnums.WeaponClass.SMG: "SMG",
	DataEnums.WeaponClass.SHOTGUN: "Shotgun", DataEnums.WeaponClass.AR: "AR",
	DataEnums.WeaponClass.SNIPER: "Sniper", DataEnums.WeaponClass.LMG: "LMG",
}


static func run_state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("RunState")


static func router() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("SceneRouter")


static func event_bus() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("EventBus")


static func playtest_log() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("PlaytestLog")


# =============================================================================
# Routing
# =============================================================================

## The run screen for the run's current phase (Title when there is no run).
static func scene_for(run: RunProgress) -> String:
	if run == null:
		return SCENE_TITLE
	# kc-v2-ui: the Run v2 phases (run-v2-api.md §2): the map, and the Event / Shop / Rest steps.
	match StringName(str(run.phase)):
		&"map":
			return SCENE_RUN_MAP
		&"event":
			return SCENE_EVENT
		&"shop":
			return SCENE_SHOP
		&"rest":
			return SCENE_REST
	match run.phase:
		RunProgress.PHASE_LOADOUT:
			return SCENE_LOADOUT
		RunProgress.PHASE_MATCH:
			return SCENE_RUN_MAP
		RunProgress.PHASE_REWARDS:
			return SCENE_REWARD
		RunProgress.PHASE_ENDED:
			return SCENE_RUN_END
	return SCENE_TITLE


static func goto(path: String) -> void:
	var r: Node = router()
	if r != null:
		r.goto_scene(path)


## After the run end: the end survey once per session while logging is on, else Title.
static func scene_after_run_end() -> String:
	var plog: Node = playtest_log()
	if plog != null and bool(plog.get("enabled")) and not bool(plog.get("end_survey_done")) \
			and ResourceLoader.exists(SCENE_END_SURVEY):
		return SCENE_END_SURVEY
	return SCENE_TITLE


# =============================================================================
# Recording a match and the After-Action report
# =============================================================================

## Records a finished MatchState with RunState.finish_match and returns the report.
static func record_match(m: MatchState) -> Dictionary:
	var rs: Node = run_state()
	var before: Dictionary = _before(rs.run)
	var summary: Dictionary = rs.finish_match(m)
	var stats: Dictionary = {"best_streak": best_streak(m)}
	if m != null and m.sides.size() == 2:
		stats["player_eliminations"] = m.sides[MatchState.PLAYER].eliminations
		stats["enemy_eliminations"] = m.sides[MatchState.ENEMY].eliminations
	var rep: Dictionary = _report(rs.run, before, summary, stats)
	if bool(rep.get("ok", false)):
		rep["mvp"] = mvp(m)
	return rep


## kc-da-ui2 (debrief MVP): the player's unit (or Operator) that did the most this match, from the
## match log: eliminations it is credited with (x10) plus damage its shots dealt. {} when none of
## your units dealt damage. {card_id, art, operator, kills, damage}.
static func mvp(m: MatchState) -> Dictionary:
	if m == null or m.sides.size() != 2:
		return {}
	var me: StringName = m.side_name(MatchState.PLAYER)
	var kills: Dictionary = {}
	var damage: Dictionary = {}
	var ids: Dictionary = {}
	for e: Dictionary in m.events:
		var t: StringName = e.get("type", &"")
		if t == RulesEvent.UNIT_ELIMINATED and StringName(str(e.get("by_side", ""))) == me and bool(e.get("credit", true)):
			var by: int = int(e.get("by_uid", -1))
			if by >= 0:
				kills[by] = int(kills.get(by, 0)) + 1
				if str(e.get("by_id", "")) != "":
					ids[by] = StringName(str(e["by_id"]))
		elif t == RulesEvent.SHOT_FIRED and StringName(str(e.get("side", ""))) == me:
			var sh: int = int(e.get("shooter_uid", -1))
			if sh >= 0:
				damage[sh] = int(damage.get(sh, 0)) + maxi(0, int(e.get("damage", 0)))
		elif t == RulesEvent.UNIT_ARRIVED and StringName(str(e.get("side", ""))) == me:
			ids[int(e.get("uid", -1))] = StringName(str(e.get("card_id", "")))
	var best: int = -1
	var best_score: int = 0
	for uid: int in kills.keys() + damage.keys():
		var sc: int = int(kills.get(uid, 0)) * 10 + int(damage.get(uid, 0))
		if sc > best_score:
			best_score = sc
			best = uid
	if best < 0:
		return {}
	var op: RulesUnit = m.sides[MatchState.PLAYER].operator_unit
	var is_op: bool = op != null and op.uid == best
	var id: StringName = ids.get(best, &"")
	if is_op and m.sides[MatchState.PLAYER].setup != null and m.sides[MatchState.PLAYER].setup.primary != null:
		id = m.sides[MatchState.PLAYER].setup.primary.id
	if id == &"":
		return {}
	return {"card_id": String(id), "art": String(m.art_by_uid.get(best, "")), "operator": is_op,
			"kills": int(kills.get(best, 0)), "damage": int(damage.get(best, 0))}


## Records a forced result (debug, tests) with RunState.record_result and returns the report.
## outcome: ModeRules-style {reason, rounds, player_score, enemy_score}; stats: {best_streak,
## player_eliminations, enemy_eliminations} (optional).
static func record_forced(result: StringName, outcome: Dictionary = {}, stats: Dictionary = {}) -> Dictionary:
	var rs: Node = run_state()
	var before: Dictionary = _before(rs.run)
	var summary: Dictionary = rs.record_result(result, outcome)
	var s: Dictionary = stats.duplicate()
	for key: String in ["player_eliminations", "enemy_eliminations"]:
		if not s.has(key) and outcome.has(key):
			s[key] = outcome[key]
	return _report(rs.run, before, summary, s)


## Highest streak the player reached in the match (from the STREAK_CHANGED events).
static func best_streak(m: MatchState) -> int:
	if m == null:
		return 0
	var best: int = 0
	for e: Dictionary in m.events:
		if e.get("type", &"") != RulesEvent.STREAK_CHANGED:
			continue
		var side: Variant = e.get("side")
		if (typeof(side) == TYPE_INT and side == MatchState.PLAYER) or StringName(str(side)) == &"player":
			best = maxi(best, maxi(int(e.get("streak", 0)), int(e.get("before", 0)) + int(e.get("gained", 0))))
	return best


static func _before(run: RunProgress) -> Dictionary:
	if run == null:
		return {}
	var md: RunMatchData = run.current_match()
	return {"tickets": run.tickets, "match": run.match_number(), "slot": md, "rival": run.is_rival_match()}


static func _report(run: RunProgress, before: Dictionary, summary: Dictionary, stats: Dictionary) -> Dictionary:
	if run == null or not summary.get("ok", false) or run.history.is_empty():
		return {"ok": false, "reason": summary.get("reason", "no run")}
	var h: Dictionary = run.history[-1]
	var md: RunMatchData = before.get("slot")
	var r: Dictionary = report_from_history(run, h, md)
	r["tickets_before"] = int(before.get("tickets", run.tickets))
	r["tickets_after"] = run.tickets
	# kc-v2-ui: REQ earned and the elite flag (run-v2-api.md §7).
	r["req_gained"] = int(summary.get("req_gained", -1))
	r["elite"] = bool(summary.get("elite", false))
	for key: String in ["best_streak", "player_eliminations", "enemy_eliminations"]:
		if stats.has(key):
			r[key] = int(stats[key])
	return r


## Report for one history entry. Eliminations / best streak are -1 when unknown.
static func report_from_history(run: RunProgress, h: Dictionary, md: RunMatchData = null) -> Dictionary:
	var n: int = int(h.get("match", 0))
	if md == null and n >= 1 and n <= run.config.matches.size():
		md = run.config.matches[n - 1]
	var lost: bool = bool(h.get("ticket_lost", false))
	return {
		"ok": true,
		"match": n,
		"matches_total": run.match_count(),
		"result": StringName(str(h.get("result", ""))),
		"reason": str(h.get("reason", "")),
		"rival": bool(h.get("rival", false)),
		"bracket": int(h.get("bracket", 0)),
		"mode": mode_word(md.mode) if md != null else str(h.get("mode", "")).capitalize(),
		"target": mode_target(run.config, md.mode) if md != null else 0,
		"squad": squad_word(md) if md != null else "",
		"map": md.map.display_name if md != null and md.map != null else "",
		"rounds": int(h.get("rounds", 0)),
		"player_score": int(h.get("player_score", 0)),
		"enemy_score": int(h.get("enemy_score", 0)),
		"player_eliminations": -1,
		"enemy_eliminations": -1,
		"best_streak": -1,
		"tickets_before": run.tickets + (1 if lost else 0),
		"tickets_after": run.tickets,
		"run_over": run.is_over(),
	}


## The report the After-Action screen shows: the one SceneRouter kept, else the last history entry.
static func current_report() -> Dictionary:
	var r: Node = router()
	var rep: Dictionary = r.get("last_match_report") if r != null else {}
	var rs: Node = run_state()
	var run: RunProgress = rs.run if rs != null else null
	if run == null or run.history.is_empty():
		return {}
	if not rep.is_empty() and int(rep.get("match", 0)) == int(run.history[-1]["match"]):
		return rep
	return report_from_history(run, run.history[-1])


# =============================================================================
# Words
# =============================================================================

static func mode_word(mode: int) -> String:
	return MODE_WORDS.get(mode, "Match")


static func mode_target(config: RunConfig, mode: int) -> int:
	match mode:
		DataEnums.GameMode.ZONE_CONTROL:
			return config.zone_control_target
		DataEnums.GameMode.FIREFIGHT:
			return config.firefight_target
		DataEnums.GameMode.DETONATOR:
			return config.detonator_arm_rounds
	return 0


static func mode_goal(config: RunConfig, mode: int) -> String:
	return String(MODE_GOALS.get(mode, "%d")) % mode_target(config, mode)


static func squad_word(md: RunMatchData) -> String:
	if md == null or md.squad == null:
		return "Unknown squad"
	var tag: String = md.squad.clan_tag
	return ("[%s] %s" % [tag, md.squad.display_name]) if tag != "" else md.squad.display_name


static func bracket_word(md: RunMatchData, is_last: bool) -> String:
	return "RIVAL" if md.is_rival or is_last else "BRACKET %d" % md.bracket


## "Enemy +1 Armor" / "No enemy bonus".
static func bonus_word(md: RunMatchData) -> String:
	var parts: PackedStringArray = []
	if md.enemy_firepower_bonus > 0:
		parts.append("+%d FP" % md.enemy_firepower_bonus)
	if md.enemy_armor_bonus > 0:
		parts.append("+%d Armor" % md.enemy_armor_bonus)
	return "Enemy " + " ".join(parts) if not parts.is_empty() else "No enemy bonus"


static func result_word(result: StringName) -> String:
	return {&"player": "WON", &"enemy": "LOST", &"draw": "DRAW"}.get(result, "")


## One line describing what an item does: stats and keywords, then its rules text.
static func item_effect_line(item: LoadoutItem) -> String:
	var parts: PackedStringArray = []
	if item.slot == DataEnums.LoadoutSlot.PRIMARY:
		parts.append("FP %d / Armor %d" % [item.operator_firepower, item.operator_armor])
	if item.firepower_bonus != 0:
		parts.append("%+d FP" % item.firepower_bonus)
	if item.armor_bonus != 0:
		parts.append("%+d Armor" % item.armor_bonus)
	if item.first_shot:
		parts.append("First Shot")
	if item.pick:
		parts.append("Pick")
	if item.flank:
		parts.append("Flank")
	if item.cover > 0:
		parts.append("Cover %d" % item.cover)
	if item.suppress:
		parts.append("Suppress")
	if item.patch > 0:
		parts.append("Patch %d" % item.patch)
	if item.holder:
		parts.append("Holder")
	if item.supply_cost > 0:
		parts.append("%d Supply" % item.supply_cost)
	return " · ".join(parts)


## Names of the ids (resolved through the run), joined; `none` when empty.
static func names_of(run: RunProgress, ids: Array, none: String = "None") -> String:
	var out: PackedStringArray = []
	for id: Variant in ids:
		var res: Resource = run.resource(StringName(str(id)))
		out.append(str(res.get("display_name")) if res != null else str(id))
	return ", ".join(out) if not out.is_empty() else none


## "2× Rifleman, 1× Breacher ..." in deck order of first appearance.
static func deck_summary(run: RunProgress) -> String:
	var order: Array[StringName] = []
	var count: Dictionary = {}
	for id: StringName in run.deck:
		if not count.has(id):
			order.append(id)
			count[id] = 0
		count[id] = int(count[id]) + 1
	var out: PackedStringArray = []
	for id: StringName in order:
		var res: Resource = run.resource(id)
		out.append("%d× %s" % [count[id], str(res.get("display_name")) if res != null else String(id)])
	return ", ".join(out)


static func time_word(seconds: float) -> String:
	var s: int = int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
