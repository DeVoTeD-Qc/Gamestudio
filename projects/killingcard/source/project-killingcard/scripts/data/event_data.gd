# event_data.gd
# Purpose: One run-map Event (run-v2.md §3): a title, two lines of scene and 2-3 options. Each
#   option is {id, label, detail, effect, amount, cost_req, needs, card}: `label` is the button text,
#   `detail` the exact result with odds printed, `effect` the RunEvents effect id that applies it.
#   The options' rules live in scripts/run/run_events.gd (keyed by `effect`); this is the text.
#   One event = one .tres in res://data/events/.
# Dependencies: DataValidator, CardData.
# Author: Mechanics Developer Agent (kc-v2-impl)
class_name EventData
extends Resource

@export var id: StringName = &""
@export var title: String = ""
## Two lines of scene.
@export_multiline var scene: String = ""
## [{id: String, label: String, detail: String, effect: String, amount: int, cost_req: int,
##   needs: String ("" | "deck_card" | "calling_card" | "terrain"), card: String (card id)}]
@export var options: Array[Dictionary] = []
## Only on the fixed first-run map (never drawn into a run-2+ map).
@export var first_run_only: bool = false


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("title", title)
	v.require_text("scene", scene)
	if options.size() < 2 or options.size() > 3:
		v.out_of_range("options", "an event has 2-3 options (got %d)" % options.size())
	for i: int in options.size():
		var o: Dictionary = options[i]
		if String(o.get("label", "")) == "" or String(o.get("detail", "")) == "":
			v.missing("options[%d]" % i, "an option needs a label and its exact result (detail)")
		if String(o.get("effect", "")) not in RunEvents.EFFECTS:
			v.invalid("options[%d].effect" % i, "unknown event effect '%s'" % String(o.get("effect", "")))
