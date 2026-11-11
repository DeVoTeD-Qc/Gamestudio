# test_da_ui2.gd
# Purpose: UI tests for the art-direction batch 2 (kc-da-ui2, art-direction.md §12 #4 #7 #8 #9 #10):
#   the inspector is one big card + a paper rules sheet; the after-action is a debrief with a stamp,
#   an MVP card and real stats only; the Codex is a binder (finish, owned / unowned, alt-art count);
#   the title shows a stencil wordmark and the equipped card with one amber button; the run map is
#   a briefing map (paper, pins, string, a red-circled boss target, no white NEXT box).
# Author: UI/UX Agent (kc-da-ui2)
extends "res://tests/test_case.gd"

const INSPECTOR_SCENE: String = "res://scenes/match/CardInspector.tscn"
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _host(size: Vector2) -> Control:
	var host: Control = Control.new()
	host.size = size
	tree.root.add_child(host)
	return host


func _free(n: Node) -> void:
	n.get_parent().remove_child(n)
	n.queue_free()


func test_inspector_is_one_card_and_a_paper_sheet() -> void:
	var db: Node = tree.root.get_node("CardDB")
	var card: CardData = db.get_card(&"marksman")
	assert_not_null(card, "marksman")
	if card == null:
		return
	for sz: Vector2 in [Vector2(844, 390), Vector2(1440, 900)]:
		var host: Control = _host(sz)
		var insp: Control = (load(INSPECTOR_SCENE) as PackedScene).instantiate()
		host.add_child(insp)
		insp.size = sz
		await _frames(2)
		var view: Dictionary = CardInfo.view_dict(card, "friend")
		insp.open({"view": view, "title": card.display_name, "type": "unit", "text": card.text,
				"keywords": CardInfo.keywords(card), "status": "", "banner": {"name": card.display_name, "fp": 2, "armor": 2},
				"side": 0, "art_line": "Art: Marksman · 1 of 5 · all in the Codex", "is_unit": true})
		await _frames(4)
		assert_true(insp.get_card_view().is_visible_in_tree(), "%s: the card shows" % sz)
		assert_true(insp.get_banner() == null, "%s: no banner copy beside the card" % sz)
		assert_true(insp.is_paper(), "%s: rules on paper" % sz)
		var all_text: String = ""
		for l: Node in insp.find_children("*", "Label", true, false):
			if (l as Label).is_visible_in_tree():
				all_text += (l as Label).text + " "
		assert_false(all_text.to_lower().contains("placeholder"), "%s: no placeholder words" % sz)
		var link: Button = insp.find_child("GlossaryLink", true, false) as Button
		if link != null:
			assert_true(link.icon != null and link.text == "", "%s: the glossary link is an icon, not a blank ?" % sz)
		assert_true(Rect2(Vector2.ZERO, sz).encloses(insp.get_node("%InfoPanel").get_global_rect()), "%s: sheet on screen" % sz)
		if sz.x >= 1440.0:
			assert_true(insp.get_card_view().get_global_rect().size.x >= 400.0, "desktop: one big card (%.0f px)" % insp.get_card_view().get_global_rect().size.x)
		# No card (a token, a rail box): the banner is the picture.
		insp.close()
		insp.open({"view": {}, "title": "Sentry Turret", "type": "token", "text": "FP 1.",
				"banner": {"name": "Sentry Turret", "fp": 1, "armor": 2, "armor_max": 2, "banner": "sentry_turret"}, "side": 0})
		await _frames(3)
		assert_true(insp.get_banner() != null, "%s: a token keeps its banner" % sz)
		insp.close()
		_free(host)
		await _frames(1)


# --- Run screens (after-action, run map): a scratch run, restored afterwards.

var _rs: Node = null
var _router: Node = null
var _saved: Dictionary = {}


func _run_setup() -> void:
	_rs = tree.root.get_node("RunState")
	_router = tree.root.get_node("SceneRouter")
	_saved = {"save_path": _rs.save_path, "autosave": _rs.autosave, "dry_run": _router.dry_run, "config": _rs.config}
	var dir: String = "user://test_da_ui2/s%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	_rs.save_path = dir.path_join("run_save.json")
	_rs.autosave = false
	_rs.config = null
	_rs.reset()
	_router.dry_run = true
	_router.last_match_report = {}


func _run_teardown() -> void:
	var dir: String = _rs.save_path.get_base_dir()
	_rs.abandon_run()
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	_rs.save_path = _saved["save_path"]
	_rs.autosave = _saved["autosave"]
	_rs.config = _saved["config"]
	_rs.reset()
	_router.dry_run = _saved["dry_run"]
	_router.last_match_report = {}


func _open_in(path: String, sz: Vector2) -> Array:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(sz)
	vp.disable_3d = true
	tree.root.add_child(vp)
	var node: Control = (load(path) as PackedScene).instantiate()
	vp.add_child(node)
	await _frames(5)
	return [vp, node]


func _labels_text(node: Node) -> String:
	var parts: PackedStringArray = []
	for c: Node in node.find_children("*", "Label", true, false):
		if (c as Label).is_visible_in_tree():
			parts.append((c as Label).text)
	return "\n".join(parts)


func _record(result: StringName) -> void:
	_rs.start_run(4242)
	_rs.begin_run()
	if _rs.run.map != null:
		var reach: Array = _rs.run.map.reachable()
		for id: StringName in reach:
			if _rs.run.map.node(id)["type"] == &"fight" or id == reach[-1]:
				_rs.move_to(id)
				break
	var win: bool = result == &"player"
	_rs.record_result(result, {"reason": &"target", "rounds": 6, "player_score": 6 if win else 2, "enemy_score": 3 if win else 6})


func test_after_action_is_a_debrief_with_stamp_mvp_and_real_stats() -> void:
	_run_setup()
	var RunFlow: GDScript = load("res://scripts/ui/run/run_flow.gd")
	for sz: Vector2 in [Vector2(844, 390), Vector2(1440, 900)]:
		# A report from a played match: eliminations, best streak and an MVP.
		_record(&"player")
		var rep: Dictionary = RunFlow.report_from_history(_rs.run, _rs.run.history[-1])
		rep.merge({"player_eliminations": 4, "enemy_eliminations": 2, "best_streak": 3,
				"mvp": {"card_id": "marksman", "art": "", "operator": false, "kills": 2, "damage": 7}}, true)
		_router.last_match_report = rep
		var got: Array = await _open_in("res://scenes/run/AfterAction.tscn", sz)
		var aa: Control = got[1]
		await _frames(2)
		var stamp: Label = aa.find_child("ResultLabel", true, false) as Label
		assert_not_null(stamp, "%s: result stamp" % sz)
		if stamp != null:
			assert_eq(stamp.text, "VICTORY", "%s: stamp word" % sz)
			assert_true(bool(stamp.get_meta(&"stamp", false)) and absf(stamp.rotation_degrees) > 3.0, "%s: a turned stamp" % sz)
			assert_true(String(stamp.get_theme_font(&"font").resource_path).contains("Stencil"), "%s: stencil face" % sz)
		assert_true(aa.get_sheet() != null and aa.get_sheet().has_meta(&"paper"), "%s: debrief on paper" % sz)
		var mvp: Control = aa.get_mvp_card()
		assert_not_null(mvp, "%s: MVP card" % sz)
		if mvp != null:
			assert_true(mvp.get_global_rect().size.x >= 230.0, "%s: MVP card shown large" % sz)
			assert_true(bool(mvp.get_parent().get_meta(&"inspectable", false)), "%s: MVP card inspectable" % sz)
			assert_not_null(mvp.get_parent().get_parent().get_node_or_null(^"Band"), "%s: MVP band" % sz)
			assert_true(Rect2(Vector2.ZERO, sz).encloses(mvp.get_global_rect()), "%s: MVP card on screen" % sz)
		var text: String = _labels_text(aa)
		assert_true("MVP" in text and "2 KILLS" in text, "%s: MVP line" % sz)
		assert_true("4-2" in text and "6-3" in text, "%s: real stats" % sz)
		assert_false("—" in text or "---" in text, "%s: no empty stat rows" % sz)
		var amber: int = 0
		for b: Node in aa.find_children("*", "Button", true, false):
			if (b as Button).is_visible_in_tree() and (b as Button).theme_type_variation == &"ReadyButton":
				amber += 1
		assert_eq(amber, 1, "%s: one amber button" % sz)
		got[0].queue_free()
		await _frames(1)
		_rs.abandon_run()
		# After a reload (no match log): no eliminations / streak rows, the Operator stands in.
		_record(&"enemy")
		_router.last_match_report = {}
		got = await _open_in("res://scenes/run/AfterAction.tscn", sz)
		aa = got[1]
		text = _labels_text(aa)
		assert_true("DEFEAT" in text, "%s: defeat stamp" % sz)
		assert_false("ELIMINATIONS" in text or "BEST STREAK" in text or "—" in text, "%s: unknown stats left out" % sz)
		assert_true("YOUR OPERATOR" in text, "%s: the Operator stands in, named as such" % sz)
		got[0].queue_free()
		await _frames(1)
		_rs.abandon_run()
	_run_teardown()


func test_mvp_from_the_match_log() -> void:
	var RunFlow: GDScript = load("res://scripts/ui/run/run_flow.gd")
	assert_eq(RunFlow.mvp(null), {}, "no match: no MVP")
	var m: MatchState = MatchState.new()
	m.sides.clear()
	m.sides.append(RulesSide.new())
	m.sides.append(RulesSide.new())
	m.events.clear()
	for e: Dictionary in [
		{"type": RulesEvent.UNIT_ARRIVED, "side": &"player", "uid": 11, "card_id": &"rifleman"},
		{"type": RulesEvent.UNIT_ARRIVED, "side": &"player", "uid": 12, "card_id": &"marksman"},
		{"type": RulesEvent.SHOT_FIRED, "side": &"player", "shooter_uid": 11, "damage": 6},
		{"type": RulesEvent.SHOT_FIRED, "side": &"player", "shooter_uid": 12, "damage": 2},
		{"type": RulesEvent.UNIT_ELIMINATED, "by_side": &"player", "by_uid": 12, "by_id": &"marksman", "credit": true},
		{"type": RulesEvent.SHOT_FIRED, "side": &"enemy", "shooter_uid": 30, "damage": 40},
	]:
		m.events.append(e)
	var got: Dictionary = RunFlow.mvp(m)
	assert_eq(String(got.get("card_id", "")), "marksman", "a kill (x10) beats 6 damage")
	assert_eq(int(got.get("kills", 0)), 1, "kills counted")
	assert_eq(int(got.get("damage", 0)), 2, "damage counted")


func test_codex_is_a_binder() -> void:
	_run_setup()
	var st: Node = tree.root.get_node("Settings")
	var saved_profile: Variant = st.get(&"run_profile")
	var saved_persist: bool = bool(st.get(&"persist"))
	st.set(&"persist", false)
	_rs.call(&"_save_profile", RunProfile.add_found_cards({}, ["marksman"]))
	var CodexView: GDScript = load("res://scripts/ui/codex/codex_view.gd")
	for sz: Vector2 in [Vector2(844, 390), Vector2(1440, 900)]:
		var vp: SubViewport = SubViewport.new()
		vp.size = Vector2i(sz)
		vp.disable_3d = true
		tree.root.add_child(vp)
		var host: Control = Control.new()
		vp.add_child(host)
		host.size = sz
		var codex: Control = CodexView.open_over(host)
		await _frames(4)
		var owned_tile: Control = null
		var unowned_tile: Control = null
		for t: Node in codex.get_tiles():
			var e: Dictionary = t.get_meta(&"entry")
			if String(e["id"]) == "marksman":
				owned_tile = t
			elif unowned_tile == null and e["kind"] != &"killstreak" and not bool(t.get_meta(&"owned")):
				unowned_tile = t
		assert_not_null(owned_tile, "%s: marksman tile" % sz)
		assert_not_null(unowned_tile, "%s: a card not owned yet" % sz)
		if owned_tile != null:
			var cv: CardView = owned_tile.find_child("Card", true, false) as CardView
			assert_true(bool(owned_tile.get_meta(&"owned")), "%s: a found card is owned" % sz)
			assert_false(bool(cv.data.get("not_found", false)), "%s: owned = full colour art" % sz)
			assert_true((cv.get_node("ArtPanel") as Control).visible and is_equal_approx((cv.get_node("ArtPanel") as Control).modulate.r, 1.0), "%s: art shown at full strength" % sz)
			assert_true(StringName(owned_tile.get_meta(&"finish")) != &"", "%s: owned card shows its finish" % sz)
			assert_not_null(owned_tile.get_node_or_null(^"Finish"), "%s: finish strip" % sz)
			var chip: Label = owned_tile.get_node_or_null(^"ArtCount") as Label
			assert_true(chip != null and chip.text.ends_with("ARTS"), "%s: alt-art count" % sz)
		if unowned_tile != null:
			var cv2: CardView = unowned_tile.find_child("Card", true, false) as CardView
			assert_true(bool(cv2.data.get("not_found", false)), "%s: unowned = stamped silhouette" % sz)
			var stamp: Label = cv2.find_child("NotFoundLabel", true, false) as Label
			assert_true(stamp != null and stamp.visible and absf(stamp.rotation_degrees) > 2.0, "%s: turned stamp" % sz)
			assert_false((cv2.get_node("ArtPanel") as Control).visible, "%s: no art behind the stamp (never a dim veil)" % sz)
			assert_eq(StringName(unowned_tile.get_meta(&"finish")), &"", "%s: no finish on a silhouette" % sz)
			# Still inspectable.
			codex.open_entry(unowned_tile.get_meta(&"entry"), &"")
			await _frames(2)
			assert_true(codex.get_inspector() != null and codex.get_inspector().is_open(), "%s: unowned card inspectable" % sz)
			codex.get_inspector().close()
		vp.queue_free()
		await _frames(1)
	st.set(&"run_profile", saved_profile)
	st.set(&"persist", saved_persist)
	_run_teardown()


func test_title_lockup_and_equipped_operator() -> void:
	_run_setup()
	for sz: Vector2 in [Vector2(844, 390), Vector2(1440, 900)]:
		var got: Array = await _open_in("res://scenes/Title.tscn", sz)
		var title: Control = got[1]
		await _frames(3)
		var label: Label = title.find_child("TitleLabel", true, false) as Label
		assert_true(label != null and label.text == "KILLINGCARD", "%s: the wordmark text stays for readers" % sz)
		var mark: Control = title.find_child("Wordmark", true, false) as Control
		assert_true(mark != null and mark.is_visible_in_tree(), "%s: the stencil lockup" % sz)
		if mark != null:
			assert_true(String((mark.get(&"_font") as Font).resource_path).contains("Stencil"), "%s: Stardos Stencil" % sz)
		var card: Control = title.get_showcase_card()
		assert_not_null(card, "%s: the equipped Operator shown" % sz)
		if card != null:
			assert_eq(String(card.data.get("type", "")), "operator", "%s: an Operator card" % sz)
			assert_true(card.get_global_rect().size.x >= 260.0, "%s: shown large (%.0f px)" % [sz, card.get_global_rect().size.x])
			assert_true(Rect2(Vector2.ZERO, sz).encloses(card.get_global_rect()), "%s: on screen" % sz)
			assert_true(bool(card.get_parent().get_meta(&"inspectable", false)), "%s: inspectable" % sz)
			title.open_showcase_inspector()
			await _frames(2)
			assert_true(title.inspector().is_open(), "%s: opens the inspector" % sz)
			title.inspector().close()
		var amber: int = 0
		for b: Node in title.find_children("*", "Button", true, false):
			if (b as Button).is_visible_in_tree() and (b as Button).theme_type_variation == &"ReadyButton":
				amber += 1
		assert_eq(amber, 1, "%s: exactly one amber button" % sz)
		got[0].queue_free()
		await _frames(1)
	_run_teardown()
