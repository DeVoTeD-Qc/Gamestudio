# shot_text.gd
# Purpose: Dev tool (kc-text): phone-size (844x390) screenshots of the text surfaces the text audit
#   touches, public art only: the hand, the inspector on a keyword unit / a vanilla unit / a tactic,
#   the Supply and streak badge inspectors, the glossary and a hover tooltip.
# Usage: xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 844x390 \
#          -s res://tests/tools/shot_text.gd -- <out_dir> <prefix>
# Author: Mid Game Designer Agent (kc-text)
extends SceneTree

var _out: String = ""
var _prefix: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _shot(nm: String) -> void:
	for i: int in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out.path_join("%s_%s.png" % [_prefix, nm]))


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://shots"
	_prefix = args[1] if args.size() > 1 else "text"
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	BannerArtDB.licensed_enabled = false  # PUBLIC art only
	BannerArtDB.clear_cache()
	var m: Control = (load("res://scenes/Match.tscn") as PackedScene).instantiate()
	root.add_child(m)
	for i: int in 30:
		await process_frame
	var c: Node = m.get_node("%MatchController")
	if c.is_mulligan_open():
		c.keep_hand()
	await _shot("hand")
	var screen: Node = c.get("_screen")
	var insp: Control = screen.call(&"get_inspector")
	var me: RulesSide = c.state.sides[0]
	# A hand card with a keyword (or the first one).
	var pick_uid: int = me.hand[0].uid
	for rc: RulesCard in me.hand:
		if rc.card.is_unit() and not CardInfo_keywords_empty(rc.card):
			pick_uid = rc.uid
			break
	c.call(&"_on_card_inspected", pick_uid)
	await _shot("insp_hand")
	insp.call(&"close")
	for id: String in ["kc_wip_private_2", "kc_wip_war_shout", "kc_wip_riot_shield", "si_grunt"]:
		var card: CardData = load("res://data/cards/%s.tres" % id) as CardData
		c.call(&"open_card_inspector", card, "friend", ("You have %d Supply." if card.cost <= me.supply else "Not enough Supply: you have %d.") % me.supply)
		await _shot("insp_" + id)
		insp.call(&"close")
	for key: StringName in [&"supply", &"streak", &"deck"]:
		c.call(&"_on_rail_inspected", key)
		await _shot("rail_" + String(key))
		insp.call(&"close")
	c.call(&"_on_card_inspected", pick_uid)
	var g: Control = insp.call(&"open_glossary", &"cover")
	await _shot("glossary")
	g.call(&"close")
	insp.call(&"close")
	# Hover tooltips (desktop): headless has no real hover, so each control's tooltip is drawn the way
	# the engine would (its _make_custom_tooltip when it has one, else a themed TooltipPanel).
	var targets: Array = [screen.get("_supply_box"), screen.call(&"get_badge", &"streak"), screen.call(&"get_badge", &"score")]
	var hand: Node = screen.call(&"get_hand")
	var panels: Array[Node] = hand.find_children("*", "PanelContainer", true, false)
	for p: Node in panels:
		if p is Control and (p as Control).tooltip_text != "":
			targets.append(p)
			break
	var y: float = 8.0
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	for t: Variant in targets:
		var ctl: Control = t as Control
		if ctl == null:
			continue
		var tip_text: String = ctl.get_tooltip(ctl.size * 0.5)
		if tip_text == "":
			continue
		var custom: Object = ctl.call(&"_make_custom_tooltip", tip_text) if ctl.has_method(&"_make_custom_tooltip") else null
		var panel := PanelContainer.new()
		panel.theme = ctl.get_theme() if ctl.get_theme() != null else m.theme
		panel.theme_type_variation = &"TooltipPanel"
		if custom is Control:
			panel.add_child(custom)
		else:
			var l := Label.new()
			l.theme_type_variation = &"TooltipLabel"
			l.text = tip_text
			panel.add_child(l)
		layer.add_child(panel)
		panel.position = Vector2(80, y)
		y += 64.0
	await _shot("tooltips")
	print("shots ", _out, " ", _prefix)
	quit()


static func CardInfo_keywords_empty(card: CardData) -> bool:
	var ci: GDScript = load("res://scripts/ui/card_info.gd") as GDScript
	return (ci.call(&"keywords", card) as Array).is_empty()
