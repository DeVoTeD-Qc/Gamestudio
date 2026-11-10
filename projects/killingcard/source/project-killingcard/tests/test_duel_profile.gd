# test_duel_profile.gd
# Purpose: kc-duel-impl: Duel decks and records in the run profile (v2): save / load / 8 slots, the
#   v1 -> v2 migration (found cards back-filled), found_cards from campaign runs (D3), records and
#   cosmetics only, and the DuelState deck CRUD.
# Author: Mechanics Developer Agent (kc-duel-impl)
extends "res://tests/test_case.gd"


func _cfg() -> DuelConfig:
	return load("res://data/duel/duel_config.tres") as DuelConfig


func _settings() -> Node:
	return tree.root.get_node("Settings")


func _duel() -> Node:
	return tree.root.get_node("DuelState")


func test_profile_v2_blank_and_v1_migration() -> void:
	var b: Dictionary = RunProfile.blank()
	assert_eq(b["version"], 2, "profile v2")
	assert_eq(b["duel_decks"], [], "no decks")
	assert_eq(b["found_cards"], [], "nothing found")
	var v1: Dictionary = {"runs_finished": 3, "run_wins": 1, "boss_wins": {"meridian": 1}, "operator_wins": ["kestrel_ar7"]}
	assert_eq(RunProfile.version_of(v1), 1, "unversioned = v1")
	assert_true(RunProfile.needs_migration(v1), "needs migration")
	var m: Dictionary = RunProfile.normalised(v1)
	assert_eq(m["version"], 2, "migrated to v2")
	assert_eq(m["runs_finished"], 3, "old values kept")
	assert_eq(m["boss_wins"], {"meridian": 1}, "old values kept")
	assert_false(RunProfile.needs_migration(m), "done")
	assert_false(RunProfile.needs_migration({}), "an empty profile is just new")
	var ids: Array[String] = DuelCollection.backfill_ids({"mortar_pit~night": true, "okafor_anvil~honors": true}, [&"rifleman"])
	assert_true("mortar_pit" in ids and "okafor_anvil" in ids and "rifleman" in ids, "back-fill from arts and the run deck: %s" % str(ids))


func test_runstate_migrates_and_records_found_cards() -> void:
	var st: Node = _settings()
	var rs: Node = tree.root.get_node("RunState")
	var saved: Dictionary = {"profile": st.run_profile, "arts": st.found_arts}
	st.run_profile = {"runs_finished": 1}
	st.found_arts = {"war_standard~flip": true}
	var p: Dictionary = rs.profile()
	assert_eq(p["version"], 2, "migrated on read")
	assert_true("war_standard" in p["found_cards"], "back-filled from found arts")
	assert_eq(int(st.run_profile.get("version", 0)), 2, "saved once")
	assert_true(DuelCollection.is_unlocked(load("res://data/cards/war_standard.tres"), rs.profile()), "unlocked for Duel")
	assert_false(DuelCollection.is_unlocked(load("res://data/cards/mortar_pit.tres"), rs.profile()), "not met yet")
	st.run_profile = saved["profile"]
	st.found_arts = saved["arts"]


func test_save_load_slots_and_round_trip() -> void:
	var p: Dictionary = RunProfile.blank()
	var d: DuelDeck = _cfg().preset(&"hollow_ranks").copy()
	d.display_name = ""
	d.set_doctrine(&"undead")
	var r: Dictionary = DuelProfile.save(p, d)
	assert_true(r["ok"], "saved")
	assert_eq(r["id"], &"deck_1", "first id")
	p = r["profile"]
	var back: DuelDeck = DuelProfile.find(p, &"deck_1")
	assert_eq(back.display_name, "Undead · Wasp-9", "default name <main trait> · <hero>")
	assert_eq(back.pick_count(), 10, "10 picks")
	assert_eq(back.doctrine_trait, &"undead", "doctrine kept")
	assert_eq(back.art_id_at(0), &"rifleman~horde", "art kept")
	assert_eq(back.trait_of_pick(0), &"undead", "trait from the art")
	assert_false(back.preset, "a saved deck is editable")
	# Survives a JSON round trip (Settings / ConfigFile store plain values).
	var j: Variant = JSON.parse_string(JSON.stringify(p))
	assert_eq(DuelProfile.find(j, &"deck_1").to_dict()["picks"], back.to_dict()["picks"], "JSON round trip")
	# Update in place.
	back.rename("Renamed")
	r = DuelProfile.save(p, back)
	assert_eq(r["id"], &"deck_1", "same slot")
	assert_eq(DuelProfile.decks(r["profile"]).size(), 1, "still one deck")
	# 8 slots.
	p = r["profile"]
	for i: int in 7:
		p = DuelProfile.save(p, DuelDeck.new())["profile"]
	assert_eq(DuelProfile.decks(p).size(), 8, "8 decks")
	r = DuelProfile.save(p, DuelDeck.new())
	assert_false(r["ok"], "no 9th deck")
	assert_eq(r["reason"], "8 decks saved: delete one first", "reason")
	assert_false(DuelProfile.save(p, _cfg().preset(&"spearhead"))["ok"], "presets can't be saved over")
	p = DuelProfile.delete(p, &"deck_3")["profile"]
	assert_eq(DuelProfile.save(p, DuelDeck.new())["id"], &"deck_3", "a freed id is reused")


func test_load_is_tolerant() -> void:
	var d: DuelDeck = DuelDeck.from_dict({"id": "deck_9", "name": "x", "hero_id": "kestrel_ar7", "doctrine_trait": "pirates",
			"picks": [{"card_id": "rifleman", "art_id": "marksman~mastery"}, {"card_id": "gone_card", "art_id": ""}, "junk"]})
	assert_eq(d.pick_count(), 2, "junk rows dropped")
	assert_eq(d.art_id_at(0), &"", "a foreign art falls back to the default")
	assert_eq(d.doctrine_trait, &"", "unknown Doctrine dropped")
	var r: Dictionary = DuelRules.validate(d, _cfg())
	assert_eq(r["status"], "NEEDS ATTENTION", "an unknown card needs attention")
	assert_true(r["errors"].any(func(l: Dictionary) -> bool: return l["code"] == &"unknown_card"), "red unknown card")
	assert_eq(DuelDeck.from_dict(null).pick_count(), 0, "garbage = empty deck")


func test_records_and_cosmetics_only() -> void:
	var p: Dictionary = RunProfile.blank()
	var res: Dictionary = {"kind": &"ai", "tier": &"veteran", "winner_side": 0, "heroes": [&"wasp_9", &"bastion_60"],
			"decks": [&"deck_1", &"iron_wall"]}
	var presets: Array = ["spearhead", "overwatch", "iron_wall", "hollow_ranks"]
	var r: Dictionary = DuelProfile.record(p, res, presets)
	assert_eq(r["records"]["heroes"]["wasp_9"]["w"], 1, "hero win")
	assert_eq(r["records"]["vs_ai"]["iron_wall"]["veteran"]["w"], 1, "preset x tier win")
	var kinds: Array = r["new_cosmetics"].map(func(c: Dictionary) -> StringName: return c["kind"])
	assert_eq(kinds, [&"duelist_frame", &"veteran_stamp"], "frame + stamp")
	p = r["profile"]
	assert_eq(p["runs_finished"], 0, "no campaign progress")
	assert_eq(p["found_cards"], [], "never a card")
	r = DuelProfile.record(p, res, presets)
	assert_true(r["new_cosmetics"].is_empty(), "cosmetics once")
	for opp: String in ["spearhead", "overwatch", "hollow_ranks"]:
		var rr: Dictionary = res.duplicate()
		rr["decks"] = [&"deck_1", StringName(opp)]
		r = DuelProfile.record(r["profile"], rr, presets)
	assert_eq(r["new_cosmetics"].back()["kind"], &"veteran_all", "every preset on Veteran")
	var loss: Dictionary = res.duplicate()
	loss["winner_side"] = 1
	loss["tier"] = &"recruit"
	r = DuelProfile.record(r["profile"], loss, presets)
	assert_eq(r["records"]["vs_ai"]["iron_wall"]["recruit"]["l"], 1, "loss")
	var hs: Dictionary = {"kind": &"hot_seat", "winner_side": 0, "heroes": [&"kestrel_ar7", &"wasp_9"], "decks": [&"a", &"b"]}
	r = DuelProfile.record(r["profile"], hs, presets)
	assert_eq(r["records"]["hot_seat_games"], 1, "hot seat counted")
	assert_true(r["new_cosmetics"].is_empty(), "no cosmetics from hot seat")


func test_duel_state_crud() -> void:
	var st: Node = _settings()
	var ds: Node = _duel()
	var saved: Variant = st.run_profile
	st.run_profile = RunProfile.blank()
	assert_eq(ds.slots_left(), 8, "8 free slots")
	assert_eq(ds.presets().size(), 4, "4 presets")
	assert_eq(ds.heroes().size(), 4, "4 heroes")
	assert_true(ds.heroes().all(func(h: Dictionary) -> bool: return h["unlocked"]), "D3: every hero playable")
	var pool: Array = ds.card_pool()
	assert_eq(pool.size(), 30, "pool rows")
	var mp: Dictionary = pool.filter(func(r: Dictionary) -> bool: return r["id"] == &"mortar_pit")[0]
	assert_true(mp["locked"], "Fields locked on a new profile")
	assert_eq(mp["unlock_text"], "Find it in the campaign", "unlock line")
	assert_true(&"iron_wall" in mp["in_presets"], "in Iron Wall")
	assert_eq(ds.card_pool({"include_locked": false}).size(), 20, "20 open chassis")
	var r: Dictionary = ds.copy_deck(&"iron_wall")
	assert_true(r["ok"], "copied")
	assert_eq(ds.decks()[0]["name"], "Iron Wall copy", "copy name")
	assert_eq(ds.decks()[0]["status"], "NEEDS ATTENTION", "locked Mortar Pit and Anvil")
	var d: DuelDeck = ds.deck(r["id"])
	d.remove_pick(&"mortar_pit")
	d.remove_pick(&"okafor_anvil")
	assert_eq(ds.save_deck(d)["ok"], true, "resaved")
	assert_eq(ds.decks()[0]["status"], "2 PICKS TO GO", "only picks missing now")
	assert_true(ds.delete_deck(r["id"]), "deleted")
	assert_eq(ds.slots_left(), 8, "slot freed")
	st.run_profile = saved
