# match_controller.gd
# Purpose: Drives a CardZone match on the real rules engine (cz07 LoadoutRules) for the match
#   screen (cz11). Everything the human can do comes from legal_actions / check on the human's
#   own actions; everything the screen shows comes from LoadoutRules.view(state, human) and
#   events_for(human). The rival's hidden fields (hand, held cards, loadout order) are never read
#   here for display: names for events come only from events already filtered for the human.
# Flow:
#   start_new(route) / start_from(state) -> the opponent acts until the human must decide ->
#   the screen calls request(action) -> apply -> the result events are announced in order
#   (event_delay apart; 0 = all at once, for tests) -> the opponent acts again whenever it must
#   decide (its drop, its turn, its Brace) -> ... -> match over.
#   The human's Brace step stops the loop until request({type: "brace", cards}) arrives.
# Opponent: `opponent` is any object with choose_action(state, seat) -> Dictionary (see
#   opponent_placeholder.gd; CzAI, cz09, implements the same call).
# Saving (cz08 MatchStore): MatchStore.save(state, meta) after every applied action (the human's,
#   undo included, and the opponent's); MatchStore.clear() on a new match, a concede and the match
#   end. start_resumed(MatchStore.resume()) continues a saved match (cz13 owns the title's
#   Continue). meta = {mode, ai_level, ai_seed, human_seat}.
# Shell hooks (cz13): `paused` holds the loop before the next event / rival action while the
#   pause menu or a coach tip is open; stats() feeds the end screen; a CzAI opponent is named by
#   its level.
# Signals: view_changed(view) after every applied action, event_shown(text, event) per event,
#   notice(text) for a refused request, phase_changed(phase), settled() when input is open again.
#   cz18 (playtest log): also EventBus.match_context(info) once per start / resume and
#   EventBus.match_view_changed(view) with every view_changed (additive emits only).
# cz12 Brace prompt: view() adds to the human's brace_prompt (additive, the rules view is untouched):
#   hand_size, dmg (printed damage + attachments, public), source {card, area, kind}, suggested
#   (inst ids of the suggested Brace, brace_advisor.gd) and suggestion ({cards, card_ids, total,
#   hits, blocked, health_after, eliminated, comes_up, reason}). The same view goes out through
#   EventBus.match_view_changed, so PlaytestLog's brace.suggested_used reads `suggested` (cz18).
#   brace_preview(cards) is the live result of any choice; brace_suggested(suggestion) fires when
#   the human's Brace step opens.
# cz12 playback: events play out one step at a time while the rival is involved (its drop, turn,
#   Brace); the human's own actions answer at once. A step is an event with words; its time is
#   event_delay x the step's weight (shots 1.5, minor steps 0.6) x the speed (fast_forward() 0.4x,
#   skip_playback() 0: the rest of this playback at once). FAST / SKIP reset when input opens.
#   Hooks for game feel (cz17): playback_step(step) per step, before its wait (step: {index, type,
#   kind, seat, rival, text, event, from, to, duration}); hold_playback() / release_playback()
#   keep the loop on a step until the effect is done (SKIP ignores holds); busy_changed(busy) and
#   settled (await it: input open again); playback_finished(summary, steps, skipped) after a
#   rival's turn (the screen shows the one-line summary when it was skipped or instant).
#   Steps come from events_for(human): the rival's private cards are never in them.
# Dependencies: LoadoutRules, MatchState, RulesData, MatchView, CardDB, EventBus, MatchStore,
#   action_text.gd, opponent_placeholder.gd, brace_advisor.gd.
# Author: UI/UX Agent (cz11, cz12)
extends Node

signal view_changed(view: Dictionary)
signal event_shown(text: String, event: Dictionary)
signal notice(text: String)
signal phase_changed(phase: StringName)
signal settled
## cz12: true when a run starts playing out, false when input opens again.
signal busy_changed(is_busy: bool)
## cz12: one playback step (see the header). Emitted before the step's wait.
signal playback_step(step: Dictionary)
## cz12: after a run that included rival steps: a one-line summary of the rival's turn.
signal playback_finished(summary: String, steps: Array, skipped: bool)
## cz12: the human's Brace step opened with this suggestion (brace_advisor.gd).
signal brace_suggested(suggestion: Dictionary)
## cz14 hot-seat: the pass-the-device cover went up (before anything of `info.seat` is shown) or
## came down (after the seat's view was emitted). info: see cover_info().
signal cover_changed(up: bool, info: Dictionary)

const ActionText: GDScript = preload("res://scripts/match/action_text.gd")
const OpponentPlaceholder: GDScript = preload("res://scripts/match/opponent_placeholder.gd")
const BraceAdvisor: GDScript = preload("res://scripts/match/brace_advisor.gd")
const CardWords: GDScript = preload("res://scripts/ui/card_words.gd")

## cz12: speed factor of FAST (x the current Event speed delays).
const FAST_FACTOR: float = 0.4
## cz17: the longest a game-feel hold keeps the loop on one step (seconds); the FX layer caps its
## own holds lower (CzMatchFx.MAX_HOLD_S).
const HOLD_CAP_S: float = 3.0
## cz12: how long each kind of step stays up, x event_delay.
const STEP_WEIGHT: Dictionary = {&"shot": 1.5, &"brace": 1.3, &"hits": 1.3, &"out": 1.5, &"move": 1.0,
		&"loot": 1.0, &"play": 0.8, &"pack": 1.0, &"turn": 0.6, &"draw": 0.6, &"round": 0.8, &"zone": 0.9, &"other": 0.7}

const PHASE_IDLE: StringName = &"idle"
const PHASE_DROP: StringName = &"drop"
const PHASE_ACT: StringName = &"act"
const PHASE_BRACE: StringName = &"brace"
const PHASE_OPPONENT: StringName = &"opponent"
const PHASE_OVER: StringName = &"over"
## cz14 hot-seat: the cover is up; nothing seat-private is in the view until reveal().
const PHASE_COVER: StringName = &"cover"

## Seconds between announced events (0 = no waiting: tests).
@export var event_delay: float = 0.45
## Seconds before each opponent action (0 = no waiting: tests).
@export var opponent_delay: float = 0.35

var human: int = MatchState.P1
var opponent: Object = null
var state: MatchState = null
var phase: StringName = PHASE_IDLE
## True while events play out or the opponent acts. Requests (except concede) wait.
var busy: bool = false
## Every announced line, oldest first.
var log_lines: PackedStringArray = []
## Card ids of the rival's last packed line (public: P10).
var rival_last_line: Array[StringName] = []
## Undos this turn (spec U6: turn_end.undo_count, for the playtest log).
var undo_count: int = 0
## Save after every action (MatchStore). Off for fixtures that must not replace the player's match.
var save_enabled: bool = true
## Saved with the match: {mode, ai_level, ai_seed, human_seat}.
var meta: Dictionary = {"mode": "ai", "ai_level": "placeholder", "ai_seed": 0, "human_seat": MatchState.P1}
## cz13: while true the loop waits before announcing the next event or asking the rival.
var paused: bool = false
## cz13: Hits landed on each seat this match (before Brace is not counted: what actually landed).
var hits_landed: Array[int] = [0, 0]

var _run_id: int = 0
var _started_ms: int = 0
var _turn_index: int = 0
## cz18: set by start_resumed for the next match_context ({age_s}); {} = a new match.
var _resume_info: Dictionary = {}
## cz12 playback state: FAST / SKIP for the current playback, game-feel holds, steps.
var playback_fast: bool = false
var playback_skip: bool = false
var _holds: int = 0
var _step_index: int = 0
var _rival_steps: Array = []
var _skipped_any: bool = false
var _in_rival_turn: bool = false
## cz12: cached suggestion for the current Brace step, keyed by the action count.
var _suggestion: Dictionary = {}
var _suggestion_key: String = ""
## cz14 hot-seat (meta.mode == "hotseat"): two humans, one device. `human` is the seat shown.
var hotseat: bool = false
## cz14: the seat the cover is up for (-1 = no cover).
var cover_seat: int = -1
## cz14: per seat, the events (already filtered for that seat) of each action applied while it
## was not shown, one Array per action (an undo drops the last one); told after its cover.
var _unseen: Array = [[], []]
## cz14: per seat, its own log lines (log_lines is the shown seat's).
var _seat_logs: Array = [PackedStringArray(), PackedStringArray()]
## cz14: per seat, the card ids of its last packed line (public, P10).
var _last_lines: Array = [[], []]


func _init() -> void:
	opponent = OpponentPlaceholder.new()


# --- Starting -------------------------------------------------------------------------

## A fresh match from CardDB content at the drop (P2 drops first, then the human as P1).
func start_new(route: int = DataEnums.Route.A) -> void:
	var content: RulesData = RulesData.from_card_db(CardDB)
	_store_clear()
	start_from(MatchState.new_match(content, route))


## A saved match from MatchStore.resume() ({state, meta}). False when there is nothing to resume.
func start_resumed(resumed: Dictionary) -> bool:
	if resumed.is_empty() or resumed.get("state") == null:
		return false
	_resume_info = {"age_s": _save_age_s(resumed)}  # cz18: match_context.resumed
	start_from(resumed["state"], resumed.get("meta", {}))
	return true


## Any state (a new match, a resumed one or a QA fixture mid-turn). match_meta: see `meta`.
func start_from(s: MatchState, match_meta: Dictionary = {}) -> void:
	for k: Variant in match_meta.keys():
		meta[k] = match_meta[k]
	hotseat = String(meta.get("mode", "ai")) == "hotseat"  # cz14
	human = int(meta.get("human_seat", human))
	meta["human_seat"] = human
	if not match_meta.has("ai_level"):
		meta["ai_level"] = opponent_kind().to_lower()
	state = s
	log_lines.clear()
	rival_last_line.clear()
	undo_count = 0
	_turn_index = 0
	hits_landed = [0, 0]
	_rival_steps.clear()
	_hotseat_begin()  # cz14: hot-seat starts (and resumes) behind the cover
	_in_rival_turn = s.phase != MatchState.PHASE_DROP and s.active == rival_seat()
	_started_ms = Time.get_ticks_msec()
	EventBus.match_started.emit(&"hotseat" if hotseat else StringName(opponent_kind().to_lower()), MatchState.P1)
	_emit_context()
	_run(null)


func opponent_kind() -> String:
	if hotseat:
		return "Player %d" % (rival_seat() + 1)  # cz14
	if opponent != null and "kind" in opponent:
		return String(opponent.get("kind"))
	if opponent != null and "level" in opponent:
		return String(opponent.get("level")).capitalize()  # CzAI (cz09): "Rookie" / "Veteran"
	return "AI"


## cz13 end screen: {rounds, turns, seconds, actions, hits_on_me, hits_on_rival}.
func stats() -> Dictionary:
	return {"rounds": state.round_number if state != null else 0, "turns": _turn_index,
			"seconds": (Time.get_ticks_msec() - _started_ms) / 1000.0,
			"actions": state.actions.size() if state != null else 0,
			"hits_on_me": hits_landed[human], "hits_on_rival": hits_landed[rival_seat()], "hotseat": hotseat}


func rival_seat() -> int:
	return 1 - human


# --- What the human sees and may do --------------------------------------------------------

func view() -> Dictionary:
	if state == null:
		return {}
	if is_covered():
		return _covered_view()  # cz14: nothing seat-private while the cover is up
	var v: Dictionary = LoadoutRules.view(state, human)
	if v.has("brace_prompt"):
		_add_brace_advice(v)
	return v


# --- Brace prompt (cz12) -----------------------------------------------------------------

## The suggested Brace for the human's open Brace step ({} when none): see brace_advisor.gd.
func brace_suggestion() -> Dictionary:
	var v: Dictionary = view()
	return v.get("brace_prompt", {}).get("suggestion", {})


## The live result of bracing with `cards` now: {total, hits, blocked, health_after, eliminated,
## comes_up, ...} (brace_advisor.preview). {} when there is no Brace step.
func brace_preview(cards: Array) -> Dictionary:
	if state == null or state.pending_brace_seat() != human or is_covered():
		return {}
	var v: Dictionary = LoadoutRules.view(state, human)
	v["brace_prompt"]["hand_size"] = state.data.balance.hand_size
	return BraceAdvisor.preview(v, cards, _lookup())


func _add_brace_advice(v: Dictionary) -> void:
	var bp: Dictionary = v["brace_prompt"]
	bp["hand_size"] = state.data.balance.hand_size
	var shot: Dictionary = v.get("last_shot", {})
	var kind: String = String(shot.get("kind", bp.get("kind", "shot")))
	var src: Dictionary = (shot.get("card", {}) if kind == "frag" else shot.get("weapon", {})) as Dictionary
	var dmg: int = 0
	var c: CardData = CardDB.get_card(StringName(str(src.get("card", ""))))
	if c != null:
		dmg = c.blast_dmg if kind == "frag" else c.dmg
		for a: Variant in src.get("attachments", []):
			var ac: CardData = CardDB.get_card(StringName(str(a)))
			dmg += ac.attach_dmg if ac != null else 0
	bp["dmg"] = dmg
	bp["source"] = {"card": StringName(str(src.get("card", ""))), "kind": kind,
			"from": StringName(str(v["opponent"].get("area", ""))), "area": StringName(str(shot.get("area", "")))}
	var key: String = "%d/%d/%d" % [state.actions.size(), state.round_number, int(bp["damage"])]
	if key != _suggestion_key:
		_suggestion_key = key
		_suggestion = BraceAdvisor.suggest(v, _lookup())
	bp["suggestion"] = _suggestion.duplicate(true)
	bp["suggested"] = (_suggestion.get("cards", []) as Array).duplicate()


func _lookup() -> Callable:
	return func(id: StringName) -> CardData: return CardDB.get_card(id)


# --- Playback controls (cz12) --------------------------------------------------------------

## FAST: the rest of this playback at FAST_FACTOR x the Event speed.
func fast_forward() -> void:
	if busy:
		playback_fast = true


## SKIP: the rest of this playback at once (until the human must decide again).
func skip_playback() -> void:
	if busy:
		playback_skip = true
		_skipped_any = true


## Game feel (cz17): keep the loop on the current step until release_playback().
func hold_playback() -> void:
	_holds += 1


func release_playback() -> void:
	_holds = maxi(0, _holds - 1)


## Seconds a step of this kind stays up at the current speed (0 = no wait).
func step_duration(kind: StringName) -> float:
	if playback_skip or event_delay <= 0.0:
		return 0.0
	return event_delay * float(STEP_WEIGHT.get(kind, 0.7)) * (FAST_FACTOR if playback_fast else 1.0)


## True when the human must decide now (drop, turn or Brace) and nothing is playing out.
func is_human_turn() -> bool:
	return state != null and not busy and not state.is_over() and state.deciding_seat() == human and not is_covered()


## The human's legal actions now ([] while the rival decides, or behind the hot-seat cover).
func legal() -> Array[Dictionary]:
	if state == null or state.is_over() or state.deciding_seat() != human or is_covered():
		return []
	return LoadoutRules.legal_actions(state)


## "" when request(a) would be accepted, else why not (in words).
func why_not(action: Dictionary) -> String:
	if state == null:
		return "No match is running."
	var a: Dictionary = LoadoutRules.normalize(state, _own(action))
	var t: String = a["type"]
	if t != "concede":
		if is_covered():
			return "Pass the device: Player %d taps the cover when ready." % (cover_seat + 1)  # cz14
		if busy:
			return "Wait: the last action is still playing out."
		if state.is_over():
			return "The match is over."
	if t == "undo":
		return _undo_reason()
	var err: StringName = LoadoutRules.check(state, a)
	if err == &"":
		return ""
	return ActionText.reason(err, a, _context(a))


## Applies one human action. Returns "" when accepted, else the reason (also sent as notice).
func request(action: Dictionary) -> String:
	var why: String = why_not(action)
	if why != "":
		notice.emit(why)
		return why
	var a: Dictionary = LoadoutRules.normalize(state, _own(action))
	var r: ActionResult = LoadoutRules.apply(state, a)
	if not r.ok:
		var msg: String = ActionText.reason(r.error, a, _context(a))
		notice.emit(msg)
		return msg
	if a["type"] == "undo":
		undo_count += 1
	_run(r)
	return ""


## Shot preview for one of the human's weapons (P19: damage after Cover and Down; never the
## rival's hand). {legal, error, reason, damage, cover, down, suppressed, may_brace, dmg, dist, range}.
func shot_preview(weapon: int) -> Dictionary:
	var p: Dictionary = LoadoutRules.preview_shot(state, human, weapon, rival_seat())
	var a: Dictionary = {"type": "shoot", "seat": human, "weapon": weapon, "target": rival_seat()}
	p["reason"] = why_not(a)
	p["dist"] = state.data.distance(state.seats[human].area, state.seats[rival_seat()].area)
	p["range"] = LoadoutRules.weapon_range(state, weapon)
	return p


## Card id of an instance the human can see (own cards, public cards).
func card_id(inst: int) -> StringName:
	return state.card_id(inst) if state != null else &""


func card(inst: int) -> CardData:
	return CardDB.get_card(card_id(inst))


# --- Options for the screen's action dock -----------------------------------------------
# Each option: {key, label, action ({} for a two-step choice), reason ("" = legal)}.

func hand_options(inst: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var c: CardData = card(inst)
	if c == null:
		return out
	if c.is_hit():
		out.append(_opt(&"adrenaline_move", "MOVE +1", {"type": "play", "card": inst, "adrenaline": "move"}))
		out.append(_opt(&"adrenaline_search", "SEARCH +1", {"type": "play", "card": inst, "adrenaline": "search"}))
		out.append(_opt(&"patch_up", "PATCH UP", {"type": "patch_up"}))
		return out
	if c.blast_dmg > 0:
		var throws: Array = frag_areas(inst)
		var o: Dictionary = {"key": &"throw", "label": "THROW", "action": {}, "reason": ""}
		if throws.is_empty():
			o["reason"] = why_not({"type": "frag", "card": inst, "area": String(state.seats[human].area)})
		out.append(o)
	else:
		out.append(_opt(&"play", "PLAY", {"type": "play", "card": inst}))
	if c.is_attachment():
		out.append(_attach_option(inst))
	out.append(_opt(&"ditch", "DITCH", {"type": "ditch", "card": inst}))
	return out


func line_options(inst: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var c: CardData = card(inst)
	if c == null:
		return out
	if c.is_weapon():
		out.append(_opt(&"fire", "FIRE", {"type": "shoot", "weapon": inst, "target": rival_seat()}))
	if c.is_attachment():
		out.append(_attach_option(inst))
	if c.is_hit():
		out.append(_opt(&"patch_up", "PATCH UP", {"type": "patch_up"}))
	return out


func area_options(area_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if state == null:
		return out
	if state.phase == MatchState.PHASE_DROP:
		out.append(_opt(&"drop", "DROP HERE", {"type": "drop", "area": String(area_id)}))
		return out
	if area_id == state.seats[human].area:
		var o: Dictionary = {"key": &"loot", "label": "LOOT…", "action": {}, "reason": ""}
		var sources: Array[Dictionary] = loot_options()
		if sources.is_empty():
			o["reason"] = "There's nothing to loot in %s." % ActionText.area_name(area_id)
		elif state.gas.has(area_id):
			o["reason"] = ActionText.reason(LoadoutRules.ERR_GAS, {}, {"here": area_id})
		out.append(o)
	else:
		out.append(_opt(&"move", "MOVE HERE", {"type": "move", "to": String(area_id)}))
	return out


## One option per loot source in the human's area: piles (top card), supply drops, crate cards.
func loot_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var v: Dictionary = view()
	var here: String = String(v["me"]["area"])
	var bal: BalanceConfig = state.data.balance
	var piles: Dictionary = v["piles"].get(StringName(here), v["piles"].get(here, {}))
	for cid: Variant in piles.keys():
		if int(piles[cid]) <= 0:
			continue
		var c: CardData = CardDB.get_card(StringName(str(cid)))
		out.append(_card_opt(_opt(StringName("loot_" + str(cid)), "%s · Search %d · %d left" % [c.display_name, c.cost, int(piles[cid])],
				{"type": "loot", "pile": str(cid)}), c))
	for d: Dictionary in v["drops"].get(StringName(here), v["drops"].get(here, [])):
		var c: CardData = CardDB.get_card(StringName(d["card"]))
		out.append(_card_opt(_opt(StringName("loot_drop_%d" % int(d["id"])), "%s · supply drop · Search %d" % [c.display_name, bal.supply_drop_cost],
				{"type": "loot", "card": int(d["id"])}), c))
	for cr: Dictionary in v["crates"]:
		if String(cr["area"]) != here:
			continue
		var free: bool = int(cr["free_picks"]) > 0 and int(cr["picker"]) == human
		for cv: Dictionary in cr["cards"]:
			var c: CardData = CardDB.get_card(StringName(cv["card"]))
			out.append(_card_opt(_opt(StringName("loot_crate_%d" % int(cv["id"])), "%s · crate · %s" % [c.display_name,
					"free" if free else "Search %d" % bal.crate_cost], {"type": "loot", "card": int(cv["id"])}), c))
	return out


## Weapons (hand or line) an attachment can go on: options with the attach action.
func attach_targets(att: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var st: SeatState = state.seats[human]
	for w: int in st.hand + st.line:
		var c: CardData = card(w)
		if c != null and c.is_weapon():
			out.append(_card_opt(_opt(StringName("attach_%d" % w), "%s (%s)" % [c.display_name, "played row" if st.line.has(w) else "hand"],
					{"type": "attach", "attachment": att, "weapon": w}), c, "Gun to attach to"))
	return out


## Areas a Frag in hand can be thrown into now (legal frag actions).
func frag_areas(inst: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for a: Dictionary in legal():
		if a["type"] == "frag" and int(a["card"]) == inst:
			out.append(StringName(a["area"]))
	return out


## Hand (and, with hold_looted, line) cards that may be held at Pack: in some legal end_turn.
func holdable() -> Array[int]:
	var out: Array[int] = []
	for a: Dictionary in legal():
		if a["type"] == "end_turn":
			for x: Variant in a.get("hold", []):
				if not out.has(int(x)):
					out.append(int(x))
	return out


## "" when this hold set is legal at End turn, else why not.
func hold_reason(hold: Array) -> String:
	var a: Dictionary = {"type": "end_turn", "hold": hold}
	var why: String = why_not(a)
	if why == "" or hold.is_empty():
		return why
	var last: int = int(hold.back())
	var c: CardData = card(last)
	if c != null and c.is_hit():
		return "A Hit is never held: it goes under your loadout."
	var limit: int = state.data.balance.hold_limit
	if hold.size() > limit:
		return "You can hold at most %d card%s. Tap a held card to let it go." % [limit, "" if limit == 1 else "s"]
	if not state.seats[human].hand.has(last):
		return "Only cards still in your hand can be held."
	return why


func hold_limit() -> int:
	return state.data.balance.hold_limit if state != null else 2


## cz-clarity: a loot / attach row names what the card gives on a second line, and carries the
## card id so a long press / right click on the row opens the card in the inspector.
func _card_opt(o: Dictionary, c: CardData, where: String = "Loot") -> Dictionary:
	if c == null:
		return o
	o["card_id"] = c.id
	o["where"] = where
	var what: String = CardWords.short(c)
	if what != "":
		o["label"] = "%s\n%s" % [o["label"], what.left(1).to_upper() + what.substr(1)]
	return o


func _opt(key: StringName, label: String, action: Dictionary) -> Dictionary:
	return {"key": key, "label": label, "action": action, "reason": why_not(action)}


func _attach_option(att: int) -> Dictionary:
	var o: Dictionary = {"key": &"attach", "label": "ATTACH…", "action": {}, "reason": ""}
	var targets: Array[Dictionary] = attach_targets(att)
	if targets.is_empty():
		o["reason"] = "No weapon in your hand or line to attach %s to." % card(att).display_name
	else:
		var any: bool = false
		for t: Dictionary in targets:
			any = any or t["reason"] == ""
		if not any:
			o["reason"] = targets[0]["reason"]
	return o


# --- The loop -----------------------------------------------------------------------------

func _run(first: ActionResult) -> void:
	_run_id += 1
	var id: int = _run_id
	if not busy:
		busy = true
		busy_changed.emit(true)
	var r: ActionResult = first
	while true:
		if r != null:
			_after_apply(r)
			_hotseat_record(r)  # cz14
			_store_save()
			# Pace the steps while the rival is involved (its action, or the human's last one before
			# the rival decides); the human's own actions answer at once. cz14: in hot-seat every
			# action is a present human's own: no pacing, no rival phase (the cover comes next).
			var paced: bool = not hotseat and (r != first or (not state.is_over() and state.deciding_seat() != human))
			if not hotseat and not state.is_over() and state.deciding_seat() != human:
				_set_phase(PHASE_OPPONENT)  # the rival's part starts with these events
			_emit_view()
			for e: Dictionary in r.events_for(human):
				var step: Dictionary = _announce(e, paced)
				if paced and not step.is_empty() and is_inside_tree():
					if not await _play_step(step, id):
						return
				if paused and not await _wait_unpaused(id):
					return
		r = null
		if state.is_over():
			break
		var d: int = state.deciding_seat()
		if d == human:
			break
		if hotseat:
			_cover_up(d)  # cz14: the other human decides next: pass the device
			break
		_set_phase(PHASE_OPPONENT)
		var think: float = 0.0 if playback_skip else opponent_delay * (FAST_FACTOR if playback_fast else 1.0)
		if think > 0.0 and is_inside_tree():
			if not await _wait_for(think, id):
				return
		if paused and not await _wait_unpaused(id):
			return
		if state.is_over() or state.deciding_seat() != d:
			continue
		var a: Dictionary = opponent.call("choose_action", state, d) if opponent != null else {}
		if not a.is_empty():
			r = LoadoutRules.apply(state, a)
		if r == null or not r.ok:
			push_warning("MatchController: opponent action %s refused (%s); taking the first legal one" % [a, r.error if r != null else &"none"])
			var options: Array[Dictionary] = LoadoutRules.legal_actions(state)
			if options.is_empty():
				push_error("MatchController: the opponent has no legal action")
				break
			r = LoadoutRules.apply(state, options[0])
	busy = false
	var skipped: bool = playback_skip or _skipped_any
	playback_fast = false
	playback_skip = false
	_skipped_any = false
	_set_phase(_phase_now())
	_emit_view()
	if hotseat:
		_rival_steps.clear()  # cz14: the next seat hears what happened after its cover (reveal)
	if not _rival_steps.is_empty():
		var steps: Array = _rival_steps.duplicate()
		_rival_steps.clear()
		playback_finished.emit(summary_of(steps), steps, skipped or event_delay <= 0.0)
	if phase == PHASE_BRACE:
		brace_suggested.emit(brace_suggestion())
	busy_changed.emit(false)
	settled.emit()


## Waits one step's time (and any game-feel holds). False when the run was replaced.
func _play_step(step: Dictionary, id: int) -> bool:
	if float(step["duration"]) > 0.0 and not await _wait_for(float(step["duration"]), id):
		return false
	var hold_until: int = Time.get_ticks_msec() + int(HOLD_CAP_S * 1000.0)  # cz17: a hold never stalls a match
	while _holds > 0 and not playback_skip and is_inside_tree() and Time.get_ticks_msec() < hold_until:
		await get_tree().process_frame
		if id != _run_id:
			return false
	return id == _run_id and is_inside_tree()


## Waits `seconds` of wall-clock time (at least one frame), sped up live by FAST and cut short by
## SKIP. False when the run was replaced or the screen left the tree.
func _wait_for(seconds: float, id: int) -> bool:
	var left_us: float = seconds * 1000000.0
	var last: int = Time.get_ticks_usec()
	while true:
		await get_tree().process_frame
		if id != _run_id or not is_inside_tree():
			return false
		var now: int = Time.get_ticks_usec()
		left_us -= float(now - last) / (FAST_FACTOR if playback_fast else 1.0)
		last = now
		if left_us <= 0.0 or playback_skip:
			return true
		while paused and is_inside_tree():
			await get_tree().process_frame
			if id != _run_id:
				return false
			last = Time.get_ticks_usec()
	return true


## "Rival's turn: moved to Quarry, looted Crowbar, fired Hunting Rifle (2 damage), packed (1 held)."
func summary_of(steps: Array) -> String:
	var parts: PackedStringArray = []
	var plays: int = 0
	for s: Dictionary in steps:
		var e: Dictionary = s["event"]
		match StringName(s["kind"]):
			&"move":
				parts.append("moved to %s" % ActionText.area_name(e.get("to", "")))
			&"loot":
				parts.append("looted %s" % ActionText.card_name(e.get("card_id", "")))
			&"play":
				plays += 1
			&"shot":
				if e["type"] == "frag_thrown":
					parts.append("threw a Frag into %s" % ActionText.area_name(e.get("area", "")))
				else:
					parts.append("fired %s (%d damage)" % [ActionText.card_name(e.get("weapon_id", "")), int(e.get("damage", 0))])
			&"brace":
				if int(e.get("seat", -1)) == rival_seat():
					parts.append("braced %d" % int(e.get("total", 0)))
			&"pack":
				if int(e.get("seat", -1)) == rival_seat():
					parts.append("packed (%d held)" % int(e.get("held_count", 0)))
	if plays > 0:
		parts.insert(0, "played %d card%s" % [plays, "" if plays == 1 else "s"])
	if parts.is_empty():
		return ""
	return "Rival's turn: %s." % ", ".join(parts)


## cz13: waits while `paused`. False when this run was replaced or the screen left the tree.
func _wait_unpaused(id: int) -> bool:
	while paused and is_inside_tree():
		await get_tree().process_frame
		if id != _run_id:
			return false
	return id == _run_id and is_inside_tree()


func _store_save() -> void:
	if not save_enabled or state == null:
		return
	var store: Node = _store()
	if store == null:
		return
	if state.is_over():
		store.call("clear")  # concede or match end: nothing to resume
	else:
		store.call("save", state, meta)


func _store_clear() -> void:
	var store: Node = _store()
	if save_enabled and store != null:
		store.call("clear")


func _store() -> Node:
	return get_node_or_null("/root/MatchStore") if is_inside_tree() else null


func _after_apply(r: ActionResult) -> void:
	for e: Dictionary in r.events:
		match String(e["type"]):
			"packed":
				if int(e["seat"]) == rival_seat():
					rival_last_line.clear()
					for inst: Variant in e.get("line_stowed", []):
						rival_last_line.append(state.card_id(int(inst)))
				else:
					undo_count = 0
			"turn_started":
				_turn_index += 1


## Announces one event; returns its playback step ({} for an event without words).
func _announce(e: Dictionary, paced: bool = false) -> Dictionary:
	var text: String = ActionText.describe(e, human)
	var step: Dictionary = {}
	if text != "":
		log_lines.append(text)
		step = _step_for(e, text, paced)
		if bool(step["rival"]):
			_rival_steps.append(step)
		playback_step.emit(step)
		event_shown.emit(text, e)
	EventBus.rules_event.emit(e)
	match String(e["type"]):
		"round_started":
			EventBus.round_started.emit(int(e["round"]))
		"turn_started":
			EventBus.turn_started.emit(int(e["seat"]), _turn_index)
		"brace_requested":
			EventBus.brace_requested.emit(int(e["seat"]), int(e["damage"]))
		"hits_landed":
			if int(e["seat"]) >= 0 and int(e["seat"]) < 2:
				hits_landed[int(e["seat"])] += int(e.get("count", 0))
			var shot: Dictionary = view().get("last_shot", {})
			var shooter: int = int(shot.get("shooter", -1))
			var cid: StringName = StringName(str((shot.get("weapon", shot.get("card", {})) as Dictionary).get("card", "")))
			EventBus.shot_resolved.emit(shooter, int(e["seat"]), cid, int(e["count"]))
		"match_ended":
			EventBus.match_ended.emit(int(e.get("winner", -1)), StringName(str(e.get("cause", ""))),
					state.round_number, (Time.get_ticks_msec() - _started_ms) / 1000.0)
	return step


const _STEP_KIND: Dictionary = {"moved": &"move", "dropped": &"move", "looted": &"loot", "played": &"play",
		"adrenaline": &"play", "attached": &"play", "patched_up": &"play", "ditched": &"play", "healed": &"play",
		"spent": &"play", "pulled": &"play", "shot_declared": &"shot", "frag_thrown": &"shot",
		"brace_requested": &"brace", "braced": &"brace", "hits_landed": &"hits", "gas_hit": &"hits",
		"bounty_claimed": &"hits", "packed": &"pack", "turn_started": &"turn", "drew": &"draw",
		"round_started": &"round", "bounty_changed": &"round", "zone_flipped": &"zone", "gas_closed": &"zone",
		"drop_landed": &"zone", "final_circle": &"zone", "crate_formed": &"zone", "eliminated": &"out",
		"match_ended": &"out", "conceded": &"out"}


## One playback step: {index, type, kind, seat, rival, text, event, from, to, duration (seconds the
## loop will wait on it; 0 = it answers at once)}. Areas are
## public (both seats' areas are in the view); the event is already filtered for the human.
func _step_for(e: Dictionary, text: String, paced: bool) -> Dictionary:
	_step_index += 1
	var t: String = String(e.get("type", ""))
	var kind: StringName = _STEP_KIND.get(t, &"other")
	var seat: int = int(e.get("seat", -1))
	var from: StringName = &""
	var to: StringName = &""
	match t:
		"moved":
			from = StringName(str(e.get("from", "")))
			to = StringName(str(e.get("to", "")))
		"dropped", "looted":
			to = StringName(str(e.get("area", "")))
		"shot_declared":
			from = state.seats[seat].area
			to = state.seats[int(e.get("target", 1 - seat))].area
		"frag_thrown":
			from = state.seats[seat].area
			to = StringName(str(e.get("area", "")))
	if t == "turn_started":
		_in_rival_turn = seat == rival_seat()
	var rival: bool = _in_rival_turn or (seat == rival_seat() and state.phase == MatchState.PHASE_DROP)
	if t == "match_ended":
		_in_rival_turn = false
	return {"index": _step_index, "type": t, "kind": kind, "seat": seat, "rival": rival, "text": text,
			"event": e, "from": from, "to": to,
			"duration": step_duration(kind) if paced and is_inside_tree() else 0.0}


# --- Playtest log hooks (cz18, additive: EventBus emits only, no behaviour change) -----------

## view_changed plus EventBus.match_view_changed with the same human view.
func _emit_view() -> void:
	var v: Dictionary = view()
	view_changed.emit(v)
	EventBus.match_view_changed.emit(v)


## EventBus.match_context: the match's setup facts (public or the human's own; see EventBus).
func _emit_context() -> void:
	var b: BalanceConfig = state.data.balance
	EventBus.match_context.emit({
		"resumed": not _resume_info.is_empty(), "age_s": float(_resume_info.get("age_s", -1.0)),
		"mode": String(meta.get("mode", "ai")), "ai_level": String(meta.get("ai_level", "")),
		"human_seat": MatchState.P1 if hotseat else human, "first_seat": MatchState.P1, "route": MatchState.route_letter(state.route),
		"hand_size": b.hand_size, "tunables_hash": b.tunables_hash(), "tunables": b.snapshot(),
		"actions": state.actions.size(), "round": state.round_number,
	})
	_resume_info = {}


## Seconds since the resumed match was saved (resumed.saved_at, else MatchStore's save header),
## -1 when unknown.
func _save_age_s(resumed: Dictionary) -> float:
	var saved_at: int = int(resumed.get("saved_at", -1))
	var store: Node = _store()
	if saved_at < 0 and store != null and store.get("_body") is Dictionary:
		saved_at = int((store.get("_body") as Dictionary).get("saved_at", -1))
	if saved_at <= 0:
		return -1.0
	return maxf(0.0, Time.get_unix_time_from_system() - saved_at)


func _set_phase(p: StringName) -> void:
	if p == phase:
		return
	phase = p
	phase_changed.emit(p)


func _phase_now() -> StringName:
	if state == null:
		return PHASE_IDLE
	if state.is_over():
		return PHASE_OVER
	if is_covered():
		return PHASE_COVER  # cz14
	if state.deciding_seat() != human:
		return PHASE_OPPONENT
	if state.phase == MatchState.PHASE_DROP:
		return PHASE_DROP
	if state.pending_brace_seat() == human:
		return PHASE_BRACE
	return PHASE_ACT


func _own(action: Dictionary) -> Dictionary:
	var a: Dictionary = action.duplicate(true)
	a["seat"] = human
	return a


func _undo_reason() -> String:
	if LoadoutRules.check(state, {"type": "undo", "seat": human}) == &"":
		return ""
	if state.deciding_seat() != human:
		return "It's the rival's turn: nothing of yours to undo."
	if state.pending_brace_seat() == human:
		return "A Brace can't be undone. Choose your Brace cards, then BRACE."
	if state.phase == MatchState.PHASE_DROP:
		return "The drop can't be undone."
	if not state.seats[human].fired.is_empty():
		return "You fired this turn: a declared shot commits everything before it, so undo stops there."
	return "Nothing to undo: your turn's draw is fixed."


## Numbers for the words in ActionText.reason (the human's own cards and public data only).
func _context(a: Dictionary) -> Dictionary:
	var st: SeatState = state.seats[human]
	var bal: BalanceConfig = state.data.balance
	var ctx: Dictionary = {"here": st.area, "have": st.search, "limit": bal.hold_limit,
			"min_loadout": bal.min_loadout, "cap": bal.adrenaline_cap_per_turn}
	for key: String in ["card", "weapon", "attachment"]:
		if a.has(key) and int(a[key]) > 0 and state.defs.has(int(a[key])) and _visible(int(a[key])):
			ctx["name"] = card(int(a[key])).display_name
	match String(a["type"]):
		"move":
			ctx["to"] = String(a.get("to", ""))
			if state.data.has_area(StringName(ctx["to"])):
				ctx["dist"] = state.data.distance(st.area, StringName(ctx["to"]))
		"loot":
			ctx["cost"] = _loot_cost(a)
		"patch_up":
			ctx["cost"] = LoadoutRules.PATCH_UP_COST
		"ditch":
			ctx["cost"] = LoadoutRules.DITCH_COST
			ctx["limit"] = bal.ditch_limit()
		"shoot":
			var w: int = int(a.get("weapon", 0))
			if st.line.has(w):
				ctx["range"] = LoadoutRules.weapon_range(state, w)
				ctx["fires"] = LoadoutRules.fire_limit(state, w)
			ctx["dist"] = state.data.distance(st.area, state.seats[rival_seat()].area)
		"frag":
			var f: int = int(a.get("card", 0))
			if st.hand.has(f):
				ctx["range"] = maxi(card(f).blast_rng, 0)
			if state.data.has_area(StringName(String(a.get("area", "")))):
				ctx["dist"] = state.data.distance(st.area, StringName(String(a["area"])))
	return ctx


## Only the human's own cards and the rival's line (public) are named.
func _visible(inst: int) -> bool:
	var st: SeatState = state.seats[human]
	if st.hand.has(inst) or st.line.has(inst) or st.loadout.has(inst):
		return true
	return state.seats[rival_seat()].line.has(inst)


func _loot_cost(a: Dictionary) -> int:
	var bal: BalanceConfig = state.data.balance
	if a.has("pile"):
		var c: CardData = CardDB.get_card(StringName(str(a["pile"])))
		return c.cost if c != null else 0
	var inst: int = int(a.get("card", 0))
	if (state.drops.get(state.seats[human].area, []) as Array).has(inst):
		return bal.supply_drop_cost
	for cr: Dictionary in state.crates:
		if (cr["cards"] as Array).has(inst):
			return 0 if (int(cr["free_picks"]) > 0 and int(cr["picker"]) == human) else bal.crate_cost
	return 0


# --- Hot-seat (cz14) --------------------------------------------------------------------------
# Two humans pass one device (spec §16.3 S1/S2: Player 1 is P1; Player 2 picks the route in
# setup and drops first). `human` is the seat on screen. Whenever the deciding seat changes (its
# turn, its drop, the defender's Brace) the loop stops behind the cover: cover_changed(true) goes
# out BEFORE anything of the next seat is shown, `phase` is PHASE_COVER, view() is the covered
# view (no hand, next hand, loadout, held cards, Brace prompt or shot preview: only what both
# seats see) and every request but concede is refused. The tap calls reveal(): the seat's own
# view(state, seat) goes out, then cover_changed(false), then a one-line summary of what the other
# seat did meanwhile (playback_finished, built from events_for(seat) only), then settled.
# Saves: meta {mode: "hotseat", human_seat: the seat on screen, cover_seat while a cover is
# pending}. A resumed hot-seat match always starts behind the cover of the deciding seat, so a
# match saved at a pending cover or Brace resumes at that cover.

## True while the hot-seat cover is up.
func is_covered() -> bool:
	return hotseat and cover_seat >= 0


## {seat, player (1/2), from_player, reason (&"drop" | &"brace" | &"start" | &"turn"), round, covered}.
func cover_info() -> Dictionary:
	if state == null:
		return {}
	var seat: int = cover_seat if cover_seat >= 0 else human
	var reason: StringName = &"turn"
	if state.phase == MatchState.PHASE_DROP:
		reason = &"drop"
	elif state.pending_brace_seat() == seat:
		reason = &"brace"
	elif state.actions.is_empty():
		reason = &"start"
	return {"seat": seat, "player": seat + 1, "from_player": 2 - seat, "reason": reason,
			"round": state.round_number, "covered": is_covered()}


## The tap on the cover: shows the covered seat its own view. No-op without a cover.
func reveal() -> void:
	if not is_covered() or busy or state == null:
		return
	var seat: int = cover_seat
	cover_seat = -1
	meta.erase("cover_seat")
	if not state.actions.is_empty():
		_store_save()
	var steps: Array = []
	for batch: Variant in _unseen[seat]:
		for e: Dictionary in batch:
			var text: String = ActionText.describe(e, seat)
			if text == "":
				continue
			log_lines.append(text)
			var t: String = String(e.get("type", ""))
			steps.append({"type": t, "kind": _STEP_KIND.get(t, &"other"), "seat": int(e.get("seat", -1)),
					"rival": true, "text": text, "event": e})
	_unseen[seat] = []
	_set_phase(_phase_now())
	_emit_view()
	cover_changed.emit(false, cover_info())
	if not steps.is_empty():
		var summary: String = catch_up_summary(steps)
		playback_finished.emit(summary, steps, true)
	if phase == PHASE_BRACE:
		brace_suggested.emit(brace_suggestion())
	settled.emit()


## "Player 1: dropped into Quarry, fired P-9 Sidearm (2 damage), packed (1 held)." ("" = nothing).
func catch_up_summary(steps: Array) -> String:
	var parts: PackedStringArray = []
	var rest: Array = []
	for s: Dictionary in steps:
		if String(s["type"]) == "dropped" and int(s["seat"]) == rival_seat():
			parts.append("dropped into %s" % ActionText.area_name((s["event"] as Dictionary).get("area", "")))
		else:
			rest.append(s)
	var body: String = summary_of(rest).trim_prefix("Rival's turn: ").trim_suffix(".")
	if body != "":
		parts.append(body)
	if parts.is_empty():
		return ""
	return "Player %d: %s." % [rival_seat() + 1, ", ".join(parts)]


func _hotseat_begin() -> void:
	cover_seat = -1
	_unseen = [[], []]
	_seat_logs = [PackedStringArray(), PackedStringArray()]
	_last_lines = [[], []]
	if not hotseat:
		return
	opponent = null  # never asked: both seats are human
	if state != null and not state.is_over():
		_cover_up(state.deciding_seat())


## Raises the cover for `seat` (which becomes the seat on screen once revealed).
func _cover_up(seat: int) -> void:
	_seat_logs[human] = log_lines.duplicate()
	human = seat
	meta["human_seat"] = seat
	meta["cover_seat"] = seat
	log_lines = (_seat_logs[seat] as PackedStringArray).duplicate()
	rival_last_line.assign(_last_lines[rival_seat()])
	_suggestion_key = ""
	_suggestion = {}
	cover_seat = seat
	if not state.actions.is_empty():
		_store_save()  # the save records the pending cover (meta.cover_seat)
	cover_changed.emit(true, cover_info())


## After each applied action: the other seat's unseen events (an undo takes back the last
## batch), public last lines, and no cover once the match is over.
func _hotseat_record(r: ActionResult) -> void:
	if not hotseat:
		return
	for e: Dictionary in r.events:
		if String(e["type"]) == "packed":
			var ids: Array = []
			for inst: Variant in e.get("line_stowed", []):
				ids.append(state.card_id(int(inst)))
			_last_lines[int(e["seat"])] = ids
	var other: int = 1 - human
	if String(r.action.get("type", "")) == "undo":
		if not (_unseen[other] as Array).is_empty():
			(_unseen[other] as Array).pop_back()
	else:
		(_unseen[other] as Array).append(r.events_for(other))
	if state.is_over() and cover_seat >= 0:
		cover_seat = -1
		meta.erase("cover_seat")
		cover_changed.emit(false, cover_info())


## view(state, human) with every seat-private part left out (the cover is up).
func _covered_view() -> Dictionary:
	var v: Dictionary = LoadoutRules.view(state, human)
	var me: Dictionary = v["me"]
	for key: String in ["loadout", "held", "next_draw", "next_hand", "hand"]:
		me[key] = []
	v.erase("brace_prompt")
	v.erase("shot_preview")
	v["covered"] = true
	return v
