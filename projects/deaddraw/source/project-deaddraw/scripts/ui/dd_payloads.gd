# dd_payloads.gd
# Purpose: Builds the zoom (inspect) payloads and tile specs for everything on the DeadDraw v2
#   screens, so every card, weapon slot, magazine, reserve, points counter, wave pip, boss, deck,
#   Skipped pile, door, machine, Jawbreaker badge, perk and survivor carries its full rules text
#   (studio UX rule: everything inspectable on right click / long press).
# Dependencies: DDRun, DDWeapon, DDText, DDBalance, DDProfile, DDUi.
# Author: Mechanics Developer Agent
class_name DDPayloads
extends RefCounted


static func card(c: DDCard, run: DDRun) -> Dictionary:
	var b: DDBalance = run.bal if run != null else DDBalance.get_default()
	var k: String = "F" if c.is_finale() else c.kind
	var tag: String = DDText.kind_label(c.kind)
	if c.is_finale():
		tag = "BOSS " + tag + " - " + DDText.trait_name(c.boss_trait).to_upper()
	elif c.drop != "":
		tag = "CARRIER ZOMBIE - drops " + DDText.drop_name(c.drop).to_upper()
	elif c.kind == DDCard.WEAPON:
		tag = ("GUN" if b.is_gun(c.wid) else "MELEE") + " WEAPON"
	return {"kind": k, "tag": tag, "title": DDText.card_name(c, b), "big": str(c.value),
		"body": DDText.card_rules(c, run, b)}


## Tile spec for a street card, with the outcome preview lines.
static func street_card_spec(c: DDCard, i: int, run: DDRun, selected: bool) -> Dictionary:
	var lines: Array = []
	var badge: String = ""
	var badge_color: Color = DDUi.WARN
	## dd-polish: the rules block part of this card's use this turn -> darken its art, keep the
	## number bright. Still selectable.
	var dim_art: bool = false
	match c.kind:
		DDCard.ZOMBIE:
			var best: Dictionary = {}
			for ch: String in [DDRun.SLOT1, DDRun.SLOT2]:
				var pw: Dictionary = run.preview(i, ch)
				if bool(pw["enabled"]) and (best.is_empty() or int(pw["hp_loss"]) < int(best["hp_loss"])):
					best = pw
			if not best.is_empty():
				lines.append([_loss_text(run.slot(int(best["slot"])).display_name(), best), DDUi.GOOD, DDUi.FONT_S])
			else:
				dim_art = run.slot(0) != null or run.slot(1) != null
				lines.append(["Bare hands only", DDUi.WARN, DDUi.FONT_S])
			lines.append([_loss_text("Bare", run.preview(i, DDRun.BARE)), DDUi.BAD, DDUi.FONT_S])
		DDCard.WEAPON:
			var mag: int = run.bal.weapon_mag(c.wid)
			lines.append([("gun, mag %d" % mag) if mag > 0 else "melee, unlimited", DDUi.TEXT_DIM, DDUi.FONT_S])
		DDCard.AMMO:
			var pa: Dictionary = run.preview(i, DDRun.USE)
			if int(pa["ammo_gain"]) <= 0 and bool(pa["enabled"]):
				dim_art = true
				badge = "RESERVE FULL"
			lines.append(["+%d reserve" % int(pa["ammo_gain"]) if bool(pa["enabled"]) else "+%d reserve" % c.value, DDUi.accent("A"), DDUi.FONT_S])
		DDCard.MEDKIT:
			var pm: Dictionary = run.preview(i, DDRun.USE)
			if bool(pm["wasted"]):
				dim_art = true
				badge = "WON'T HEAL"
				lines.append(["won't heal", DDUi.WARN, DDUi.FONT_S])
			elif int(pm["heal"]) <= 0 and bool(pm["enabled"]):
				dim_art = true
				badge = "FULL HP"
				lines.append(["full HP: heals 0", DDUi.WARN, DDUi.FONT_S])
			else:
				lines.append(["+%d HP" % (int(pm["heal"]) if bool(pm["enabled"]) else c.value), DDUi.GOOD, DDUi.FONT_S])
		DDCard.BARRICADE:
			lines.append(["+%d Cover" % c.value, DDUi.COVER, DDUi.FONT_S])
	if c.is_finale():
		badge = DDText.trait_name(c.boss_trait).to_upper()
		badge_color = DDUi.accent("F")
	elif c.drop != "" and badge == "":
		badge = "CARRIER"
		badge_color = DDUi.accent("X")
	elif c.skipped and badge == "":
		badge = "BACK"
		badge_color = DDUi.accent("D")
	elif c.holdover and badge == "":
		badge = "HOLDOVER"
		badge_color = DDUi.TEXT_DIM
	return {"kind": "F" if c.is_finale() else c.kind, "tag": DDText.kind_label(c.kind), "badge": badge,
		"badge_color": badge_color, "big": str(c.value), "title": DDText.card_name(c, run.bal), "lines": lines,
		"selected": selected, "art_dim": dim_art, "payload": card(c, run)}


static func _loss_text(label: String, p: Dictionary) -> String:
	var t: String = "%s -%d" % [label, int(p["hp_loss"])]
	if bool(p["dies"]):
		t += " DIES"
	elif bool(p["second_wind"]):
		t += " (Second Wind)"
	return t


# ---------------------------------------------------------------- weapons
static func slot_payload(run: DDRun, i: int) -> Dictionary:
	var w: DDWeapon = run.slot(i)
	var body: PackedStringArray = []
	if w == null:
		body.append("Slot %d is empty. A weapon card, the Lucky Locker or a Wall Rack can fill it." % (i + 1))
		body.append("You always have your bare hands too: zombies then deal their full strength.")
		return {"kind": "W", "tag": "SLOT %d" % (i + 1), "title": "Empty", "big": "-", "body": "\n".join(body)}
	var p: int = run.power_of(w)
	body.append("Power %d: a zombie you fight with it deals strength - %d (minimum 0)%s." % [p, p, " (Steady Aim +%d)" % (p - w.power) if p != w.power else ""])
	if w.is_gun():
		body.append("Gun. Magazine %d / %d: each kill spends 1 round. Reserve ammo: %d." % [w.ammo, w.cap, run.reserve])
		var mode: String = "the rounds left in the magazine are dropped, " if run.bal.text("reload_mode") == "drop" else ""
		body.append("Reload (1 action, max 1 per street): %sa fresh magazine comes from the reserve and the notch clears. Free on the boss street." % mode)
	else:
		body.append("Melee. Never runs out; +%d points for every kill up close. Its notch clears at the start of every wave." % run.bal.shown(int(run.bal.points("up_close"))))
	if w.is_fresh():
		body.append("Fresh: no notch, it can hit anything.")
	else:
		body.append("Notch %d: it %s." % [w.notch, DDText.notch_tag(w.notch, run.equal_ok(w))])
	body.append("Notch rule: every kill notches the weapon at that zombie's strength; afterwards it only hits zombies weaker than its notch%s." % (" (or equal)" if run.equal_ok(w) else ""))
	if w.upgraded:
		body.append("RETROFIT: +%d power%s." % [int(run.bal.fixture_num("retrofit", "power")), ", bigger magazine" if w.is_gun() else ", Keen (hits equal to its notch)"])
	return {"kind": "W", "tag": "SLOT %d - %s" % [i + 1, "GUN" if w.is_gun() else "MELEE"], "title": w.display_name(),
		"big": str(p), "body": "\n".join(body)}


static func slot_spec(run: DDRun, i: int) -> Dictionary:
	var w: DDWeapon = run.slot(i)
	var lines: Array = []
	var spec: Dictionary = {"kind": "W", "tag": "SLOT %d  %s" % [i + 1, "" if w == null else ("GUN" if w.is_gun() else "MELEE")],
		"compact": true, "row": true, "big_size": 26, "payload": slot_payload(run, i)}
	if w == null:
		spec["big"] = "-"
		spec["title"] = "Empty slot"
		lines.append(["bare hands still work", DDUi.TEXT_DIM, DDUi.FONT_S - 3])
	else:
		spec["big"] = "P%d" % run.power_of(w)
		spec["title"] = w.display_name()
		var tagline: String = "fresh" if w.is_fresh() else DDText.notch_tag(w.notch, run.equal_ok(w))
		if w.is_gun():
			spec["pips"] = [w.ammo, w.cap]
			lines.append(["%d/%d  %s" % [w.ammo, w.cap, tagline] if w.ammo > 0 else "EMPTY - reload", (DDUi.GOOD if w.is_fresh() else DDUi.WARN) if w.ammo > 0 else DDUi.BAD, DDUi.FONT_S - 3])
		else:
			lines.append(["unlimited  %s" % tagline, DDUi.GOOD if w.is_fresh() else DDUi.WARN, DDUi.FONT_S - 3])
		if w.upgraded:
			spec["badge"] = "R"
			spec["badge_color"] = DDUi.accent("K")
	spec["lines"] = lines
	return spec


static func weapon_payload(w: DDWeapon, run: DDRun, tag: String) -> Dictionary:
	var b: PackedStringArray = []
	if w.is_gun():
		b.append("Gun, power %d, magazine %d (arrives full)." % [w.power, w.cap])
	else:
		b.append("Melee, power %d, unlimited uses%s." % [w.power, ", Keen" if w.upgraded else ""])
	b.append("Into slot 1 or 2 (the weapon there is scrapped, +%d)." % run.bal.shown(int(run.bal.points("scrap"))))
	return {"kind": "W", "tag": tag, "title": w.display_name(), "big": str(w.power), "body": "\n".join(b)}


static func reserve_payload(run: DDRun) -> Dictionary:
	return {"kind": "A", "tag": "RESERVE AMMO", "title": "Reserve", "big": str(run.reserve),
		"body": "One shared pool of rounds for all your guns (max %d). Reloading moves rounds from here into a gun's magazine. More from Ammo cards, the Full Load drop, the Wall Rack's refill%s." % [run.bal.num("reserve_cap"), " and Bandolier" if run.has_perk("bandolier") else ""]}


static func reserve_spec(run: DDRun) -> Dictionary:
	return {"kind": "A", "tag": "RESERVE", "big": str(run.reserve), "big_size": 26, "title": "", "row": true,
		"lines": [["/%d" % run.bal.num("reserve_cap"), DDUi.TEXT_DIM, DDUi.FONT_S - 4]], "compact": true, "payload": reserve_payload(run)}


# ---------------------------------------------------------------- points, waves, deck
static func points_payload(run: DDRun) -> Dictionary:
	var b: DDBalance = run.bal
	var body: PackedStringArray = []
	body.append("Points to spend: %d. Earned this run: %d (the score; spending doesn't lower it)." % [b.shown(run.points), b.shown(run.points_earned)])
	body.append("Kill: half its strength x10 (a 7 pays %d). Up close (melee or bare hands): +%d." % [b.shown(int(7 * b.points("kill"))), b.shown(int(b.points("up_close")))])
	body.append("Scrap a weapon: +%d. Clear a wave: +%d. Boss kill: +%d. Payday: double kill points." % [b.shown(int(b.points("scrap"))), b.shown(int(b.points("wave"))), b.shown(int(b.points("boss")))])
	body.append("Spend on doors (between streets) and machines. Score = points earned + 10 x HP left at each boss.")
	return {"kind": "X", "tag": "POINTS", "title": "Points", "big": str(b.shown(run.points)), "body": "\n".join(body)}


static func points_spec(run: DDRun) -> Dictionary:
	return {"kind": "X", "tag": "POINTS", "big": "", "title": str(run.bal.shown(run.points)), "title_size": DDUi.FONT_L, "row": true,
		"compact": true, "payload": points_payload(run)}


static func wave_pip_payload(run: DDRun, w: int) -> Dictionary:
	var zs: Array[int] = run.bal.wave_zombies(run.district_index, w)
	var state: String = "cleared" if w < run.wave_index else ("NOW" if w == run.wave_index else "to come")
	var body: PackedStringArray = []
	body.append("Wave %d of %d in %s (%s): %s - strengths %s, one of them a Carrier." % [w + 1, run.wave_count(), str(run.district().get("name", "")), state,
		DDText.zombie_summary(zs), DDText.zombie_list(zs)])
	body.append("A wave is one pass through the deck. When the deck can't fill a street, the wave ends: +%d points, then the Skipped pile + the next wave + 1 restock card per opened room are shuffled into the new deck." % run.bal.shown(int(run.bal.points("wave"))))
	if w == run.wave_count() - 1:
		body.append("Boss wave: when the deck runs out, skipped cards come back for one last lap, then the boss street.")
	return {"kind": "D", "tag": "WAVE %d" % (w + 1), "title": state.capitalize(), "big": str(w + 1), "body": "\n".join(body)}


static func wave_pip_spec(run: DDRun, w: int) -> Dictionary:
	var now: bool = w == run.wave_index
	return {"kind": "D", "tag": "", "big": str(w + 1), "big_size": 22, "title": "", "compact": true, "row": true,
		"selected": now, "dim": w < run.wave_index, "payload": wave_pip_payload(run, w)}


static func deck_payload(run: DDRun) -> Dictionary:
	var c: Dictionary = run.deck_counts()
	var body: PackedStringArray = []
	body.append("Wave %d - %d cards left in the deck, %d of them zombies." % [run.wave_index + 1, run.deck.size(), run.deck_zombies()])
	body.append("Zombies %d: %s" % [(c["Z"] as Array).size(), _list(c["Z"])])
	var ws: PackedStringArray = []
	for card: DDCard in run.deck:
		if card.kind == DDCard.WEAPON:
			ws.append(DDText.card_name(card, run.bal))
	body.append("Weapons %d: %s" % [ws.size(), ", ".join(ws) if not ws.is_empty() else "none"])
	body.append("Ammo %d: %s" % [(c["A"] as Array).size(), _list(c["A"])])
	body.append("Medkits %d: %s" % [(c["M"] as Array).size(), _list(c["M"])])
	body.append("Barricades %d: %s" % [(c["B"] as Array).size(), _list(c["B"])])
	body.append("")
	body.append(str(run.next_preview()["text"]))
	return {"kind": "D", "tag": "DECK - WAVE %d" % (run.wave_index + 1), "title": "Cards left", "big": str(run.deck.size()), "body": "\n".join(body)}


static func deck_spec(run: DDRun) -> Dictionary:
	var t: String = "Wave %d - %d card%s (%d zombie%s)" % [run.wave_index + 1, run.deck.size(), "" if run.deck.size() == 1 else "s",
		run.deck_zombies(), "" if run.deck_zombies() == 1 else "s"]
	if run.boss_street:
		t = "BOSS STREET"
	elif run.last_lap:
		t += " - last lap"
	return {"kind": "D", "tag": "DECK", "big": str(run.deck.size()), "big_size": 26, "title": "", "row": true,
		"lines": [[t, DDUi.TEXT, DDUi.FONT_S - 3]], "compact": true, "payload": deck_payload(run)}


static func skipped_payload(run: DDRun) -> Dictionary:
	var extra: Array = []
	for c: DDCard in run.skipped:
		extra.append({"kind": "F" if c.is_finale() else c.kind, "big": str(c.value), "title": DDText.card_name(c, run.bal)})
	var body: PackedStringArray = []
	body.append("%d card%s skipped this wave, face up." % [run.skipped.size(), "" if run.skipped.size() == 1 else "s"])
	body.append("Skip (before you act on a full street, never two in a row): all 4 street cards come here. They come back in the next wave, shuffled in with it, and this wave ends sooner.")
	body.append("On the boss wave they come back for one last lap (no skipping) before the boss.")
	if run.last_lap:
		body.append("Last lap now: no more skipping this district.")
	return {"kind": "D", "tag": "SKIPPED PILE", "title": "Back next wave", "big": str(run.skipped.size()), "body": "\n".join(body), "extra_cards": extra}


static func skipped_spec(run: DDRun) -> Dictionary:
	return {"kind": "D", "tag": "SKIPPED", "big": str(run.skipped.size()), "big_size": 26, "title": "", "row": true,
		"lines": [["next wave" if not run.is_boss_wave() or run.last_lap else "last lap", DDUi.TEXT_DIM, DDUi.FONT_S - 4]],
		"compact": true, "payload": skipped_payload(run)}


## The "Last street of the wave" banner with the next-wave preview (inspectable).
static func next_spec(run: DDRun) -> Dictionary:
	var nx: Dictionary = run.next_preview()
	var head: String = "LAST STREET OF THE WAVE"
	if run.boss_street:
		head = "BOSS STREET - resolve every card, reloads are free"
	elif run.last_lap:
		head = "LAST LAP - no skipping"
	var body: PackedStringArray = [str(nx["text"])]
	if str(nx.get("kind", "")) == "wave":
		body.append("Clearing the wave pays +%d. Your Holdover stays on the street; melee notches clear; buffs end; machines can be used again." % run.bal.shown(int(nx["bonus"])))
	return {"kind": "F" if run.boss_street else "D", "tag": head, "title": "", "big": "", "compact": true, "row": true,
		"lines": [[str(nx["text"]), DDUi.TEXT, DDUi.FONT_S - 3]], "payload": {"kind": "D", "tag": head, "title": "What comes next", "big": "", "body": "\n".join(body)}}


static func _list(a: Array) -> String:
	if a.is_empty():
		return "none"
	var p: PackedStringArray = []
	for v: Variant in a:
		p.append(str(int(v)))
	return ", ".join(p)


# ---------------------------------------------------------------- bosses
static func finale(d: Dictionary) -> Dictionary:
	var f: Dictionary = d.get("finale", {})
	var zs: PackedStringArray = []
	for z: Variant in f.get("zombies", []):
		zs.append(str(int(z)))
	var t: String = str(f.get("trait", ""))
	var body: PackedStringArray = []
	body.append("%s's boss, face up from the start: %s %s." % [str(d.get("name", "")), "zombies" if zs.size() > 1 else "zombie", " / ".join(zs)])
	body.append("%s: %s" % [DDText.trait_name(t), DDText.trait_text(t)])
	body.append("Wave 3 ends with it: when the deck (and the last lap) runs out, the boss joins your Holdover for the boss street. Resolve every card, no skip; reloads are free. Beat it to clear the district (+%d points per boss card, +10 score per HP left)." % DDBalance.get_default().shown(int(DDBalance.get_default().points("boss"))))
	return {"kind": "F", "tag": "BOSS - " + str(d.get("name", "")).to_upper(), "title": str(f.get("name", "")),
		"big": "/".join(zs), "body": "\n".join(body)}


static func finale_spec(d: Dictionary, compact: bool = true, badge: String = "") -> Dictionary:
	var f: Dictionary = d.get("finale", {})
	var p: Dictionary = finale(d)
	return {"kind": "F", "tag": "BOSS", "badge": badge, "badge_color": DDUi.accent("F"),
		"big": p["big"], "big_size": 22 if compact else 56, "title": str(f.get("name", "")) if not compact else "",
		"lines": [] if compact else [[DDText.trait_name(str(f.get("trait", ""))), DDUi.accent("F"), DDUi.FONT_S]],
		"compact": compact, "row": compact, "payload": p}


# ---------------------------------------------------------------- rooms and machines
static func room_payload(run: DDRun, i: int) -> Dictionary:
	var r: Dictionary = run.room(i)
	var m: Dictionary = r.get("machine", {})
	var b: DDBalance = run.bal
	var body: PackedStringArray = []
	var st: String = run.room_status(i)
	body.append("Room %d of %d in %s. Price %d points. Status: %s." % [i + 1, run.room_count(), str(run.district().get("name", "")), b.shown(int(r.get("cost", 0))),
		{"open": "OPEN", "next": "next door you can open", "locked": "locked (rooms open in order)"}[st]])
	body.append("Opening it (between streets, free action): its loot is shuffled into the deck at once - %s - and from the next wave on it restocks %d of those per wave." % [_pack_text(r.get("pack", [])), b.num("restock_per_room")])
	body.append("Machine: %s. %s" % [DDText.machine_name(str(m.get("kind", ""))), DDText.machine_text(m, b)])
	body.append("Rooms close again when you leave the district.")
	return {"kind": "R", "tag": "DOOR - " + DDText.machine_name(str(m.get("kind", ""))).to_upper(), "title": str(r.get("name", "")),
		"big": str(b.shown(int(r.get("cost", 0)))), "body": "\n".join(body)}


static func _pack_text(pack: Array) -> String:
	var p: PackedStringArray = []
	for spec: Variant in pack:
		var s: String = str(spec)
		match s.substr(0, 1):
			"W":
				p.append("a weapon from the district")
			"A":
				p.append("Ammo %s" % s.substr(1))
			"M":
				p.append("Medkit %s" % s.substr(1))
			"B":
				p.append("Barricade %s" % s.substr(1))
	return ", ".join(p)


static func room_spec(run: DDRun, i: int, selected: bool) -> Dictionary:
	var r: Dictionary = run.room(i)
	var m: Dictionary = r.get("machine", {})
	var st: String = run.room_status(i)
	var lines: Array = []
	var badge: String = ""
	var kind: String = "R"
	if st == "open":
		kind = "K"
		if run.machine_used(i):
			lines.append(["used this wave", DDUi.TEXT_DIM, DDUi.FONT_S - 3])
		else:
			var opts: Array[Dictionary] = run.machine_options(i)
			var price: int = int(opts[0]["price"]) if not opts.is_empty() else 0
			lines.append(["USE %d" % run.bal.shown(price), DDUi.GOOD if (not opts.is_empty() and run.points >= price) else DDUi.WARN, DDUi.FONT_S - 3])
	elif st == "next":
		var cost: int = int(r.get("cost", 0))
		lines.append(["OPEN %d" % run.bal.shown(cost), DDUi.GOOD if run.points >= cost else DDUi.WARN, DDUi.FONT_S - 3])
	else:
		badge = "LOCKED"
		lines.append(["%d - locked" % run.bal.shown(int(r.get("cost", 0))), DDUi.TEXT_DIM, DDUi.FONT_S - 3])
	var title: String = DDText.machine_name(str(m.get("kind", ""))) if st == "open" else str(r.get("name", ""))
	return {"kind": kind, "tag": str(r.get("name", "")).to_upper() if st == "open" else "DOOR", "title": title, "lines": lines,
		"badge": badge, "badge_color": DDUi.TEXT_DIM, "compact": true, "row": true, "selected": selected, "dim": st == "locked",
		"payload": room_payload(run, i)}


static func buff_payload(id: String, bal: DDBalance) -> Dictionary:
	if id == "payday":
		return {"kind": "X", "tag": "PAYDAY (this wave)", "title": "Payday", "big": "x2",
			"body": "Kills give double points until the end of the wave (Carrier drop or Jawbreaker)."}
	return {"kind": "J", "tag": "JAWBREAKER (this wave)", "title": DDText.buff_name(id), "big": "",
		"body": "%s: %s It ends with the wave." % [DDText.buff_name(id), DDText.buff_text(id, bal).capitalize()]}


static func buff_spec(id: String, bal: DDBalance) -> Dictionary:
	return {"kind": "X" if id == "payday" else "J", "tag": "WAVE BUFF", "title": DDText.buff_name(id), "title_size": DDUi.FONT_S - 5, "compact": true, "row": true,
		"payload": buff_payload(id, bal)}


# ---------------------------------------------------------------- perks, survivors, unlocks
static func perk(id: String, bal: DDBalance) -> Dictionary:
	return {"kind": "P", "tag": "PERK", "title": DDText.perk_name(id), "big": "",
		"body": DDText.perk_text(id, bal) + "\nPerks last the rest of the run."}


static func perk_spec(id: String, bal: DDBalance, compact: bool, selected: bool = false, badge: String = "") -> Dictionary:
	var lines: Array = []
	if not compact:
		lines.append([DDText.perk_text(id, bal), DDUi.TEXT, DDUi.FONT_S])
	return {"kind": "P", "tag": "PERK", "title": DDText.perk_name(id), "lines": lines, "compact": compact,
		"selected": selected, "badge": badge, "badge_color": DDUi.GOOD, "payload": perk(id, bal)}


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
		if prof.best_v1(id) > 0:
			body.append("Old record (v1 rules): %d" % prof.best_v1(id))
		if prof.badges(id) > 0:
			body.append("Survivor's Mark x%d (runs won)" % prof.badges(id))
	return {"kind": "S", "tag": "SURVIVOR", "title": str(s.get("name", id)), "big": str(bal.survivor_max_hp(id)),
		"body": "\n".join(body)}


static func unlock_hint(milestone: String, bal: DDBalance) -> String:
	if milestone == "win":
		return "win a run"
	for d: Variant in bal.districts():
		if str((d as Dictionary).get("id", "")) == milestone:
			return "clear %s" % str((d as Dictionary).get("name", milestone))
	return "keep playing"


## Zoom payload for an unlock key from DDProfile ("perk:x", "survivor:x", "badge:x").
static func unlock(key: String, bal: DDBalance, prof: DDProfile) -> Dictionary:
	if key.begins_with("perk:"):
		var p: Dictionary = perk(key.trim_prefix("perk:"), bal)
		p["tag"] = "NEW PERK UNLOCKED"
		p["body"] = str(p["body"]) + "\nIt can now be offered at safehouses."
		return p
	if key.begins_with("survivor:"):
		var s: Dictionary = survivor(key.trim_prefix("survivor:"), bal, prof)
		s["tag"] = "NEW SURVIVOR UNLOCKED"
		return s
	if key.begins_with("badge:"):
		var sid: String = key.trim_prefix("badge:")
		return {"kind": "S", "tag": "NEW BADGE", "title": "Survivor's Mark", "big": "*",
			"body": "%s made it out of the city. The mark shows on the title screen." % str(bal.survivor(sid).get("name", sid))}
	return {"kind": "D", "tag": "NEW", "title": key, "body": ""}


static func cover(run: DDRun) -> Dictionary:
	return {"kind": "B", "tag": "COVER", "title": "Cover", "big": str(run.cover),
		"body": "Cover soaks up damage before your HP does. It goes away at the end of the street."}


static func how_to_play(bal: DDBalance) -> Dictionary:
	var b: PackedStringArray = []
	b.append("Hold out across 3 districts, 3 waves each. Every street deals %d cards; you take %d actions: resolve a card, or reload a gun (max 1 reload per street). What you leave is the Holdover." % [bal.num("street_size"), bal.num("actions_per_street")])
	b.append("ZOMBIES: fight with slot 1, slot 2 or bare hands. You take strength - power. Every kill notches that weapon: it then only hits zombies weaker than that kill.")
	b.append("GUNS spend 1 round per kill. RELOAD drops what's left, loads a fresh magazine from your reserve and clears the notch. MELEE never runs out (+%d up close); its notch clears every wave." % bal.shown(int(bal.points("up_close"))))
	b.append("The deck is the wave: when it can't fill a street, the wave ends. SKIP a full street before acting: its cards come back next wave. Never two skips in a row.")
	b.append("POINTS from kills buy DOORS (more loot + a machine) and MACHINES: Retrofit Bench, Grin Machine, Lucky Locker, Wall Rack. Every price and result is shown before you pay.")
	b.append("Wave 3 ends with the face-up boss. A safehouse between districts heals %d and offers a perk." % bal.num("safehouse_heal"))
	b.append("Long press or right click anything to read it.")
	return {"kind": "D", "tag": "HOW TO PLAY", "title": "Last Stand", "big": "", "body": "\n\n".join(b)}
