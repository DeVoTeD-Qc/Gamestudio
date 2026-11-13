# dd_v4_hooks.gd
# Purpose: dd-v4-impl. Everything the views need for the v4 rules, kept out of main.gd and
#   dd_payloads.gd (both are being rebuilt by dd-ux-v4): the melee slot (Bare Hands or a melee
#   weapon with use pips), melee weapon cards on the street (TAKE / SCRAP), the Salvage "+N" a
#   swapped-out gun pays, the Stovepipe Launcher's single kill socket, the Run sentence and the
#   Safehouse Shop state. Every payload is the usual inspect dictionary (kind, tag, title, big,
#   body) plus the dd-ux-v4 2-line tooltip t1 / t2, so right click / long press works on all of it.
# Dependencies: DDRun, DDCard, DDText, DDBalance, DDUi.
# Author: Mechanics Developer Agent
class_name DDV4Hooks
extends RefCounted


# ---------------------------------------------------------------- melee slot
## Art lookup keys (dd_art.gd texture_for) for a melee id; "" or "bare_hands" = the taped fists.
static func melee_art_keys(mid: String, display_name: String = "") -> Array:
	var id: String = mid if mid != "" else "bare_hands"
	var out: Array = ["melee_" + id, "melee:" + id]
	if display_name != "":
		out.append(display_name.to_lower())
	if id == "bare_hands":
		out.append("bare hands")
	return out


## The melee tile: {name, id, power, uses, uses_max, bare, active, art_keys, lines, payload}.
## uses / uses_max drive the use pips (filled = uses left); bare = true shows no pips.
static func melee_spec(run: DDRun) -> Dictionary:
	var bare: bool = not run.has_melee_weapon()
	var id: String = "" if bare else str(run.melee.get("id", ""))
	var name: String = run.melee_name()
	var uses_max: int = 0 if bare else maxi(run.melee_uses(), run.bal.melee_uses(id))
	return {"kind": "K", "name": name, "id": id, "power": run.melee_power(), "uses": run.melee_uses(), "uses_max": uses_max,
		"bare": bare, "active": run.active == DDRun.MELEE, "art_keys": melee_art_keys(id, name),
		"lines": [["0 pts" if bare else DDText.uses_text(run.melee_uses()), DDUi.TEXT_DIM, DDUi.FONT_S - 5]], "payload": melee(run)}


## Melee zoom (replaces DDPayloads.melee for v4: Bare Hands or the weapon you hold).
static func melee(run: DDRun) -> Dictionary:
	var b: DDBalance = run.bal
	var on: String = " - ACTIVE" if run.active == DDRun.MELEE else ""
	if not run.has_melee_weapon():
		var body: String = "Always there. %s%s\nA melee weapon card (Pipe Wrench, Fire Axe, Sledgehammer) is stronger until its uses run out." % [
			DDText.bare_hands_text(b), ("\nBrawler: Bare Hands +%d strength." % b.num("brawler_bonus")) if run.has_patch("brawler") else ""]
		return {"kind": "K", "tag": "MELEE" + on, "title": run.melee_name(), "big": str(run.melee_power()), "body": body,
			"t1": "%s · strength %d · never breaks" % [run.melee_name(), run.melee_power()], "t2": "Any zombie, even one your guns can't take. No points."}
	var id: String = str(run.melee.get("id", ""))
	return {"kind": "K", "tag": "MELEE WEAPON" + on, "title": run.melee_name(), "big": str(run.melee_power()),
		"body": "%s\n%s left, then Bare Hands (strength %d)." % [DDText.melee_card_text(id, b, run.melee_uses()),
			DDText.uses_text(run.melee_uses()), b.num("hands_power")],
		"t1": "%s · strength %d" % [run.melee_name(), run.melee_power()],
		"t2": "Any zombie, even one your guns can't take. No points."}


# ---------------------------------------------------------------- melee weapon cards (street "K")
## Zoom for a melee weapon card on the street (or in a room pack).
static func melee_card(c: DDCard, run: DDRun, index: int = -1) -> Dictionary:
	var b: DDBalance = run.bal
	var uses: int = run.melee_take_uses(c.wid)
	var body: PackedStringArray = [DDText.melee_card_text(c.wid, b, uses)]
	if run.has_melee_weapon():
		body.append("TAKE replaces your %s (%s left)." % [run.melee_name(), DDText.uses_text(run.melee_uses())])
	else:
		body.append("TAKE: it replaces Bare Hands (strength %d)." % b.num("hands_power"))
	body.append("Or SCRAP it for %d pts." % b.shown(b.num("scrap_points")))
	if c.holdover:
		body.append("HOLDOVER: left from the last street.")
	return {"kind": "K", "tag": "MELEE WEAPON", "title": b.melee_name(c.wid), "big": str(b.melee_power(c.wid)), "body": "\n".join(body),
		"t1": "%s · strength %d" % [b.melee_name(c.wid), b.melee_power(c.wid)],
		"t2": "Tap: TAKE it as your melee (no points), or SCRAP +%d." % b.shown(b.num("scrap_points"))}


## The street tile for a melee weapon card (same shape as DDPayloads.street_card_spec).
static func melee_card_spec(c: DDCard, i: int, run: DDRun) -> Dictionary:
	var b: DDBalance = run.bal
	var uses: int = run.melee_take_uses(c.wid)
	return {"kind": "K", "tag": "HOLDOVER" if c.holdover else "", "badge": "", "badge_color": DDUi.WARN, "badge_size": DDUi.FONT_M,
		"big": "", "title": b.melee_name(c.wid), "lines": [["strength %d · %s" % [b.melee_power(c.wid), DDText.uses_text(uses)], DDUi.accent("K"), DDUi.FONT_S]],
		"art_dim": false, "lock": "", "art_keys": melee_art_keys(c.wid, b.melee_name(c.wid)), "uses": uses, "payload": melee_card(c, run, i)}


## The TAKE / SCRAP sheet for a melee card: [{choice, label, enabled, reason}]. Tapping the card
## with DDRun.USE also takes it, so the current "tap a non-zombie card" path already works.
static func melee_choices(run: DDRun, i: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if i < 0 or i >= run.street.size() or run.street[i].kind != DDCard.MELEE:
		return out
	var c: DDCard = run.street[i]
	var tp: Dictionary = run.card_preview(i, DDRun.TAKE)
	var label: String = "TAKE · %s" % DDText.uses_text(int(tp.get("uses", 0)))
	if str(tp.get("replaces", "")) != "":
		label += "\nreplaces %s (%s left)" % [str(tp["replaces"]), DDText.uses_text(int(tp["replaces_uses"]))]
	out.append({"choice": DDRun.TAKE, "label": label, "enabled": bool(tp["ok"]), "reason": str(tp["reason"])})
	var sp: Dictionary = run.card_preview(i, DDRun.SCRAP)
	out.append({"choice": DDRun.SCRAP, "label": "SCRAP\n+%d pts" % run.bal.shown(int(sp.get("points", 0))), "enabled": bool(sp["ok"]), "reason": str(sp["reason"])})
	return out


# ---------------------------------------------------------------- guns: salvage, one shot
## Equip-sheet line for a gun slot: "INTO SLOT 1\nreplaces Hunting Rifle 3/4 · salvage +30".
static func equip_label(run: DDRun, i: int, s: int) -> String:
	var pv: Dictionary = run.card_preview(i, DDRun.EQUIP1 if s == 0 else DDRun.EQUIP2)
	var g: DDGun = run.slot(s)
	if g == null:
		return "INTO SLOT %d\n(empty)" % (s + 1)
	var t: String = "INTO SLOT %d\nreplaces %s %d/%d" % [s + 1, g.name, g.stack.size(), g.cap]
	if int(pv.get("salvage", 0)) > 0:
		t += " · salvage +%d" % run.bal.shown(int(pv["salvage"]))
	return t


## Salvage payouts in an event (street equip or Wall Rack): [{slot, units, shown, text}] for the
## "+N" float over that gun slot. Empty when nothing was salvaged.
static func salvage_floats(ev: Dictionary, bal: DDBalance) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for info: Variant in ev.get("collects", []):
		if info is Dictionary and int((info as Dictionary).get("salvage", 0)) > 0:
			var u: int = int(info["salvage"])
			out.append({"slot": int(info.get("slot", 0)), "units": u, "shown": bal.shown(u), "text": DDText.salvage_text(u, bal)})
	return out


## Kill sockets for a gun tile: capacity many; the launcher has exactly one (that IS its
## one-shot cue, no extra icon). [{filled, value}].
static func sockets(g: DDGun) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if g == null:
		return out
	for k: int in g.cap:
		out.append({"filled": k < g.stack.size(), "value": g.stack[k] if k < g.stack.size() else 0})
	return out


# ---------------------------------------------------------------- Run, shop
## The Run button's tooltip / zoom (v4: any time, cards to the bottom).
static func run_payload(run: DDRun) -> Dictionary:
	var why: String = run.run_block_reason()
	return {"kind": "D", "tag": "RUN", "title": "Run", "big": "-%d" % run.run_cost() if run.run_cost() > 0 else "0",
		"body": DDText.run_rule_text(run.bal) + ("\nNow: %s." % why if why != "" else ""),
		"t1": ("Run · -%d HP" % run.run_cost() if run.run_cost() > 0 else "Run · free") + " · not twice in a row",
		"t2": ("The %d cards here go to the bottom of the pile; you get a new street." % run.street.size()) if run.bal.text("run_return") == "bottom" else "The street goes back into the pile; you get a new street."}


## The supplies tile in the shop.
static func supplies_payload(run: DDRun) -> Dictionary:
	var b: DDBalance = run.bal
	return {"kind": "M", "tag": "SAFEHOUSE SHOP", "title": "Supplies", "big": "%d" % b.shown(run.supplies_rate()),
		"body": "%d pts per HP, up to your max HP after the free +%d rest. Healed now." % [b.shown(run.supplies_rate()), run.safehouse_heal()],
		"t1": "Supplies · %d pts per HP" % b.shown(run.supplies_rate()), "t2": "Heal now with points you can't take along."}


## The Leave button's tooltip.
static func leave_payload(run: DDRun) -> Dictionary:
	var lost: int = int(run.shop_state()["left_behind"])
	return {"kind": "X", "tag": "LEAVE", "title": DDText.leave_text(lost, run.bal), "big": str(run.bal.shown(lost)),
		"body": DDText.shop_text(run.bal) + "\nYour score keeps every point you earned.",
		"t1": DDText.leave_text(lost, run.bal), "t2": "Unspent points stay here; your score keeps them."}


## The Salvage "+N" feedback: floats "SALVAGE +30" over each gun slot that was salvaged in `ev`.
## feedback: the DDFeedback node (its _float(rect, text, color, delay)); gun_views: the two gun
## slot Controls (index = slot). Call it after a resolve / Wall Rack event. Returns the floats.
static func play_salvage(feedback: Object, gun_views: Array, ev: Dictionary, bal: DDBalance) -> Array[Dictionary]:
	var fl: Array[Dictionary] = salvage_floats(ev, bal)
	if feedback == null or not feedback.has_method("_float"):
		return fl
	for k: int in fl.size():
		var s: int = int(fl[k]["slot"])
		var v: Variant = gun_views[s] if s >= 0 and s < gun_views.size() else null
		if v is Control and is_instance_valid(v):
			feedback.call("_float", (v as Control).get_global_rect(), str(fl[k]["text"]), DDUi.accent("X"), 0.15 + 0.1 * k)
	return fl
