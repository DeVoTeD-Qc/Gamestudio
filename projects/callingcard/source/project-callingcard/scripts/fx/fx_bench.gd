# fx_bench.gd
# Purpose: Frame-time benchmark for the duel with every cc15 effect live (scenes/fx/FxBench.tscn).
#   Plays scripted duels on Duel.tscn with the real pacing (event_delay 0.22 s, rival_delay 0.7 s),
#   tapping the first hand card into the first valid slot, vsync off, and prints one line per run:
#     FXBENCH window=844x390 duels=2 frames=N avg_fps=.. p1_low_fps=.. worst_ms=.. effects=[..]
#   Run (Compatibility renderer, as the web build):
#     xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 844x390 res://scenes/fx/FxBench.tscn
#   Add `-- --no-fx` for the same duels without the FX layer (baseline).
#   Seeds 2024 / 4321 include a Set Link, an Ambush spring, a "Carded!" and a Triptych.
# Dependencies: scenes/Duel.tscn, DuelFx.
# Author: Game Feel Engineer Agent (cc15)
extends Node

const DUEL_SCENE: String = "res://scenes/Duel.tscn"
const SEEDS: Array[int] = [2024, 4321]

var _frames: PackedFloat32Array = PackedFloat32Array()
## CPU cost per frame (ms): scripts + tweens + physics (Performance) + the renderer's CPU side.
var _cpu: PackedFloat32Array = PackedFloat32Array()
var _gpu: PackedFloat32Array = PackedFloat32Array()
var _effects: Dictionary = {}


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_run.call_deferred()


func _run() -> void:
	await _idle()
	var t0: int = Time.get_ticks_msec()
	for s: int in SEEDS:
		await _duel(s)
	var sorted: PackedFloat32Array = _frames.duplicate()
	sorted.sort()
	var total: float = 0.0
	for d: float in _frames:
		total += d
	var n: int = maxi(_frames.size(), 1)
	var p99: float = sorted[clampi(int(n * 0.99), 0, n - 1)] if not sorted.is_empty() else 0.0
	print("FXBENCH cpu_ms avg=%.2f p99=%.2f max=%.2f  gpu_ms avg=%.2f p99=%.2f (llvmpipe = software GPU)" % [
			_avg(_cpu), _pct(_cpu, 0.99), _pct(_cpu, 1.0), _avg(_gpu), _pct(_gpu, 0.99)])
	print("FXBENCH window=%s duels=%d time=%.1fs frames=%d avg_fps=%.1f p1_low_fps=%.1f worst_ms=%.1f effects=%s" % [
			DisplayServer.window_get_size(), SEEDS.size(), (Time.get_ticks_msec() - t0) / 1000.0, _frames.size(),
			n / maxf(total, 0.001), 1.0 / maxf(p99, 0.0001), (sorted[-1] if not sorted.is_empty() else 0.0) * 1000.0,
			_effects.keys()])
	get_tree().quit()


## Static reference: the cc07 mock mid-duel wall, nothing animating, for 3 s.
func _idle() -> void:
	var script: GDScript = load("res://scripts/duel/duel_controller.gd")
	script.set_autostart(false)
	var duel: Control = (load(DUEL_SCENE) as PackedScene).instantiate()
	add_child(duel)
	script.set_autostart(true)
	duel.show_state(load("res://scripts/ui/mock_duel_data.gd").mid_state())
	for i: int in 10:
		await get_tree().process_frame
	var t0: int = Time.get_ticks_usec()
	var n: int = 0
	while Time.get_ticks_usec() - t0 < 3000000:
		await get_tree().process_frame
		n += 1
	print("FXBENCH idle mid-duel wall (no animation): %.1f fps" % (n / ((Time.get_ticks_usec() - t0) / 1000000.0)))
	duel.queue_free()
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


func _duel(seed_value: int) -> void:
	var duel: Control = (load(DUEL_SCENE) as PackedScene).instantiate()
	var ctrl: Node = duel.get_node("%DuelController")
	ctrl.seed_value = seed_value
	var no_fx: bool = OS.get_cmdline_user_args().has("--no-fx")
	if no_fx:  # baseline: the same duel without the feedback layer
		var f: Node = duel.get_node("%FX")
		duel.remove_child(f)
		f.free()
	add_child(duel)
	if not no_fx:
		var fx: Node = duel.get_node("%FX")
		fx.effect_started.connect(func(kind: StringName, _s: StringName, _d: float) -> void: _effects[kind] = true)
	for i: int in 3:
		await get_tree().process_frame
	duel.get_overlay().get_button(&"start").pressed.emit()
	await get_tree().process_frame
	duel.get_overlay().get_button(&"begin").pressed.emit()
	var guard: int = Time.get_ticks_msec()
	var last: int = Time.get_ticks_usec()
	while duel.get_overlay().kind() != &"end" and Time.get_ticks_msec() - guard < 90000:
		if ctrl.phase == &"player":
			var c: CardData = ctrl.state.hands[0][0]
			for b: Node in duel.get_hand().get_card_buttons():
				if b.get_meta(&"card_id") == c.id:
					b.pressed.emit()
			for s: Node in duel.get_wall().get_slots():
				if s.target_state == &"valid":
					s.pressed.emit()
					break
			if not duel.pick_targets.is_empty():
				duel.get_wall().get_slot(duel.pick_targets[0]).pressed.emit()
			duel.get_node("%PlaceButton").pressed.emit()
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		_frames.append((now - last) / 1000000.0)
		last = now
		var rid: RID = get_viewport().get_viewport_rid()
		_cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
				+ RenderingServer.viewport_get_measured_render_time_cpu(rid))
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
	duel.queue_free()
	await get_tree().process_frame
