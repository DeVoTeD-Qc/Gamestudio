# dd_run.gd
# Purpose: The whole DeadDraw rules engine for one run (3 districts), with no nodes or UI.
#   Every rule mirrors projects/deaddraw/tools/sim_deaddraw.py (apply / play_district /
#   play_run): street of 4, resolve 3, Holdover, Retreat (not twice in a row, cards go to the
#   bottom of the deck by default), Equip/Scrap, the Notch rule, one medkit per street,
#   barricade Cover, face-up Finales, safehouse heal + perk pick, survivor passives, scoring.
#   The UI only calls the public methods below and renders the returned event dictionaries.
# Dependencies: DDBalance, DDCard, DDText.
# Author: Mechanics Developer Agent
class_name DDRun
extends RefCounted

## Emitted after every state change with an event dictionary (see _event()).
signal changed(ev: Dictionary)

enum Phase { STREET, SAFEHOUSE, DEAD, WON }

const NO_NOTCH: int = 99

# Choices for resolve()
const BARE: String = "bare"
const WEAPON: String = "weapon"
const EQUIP: String = "equip"
const SCRAP: String = "scrap"
const USE: String = "use"

var bal: DDBalance
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var survivor_id: String = ""
var passive: String = ""
var hp: int = 20
var max_hp: int = 20
var weapon: int = 0                 # 0 = bare hands
var notch: int = NO_NOTCH           # last kill with this weapon; NO_NOTCH = fresh
var cover: int = 0
var medkits_used: int = 0           # medkits resolved this street (healing or not)
var fled_last: bool = false         # the previous street was a retreat
var second_wind: bool = false       # Second Wind still unused
var perks: Array[String] = []
var perk_pool: Array[String] = []   # perks unlocked when the run started
var perk_offer: Array[String] = []  # safehouse offer

var district_index: int = 0
var deck: Array[DDCard] = []        # top of the deck is the back (pop_back), like the sim
var street: Array[DDCard] = []
var finale_in: bool = false         # the Finale street has been dealt
var resolved_count: int = 0         # cards resolved on the current street
var to_resolve: int = 3             # cards that must be resolved on the current street
var street_was_full: bool = false   # the street had street_size cards when dealt
var phase: Phase = Phase.STREET

var district_scores: Array[int] = []
var cleared_ids: Array[String] = []
var streets_played: int = 0
var retreats: int = 0
var log_lines: Array[String] = []


func _init(balance: DDBalance = null) -> void:
	bal = balance if balance != null else DDBalance.get_default()


# ================================================================ run setup
## Starts a run. pool = the perks unlocked on the profile (offered at safehouses).
func start(survivor: String, pool: Array[String], seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	survivor_id = survivor
	var s: Dictionary = bal.survivor(survivor)
	passive = str(s.get("passive", ""))
	hp = bal.survivor_hp(survivor)
	max_hp = bal.survivor_max_hp(survivor)
	weapon = int(s.get("kit_weapon", 0))
	notch = NO_NOTCH
	perks.clear()
	perk_pool = pool.duplicate()
	perk_offer.clear()
	second_wind = false
	district_index = 0
	district_scores.clear()
	cleared_ids.clear()
	streets_played = 0
	retreats = 0
	log_lines.clear()
	phase = Phase.STREET
	_start_district()


func district() -> Dictionary:
	return bal.district(district_index)


func finale() -> Dictionary:
	return district().get("finale", {})


func finale_cards() -> Array[DDCard]:
	var f: Dictionary = finale()
	var out: Array[DDCard] = []
	for z: Variant in f.get("zombies", []):
		out.append(DDCard.make(DDCard.ZOMBIE, int(z), str(f.get("trait", "boss")), str(f.get("name", "Finale"))))
	return out


static func build_deck(d: Dictionary) -> Array[DDCard]:
	var out: Array[DDCard] = []
	for v: Variant in d.get("zombies", []):
		out.append(DDCard.make(DDCard.ZOMBIE, int(v)))
	for v: Variant in d.get("weapons", []):
		out.append(DDCard.make(DDCard.WEAPON, int(v)))
	for v: Variant in d.get("medkits", []):
		out.append(DDCard.make(DDCard.MEDKIT, int(v)))
	for v: Variant in d.get("barricades", []):
		out.append(DDCard.make(DDCard.BARRICADE, int(v)))
	return out


func _shuffle(a: Array) -> void:
	# Fisher-Yates with our own rng so runs are reproducible from a seed.
	for k: int in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, k)
		var t: Variant = a[k]
		a[k] = a[j]
		a[j] = t


func _start_district() -> void:
	deck = build_deck(district())
	_shuffle(deck)
	street.clear()
	fled_last = false
	finale_in = false
	var axe: int = bal.num("fire_axe_power")
	if has_perk("fire_axe") and (weapon < axe or notch < NO_NOTCH):
		weapon = axe
		notch = NO_NOTCH
		_log("Axe in the Trunk: you grab a fresh %s." % DDText.weapon_name(axe))
	_log("You enter %s." % str(district().get("name", "the district")))
	_begin_street()


## Test/debug hook: replace the deck (top card first) and the street, then deal.
func setup_street(deck_codes: Array, street_codes: Array = [], deal: bool = true) -> void:
	deck.clear()
	for k: int in range(deck_codes.size() - 1, -1, -1):
		deck.append(_as_card(deck_codes[k]))
	street.clear()
	for c: Variant in street_codes:
		street.append(_as_card(c))
	finale_in = false
	phase = Phase.STREET
	if deal:
		_begin_street()


func _as_card(c: Variant) -> DDCard:
	return c if c is DDCard else DDCard.parse(str(c))


func _begin_street() -> void:
	var size: int = bal.num("street_size")
	while street.size() < size and not deck.is_empty():
		var dealt: DDCard = deck.pop_back()
		dealt.retreated = false
		street.append(dealt)
	if deck.is_empty() and not finale_in and street.size() <= 1:
		street.append_array(finale_cards())
		finale_in = true
		_log("The Finale arrives: %s." % str(finale().get("name", "")))
	if street.is_empty():
		_clear_district()
		return
	cover = bal.rule("tripwire_cover") if (has_perk("tripwire") and fled_last) else 0
	if cover > 0:
		_log("Tripwire: you start this street with %d Cover." % cover)
	medkits_used = 0
	resolved_count = 0
	street_was_full = street.size() == size
	if finale_in:
		to_resolve = street.size()
	else:
		to_resolve = mini(bal.num("resolve_per_street"), street.size())
		if street.size() < size:
			to_resolve = maxi(1, street.size() - 1)


# ================================================================ queries
func has_perk(id: String) -> bool:
	return perks.has(id)


func is_quarantine() -> bool:
	return finale_in and str(finale().get("trait", "")) == "quarantine"


func cards_left_to_resolve() -> int:
	return to_resolve - resolved_count


func medkit_limit() -> int:
	return bal.rule("triage_medkits_per_street") if passive == "triage" else bal.rule("medkits_per_street")


func medkit_would_heal() -> bool:
	return medkits_used < medkit_limit() and not is_quarantine()


func can_use_weapon_on(strength: int) -> bool:
	if weapon == 0:
		return false
	if passive == "steady_hands":
		return strength <= notch
	return strength < notch


## Short reason why the weapon cannot hit this zombie ("" if it can).
func weapon_block_reason(strength: int) -> String:
	if weapon == 0:
		return "no weapon"
	if can_use_weapon_on(strength):
		return ""
	return DDText.notch_tag(notch, passive)


func can_retreat() -> bool:
	return phase == Phase.STREET and resolved_count == 0 and not finale_in \
		and street.size() == bal.num("street_size") and not fled_last


func retreat_block_reason() -> String:
	if phase != Phase.STREET:
		return "not on a street"
	if finale_in:
		return "no retreat from the Finale"
	if fled_last:
		return "you retreated last street"
	if resolved_count > 0:
		return "you already started searching"
	if street.size() != bal.num("street_size"):
		return "street is short"
	return ""


## Theo's Slip Away: after resolving exactly 1 card of a full street, the other 3 go back.
func can_slip_away() -> bool:
	return phase == Phase.STREET and passive == "slip_away" and resolved_count == 1 \
		and street_was_full and not finale_in and not fled_last


func choices_for(index: int) -> Array[String]:
	var out: Array[String] = []
	if index < 0 or index >= street.size():
		return out
	var c: DDCard = street[index]
	match c.kind:
		DDCard.ZOMBIE:
			out.append(BARE)
			out.append(WEAPON)   # may be disabled; see preview()["enabled"]
		DDCard.WEAPON:
			out.append(EQUIP)
			if bal.weapon_scrap():
				out.append(SCRAP)
		_:
			out.append(USE)
	return out


## What resolving street[index] with `choice` would do, without changing anything.
## Keys: enabled, reason, kind, value, choice, dmg (before cover), blocked (by weapon),
## absorbed (by cover), hp_loss, heal, cover_gain, weapon_after, notch_after, breaks,
## second_wind, dies, text (one-line log).
func preview(index: int, choice: String) -> Dictionary:
	var r: Dictionary = {"enabled": false, "reason": "", "choice": choice, "dmg": 0, "blocked": 0,
		"absorbed": 0, "hp_loss": 0, "heal": 0, "cover_gain": 0, "weapon_after": weapon,
		"notch_after": notch, "breaks": false, "second_wind": false, "dies": false, "text": "",
		"hp_after": hp, "wasted": false}
	if phase != Phase.STREET:
		r["reason"] = "not on a street"
		return r
	if index < 0 or index >= street.size():
		r["reason"] = "no such card"
		return r
	if resolved_count >= to_resolve:
		r["reason"] = "street done"
		return r
	var c: DDCard = street[index]
	r["kind"] = c.kind
	r["value"] = c.value
	var cname: String = DDText.card_name(c)
	if not choices_for(index).has(choice):
		r["reason"] = "not a choice for this card"
		return r
	match c.kind:
		DDCard.ZOMBIE:
			var dmg: int = c.value
			if choice == WEAPON:
				var why: String = weapon_block_reason(c.value)
				if why != "":
					r["reason"] = why
					return r
				dmg = maxi(0, c.value - weapon)
				r["blocked"] = c.value - dmg
				if c.boss_trait == "shatter":
					r["breaks"] = true
					r["weapon_after"] = 0
					r["notch_after"] = NO_NOTCH
				else:
					r["notch_after"] = c.value
			else:
				if has_perk("knuckle_wraps"):
					var red: int = mini(dmg, bal.rule("knuckle_wraps_reduction"))
					r["blocked"] = red
					dmg -= red
			r["dmg"] = dmg
			var absorbed: int = mini(cover, dmg)
			r["absorbed"] = absorbed
			var loss: int = dmg - absorbed
			var after: int = hp - loss
			if after <= 0 and second_wind:
				r["second_wind"] = true
				after = bal.rule("second_wind_hp")
			r["hp_loss"] = hp - after
			r["hp_after"] = after
			r["dies"] = after <= 0
			r["text"] = _fight_text(cname, c, choice, r)
		DDCard.WEAPON:
			if choice == EQUIP:
				r["weapon_after"] = c.value
				r["notch_after"] = NO_NOTCH
				if weapon > 0:
					r["text"] = "Equipped %s (%d), dropped %s." % [cname, c.value, DDText.weapon_name(weapon)]
				else:
					r["text"] = "Equipped %s (%d)." % [cname, c.value]
			else:
				r["text"] = "Scrapped %s (%d)." % [cname, c.value]
		DDCard.MEDKIT:
			if medkit_would_heal():
				var heal: int = c.value + (bal.rule("field_kit_bonus") if has_perk("field_kit") else 0)
				if passive == "triage":
					heal += bal.num("triage_heal_bonus")
				var after_h: int = mini(max_hp, hp + heal)
				r["heal"] = after_h - hp
				r["hp_after"] = after_h
				r["text"] = "%s: healed %d HP." % [cname, after_h - hp]
			else:
				r["wasted"] = true
				if is_quarantine():
					r["text"] = "%s: Quarantine, no healing on the Finale street." % cname
				else:
					r["text"] = "%s: used up, medkit limit reached this street." % cname
		DDCard.BARRICADE:
			var gain: int = c.value + (bal.rule("sandbags_bonus") if has_perk("sandbags") else 0)
			r["cover_gain"] = gain
			r["text"] = "%s: +%d Cover this street." % [cname, gain]
	r["enabled"] = true
	return r


func _fight_text(cname: String, c: DDCard, choice: String, r: Dictionary) -> String:
	var t: String = "%s %d: " % [cname, c.value]
	if choice == WEAPON:
		t += "%s blocked %d" % [DDText.weapon_name(weapon), int(r["blocked"])]
	else:
		t += "bare-handed"
		if int(r["blocked"]) > 0:
			t += ", wraps blocked %d" % int(r["blocked"])
	if int(r["absorbed"]) > 0:
		t += ", Cover soaked %d" % int(r["absorbed"])
	t += ", you took %d." % int(r["hp_loss"])
	if bool(r["breaks"]):
		t += " Shatter: your weapon broke."
	elif choice == WEAPON:
		t += " Notch now %d." % int(r["notch_after"])
	if bool(r["second_wind"]):
		t += " Second Wind: you hang on at %d HP." % int(r["hp_after"])
	return t


# ================================================================ actions
## Resolves street[index]. Returns the event (empty "ok" false if illegal).
func resolve(index: int, choice: String) -> Dictionary:
	var p: Dictionary = preview(index, choice)
	if not bool(p["enabled"]):
		return {"ok": false, "reason": p["reason"]}
	var c: DDCard = street[index]
	var hp_before: int = hp
	match c.kind:
		DDCard.ZOMBIE:
			cover -= int(p["absorbed"])
			hp = int(p["hp_after"])
			if bool(p["second_wind"]):
				second_wind = false
			if choice == WEAPON:
				weapon = int(p["weapon_after"])
				notch = int(p["notch_after"])
		DDCard.WEAPON:
			if choice == EQUIP or not bal.weapon_scrap():
				weapon = c.value
				notch = NO_NOTCH
		DDCard.MEDKIT:
			hp = int(p["hp_after"])
			medkits_used += 1
		DDCard.BARRICADE:
			cover += int(p["cover_gain"])
	street.remove_at(index)
	c.holdover = false
	resolved_count += 1
	_log(str(p["text"]))
	var ev: Dictionary = _event("resolve", p["text"], hp - hp_before)
	ev["card"] = c
	ev["choice"] = choice
	ev["preview"] = p
	if hp <= 0:
		hp = 0
		_die()
		ev["dead"] = true
		ev["phase"] = phase
		changed.emit(ev)
		return ev
	if resolved_count >= to_resolve:
		ev.merge(_end_street(), true)
	ev["phase"] = phase
	changed.emit(ev)
	return ev


func _end_street() -> Dictionary:
	var out: Dictionary = {"street_ended": true}
	streets_played += 1
	fled_last = false
	for c: DDCard in street:
		c.holdover = true
	if street.size() > 0:
		out["holdover"] = street[0]
		_log("Holdover: %s stays for the next street." % DDText.card_name(street[0]))
	var was_finale: bool = finale_in
	var before: int = district_index
	_begin_street()
	if was_finale or phase != Phase.STREET or district_index != before:
		out["district_cleared"] = true
	return out


func retreat() -> Dictionary:
	if not can_retreat():
		return {"ok": false, "reason": retreat_block_reason()}
	return _send_back("Retreat")


func slip_away() -> Dictionary:
	if not can_slip_away():
		return {"ok": false, "reason": "Slip Away not available"}
	return _send_back("Slip Away")


func _send_back(label: String) -> Dictionary:
	var back: Array[DDCard] = street.duplicate()
	street.clear()
	for c: DDCard in back:
		c.holdover = false
	_shuffle(back)
	if bal.retreat_mode() == "shuffle":
		deck.append_array(back)
		_shuffle(deck)
		_log("%s: %d cards shuffled back into the deck." % [label, back.size()])
	else:
		# bottom of the deck = the front of the array (we deal from the back)
		for c: DDCard in back:
			c.retreated = true
		var nd: Array[DDCard] = back.duplicate()
		nd.append_array(deck)
		deck = nd
		_log("%s: %d cards go to the bottom of the deck." % [label, back.size()])
	fled_last = true
	retreats += 1
	streets_played += 1
	var text: String = log_lines[log_lines.size() - 1]
	var hp_before: int = hp
	if has_perk("scrounger"):
		hp = mini(max_hp, hp + bal.rule("scrounger_heal"))
		if hp > hp_before:
			text += " Scrounger: +%d HP." % (hp - hp_before)
			_log("Scrounger: +%d HP." % (hp - hp_before))
	_begin_street()
	var ev: Dictionary = _event("retreat", text, hp - hp_before)
	ev["returned"] = back
	ev["phase"] = phase
	changed.emit(ev)
	return ev


func _clear_district() -> void:
	var score: int = bal.rule("score_per_district") + hp
	district_scores.append(score)
	cleared_ids.append(str(district().get("id", "")))
	_log("%s cleared! District score %d." % [str(district().get("name", "")), score])
	street.clear()
	if district_index >= bal.district_count() - 1:
		phase = Phase.WON
		_log("You made it out of the city. Run score %d." % run_score())
		return
	phase = Phase.SAFEHOUSE
	var before: int = hp
	hp = mini(max_hp, hp + bal.num("safehouse_heal"))
	_log("Safehouse: you rest and heal %d HP." % (hp - before))
	_make_offer()


func _make_offer() -> void:
	var pool: Array[String] = []
	for p: String in perk_pool:
		if not perks.has(p):
			pool.append(p)
	_shuffle(pool)
	perk_offer = pool.slice(0, mini(bal.num("perk_choices"), pool.size()))


func safehouse_healed() -> int:
	return bal.num("safehouse_heal")


## Pick a safehouse perk (or "" when the offer is empty) and head to the next district.
func choose_perk(id: String) -> Dictionary:
	if phase != Phase.SAFEHOUSE:
		return {"ok": false, "reason": "not at a safehouse"}
	if id == "" and not perk_offer.is_empty():
		return {"ok": false, "reason": "pick a perk"}
	if id != "" and not perk_offer.has(id):
		return {"ok": false, "reason": "perk not offered"}
	var hp_before: int = hp
	if id != "":
		perks.append(id)
		if id == "thick_jacket":
			var j: int = bal.rule("thick_jacket_hp")
			max_hp += j
			hp += j
		elif id == "second_wind":
			second_wind = true
		_log("Perk taken: %s." % DDText.perk_name(id))
	perk_offer.clear()
	district_index += 1
	phase = Phase.STREET
	_start_district()
	var ev: Dictionary = _event("perk", "Perk taken: %s." % DDText.perk_name(id) if id != "" else "On the road.", hp - hp_before)
	ev["phase"] = phase
	changed.emit(ev)
	return ev


func _die() -> void:
	phase = Phase.DEAD
	district_scores.append(0)
	_log("You were overrun in %s. Run score %d." % [str(district().get("name", "")), run_score()])


func run_score() -> int:
	var t: int = 0
	for s: int in district_scores:
		t += s
	return t


# ================================================================ helpers
func deck_counts() -> Dictionary:
	var out: Dictionary = {"Z": [], "W": [], "M": [], "B": []}
	for c: DDCard in deck:
		(out[c.kind] as Array).append(c.value)
	for k: String in out:
		(out[k] as Array).sort()
	return out


## Retreated cards waiting at the bottom of the deck, next-to-come first (bottom mode only).
func bottom_cards() -> Array[DDCard]:
	var out: Array[DDCard] = []
	for k: int in range(deck.size() - 1, -1, -1):
		if deck[k].retreated:
			out.append(deck[k])
	return out


func _event(kind: String, text: String, hp_delta: int) -> Dictionary:
	return {"ok": true, "kind": kind, "text": text, "hp_delta": hp_delta, "hp": hp,
		"max_hp": max_hp, "street_ended": false, "district_cleared": false, "dead": false}


func _log(t: String) -> void:
	log_lines.append(t)
	if log_lines.size() > 200:
		log_lines.remove_at(0)
