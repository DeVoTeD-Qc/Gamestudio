# test_cipher_lock.gd
# Purpose: The album's 4-dial Cipher Lock (cc11; spec 5, content cc03 follow-up: code 4-3-1-2,
#   glyphs Graveyard Shift 1, Mayday 2, Brass Tacks 3, Frostbite 4, the Cipher set's riddle is the
#   order hint). Checks: the dials start on neither the answer nor 1-2-3-4; a wrong code does not
#   unlock Key Fragment; the right code (dialled with the dial controls) does; Collection is the
#   only one emitting cipher_attempted / cipher_solved; the solved state survives a reload; the
#   riddle, the glyph cards and balance.cipher_code agree.
# Author: UI/UX Agent (cc11)
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_album_fixtures.gd")
const CipherLock: GDScript = preload("res://scripts/ui/cipher_lock.gd")
const KEY: StringName = &"key_fragment"


func test_initial_dials_are_never_the_answer_or_ascending() -> void:
	var ans: PackedInt32Array = CardDB.get_balance().cipher_code
	assert_eq(Array(ans), [4, 3, 1, 2], "content: the code is 4-3-1-2")
	var start: Array[int] = CipherLock.initial_code(ans, 4)
	assert_ne_code(start, [4, 3, 1, 2], "start is not the answer")
	assert_ne_code(start, [1, 2, 3, 4], "start is not 1-2-3-4")
	# Whatever the data says, the start avoids it and the ascending order.
	for a: Array in [[1, 1, 1, 1], [1, 2, 3, 4], [2, 2, 2, 2], [2, 1, 4, 3]]:
		var s: Array[int] = CipherLock.initial_code(PackedInt32Array(a), 4)
		assert_ne_code(s, a, "start avoids answer %s" % [a])
		assert_ne_code(s, [1, 2, 3, 4], "start avoids 1-2-3-4 (answer %s)" % [a])
	var fx: RefCounted = Fx.new(tree)
	var setup: Array = await fx.spawn(Fx.PHONE, fx.make_collection("cipher_start"), &"cipher_lock")
	var lock: PanelContainer = setup[1].get_cipher_lock()
	assert_eq(lock.get_dials().size(), 4, "4 dials")
	assert_ne_code(lock.current_code(), [4, 3, 1, 2], "scene dials do not start on the answer")
	assert_ne_code(lock.current_code(), [1, 2, 3, 4], "scene dials do not start on 1-2-3-4")
	fx.finish()


func test_wrong_code_does_not_unlock_key_fragment() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("cipher_wrong")
	var setup: Array = await fx.spawn(Fx.PHONE_NOTCH, coll, &"cipher_lock")
	var album: Control = setup[1]
	var lock: PanelContainer = album.get_cipher_lock()
	var bus: Array = _record_bus()
	for code: Array in [[1, 2, 3, 4], [2, 1, 4, 3], [4, 3, 2, 1]]:
		lock.set_code(code)
		assert_eq(Array(lock.current_code()), code, "dials set to %s" % [code])
		lock.get_try_button().pressed.emit()
		await fx.settle(1)
		assert_false(coll.owns(KEY), "%s does not unlock Key Fragment" % [code])
		assert_false(coll.is_cipher_solved(), "%s does not solve the lock" % [code])
	assert_eq(coll.cipher_attempts(), 3, "3 attempts counted")
	assert_true(lock.get_feedback().text.begins_with("The lock holds") and lock.get_feedback().text.contains("Attempt 3"), "wrong feedback: %s" % lock.get_feedback().text)
	assert_false(lock.is_solved_view(), "TRY CODE still offered")
	assert_eq(_count(bus, "cipher_attempted"), 3, "cipher_attempted once per try (Collection only)")
	assert_eq(_count(bus, "cipher_solved"), 0, "not solved")
	assert_eq(_count(bus, "card_unlocked"), 0, "nothing unlocked")
	await fx.settle(2)
	album.show_page(&"cipher")
	await fx.settle(2)
	assert_false(album.get_page().get_hanger(KEY).owned, "Key Fragment still a silhouette")
	_stop(bus)
	fx.finish()


func test_right_code_unlocks_key_fragment() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("cipher_right")
	var setup: Array = await fx.spawn(Fx.PHONE, coll, &"cipher")
	var album: Control = setup[1]
	# The Cipher page links to the lock and shows Key Fragment's goal.
	var page: Control = album.get_page()
	var key_hanger: Node = page.get_hanger(KEY)
	assert_eq(key_hanger.goal_text, "Unlock: Solve the Cipher Lock", "Key Fragment silhouette names the lock")
	(page.find_child("CipherLockButton", true, false) as Button).pressed.emit()
	await fx.settle(2)
	assert_eq(album.current_page, &"cipher_lock", "CIPHER LOCK button opens the lock")
	var lock: PanelContainer = album.get_cipher_lock()
	var bus: Array = _record_bus()
	# Dial 4-3-1-2 with the controls: from 1-1-1-1, dial I down once (wraps to 4), dial II up twice,
	# dial III untouched, dial IV face tapped once.
	var dials: Array = lock.get_dials()
	dials[0].get_down().pressed.emit()
	dials[1].get_up().pressed.emit()
	dials[1].get_up().pressed.emit()
	dials[3].get_face().pressed.emit()
	assert_eq(lock.current_code(), [4, 3, 1, 2] as Array[int], "dialled 4-3-1-2")
	lock.get_try_button().pressed.emit()
	await fx.settle(3)
	assert_true(coll.owns(KEY), "Key Fragment unlocked")
	assert_true(coll.is_cipher_solved(), "lock solved")
	assert_eq(_count(bus, "cipher_attempted"), 1, "one cipher_attempted (from Collection)")
	assert_eq(_count(bus, "cipher_solved"), 1, "one cipher_solved (from Collection)")
	assert_true(bus.has(["card_unlocked", KEY]), "card_unlocked(key_fragment)")
	assert_true(lock.is_solved_view(), "TRY CODE gone")
	assert_true(lock.get_feedback().text.contains("Key Fragment is yours"), "feedback: %s" % lock.get_feedback().text)
	var reward: BannerCard = lock.get_reward_card()
	assert_not_null(reward, "reward card shown")
	assert_eq(reward.card_id, KEY, "reward is Key Fragment")
	assert_false(reward.locked, "reward card in colour")
	for d: Node in dials:
		assert_true(d.locked, "dial %d locked open" % d.dial_index)
	assert_eq(album.get_toast_text(), "New card: Key Fragment", "toast")
	assert_eq(album.get_tab(&"cipher_lock").text, "Cipher Lock (open)", "tab says open")
	assert_eq((album.get_node("%CardCount") as Label).text, "14 / 20", "count updated")
	# Trying again changes nothing.
	lock.get_try_button().pressed.emit()
	assert_eq(coll.cipher_attempts(), 1, "no attempt after solving")
	album.show_page(&"cipher")
	await fx.settle(2)
	var h: Node = album.get_page().get_hanger(KEY)
	assert_true(h.owned and not h.get_card_view().locked, "Key Fragment owned on the Cipher page")
	assert_eq(h.info_text, "Clearance 3 · Distinction · Cipher", "Key Fragment line")
	_stop(bus)
	# Reload: a new album on the same collection shows the open lock on the code.
	var setup2: Array = await fx.spawn(Fx.DESKTOP, coll, &"cipher_lock")
	var lock2: PanelContainer = setup2[1].get_cipher_lock()
	assert_true(lock2.is_solved_view(), "solved state after reopening")
	assert_eq(lock2.current_code(), [4, 3, 1, 2] as Array[int], "dials rest on the code")
	assert_true(lock2.get_feedback().text.contains("Opened in 1 try"), "solved feedback: %s" % lock2.get_feedback().text)
	fx.finish()


func test_dial_controls() -> void:
	var fx: RefCounted = Fx.new(tree)
	var setup: Array = await fx.spawn(Fx.PHONE_SMALL, fx.make_collection("cipher_dials"), &"cipher_lock")
	var lock: PanelContainer = setup[1].get_cipher_lock()
	var d: Node = lock.get_dials()[2]
	d.set_value(4, false)
	d.get_up().pressed.emit()
	assert_eq(d.value, 1, "up wraps 4 -> 1")
	d.get_down().pressed.emit()
	assert_eq(d.value, 4, "down wraps 1 -> 4")
	d.get_face().pressed.emit()
	assert_eq(d.value, 1, "tap on the face turns to the next glyph")
	var ev := InputEventAction.new()
	ev.action = &"ui_up"
	ev.pressed = true
	d.get_face().gui_input.emit(ev)
	assert_eq(d.value, 2, "arrow key up on a focused dial")
	ev.action = &"ui_down"
	d.get_face().gui_input.emit(ev)
	assert_eq(d.value, 1, "arrow key down")
	# Glyphs are distinct shapes (never told apart by colour), drawn from ArtIcons.
	var seen: Dictionary = {}
	for g: int in range(1, 5):
		var tex: Texture2D = ArtIcons.cipher_glyph(g, 96.0)
		assert_not_null(tex, "glyph %d texture" % g)
		seen[hash(tex.get_image().get_data())] = true
	assert_eq(seen.size(), 4, "four different glyph shapes")
	# Dial faces show the glyph only: no number on the face.
	for dial: Node in lock.get_dials():
		assert_eq(dial.get_face().text, "", "dial face has no number")
	fx.finish()


func test_riddle_glyphs_and_code_agree() -> void:
	var riddle: String = CipherLock.riddle_text()
	assert_eq(riddle, "Cold comes first, then the old guard. Night falls third; the signal fires last.", "riddle is the Cipher set tagline")
	# Riddle order -> set -> the glyph hidden in that set's card -> the code.
	var order: Array[StringName] = [&"whiteout", &"old_guard", &"night_shift", &"signal_fire"]
	var code: Array = []
	for set_id: StringName in order:
		var glyph: int = 0
		for c: CardData in CardDB.cards_in_set(set_id):
			if c.cipher_glyph > 0:
				assert_eq(glyph, 0, "%s hides exactly one glyph" % set_id)
				glyph = c.cipher_glyph
		code.append(glyph)
	assert_eq(code, Array(CardDB.get_balance().cipher_code), "riddle order gives balance.cipher_code")
	var glyph_cards: Dictionary = {}
	for c: CardData in CardDB.all_cards():
		if c.cipher_glyph > 0:
			glyph_cards[c.id] = c.cipher_glyph
	assert_eq(glyph_cards, {&"graveyard_shift": 1, &"frostbite": 4, &"mayday": 2, &"brass_tacks": 3}, "glyphs per content cc03")
	var rewards: Array = []
	for c: CardData in CipherLock.reward_cards():
		rewards.append(c.id)
	assert_eq(rewards, [KEY], "the lock unlocks Key Fragment")


func test_reduced_motion_wrong_code_has_no_shake() -> void:
	var fx: RefCounted = Fx.new(tree)
	var coll: Node = fx.make_collection("cipher_motion")
	var setup: Array = await fx.spawn(Fx.DESKTOP, coll, &"cipher_lock")
	var lock: PanelContainer = setup[1].get_cipher_lock()
	var was: bool = Settings.reduced_motion
	Settings.reduced_motion = true
	lock.set_code([1, 1, 1, 1])
	lock.get_try_button().pressed.emit()
	await fx.settle(2)
	for d: Node in lock.get_dials():
		assert_eq(d.get_face().position.x, 0.0, "no shake with reduced motion")
	Settings.reduced_motion = was
	fx.finish()


# --- Helpers -------------------------------------------------------------------------------

func assert_ne_code(a: Array, b: Array, message: String) -> void:
	assert_true(Array(a) != Array(b), "%s (%s)" % [message, a])


func _record_bus() -> Array:
	var log: Array = []
	var conns: Array = []
	for sig: String in ["cipher_attempted", "cipher_solved", "card_unlocked"]:
		var cb: Callable = func(a: Variant = null, b: Variant = null) -> void:
			var e: Array = [sig]
			if a != null:
				e.append(a)
			log.append(e)
		EventBus.connect(sig, cb)
		conns.append([sig, cb])
	log.append(["__conns", conns])
	return log


func _stop(log: Array) -> void:
	for e: Array in log:
		if e[0] == "__conns":
			for c: Array in e[1]:
				EventBus.disconnect(c[0], c[1])


func _count(log: Array, sig: String) -> int:
	var n: int = 0
	for e: Array in log:
		if e[0] == sig:
			n += 1
	return n
