# test_readability.gd
# Purpose: kc-readability (the head, iPhone landscape: "The cost icon and number as well as stats icon
#   and number need to be bigger/more readable ... a better font ... the supply count at top should use
#   same iconography as supply cost of cards ... some backing behind icons"). Checks, at 844x390 and
#   the iPhone SE's 667x375:
#   - hand cards (X1): the cost digit and the FP / Armor digits, in pt;
#   - board banners: the same digits;
#   - one number face (Oswald Bold, tabular digits) with a dark outline for every card number and
#     the Supply counter; its OFL licence is bundled;
#   - the Supply pips are cost hexes;
#   - soft dark backings behind the badge groups on the art (never a band).
# Author: UI/UX Agent (kc-readability)
extends "res://tests/test_case.gd"

const Layout: GDScript = preload("res://tests/test_board_layout.gd")
const MATCH_SCENE: String = "res://scenes/Match.tscn"
const PHONE_SE: Dictionary = {"name": "iPhone SE 667x375 @2x", "pt": Vector2(667, 375), "ratio": 2.0}
## Digit floors (pt): the head asked for about 13-14 pt on an iPhone; the SE's 16:9 tray is narrower.
const MIN_PT: Dictionary = {"iPhone 844x390 @3x": 13.0, "iPhone SE 667x375 @2x": 11.0}

var _saved_root_size: Vector2i = Vector2i.ZERO


func _frames(n: int) -> void:
	for i: int in n:
		await tree.process_frame


func _spawn(screen: Dictionary) -> Array:
	_saved_root_size = tree.root.size
	tree.root.size = Vector2i(1280, 720)
	await tree.process_frame
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(screen))
	vp.disable_3d = true
	tree.root.add_child(vp)
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	vp.add_child(m)
	await _frames(4)
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	var st: MatchState = c.state
	for side: int in 2:
		st.put_in_line(st.create_unit(side, CardDB.get_card(&"rifleman")), 0)
	st.sides[0].hand.append(RulesCard.new(st.new_uid(), CardDB.get_card(&"marksman"), SynergyRules.LEVEL_TRAINED))
	c.refresh()
	await _frames(4)
	return [vp, m, c]


## The digit size (px) CardLook draws in a reticle / plate / hex of this rect.
static func _reticle_px(r: Rect2, digits: int = 1) -> float:
	var rad: float = minf(r.size.x, r.size.y) * 0.5
	return maxi(14, int(roundf(rad * (1.2 if digits > 1 else 1.4))))


static func _armor_px(r: Rect2, digits: int = 1) -> float:
	return maxi(14, int(roundf(r.size.x * (0.62 if digits > 1 else 0.74))))


static func _cost_px(r: Rect2) -> float:
	return maxi(12, int(r.size.y * 0.8))


func test_number_face_and_licence() -> void:
	assert_eq((CardLook.NUM_FONT as FontVariation).base_font.resource_path, "res://assets/fonts/Oswald-Variable.ttf", "Oswald")
	assert_eq(int((CardLook.NUM_FONT as FontVariation).variation_opentype.get(2003265652, 0)), 700, "Bold (wght 700)")
	assert_eq(int((CardLook.NUM_FONT as FontVariation).opentype_features.get(1953396077, 0)), 1, "tabular digits")
	assert_true(FileAccess.file_exists("res://assets/fonts/OFL-Oswald.txt"), "its OFL licence is bundled")
	assert_true(CardLook.NUM_OUTLINE >= 3, "a dark outline on numbers over art")
	assert_true(CardLook.BACKING.a >= 0.75 and CardLook.BACKING.a <= 0.85, "backing ~75-85%% black (%.2f)" % CardLook.BACKING.a)


func test_hand_and_board_digits_in_pt() -> void:
	for screen: Dictionary in [Layout.PHONE, PHONE_SE]:
		var s: Array = await _spawn(screen)
		var vp: SubViewport = s[0]
		var m: Control = s[1]
		var label: String = screen["name"]
		var k: float = Layout.points_per_px(screen)
		var floor_pt: float = MIN_PT[label]
		var checked: int = 0
		for chip: Node in m.get_hand().get_cards():
			var bv: BannerView = m.get_hand().get_banner(chip)
			if bv == null:
				continue
			assert_eq(bv.cost_scale > 1.0, true, "%s: hand cost hex boosted" % label)
			var an: Dictionary = bv.anatomy_now()
			var cost_pt: float = _cost_px(an["cost"]) * k
			assert_true(cost_pt >= floor_pt, "%s: hand cost digit %.1f pt" % [label, cost_pt])
			if bv.entry.has("fp"):
				var face: Control = chip.get_node("Face")
				var sr: Dictionary = BannerCard.stat_rects(face.size)
				var fp_pt: float = _reticle_px(sr["fp"]) * k
				var ar_pt: float = _armor_px(sr["armor"]) * k
				assert_true(fp_pt >= floor_pt and ar_pt >= floor_pt, "%s: hand FP %.1f / Armor %.1f pt" % [label, fp_pt, ar_pt])
				assert_false(bv.draw_stats, "%s: the hand card draws its own big stats" % label)
				var name_l: Label = chip.find_child("NameLabel", true, false)
				var need: float = CardLook.TITLE_FONT.get_string_size(name_l.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, CardLook.TITLE_PX).x
				assert_true(need <= name_l.size.x + 0.5 or name_l.autowrap_mode != TextServer.AUTOWRAP_OFF, "%s: %s whole (or wrapped)" % [label, name_l.text])
			checked += 1
		assert_true(checked >= 4, "%s: hand cards checked (%d)" % [label, checked])
		var slot: Node = m.get_board().get_lanes()[0].get_friendly_slots()[0]
		var bb: BannerView = slot.get(&"banner")
		var a: Dictionary = bb.anatomy_now()
		var bfp: float = _reticle_px(a["fp"]) * k
		var bar: float = _armor_px(a["armor"]) * k
		assert_true(bfp >= floor_pt and bar >= floor_pt, "%s: board FP %.1f / Armor %.1f pt" % [label, bfp, bar])
		# Backings: the stats, the trait and (peeked) the cost group, each a small plate, never a band.
		bb.peek = true
		bb.queue_redraw_all()
		await _frames(2)
		assert_true(bb.backing_rects.size() >= 2, "%s: soft backings drawn (%d)" % [label, bb.backing_rects.size()])
		for r: Rect2 in bb.backing_rects:
			assert_true(r.size.x < bb.size.x * 0.6, "%s: a plate, not a band (%s)" % [label, r])
		bb.peek = false
		# The Supply counter: cost hexes and the number face.
		var sup: Control = m.get_node("%SupplyCounter")
		var pips: Array[Node] = sup.find_children("*", "Panel", true, false).filter(func(p: Node) -> bool: return p.has_meta(&"hex"))
		assert_true(pips.size() >= 1, "%s: Supply pips are cost hexes" % label)
		var val: Label = m.get("_supply_value")
		assert_eq(val.get_theme_font(&"font"), CardLook.NUM_FONT, "%s: Supply number in the number face" % label)
		assert_true(val.get_theme_font_size(&"font_size") * k >= floor_pt, "%s: Supply number %.1f pt" % [label, val.get_theme_font_size(&"font_size") * k])
		vp.queue_free()
		tree.root.size = _saved_root_size
		await tree.process_frame


func test_y2plus_numbers() -> void:
	var cv: CardView = (load("res://scenes/match/CardView.tscn") as PackedScene).instantiate()
	tree.root.add_child(cv)
	cv.set_card_data(CardView.view_for_card(CardDB.get_card(&"marksman")))
	cv.set_card_width(172)
	await tree.process_frame
	var k: float = Layout.points_per_px(Layout.PHONE)
	for n: String in ["CostLabel", "FirepowerLabel", "ArmorLabel"]:
		var l: Label = cv.find_child(n, true, false)
		assert_eq(l.get_theme_font(&"font"), CardLook.NUM_FONT, "%s in the number face" % n)
		assert_true(l.get_theme_font_size(&"font_size") * k >= 14.0, "%s %.1f pt" % [n, l.get_theme_font_size(&"font_size") * k])
	cv.free()
