extends SceneTree
func _dump(n: Node, depth: int, maxd: int) -> void:
	for c in n.get_children():
		if c is Control and (c as Control).visible:
			var r: Rect2 = (c as Control).get_global_rect()
			var t: String = c.get_class()
			if c is DDCardView: t += " " + str((c as DDCardView).payload.get("tag",""))
			if c is Button: t += " '" + (c as Button).text.replace("\n"," | ") + "'"
			print("  ".repeat(depth), t, " ", r.position.round(), " ", r.size.round())
			if depth < maxd: _dump(c, depth + 1, maxd)
func _initialize():
	_go.call_deferred()
func _go():
	var args := OS.get_cmdline_user_args()
	var w := int(args[0]); var h := int(args[1]); var depth := int(args[2])
	root.size = Vector2i(w, h)
	var game = root.get_node("Game")
	game.set("profile", DDProfile.new(DDBalance.get_default(), "user://dbg.json"))
	var m: Control = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(m)
	await process_frame
	var q := {"screen": "street", "seed": "7"}
	for a in args.slice(3):
		var kv = a.split("=")
		q[kv[0]] = kv[1]
	m.call("apply_debug", q)
	m.call("_render")
	await process_frame
	await process_frame
	print("VP ", m.get_viewport_rect().size)
	_dump(m, 0, depth)
	quit()
