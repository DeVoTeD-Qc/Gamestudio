# gen_wip_cards.gd
# Purpose: kc-wip-impl. Writes the studio head's 19 "Wip" cards (documentation/design/wip-set.md §1, with
#   the head's answers W2 (a) Private I 2/1 and Private II 2/3, W3 (a) Kamikaze cost 2, W4 (a) one home
#   trait per card, §3.3) to res://data/cards/kc_wip_<name>.tres. Ids are kc_wip_<snake_name> (the MW3
#   pitch mapping, documentation/art/mw3-pitch-set.csv, already uses them). The Privates are the Standard
#   Issue starter (plain, never offered, no trait); the other 15 join the reward pool and the Duel pool.
#   Re-running overwrites the 19 files with the same content.
# Run: godot --headless --path <project> -s res://tests/tools/gen_wip_cards.gd
# Author: Mechanics Developer Agent (kc-wip-impl)
extends SceneTree

const K := DataEnums.EffectKind
const T := DataEnums.Target
const Z := DataEnums.ZoneScope
const TR := DataEnums.Trigger
const W := DataEnums.WeaponClass

## [suffix, name, type, cost, fp, armor, weapon class, trait, text]
const CARDS: Array = [
	["private_1", "Private I", 0, 1, 2, 1, W.NONE, &"", ""],
	["private_2", "Private II", 0, 2, 2, 3, W.NONE, &"", ""],
	["private_3", "Private III", 0, 3, 3, 3, W.NONE, &"", ""],
	["private_4", "Private IV", 0, 4, 4, 4, W.NONE, &"", ""],
	["scout", "Scout", 0, 1, 0, 3, W.SMG, &"vanguard", "Front line."],
	["medic", "Medic", 0, 2, 2, 3, W.AR, &"undead", "Patch 1."],
	["sharpshooter", "Sharpshooter", 0, 3, 3, 2, W.SNIPER, &"specops", "First Shot."],
	["flag_bearer", "Flag Bearer", 0, 4, 2, 2, W.AR, &"vanguard", "On Deploy: your units here get +1/+1 (itself included)."],
	["hacker", "Hacker", 0, 2, 1, 1, W.SMG, &"specops", "On Deploy: +1 Supply next round."],
	["kamikaze", "Kamikaze", 0, 2, 1, 1, W.NONE, &"heavy", "On Down: 1 damage to each enemy unit here."],
	["runner", "Runner", 0, 3, 2, 4, W.SMG, &"specops", "Agile."],
	["sniper", "Sniper", 0, 4, 5, 2, W.SNIPER, &"specops", "Pick."],
	["juggernaut", "Juggernaut", 0, 5, 4, 5, W.LMG, &"heavy", "Pierce."],
	["riot_shield", "Riot Shield", 0, 4, 1, 3, W.NONE, &"vanguard", "Suppress 1. Cover 1."],
	["fast_learner", "Fast Learner", 0, 5, 3, 4, W.AR, &"undead", "At end of round: this unit gets +1/+1."],
	["laser_gunner", "Laser Gunner", 0, 5, 2, 2, W.NONE, &"heavy", "Beam. It hits your units in front of it too."],
	["war_shout", "War Shout", 1, 2, 0, 0, W.NONE, &"", "Your units get +2 FP this round."],
	["barrage", "Barrage", 1, 3, 0, 0, W.NONE, &"", "1 damage to each enemy frontline unit."],
	["premium_loadout", "Premium Loadout", 1, 1, 0, 0, W.NONE, &"", "A unit of yours gets +1/+1."],
]


func _init() -> void:
	for row: Array in CARDS:
		var c: CardData = build(row)
		var v: DataValidator = DataValidator.new()
		v.begin("gen", String(c.id))
		c.validate(v)
		if v.error_count() > 0:
			push_error("gen_wip_cards: %s does not validate: %s" % [c.id, v.issues])
		var path: String = "res://data/cards/%s.tres" % c.id
		var err: int = ResourceSaver.save(c, path)
		print("%s %s" % ["saved" if err == OK else "FAILED", path])
	quit()


static func fx(trigger: int, kind: int, target: int, scope: int, amount: int, duration: int = 0) -> EffectData:
	var e: EffectData = EffectData.new()
	e.trigger = trigger
	e.kind = kind
	e.target = target
	e.zone_scope = scope
	e.amount = amount
	e.duration_rounds = duration
	return e


static func build(row: Array) -> CardData:
	var c: CardData = CardData.new()
	var key: String = row[0]
	c.id = StringName("kc_wip_" + key)
	c.display_name = row[1]
	c.card_type = row[2]
	c.cost = row[3]
	c.firepower = row[4]
	c.armor = row[5]
	c.weapon_class = row[6]
	c.text = row[8]
	var t: StringName = row[7]
	if key.begins_with("private_"):
		c.collectible = false
		c.standard_issue = true
	elif c.is_unit():
		c.card_trait = t
		c.trait_options.assign([t])
	match key:
		"scout":
			c.arrives_front = true
		"medic":
			c.patch = 1
		"sharpshooter":
			c.first_shot = true
		"sniper":
			c.pick = true
		"juggernaut":
			c.pierce = true
		"riot_shield":
			c.suppress = true
			c.suppress_amount = 1
			c.cover = 1
		"runner":
			c.agile = true
		"laser_gunner":
			c.beam = true
		"flag_bearer":
			c.effects.append(fx(TR.ON_DEPLOY, K.MODIFY_FIREPOWER, T.ALL_FRIENDLIES, Z.THIS_ZONE, 1))
			c.effects.append(fx(TR.ON_DEPLOY, K.MODIFY_ARMOR, T.ALL_FRIENDLIES, Z.THIS_ZONE, 1))
		"hacker":
			c.effects.append(fx(TR.ON_DEPLOY, K.GAIN_SUPPLY_NEXT_ROUND, T.OWNER, Z.ANY, 1))
		"kamikaze":
			c.effects.append(fx(TR.ON_DOWN, K.DAMAGE, T.ALL_ENEMIES, Z.THIS_ZONE, 1))
		"fast_learner":
			c.effects.append(fx(TR.END_OF_ROUND, K.MODIFY_FIREPOWER, T.SELF, Z.THIS_ZONE, 1))
			c.effects.append(fx(TR.END_OF_ROUND, K.MODIFY_ARMOR, T.SELF, Z.THIS_ZONE, 1))
		"war_shout":
			c.effects.append(fx(TR.ON_PLAY, K.MODIFY_FIREPOWER, T.ALL_FRIENDLIES, Z.ALL_ZONES, 2, 1))
		"barrage":
			c.effects.append(fx(TR.ON_PLAY, K.DAMAGE, T.ENEMY_POINT_MAN, Z.ALL_ZONES, 1))
		"premium_loadout":
			c.effects.append(fx(TR.ON_PLAY, K.MODIFY_FIREPOWER, T.CHOSEN_FRIENDLY, Z.ANY, 1))
			c.effects.append(fx(TR.ON_PLAY, K.MODIFY_ARMOR, T.CHOSEN_FRIENDLY, Z.ANY, 1))
	return c
