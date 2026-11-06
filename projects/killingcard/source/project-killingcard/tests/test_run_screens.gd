# test_run_screens.gd
# Purpose: p11 run and reward screens. Drives the whole run flow headless with simulated taps
#   (InputEventMouseButton pushed into the screen's viewport) through Title, Loadout, RunMap,
#   Match hand-off, AfterAction, every reward offer type (Supply Drop, weapon level, Perk offer),
#   RunEnd and back, with forced match results; continue-from-save (each phase, and a corrupt
#   save); the replace-run confirmation; Boot's consent routing; the SceneRouter match contract.
#   Every screen is checked at 1280x720 desktop and 844x390 @3x iPhone landscape (with notch
#   insets): the layout fits, every visible control is on screen, text >= 11 pt, every visible
#   button >= 44 pt both ways, Supply Drop cards >= 0.8x with name / cost / stats >= 11 pt.
#   SceneRouter runs in dry_run, so a route is recorded and this test loads the next screen itself.
# Author: UI/UX Agent (p11)
extends "res://tests/test_case.gd"

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const RunFlow: GDScript = preload("res://scripts/ui/run/run_flow.gd")
const BootScript: GDScript = preload("res://scripts/ui/boot.gd")
const MIN_TAP_PT: float = 44.0
const MIN_TEXT_PT: float = 11.0
const EPS: float = 0.5
const PHONE: Dictionary = {"name": "iPhone 844x390 @3x", "pt": Vector2(844, 390), "ratio": 3.0, "notch": true}
const DESKTOP: Dictionary = {"name": "desktop 1280x720", "pt": Vector2(1280, 720), "ratio": 1.0, "notch": false}
const SEED: int = 4242

var _rs: Node = null
var _router: Node = null
var _saved: Dictionary = {}
var _saved_root_size: Vector2i
var _vp: SubViewport = null
var _routes: Array[String] = []
var _screens_checked: Dictionary = {}


# =============================================================================
# Setup
# =============================================================================

func _setup() -> void:
	_rs = tree.root.get_node("RunState")
	_router = tree.root.get_node("SceneRouter")
	var plog: Node = tree.root.get_node("PlaytestLog")
	_saved = {"save_path": _rs.save_path, "autosave": _rs.autosave, "dry_run": _router.dry_run,
			"plog_enabled": plog.enabled}
	plog.enabled = false
	var dir: String = "user://test_run_screens/s%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	_rs.save_path = dir.path_join("run_save.json")
	_rs.autosave = true
	_rs.reset()
	_router.dry_run = true
	_router.pending_match = null
	_router.active_match = null
	_router.last_match_report = {}
	_routes.clear()
	if not _router.scene_change_started.is_connected(_on_route):
		_router.scene_change_started.connect(_on_route)
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)


func _teardown() -> void:
	_close_screen()
	_router.scene_change_started.disconnect(_on_route)
	var dir: String = _rs.save_path.get_base_dir()
	_rs.abandon_run()
	for f: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)
	_rs.save_path = _saved["save_path"]
	_rs.autosave = _saved["autosave"]
	_rs.reset()
	_router.dry_run = _saved["dry_run"]
	_router.pending_match = null
	_router.active_match = null
	_router.last_match_report = {}
	tree.root.get_node("PlaytestLog").enabled = _saved["plog_enabled"]
	tree.root.size = _saved_root_size


func _on_route(path: String) -> void:
	_routes.append(path)


func _logical(screen: Dictionary) -> Vector2:
	var px: Vector2 = screen["pt"] * float(screen["ratio"])
	return ScreenProfile.logical_size(px, ScreenProfile.base_size(px, screen["ratio"]))


func _k(screen: Dictionary) -> float:
	return ScreenProfile.points_per_px(screen["pt"] * float(screen["ratio"]), screen["ratio"])


## Opens a screen in a SubViewport the size of the logical canvas. Phone: notch insets of
## 47 pt left/right and the 21 pt home indicator.
func _open(path: String, screen: Dictionary) -> Control:
	_close_screen()
	_vp = SubViewport.new()
	_vp.size = Vector2i(_logical(screen))
	_vp.disable_3d = true
	_vp.gui_disable_input = false
	tree.root.add_child(_vp)
	var node: Control = (load(path) as PackedScene).instantiate()
	_vp.add_child(node)
	if screen["notch"] and "safe_area_override" in node:
		var k: float = _k(screen)
		var sz: Vector2 = Vector2(_vp.size)
		node.set("safe_area_override", Rect2(47.0 / k, 0.0, sz.x - 94.0 / k, sz.y - 21.0 / k))
	await _frames(4)
	return node


func _close_screen() -> void:
	if _vp != null:
		_vp.queue_free()
		_vp = null


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_vp.push_input(e)


## Taps the middle of a control (press, a frame, release), like a finger on the phone.
## kc-trait-ui: a Promotion of a Recruit / a twin training opens TRAIN AS (one tile per trait option);
## checks it and taps the pre-selected trait. No-op when no picker opened.
func _train_pick(reward: Control, label: String, screen: Dictionary) -> void:
	await _frames(2)
	if reward.train_pick.is_empty():
		return
	assert_false(reward.pick_tiles.is_empty(), "%s: TRAIN AS lists the trait options" % label)
	_check(reward, screen, "train as")
	var pre: Control = null
	for t: Control in reward.pick_tiles:
		assert_not_null(t.find_child("RandomArtLine", true, false), "%s: says what art it gets" % label)
		if bool(t.get_meta(&"preselected", false)):
			pre = t
	assert_not_null(pre, "%s: one option is pre-selected" % label)
	await _tap(pre if pre != null else reward.pick_tiles[0])


func _tap(ctl: Control) -> void:
	assert_true(ctl.is_visible_in_tree(), "tap target %s is visible" % ctl.name)
	var pos: Vector2 = ctl.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	_vp.push_input(motion)
	_mouse(pos, true)
	await _frames(1)
	_mouse(pos, false)
	await _frames(3)


## Taps ctl and checks the router was asked for `expected`; then opens that screen.
func _tap_to(ctl: Control, expected: String, screen: Dictionary) -> Control:
	_routes.clear()
	await _tap(ctl)
	assert_true(_routes.size() >= 1 and _routes[-1] == expected,
			"%s: %s routes to %s (got %s)" % [screen["name"], ctl.name, expected.get_file(), _routes])
	if _routes.is_empty() or _routes[-1] != expected or expected == RunFlow.SCENE_MATCH:
		return null
	return await _open(expected, screen)


func _button(node: Node, text_starts: String) -> Button:
	for c: Node in node.find_children("*", "Button", true, false):
		var b: Button = c
		if b.is_visible_in_tree() and b.text.begins_with(text_starts):
			return b
	return null


func _all_text(node: Node) -> String:
	var parts: PackedStringArray = []
	for c: Node in node.find_children("*", "Label", true, false):
		if (c as Label).is_visible_in_tree():
			parts.append((c as Label).text)
	return "\n".join(parts)


## Size / tap checks for the screen on show.
func _check(node: Control, screen: Dictionary, what: String) -> void:
	var k: float = _k(screen)
	var rect: Rect2 = Rect2(Vector2.ZERO, Vector2(_vp.size)).grow(EPS)
	var label: String = "%s %s" % [screen["name"], what]
	var needed: Vector2 = node.get_node("%SafeArea").get_combined_minimum_size()
	assert_true(needed.x <= _vp.size.x + EPS and needed.y <= _vp.size.y + EPS,
			"%s needs %s but the screen is %s" % [label, needed, _vp.size])
	var checked: int = 0
	for c: Node in node.find_children("*", "Control", true, false):
		var ctl: Control = c
		if not ctl.is_visible_in_tree() or _inside(ctl, "CardView") or _inside(ctl, "ScrollContainer"):
			continue
		var r: Rect2 = ctl.get_global_rect()
		assert_true(rect.encloses(r), "%s: %s at %s is off screen %s" % [label, ctl.name, r, rect])
		if ctl is Label and (ctl as Label).text != "":
			var pt: float = ctl.get_theme_font_size(&"font_size") * k
			assert_true(pt >= MIN_TEXT_PT - 0.01, "%s: %s text %.1f pt" % [label, ctl.name, pt])
			checked += 1
		elif ctl is Button:
			var b: Button = ctl
			assert_true(b.size.y * k >= MIN_TAP_PT and b.size.x * k >= MIN_TAP_PT,
					"%s: %s tap target %.1fx%.1f pt" % [label, b.name, b.size.x * k, b.size.y * k])
			assert_true(b.get_theme_font_size(&"font_size") * k >= MIN_TEXT_PT, "%s: %s button text" % [label, b.name])
			checked += 1
	# Scrolling content still has to be readable.
	for c: Node in node.find_children("*", "Label", true, false):
		if _inside(c, "ScrollContainer") and (c as Label).is_visible_in_tree() and (c as Label).text != "":
			assert_true((c as Label).get_theme_font_size(&"font_size") * k >= MIN_TEXT_PT - 0.01,
					"%s: scrolled %s text" % [label, c.name])
	assert_true(checked >= 3, "%s: checked %d controls" % [label, checked])
	_screens_checked["%s|%s" % [screen["name"], what]] = true


static func _inside(ctl: Node, type_name: String) -> bool:
	var p: Node = ctl.get_parent()
	while p != null:
		if p.is_class(type_name) or (type_name == "CardView" and p is CardView):
			return true
		p = p.get_parent()
	return false


# =============================================================================
# The whole run, one tap at a time
# =============================================================================

func test_full_run_desktop() -> void:
	await _full_run(DESKTOP)


func test_full_run_phone() -> void:
	await _full_run(PHONE)


## Fresh run: Title -> Loadout -> 5 matches (win, win, loss, draw, Rival win) with every offer
## type taken or skipped by tapping -> RunEnd victory -> NEW RUN.
func _full_run(screen: Dictionary) -> void:
	_setup()
	var bus: Node = tree.root.get_node("EventBus")
	var next_clicks: Array = [0]
	var shown: Array[StringName] = []
	var on_next: Callable = func() -> void: next_clicks[0] += 1
	var on_shown: Callable = func(s: StringName) -> void: shown.append(s)
	bus.next_match_requested.connect(on_next)
	bus.screen_shown.connect(on_shown)
	var label: String = screen["name"]

	# Title: no save, so only START NEW RUN.
	var title: Control = await _open(RunFlow.SCENE_TITLE, screen)
	assert_false(title.get_node("%ContinueButton").visible, "%s: no Continue without a save" % label)
	_check(title, screen, "title")
	var loadout: Control = await _tap_to(title.get_node("%StartButton"), RunFlow.SCENE_LOADOUT, screen)
	assert_not_null(_rs.run, "%s: Start began a run" % label)
	_rs.run.seed_value = SEED  # deterministic offers below

	# kc-ui4: the loadout opens on STARTING SQUAD (Operator pick + the starter deck by card).
	await _frames(2)
	var starter: Control = loadout.get_starter()
	assert_not_null(starter, "%s: the starter panel opens first" % label)
	_check(loadout, screen, "loadout starter")
	assert_eq(starter.get_deck_tiles().map(func(t: Control) -> int: return int(t.get_meta(&"count"))).reduce(func(a: int, b: int) -> int: return a + b, 0),
			_rs.run.deck.size(), "%s: the grouped starter adds up to the deck" % label)
	await _tap(_button(starter, "NEXT: KILLSTREAKS"))
	await _frames(2)
	assert_true(loadout.get_starter() == null, "%s: NEXT closes it" % label)
	# Loadout: starter kit shown, starter killstreaks pre-picked; swap Mortar for Sentry.
	_check(loadout, screen, "loadout")
	var text: String = _all_text(loadout)
	for word: String in ["Kestrel AR-7", "P-12 Sidearm", "Frag Grenade", "Flashbang", "20 cards"]:
		assert_true(word in text, "%s: loadout shows %s" % [label, word])
	assert_eq(loadout.picked.size(), 3, "%s: starter killstreaks pre-picked" % label)
	var begin: Button = _button(loadout, "BEGIN RUN")
	await _tap(loadout.get_node("%Body").find_child("Killstreak_mortar_barrage", true, false))
	assert_true(begin.disabled, "%s: BEGIN needs 3 picks" % label)
	await _tap(loadout.get_node("%Body").find_child("Killstreak_sentry_turret", true, false))
	assert_false(begin.disabled, "%s: 3 picks enable BEGIN" % label)
	_check(loadout, screen, "loadout picked")
	var map: Control = await _tap_to(begin, RunFlow.SCENE_RUN_MAP, screen)
	assert_eq(_rs.run.killstreaks, [&"recon_drone", &"attack_helo", &"sentry_turret"] as Array[StringName], "%s: picks saved" % label)
	assert_eq(_rs.run.phase, RunProgress.PHASE_MATCH, "%s: run begun" % label)

	# Match 1 through the real hand-off: RunMap DEPLOY -> pending MatchState -> finish_run_match.
	var plan: Array = [
		# kc-syn-ui: synergy offers on (Doctrine after M1, Promotion after M2 / M4, Regroup after a loss).
		[&"player", {"reason": &"target", "rounds": 6, "player_score": 6, "enemy_score": 3}, [RewardOffers.KIND_SUPPLY_DROP, RewardOffers.KIND_DOCTRINE, RewardOffers.KIND_ATTACHMENT]],
		[&"player", {"reason": &"round_cap", "rounds": 8, "player_score": 7, "enemy_score": 5}, [RewardOffers.KIND_SUPPLY_DROP, RewardOffers.KIND_PROMOTION, RewardOffers.KIND_PERK]],
		[&"enemy", {"reason": &"target", "rounds": 5, "player_score": 2, "enemy_score": 6}, [RewardOffers.KIND_REGROUP, RewardOffers.KIND_ATTACHMENT]],
		[&"draw", {"reason": &"overtime_draw", "rounds": 10, "player_score": 5, "enemy_score": 5}, [RewardOffers.KIND_ATTACHMENT, RewardOffers.KIND_PROMOTION, RewardOffers.KIND_PERK]],
		[&"player", {"reason": &"target", "rounds": 7, "player_score": 6, "enemy_score": 4}, []],
	]
	for i: int in plan.size():
		var step: Array = plan[i]
		var what: String = "run map %d" % (i + 1)
		_check(map, screen, what)
		var node: PanelContainer = map.get_match_node(i)
		assert_eq(node.theme_type_variation, &"RunNodeNext", "%s: match %d marked next" % [label, i + 1])
		assert_true("NEXT" in _all_text(node), "%s: match %d says NEXT" % [label, i + 1])
		var md: RunMatchData = _rs.run.config.matches[i]
		var node_text: String = _all_text(node)
		for word: String in [RunFlow.squad_word(md), RunFlow.mode_word(md.mode), md.map.display_name, RunFlow.bonus_word(md)]:
			assert_true(word in node_text, "%s: match %d shows %s" % [label, i + 1, word])
		assert_true(("%d/3" % _rs.run.tickets) in _all_text(map), "%s: tickets left shown" % label)
		var clicks: int = next_clicks[0]
		await _tap_to(_button(map, "DEPLOY"), RunFlow.SCENE_MATCH, screen)
		assert_eq(next_clicks[0], clicks + 1, "%s: DEPLOY emits next_match_requested" % label)
		var m: MatchState = _router.take_pending_match()
		assert_not_null(m, "%s: DEPLOY handed a MatchState to Match" % label)
		if m == null:
			break
		assert_eq(m.seed_value, _rs.run.match_seed(), "%s: run match seed" % label)
		assert_true(_router.is_run_match(m), "%s: is_run_match" % label)
		_routes.clear()
		var report: Dictionary
		if i == 0:
			# Played like Match.tscn would: start it, end it, hand it back.
			m.start_match()
			m.result = step[0]
			var outcome: Dictionary = (step[1] as Dictionary).duplicate()
			outcome["result"] = step[0]
			m.hooks.mode_rules.outcome = outcome
			m.sides[0].eliminations = 9
			m.sides[1].eliminations = 4
			m.emit_event(RulesEvent.STREAK_CHANGED, {"side": &"player", "streak": 4, "before": 2, "gained": 2, "reset": false, "earned": []})
			report = _router.finish_run_match(m)
			assert_eq(report["best_streak"], 4, "%s: best streak from events" % label)
			assert_eq(report["player_eliminations"], 9, "%s: eliminations from the match" % label)
		else:
			report = _router.finish_run_match_forced(step[0], step[1], {"best_streak": i, "player_eliminations": 3 + i, "enemy_eliminations": 2})
		assert_true(report.get("ok", false), "%s: match %d recorded" % [label, i + 1])
		assert_eq(_routes, [RunFlow.SCENE_AFTER_ACTION] as Array[String], "%s: match end routes to AfterAction" % label)
		var aa: Control = await _open(RunFlow.SCENE_AFTER_ACTION, screen)
		_check(aa, screen, "after-action %d" % (i + 1))
		var aa_text: String = _all_text(aa)
		var word: String = {&"player": "VICTORY", &"enemy": "DEFEAT"}.get(step[0], "DRAW")
		assert_true(word in aa_text, "%s: after-action %d says %s" % [label, i + 1, word])
		assert_true(("%d-%d" % [step[1]["player_score"], step[1]["enemy_score"]]) in aa_text, "%s: score shown" % label)
		assert_true(str(step[1]["rounds"]) in aa_text, "%s: rounds shown" % label)
		if step[0] == &"enemy":
			assert_true("-1 (was 3)" in aa_text and "2/3" in aa_text, "%s: ticket change shown" % label)
		else:
			assert_true("no change" in aa_text, "%s: no ticket change" % label)
		# Offers in order, each resolved with one tap.
		var kinds: Array = step[2]
		if kinds.is_empty():
			var end: Control = await _tap_to(_button(aa, "RUN SUMMARY"), RunFlow.SCENE_RUN_END, screen)
			_check(end, screen, "run end victory")
			var end_text: String = _all_text(end)
			assert_true("VICTORY" in end_text and "You beat the Rival squad." in end_text, "%s: victory summary" % label)
			assert_true("Record 3 won, 1 lost, 1 drawn" in end_text, "%s: record" % label)
			assert_true("Tickets left 2 of 3" in end_text, "%s: tickets left" % label)
			var again: Control = await _tap_to(_button(end, "NEW RUN"), RunFlow.SCENE_LOADOUT, screen)
			assert_not_null(_rs.run, "%s: NEW RUN started a run" % label)
			assert_eq(_rs.run.phase, RunProgress.PHASE_LOADOUT, "%s: new run in loadout" % label)
			assert_not_null(again, "%s: loadout open" % label)
			break
		var reward: Control = await _tap_to(_button(aa, "CONTINUE:"), RunFlow.SCENE_REWARD, screen)
		for j: int in kinds.size():
			var kind: StringName = kinds[j]
			assert_eq(reward.offer.get("kind", &""), kind, "%s: match %d offer %d is %s" % [label, i + 1, j + 1, kind])
			assert_eq(shown[-1], StringName("reward_" + String(kind)), "%s: screen_shown for %s" % [label, kind])
			_check(reward, screen, "reward %s m%d" % [kind, i + 1])
			var last: bool = j == kinds.size() - 1
			var deck: int = _rs.run.deck.size()
			var atts: int = _rs.run.attachments.size()
			var perks: int = _rs.run.perks.size()
			_routes.clear()
			if kind == RewardOffers.KIND_SUPPLY_DROP:
				assert_eq(reward.card_views.size(), 3, "%s: Supply Drop shows 3 cards" % label)
				assert_true(reward.get_card_scale() >= 0.8 - 0.001, "%s: card scale %.2f" % [label, reward.get_card_scale()])
				for t: int in reward.tiles.size():
					var tile_rect: Rect2 = reward.tiles[t].get_global_rect().grow(EPS)
					var card_rect: Rect2 = reward.card_views[t].get_global_rect()
					var rules: Label = reward.tiles[t].find_child("RulesLabel", true, false)
					assert_true(tile_rect.encloses(card_rect), "%s: card %d inside its tile (%s in %s)" % [label, t, card_rect, tile_rect])
					assert_true(rules.size.y >= 20.0 and not card_rect.intersects(rules.get_global_rect().grow(-1.0)),
							"%s: rules line %d below the card (%s vs %s)" % [label, t, rules.get_global_rect(), card_rect])
					assert_true(reward.detail_buttons[t].get_global_rect().position.y >= card_rect.end.y - EPS, "%s: DETAILS below card %d" % [label, t])
					assert_true(rules.get_line_count() <= rules.max_lines_visible, "%s: rules line %d cut to fit (%d lines)" % [label, t, rules.get_line_count()])
					if screen == DESKTOP:
						assert_true(reward.get_card_scale() > 1.0, "desktop cards above 1x (%.2f)" % reward.get_card_scale())
				for v: Control in reward.card_views:
					var pt: float = v.get_min_effective_font_size(PackedStringArray(["NameLabel", "CostLabel", "FirepowerLabel", "ArmorLabel"])) * _k(screen)
					assert_true(pt >= MIN_TEXT_PT, "%s: card face %.1f pt" % [label, pt])
				# DETAILS opens the inspector without choosing; CLOSE shuts it.
				await _tap(reward.detail_buttons[1])
				assert_true(reward.get_inspector().is_open(), "%s: DETAILS opens the inspector" % label)
				assert_eq(_rs.run.deck.size(), deck, "%s: DETAILS doesn't pick" % label)
				await _tap(reward.get_inspector().get_node("%CloseButton"))
				assert_false(reward.get_inspector().is_open(), "%s: CLOSE shuts the inspector" % label)
				assert_not_null(reward.retire_tile, "%s: Supply Drop has the Retire option" % label)
				if i == 1:
					# kc-syn-ui: the 4th option: Retire a card (a Recruit with a twin trains the twin).
					await _tap(reward.retire_tile)
					await _frames(2)
					assert_true(reward.retire_mode and not reward.list_tiles.is_empty(), "%s: Retire lists the deck" % label)
					_check(reward, screen, "retire picker m%d" % (i + 1))
					var opt: Dictionary = _rs.run.retire_options()[0]
					var honor: int = _rs.run.honor_roll.size()
					if int(opt["twin_index"]) >= 0:
						assert_true(reward.list_tiles[0].find_child("TwinLine", true, false) != null, "%s: twin-training preview" % label)
					await _tap(reward.list_tiles[0])
					await _train_pick(reward, label, screen)
					assert_eq(_rs.run.deck.size(), deck - 1, "%s: Retire removes a card" % label)
					assert_eq(_rs.run.honor_roll.size(), honor + 1, "%s: retired card on the Honor Roll" % label)
				else:
					var want: StringName = reward.offer["options"][1]
					await _tap(reward.tiles[1])
					assert_eq(_rs.run.deck.size(), deck + 1, "%s: tapping a card adds it" % label)
					assert_eq(_rs.run.deck[-1], want, "%s: the tapped card" % label)
			elif kind == RewardOffers.KIND_ATTACHMENT:
				assert_eq(reward.tiles.size(), 2, "%s: 2 attachments" % label)
				if i == 2:
					await _tap(reward._skip_button)
					assert_eq(_rs.run.attachments.size(), atts, "%s: skipped attachment" % label)
				else:
					var want_att: StringName = reward.offer["options"][0]
					assert_true(_rs.run.resource(want_att).display_name.to_upper() in _all_text(reward.tiles[0]), "%s: attachment name" % label)
					await _tap(reward.tiles[0])
					assert_eq(_rs.run.attachments.size(), atts + 1, "%s: attachment fitted" % label)
					assert_eq(_rs.run.attachments[-1], want_att, "%s: the tapped attachment" % label)
			elif kind == RewardOffers.KIND_DOCTRINE:
				assert_eq(reward.tiles.size(), 2, "%s: 2 Doctrine emblems" % label)
				var want_doc: StringName = reward.offer["options"][0]
				await _tap(reward.tiles[0])
				assert_eq(_rs.run.doctrine, want_doc, "%s: Doctrine picked" % label)
			elif kind == RewardOffers.KIND_PROMOTION:
				assert_eq(reward.list_tiles.size(), (reward.offer["options"] as Array).size(), "%s: one tile per promotion option" % label)
				var pid: StringName = reward.offer["options"][0]
				var plv: int = int(reward.offer["levels"][0])
				var before_up: int = 0
				for d: Dictionary in _rs.run.deck_view():
					before_up += 1 if d["id"] == pid and int(d["level"]) == plv + 1 else 0
				await _tap(reward.list_tiles[0])
				await _train_pick(reward, label, screen)
				var after_up: int = 0
				for d: Dictionary in _rs.run.deck_view():
					after_up += 1 if d["id"] == pid and int(d["level"]) == plv + 1 else 0
				assert_eq(after_up, before_up + 1, "%s: one copy promoted" % label)
			elif kind == RewardOffers.KIND_REGROUP:
				assert_false(reward.list_tiles.is_empty(), "%s: Regroup lists cards to retire" % label)
				await _tap(reward.list_tiles[0])
				await _train_pick(reward, label, screen)
				assert_eq(_rs.run.deck.size(), deck - 1, "%s: Regroup retires a card" % label)
			else:
				assert_eq(reward.tiles.size(), 2, "%s: 2 perks" % label)
				var want_perk: StringName = reward.offer["options"][1]
				await _tap(reward.tiles[1])
				assert_eq(_rs.run.perks.size(), perks + 1, "%s: perk taken" % label)
				assert_eq(_rs.run.perks[-1], want_perk, "%s: the tapped perk" % label)
			await _frames(2)
			if last:
				assert_eq(_routes, [RunFlow.SCENE_RUN_MAP] as Array[String], "%s: last offer -> run map" % label)
			else:
				assert_true(_routes.is_empty(), "%s: next offer on the same screen" % label)
		map = await _open(RunFlow.SCENE_RUN_MAP, screen)
		var done: PanelContainer = map.get_match_node(i)
		assert_eq(done.theme_type_variation, &"RunNodeDone", "%s: match %d done" % [label, i + 1])
		assert_true(RunFlow.result_word(step[0]) in _all_text(done), "%s: match %d result on the map" % [label, i + 1])
	assert_true(_screens_checked.size() >= 15, "%s: %d screens checked" % [label, _screens_checked.size()])
	assert_eq(_rs.run.config.matches.size(), 5, "5-match run")
	bus.next_match_requested.disconnect(on_next)
	bus.screen_shown.disconnect(on_shown)
	_teardown()


# =============================================================================
# Defeat and the end survey
# =============================================================================

func test_defeat_out_of_tickets_and_survey() -> void:
	_setup()
	_start_begun_run()
	for i: int in 3:
		_router.finish_run_match_forced(&"enemy", {"reason": &"target", "rounds": 5, "player_score": 1, "enemy_score": 6})
		while not _rs.current_offer().is_empty():
			_rs.skip_offer()
	assert_true(_rs.run.is_over(), "3 losses end the run")
	var aa: Control = await _open(RunFlow.SCENE_AFTER_ACTION, PHONE)
	_check(aa, PHONE, "after-action last defeat")
	assert_true("DEFEAT" in _all_text(aa), "defeat shown")
	assert_true("0/3" in _all_text(aa) and "-1 (was 1)" in _all_text(aa), "last ticket shown")
	var end: Control = await _tap_to(_button(aa, "RUN SUMMARY"), RunFlow.SCENE_RUN_END, PHONE)
	_check(end, PHONE, "run end defeat")
	var text: String = _all_text(end)
	assert_true("DEFEAT" in text and "RUN OVER" in text, "defeat summary")
	assert_true("You ran out of Reinforcement Tickets." in text, "reason in words")
	assert_true("Record 0 won, 3 lost, 0 drawn" in text, "record")
	# Playtest logging on and the end survey not done: the button goes to the survey first.
	var plog: Node = tree.root.get_node("PlaytestLog")
	var saved_path: String = plog.log_path
	plog.log_path = _rs.save_path.get_base_dir().path_join("playtest_log.jsonl")
	plog.enabled = true
	plog.end_survey_done = false
	end = await _open(RunFlow.SCENE_RUN_END, DESKTOP)
	_check(end, DESKTOP, "run end survey")
	var survey: Button = _button(end, "PLAYTEST SURVEY")
	assert_not_null(survey, "survey button while logging")
	assert_false(_button(end, "TITLE") != null, "no TITLE shortcut past the survey")
	if survey != null:
		await _tap_to(survey, RunFlow.SCENE_END_SURVEY, DESKTOP)
	assert_eq(_rs.run, null, "ended run dropped")
	assert_false(_rs.has_save(), "ended run's save deleted")
	plog.enabled = false
	plog.flush()
	plog.log_path = saved_path
	_teardown()


# =============================================================================
# Continue from a save
# =============================================================================

func _start_begun_run() -> void:
	_rs.start_run(SEED)
	_rs.set_killstreaks([&"recon_drone", &"mortar_barrage", &"attack_helo"])
	_rs.begin_run()


func test_continue_into_rewards() -> void:
	_setup()
	_start_begun_run()
	_router.finish_run_match_forced(&"player", {"reason": &"target", "rounds": 6, "player_score": 6, "enemy_score": 2})
	var options: Array = _rs.current_offer()["options"].duplicate()
	assert_true(_rs.has_save(), "run saved")
	_rs.reset()  # a browser reload
	_router.last_match_report = {}
	for screen: Dictionary in [PHONE, DESKTOP]:
		_rs.reset()
		var title: Control = await _open(RunFlow.SCENE_TITLE, screen)
		var cont: Button = title.get_node("%ContinueButton")
		assert_true(cont.visible, "%s: Continue shown with a save" % screen["name"])
		_check(title, screen, "title with save")
		var reward: Control = await _tap_to(cont, RunFlow.SCENE_REWARD, screen)
		assert_eq(reward.offer["kind"], RewardOffers.KIND_SUPPLY_DROP, "%s: back on the Supply Drop" % screen["name"])
		assert_eq(reward.offer["options"], options, "%s: same cards after reload" % screen["name"])
	# The After-Action report survives a reload too (rebuilt from history).
	var aa: Control = await _open(RunFlow.SCENE_AFTER_ACTION, PHONE)
	assert_true("VICTORY" in _all_text(aa) and "6-2" in _all_text(aa), "after-action from history")
	assert_true("—" in _all_text(aa), "unknown stats shown as a dash")
	_teardown()


func test_continue_each_phase() -> void:
	_setup()
	_rs.start_run(SEED)
	_rs.reset()
	var title: Control = await _open(RunFlow.SCENE_TITLE, PHONE)
	await _tap_to(title.get_node("%ContinueButton"), RunFlow.SCENE_LOADOUT, PHONE)
	_rs.set_killstreaks([&"recon_drone", &"mortar_barrage", &"attack_helo"])
	_rs.begin_run()
	_rs.reset()
	title = await _open(RunFlow.SCENE_TITLE, PHONE)
	var map: Control = await _tap_to(title.get_node("%ContinueButton"), RunFlow.SCENE_RUN_MAP, PHONE)
	assert_eq(map.get_match_node(0).theme_type_variation, &"RunNodeNext", "continued at match 1")
	_teardown()


func test_continue_corrupt_save_shows_warning() -> void:
	_setup()
	var f: FileAccess = FileAccess.open(_rs.save_path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var title: Control = await _open(RunFlow.SCENE_TITLE, PHONE)
	var cont: Button = title.get_node("%ContinueButton")
	assert_true(cont.visible, "Continue shown for the file on disk")
	_routes.clear()
	await _tap(cont)
	assert_true(_routes.is_empty(), "a bad save routes nowhere")
	assert_false(cont.visible, "Continue hidden after the failure")
	var warning: Label = title.get_node("%WarningLabel")
	assert_true(warning.is_visible_in_tree(), "warning shown")
	assert_eq(warning.text, _rs.last_load_warning, "shows RunState.last_load_warning")
	assert_true(warning.text.begins_with("Saved run could not be loaded"), "warning text: %s" % warning.text)
	_check(title, PHONE, "title load warning")
	await _tap_to(title.get_node("%StartButton"), RunFlow.SCENE_LOADOUT, PHONE)
	_teardown()


func test_start_over_asks_before_replacing_a_save() -> void:
	_setup()
	_start_begun_run()
	var seed_before: int = _rs.run.seed_value
	_rs.reset()
	var title: Control = await _open(RunFlow.SCENE_TITLE, PHONE)
	_routes.clear()
	await _tap(title.get_node("%StartButton"))
	assert_true(_routes.is_empty(), "first tap only asks")
	assert_true(title.get_node("%ConfirmPanel").is_visible_in_tree(), "confirmation shown")
	_check(title, PHONE, "title confirm replace")
	await _tap(title.get_node("%KeepButton"))
	assert_false(title.get_node("%ConfirmPanel").is_visible_in_tree(), "KEEP IT closes it")
	assert_true(_rs.has_save(), "save kept")
	await _tap(title.get_node("%StartButton"))
	await _tap_to(title.get_node("%ReplaceButton"), RunFlow.SCENE_LOADOUT, PHONE)
	assert_true(_rs.run != null and _rs.run.phase == RunProgress.PHASE_LOADOUT, "new run")
	assert_true(_rs.run.seed_value != seed_before or _rs.run.history.is_empty(), "replaced")
	_teardown()


# =============================================================================
# Loadout rules, routing, hand-off contract
# =============================================================================

func test_loadout_slot_limit() -> void:
	_setup()
	_rs.start_run(SEED)
	var loadout: Control = await _open(RunFlow.SCENE_LOADOUT, DESKTOP)
	await _frames(2)
	if loadout.get_starter() != null:
		loadout.get_starter().close()
		await _frames(2)
	_check(loadout, DESKTOP, "loadout desktop")
	var sentry: Button = loadout.get_node("%Body").find_child("Killstreak_sentry_turret", true, false)
	await _tap(sentry)
	assert_eq(loadout.picked.size(), 3, "a 4th pick is refused")
	assert_false(sentry.selected, "sentry not picked")
	assert_true("slots are full" in _all_text(loadout), "says why")
	var recon: Button = loadout.get_node("%Body").find_child("Killstreak_recon_drone", true, false)
	assert_true(recon.selected and "PICKED" in _all_text(recon), "picked tile says PICKED")
	assert_eq(recon.theme_type_variation, &"PickTileSelected", "picked tile style")
	_routes.clear()
	await _tap(_button(loadout, "BACK"))
	assert_eq(_routes, [RunFlow.SCENE_TITLE] as Array[String], "BACK -> Title")
	_teardown()


func test_boot_routes_through_consent() -> void:
	var plog: Node = tree.root.get_node("PlaytestLog")
	var answered: bool = plog.consent_answered
	plog.consent_answered = false
	assert_eq(BootScript.first_scene(plog, false), "res://scenes/survey/Consent.tscn", "consent first")
	assert_eq(BootScript.first_scene(plog, true), "res://scenes/Title.tscn", "headless skips consent")
	plog.consent_answered = true
	assert_eq(BootScript.first_scene(plog, false), "res://scenes/Title.tscn", "answered -> Title")
	plog.consent_answered = answered


func test_scene_for_phase() -> void:
	_setup()
	assert_eq(RunFlow.scene_for(null), RunFlow.SCENE_TITLE, "no run")
	_rs.start_run(SEED)
	assert_eq(RunFlow.scene_for(_rs.run), RunFlow.SCENE_LOADOUT, "loadout")
	_rs.begin_run()
	assert_eq(RunFlow.scene_for(_rs.run), RunFlow.SCENE_RUN_MAP, "match")
	_rs.record_result(&"player")
	assert_eq(RunFlow.scene_for(_rs.run), RunFlow.SCENE_REWARD, "rewards")
	for scene: String in [RunFlow.SCENE_LOADOUT, RunFlow.SCENE_RUN_MAP, RunFlow.SCENE_AFTER_ACTION,
			RunFlow.SCENE_REWARD, RunFlow.SCENE_RUN_END, RunFlow.SCENE_MATCH]:
		assert_true(ResourceLoader.exists(scene), "%s exists" % scene)
	_teardown()


func test_match_handoff_contract() -> void:
	_setup()
	_start_begun_run()
	_routes.clear()
	var m: MatchState = _router.start_run_match()
	assert_not_null(m, "start_run_match makes a MatchState")
	assert_eq(_routes, [RunFlow.SCENE_MATCH] as Array[String], "opens Match.tscn")
	assert_eq(m.phase, MatchState.Phase.SETUP, "not started yet")
	assert_eq(_router.take_pending_match(), m, "Match takes it")
	assert_eq(_router.take_pending_match(), null, "only once")
	var other: MatchState = _rs.create_match()
	var refused: Dictionary = _router.finish_run_match(other)
	assert_false(refused["ok"], "another match is refused")
	assert_eq(_rs.run.history.size(), 0, "nothing recorded")
	m.result = &"draw"
	m.hooks.mode_rules.outcome = {"result": &"draw", "reason": &"overtime_draw", "rounds": 10, "player_score": 4, "enemy_score": 4}
	_routes.clear()
	var rep: Dictionary = _router.finish_run_match(m)
	assert_true(rep["ok"], "recorded")
	assert_eq(_routes, [RunFlow.SCENE_AFTER_ACTION] as Array[String], "-> AfterAction")
	assert_eq(_rs.run.history.size(), 1, "one match in history")
	assert_false(_router.is_run_match(m), "hand-off cleared")
	assert_eq(_router.finish_run_match(m)["ok"], false, "a second finish is refused")
	_teardown()


# =============================================================================
# kc-trait-ui: Supply Drop copies, Re-issue, TRAIN AS (Promotion / twin), deck view traits
# =============================================================================

func test_trait_ui_reward_flows() -> void:
	for screen: Dictionary in [PHONE, DESKTOP]:
		_setup()
		var label: String = screen["name"]
		_rs.start_run(SEED)
		_rs.begin_run()
		var r: RunProgress = _rs.run
		var mk: CardData = r.resource(&"marksman") as CardData
		var at: int = r.deck.size()
		r._append_copy(&"marksman", 1, &"specops", r._random_art(mk, &"specops"))
		_rs.record_result(&"player")
		var reward: Control = await _open(RunFlow.SCENE_REWARD, screen)
		assert_eq(reward.offer["kind"], RewardOffers.KIND_SUPPLY_DROP, "%s: Supply Drop" % label)
		_check(reward, screen, "trait supply drop")
		# Each card is a concrete copy: the tile carries the trait its art gives, with the icon line.
		for i: int in reward.tiles.size():
			var c: CardData = r.resource(reward.offer["options"][i]) as CardData
			if c.is_unit() and c.has_trait_choice():
				assert_eq(reward.tiles[i].get_meta(&"trait"), StringName(reward.offer["traits"][i]), "%s: tile %d trait" % [label, i])
				var head: Node = reward.tiles[i].find_child("TraitLine", true, false)
				assert_not_null(head, "%s: tile %d trait line" % [label, i])
				assert_eq((head.find_child("TraitIcon", true, false) as Control).get_meta(&"trait"), StringName(reward.offer["traits"][i]), "%s: icon" % label)
		# DETAILS (the more-info view) names the art and the trait it gives.
		await _tap(reward.detail_buttons[0])
		assert_true(reward.get_inspector().is_open(), "%s: DETAILS" % label)
		await _tap(reward.get_inspector().get_node("%CloseButton"))
		# RE-ISSUE next to RETIRE: pick the Marksman, then Heavy.
		assert_not_null(reward.reissue_tile, "%s: Re-issue option" % label)
		assert_not_null(reward.retire_tile, "%s: Retire option still there" % label)
		await _tap(reward.reissue_tile)
		assert_true(reward.reissue_mode and not reward.list_tiles.is_empty(), "%s: Re-issue lists copies" % label)
		_check(reward, screen, "reissue copies")
		var rows: Array[Dictionary] = r.reissue_options()
		var ri: int = rows.map(func(o: Dictionary) -> int: return int(o["index"])).find(at)
		assert_true(ri >= 0, "%s: the Marksman is listed" % label)
		await _tap(reward.list_tiles[ri])
		assert_eq(reward.reissue_row, ri, "%s: copy picked" % label)
		assert_not_null(reward.find_child("NowCard", true, false), "%s: preview of the copy now" % label)
		_check(reward, screen, "reissue traits")
		var heavy: Control = null
		for t: Control in reward.pick_tiles:
			if t.get_meta(&"trait") == &"heavy":
				heavy = t
		assert_not_null(heavy, "%s: a Heavy tile" % label)
		assert_true((heavy.find_child("RandomArtLine", true, false) as Label).text.contains("random Heavy art"), "%s: says the art is random" % label)
		var deck: int = r.deck.size()
		await _tap(heavy)
		await _frames(2)
		assert_eq(r.copy_trait(at), &"heavy", "%s: re-issued as Heavy" % label)
		assert_eq(ArtTraits.trait_of(r.art_of(at), mk), &"heavy", "%s: wearing a Heavy art" % label)
		assert_eq(r.deck.size(), deck, "%s: no card added" % label)
		# Promotion of a Recruit: TRAIN AS with counts and the pre-selected option.
		r.pending_offers.clear()
		r.phase = RunProgress.PHASE_REWARDS
		r._add_synergy_offer(RewardOffers.KIND_PROMOTION, 1)
		reward.show_offer()
		await _frames(2)
		var popts: Array[Dictionary] = r.promotion_options()
		var pi: int = -1
		for i: int in popts.size():
			if bool(popts[i]["trains"]) and (r.resource(popts[i]["id"]) as CardData).trait_choices().size() > 1:
				pi = i
				break
		assert_true(pi >= 0, "%s: a Recruit to train" % label)
		var copy: int = int(popts[pi]["index"])
		var pid: StringName = popts[pi]["id"]
		await _tap(reward.list_tiles[pi])
		assert_false(reward.train_pick.is_empty(), "%s: TRAIN AS opened" % label)
		_check(reward, screen, "train as")
		var choices: Array[Dictionary] = r.train_choices(copy)
		assert_eq(reward.pick_tiles.size(), choices.size(), "%s: one tile per option" % label)
		var alt: Control = null
		for t: Control in reward.pick_tiles:
			assert_true((t.find_child("CountLine", true, false) as Label).text.contains(">") or t.get_meta(&"trait") == &"", "%s: count change" % label)
			if not bool(t.get_meta(&"preselected")):
				alt = t
		assert_eq(reward.pick_tiles.filter(func(t: Control) -> bool: return bool(t.get_meta(&"preselected"))).size(), 1, "%s: one pre-selected" % label)
		var alt_t: StringName = alt.get_meta(&"trait")
		await _tap(alt)
		await _frames(2)
		assert_eq(r.level_of(copy), SynergyRules.LEVEL_TRAINED, "%s: trained" % label)
		assert_eq(r.copy_trait(copy), alt_t, "%s: into the picked trait" % label)
		assert_eq(ArtTraits.trait_of(r.art_of(copy), r.resource(pid) as CardData), alt_t, "%s: with an art of it" % label)
		# Regroup: RE-ISSUE in the header; a Recruit with a twin opens TRAIN AS for the twin.
		r.pending_offers.clear()
		r.phase = RunProgress.PHASE_REWARDS
		r._add_synergy_offer(RewardOffers.KIND_REGROUP, 1)
		reward.show_offer()
		await _frames(2)
		assert_true(reward.get_node("%Header").find_child("ReissueButton", true, false).visible, "%s: Regroup offers Re-issue" % label)
		_check(reward, screen, "regroup")
		var ropts: Array[Dictionary] = r.retire_options()
		var ti: int = -1
		for i: int in ropts.size():
			if int(ropts[i]["twin_index"]) >= 0 and (r.resource(ropts[i]["id"]) as CardData).trait_choices().size() > 1:
				ti = i
				break
		if ti >= 0:
			var deck2: int = r.deck.size()
			await _tap(reward.list_tiles[ti])
			assert_eq(reward.train_pick.get("kind", &""), &"twin", "%s: twin TRAIN AS" % label)
			var pre: Control = reward.pick_tiles.filter(func(t: Control) -> bool: return bool(t.get_meta(&"preselected")))[0]
			await _tap(pre)
			await _frames(2)
			assert_eq(r.deck.size(), deck2 - 1, "%s: retired, twin trained" % label)
		# The deck view names each design's copy traits.
		r.pending_offers.clear()
		reward.open_deck()
		await _frames(2)
		var row: Node = reward.get_engine_view().find_child("Row_marksman", true, false)
		assert_not_null(row, "%s: Marksman row" % label)
		assert_true((row.find_child("CopyTraits", true, false) as Label).text.contains("Heavy 1"), "%s: copy traits in the deck view" % label)
		_teardown()
