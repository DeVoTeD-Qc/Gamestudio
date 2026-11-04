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
# Signals: view_changed(view) after every applied action, event_shown(text, event) per event,
#   notice(text) for a refused request, phase_changed(phase), settled() when input is open again.
# Dependencies: LoadoutRules, MatchState, RulesData, MatchView, CardDB, EventBus,
#   action_text.gd, opponent_placeholder.gd.
# Author: UI/UX Agent (cz11)
extends Node

signal view_changed(view: Dictionary)
signal event_shown(text: String, event: Dictionary)
signal notice(text: String)
signal phase_changed(phase: StringName)
signal settled

const ActionText: GDScript = preload("res://scripts/match/action_text.gd")
const OpponentPlaceholder: GDScript = preload("res://scripts/match/opponent_placeholder.gd")

const PHASE_IDLE: StringName = &"idle"
const PHASE_DROP: StringName = &"drop"
const PHASE_ACT: StringName = &"act"
const PHASE_BRACE: StringName = &"brace"
const PHASE_OPPONENT: StringName = &"opponent"
const PHASE_OVER: StringName = &"over"

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

var _run_id: int = 0
var _started_ms: int = 0
var _turn_index: int = 0


func _init() -> void:
	opponent = OpponentPlaceholder.new()


# --- Starting -------------------------------------------------------------------------

## A fresh match from CardDB content at the drop (P2 drops first, then the human as P1).
func start_new(route: int = DataEnums.Route.A) -> void:
	var content: RulesData = RulesData.from_card_db(CardDB)
	start_from(MatchState.new_match(content, route))


## Any state (a new match or a QA fixture mid-turn).
func start_from(s: MatchState) -> void:
	state = s
	log_lines.clear()
	rival_last_line.clear()
	undo_count = 0
	_turn_index = 0
	_started_ms = Time.get_ticks_msec()
	EventBus.match_started.emit(StringName(opponent_kind().to_lower()), MatchState.P1)
	_run(null)


func opponent_kind() -> String:
	if opponent != null and "kind" in opponent:
		return String(opponent.get("kind"))
	return "AI"


func rival_seat() -> int:
	return 1 - human


# --- What the human sees and may do --------------------------------------------------------

func view() -> Dictionary:
	return LoadoutRules.view(state, human) if state != null else {}


## True when the human must decide now (drop, turn or Brace) and nothing is playing out.
func is_human_turn() -> bool:
	return state != null and not busy and not state.is_over() and state.deciding_seat() == human


## The human's legal actions now ([] while the rival decides).
func legal() -> Array[Dictionary]:
	if state == null or state.is_over() or state.deciding_seat() != human:
		return []
	return LoadoutRules.legal_actions(state)


## "" when request(a) would be accepted, else why not (in words).
func why_not(action: Dictionary) -> String:
	if state == null:
		return "No match is running."
	var a: Dictionary = LoadoutRules.normalize(state, _own(action))
	var t: String = a["type"]
	if t != "concede":
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
		out.append(_opt(StringName("loot_" + str(cid)), "%s · Search %d · %d left" % [c.display_name, c.cost, int(piles[cid])],
				{"type": "loot", "pile": str(cid)}))
	for d: Dictionary in v["drops"].get(StringName(here), v["drops"].get(here, [])):
		var c: CardData = CardDB.get_card(StringName(d["card"]))
		out.append(_opt(StringName("loot_drop_%d" % int(d["id"])), "%s · supply drop · Search %d" % [c.display_name, bal.supply_drop_cost],
				{"type": "loot", "card": int(d["id"])}))
	for cr: Dictionary in v["crates"]:
		if String(cr["area"]) != here:
			continue
		var free: bool = int(cr["free_picks"]) > 0 and int(cr["picker"]) == human
		for cv: Dictionary in cr["cards"]:
			var c: CardData = CardDB.get_card(StringName(cv["card"]))
			out.append(_opt(StringName("loot_crate_%d" % int(cv["id"])), "%s · crate · %s" % [c.display_name,
					"free" if free else "Search %d" % bal.crate_cost], {"type": "loot", "card": int(cv["id"])}))
	return out


## Weapons (hand or line) an attachment can go on: options with the attach action.
func attach_targets(att: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var st: SeatState = state.seats[human]
	for w: int in st.hand + st.line:
		var c: CardData = card(w)
		if c != null and c.is_weapon():
			out.append(_opt(StringName("attach_%d" % w), "%s (%s)" % [c.display_name, "line" if st.line.has(w) else "hand"],
					{"type": "attach", "attachment": att, "weapon": w}))
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
	busy = true
	var r: ActionResult = first
	while true:
		if r != null:
			_after_apply(r)
			view_changed.emit(view())
			for e: Dictionary in r.events_for(human):
				_announce(e)
				if event_delay > 0.0 and is_inside_tree():
					await get_tree().create_timer(event_delay).timeout
					if id != _run_id or not is_inside_tree():
						return
		r = null
		if state.is_over():
			break
		var d: int = state.deciding_seat()
		if d == human:
			break
		_set_phase(PHASE_OPPONENT)
		if opponent_delay > 0.0 and is_inside_tree():
			await get_tree().create_timer(opponent_delay).timeout
			if id != _run_id or not is_inside_tree():
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
	_set_phase(_phase_now())
	view_changed.emit(view())
	settled.emit()


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


func _announce(e: Dictionary) -> void:
	var text: String = ActionText.describe(e, human)
	if text != "":
		log_lines.append(text)
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
			var shot: Dictionary = view().get("last_shot", {})
			var shooter: int = int(shot.get("shooter", -1))
			var cid: StringName = StringName(str((shot.get("weapon", shot.get("card", {})) as Dictionary).get("card", "")))
			EventBus.shot_resolved.emit(shooter, int(e["seat"]), cid, int(e["count"]))
		"match_ended":
			EventBus.match_ended.emit(int(e.get("winner", -1)), StringName(str(e.get("cause", ""))),
					state.round_number, (Time.get_ticks_msec() - _started_ms) / 1000.0)


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
