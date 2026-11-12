# dd_payloads.gd
# Purpose: Builds the tile specs and zoom payloads (long press / right click) for every v3 board
#   element: street cards (with the ACTIVE weapon's damage chip or the rule lock), guns and their
#   kill stacks, melee, wave decks, the boss, the draw pile (and Lookout), room decks / machines,
#   Patches, survivors, HP / Cover / points, unlocks, how to play. Clarity over information: a
#   tile shows what this tap needs; the zoom has the rest.
#   dd-ux-v4 (head's M3 b): every payload carries a 2-line tooltip, "t1" (bold: what it is and
#   its numbers now) and "t2" (plain: what it does for you), each under about 70 characters.
#   The inspect overlay shows only those two lines; the full rules live in the Glossary and the
#   Codex. "body" stays as the long form (the history list, tests); it is not shown as a tooltip.
# Dependencies: DDRun, DDCard, DDGun, DDText, DDUi, DDBalance, DDProfile.
# Author: Mechanics Developer Agent
class_name DDPayloads
extends RefCounted

const Art: GDScript = preload("res://scripts/ui/dd_art.gd")


## dd-ux-v4: sets the 2-line tooltip on a payload and returns it.
static func tip(p: Dictionary, t1: String, t2: String) -> Dictionary:
	p["t1"] = t1
	p["t2"] = t2
	return p


static func _short_name(n: String) -> String:
	# "Hunting Rifle" -> "Rifle", "Ratchet Crossbow" -> "Crossbow" (tooltip lines stay short)
	var parts: PackedStringArray = n.split(" ")
	return parts[parts.size() - 1] if parts.size() > 1 and n.length() > 10 else n


## dd-ux-v4: what the next kill socket accepts ("≤5", "≥8", "=5", "odd", "4-6", "any", "none").
## dd-ux-text: the one notation lives in DDText (need_tag / need_words).
static func accept_tag(zs: Array[int]) -> String:
	return DDText.need_tag(zs)


## The same for a tooltip: "≤5", "≥8", "exactly 5", "an odd number", "any zombie".
static func accept_words(zs: Array[int]) -> String:
	return DDText.need_words(zs)


static func _weapon_label(run: DDRun, w: int) -> String:
	if w == DDRun.MELEE:
		return "Melee"
	var g: DDGun = run.slot(w)
	return g.name if g != null else "Slot %d" % (w + 1)


# ---------------------------------------------------------------- street cards
## Zoom for a street card. Zombies: damage with each weapon and which gun rules allow it.
static func card(c: DDCard, run: DDRun, index: int = -1) -> Dictionary:
	var b: DDBalance = run.bal
	if c.kind == DDCard.MELEE:
		# v4: a melee weapon card (Pipe Wrench, Fire Axe, Sledgehammer)
		var mp: Dictionary = DDV4Hooks.melee_card(c, run, index)
		mp["hit"] = b.melee_power(c.wid)
		mp["art_keys"] = DDV4Hooks.melee_art_keys(c.wid, b.melee_name(c.wid))
		return mp
	var body: PackedStringArray = []
	match c.kind:
		DDCard.ZOMBIE:
			body.append("Strength %d: its attack and its toughness. You lose %d minus your hit. A gun kill pays %d pts." % [c.value, c.value, b.shown(c.value)])
			if c.is_boss():
				body.append("%s (%s): %s" % [c.boss_name, DDText.trait_name(c.boss_trait), DDText.trait_text(c.boss_trait)])
			var verdict: String = gun_verdict(c, run, index)
			if verdict != "":
				body.append(verdict + ".")
			for w: int in 3:
				if w != DDRun.MELEE and run.slot(w) == null:
					continue
				var pr: Dictionary = run.preview(index, w) if index >= 0 else {}
				var p: int = run.power_of(w)
				var line: String = "%s (hit %d): %s" % [_weapon_label(run, w), p, ("-%d HP" % maxi(0, c.value - p)) if maxi(0, c.value - p) > 0 else "no damage"]
				if not pr.is_empty() and not bool(pr["ok"]):
					line += " - NO: %s" % str(pr["reason"])
				elif not pr.is_empty() and bool(pr["uses_loose"]):
					line += " - Loose Grip breaks the rule"
				elif not pr.is_empty() and bool(pr["finishes"]):
					line += " - fills the gun"
				body.append(line)
			body.append("Damage = strength - hit. Cover takes it first.")
		DDCard.WEAPON:
			body.append(DDText.gun_card_text(c.wid, b, run.steady()))
			body.append("Tap: equip it (a free slot first), or scrap it for %d pts." % b.shown(b.num("scrap_points")))
		DDCard.MEDKIT:
			body.append("Heal %d%s." % [run.medkit_heal(c), " (one medkit per street)" if b.num("medkits_per_street") == 1 else ""])
		DDCard.COVER:
			body.append("+%d Cover: it takes damage before your HP." % c.value)
	if c.holdover:
		body.append("HOLDOVER: left from the last street.")
	var art_big: String = str(c.value) if c.kind != DDCard.WEAPON else "P%d" % b.weapon_power(c.wid)
	var p: Dictionary = {"art_keys": Art.card_keys(c, str(run.district().get("id", ""))), "kind": "F" if c.is_boss() else c.kind, "tag": DDText.kind_label(c.kind) if not c.is_boss() else "BOSS - " + DDText.trait_name(c.boss_trait).to_upper(),
		"title": DDText.card_name(c, b), "big": art_big, "body": "\n".join(body)}
	if c.kind == DDCard.ZOMBIE:
		p["strength"] = c.value
	elif c.kind == DDCard.WEAPON:
		p["hit"] = b.weapon_power(c.wid)
	return tip(p, card_t1(c, run), card_t2(c, run, index))


static func card_t1(c: DDCard, run: DDRun) -> String:
	var b: DDBalance = run.bal
	match c.kind:
		DDCard.ZOMBIE:
			return "%s · strength %d (attack and toughness)" % [DDText.card_name(c, b), c.value]
		DDCard.WEAPON:
			return "%s · hits %d · holds %d" % [b.weapon_name(c.wid), b.weapon_power(c.wid), b.weapon_cap(c.wid)]
		DDCard.MEDKIT:
			return "%s · heals %d" % [DDText.card_name(c, b), run.medkit_heal(c)]
		DDCard.COVER:
			return "%s · +%d Cover" % [DDText.card_name(c, b), c.value]
	return DDText.card_name(c, b)


static func card_t2(c: DDCard, run: DDRun, index: int) -> String:
	var b: DDBalance = run.bal
	match c.kind:
		DDCard.ZOMBIE:
			var w: int = run.active
			var who: String = "Melee" if w == DDRun.MELEE else _short_name(_weapon_label(run, w))
			var pr: Dictionary = run.preview(index, w) if index >= 0 else {}
			var mel: int = maxi(0, c.value - run.melee_power())
			var vd: String = gun_verdict(c, run, index)
			if vd == "":
				vd = who
			if not pr.is_empty() and not bool(pr["ok"]) and w != DDRun.MELEE and run.slot(w) != null:
				return "%s. Melee: %s." % [vd, ("-%d HP" % mel) if mel > 0 else "no damage"]
			var dmg: int = maxi(0, c.value - run.power_of(w))
			if w == DDRun.MELEE or run.slot(w) == null:
				return "Melee: %s, no points." % [("-%d HP" % mel) if mel > 0 else "no damage"]
			var g: DDGun = run.slot(w)
			var hurt: String = ("-%d HP" % dmg) if dmg > 0 else "no damage"
			var s: String = "%s: %s, +%d pts (kill %d of %d)." % [vd, hurt, b.shown(c.value), g.stack.size() + 1, g.cap]
			if c.is_boss():
				s = "%s: %s. %s" % [vd, hurt, DDText.trait_name(c.boss_trait)]
			return s
		DDCard.WEAPON:
			return "Each kill: %s. Tap: equip, or scrap (+%d)." % [_rule_words(b.weapon_rule(c.wid), run.steady()), b.shown(b.num("scrap_points"))]
		DDCard.MEDKIT:
			return "You have %d/%d HP. Tap to heal." % [run.hp, run.max_hp]
		DDCard.COVER:
			return "Cover takes damage before your HP."
	return ""


## dd-ux-text: the rule in words, after "Each kill:" (one notation: DDText.rule_short).
static func _rule_words(rule: String, rosa: bool) -> String:
	return DDText.rule_short(rule, rosa)


static func street_card_spec(c: DDCard, i: int, run: DDRun) -> Dictionary:
	var b: DDBalance = run.bal
	if c.kind == DDCard.MELEE:
		var ms: Dictionary = DDV4Hooks.melee_card_spec(c, i, run)
		ms["hit"] = b.melee_power(c.wid)
		ms["lines"] = [[DDText.uses_text(int(ms.get("uses", 0))) + " · melee", DDUi.accent("K"), DDUi.FONT_S]]
		ms["payload"] = card(c, run, i)
		return ms
	var lines: Array = []
	var badge: String = ""
	var badge_color: Color = DDUi.WARN
	var dim_art: bool = false
	var lock: String = ""
	match c.kind:
		DDCard.ZOMBIE:
			var pr: Dictionary = run.preview(i, run.active)
			if bool(pr["ok"]):
				var loss: int = int(pr["hp_loss"])
				badge = ("-%d" % loss) if loss > 0 else "0"
				badge_color = DDUi.BAD if loss > 0 else DDUi.GOOD
				if bool(pr["dies"]):
					badge = "-%d DIES" % loss
				var extra: String = ""
				if run.active != DDRun.MELEE:
					extra = "+%d pts" % b.shown(int(pr["points"])) if int(pr["points"]) > 0 else ""
					if bool(pr["finishes"]):
						extra += " FINISH"
					if bool(pr["uses_loose"]):
						extra = "BENT RULE " + extra
				else:
					extra = "0 pts"
				if int(pr["absorbed"]) > 0:
					extra = ("Cover %d  " % int(pr["absorbed"])) + extra
				lines.append([extra.strip_edges() if extra.strip_edges() != "" else "kill", DDUi.GOOD if loss == 0 else DDUi.TEXT, DDUi.FONT_S])
			else:
				lock = str(pr["reason"])
				badge = "LOCK"
				badge_color = DDUi.TEXT_DIM
				dim_art = true
				lines.append([lock, DDUi.WARN, DDUi.FONT_S - 1])
		DDCard.WEAPON:
			# dd-ux-v4: the hit burst shows the power; the line names the rule and the capacity
			lines.append([DDText.rule_tag(b.weapon_rule(c.wid), run.steady()), DDUi.accent("W"), DDUi.FONT_S - 3])
		DDCard.MEDKIT:
			var pm: Dictionary = run.card_preview(i, DDRun.USE)
			if bool(pm["wasted"]):
				dim_art = true
				badge = "DISCARD"
				lines.append(["%d medkit per street" % b.num("medkits_per_street"), DDUi.WARN, DDUi.FONT_S])
			elif int(pm["heal"]) <= 0:
				dim_art = true
				badge = "FULL HP"
				lines.append(["heals 0", DDUi.WARN, DDUi.FONT_S])
			else:
				lines.append(["+%d HP" % int(pm["heal"]), DDUi.GOOD, DDUi.FONT_S])
		DDCard.COVER:
			lines.append(["+%d Cover" % c.value, DDUi.COVER, DDUi.FONT_S])
	if c.is_boss() and badge == "":
		badge = DDText.trait_name(c.boss_trait).to_upper()
		badge_color = DDUi.accent("F")
	# dd-ux-clean: no kind label on the tile (the art and the colour say it; the zoom has it)
	var tag: String = ""
	if c.is_boss():
		tag = "BOSS" if c.phase == 0 else "PHASE %d" % c.phase
	elif c.holdover:
		tag = "HOLDOVER"
	var spec: Dictionary = {"kind": "F" if c.is_boss() else c.kind, "tag": tag, "badge": badge, "badge_color": badge_color, "badge_size": DDUi.FONT_M,
		"big": str(c.value) if c.kind != DDCard.WEAPON else "", "title": DDText.card_name(c, b), "lines": lines,
		"art_dim": dim_art, "lock": lock, "payload": card(c, run, i)}
	# dd-ux-v4: zombies (and bosses) show the strength mark, guns the hit burst
	if c.kind == DDCard.ZOMBIE:
		spec["strength"] = c.value
		# dd-art-fit (head: the rule chips read like a special ability): no chip on zombies. With a
		# gun active, the zombies it can take are LIT (a rim in the gun's yellow) and the rest are
		# dark (art_dim + the LOCK line, as before); with melee active every zombie looks normal.
		# The yes / no in words is in the zombie's tooltip (card_t2).
		var ga: DDGun = run.slot(run.active) if run.active != DDRun.MELEE else null
		if ga != null and bool(run.preview(i, run.active)["ok"]):
			spec["lit"] = true
	elif c.kind == DDCard.WEAPON:
		spec["hit"] = b.weapon_power(c.wid)
		spec["rule_chip"] = weapon_rule_chip(c.wid, b, run.steady())
	return spec


## dd-art-fit: the active gun's yes / no for a street zombie, in words (it replaced the rule chip):
## "Rifle takes it" / "Rifle: needs ≤3" (the same words as the LOCK line and the toast).
## "" with melee active, an empty slot or no street index.
static func gun_verdict(c: DDCard, run: DDRun, index: int) -> String:
	if index < 0 or run.active == DDRun.MELEE:
		return ""
	var g: DDGun = run.slot(run.active)
	if g == null:
		return ""
	var pr: Dictionary = run.preview(index, run.active)
	if bool(pr["ok"]):
		return "%s takes it" % _short_name(g.name)
	var why: String = str(pr["reason"])
	if not run.gun_allows(g, c.value):
		why = DDText.rule_block(g, c.value, run)
	return "%s: %s" % [_short_name(g.name), why]


## dd-ui6: a street gun card's own rule, as the same chip (no verdict).
static func weapon_rule_chip(wid: String, b: DDBalance, rosa: bool = false) -> Dictionary:
	var rule: String = b.weapon_rule(wid)
	var p: Dictionary = tip({"kind": "W", "tag": "RULE", "title": DDText.rule_tag(rule, rosa), "icon_keys": Art.rule_keys(rule)},
		"%s · %s" % [b.weapon_name(wid), DDText.rule_tag(rule, rosa)], "Each kill: %s." % _rule_words(rule, rosa))
	return {"tex": Art.texture_for(Art.rule_keys(rule)), "state": -1, "payload": p}


# ---------------------------------------------------------------- guns
## A gun definition zoom (street gun card, Wall Rack).
static func gun_def(wid: String, bal: DDBalance, tag: String = "GUN", rosa: bool = false) -> Dictionary:
	var rw: Array = bal.weapon_reward(wid)
	return tip({"kind": "W", "tag": tag, "title": bal.weapon_name(wid), "big": "P%d" % bal.weapon_power(wid), "hit": bal.weapon_power(wid),
		"body": DDText.gun_card_text(wid, bal, rosa), "icon_row": gun_icon_row(bal, bal.weapon_rule(wid), wid, rosa, "open")},
		"%s · hits %d · holds %d" % [bal.weapon_name(wid), bal.weapon_power(wid), bal.weapon_cap(wid)],
		"Each kill: %s. Full: +%d, %s." % [_rule_words(bal.weapon_rule(wid), rosa), bal.shown(bal.num("finish_bonus")), DDText.reward_short(str(rw[0]), int(rw[1]), bal)])


static func _range_text(zs: Array[int]) -> String:
	if zs.is_empty():
		return "nothing"
	var parts: PackedStringArray = []
	var a: int = zs[0]
	var prev: int = zs[0]
	for k: int in range(1, zs.size() + 1):
		var z: int = zs[k] if k < zs.size() else -99
		if z == prev + 1:
			prev = z
			continue
		parts.append(str(a) if a == prev else "%d-%d" % [a, prev])
		a = z
		prev = z
	return ", ".join(parts)


static func gun(run: DDRun, s: int) -> Dictionary:
	var g: DDGun = run.slot(s)
	if g == null:
		return tip({"kind": "W", "tag": "GUN SLOT %d" % (s + 1), "title": "Empty slot", "big": "",
			"body": "Tap a gun card on the street, or buy one at a Wall Rack. Melee is always there."},
			"Gun slot %d · empty" % (s + 1), "Equip a gun from the street, or buy one at a Wall Rack.")
	var b: DDBalance = run.bal
	var body: PackedStringArray = []
	var rw: Array = b.weapon_reward(g.wid)
	body.append("Hits %d%s. %d of %d kills%s." % [g.power, " (Honed)" if g.honed else "", g.stack.size(), g.cap,
		(", total %d of %d" % [g.total(), b.num("spread_cap")]) if g.rule == "spread" else ""])
	body.append("%s%s" % [DDText.rule_text(g.rule, b, run.steady()), " (Flipped at the Retrofit Bench)" if g.flipped else ""])
	body.append("Next kill: %s." % accept_words(run.can_take(g)))
	body.append("CHALLENGE %s: %s -> %s. Now: %s." % [DDText.challenge_name(b.weapon_challenge(g.wid)).to_upper(), DDText.challenge_text(b.weapon_challenge(g.wid), b),
		DDText.reward_text(str(rw[0]), int(rw[1]), b), str({"met": "met", "on_track": "on track", "broken": "can't be met any more", "open": "not decided yet"}[run.challenge_state(g)])])
	body.append("Kills: %s." % (DDText.zombie_list(g.stack) if not g.stack.is_empty() else "none yet"))
	body.append("Each kill pays its number. Full: +%d, the challenge pays, the gun leaves." % b.shown(b.num("finish_bonus")))
	body.append("ACTIVE: taps on zombies use it." if run.active == s else "Tap to make it active.")
	var p: Dictionary = {"kind": "W", "tag": "GUN %d%s" % [s + 1, " - ACTIVE" if run.active == s else ""], "title": g.name, "big": "P%d" % g.power, "hit": g.power, "body": "\n".join(body),
		"art_keys": Art.weapon_keys(g.wid, g.name)}
	p["icon_row"] = gun_icon_row(b, g.rule, g.wid, run.steady(), run.challenge_state(g))
	var nxt: String = "Full." if g.kills_left() <= 0 else "Next kill: %s." % accept_words(run.can_take(g))
	return tip(p, "%s · hits %d · %d of %d kills" % [g.name, g.power, g.stack.size(), g.cap],
		"%s Full: +%d, %s." % [nxt, b.shown(b.num("finish_bonus")), DDText.reward_short(str(rw[0]), int(rw[1]), b)])


static func stack_card(run: DDRun, s: int, k: int) -> Dictionary:
	var g: DDGun = run.slot(s)
	var z: int = g.stack[k]
	return tip({"kind": "Z", "tag": "KILL %d ON %s" % [k + 1, g.name.to_upper()], "title": "Zombie %d" % z, "big": str(z), "strength": z,
		"art_keys": Art.card_keys(DDCard.make(DDCard.ZOMBIE, z)),
		"body": "Kill %d of %d on the %s (paid %d pts).%s" % [k + 1, g.cap, g.name, run.bal.shown(z),
			"\nThe LAST kill: the rule checks the next kill against it." if k == g.stack.size() - 1 else ""]},
		"Kill %d · %s %d" % [k + 1, DDText.zombie_name(z), z],
		"Paid +%d pts.%s" % [run.bal.shown(z), " The next kill is checked against it." if k == g.stack.size() - 1 else ""])


## The gun card tile: stats and rule on the left, the kill stack on the right.
static func gun_spec(run: DDRun, s: int) -> Dictionary:
	var g: DDGun = run.slot(s)
	var spec: Dictionary = {"kind": "W", "slot": s, "active": run.active == s, "payload": gun(run, s)}
	if g == null:
		spec["empty"] = true
		return spec
	var b: DDBalance = run.bal
	var rw: Array = b.weapon_reward(g.wid)
	spec["name"] = g.name
	spec["wid"] = g.wid
	spec["power"] = g.power
	spec["cap"] = g.cap
	spec["rule"] = g.rule
	spec["rule_text"] = DDText.rule_tag(g.rule, run.steady())
	spec["challenge"] = DDText.challenge_name(b.weapon_challenge(g.wid))
	spec["reward"] = DDText.reward_short(str(rw[0]), int(rw[1]), b)
	spec["challenge_state"] = run.challenge_state(g)
	spec["stack"] = g.stack.duplicate()
	spec["honed"] = g.honed
	spec["flipped"] = g.flipped
	spec["left"] = g.kills_left()
	spec["can_take"] = _range_text(run.can_take(g))
	spec["accept"] = accept_tag(run.can_take(g))
	spec["finish_shown"] = b.shown(b.num("finish_bonus"))
	spec["plate_payload"] = full_plate(run, s)
	spec["reward_kind"] = str(rw[0])
	var stack_payloads: Array = []
	for k: int in g.stack.size():
		stack_payloads.append(stack_card(run, s, k))
	spec["stack_payloads"] = stack_payloads
	return spec


## dd-ui6: the icon key a gun's tooltip shows under its two lines: its rule, the Full set bonus
## and its challenge reward, with the same glyphs as the gun tile.
static func gun_icon_row(b: DDBalance, rule: String, wid: String, rosa: bool, cs: String) -> Array:
	var rw: Array = b.weapon_reward(wid)
	return [
		{"keys": Art.rule_keys(rule), "text": DDText.rule_tag(rule, rosa)},
		{"keys": Art.badge_keys("full_set"), "text": "Full +%d" % b.shown(b.num("finish_bonus")), "color": DDUi.accent("X")},
		{"keys": Art.badge_keys("challenge" if cs in ["met", "on_track"] else "challenge_open"), "text": "%s %s" % [DDText.challenge_name(b.weapon_challenge(wid)), DDText.reward_short(str(rw[0]), int(rw[1]), b)]},
	]


## dd-ui6: the Full set plate on a gun tile (the completion bonus): fill every socket for the
## finish bonus, plus the challenge reward when its challenge holds.
static func full_plate(run: DDRun, s: int) -> Dictionary:
	var g: DDGun = run.slot(s)
	var b: DDBalance = run.bal
	var rw: Array = b.weapon_reward(g.wid)
	var cs: String = run.challenge_state(g)
	var left: int = g.kills_left()
	var now: String = {"met": "met", "on_track": "on track", "broken": "missed", "open": "open"}.get(cs, "")
	return tip({"kind": "W", "tag": "FULL SET", "title": "Full set", "icon_keys": Art.badge_keys("full_set"),
		"body": "Fill all %d sockets: +%d pts, then the gun leaves. Challenge %s: %s -> %s." % [g.cap, b.shown(b.num("finish_bonus")),
			DDText.challenge_name(b.weapon_challenge(g.wid)).to_upper(), DDText.challenge_text(b.weapon_challenge(g.wid), b), DDText.reward_text(str(rw[0]), int(rw[1]), b)]},
		"Full set: +%d pts · %s" % [b.shown(b.num("finish_bonus")), ("%d kill%s to go" % [left, "" if left == 1 else "s"]) if left > 0 else "full"],
		"Challenge %s %s: %s." % [DDText.challenge_name(b.weapon_challenge(g.wid)), DDText.reward_short(str(rw[0]), int(rw[1]), b), now])


## dd-ux-v4 + v4 rules: the melee slot's zoom is DDV4Hooks.melee (Bare Hands or the melee weapon
## you hold), with the hit burst and the art for the tooltip.
static func melee(run: DDRun) -> Dictionary:
	var p: Dictionary = DDV4Hooks.melee(run)
	p["hit"] = run.melee_power()
	p["art_keys"] = DDV4Hooks.melee_art_keys(str(run.melee.get("id", "")) if run.has_melee_weapon() else "", run.melee_name())
	return p



# ---------------------------------------------------------------- left column: waves + boss
static func wave(run: DDRun, w: int) -> Dictionary:
	var zs: Array[int] = run.bal.wave_zombies(run.district_index, w)
	var spec: Array = run.bal.wave_spec(run.district_index, w)
	var guns: int = 0
	for code: Variant in spec:
		if typeof(code) == TYPE_STRING and str(code).begins_with("W"):
			guns += 1
	var st: String = run.wave_status(w)
	var sorted: Array[int] = zs.duplicate()
	sorted.sort()
	return tip({"kind": "D", "tag": "WAVE %d - %s" % [w + 1, st.to_upper()], "title": "Wave %d deck" % (w + 1), "big": str(spec.size()),
		"body": "%d cards: zombies %s + %d gun%s.\n%s\nThe numbers are known; only the order is hidden. Each open room adds 1 card per wave." % [
			spec.size(), DDText.zombie_list(sorted), guns, "" if guns == 1 else "s",
			{"done": "Already in the pile.", "active": "In the pile now.", "waiting": "Joins the pile when the pile runs out."}[st]]},
		"Wave %d · %d cards · %s" % [w + 1, spec.size(), {"done": "done", "active": "in the pile", "waiting": "waiting"}[st]],
		"Zombies %s. It joins the pile when the pile runs out." % DDText.zombie_range(zs))


static func wave_spec(run: DDRun, w: int) -> Dictionary:
	var zs: Array[int] = run.bal.wave_zombies(run.district_index, w)
	var st: String = run.wave_status(w)
	var n: int = run.bal.wave_spec(run.district_index, w).size()
	return {"kind": "D", "tag": "W%d" % (w + 1), "badge": {"done": "DONE", "active": "IN PILE", "waiting": ""}[st],
		"badge_color": DDUi.TEXT_DIM if st == "done" else DDUi.GOOD, "title": "%d cards" % n,
		"lines": [["zombies %s" % DDText.zombie_range(zs), DDUi.TEXT_DIM, DDUi.FONT_S - 4]], "row": true, "dim": st == "done",
		"selected": st == "active", "payload": wave(run, w)}


## dd-ux-clean: every wave deck in one zoom (the board shows them as one stack).
static func waves(run: DDRun) -> Dictionary:
	var parts: PackedStringArray = []
	for w: int in run.wave_count():
		var zs: Array[int] = run.bal.wave_zombies(run.district_index, w)
		var sorted: Array[int] = zs.duplicate()
		sorted.sort()
		var st: String = run.wave_status(w)
		parts.append("WAVE %d (%s): %d cards, zombies %s." % [w + 1, {"done": "done", "active": "in the pile now", "waiting": "waiting"}[st],
			run.bal.wave_spec(run.district_index, w).size(), DDText.zombie_list(sorted)])
	parts.append("When the pile runs out, the next wave joins it. After the last wave: the boss. The numbers are known; only the order is hidden.")
	var n: int = waves_waiting(run)
	var t2: String = "Boss next, when the pile runs out."
	for w2: int in run.wave_count():
		if run.wave_status(w2) == "waiting":
			t2 = "Next wave: %d cards, zombies %s. Then %s." % [run.bal.wave_spec(run.district_index, w2).size(),
				DDText.zombie_range(run.bal.wave_zombies(run.district_index, w2)), "the boss" if n == 1 else "%d more" % (n - 1)]
			break
	return tip({"kind": "D", "tag": "WAVES - %s" % str(run.district().get("name", "")).to_upper(), "title": "Wave %d of %d" % [mini(run.wave_index + 1, run.wave_count()), run.wave_count()],
		"big": str(n), "body": "\n".join(parts)},
		("Boss street · %s" % str(run.district().get("name", ""))) if run.boss_street else ("Wave %d of %d · %d waiting" % [mini(run.wave_index + 1, run.wave_count()), run.wave_count(), n]), t2)


static func waves_waiting(run: DDRun) -> int:
	var n: int = 0
	for w: int in run.wave_count():
		if run.wave_status(w) == "waiting":
			n += 1
	return n


## The wave stack tile: how many decks wait, and the next threat only.
static func waves_spec(run: DDRun) -> Dictionary:
	var n: int = waves_waiting(run)
	var nxt: String = "boss next"
	for w: int in run.wave_count():
		if run.wave_status(w) == "waiting":
			nxt = "next: %s" % DDText.zombie_range(run.bal.wave_zombies(run.district_index, w))
			break
	return {"kind": "D", "tag": "WAVE %d/%d" % [mini(run.wave_index + 1, run.wave_count()), run.wave_count()], "big": "×%d" % n, "big_size": 34,
		"compact": true, "lines": [[nxt, DDUi.TEXT, DDUi.FONT_S - 3]], "dim": n == 0, "payload": waves(run)}


static func boss(run: DDRun) -> Dictionary:
	var b: Dictionary = run.boss_def()
	var final: bool = run.is_final_district()
	var zs: Array = b.get("zombies", [9])
	return tip({"kind": "F", "tag": "BOSS - %s" % DDText.trait_name(str(b.get("trait", ""))).to_upper(), "title": str(b.get("name", "")),
		"big": DDText.boss_summary(b), "strength": int(zs[0]), "art_keys": Art.finale_keys(run.district()),
		"body": "%s\n%s\nComes after the last wave, with the Holdover. Resolve every card.\n%s" % [
			DDText.boss_summary(b), DDText.trait_text(str(b.get("trait", ""))),
			"NO ESCAPE: no Run, no Run past." if final else "Run past: -%d HP, no reward (+%d pts and a free Patch)." % [run.bal.num("boss_runpast_damage"), run.bal.shown(run.bal.num("boss_reward_points"))]]},
		"%s · strength %s" % [str(b.get("name", "")), DDText.boss_summary(b).replace(" -> ", ", then ")] + (" · ×%d" % zs.size() if zs.size() > 1 and str(b.get("trait", "")) != "phases" else ""),
		"After the last wave. %s" % ("No escape." if final else "Run past: -%d HP, no reward." % run.bal.num("boss_runpast_damage")))


static func boss_spec(run: DDRun) -> Dictionary:
	var b: Dictionary = run.boss_def()
	var zs: Array = b.get("zombies", [9])
	# dd-ux-clean: the tile shows the first number, the name and "x3" for a horde; phases and the
	# trait are in the zoom
	var lines: Array = []
	if zs.size() > 1 and str(b.get("trait", "")) != "phases":
		lines.append(["x%d at once" % zs.size(), DDUi.TEXT_DIM, DDUi.FONT_S - 4])
	return {"kind": "F", "tag": "BOSS" if not run.is_final_district() else "NO ESCAPE", "big": str(int(zs[0])), "big_size": 34,
		"title": str(b.get("name", "")), "title_fit": true, "compact": true, "lines": lines, "payload": boss(run)}


# ---------------------------------------------------------------- middle: the pile
static func pile(run: DDRun) -> Dictionary:
	var cnt: Dictionary = run.pile_counts()
	var zs: Dictionary = cnt["Z"]
	var keys: Array = zs.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k: Variant in keys:
		parts.append("%d x%d" % [int(k), int(zs[k])])
	var body: String = "%d cards, shuffled (counts, not order):\nZombies: %s\nGuns %d, medkits %d, cover %d." % [run.pile.size(),
		", ".join(parts) if not parts.is_empty() else "none", int(cnt["W"]), int(cnt["M"]), int(cnt["C"])]
	body += "\nWhen it runs out, the next wave joins it."
	var lc: DDCard = run.lookout_card()
	if lc != null:
		body += "\nLOOKOUT: the top card is %s %d." % [DDText.card_name(lc, run.bal), lc.value]
	var items: int = int(cnt["M"]) + int(cnt["C"])
	return tip({"kind": "D", "tag": "DRAW PILE", "title": "Draw pile", "big": str(run.pile.size()), "body": body, "art_keys": Art.deck_back_keys("pile")},
		"Draw pile · %d card%s" % [run.pile.size(), "" if run.pile.size() == 1 else "s"],
		("%d zombies, %d guns, %d items. The order is hidden." % [run.pile_zombies(), int(cnt["W"]), items]) + (" Top: %s %d." % [DDText.card_name(lc, run.bal), lc.value] if lc != null else ""))


static func pile_spec(run: DDRun) -> Dictionary:
	return {"kind": "D", "tag": "PILE", "big": str(run.pile.size()), "big_size": 30, "title": "%d zombie%s" % [run.pile_zombies(), "" if run.pile_zombies() == 1 else "s"],
		"row": true, "payload": pile(run)}


# ---------------------------------------------------------------- right column: rooms
static func room(run: DDRun, i: int) -> Dictionary:
	var r: Dictionary = run.room(i)
	var m: Dictionary = run.machine(i)
	var pack: PackedStringArray = []
	for p: Variant in r.get("pack", []):
		pack.append(DDText.pack_entry(str(p)))
	var body: String = "Price %d. %s.\nPack (3 cards into the pile): %s.\nOnce open: 1 more card per wave.\n\n%s: %s" % [
		run.bal.shown(run.room_cost(i)), "Open" if run.room_open[i] else "Closed", ", ".join(pack),
		DDText.machine_name(str(m.get("kind", ""))).to_upper(), DDText.machine_text(m, run.bal)]
	if run.room_open[i] and run.machine_used[i]:
		body += "\nUsed this wave: back next wave."
	var p: Dictionary = {"kind": "R" if not run.room_open[i] else "Q", "tag": "ROOM - %s" % DDText.machine_name(str(m.get("kind", ""))).to_upper(),
		"title": str(r.get("name", "")), "big": str(run.bal.shown(run.room_cost(i))), "body": body,
		"art_keys": Art.machine_keys(m) if run.room_open[i] else Art.room_keys(str(run.district().get("id", "")), str(r.get("name", "")))}
	var price: int = run.bal.shown(run.room_cost(i))
	var mname: String = DDText.machine_name(str(m.get("kind", "")))
	var adds: String = "a %s (%s)" % [mname, _short_name(run.bal.weapon_name(str(m.get("wid", ""))))] if str(m.get("kind", "")) == "wall" else "the " + mname
	if run.room_open[i] and run.machine_used[i]:
		return tip(p, "%s · used this wave" % mname, "Back next wave.")
	if run.room_open[i]:
		return tip(p, "%s · open" % mname, "Use it once per wave: tap USE.")
	if run.can_open_room(i):
		return tip(p, "%s · OPEN for %d pts" % [str(r.get("name", "")), price], "Inside: %s, and %s." % [_pack_short(run, i), adds])
	return tip(p, "%s · %d pts · need %d more" % [str(r.get("name", "")), price, maxi(0, price - run.bal.shown(run.points))],
		"Inside: %s, and %s." % [_pack_short(run, i), adds])


## dd-ux-text: a room's 3 pack cards in a few words: "a gun, medkit 4, cover 2".
static func _pack_short(run: DDRun, i: int) -> String:
	var pack: PackedStringArray = []
	for p: Variant in run.room(i).get("pack", []):
		pack.append(DDText.pack_entry(str(p)))
	return ", ".join(pack) if not pack.is_empty() else "3 cards"


## dd-ux-text: the gold OPEN / locked plate on a room door has its own tooltip: the price and what
## is inside (it used to show an empty one).
static func room_plate(run: DDRun, i: int) -> Dictionary:
	var p: Dictionary = room(run, i)
	if run.room_open[i]:
		return p
	var price: int = run.bal.shown(run.room_cost(i))
	var m: Dictionary = run.machine(i)
	var mname: String = DDText.machine_name(str(m.get("kind", "")))
	var t1: String = ("OPEN · %d pts" % price) if run.can_open_room(i) else ("%d pts · need %d more" % [price, maxi(0, price - run.bal.shown(run.points))])
	return tip(p, "%s · %s" % [str(run.room(i).get("name", "")), t1], "Inside: %s, and the %s." % [_pack_short(run, i), mname])


static func room_spec(run: DDRun, i: int) -> Dictionary:
	var r: Dictionary = run.room(i)
	var m: Dictionary = run.machine(i)
	var kind: String = str(m.get("kind", ""))
	var open: bool = run.room_open[i]
	var line: String
	if open:
		line = "used this wave" if run.machine_used[i] else DDText.machine_name(kind)
	else:
		line = DDText.machine_name(kind)
	# dd-ux-clean: the tile names the room and its machine; the price is on the OPEN button only
	return {"kind": "Q" if open else "R", "tag": str(r.get("name", "")).to_upper(), "title": line, "title_size": DDUi.FONT_S, "row": true,
		"payload": room(run, i)}


# ---------------------------------------------------------------- patches, people, counters
static func patch(id: String, bal: DDBalance) -> Dictionary:
	return tip({"kind": "P", "tag": "PATCH", "title": DDText.patch_name(id), "big": "", "body": DDText.patch_text(id, bal) + "\nFor the whole run.", "art_keys": Art.patch_keys(id)},
		"%s · Patch" % DDText.patch_name(id), patch_line(id, bal))


## One short line per Patch (tooltips, Codex, Glossary).
static func patch_line(id: String, bal: DDBalance) -> String:
	match id:
		"lookout":
			return "See the pile's top card; bury it once per street."
		"thick_jacket":
			return "+%d max HP, and heal %d." % [bal.num("thick_jacket_hp"), bal.num("thick_jacket_hp")]
		"field_medic":
			return "Medkits heal %d more." % bal.num("field_medic_bonus")
		"brawler":
			return "Melee hits %d harder." % bal.num("brawler_bonus")
		"bounty":
			return "Finishing a gun pays +%d per zombie on it." % bal.shown(1)
		"loose_grip":
			return "Once per wave, one gun kill may break its rule."
		"second_wind":
			return "Once per run, at 0 HP you go to %d HP instead." % bal.num("second_wind_hp")
		"trophy_belt":
			return "Heal %d whenever you finish a gun." % bal.num("trophy_belt_heal")
		"lockpick":
			return "Rooms cost %d less." % bal.shown(bal.num("lockpick_off"))
		"iron_stomach":
			return "Healing past your max HP becomes Cover."
		"adrenaline":
			return "At %d HP or less, every weapon hits 1 harder." % bal.num("adrenaline_hp")
		"grudge":
			return "Hit 1 harder against zombies ≥%d." % bal.num("grudge_min")
		"show_off":
			return "Every challenge you meet pays +%d more." % bal.shown(bal.num("show_off_points"))
		"whetstone":
			return "Melee weapons you pick up get +%d uses." % bal.num("whetstone_dur")
	return DDText.patch_text(id, bal)


static func patch_spec(id: String, bal: DDBalance, compact: bool = true) -> Dictionary:
	return {"kind": "P", "tag": "" if compact else "PATCH", "title": DDText.patch_name(id), "compact": compact, "row": compact,
		"lines": [] if compact else [[patch_line(id, bal), DDUi.TEXT, DDUi.FONT_S]], "payload": patch(id, bal)}


static func survivor(id: String, bal: DDBalance, prof: DDProfile) -> Dictionary:
	var s: Dictionary = bal.survivor(id)
	var passive: String = str(s.get("passive", ""))
	var body: PackedStringArray = []
	body.append("%s, %s. Max HP %d." % [str(s.get("name", id)), str(s.get("role", "")).to_lower(), bal.survivor_max_hp(id)])
	body.append("%s: %s" % [DDText.passive_name(passive), DDText.passive_text(passive, bal)])
	if prof != null:
		if not prof.survivor_unlocked(id):
			body.append("LOCKED: %s." % unlock_hint(prof.unlock_milestone_for("survivor:" + id), bal))
		body.append("Best score: %d" % bal.shown(prof.best_score(id)))
		if prof.best_v2(id) > 0:
			body.append("Old record (v2 rules): %d" % bal.shown(prof.best_v2(id)))
		if prof.badges(id) > 0:
			body.append("Survivor's Mark x%d (runs won)" % prof.badges(id))
	var t2: String = "%s: %s" % [DDText.passive_name(passive), passive_line(passive, bal)]
	if prof != null and not prof.survivor_unlocked(id):
		t2 = "Locked: %s." % unlock_hint(prof.unlock_milestone_for("survivor:" + id), bal)
	return tip({"kind": "S", "tag": "SURVIVOR", "title": str(s.get("name", id)), "big": str(bal.survivor_max_hp(id)), "body": "\n".join(body)},
		"%s · %d HP%s" % [str(s.get("name", id)), bal.survivor_max_hp(id), (" · best %d" % bal.shown(prof.best_score(id))) if prof != null and prof.best_score(id) > 0 else ""], t2)


static func passive_line(passive: String, bal: DDBalance) -> String:
	match passive:
		"steady_hands":
			return "Rifle and Crossbow also take an equal number."
		"triage":
			return "Medkits heal %d more." % bal.num("triage_bonus")
		"slip_away":
			return "Run costs no HP."
	return DDText.passive_text(passive, bal)


static func unlock_hint(milestone: String, bal: DDBalance) -> String:
	if milestone == "win":
		return "win a run"
	for d: Variant in bal.districts():
		if str((d as Dictionary).get("id", "")) == milestone:
			return "clear %s" % str((d as Dictionary).get("name", milestone))
	return "keep playing"


static func unlock(key: String, bal: DDBalance, prof: DDProfile) -> Dictionary:
	if key.begins_with("survivor:"):
		var s: Dictionary = survivor(key.trim_prefix("survivor:"), bal, prof)
		s["tag"] = "NEW SURVIVOR UNLOCKED"
		s["t1"] = "New survivor · " + str(s["title"])
		return s
	if key.begins_with("badge:"):
		var sid: String = key.trim_prefix("badge:")
		return tip({"kind": "S", "tag": "NEW BADGE", "title": "Survivor's Mark", "big": "*",
			"body": "%s made it out of the city. Shown on the title screen." % str(bal.survivor(sid).get("name", sid))},
			"Survivor's Mark · %s" % str(bal.survivor(sid).get("name", sid)), "Made it out of the city. Shown on the title screen.")
	if key.begins_with("perk:"):
		return tip({"kind": "P", "tag": "UNLOCKED", "title": key.trim_prefix("perk:").capitalize(), "body": ""}, "Unlocked · " + key.trim_prefix("perk:").capitalize(), "It can now show up in your runs.")
	return tip({"kind": "D", "tag": "NEW", "title": key, "body": ""}, "New · " + key, "")


static func hp(run: DDRun) -> Dictionary:
	var s: Dictionary = run.bal.survivor(run.survivor_id)
	return tip({"kind": "S", "tag": "HP - %s" % str(s.get("name", "")).to_upper(), "title": "Health", "big": "%d/%d" % [run.hp, run.max_hp],
		"body": "HP %d of %d. At 0 the run ends%s. Damage = strength - hit; Cover takes it first.%s\n%s: %s" % [run.hp, run.max_hp,
			" (Second Wind: once, back to %d)" % run.bal.num("second_wind_hp") if run.has_patch("second_wind") and not run.second_wind_used else "",
			("\nCover now: %d." % run.cover) if run.cover > 0 else "", DDText.passive_name(run.passive), DDText.passive_text(run.passive, run.bal)]},
		"HP %d / %d · %s%s" % [run.hp, run.max_hp, str(s.get("name", "")), (" · Cover %d" % run.cover) if run.cover > 0 else ""],
		"%s: %s" % [DDText.passive_name(run.passive), passive_line(run.passive, run.bal)])


## dd-ux-clean: every Patch you have, in one zoom (the HUD shows one chip).
static func patches(run: DDRun) -> Dictionary:
	var parts: PackedStringArray = []
	for p: String in run.patches:
		parts.append("%s: %s" % [DDText.patch_name(p), DDText.patch_text(p, run.bal)])
	var names: PackedStringArray = []
	for p2: String in run.patches:
		names.append(DDText.patch_name(p2))
	return tip({"kind": "P", "tag": "PATCHES", "title": "%d Patch%s" % [run.patches.size(), "" if run.patches.size() == 1 else "es"], "big": str(run.patches.size()),
		"body": "\n".join(parts) + "\nFor the whole run."},
		"%d Patch%s · for the whole run" % [run.patches.size(), "" if run.patches.size() == 1 else "es"], ", ".join(names) + ". Each one is in the Codex.")


## dd-ux-clean: the history (the board shows only the last line).
static func history(run: DDRun) -> Dictionary:
	var lines: Array[String] = run.log_lines.slice(maxi(0, run.log_lines.size() - 12))
	lines.reverse()
	return {"kind": "D", "tag": "WHAT HAPPENED", "title": "History", "big": "", "list": true, "body": "\n".join(lines) if not lines.is_empty() else "Nothing yet.",
		"t1": "What happened · the last %d" % lines.size(), "t2": lines[0] if not lines.is_empty() else "Nothing yet."}


static func cover(run: DDRun) -> Dictionary:
	return tip({"kind": "C", "tag": "COVER", "title": "Cover", "big": str(run.cover),
		"body": "Cover takes damage before your HP. It stays until used up."},
		"Cover %d" % run.cover, "Takes damage before your HP. Stays until used up.")


static func points(run: DDRun) -> Dictionary:
	var b: DDBalance = run.bal
	return tip({"kind": "X", "tag": "POINTS", "title": "Points", "big": str(b.shown(run.points)),
		"body": "Spend them on rooms and machines. %d earned this run (spending doesn't lower your score).\nA gun kill pays its number ×10; a full gun +%d and its challenge; a scrapped gun +%d; a boss +%d. Melee pays nothing." % [
			b.shown(run.points_earned), b.shown(b.num("finish_bonus")), b.shown(b.num("scrap_points")), b.shown(b.num("boss_reward_points"))]},
		"%d pts · %d earned this run" % [b.shown(run.points), b.shown(run.points_earned)],
		"Gun kills pay their number ×10. Spend them on rooms.")


static func how_to_play(bal: DDBalance) -> Dictionary:
	var b: PackedStringArray = []
	b.append("3 districts: 3 waves each, then a boss. When the pile runs out, the next wave joins it.")
	b.append("Each street deals %d cards; you resolve %d, 1 stays (the Holdover). %s" % [bal.num("street_size"), bal.num("actions"), DDText.run_rule_text(bal)])
	b.append("Pick the ACTIVE weapon (gun 1, gun 2 or melee), then tap zombies. You lose strength - hit HP. Each gun kill fills a socket and pays its number. Each gun has a RULE for its next kill (e.g. lower than the last kill).")
	b.append("A full gun pays +%d and its CHALLENGE, then leaves. Melee: Bare Hands (hits %d, any zombie, no points); melee weapons hit harder until their uses run out." % [bal.shown(bal.num("finish_bonus")), bal.num("hands_power")])
	b.append("Spend points to OPEN rooms: 3 cards join the pile and a machine switches on (Retrofit Bench, Patch Press, Wall Rack).")
	b.append("Long press or right click anything to read it.")
	return {"kind": "D", "tag": "HOW TO PLAY", "title": "Kill Stacks", "big": "", "list": true, "body": "\n\n".join(b)}
