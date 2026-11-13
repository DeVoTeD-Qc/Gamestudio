# test_r2_fixes.gd
# Purpose: kc-r2-fixes (playtest round 2, v32):
#   1. no build, licence or pitch words ("PRIVATE PITCH", "REFERENCE ART", "MW3 CALLING CARD",
#      "BANNER:", "dev preview") on any player-facing line: the inspector's art caption, and every
#      string literal in the UI / FX scripts;
#   2. FAST plays a firefight as its column results only (about 3 s), a real skip ends even that at
#      once, and on the match screen a tap anywhere (the killfeed too) skips the round;
#   4. a column with no losses says why (Cover and where it comes from);
#   5. the hand keeps its order and card size after a play, and an undone card goes back to its place.
# Author: UI/UX Agent (kc-r2-fixes)
extends "res://tests/test_case.gd"

const F = preload("res://tests/rules_fixtures.gd")
const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const DirectorScene: PackedScene = preload("res://scenes/fx/FeedbackDirector.tscn")
const ScoreRace: GDScript = preload("res://scripts/ui/score_race.gd")
const ControllerScript: GDScript = preload("res://scripts/ui/match_controller.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const P: int = 0
const E: int = 1
const FORBIDDEN: PackedStringArray = ["private pitch", "reference art", "mw3 calling card", "calling card (reference",
		"banner: ", "dev preview", "not licensed"]

var _saved_root_size: Vector2i = Vector2i.ZERO


class ZoneLocator:
	extends RefCounted

	func unit_rect(_uid: int) -> Rect2:
		return Rect2(100, 100, 80, 80)

	func zone_rect(zone: StringName) -> Rect2:
		var z: int = MapData.ZONE_IDS.find(zone)
		return Rect2(z * 400, 100, 400, 500)

	func anchor_rect(_name: StringName) -> Rect2:
		return Rect2(20, 10, 300, 60)


# =============================================================================
# 1. No pitch / licence words in front of the player
# =============================================================================

func test_licensed_art_caption_has_no_pitch_words() -> void:
	var art: BannerArt = BannerArt.new()
	art.id = &"kc_mw3_pin_pulled"
	art.card_id = &"rifleman"
	art.title = "Pin Pulled"
	art.licensed = true
	art.licence = "Activision. NOT LICENSED: private pitch prototype only, never ship or publish."
	art.source_note = "Licensed reference art (private pitch build): pin_pulled.png"
	var c: Node = ControllerScript.new()
	var line: String = c._art_line(art)
	c.free()
	assert_true(line.begins_with("Art: Pin Pulled"), "a plain art caption (%s)" % line)
	for word: String in FORBIDDEN:
		assert_false(word in line.to_lower(), "no '%s' in the inspector caption (%s)" % [word, line])
	assert_false("mw3" in line.to_lower(), "no MW3 in the caption")


func test_no_pitch_words_in_player_facing_strings() -> void:
	var files: PackedStringArray = []
	for dir: String in ["res://scripts/ui", "res://scripts/fx", "res://scripts/run", "res://scripts/data"]:
		_collect(dir, files)
	assert_true(files.size() > 40, "scanned the UI scripts (%d)" % files.size())
	var literal: RegEx = RegEx.create_from_string("\"([^\"\\\\]|\\\\.)*\"")
	var bad: PackedStringArray = []
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		var n: int = 0
		for line: String in text.split("\n"):
			n += 1
			var code: String = line.strip_edges()
			if code.begins_with("#") or code.begins_with("##"):
				continue
			# The licence field itself is data for the build tools, never shown (checked below).
			if code.begins_with("art.licence =") or code.begins_with("art.source_note ="):
				continue
			for m: RegExMatch in literal.search_all(line):
				var s: String = m.get_string().to_lower()
				for word: String in FORBIDDEN:
					if word in s:
						bad.append("%s:%d %s" % [path.get_file(), n, m.get_string()])
	assert_eq(bad, PackedStringArray(), "no pitch / licence words in a string the player can see")
	# The licence and source notes never reach a label: only the art database touches them.
	var readers: PackedStringArray = []
	for path: String in files:
		if path.ends_with("banner_art_db.gd") or path.ends_with("banner_art.gd"):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		if ".licence" in text or ".source_note" in text:
			readers.append(path.get_file())
	assert_eq(readers, PackedStringArray(), "nothing shows an art's licence or source note")


func _collect(dir: String, out: PackedStringArray) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		_collect(dir.path_join(sub), out)


# =============================================================================
# 2. FAST and skip
# =============================================================================

func _three_column_fight() -> Array:
	var m: MatchState = F.new_match(null, null, F.map())
	for z: int in 3:
		F.place(m, P, F.unit("ours%d" % z, 3, 3), z)
		F.place(m, E, F.unit("theirs%d" % z, 1, 2), z)
	var start: int = m.events.size()
	m.firefight()
	return [m, m.events_since(start)]


func _director() -> Array:
	var root: Control = Control.new()
	root.size = Vector2(1280, 720)
	tree.root.add_child(root)
	var d: Control = DirectorScene.instantiate()
	d.use_settings = false
	d.fast = false
	d.reduced_motion = false
	root.add_child(d)
	d.locator = ZoneLocator.new()
	return [root, d]


func test_fast_plays_column_results_in_about_three_seconds() -> void:
	var fight: Array = _three_column_fight()
	var events: Array = fight[1]
	var made: Array = _director()
	var d: Control = made[1]
	var caps: Array[String] = []
	d.caption_changed.connect(func(lines: Array) -> void:
		for l: Variant in lines:
			caps.append(String(l)))
	var summaries: Array[String] = []
	d.fx_started.connect(func(kind: StringName, node: Object, _dur: float) -> void:
		if node != null and "label" in node and node.label != null:
			summaries.append("%s:%s" % [kind, String(node.label.text)]))
	d.summary_only = true
	var t0: int = Time.get_ticks_msec()
	await d.play(events)
	var took: int = Time.get_ticks_msec() - t0
	assert_true(took >= 1800 and took <= 3600, "FAST: a 3-column firefight in about 3 s (%d ms)" % took)
	for letter: String in ["A", "B", "C"]:
		assert_true(caps.any(func(c: String) -> bool: return c.begins_with("COLUMN %s:" % letter)), "column %s result shown (%s)" % [letter, caps])
	assert_eq(summaries.filter(func(t: String) -> bool: return t.begins_with("summary:")).size(), 3, "one result popup per column (%s)" % [summaries])
	assert_false(summaries.any(func(t: String) -> bool: return not t.begins_with("summary:")), "nothing else plays (%s)" % [summaries])
	assert_false(d.logged_kinds().has(&"tracer"), "no tracers in FAST")
	# A real skip during FAST ends the column results too.
	var fight2: Array = _three_column_fight()
	var once: Array = [false, false]
	d.event_landed.connect(func(ev: Dictionary) -> void:
		if ev["type"] == RulesEvent.FIREFIGHT_COLUMN_ENDED and not once[0]:
			once[0] = true
			d.skip.call_deferred())
	t0 = Time.get_ticks_msec()
	await d.play(fight2[1])
	took = Time.get_ticks_msec() - t0
	assert_true(took < 1200, "a tap skips FAST's results too (%d ms)" % took)
	# FAST switched on in the middle of a full playback: the rest is results only.
	d.summary_only = false
	var fight3: Array = _three_column_fight()
	d.event_landed.connect(func(ev: Dictionary) -> void:
		if ev["type"] == RulesEvent.FIREFIGHT_BEAT and not once[1]:
			once[1] = true
			d.set_summary_only.call_deferred(true))
	t0 = Time.get_ticks_msec()
	await d.play(fight3[1])
	took = Time.get_ticks_msec() - t0
	assert_true(took <= 3800, "FAST mid-fight shortens the rest (%d ms)" % took)
	(made[0] as Node).queue_free()
	await tree.process_frame


func test_fast_setting_is_kept_and_a_tap_anywhere_skips_the_round() -> void:
	assert_true(&"fast_fights" in Settings.PERSISTED_KEYS, "FAST is kept between sessions")
	var was: bool = Settings.fast_fights
	Settings.fast_fights = false
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var fast_b: Button = m.get_fast_button()
	assert_not_null(fast_b, "a FAST button beside SPEED")
	assert_false(fast_b.button_pressed, "off by default")
	fast_b.button_pressed = true
	assert_true(Settings.fast_fights, "the toggle records the choice")
	assert_true(c.fast_fights_on(), "the match plays FAST")
	fast_b.button_pressed = false
	# A tap on the killfeed while the round plays skips it (it used to open the Killfeed explainer).
	_stage(c)
	await _frames(2)
	c.press_ready()
	await _frames(3)
	assert_true(c.is_busy(), "the round is playing")
	var feed: Control = m.get_key_controls().get("killfeed", null)
	var p: Vector2 = feed.get_global_rect().get_center() if feed != null and feed.is_visible_in_tree() \
			else m.get_board().get_global_rect().get_center()
	var t0: int = Time.get_ticks_msec()
	_mouse(vp, p, true)
	_mouse(vp, p, false)
	if c.is_busy():
		await c.round_presented
	var took: int = Time.get_ticks_msec() - t0
	assert_true(took < 2500, "the tap skipped to the result (%d ms)" % took)
	assert_true(c.last_playback_skipped, "recorded as skipped")
	assert_false(m.get_inspector().is_open(), "the tap opened nothing")
	_despawn(vp)
	await tree.process_frame
	Settings.fast_fights = was


# =============================================================================
# 4. "No losses" says why
# =============================================================================

func test_no_losses_column_names_the_cover() -> void:
	var m: MatchState = F.new_match(null, null, F.map())
	F.place(m, P, F.unit("ours", 1, 3), F.LEFT)
	F.place(m, E, F.unit("theirs", 1, 3, F.W.NONE, {"cover": 1}), F.LEFT)
	var start: int = m.events.size()
	m.firefight()
	var events: Array = m.events_since(start)
	var shots: Array = events.filter(func(e: Dictionary) -> bool:
		return e["type"] == RulesEvent.SHOT_FIRED and int(e.get("cover", 0)) > 0)
	assert_false(shots.is_empty(), "the shot at the covered unit carries its Cover")
	assert_true("its own Cover" in PackedStringArray(shots[0].get("cover_from", [])), "and where it comes from")
	var fights: Dictionary = ScoreRace.column_fights(events)
	var left: Dictionary = fights.get(MapData.ZONE_IDS[0], {})
	assert_false(left.is_empty(), "column A fought")
	var why: String = ScoreRace.no_losses_reason(left)
	assert_true(why.begins_with("No losses:"), "a reason (%s)" % why)
	assert_true("Cover" in why, "it names Cover (%s)" % why)
	assert_eq(ScoreRace.no_losses_reason({"shots": 2, "zero": 2, "covered": 2, "cover_from": {"Bulwark": true}}),
			"No losses: Cover from Bulwark stopped every hit.", "a Field's Cover is named")
	assert_eq(ScoreRace.no_losses_reason({"kills": 1, "shots": 2}), "", "no reason when someone fell")


# =============================================================================
# 5. Hand stability
# =============================================================================

func test_hand_keeps_order_and_size_after_a_play_and_an_undo() -> void:
	var s: Array = await _spawn(Layout.DESKTOP)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var st: MatchState = c.state
	var me: RulesSide = st.sides[c.me_side]
	me.supply = 10
	c.refresh()
	await _frames(3)
	var hand: Control = m.get_hand()
	var before: Array[int] = _uids(hand)
	assert_true(before.size() >= 3, "a hand to play from (%d)" % before.size())
	var size_before: Vector2 = (hand.get_cards()[0] as Control).size
	var pos_before: Dictionary = {}
	for chip: Node in hand.get_cards():
		pos_before[int(chip.get_meta(&"uid", -1))] = (chip as Control).position
	# Play the first unit in the hand.
	var played: int = -1
	for uid: int in before:
		var rc: RulesCard = me.find_in_hand(uid)
		if rc != null and rc.card.is_unit():
			played = uid
			break
	assert_true(played >= 0, "a unit in hand")
	c.select_card(played)
	var res: Dictionary = c.play_at(0)
	assert_true(bool(res.get("ok", false)), "played (%s)" % [res])
	await _frames(3)
	var after: Array[int] = _uids(hand)
	var expect: Array[int] = before.duplicate()
	expect.erase(played)
	assert_eq(after, expect, "the others keep their order")
	assert_eq((hand.get_cards()[0] as Control).size, size_before, "the cards keep their size within the Deploy")
	var i_played: int = before.find(played)
	for i: int in after.size():
		var chip: Control = hand.get_card(after[i])
		if before.find(after[i]) < i_played:
			assert_eq(chip.position, pos_before[after[i]], "a card before the played one does not move")
	# Undo: the card goes back to its old place (the rules put it at the end).
	c.undo()
	await _frames(3)
	assert_eq(_uids(hand), before, "an undone card goes back to its place")
	# Selecting an unaffordable card does not leave it picked up (kc-r2-fixes small fix).
	me.supply = 0
	c.refresh()
	await _frames(2)
	c.select_card(before[0])
	assert_true(c.selection.is_empty(), "a card you can't pay for is not left selected")
	_despawn(vp)
	await tree.process_frame


func _uids(hand: Control) -> Array[int]:
	var out: Array[int] = []
	for chip: Node in hand.get_cards():
		out.append(int(chip.get_meta(&"uid", -1)))
	return out


# =============================================================================
# Helpers
# =============================================================================

func _stage(c: Node) -> void:
	var st: MatchState = c.state
	for side: RulesSide in st.sides:
		for z: int in 3:
			side.line(z).clear()
		side.plays.clear()
	st.sides[E].ready = false
	for z: int in 3:
		st.put_in_line(st.create_unit(P, CardDB.get_card(&"rifleman")), z)
		st.put_in_line(st.create_unit(E, CardDB.get_card(&"rifleman")), z)
	c.refresh()


func _spawn(screen: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	assert_not_null(c.state, "%s live match started" % screen["name"])
	if c.is_mulligan_open():
		c.keep_hand()
		await _frames(2)
	return [vp, m, c]


func _despawn(vp: SubViewport) -> void:
	vp.queue_free()
	tree.root.size = _saved_root_size
	Engine.time_scale = 1.0


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _mouse(vp: SubViewport, pos: Vector2, pressed: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	vp.push_input(e)
