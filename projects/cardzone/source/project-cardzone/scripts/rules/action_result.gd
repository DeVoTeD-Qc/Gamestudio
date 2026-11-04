# action_result.gd
# Purpose: What one action did (or, from LoadoutRules.preview, would do): ok or the reason it was
#   rejected, the normalised action as logged, and the ordered event list the UI, game feel and
#   the playtest log replay. Events may carry a `secret` part only their owner may see
#   (`secret_for`); hand them to a seat through events_for(seat) (fairness, spec P18).
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name ActionResult
extends RefCounted

## false = rejected; `error` names why (LoadoutRules.ERR_*) and the state is unchanged.
var ok: bool = false
var error: StringName = &""
## true for LoadoutRules.preview() (run on a copy; the real state was not changed).
var is_preview: bool = false
## The action as the engine logged it (card refs resolved, e.g. frag's card).
var action: Dictionary = {}
## Ordered events: {type, seat?, ...}. See LoadoutRules (EVENT TYPES in its header).
var events: Array[Dictionary] = []
## The last shot or Frag record after this action (shoot, frag and brace actions), else {}.
var shot: Dictionary = {}


static func rejected(code: StringName, act: Dictionary = {}) -> ActionResult:
	var r: ActionResult = ActionResult.new()
	r.ok = false
	r.error = code
	r.action = act
	return r


## The events as `seat` may see them (secret parts merged for their owner, dropped for others).
func events_for(seat: int) -> Array[Dictionary]:
	return LoadoutRules.events_for(events, seat)


func event_types() -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in events:
		out.append(String(e["type"]))
	return out
