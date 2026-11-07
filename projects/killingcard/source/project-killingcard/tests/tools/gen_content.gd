# Generates all p03 prototype content as .tres under res://data/. Run:
# godot --headless --path <project> -s <this file>
extends SceneTree

var _saved: Dictionary = {}

func _init() -> void:
	_gen()
	quit()


func fx(trigger: int, kind: int, target: int, scope: int, amount: int = 0, opts: Dictionary = {}) -> EffectData:
	var e := EffectData.new()
	e.trigger = trigger
	e.kind = kind
	e.target = target
	e.zone_scope = scope
	e.amount = amount
	for k: String in opts:
		e.set(k, opts[k])
	return e


func save(res: Resource, path: String) -> Resource:
	if FileAccess.file_exists(path) and _keep(path):
		var existing: Resource = ResourceLoader.load(path)
		_saved[path] = existing
		return existing
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("save failed " + path)
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	_saved[path] = loaded
	return loaded


func _keep(path: String) -> bool:
	return path in ["res://data/cards/rifleman.tres", "res://data/cards/breach_and_clear.tres", "res://data/loadout/mortar_barrage.tres"]


func unit(id: String, name: String, wc: int, cost: int, fp: int, ar: int, text: String = "", props: Dictionary = {}, effects: Array = []) -> CardData:
	var c := CardData.new()
	c.id = StringName(id); c.display_name = name; c.card_type = DataEnums.CardType.UNIT
	c.weapon_class = wc; c.cost = cost; c.firepower = fp; c.armor = ar; c.text = text
	for k: String in props:
		c.set(k, props[k])
	var arr: Array[EffectData] = []
	arr.assign(effects)
	c.effects = arr
	return save(c, "res://data/cards/%s.tres" % id)


func card(id: String, name: String, type: int, cost: int, text: String, effects: Array, props: Dictionary = {}) -> CardData:
	var c := CardData.new()
	c.id = StringName(id); c.display_name = name; c.card_type = type; c.cost = cost; c.text = text
	for k: String in props:
		c.set(k, props[k])
	var arr: Array[EffectData] = []
	arr.assign(effects)
	c.effects = arr
	return save(c, "res://data/cards/%s.tres" % id)


func item(id: String, name: String, slot: int, text: String, props: Dictionary = {}, effects: Array = []) -> LoadoutItem:
	var it := LoadoutItem.new()
	it.id = StringName(id); it.display_name = name; it.slot = slot; it.text = text
	for k: String in props:
		if k == "attachments":
			var a: Array[Resource] = []
			a.assign(props[k])
			it.attachments = a
		else:
			it.set(k, props[k])
	var arr: Array[EffectData] = []
	arr.assign(effects)
	it.effects = arr
	return save(it, "res://data/loadout/%s.tres" % id)


func cards_list(pairs: Array) -> Array[CardData]:
	var out: Array[CardData] = []
	for p: Array in pairs:
		for i: int in p[1]:
			out.append(p[0])
	return out


func items(list: Array) -> Array[LoadoutItem]:
	var out: Array[LoadoutItem] = []
	out.assign(list)
	return out


func _gen() -> void:
	for d: String in ["res://data/cards", "res://data/loadout", "res://data/squads", "res://data/maps"]:
		DirAccess.make_dir_recursive_absolute(d)
	var T := DataEnums.Trigger; var K := DataEnums.EffectKind; var TG := DataEnums.Target; var Z := DataEnums.ZoneScope; var C := DataEnums.Condition; var W := DataEnums.WeaponClass

	# --- Token -------------------------------------------------------------
	var sentry := unit("sentry", "Sentry", W.NONE, 0, 2, 4, "Cover 1. Ignored for control; no elimination credit for destroying it.",
		{"cover": 1, "collectible": false, "counts_for_control": false, "grants_elimination_credit": false})

	# --- Starter card set (core-rules §5, 20 designs) -------------------------
	var rifleman := unit("rifleman", "Rifleman", W.AR, 1, 2, 2)
	var point_man := unit("point_man", "Point Man", W.SMG, 2, 2, 3, "First Shot", {"first_shot": true})
	var medic := unit("combat_medic", "Combat Medic", W.AR, 2, 1, 3, "Patch 2", {"patch": 2})
	# kc-syn v1.1: Recon Specialist 1/2 -> 2/3. Neighbor keywords / traits (neighbor_keyword,
	# card_trait) and the Brawler / Smoke Screen / Blackout / Sabotage chassis were added to the
	# .tres files directly (synergy-system.md §6.1); this generator predates them.
	var recon_spec := unit("recon_specialist", "Recon Specialist", W.AR, 2, 2, 3,
		"On Deploy: next round, enemy red dots in this zone are revealed.", {},
		[fx(T.ON_DEPLOY, K.REVEAL_RED_DOTS, TG.OWNER, Z.THIS_ZONE, 0, {"delay_rounds": 1, "duration_rounds": 1})])
	var breacher := unit("breacher", "Breacher", W.SHOTGUN, 3, 3, 4, "First Shot", {"first_shot": true})
	var marksman := unit("marksman", "Marksman", W.SNIPER, 3, 2, 2, "Pick", {"pick": true})
	var flanker := unit("flanker", "Flanker", W.SMG, 3, 2, 3, "Flank", {"flank": true})
	# kc-fight-impl (firefight-order.md §6.2): Protector cost 3 -> 4 and no Guard; Pierce on the LMG
	# units (Gunner, Demolitions Expert; head's answer O3). The .tres files were edited directly.
	var shieldman := unit("shieldman", "Protector", W.NONE, 4, 1, 5,
		"Cover 1. Slides to the front of its column on arrival.", {"cover": 1, "arrives_front": true})
	var gunner := unit("gunner", "Gunner", W.LMG, 4, 2, 6, "Suppress. Pierce", {"suppress": true, "pierce": true})
	var demo := unit("demolitions_expert", "Demolitions Expert", W.LMG, 4, 2, 4,
		"Pierce. On Down: 3 damage to the enemy point man here.", {"pierce": true},
		[fx(T.ON_DOWN, K.DAMAGE, TG.ENEMY_POINT_MAN, Z.THIS_ZONE, 3)])
	var anvil := unit("okafor_anvil", "Commander", W.AR, 5, 3, 6,
		"Holder. Your other units here get +1 FP.", {"is_elite": true, "holder": true},
		[fx(T.PASSIVE, K.MODIFY_FIREPOWER, TG.OTHER_FRIENDLIES, Z.THIS_ZONE, 1)])
	var wren := unit("halek_wren", "Ace", W.SNIPER, 5, 4, 3,
		"Pick. Its eliminations give +1 extra streak.", {"is_elite": true, "pick": true},
		[fx(T.ON_ELIMINATE, K.STREAK_BONUS, TG.OWNER, Z.ANY, 1)])
	var callout := card("callout", "Callout", DataEnums.CardType.TACTIC, 0,
		"Resolves immediately: reveal red dots in a zone; your first unit to arrive there gets +1 FP.",
		[fx(T.IMMEDIATE, K.REVEAL_RED_DOTS, TG.OWNER, Z.CHOSEN_ZONE),
		 fx(T.IMMEDIATE, K.MODIFY_FIREPOWER, TG.NEXT_FRIENDLY_ARRIVING, Z.CHOSEN_ZONE, 1, {"duration_rounds": 1})])
	var ammo := card("ammo_resupply", "Ammo Resupply", DataEnums.CardType.TACTIC, 1, "Resolves immediately: draw 2.",
		[fx(T.IMMEDIATE, K.DRAW, TG.OWNER, Z.ANY, 2)])
	var flank_route := card("flank_route", "Flank Route", DataEnums.CardType.TACTIC, 1,
		"Move a friendly unit to an adjacent zone; it gains First Shot this round.",
		[fx(T.ON_PLAY, K.MOVE_UNIT, TG.CHOSEN_FRIENDLY, Z.ADJACENT_ZONE),
		 fx(T.ON_PLAY, K.GRANT_FIRST_SHOT, TG.CHOSEN_FRIENDLY, Z.ANY, 0, {"duration_rounds": 1})])
	var supp_fire := card("suppressing_fire", "Suppressing Fire", DataEnums.CardType.TACTIC, 2,
		"Enemy units in a zone get -1 FP this round.",
		[fx(T.ON_PLAY, K.MODIFY_FIREPOWER, TG.ALL_ENEMIES, Z.CHOSEN_ZONE, -1, {"duration_rounds": 1})])
	var hold := card("hold_the_line", "Hold the Line", DataEnums.CardType.TACTIC, 2,
		"Your units in a zone gain Cover 1 this round.",
		[fx(T.ON_PLAY, K.GRANT_COVER, TG.ALL_FRIENDLIES, Z.CHOSEN_ZONE, 1, {"duration_rounds": 1})])
	var bac := card("breach_and_clear", "Breach and Clear", DataEnums.CardType.TACTIC, 3,
		"2 damage to each enemy unit in a zone (3 if Close).",
		[fx(T.ON_PLAY, K.DAMAGE, TG.ALL_ENEMIES, Z.CHOSEN_ZONE, 2, {"bonus_amount": 1, "bonus_condition": C.ZONE_IS_CLOSE})])
	# --- Fields (CardType.EQUIPMENT; KillingCard field-cards.md §4, kc-field-impl) ---------
	var FIELD: int = DataEnums.CARD_TYPE_FIELD
	var tripwire := card("tripwire_charge", "Tripwire Charge", FIELD, 2,
		"Hidden. The next enemy unit to arrive in this column takes 3 damage. Then it's gone.",
		[fx(T.ON_ENEMY_ARRIVE, K.DAMAGE, TG.ARRIVING_ENEMY, Z.THIS_ZONE, 3)],
		{"hidden": true, "consumed_on_trigger": true})
	var comms := card("comms_relay", "Comms Relay", FIELD, 2,
		"While you control this column: streak +1 at end of round.",
		[fx(T.END_OF_ROUND, K.STREAK_BONUS, TG.OWNER, Z.THIS_ZONE, 1, {"condition": C.YOU_CONTROL_ZONE})])
	var listening_post := card("listening_post", "Listening Post", FIELD, 1,
		"Each round, enemy red dots in this column are revealed to you.",
		[fx(T.END_OF_ROUND, K.REVEAL_RED_DOTS, TG.OWNER, Z.THIS_ZONE, 0, {"delay_rounds": 1, "duration_rounds": 1})])
	var mortar_pit := card("mortar_pit", "Mortar Pit", FIELD, 3,
		"At end of round: 1 damage to the enemy frontline unit in this column.",
		[fx(T.END_OF_ROUND, K.DAMAGE, TG.ENEMY_POINT_MAN, Z.THIS_ZONE, 1)])
	var bulwark := card("bulwark", "Bulwark", FIELD, 3,
		"Your frontline unit in this column has Cover 1.",
		[fx(T.PASSIVE, K.GRANT_COVER, TG.FRIENDLY_POINT_MAN, Z.THIS_ZONE, 1)])
	var war_standard := card("war_standard", "War Standard", FIELD, 3,
		"Your frontline unit in this column gets +1 FP.",
		[fx(T.PASSIVE, K.MODIFY_FIREPOWER, TG.FRIENDLY_POINT_MAN, Z.THIS_ZONE, 1)])
	var sniper_perch := card("sniper_perch", "Sniper Perch", FIELD, 2,
		"Your Sniper units in this column get +1 FP.",
		[fx(T.PASSIVE, K.MODIFY_FIREPOWER, TG.ALL_FRIENDLIES, Z.THIS_ZONE, 1, {"target_class": W.SNIPER})])
	var aid_station := card("aid_station", "Aid Station", FIELD, 2,
		"At end of round: your most damaged unit in this column heals 1.",
		[fx(T.END_OF_ROUND, K.HEAL, TG.MOST_DAMAGED_FRIENDLY, Z.THIS_ZONE, 1)])

	# --- Loadout -------------------------------------------------------------
	var ext_mag := item("extended_mag", "Extended Mag", DataEnums.LoadoutSlot.ATTACHMENT, "+1 FP.", {"firepower_bonus": 1})
	var foregrip := item("foregrip", "Foregrip", DataEnums.LoadoutSlot.ATTACHMENT, "Cover 1.", {"cover": 1})
	var holo := item("holo_sight", "Holo Sight", DataEnums.LoadoutSlot.ATTACHMENT, "First Shot in Mid zones.", {},
		[fx(T.PASSIVE, K.GRANT_FIRST_SHOT, TG.OPERATOR, Z.OPERATOR_ZONE, 0, {"condition": C.ZONE_IS_MID})])
	var ceramic := item("ceramic_lining", "Ceramic Lining", DataEnums.LoadoutSlot.ATTACHMENT, "+2 Armor.", {"armor_bonus": 2})
	var kestrel := item("kestrel_ar7", "Kestrel AR-7", DataEnums.LoadoutSlot.PRIMARY, "AR. Reliable.",
		{"weapon_class": W.AR, "operator_firepower": 3, "operator_armor": 7, "rotations_per_round": 1,
		 "attachments": [ext_mag, foregrip, holo, ceramic]})
	var wasp := item("wasp_9", "Wasp-9", DataEnums.LoadoutSlot.PRIMARY, "SMG. First Shot. May Rotate twice per round.",
		{"weapon_class": W.SMG, "operator_firepower": 2, "operator_armor": 6, "rotations_per_round": 2, "first_shot": true,
		 "attachments": [ext_mag, foregrip, ceramic]})
	item("longreach_338", "Longreach .338", DataEnums.LoadoutSlot.PRIMARY, "Sniper. Pick.",
		{"weapon_class": W.SNIPER, "operator_firepower": 3, "operator_armor": 5, "rotations_per_round": 1, "pick": true,
		 "attachments": [ext_mag, foregrip, holo, ceramic]})
	# kc-loadout-cut: the P-12 Sidearm, Frag Grenade and Flashbang are gone.
	var p_disc := item("streak_discipline", "Streak Discipline", DataEnums.LoadoutSlot.PERK, "Your killstreak thresholds -1 (min 1).", {},
		[fx(T.PASSIVE, K.STREAK_THRESHOLD_MOD, TG.OWNER, Z.ANY, -1)])
	var p_salv := item("field_salvage", "Field Salvage", DataEnums.LoadoutSlot.PERK, "The first time each round you eliminate an enemy, draw 1.",
		{"uses_per_round": 1}, [fx(T.ON_ELIMINATE, K.DRAW, TG.OWNER, Z.ANY, 1)])
	var p_grit := item("grit", "Grit", DataEnums.LoadoutSlot.PERK, "Once per match, your Operator survives lethal damage with 1 Armor.",
		{"uses_per_match": 1}, [fx(T.PASSIVE, K.SURVIVE_LETHAL, TG.OPERATOR, Z.ANY, 1)])
	var p_obj := item("objective_focus", "Objective Focus", DataEnums.LoadoutSlot.PERK, "End of round: if you control 2+ zones, streak +1.", {},
		[fx(T.END_OF_ROUND, K.STREAK_BONUS, TG.OWNER, Z.ANY, 1, {"condition": C.YOU_CONTROL_2_PLUS_ZONES})])
	var recon := item("recon_drone", "Recon Drone", DataEnums.LoadoutSlot.KILLSTREAK,
		"This round and next: enemy deployments are shown face-up during Deploy, and enemy units lose Cover.",
		{"streak_threshold": 2},
		[fx(T.IMMEDIATE, K.REVEAL_DEPLOYMENTS, TG.OWNER, Z.ALL_ZONES, 0, {"duration_rounds": 2}),
		 fx(T.IMMEDIATE, K.REMOVE_COVER, TG.ALL_ENEMIES, Z.ALL_ZONES, 0, {"duration_rounds": 2})])
	var mortar := item("mortar_barrage", "Mortar Barrage", DataEnums.LoadoutSlot.KILLSTREAK, "2 damage to each enemy unit in one zone.",
		{"streak_threshold": 3}, [fx(T.ON_PLAY, K.DAMAGE, TG.ALL_ENEMIES, Z.CHOSEN_ZONE, 2)])
	var sentry_ks := item("sentry_turret", "Sentry Turret", DataEnums.LoadoutSlot.KILLSTREAK,
		"Place a Sentry (FP 2 / Armor 4, Cover 1) at the back of a zone's line until destroyed.",
		{"streak_threshold": 4}, [fx(T.ON_PLAY, K.SUMMON_UNIT, TG.OWNER, Z.CHOSEN_ZONE, 0, {"summon_card": sentry})])
	var helo := item("attack_helo", "Attack Helo", DataEnums.LoadoutSlot.KILLSTREAK,
		"Start of this round's and next round's firefights: 2 damage to the enemy point man in every zone.",
		{"streak_threshold": 5}, [fx(T.START_OF_FIREFIGHT, K.DAMAGE, TG.ENEMY_POINT_MAN, Z.ALL_ZONES, 2, {"duration_rounds": 2})])

	# --- Map ---------------------------------------------------------------
	var map := MapData.new()
	map.id = &"port_vasel"; map.display_name = "Port Vasel"
	map.zone_names = PackedStringArray(["Container Stacks", "Crane Yard", "Loading Offices"])
	var zr: Array[DataEnums.RangeTag] = [DataEnums.RangeTag.CLOSE, DataEnums.RangeTag.LONG, DataEnums.RangeTag.MID]
	map.zone_ranges = zr
	map = save(map, "res://data/maps/port_vasel.tres")

	# --- Squads --------------------------------------------------------------
	var rusher := squad("squad_rusher", "SandViper_07", "DSRT", DataEnums.Personality.RUSHER,
		cards_list([[point_man, 3], [breacher, 3], [flanker, 2], [rifleman, 2], [shieldman, 1], [medic, 1],
			[callout, 1], [flank_route, 2], [bac, 1], [ammo, 1], [tripwire, 1]]),
		wasp, [ext_mag], [], [recon, sentry_ks],  # p19: Mortar -> Sentry (balance-log B2)
		[1.5, 0.5, 2.0, 3.0], 0.15, [DataEnums.RangeTag.CLOSE])
	# kc-art-traits-impl (head F1): one Gunner -> Hold the Line (campaign shortfall from LMG Pierce).
	# SquadData.identity_trait and CardData.trait_options were added to the .tres files directly.
	var anchor := squad("squad_anchor", "Bulwark_Nine", "QUAY", DataEnums.Personality.ANCHOR,
		cards_list([[gunner, 2], [shieldman, 2], [rifleman, 3], [medic, 2], [demo, 2], [marksman, 1],
			[hold, 3], [supp_fire, 2], [comms, 1]]),
		kestrel, [foregrip], [], [recon, sentry_ks],
		[1.0, 1.5, 3.0, 3.0], 0.10, [])
	var rival := squad("squad_black_meridian", "Meridian_Six", "BKMRD", DataEnums.Personality.ANCHOR,
		cards_list([[anvil, 1], [wren, 1], [gunner, 2], [shieldman, 2], [marksman, 2], [breacher, 1], [medic, 2],
			[demo, 1], [rifleman, 2], [hold, 1], [supp_fire, 1], [bac, 1], [comms, 1], [callout, 1], [ammo, 1]]),
		kestrel, [foregrip, ceramic, ext_mag], [p_grit, p_obj], [recon, mortar, sentry_ks],  # p19: + Extended Mag (B4)
		[1.2, 1.2, 2.5, 3.0], 0.05, [])
	squad("squad_tutorial", "TrainingBot_01", "DRILL", DataEnums.Personality.RUSHER,
		cards_list([[rifleman, 8], [point_man, 3], [marksman, 2], [medic, 2]]),
		kestrel, [], [], [],
		[1.0, 1.0, 2.0, 3.0], 0.0, [])

	# --- Run config ------------------------------------------------------------
	var run := RunConfig.new()
	run.id = &"run_default"; run.display_name = "Prototype Run"
	# p19 (balance-log B3): the Anchor plays Zone Control in Bracket 1 and Firefight in Bracket 2.
	var plan: Array = [[1, false, rusher, DataEnums.GameMode.ZONE_CONTROL], [1, false, anchor, DataEnums.GameMode.ZONE_CONTROL],
		[2, false, rusher, DataEnums.GameMode.FIREFIGHT], [2, false, anchor, DataEnums.GameMode.FIREFIGHT],
		[2, true, rival, DataEnums.GameMode.ZONE_CONTROL]]
	var ms: Array[RunMatchData] = []
	for p: Array in plan:
		var m := RunMatchData.new()
		m.bracket = p[0]; m.is_rival = p[1]; m.squad = p[2]; m.mode = p[3]; m.map = map
		m.enemy_firepower_bonus = 0
		m.enemy_armor_bonus = 1 if p[0] == 2 else 0
		ms.append(m)
	run.matches = ms
	run.tickets = 3
	run.supply_drop_choices = 3
	run.weapon_level_after_matches = PackedInt32Array([1, 3, 4])
	run.attachment_choices = 2
	run.perk_offer_after_matches = PackedInt32Array([2, 4])
	run.perk_choices = 2
	# p19 (balance-log B1): Recon Specialist -> a second Breacher.
	# kc-syn §5.1: the plain v3 starter (kc-no-training: copy levels are gone).
	# kc-onboard: the shipped starter is now the 20 Standard Issue cards (data/cards/si_*.tres), with
	# the run ladder fields, the slot 1-2 enemy decks and legacy_cards edited in run_config.tres
	# directly (like trait_options / identity_trait); this generator still writes the kc-syn data.
	run.starter_deck = cards_list([[rifleman, 3], [point_man, 4], [breacher, 3], [marksman, 2], [medic, 2],
		[gunner, 1], [shieldman, 1], [ammo, 2], [hold, 2]])
	run.starter_primary = kestrel
	run.starter_killstreaks = items([recon, mortar, helo])
	run.reward_pool = cards_list([[flanker, 2], [demo, 2], [bac, 2], [comms, 2], [anvil, 1], [wren, 1],
		[point_man, 1], [marksman, 1], [medic, 1], [breacher, 1], [gunner, 1], [shieldman, 1], [recon_spec, 1],
		[callout, 2], [ammo, 1], [flank_route, 2], [supp_fire, 2], [hold, 1], [tripwire, 2],  # kc-syn: +1 each (+ Brawler x2 in the .tres)
		# kc-field-impl: the six new Fields enter through the reward pool only (field-cards.md §4.2).
		[listening_post, 1], [mortar_pit, 1], [bulwark, 1], [war_standard, 1], [sniper_perch, 1], [aid_station, 1]])
	run.killstreak_pool = items([recon, mortar, sentry_ks, helo])
	run.perk_pool = items([p_disc, p_salv, p_grit, p_obj])
	run.perk_slots = 3; run.killstreak_slots = 3
	run.deck_size = 20; run.opening_hand = 4; run.round1_extra_draw = 1; run.free_mulligans = 1
	run.draws_per_round = 2; run.hand_cap = 7; run.supply_round_offset = 1; run.supply_cap = 7
	run.zone_capacity = 4
	run.zone_control_target = 6; run.firefight_target = 7; run.round_cap = 8; run.overtime_draw_round = 10
	run.detonator_arm_rounds = 2
	run.range_bonus_smg = PackedInt32Array([1, 0, 0])
	run.range_bonus_shotgun = PackedInt32Array([2, 0, -1])
	run.range_bonus_ar = PackedInt32Array([0, 1, 0])
	run.range_bonus_sniper = PackedInt32Array([-1, 0, 2])
	run.range_bonus_lmg = PackedInt32Array([0, 0, 0])
	save(run, "res://data/run_config.tres")
	print("generated %d files" % _saved.size())


func squad(id: String, tag: String, clan: String, pers: int, deck: Array[CardData], primary: LoadoutItem, atts: Array,
		perks: Array, ks: Array, w: Array, sb: float, ranges: Array) -> SquadData:
	var s := SquadData.new()
	s.id = StringName(id); s.display_name = tag; s.clan_tag = clan; s.personality = pers
	s.deck = deck; s.primary = primary; s.attachments = items(atts)
	s.perks = items(perks); s.killstreaks = items(ks)
	s.weight_damage_dealt = w[0]; s.weight_damage_taken = w[1]; s.weight_zone_control = w[2]; s.weight_deny_streak = w[3]
	s.second_best_chance = sb
	var r: Array[DataEnums.RangeTag] = []
	r.assign(ranges)
	s.preferred_ranges = r
	return save(s, "res://data/squads/%s.tres" % id)
