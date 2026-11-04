# setup_launch.gd
# Purpose: How a CardZone match is started from the shell (cz13): Title (CONTINUE), Match setup
#   (START) and the end screen (NEW MATCH) leave a launch request, the match screen picks it up
#   and begin(controller) starts the match on the cz11 MatchController.
#     request_new(choices)  a new match: {opponent, first, route} (see OPPONENTS, FIRSTS, ROUTES)
#     request_again()       a new match with the last choices (Alternate and Pick-for-me advance)
#     request_resume()      the saved match (MatchStore.resume())
#   The request lives in Engine metadata, so it survives the scene change without an autoload.
# Rules applied here (spec §16.3):
#   S1 first player: Me = the human is P1; Opponent = the human is P2; Alternate = swap from the
#      last match on this device (the first match ever: the human is P1). P1 takes the first turn;
#      P2 drops first (the controller and the rules engine do the drop as cz11 does).
#   S2 route: vs the AI the human picks A, B or C, or Pick for me = A, B, C in rotation per match on
#      this device, starting with A.
#   Hot-seat (cz14): two humans, one device, no AI. S1: Player 1 is P1 (FIRST TURN does not
#      apply and Alternate does not advance); S2: Player 2 picks the route in setup (A, B, C or
#      Pick for me) and drops first. meta {mode: "hotseat", ai_level: "", human_seat: P1}; the
#      controller then shows only the deciding seat's view, behind a cover at every seat change.
#   Dev panel overrides (dev_panel_overrides.gd) apply to new matches only; a resumed match keeps
#   its saved balance.
# Opponent: CzAI.for_level(level, seed) (cz09), loaded at run time so a broken AI script can't
#   stop the shell; if it does not load, the cz11 placeholder plays and ai_fallback_reason() says why.
# Dependencies: MatchState, RulesData, CardDB, MatchStore, opponent_placeholder.gd, setup_prefs.gd,
#   dev_panel_overrides.gd, scripts/ai/cz_ai.gd (optional).
# Author: UI/UX Agent (cz13)
extends RefCounted

const SetupPrefs: GDScript = preload("res://scripts/ui/setup_prefs.gd")
const DevOverrides: GDScript = preload("res://scripts/ui/dev_panel_overrides.gd")
const OpponentPlaceholder: GDScript = preload("res://scripts/match/opponent_placeholder.gd")

const AI_SCRIPT: String = "res://scripts/ai/cz_ai.gd"
const META_KEY: StringName = &"cz_launch"

const OPPONENTS: Array[String] = ["rookie", "veteran", "hotseat"]
const FIRSTS: Array[String] = ["me", "opponent", "alternate"]
const ROUTES: Array[String] = ["A", "B", "C", "rotate"]
const DEFAULT_CHOICES: Dictionary = {"opponent": "rookie", "first": "alternate", "route": "rotate"}

static var _ai_fallback: String = ""


# --- Requests -------------------------------------------------------------------------------

static func request_new(choices: Dictionary) -> void:
	Engine.set_meta(META_KEY, {"kind": "new", "choices": normalize(choices)})


static func request_again() -> void:
	request_new(last_choices())


static func request_resume() -> void:
	Engine.set_meta(META_KEY, {"kind": "resume"})


static func has_pending() -> bool:
	return Engine.has_meta(META_KEY)


static func pending() -> Dictionary:
	return Engine.get_meta(META_KEY, {}) if has_pending() else {}


static func clear_pending() -> void:
	if Engine.has_meta(META_KEY):
		Engine.remove_meta(META_KEY)


# --- Choices --------------------------------------------------------------------------------

## The choices the setup screen opens with: the last ones used on this device.
static func last_choices() -> Dictionary:
	var c: Dictionary = {}
	for key: String in DEFAULT_CHOICES.keys():
		c[key] = SetupPrefs.get_value("setup", key, DEFAULT_CHOICES[key])
	return normalize(c)


## Unknown values fall back to the defaults.
static func normalize(choices: Dictionary) -> Dictionary:
	var c: Dictionary = DEFAULT_CHOICES.duplicate()
	if OPPONENTS.has(String(choices.get("opponent", ""))):
		c["opponent"] = String(choices["opponent"])
	if FIRSTS.has(String(choices.get("first", ""))):
		c["first"] = String(choices["first"])
	if ROUTES.has(String(choices.get("route", ""))):
		c["route"] = String(choices["route"])
	return c


## "" when the choices can start a match, else why not (in words).
static func why_not(choices: Dictionary) -> String:
	return ""


## cz14: true when the choices are a hot-seat match (two humans, one device).
static func is_hotseat(choices: Dictionary) -> bool:
	return String(normalize(choices)["opponent"]) == "hotseat"


## What the choices mean for the next match: {human_seat, route (DataEnums.Route), route_letter,
## ai_level}. Does not change anything on the device (see _commit).
static func resolve(choices: Dictionary) -> Dictionary:
	var c: Dictionary = normalize(choices)
	var seat: int = MatchState.P1
	var first: String = "me" if is_hotseat(c) else String(c["first"])  # cz14 S1: Player 1 is P1
	match first:
		"opponent":
			seat = MatchState.P2
		"alternate":
			var last: Variant = SetupPrefs.get_value("setup", "last_human_seat", null)
			seat = MatchState.P1 if last == null else 1 - int(last)
	var letter: String = String(c["route"])
	if letter == "rotate":
		letter = String(SetupPrefs.get_value("setup", "next_route", "A"))
		if not ["A", "B", "C"].has(letter):
			letter = "A"
	return {"human_seat": seat, "route": MatchState.route_from_letter(letter), "route_letter": letter,
			"ai_level": "" if is_hotseat(c) else String(c["opponent"]), "hotseat": is_hotseat(c)}


## Text for the setup screen's "next match" line.
static func preview_text(choices: Dictionary) -> String:
	var r: Dictionary = resolve(choices)
	if bool(r["hotseat"]):
		return "Next match: hot-seat, route %s (Player 2 picks it), Player 2 drops first, Player 1 takes the first turn." % r["route_letter"]
	var first: String = "you take the first turn" if int(r["human_seat"]) == MatchState.P1 \
			else "the rival takes the first turn (you drop first)"
	return "Next match: route %s, %s." % [r["route_letter"], first]


static func _commit(choices: Dictionary, resolved: Dictionary) -> void:
	var c: Dictionary = normalize(choices)
	for key: String in c.keys():
		SetupPrefs.set_value("setup", key, c[key])
	if not bool(resolved.get("hotseat", false)):  # cz14: hot-seat leaves the vs-AI Alternate alone
		SetupPrefs.set_value("setup", "last_human_seat", int(resolved["human_seat"]))
	if String(c["route"]) == "rotate":
		var i: int = "ABC".find(String(resolved["route_letter"]))
		SetupPrefs.set_value("setup", "next_route", "ABC"[(i + 1) % 3])
	SetupPrefs.set_value("setup", "matches_started", int(SetupPrefs.get_value("setup", "matches_started", 0)) + 1)


# --- Starting -------------------------------------------------------------------------------

## Starts the pending request on a MatchController. "" when a match started, else why not
## (nothing pending, hot-seat, or a save that can't be resumed: MatchStore.status_text()).
static func begin(ctrl: Node) -> String:
	var req: Dictionary = pending()
	clear_pending()
	if req.is_empty():
		return "No match was requested."
	if String(req.get("kind", "")) == "resume":
		return _begin_resume(ctrl)
	return _begin_new(ctrl, req.get("choices", {}))


static func _begin_new(ctrl: Node, choices: Dictionary) -> String:
	var why: String = why_not(choices)
	if why != "":
		return why
	var db: Node = _autoload("CardDB")
	var r: Dictionary = resolve(choices)
	var errors: Array = []
	var content: RulesData = RulesData.from_card_db(db).with_balance(DevOverrides.overrides(), errors)
	if not errors.is_empty():
		push_warning("SetupLaunch: dev overrides refused: %s" % ", ".join(errors))
	var ai_seed: int = int(Time.get_unix_time_from_system()) % 1000000
	if bool(r["hotseat"]):
		return _begin_hotseat(ctrl, choices, r, content)
	ctrl.set("opponent", make_opponent(String(r["ai_level"]), ai_seed))
	var store: Node = _autoload("MatchStore")
	if store != null and bool(ctrl.get("save_enabled")):
		store.call("clear")
	_commit(choices, r)
	var meta: Dictionary = {"mode": "ai", "ai_level": String(r["ai_level"]) if _ai_fallback == "" else "placeholder",
			"ai_seed": ai_seed, "human_seat": int(r["human_seat"])}
	ctrl.call("start_from", MatchState.new_match(content, int(r["route"])), meta)
	return ""


static func _begin_resume(ctrl: Node) -> String:
	var store: Node = _autoload("MatchStore")
	if store == null:
		return "Saving isn't available."
	var resumed: Dictionary = store.call("resume")
	if resumed.is_empty():
		var text: String = String(store.call("status_text"))
		return text if text != "" else "There is no saved match."
	var meta: Dictionary = resumed.get("meta", {})
	if String(meta.get("mode", "ai")) == "hotseat":
		ctrl.set("opponent", null)  # cz14: both seats are human; the controller resumes behind a cover
	else:
		ctrl.set("opponent", make_opponent(String(meta.get("ai_level", "rookie")), int(meta.get("ai_seed", 0))))
	ctrl.call("start_resumed", resumed)
	return ""


## cz14: a new hot-seat match: no AI; Player 1 = P1; P2 (who picked the route) drops first.
static func _begin_hotseat(ctrl: Node, choices: Dictionary, r: Dictionary, content: RulesData) -> String:
	_ai_fallback = ""
	ctrl.set("opponent", null)
	var store: Node = _autoload("MatchStore")
	if store != null and bool(ctrl.get("save_enabled")):
		store.call("clear")
	_commit(choices, r)
	var meta: Dictionary = {"mode": "hotseat", "ai_level": "", "ai_seed": 0, "human_seat": MatchState.P1}
	ctrl.call("start_from", MatchState.new_match(content, int(r["route"])), meta)
	return ""


## The rival for a level: CzAI (cz09) when its script loads, else the cz11 placeholder.
static func make_opponent(level: String, ai_seed: int) -> Object:
	_ai_fallback = ""
	if level == "placeholder":
		return OpponentPlaceholder.new()
	var script: GDScript = load(AI_SCRIPT) as GDScript if ResourceLoader.exists(AI_SCRIPT) else null
	if script == null or not script.can_instantiate():
		_ai_fallback = "the AI script (%s) did not load" % AI_SCRIPT
	else:
		var ai: Object = script.call("for_level", StringName(level), ai_seed)
		if ai != null and ai.has_method("choose_action"):
			return ai
		_ai_fallback = "CzAI.for_level(%s) gave no opponent" % level
	push_warning("SetupLaunch: %s; the placeholder opponent plays." % _ai_fallback)
	return OpponentPlaceholder.new()


## Why the last make_opponent() fell back to the placeholder ("" = the real AI plays).
static func ai_fallback_reason() -> String:
	return _ai_fallback


static func _autoload(node_name: String) -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null(node_name) if loop != null else null
