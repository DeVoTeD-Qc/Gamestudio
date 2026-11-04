# fx_bench.gd
# Adapted from CallingCard scripts/fx/fx_bench.gd (cc15).
# Purpose: Frame-time benchmark for the match screen with every cz17 beat live
#   (scenes/fx/FxBench.tscn). Plays Veteran-vs-Veteran matches on the real Match.tscn at the phone's
#   logical size (iPhone 844x390 pt @3x + notch = 1168x540 logical px, as the layout tests), Normal
#   Event speed (0.45 s / 0.35 s), the human seat driven by a CzAI through controller.request() with
#   0.3 s between its actions, vsync off, and prints:
#     FXBENCH idle ...         static screen, nothing animating (reference)
#     FXBENCH cpu_ms ...       CPU per frame (scripts + tweens + the renderer's CPU side), GPU ms
#     FXBENCH window=... seconds=.. frames=N avg_fps=.. p1_low_fps=.. worst_ms=.. beats={kind: n}
#     FXBENCH beat_ms ...      frame time while a beat runs vs while none runs
#   Run (Compatibility renderer, as the web build):
#     xvfb-run -a -s "-screen 0 1400x800x24" godot --path . --rendering-driver opengl3 \
#         res://scenes/fx/FxBench.tscn -- [--no-fx] [--reduced] [--seconds=60] [--seed=7]
#   --no-fx: the same matches with the FX layer off (baseline). --reduced: reduced motion on.
#   On this cloud machine the GPU is llvmpipe (software): the numbers are a CPU-bound worst case,
#   not an iPhone measurement.
# Dependencies: scenes/match/Match.tscn, CzMatchFx, CzAI, screen_profile.gd.
# Author: Game Feel Engineer Agent (cz17)
extends Node

const MATCH_SCENE: String = "res://scenes/match/Match.tscn"
const ScreenProfile: GDScript = preload("res://scripts/ui/screen_profile.gd")
const PHONE_PT: Vector2 = Vector2(844, 390)
const RATIO: float = 3.0
const INSETS: Rect2 = Rect2(47, 0, 47, 21)
const HUMAN_THINK_S: float = 0.3

var _frames: PackedFloat32Array = PackedFloat32Array()
var _cpu: PackedFloat32Array = PackedFloat32Array()
var _gpu: PackedFloat32Array = PackedFloat32Array()
var _beat_frames: PackedFloat32Array = PackedFloat32Array()
var _quiet_frames: PackedFloat32Array = PackedFloat32Array()
var _beats: Dictionary = {}
var _seconds: float = 60.0
var _seed: int = 7
var _no_fx: bool = false
var _logical: Vector2 = Vector2(1168, 540)
var _k: float = 0.7222


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--no-fx":
			_no_fx = true
		elif a == "--reduced":
			get_node(^"/root/Settings").set(&"reduced_motion", true)
		elif a.begins_with("--seconds="):
			_seconds = float(a.trim_prefix("--seconds="))
		elif a.begins_with("--seed="):
			_seed = int(a.trim_prefix("--seed="))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var px: Vector2 = PHONE_PT * RATIO
	_logical = ScreenProfile.logical_size(px, ScreenProfile.base_size(px, RATIO))
	_k = ScreenProfile.points_per_px(px, RATIO)
	var win: Window = get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.size = Vector2i(_logical)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_run.call_deferred()


func _spawn() -> Control:
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	m.set(&"auto_start", false)
	m.set(&"points_per_px_override", _k)
	m.set(&"safe_area_override", Rect2(INSETS.position / _k, _logical - INSETS.position / _k - INSETS.size / _k))
	var ctrl: Node = m.get_node("%MatchController")
	ctrl.set(&"save_enabled", false)
	ctrl.set(&"event_delay", 0.45)
	ctrl.set(&"opponent_delay", 0.35)
	ctrl.set(&"opponent", CzAI.for_level(&"veteran", _seed))
	add_child(m)
	return m


func _run() -> void:
	await _idle()
	var t0: int = Time.get_ticks_msec()
	var matches: int = 0
	while (Time.get_ticks_msec() - t0) / 1000.0 < _seconds:
		matches += 1
		await _match(_seed + matches, t0)
	var sorted: PackedFloat32Array = _frames.duplicate()
	sorted.sort()
	var total: float = 0.0
	for d: float in _frames:
		total += d
	var n: int = maxi(_frames.size(), 1)
	var p99: float = sorted[clampi(int(n * 0.99), 0, n - 1)] if not sorted.is_empty() else 0.0
	print("FXBENCH cpu_ms avg=%.2f p99=%.2f max=%.2f  gpu_ms avg=%.2f p99=%.2f (renderer: %s)" % [
			_avg(_cpu), _pct(_cpu, 0.99), _pct(_cpu, 1.0), _avg(_gpu), _pct(_gpu, 0.99), RenderingServer.get_video_adapter_name()])
	print("FXBENCH window=%s fx=%s reduced=%s seconds=%.1f matches=%d frames=%d avg_fps=%.1f p1_low_fps=%.1f worst_ms=%.1f beats=%s" % [
			DisplayServer.window_get_size(), not _no_fx, get_node(^"/root/Settings").get(&"reduced_motion"),
			(Time.get_ticks_msec() - t0) / 1000.0, matches, _frames.size(), n / maxf(total, 0.001),
			1.0 / maxf(p99, 0.0001), (sorted[-1] if not sorted.is_empty() else 0.0) * 1000.0, _beats])
	print("FXBENCH beat_ms avg=%.2f p99=%.2f (n=%d)  quiet_ms avg=%.2f p99=%.2f (n=%d)" % [
			_avg(_beat_frames) * 1000.0, _pct(_beat_frames, 0.99) * 1000.0, _beat_frames.size(),
			_avg(_quiet_frames) * 1000.0, _pct(_quiet_frames, 0.99) * 1000.0, _quiet_frames.size()])
	get_tree().quit()


## Static reference: a fresh match at the drop, nothing animating, for 3 s.
func _idle() -> void:
	var m: Control = _spawn()
	m.call(&"start_live")
	for i: int in 10:
		await get_tree().process_frame
	var t0: int = Time.get_ticks_usec()
	var n: int = 0
	while Time.get_ticks_usec() - t0 < 3000000:
		await get_tree().process_frame
		n += 1
	print("FXBENCH idle match screen (no animation): %.1f fps" % (n / ((Time.get_ticks_usec() - t0) / 1000000.0)))
	m.queue_free()
	await get_tree().process_frame


func _match(seed_value: int, t0: int) -> void:
	var m: Control = _spawn()
	var ctrl: Node = m.get_node("%MatchController")
	var fx: CzMatchFx = m.get_node("%FX") as CzMatchFx
	fx.enabled = not _no_fx
	fx.effect_started.connect(func(kind: StringName, _i: Dictionary, _s: float) -> void:
		_beats[kind] = int(_beats.get(kind, 0)) + 1)
	var me: CzAI = CzAI.for_level(&"veteran", seed_value * 31 + 1)
	m.call(&"start_live")
	var last: int = Time.get_ticks_usec()
	var next_act: int = Time.get_ticks_msec() + int(HUMAN_THINK_S * 1000.0)
	while ctrl.get(&"phase") != &"over" and (Time.get_ticks_msec() - t0) / 1000.0 < _seconds:
		if bool(ctrl.call(&"is_human_turn")) and Time.get_ticks_msec() >= next_act:
			var a: Dictionary = me.choose_action(ctrl.get(&"state"), int(ctrl.get(&"human")))
			if not a.is_empty():
				ctrl.call(&"request", a)
			next_act = Time.get_ticks_msec() + int(HUMAN_THINK_S * 1000.0)
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		var dt: float = (now - last) / 1000000.0
		last = now
		_frames.append(dt)
		(_beat_frames if fx.is_busy() else _quiet_frames).append(dt)
		var rid: RID = get_viewport().get_viewport_rid()
		_cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
				+ RenderingServer.viewport_get_measured_render_time_cpu(rid))
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	m.queue_free()
	await get_tree().process_frame


static func _avg(a: PackedFloat32Array) -> float:
	var t: float = 0.0
	for v: float in a:
		t += v
	return t / maxf(a.size(), 1)


static func _pct(a: PackedFloat32Array, q: float) -> float:
	if a.is_empty():
		return 0.0
	var s: PackedFloat32Array = a.duplicate()
	s.sort()
	return s[clampi(int((s.size() - 1) * q), 0, s.size() - 1)]
