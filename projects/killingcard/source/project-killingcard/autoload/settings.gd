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
## Master volume, linear 0.0 - 1.0 (kc-juice: applied to the Master bus by scripts/fx/sfx_bank.gd).
var master_volume: float = 0.8
## kc-juice: sound effects volume, linear 0.0 - 1.0 (the SFX bus).
var sfx_volume: float = 0.8
## kc-juice: Settings "Screen shake" (default on). Off, or reduced_motion on: no shake at all.
var screen_shake: bool = true
## kc-juice: the player set REDUCE MOTION themselves (then it is saved; else it follows the browser).
var motion_chosen: bool = false
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
## kc-trait-ui (head): the Codex is a collection viewer. Art id (String) -> true for every art a
## copy in one of your runs has worn (the starter, Supply Drops, training, Re-issue). Default arts
## count as found. The Codex marks them FOUND.
var found_arts: Dictionary = {}
## kc-onboard §5 (progressive reveal, RevealFlags): systems the player has met (flag String -> true)
## and the "New: X" explainers they have dismissed. Per profile, never per run; "Reset tips" clears both.
var met_flags: Dictionary = {}
var seen_flags: Dictionary = {}
## kc-ui4: the Operator (primary weapon id) picked on the starter screen; "" = the run's default.
## New runs and the quick match start with it.
var operator_primary: String = ""
## kc-cards-impl: Settings > Cards > "Always show all card info": board cards always show their cost,
## level and weapon (else only on hover / hold). Mirrored into BannerView.show_all.
var show_all_card_info: bool = false:
	set(value):
		show_all_card_info = value
		BannerView.show_all = value
		if is_inside_tree():
			BannerView.refresh_all(get_tree())

const SAVE_PATH: String = "user://settings.cfg"
const SECTION: String = "options"
## Options kept between sessions (kc-ui3: the head asked for mirror and SPEED x2).
const PERSISTED_KEYS: Array[StringName] = [&"mirror_layout", &"speed_x2", &"speed_chosen", &"fast_animations",
		&"equipped_arts", &"operator_primary", &"found_arts", &"met_flags", &"seen_flags",
		&"show_all_card_info", &"master_volume", &"sfx_volume", &"screen_shake", &"reduced_motion", &"motion_chosen"]
## Save on set_value() (true once the startup load ran; off in headless tests).
var persist: bool = false


func _ready() -> void:
	reduced_motion = _system_prefers_reduced_motion()
	# kc-juice: the sound effects bank (/root/Settings/Sfx), in every scene and in the tests.
	var bank: Node = (load("res://scripts/fx/sfx_bank.gd") as GDScript).new()
	bank.name = "Sfx"
	add_child(bank)
	# Headless runs (tests, exports) have no real screen; tests check ScreenProfile directly.
	if DisplayServer.get_name() == "headless":
		return
	load_from(SAVE_PATH)
	if not motion_chosen:
		reduced_motion = _system_prefers_reduced_motion()
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


## kc-trait-ui: marks `arts` (art ids) found (saved when one is new). True if any was new.
func mark_found(arts: Array) -> bool:
	var d: Dictionary = found_arts.duplicate()
	var added: bool = false
	for a: Variant in arts:
		var k: String = String(a)
		if k != "" and not d.has(k):
			d[k] = true
			added = true
	if added:
		set_value(&"found_arts", d)
	return added


## kc-onboard §5: records systems the player meets (RevealFlags ids). Returns the newly met ones
## (saved when there is one).
func meet(flags: Array) -> Array[StringName]:
	var d: Dictionary = met_flags.duplicate()
	var added: Array[StringName] = []
	for f: Variant in flags:
		var k: String = String(f)
		if k != "" and not d.has(k):
			d[k] = true
			added.append(StringName(k))
	if not added.is_empty():
		set_value(&"met_flags", d)
	return added


func has_met(flag: StringName) -> bool:
	return met_flags.has(String(flag))


## kc-onboard §5: the player dismissed the "New:" card of `flag` ("Got it").
func mark_seen(flag: StringName) -> void:
	if not seen_flags.has(String(flag)):
		var d: Dictionary = seen_flags.duplicate()
		d[String(flag)] = true
		set_value(&"seen_flags", d)


func is_seen(flag: StringName) -> bool:
	return seen_flags.has(String(flag))


## kc-onboard §5.1: "Reset tips" in Settings: every system hidden again, every explainer shown again.
func reset_tips() -> void:
	met_flags = {}
	set_value(&"seen_flags", {})
	set_value(&"met_flags", {})


## True when `art_id` has been found in a run (or is a chassis' default art: `default_art`).
func is_found(art_id: StringName, default_art: StringName = &"") -> bool:
	return art_id == default_art or found_arts.has(String(art_id))


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
