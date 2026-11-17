# log_flash.gd
# Purpose: kc-feedback-2 (the studio head: "Yes, flash it"): after each round's playback ends, the LOG
#   badge in the icon strip flashes briefly (2 amber pulses over about 1.2 s, no sound) so players learn
#   the round log is there. It never plays during a tip or an overlay: it waits until nothing blocks
#   (blocked() false for SETTLE_S in a row), stops at once if something opens, and gives up after
#   WAIT_MAX_S. It only draws (the badge's `flash` value): input is never blocked.
#   Reduced motion (Settings.reduced_motion): a gentle steady highlight instead of the pulses.
# Usage: var lf := LogFlash.new(); add_child(lf); lf.badge = log_badge
#        lf.request(func() -> bool: return a_tip_or_overlay_is_up)
# Dependencies: strip_badge.gd (the `flash` / `flash_gentle` it draws).
# Author: UI/UX Agent (kc-feedback-2)
extends Node

const PULSES: int = 2
const DURATION_S: float = 1.2
## Unblocked time before the flash starts (lets the Deploy's first tip open first).
const SETTLE_S: float = 0.4
## A request that cannot play within this long is dropped.
const WAIT_MAX_S: float = 20.0
## The reduced-motion highlight's strength (steady, no pulses).
const GENTLE: float = 0.6

enum Phase { IDLE, WAITING, FLASHING }

var badge: Control = null
var phase: Phase = Phase.IDLE
## Flashes that played to the end / were cut by a tip or overlay (tests, QA).
var played: int = 0
var interrupted: int = 0
var _blocked: Callable = Callable()
var _t: float = 0.0
var _clear: float = 0.0


func _ready() -> void:
	name = "LogFlash"
	set_process(false)


## Queues one flash; blocked() says when a tip or overlay is up (the flash waits / stops).
func request(blocked: Callable = Callable()) -> void:
	_stop()
	_blocked = blocked
	phase = Phase.WAITING
	_t = 0.0
	_clear = 0.0
	set_process(true)


## Drops a waiting or running flash (the next round started).
func cancel() -> void:
	_stop()


func is_flashing() -> bool:
	return phase == Phase.FLASHING


## The badge's flash strength at time t (0..DURATION_S) of a flash: PULSES peaks, 0 at both ends.
static func level_at(t: float, gentle: bool) -> float:
	if t <= 0.0 or t >= DURATION_S:
		return 0.0
	if gentle:
		return GENTLE
	var s: float = sin(PI * float(PULSES) * t / DURATION_S)
	return s * s


func _is_blocked() -> bool:
	return _blocked.is_valid() and bool(_blocked.call())


func _process(delta: float) -> void:
	match phase:
		Phase.WAITING:
			_t += delta
			if _is_blocked() or badge == null or not badge.is_visible_in_tree():
				_clear = 0.0
			else:
				_clear += delta
			if _clear >= SETTLE_S:
				phase = Phase.FLASHING
				_t = 0.0
			elif _t >= WAIT_MAX_S:
				_stop()
		Phase.FLASHING:
			if _is_blocked():
				interrupted += 1
				_stop()
				return
			_t += delta
			if _t >= DURATION_S:
				played += 1
				_stop()
				return
			_set_badge(level_at(_t, _reduced_motion()), _reduced_motion())
		_:
			set_process(false)


func _stop() -> void:
	phase = Phase.IDLE
	set_process(false)
	_set_badge(0.0, false)


func _set_badge(v: float, gentle: bool) -> void:
	if badge != null and is_instance_valid(badge) and &"flash" in badge:
		badge.set(&"flash_gentle", gentle)
		badge.set(&"flash", v)


func _reduced_motion() -> bool:
	var s: Node = get_node_or_null(^"/root/Settings")
	return s != null and bool(s.get(&"reduced_motion"))
