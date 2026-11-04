# test_brace_prompt.gd
# Purpose: cz12 Brace prompt. The suggestion (scripts/match/brace_advisor.gd): fewest Hits, then
#   fewest cards, then keep the best next-turn cards, Spent cards cost extra, a short reason, what
#   comes up instead, and fairness (the rival's private cards never change it). The controller
#   exposes it (view().brace_prompt.suggested / suggestion, EventBus.match_view_changed,
#   brace_suggested) and PlaytestLog's brace.suggested_used turns true / false. The panel by touch
#   on a phone: USE SUGGESTED + BRACE = 2 taps, adjusting by tapping next-hand cards, nothing to
#   brace with (TAKE n HITS), the lethal warning, SUGGESTED tags, 64 px targets inside the safe area.
# Author: UI/UX Agent (cz12)
extends "res://tests/test_match_flow_kit.gd"

const BraceAdvisor: GDScript = preload("res://scripts/match/brace_advisor.gd")


## A rival (P2, active) about to shoot P1 with `weapon` from `from`; P1 at `to` with `loadout`.
func _shot_fixture(weapon: String, from: String, to: String, loadout: Array, p1_health: int = 5,
		p2_extra: Dictionary = {}) -> MatchState:
	var p2: Dictionary = {"area": from, "health": 5, "line": [weapon], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]}
	for k: Variant in p2_extra.keys():
		p2[k] = p2_extra[k]
	return _fixture({"active": "P2", "P1": {"area": to, "health": p1_health, "loadout": loadout}, "P2": p2})


## The human's view at the Brace step of a fixture (the rival fires its weapon).
func _brace_view(s: MatchState) -> Dictionary:
	var w: int = s.seats[1].line[0]
	var r: ActionResult = LoadoutRules.apply(s, {"type": "shoot", "seat": 1, "weapon": w, "target": 0})
	assert_true(r.ok, "the fixture shot is legal (%s)" % r.error)
	var v: Dictionary = LoadoutRules.view(s, 0)
	if v.has("brace_prompt"):
		v["brace_prompt"]["hand_size"] = s.data.balance.hand_size
	return v


func _lookup() -> Callable:
	return func(id: StringName) -> CardData: return CardDB.get_card(id)


func _ids(v: Dictionary, insts: Array) -> Array:
	var out: Array = []
	for cv: Dictionary in v["me"]["loadout"]:
		if insts.has(int(cv["id"])):
			out.append(String(cv["card"]))
	return out


# --- The suggestion ---------------------------------------------------------------------------

func test_suggestion_fewest_hits_then_fewest_cards_then_keep_best() -> void:
	# 2 damage: Plate Vest alone (1 card) beats Duck + anything; it keeps Duck.
	var v: Dictionary = _brace_view(_shot_fixture("hunting_rifle", "docks", "rail_yard",
			["scavenge", "duck", "plate_vest", "dash", "scavenge", "dash", "duck"]))
	assert_eq(int(v["brace_prompt"]["damage"]), 2, "Hunting Rifle into Rail Yard: 2 damage")
	var s: Dictionary = BraceAdvisor.suggest(v, _lookup())
	assert_eq(_ids(v, s["cards"]), ["plate_vest"], "1 card that blocks all 2")
	assert_eq([int(s["hits"]), int(s["total"]), int(s["blocked"])], [0, 2, 2], "0 Hits")
	assert_eq(s["reason"], "Blocks all 2 damage with 1 card, keeping Duck for your turn.", "the reason line")
	assert_eq(s["comes_up"], [&"dash"], "the next loadout card (the 2nd Dash) comes up instead of the Vest")
	# 1 damage (Quarry Cover 1): Duck, not the more valuable Plate Vest.
	v = _brace_view(_shot_fixture("hunting_rifle", "radio_hill", "quarry",
			["scavenge", "plate_vest", "duck", "dash", "scavenge", "dash", "duck"]))
	assert_eq(int(v["brace_prompt"]["damage"]), 1, "DMG 2 - Cover 1")
	s = BraceAdvisor.suggest(v, _lookup())
	assert_eq(_ids(v, s["cards"]), ["duck"], "the cheaper card blocks the 1 damage")
	assert_true("keeping Plate Vest" in String(s["reason"]), "keeps the Vest: %s" % s["reason"])


func test_suggestion_partial_block_spent_cost_and_nothing_to_brace() -> void:
	# 3 damage (Assault Rifle), only Duck (1): the best block lets 2 Hits through.
	var v: Dictionary = _brace_view(_shot_fixture("assault_rifle", "docks", "rail_yard",
			["scavenge", "duck", "dash", "scavenge", "dash", "dash"]))
	assert_eq(int(v["brace_prompt"]["damage"]), 3, "Assault Rifle: 3 damage")
	var s: Dictionary = BraceAdvisor.suggest(v, _lookup())
	assert_eq(_ids(v, s["cards"]), ["duck"], "everything that helps")
	assert_eq(int(s["hits"]), 2, "2 Hits still land")
	assert_eq(s["reason"], "Your best block: stops 1 of 3, 2 Hits land.", "partial block reason")
	# Smoke Grenade (Brace 2, Spent on Brace) vs Plate Vest (Brace 2): the Vest stays in the game.
	v = _brace_view(_shot_fixture("hunting_rifle", "docks", "rail_yard",
			["smoke_grenade", "plate_vest", "scavenge", "dash", "scavenge", "dash"]))
	s = BraceAdvisor.suggest(v, _lookup())
	assert_eq(_ids(v, s["cards"]), ["plate_vest"], "a Spent card counts extra")
	assert_true(BraceAdvisor.keep_value(CardDB.get_card(&"smoke_grenade")) > BraceAdvisor.keep_value(CardDB.get_card(&"plate_vest")),
			"Smoke Grenade's keep value includes the Spent penalty")
	# Nothing can brace.
	v = _brace_view(_shot_fixture("hunting_rifle", "docks", "rail_yard", ["scavenge", "dash", "scavenge", "dash", "scavenge", "dash"]))
	s = BraceAdvisor.suggest(v, _lookup())
	assert_eq(s["cards"], [], "no suggestion cards")
	assert_eq(s["reason"], "Nothing in your next hand can brace: 2 Hits land.", "says so")
	# Lethal: 2 Hits at health 1.
	v = _brace_view(_shot_fixture("hunting_rifle", "docks", "rail_yard", ["scavenge", "dash", "scavenge", "dash", "scavenge", "dash"], 1))
	s = BraceAdvisor.suggest(v, _lookup())
	assert_true(bool(s["eliminated"]), "2 Hits at health 1 eliminate")
	assert_true("Not enough armour" in String(s["reason"]), "lethal warning: %s" % s["reason"])


func test_suggestion_never_depends_on_the_rivals_private_cards() -> void:
	var loadout: Array = ["scavenge", "duck", "plate_vest", "dash", "scavenge", "dash", "duck"]
	var a: Dictionary = _brace_view(_shot_fixture("hunting_rifle", "docks", "rail_yard", loadout, 5,
			{"hand": ["plate_vest", "medkit"], "loadout": ["duck", "dash", "scavenge", "scavenge", "dash"]}))
	var b: Dictionary = _brace_view(_shot_fixture("hunting_rifle", "docks", "rail_yard", loadout, 5,
			{"hand": ["scavenge", "dash"], "loadout": ["dash", "scavenge", "duck", "dash", "scavenge"]}))
	var sa: Dictionary = BraceAdvisor.suggest(a, _lookup())
	var sb: Dictionary = BraceAdvisor.suggest(b, _lookup())
	assert_eq(sa, sb, "same suggestion whatever the rival holds")


# --- Controller exposure and the playtest log ----------------------------------------------

func test_controller_exposes_the_suggestion_for_the_logger() -> void:
	var plog: Node = tree.root.get_node("PlaytestLog")
	var saved: Dictionary = {"log_path": plog.log_path, "consent_path": plog.consent_path, "enabled": plog.enabled,
			"answered": plog.consent_answered, "auto": plog.auto_prompt}
	var dir: String = "user://test_brace_prompt/%d" % OS.get_process_id()  # per test process (cz14)
	DirAccess.make_dir_recursive_absolute(dir)
	plog.log_path = dir.path_join("log.jsonl")
	plog.consent_path = dir.path_join("consent.cfg")
	plog.auto_prompt = false
	plog.delete_log()
	plog.set_consent(true, false)
	var braces: Array = []
	var on_entry: Callable = func(e: Dictionary) -> void:
		if e.get("event", "") == "brace":
			braces.append(e)
	plog.event_logged.connect(on_entry)
	var bus_views: Array = []
	var on_view: Callable = func(v: Dictionary) -> void:
		if v.has("brace_prompt"):
			bus_views.append(v)
	EventBus.match_view_changed.connect(on_view)
	var loadout: Array = ["scavenge", "duck", "plate_vest", "dash", "scavenge", "dash", "duck"]
	for round_i: int in 2:
		var m: Control = await _spawn(null, Shooter.new())
		var ctrl: Node = m.get_controller()
		var got: Array = []
		ctrl.brace_suggested.connect(func(sg: Dictionary) -> void: got.append(sg))
		m.start_live(_shot_fixture("hunting_rifle", "docks", "rail_yard", loadout))
		for i: int in 3:
			await tree.process_frame
		assert_eq(ctrl.phase, &"brace", "Brace step")
		var bp: Dictionary = ctrl.view()["brace_prompt"]
		assert_eq(bp["suggested"], bp["suggestion"]["cards"], "suggested = the suggestion's cards")
		assert_eq(got.size(), 1, "brace_suggested fired once")
		assert_eq(got[0].get("cards", []), bp["suggested"], "with the same cards")
		assert_true(not bus_views.is_empty() and bus_views.back()["brace_prompt"].has("suggested"),
				"EventBus.match_view_changed carries brace_prompt.suggested")
		assert_eq(int(bp["dmg"]), 2, "printed damage in the prompt")
		assert_eq(bp["source"]["card"], &"hunting_rifle", "source weapon")
		if round_i == 0:
			await _touch_brace(m, &"brace_suggested")
		else:
			await _touch_card(m, &"next", 1)  # Duck: an adjusted choice
		await _touch_brace(m, &"brace")
		assert_true(ctrl.phase != &"brace", "braced (phase %s)" % ctrl.phase)
		_despawn(m)
		await tree.process_frame
	plog.flush()
	assert_eq(braces.size(), 2, "two brace lines logged")
	if braces.size() == 2:
		assert_eq(braces[0]["suggested_used"], true, "USE SUGGESTED -> suggested_used true")
		assert_eq(braces[0]["cards"], ["plate_vest"], "the suggested card")
		assert_eq(braces[1]["suggested_used"], false, "an adjusted brace -> false")
	plog.event_logged.disconnect(on_entry)
	EventBus.match_view_changed.disconnect(on_view)
	plog.delete_log()
	DirAccess.remove_absolute(plog.consent_path)
	plog.enabled = saved["enabled"]
	plog.consent_answered = saved["answered"]
	plog.auto_prompt = saved["auto"]
	plog.log_path = saved["log_path"]
	plog.consent_path = saved["consent_path"]


# --- The panel by touch -----------------------------------------------------------------------

func test_two_taps_accept_the_suggestion() -> void:
	var m: Control = await _spawn(_shot_fixture("hunting_rifle", "docks", "rail_yard",
			["scavenge", "duck", "plate_vest", "dash", "scavenge", "dash", "duck"], 4), Shooter.new())
	var ctrl: Node = m.get_controller()
	assert_eq(m.mode, &"brace", "brace mode")
	var panel: PanelContainer = m.get_brace_panel()
	assert_true(panel.visible, "the Brace panel is up")
	assert_false(m.get_dock().visible, "the old dock is hidden")
	var t: Dictionary = panel.get_texts()
	assert_eq(t["title"], "INCOMING · HUNTING RIFLE FROM DOCKS", "title")
	assert_eq(t["sum"], "DMG 2 − Cover 0 − Down 0 = 2 damage", "sum")
	assert_eq(t["result"], "YOU TAKE 2 HITS · HEALTH 4 → 2", "result before choosing")
	assert_true(t["line"].begins_with("SUGGESTED: Plate Vest (2) → 0 Hits."), "suggestion line: %s" % t["line"])
	assert_eq(panel.get_keys(), [&"brace_suggested", &"brace"], "USE SUGGESTED, then confirm")
	assert_eq(m.get_brace_button(&"brace").text, "TAKE 2 HITS", "confirm says what happens")
	# SUGGESTED tag under the Vest (strip index 2).
	var tags: Array[Label] = m.get_brace_tags()
	assert_eq(tags.size(), 1, "one SUGGESTED tag")
	if tags.size() == 1:
		var card: Rect2 = m.get_cards(&"next")[2].get_global_rect()
		var tr: Rect2 = tags[0].get_global_rect()
		assert_true(absf(tr.position.x - card.position.x) < 1.0 and tr.position.y >= card.end.y, "tag right under the Vest %s / %s" % [tr, card])
		assert_false(tr.intersects(panel.get_global_rect()), "tag clear of the panel")
	# Tap 1: USE SUGGESTED. Tap 2: BRACE.
	await _touch_brace(m, &"brace_suggested")
	assert_eq(m.brace_set.size(), 1, "the Vest chosen")
	assert_true((m.get_cards(&"next")[2] as CzCard).selected, "the Vest marked")
	assert_eq(panel.get_texts()["result"], "0 HITS · HEALTH 4", "live result")
	assert_eq(panel.get_keys(), [&"brace_clear", &"brace"], "CLEAR replaces USE SUGGESTED")
	assert_eq(m.get_brace_button(&"brace").text, "BRACE · 0 HITS", "confirm label")
	await _touch_brace(m, &"brace")
	assert_eq(int(ctrl.view()["me"]["health"]), 4, "no Hit landed")
	assert_true("You braced with Plate Vest (Brace 2): 0 Hits." in "\n".join(ctrl.log_lines), "brace announced")
	assert_false(panel.visible, "panel closes")
	assert_eq(m.get_brace_tags().size(), 0, "tags gone")
	_despawn(m)


func test_adjust_clear_and_lethal_warning() -> void:
	var m: Control = await _spawn(_shot_fixture("assault_rifle", "docks", "rail_yard",
			["scavenge", "duck", "plate_vest", "dash", "scavenge", "dash", "duck"], 1), Shooter.new())
	var panel: PanelContainer = m.get_brace_panel()
	assert_eq(panel.get_texts()["result"], "YOU TAKE 3 HITS · YOU'RE OUT", "3 Hits at health 1: out")
	await _touch_card(m, &"next", 1)  # Duck only
	var t: Dictionary = panel.get_texts()
	assert_eq(t["result"], "YOU TAKE 2 HITS · YOU'RE OUT", "still out with Duck alone")
	assert_true(t["line"].begins_with("Your choice: Duck (1) (Brace 1). Suggested: Duck (1) + Plate Vest (2) → 0 Hits."), "choice vs suggestion: %s" % t["line"])
	await _touch_brace(m, &"brace_suggested")
	assert_eq(panel.get_texts()["result"], "0 HITS · HEALTH 1", "the suggestion saves you")
	assert_true("Suggested brace chosen." in panel.get_texts()["line"], "says it")
	await _touch_brace(m, &"brace_clear")
	assert_eq(m.brace_set.size(), 0, "CLEAR empties the choice")
	await _touch_card(m, &"next", 0)
	assert_true("no Brace value" in m.last_notice, "Scavenge refused in words: %s" % m.last_notice)
	await _touch_card(m, &"next", 2)
	await _touch_card(m, &"next", 1)
	await _touch_brace(m, &"brace")
	assert_eq(int(m.get_controller().view()["me"]["health"]), 1, "survived")
	_despawn(m)


func test_nothing_to_brace_with_one_tap_and_fits_the_phone() -> void:
	var m: Control = await _spawn(_shot_fixture("hunting_rifle", "docks", "rail_yard",
			["scavenge", "dash", "scavenge", "dash", "scavenge", "dash"], 5), Shooter.new())
	var panel: PanelContainer = m.get_brace_panel()
	assert_eq(panel.get_keys(), [&"brace"], "only the confirm button")
	assert_eq(m.get_brace_button(&"brace").text, "TAKE 2 HITS", "TAKE 2 HITS")
	assert_eq(panel.get_texts()["line"], "Nothing in your next hand can brace: 2 Hits land.", "explained")
	# Fits: inside the safe area, under the strip, 64 px targets, text not cut.
	var safe: Rect2 = m.safe_area_override.grow(EPS)
	var pr: Rect2 = panel.get_global_rect()
	assert_true(safe.encloses(pr), "panel %s inside the safe area %s" % [pr, safe])
	assert_true(pr.position.y >= m.get_node("%StripCards").get_global_rect().end.y, "panel under the next hand")
	var b: Button = m.get_brace_button(&"brace")
	var br: Rect2 = b.get_global_rect()
	assert_true(minf(br.size.x, br.size.y) >= 64.0 - EPS and pr.grow(EPS).encloses(br), "64 px button inside the panel %s" % br)
	for l: Label in panel.get_labels():
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
			assert_true(l.get_minimum_size().x <= l.size.x + EPS or l.text == "", "%s fits: '%s'" % [l.name, l.text])
	await _touch_brace(m, &"brace")
	assert_eq(int(m.get_controller().view()["me"]["health"]), 3, "2 Hits landed")
	_despawn(m)
