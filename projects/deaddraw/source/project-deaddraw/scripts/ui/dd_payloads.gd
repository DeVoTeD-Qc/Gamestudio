# dd_payloads.gd
# Purpose: Builds the zoom (inspect) payloads and card-tile specs for everything on screen, so
#   every card, the weapon slot, deck counter, Finale, perks and survivors carry rules text.
# Dependencies: DDRun, DDText, DDBalance, DDProfile, DDUi.
# Author: Mechanics Developer Agent
class_name DDPayloads
extends RefCounted


static func card(c: DDCard, run: DDRun) -> Dictionary:
	var k: String = "F" if c.is_finale() else c.kind
	var tag: String = DDText.kind_label(c.kind)
	if c.is_finale():
		tag = "FINALE " + tag + " - " + DDText.trait_name(c.boss_trait).to_upper()
	return {"kind": k, "tag": tag, "title": DDText.card_name(c), "big": str(c.value),
		"body": DDText.card_rules(c, run, run.bal if run != null else DDBalance.get_default())}


## Tile spec for a street card, with the outcome preview lines.
static func street_card_spec(c: DDCard, i: int, run: DDRun, selected: bool) -> Dictionary:
	var lines: Array = []
	var badge: String = ""
	var badge_color: Color = DDUi.WARN
	match c.kind:
		DDCard.ZOMBIE:
			var pb: Dictionary = run.preview(i, DDRun.BARE)
			lines.append([_loss_text("Bare", pb), DDUi.BAD, DDUi.FONT_S])
			if run.weapon > 0:
				var pw: Dictionary = run.preview(i, DDRun.WEAPON)
				if bool(pw["enabled"]):
					lines.append([_loss_text(DDText.weapon_name(run.weapon), pw), DDUi.GOOD, DDUi.FONT_S])
				else:
					lines.append(["Weapon: " + str(pw["reason"]), DDUi.TEXT_DIM, DDUi.FONT_S])
		DDCard.WEAPON:
			lines.append(["Equip or Scrap", DDUi.TEXT_DIM, DDUi.FONT_S])
		DDCard.MEDKIT:
			var pm: Dictionary = run.preview(i, DDRun.USE)
			if bool(pm["wasted"]):
				badge = "WON'T HEAL"
				lines.append(["won't heal", DDUi.WARN, DDUi.FONT_S])
			elif int(pm["heal"]) <= 0:
				# dd-feel: at full HP a medkit heals nothing - say so instead of "+0 HP"
				badge = "FULL HP"
				lines.append(["full HP: heals 0", DDUi.WARN, DDUi.FONT_S])
			else:
				lines.append(["+%d HP" % int(pm["heal"]), DDUi.GOOD, DDUi.FONT_S])
		DDCard.BARRICADE:
			var pc: Dictionary = run.preview(i, DDRun.USE)
			lines.append(["+%d Cover" % int(pc["cover_gain"]), DDUi.COVER, DDUi.FONT_S])
	if c.is_finale():
		badge = DDText.trait_name(c.boss_trait).to_upper()
		badge_color = DDUi.accent("F")
	elif c.holdover and badge == "":
		badge = "HOLDOVER"
		badge_color = DDUi.TEXT_DIM
	return {"kind": "F" if c.is_finale() else c.kind, "tag": DDText.kind_label(c.kind), "badge": badge,
		"badge_color": badge_color, "big": str(c.value), "title": DDText.card_name(c), "lines": lines,
		"selected": selected, "payload": card(c, run)}


static func _loss_text(label: String, p: Dictionary) -> String:
	var t: String = "%s -%d" % [label, int(p["hp_loss"])]
	if bool(p["dies"]):
		t += " DIES"
	elif bool(p["second_wind"]):
		t += " (Second Wind)"
	return t


static func weapon_slot(run: DDRun) -> Dictionary:
	var body: PackedStringArray = []
	if run.weapon == 0:
		body.append("You are bare-handed: zombies deal their full strength.")
		body.append("Equip a weapon card to fight with it.")
	else:
		body.append("Power %d: a zombie you fight with it deals strength - %d (minimum 0)." % [run.weapon, run.weapon])
		if run.notch >= DDRun.NO_NOTCH:
			body.append("Fresh: no notch yet, it can hit anything.")
		else:
			body.append("Last notch: %d. It %s." % [run.notch, DDText.notch_tag(run.notch, run.passive)])
	body.append("Notch rule: every kill notches the weapon at that zombie's strength. Afterwards it only hits zombies weaker than its last notch%s." % (" (Rosa: or equal)" if run.passive == "steady_hands" else ""))
	body.append("Fighting bare-handed never changes the notch.")
	return {"kind": "W", "tag": "YOUR WEAPON", "title": DDText.weapon_name(run.weapon),
		"big": str(run.weapon) if run.weapon > 0 else "-", "body": "\n".join(body)}


static func weapon_slot_spec(run: DDRun) -> Dictionary:
	var lines: Array = []
	if run.weapon > 0:
		var notched: bool = run.notch < DDRun.NO_NOTCH
		lines.append([DDText.notch_tag(run.notch, run.passive), DDUi.WARN if notched else DDUi.GOOD, DDUi.FONT_S])
	else:
		lines.append(["no weapon", DDUi.TEXT_DIM, DDUi.FONT_S])
	return {"kind": "W", "tag": "WEAPON", "big": str(run.weapon) if run.weapon > 0 else "-",
		"big_size": 44, "title": DDText.weapon_name(run.weapon), "lines": lines, "compact": true,
		"payload": weapon_slot(run)}


static func deck(run: DDRun) -> Dictionary:
	var c: Dictionary = run.deck_counts()
	var body: PackedStringArray = []
	body.append("%d cards left in the deck." % run.deck.size())
	body.append("Zombies %d: %s" % [(c["Z"] as Array).size(), _list(c["Z"])])
	body.append("Weapons %d: %s" % [(c["W"] as Array).size(), _list(c["W"])])
	body.append("Medkits %d: %s" % [(c["M"] as Array).size(), _list(c["M"])])
	body.append("Barricades %d: %s" % [(c["B"] as Array).size(), _list(c["B"])])
	var bottom: Array[DDCard] = run.bottom_cards()
	var extra: Array = []
	if not bottom.is_empty():
		body.append("")
		body.append("%d retreated card%s at the bottom of the deck (they come back last, right before the Finale):" % [bottom.size(), "" if bottom.size() == 1 else "s"])
		for b: DDCard in bottom:
			extra.append({"kind": b.kind, "big": str(b.value), "title": DDText.card_name(b)})
	return {"kind": "D", "tag": "DECK", "title": "Cards left", "big": str(run.deck.size()),
		"body": "\n".join(body), "extra_cards": extra}


static func deck_spec(run: DDRun) -> Dictionary:
	var lines: Array = []
	var nb: int = run.bottom_cards().size()
	if nb > 0:
		lines.append(["%d at bottom" % nb, DDUi.WARN, DDUi.FONT_S])
	else:
		lines.append(["cards left", DDUi.TEXT_DIM, DDUi.FONT_S])
	return {"kind": "D", "tag": "DECK", "big": str(run.deck.size()), "big_size": 44, "title": "",
		"lines": lines, "compact": true, "payload": deck(run)}


static func _list(a: Array) -> String:
	if a.is_empty():
		return "none"
	var p: PackedStringArray = []
	for v: Variant in a:
		p.append(str(int(v)))
	return ", ".join(p)


static func finale(d: Dictionary) -> Dictionary:
	var f: Dictionary = d.get("finale", {})
	var zs: PackedStringArray = []
	for z: Variant in f.get("zombies", []):
		zs.append(str(int(z)))
	var t: String = str(f.get("trait", ""))
	var body: PackedStringArray = []
	body.append("%s's Finale, face up from the start: %s %s." % [str(d.get("name", "")), "zombies" if zs.size() > 1 else "zombie", " / ".join(zs)])
	body.append("%s: %s" % [DDText.trait_name(t), DDText.trait_text(t)])
	body.append("When the deck is empty, the Finale joins the Holdover to make the Finale street. Resolve every card, no Holdover, no retreat. Clear it to clear the district.")
	return {"kind": "F", "tag": "FINALE - " + str(d.get("name", "")).to_upper(), "title": str(f.get("name", "")),
		"big": "/".join(zs), "body": "\n".join(body)}


static func finale_spec(d: Dictionary, compact: bool = true, badge: String = "") -> Dictionary:
	var f: Dictionary = d.get("finale", {})
	var p: Dictionary = finale(d)
	return {"kind": "F", "tag": "FINALE", "badge": badge, "badge_color": DDUi.accent("F"),
		"big": p["big"], "big_size": 40 if compact else 56, "title": str(f.get("name", "")),
		"lines": [[DDText.trait_name(str(f.get("trait", ""))), DDUi.accent("F"), DDUi.FONT_S]],
		"compact": compact, "payload": p}


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
		body.append("Best score: %d" % prof.best_score(id))
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
	b.append("Every street deals %d cards. Resolve %d of them, one at a time, in any order. The last one is the Holdover and waits for the next street." % [bal.num("street_size"), bal.num("resolve_per_street")])
	b.append("ZOMBIES hurt you by their strength. Fight with your weapon to take strength - power. Each kill notches the weapon: it then only hits zombies weaker than that kill.")
	b.append("WEAPONS: Equip (replaces yours, fresh) or Scrap.  MEDKITS: heal, only one per street.  BARRICADES: Cover that soaks damage this street.")
	b.append("RETREAT before touching a street: its cards go to the bottom of the deck and come back late. Never two streets in a row, never on the Finale.")
	b.append("Each district ends with a face-up Finale. Clear all 3 districts to win. Between districts: a safehouse heals %d and offers a perk." % bal.num("safehouse_heal"))
	b.append("Long press or right click anything to read it.")
	return {"kind": "D", "tag": "HOW TO PLAY", "title": "Surviving the street", "big": "", "body": "\n\n".join(b)}
