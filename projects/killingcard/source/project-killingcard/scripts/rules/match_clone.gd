# match_clone.gd
# Purpose: Deep copy of a MatchState for look-ahead (the p12 outcome preview, tests, a future
#   AI that wants the real resolver). The copy can be resolved, mutated and thrown away without
#   touching the live match: RulesSide / RulesUnit objects, every Array / Dictionary (plays,
#   lines, equipment, mods, ctx dictionaries of registered effects) and the seeded RNG (same
#   seed and position) are copied; unit references inside ctx dictionaries are remapped to the
#   copies. Immutable data is shared: CardData / EffectData / LoadoutItem / MapData resources,
#   RunConfig, SideSetup and RulesCard (a uid + CardData pair the engine never changes).
#   MatchHooks is shared too. Reveal and Firefight only call hooks that read the state or write
#   to the state they are given (initiative, on_elimination, on_item_resolved); do not run
#   score() on a copy that shares ModeRules (score_round / check_match_end store outcome data
#   on the hooks). OutcomeForecast stops after the Firefight for that reason.
#   Copying is generic over each class's script variables, so fields added later are copied too.
# Usage:
#   var sim: MatchState = MatchClone.copy(state)
#   sim.reveal(); sim.firefight()      # the live `state` is unchanged
# Dependencies: MatchState, RulesSide, RulesUnit.
# Author: UI/UX Agent (p12)
class_name MatchClone
extends RefCounted


## A fully independent copy of `state` (null in, null out).
static func copy(state: MatchState) -> MatchState:
	if state == null:
		return null
	var memo: Dictionary = {}
	var out: MatchState = MatchState.new(state.config, null, null, null, state.seed_value, state.hooks)
	memo[state.get_instance_id()] = out
	_copy_vars(state, out, memo)
	return out


## Copies every script variable of `src` into `dst` (deep, see _copy_value).
static func _copy_vars(src: Object, dst: Object, memo: Dictionary) -> void:
	for p: Dictionary in src.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var key: StringName = p["name"]
		dst.set(key, _copy_value(src.get(key), memo))


static func _copy_value(v: Variant, memo: Dictionary) -> Variant:
	match typeof(v):
		TYPE_ARRAY:
			var a: Array = (v as Array).duplicate(false)  # keeps the typed-array type
			for i: int in a.size():
				a[i] = _copy_value(a[i], memo)
			return a
		TYPE_DICTIONARY:
			var d: Dictionary = (v as Dictionary).duplicate(false)
			for k: Variant in d.keys():
				d[k] = _copy_value(d[k], memo)
			return d
		TYPE_OBJECT:
			return _copy_object(v, memo)
	return v  # value types (ints, strings, packed arrays, vectors...)


static func _copy_object(o: Object, memo: Dictionary) -> Object:
	if o == null:
		return null
	var id: int = o.get_instance_id()
	if memo.has(id):
		return memo[id]
	if o is RulesUnit:
		var u: RulesUnit = RulesUnit.new()
		memo[id] = u
		_copy_vars(o, u, memo)
		return u
	if o is RulesSide:
		var s: RulesSide = RulesSide.new()
		memo[id] = s
		_copy_vars(o, s, memo)
		return s
	if o is RandomNumberGenerator:
		var src: RandomNumberGenerator = o
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = src.seed  # setting the seed resets the position, so the state goes second
		rng.state = src.state
		memo[id] = rng
		return rng
	if o is MatchState:
		push_warning("MatchClone: nested MatchState reference is shared, not copied")
	return o  # immutable data and shared services (see header)
