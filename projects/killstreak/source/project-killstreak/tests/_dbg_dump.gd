extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,720)
	await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(int(OS.get_cmdline_user_args()[0]), int(OS.get_cmdline_user_args()[1]))
	root.add_child(vp)
	var m: Control = load("res://scenes/Match.tscn").instantiate()
	vp.add_child(m)
	for i in 4: await process_frame
	_dump(m, 0)
	quit()
func _dump(n: Node, d: int) -> void:
	if n is Control and d < 9:
		var c: Control = n
		print("  ".repeat(d), n.name, " ", c.get_global_rect(), " min=", c.get_combined_minimum_size())
	for ch in n.get_children(): _dump(ch, d+1)
