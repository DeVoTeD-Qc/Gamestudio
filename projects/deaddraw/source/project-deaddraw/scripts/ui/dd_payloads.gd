# dd_payloads.gd
# Purpose: Builds the tile specs and zoom payloads (long press / right click) for every v3 board
#   element: street cards (with the ACTIVE weapon's damage chip or the rule lock), guns and their
#   kill stacks, melee, wave decks, the boss, the draw pile (and Lookout), room decks / machines,
#   Patches, survivors, HP / Cover / points, unlocks, how to play. Clarity over information: a
#   tile shows what this tap needs; the zoom has the rest.
# Dependencies: DDRun, DDCard, DDGun, DDText, DDUi, DDBalance, DDProfile.
# Author: Mechanics Developer Agent
class_name DDPayloads
extends RefCounted


static func _weapon_label(run: DDRun, w: int) -> String:
	if w == DDRun.MELEE:
		return "Melee"
	var g: DDGun = run.slot(w)
	return g.name if g != null else "Slot %d" % (w + 1)


# ---------------------------------------------------------------- street cards
## Zoom for a street card. Zombies: damage with each weapon and which gun rules allow it.
static func card(c: DDCard, run: DDRun, index: int = -1) -> Dictionary:
	var b: DDBalance = run.bal
	var body: PackedStringArray = []
	match c.kind:
		DDCard.ZOMBIE:
			body.append("Number %d: its strength and its points (paid when a gun kills it; melee pays nothing)." % c.value)
			if c.is_boss():
				body.append("%s (%s): %s" % [c.boss_name, DDText.trait_name(c.boss_trait), DDText.trait_text(c.boss_trait)])
			for w: int in 3:
				if w != DDRun.MELEE and run.slot(w) == null:
					continue
				var pr: Dictionary = run.preview(index, w) if index >= 0 else {}
				var p: int = run.power_of(w)
				var line: String = "%s (power %d): %s" % [_weapon_label(run, w), p, ("-%d HP" % maxi(0, c.value - p)) if maxi(0, c.value - p) > 0 else "no damage"]
				if not pr.is_empty() and not bool(pr["ok"]):
					line += " - NOT ALLOWED (%s)" % str(pr["reason"])
				elif not pr.is_empty() and bool(pr["uses_loose"]):
					line += " - uses Loose Grip (bends the rule)"
				elif not pr.is_empty() and bool(pr["finishes"]):
					line += " - FINISHES the gun"
				body.append(line)
			body.append("Damage = number - power, Cover first.")
		DDCard.WEAPON:
			body.append(DDText.gun_card_text(c.wid, b, run.steady()))
			body.append("Tap it: put it into slot 1 or 2 (replacing a gun discards its stack: no bonus, no challenge), or scrap it for %d points." % b.shown(b.num("scrap_points")))
		DDCard.MEDKIT:
			body.append("Heal %d (one medkit per street; a second one is discarded)." % run.medkit_heal(c))
		DDCard.COVER:
			body.append("Gain %d Cover: it absorbs damage before HP and stays until used." % c.value)
	if c.holdover:
		body.append("HOLDOVER: left over from the last street.")
	var art_big: String = str(c.value) if c.kind != DDCard.WEAPON else "P%d" % b.weapon_power(c.wid)
	return {"kind": "F" if c.is_boss() else c.kind, "tag": DDText.kind_label(c.kind) if not c.is_boss() else "BOSS - " + DDText.trait_name(c.boss_trait).to_upper(),
		"title": DDText.card_name(c, b), "big": art_big, "body": "\n".join(body)}


static func street_card_spec(c: DDCard, i: int, run: DDRun) -> Dictionary:
	var b: DDBalance = run.bal
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
				badge = ("-%d" % loss) if loss > 0 else "-0"
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
					extra = "melee: 0 pts"
				if int(pr["absorbed"]) > 0:
					extra = ("Cover %d  " % int(pr["absorbed"])) + extra
				lines.append([extra.strip_edges() if extra.strip_edges() != "" else "kill", DDUi.GOOD if loss == 0 else DDUi.TEXT, DDUi.FONT_S - 2])
			else:
				lock = str(pr["reason"])
				badge = "LOCK"
				badge_color = DDUi.TEXT_DIM
				dim_art = true
				lines.append([lock, DDUi.WARN, DDUi.FONT_S - 3])
		DDCard.WEAPON:
			lines.append(["P%d - %s" % [b.weapon_power(c.wid), DDText.RULE_ICONS.get(b.weapon_rule(c.wid), "")], DDUi.accent("W"), DDUi.FONT_S - 2])
		DDCard.MEDKIT:
			var pm: Dictionary = run.card_preview(i, DDRun.USE)
			if bool(pm["wasted"]):
				dim_art = true
				badge = "DISCARD"
				lines.append(["1 medkit per street", DDUi.WARN, DDUi.FONT_S - 2])
			elif int(pm["heal"]) <= 0:
				dim_art = true
				badge = "FULL HP"
				lines.append(["heals 0", DDUi.WARN, DDUi.FONT_S - 2])
			else:
				lines.append(["+%d HP" % int(pm["heal"]), DDUi.GOOD, DDUi.FONT_S - 2])
		DDCard.COVER:
			lines.append(["+%d Cover" % c.value, DDUi.COVER, DDUi.FONT_S - 2])
	if c.is_boss() and badge == "":
		badge = DDText.trait_name(c.boss_trait).to_upper()
		badge_color = DDUi.accent("F")
	var tag: String = DDText.kind_label(c.kind)
	if c.is_boss():
		tag = "BOSS" if c.phase == 0 else "PHASE %d" % c.phase
	elif c.holdover:
		tag = "HOLDOVER"
	return {"kind": "F" if c.is_boss() else c.kind, "tag": tag, "badge": badge, "badge_color": badge_color,
		"big": str(c.value) if c.kind != DDCard.WEAPON else "", "title": DDText.card_name(c, b), "lines": lines,
		"art_dim": dim_art, "lock": lock, "payload": card(c, run, i)}


# ---------------------------------------------------------------- guns
## A gun definition zoom (street gun card, Wall Rack).
static func gun_def(wid: String, bal: DDBalance, tag: String = "GUN", rosa: bool = false) -> Dictionary:
	return {"kind": "W", "tag": tag, "title": bal.weapon_name(wid), "big": "P%d" % bal.weapon_power(wid),
		"body": DDText.gun_card_text(wid, bal, rosa)}


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
		return {"kind": "W", "tag": "GUN SLOT %d" % (s + 1), "title": "Empty slot", "big": "",
			"body": "Equip a gun card from the street (tap it) or buy one at a Wall Rack. Melee is always there."}
	var b: DDBalance = run.bal
	var body: PackedStringArray = []
	var rw: Array = b.weapon_reward(g.wid)
	body.append("Power %d%s. Capacity %d: %d/%d kills on the stack%s." % [g.power, " (Honed)" if g.honed else "", g.cap, g.stack.size(), g.cap,
		(", total %d of %d" % [g.total(), b.num("spread_cap")]) if g.rule == "spread" else ""])
	body.append("RULE: %s%s" % [DDText.rule_text(g.rule, b, run.steady()), " (Flipped at the Retrofit Bench)" if g.flipped else ""])
	body.append("Can still take: %s." % _range_text(run.can_take(g)))
	body.append("CHALLENGE %s: %s -> %s. Now: %s." % [DDText.challenge_name(b.weapon_challenge(g.wid)).to_upper(), DDText.challenge_text(b.weapon_challenge(g.wid), b),
		DDText.reward_text(str(rw[0]), int(rw[1]), b), str({"met": "met", "on_track": "on track", "broken": "can't be met any more", "open": "not decided yet"}[run.challenge_state(g)])])
	body.append("Stack: %s." % (DDText.zombie_list(g.stack) if not g.stack.is_empty() else "empty"))
	body.append("Each kill pays its number now. When the stack is full the gun is FINISHED: +%d bonus, the challenge pays, the gun leaves." % b.shown(b.num("finish_bonus")))
	if run.active == s:
		body.append("ACTIVE: every tap on a zombie attacks with this gun.")
	else:
		body.append("Tap to make it the active weapon.")
	return {"kind": "W", "tag": "GUN %d%s" % [s + 1, " - ACTIVE" if run.active == s else ""], "title": g.name, "big": "P%d" % g.power, "body": "\n".join(body)}


static func stack_card(run: DDRun, s: int, k: int) -> Dictionary:
	var g: DDGun = run.slot(s)
	var z: int = g.stack[k]
	return {"kind": "Z", "tag": "KILL %d ON %s" % [k + 1, g.name.to_upper()], "title": "Zombie %d" % z, "big": str(z),
		"body": "Kill %d of %d on the %s (paid %d points when it was killed).%s" % [k + 1, g.cap, g.name, run.bal.shown(z),
			"\nThe TOP kill: the rule checks the next kill against it." if k == g.stack.size() - 1 else ""]}


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
	spec["rule_text"] = DDText.rule_short(g.rule, run.steady())
	spec["challenge"] = DDText.challenge_name(b.weapon_challenge(g.wid))
	spec["reward"] = DDText.reward_short(str(rw[0]), int(rw[1]), b)
	spec["challenge_state"] = run.challenge_state(g)
	spec["stack"] = g.stack.duplicate()
	spec["honed"] = g.honed
	spec["flipped"] = g.flipped
	spec["left"] = g.kills_left()
	spec["can_take"] = _range_text(run.can_take(g))
	var stack_payloads: Array = []
	for k: int in g.stack.size():
		stack_payloads.append(stack_card(run, s, k))
	spec["stack_payloads"] = stack_payloads
	return spec


static func melee(run: DDRun) -> Dictionary:
	return {"kind": "K", "tag": "MELEE%s" % (" - ACTIVE" if run.active == DDRun.MELEE else ""), "title": "Crowbar", "big": "P%d" % run.melee_power(),
		"body": "Always there. Power %d, no rule, unlimited. Melee kills don't stack and pay NO points: the escape valve for a zombie your guns can't take.%s" % [
			run.melee_power(), "\nBrawler Patch: +%d power." % run.bal.num("brawler_bonus") if run.has_patch("brawler") else ""]}


# ---------------------------------------------------------------- left column: waves + boss
static func wave(run: DDRun, w: int) -> Dictionary:
	var zs: Array[int] = run.bal.wave_zombies(run.district_index, w)
	var spec: Array = run.bal.wave_spec(run.district_index, w)
	var guns: int = spec.size() - zs.size()
	var st: String = run.wave_status(w)
	var sorted: Array[int] = zs.duplicate()
	sorted.sort()
	return {"kind": "D", "tag": "WAVE %d - %s" % [w + 1, st.to_upper()], "title": "Wave %d deck" % (w + 1), "big": str(spec.size()),
		"body": "%d cards: zombies %s + %d gun%s.\n%s\nZombie numbers are public; only the order is hidden. Opened rooms add 1 restock card each when a wave shuffles in." % [
			spec.size(), DDText.zombie_list(sorted), guns, "" if guns == 1 else "s",
			{"done": "Already shuffled into the pile.", "active": "In the pile now.", "waiting": "Waits on the left: it is shuffled into the pile when the pile runs dry."}[st]]}


static func wave_spec(run: DDRun, w: int) -> Dictionary:
	var zs: Array[int] = run.bal.wave_zombies(run.district_index, w)
	var st: String = run.wave_status(w)
	var n: int = run.bal.wave_spec(run.district_index, w).size()
	return {"kind": "D", "tag": "W%d" % (w + 1), "badge": {"done": "DONE", "active": "IN PILE", "waiting": ""}[st],
		"badge_color": DDUi.TEXT_DIM if st == "done" else DDUi.GOOD, "title": "%d cards" % n,
		"lines": [["zombies %s" % DDText.zombie_range(zs), DDUi.TEXT_DIM, DDUi.FONT_S - 4]], "row": true, "dim": st == "done",
		"selected": st == "active", "payload": wave(run, w)}


static func boss(run: DDRun) -> Dictionary:
	var b: Dictionary = run.boss_def()
	var final: bool = run.is_final_district()
	return {"kind": "F", "tag": "BOSS - %s" % DDText.trait_name(str(b.get("trait", ""))).to_upper(), "title": str(b.get("name", "")),
		"big": DDText.boss_summary(b),
		"body": "%s\n%s\nThe boss street comes when every wave is spent and at most one card is left: the Holdover plus the boss. Resolve every card.\n%s" % [
			DDText.boss_summary(b), DDText.trait_text(str(b.get("trait", ""))),
			"NO ESCAPE: no Run, no run-past." if final else "Run past: take %d damage and lose the reward (+%d points and a free Patch)." % [run.bal.num("boss_runpast_damage"), run.bal.shown(run.bal.num("boss_reward_points"))]]}


static func boss_spec(run: DDRun) -> Dictionary:
	var b: Dictionary = run.boss_def()
	return {"kind": "F", "tag": "BOSS", "badge": "NO ESCAPE" if run.is_final_district() else "", "badge_color": DDUi.BAD,
		"big": DDText.boss_summary(b), "big_size": 22, "title": str(b.get("name", "")), "row": true, "title_size": DDUi.FONT_S - 4,
		"payload": boss(run)}


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
	body += "\nWhen it runs dry while dealing, the next wave deck is shuffled in."
	var lc: DDCard = run.lookout_card()
	if lc != null:
		body += "\nLOOKOUT: the top card is %s %d." % [DDText.card_name(lc, run.bal), lc.value]
	return {"kind": "D", "tag": "DRAW PILE", "title": "Draw pile", "big": str(run.pile.size()), "body": body}


static func pile_spec(run: DDRun) -> Dictionary:
	return {"kind": "D", "tag": "DRAW PILE", "big": str(run.pile.size()), "big_size": 34, "title": "%d zombies" % run.pile_zombies(),
		"row": true, "payload": pile(run)}


# ---------------------------------------------------------------- right column: rooms
static func room(run: DDRun, i: int) -> Dictionary:
	var r: Dictionary = run.room(i)
	var m: Dictionary = run.machine(i)
	var pack: PackedStringArray = []
	for p: Variant in r.get("pack", []):
		pack.append(DDText.pack_entry(str(p)))
	var body: String = "Price %d. %s.\nPack (3 cards, shuffled into the pile when you open it): %s.\nRestock: 1 card of the pack per new wave once open.\n\n%s: %s" % [
		run.bal.shown(run.room_cost(i)), "OPEN" if run.room_open[i] else "Closed: open it any time you can pay", ", ".join(pack),
		DDText.machine_name(str(m.get("kind", ""))).to_upper(), DDText.machine_text(m, run.bal)]
	if run.room_open[i] and run.machine_used[i]:
		body += "\nUsed this wave: back next wave."
	return {"kind": "R" if not run.room_open[i] else "K", "tag": "ROOM - %s" % DDText.machine_name(str(m.get("kind", ""))).to_upper(),
		"title": str(r.get("name", "")), "big": str(run.bal.shown(run.room_cost(i))), "body": body}


static func room_spec(run: DDRun, i: int) -> Dictionary:
	var r: Dictionary = run.room(i)
	var m: Dictionary = run.machine(i)
	var kind: String = str(m.get("kind", ""))
	var open: bool = run.room_open[i]
	var line: String
	if open:
		line = "used this wave" if run.machine_used[i] else DDText.machine_name(kind)
	else:
		line = DDText.machine_name(kind) + ((" - " + run.bal.weapon_name(str(m.get("wid", "")))) if kind == "wall" else "")
	return {"kind": "K" if open else "R", "tag": str(r.get("name", "")).to_upper(), "badge": "OPEN" if open else "",
		"badge_color": DDUi.GOOD, "big": "" if open else str(run.bal.shown(run.room_cost(i))), "big_size": 24, "row": true,
		"lines": [[line, DDUi.TEXT_DIM if not open else DDUi.accent("K"), DDUi.FONT_S - 4]], "payload": room(run, i)}


# ---------------------------------------------------------------- patches, people, counters
static func patch(id: String, bal: DDBalance) -> Dictionary:
	return {"kind": "P", "tag": "PATCH", "title": DDText.patch_name(id), "big": "", "body": DDText.patch_text(id, bal) + "\nPermanent for the run."}


static func patch_spec(id: String, bal: DDBalance, compact: bool = true) -> Dictionary:
	return {"kind": "P", "tag": "PATCH", "title": DDText.patch_name(id), "compact": compact, "row": compact,
		"lines": [] if compact else [[DDText.patch_text(id, bal), DDUi.TEXT, DDUi.FONT_S]], "payload": patch(id, bal)}


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
		if prof.badges(id) > 0:
			body.append("Survivor's Mark x%d (runs won)" % prof.badges(id))
	return {"kind": "S", "tag": "SURVIVOR", "title": str(s.get("name", id)), "big": str(bal.survivor_max_hp(id)), "body": "\n".join(body)}


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
		return s
	if key.begins_with("badge:"):
		var sid: String = key.trim_prefix("badge:")
		return {"kind": "S", "tag": "NEW BADGE", "title": "Survivor's Mark", "big": "*",
			"body": "%s made it out of the city. The mark shows on the title screen." % str(bal.survivor(sid).get("name", sid))}
	if key.begins_with("perk:"):
		return {"kind": "P", "tag": "UNLOCKED", "title": key.trim_prefix("perk:").capitalize(), "body": ""}
	return {"kind": "D", "tag": "NEW", "title": key, "body": ""}


static func hp(run: DDRun) -> Dictionary:
	return {"kind": "S", "tag": "HP", "title": "Health", "big": "%d/%d" % [run.hp, run.max_hp],
		"body": "HP %d of %d. At 0 the run ends%s. Damage = zombie - weapon power; Cover soaks it first." % [run.hp, run.max_hp,
			" (Second Wind: once, back to %d)" % run.bal.num("second_wind_hp") if run.has_patch("second_wind") and not run.second_wind_used else ""]}


static func cover(run: DDRun) -> Dictionary:
	return {"kind": "C", "tag": "COVER", "title": "Cover", "big": str(run.cover),
		"body": "Cover soaks damage before your HP does. It stays until it is used up."}


static func points(run: DDRun) -> Dictionary:
	var b: DDBalance = run.bal
	return {"kind": "X", "tag": "POINTS", "title": "Points", "big": str(b.shown(run.points)),
		"body": "Spend on rooms, Patches, the Bench and the Wall Rack. %d earned this run (spending doesn't lower the score).\nEvery gun kill pays its number (x10 on screen); finishing a gun +%d and its challenge; scrapping a gun +%d; a boss +%d. Melee pays nothing." % [
			b.shown(run.points_earned), b.shown(b.num("finish_bonus")), b.shown(b.num("scrap_points")), b.shown(b.num("boss_reward_points"))]}


static func how_to_play(bal: DDBalance) -> Dictionary:
	var b: PackedStringArray = []
	b.append("3 districts, 3 wave decks each, then the boss. Wave decks wait on the LEFT, room decks on the RIGHT, the draw pile in the MIDDLE. When the pile runs dry, the next wave is shuffled in.")
	b.append("Every street deals %d cards; you resolve %d, 1 stays (the Holdover). Before resolving you may RUN: the street goes back into the pile for %d HP (not twice in a row, never on a boss street)." % [bal.num("street_size"), bal.num("actions"), bal.num("run_damage")])
	b.append("Pick the ACTIVE weapon (gun 1, gun 2 or melee), then tap zombies. You take number - power damage. Each kill STACKS on the gun and pays its number in points. Each gun has a RULE (lower than the top kill, same number...) and a capacity.")
	b.append("A full stack FINISHES the gun: +%d bonus, its CHALLENGE pays extra, the gun leaves. Then equip the next one. Melee: power %d, no rule, no points." % [bal.shown(bal.num("finish_bonus")), bal.num("melee_power")])
	b.append("Spend points to OPEN rooms (their cards shuffle in, their machine switches on): Retrofit Bench, Patch Press, Wall Rack.")
	b.append("Long press or right click anything to read it.")
	return {"kind": "D", "tag": "HOW TO PLAY", "title": "Kill Stacks", "big": "", "body": "\n\n".join(b)}
