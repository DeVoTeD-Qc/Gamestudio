# test_deck_match.gd
# Purpose: kc-deck-match (the head: "The starting deck shown when we start campaign doesn't match what
#   I draw in game 1. Make sure we use the correct starting deck with mostly units and one kind of
#   tactics. Tactic and Field cards should have a different icon."). Checks:
#   - in the public build AND with the private pitch active (PitchDecks.forced), a run's first match
#     plays exactly the starter the Loadout screen shows (StarterPanel.grouped_starter): the same
#     card multiset in the player's deck + hand; the pitch swaps reach only the Quick Match;
#   - the starter is mostly units, one Tactic kind, no Field;
#   - Tactic and Field have different type icons (CardLook.type_icon_id / draw_type_icon).
# Author: UI/UX Agent (kc-deck-match)
extends "res://tests/test_case.gd"

const StarterPanel: GDScript = preload("res://scripts/ui/run/starter_panel.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const SEED: int = 4242


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


static func _multiset(cards: Array) -> Dictionary:
	var out: Dictionary = {}
	for c: Variant in cards:
		var id: StringName = (c as CardData).id if c is CardData else (c as RulesCard).card.id
		out[id] = int(out.get(id, 0)) + 1
	return out


func test_starter_is_units_and_one_tactic_kind() -> void:
	var cfg: RunConfig = CardDB.get_run_config()
	var units: int = 0
	var tactic_kinds: Dictionary = {}
	for c: CardData in cfg.starter_deck:
		assert_false(c.is_field(), "no Field in the starter (%s)" % c.id)
		if c.is_unit():
			units += 1
		elif c.card_type == DataEnums.CardType.TACTIC:
			tactic_kinds[c.id] = true
	assert_true(units * 2 > cfg.starter_deck.size(), "mostly units (%d of %d)" % [units, cfg.starter_deck.size()])
	assert_eq(tactic_kinds.size(), 1, "one Tactic kind (%s)" % [tactic_kinds.keys()])
	var shown: Dictionary = {}
	for g: Dictionary in StarterPanel.grouped_starter(cfg):
		shown[(g["card"] as CardData).id] = int(g["count"])
	assert_eq(shown, _multiset(cfg.starter_deck), "the starter panel lists the config's starter")


func test_first_run_match_plays_the_shown_starter() -> void:
	var rs: Node = tree.root.get_node("RunState")
	var router: Node = tree.root.get_node("SceneRouter")
	var saved: Dictionary = {"save_path": rs.save_path, "autosave": rs.autosave, "config": rs.config, "dry_run": router.dry_run}
	rs.config = null
	rs.autosave = false
	rs.save_path = "user://test_deck_match/run.json"
	router.dry_run = true
	for pitch: bool in [false, true]:
		var label: String = "pitch build" if pitch else "public build"
		PitchDecks.forced = pitch
		rs.start_run(SEED)
		rs.begin_run()
		var shown: Dictionary = {}
		for g: Dictionary in StarterPanel.grouped_starter(rs.run.config):
			shown[(g["card"] as CardData).id] = int(g["count"])
		var vp: SubViewport = SubViewport.new()
		vp.size = Vector2i(1280, 720)
		tree.root.add_child(vp)
		var screen: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
		vp.add_child(screen)
		await _frames(3)
		var c: Node = screen.get_node("%MatchController")
		var m: MatchState = rs.create_match()
		assert_true(c.start_run_match(m), "%s: the run match starts" % label)
		assert_false(c.pitch_swaps_apply(), "%s: no showcase swaps in a run match" % label)
		var me: RulesSide = c.state.sides[0]
		var played: Dictionary = _multiset(me.deck + me.hand)
		assert_eq(played, shown, "%s: match 1 deck + hand = the starter shown (%s)" % [label, played])
		# The Quick Match still showcases the pitch (and only there).
		c.is_run_match = false
		assert_eq(c.pitch_swaps_apply(), pitch, "%s: Quick Match swaps only in the pitch build" % label)
		vp.queue_free()
		await tree.process_frame
		rs.abandon_run()
	PitchDecks.forced = false
	rs.save_path = saved["save_path"]
	rs.autosave = saved["autosave"]
	rs.config = saved["config"]
	router.dry_run = saved["dry_run"]
	router.pending_match = null
	router.active_match = null
	rs.reset()


func test_tactic_and_field_type_icons_differ() -> void:
	assert_eq(CardLook.type_icon_id(&"tactic"), CardLook.ICO_TYPE_TACTIC, "Tactic: ico_type_tactic")
	assert_eq(CardLook.type_icon_id(&"field"), CardLook.ICO_TYPE_FIELD, "Field: ico_type_field")
	assert_eq(CardLook.type_icon_id(&"equipment"), CardLook.ICO_TYPE_FIELD, "equipment = Field")
	assert_true(CardLook.ICO_TYPE_TACTIC != CardLook.ICO_TYPE_FIELD, "two different slots")
	# The code fallbacks draw different shapes: rasterise both and compare.
	var imgs: Array[Image] = []
	for kind: StringName in [&"tactic", &"field"]:
		var vp: SubViewport = SubViewport.new()
		vp.size = Vector2i(32, 32)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		tree.root.add_child(vp)
		var ci := Control.new()
		ci.size = Vector2(32, 32)
		vp.add_child(ci)
		ci.draw.connect(func() -> void: CardLook.draw_type_icon(ci, Rect2(0, 0, 32, 32), kind, Color.WHITE, true))
		ci.queue_redraw()
		await RenderingServer.frame_post_draw
		await _frames(1)
		imgs.append(vp.get_texture().get_image())
		vp.queue_free()
	var diff: int = 0
	for y: int in 32:
		for x: int in 32:
			if absf(imgs[0].get_pixel(x, y).a - imgs[1].get_pixel(x, y).a) > 0.5:
				diff += 1
	assert_true(diff > 40 or DisplayServer.get_name() == "headless", "the two glyphs differ (%d px)" % diff)
	# Every card face that names the type shows the icon: the Y2+ type line and the X1 kind badge.
	var cv: CardView = (load("res://scenes/match/CardView.tscn") as PackedScene).instantiate()
	tree.root.add_child(cv)
	cv.set_card_data(CardView.view_for_card(CardDB.get_card(&"ammo_resupply")))
	await _frames(1)
	assert_eq(cv.type_icon_kind(), &"tactic", "Y2+ Tactic shows the Tactic icon")
	cv.set_card_data(CardView.view_for_card(CardDB.get_card(&"war_standard")))
	await _frames(1)
	assert_eq(cv.type_icon_kind(), &"field", "Y2+ Field shows the Field icon")
	cv.set_card_data(CardView.view_for_card(CardDB.get_card(&"marksman")))
	await _frames(1)
	assert_eq(cv.type_icon_kind(), &"", "a unit keeps its look (no type icon on the line)")
	cv.queue_free()
	var lay: Dictionary = BannerCard.layout_for(Vector2(220, 100), BannerCard.entry_for_card(CardDB.get_card(&"war_standard")))
	assert_true((lay["kind_word"] as Rect2).has_area(), "X1 Field: the kind badge (icon + FIELD)")
