extends SceneTree
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var vp := SubViewport.new(); vp.size = Vector2i(1168, 540); root.add_child(vp)
	var m: Control = load("res://scenes/Match.tscn").instantiate(); vp.add_child(m)
	for i in 3: await process_frame
	var snap: Dictionary = load("res://scripts/ui/mock_match_data.gd").round_3_sample()
	for lane in snap["lanes"]:
		lane["friendly"] = [{"name": "Demolitions Expert", "cls": "LMG", "fp": 10, "armor": 5, "armor_max": 12}]
	m.show_snapshot(snap)
	for i in 3: await process_frame
	var slot: Control = m.get_node("%Board").get_lanes()[0].get_friendly_slots()[0]
	_dump(slot, 0)
	var lane: Control = m.get_node("%Board").get_lanes()[0]
	print("lane min ", lane.get_combined_minimum_size(), " board ", m.get_node("%Board").get_combined_minimum_size(), " top ", m.get_node("%TopBar").get_combined_minimum_size(), " bottom ", m.get_node("%BottomBar").get_combined_minimum_size())
	for c in m.get_node("%BottomBar").get_children(): print("  ", c.name, c.get_combined_minimum_size())
	for c in m.get_node("%TopBar").get_children(): print("  ", c.name, c.get_combined_minimum_size())
	quit()
func _dump(n: Node, d: int) -> void:
	if n is Control:
		print("  ".repeat(d), n.name, " min=", n.get_combined_minimum_size(), " size=", n.size, " vis=", n.visible)
	for c in n.get_children(): _dump(c, d + 1)
