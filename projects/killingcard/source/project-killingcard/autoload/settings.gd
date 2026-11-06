# settings.gd
# Purpose: Settings autoload. Player options (fast animations, UI scale, sound).
#   kc-ui3: the options in PERSISTED_KEYS (mirror layout, SPEED x2, fast animations) are saved to
#   user://settings.cfg on every set_value() and loaded at startup (not in headless runs, so the
#   tests never read a player's file; tests call load_from() / save_to() with their own path).
#   Also owns the screen profile: at startup and on every window resize it sets the root's
#   canvas base size from the real screen (scripts/ui/screen_profile.gd, f01) so phones get
#   readable text and >= 44 pt tap targets. ui_scale feeds into that rule.
# Dependencies: scripts/ui/screen_profile.gd.
# Author: Mechanics Developer Agent (screen profile: UI/UX Agent, f01)
extends Node

const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")

signal settings_changed

## Shorten non-essential animations (killfeed, call-in takeover).
var fast_animations: bool = false
## No screen shake, hit-stop or travelling effects (scripts/fx/fx_timing.gd, p14). On the web it
## starts from the browser's prefers-reduced-motion setting.
var reduced_motion: bool = false
## Extra UI scale (0.8 - 1.5): raises the minimum on-screen size of one logical px.
var ui_scale: float = 1.0
## Master volume, linear 0.0 - 1.0.
var master_volume: float = 0.8
## Show the firefight outcome preview by default.
var show_outcome_preview: bool = true
## kc-board2: mirror the match layout (hand tray on the left, icon strip on the right) for
## left-handed players. The board itself is symmetric.
var mirror_layout: bool = false
## kc-ui3: the tray's SPEED x2 toggle (the round's feedback at double speed), kept between sessions.
var speed_x2: bool = false
## kc-fight-ui: the player picked a speed with the SPEED toggle. Until then the firefight plays at the
## resolver's default (x1 for the first runs, x2 once the tutorial is done; match_screen.gd).
var speed_chosen: bool = false
## kc-ui4 (head: "select them to see alternate art and equip the alternate art I want"): chassis id
## (String) -> equipped art id (String), set in the Codex. Every copy of that card you play wears
## it; a card with no entry keeps the per-copy variety.
var equipped_arts: Dictionary = {}
## kc-ui4: the Operator (primary weapon id) picked on the starter screen; "" = the run's default.
## New runs and the quick match start with it.
var operator_primary: String = ""

const SAVE_PATH: String = "user://settings.cfg"
const SECTION: String = "options"
## Options kept between sessions (kc-ui3: the head asked for mirror and SPEED x2).
const PERSISTED_KEYS: Array[StringName] = [&"mirror_layout", &"speed_x2", &"speed_chosen", &"fast_animations",
		&"equipped_arts", &"operator_primary"]
## Save on set_value() (true once the startup load ran; off in headless tests).
var persist: bool = false


func _ready() -> void:
	reduced_motion = _system_prefers_reduced_motion()
	# Headless runs (tests, exports) have no real screen; tests check ScreenProfile directly.
	if DisplayServer.get_name() == "headless":
		return
	load_from(SAVE_PATH)
	persist = true
	var root: Window = get_tree().root
	# kc-board: browser smoke tests (?qa=1) read window.kcQa (scripts/qa/qa_bridge.gd).
	var qa: GDScript = load("res://scripts/qa/qa_bridge.gd") as GDScript
	if qa != null and qa.call(&"enabled"):
		var bridge: Node = qa.new()
		bridge.name = "QaBridge"
		add_child(bridge)
	root.size_changed.connect(_apply_screen_profile)
	settings_changed.connect(_apply_screen_profile)
	_apply_screen_profile()
	var base: Vector2 = Vector2(root.content_scale_size)
	print("Screen profile: window %s px, screen scale %.2f, base %s, %.3f pt per px" % [
			DisplayServer.window_get_size(), ScreenProfile.screen_scale(), base,
			ScreenProfile.points_per_px(Vector2(DisplayServer.window_get_size()), ScreenProfile.screen_scale(), ui_scale)])


## Browser prefers-reduced-motion (web builds only; false elsewhere).
func _system_prefers_reduced_motion() -> bool:
	if not OS.has_feature("web"):
		return false
	var matches: Variant = JavaScriptBridge.eval(
			"window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches", true)
	return matches == true


func _apply_screen_profile() -> void:
	ScreenProfile.apply(get_tree().root, ui_scale)


## Applies a setting by name and notifies listeners.
func set_value(key: StringName, value: Variant) -> void:
	if not key in self:
		push_error("Settings: unknown key %s" % key)
		return
	set(key, value)
	if persist and PERSISTED_KEYS.has(key):
		save_to(SAVE_PATH)
	settings_changed.emit()


## kc-ui4: equips `art_id` on every copy of `chassis` (&"" or the chassis' default art clears it:
## the card goes back to the per-copy variety). Saved like any persisted option.
func equip_art(chassis: StringName, art_id: StringName) -> void:
	var d: Dictionary = equipped_arts.duplicate()
	if art_id == &"":
		d.erase(String(chassis))
	else:
		d[String(chassis)] = String(art_id)
	set_value(&"equipped_arts", d)


## The art equipped on `chassis` (&"" = none: per-copy variety).
func equipped_art(chassis: StringName) -> StringName:
	return StringName(String(equipped_arts.get(String(chassis), "")))


## Writes PERSISTED_KEYS to a ConfigFile. Returns the Error code.
func save_to(path: String) -> Error:
	var cfg := ConfigFile.new()
	for key: StringName in PERSISTED_KEYS:
		cfg.set_value(SECTION, String(key), get(key))
	return cfg.save(path)


## Reads PERSISTED_KEYS from a ConfigFile (missing file or keys keep their values). True if read.
func load_from(path: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	for key: StringName in PERSISTED_KEYS:
		var v: Variant = cfg.get_value(SECTION, String(key), get(key))
		if typeof(v) == typeof(get(key)):
			set(key, v)
	return true
