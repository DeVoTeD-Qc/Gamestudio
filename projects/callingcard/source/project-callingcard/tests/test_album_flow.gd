# test_album_flow.gd
# Purpose: Album flows (cc11) on a fresh demo collection (its own Collection instance and save):
#   - silhouettes of unowned cards show the unlock goal with live progress, Clearance and trait,
#     and the inspector keeps the silhouette and repeats the goal,
#   - Showcase (store) cards read as premium frame / Clearance 1 / no trait, everywhere,
#   - set completion (3 wins unlock Polar Night -> Whiteout complete): toast + set frames,
#   - Triptychs: "???" + hint until scored, then the panorama reveal and the revealed slot.
# Author: UI/UX Agent (cc11)
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_album_fixtures.gd")
const Hanger: GDScript = preload("res://scripts/ui/album_card_hanger.gd")


func test_album_opens_on_first_set_with_demo_counts() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("counts")
	var seen: Array = []
	var cb: Callable = func(id: StringName) -> void: seen.append(id)
	EventBus.album_opened.connect(cb)
	var setup: Array = await fx.spawn(Fx.DESKTOP, coll)
	var album: Control = setup[1]
	assert_eq(album.current_page, &"night_shift", "opens on the first set page")
	assert_eq((album.get_node("%CardCount") as Label).text, "13 / 20", "spec 8: 13 / 20 cards")
	assert_eq(album.get_tab(&"night_shift").text, "Night Shift 3/4", "tab shows set progress")
	assert_eq(album.get_page().get_progress_label().text, "3 / 4 cards", "page shows set progress")
	assert_true(album.get_tab(&"night_shift").button_pressed, "current tab pressed")
	album.get_tab(&"whiteout").pressed.emit()
	await fx.settle(2)
	assert_eq(album.current_page, &"whiteout", "tab switches page")
	assert_true(seen.has(&"night_shift") and seen.has(&"whiteout"), "album_opened emitted per page (%s)" % [seen])
	EventBus.album_opened.disconnect(cb)
	fx.finish()


func test_silhouettes_show_goal_progress_clearance_and_trait() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("silhouettes")
	var setup: Array = await fx.spawn(Fx.PHONE, coll, &"night_shift")
	var album: Control = setup[1]
	var page: Control = album.get_page()
	# Spec 8 step 1: City Never Sleeps reads "Legend · Reclaim · Unlock: beat Warden".
	var h: Node = page.get_hanger(&"city_never_sleeps")
	assert_not_null(h, "City Never Sleeps hung on the Night Shift page")
	assert_false(h.owned, "not owned at the demo start")
	var cv: BannerCard = h.get_card_view()
	assert_true(cv.locked, "drawn as an embossed silhouette")
	assert_eq(cv.clearance, 4, "silhouette keeps its Clearance pips")
	assert_eq(cv.trait_id, &"reclaim", "silhouette keeps its trait icon")
	assert_eq(h.info_text, "Clearance 4 · Legend · Reclaim", "Clearance and trait in words")
	assert_eq(h.goal_text, "Unlock: Beat the Warden", "unlock goal")
	assert_eq(Hanger.progress_text(h.progress), "0 / 1", "goal progress")
	assert_not_null(h.get_progress_bar(), "progress bar")
	# Owned cards show no goal.
	var own: Node = page.get_hanger(&"neon_rain")
	assert_true(own.owned and not own.get_card_view().locked, "Neon Rain owned and in colour")
	assert_eq(own.goal_text, "", "owned card has no goal")
	assert_eq(own.info_text, "Clearance 2 · Merit · Veteran", "owned card line")
	# Live progress: one win moves Polar Night (Win 3 duels in a row) to 1 / 3.
	album.show_page(&"whiteout")
	await fx.settle(2)
	var polar: Node = album.get_page().get_hanger(&"polar_night")
	assert_eq(polar.goal_text, "Unlock: Win 3 duels in a row", "Polar Night goal")
	assert_eq(Hanger.progress_text(polar.progress), "0 / 3", "Polar Night starts at 0 / 3")
	_win(&"quartermaster")
	await fx.settle(3)
	polar = album.get_page().get_hanger(&"polar_night")
	assert_eq(Hanger.progress_text(polar.progress), "1 / 3", "progress updates from EventBus (1 / 3)")
	assert_eq(int(polar.get_progress_bar().value), 1, "bar at 1")
	assert_eq(int(polar.get_progress_bar().max_value), 3, "bar out of 3")
	# Every locked card on every set page carries a goal and a progress line.
	for s: SetData in CardDB.all_sets():
		album.show_page(s.id)
		await fx.settle(1)
		for hh: Node in album.get_page().get_hangers():
			if not hh.owned:
				assert_true(hh.goal_text.begins_with("Unlock: ") and hh.goal_text.length() > 10, "%s shows its goal" % hh.card.id)
				assert_false(hh.progress.is_empty(), "%s shows its progress" % hh.card.id)
				assert_true(hh.info_text.begins_with("Clearance "), "%s shows Clearance" % hh.card.id)
	# The inspector keeps the silhouette and repeats goal + progress.
	album.show_page(&"whiteout")
	await fx.settle(1)
	var btn: Button = album.get_page().get_hanger(&"polar_night").get_button()
	btn.simulate_hold()
	btn.pressed.emit()  # the release after a hold does not tap again
	await fx.settle(2)
	var insp: Control = album.get_inspector()
	assert_true(insp.is_open(), "long-press opens the inspector")
	assert_true(insp.get_card_view().locked, "inspector shows the silhouette")
	var earned: String = (insp.get_node("%EarnedLabel") as Label).text
	assert_true(earned.contains("Win 3 duels in a row") and earned.contains("1 / 3"), "inspector goal + progress: %s" % earned)
	assert_eq((insp.get_node("%TraitHeading") as Label).text, "TRAIT · CLUTCH", "inspector trait")
	assert_eq((insp.get_node("%ClearanceLabel") as Label).text, "Clearance 3 · Distinction", "inspector Clearance")
	insp.close()
	fx.finish()


func test_showcase_reads_premium_clearance_1_no_trait() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("showcase")
	var setup: Array = await fx.spawn(Fx.DESKTOP, coll, &"showcase")
	var album: Control = setup[1]
	var page: Control = album.get_page()
	var issue: Dictionary = ArtKit.FRAMES[1]
	var ids: Array[StringName] = []
	for c: CardData in CardDB.cards_in_set(&"showcase"):
		ids.append(c.id)
		assert_eq(c.clearance, 1, "%s data: Clearance 1" % c.id)
		assert_eq(c.card_trait(), DataEnums.CardTrait.NONE, "%s data: no trait" % c.id)
		var h: Node = page.get_hanger(c.id)
		assert_true(h.owned, "%s owned (store, free in the demo)" % c.id)
		var cv: BannerCard = h.get_card_view()
		var spec: Dictionary = cv._frame_spec()
		assert_eq(spec["name"], "Showcase", "%s wears the Showcase frame" % c.id)
		assert_true(float(spec["glint"]) > float(ArtKit.FRAMES[4]["glint"]) - 0.001, "%s frame is the flashiest (animated reflections)" % c.id)
		assert_true(float(spec["border"]) > float(issue["border"]), "%s frame heavier than a Clearance 1 frame" % c.id)
		assert_eq(cv.clearance, 1, "%s shows 1 Clearance pip" % c.id)
		assert_eq(cv.trait_id, &"none", "%s shows no trait icon" % c.id)
		assert_eq(h.info_text, "Showcase frame · Clearance 1 · No trait", "%s caption" % c.id)
		album.inspect_card(c.id)
		await fx.settle(1)
		var insp: Control = album.get_inspector()
		assert_eq((insp.get_node("%ClearanceLabel") as Label).text, "Clearance 1 · Issue", "%s inspector Clearance" % c.id)
		assert_eq((insp.get_node("%TraitHeading") as Label).text, "TRAIT · NO TRAIT", "%s inspector: no trait" % c.id)
		assert_eq((insp.get_node("%TraitRule") as Label).text, "Store card: premium frame, Clearance 1, no trait.", "%s inspector rule" % c.id)
		assert_eq(insp.get_card_view()._frame_spec()["name"], "Showcase", "%s inspector frame" % c.id)
		insp.close()
	assert_eq(ids, [&"chrome_tiger", &"gold_leaf"], "Showcase page holds the two store cards")
	var tag: Label = page.get_node("Tagline")
	assert_true(tag.text.contains("Clearance 1") and tag.text.contains("no trait"), "page states the store rule: %s" % tag.text)
	assert_false(page.get_node("Header").find_child("SetReward", true, false).visible, "no completion reward on Showcase")
	# The same cards on a normal Clearance 1 frame would read as Issue: chrome vs gold differ too.
	var frames: Dictionary = {}
	for h: Node in page.get_hangers():
		frames[h.get_card_view()._frame_spec()["base"]] = true
	assert_eq(frames.size(), 2, "chrome and gold leaf frames differ")
	fx.finish()


func test_set_completion_celebrates_and_frames_cards() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("set_complete")
	var setup: Array = await fx.spawn(Fx.PHONE_NOTCH, coll, &"whiteout")
	var album: Control = setup[1]
	var events: Array = []
	var on_set: Callable = func(id: StringName) -> void: events.append(["set", id])
	var on_card: Callable = func(id: StringName, _src: StringName) -> void: events.append(["card", id])
	EventBus.set_completed.connect(on_set)
	EventBus.card_unlocked.connect(on_card)
	for i: int in 3:
		_win(&"archivist")
	await fx.settle(3)
	assert_true(events.has(["card", &"polar_night"]), "Polar Night unlocked by 3 wins in a row")
	assert_true(events.has(["set", &"whiteout"]), "Whiteout completed")
	assert_true(album.get_toast_text().begins_with("Set complete: Whiteout") or album.get_toast_text().begins_with("New card"), "toast: %s" % album.get_toast_text())
	var page: Control = album.get_page()
	assert_eq(page.get_progress_label().text, "4 / 4 cards · Complete", "page says complete")
	for h: Node in page.get_hangers():
		assert_true(h.owned, "%s owned" % h.card.id)
		assert_true(h.get_card_view().set_complete, "%s wears the animated set frame" % h.card.id)
		assert_true(h.info_text.ends_with("Set frame"), "%s caption names the set frame" % h.card.id)
	assert_eq(album.get_tab(&"whiteout").text, "Whiteout 4/4", "tab updated")
	assert_eq((album.get_node("%CardCount") as Label).text, "14 / 20", "header count updated")
	EventBus.set_completed.disconnect(on_set)
	EventBus.card_unlocked.disconnect(on_card)
	fx.finish()


func test_triptych_hints_then_panorama_reveal() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("triptych")
	var setup: Array = await fx.spawn(Fx.PHONE, coll, &"triptychs")
	var album: Control = setup[1]
	var page: Control = album.get_page()
	for t: TriptychData in CardDB.all_triptychs():
		var slot: Control = page.get_slot(t.id)
		assert_not_null(slot, "%s has a slot" % t.id)
		assert_false(page.is_revealed_slot(t.id), "%s hidden at the start" % t.id)
		var frames: Control = slot.get_node("HiddenFrames")
		assert_eq(frames.get_child_count(), 3, "%s: three joined empty frames" % t.id)
		assert_eq((frames.get_child(0).get_child(0) as Label).text, "???", "%s shows ???" % t.id)
		assert_eq((slot.get_node("Hint") as Label).text, "“%s”" % t.hint, "%s shows its hint" % t.id)
		assert_false(slot.get_node("Hint").text.contains(t.cards[0].display_name), "%s hint does not name its cards" % t.id)
	assert_eq(album.get_tab(&"triptychs").text, "Triptychs 0/3", "tab count")
	# Scoring Midnight Run in a duel reveals it (Collection emits triptych_revealed).
	EventBus.triptych_scored.emit(&"player", &"midnight_run", true)
	await fx.settle(2)
	var reveal: Control = album.get_reveal()
	assert_true(reveal.is_open(), "panorama reveal opens")
	assert_eq(reveal.get_panorama().triptych, &"midnight_run", "12:1 Midnight Run panorama")
	var cards: Array = []
	for c: BannerCard in reveal.get_stage_cards():
		cards.append(c.card_id)
	assert_eq(cards, [&"graveyard_shift", &"neon_rain", &"last_train"], "the three cards slide together")
	assert_false(reveal.is_finished(), "animating")
	await tree.create_timer(1.7).timeout
	assert_true(reveal.is_finished(), "reveal finishes in about 1.5 s")
	assert_true(reveal.get_panorama().modulate.a > 0.99, "panorama shown")
	var labels: Array[String] = []
	for l: Label in reveal.get_labels():
		labels.append(l.text)
	assert_true(labels.has("MIDNIGHT RUN"), "title shown: %s" % [labels])
	assert_true(labels.has("TITLE EARNED · NIGHT OWL+"), "reward title shown: %s" % [labels])
	assert_true(coll.has_title(&"midnight_run"), "title granted by Collection")
	reveal.get_continue_button().pressed.emit()
	await fx.settle(3)
	assert_false(reveal.is_open(), "CONTINUE closes")
	page = album.get_page()
	assert_true(page.is_revealed_slot(&"midnight_run"), "slot now shows the panorama")
	assert_false(page.is_revealed_slot(&"cold_signal"), "others stay hidden")
	assert_eq((page.get_slot(&"midnight_run").get_node("Name") as Label).text, "MIDNIGHT RUN", "name under the panorama")
	assert_eq(album.get_tab(&"triptychs").text, "Triptychs 1/3", "tab count updated")
	# Tapping the revealed panorama replays the reveal; a tap mid-animation skips to the end.
	(page.get_slot(&"midnight_run").get_node("PanoramaButton") as Button).pressed.emit()
	await fx.settle(1)
	assert_true(reveal.is_open(), "tap replays the reveal")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	reveal.get_node("Scrim").gui_input.emit(ev)
	assert_true(reveal.is_finished(), "tap skips to the end")
	reveal.get_node("Scrim").gui_input.emit(ev)
	assert_false(reveal.is_open(), "second tap closes")
	fx.finish()


func test_reveal_respects_reduced_motion_and_fast_animations() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("reveal_motion")
	var setup: Array = await fx.spawn(Fx.DESKTOP, coll, &"triptychs")
	var album: Control = setup[1]
	var reveal: Control = album.get_reveal()
	var was_reduced: bool = Settings.reduced_motion
	var was_fast: bool = Settings.fast_animations
	Settings.reduced_motion = true
	album.play_triptych_reveal(&"cold_signal")
	var cards: Array[BannerCard] = reveal.get_stage_cards()
	var cw: float = cards[0].size.x
	for i: int in 3:
		assert_true(absf(cards[i].position.x - cw * i) < 0.5, "reduced motion: card %d does not travel" % i)
	reveal.close()
	Settings.reduced_motion = false
	Settings.fast_animations = true
	album.play_triptych_reveal(&"open_book")
	assert_true(cards[0].position.x < -0.5, "normal motion: cards start apart")
	await tree.create_timer(0.75).timeout
	assert_true(reveal.is_finished(), "fast animations: done in 0.6 s")
	reveal.close()
	Settings.reduced_motion = was_reduced
	Settings.fast_animations = was_fast
	fx.finish()


func test_back_closes_overlays_then_leaves() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("back")
	var setup: Array = await fx.spawn(Fx.DESKTOP, coll)
	var album: Control = setup[1]
	var router: Node = tree.root.get_node("SceneRouter")
	var was_dry: bool = router.dry_run
	router.dry_run = true
	router.last_requested = ""
	album.inspect_card(&"graveyard_shift")
	var back: Button = album.get_node("%BackButton")
	back.pressed.emit()
	assert_false(album.get_inspector().is_open(), "BACK closes the inspector first")
	assert_eq(router.last_requested, "", "and stays in the album")
	back.pressed.emit()
	assert_eq(router.last_requested, router.SCENE_TITLE, "then BACK leaves the album")
	router.dry_run = was_dry
	fx.finish()


func _win(rival: StringName) -> void:
	EventBus.duel_started.emit(&"rival", rival, &"player")
	EventBus.duel_ended.emit(&"win", 6, 4, 10, 180.0)
