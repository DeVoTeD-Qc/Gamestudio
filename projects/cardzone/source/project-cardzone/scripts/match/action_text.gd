# action_text.gd
# Purpose: Words for the match screen (cz11): why an action is illegal (every LoadoutRules.ERR_*
#   code, with the numbers that matter), and one short line per engine event as the human seat
#   sees it (events already filtered by LoadoutRules.events_for, so a rival's private cards never
#   reach this file). Plain text, no colour-only meaning.
# Dependencies: CardDB autoload (names), LoadoutRules (error codes), MatchState (seats).
# Author: UI/UX Agent (cz11)
extends RefCounted


static func _db() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null("CardDB") if loop != null else null


static func card_name(id: Variant) -> String:
	var db: Node = _db()
	var c: CardData = db.get_card(StringName(str(id))) if db != null else null
	return c.display_name if c != null else str(id)


static func area_name(id: Variant) -> String:
	var db: Node = _db()
	var a: AreaData = db.get_area(StringName(str(id))) if db != null else null
	return a.display_name if a != null else str(id)


# --- Illegal actions --------------------------------------------------------------

## Why `a` was refused, in words. ctx (MatchController._context): here, to, dist, cost, have,
## range, name, fires, limit, min_loadout, cap.
static func reason(code: StringName, a: Dictionary, ctx: Dictionary) -> String:
	var t: String = String(a.get("type", ""))
	var nm: String = String(ctx.get("name", "That card"))
	match code:
		LoadoutRules.ERR_OVER:
			return "The match is over."
		LoadoutRules.ERR_PHASE:
			return "Pick your drop area first: tap an outer area on the map." if t != "drop" else "The drop is over."
		LoadoutRules.ERR_NOT_YOUR_TURN:
			return "It's the rival's turn. Wait for yours."
		LoadoutRules.ERR_PENDING_BRACE:
			return "Brace first: tap armour cards in your next hand, then BRACE."
		LoadoutRules.ERR_NO_PENDING:
			return "Nothing to brace against right now."
		LoadoutRules.ERR_NOT_IN_HAND:
			return "%s isn't in your hand." % nm
		LoadoutRules.ERR_NOT_IN_LINE:
			return "%s isn't in your line. Play or loot a weapon first; then it can fire." % nm
		LoadoutRules.ERR_BAD_CARD:
			if t == "shoot":
				return "Only a weapon can fire."
			return "%s can't be played." % nm
		LoadoutRules.ERR_ADRENALINE:
			return "This match allows Adrenaline for Move only."
		LoadoutRules.ERR_ADRENALINE_CAP:
			return "You've already played %d Hits for Adrenaline this turn (the limit)." % int(ctx.get("cap", 0))
		LoadoutRules.ERR_FRAG_PLAY:
			return "A Frag isn't played: use THROW, then tap an area in range."
		LoadoutRules.ERR_NO_MOVE:
			return "No Move left. Play a card with Move (Dash, Trail Boots…) or a Hit for Adrenaline: Move."
		LoadoutRules.ERR_NOT_ADJACENT:
			if String(ctx.get("to", "")) == String(ctx.get("here", "")):
				return "You're already in %s." % area_name(ctx.get("here", ""))
			return "%s is %d areas away. Move one area at a time, to a neighbour of %s." % [
					area_name(ctx.get("to", "")), int(ctx.get("dist", 0)), area_name(ctx.get("here", ""))]
		LoadoutRules.ERR_GAS:
			return "%s is in the gas: its loot can't be taken." % area_name(ctx.get("here", ""))
		LoadoutRules.ERR_NO_SEARCH:
			return "Not enough Search: this costs %d, you have %d. Play Scavenge, Duck or a Hit for Adrenaline: Search." % [
					int(ctx.get("cost", 0)), int(ctx.get("have", 0))]
		LoadoutRules.ERR_NO_SOURCE:
			return "There's nothing to loot here."
		LoadoutRules.ERR_NOT_READY:
			return "This supply drop just landed: it can be looted from next round."
		LoadoutRules.ERR_NO_SHOTS:
			return "%s has already fired %d time%s this turn." % [nm, int(ctx.get("fires", 1)), "" if int(ctx.get("fires", 1)) == 1 else "s"]
		LoadoutRules.ERR_BAD_TARGET:
			return "The rival can't be targeted."
		LoadoutRules.ERR_OUT_OF_RANGE:
			if t == "frag":
				return "%s is %d areas away; %s reaches %d." % [area_name(a.get("area", "")), int(ctx.get("dist", 0)), nm, int(ctx.get("range", 0))]
			return "Out of range: the rival is %d area%s away and %s reaches %d." % [int(ctx.get("dist", 0)),
					"" if int(ctx.get("dist", 0)) == 1 else "s", nm, int(ctx.get("range", 0))]
		LoadoutRules.ERR_ATTACH:
			return "Can't attach: a weapon takes at most 2 attachments, never 2 of the same, and both cards must be in your hand or line."
		LoadoutRules.ERR_NO_HIT:
			return "No Hit in your hand or line to patch up."
		LoadoutRules.ERR_DITCH:
			return "Only a Starter card in your hand can be ditched (not a Hit, not loot, not a weapon with attachments)."
		LoadoutRules.ERR_DITCH_LIMIT:
			return "You've already ditched this turn (%d per turn)." % int(ctx.get("limit", 1))
		LoadoutRules.ERR_MIN_LOADOUT:
			return "Your cards can't go below %d non-Hit cards, so you can't ditch now." % int(ctx.get("min_loadout", 6))
		LoadoutRules.ERR_HOLD:
			return "You can hold up to %d non-Hit cards from your hand." % int(ctx.get("limit", 2))
		LoadoutRules.ERR_RACK:
			return "That rack move isn't possible."
		LoadoutRules.ERR_BRACE:
			return "Only cards in your next hand with a Brace value, not braced yet this turn, can brace."
		LoadoutRules.ERR_UNDO:
			return "Nothing to undo."
		LoadoutRules.ERR_DROP:
			return "Drop into an outer area (1-6), not the Core."
		LoadoutRules.ERR_UNKNOWN:
			return "That isn't an action."
	return "Not allowed (%s)." % code


# --- Events -------------------------------------------------------------------------

## One line for an event as seat `me` sees it ("" = not worth a line).
static func describe(e: Dictionary, me: int) -> String:
	var seat: int = int(e.get("seat", -1))
	var you: bool = seat == me
	var who: String = "You" if you else "Rival"
	match String(e.get("type", "")):
		"dropped":
			return "%s dropped into %s." % [who, area_name(e["area"])]
		"round_started":
			return "Round %d." % int(e["round"])
		"bounty_changed":
			var to: int = int(e.get("to", -1))
			if to < 0:
				return "Health is tied: the Bounty is set aside."
			return "You take the Bounty (most health)." if to == me else "The rival takes the Bounty (most health)."
		"zone_flipped":
			var db: Node = _db()
			var z: ZoneCardData = db.get_zone_card(int(e["card"])) if db != null else null
			return "Zone card %d: %s." % [int(e["card"]), z.display_name if z != null else "?"]
		"gas_closed":
			return "Gas closes %s. Ending a turn there costs 1 Hit." % area_name(e["area"])
		"drop_landed":
			return "Supply drop: %s lands in %s." % [card_name(e["card_id"]), area_name(e["area"])]
		"final_circle":
			var taken: Dictionary = e.get("taken", {})
			return "Final circle %d: you take %d Hit%s, the rival %d." % [int(e["step"]), int(taken.get(me, 0)),
					"" if int(taken.get(me, 0)) == 1 else "s", int(taken.get(1 - me, 0))]
		"turn_started":
			return "Your turn." if you else "Rival's turn."
		"drew":
			if you and e.has("cards"):
				var hits: int = int(e.get("hits", 0))
				return "You draw %d card%s%s." % [int(e["count"]), "" if int(e["count"]) == 1 else "s",
						(" (%d Hit%s came along)" % [hits, "" if hits == 1 else "s"]) if hits > 0 else ""]
			return "Rival draws %d card%s." % [int(e["count"]), "" if int(e["count"]) == 1 else "s"]
		"played":
			var gain: PackedStringArray = []
			if int(e.get("move", 0)) > 0:
				gain.append("Move +%d" % int(e["move"]))
			if int(e.get("search", 0)) > 0:
				gain.append("Search +%d" % int(e["search"]))
			return "%s played %s%s." % [who, card_name(e["card_id"]), (": " + ", ".join(gain)) if not gain.is_empty() else ""]
		"adrenaline":
			return "%s played a Hit for Adrenaline: %s +1." % [who, "Move" if e["mode"] == "move" else "Search"]
		"healed":
			return "%s healed %d (health %d)." % [who, int(e["healed"]), int(e["health"])]
		"spent":
			return "%s is spent (out of the game)." % card_name(e["card_id"])
		"pulled":
			return "%s pulled %d card%s." % [who, int(e["count"]), "" if int(e["count"]) == 1 else "s"]
		"moved":
			return "%s moved to %s." % [who, area_name(e["to"])]
		"looted":
			return "%s looted %s (Search %d)." % [who, card_name(e["card_id"]), int(e.get("cost", 0))]
		"attached":
			return "%s attached %s to %s." % [who, card_name(e["attachment_id"]), card_name(e["weapon_id"])]
		"patched_up":
			return "%s patched up: health %d." % [who, int(e["health"])]
		"ditched":
			return "%s ditched %s." % [who, card_name(e["card_id"])]
		"shot_declared":
			var tail: String = " (no Brace: Suppressor)" if e.get("suppressed", false) else ""
			return "%s fired %s: %d damage%s." % [who, card_name(e["weapon_id"]), int(e["damage"]), tail]
		"frag_thrown":
			return "%s threw a Frag into %s." % [who, area_name(e["area"])]
		"brace_requested":
			return "Brace! %d damage incoming." % int(e["damage"]) if you else "The rival may Brace (%d damage)." % int(e["damage"])
		"braced":
			var names: PackedStringArray = []
			for id: Variant in e.get("card_ids", []):
				names.append(card_name(id))
			if names.is_empty():
				return "%s didn't brace: %d Hit%s." % [who, int(e["hits"]), "" if int(e["hits"]) == 1 else "s"]
			return "%s braced with %s (Brace %d): %d Hit%s." % [who, ", ".join(names), int(e["total"]), int(e["hits"]), "" if int(e["hits"]) == 1 else "s"]
		"hits_landed":
			return "%s took %d Hit%s: health %d%s." % [who, int(e["count"]), "" if int(e["count"]) == 1 else "s",
					int(e["health"]), ", Down" if e.get("down", false) else ""]
		"bounty_claimed":
			return "%s claimed the Bounty: healed %d." % [who, int(e["healed"])]
		"gas_hit":
			return "%s ended the turn in gas: 1 Hit (health %d)." % [who, int(e["health"])]
		"packed":
			if you:
				return "You packed: %d held on top, the rest under your loadout." % int(e.get("held_count", 0))
			return "Rival packed: %d held." % int(e.get("held_count", 0))
		"eliminated":
			return "%s %s eliminated." % [who, "are" if you else "is"]
		"crate_formed":
			return "A crate drops in %s." % area_name(e["area"])
		"match_ended":
			return result_text(e, me)
		"undone":
			return "Undone."
		"conceded":
			return "%s conceded." % who
	return ""


## "You win: rival eliminated by a shot." / "Draw: ..." from a match_end dictionary.
static func result_text(r: Dictionary, me: int) -> String:
	var cause: String = {"shot": "a shot", "frag": "a Frag", "gas": "the gas", "final_circle": "the final circle",
			"hard_end": "the hard end (more health)", "concede": "concession"}.get(String(r.get("cause", "")), String(r.get("cause", "")))
	if String(r.get("result", "")) == "draw":
		return "Draw (%s)." % cause
	var won: bool = int(r.get("winner", -1)) == me
	return ("You win (%s)." if won else "The rival wins (%s).") % cause
