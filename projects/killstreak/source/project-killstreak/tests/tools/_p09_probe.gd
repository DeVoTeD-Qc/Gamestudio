extends SceneTree
const Layout = preload("res://tests/test_board_layout.gd")
func _initialize() -> void:
	_run.call_deferred()
func _ev(vp, pos, pressed):
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = pos; e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	vp.push_input(e)
func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var vp := SubViewport.new()
	vp.size = Vector2i(Layout.logical_size(Layout.PHONE))
	root.add_child(vp)
	var m: Control = load("res://scenes/Match.tscn").instantiate()
	vp.add_child(m)
	for i in 5: await process_frame
	var c = m.get_node("%MatchController")
	var p: Vector2 = m.get_operator_panel().get_global_rect().position + Vector2(30, 20)
	for k in 3:
		_ev(vp, p, true); await process_frame; _ev(vp, p, false)
		for i in 3: await process_frame
		print("after tap ", k, " selection ", c.selection)
	quit()
