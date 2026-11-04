# dossier_rewards.gd
# Purpose: Pays a cleared Dossier's cosmetic reward (spec §5.2) and words it for the result panel.
#   Payout goes to the Collection autoload's Dossier-completion API (cc09:
#   Collection.complete_dossier(id, attempts, duration_s)), which grants on the first clear only.
#   If no Collection with that API is reachable, EventBus.dossier_completed(id) is emitted instead.
#   The Dossier screen also pays at most once per visit, so a replayed clear never asks twice.
# Dependencies: DossierData, CardData, Collection autoload (optional), EventBus.
# Author: Mechanics Developer Agent (cc12)
class_name DossierRewards
extends RefCounted

const VIA_COLLECTION: StringName = &"collection"
const VIA_EVENT_BUS: StringName = &"event_bus"


## Pays the reward for `d`. collection: a Collection node (null = /root/Collection).
## Returns VIA_COLLECTION or VIA_EVENT_BUS (how it was paid).
static func pay(d: DossierData, attempts: int, duration_s: float, collection: Node = null) -> StringName:
	var col: Node = collection if collection != null else _autoload(&"Collection")
	if col != null and col.has_method(&"complete_dossier"):
		col.call(&"complete_dossier", d.id, attempts, duration_s)
		return VIA_COLLECTION
	var bus: Node = _autoload(&"EventBus")
	if bus != null:
		bus.emit_signal(&"dossier_completed", d.id)
	return VIA_EVENT_BUS


## What the first clear grants, read before paying (owned cards fall back to the title, as
## Collection.record_dossier_clear does). Already cleared -> "" (nothing new).
static func reward_lines(d: DossierData, collection: Node = null) -> PackedStringArray:
	var col: Node = collection if collection != null else _autoload(&"Collection")
	var out: PackedStringArray = []
	if col != null and col.has_method(&"is_dossier_cleared") and col.call(&"is_dossier_cleared", d.id):
		return out
	var owned: bool = d.reward_card != null and col != null and col.has_method(&"owns") and col.call(&"owns", d.reward_card.id)
	if d.reward_card != null and not owned:
		out.append("Card: %s" % d.reward_card.display_name)
	elif not d.reward_title.strip_edges().is_empty():
		out.append("Title: %s" % d.reward_title)
	if d.reward_frame != &"":
		out.append("Frame: %s" % String(d.reward_frame).replace("_", " ").capitalize())
	return out


static func _autoload(name: StringName) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(NodePath(String(name)))
	return null
