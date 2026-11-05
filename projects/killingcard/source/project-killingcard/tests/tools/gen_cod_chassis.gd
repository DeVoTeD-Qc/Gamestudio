# gen_cod_chassis.gd
# Purpose: Writes the 4 chassis card-system.md §3.2 adds (Brawler, Smoke Screen, Blackout, Sabotage)
#   as data/cards/*.tres, using only existing effect kinds (§3.2 table). Skips any that already exist,
#   so it never rewrites the rest of the content (gen_content.gd regenerates everything).
#   Data only (kc-cod2): they are NOT in the reward pool, the starter deck or the squads; the private
#   pitch build adds them to its decks (scripts/data/pitch_decks.gd). Provisional until balance_sim.
# Run: godot --headless --path <project> -s res://tests/tools/gen_cod_chassis.gd
# Author: Mechanics Developer Agent (kc-cod2)
extends SceneTree


func _init() -> void:
	var T := DataEnums.Trigger
	var K := DataEnums.EffectKind
	var TG := DataEnums.Target
	var Z := DataEnums.ZoneScope
	var W := DataEnums.WeaponClass
	var TACTIC: int = DataEnums.CardType.TACTIC
	var brawler := CardData.new()
	brawler.id = &"brawler"
	brawler.display_name = "Brawler"
	brawler.card_type = DataEnums.CardType.UNIT
	brawler.weapon_class = W.SHOTGUN
	brawler.cost = 2
	brawler.firepower = 2
	brawler.armor = 3
	_save(brawler)
	_save(_tactic("smoke_screen", "Smoke Screen", 1, "Your units in a zone can't be targeted by Pick or Flank this round.",
			[_fx(T.ON_PLAY, K.UNTARGETABLE_BY_PICK_FLANK, TG.ALL_FRIENDLIES, Z.CHOSEN_ZONE, 0, 1)], TACTIC))
	_save(_tactic("blackout", "Blackout", 1, "Enemy units in a zone lose First Shot this round.",
			[_fx(T.ON_PLAY, K.REMOVE_FIRST_SHOT, TG.ALL_ENEMIES, Z.CHOSEN_ZONE, 0, 1)], TACTIC))
	_save(_tactic("sabotage", "Sabotage", 2, "Destroy an enemy Field in a zone; 1 damage to each enemy unit there.",
			[_fx(T.ON_PLAY, K.DESTROY_EQUIPMENT, TG.ENEMY_EQUIPMENT, Z.CHOSEN_ZONE, 1, 0),
			 _fx(T.ON_PLAY, K.DAMAGE, TG.ALL_ENEMIES, Z.CHOSEN_ZONE, 1, 0)], TACTIC))
	quit()


func _fx(trigger: int, kind: int, target: int, scope: int, amount: int, duration: int) -> EffectData:
	var e := EffectData.new()
	e.trigger = trigger
	e.kind = kind
	e.target = target
	e.zone_scope = scope
	e.amount = amount
	e.duration_rounds = duration
	return e


func _tactic(id: String, name: String, cost: int, text: String, effects: Array, type: int) -> CardData:
	var c := CardData.new()
	c.id = StringName(id)
	c.display_name = name
	c.card_type = type
	c.cost = cost
	c.text = text
	var arr: Array[EffectData] = []
	arr.assign(effects)
	c.effects = arr
	return c


func _save(c: CardData) -> void:
	var path: String = "res://data/cards/%s.tres" % c.id
	if FileAccess.file_exists(path):
		print("keep ", path)
		return
	var err: Error = ResourceSaver.save(c, path)
	print("wrote " if err == OK else "FAILED ", path)
