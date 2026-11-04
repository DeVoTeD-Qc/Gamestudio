# fan_row.gd
# Purpose: Container for a row of same-size cards (hand, line, loadout strip). Cards sit side by
#   side with `gap`; when they do not fit they overlap from the right like a fanned hand, but
#   every card keeps an exposed strip of at least min_step px (>= 64 logical px = >= 44 pt), so
#   each stays a tap target and its left edge (cost, Brace shield, rarity stripe) stays readable
#   (art-direction.md §3: "cards overlap but keep a >= 44 pt exposed strip"). Later cards draw
#   on top. MatchScreen sets card_size from the room it has.
# Dependencies: none.
# Author: UI/UX Agent (cz10)
extends Container

var card_size: Vector2 = Vector2(84, 118):
	set(v):
		card_size = v
		update_minimum_size()
		queue_sort()
var gap: float = 8.0
## Smallest exposed width of a covered card (logical px).
var min_step: float = 64.0
## Cards this row must be able to hold without dropping below min_step (minimum width).
var capacity: int = 5:
	set(v):
		capacity = v
		update_minimum_size()


func _get_minimum_size() -> Vector2:
	var n: int = maxi(capacity, 1)
	return Vector2(card_size.x + (n - 1) * min_step, card_size.y)


## Distance between the left edges of neighbouring cards for n cards in this width.
func step_for(n: int) -> float:
	if n <= 1:
		return card_size.x + gap
	return minf(card_size.x + gap, (size.x - card_size.x) / float(n - 1))


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var cards: Array[Control] = []
		for c: Node in get_children():
			if c is Control and (c as Control).visible:
				cards.append(c)
		var step: float = step_for(cards.size())
		var y: float = floorf((size.y - card_size.y) * 0.5)
		for i: int in cards.size():
			fit_child_in_rect(cards[i], Rect2(Vector2(floorf(i * step), y), card_size))
