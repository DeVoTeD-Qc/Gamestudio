# dd_feedback.gd
# Purpose: dd-feel, v3 "Kill Stacks". The street's feedback animations and sound cues. main.gd
#   rebuilds the whole screen after every action; just before the action it takes a snapshot
#   (street card rects, each gun's stack card rects and where its next kill lands, HP, Cover), and
#   after the rebuild it calls play() with the event and the new views. Feedback then animates
#   from the old picture to the new one:
#     kill      the zombie flies from the street onto the active gun's stack and lands offset so
#               its number stays visible; "+N" points float up; the stack counter is already new
#     melee     the zombie lunges and fades (no stack, no points)
#     damage    HP panel flashes red, HP ticks down, screen shake by the damage; Cover: shield
#     collect   a finished gun's stack slides off, card by card, into the points counter; the gun
#               card shows "FINISHED +50"; a met challenge stamps a gold badge ("STAIRCASE!") and
#               its reward flies to HP / Cover / points; Encore pops the gun back
#     discard   a replaced, unfinished gun's stack drops and fades (it pays nothing)
#     equip     the gun card flies into its slot; scrap drops; medkit -> HP; cover -> Cover chip
#     shuffle   wave / room cards fly face down from their deck on the left / right into the
#               middle pile, which riffles; opened rooms flick one restock card each
#     run       the street flies back into the pile, then a new street is dealt
#     deal      new cards fly from the pile face down and flip; boss cards come from the boss tile
#     holdover  the card that stayed slides to its new place
#   Every animation uses ghosts in the fx layer (or scale / colour on real nodes, which never
#   fight the containers' layout) and never blocks input: tapping mid-animation just rebuilds the
#   screen, which clears the ghosts. Reduce motion: nothing flies, shakes or zooms; cards fade.
# Dependencies: DDCardView, DDGunView, DDUi, DDCard, DDRun, scripts/fx/dd_sfx.gd, scripts/ui/dd_art.gd.
# Author: Game Feel Engineer Agent (dd-feel), v3 pass: Mechanics Developer Agent
extends Node

const Sfx: GDScript = preload("res://scripts/fx/dd_sfx.gd")
const Art: GDScript = preload("res://scripts/ui/dd_art.gd")

const DEAL_STAGGER: float = 0.07
const DEAL_FLY: float = 0.2
const FLIP: float = 0.14
const SLIDE: float = 0.18
const KILL_FLY: float = 0.32

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


func _mark(n: String) -> void:
	if not last_played.has(n):
		last_played.append(n)


# ================================================================ entry point
## p: {type: "attack"|"card"|"run"|"room"|"machine"|"deal", ev, snap}. ctx: the new views
## (see main.gd _fx_context()).
func play(p: Dictionary, ctx: Dictionary) -> void:
	last_played.clear()
	var snap: Dictionary = p.get("snap", {})
	var ev: Dictionary = p.get("ev", {})
	var t: String = str(p.get("type", ""))
	var deal_delay: float = 0.0
	match t:
		"attack":
			deal_delay = _attack_fx(ev, snap, ctx)
		"card":
			deal_delay = _card_fx(ev, snap, ctx)
		"run":
			deal_delay = _run_fx(ev, snap, ctx)
		"room":
			_shuffle_in(ctx.get("rooms", [])[int(ev.get("room", 0))] if int(ev.get("room", 0)) < (ctx.get("rooms", []) as Array).size() else null,
				(ev.get("cards", []) as Array).size(), ctx, 0.0, true)
			_mark("room_open")
		"machine":
			_machine_fx(ev, snap, ctx)
	var t_collect: float = deal_delay
	for info: Variant in ev.get("collects", []):
		t_collect = _collect_fx(info, snap, ctx, t_collect)
	# wave decks shuffle in before the new cards are dealt
	for w: Variant in ev.get("waves", []):
		var wi: int = int((w as Dictionary).get("wave", 0))
		var waves: Array = ctx.get("waves", [])
		_shuffle_in(waves[wi] if wi < waves.size() else null, int((w as Dictionary).get("cards", 6)), ctx, deal_delay, false)
		var rooms: Array = ctx.get("rooms", [])
		var open: Array = ctx.get("open_rooms", [])
		var k: int = 0
		for ri: int in rooms.size():
			if ri < open.size() and bool(open[ri]) and k < int((w as Dictionary).get("restock", 0)):
				_shuffle_in(rooms[ri], 1, ctx, deal_delay + 0.12, false)
				k += 1
		deal_delay += 0.75 if not reduce else 0.2
		_mark("wave_shuffle")
	# the street now: cards that were already there slide, new ones are dealt
	var views: Dictionary = ctx.get("street", {})
	var old_rects: Dictionary = snap.get("rects", {})
	var pile_rect: Rect2 = _rect(ctx.get("pile"))
	var boss_rect: Rect2 = _rect(ctx.get("boss"))
	var k2: int = 0
	for id: Variant in ctx.get("order", []):
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
			var boss_card: bool = c != null and c.is_boss()
			_deal(v, boss_rect if boss_card and boss_rect.size != Vector2.ZERO else pile_rect, deal_delay + DEAL_STAGGER * k2, boss_card, ctx)
			k2 += 1
	if k2 > 0:
		_mark("deal")
	if bool(ev.get("dead", false)):
		_death()
	elif bool(ev.get("district_cleared", false)):
		_after(maxf(0.12, t_collect), func() -> void: Sfx.cue(&"clear"))
		_mark("clear")


# ================================================================ kills
## Returns the delay before a new street may be dealt.
func _attack_fx(ev: Dictionary, snap: Dictionary, ctx: Dictionary) -> float:
	var c: DDCard = ev.get("card")
	if c == null:
		return 0.0
	var pr: Dictionary = ev.get("preview", {})
	var id: int = c.get_instance_id()
	var from: Rect2 = (snap.get("rects", {}) as Dictionary).get(id, Rect2())
	var spec: Dictionary = (snap.get("specs", {}) as Dictionary).get(id, {})
	var ghost: DDCardView = _ghost(spec, from) if from.size != Vector2.ZERO and not spec.is_empty() else null
	var w: int = int(ev.get("weapon", DDRun.MELEE))
	_damage_fx(pr, snap, ctx)
	if w == DDRun.MELEE:
		_mark("melee")
		Sfx.cue(&"hit", 0.9)
		if ghost != null:
			ghost.modulate = Color(1.7, 0.6, 0.55)
			var tw: Tween = ghost.create_tween()
			if not reduce:
				ghost.pivot_offset = ghost.size * 0.5
				tw.tween_property(ghost, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_callback(func() -> void: _slash(ghost.get_global_rect(), DDUi.TEXT, 0.0))
			tw.tween_property(ghost, "modulate:a", 0.0, 0.18)
			tw.tween_callback(ghost.queue_free)
		return 0.12
	_mark("kill_stack")
	var guns: Array = ctx.get("guns", [null, null])
	var gv: DDGunView = guns[w] if w < guns.size() else null
	var target: Rect2 = Rect2()
	var mini: DDCardView = null
	var collected: bool = false
	for info: Variant in ev.get("collects", []):
		if int((info as Dictionary).get("slot", -1)) == w:
			collected = true
	if gv != null and is_instance_valid(gv) and not collected and not gv.stack_cards.is_empty():
		mini = gv.stack_cards[gv.stack_cards.size() - 1]
		target = _rect(mini)
	else:
		var nr: Array = snap.get("next_rect", [Rect2(), Rect2()])
		target = nr[w] if w < nr.size() else Rect2()
	if mini != null:
		mini.modulate.a = 0.0
	var pts: int = int(pr.get("points", 0))
	if ghost == null or target.size == Vector2.ZERO or reduce:
		if ghost != null:
			ghost.queue_free()
		if mini != null:
			var tw0: Tween = mini.create_tween()
			tw0.tween_property(mini, "modulate:a", 1.0, 0.15)
		Sfx.cue(&"kill")
		if pts > 0:
			_float(target if target.size != Vector2.ZERO else from, "+%d" % (pts * 10), DDUi.accent("X"), 0.0)
		return 0.12
	var tw: Tween = ghost.create_tween()
	var s: float = clampf(minf(target.size.x / maxf(1.0, from.size.x), target.size.y / maxf(1.0, from.size.y)), 0.15, 1.0)
	ghost.pivot_offset = Vector2.ZERO
	tw.tween_property(ghost, "position", target.position - fx.global_position, KILL_FLY).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(ghost, "scale", Vector2(s, s), KILL_FLY).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(ghost, "rotation", -0.05, KILL_FLY)
	tw.tween_callback(func() -> void:
		Sfx.cue(&"kill", randf_range(0.95, 1.05))
		Sfx.cue(&"notch", 1.1)
		if mini != null and is_instance_valid(mini):
			mini.modulate.a = 1.0
			_pop(mini, 1.25, DDUi.accent("Z"))
		if pts > 0:
			_float(target, "+%d" % (pts * 10), DDUi.accent("X"), 0.0))
	tw.tween_property(ghost, "modulate:a", 0.0, 0.05)
	tw.tween_callback(ghost.queue_free)
	return KILL_FLY + 0.05


func _damage_fx(pr: Dictionary, snap: Dictionary, ctx: Dictionary) -> void:
	var loss: int = int(pr.get("hp_loss", 0))
	if loss > 0:
		Sfx.cue(&"hit", clampf(1.15 - loss * 0.03, 0.8, 1.15))
		_pulse(ctx.get("hp_panel"), Color(1.8, 0.55, 0.5))
		_tick_hp(ctx, int(snap.get("hp", 0)), 0.0)
		shake(clampf(4.0 + loss * 0.9, 4.0, 15.0), 0.22)
		_mark("hit")
	if int(pr.get("absorbed", 0)) > 0:
		Sfx.cue(&"block")
		_shield(ctx.get("hp_box"))
		_mark("block")


## Collect moment. Returns the time it ends (for the next collect / the clear cue).
func _collect_fx(info: Dictionary, snap: Dictionary, ctx: Dictionary, t0: float) -> float:
	var s: int = int(info.get("slot", 0))
	var rects: Array = (snap.get("stack_rects", [[], []]) as Array)[s] if s < 2 else []
	var nr: Array = snap.get("next_rect", [Rect2(), Rect2()])
	var st: Array = info.get("stack", [])
	var all_rects: Array = rects.duplicate()
	if all_rects.size() < st.size():
		all_rects.append(nr[s] if s < nr.size() else Rect2())
	var guns: Array = ctx.get("guns", [null, null])
	var gv: Control = guns[s] if s < guns.size() else null
	var gun_rect: Rect2 = (snap.get("gun_rects", [Rect2(), Rect2()]) as Array)[s] if s < 2 else Rect2()
	if gun_rect.size == Vector2.ZERO:
		gun_rect = _rect(gv)
	var pts_anchor: Control = ctx.get("points")
	if not bool(info.get("finished", false)):
		_mark("discard")
		for k: int in st.size():
			if k >= all_rects.size() or (all_rects[k] as Rect2).size == Vector2.ZERO:
				continue
			var g: Control = _mini_ghost(int(st[k]), all_rects[k])
			_after(t0, func() -> void:
				if is_instance_valid(g):
					_drop_ctrl(g))
		if not st.is_empty():
			_float(gun_rect, "stack discarded", DDUi.TEXT_DIM, t0)
		return t0 + 0.3
	_mark("collect")
	var t: float = t0 + 0.05
	for k: int in st.size():
		if k >= all_rects.size() or (all_rects[k] as Rect2).size == Vector2.ZERO:
			continue
		var g2: Control = _mini_ghost(int(st[k]), all_rects[k])
		var dt: float = t + 0.09 * k
		_after(dt, func() -> void:
			if not is_instance_valid(g2):
				return
			Sfx.cue(&"flip", 1.0 + 0.06 * k)
			if reduce or pts_anchor == null or not is_instance_valid(pts_anchor):
				var tf: Tween = g2.create_tween()
				tf.tween_property(g2, "modulate:a", 0.0, 0.2)
				tf.tween_callback(g2.queue_free)
				return
			var to: Rect2 = _rect(pts_anchor)
			var tw: Tween = g2.create_tween()
			tw.tween_property(g2, "position", to.position + to.size * 0.5 - g2.size * 0.25 - fx.global_position, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(g2, "scale", Vector2(0.5, 0.5), 0.3)
			tw.tween_callback(func() -> void:
				if is_instance_valid(pts_anchor):
					_pop(pts_anchor, 1.08, DDUi.accent("X")))
			tw.tween_property(g2, "modulate:a", 0.0, 0.05)
			tw.tween_callback(g2.queue_free))
	var t_end: float = t + 0.09 * st.size() + 0.3
	var bonus: int = int(info.get("bonus", 0)) + int(info.get("bounty", 0))
	_float(gun_rect, "FINISHED +%d" % (bonus * 10), DDUi.GOOD, t + 0.05, 30)
	_after(t + 0.05, func() -> void: Sfx.cue(&"clear", 1.25))
	if bool(info.get("shatter", false)):
		_mark("shatter")
		_after(t, func() -> void:
			Sfx.cue(&"break")
			_pulse(gv, Color(1.9, 0.5, 0.45))
			_wobble(gv))
	if bool(info.get("challenge", false)):
		_mark("challenge")
		var name: String = DDText.challenge_name(str(info.get("challenge_id", ""))).to_upper() + "!"
		var reward: String = DDText.reward_short(str(info.get("reward", "")), int(info.get("reward_amount", 0)), DDBalance.get_default())
		_stamp(gun_rect, name, reward, t_end)
		var kind: String = str(info.get("reward", ""))
		var dest: Variant = ctx.get("hp_panel") if kind == "heal" else (ctx.get("cover") if kind == "cover" else (gv if kind == "encore" else pts_anchor))
		_after(t_end + 0.5, func() -> void:
			if dest != null and is_instance_valid(dest):
				_float_to(gun_rect, dest, reward, DDUi.accent("X"))
			if kind == "encore" and gv != null and is_instance_valid(gv):
				_pop(gv, 1.1, DDUi.SELECT))
		t_end += 1.1
	return t_end


## The gold challenge stamp over the gun card.
func _stamp(r: Rect2, title: String, sub: String, delay: float) -> void:
	if fx == null or r.size == Vector2.ZERO:
		return
	var p: PanelContainer = DDUi.panel(Color("2a2208"), 10, DDUi.accent("X"), 4)
	p.set_meta(&"ghost", true)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v: VBoxContainer = DDUi.vbox(0)
	p.add_child(v)
	v.add_child(DDUi.label(title, DDUi.FONT_L, DDUi.accent("X"), HORIZONTAL_ALIGNMENT_CENTER))
	if sub != "":
		v.add_child(DDUi.label(sub, DDUi.FONT_S, DDUi.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var tex: Texture2D = Art.texture_for(Art.badge_keys("challenge"))
	if tex != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(40, 40)
		v.add_child(tr)
	DDUi.ignore_mouse(p)
	fx.add_child(p)
	p.size = p.get_combined_minimum_size()
	p.position = r.position + (r.size - p.size) * 0.5 - fx.global_position
	p.modulate.a = 0.0
	var tw: Tween = p.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		Sfx.cue(&"perk", 1.1)
		p.pivot_offset = p.size * 0.5
		if not reduce:
			p.scale = Vector2(1.7, 1.7)
			p.rotation = -0.12)
	tw.tween_property(p, "modulate:a", 1.0, 0.08)
	if not reduce:
		tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


# ================================================================ other cards
func _card_fx(ev: Dictionary, snap: Dictionary, ctx: Dictionary) -> float:
	var c: DDCard = ev.get("card")
	if c == null:
		return 0.0
	var pr: Dictionary = ev.get("preview", {})
	var id: int = c.get_instance_id()
	var from: Rect2 = (snap.get("rects", {}) as Dictionary).get(id, Rect2())
	var spec: Dictionary = (snap.get("specs", {}) as Dictionary).get(id, {})
	var ghost: DDCardView = _ghost(spec, from) if from.size != Vector2.ZERO and not spec.is_empty() else null
	match c.kind:
		DDCard.WEAPON:
			if str(ev.get("choice", "")) == DDRun.SCRAP:
				_mark("scrap")
				Sfx.cue(&"scrap")
				_drop(ghost)
				_float(from, "+%d" % (int(pr.get("points", 0)) * 10), DDUi.accent("X"), 0.05)
			else:
				_mark("equip")
				var s: int = int(ev.get("slot", 0))
				var guns: Array = ctx.get("guns", [null, null])
				var gv: Control = guns[s] if s < guns.size() else null
				_fly_into(ghost, gv, func() -> void:
					Sfx.cue(&"equip")
					_pop(gv, 1.08, DDUi.accent("W")))
		DDCard.MEDKIT:
			var hp_panel: Control = ctx.get("hp_panel")
			if int(pr.get("heal", 0)) > 0:
				_mark("heal")
				_fly_into(ghost, hp_panel, func() -> void:
					Sfx.cue(&"heal")
					_pulse(hp_panel, Color(0.7, 1.6, 0.8)))
				_tick_hp(ctx, int(snap.get("hp", 0)), 0.08)
			else:
				_mark("no_heal")
				Sfx.cue(&"warn")
				_grey_out(ghost)
		DDCard.COVER:
			_mark("cover")
			var target: Control = ctx.get("cover") if ctx.get("cover") != null else ctx.get("hp_panel")
			_fly_into(ghost, target, func() -> void:
				Sfx.cue(&"cover")
				_shield(ctx.get("hp_box"))
				_pop(ctx.get("cover"), 1.35, DDUi.COVER))
	return 0.16 if bool(ev.get("street_ended", false)) else 0.0


func _run_fx(ev: Dictionary, snap: Dictionary, ctx: Dictionary) -> float:
	_mark("run")
	Sfx.cue(&"retreat")
	var to: Rect2 = _rect(ctx.get("pile"))
	var rects: Dictionary = snap.get("rects", {})
	var specs: Dictionary = snap.get("specs", {})
	var k: int = 0
	for id: Variant in rects:
		var g: DDCardView = _ghost(specs.get(id, {}), rects[id]) if not (specs.get(id, {}) as Dictionary).is_empty() else null
		if g == null:
			continue
		var tw: Tween = g.create_tween()
		if reduce or to.size == Vector2.ZERO:
			tw.tween_property(g, "modulate:a", 0.0, 0.15)
		else:
			tw.tween_interval(0.04 * k)
			var s: float = clampf(to.size.y / maxf(1.0, g.size.y), 0.2, 1.0)
			tw.tween_property(g, "position", to.position - fx.global_position, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(g, "scale", Vector2(s, s), 0.24)
			tw.tween_property(g, "modulate:a", 0.0, 0.05)
		tw.tween_callback(g.queue_free)
		k += 1
	_after(0.3, func() -> void: _riffle(ctx.get("pile")))
	_damage_fx({"hp_loss": maxi(0, int(snap.get("hp", 0)) - int(ctx.get("hp", 0)))}, snap, ctx)
	return 0.42 if not reduce else 0.1


func _machine_fx(ev: Dictionary, snap: Dictionary, ctx: Dictionary) -> void:
	var res: Dictionary = ev.get("result", {})
	_mark("machine_" + str(res.get("machine", "")))
	Sfx.cue(&"perk")
	var s: int = int(res.get("slot", -1))
	var guns: Array = ctx.get("guns", [null, null])
	if s >= 0 and s < guns.size() and guns[s] != null:
		_pop(guns[s], 1.08, DDUi.SELECT)
	if res.has("trimmed"):
		# the removed kill already paid when it was made: it pops off and drops away
		var rects: Array = (snap.get("stack_rects", [[], []]) as Array)[s]
		if not rects.is_empty():
			var g: Control = _mini_ghost(int(res["trimmed"]), rects[rects.size() - 1])
			_drop_ctrl(g)
	var rooms: Array = ctx.get("rooms", [])
	var ri: int = int(res.get("room", -1))
	if ri >= 0 and ri < rooms.size():
		_pop(rooms[ri], 1.06, DDUi.accent("K"))


# ================================================================ shuffle-in
## `n` face-down cards fly from `src` (a wave deck / room deck) into the middle pile, which then
## riffles. door: the room tile swings open first.
func _shuffle_in(src: Variant, n: int, ctx: Dictionary, delay: float, door: bool) -> void:
	var pile: Control = ctx.get("pile")
	if src == null or not is_instance_valid(src) or pile == null:
		return
	var from: Rect2 = _rect(src)
	var to: Rect2 = _rect(pile)
	if door and not reduce:
		var c: Control = src
		c.pivot_offset = Vector2(0, c.size.y * 0.5)
		var td: Tween = c.create_tween()
		td.tween_property(c, "scale:x", 0.2, 0.12).set_trans(Tween.TRANS_SINE)
		td.tween_property(c, "scale:x", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.cue(&"clear", 1.2)
	if reduce or from.size == Vector2.ZERO or to.size == Vector2.ZERO:
		_after(delay, func() -> void: _pulse(pile, Color(1.4, 1.4, 1.4)))
		return
	var sz: Vector2 = Vector2(to.size.y * 0.7, to.size.y)
	for k: int in mini(n, 8):
		var b: Control = _back(sz)
		b.position = from.position + (from.size - sz) * 0.5 - fx.global_position
		b.modulate.a = 0.0
		var tw: Tween = b.create_tween()
		tw.tween_interval(delay + 0.06 * k)
		tw.tween_callback(func() -> void:
			b.modulate.a = 1.0
			Sfx.cue(&"deal", randf_range(0.9, 1.1)))
		tw.tween_property(b, "position", to.position + (to.size - sz) * 0.5 - fx.global_position + Vector2(randf_range(-6, 6), 0), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(b, "rotation", randf_range(-0.2, 0.2), 0.3)
		tw.tween_property(b, "modulate:a", 0.0, 0.08)
		tw.tween_callback(b.queue_free)
	_after(delay + 0.06 * mini(n, 8) + 0.3, func() -> void: _riffle(pile))


## The pile riffles: a quick double wobble and pop (the shuffle).
func _riffle(pile: Variant) -> void:
	if pile == null or not is_instance_valid(pile):
		return
	_mark("riffle")
	Sfx.cue(&"flip", 0.8)
	_wobble(pile)
	_pop(pile, 1.08, DDUi.TEXT)


# ================================================================ small ghosts
func _mini_ghost(z: int, r: Rect2) -> Control:
	var p: PanelContainer = DDUi.panel(DDUi.card_bg("Z"), 2, DDUi.accent("Z"), 2)
	p.set_meta(&"ghost", true)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = DDUi.label(str(z), maxi(14, int(r.size.x * 0.3)), DDUi.TEXT)
	p.add_child(l)
	fx.add_child(p)
	p.position = r.position - fx.global_position
	p.size = r.size
	p.custom_minimum_size = r.size
	return p


func _drop_ctrl(g: Control) -> void:
	var tw: Tween = g.create_tween()
	if not reduce:
		g.pivot_offset = g.size * 0.5
		tw.tween_property(g, "position:y", g.position.y + 40.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(g, "rotation", 0.25, 0.25)
	tw.parallel().tween_property(g, "modulate", Color(0.5, 0.5, 0.5, 0.0), 0.25)
	tw.tween_callback(g.queue_free)


## A floating text that rises and fades over rect r.
func _float(r: Rect2, t: String, col: Color, delay: float, size: int = 26) -> void:
	if fx == null or r.size == Vector2.ZERO:
		return
	var l: Label = DDUi.label(t, size, col)
	l.set_meta(&"ghost", true)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	fx.add_child(l)
	l.position = r.position + Vector2(r.size.x * 0.5 - l.get_combined_minimum_size().x * 0.5, r.size.y * 0.25) - fx.global_position
	l.modulate.a = 0.0
	var tw: Tween = l.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(l, "modulate:a", 1.0, 0.06)
	if not reduce:
		tw.tween_property(l, "position:y", l.position.y - 44.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_interval(0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


## A text chip flies from rect r to a node (a reward going to HP / Cover / points).
func _float_to(r: Rect2, dest: Control, t: String, col: Color) -> void:
	var l: Label = DDUi.label(t, 26, col)
	l.set_meta(&"ghost", true)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	fx.add_child(l)
	l.position = r.position + r.size * 0.5 - fx.global_position
	var to: Rect2 = _rect(dest)
	var tw: Tween = l.create_tween()
	if not reduce:
		tw.tween_property(l, "position", to.position + to.size * 0.5 - fx.global_position, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		Sfx.cue(&"heal" if t.contains("HP") else &"cover", 1.1)
		_pop(dest, 1.15, col))
	tw.tween_property(l, "modulate:a", 0.0, 0.1)
	tw.tween_callback(l.queue_free)


# ================================================================ deal
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
	# the timer lives on a ghost node: a rebuild (clear()) cancels it before the nodes the
	# callback captured are freed
	var holder: Node = Node.new()
	holder.set_meta(&"ghost", true)
	fx.add_child(holder)
	var tw: Tween = holder.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(f)
	tw.tween_callback(holder.queue_free)


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
