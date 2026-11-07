# test_run_v2_ui.gd
# Purpose: kc-v2-ui (Run v2 screens, run-v2.md §9, run-v2-api.md). Checks, at the phone landscape
#   (844x390), phone portrait (390x844) and iPad (1180x820) canvases:
#   - the view adapter: the rules' map shape (0-based steps, per-node links, 3 Terrain rows a fight)
#     and the sample shape normalise to the same screen data;
#   - the run map: 9 steps x 3 lanes, the boss on the map from step 1 with its rule, path choice (only
#     linked nodes are NEXT), tap = brief, tap again / GO = move_to, long press = the node inspector;
#     everything on screen;
#   - Event / Shop / Rest: exact results on the buttons, CONFIRM, "what just happened" lines with the
#     numbers that changed, prices (Muster out 2 REQ), the deck picker, every tile inspectable;
#   - the objective tile's Terrain chip (alone: fills the Field area; with Fields: a square chip and
#     the Field chips moved right), its own hit area (tap = rule toast, long press = inspector);
#   - the Operator ability button: READY -> AIM -> PLAN -> (UNDO) READY -> USED, inside the Operator
#     card, inspectable; the match intro (boss rule + 3 columns) and the boss plate on an empty slot.
#   The screens run on the sample views (RunV2Views.preview_*) so they don't depend on the run
#   generator's seed; the match tests use the real MatchState fields of kc-v2-impl.
# Author: UI/UX Agent (kc-v2-ui)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const RunV2Views: GDScript = preload("res://scripts/ui/run/run_v2_views.gd")
const ObjectiveTile: GDScript = preload("res://scripts/ui/objective_tile.gd")
const PORTRAIT: Dictionary = {"name": "iPhone 390x844 portrait", "pt": Vector2(390, 844), "ratio": 3.0}
const IPAD: Dictionary = {"name": "iPad 1180x820", "pt": Vector2(1180, 820), "ratio": 2.0}

var _saved_root_size: Vector2i = Vector2i.ZERO


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _screens() -> Array[Dictionary]:
	return [Layout.PHONE, PORTRAIT, IPAD]


func _open(path: String, screen: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var node: Control = (load(path) as PackedScene).instantiate()
	vp.add_child(node)
	await _frames(8)
	return [vp, node]


func _close(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size
	await _frames(2)


func _setup_run() -> void:
	var rs: Node = tree.root.get_node("RunState")
	rs.autosave = false
	if rs.run == null:
		rs.start_run(4242)
	tree.root.get_node("SceneRouter").dry_run = true
	RunV2Views.clear_overrides()


func _teardown() -> void:
	RunV2Views.clear_overrides()


## Every visible Button / Label outside a scroll is inside the viewport.
func _check_on_screen(root_ctl: Control, vp: SubViewport, label: String) -> void:
	var view: Rect2 = Rect2(Vector2.ZERO, Vector2(vp.size)).grow(1.0)
	var bad: PackedStringArray = []
	for n: Node in root_ctl.find_children("*", "Control", true, false):
		var ctl: Control = n
		if not ctl.is_visible_in_tree() or not (ctl is Button or ctl is Label):
			continue
		var p: Node = ctl.get_parent()
		var scrolled: bool = false
		while p != null and p != root_ctl:
			if p is ScrollContainer:
				scrolled = true
				break
			p = p.get_parent()
		if scrolled:
			continue
		if not view.encloses(ctl.get_global_rect()):
			bad.append("%s %s" % [ctl.name, ctl.get_global_rect()])
	assert_true(bad.is_empty(), "%s: off screen: %s" % [label, ", ".join(bad.slice(0, 6))])


# =============================================================================
# The adapter
# =============================================================================

func test_rules_map_shape_normalises() -> void:
	var api: Dictionary = {"steps": 9, "lanes": 3, "step": 0, "current": &"s0_l1", "req": 4, "tickets": 2, "max_tickets": 3,
		"threat": 1, "modifiers": [&"veterans"], "boss": {"id": &"choir", "rule_id": &"horde"},
		"nodes": [
			{"id": &"s0_l1", "step": 0, "lane": 1, "type": &"fight", "name": "Fight", "links": [&"s1_l0", &"s1_l2"], "visited": true,
				"current": true, "fight": {"label": "F1", "crew": "SandViper_07", "mode_name": "Zone Control",
					"terrain": [{"zone": 0, "id": &""}, {"zone": 1, "id": &"rooftops", "name": "Rooftops", "text": "x"}, {"zone": 2, "id": &""}]}},
			{"id": &"s1_l0", "step": 1, "lane": 0, "type": &"event", "name": "Event", "links": [], "reachable": true, "event": {"id": &"audit", "title": "Quartermaster's Audit"}},
			{"id": &"s1_l2", "step": 1, "lane": 2, "type": &"shop", "name": "Shop", "links": [], "reachable": true},
		]}
	var m: Dictionary = RunV2Views.normalise_map(api)
	assert_eq(int(m["step"]), 1, "0-based step 0 -> standing on step 1")
	assert_eq(int(m["tickets_max"]), 3, "max_tickets read")
	var f: Dictionary = RunV2Views.node_by_id(m, "s0_l1")
	assert_eq(int(f["step"]), 1, "node steps become 1-based")
	assert_eq((f["terrain"] as Array).size(), 1, "empty Terrain rows are dropped")
	assert_eq(String(f["terrain"][0]["name"]), "Rooftops", "the Terrain keeps its name")
	assert_eq(int(f["fight"]), 1, "F1 -> fight 1")
	assert_eq((m["links"] as Array).size(), 2, "per-node links become pairs")
	assert_eq(String(RunV2Views.node_by_id(m, "s1_l0")["event"]), "Quartermaster's Audit", "the event's title")
	assert_eq(String(m["boss"]["name"]), "The Hollow Choir", "the boss words come from the spec when the view has none")
	assert_eq(String(m["modifiers"][0]["name"]), "Veteran Crews", "modifier ids get their names")
	var sample: Dictionary = RunV2Views.sample_map_view(2, 0)
	assert_eq((sample["nodes"] as Array).size(), 18, "the sample map has the spec's 18 nodes")
	var next: Array = (sample["nodes"] as Array).filter(func(n: Dictionary) -> bool: return bool(n.get("reachable", false)))
	assert_eq(next.size(), 2, "from the left-lane event, two step-3 fights are next")


# =============================================================================
# Run map
# =============================================================================

func test_run_map_v2_at_three_sizes() -> void:
	_setup_run()
	for screen: Dictionary in _screens():
		RunV2Views.preview_map(RunV2Views.sample_map_view(2, 0))
		var s: Array = await _open("res://scenes/run/RunMap.tscn", screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var v: Control = m.get_map_view()
		assert_not_null(v, "%s: the v2 map is built" % screen["name"])
		if v == null:
			await _close(vp)
			continue
		await _frames(4)
		_check_on_screen(m, vp, "%s run map" % screen["name"])
		assert_eq(v.graph.get_map_nodes().size(), 18, "%s: 18 nodes" % screen["name"])
		var boss: Control = v.get_boss_plate()
		assert_true(boss.is_visible_in_tree(), "%s: the boss plate is shown from step 1" % screen["name"])
		var rule: Label = boss.find_child("BossRule", true, false) as Label
		assert_true(rule != null and rule.text.contains("round 4"), "%s: the boss rule is printed" % screen["name"])
		assert_true(v.get_go_button().text == "FIGHT HERE" and not v.get_go_button().disabled, "%s: the first reachable fight is briefed (%s)" % [screen["name"], v.get_go_button().text])
		# The nodes are 44 pt tap targets.
		var k: float = Layout.points_per_px(screen)
		var tile: float = v.graph.tile_px()
		assert_true(tile * k >= 34.0, "%s: node tiles %.0f pt (with their words the tap area is taller)" % [screen["name"], tile * k])
		var node: Control = v.graph.get_map_node("s3l0")
		assert_true(node.size.y * k >= 44.0, "%s: a node's tap area is %.0f pt tall" % [screen["name"], node.size.y * k])
		# Not on the path: the brief says so and GO is off.
		v.select("s6l1")
		assert_true(v.get_go_button().disabled and v.get_go_button().text == "NOT ON YOUR PATH YET", "%s: a far node can't be chosen" % screen["name"])
		# Tap a reachable node twice = move_to.
		RunV2Views.act_log.clear()
		v.select("s3l1")
		v._on_tapped("s3l1")
		assert_eq(RunV2Views.act_log.size(), 1, "%s: the second tap steps on it" % screen["name"])
		if not RunV2Views.act_log.is_empty():
			assert_eq(RunV2Views.act_log[0][0], &"move_to", "%s: RunState.move_to" % screen["name"])
		# Long press a node: the inspector with its Terrain rule and what it gives.
		v.graph.node_inspected.emit("s3l0")
		await _frames(3)
		var insp: Control = m.get_inspector()
		assert_true(insp.is_open(), "%s: long press opens the node inspector" % screen["name"])
		var kws: Control = insp.find_child("KeywordList", true, false)
		var all: String = ""
		for l: Node in kws.get_children():
			if l is Label:
				all += (l as Label).text + " "
		assert_true(all.contains("Smoke") and all.contains("both sides"), "%s: the inspector has the Terrain rule (%s)" % [screen["name"], all.left(80)])
		insp.close()
		# Every node, the boss plate, the REQ and Threat chips are inspectable.
		for n: Control in v.graph.get_map_nodes():
			assert_true(n.has_meta(&"inspectable"), "node inspectable")
		for chip: String in ["ReqChip", "ThreatChip", "Tickets"]:
			var c: Control = m.find_child(chip, true, false)
			assert_true(c != null and c.has_meta(&"inspectable"), "%s: %s inspectable" % [screen["name"], chip])
		await _close(vp)
	_teardown()


# =============================================================================
# Event / Shop / Rest
# =============================================================================

func test_event_shop_rest_preview_flow() -> void:
	_setup_run()
	for screen: Dictionary in _screens():
		RunV2Views.clear_overrides()
		RunV2Views.preview_event(RunV2Views.sample_event_view())
		var s: Array = await _open("res://scenes/run/Event.tscn", screen)
		var e: Control = s[1]
		_check_on_screen(e, s[0], "%s event" % screen["name"])
		assert_eq(e.get_option_tiles().size(), 3, "three options")
		assert_true(e.get_confirm_button().disabled, "nothing picked: CONFIRM is off")
		e.pick(1)
		assert_false(e.get_confirm_button().disabled, "picked: CONFIRM is on")
		for t: Button in e.get_option_tiles():
			assert_true(t.has_meta(&"inspectable"), "event option inspectable")
		e.confirm()
		await _frames(2)
		assert_eq(RunV2Views.act_log[-1][0], &"choose_event", "CONFIRM calls choose_event")
		assert_true(e.feedback_text().contains("Comms Relay"), "the result line says what happened (%s)" % e.feedback_text())
		assert_eq(e.get_confirm_button().text, "CONTINUE", "then CONTINUE")
		await _close(s[0])
		# Shop.
		RunV2Views.clear_overrides()
		RunV2Views.preview_shop(RunV2Views.sample_shop_view())
		s = await _open("res://scenes/run/Shop.tscn", screen)
		var sh: Control = s[1]
		await _frames(2)
		_check_on_screen(sh, s[0], "%s shop" % screen["name"])
		assert_eq(sh.get_buy_buttons()[0].text, "BUY · 4 REQ", "a unit costs 4 REQ")
		assert_true(sh.get_service_tile(&"muster").content.get_child(0).text.contains("2 REQ"), "Muster out costs 2 REQ (head)")
		sh.buy(0)
		await _frames(2)
		assert_true(sh.feedback_text().contains("REQ 7 -> 3"), "the buy says REQ before and after (%s)" % sh.feedback_text())
		assert_eq(sh.get_buy_buttons()[0].text, "SOLD", "the bought card is SOLD")
		assert_true(sh.get_buy_buttons()[1].text == "BUY · 3 REQ" and not sh.get_buy_buttons()[1].disabled, "3 REQ left buys a tactic")
		var perk: Button = sh.get_service_tile(&"perk_0")
		assert_true(perk != null and perk.disabled, "a 6 REQ Perk is off with 3 REQ")
		RunV2Views.act_log.clear()
		sh.muster([2, 7])
		assert_eq(RunV2Views.act_log.size(), 2, "Muster out: one call per card")
		if RunV2Views.act_log.size() == 2:
			assert_eq(RunV2Views.act_log[0][1][0], 7, "highest deck index first (the others stay valid)")
		await _close(s[0])
		# Rest.
		RunV2Views.clear_overrides()
		RunV2Views.preview_rest(RunV2Views.sample_rest_options())
		s = await _open("res://scenes/run/Rest.tscn", screen)
		var rr: Control = s[1]
		_check_on_screen(rr, s[0], "%s rest" % screen["name"])
		assert_eq(rr.get_tiles().size(), 3, "three rest options")
		rr.pick(1)
		assert_eq(rr.get_confirm_button().text, "PICK 2 CARDS", "DRILL asks for the cards")
		rr.confirm()
		await _frames(3)
		assert_true(rr.get_picker().visible, "DRILL opens the deck picker")
		rr.get_picker().hide()
		rr.pick(0)
		rr.confirm()
		assert_eq(RunV2Views.act_log[-1][0], &"rest_choose", "CONFIRM calls rest_choose")
		assert_true(rr.feedback_text() != "", "the rest says what happened")
		await _close(s[0])
	_teardown()


# =============================================================================
# Terrain on the objective tile
# =============================================================================

func test_objective_tile_terrain_chip() -> void:
	var holder: Control = Control.new()
	holder.theme = load("res://assets/ui/hud_theme.tres")
	tree.root.add_child(holder)
	var t: Control = ObjectiveTile.new()
	holder.add_child(t)
	t.size = Vector2(228, 52)
	t.compact = true
	var terrain: Dictionary = RunV2Views.terrain_entry({"id": &"smoke", "zone": 1})
	t.set_tile({"label": "B", "control": &"empty", "fields": {}, "terrain": terrain})
	await _frames(2)
	var r: Rect2 = t.terrain_rect()
	assert_true(r.has_area(), "a Terrain gets a chip")
	assert_true(r.size.x >= t.field_area().size.x - 1.0, "alone, the chip fills the Field area")
	assert_true(t.terrain_hit(r.get_center()), "the chip is its own hit area")
	t.set_tile({"label": "B", "control": &"player", "terrain": terrain,
			"fields": {"player": [{"name": "Sniper Perch", "card_id": &"sniper_perch", "card_uid": 7}]}})
	await _frames(2)
	r = t.terrain_rect()
	assert_true(r.has_area() and r.size.x < 40.0, "with a Field the Terrain is a square chip (%s)" % r)
	var chips: Array = t.chip_rects()
	assert_eq(chips.size(), 1, "the Field chip is still drawn")
	if not chips.is_empty():
		assert_true((chips[0][0] as Rect2).position.x >= r.end.x, "the Field chip moved right of the Terrain chip")
	t.set_tile({"label": "B", "control": &"empty", "fields": {}})
	await _frames(2)
	assert_false(t.terrain_rect().has_area(), "no Terrain: no chip")
	holder.queue_free()


# =============================================================================
# The match: Terrain, ability button, boss plate, intro
# =============================================================================

func _spawn_match(screen: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	var st: MatchState = c.state
	st.terrain[0] = &"smoke"
	st.terrain[2] = &"supply_cache"
	st.sides[0].kit_on = true
	st.sides[0].ability = load("res://data/loadout/ab_dig_in.tres")
	st.boss_id = &"meridian"
	st.boss_rule = &"reinforcements"
	st.boss_name = "Meridian_Six"
	st.boss_rule_name = "Reinforcements"
	st.boss_rule_text = "From round 4, gains 1 extra Supply every round."
	m.set(&"_intro_shown", false)
	m.intro_node = {"type": &"boss"}
	c.refresh()
	await _frames(4)
	return [vp, m, c]


func test_match_terrain_ability_boss() -> void:
	if not ResourceLoader.exists("res://data/loadout/ab_dig_in.tres"):
		assert_true(true, "kc-v2-impl data not in this build")
		return
	for screen: Dictionary in _screens():
		var s: Array = await _spawn_match(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		var name: String = screen["name"]
		# The intro: boss rule + one row per column.
		var intro: Control = m.get_match_intro()
		assert_true(intro.visible, "%s: the match intro opens before play" % name)
		assert_not_null(intro.find_child("IntroBossRule", true, false), "%s: the intro has the boss rule" % name)
		for z: String in ["A", "B", "C"]:
			assert_not_null(intro.find_child("Column" + z, true, false), "%s: intro row for column %s" % [name, z])
		intro.close()
		await _frames(2)
		# Terrain on the tiles.
		var lanes: Array = m.get_board().get_lanes()
		assert_true((lanes[0].get_objective_tile().terrain_rect() as Rect2).has_area(), "%s: column A shows its Terrain chip" % name)
		assert_false((lanes[1].get_objective_tile().terrain_rect() as Rect2).has_area(), "%s: column B has none" % name)
		c.show_terrain_rule(0)
		assert_true(String(m.get_toast_text()).contains("No Pick or Flank"), "%s: a tap on the chip says the rule (%s)" % [name, m.get_toast_text()])
		# The boss plate: visible, on an empty rival back-row slot.
		var plate: Control = m.get_boss_plate()
		assert_true(plate.is_visible_in_tree(), "%s: the boss plate is on the board" % name)
		assert_true(plate.has_meta(&"inspectable"), "%s: the boss plate is inspectable" % name)
		# The ability button.
		var ab: Control = m.get_ability_button()
		assert_true(ab.is_visible_in_tree(), "%s: the ability button is shown" % name)
		assert_eq(ab.word(), "USE", "%s: READY reads USE" % name)
		var k: float = Layout.points_per_px(screen)
		assert_true(ab.size.x * k >= 44.0 - 0.5, "%s: the button is a 44 pt target (%.0f pt)" % [name, ab.size.x * k])
		var op: Control = m.get_hand().get_operator_card()
		if op != null:
			assert_true(op.get_global_rect().grow(1.0).encloses(ab.get_global_rect()), "%s: the button sits on the Operator card" % name)
		c.use_ability()
		await _frames(2)
		assert_eq(ab.word(), "AIM", "%s: tap = pick a target (AIM)" % name)
		c.play_at(1)
		await _frames(2)
		assert_eq(ab.word(), "PLAN", "%s: a column queues it (PLAN)" % name)
		c.undo()
		await _frames(2)
		assert_eq(ab.word(), "USE", "%s: UNDO gives it back" % name)
		c.state.sides[0].uses_this_match[&"ab_dig_in"] = 1
		c.refresh()
		await _frames(2)
		assert_eq(ab.word(), "USED", "%s: spent = USED" % name)
		ab.inspected.emit()
		await _frames(3)
		assert_true(m.get_inspector().is_open(), "%s: long press = the ability's inspector" % name)
		m.get_inspector().close()
		vp.queue_free()
		tree.root.size = _saved_root_size
		await _frames(2)


# =============================================================================
# The real rules: begin a map run, step on F1 from the map, the match starts with its Terrain
# =============================================================================

func test_real_map_run_from_the_map_screen() -> void:
	var rs: Node = tree.root.get_node("RunState")
	if not rs.has_method(&"map_view"):
		assert_true(true, "kc-v2-impl not in this build")
		return
	RunV2Views.clear_overrides()
	var router: Node = tree.root.get_node("SceneRouter")
	var saved: Dictionary = {"autosave": rs.autosave, "dry_run": router.dry_run, "map": rs.get(&"run_map_enabled")}
	rs.autosave = false
	router.dry_run = true
	rs.set(&"run_map_enabled", true)
	rs.start_run(4242)
	rs.set_killstreaks(rs.run.killstreaks)
	assert_eq(rs.begin_run(), "", "the map run begins")
	assert_eq(String(rs.run.phase), "map", "phase map after the loadout")
	var RunFlow: GDScript = load("res://scripts/ui/run/run_flow.gd")
	assert_eq(RunFlow.call(&"scene_for", rs.run), "res://scenes/run/RunMap.tscn", "the map phase routes to the run map")
	var s: Array = await _open("res://scenes/run/RunMap.tscn", Layout.PHONE)
	var m: Control = s[1]
	var v: Control = m.get_map_view()
	assert_not_null(v, "the rules' map_view builds the v2 map")
	if v != null:
		var reach: Array = (v.map["nodes"] as Array).filter(func(n: Dictionary) -> bool: return bool(n.get("reachable", false)))
		assert_eq(reach.size(), 1, "before F1 only F1 is reachable")
		assert_false((v.map.get("boss", {}) as Dictionary).is_empty(), "the boss is on the map from step 1")
		if reach.size() == 1:
			var err: String = m.choose_node(String(reach[0]["id"]))
			assert_eq(err, "", "stepping on F1 works (%s)" % err)
			assert_true(router.pending_match != null, "F1 deploys a match")
	await _close(s[0])
	router.pending_match = null
	rs.autosave = saved["autosave"]
	router.dry_run = saved["dry_run"]
	rs.set(&"run_map_enabled", saved["map"])
	rs.reset()
