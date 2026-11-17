# ui-pass-3 "explain once": the concept registry (data/concepts.json) covers every rule, machine,
# mod, boss trait and survivor skill in plain short text; the Guide lists every concept; the callout
# shows one concept at a time, anchored beside (never on) its thing, and is marked seen when
# dismissed; and a callout never triggers a game action (the taps that dismiss it, a release left
# over from an earlier press, Got it, Esc: the run is untouched). Inspect shows the concept text.
extends "res://tests/dd_test_case.gd"

const Codex: GDScript = preload("res://scripts/ui/dd_codex.gd")
const Callout: GDScript = preload("res://scripts/ui/dd_callout.gd")

var _paths: Array[String] = []


func _main() -> Control:
	var game: Node = tree.root.get_node_or_null("Game")
	var pp: String = "user://dd_test_concepts_%d.json" % Time.get_ticks_usec()
	_paths.append(pp)
	_paths.append(pp + ".run")
	game.set("profile", DDProfile.new(bal(), pp))
	game.set("run_save", DDRunSave.new(pp + ".run"))
	var m: Control = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	tree.root.add_child(m)
	return m


func _done(m: Control) -> void:
	m.queue_free()
	await tree.process_frame
	for p: String in _paths:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_paths.clear()


func _settle() -> void:
	for k: int in 5:
		await tree.process_frame


func _game() -> Node:
	return tree.root.get_node("Game")


func _click(m: Control, at: Vector2, press: bool = true, release: bool = true) -> void:
	# past the callout's guard (a tap right as it opens is eaten without dismissing it)
	await tree.create_timer(0.65).timeout
	var xf: Transform2D = m.get_viewport().get_final_transform()
	if press:
		var mb: InputEventMouseButton = InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = true
		mb.position = xf * at
		mb.global_position = mb.position
		Input.parse_input_event(mb)
		await tree.process_frame
	if release:
		var up: InputEventMouseButton = InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = xf * at
		up.global_position = up.position
		Input.parse_input_event(up)
	await _settle()


func _state(run: DDRun) -> String:
	return JSON.stringify([run.hp, run.cover, run.points, run.resolved, run.street.size(), run.active, run.pile.size(),
		run.slots.map(func(g: Variant) -> Array: return (g as DDGun).stack.duplicate() if g != null else [])])


# ---------------------------------------------------------------- the registry
func test_registry_is_complete_short_and_plain() -> void:
	var ids: Array[String] = DDConcepts.ids()
	check(ids.size() >= 50, "about every idea a newcomer meets (%d)" % ids.size())
	var seen: Dictionary = {}
	for id: String in ids:
		check(not seen.has(id), "unique id " + id)
		seen[id] = true
		var t: String = DDConcepts.title(id, bal())
		var x: String = DDConcepts.text(id, bal())
		check(t != "" and x != "", id + " has a title and a text")
		check(not t.contains("{") and not x.contains("{"), id + " placeholders filled: " + x)
		check(x.length() <= 170, "%s is short (%d chars)" % [id, x.length()])
		var sentences: int = x.count(". ") + 1
		check(sentences <= 2, "%s is 1-2 sentences (%d)" % [id, sentences])
		check(DDConcepts.groups().has(DDConcepts.group(id)), id + " is in a Guide group")
		check(str(DDConcepts.raw(id).get("trigger", "")) != "", id + " says when it first shows")
	# every rule, machine, mod, boss trait and survivor skill of the game has its concept
	for wid: Variant in bal().weapons().keys():
		if bal().is_gun(str(wid)):
			check(DDConcepts.has(DDConcepts.rule_id(bal().weapon_rule(str(wid)))), "the %s rule has a concept" % bal().weapon_rule(str(wid)))
	for d: Variant in bal().districts():
		check(DDConcepts.has("boss_" + str(((d as Dictionary).get("boss", {}) as Dictionary).get("trait", ""))), "boss trait concept")
		for r: Variant in (d as Dictionary).get("rooms", []):
			var mk: String = str(((r as Dictionary).get("machine", {}) as Dictionary).get("kind", ""))
			check(DDConcepts.has({"wall": "wall_rack", "bench": "bench", "patch": "patch_press"}.get(mk, "?")), "machine concept " + mk)
	for mid: Variant in DDText.MOD_NAMES.keys():
		check(DDConcepts.has("mod_" + str(mid)), "Gun Mod concept " + str(mid))
	for sid: String in bal().survivor_ids():
		check(DDConcepts.has("passive_" + str(bal().survivor(sid).get("passive", ""))), "skill concept for " + sid)
	eq(DDConcepts.fill("{pts:finish_bonus} / {n:run_damage}", bal()), "%d / %d" % [bal().shown(bal().num("finish_bonus")), bal().num("run_damage")], "placeholders read the balance")


func test_the_guide_lists_every_concept() -> void:
	var all: Dictionary = {}
	for sec: Variant in Codex.call("sections", bal()):
		for row: Variant in (sec as Array)[1]:
			if (row as Dictionary).has("concept"):
				all[str(row["concept"])] = str(row["line"])
	for id: String in DDConcepts.ids():
		check(all.has(id), "the Guide lists " + id)
		check(str(all.get(id, "")) == DDConcepts.text(id, bal()), id + ": the Guide has the full text")


func test_bubble_never_covers_its_anchor() -> void:
	for vp: Vector2 in [Vector2(560, 1212), Vector2(1212, 560), Vector2(996, 560)]:
		for a: Rect2 in [Rect2(10, 10, 120, 160), Rect2(vp.x - 200, vp.y - 120, 180, 100), Rect2(vp.x * 0.4, vp.y * 0.4, 100, 100), Rect2(0, vp.y - 300, 300, 290)]:
			var sz: Vector2 = Vector2(minf(vp.x - 24.0, 460.0), 150)
			var p: Vector2 = Callout.call("place_rect", a, sz, vp)
			var r: Rect2 = Rect2(p, sz)
			check(not r.intersects(a), "%s: the bubble (%s) stays off the anchor (%s)" % [str(vp), str(r), str(a)])
			check(r.position.x >= 0 and r.position.y >= 0 and r.end.x <= vp.x and r.end.y <= vp.y, "%s: the bubble is on screen" % str(vp))


# ---------------------------------------------------------------- the queue on screen
func test_one_at_a_time_marked_seen_never_twice() -> void:
	tree.root.size = Vector2i(844, 390)
	var m: Control = _main()
	await _settle()
	var prof: DDProfile = _game().get("profile")
	eq(str(m.call("screen_name")), "TITLE", "title")
	eq(str(m.call("show_due_concept")), "inspect", "the title explains hold-to-read, on a survivor card")
	var co: Control = m.get("_callout")
	check(co.call("is_open"), "the callout is open")
	eq(str(m.call("show_due_concept")), "inspect", "one at a time: asking again keeps the same one")
	m.call("dismiss_hint")
	await _settle()
	check(prof.concept_seen("inspect"), "dismissed = seen (saved in the profile)")
	eq(str(m.call("show_due_concept")), "", "nothing else to explain on the title")
	m.call("_start_run")
	await _settle()
	eq(str(m.call("show_due_concept")), "district", "the map explains districts")
	m.call("dismiss_hint")
	await _settle()
	eq(str(m.call("show_due_concept")), "", "1 per action: the survivor's skill waits for the player's next action")
	m.call("player_acted")
	check(str(m.call("show_due_concept")).begins_with("passive_"), "then the survivor's skill")
	m.call("dismiss_hint")
	# back to the title: hold-to-read is not explained again
	m.set("screen", 0)
	m.call("_render")
	await _settle()
	eq(str(m.call("show_due_concept")), "", "a seen concept never comes back")
	prof.reset_concepts()
	eq(str(m.call("show_due_concept")), "inspect", "Reset tips: it explains again")
	m.call("dismiss_hint")
	await _done(m)


func test_a_callout_never_triggers_a_game_action() -> void:
	for sz: Vector2i in [Vector2i(390, 844), Vector2i(844, 390)]:
		tree.root.size = sz
		var m: Control = _main()
		await _settle()
		m.call("apply_debug", {"screen": "street", "seed": "11", "hints": "1"})
		m.call("_render")
		await _settle()
		m.call("dismiss_banner")
		var run: DDRun = _game().get("run")
		var before: String = _state(run)
		var id: String = m.call("show_due_concept")
		check(id != "", "%s: a concept is explained on the street (%s)" % [str(sz), id])
		await _settle()
		var co: Control = m.get("_callout")
		# a tap right on a zombie and one on RUN while the callout is open: eaten, the run is untouched
		var z: DDCardView = null
		for v: Node in m.find_children("*", "DDCardView", true, false):
			if (v as DDCardView).index >= 0 and (v as DDCardView).index < 100 and (v as DDCardView).kind == DDCard.ZOMBIE:
				z = v
				break
		check(z != null, "a zombie on the street")
		await _click(m, z.get_global_rect().get_center())
		eq(_state(run), before, "%s: the tap on a zombie only closed the callout" % str(sz))
		check(not co.call("is_open"), "%s: (closed)" % str(sz))
		check(not co.call("is_open"), "%s: and it closed it" % str(sz))
		check(_game().get("profile").concept_seen(id), "%s: and marked it seen" % str(sz))
		# the next callout (after the player's next action: 1 per action): a release left over from
		# an earlier press does nothing at all
		eq(str(m.call("show_due_concept")), "", "%s: 1 per action: nothing more until the player acts" % str(sz))
		m.call("player_acted")
		var id2: String = m.call("show_due_concept")
		check(id2 != "" and id2 != id, "%s: the next concept (%s)" % [str(sz), id2])
		await _settle()
		var rb: Button = m.find_child("Run", true, false)
		check(rb != null, "RUN on screen")
		await _click(m, rb.get_global_rect().get_center(), false, true)
		check(co.call("is_open"), "%s: a stray release doesn't dismiss it" % str(sz))
		await _click(m, rb.get_global_rect().get_center())
		eq(_state(run), before, "%s: a tap on RUN under the callout didn't run" % str(sz))
		check(not co.call("is_open"), "%s: it dismissed the callout" % str(sz))
		# Got it (the button in the bubble) and Esc: the same, nothing happens to the run
		m.call("player_acted")
		var id3: String = m.call("show_due_concept")
		if id3 != "":
			await _settle()
			var ok: Button = co.find_child("HintOk", true, false)
			check(ok != null and ok.size.y >= 63.5, "%s: Got it is a 44 CSS px target" % str(sz))
			await _click(m, ok.get_global_rect().get_center())
			check(not co.call("is_open"), "%s: Got it closes" % str(sz))
		eq(_state(run), before, "%s: the run is exactly as before the callouts" % str(sz))
		# while a finger is down, no callout opens (the release can't land on a button)
		_game().get("profile").reset_concepts()
		m.call("player_acted")
		var xf: Transform2D = m.get_viewport().get_final_transform()
		var mb: InputEventMouseButton = InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = true
		mb.position = xf * Vector2(4, 4)
		mb.global_position = mb.position
		Input.parse_input_event(mb)
		await tree.process_frame
		eq(str(m.call("show_due_concept")), "", "%s: no callout opens under a held finger" % str(sz))
		await _click(m, Vector2(4, 4), false, true)
		await _done(m)


func test_a_tap_as_it_opens_is_eaten_not_a_dismiss() -> void:
	tree.root.size = Vector2i(844, 390)
	var m: Control = _main()
	await _settle()
	eq(str(m.call("show_due_concept")), "inspect", "title concept")
	var co: Control = m.get("_callout")
	var xf: Transform2D = m.get_viewport().get_final_transform()
	for pressed: bool in [true, false]:
		var mb: InputEventMouseButton = InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = xf * Vector2(6, 6)
		mb.global_position = mb.position
		Input.parse_input_event(mb)
		await tree.process_frame
	check(co.call("is_open"), "a tap in the first moment (meant for what was there before) leaves it open")
	check(not _game().get("profile").concept_seen("inspect"), "and not marked seen")
	await _click(m, Vector2(6, 6))
	check(not co.call("is_open") and _game().get("profile").concept_seen("inspect"), "a later tap dismisses it")
	await _done(m)


# ---------------------------------------------------------------- follow-up (the head's answers)
## The bug: a tap aimed at the WAVE banner that lands just after the banner closes dismissed the
## first callout ("The street") unread. Now a callout opens only CONCEPT_GRACE_MS after a banner
## closes and after the last pointer release, and a tap in its first GUARD_MS doesn't dismiss it.
func test_a_tap_aimed_at_the_banner_never_dismisses_the_first_callout() -> void:
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	m.call("apply_debug", {"screen": "street", "seed": "11", "hints": "1", "overlay": "banner"})
	m.call("_render")
	await _settle()
	await tree.create_timer(0.1).timeout
	await _settle()
	check(bool(m.call("banner_open")), "the WAVE banner is up")
	var prof: DDProfile = _game().get("profile")
	var run: DDRun = _game().get("run")
	var before: String = _state(run)
	var co: Control = m.get("_callout")
	# the banner ends on its own just before the player's tap
	m.call("dismiss_banner")
	m.call("_on_concept_timer")
	check(not co.call("is_open"), "no callout right after the banner closes")
	check(int(m.call("concept_grace_left")) > 300, "it waits out the grace (%d ms left)" % int(m.call("concept_grace_left")))
	# the tap meant for the banner lands on an empty corner: its release starts the grace again
	var xf: Transform2D = m.get_viewport().get_final_transform()
	await tree.create_timer(0.4).timeout
	for pressed: bool in [true, false]:
		var mb: InputEventMouseButton = InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = xf * Vector2(6, 6)
		mb.global_position = mb.position
		Input.parse_input_event(mb)
		await tree.process_frame
	m.call("_on_concept_timer")
	check(not co.call("is_open"), "still none: a finger just lifted")
	check(int(m.call("concept_grace_left")) > 450, "the release restarted the grace")
	eq(_state(run), before, "the stray tap changed nothing")
	# the concept timer itself waits the grace out, then explains the street
	await tree.create_timer(0.75).timeout
	await _settle()
	eq(str(m.get("hint_id")), "street", "after the grace, the first callout is the street")
	check(co.call("is_open"), "(open)")
	# a second tap aimed at the banner, right as the callout opens: eaten, not a dismiss
	for pressed2: bool in [true, false]:
		var mb2: InputEventMouseButton = InputEventMouseButton.new()
		mb2.button_index = MOUSE_BUTTON_LEFT
		mb2.pressed = pressed2
		mb2.position = xf * Vector2(6, 6)
		mb2.global_position = mb2.position
		Input.parse_input_event(mb2)
		await tree.process_frame
	check(co.call("is_open") and not prof.concept_seen("street"), "a tap in the grace window doesn't dismiss it or mark it seen")
	# Enter in the grace window doesn't either
	var key: InputEventAction = InputEventAction.new()
	key.action = "ui_accept"
	key.pressed = true
	Input.parse_input_event(key)
	await tree.process_frame
	check(co.call("is_open") and not prof.concept_seen("street"), "nor a key")
	await _click(m, Vector2(6, 6))
	check(not co.call("is_open") and prof.concept_seen("street"), "a tap once it has been read dismisses it")
	eq(_state(run), before, "the run is untouched")
	await _done(m)


## Head: "1 per action": one callout, then the rest wait for the player's next game action.
func test_one_callout_per_action() -> void:
	tree.root.size = Vector2i(844, 390)
	var m: Control = _main()
	await _settle()
	m.call("apply_debug", {"screen": "street", "seed": "11", "hints": "1"})
	m.call("_render")
	await _settle()
	m.call("dismiss_banner")
	eq(str(m.call("show_due_concept")), "street", "one concept")
	m.call("dismiss_hint")
	await _settle()
	eq(str(m.call("show_due_concept")), "", "then nothing until the player acts")
	m.call("_on_concept_timer")
	await _settle()
	check(not (m.get("_callout") as Control).call("is_open"), "(the timer doesn't open one either)")
	# the player's action: picks melee
	m.call("tap_weapon", DDRun.MELEE)
	await _settle()
	var id2: String = m.call("show_due_concept")
	check(id2 != "" and id2 != "street", "after the action, the next one (%s)" % id2)
	m.call("dismiss_hint")
	await _settle()
	eq(str(m.call("show_due_concept")), "", "and again only one")
	await _done(m)


## Head: "hide it until explained": the gun tile's challenge line shows once the Challenges concept
## has been explained (it fades in as that callout opens), and always with Tips off.
func test_challenge_line_hidden_until_explained() -> void:
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	var prof: DDProfile = _game().get("profile")
	m.call("apply_debug", {"screen": "street", "seed": "6", "gun1": "rifle", "stack1": "8,6", "hints": "1"})
	m.call("_render")
	await _settle()
	m.call("dismiss_banner")
	var gv: DDGunView = (m.get("_gun_views") as Array)[0]
	check(gv != null and gv.chal_line != null, "the Rifle tile has a challenge line")
	check(gv.chal_line.modulate.a < 0.01 and gv.chal_line.mouse_filter == Control.MOUSE_FILTER_IGNORE, "hidden before the Challenges concept")
	var r0: Rect2 = gv.chal_line.get_global_rect()
	var ids: Array = (m.call("concept_candidates") as Array).map(func(c: Array) -> String: return str(c[0]))
	check(ids.has("challenge"), "the Challenges concept is due on a gun with kills (%s)" % str(ids))
	# explain everything before it (1 per action), until Challenges comes
	var guard: int = 0
	while str(m.call("show_due_concept")) != "challenge" and guard < 20:
		guard += 1
		m.call("dismiss_hint")
		m.call("player_acted")
	eq(str(m.get("hint_id")), "challenge", "the Challenges concept is explained")
	await tree.create_timer(0.5).timeout
	check(gv.chal_line.modulate.a > 0.99, "the line appears as it is explained")
	m.call("dismiss_hint")
	await _settle()
	check(prof.concept_seen("challenge"), "seen")
	m.call("_render")
	await _settle()
	gv = (m.get("_gun_views") as Array)[0]
	check(gv.chal_line.modulate.a > 0.99 and gv.chal_line.mouse_filter == Control.MOUSE_FILTER_STOP, "and stays shown")
	eq(gv.chal_line.get_global_rect(), r0, "the line keeps its place (nothing in the tile moved)")
	# Reset tips hides it again; Tips off always shows it
	prof.reset_concepts()
	m.call("_render")
	await _settle()
	gv = (m.get("_gun_views") as Array)[0]
	check(gv.chal_line.modulate.a < 0.01, "Reset tips: hidden again until explained")
	_game().call("set_setting", "tips", false)
	await _settle()
	check(gv.chal_line.modulate.a > 0.99, "Tips off: the line always shows")
	_game().call("set_setting", "tips", true)
	await _done(m)


func test_inspect_shows_the_concepts() -> void:
	tree.root.size = Vector2i(390, 844)
	var m: Control = _main()
	await _settle()
	m.call("apply_debug", {"screen": "street", "seed": "6", "gun1": "rifle", "stack1": "8,6"})
	m.call("_render")
	await _settle()
	var run: DDRun = _game().get("run")
	var gp: Dictionary = DDPayloads.gun(run, 0)
	check((gp.get("concepts", []) as Array).has("rule_down"), "the Rifle's tooltip carries its rule concept")
	var insp: DDInspect = m.get("_inspect")
	insp.open(gp)
	await _settle()
	check(insp.last_concepts.has("rule_down"), "the tooltip shows it")
	var cl: Label = insp.find_child("Concept_rule_down", true, false)
	check(cl != null and cl.text.contains(DDConcepts.text("rule_down", bal())), "in full")
	insp.close()
	for i: int in run.street.size():
		var cp: Dictionary = DDPayloads.card(run.street[i], run, i)
		check(not (cp.get("concepts", []) as Array).is_empty(), "street card %s has its concepts" % run.street[i].code())
	await _done(m)
