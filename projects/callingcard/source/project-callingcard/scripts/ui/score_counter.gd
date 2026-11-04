# score_counter.gd
# Purpose: One lacquer score counter (art direction §5): owner tab (solid = you, notched = rival),
#   name and cards left in hand, the Signature ribbon with that card's name (and "CARDED" once it
#   is captured), and the score as a key number. side = &"rival" mirrors it (score on the left).
# Dependencies: ArtKit (cc14 palette); theme variations ScorePlayerPanel/ScoreRivalPanel, ScorePlayer/ScoreRival.
# Author: UI/UX Agent (cc07)
extends PanelContainer


@export var side: StringName = &"player"

@onready var _row: HBoxContainer = %Row
@onready var _tab: Control = %Tab
@onready var _name: Label = %NameLabel
@onready var _ribbon: Control = %Ribbon
@onready var _sig: Label = %SignatureLabel
@onready var _sig_state: Label = %SignatureState
@onready var _score: Label = %ScoreLabel
@onready var _info: VBoxContainer = %Info


func _ready() -> void:
	theme_type_variation = &"ScorePlayerPanel" if side == &"player" else &"ScoreRivalPanel"
	_score.theme_type_variation = &"ScorePlayer" if side == &"player" else &"ScoreRival"
	_tab.draw.connect(_draw_tab)
	_ribbon.draw.connect(_draw_ribbon)
	if side == &"rival":
		# Mirror: [score][info][tab], text right-aligned.
		_row.move_child(_score, 0)
		_row.move_child(_tab, -1)
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_info.alignment = BoxContainer.ALIGNMENT_BEGIN
		var ribbon_row: HBoxContainer = _ribbon.get_parent()
		ribbon_row.alignment = BoxContainer.ALIGNMENT_END
		ribbon_row.move_child(_ribbon, -1)


## data: {name, score, hand_count, signature_name, signature_carded_by}
func show_counter(data: Dictionary) -> void:
	var hand_count: int = int(data.get("hand_count", 0))
	_name.text = "%s · %d in hand" % [String(data.get("name", "")).to_upper(), hand_count]
	_score.text = str(int(data.get("score", 0)))
	_sig.text = String(data.get("signature_name", ""))
	var carded_by: StringName = data.get("signature_carded_by", &"")
	_sig_state.visible = carded_by != &""
	_sig_state.text = "CARDED"
	_sig_state.add_theme_color_override(&"font_color", ArtKit.side_color(carded_by))
	_ribbon.queue_redraw()


func get_score_label() -> Label:
	return _score


func get_important_labels() -> Array[Label]:
	return [_name, _sig, _sig_state, _score]


func _draw_tab() -> void:
	var s: Vector2 = _tab.size
	var w: float = s.x
	var col: Color = ArtKit.side_color(side)
	if side == &"player":
		_tab.draw_rect(Rect2(Vector2(0, (s.y - w) * 0.5), Vector2(w, w)), col)
	else:
		var y: float = (s.y - w) * 0.5
		_tab.draw_colored_polygon(PackedVector2Array([Vector2(0, y), Vector2(w, y), Vector2(w, y + w),
				Vector2(w * 0.5, y + w * 0.45), Vector2(0, y + w)]), col)


func _draw_ribbon() -> void:
	var s: Vector2 = _ribbon.size
	_ribbon.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y),
			Vector2(s.x * 0.5, s.y * 0.7), Vector2(0, s.y)]), ArtKit.SIGNATURE)
