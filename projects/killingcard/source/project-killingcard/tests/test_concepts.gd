# test_concepts.gd
# Purpose: kc-ui-pass: the "explain once" concept system (ConceptRegistry + the ConceptGuide autoload).
#   - every keyword in the card / loadout data has a concept (a new keyword property, or a card that
#     shows a keyword with no concept, fails here), and every trait and Terrain;
#   - concept texts are short and plain;
#   - the seen set persists (Settings file, mirrored by SaveMirror) and RESET TIPS clears it;
#   - one callout at a time, queued; holds wait; a gone anchor is not marked seen; tips off = none;
#   - a callout NEVER passes a tap, a drag or a key to the game (a real Match: READY under it);
#   - the bubble never covers its target or the avoid rects at phone size.
# Author: UI/UX Agent (kc-ui-pass)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const Callout: GDScript = preload("res://scripts/ui/concepts/concept_callout.gd")
const CardInfo: GDScript = preload("res://scripts/ui/card_info.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const SCRATCH: String = "user://test_concepts_settings.cfg"

var _saved: Dictionary = {}


func _guide() -> Node:
	return tree.root.get_node("ConceptGuide")


func _begin() -> Node:
	var g: Node = _guide()
	_saved = {"auto": g.auto_show, "seen": g.seen_override, "tips": g.tips_override, "host": g.host}
	g.seen_override = {}
	g.tips_override = true
	g.auto_show = false
	g.clear_queue()
	return g


func _end() -> void:
	var g: Node = _guide()
	g.dismiss()
	g.clear_queue()
	g.auto_show = _saved["auto"]
	g.seen_override = _saved["seen"]
	g.tips_override = _saved["tips"]
	g.host = _saved["host"]


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _wait(s: float) -> void:
	await tree.create_timer(s).timeout


# --- 1. coverage ------------------------------------------------------------------------------

func test_every_keyword_in_the_data_has_a_concept() -> void:
	# Every keyword rule the UI can print.
	for kw: StringName in CardInfo.KEYWORD_RULES:
		assert_true(ConceptRegistry.has(ConceptRegistry.keyword_concept(kw)), "keyword %s has a concept" % kw)
	# Every property in the data's keyword / special-rule groups maps to a concept (or is internal).
	for res: Resource in [CardData.new(), LoadoutItem.new()]:
		var group: String = ""
		for p: Dictionary in res.get_property_list():
			if int(p["usage"]) & PROPERTY_USAGE_GROUP:
				group = String(p["name"])
				continue
			if not (int(p["usage"]) & PROPERTY_USAGE_EDITOR):
				continue
			if group.begins_with("Keywords") or group == "Special rules":
				var prop: StringName = StringName(p["name"])
				assert_true(ConceptRegistry.PROPERTY_CONCEPTS.has(prop),
						"%s.%s (group %s) is in ConceptRegistry.PROPERTY_CONCEPTS" % [res.get_class(), prop, group])
				var cid: StringName = ConceptRegistry.PROPERTY_CONCEPTS.get(prop, &"")
				if cid != &"":
					assert_true(ConceptRegistry.has(cid), "%s -> %s is a concept" % [prop, cid])
	# Every card in the data: what it shows, it can explain.
	var cards: Array[CardData] = tree.root.get_node("CardDB").all_cards()
	assert_true(cards.size() > 20, "the card data loaded")
	for card: CardData in cards:
		for k: Dictionary in CardInfo.keywords(card):
			assert_true(ConceptRegistry.has(ConceptRegistry.keyword_concept(k["id"])), "%s: keyword %s has a concept" % [card.id, k["id"]])
		for cid: StringName in ConceptRegistry.for_card(card):
			assert_true(ConceptRegistry.has(cid), "%s teaches %s, which exists" % [card.id, cid])
	for tr: StringName in SynergyRules.TRAITS:
		assert_true(ConceptRegistry.has(StringName("trait_" + String(tr))), "trait %s" % tr)
	for t: StringName in TerrainRules.ALL:
		assert_true(ConceptRegistry.has(StringName("terrain_" + String(t))), "terrain %s" % t)
	# The old "New: X" flags all have a concept (one onboarding system).
	for f: StringName in RevealFlags.EXPLAINED:
		if f == RevealFlags.LINKS:
			continue  # kc-pos-cut: links are retired, never explained
		assert_true(ConceptRegistry.has(f), "reveal flag %s is a concept" % f)


func test_concept_texts_are_short_and_plain() -> void:
	var ids: Array[StringName] = ConceptRegistry.ids()
	assert_true(ids.size() >= 60, "a full list (%d)" % ids.size())
	for id: StringName in ids:
		var c: Dictionary = ConceptRegistry.get_concept(id)
		assert_true(String(c["title"]).length() > 1 and String(c["title"]).length() <= 26, "%s title" % id)
		var t: String = String(c["text"])
		assert_true(t.length() >= 12 and t.length() <= 180, "%s text length %d" % [id, t.length()])
		assert_false("%d" in t, "%s has no format codes" % id)
		assert_true(String(c["group"]) in ["match", "run", "keyword", "trait", "terrain"], "%s group" % id)
		assert_true(String(c.get("trigger", "")) != "", "%s says when it is explained" % id)


# --- 2. the seen set --------------------------------------------------------------------------

func test_seen_set_persists_and_reset_clears_it() -> void:
	var st: Node = tree.root.get_node("Settings")
	var saved_seen: Dictionary = st.seen_flags.duplicate()
	var saved_tips: bool = st.tips_enabled
	var g: Node = _guide()
	var saved_override: Variant = g.seen_override
	g.seen_override = null
	st.seen_flags = {}
	assert_false(g.is_seen(&"supply"), "not seen yet")
	g.mark_seen(&"supply")
	g.mark_seen(&"kw_front")  # an old flag name: stored as the concept
	assert_true(g.is_seen(&"supply") and g.is_seen(&"kw_arrives_front"), "marked")
	st.tips_enabled = false
	assert_eq(st.save_to(SCRATCH), OK, "saved")
	var fresh: Node = (load("res://autoload/settings.gd") as GDScript).new()
	assert_true(fresh.load_from(SCRATCH), "read back")
	assert_true(fresh.is_seen(&"supply") and fresh.is_seen(&"kw_arrives_front"), "the seen set survives a reload")
	assert_false(fresh.tips_enabled, "Tips off survives a reload")
	assert_true(&"seen_flags" in fresh.PERSISTED_KEYS and &"tips_enabled" in fresh.PERSISTED_KEYS, "persisted keys")
	fresh.free()
	# RESET TIPS: every concept again, tips back on.
	st.reset_tips()
	assert_false(g.is_seen(&"supply"), "reset clears the seen set")
	assert_true(st.tips_enabled, "reset turns tips back on")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	st.seen_flags = saved_seen
	st.tips_enabled = saved_tips
	g.seen_override = saved_override


# --- 3. the queue -----------------------------------------------------------------------------

func test_one_at_a_time_queued_held_and_never_twice() -> void:
	var g: Node = _begin()
	var host := Control.new()
	host.size = Vector2(1168, 540)
	tree.root.add_child(host)
	var a := Button.new()
	a.position = Vector2(100, 100)
	a.size = Vector2(120, 64)
	host.add_child(a)
	var b := Button.new()
	b.position = Vector2(700, 300)
	b.size = Vector2(120, 64)
	host.add_child(b)
	await _frames(1)
	assert_true(g.notice(&"supply", a), "queued")
	assert_false(g.notice(&"supply", b), "never queued twice")
	assert_true(g.notice(&"hand", b), "a second one waits")
	assert_false(g.notice(&"no_such_concept", a), "unknown ids are ignored")
	assert_eq(g.queued_ids(), [&"supply", &"hand"] as Array[StringName], "in notice order")
	assert_eq(g.show_next(), &"supply", "the first opens")
	assert_true(g.is_showing(), "showing")
	assert_eq(g.show_next() if not g.is_showing() else &"", &"", "one at a time")
	g.dismiss()
	assert_true(g.is_seen(&"supply"), "dismissed = seen")
	assert_false(g.notice(&"supply", a), "a seen concept is never queued again")
	await _wait(0.4)
	# A hold blocks the automatic show.
	var holder := Node.new()
	tree.root.add_child(holder)
	var held: Array = [true]
	g.add_hold_check(holder, func() -> bool: return held[0])
	g.auto_show = true
	await _wait(0.8)
	assert_false(g.is_showing(), "held: nothing opens")
	held[0] = false
	await _wait(0.8)
	assert_eq(g.current_id(), &"hand", "released: the next opens by itself")
	g.dismiss()
	g.auto_show = false
	holder.queue_free()
	await _wait(0.4)
	# A gone anchor: dropped, not seen.
	g.notice(&"ready", a)
	a.hide()
	assert_eq(g.show_next(), &"", "hidden anchor: nothing opens")
	assert_false(g.is_seen(&"ready"), "and it is not marked seen")
	# Tips off: nothing.
	a.show()
	g.set_tips_enabled(false)
	assert_false(g.notice(&"ready", a), "tips off: nothing is queued")
	g.set_tips_enabled(true)
	host.queue_free()
	_end()


# --- 4. no input ever passes through ----------------------------------------------------------

func test_callout_swallows_taps_keys_and_the_dismissing_tap() -> void:
	var g: Node = _begin()
	var vp := SubViewport.new()
	vp.size = Vector2i(1168, 540)
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var host := Control.new()
	host.size = Vector2(1168, 540)
	vp.add_child(host)
	var presses: Array = [0]
	var big := Button.new()
	big.position = Vector2.ZERO
	big.size = Vector2(1168, 540)
	big.pressed.connect(func() -> void: presses[0] += 1)
	host.add_child(big)
	var anchor := Control.new()
	anchor.position = Vector2(500, 200)
	anchor.size = Vector2(100, 80)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(anchor)
	g.host = vp
	await _frames(2)
	var mid: Vector2 = Vector2(560, 240)
	# Control: without a callout the tap presses the button.
	await _tap(vp, mid)
	assert_eq(presses[0], 1, "the button works")
	g.notice(&"supply", anchor)
	g.show_next()
	await _frames(2)
	# A tap right away (before ARM_S): eaten, the callout stays.
	await _tap(vp, mid)
	assert_eq(presses[0], 1, "an early tap never reaches the game")
	assert_true(g.is_showing(), "and does not dismiss (no double-tap accidents)")
	# Keys: eaten.
	var r := InputEventKey.new()
	r.keycode = KEY_R
	r.physical_keycode = KEY_R
	r.pressed = true
	vp.push_input(r)
	await _frames(1)
	assert_true(g.is_showing(), "a game key does nothing")
	await _wait(Callout.ARM_S + 0.1)
	# A drag: eaten (never starts anything under it).
	_mouse(vp, mid, true)
	await _frames(1)
	_motion(vp, mid + Vector2(80, 40))
	await _frames(1)
	_mouse(vp, mid + Vector2(80, 40), false)
	await _frames(1)
	assert_eq(presses[0], 1, "the dismissing tap never reaches the game")
	assert_false(g.is_showing(), "the tap dismissed it")
	assert_true(g.is_seen(&"supply"), "seen")
	# The rest of that tap (a touch's emulated mouse release) is still eaten.
	_mouse(vp, mid, false)
	await _frames(1)
	assert_eq(presses[0], 1, "the trailing release is eaten too")
	await _wait(Callout.LINGER_S + 0.15)
	await _tap(vp, mid)
	assert_eq(presses[0], 2, "afterwards the game gets taps again")
	vp.queue_free()
	_end()


func test_callout_over_a_real_match_never_presses_ready() -> void:
	var g: Node = _begin()
	var saved_size: Vector2i = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	var vp := SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(Layout.PHONE))
	vp.disable_3d = true
	vp.handle_input_locally = true
	tree.root.add_child(vp)
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	await _frames(2)
	g.host = vp
	g.clear_queue()
	c.notice_concepts()
	var q: Array[StringName] = g.queued_ids()
	assert_true(q.has(&"goal") and q.has(&"hand") and q.has(&"supply"), "the first Deploy notices the basics: %s" % [q])
	assert_true(q.find(&"goal") < q.find(&"supply"), "the goal comes first")
	var ready_btn: Button = m.get_ready_button()
	var shown: StringName = g.show_next()
	await _frames(2)
	assert_true(shown != &"", "a callout opened")
	var callout: Control = g.get_callout()
	var bubble: Rect2 = callout.bubble_rect()
	assert_false(bubble.intersects(ready_btn.get_global_rect()), "the bubble does not cover READY (%s vs %s)" % [bubble, ready_btn.get_global_rect()])
	assert_false(bubble.intersects(callout.target.grow(2.0)), "nor the thing it explains")
	await _wait(Callout.ARM_S + 0.1)
	await _tap(vp, ready_btn.get_global_rect().get_center())
	assert_false(c.state.sides[0].ready, "the tap on READY under a callout did not end the turn")
	assert_false(c.is_busy(), "no round is resolving")
	assert_false(g.is_showing() and g.current_id() == shown, "it dismissed the callout instead")
	vp.queue_free()
	tree.root.size = saved_size
	_end()


func test_mulligan_tip_comes_first_and_the_rest_waits_under_the_panel() -> void:
	var g: Node = _begin()
	var vp := SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(Layout.PHONE))
	vp.disable_3d = true
	tree.root.add_child(vp)
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	if not c.is_mulligan_open():
		c.open_mulligan()
	await _frames(1)
	assert_eq(g.peek_id(), &"mulligan", "the mulligan tip is first: %s" % [g.queued_ids()])
	assert_false(g.is_held(), "and may open over the panel")
	g.show_next()
	g.dismiss()
	await _frames(1)
	assert_true(g.is_held(), "the other tips wait while the panel covers their anchors")
	c.keep_hand()
	await _frames(2)
	assert_false(g.is_held(), "after KEEP HAND they may open")
	vp.queue_free()
	_end()


func test_bubble_never_covers_target_or_avoid_at_phone_size() -> void:
	var view: Vector2 = Vector2(1168, 540)
	var bs: Vector2 = Vector2(420, 170)
	var targets: Array[Rect2] = [Rect2(20, 20, 80, 80), Rect2(900, 400, 200, 120), Rect2(400, 200, 300, 120),
			Rect2(860, 60, 280, 380), Rect2(10, 300, 560, 220)]
	var avoid: Array[Rect2] = [Rect2(980, 470, 180, 64)]
	for t: Rect2 in targets:
		var p: Vector2 = Callout.best_position(bs, view, t, avoid)
		var r: Rect2 = Rect2(p, bs)
		assert_true(Rect2(Vector2.ZERO, view).encloses(r), "on screen for %s" % t)
		assert_false(r.intersects(t), "does not cover target %s (bubble %s)" % [t, r])
		assert_false(r.intersects(avoid[0]), "does not cover READY for %s (bubble %s)" % [t, r])


# --- helpers ----------------------------------------------------------------------------------

func _mouse(vp: SubViewport, pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	vp.push_input(e)


func _motion(vp: SubViewport, pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(e)


func _tap(vp: SubViewport, pos: Vector2) -> void:
	_mouse(vp, pos, true)
	await _frames(1)
	_mouse(vp, pos, false)
	await _frames(3)


# --- 5. a gentle first fight (deck order only) ------------------------------------------------

func test_gentle_opening_only_reorders_the_deck() -> void:
	var db: Node = tree.root.get_node("CardDB")
	var ids: Array[StringName] = [&"si_sergeant", &"si_armored", &"si_trooper", &"si_sergeant", &"si_armored",
			&"si_trooper", &"si_grunt", &"si_sergeant", &"si_armored", &"si_trooper"]
	for seed_value: int in [1, 7, 42, 999, 31337]:
		var s := SideSetup.new()
		for i: int in ids.size():
			s.deck.append(db.get_card(ids[i]))
			s.deck_arts.append(StringName("art_%d" % i))
			s.deck_traits.append(&"")
		var before: Dictionary = {}
		for i: int in s.deck.size():
			before[s.deck_arts[i]] = s.deck[i]
		RunProgress.gentle_opening(s, seed_value, 5)
		assert_eq(s.deck.size(), ids.size(), "same size")
		assert_true(s.keep_deck_order, "the order is kept")
		for i: int in s.deck.size():
			assert_eq(before[s.deck_arts[i]], s.deck[i], "arts move with their cards")
		var cheapest: int = 99
		for c: CardData in s.deck:
			if c.is_unit():
				cheapest = mini(cheapest, c.cost)
		var hand_min: int = 99
		for k: int in 5:
			if s.deck[k].is_unit():
				hand_min = mini(hand_min, s.deck[k].cost)
		assert_eq(hand_min, cheapest, "seed %d: the opening hand holds the cheapest unit" % seed_value)
