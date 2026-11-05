# card_words.gd
# Purpose: Plain-language words for a card (cz-clarity): what it gives you, in short sentences a
#   newcomer can act on ("Play it: +1 Search this turn."), and what the little icons on the card
#   mean. Used by the inspector (right click / long press on any card), the loot list and the
#   outcome lines ("You looted Scrap SMG: a gun, 2 damage, same area only."). Reads only CardData,
#   so it never changes a rule; numbers come from the card and BalanceConfig.
# Dependencies: CardData, DataEnums.
# Author: UI/UX Agent (cz-clarity)
extends RefCounted


## "same area only" / "your area or next door" / "anywhere on the map".
static func range_words(rng: int) -> String:
	match rng:
		0:
			return "same area only"
		1:
			return "your area or a neighbouring one"
	return "anywhere on the map"


## One short phrase for what the card is: "a gun: 2 damage, same area only".
static func short(c: CardData) -> String:
	if c == null:
		return ""
	if c.is_hit():
		return "a Hit: you lost 1 health"
	if c.is_weapon():
		return "a gun: %d damage, %s" % [c.dmg, range_words(c.rng)]
	if c.blast_dmg > 0:
		return "a grenade: %d damage to everyone in one area" % c.blast_dmg
	if c.is_attachment():
		return "a gun attachment: %s" % _attach_bonus(c)
	var parts: PackedStringArray = _play_gains(c)
	if c.brace > 0:
		parts.append("Brace %d" % c.brace)
	return ", ".join(parts) if not parts.is_empty() else c.display_name


## The sentences the inspector shows under "WHAT IT GIVES YOU".
static func gives(c: CardData) -> PackedStringArray:
	var out: PackedStringArray = []
	if c == null:
		return out
	if c.is_hit():
		out.append("You took a Hit: it cost you 1 health and landed on top of your deck.")
		out.append("When you draw it, it is a free extra card: play it for +1 Move or +1 Search (Adrenaline).")
		out.append("PATCH UP (spend 2 Search) puts it back on your health.")
		out.append("While a Hit is in your next hand you are DOWN: every shot at you deals 1 less.")
		return out
	if c.id == &"bounty":
		out.append("Goes to whoever has the most health at the start of a round.")
		out.append("Whoever hits the holder heals 1. In the final circle the holder takes 1 extra Hit.")
		return out
	if c.is_weapon():
		var fires: String = "once a turn" if c.fires_per_turn <= 1 else "%d times a turn" % c.fires_per_turn
		out.append("A gun: %d damage to the rival, %s. Fires %s." % [c.dmg, range_words(c.rng), fires])
		out.append("Play it (or loot it) into your played row, then tap it there and FIRE.")
		if c.ignores_cover:
			out.append("Ignores Cover: areas with a shield don't soften its shots.")
		return out
	if c.blast_dmg > 0:
		out.append("Throw it into an area up to %d away: %d damage to everyone there, you too. Ignores Cover." % [maxi(c.blast_rng, 0), c.blast_dmg])
		out.append("Used up after one throw.")
		return out
	if c.is_attachment():
		out.append("Attach it to a gun in your hand or played row: %s. It stays on the gun." % _attach_bonus(c))
		return out
	var gains: PackedStringArray = _play_gains(c)
	if not gains.is_empty():
		out.append("Play it: %s this turn." % ", ".join(gains))
	if c.heal > 0:
		out.append("Heal %d: puts up to %d Hit%s from your hand or played row back on your health." % [c.heal, c.heal, "" if c.heal == 1 else "s"])
	if c.pull > 0:
		out.append("Pull %d: draw %d more card%s right away." % [c.pull, c.pull, "" if c.pull == 1 else "s"])
	if c.brace > 0:
		out.append("Or keep it: while it sits in your next hand it blocks %d damage when you're shot (Brace %d)." % [c.brace, c.brace])
	if c.spent == DataEnums.SpentMode.ON_PLAY:
		out.append("Used up when played (it leaves the game).")
	elif c.spent == DataEnums.SpentMode.ON_BRACE:
		out.append("Used up if you Brace with it.")
	return out


## What the icons on this card mean (only the ones it shows).
static func icon_legend(c: CardData) -> String:
	if c == null or c.is_hit():
		return ""
	var parts: PackedStringArray = []
	if c.cost > 0:
		parts.append("dark disc = Search needed to loot it")
	parts.append("shield = Brace (a dash means none)")
	if c.is_weapon():
		parts.append("crosshair = damage, R = range")
	if c.move > 0:
		parts.append("boot = Move")
	if c.search > 0:
		parts.append("magnifier = Search")
	if c.heal > 0:
		parts.append("cross = Heal")
	if c.is_starter():
		parts.append("dashed tag = Starter card")
	else:
		parts.append("letter tag = rarity (C, U, R, E, L)")
	return "Icons: " + "; ".join(parts) + "."


static func _play_gains(c: CardData) -> PackedStringArray:
	var out: PackedStringArray = []
	if c.move > 0:
		out.append("+%d Move" % c.move)
	if c.search > 0:
		out.append("+%d Search" % c.search)
	return out


static func _attach_bonus(c: CardData) -> String:
	var parts: PackedStringArray = []
	if c.attach_dmg > 0:
		parts.append("+%d damage" % c.attach_dmg)
	if c.attach_rng > 0:
		parts.append("+%d range" % c.attach_rng)
	if c.attach_extra_fire > 0:
		parts.append("fires %d more time%s a turn" % [c.attach_extra_fire, "" if c.attach_extra_fire == 1 else "s"])
	if c.attach_no_brace:
		parts.append("the rival can't block its shots with cards")
	return ", ".join(parts) if not parts.is_empty() else "no bonus"
