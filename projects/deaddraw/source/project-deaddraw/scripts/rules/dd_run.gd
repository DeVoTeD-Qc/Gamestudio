# dd_run.gd
# Purpose: The whole DeadDraw v2 rules engine for one run ("Last Stand" waves), with no nodes or
#   UI. Every rule mirrors projects/deaddraw/tools/sim_deaddraw_v2.py (mixed deck, hybrid "notch"
#   combat, reload_mode "drop"): 3 districts x 3 waves; one mixed deck per district (the current
#   wave's zombie pack + the loot of the Entrance and every opened room + last wave's Skipped
#   pile); the deck running out ends the wave; Skip sends the street to the Skipped pile, which
#   comes back in the next wave (boss wave: one last lap, then the face-up boss street). Street of
#   4, 3 actions (resolve a card or reload a gun, max one reload per street), Holdover. Two weapon
#   slots + bare hands; guns spend 1 round per kill from the magazine, melee is unlimited; every
#   weapon has the notch (reload clears it for guns, each new wave for melee). Rooms bought with
#   points add loot and a machine (Retrofit Bench, Grin Machine, Lucky Locker, Wall Rack). Carrier
#   zombies drop power-ups. Points (sim units; the UI shows x10), survivors, perks, safehouses.
#   The UI only calls the public methods below and renders the returned event dictionaries.
# Dependencies: DDBalance, DDCard, DDWeapon, DDText.
# Author: Mechanics Developer Agent
class_name DDRun
extends RefCounted

## Emitted after every state change with an event dictionary (see _event()).
signal changed(ev: Dictionary)

enum Phase { STREET, SAFEHOUSE, DEAD, WON }

const NO_NOTCH: int = 99

# Choices for resolve()
const BARE: String = "bare"
const SLOT1: String = "slot1"
const SLOT2: String = "slot2"
const EQUIP1: String = "equip1"
const EQUIP2: String = "equip2"
const SCRAP: String = "scrap"
const USE: String = "use"
## Kind words the feedback layer uses ("a weapon was used", "a weapon was equipped").
const WEAPON: String = "weapon"
const EQUIP: String = "equip"

var bal: DDBalance
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var survivor_id: String = ""
var passive: String = ""
var hp: int = 20
var max_hp: int = 20
var slots: Array = [null, null]       # DDWeapon or null
var reserve: int = 0                  # shared ammo reserve for every gun
var points: int = 0                   # spendable points (sim units)
var points_earned: int = 0            # every point gained this run (spending doesn't lower it)
var cover: int = 0
var medkits_used: int = 0             # medkits resolved this street (healing or not)
var fled_last: bool = false           # the previous street was skipped
var second_wind: bool = false         # Second Wind still unused
var perks: Array[String] = []
var perk_pool: Array[String] = []     # perks unlocked when the run started
var perk_offer: Array[String] = []    # safehouse offer
var buffs: Array[String] = []         # Jawbreakers / Payday drop: last until the end of the wave
var free_reload: bool = false         # Fast Hands: the first reload this wave costs no action
var reloads_left: int = 1

var district_index: int = 0
var wave_index: int = 0
var last_lap: bool = false            # boss wave: the Skipped pile came back for one last lap
var boss_street: bool = false         # the boss street has been dealt
var deck: Array[DDCard] = []          # top of the deck is the back (pop_back), like the sim
var street: Array[DDCard] = []
var skipped: Array[DDCard] = []       # the Skipped pile (face up), back in the next wave
var opened: Array[int] = []           # indices of opened rooms, in order
var machine_state: Array[Dictionary] = []   # per room: {used: bool (this wave), n: purchases}
var district_weapons: Array[String] = []    # the district's weapon pool, next one at the back

var actions_used: int = 0             # actions taken on this street (cards + paid reloads)
var budget: int = 3                   # actions this street allows
var cards_resolved: int = 0
var street_was_full: bool = false
var phase: Phase = Phase.STREET
## A weapon from the Lucky Locker or the Wall Rack waiting for a slot: {weapon, source, room}.
var pending_offer: Dictionary = {}
## Info about the last wave change, for the banner: see _wave_info().
var last_wave_info: Dictionary = {}

var boss_hp: Array[int] = []          # HP left after each boss (scored)
var cleared_ids: Array[String] = []
var streets_played: int = 0
var skips: int = 0
var reloads: int = 0
var kills: int = 0
var log_lines: Array[String] = []
var _notes: Array[String] = []


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
	max_hp = hp
	slots = [null, null]
	var kit: Array = bal.list("start_kit")
	for i: int in mini(2, kit.size()):
		slots[i] = make_weapon(str(kit[i]))
	reserve = bal.num("start_reserve")
	points = bal.num("start_points")
	points_earned = 0
	perks.clear()
	perk_pool = pool.duplicate()
	perk_offer.clear()
	second_wind = false
	buffs.clear()
	district_index = 0
	boss_hp.clear()
	cleared_ids.clear()
	streets_played = 0
	skips = 0
	reloads = 0
	kills = 0
	log_lines.clear()
	pending_offer = {}
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
		out.append(DDCard.make(DDCard.ZOMBIE, int(z), str(f.get("trait", "boss")), str(f.get("name", "Boss"))))
	return out


func wave_count() -> int:
	return bal.wave_count(district_index)


func is_boss_wave() -> bool:
	return wave_index >= wave_count() - 1


## A fresh weapon from its id (full magazine, no notch). Melee gets melee_power_bonus.
func make_weapon(wid: String) -> DDWeapon:
	return DDWeapon.make(wid, bal.weapon_name(wid), bal.weapon_power(wid), bal.weapon_mag(wid))


func _shuffle(a: Array) -> void:
	# Fisher-Yates with our own rng so runs are reproducible from a seed.
	for k: int in range(a.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, k)
		var t: Variant = a[k]
		a[k] = a[j]
		a[j] = t


func _pick(a: Array) -> Variant:
	return a[rng.randi_range(0, a.size() - 1)] if not a.is_empty() else null


## A loot card from a pack spec: "W" = the next weapon of the district pool, "A4" ammo 4, "M3"
## medkit 3, "B2" barricade 2 (sim make_loot()).
func make_loot(spec: String) -> DDCard:
	if spec == "W":
		if district_weapons.is_empty():
			return DDCard.make(DDCard.AMMO, bal.rule("empty_pool_ammo"))
		var id: String = district_weapons.pop_back()
		return DDCard.weapon(id, bal.weapon_power(id))
	return DDCard.make(spec.substr(0, 1), int(spec.substr(1)))


## The wave's zombie pack: one of them is a Carrier with a random drop (sim wave_pack()).
func wave_pack(w: int) -> Array[DDCard]:
	var out: Array[DDCard] = []
	for z: int in bal.wave_zombies(district_index, w):
		out.append(DDCard.make(DDCard.ZOMBIE, z))
	if not out.is_empty():
		var carrier: DDCard = _pick(out)
		var drops: Array = bal.list("drops")
		if not drops.is_empty():
			carrier.drop = str(_pick(drops))
	return out


func _start_district() -> void:
	var d: Dictionary = district()
	district_weapons.clear()
	for w: Variant in d.get("weapons", []):
		district_weapons.append(str(w))
	_shuffle(district_weapons)
	if has_perk("fire_axe"):
		var axe: DDWeapon = make_weapon("axe")
		axe.power = bal.num("fire_axe_power")
		var i: int = worst_slot()
		if wscore(axe) > wscore(slots[i]):
			var old: String = (slots[i] as DDWeapon).display_name() if slots[i] != null else ""
			slots[i] = axe
			_log("Axe in the Trunk: a fresh Fire Axe (%d) goes into slot %d%s." % [axe.power, i + 1, (" in place of your " + old) if old != "" else ""])
	opened.clear()
	machine_state.clear()
	for r: Variant in bal.rooms(district_index):
		machine_state.append({"used": false, "n": 0})
	wave_index = 0
	last_lap = false
	boss_street = false
	skipped.clear()
	street.clear()
	pending_offer = {}
	deck = wave_pack(0)
	for spec: Variant in d.get("entrance", []):
		deck.append(make_loot(str(spec)))
	_shuffle(deck)
	fled_last = false
	_start_wave()
	_log("You enter %s. Wave 1: %s." % [str(d.get("name", "the district")), DDText.zombie_list(bal.wave_zombies(district_index, 0))])
	last_wave_info = _wave_info(0, 0, 0)
	_begin_street()


## Start of every wave (sim start_wave()): buffs end, Fast Hands, Bandolier, melee notches clear,
## machines can be used again.
func _start_wave() -> void:
	buffs.clear()
	free_reload = has_perk("fast_hands")
	if has_perk("bandolier"):
		reserve = mini(bal.num("reserve_cap"), reserve + bal.num("bandolier_reserve"))
	if bal.flag("melee_wave_reset"):
		for w: Variant in slots:
			if w != null and not (w as DDWeapon).is_gun():
				(w as DDWeapon).notch = NO_NOTCH
	for m: Dictionary in machine_state:
		m["used"] = false


## Test/debug hook: replace the deck (top card first) and the street, then deal.
func setup_street(deck_codes: Array, street_codes: Array = [], deal: bool = true) -> void:
	deck.clear()
	for k: int in range(deck_codes.size() - 1, -1, -1):
		deck.append(as_card(deck_codes[k]))
	street.clear()
	for c: Variant in street_codes:
		street.append(as_card(c))
	boss_street = false
	pending_offer = {}
	phase = Phase.STREET
	if deal:
		_begin_street()


## Test/debug hook: a card from a code (weapons get their power from the balance data).
func as_card(c: Variant) -> DDCard:
	if c is DDCard:
		return c
	var card: DDCard = DDCard.parse(str(c))
	if card.kind == DDCard.WEAPON:
		card.value = bal.weapon_power(card.wid)
	return card


## Deals the street up to street_size, and runs wave changes / the last lap / the boss street
## when the deck can't go on (sim play_district_mixed()).
func _begin_street() -> void:
	var size: int = bal.num("street_size")
	var guard: int = 0
	while guard < 20:
		guard += 1
		while street.size() < size and not deck.is_empty():
			var dealt: DDCard = deck.pop_back()
			street.append(dealt)
		if boss_street or not deck.is_empty() or street.size() > 1:
			break
		if is_boss_wave():
			if not skipped.is_empty() and not last_lap:
				deck = skipped.duplicate()
				skipped.clear()
				last_lap = true
				_shuffle(deck)
				_log("Last lap: the %d skipped cards come back once more. No skipping now." % deck.size())
				continue
			boss_street = true
			street.append_array(finale_cards())
			_log("The boss arrives: %s. Resolve every card; reloads are free." % str(finale().get("name", "")))
			break
		_end_wave()
	_new_street_state()
	if street.is_empty():
		_clear_district()


## Wave end: wave bonus, then Skipped pile + next wave pack + room restock become the new deck.
func _end_wave() -> void:
	var bonus: int = int(bal.points("wave"))
	_earn(bonus)
	var back: Array[DDCard] = skipped.duplicate()
	skipped.clear()
	wave_index += 1
	var pack: Array[DDCard] = wave_pack(wave_index)
	var restock: Array[DDCard] = _restock()
	deck = back
	deck.append_array(pack)
	deck.append_array(restock)
	_shuffle(deck)
	_start_wave()
	last_wave_info = _wave_info(wave_index, back.size(), restock.size())
	last_wave_info["bonus"] = bonus
	_log("Wave cleared: +%d points. WAVE %d - %s%s%s." % [bal.shown(bonus), wave_index + 1, DDText.zombie_summary(bal.wave_zombies(district_index, wave_index)),
		(" + %d skipped" % back.size()) if not back.is_empty() else "", (" + %d restock" % restock.size()) if not restock.is_empty() else ""])


func _wave_info(w: int, n_skipped: int, n_restock: int) -> Dictionary:
	var zs: Array[int] = bal.wave_zombies(district_index, w)
	return {"wave": w, "district": district_index, "zombies": zs, "skipped": n_skipped, "restock": n_restock,
		"boss_wave": w >= wave_count() - 1, "bonus": 0}


func _restock() -> Array[DDCard]:
	var out: Array[DDCard] = []
	var d: Dictionary = district()
	for k: int in bal.num("entrance_restock"):
		var e: Array = d.get("entrance", [])
		if not e.is_empty():
			out.append(make_loot(str(_pick(e))))
	var rs: Array = bal.rooms(district_index)
	for i: int in opened:
		var pack: Array = (rs[i] as Dictionary).get("pack", [])
		for k: int in bal.num("restock_per_room"):
			if not pack.is_empty():
				out.append(make_loot(str(_pick(pack))))
	return out


func restock_count() -> int:
	return bal.num("entrance_restock") + opened.size() * bal.num("restock_per_room")


func _new_street_state() -> void:
	var size: int = bal.num("street_size")
	cover = bal.rule("tripwire_cover") if (has_perk("tripwire") and fled_last) else 0
	if cover > 0:
		_log("Tripwire: you start this street with %d Cover." % cover)
	medkits_used = 0
	reloads_left = bal.num("reloads_per_street")
	actions_used = 0
	cards_resolved = 0
	street_was_full = street.size() >= size
	_set_budget()


func _set_budget() -> void:
	var size: int = bal.num("street_size")
	if boss_street:
		budget = street.size()
	elif street.size() >= size:
		budget = bal.num("actions_per_street")
	else:
		budget = maxi(1, street.size() - 1)


# ================================================================ queries
func has_perk(id: String) -> bool:
	return perks.has(id)


func has_buff(id: String) -> bool:
	return buffs.has(id)


func is_quarantine() -> bool:
	return boss_street and str(finale().get("trait", "")) == "quarantine"


func actions_left() -> int:
	return maxi(0, budget - actions_used)


## Kept for the v1 UI vocabulary: what is left to do on this street.
func cards_left_to_resolve() -> int:
	return actions_left()


## The deck can't fill another street after this one (the "Last street of the wave" banner).
func is_last_street() -> bool:
	return phase == Phase.STREET and not boss_street and deck.is_empty()


func deck_zombies() -> int:
	var n: int = 0
	for c: DDCard in deck:
		if c.kind == DDCard.ZOMBIE:
			n += 1
	return n


func deck_counts() -> Dictionary:
	var out: Dictionary = {"Z": [], "W": [], "A": [], "M": [], "B": []}
	for c: DDCard in deck:
		if not out.has(c.kind):
			out[c.kind] = []
		(out[c.kind] as Array).append(c.value)
	for k: String in out:
		(out[k] as Array).sort()
	return out


## What comes after the deck runs out: {kind: "wave"|"last_lap"|"boss", ...} for the preview card.
func next_preview() -> Dictionary:
	if boss_street:
		return {"kind": "clear", "text": "Clear this street to clear %s." % str(district().get("name", ""))}
	if is_boss_wave():
		if not skipped.is_empty() and not last_lap:
			return {"kind": "last_lap", "count": skipped.size(),
				"text": "Next: last lap - the %d skipped card%s come back once, no skipping. Then the boss." % [skipped.size(), "" if skipped.size() == 1 else "s"]}
		return {"kind": "boss", "text": "Next: BOSS street - the Holdover + %s." % DDText.finale_summary(finale())}
	var zs: Array[int] = bal.wave_zombies(district_index, wave_index + 1)
	var t: String = "Next: Wave %d - %s" % [wave_index + 2, DDText.zombie_summary(zs)]
	if not skipped.is_empty():
		t += ", + %d skipped" % skipped.size()
	if restock_count() > 0:
		t += ", + %d restock" % restock_count()
	return {"kind": "wave", "wave": wave_index + 1, "zombies": zs, "skipped": skipped.size(), "restock": restock_count(),
		"bonus": int(bal.points("wave")), "text": t + "."}


func medkit_limit() -> int:
	return bal.rule("triage_medkits_per_street") if passive == "triage" else bal.rule("medkits_per_street")


func medkit_would_heal() -> bool:
	return medkits_used < medkit_limit() and not is_quarantine()


func slot(i: int) -> DDWeapon:
	return slots[i] if i >= 0 and i < slots.size() else null


## The weapon can hit this strength under the notch rule (Rosa / Keen melee: equal too).
func reach_ok(w: DDWeapon, z: int) -> bool:
	if w == null:
		return false
	if equal_ok(w):
		return z <= w.notch
	return z < w.notch


func equal_ok(w: DDWeapon) -> bool:
	return passive == "steady_hands" or (w != null and w.upgraded and not w.is_gun())


## Effective power: guns +2 with Steady Aim.
func power_of(w: DDWeapon) -> int:
	if w == null:
		return 0
	return w.power + (bal.rule("steady_aim_power") if (w.is_gun() and has_buff("steady_aim")) else 0)


## Short reason why slot i can't fight this zombie ("" if it can).
func slot_block_reason(i: int, z: int) -> String:
	var w: DDWeapon = slot(i)
	if w == null:
		return "slot empty"
	if w.is_gun() and w.ammo < 1:
		return "mag empty - reload"
	if not reach_ok(w, z):
		return DDText.notch_tag(w.notch, equal_ok(w))
	return ""


## AI weapon score from the sim (wscore): used for Axe in the Trunk's slot pick.
func wscore(w: Variant) -> float:
	if w == null:
		return -1.0
	var ww: DDWeapon = w
	if not ww.is_gun():
		return ww.power + 1.5
	return ww.power + 0.25 * ww.cap + (0.5 if reserve >= 4 else -1.0)


func worst_slot() -> int:
	return 0 if wscore(slots[0]) <= wscore(slots[1]) else 1


func _busy_reason() -> String:
	if phase != Phase.STREET:
		return "not on a street"
	if not pending_offer.is_empty():
		return "choose where the new weapon goes first"
	return ""


func can_skip() -> bool:
	return skip_block_reason() == ""


func skip_block_reason() -> String:
	var b: String = _busy_reason()
	if b != "":
		return b
	if not bal.flag("allow_retreat"):
		return "skipping is off"
	if boss_street:
		return "no skipping the boss"
	if last_lap:
		return "no skipping on the last lap"
	if fled_last and not has_buff("light_step"):
		return "you skipped last street"
	if actions_used > 0:
		return "you already started this street"
	if street.size() != bal.num("street_size"):
		return "the street is short"
	return ""


## Theo's Slip Away: after resolving exactly 1 card of a full street, the other 3 are skipped.
func can_slip_away() -> bool:
	if passive != "slip_away" or _busy_reason() != "" or not bal.flag("allow_retreat"):
		return false
	if boss_street or last_lap or (fled_last and not has_buff("light_step")):
		return false
	return street_was_full and cards_resolved == 1 and actions_used == 1 and not street.is_empty()


func choices_for(index: int) -> Array[String]:
	var out: Array[String] = []
	if index < 0 or index >= street.size():
		return out
	match street[index].kind:
		DDCard.ZOMBIE:
			out.append_array([SLOT1, SLOT2, BARE])
		DDCard.WEAPON:
			out.append_array([EQUIP1, EQUIP2, SCRAP])
		_:
			out.append(USE)
	return out


## What resolving street[index] with `choice` would do, without changing anything.
## Keys: enabled, reason, kind, value, choice, slot, dmg (before cover), blocked (by weapon or
## wraps), absorbed (by cover / Thick Skin), hp_loss, hp_after, heal, cover_gain, ammo_gain,
## points (gained), notch_after, ammo_after, breaks, up_close, drop, second_wind, dies, wasted,
## replaces (weapon name or ""), text (one-line log).
func preview(index: int, choice: String) -> Dictionary:
	var r: Dictionary = {"enabled": false, "reason": "", "choice": choice, "slot": -1, "dmg": 0, "blocked": 0,
		"absorbed": 0, "skin": 0, "hp_loss": 0, "hp_after": hp, "heal": 0, "cover_gain": 0, "ammo_gain": 0,
		"points": 0, "notch_after": NO_NOTCH, "ammo_after": -1, "breaks": false, "up_close": false, "drop": "",
		"second_wind": false, "dies": false, "wasted": false, "replaces": "", "text": "", "kind": "", "value": 0}
	var busy: String = _busy_reason()
	if busy != "":
		r["reason"] = busy
		return r
	if index < 0 or index >= street.size():
		r["reason"] = "no such card"
		return r
	if actions_left() <= 0:
		r["reason"] = "street done"
		return r
	var c: DDCard = street[index]
	r["kind"] = c.kind
	r["value"] = c.value
	if not choices_for(index).has(choice):
		r["reason"] = "not a choice for this card"
		return r
	var cname: String = DDText.card_name(c, bal)
	match c.kind:
		DDCard.ZOMBIE:
			var dmg: int = c.value
			var up_close: bool = true
			if choice == SLOT1 or choice == SLOT2:
				var i: int = 0 if choice == SLOT1 else 1
				r["slot"] = i
				var why: String = slot_block_reason(i, c.value)
				if why != "":
					r["reason"] = why
					return r
				var w: DDWeapon = slot(i)
				dmg = maxi(0, c.value - power_of(w))
				r["blocked"] = c.value - dmg
				up_close = not w.is_gun()
				r["ammo_after"] = w.ammo - 1 if w.is_gun() else -1
				if c.boss_trait == "shatter":
					r["breaks"] = true
				r["notch_after"] = c.value
			else:
				if has_perk("knuckle_wraps"):
					var red: int = mini(dmg, bal.rule("knuckle_wraps_reduction"))
					r["blocked"] = red
					dmg -= red
			if has_buff("thick_skin"):
				var sk: int = mini(dmg, bal.rule("thick_skin_reduction"))
				r["skin"] = sk
				dmg -= sk
			r["dmg"] = dmg
			var absorbed: int = mini(cover, dmg)
			r["absorbed"] = absorbed
			var after: int = hp - (dmg - absorbed)
			if after <= 0 and second_wind:
				r["second_wind"] = true
				after = bal.rule("second_wind_hp")
			r["hp_loss"] = hp - after
			r["hp_after"] = after
			r["dies"] = after <= 0
			r["up_close"] = up_close
			var pts: int = int(c.value * bal.points("kill")) + (int(bal.points("up_close")) if up_close else 0) + (int(bal.points("boss")) if c.is_boss() else 0)
			if has_buff("payday"):
				pts *= bal.rule("payday_mult")
			r["points"] = pts
			if c.drop != "" and not bool(r["dies"]):
				r["drop"] = c.drop
			r["text"] = _fight_text(cname, c, r)
		DDCard.WEAPON:
			var nw: String = DDText.weapon_card_label(c, bal)
			if choice == SCRAP:
				r["points"] = int(bal.points("scrap"))
				r["text"] = "Scrapped %s: +%d points." % [nw, bal.shown(int(r["points"]))]
			else:
				var i2: int = 0 if choice == EQUIP1 else 1
				r["slot"] = i2
				var old: DDWeapon = slot(i2)
				if old != null:
					r["replaces"] = old.display_name()
					r["points"] = int(bal.points("scrap"))
					r["text"] = "%s into slot %d (scrapped %s, +%d points)." % [nw, i2 + 1, old.display_name(), bal.shown(int(r["points"]))]
				else:
					r["text"] = "%s into slot %d." % [nw, i2 + 1]
		DDCard.AMMO:
			var cap: int = bal.num("reserve_cap")
			var gain: int = mini(cap, reserve + c.value) - reserve
			r["ammo_gain"] = gain
			if gain < c.value:
				r["wasted"] = gain <= 0
				r["text"] = "%s: +%d reserve ammo (reserve full at %d)." % [cname, gain, cap]
			else:
				r["text"] = "%s: +%d reserve ammo." % [cname, gain]
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
					r["text"] = "%s: Quarantine, no healing on the boss street." % cname
				else:
					r["text"] = "%s: used up, medkit limit reached this street." % cname
		DDCard.BARRICADE:
			r["cover_gain"] = c.value
			r["text"] = "%s: +%d Cover this street." % [cname, c.value]
	r["enabled"] = true
	return r


func _fight_text(cname: String, c: DDCard, r: Dictionary) -> String:
	var t: String = "%s %d: " % [cname, c.value]
	var i: int = int(r["slot"])
	if i >= 0:
		var w: DDWeapon = slot(i)
		t += "%s blocked %d" % [w.display_name(), int(r["blocked"])]
	else:
		t += "bare-handed"
		if int(r["blocked"]) > 0:
			t += ", wraps blocked %d" % int(r["blocked"])
	if int(r["skin"]) > 0:
		t += ", Thick Skin %d" % int(r["skin"])
	if int(r["absorbed"]) > 0:
		t += ", Cover soaked %d" % int(r["absorbed"])
	t += ", -%d HP, +%d pts" % [int(r["hp_loss"]), bal.shown(int(r["points"]))]
	if bool(r["up_close"]):
		t += " (up close)"
	t += "."
	if bool(r["breaks"]):
		t += " Shatter: your weapon broke."
	elif i >= 0:
		t += " Notch %d." % int(r["notch_after"])
	if bool(r["second_wind"]):
		t += " Second Wind: you hang on at %d HP." % int(r["hp_after"])
	return t


# ================================================================ actions
## Resolves street[index] with a choice (see choices_for()). Returns the event ({ok: false,
## reason} if illegal).
func resolve(index: int, choice: String) -> Dictionary:
	var p: Dictionary = preview(index, choice)
	if not bool(p["enabled"]):
		return {"ok": false, "reason": p["reason"]}
	_notes.clear()
	var c: DDCard = street[index]
	var hp_before: int = hp
	var pts_before: int = points
	var ev_extra: Dictionary = {}
	match c.kind:
		DDCard.ZOMBIE:
			var i: int = int(p["slot"])
			cover -= int(p["absorbed"])
			hp = int(p["hp_after"])
			if bool(p["second_wind"]):
				second_wind = false
			if i >= 0:
				var w: DDWeapon = slot(i)
				if w.is_gun():
					w.ammo -= 1
				if bool(p["breaks"]):
					slots[i] = null
				else:
					w.notch = c.value
			kills += 1
			_earn(int(p["points"]))
		DDCard.WEAPON:
			if choice == SCRAP:
				_earn(int(p["points"]))
			else:
				var i2: int = int(p["slot"])
				if slot(i2) != null:
					_earn(int(p["points"]))
				slots[i2] = make_weapon(c.wid)
		DDCard.AMMO:
			reserve += int(p["ammo_gain"])
		DDCard.MEDKIT:
			hp = int(p["hp_after"])
			medkits_used += 1
		DDCard.BARRICADE:
			cover += int(p["cover_gain"])
	street.remove_at(index)
	c.holdover = false
	c.skipped = false
	actions_used += 1
	cards_resolved += 1
	_log(str(p["text"]))
	if hp > 0 and str(p["drop"]) != "":
		ev_extra["drop"] = str(p["drop"])
		_apply_drop(str(p["drop"]))
	var ev: Dictionary = _event("resolve", str(p["text"]), hp - hp_before, points - pts_before)
	ev.merge(ev_extra, true)
	ev["card"] = c
	ev["choice"] = choice
	ev["slot"] = int(p["slot"])
	ev["preview"] = p
	if hp <= 0:
		hp = 0
		_die()
		ev["dead"] = true
		return _emit(ev)
	if actions_used >= budget or street.is_empty():
		ev.merge(_end_street(), true)
	return _emit(ev)


func _apply_drop(d: String) -> void:
	match d:
		"full_load":
			for w: Variant in slots:
				if w != null and (w as DDWeapon).is_gun():
					(w as DDWeapon).ammo = (w as DDWeapon).cap
					(w as DDWeapon).notch = NO_NOTCH
			reserve = mini(bal.num("reserve_cap"), reserve + bal.num("full_load_reserve"))
			_log("Carrier drop - Full Load: every gun's magazine is full and its notch cleared, +%d reserve." % bal.num("full_load_reserve"))
		"payday":
			buffs.append("payday")
			_log("Carrier drop - Payday: kills give double points for the rest of the wave.")
		"boards":
			cover += bal.num("boards_cover")
			_log("Carrier drop - Boards: +%d Cover now." % bal.num("boards_cover"))


func _end_street() -> Dictionary:
	var out: Dictionary = {"street_ended": true}
	streets_played += 1
	fled_last = false
	var was_boss: bool = boss_street
	var wave_before: int = wave_index
	var lap_before: bool = last_lap
	var before: int = district_index
	for c: DDCard in street:
		c.holdover = true
	if not street.is_empty() and not was_boss:
		out["holdover"] = street[0]
		_log("Holdover: %s stays for the next street." % DDText.cards_text(street, bal))
	if was_boss:
		street.clear()
		_clear_district()
	else:
		_begin_street()
	if was_boss or phase != Phase.STREET or district_index != before:
		out["district_cleared"] = true
	if wave_index != wave_before and district_index == before:
		out["wave_changed"] = last_wave_info.duplicate()
	if last_lap and not lap_before:
		out["last_lap"] = true
	if boss_street and not was_boss:
		out["boss_street"] = true
	return out


## Reload preview for slot i: {enabled, reason, drop, load, cost (actions), free_why, text}.
func reload_preview(i: int) -> Dictionary:
	var r: Dictionary = {"enabled": false, "reason": "", "drop": 0, "load": 0, "cost": 1, "free_why": "", "text": "", "useful": false}
	var w: DDWeapon = slot(i)
	if w == null or not w.is_gun():
		r["reason"] = "melee never reloads" if w != null else "slot empty"
		return r
	r["useful"] = w.ammo < w.cap or not w.is_fresh()
	var keep: int = 0 if bal.text("reload_mode") == "drop" else w.ammo
	r["drop"] = w.ammo - keep
	r["load"] = mini(reserve, w.cap - keep)
	r["cost"] = reload_cost()
	r["free_why"] = reload_free_why()
	r["text"] = "Drop %d, load %d of %d reserve, notch clears" % [int(r["drop"]), int(r["load"]), reserve]
	var busy: String = _busy_reason()
	if busy != "":
		r["reason"] = busy
	elif not bool(r["useful"]):
		r["reason"] = "full and fresh"
	elif reserve <= 0:
		r["reason"] = "no reserve ammo"
	elif reloads_left <= 0:
		r["reason"] = "one reload per street"
	elif int(r["cost"]) > 0 and actions_left() < 2:
		r["reason"] = "no action to spare"
	else:
		r["enabled"] = true
	return r


func reload_cost() -> int:
	return 0 if reload_free_why() != "" else 1


func reload_free_why() -> String:
	if boss_street:
		return "boss street"
	if has_buff("sleight"):
		return "Sleight of Hand"
	if free_reload:
		return "Fast Hands"
	return ""


func can_reload(i: int) -> bool:
	return bool(reload_preview(i)["enabled"])


## Reload slot i: the rounds left are dropped, a fresh magazine comes from the reserve, the notch
## clears. One action (free on the boss street, with Sleight of Hand or Fast Hands' first).
func reload(i: int) -> Dictionary:
	var p: Dictionary = reload_preview(i)
	if not bool(p["enabled"]):
		return {"ok": false, "reason": p["reason"]}
	_notes.clear()
	var w: DDWeapon = slot(i)
	var why: String = reload_free_why()
	if bal.text("reload_mode") == "drop":
		w.ammo = 0
	var n: int = mini(reserve, w.cap - w.ammo)
	reserve -= n
	w.ammo += n
	w.notch = NO_NOTCH
	reloads_left -= 1
	reloads += 1
	if why == "":
		actions_used += 1
	elif why == "Fast Hands":
		free_reload = false
	var t: String = "Reloaded %s: dropped %d, loaded %d, notch cleared%s. Reserve %d." % [w.display_name(), int(p["drop"]), n,
		(" (free: %s)" % why) if why != "" else " (1 action)", reserve]
	_log(t)
	var ev: Dictionary = _event("reload", t, 0, 0)
	ev["slot"] = i
	ev["preview"] = p
	if actions_used >= budget:
		ev.merge(_end_street(), true)
	return _emit(ev)


## Skip: every street card goes face up onto the Skipped pile and comes back in the next wave.
func skip() -> Dictionary:
	if not can_skip():
		return {"ok": false, "reason": skip_block_reason()}
	return _send_back("Skip")


func slip_away() -> Dictionary:
	if not can_slip_away():
		return {"ok": false, "reason": "Slip Away not available"}
	return _send_back("Slip Away")


func retreat() -> Dictionary:
	return skip()


func _send_back(label: String) -> Dictionary:
	_notes.clear()
	var back: Array[DDCard] = street.duplicate()
	street.clear()
	for c: DDCard in back:
		c.holdover = false
		c.skipped = true
	skipped.append_array(back)
	var used_light: bool = fled_last and has_buff("light_step")
	fled_last = true
	skips += 1
	streets_played += 1
	var t: String = "%s: %d card%s onto the Skipped pile - they come back next wave%s." % [label, back.size(), "" if back.size() == 1 else "s",
		" (Light Step)" if used_light else ""]
	_log(t)
	var wave_before: int = wave_index
	var lap_before: bool = last_lap
	_begin_street()
	var ev: Dictionary = _event("skip", t, 0, 0)
	ev["returned"] = back
	if wave_index != wave_before:
		ev["wave_changed"] = last_wave_info.duplicate()
	if last_lap and not lap_before:
		ev["last_lap"] = true
	if boss_street:
		ev["boss_street"] = true
	return _emit(ev)


# ================================================================ rooms and machines
func room(i: int) -> Dictionary:
	var rs: Array = bal.rooms(district_index)
	return rs[i] if i >= 0 and i < rs.size() else {}


func room_count() -> int:
	return bal.rooms(district_index).size()


## "open", "next" (the one you can buy now; rooms open in order) or "locked".
func room_status(i: int) -> String:
	if opened.has(i):
		return "open"
	return "next" if i == opened.size() else "locked"


func room_block_reason(i: int) -> String:
	var b: String = _busy_reason()
	if b != "":
		return b
	var st: String = room_status(i)
	if st == "open":
		return "already open"
	if st == "locked":
		return "open %s first" % str(room(opened.size()).get("name", "the room before"))
	if boss_street:
		return "the boss is here"
	if actions_used > 0:
		return "between streets only"
	var cost: int = int(room(i).get("cost", 0))
	if points < cost:
		return "need %d more points" % bal.shown(cost - points)
	return ""


func can_open_room(i: int) -> bool:
	return room_block_reason(i) == ""


## Opens a door: pay its price, its loot pack is shuffled into the deck now, its machine becomes
## usable and it restocks 1 loot card per wave from the next wave on. Free action between streets.
func open_room(i: int) -> Dictionary:
	var why: String = room_block_reason(i)
	if why != "":
		return {"ok": false, "reason": why}
	_notes.clear()
	var r: Dictionary = room(i)
	var cost: int = int(r.get("cost", 0))
	points -= cost
	opened.append(i)
	var loot: Array[DDCard] = []
	for spec: Variant in r.get("pack", []):
		loot.append(make_loot(str(spec)))
	deck.append_array(loot)
	_shuffle(deck)
	var size: int = bal.num("street_size")
	var dealt: Array[DDCard] = []
	while street.size() < size and not deck.is_empty():
		var c: DDCard = deck.pop_back()
		street.append(c)
		dealt.append(c)
	street_was_full = street.size() >= size
	_set_budget()
	var t: String = "Opened %s for %d points: %s shuffled into the deck; %s is ready." % [str(r.get("name", "")), bal.shown(cost),
		DDText.cards_text(loot, bal), DDText.machine_name(str((r.get("machine", {}) as Dictionary).get("kind", "")))]
	_log(t)
	var ev: Dictionary = _event("room", t, 0, -cost)
	ev["room"] = i
	ev["loot"] = loot
	ev["dealt"] = dealt
	return _emit(ev)


func machine(i: int) -> Dictionary:
	return room(i).get("machine", {})


## Every option a room's machine offers right now, each stating its price and result:
## [{id, label, price, enabled, reason, result}].
func machine_options(i: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var m: Dictionary = machine(i)
	var kind: String = str(m.get("kind", ""))
	var base: String = _machine_block(i)
	match kind:
		"retrofit":
			var cost: int = int(bal.fixture_num("retrofit", "cost"))
			for s: int in 2:
				var w: DDWeapon = slot(s)
				var o: Dictionary = {"id": "retrofit%d" % (s + 1), "price": cost, "slot": s}
				if w == null:
					o["label"] = "Slot %d is empty" % (s + 1)
					o["reason"] = "slot empty"
				elif w.upgraded:
					o["label"] = "%s: already retrofitted" % w.display_name()
					o["reason"] = "once per weapon"
				else:
					var after: DDWeapon = retrofit_result(w)
					o["label"] = "Retrofit %s" % w.name
					o["result"] = "%s -> %s" % [DDText.weapon_stats(w, self), DDText.weapon_stats(after, self)]
					o["reason"] = base if base != "" else _afford(cost)
				out.append(o)
		"grin":
			var cost2: int = grin_price(i)
			out.append({"id": "grin", "price": cost2, "label": "Turn the crank",
				"result": "1 random Jawbreaker of %d, lasts this wave" % bal.list("grin_effects").size(),
				"reason": base if base != "" else _afford(cost2)})
		"locker":
			var cost3: int = int(bal.fixture_num("locker", "cost"))
			out.append({"id": "locker", "price": cost3, "label": "Roll the Locker",
				"result": "1 random weapon (odds on the card); take it into a slot or leave it", "reason": base if base != "" else _afford(cost3)})
		"wallrack":
			var wid: String = str(m.get("wid", ""))
			var own: int = owned_slot(wid)
			if own >= 0:
				var w2: DDWeapon = slot(own)
				var cost4: int = int(bal.fixture_num("wallrack", "ammo_cost"))
				var gain: int = mini(bal.num("reserve_cap"), reserve + w2.cap) - reserve
				out.append({"id": "wall_ammo", "price": cost4, "label": "Ammo refill",
					"result": "%s full (%d), notch clears, +%d reserve" % [w2.display_name(), w2.cap, gain], "reason": base if base != "" else _afford(cost4)})
			else:
				var cost5: int = bal.weapon_price(wid)
				out.append({"id": "wall_buy", "price": cost5, "label": "Buy the %s" % bal.weapon_name(wid),
					"result": "%s into a slot you choose, full magazine" % DDText.weapon_stats(make_weapon(wid), self), "reason": base if base != "" else _afford(cost5)})
	for o: Dictionary in out:
		o["enabled"] = str(o.get("reason", "")) == ""
		if not o.has("result"):
			o["result"] = ""
	return out


func _afford(cost: int) -> String:
	return "" if points >= cost else "need %d more points" % bal.shown(cost - points)


func _machine_block(i: int) -> String:
	var b: String = _busy_reason()
	if b != "":
		return b
	if not opened.has(i):
		return "open the room first"
	if bool(machine_state[i].get("used", false)):
		return "used this wave"
	if actions_used > 0:
		return "between streets only"
	return ""


func machine_used(i: int) -> bool:
	return i >= 0 and i < machine_state.size() and bool(machine_state[i].get("used", false))


func grin_price(i: int) -> int:
	var n: int = int(machine_state[i].get("n", 0)) if i >= 0 and i < machine_state.size() else 0
	return int(bal.fixture_num("grin", "cost") + bal.fixture_num("grin", "step") * n)


func owned_slot(wid: String) -> int:
	for s: int in 2:
		if slot(s) != null and slot(s).wid == wid:
			return s
	return -1


func retrofit_result(w: DDWeapon) -> DDWeapon:
	var a: DDWeapon = w.copy()
	a.power += int(bal.fixture_num("retrofit", "power"))
	if a.is_gun():
		a.cap = int(a.cap * bal.fixture_num("retrofit", "mag_mult") + 0.5)
		a.ammo = a.cap
	a.notch = NO_NOTCH
	a.upgraded = true
	return a


## Use a machine option (from machine_options()). The result is in ev["result"].
func use_machine(i: int, option_id: String) -> Dictionary:
	var opt: Dictionary = {}
	for o: Dictionary in machine_options(i):
		if str(o["id"]) == option_id:
			opt = o
	if opt.is_empty():
		return {"ok": false, "reason": "no such option"}
	if not bool(opt["enabled"]):
		return {"ok": false, "reason": str(opt["reason"])}
	_notes.clear()
	var price: int = int(opt["price"])
	var pts_before: int = points
	var hp_before: int = hp
	points -= price
	machine_state[i]["used"] = true
	var result: Dictionary = {"machine": str(machine(i).get("kind", "")), "option": option_id}
	var t: String = ""
	match option_id:
		"retrofit1", "retrofit2":
			var s: int = int(opt["slot"])
			slots[s] = retrofit_result(slot(s))
			result["weapon"] = slot(s)
			t = "Retrofit Bench: %s is now %s." % [slot(s).name, DDText.weapon_stats(slot(s), self)]
		"grin":
			machine_state[i]["n"] = int(machine_state[i].get("n", 0)) + 1
			var e: String = str(_pick(bal.list("grin_effects")))
			result["effect"] = e
			if e == "sugar_rush":
				hp = mini(max_hp, hp + bal.rule("sugar_rush_heal"))
			else:
				buffs.append(e)
			t = "Grin Machine: %s - %s" % [DDText.buff_name(e), DDText.buff_text(e, bal)]
		"locker":
			var wid: String = str(_pick(bal.list("locker_pool")))
			var w: DDWeapon = make_weapon(wid)
			pending_offer = {"weapon": w, "source": "locker", "room": i, "can_leave": true}
			result["weapon"] = w
			t = "Lucky Locker: you got a %s (%s). Pick a slot or leave it." % [w.name, DDText.weapon_stats(w, self)]
		"wall_buy":
			var wid2: String = str(machine(i).get("wid", ""))
			var w2: DDWeapon = make_weapon(wid2)
			pending_offer = {"weapon": w2, "source": "wallrack", "room": i, "can_leave": false}
			result["weapon"] = w2
			t = "Wall Rack: you bought the %s. Pick a slot for it." % w2.name
		"wall_ammo":
			var s2: int = owned_slot(str(machine(i).get("wid", "")))
			var w3: DDWeapon = slot(s2)
			w3.ammo = w3.cap
			w3.notch = NO_NOTCH
			reserve = mini(bal.num("reserve_cap"), reserve + w3.cap)
			result["weapon"] = w3
			t = "Wall Rack ammo: %s full, notch cleared, reserve %d." % [w3.display_name(), reserve]
	t += " (-%d points)" % bal.shown(price)
	_log(t)
	var ev: Dictionary = _event("machine", t, hp - hp_before, points - pts_before)
	ev["room"] = i
	ev["result"] = result
	return _emit(ev)


## Put the pending Locker / Wall Rack weapon into slot 1 / 2 (EQUIP1 / EQUIP2) or leave it (SCRAP,
## Locker only: +scrap points). A replaced weapon is scrapped (+scrap points).
func offer_preview(choice: String) -> Dictionary:
	var r: Dictionary = {"enabled": false, "reason": "", "points": 0, "replaces": "", "text": ""}
	if pending_offer.is_empty():
		r["reason"] = "nothing to place"
		return r
	var w: DDWeapon = pending_offer["weapon"]
	if choice == SCRAP:
		if not bool(pending_offer.get("can_leave", false)):
			r["reason"] = "you paid for it"
			return r
		r["points"] = int(bal.points("scrap"))
		r["text"] = "Left the %s: +%d points." % [w.name, bal.shown(int(r["points"]))]
	elif choice == EQUIP1 or choice == EQUIP2:
		var s: int = 0 if choice == EQUIP1 else 1
		var old: DDWeapon = slot(s)
		if old != null:
			r["replaces"] = old.display_name()
			r["points"] = int(bal.points("scrap"))
			r["text"] = "%s into slot %d (scrapped %s, +%d points)." % [w.name, s + 1, old.display_name(), bal.shown(int(r["points"]))]
		else:
			r["text"] = "%s into slot %d." % [w.name, s + 1]
	else:
		r["reason"] = "not a choice"
		return r
	r["enabled"] = true
	return r


func take_offer(choice: String) -> Dictionary:
	var p: Dictionary = offer_preview(choice)
	if not bool(p["enabled"]):
		return {"ok": false, "reason": p["reason"]}
	_notes.clear()
	var w: DDWeapon = pending_offer["weapon"]
	var before: int = points
	_earn(int(p["points"]))
	if choice != SCRAP:
		slots[0 if choice == EQUIP1 else 1] = w
	pending_offer = {}
	_log(str(p["text"]))
	var ev: Dictionary = _event("offer", str(p["text"]), 0, points - before)
	ev["choice"] = choice
	ev["slot"] = -1 if choice == SCRAP else (0 if choice == EQUIP1 else 1)
	return _emit(ev)


# ================================================================ districts, safehouse, end
func _clear_district() -> void:
	var hp_score: int = hp * bal.rule("score_hp_mult")
	boss_hp.append(hp_score)
	cleared_ids.append(str(district().get("id", "")))
	_log("%s cleared! %d HP left: +%d score." % [str(district().get("name", "")), hp, bal.shown(hp_score)])
	street.clear()
	skipped.clear()
	deck.clear()
	boss_street = false
	if district_index >= bal.district_count() - 1:
		phase = Phase.WON
		_log("You made it out of the city. Run score %d." % bal.shown(run_score()))
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
	_notes.clear()
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
	var ev: Dictionary = _event("perk", "Perk taken: %s." % DDText.perk_name(id) if id != "" else "On the road.", hp - hp_before, 0)
	return _emit(ev)


func _die() -> void:
	phase = Phase.DEAD
	_log("You were overrun in %s. Run score %d." % [str(district().get("name", "")), bal.shown(run_score())])


## Score in sim units (shown x10): every point earned + HP left at each boss.
func run_score() -> int:
	var t: int = points_earned
	for s: int in boss_hp:
		t += s
	return t


# ================================================================ helpers
func _earn(n: int) -> void:
	points += n
	points_earned += n


func _event(kind: String, text: String, hp_delta: int, points_delta: int) -> Dictionary:
	return {"ok": true, "kind": kind, "text": text, "hp_delta": hp_delta, "points_delta": points_delta, "hp": hp,
		"max_hp": max_hp, "street_ended": false, "district_cleared": false, "dead": false}


func _emit(ev: Dictionary) -> Dictionary:
	ev["phase"] = phase
	ev["notes"] = _notes.duplicate()
	changed.emit(ev)
	return ev


func _log(t: String) -> void:
	log_lines.append(t)
	_notes.append(t)
	if log_lines.size() > 200:
		log_lines.remove_at(0)


## Plain-data snapshot of the run (debug / QA / tests): never used to restore a run.
func summary() -> Dictionary:
	var ws: Array = []
	for w: Variant in slots:
		ws.append((w as DDWeapon).to_dict() if w != null else null)
	return {"district": district_index, "wave": wave_index, "hp": hp, "points": points, "earned": points_earned,
		"reserve": reserve, "slots": ws, "deck": deck.size(), "street": street.size(), "skipped": skipped.size(),
		"opened": opened.duplicate(), "phase": Phase.keys()[phase], "boss_street": boss_street, "last_lap": last_lap}
