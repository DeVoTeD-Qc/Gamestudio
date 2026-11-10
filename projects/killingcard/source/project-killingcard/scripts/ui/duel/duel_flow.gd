# duel_flow.gd
# Purpose: kc-duel-ui. Hand-off between the Duel screens (static state, like run_flow.gd for the run):
#   the deck the builder edits, the match setup the hub starts (vs AI: your deck, the opponent preset,
#   the tier; Pass & Play: both decks and names), and the last result for the result screen.
#   start_match() asks the rules for the MatchState (DuelRules.create_match(setup), duel-api.md) and
#   opens Match.tscn; match_controller.gd takes it with take_pending() and reports with finish().
# Dependencies: duel_views.gd, run_flow.gd (goto), SceneRouter.
# Author: UI/UX Agent (kc-duel-ui)
extends RefCounted

const DuelViews: GDScript = preload("res://scripts/ui/duel/duel_views.gd")
const RunFlow: GDScript = preload("res://scripts/ui/run/run_flow.gd")

const SCENE_HUB: String = "res://scenes/duel/DuelHub.tscn"
const SCENE_BUILDER: String = "res://scenes/duel/DeckBuilder.tscn"
const SCENE_RESULT: String = "res://scenes/duel/DuelResult.tscn"
const SCENE_MATCH: String = "res://scenes/Match.tscn"
const SCENE_TITLE: String = "res://scenes/Title.tscn"

const MODE_VS_AI: StringName = &"vs_ai"
const MODE_HOT_SEAT: StringName = &"hot_seat"

## The deck the builder opens (a copy; {} = a new deck).
static var edit_deck: Dictionary = {}
## Where the builder goes back to.
static var builder_return: String = SCENE_HUB
## The match the hub set up: {mode, decks: [deck0, deck1], names: [String, String], tier, opponent_id,
## seed, open_pool}.
static var setup: Dictionary = {}
## The MatchState waiting for Match.tscn (null = none).
static var pending: Object = null
## The duel Match.tscn is playing (set by take_pending, cleared by finish).
static var active: Object = null
## The last finished duel: {mode, result (&"win"/&"loss"/&"draw" for seat 0), winner_name, score: [a, b],
## rounds, reason, names, decks, tier, opponent_id, lines: PackedStringArray}.
static var last_result: Dictionary = {}
## Hub tab to open on ("mine" / "presets").
static var hub_tab: String = "mine"


static func goto(path: String) -> void:
	RunFlow.goto(path)


static func open_builder(deck: Dictionary, back_to: String = SCENE_HUB) -> void:
	edit_deck = deck.duplicate(true)
	builder_return = back_to
	goto(SCENE_BUILDER)


## Builds the match from `p_setup` with the rules and opens the match screen. {ok, text}.
static func start_match(p_setup: Dictionary) -> Dictionary:
	setup = p_setup.duplicate(true)
	if not setup.has("seed"):
		setup["seed"] = int(Time.get_unix_time_from_system()) % 1000000007
	var decks: Array = setup.get("decks", [])
	for d: Variant in decks:
		var r: Dictionary = DuelViews.validate(d, bool((d as Dictionary).get("preset", false)) or bool(setup.get("open_pool", false)))
		if not bool(r["ok"]):
			return {"ok": false, "text": "%s: %s" % [(d as Dictionary).get("name", "Deck"), r["errors"][0]["text"]]}
	var rules_setup: Dictionary = setup.duplicate(true)
	rules_setup["decks"] = decks.map(func(d: Variant) -> Dictionary: return DuelViews.to_rules(d))
	var m: Variant = DuelViews._ask(&"create_match", [rules_setup])
	if not m is Object:
		pending = null
		return {"ok": false, "text": "Duel matches need the rules (DuelRules.create_match): not in this build yet."}
	pending = m
	goto(SCENE_MATCH)
	return {"ok": true, "text": ""}


## Match.tscn: the duel waiting to be played (once). null = not a duel.
static func take_pending() -> Object:
	var m: Object = pending
	pending = null
	if m != null:
		active = m
	return m


static func is_duel(m: Object) -> bool:
	return m != null and m == active


static func is_hot_seat() -> bool:
	return StringName(str(setup.get("mode", ""))) == MODE_HOT_SEAT


## Player names for the seats (["You", "<opponent preset>"] vs AI).
static func names() -> PackedStringArray:
	var n: Array = setup.get("names", [])
	var out: PackedStringArray = []
	for i: int in 2:
		out.append(String(n[i]) if i < n.size() and String(n[i]) != "" else ("Player %d" % (i + 1)))
	return out


## Match.tscn: the duel is over. Notes the record and opens the result screen.
static func finish(result: Dictionary) -> void:
	active = null
	last_result = result.duplicate(true)
	last_result["mode"] = setup.get("mode", MODE_VS_AI)
	last_result["names"] = names()
	last_result["decks"] = setup.get("decks", [])
	last_result["tier"] = setup.get("tier", &"")
	last_result["opponent_id"] = setup.get("opponent_id", "")
	if StringName(str(last_result["mode"])) == MODE_VS_AI:
		var decks: Array = setup.get("decks", [{}, {}])
		DuelViews.note_result(StringName(str(result.get("result", "draw"))), StringName(str((decks[0] as Dictionary).get("hero", ""))),
				String(setup.get("opponent_id", "")), StringName(str(setup.get("tier", ""))))
	goto(SCENE_RESULT)


## The result screen's REMATCH: the same setup, a new seed.
static func rematch() -> Dictionary:
	var s: Dictionary = setup.duplicate(true)
	s.erase("seed")
	return start_match(s)
