# killstreak_strikes.gd
# Purpose: kc-ks-seq (studio head: "the ones that do damage like mortar should wait until fight start
#   and the killstreak's sequence triggers before dealing damage"). A killstreak that deals damage is
#   a STRIKE. It never deals damage when it is earned, called or revealed: at Reveal it is QUEUED, and
#   it resolves as Firefight step 0, "Killstreak strikes", before column A fights.
#
#   Timing, exactly (firefight-order.md §2.1 step 0, updated):
#     Deploy   the call is face-down (ITEM_USED, private). Non-damage killstreaks keep their timing:
#              Recon Drone resolves at once (IMMEDIATE), the Sentry arrives at Reveal step b.
#     Reveal   step b reveals the strike (ITEM_REVEALED) and queues it (KILLSTREAK_QUEUED): its
#              ON_PLAY damage is stored in MatchState.firefight_effects for this round's fight; its
#              START_OF_FIREFIGHT damage (Attack Helo) is registered as before, for its rounds.
#     Fight 0  Killstreak strikes, one at a time, in queue order: strikes still standing from an
#              earlier round first (Attack Helo's second pass), then this round's calls in Reveal
#              order (initiative side first, each side's plays in order). Each strike:
#              KILLSTREAK_STRIKE -> its damage (DAMAGE_DEALT, SURVIVED_LETHAL) -> the dead are
#              removed (UNIT_ELIMINATED) -> KILLSTREAK_RESOLVED {hits, kills, what}. The next strike
#              sees the board as the last one left it. Then the lines close up (LINE_ADVANCED)
#              and column A starts.
#   Damage values, targets, Cover and streak credit are unchanged (a killstreak kill gives no streak).
#   Stateless and deterministic; the queue is MatchState.firefight_effects, so MatchClone, the
#   outcome preview and the AI view see it with no extra state.
# Dependencies: DataEnums, EffectData, LoadoutItem, RulesEvent, EffectResolver, RulesUnit (MatchState passed in).
# Author: Game Feel Engineer Agent (kc-ks-seq)
class_name KillstreakStrikes
extends RefCounted

const ZONE_LETTERS: Array[String] = ["A", "B", "C"]
const MINUS: String = "−"


## True when the item is a killstreak that deals damage (Mortar Barrage, Attack Helo).
static func is_strike(item: LoadoutItem) -> bool:
	if item == null or item.slot != DataEnums.LoadoutSlot.KILLSTREAK:
		return false
	for e: EffectData in item.effects:
		if e != null and e.kind == DataEnums.EffectKind.DAMAGE:
			return true
	return false


## True when this effect of a strike waits for the fight (ON_PLAY damage). START_OF_FIREFIGHT
## effects already wait; everything else (Cover removal, summons...) keeps its own timing.
static func waits_for_fight(e: EffectData) -> bool:
	return e != null and e.trigger == DataEnums.Trigger.ON_PLAY and e.kind == DataEnums.EffectKind.DAMAGE


## Reveal step b for a killstreak strike: the effects that don't wait resolve now (as
## EffectResolver.resolve_play would), the ON_PLAY damage is queued for this round's fight step 0,
## then KILLSTREAK_QUEUED tells the UI where and when it lands.
static func queue(state, si: int, item: LoadoutItem, ctx: Dictionary) -> void:
	var now: Array[EffectData] = []
	var queued: int = 0
	var zones: Array[int] = []
	var fights: int = 1
	for e: EffectData in item.effects:
		if e == null:
			continue
		if waits_for_fight(e):
			state.firefight_effects.append({"effect": e, "ctx": ctx, "until_round": state.round_number,
					"from_round": state.round_number})
			queued += 1
			for z: int in EffectResolver.scope_zones(state, e, ctx):
				if z >= 0 and z not in zones:
					zones.append(z)
		else:
			now.append(e)
			if e.trigger == DataEnums.Trigger.START_OF_FIREFIGHT and e.kind == DataEnums.EffectKind.DAMAGE:
				fights = maxi(fights, maxi(1, e.duration_rounds))
				for z: int in EffectResolver.scope_zones(state, e, ctx):
					if z >= 0 and z not in zones:
						zones.append(z)
	EffectResolver.resolve_play(state, now, ctx)
	zones.sort()
	state.emit_event(RulesEvent.KILLSTREAK_QUEUED, {
		"side": state.side_name(si), "item_id": item.id, "zone": state.zone_name(int(ctx["zone"])) if state.is_zone(int(ctx["zone"])) else &"",
		"zones": zones.map(func(z: int) -> StringName: return state.zone_name(z)), "fights": fights,
		"resolves": &"firefight",
	})


## Firefight step 0: every registered START_OF_FIREFIGHT / queued strike effect due this round, in
## queue order. Killstreak sources are wrapped in KILLSTREAK_STRIKE ... KILLSTREAK_RESOLVED, with
## their eliminations processed before the next strike. The caller closes the lines up after.
static func resolve_step0(state) -> void:
	var due: Array[Dictionary] = []
	for f: Dictionary in state.firefight_effects:
		if int(f["until_round"]) >= state.round_number:
			due.append(f)
	var i: int = 0
	while i < due.size():
		var ctx: Dictionary = due[i]["ctx"]
		var group: Array[Dictionary] = [due[i]]
		while i + group.size() < due.size() and (due[i + group.size()]["ctx"] as Dictionary) == ctx:
			group.append(due[i + group.size()])
		i += group.size()
		if StringName(ctx.get("source_kind", &"")) != state.SRC_KILLSTREAK:
			for f: Dictionary in group:
				EffectResolver.resolve_effect(state, f["effect"], f["ctx"])
			continue
		_strike(state, group)


static func _strike(state, group: Array[Dictionary]) -> void:
	var ctx: Dictionary = group[0]["ctx"]
	var si: int = int(ctx["side"])
	var item_id: StringName = ctx.get("source_id", &"")
	var zones: Array[int] = []
	for f: Dictionary in group:
		for z: int in EffectResolver.scope_zones(state, f["effect"], ctx):
			if z >= 0 and z not in zones:
				zones.append(z)
	zones.sort()
	var from_round: int = int(group[0].get("from_round", state.round_number))
	var until: int = int(group[0]["until_round"])
	var zone_names: Array = zones.map(func(z: int) -> StringName: return state.zone_name(z))
	var head: Dictionary = {"side": state.side_name(si), "item_id": item_id,
			"zone": state.zone_name(int(ctx["zone"])) if state.is_zone(int(ctx["zone"])) else &"",
			"zones": zone_names, "pass": state.round_number - from_round + 1, "passes": until - from_round + 1}
	state.emit_event(RulesEvent.KILLSTREAK_STRIKE, head)
	var start: int = state.events.size()
	for f: Dictionary in group:
		EffectResolver.resolve_effect(state, f["effect"], f["ctx"])
	var hits: Array[Dictionary] = []
	for ev: Dictionary in state.events_since(start):
		if ev["type"] != RulesEvent.DAMAGE_DEALT or StringName(ev.get("source_id", &"")) != item_id:
			continue
		var u: RulesUnit = state.find_unit(int(ev["target_uid"]))
		hits.append({"uid": int(ev["target_uid"]), "side": ev["side"], "amount": int(ev["amount"]),
				"remaining": int(ev["remaining"]), "card_id": u.source_id if u != null else &"",
				"name": unit_name(u), "zone": state.zone_name(u.zone) if u != null and state.is_zone(u.zone) else &""})
	state.process_eliminations()
	var kills: Array[int] = []
	for ev: Dictionary in state.events_since(start):
		if ev["type"] == RulesEvent.UNIT_ELIMINATED and bool(ev.get("by_killstreak", false)) \
				and StringName(ev.get("by_id", &"")) == item_id:
			kills.append(int(ev["victim_uid"]))
	var done: Dictionary = head.duplicate()
	done["hits"] = hits
	done["kills"] = kills
	done["what"] = log_line(display_name(state, si, item_id), zones, hits, kills)
	state.emit_event(RulesEvent.KILLSTREAK_RESOLVED, done)


## "Mortar Barrage hit column B: Trooper −2, Sergeant −2 (down)". Several columns name each hit's column.
static func log_line(item_name: String, zones: Array[int], hits: Array, kills: Array) -> String:
	var where: String
	if zones.size() == 1:
		where = "column %s" % ZONE_LETTERS[zones[0]]
	elif zones.size() == 3:
		where = "every column"
	else:
		where = "columns %s" % ", ".join(zones.map(func(z: int) -> String: return ZONE_LETTERS[z]))
	if hits.is_empty():
		return "%s hit %s: no targets." % [item_name, where]
	var parts: Array[String] = []
	for h: Dictionary in hits:
		var part: String = "%s %s%d" % [h["name"], MINUS, int(h["amount"])]
		if int(h["amount"]) == 0:
			part += " (Cover)"
		elif int(h["uid"]) in kills:
			part += " (down)"
		if zones.size() > 1 and StringName(h.get("zone", &"")) != &"":
			part += " in %s" % ZONE_LETTERS[MapData.ZONE_IDS.find(StringName(h["zone"]))]
		parts.append(part)
	return "%s hit %s: %s" % [item_name, where, ", ".join(parts)]


static func unit_name(u: RulesUnit) -> String:
	if u == null:
		return "a unit"
	if u.is_operator:
		return "Operator"
	if u.card != null and u.card.display_name != "":
		return u.card.display_name
	return String(u.source_id).replace("_", " ").capitalize()


static func display_name(state, si: int, item_id: StringName) -> String:
	var item: LoadoutItem = state.find_item(si, item_id)
	if item != null and item.display_name != "":
		return item.display_name
	return String(item_id).replace("_", " ").capitalize()
