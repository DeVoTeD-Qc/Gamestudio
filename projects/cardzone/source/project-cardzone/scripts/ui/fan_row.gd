# fan_row.gd
# Purpose: Container for a row of same-size cards (hand, line, loadout strip). Cards sit side by
#   side with `gap`; when they do not fit they overlap from the right like a fanned hand, but
#   every card keeps an exposed strip of at least min_step px (>= 64 logical px = >= 44 pt), so
#   each stays a tap target and its left edge (cost, Brace shield, rarity stripe) stays readable
#   (art-direction.md §3: "cards overlap but keep a >= 44 pt exposed strip"). Later cards draw
#   on top. MatchScreen sets card_size from the room it has.
#   focus_index (cz11, from the cz10 review: names and right-hand stats were cut in the fan): the
#   selected card opens to its full width; the others close up, never below min_step.
# Dependencies: none.
# Author: UI/UX Agent (cz10)
extends Container

var card_size: Vector2 = Vector2(84, 118):
	set(v):
		card_size = v
		update_minimum_size()
		queue_sort()
var gap: float = 8.0
## Vertical placement when the row is taller than a card: 0 top, 0.5 centre, 1 bottom.
var valign: float = 0.5
## Smallest exposed width of a covered card (logical px).
var min_step: float = 64.0
## Cards this row must be able to hold without dropping below min_step (minimum width).
var capacity: int = 5:
	set(v):
		capacity = v
		update_minimum_size()
## Card shown at full width (the selection), or -1.
var focus_index: int = -1:
	set(v):
		if v != focus_index:
			focus_index = v
			queue_sort()


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
		var y: float = floorf((size.y - card_size.y) * valign)
		var xs: Array[float] = positions(cards.size())
		for i: int in cards.size():
			fit_child_in_rect(cards[i], Rect2(Vector2(xs[i], y), card_size))


## Left edges of n cards: evenly stepped, or with the focus card opened to its full width.
func positions(n: int) -> Array[float]:
	var out: Array[float] = []
	var step: float = step_for(n)
	var full: float = card_size.x + gap
	if focus_index < 0 or focus_index >= n - 1 or step >= card_size.x or n < 2:
		for i: int in n:
			out.append(floorf(i * step))
		return out
	var span: float = size.x - card_size.x
	var open: float = full
	var other: float = 0.0
	if n > 2:
		open = minf(full, span - (n - 2) * min_step)
		open = maxf(open, step)
		other = minf(full, (span - open) / float(n - 2))
	else:
		open = minf(full, span)
	var x: float = 0.0
	for i: int in n:
		out.append(floorf(x))
		x += open if i == focus_index else other
	return out
