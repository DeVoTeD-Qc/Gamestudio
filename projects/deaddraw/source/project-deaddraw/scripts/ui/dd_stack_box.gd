# dd_stack_box.gd
# Purpose: dd-ux-clean: draws a deck tile as a physical pile - up to 3 card backs peek out under
#   the tile, offset down-right, so "how much is left" reads at a glance without listing the
#   contents (the wave stack and the draw pile). The tile itself (the last child) stays the
#   tappable / inspectable DDCardView; the backs ignore the mouse.
# Dependencies: DDUi. Loaded with preload() by main.gd (no class_name, so no class-cache rescan).
# Author: UI/UX Agent
extends Container

const STEP: float = 4.0

var layers: int = 0


func setup(view: Control, n: int, kind: String) -> Container:
	layers = clampi(n, 0, 3)
	size_flags_horizontal = view.size_flags_horizontal
	size_flags_vertical = view.size_flags_vertical
	for k: int in layers:
		var p: Panel = Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shade: float = 0.25 + 0.15 * (layers - 1 - k)
		p.add_theme_stylebox_override("panel", DDUi.box(DDUi.card_bg(kind).darkened(shade), DDUi.accent(kind).darkened(0.35 + shade * 0.5), 2, 12, 0))
		add_child(p)
	add_child(view)
	return self


func _view() -> Control:
	return get_child(get_child_count() - 1) as Control if get_child_count() > 0 else null


func _get_minimum_size() -> Vector2:
	var v: Control = _view()
	var off: float = STEP * layers
	return (v.get_combined_minimum_size() if v != null else Vector2.ZERO) + Vector2(off, off)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var off: float = STEP * layers
		var r: Rect2 = Rect2(Vector2.ZERO, (size - Vector2(off, off)).max(Vector2.ZERO))
		var n: int = get_child_count()
		for i: int in n:
			var c: Control = get_child(i) as Control
			if c == null:
				continue
			if i == n - 1:
				fit_child_in_rect(c, r)
			else:
				var k: float = STEP * (layers - i)
				fit_child_in_rect(c, Rect2(Vector2(k, k), r.size))
