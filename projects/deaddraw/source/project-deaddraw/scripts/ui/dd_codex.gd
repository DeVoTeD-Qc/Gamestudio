# dd_codex.gd
# Purpose: dd-ux-v4 (head's points 9 and 11): two full-screen overlays.
#   - The CODEX (from the title and the Menu): every gun, the melee weapon, the zombie tiers, the
#     bosses, the items (medkits, cover) and the Patches, built from balance.json. Filters: type
#     (All, Guns, Melee, Zombies, Bosses, Items, Patches), district (All districts or one) and
#     "Met only". Entries you haven't met yet are dark silhouettes named "???" (head's M4 a); what
#     you have met is saved in the profile (DDProfile.codex_met). Every tile has its 2-line tooltip
#     on right click / long press, and a tap on a tile opens it too.
#   - The GLOSSARY (the ? in the street's HUD, and How to play): every icon in the game, one line
#     each, in sections, plus how a street works in five short lines.
#   Both close with the Close button, Esc, or a tap on the dim edge. They sit under the tooltip
#   overlay, so tooltips open on top of them.
# Dependencies: DDUi, DDText, DDPayloads, DDBalance, DDProfile, DDCardView, scripts/ui/dd_art.gd,
#   scripts/ui/dd_marks.gd. Loaded with preload() by main.gd.
# Author: UI/UX Agent (dd-ux-v4)
extends Control

const Art: GDScript = preload("res://scripts/ui/dd_art.gd")
const Marks: GDScript = preload("res://scripts/ui/dd_marks.gd")

signal opened
signal closed
signal inspect_requested(payload: Dictionary)
## dd-ux-equip: a touch scroll of the list ended.
signal scrolled

const TYPES: Array[String] = ["all", "guns", "melee", "zombies", "bosses", "items", "patches"]
const TYPE_KIND: Dictionary = {"guns": "W", "melee": "K", "zombies": "Z", "bosses": "F", "items": "M", "patches": "P"}

var mode: String = ""
var f_type: String = "all"
var f_dist: String = "any"
var f_met: bool = false
## dd-art-fit (head: review every card): "Show all" reveals every entry (art, name, numbers, rules)
## without marking anything met (the profile's codex_met is untouched). Session only: this node
## lives as long as the game, and the flag is never saved.
var show_all: bool = false
var _bal: DDBalance = null
var _profile: DDProfile = null
var _root: Control = null
## The Codex tiles on screen now (tests): [{key, met, type, view}].
var shown: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func is_open() -> bool:
	return visible


func close() -> void:
	visible = false
	mode = ""
	if _root != null:
		_root.queue_free()
		_root = null
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ================================================================ entries
## Every Codex entry: {key, type, name, art_keys, hit, rule, stat, line, districts: [ids]}.
static func entries(bal: DDBalance) -> Array:
	var out: Array = []
	var ds: Array = bal.districts()
	var wdist: Dictionary = {}
	var zdist: Dictionary = {}
	var mdist: Dictionary = {}
	var cdist: Dictionary = {}
	for d: Variant in ds:
		var dd: Dictionary = d
		var id: String = str(dd.get("id", ""))
		for wid: Variant in dd.get("weapons", []):
			_add(wdist, str(wid), id)
		for r: Variant in dd.get("rooms", []):
			var m: Dictionary = (r as Dictionary).get("machine", {})
			if str(m.get("kind", "")) == "wall":
				_add(wdist, str(m.get("wid", "")), id)
			for c: Variant in (r as Dictionary).get("pack", []):
				_card_dist(str(c), id, mdist, cdist)
		for c2: Variant in dd.get("entrance", []):
			_card_dist(str(c2), id, mdist, cdist)
		for wave: Variant in dd.get("waves", []):
			for z: Variant in wave:
				if typeof(z) == TYPE_STRING:
					_card_dist(str(z), id, mdist, cdist)
				else:
					_add(zdist, DDText.zombie_name(int(z)), id)
	for wid2v: Variant in bal.weapons().keys():
		var wid2: String = str(wid2v)
		if not bal.is_gun(wid2):
			continue
		var rw: Array = bal.weapon_reward(wid2)
		out.append({"key": "gun:" + wid2, "type": "guns", "name": bal.weapon_name(wid2), "art_keys": Art.weapon_keys(wid2, bal.weapon_name(wid2)),
			"hit": bal.weapon_power(wid2), "rule": bal.weapon_rule(wid2), "cap": bal.weapon_cap(wid2), "stat": DDText.rule_tag(bal.weapon_rule(wid2)), "districts": wdist.get(wid2, []),
			"line": "Each kill: %s. Full: %s." % [DDText.rule_short(bal.weapon_rule(wid2)), DDText.reward_short(str(rw[0]), int(rw[1]), bal)]})
	var all_ids: Array = ds.map(func(d: Variant) -> String: return str((d as Dictionary).get("id", "")))
	# v4: Bare Hands (always) and the melee weapon cards (power, uses)
	out.append({"key": "melee:bare_hands", "type": "melee", "name": "Bare Hands", "art_keys": DDV4Hooks.melee_art_keys("", "Bare Hands"), "hit": bal.num("hands_power"),
		"stat": "always", "districts": all_ids, "line": "Always with you. Any zombie, no points, never breaks."})
	# which districts deal each melee weapon card (balance melee_pool)
	var mdist2: Dictionary = {}
	var pool: Dictionary = bal.dict("melee_pool")
	for did: Variant in pool:
		for m2: Variant in pool[did]:
			_add(mdist2, str(m2), str(did))
	for mid: Variant in bal.dict("melee_weapons").keys():
		var m: String = str(mid)
		out.append({"key": "melee:" + m, "type": "melee", "name": bal.melee_name(m), "art_keys": DDV4Hooks.melee_art_keys(m, bal.melee_name(m)), "hit": bal.melee_power(m),
			"uses": bal.melee_uses(m), "stat": "melee", "districts": mdist2.get(m, all_ids),
			"line": "Found in the pile. Each kill uses 1; at 0 it breaks."})
	# dd-art-import45 (art pack 4): one entry per zombie value, its character name and painting; the tier
	# (rules name, ring colour, the line) is in the stat row and the tooltip
	for v: int in range(1, 13):
		var t: int = 0 if v <= 3 else (1 if v <= 6 else (2 if v <= 9 else 3))
		var nm: String = Marks.TIER_NAMES[t]
		out.append({"key": "zombie:v%d" % v, "type": "zombies", "name": DDText.zombie_title(v), "art_keys": Art.card_keys(DDCard.make(DDCard.ZOMBIE, v)),
			"strength": v, "stat": "%s · %d" % [nm, v], "districts": zdist.get(nm, []),
			"line": ["Slow and weak. Good points on small guns.", "The bulk of every wave.", "Hurts with weak guns; pays %d-%d." % [bal.shown(7), bal.shown(9)], "Only in the worst places."][t]})
	for d2: Variant in ds:
		var dd2: Dictionary = d2
		var b: Dictionary = dd2.get("boss", {})
		var zs: Array = b.get("zombies", [9])
		out.append({"key": "boss:" + str(dd2.get("id", "")), "type": "bosses", "name": str(b.get("name", "")), "art_keys": Art.finale_keys(dd2),
			"strength": int(zs[0]), "stat": DDText.boss_summary(b).replace(" -> ", ", "), "districts": [str(dd2.get("id", ""))],
			"line": "%s boss. %s" % [str(dd2.get("name", "")), {"shatter": "Shatter: the gun that kills it is destroyed (melee is safe).", "horde": "Three arrive at once.",
				"phases": "Three phases, no escape."}.get(str(b.get("trait", "")), "")]})
	for mk: Array in [["Bandage", 3, "heals 3"], ["First Aid Kit", 4, "heals 4-5"], ["Trauma Kit", 6, "heals 6-7"]]:
		out.append({"key": "item:" + Art.slug(str(mk[0])), "type": "items", "name": str(mk[0]), "art_keys": Art.card_keys(DDCard.make(DDCard.MEDKIT, int(mk[1]))),
			"value": int(mk[1]), "badge_kind": "M", "stat": str(mk[2]), "districts": mdist.get(str(mk[0]), []), "line": "Medkit: %s HP. One medkit per street." % str(mk[2]).trim_prefix("heals ")})
	for ck: Array in [["Plywood", 2], ["Car Door", 3], ["Dumpster", 4]]:
		out.append({"key": "item:" + Art.slug(str(ck[0])), "type": "items", "name": str(ck[0]), "art_keys": Art.card_keys(DDCard.make(DDCard.COVER, int(ck[1]))),
			"value": int(ck[1]), "badge_kind": "C", "stat": "+%d Cover" % int(ck[1]), "districts": cdist.get(str(ck[0]), []), "line": "Cover %d: takes damage before your HP." % int(ck[1])})
	for pid: Variant in bal.patches():
		out.append({"key": "patch:" + str(pid), "type": "patches", "name": DDText.patch_name(str(pid)), "art_keys": Art.patch_keys(str(pid)), "art_fit": "contain",
			"stat": "Patch", "districts": all_ids, "line": DDPayloads.patch_line(str(pid), bal)})
	return out


static func _add(d: Dictionary, k: String, id: String) -> void:
	if not d.has(k):
		d[k] = []
	if not (d[k] as Array).has(id):
		(d[k] as Array).append(id)


static func _card_dist(code: String, id: String, mdist: Dictionary, cdist: Dictionary) -> void:
	if code.begins_with("M") and code.length() > 1:
		_add(mdist, DDText.medkit_name(int(code.substr(1))), id)
	elif code.begins_with("C") and code.length() > 1:
		_add(cdist, DDText.cover_name(int(code.substr(1))), id)


## The Codex keys a run has met right now: street cards, equipped guns, Patches (owned or offered),
## the boss on a boss street, and melee.
static func keys_met_by(run: DDRun) -> Array[String]:
	var out: Array[String] = ["melee:bare_hands"]
	if run.has_melee_weapon():
		out.append("melee:" + str(run.melee.get("id", "")))
	var cards: Array = run.street.duplicate()
	var lc: DDCard = run.lookout_card()
	if lc != null:
		cards.append(lc)
	for c: Variant in cards:
		var cc: DDCard = c
		match cc.kind:
			DDCard.ZOMBIE:
				if cc.is_boss():
					out.append("boss:" + str(run.district().get("id", "")))
				else:
					out.append("zombie:" + DDText.zombie_name(cc.value).to_lower())
					out.append("zombie:v%d" % cc.value)
			DDCard.WEAPON:
				out.append("gun:" + cc.wid)
			DDCard.MELEE:
				out.append("melee:" + cc.wid)
			DDCard.MEDKIT:
				out.append("item:" + Art.slug(DDText.medkit_name(cc.value)))
			DDCard.COVER:
				out.append("item:" + Art.slug(DDText.cover_name(cc.value)))
	for s: int in 2:
		if run.slot(s) != null:
			out.append("gun:" + run.slot(s).wid)
	for p: String in run.patches:
		out.append("patch:" + p)
	for p2: Variant in run.pending_patch.get("offer", []):
		out.append("patch:" + str(p2))
	return out


# ================================================================ the frame
func _frame(title: String, sub: String) -> VBoxContainer:
	if _root != null:
		_root.queue_free()
	var vp: Vector2 = get_viewport_rect().size
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root = root
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			close())
	root.add_child(dim)
	var panel: PanelContainer = DDUi.panel(DDUi.BG, 12, DDUi.accent("D").darkened(0.3), 2)
	panel.name = "CodexPanel" if mode == "codex" else "GlossaryPanel"
	var pw: float = minf(vp.x - 16.0, 1100.0)
	panel.position = Vector2((vp.x - pw) * 0.5, 8.0)
	panel.size = Vector2(pw, vp.y - 16.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	DDUi.skin_panel(panel, "overlay", 16)
	root.add_child(panel)
	var v: VBoxContainer = DDUi.vbox(8)
	panel.add_child(v)
	var head: HBoxContainer = DDUi.hbox(8)
	v.add_child(head)
	var tl: Label = DDUi.label(title, DDUi.FONT_L, DDUi.TEXT)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(tl)
	if sub != "":
		var sl: Label = DDUi.label(sub, DDUi.FONT_S - 2, DDUi.TEXT_DIM)
		sl.name = "Count"
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		head.add_child(sl)
	var x: Button = DDUi.button("Close", DDUi.PANEL_HI, DDUi.FONT_S)
	x.name = "CloseOverlay"
	x.custom_minimum_size = Vector2(96, 64)
	x.pressed.connect(close)
	head.add_child(x)
	return v


func _scroll(v: VBoxContainer) -> VBoxContainer:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.name = "Scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	# dd-ux-equip: one-finger drag (on tiles or empty space) and two-finger scroll on touch
	DDTouchScroll.attach(sc).gesture_ended.connect(func() -> void: scrolled.emit())
	var inner: VBoxContainer = DDUi.vbox(8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(inner)
	return inner


func _chip(text: String, on: bool, cb: Callable, nm: String) -> Button:
	var b: Button = DDUi.button(text, DDUi.WARN.darkened(0.45) if on else DDUi.PANEL, DDUi.FONT_S - 3)
	b.name = nm
	b.toggle_mode = false
	b.custom_minimum_size = Vector2(0, 64)
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	if on:
		b.add_theme_stylebox_override("normal", DDUi.box(DDUi.WARN.darkened(0.45), DDUi.WARN, 3, 12, 10))
	# dd-art2-import: painted filter chips (on = gold plate, off = dark slate; bone words with an ink outline:
	# ink on the dark gold reads only 3:1, bone 6.9:1)
	if DDUi.Kit.skin_plate(b, "dd_chip_filter_on" if on else "dd_chip_filter_off", 10.0):
		# the painted corners need room: never narrower than a fat thumb
		b.custom_minimum_size.x = 72.0
		for sn: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var cst: StyleBox = b.get_theme_stylebox(sn)
			cst.content_margin_left = 14.0
			cst.content_margin_right = 14.0
	b.set_meta(&"on", on)
	b.pressed.connect(cb)
	return b


# ================================================================ Codex
func open_codex(bal: DDBalance, profile: DDProfile) -> void:
	_bal = bal
	_profile = profile
	mode = "codex"
	_build_codex()
	visible = true
	opened.emit()


func set_filters(t: String, d: String, met: bool) -> void:
	f_type = t
	f_dist = d
	f_met = met
	if mode == "codex":
		_build_codex.call_deferred()


## The Show all / Hide unmet toggle.
func set_show_all(on: bool) -> void:
	show_all = on
	if mode == "codex":
		_build_codex.call_deferred()


func _build_codex() -> void:
	var all: Array = entries(_bal)
	var met_n: int = 0
	for e: Variant in all:
		if _profile != null and _profile.codex_met(str((e as Dictionary)["key"])):
			met_n += 1
	var v: VBoxContainer = _frame("Codex", "%d of %d met" % [met_n, all.size()])
	var types: HFlowContainer = HFlowContainer.new()
	types.name = "TypeFilters"
	types.add_theme_constant_override("h_separation", 6)
	types.add_theme_constant_override("v_separation", 6)
	v.add_child(types)
	for t: String in TYPES:
		types.add_child(_chip(t.capitalize(), f_type == t, func() -> void: set_filters(t, f_dist, f_met), "Type_" + t))
	var dists: HFlowContainer = HFlowContainer.new()
	dists.name = "DistrictFilters"
	dists.add_theme_constant_override("h_separation", 6)
	dists.add_theme_constant_override("v_separation", 6)
	v.add_child(dists)
	dists.add_child(_chip("All districts", f_dist == "any", func() -> void: set_filters(f_type, "any", f_met), "Dist_any"))
	for d: Variant in _bal.districts():
		var did: String = str((d as Dictionary).get("id", ""))
		dists.add_child(_chip(str((d as Dictionary).get("name", "")), f_dist == did, func() -> void: set_filters(f_type, did, f_met), "Dist_" + did))
	dists.add_child(_chip("Met only", f_met, func() -> void: set_filters(f_type, f_dist, not f_met), "MetOnly"))
	dists.add_child(_chip("Hide unmet" if show_all else "Show all", show_all, func() -> void: set_show_all(not show_all), "ShowAll"))
	var inner: VBoxContainer = _scroll(v)
	var grid: GridContainer = GridContainer.new()
	grid.name = "CodexGrid"
	var vp: Vector2 = get_viewport_rect().size
	var gw: float = minf(vp.x - 16.0, 1100.0) - 24.0 - 12.0
	grid.columns = maxi(2, int(gw / 170.0))
	var tw: float = (gw - 8.0 * (grid.columns - 1)) / grid.columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	inner.add_child(grid)
	shown = []
	for e2: Variant in all:
		var e: Dictionary = e2
		var met: bool = _profile != null and _profile.codex_met(str(e["key"]))
		if f_type != "all" and str(e["type"]) != f_type:
			continue
		if f_dist != "any" and not (e["districts"] as Array).has(f_dist):
			continue
		if f_met and not met:
			continue
		var tile: DDCardView = _codex_tile(e, met or show_all, Vector2(tw, tw * 1.25))
		grid.add_child(tile)
		shown.append({"key": e["key"], "met": met, "revealed": met or show_all, "type": e["type"], "view": tile})
	if shown.is_empty():
		inner.add_child(DDUi.label("Nothing here yet: meet it in a run.", DDUi.FONT_S, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER, true))


func _codex_tile(e: Dictionary, met: bool, sz: Vector2) -> DDCardView:
	var kind: String = str(TYPE_KIND.get(str(e["type"]), "D"))
	var dn: PackedStringArray = []
	for d: Variant in _bal.districts():
		if (e["districts"] as Array).has(str((d as Dictionary).get("id", ""))):
			dn.append(str((d as Dictionary).get("name", "")))
	# dd-capacity: a gun's capacity / a melee weapon's uses are the mark (and the tooltip's mark row), not words
	var t1: String = "%s%s%s" % [str(e["name"]), (" · strength %d" % int(e["hit"])) if e.has("hit") else "",
		"" if (e.has("cap") or e.has("uses")) else " · " + str(e["stat"])]
	var p: Dictionary = {"kind": kind, "title": str(e["name"]), "t1": t1, "t2": str(e["line"])}
	if not met:
		p = {"kind": kind, "title": "???", "t1": "??? · not met yet", "t2": "Meet it in a run to fill this entry."}
	var tex: Texture2D = Art.texture_for(e["art_keys"])
	if met:
		if tex != null:
			p["art"] = tex
		if e.has("hit"):
			p["hit"] = e["hit"]
		for sk: String in ["cap", "uses"]:
			if e.has(sk):
				p[sk] = e[sk]
		if e.has("strength"):
			p["strength"] = e["strength"]
			p["t2"] = "Its number is its attack and its toughness. " + str(e["line"])
		if e.has("value"):
			p["big"] = str(e["value"])
			p["kind"] = str(e.get("badge_kind", kind))
	var v: DDCardView = DDCardView.new()
	v.setup({"kind": kind, "payload": p, "row": true})
	for c: Node in v.get_children():
		v.remove_child(c)
		c.queue_free()
	v.add_theme_stylebox_override("panel", DDUi.box(DDUi.card_bg(kind) if met else Color("343b40"), DDUi.accent(kind) if met else Color("4a5358"), 2, 10, 4))
	if DDUi.Kit.rim(v, DDUi.accent(kind) if met else Color("4a5358"), false, true) != null:
		v.add_theme_stylebox_override("panel", DDUi.Kit.card_body(DDUi.card_bg(kind) if met else Color("343b40"), 4.0, 10.0))
	v.custom_minimum_size = sz
	v.name = "Cx_" + str(e["key"]).replace(":", "_")
	v.set_meta(&"key", str(e["key"]))
	v.set_meta(&"met", met)
	var col: VBoxContainer = DDUi.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(col)
	var win: Control = Control.new()
	win.clip_contents = true
	win.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(win)
	if tex != null:
		var contain: bool = str(e.get("art_fit", "cover")) == "contain"
		var tr: TextureRect = TextureRect.new() if contain else Art.cover_rect(tex)
		if contain:
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not met:
			# a dark silhouette until met
			tr.self_modulate = Color(0.13, 0.13, 0.15, 1.0)
		win.add_child(tr)
		v.art_rect = tr
	if met:
		var mark: Control = null
		if e.has("hit"):
			mark = Marks.HitBurst.new(int(e["hit"]))
		elif e.has("strength"):
			mark = Marks.StrengthMark.new(int(e["strength"]))
		elif e.has("value"):
			mark = Marks.NumBadge.new(int(e["value"]), "item", DDUi.accent(str(e.get("badge_kind", kind))))
		if mark != null:
			mark.name = "NumBadge"
			mark.position = Vector2(3, 3)
			mark.size = Vector2(40, 40)
			win.add_child(mark)
		# dd-capacity: the capacity / uses mark in the opposite corner, as on the street card
		if e.has("cap") or e.has("uses"):
			var sm: Control = Marks.StatMark.new(int(e.get("cap", e.get("uses", 0))), "cap" if e.has("cap") else "uses")
			sm.name = "StatMark"
			win.add_child(sm)
			var place: Callable = func() -> void:
				if is_instance_valid(sm) and win.size.y > 0.0:
					var sh: float = clampf(minf(34.0, win.size.y - 50.0), 22.0, 34.0)
					sm.size = Vector2(float(sm.call("width_for", sh)), sh)
					sm.position = win.size - sm.size - Vector2(3, 3)
			win.resized.connect(place)
	else:
		var q: Label = DDUi.label("?", 40, Color(DDUi.TEXT_DIM, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		win.add_child(q)
	var nl: Label = DDUi.label(str(e["name"]) if met else "???", DDUi.FONT_S - 3, DDUi.TEXT if met else DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.custom_minimum_size = Vector2(10, 0)
	col.add_child(nl)
	var sr: HBoxContainer = DDUi.hbox(4)
	sr.alignment = BoxContainer.ALIGNMENT_CENTER
	sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sr)
	if met and str(e.get("rule", "")) != "":
		var rtex: Texture2D = Art.texture_for(Art.rule_keys(str(e["rule"])))
		if rtex != null:
			var ri: TextureRect = TextureRect.new()
			ri.texture = rtex
			ri.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ri.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ri.custom_minimum_size = Vector2(20, 20)
			sr.add_child(ri)
	sr.add_child(DDUi.label(str(e["stat"]) if met else "", DDUi.FONT_S - 6, DDUi.TEXT_DIM))
	DDUi.ignore_mouse(v)
	v.inspected.connect(func(pl: Dictionary) -> void: inspect_requested.emit(pl))
	v.tapped.connect(func(_x: DDCardView) -> void: inspect_requested.emit(p))
	return v


# ================================================================ Glossary
func open_glossary(bal: DDBalance) -> void:
	_bal = bal
	mode = "glossary"
	var v: VBoxContainer = _frame("Help · Glossary", "")
	var inner: VBoxContainer = _scroll(v)
	for sec: Array in sections(bal):
		var h: Label = DDUi.label(str(sec[0]), DDUi.FONT_S - 4, DDUi.WARN)
		inner.add_child(h)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 2 if get_viewport_rect().size.x > 900.0 else 1
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		inner.add_child(grid)
		for row: Variant in sec[1]:
			grid.add_child(_gloss_row(row as Dictionary))
	visible = true
	opened.emit()


## Glossary sections: [title, [{icon, name, line}...]]. icon: "burst:4", "strength:7", "num:M:4", "rule:down",
## "badge:challenge", "lock", "socket", "chip:-3", "text:HOLD" ...
static func sections(bal: DDBalance) -> Array:
	var rules: Array = []
	# dd-ux-text: each rule by the same tag as the gun tile, then the same words as every tooltip
	for r: Array in [["any", "Service Pistol"], ["down", "Hunting Rifle"], ["up", "Ratchet Crossbow"], ["same", "Twin-Bore"], ["zigzag", "Lever Rifle"],
			["close", "Scout Carbine"], ["parity", "Nail Driver"], ["spread", "Pump Shotgun"], ["big", "Elephant Gun"], ["small", "Alley Sweeper"],
			["heavy", "Stovepipe Launcher"]]:
		var tag: String = DDText.rule_tag(str(r[0]))
		rules.append({"icon": "rule:" + str(r[0]), "name": tag.substr(0, 1) + tag.substr(1).to_lower(), "line": "Each kill: %s (%s)." % [DDText.rule_short(str(r[0])), str(r[1])]})
	rules.append({"icon": "rule:down", "name": "Last or lower / higher", "line": "Rosa's Steady Hands: the Rifle and Crossbow also take an equal number."})
	rules.append({"icon": "rule:bent", "name": "Bent rule", "line": "Loose Grip: once per wave, one kill may break its rule."})
	# dd-challenge-rack: every challenge with its gun, its rule in plain words and an example
	var chals: Array = []
	var ws: Dictionary = bal.weapons()
	for wid: Variant in ws.keys():
		var cid: String = bal.weapon_challenge(str(wid))
		if cid == "":
			continue
		var rw: Array = bal.weapon_reward(str(wid))
		var ct: String = DDText.challenge_text(cid, bal)
		chals.append({"icon": "badge:challenge_open", "name": "%s (%s)" % [DDText.challenge_name(cid), bal.weapon_name(str(wid))],
			"line": "%s%s. Pays %s." % [ct.substr(0, 1).to_upper(), ct.substr(1), DDText.reward_text(str(rw[0]), int(rw[1]), bal)]})
	return [
		["NUMBER BADGES: THE CARD THEY SIT ON AND THEIR SHAPE SAY WHAT", [
			{"icon": "burst:4", "name": "Weapon strength (round badge on a gun or melee card)", "line": "How hard the weapon hits. You lose the zombie's strength minus this in HP. (Yellow fill.)"},
			{"icon": "stat:cap:4", "name": "Capacity (stack of squares, on a gun)", "line": "A gun's kills before it pays out: 4 kills fill it, then +%d and it leaves." % bal.shown(bal.num("finish_bonus"))},
			{"icon": "stat:uses:3", "name": "Uses (stack of dots, on a melee weapon)", "line": "A melee weapon's uses: each kill uses 1; at 0 it breaks."},
			{"icon": "strength:7", "name": "Zombie strength (round badge on a zombie card)", "line": "Its attack and toughness. A gun kill pays it ×10 pts. (Dark red fill.)"},
			{"icon": "tiers", "name": "Tier (the ring around a zombie's badge)", "line": "Shambler 1-3, Lurcher 4-6, Bruiser 7-9, Hulk 10+: the card's name says the tier too."},
			{"icon": "num:M:4", "name": "Heal (round badge on a medkit card)", "line": "A medkit's number: the HP it heals."},
			{"icon": "num:C:3", "name": "Cover (round badge on a cover card)", "line": "A cover card's number: the Cover you gain."},
		]],
		["ON YOUR WEAPONS", [
			{"icon": "socket", "name": "Kill sockets", "line": "One per kill the gun holds; a filled one shows the kill."},
			{"icon": "next", "name": "Next socket", "line": "What the next kill needs: ≤5 means 5 or lower, ≥8 means 8 or higher."},
			{"icon": "badge:full_set", "name": "Full set", "line": "Every socket filled: +%d pts, then the gun leaves. 1 to go: the cup glows." % bal.shown(bal.num("finish_bonus"))},
			{"icon": "badge:challenge_open", "name": "Challenge", "line": "Fill the gun a special way for an extra reward."},
			{"icon": "text:ACTIVE", "name": "Active weapon", "line": "Tap a gun or melee; taps on zombies use it."},
			{"icon": "art:bare_hands", "name": "Bare Hands", "line": "Your melee: any zombie, no points, never breaks."},
			{"icon": "text:+N", "name": "Salvage", "line": "Swap out a gun: it pays part of its kills back."},
			{"icon": "mod:open_breech", "name": "Gun Mod (MOD chip)", "line": "Fitted at the safehouse to gun slot 1 or 2; every gun in that slot gets its rule."},
		]],
		["WEAPON RULES: WHICH ZOMBIE CAN GO ON NEXT", rules],
		["CHALLENGES: FILL THE GUN THIS WAY FOR ITS EXTRA REWARD", chals],
		["ON ZOMBIES", [
			{"icon": "chip:-3", "name": "Damage chip (top corner of a zombie)", "line": "The HP you lose with the active weapon, after Cover. 0 = none; DIES = it ends the run (a tap asks first)."},
			{"icon": "litdark", "name": "Lit / dark", "line": "Lit = the active gun can take it; dark = it can't."},
			{"icon": "text:LOCK", "name": "Rule lock", "line": "The active gun can't take it; the card says what it needs (e.g. needs ≤5)."},
			{"icon": "text:HOLD", "name": "Holdover", "line": "The card you didn't resolve stays for the next street."},
		]],
		["ON THE BOARD", [
			{"icon": "wave", "name": "Wave door", "line": "The big number is the wave now; +N waves wait."},
			{"icon": "lock", "name": "Room price", "line": "Locked until you have the points; the bar fills."},
			{"icon": "open", "name": "Gold plate", "line": "You can pay: tap it to open the room (3 cards + a machine)."},
			{"icon": "text:USE", "name": "USE", "line": "The room's machine, once per wave."},
			{"icon": "pile", "name": "Draw pile", "line": "Cards are dealt from here. The order is hidden."},
			{"icon": "pips", "name": "Resolve dots", "line": "Deal with %d of the %d cards; 1 stays." % [bal.num("actions"), bal.num("street_size")]},
			{"icon": "text:+2", "name": "Cover", "line": "Takes damage before your HP."},
			{"icon": "text:PTS", "name": "Points", "line": "Gun kills pay. Spend them on rooms and machines."},
			{"icon": "text:RUN", "name": "Run", "line": "-%d HP: the street's cards go to the bottom of the pile. Not twice in a row." % bal.num("run_damage")},
			{"icon": "text:SHOP", "name": "Safehouse Shop", "line": "Spend your points before you leave: they stay behind."},
		]],
		["HOW A STREET WORKS", [
			{"icon": "text:1", "name": "Deal", "line": "%d cards come off the pile." % bal.num("street_size")},
			{"icon": "text:2", "name": "Pick a weapon", "line": "Tap a gun (or melee), then tap zombies."},
			{"icon": "text:3", "name": "Fill sockets", "line": "Each gun kill fills a socket and pays its number. The gun's rule says what fits next."},
			{"icon": "text:4", "name": "Fill guns", "line": "A full gun pays +%d and its challenge, then leaves." % bal.shown(bal.num("finish_bonus"))},
			{"icon": "text:5", "name": "Waves, then the boss", "line": "When the pile runs out, the next wave joins it."},
		]],
	]


func _gloss_row(row: Dictionary) -> DDCardView:
	var p: Dictionary = {"kind": "D", "title": str(row["name"]), "t1": str(row["name"]), "t2": str(row["line"])}
	var v: DDCardView = DDCardView.new()
	v.setup({"kind": "D", "payload": p, "row": true})
	for c: Node in v.get_children():
		v.remove_child(c)
		c.queue_free()
	v.add_theme_stylebox_override("panel", DDUi.box(DDUi.PANEL, Color(0, 0, 0, 0), 0, 10, 6))
	v.custom_minimum_size = Vector2(0, 64)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.name = "Gl_" + Art.slug(str(row["name"]))
	var h: HBoxContainer = DDUi.hbox(10)
	v.add_child(h)
	var ic: Control = icon(str(row["icon"]))
	ic.custom_minimum_size = Vector2(52, 48)
	h.add_child(ic)
	var t: VBoxContainer = DDUi.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(t)
	t.add_child(DDUi.label(str(row["name"]), DDUi.FONT_S - 2, DDUi.TEXT))
	t.add_child(DDUi.label(str(row["line"]), DDUi.FONT_S - 5, DDUi.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true))
	DDUi.ignore_mouse(v)
	v.inspected.connect(func(pl: Dictionary) -> void: inspect_requested.emit(pl))
	v.tapped.connect(func(_x: DDCardView) -> void: inspect_requested.emit(p))
	return v


## A badge centred at 42 px (the same size in every Glossary row).
static func _square(b: Control) -> Control:
	var cc: CenterContainer = CenterContainer.new()
	b.custom_minimum_size = Vector2(42, 42)
	cc.add_child(b)
	return cc


## A Glossary icon, drawn with the same marks the game uses.
static func icon(id: String) -> Control:
	var c: Control = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arg: String = id.get_slice(":", 1)
	var inner: Control = null
	match id.get_slice(":", 0):
		"burst":
			inner = _square(Marks.HitBurst.new(int(arg)))
		"stat":
			# dd-capacity: stat:<cap|uses>:<n>, the mark as on the cards
			var smk: Control = Marks.StatMark.new(int(id.get_slice(":", 2)), arg)
			smk.custom_minimum_size = Vector2(float(smk.call("width_for", 34.0)), 34.0)
			var scc: CenterContainer = CenterContainer.new()
			scc.add_child(smk)
			inner = scc
		"strength":
			inner = _square(Marks.StrengthMark.new(int(arg)))
		"tiers":
			var gc: GridContainer = GridContainer.new()
			gc.columns = 2
			gc.add_theme_constant_override("h_separation", 2)
			gc.add_theme_constant_override("v_separation", 2)
			for v: int in [2, 5, 8, 11]:
				var m: Control = Marks.StrengthMark.new(v)
				m.custom_minimum_size = Vector2(23, 23)
				gc.add_child(m)
			var tc: CenterContainer = CenterContainer.new()
			tc.add_child(gc)
			inner = tc
		"num":
			# dd-polish5: an item badge, num:<kind>:<value>
			var nb: Control = Marks.NumBadge.new(int(id.get_slice(":", 2)), "item", DDUi.accent(arg))
			inner = _square(nb)
		"art":
			var tra: TextureRect = TextureRect.new()
			tra.texture = Art.texture_for(DDV4Hooks.melee_art_keys("", "Bare Hands"))
			tra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tra.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			inner = tra
		"mod":
			# dd-mods-import: a Gun Mod badge (text "MOD" when it is not painted)
			var mtr: TextureRect = Art.mod_badge(arg, 40.0)
			if mtr != null:
				inner = mtr
			else:
				var lm: Label = DDUi.label("MOD", DDUi.FONT_S - 4, DDUi.WARN, HORIZONTAL_ALIGNMENT_CENTER)
				lm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				inner = lm
		"rule", "badge":
			var tr: TextureRect = TextureRect.new()
			tr.texture = Art.texture_for(Art.rule_keys(arg) if id.begins_with("rule") else Art.badge_keys(arg))
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			inner = tr
		"litdark":
			# dd-art-fit: a lit zombie (gun-yellow rim) beside a dark one
			var hl: HBoxContainer = DDUi.hbox(3)
			hl.alignment = BoxContainer.ALIGNMENT_CENTER
			for lit: bool in [true, false]:
				var pz: PanelContainer = PanelContainer.new()
				var sb: StyleBoxFlat = DDUi.box(DDUi.card_bg("Z"), DDUi.WARN if lit else DDUi.accent("Z").darkened(0.5), 2, 4, 2)
				if lit:
					sb.shadow_color = Color(DDUi.WARN, 0.45)
					sb.shadow_size = 3
				pz.add_theme_stylebox_override("panel", sb)
				pz.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var sm: Control = Marks.StrengthMark.new(5)
				sm.custom_minimum_size = Vector2(18, 18)
				pz.add_child(sm)
				if not lit:
					pz.modulate = Color(0.45, 0.45, 0.45)
				hl.add_child(pz)
			inner = hl
		"socket", "next":
			inner = Marks.Socket.new(id == "next", "≤5" if id == "next" else "")
		"lock", "open":
			inner = Marks.Padlock.new(id == "open", DDUi.WARN if id == "open" else DDUi.TEXT)
		"wave":
			inner = Marks.WaveNumeral.new("2")
		"pile":
			var tr2: TextureRect = TextureRect.new()
			tr2.texture = Art.texture_for(Art.deck_back_keys("pile"))
			tr2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			inner = tr2
		"pips":
			var hp: HBoxContainer = DDUi.hbox(3)
			hp.alignment = BoxContainer.ALIGNMENT_CENTER
			for k: int in 3:
				var dot: Panel = Panel.new()
				dot.custom_minimum_size = Vector2(12, 12)
				dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				dot.add_theme_stylebox_override("panel", DDUi.box(DDUi.SELECT if k == 0 else Color(0, 0, 0, 0), DDUi.SELECT if k == 0 else DDUi.TEXT_DIM, 2, 6, 0))
				hp.add_child(dot)
			inner = hp
		"chip":
			var pc: PanelContainer = DDUi.tag(arg, "red", DDUi.FONT_S - 2, DDUi.BAD)
			var cc: CenterContainer = CenterContainer.new()
			cc.add_child(pc)
			inner = cc
		_:
			var l2: Label = DDUi.label(arg, DDUi.FONT_S - 4 if arg.length() > 2 else DDUi.FONT_M, DDUi.WARN, HORIZONTAL_ALIGNMENT_CENTER)
			l2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			inner = l2
	if inner != null:
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(inner)
	return c
