# zone_card_data.gd
# Purpose: One Zone card (spec §8, R39-R44) with its line for each route A / B / C:
#   which area gas closes, where the supply drop lands, or the final-circle step.
#   One card = one .tres in res://data/zone/ (zone_01.tres .. zone_14.tres).
#   A card is Calm (nothing set), Gas (close_* set), Drop (drop_card + drop_*), Gas + Drop,
#   or Final circle (final_circle_step > 0). Route-wide rules (an area closes once, no drop
#   into gas, numbers 1..N without gaps) are CardDB cross checks.
# Dependencies: DataEnums, AreaData, CardData, DataValidator.
# Author: Mechanics Developer Agent
class_name ZoneCardData
extends Resource

const ROUTES: Array[DataEnums.Route] = [DataEnums.Route.A, DataEnums.Route.B, DataEnums.Route.C]

@export_group("Identity")
## Unique id, lowercase snake_case: zone_01 .. zone_14.
@export var id: StringName = &""
## Position in the Zone deck, 1 = flipped in round 1. Unique, no gaps.
@export_range(1, 20) var number: int = 0
## Printed title ("Calm", "Gas closes", "Supply drop", "Final circle I").
@export var display_name: String = ""

@export_group("Gas closes (per route)")
## Area flipped to gas on route A / B / C. Leave all three empty on a card that closes nothing.
@export var close_a: AreaData = null
@export var close_b: AreaData = null
@export var close_c: AreaData = null

@export_group("Supply drop (per route)")
## The supply-drop card (CardData with supply_drop on). Empty on a card that drops nothing.
@export var drop_card: CardData = null
## Area the drop lands in on route A / B / C (after gas closes on the same card, R39).
@export var drop_a: AreaData = null
@export var drop_b: AreaData = null
@export var drop_c: AreaData = null

@export_group("Final circle (R43)")
## 0 = not a final-circle card; 1, 2, 3 = final circle I, II, III (Hits from
## BalanceConfig.final_circle_hits). The same on every route.
@export_range(0, 9) var final_circle_step: int = 0


## Area gas closes on this route, or null.
func close_for(route: DataEnums.Route) -> AreaData:
	return [close_a, close_b, close_c][route] if route >= 0 and route < 3 else null


## Area the drop lands in on this route, or null.
func drop_area_for(route: DataEnums.Route) -> AreaData:
	return [drop_a, drop_b, drop_c][route] if route >= 0 and route < 3 else null


func closes_gas() -> bool:
	return close_a != null or close_b != null or close_c != null


func has_drop() -> bool:
	return drop_card != null


func is_final_circle() -> bool:
	return final_circle_step > 0


func kind() -> DataEnums.ZoneKind:
	if is_final_circle():
		return DataEnums.ZoneKind.FINAL_CIRCLE
	if closes_gas() and has_drop():
		return DataEnums.ZoneKind.GAS_AND_DROP
	if closes_gas():
		return DataEnums.ZoneKind.GAS
	if has_drop():
		return DataEnums.ZoneKind.DROP
	return DataEnums.ZoneKind.CALM


## The printed line for one route, e.g. "close Farmstead · drop Motel" or "–".
func route_text(route: DataEnums.Route) -> String:
	var parts: PackedStringArray = []
	var closed: AreaData = close_for(route)
	var dropped: AreaData = drop_area_for(route)
	if closed != null:
		parts.append("close %s" % closed.display_name)
	if dropped != null:
		parts.append("drop %s" % dropped.display_name)
	return " · ".join(parts) if not parts.is_empty() else "–"


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.check_range("number", number, 1, 20)
	v.require_text("display_name", display_name)
	v.check_line("display_name", display_name, 24)
	v.check_range("final_circle_step", final_circle_step, 0, 9)
	var closes: Array = [close_a, close_b, close_c]
	var drops: Array = [drop_a, drop_b, drop_c]
	if is_final_circle():
		if closes_gas() or has_drop() or drops.any(func(a: AreaData) -> bool: return a != null):
			v.add(DataValidator.ROUTE_RULE, "final_circle_step", "a final-circle card closes nothing and drops nothing")
		return
	# Gas: every route closes an area, or none does.
	var close_count: int = closes.count(null)
	if close_count != 0 and close_count != 3:
		v.add(DataValidator.ROUTE_RULE, "close_" + _first_missing(closes), "gas closes on some routes but not this one; set all three or none")
	for i: int in 3:
		var field: String = "close_" + DataEnums.ROUTE_LETTERS[i].to_lower()
		if closes[i] != null and v.check_ref(field, closes[i], AreaData, true) and (closes[i] as AreaData).is_core():
			v.add(DataValidator.ROUTE_RULE, field, "the Core never closes (it is the final arena)")
	# Drop: a supply-drop card with a landing area on every route, or nothing.
	if drop_card == null:
		for i: int in 3:
			if drops[i] != null:
				v.missing("drop_card", "drop_%s is set but there is no drop_card" % DataEnums.ROUTE_LETTERS[i].to_lower())
				break
	else:
		if v.check_ref("drop_card", drop_card, CardData, true) and not drop_card.supply_drop:
			v.invalid("drop_card", "'%s' is not a supply-drop card (set supply_drop on the card)" % drop_card.id)
		for i: int in 3:
			var field: String = "drop_" + DataEnums.ROUTE_LETTERS[i].to_lower()
			if drops[i] == null:
				v.add(DataValidator.ROUTE_RULE, field, "the drop needs a landing area on every route")
			else:
				v.check_ref(field, drops[i], AreaData, true)


func _first_missing(areas: Array) -> String:
	for i: int in areas.size():
		if areas[i] == null:
			return DataEnums.ROUTE_LETTERS[i].to_lower()
	return "a"
