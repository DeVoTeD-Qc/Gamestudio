# duel_flow.gd
# Purpose: kc-duel-ui. Hand-off between the Duel screens (static state, like run_flow.gd for the run):
#   the deck the builder edits, the match setup the hub starts (vs AI: your deck, the opponent preset,
#   the tier; Pass & Play: both decks and names), and the last result for the result screen.
#   start_match() asks DuelState for the match (duel-api.md §5: start_vs_ai / start_hot_seat; the
#   DuelMatch is kept as DuelState.current) and opens Match.tscn; match_controller.gd takes it with
#   take_pending() and reports the end with finish() (DuelState.finish records it, §7).
# Dependencies: duel_views.gd, run_flow.gd (goto).
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
## The match the hub set up: {mode, decks: [deck0, deck1] (screen shape), names: [String, String], tier,
## opponent_id, seed, open_pool}.
static var setup: Dictionary = {}
## The DuelMatch (or, without DuelState, a plain MatchState) waiting for Match.tscn.
static var pending: Object = null
## The duel Match.tscn is playing (set by take_pending, cleared by finish).
static var active: Object = null
## The last finished duel (duel-api.md §6.2 result + records, new_cosmetics, setup).
static var last_result: Dictionary = {}
## Hub state to open on: "mine" / "presets", or "play:<deck id>" (the VS AI setup with that deck).
static var hub_tab: String = "mine"
## Tests: true = start_match() builds the match but doesn't change the scene.
static var dry_run: bool = false


static func goto(path: String) -> void:
	if not dry_run:
		RunFlow.goto(path)


static func open_builder(deck: Dictionary, back_to: String = SCENE_HUB) -> void:
	edit_deck = deck.duplicate(true)
	builder_return = back_to
	goto(SCENE_BUILDER)


## Builds the match from `p_setup` and opens the match screen. {ok, text}.
static func start_match(p_setup: Dictionary) -> Dictionary:
	setup = p_setup.duplicate(true)
	var decks: Array = setup.get("decks", [])
	var seed_value: int = int(setup.get("seed", -1))
	var r: Dictionary = {}
	if StringName(str(setup.get("mode", MODE_VS_AI))) == MODE_HOT_SEAT:
		r = DuelViews.start_hot_seat(decks[0], decks[1], names(), {"open_pool": bool(setup.get("open_pool", false)), "seed": seed_value})
	else:
		r = DuelViews.start_vs_ai(decks[0], StringName(str(setup.get("opponent_id", "random"))), StringName(str(setup.get("tier", "regular"))), seed_value)
	if not bool(r.get("ok", false)):
		pending = null
		return {"ok": false, "text": String(r.get("reason", "The duel could not start."))}
	pending = r["match"] if r.get("match") != null else r.get("state")
	goto(SCENE_MATCH)
	return {"ok": true, "text": ""}


## Match.tscn: the duel waiting to be played (once). null = not a duel. With DuelState it is the
## DuelMatch also kept as DuelState.current (taken there too, so it is played once).
static func take_pending() -> Object:
	var m: Object = pending
	pending = null
	# Only the match this hand-off started (DuelState.current may hold a match a test or tool made).
	var ds: Node = DuelViews.state()
	if m != null and ds != null and ds.has_method(&"take_current") and ds.get(&"current") == m:
		ds.call(&"take_current")
	if m != null:
		active = m
	return m


static func is_duel(m: Object) -> bool:
	return m != null and m == active


static func is_hot_seat() -> bool:
	return StringName(str(setup.get("mode", ""))) == MODE_HOT_SEAT


## Player names for the seats.
static func names() -> PackedStringArray:
	var n: Array = setup.get("names", [])
	var out: PackedStringArray = []
	for i: int in 2:
		out.append(String(n[i]) if i < n.size() and String(n[i]) != "" else ("Player %d" % (i + 1)))
	return out


## Match.tscn: the duel is over (match = the DuelMatch; result = its result() or the controller's own
## {winner_side, scores, rounds, reason} without DuelState). Records it and opens the result screen.
static func finish(match: Object, result: Dictionary = {}) -> Dictionary:
	active = null
	var out: Dictionary = {}
	var ds: Node = DuelViews.state()
	if ds != null and ds.has_method(&"finish") and match != null and match.has_method(&"result"):
		out = ds.call(&"finish", match)
	if out.is_empty() or not out.has("result"):
		var res: Dictionary = result.duplicate(true)
		if match != null and match.has_method(&"result"):
			res = match.call(&"result")
		out = {"ok": true, "result": res, "records": DuelViews.records(), "new_cosmetics": []}
		if StringName(str(setup.get("mode", MODE_VS_AI))) == MODE_VS_AI and not setup.is_empty():
			var won: int = int(res.get("winner_side", -1))
			var decks: Array = setup.get("decks", [{}, {}])
			DuelViews.note_local(&"win" if won == 0 else (&"loss" if won == 1 else &"draw"), StringName(str((decks[0] as Dictionary).get("hero", ""))),
					String(setup.get("opponent_id", "")), StringName(str(setup.get("tier", ""))))
			out["records"] = DuelViews.records()
	last_result = out.duplicate(true)
	last_result["setup"] = setup.duplicate(true)
	goto(SCENE_RESULT)
	return last_result


## The result screen's REMATCH: the same setup, a new seed.
static func rematch() -> Dictionary:
	var s: Dictionary = setup.duplicate(true)
	s.erase("seed")
	return start_match(s)


## Setters for the hand-off state (a script preloaded as a const can't assign its static vars).
static func set_hub_tab(t: String) -> void:
	hub_tab = t


static func set_edit_deck(d: Dictionary) -> void:
	edit_deck = d.duplicate(true)


static func set_setup(s: Dictionary) -> void:
	setup = s.duplicate(true)


static func set_last_result(r: Dictionary) -> void:
	last_result = r.duplicate(true)


static func set_dry_run(on: bool) -> void:
	dry_run = on


static func clear_active() -> void:
	active = null
