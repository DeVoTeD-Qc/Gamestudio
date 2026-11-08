# dd_feedback.gd
# Purpose: dd-feel. The street's feedback animations and sound cues. main.gd rebuilds the whole
#   screen after every action; just before the action it takes a snapshot (where each street card
#   was, HP, Cover, weapon), and after the rebuild it calls play() with the event and the new
#   views. Feedback then animates from the old picture to the new one:
#     deal      new cards fly from the deck face down (staggered 70 ms) and flip face up
#     holdover  the card that stayed slides from its old slot to its new one
#     close-up  cards that moved because one was resolved slide to their new slot
#     zombie    the card shakes and flashes red; weapon kill: a slash and it shrinks away;
#               bare-handed: it lunges and fades. HP panel flashes red, HP number ticks down,
#               screen shake scaled by the damage. Cover soak: gold shield flash (block cue).
#     notch     a slash mark is carved over the weapon slot and the notch line pops
#     break     (Shatter) the weapon slot wobbles and flashes red
#     equip     the weapon card flies into the weapon slot, which pops
#     scrap     the card drops, tilts and fades
#     medkit    the card flies into the HP panel, green pulse, HP ticks up (no heal: grey fade, warn)
#     barricade the card flies to the HP panel, gold shield outline, the Cover chip pops
#     retreat   (v2 Skip) every street card slides onto the Skipped pile, then a new street is dealt
#     ammo      (v2) the ammo card flies into the reserve counter, which pops
#     finale    a Finale card flips with a purple flash, a low swell and a light shake
#     death     heavy shake and a red screen flash; clear: a bright cue
#   Every animation is <= 300 ms, uses ghosts in the fx layer (or scale / colour on real nodes,
#   which never fight the containers' layout) and never blocks input: tapping mid-animation just
#   rebuilds the screen, which clears the ghosts. Reduce motion: nothing flies, shakes or zooms;
#   cards fade in / out and colour pulses stay.
# Dependencies: DDCardView, DDUi, DDCard, DDRun, scripts/fx/dd_sfx.gd, scripts/ui/dd_art.gd.
# Author: Game Feel Engineer Agent (dd-feel)
extends Node

const Sfx: GDScript = preload("res://scripts/fx/dd_sfx.gd")
const Art: GDScript = preload("res://scripts/ui/dd_art.gd")

const DEAL_STAGGER: float = 0.07
const DEAL_FLY: float = 0.2
const FLIP: float = 0.14
const SLIDE: float = 0.18

## The layer ghosts live in (full-rect Control above the content) and the node that shakes.
var fx: Control
var content: Control
var reduce: bool = false
var shake_on: bool = true
## Names of the animations started by the last play() (tests and QA read it).
var last_played: Array[String] = []
var _shake_tween: Tween = null


func setup(fx_layer: Control, shake_target: Control) -> void:
	fx = fx_layer
	content = shake_target


## Frees every ghost and resets the shake (called on every rebuild).
func clear() -> void:
	if fx != null:
		for c: Node in fx.get_children():
			if c.has_meta(&"ghost"):
				c.queue_free()
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	if content != null:
		content.position = Vector2.ZERO


# ================================================================ entry point
## p: {type: "resolve"|"retreat"|"deal", ev, snap}. ctx: the new views (see main.gd _fx_context()).
func play(p: Dictionary, ctx: Dictionary) -> void:
	last_played.clear()
	var snap: Dictionary = p.get("snap", {})
	var ev: Dictionary = p.get("ev", {})
	var t: String = str(p.get("type", ""))
	var views: Dictionary = ctx.get("street", {})
	var deal_delay: float = 0.0
	if t == "resolve":
		deal_delay = _resolve_fx(ev, snap, ctx)
	elif t == "retreat":
		deal_delay = _retreat_fx(ev, snap, ctx)
	# the street now: cards that were already there slide, new ones are dealt
	var old_rects: Dictionary = snap.get("rects", {})
	var deck_rect: Rect2 = _rect(ctx.get("deck")) if ctx.get("deck") != null else Rect2(snap.get("deck_rect", Rect2()))
	var k: int = 0
	var order: Array = ctx.get("order", [])
	for id: Variant in order:
		var v: DDCardView = views.get(id)
		if v == null or not is_instance_valid(v):
			continue
		var c: DDCard = (ctx.get("cards", {}) as Dictionary).get(id)
		if old_rects.has(id):
			var from: Rect2 = old_rects[id]
			if from.position.distance_to(_rect(v).position) > 2.0:
				var holdover: bool = bool(ev.get("street_ended", false))
				_slide(v, ctx.get("specs", {}).get(id, {}), from, 0.1 if holdover else 0.0, holdover)
		else:
			_deal(v, deck_rect, deal_delay + DEAL_STAGGER * k, c != null and c.is_finale(), ctx)
			k += 1
	if k > 0:
		last_played.append("deal")
	if bool(ev.get("dead", false)):
		_death()
	elif bool(ev.get("district_cleared", false)):
		_after(0.12, func() -> void: Sfx.cue(&"clear"))
		last_played.append("clear")


# ================================================================ resolve
## Returns the delay before a new street may be dealt.
func _resolve_fx(ev: Dictionary, snap: Dictionary, ctx: Dictionary) -> float:
	var c: DDCard = ev.get("card")
	if c == null:
		return 0.0
	var pr: Dictionary = ev.get("preview", {})
	var id: int = c.get_instance_id()
	var from: Rect2 = (snap.get("rects", {}) as Dictionary).get(id, Rect2())
	var spec: Dictionary = (snap.get("specs", {}) as Dictionary).get(id, {})
	var ghost: DDCardView = _ghost(spec, from) if from.size != Vector2.ZERO and not spec.is_empty() else null
	var choice: String = str(ev.get("choice", ""))
	match c.kind:
		DDCard.ZOMBIE:
			_zombie_fx(ghost, choice, pr, snap, ctx)
		DDCard.WEAPON:
			if choice == DDRun.EQUIP1 or choice == DDRun.EQUIP2:
				last_played.append("equip")
				var wv: Control = ctx.get("weapon")
				_fly_into(ghost, wv, func() -> void:
					Sfx.cue(&"equip")
					_pop(wv, 1.15, DDUi.accent("W")))
			else:
				last_played.append("scrap")
				Sfx.cue(&"scrap")
				_drop(ghost)
		DDCard.MEDKIT:
			var hp_panel: Control = ctx.get("hp_panel")
			if int(pr.get("heal", 0)) > 0:
				last_played.append("heal")
				_fly_into(ghost, hp_panel, func() -> void:
					Sfx.cue(&"heal")
					_pulse(hp_panel, Color(0.7, 1.6, 0.8)))
				_tick_hp(ctx, int(snap.get("hp", 0)), 0.08)
			else:
				last_played.append("no_heal")
				Sfx.cue(&"warn")
				_grey_out(ghost)
		DDCard.AMMO:
			# v2: the ammo card flies into the reserve counter, which pops
			last_played.append("ammo")
			var rv: Control = ctx.get("reserve") if ctx.get("reserve") != null else ctx.get("weapon")
			_fly_into(ghost, rv, func() -> void:
				Sfx.cue(&"equip", 1.25)
				_pop(rv, 1.15, DDUi.accent("A")))
		DDCard.BARRICADE:
			last_played.append("cover")
			var target: Control = ctx.get("cover") if ctx.get("cover") != null else ctx.get("hp_panel")
			_fly_into(ghost, target, func() -> void:
				Sfx.cue(&"cover")
				_shield(ctx.get("hp_box"))
				_pop(ctx.get("cover"), 1.35, DDUi.COVER))
	return 0.16 if bool(ev.get("street_ended", false)) else 0.0


func _zombie_fx(ghost: DDCardView, choice: String, pr: Dictionary, snap: Dictionary, ctx: Dictionary) -> void:
	var loss: int = int(pr.get("hp_loss", 0))
	var weapon_used: bool = choice == DDRun.SLOT1 or choice == DDRun.SLOT2
	last_played.append("zombie_weapon" if weapon_used else "zombie_bare")
	if weapon_used:
		Sfx.cue(&"kill", randf_range(0.95, 1.05))
	if loss > 0:
		Sfx.cue(&"hit", clampf(1.15 - loss * 0.03, 0.8, 1.15))
		_pulse(ctx.get("hp_panel"), Color(1.8, 0.55, 0.5))
		_tick_hp(ctx, int(snap.get("hp", 0)), 0.0)
		shake(clampf(4.0 + loss * 0.9, 4.0, 15.0), 0.22)
		last_played.append("hit")
	if int(pr.get("absorbed", 0)) > 0:
		Sfx.cue(&"block")
		_shield(ctx.get("hp_box"))
		last_played.append("block")
	if ghost != null:
		ghost.modulate = Color(1.7, 0.6, 0.55)
		var tw: Tween = ghost.create_tween()
		if not reduce:
			var p0: Vector2 = ghost.position
			for k: int in 4:
				var off: Vector2 = Vector2(7.0 * (1 if k % 2 == 0 else -1), randf_range(-3.0, 3.0))
				tw.tween_property(ghost, "position", p0 + off, 0.035)
			tw.tween_property(ghost, "position", p0, 0.03)
			if weapon_used:
				tw.tween_callback(func() -> void: _slash(ghost.get_global_rect(), DDUi.TEXT, 0.0))
				tw.tween_property(ghost, "scale", Vector2(0.7, 0.7), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(ghost, "modulate:a", 0.0, 0.12)
			else:
				tw.tween_property(ghost, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(ghost, "modulate:a", 0.0, 0.1)
		else:
			tw.tween_property(ghost, "modulate", Color(1.7, 0.6, 0.55, 0.0), 0.18)
		tw.tween_callback(ghost.queue_free)
	if weapon_used:
		var wv: DDCardView = ctx.get("weapon")
		if bool(pr.get("breaks", false)):
			last_played.append("break")
			_after(0.08, func() -> void: Sfx.cue(&"break"))
			_pulse(wv, Color(1.9, 0.5, 0.45))
			_wobble(wv)
		elif wv != null and int(snap.get("notch", 0)) != int(pr.get("notch_after", 0)):
			last_played.append("notch")
			_after(0.12, func() -> void:
				Sfx.cue(&"notch")
				if is_instance_valid(wv):
					_slash(wv.get_global_rect(), DDUi.WARN, 0.0)
					if not wv.line_labels.is_empty():
						_pop(wv.line_labels[0], 1.6, DDUi.WARN))


# ================================================================ retreat
func _retreat_fx(ev: Dictionary, snap: Dictionary, ctx: Dictionary) -> float:
	last_played.append("retreat")
	Sfx.cue(&"retreat")
	var deck: Control = ctx.get("deck")
	var to: Rect2 = _rect(deck) if deck != null else Rect2(snap.get("deck_rect", Rect2()))
	var k: int = 0
	for c: Variant in ev.get("returned", []):
		var id: int = (c as DDCard).get_instance_id()
		var from: Rect2 = (snap.get("rects", {}) as Dictionary).get(id, Rect2())
		var spec: Dictionary = (snap.get("specs", {}) as Dictionary).get(id, {})
		if from.size == Vector2.ZERO or spec.is_empty():
			continue
		var g: DDCardView = _ghost(spec, from)
		var tw: Tween = g.create_tween()
		tw.tween_interval(0.04 * k)
		if reduce:
			tw.tween_property(g, "modulate:a", 0.0, 0.16)
		else:
			var s: float = minf(to.size.x / maxf(1.0, from.size.x), to.size.y / maxf(1.0, from.size.y))
			tw.tween_property(g, "position", to.position + (to.size - from.size * s) * 0.5 - fx.global_position, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(g, "scale", Vector2(s, s), 0.2)
			tw.parallel().tween_property(g, "modulate:a", 0.25, 0.2)
		tw.tween_callback(g.queue_free)
		k += 1
	if deck != null:
		_after(0.2, func() -> void: _pop(deck, 1.12, DDUi.accent("D")))
	return 0.04 * k + 0.2 if not reduce else 0.12


# ================================================================ deal / slide
func _deal(v: DDCardView, deck_rect: Rect2, delay: float, finale: bool, ctx: Dictionary) -> void:
	var to: Rect2 = _rect(v)
	v.modulate.a = 0.0
	if reduce or deck_rect.size == Vector2.ZERO:
		var tw0: Tween = v.create_tween()
		tw0.tween_interval(delay * 0.5)
		tw0.tween_callback(func() -> void: Sfx.cue(&"deal", randf_range(0.95, 1.08)))
		tw0.tween_property(v, "modulate:a", 1.0, 0.12)
		if finale:
			tw0.tween_callback(func() -> void: _finale_reveal(v, ctx))
		return
	var back: Control = _back(to.size)
	var s: float = minf(deck_rect.size.x / maxf(1.0, to.size.x), deck_rect.size.y / maxf(1.0, to.size.y))
	back.scale = Vector2(s, s)
	back.position = deck_rect.position + (deck_rect.size - to.size * s) * 0.5 - fx.global_position
	back.modulate.a = 0.0
	var tw: Tween = back.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		back.modulate.a = 1.0
		Sfx.cue(&"deal", randf_range(0.95, 1.08)))
	tw.tween_property(back, "position", to.position - fx.global_position, DEAL_FLY).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(back, "scale", Vector2.ONE, DEAL_FLY).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# flip: the back narrows to an edge, the face widens from it
	back.pivot_offset = to.size * 0.5
	tw.tween_property(back, "scale:x", 0.0, FLIP * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(v):
			_flip_up(v, finale, ctx))
	tw.tween_callback(back.queue_free)


func _flip_up(v: DDCardView, finale: bool, ctx: Dictionary) -> void:
	Sfx.cue(&"flip", randf_range(0.95, 1.06))
	v.pivot_offset = v.size * 0.5
	v.scale = Vector2(0.0, 1.0)
	v.modulate = Color(1.5, 1.5, 1.5, 1.0)
	var tw: Tween = v.create_tween()
	tw.tween_property(v, "scale:x", 1.0, FLIP * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(v, "modulate", Color.WHITE, FLIP)
	if finale:
		tw.tween_callback(func() -> void: _finale_reveal(v, ctx))


func _finale_reveal(v: DDCardView, ctx: Dictionary) -> void:
	if not last_played.has("finale"):
		last_played.append("finale")
	Sfx.cue(&"finale")
	_pulse(v, Color(1.6, 1.0, 1.9))
	_pop(v, 1.12, DDUi.accent("F"))
	_pulse(ctx.get("finale"), Color(1.6, 1.0, 1.9))
	shake(6.0, 0.2)


func _slide(v: DDCardView, spec: Dictionary, from: Rect2, delay: float, holdover: bool) -> void:
	if not last_played.has("holdover" if holdover else "slide"):
		last_played.append("holdover" if holdover else "slide")
	if reduce or spec.is_empty():
		if holdover:
			_pulse(v, Color(1.4, 1.4, 1.4))
		return
	var to: Rect2 = _rect(v)
	var g: DDCardView = _ghost(spec, from)
	v.modulate.a = 0.0
	var s: Vector2 = Vector2(to.size.x / maxf(1.0, from.size.x), to.size.y / maxf(1.0, from.size.y))
	var tw: Tween = g.create_tween()
	tw.tween_interval(delay)
	if holdover:
		tw.tween_callback(func() -> void: Sfx.cue(&"deal", 0.8))
	tw.tween_property(g, "position", to.position - fx.global_position, SLIDE + (0.06 if holdover else 0.0)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g, "scale", s, SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(v):
			v.modulate.a = 1.0
			if holdover:
				_pop(v, 1.06, DDUi.SELECT))
	tw.tween_callback(g.queue_free)


# ================================================================ end moments
func _death() -> void:
	last_played.append("death")
	Sfx.cue(&"death")
	shake(18.0, 0.3)
	screen_flash(Color(DDUi.BAD, 0.45), 0.3)


## A full-screen colour wash that fades out (also with reduce motion: it does not move).
func screen_flash(col: Color, dur: float) -> void:
	if fx == null:
		return
	var r: ColorRect = ColorRect.new()
	r.set_meta(&"ghost", true)
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.add_child(r)
	if reduce:
		r.color.a = col.a * 0.5
	var tw: Tween = r.create_tween()
	tw.tween_property(r, "color:a", 0.0, dur)
	tw.tween_callback(r.queue_free)


## End / safehouse title: slams in from 1.3x (a fade with reduce motion).
func title_slam(l: Control, won: bool) -> void:
	if l == null:
		return
	l.modulate.a = 0.0
	var tw: Tween = l.create_tween()
	if reduce:
		tw.tween_property(l, "modulate:a", 1.0, 0.2)
	else:
		(func() -> void:
			if is_instance_valid(l):
				l.pivot_offset = l.size * 0.5).call_deferred()
		l.scale = Vector2(1.3, 1.3)
		tw.tween_property(l, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(l, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if not won:
			tw.tween_callback(func() -> void: _wobble(l))
	if won:
		tw.tween_callback(func() -> void: _pulse(l, Color(1.6, 1.6, 1.2)))


# ================================================================ primitives
## Screen shake on the content node (off with the setting or reduce motion).
func shake(strength: float, dur: float) -> void:
	if reduce or not shake_on or content == null:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	content.position = Vector2.ZERO
	_shake_tween = content.create_tween()
	var steps: int = maxi(3, int(dur / 0.04))
	for k: int in steps:
		var fall: float = 1.0 - float(k) / float(steps)
		var off: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * strength * fall
		_shake_tween.tween_property(content, "position", off, dur / float(steps + 1))
	_shake_tween.tween_property(content, "position", Vector2.ZERO, dur / float(steps + 1))
	if not last_played.has("shake"):
		last_played.append("shake")


## A colour pulse on any CanvasItem (modulate from `col` back to white).
func _pulse(n: Variant, col: Color) -> void:
	if n == null or not is_instance_valid(n):
		return
	var c: CanvasItem = n
	var a: float = c.modulate.a
	c.modulate = Color(col.r, col.g, col.b, a)
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "modulate", Color(1, 1, 1, a), 0.28)


## Scale pop from `amount` back to 1 around the centre (a brightness pulse with reduce motion).
func _pop(n: Variant, amount: float, tint: Color) -> void:
	if n == null or not is_instance_valid(n):
		return
	var c: Control = n
	if reduce:
		_pulse(c, Color(1.4, 1.4, 1.4))
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(amount, amount)
	var a: float = c.modulate.a
	c.modulate = Color(tint.r * 1.4 + 0.3, tint.g * 1.4 + 0.3, tint.b * 1.4 + 0.3, a)
	var tw: Tween = c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "modulate", Color(1, 1, 1, a), 0.25)


## A short rotation wobble (does not move the node, so it never fights its container).
func _wobble(n: Variant) -> void:
	if reduce or n == null or not is_instance_valid(n):
		return
	var c: Control = n
	c.pivot_offset = c.size * 0.5
	var tw: Tween = c.create_tween()
	for d: float in [0.07, -0.06, 0.04, -0.02, 0.0]:
		tw.tween_property(c, "rotation", d, 0.045)


## A ghost flies into `target` (shrinking to its size) and runs `on_land`; no ghost: runs at once.
func _fly_into(ghost: DDCardView, target: Variant, on_land: Callable) -> void:
	if ghost == null or target == null or not is_instance_valid(target):
		on_land.call()
		if ghost != null:
			ghost.queue_free()
		return
	var to: Rect2 = _rect(target)
	var tw: Tween = ghost.create_tween()
	if reduce:
		tw.tween_property(ghost, "modulate:a", 0.0, 0.14)
		tw.tween_callback(on_land)
	else:
		var from_size: Vector2 = ghost.size
		var s: float = minf(to.size.x / maxf(1.0, from_size.x), to.size.y / maxf(1.0, from_size.y))
		s = clampf(s, 0.2, 1.0)
		var dest: Vector2 = to.position + (to.size - from_size * s) * 0.5 - fx.global_position
		tw.tween_property(ghost, "position", dest, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(ghost, "scale", Vector2(s, s), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(on_land)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.06)
	tw.tween_callback(ghost.queue_free)


func _drop(ghost: DDCardView) -> void:
	if ghost == null:
		return
	var tw: Tween = ghost.create_tween()
	if not reduce:
		ghost.pivot_offset = ghost.size * 0.5
		tw.tween_property(ghost, "position:y", ghost.position.y + 46.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(ghost, "rotation", 0.18, 0.22)
	tw.parallel().tween_property(ghost, "modulate", Color(0.6, 0.6, 0.6, 0.0), 0.22)
	tw.tween_callback(ghost.queue_free)


func _grey_out(ghost: DDCardView) -> void:
	if ghost == null:
		return
	ghost.modulate = Color(0.55, 0.55, 0.55)
	var tw: Tween = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)


## A thin bright bar drawn across `r` at an angle, carved in (scale) then faded.
func _slash(r: Rect2, col: Color, delay: float) -> void:
	if fx == null or r.size == Vector2.ZERO:
		return
	var bar: ColorRect = ColorRect.new()
	bar.set_meta(&"ghost", true)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = col
	var w: float = minf(r.size.x, r.size.y) * 0.9
	bar.size = Vector2(w, 5.0)
	bar.pivot_offset = Vector2(w * 0.5, 2.5)
	bar.position = r.position + r.size * 0.5 - bar.pivot_offset - fx.global_position
	bar.rotation = -0.6
	fx.add_child(bar)
	var tw: Tween = bar.create_tween()
	if delay > 0.0:
		bar.modulate.a = 0.0
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void: bar.modulate.a = 1.0)
	if not reduce:
		bar.scale = Vector2(0.0, 1.0)
		tw.tween_property(bar, "scale:x", 1.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bar, "modulate:a", 0.0, 0.22)
	tw.tween_callback(bar.queue_free)


## A gold shield outline over the HP row (Cover gained or soaking a hit).
func _shield(over: Variant) -> void:
	if fx == null or over == null or not is_instance_valid(over):
		return
	var r: Rect2 = _rect(over)
	var p: Panel = Panel.new()
	p.set_meta(&"ghost", true)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st: StyleBoxFlat = DDUi.box(Color(DDUi.COVER, 0.18), DDUi.COVER, 4, 16, 0)
	p.add_theme_stylebox_override("panel", st)
	p.position = r.position - Vector2(6, 6) - fx.global_position
	p.size = r.size + Vector2(12, 12)
	fx.add_child(p)
	var tw: Tween = p.create_tween()
	if not reduce:
		p.pivot_offset = p.size * 0.5
		p.scale = Vector2(0.96, 0.9)
		tw.tween_property(p, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 0.0, 0.2)
	tw.tween_callback(p.queue_free)


## Ticks the HP label / bar from `from` to the run's HP now.
func _tick_hp(ctx: Dictionary, from: int, delay: float) -> void:
	var lab: Label = ctx.get("hp_label")
	var bar: ProgressBar = ctx.get("hp_bar")
	var to: int = int(ctx.get("hp", from))
	var max_hp: int = int(ctx.get("max_hp", 0))
	if lab == null or from == to:
		return
	var fmt: Callable = func(x: float) -> void:
		if is_instance_valid(lab):
			lab.text = "HP  %d / %d" % [int(round(x)), max_hp]
		if bar != null and is_instance_valid(bar):
			bar.value = x
	fmt.call(float(from))
	var tw: Tween = lab.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(fmt, float(from), float(to), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _after(delay: float, f: Callable) -> void:
	if fx == null:
		f.call()
		return
	var tw: Tween = fx.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(f)


## A non-interactive copy of a card tile in the fx layer at a global rect.
func _ghost(spec: Dictionary, r: Rect2) -> DDCardView:
	var s: Dictionary = spec.duplicate()
	s["selected"] = false
	var g: DDCardView = DDCardView.new()
	g.setup(s)
	g.index = -2
	g.set_meta(&"ghost", true)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.add_child(g)
	g.position = r.position - fx.global_position
	g.size = r.size
	g.custom_minimum_size = r.size
	return g


## A face-down card (the card-back art when the manifest has one).
func _back(sz: Vector2) -> Control:
	var p: PanelContainer = PanelContainer.new()
	p.set_meta(&"ghost", true)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st: StyleBoxFlat = DDUi.box(Color("1b211f"), Color("55605a"), 3, 14, 6)
	p.add_theme_stylebox_override("panel", st)
	var tex: Texture2D = Art.texture_for(Art.back_keys())
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(tr)
	else:
		var l: Label = DDUi.label("DD", DDUi.FONT_XL, Color("55605a"), HORIZONTAL_ALIGNMENT_CENTER)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
	fx.add_child(p)
	p.custom_minimum_size = sz
	p.size = sz
	return p


static func _rect(n: Variant) -> Rect2:
	if n == null or not is_instance_valid(n):
		return Rect2()
	return (n as Control).get_global_rect()
