# reveal_gate.gd
# Purpose: kc-onboard-ui (onboarding-progression.md §5): the UI side of progressive reveal. A system
#   the player hasn't met yet is hidden; "hidden doesn't mean off": it shows while something in play
#   uses it right now (RevealFlags.visible(flag, met, now)). The met set is the profile's
#   (Settings.met_flags, fed by RunState.note_systems). shown() is the one call the screens make.
#   Contexts: run screens and run / tutorial matches reveal step by step (`active`); the quick
#   match, the pitch build's sandbox and tools show everything (the match controller sets `active`
#   per match: a quick match is for players who know the game, and a pitch must show it all).
# Dependencies: RevealFlags, the Settings autoload (met_flags; optional).
# Author: UI/UX Agent (kc-onboard-ui)
class_name RevealGate
extends RefCounted

## True while the screen on show reveals systems step by step (run screens, run matches and the
## tutorial set it; the Title / quick match clear it). False (the default) = show everything.
static var active: bool = false


## The profile's met systems ({} without the Settings autoload).
static func met() -> Dictionary:
	var st: Node = _settings()
	var d: Variant = st.get(&"met_flags") if st != null else null
	return d if typeof(d) == TYPE_DICTIONARY else {}


## True when an element of `flag` shows: reveal off, the system already met, or in use `now`.
static func shown(flag: StringName, now: Array = [], ctx_active: Variant = null) -> bool:
	var on: bool = active if ctx_active == null else bool(ctx_active)
	if not on:
		return true
	return RevealFlags.visible(flag, met(), now)


static func _settings() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null(^"Settings")
	return null
