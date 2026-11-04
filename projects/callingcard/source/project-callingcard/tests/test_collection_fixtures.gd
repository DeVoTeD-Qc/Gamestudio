# test_collection_fixtures.gd
# Purpose: Shared helpers for the cc09 Collection tests (no test methods, so the runner skips it).
#   Each test drives its own Collection instance with its own save file under
#   user://test_collection/ and mutes the Collection autoload meanwhile, so the real save
#   (user://collection.json) is never touched by tests. Call finish() at the end of every test.
# Author: Mechanics Developer Agent
extends RefCounted

const COLLECTION_SCRIPT: GDScript = preload("res://autoload/collection.gd")
const DIR: String = "user://test_collection"

var tree: SceneTree
var instances: Array[Node] = []
## Every EventBus emission the helpers recorded: [signal name, args...].
var events: Array = []
var _autoload_was_listening: bool = true
var _recording: Array[Dictionary] = []


func _init(p_tree: SceneTree) -> void:
	tree = p_tree
	DirAccess.make_dir_recursive_absolute(DIR)
	var auto: Node = tree.root.get_node("Collection")
	_autoload_was_listening = auto.listening
	auto.listening = false
	var bus: Node = bus()
	for sig: String in ["card_unlocked", "unlocked", "title_earned", "frame_earned", "set_completed",
			"unlock_progress", "unlock_goal_completed", "triptych_revealed", "cipher_attempted",
			"cipher_solved", "lobby_duel_saved", "lineup_saved", "collection_reset"]:
		var cb: Callable = _recorder(sig)
		bus.connect(sig, cb)
		_recording.append({"sig": sig, "cb": cb})


func _recorder(sig: String) -> Callable:
	return func(a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null) -> void:
		var e: Array = [sig]
		for v: Variant in [a, b, c, d]:
			if v != null:
				e.append(v)
		events.append(e)


func bus() -> Node:
	return tree.root.get_node("EventBus")


func db() -> Node:
	return tree.root.get_node("CardDB")


static func path_for(name: String) -> String:
	return DIR.path_join(name + ".json")


## A Collection instance on its own save file. fresh: delete the file first.
func make(name: String, fresh: bool = true) -> Node:
	var path: String = path_for(name)
	if fresh:
		for p: String in [path, path + ".tmp", "%s.corrupt.json" % path.get_basename()]:
			SaveFile.remove(p)
	var c: Node = COLLECTION_SCRIPT.new()
	c.save_path = path
	c.name = "TestCollection_%s" % name
	tree.root.add_child(c)  # _ready: connects EventBus and loads the save
	instances.append(c)
	return c


## Removes an instance (the "browser reload": a new instance then reads the file again).
func drop(c: Node) -> void:
	instances.erase(c)
	tree.root.remove_child(c)
	c.free()


func finish() -> void:
	for c: Node in instances.duplicate():
		drop(c)
	for r: Dictionary in _recording:
		if bus().is_connected(r["sig"], r["cb"]):
			bus().disconnect(r["sig"], r["cb"])
	tree.root.get_node("Collection").listening = _autoload_was_listening


func events_named(sig: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == sig)


func unlocked_cards() -> Array:
	return events_named("card_unlocked").map(func(e: Array) -> StringName: return e[1])

# --- Driving duels through EventBus (as the duel controller will) --------------------------

func ids(cards: Array) -> Array:
	return cards.map(func(c: CardData) -> StringName: return c.id)


## Lineup ids of the loaner lineup (no Legend).
func loaner_ids() -> Array:
	return ids(db().get_balance().loaner_lineup)


func start_duel(source: StringName, rival_id: StringName, lineup: Array, signature: StringName = &"") -> void:
	bus().duel_started.emit(source, rival_id, &"player")
	if not lineup.is_empty():
		bus().duel_lineup_locked.emit(lineup, signature if signature != &"" else lineup[0], false)


func end_duel(result: StringName) -> void:
	bus().duel_ended.emit(result, 6, 5, 10, 120.0)


## One whole duel: start, optional captures, end.
func play(result: StringName, rival_id: StringName = &"archivist", lineup: Array = [], captures: int = 0,
		source: StringName = &"rival") -> void:
	start_duel(source, rival_id, lineup if not lineup.is_empty() else loaner_ids())
	for i: int in captures:
		bus().card_captured.emit(&"player", &"mayday", &"b2")
	end_duel(result)


## A legal 5-card lineup holding a Legend (needs City Never Sleeps owned): CNS 4 + four Issue / Merit cards.
func legend_lineup_ids() -> Array:
	return [&"city_never_sleeps", &"graveyard_shift", &"frostbite", &"flare_up", &"service_ribbon"]
