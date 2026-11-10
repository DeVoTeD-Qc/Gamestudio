# test_mw3_cards.gd
# Purpose: kc-mw3-cards (head): in the private pitch build the Standard Issue starters (si_* arts) wear
#   their licensed calling card ahead of the public drop-ins, and pitch-manifest rows for card ids that
#   do not exist yet (the head's Wip set, kc_wip_<name>) are picked up as soon as such a card appears.
#   Without licensed art (public build, clean checkout) the starters keep their original art.
#   Uses a scratch folder with generated images: no licensed art is read by the tests.
# Author: Technical Artist Agent (kc-mw3-cards)
extends "res://tests/test_case.gd"

const DIR: String = "user://kc_mw3_cards_test/"


func _card(id: String) -> CardData:
	return load("res://data/cards/%s.tres" % id) as CardData


func _make_folder() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var colors: Dictionary = {"g": Color.OLIVE, "a": Color.ORANGE, "p": Color.GOLD}
	for key: String in colors:
		var img: Image = Image.create(64, 16, false, Image.FORMAT_RGB8)
		img.fill(colors[key])
		img.save_png(DIR + key + ".png")
	var f: FileAccess = FileAccess.open(DIR + "manifest.csv", FileAccess.WRITE)
	f.store_line("file,kind,card,title,id,animated,frames_file,frames,frame_ms,mastery_family,tier_rank,family,trait")
	f.store_line("g.png,unit,si_grunt,Grunt Card,kc_t_si_grunt,no,,,,,,operators,")
	f.store_line("a.png,tactic,si_ammo_resupply,Crate Card,kc_t_si_ammo,no,,,,,,honors,")
	f.store_line("p.png,unit,kc_wip_private_1,Private Card,kc_t_wip_p1,no,,,,,,mastery,")
	f.close()


func _drop_folder() -> void:
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + file)
	DirAccess.remove_absolute(DIR)


func _restore(saved_dir: String, saved_on: bool) -> void:
	BannerArtDB.licensed_dir = saved_dir
	BannerArtDB.licensed_enabled = saved_on
	BannerArtDB.clear_cache()
	ArtTraits.clear_cache()


func test_starters_wear_licensed_art_in_pitch_build_only() -> void:
	var saved_dir: String = BannerArtDB.licensed_dir
	var saved_on: bool = BannerArtDB.licensed_enabled
	_make_folder()
	BannerArtDB.licensed_dir = DIR
	BannerArtDB.licensed_enabled = true
	BannerArtDB.clear_cache()
	ArtTraits.clear_cache()
	var grunt: CardData = _card("si_grunt")
	var ammo: CardData = _card("ammo_resupply")
	assert_eq(ArtTraits.starter_art(grunt), &"si_grunt", "a starter still wears its Standard Issue art id")
	assert_eq(ArtTraits.starter_art(ammo), &"si_ammo_resupply", "the starter tactic too")
	var art: BannerArt = BannerArtDB.get_art(&"si_grunt")
	assert_true(art.licensed and not art.placeholder, "pitch build: the Grunt wears its calling card, not the drop-in")
	assert_eq(art.title, "Grunt Card", "the calling card's title")
	assert_eq(BannerArtDB.art_title(&"si_grunt"), "Grunt Card", "the title shows as the card name")
	assert_true(BannerArtDB.get_art(&"si_ammo_resupply").licensed, "the starter Ammo Resupply wears its calling card")
	assert_true(not BannerArtDB.get_art(&"si_trooper").licensed, "a starter without a row keeps its own art")
	assert_eq(BannerArtDB.banner_texture(&"si_grunt").get_size(), Vector2(64, 16), "4:1 band of the licensed image")
	assert_true(ArtTraits.is_standard_issue_art(&"si_grunt", grunt), "still a Standard Issue art (serial, no trait)")
	assert_eq(ArtTraits.trait_of(&"si_grunt", grunt), &"", "a starter never gets a trait from its art")
	# Public build (licensed art off): the original Standard Issue art, never a licensed path.
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	ArtTraits.clear_cache()
	var pub: BannerArt = BannerArtDB.get_art(&"si_grunt")
	assert_true(not pub.licensed, "public build: the Grunt keeps its original art")
	assert_true(not pub.image_path.contains("licensed"), "public build: no licensed path")
	assert_eq(BannerArtDB.art_title(&"si_grunt"), "", "public build: the card keeps its own name")
	_restore(saved_dir, saved_on)
	_drop_folder()


func test_wip_rows_apply_once_the_card_exists() -> void:
	var saved_dir: String = BannerArtDB.licensed_dir
	var saved_on: bool = BannerArtDB.licensed_enabled
	_make_folder()
	BannerArtDB.licensed_dir = DIR
	BannerArtDB.licensed_enabled = true
	BannerArtDB.clear_cache()
	ArtTraits.clear_cache()
	assert_eq(BannerArtDB.licensed_pool(&"kc_wip_private_1"), [&"kc_t_wip_p1"] as Array[StringName], "row waits under the proposed id")
	var card := CardData.new()  # what the mechanics developer will add (data/cards/kc_wip_private_1.tres)
	card.id = &"kc_wip_private_1"
	card.display_name = "Private I"
	assert_true(&"kc_t_wip_p1" in ArtTraits.arts_for(card), "the new card lists its calling card")
	assert_eq(ArtTraits.default_art(card, card.card_trait), &"kc_t_wip_p1", "and wears it by default")
	assert_true(BannerArtDB.get_art(&"kc_wip_private_1").licensed, "its own id renders the calling card")
	BannerArtDB.licensed_enabled = false
	BannerArtDB.clear_cache()
	ArtTraits.clear_cache()
	assert_eq(ArtTraits.arts_for(card)[0], &"kc_wip_private_1", "public build: its own placeholder art")
	assert_true(not BannerArtDB.get_art(&"kc_wip_private_1").licensed, "public build: never licensed")
	_restore(saved_dir, saved_on)
	_drop_folder()
