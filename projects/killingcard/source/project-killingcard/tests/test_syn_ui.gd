# test_syn_ui.gd
# Purpose: kc-syn-ui, the synergy layer on screen (synergy-system.md §9 / §11.3-11.4): banner
#   trait icons / buffed-stat colours (kc-pos-cut: no neighbour keywords, no link ticks),
#   the trait rail and set callouts, the placement preview (ghost with the RESULTING stats,
#   chips; matches the board after Reveal), the inspector's "FP 4 = 3 base +1 Vanguard 2 ..."
#   lines, the Operator's own card (its Supply cost in the deck cards' cost hex since kc-loadout-cut,
#   NEED SUPPLY state, half-height mini
#   card on the board), Undead heal feedback, quick match on the starter, the inspector fix.
#   Runs with or without the git-ignored licensed art folder.
# Author: UI/UX Agent (kc-syn-ui)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const StatBreakdown: GDScript = preload("res://scripts/ui/stat_breakdown.gd")
const MatchSnapshot: GDScript = preload("res://scripts/ui/match_snapshot.gd")
const CostHex: GDScript = preload("res://scripts/ui/cost_hex.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"

var _saved_root_size: Vector2i = Vector2i.ZERO


## Breacher (Vanguard) in B1 with a Marksman (Spec Ops) behind it, a Point Man (Vanguard) in A1:
## Vanguard 2 (+1 FP to every Vanguard since kc-pos-cut; no neighbour links). Returns {breacher, marksman, point_man}.
func _stage(st: MatchState) -> Dictionary:
	var out: Dictionary = {}
	for pair: Array in [[&"breacher", 1], [&"marksman", 1], [&"point_man", 0]]:
		var u: RulesUnit = st.create_unit(0, CardDB.get_card(pair[0]))
		st.put_in_line(u, int(pair[1]))
		out[pair[0]] = u
	return out


func test_board_shows_links_rail_and_resulting_stats() -> void:
	for screen: Dictionary in [Layout.PHONE, Layout.DESKTOP]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		var label: String = screen["name"]
		var st: MatchState = c.state
		var u: Dictionary = _stage(st)
		c.refresh()
		await _frames(3)
		var snap: Dictionary = MatchSnapshot.build(st, c.map, 0)
		var rail: Array = snap["synergy"]["player"]["rail"]
		assert_eq(rail.size(), 2, "%s rail: Vanguard and Spec Ops in play" % label)
		assert_eq([rail[0]["trait"], rail[0]["count"], rail[0]["tier"], rail[0]["next"]], [&"vanguard", 2, 2, 0], "%s Vanguard 2 at tier 2 (no 3-set since v2.1)" % label)
		assert_eq(m.get_trait_rail().chip_texts(&"player"), PackedStringArray(["Vanguard 2", "Spec Ops 1/2"]), "%s rail chips" % label)
		assert_true(m.get_trait_rail().is_visible_in_tree(), "%s rail visible in the strip" % label)
		var strip_r: Rect2 = m.get_badge(&"deck").get_parent().get_global_rect().grow(0.6)
		if m.metrics.has("rail_tray"):
			# kc-layout-a: the phone's sets rail sits in the tray's top row (the killstreak sockets took
			# its place in the strip).
			assert_true(m.get_tray().get_global_rect().grow(0.6).encloses(m.get_trait_rail().get_global_rect()), "%s rail in the tray's top row" % label)
		else:
			assert_true(strip_r.encloses(m.get_trait_rail().get_global_rect()), "%s rail inside the icon strip" % label)
		# kc-pos-cut: the board draws no link ticks any more.
		assert_false(m.get_board().has_method(&"get_drawn_ticks"), "%s no link ticks" % label)
		# Banner entries: buffed FP marked, keyword pip lit, trait tier (kc-no-training: no camo band).
		var b_entry: Dictionary = {}
		var m_entry: Dictionary = {}
		for e: Dictionary in snap["lanes"][1]["friendly"]:
			if int(e["uid"]) == (u[&"breacher"] as RulesUnit).uid:
				b_entry = e
			elif int(e["uid"]) == (u[&"marksman"] as RulesUnit).uid:
				m_entry = e
		assert_eq(int(b_entry["fp"]), st.firepower_of(u[&"breacher"]), "%s banner FP = the engine's" % label)
		assert_true(int(b_entry["fp"]) > int(b_entry["fp_base"]) and int(b_entry["fp_trend"]) == 1, "%s Breacher FP buffed (%d > %d)" % [label, b_entry["fp"], b_entry["fp_base"]])
		assert_eq(String(b_entry.get("kw", "")), "", "%s kc-pos-cut: no neighbour keyword pip" % label)
		assert_eq([String(b_entry["trait"]), int(b_entry["trait_tier"]), b_entry.has("band")], ["vanguard", 2, false], "%s Vanguard 2 icon, no camo band (kc-no-training)" % label)
		assert_eq(int(m_entry["cover"]), 0, "%s kc-pos-cut: no Guard Cover on the Marksman" % label)
		# Inspector: where the number comes from.
		c._on_lane_long_pressed(1, &"player", (u[&"breacher"] as RulesUnit).uid)
		await _frames(3)
		var insp: Control = m.get_inspector()
		var words: String = ""
		for n: Node in insp.get_node("%KeywordList").get_children():
			words += (n as Label).text + "\n"
		assert_true("base" in words and "Vanguard 2" in words, "%s FP breakdown in the inspector: %s" % [label, words])
		assert_false("Spotter" in words or "Link ON" in words, "%s kc-pos-cut: no link lines" % label)
		var screen_r: Rect2 = Rect2(Vector2.ZERO, Vector2(vp.size)).grow(0.6)
		assert_true(screen_r.encloses(insp.get_node("%InfoPanel").get_global_rect()), "%s inspector text panel on screen" % label)
		insp.close()
		# Set callout when a tier switches on (event while the round plays), crack when off.
		m.on_synergy_event({"side": &"player", "counts": {&"vanguard": 2, &"heavy": 2}, "sets": {&"vanguard": 2, &"heavy": 2}, "links": []})
		assert_true(m.get_last_set_callout().begins_with("HEAVY 2:"), "%s callout: %s" % [label, m.get_last_set_callout()])
		assert_eq(m.get_trait_rail().chip_texts(&"player"), PackedStringArray(["Vanguard 2/3", "Heavy 2/3"]), "%s rail follows the event" % label)
		m.on_synergy_event({"side": &"player", "counts": {&"heavy": 2}, "sets": {&"heavy": 2}, "links": []})
		assert_eq(m.get_last_set_callout(), "VANGUARD 2 OFF", "%s a set that switched off is called out" % label)
		_despawn(vp)
		await tree.process_frame


func test_placement_preview_shows_the_result() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var vp: SubViewport = s[0]
	var m: Control = s[1]
	var c: Node = s[2]
	var st: MatchState = c.state
	var me: RulesSide = st.sides[0]
	var pm: RulesUnit = st.create_unit(0, CardDB.get_card(&"point_man"))
	st.put_in_line(pm, 0)
	var rc: RulesCard = RulesCard.new(st.new_uid(), CardDB.get_card(&"marksman"))
	me.hand.append(rc)
	me.supply = 9
	c.refresh()
	await _frames(2)
	var pm_fp_before: int = st.firepower_of(pm)
	c.select_card(rc.uid)
	await _frames(3)
	var lane_a: Node = m.get_board().get_lanes()[0]
	var ghost: BannerView = lane_a.get_ghost()
	assert_not_null(ghost, "ghost in column A")
	var want: Dictionary = StatBreakdown.of_ghost(st, 0, rc.uid, 0)
	assert_eq(int(ghost.entry["fp"]), int(want["fp"]["total"]), "ghost shows the resulting FP")
	assert_eq(String(ghost.entry.get("kw", "")), "", "kc-pos-cut: no neighbour keyword pip on the ghost")
	# kc-pos-cut: the placement preview names no links and draws no ghost ticks.
	assert_false("LINKS" in lane_a.get_target_chips(), "no link part in the preview: %s" % lane_a.get_target_chips())
	assert_eq(lane_a.target_text, "PLAY HERE", "the column badge keeps its words")
	# Play it there; after Reveal the board matches the preview.
	var res: Dictionary = c.play_at(0)
	assert_true(res["ok"], "played: %s" % res.get("reason", ""))
	me.ready = true
	st.sides[1].ready = true
	st.reveal()
	var mu: RulesUnit = null
	for x: RulesUnit in me.lines[0]:
		if x.uid == rc.uid:
			mu = x
	assert_not_null(mu, "Marksman arrived in A")
	if mu != null:
		assert_eq(int(st.synergy_of(mu).get("fp", 0)), int((want["preview"]["card"] as Dictionary).get("fp", 0)), "its own link bonus as previewed")
		assert_eq(st.firepower_of(pm), pm_fp_before, "kc-pos-cut: no Spotter +1 for the Point Man")
	_despawn(vp)


func test_operator_card_is_its_own_card() -> void:
	for screen: Dictionary in [Layout.PHONE, Layout.DESKTOP]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var c: Node = s[2]
		var label: String = screen["name"]
		var st: MatchState = c.state
		var me: RulesSide = st.sides[0]
		var hand: Control = m.get_hand()
		var card: Control = hand.get_operator_card()
		# kc-loadout-cut (head): the Supply cost sits in the same cost hex as every deck card.
		assert_true(card.find_child("OperatorPlate", true, false) == null, "%s no brass Supply plate any more" % label)
		# kc-cards-impl (O2): the cost is drawn in the standard hex (CardLook.draw_cost), like every card.
		assert_eq(int(card.get_meta(&"cost", -1)), st.operator_cost(), "%s the hex shows its Supply cost" % label)
		var sb: StyleBox = card.get_theme_stylebox(&"panel")
		assert_true(sb is StyleBoxFlat and (sb as StyleBoxFlat).border_color.is_equal_approx(Color("#C9A227")), "%s brass frame" % label)
		# kc-econ: round 1's placement is free (operator_free_round1); a respawn costs 1.
		assert_eq(st.operator_cost(), 0, "%s round 1: the Operator is free to place" % label)
		st.round_number = 2
		assert_eq(st.operator_cost(), st.config.operator_cost, "%s later rounds (respawn): it costs Supply" % label)
		# Not enough Supply: red plate, NEED 1 SUPPLY, no glow.
		me.supply = 0
		c.refresh()
		await _frames(2)
		card = hand.get_operator_card()
		assert_true(bool(card.get_meta(&"operator_short", false)), "%s short of Supply" % label)
		assert_eq(String((card.find_child("OperatorStatus", true, false) as Label).text), "NEED %d SUPPLY" % st.operator_cost(), "%s says why" % label)
		assert_false((card.get_node("Glow") as Control).visible, "%s no deploy glow" % label)
		c.select_operator()
		assert_true("Not enough Supply" in m.get_toast_text(), "%s toast: %s" % [label, m.get_toast_text()])
		c.clear_selection()
		# On the board: the half-height mini card, still first in the tray.
		var op: RulesUnit = me.operator_unit
		st.put_in_line(op, 2)
		me.operator_can_deploy = false
		me.supply = 3
		c.refresh()
		await _frames(3)
		card = hand.get_operator_card()
		# kc-cards-impl (O2): the same Operator card in the bottom row, its state ON BOARD · C1.
		assert_eq(StringName(card.get_meta(&"state")), &"board", "%s on the board" % label)
		var k: float = Layout.points_per_px(screen)
		assert_true(card.size.y * k >= 44.0 - 0.1, "%s still a 44 pt tap target" % label)
		for chip: Node in hand.get_cards():
			assert_false(card.get_global_rect().grow(-1.0).intersects((chip as Control).get_global_rect()), "%s the Operator overlaps no hand card" % label)
		var where: Label = card.find_child("OperatorStatus", true, false) as Label
		assert_eq(where.text, "ON BOARD · C1", "%s says where it stands" % label)
		_despawn(vp)
		await tree.process_frame


func test_quick_match_plays_the_starter() -> void:
	var s: Array = await _spawn(Layout.DESKTOP)
	var c: Node = s[2]
	var setup: SideSetup = c.state.sides[0].setup
	var cfg: RunConfig = CardDB.get_run_config()
	assert_false("deck_levels" in setup, "kc-no-training: no copy levels")
	for rc: RulesCard in c.state.sides[0].hand:
		assert_true(SynergyRules.is_single_trait(rc.card_trait()), "a hand copy carries at most one trait")
	assert_true(cfg != null, "run config")
	_despawn(s[0])


func test_undead_heal_feedback() -> void:
	var s: Array = await _spawn(Layout.PHONE)
	var m: Control = s[1]
	var c: Node = s[2]
	var st: MatchState = c.state
	var b: RulesUnit = st.create_unit(0, CardDB.get_card(&"brawler"))
	st.put_in_line(b, 0)
	c.refresh()
	await _frames(2)
	var fx: Control = m.get_fx()
	fx.clear_log()
	await fx.play([{"type": RulesEvent.UNIT_HEALED, "side": &"player", "source_id": &"trait_undead", "source_uid": -1,
			"target_uid": b.uid, "amount": 1, "remaining": 3, "zone": &"left"}])
	assert_true(&"damage_number" in fx.logged_kinds() and &"tag" in fx.logged_kinds(), "heal number + UNDEAD HEAL tag (%s)" % [fx.logged_kinds()])
	_despawn(s[0])


# =============================================================================
# Helpers (as test_ui3.gd)
# =============================================================================

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


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame
