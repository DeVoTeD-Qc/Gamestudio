# test_lineup_flow.gd
# Purpose: Flow checks for the lineup builder (cc10, scenes/LineupBuilder.tscn). Every action is
#   driven by ONE real tap (press + release through the viewport) and the test checks the state
#   changed after exactly that tap:
#   - a valid save (Collection.save_lineup, EventBus.lineup_saved emitted once, by Collection),
#   - each invalid reason shown in plain words (every LineupRules code; never a code name or the
#     rules' developer message), the live Clearance meter and Legend counter,
#   - the Signature toggle (mark, move, unmark; ribbon on the card),
#   - the loaner lineup offered only when the collection can't make a legal lineup,
#   - DUEL hands the lineup to DuelController.set_next_duel and routes to Duel.tscn,
#   - hold inspects without picking; locked cards explain how to earn them.
# Author: UI/UX Agent (cc10)
extends "res://tests/test_case.gd"

const Fx: GDScript = preload("res://tests/test_lineup_fixtures.gd")
const LineupMessages: GDScript = preload("res://scripts/ui/lineup_messages.gd")
const DuelControllerScript: GDScript = preload("res://scripts/duel/duel_controller.gd")

## Words the player must never see (raw codes and the rules' developer-facing messages).
const FORBIDDEN: Array[String] = ["SIZE", "EMPTY_SLOT", "DUPLICATE", "CLEARANCE_CAP", "LEGEND_LIMIT",
		"SIGNATURE_COUNT", "SIGNATURE_NOT_IN_LINEUP", "SIGNATURE_INELIGIBLE", "NOT_OWNED",
		"Total Clearance is", "Legends; at most", "marked).", "&\""]


func test_valid_save_one_tap_per_action() -> void:
	var f: RefCounted = Fx.new(tree)
	var b: Control = await f.spawn(Fx.PHONE_NOTCH, "lineup_valid")
	var saved_events: Array = []
	var on_saved: Callable = func(ids: Array, clearance: int, sig: StringName, loaner: bool) -> void:
		saved_events.append([ids, clearance, sig, loaner])
	EventBus.lineup_saved.connect(on_saved)
	assert_eq(b.get_headline_text(), "PICK 5 CARDS", "empty lineup headline")
	assert_true((b.get_node("%SaveButton") as Button).disabled, "SAVE off while empty")
	var expected_clearance: Array[int] = [1, 4, 6, 8, 10]
	for i: int in Fx.VALID_IDS.size():
		var before: int = f.taps
		await f.tap_card(Fx.VALID_IDS[i])
		assert_eq(f.taps - before, 1, "one tap adds %s" % Fx.VALID_IDS[i])
		assert_eq(b.get_lineup_ids().size(), i + 1, "tap %d added a card" % (i + 1))
		assert_eq(b.get_clearance(), expected_clearance[i], "live Clearance after %d cards" % (i + 1))
		assert_eq((b.get_node("%ClearanceValue") as Label).text, "%d/12" % expected_clearance[i], "meter text")
		assert_eq(int(b.get_meter().value), expected_clearance[i], "meter value")
	assert_eq(b.get_lineup_ids(), f.ids(Fx.VALID_IDS), "lineup in tap order")
	assert_eq(b.get_signature_id(), &"chrome_tiger", "first card is the Signature until moved")
	await f.tap_signature(1)
	assert_eq(b.get_signature_id(), &"snow_blind", "one tap moves the Signature")
	assert_true(b.get_result()["valid"], "lineup is legal")
	assert_eq(b.get_headline_text(), "READY TO DUEL", "ready headline")
	assert_true(b.get_reasons_text().contains("Signature: Snow Blind"), "summary names the Signature")
	assert_false((b.get_node("%SaveButton") as Button).disabled, "SAVE on")
	assert_false((b.get_node("%DuelButton") as Button).disabled, "DUEL on")
	await f.tap_named("%SaveButton")
	assert_true(f.collection.has_saved_lineup(), "one tap on SAVE saves")
	var saved: Dictionary = f.collection.get_saved_lineup_ids()
	assert_eq(saved["cards"], f.ids(Fx.VALID_IDS), "saved cards")
	assert_eq(saved["signature"], &"snow_blind", "saved Signature")
	assert_false(saved["loaner"], "not a loaner lineup")
	assert_eq(saved_events.size(), 1, "lineup_saved emitted exactly once (by Collection)")
	if saved_events.size() == 1:
		assert_eq(saved_events[0][1], 10, "saved Clearance")
	assert_eq(b.get_headline_text(), "SAVED · READY TO DUEL", "saved headline")
	assert_eq(b.get_notice_text(), "Lineup saved.", "saved notice")
	EventBus.lineup_saved.disconnect(on_saved)
	f.finish()


func test_each_invalid_reason_in_words() -> void:
	var f: RefCounted = Fx.new(tree)
	# Extra cards: two Clearance 3 and both Legends, so the cap and Legend limit can be reached by taps.
	var owned: Array = []
	for c: CardData in CardDB.starting_cards():
		owned.append(c.id)
	owned.append_array([&"dead_air", &"honor_roll", &"long_watch", &"city_never_sleeps"])
	var b: Control = await f.spawn(Fx.PHONE_SE, "lineup_invalid", owned)
	# SIZE: three cards.
	for id: StringName in [&"chrome_tiger", &"flare_up", &"frostbite"]:
		await f.tap_card(id)
	_expect(b, LineupRules.SIZE, "Pick 2 more cards: a lineup has exactly 5.")
	assert_eq(b.get_headline_text(), "NOT READY · 1 THING TO FIX", "headline counts the reasons")
	assert_true((b.get_node("%SaveButton") as Button).disabled and (b.get_node("%DuelButton") as Button).disabled,
			"SAVE and DUEL off while invalid")
	# LEGEND_LIMIT: both Legends (Clearance 4+4+1+1+1 = 11, under the cap).
	await f.tap_card(&"long_watch")
	await f.tap_card(&"city_never_sleeps")
	_expect(b, LineupRules.LEGEND_LIMIT, "Only one Legend fits in a lineup")
	assert_true(b.get_reasons_text().contains("Long Watch") and b.get_reasons_text().contains("City Never Sleeps"),
			"Legend reason names both cards")
	assert_eq(b.get_result()["errors"].size(), 1, "only the Legend limit (%s)" % [b.get_result()["errors"]])
	assert_eq((b.get_node("%LegendLabel") as Label).text, "LEGENDS 2/1", "Legend counter")
	# A 6th card is refused with words, nothing changes.
	await f.tap_card(&"gold_leaf")
	assert_eq(b.get_lineup_ids().size(), 5, "6th card refused")
	assert_true(b.get_notice_text().begins_with("Your lineup is full (5 cards). Tap a card in your lineup"), "full notice: %s" % b.get_notice_text())
	# CLEARANCE_CAP: swap to 3+3+3+3+2 = 14 (one tap per change).
	await f.tap_named("%ClearButton")
	for id: StringName in [&"brass_tacks", &"snow_blind", &"dead_air", &"honor_roll", &"glacier"]:
		await f.tap_card(id)
	_expect(b, LineupRules.CLEARANCE_CAP, "Clearance is 14 of 12: 2 too high. Swap a card for one with lower Clearance.")
	assert_eq((b.get_node("%ClearanceValue") as Label).text, "14/12", "meter shows the real total")
	assert_eq((b.get_node("%MeterTitle") as Label).text, "CLEARANCE OVER", "meter says OVER (not colour alone)")
	assert_eq(int(b.get_meter().value), 12, "bar full")
	assert_true(b.get_meter().has_theme_stylebox_override(&"fill"), "over-cap fill")
	# SIGNATURE_COUNT: unmark the only Signature with one tap.
	await f.tap_row(4)  # take Glacier out
	await f.tap_card(&"chrome_tiger")  # 3+3+3+3+1 = 13, still over
	await f.tap_row(4)
	await f.tap_card(&"last_train")
	await f.tap_row(3)
	await f.tap_card(&"flare_up")  # brass 3, snow 3, dead 3, last_train 2, flare 1 = 12
	assert_true(b.get_result()["valid"], "legal again: %s" % [b.get_result()["reasons"]])
	var sig_row: int = b.get_lineup_ids().find(b.get_signature_id())
	await f.tap_signature(sig_row)
	_expect(b, LineupRules.SIGNATURE_COUNT, "No Signature yet. Tap SIGNATURE next to the card you want to count double.")
	# NOT_OWNED / DUPLICATE / SIGNATURE_NOT_IN_LINEUP: lineups only a restore or another screen can
	# produce (taps can't add an unowned card twice); set them directly and read the words.
	b.set_lineup([&"chrome_tiger", &"flare_up", &"frostbite", &"gold_leaf", &"polar_night"], &"chrome_tiger")
	await f.frames()
	_expect(b, LineupRules.NOT_OWNED, "You don't own Polar Night yet, so it can't go in your lineup.")
	b.set_lineup([&"chrome_tiger", &"chrome_tiger", &"frostbite", &"gold_leaf", &"flare_up"], &"frostbite")
	await f.frames()
	_expect(b, LineupRules.DUPLICATE, "Chrome Tiger is in your lineup twice.")
	b.set_lineup([&"chrome_tiger", &"service_ribbon", &"frostbite", &"gold_leaf", &"flare_up"], &"snow_blind")
	await f.frames()
	_expect(b, LineupRules.SIGNATURE_NOT_IN_LINEUP, "Your Signature, Snow Blind, isn't in the lineup.")
	f.finish()


## Every LineupRules code has its own sentence (no code falls through to the generic text), and
## SIGNATURE_INELIGIBLE (no shipped card is ineligible) reads right on a test card.
func test_every_rules_code_has_words() -> void:
	var codes: Array[StringName] = []
	for v: Variant in LineupRules.new().get_script().get_script_constant_map().values():
		if v is StringName:
			codes.append(v)
	assert_true(codes.size() >= 9, "found the rules codes (%d)" % codes.size())
	var generic: String = LineupMessages.describe(&"NO_SUCH_CODE", [], [])
	var cards: Array = []
	for id: StringName in Fx.VALID_IDS:
		cards.append(CardDB.get_card(id))
	for code: StringName in codes:
		assert_true(LineupMessages.ORDER.has(code), "%s is in the builder's reason order" % code)
		var words: String = LineupMessages.describe(code, cards, [cards[0]], [])
		assert_true(words != generic and words.length() > 10, "%s has its own words: %s" % [code, words])
		for bad: String in FORBIDDEN:
			assert_false(words.contains(bad), "%s words contain '%s': %s" % [code, bad, words])
	var odd: CardData = (CardDB.get_card(&"chrome_tiger") as CardData).duplicate()
	odd.signature_eligible = false
	var lineup: Array = [odd, CardDB.get_card(&"flare_up"), CardDB.get_card(&"frostbite"),
			CardDB.get_card(&"gold_leaf"), CardDB.get_card(&"glacier")]
	var r: Dictionary = LineupRules.validate(lineup, [odd], null, CardDB.get_balance())
	assert_eq(r["errors"], [LineupRules.SIGNATURE_INELIGIBLE], "rules flag the ineligible Signature")
	var reasons: PackedStringArray = LineupMessages.reasons(r, lineup, [odd], null, CardDB.get_balance())
	assert_eq(reasons, PackedStringArray(["Chrome Tiger can't be a Signature. Mark another card in your lineup."]), "ineligible words")
	# Two Signatures marked (another screen could pass several).
	r = LineupRules.validate(lineup, [lineup[1], lineup[2]], null, CardDB.get_balance())
	reasons = LineupMessages.reasons(r, lineup, [lineup[1], lineup[2]], null, CardDB.get_balance())
	assert_true(reasons.has("You marked 2 Signatures, but only one card can be your Signature. Unmark the others."), "two Signatures: %s" % [reasons])
	# Too many cards.
	var six: Array = lineup.duplicate()
	six.append(CardDB.get_card(&"mayday"))
	r = LineupRules.validate(six, [six[1]], null, CardDB.get_balance())
	reasons = LineupMessages.reasons(r, six, [six[1]], null, CardDB.get_balance())
	assert_true(reasons.has("Too many cards: a lineup has exactly 5. Take 1 out."), "six cards: %s" % [reasons])


func test_signature_toggle() -> void:
	var f: RefCounted = Fx.new(tree)
	var b: Control = await f.spawn(Fx.PHONE, "lineup_sig")
	var row0: Node = b.get_row(0)
	assert_true(row0.get_signature_toggle().disabled, "SIGNATURE off on an empty slot")
	for id: StringName in Fx.VALID_IDS:
		await f.tap_card(id)
	assert_eq(b.get_signature_id(), &"chrome_tiger", "first card auto-marked")
	assert_true(row0.get_signature_toggle().button_pressed, "row 1 toggle on")
	assert_true(row0.get_card_view().signature, "ribbon on row 1 card")
	assert_true((b.get_collection_button(&"chrome_tiger").get_node("Card") as BannerCard).signature, "ribbon in the grid too")
	# Move it: one tap.
	await f.tap_signature(3)
	assert_eq(b.get_signature_id(), &"neon_rain", "Signature moved with one tap")
	for i: int in 5:
		var on: bool = i == 3
		assert_eq(b.get_row(i).get_signature_toggle().button_pressed, on, "row %d toggle" % (i + 1))
		assert_eq(b.get_row(i).get_card_view().signature, on, "row %d ribbon" % (i + 1))
	assert_eq(b.get_notice_text(), "Neon Rain is your Signature: it counts double.", "mark notice")
	# Unmark: one tap on the same toggle.
	await f.tap_signature(3)
	assert_eq(b.get_signature_id(), &"", "unmarked with one tap")
	assert_false(b.get_row(3).get_signature_toggle().button_pressed, "toggle off")
	assert_false(b.get_result()["valid"], "no Signature: not legal")
	assert_true(b.get_reasons_text().contains("No Signature yet"), "reason in words")
	# Mark again, then take the Signature card out: the reason says to mark another.
	await f.tap_signature(2)
	assert_eq(b.get_signature_id(), &"glacier", "marked again")
	await f.tap_row(2)
	assert_eq(b.get_signature_id(), &"", "removing the Signature card clears the mark")
	assert_true(b.get_notice_text().contains("It was your Signature"), "notice says so")
	assert_true(b.get_row(4).get_signature_toggle().disabled, "row 5 empty after removal: its toggle is off")
	f.finish()


func test_loaner_offered_only_when_needed() -> void:
	var f: RefCounted = Fx.new(tree)
	var b: Control = await f.spawn(Fx.DESKTOP, "lineup_no_loaner")
	assert_false(b.is_loaner_offered(), "starting collection makes a legal lineup: no loaner")
	assert_false((b.get_node("%LoanerRow") as Control).visible, "loaner row hidden")
	f.finish()
	var owned: Array = [&"graveyard_shift", &"chrome_tiger", &"frostbite"]
	var owned_cards: Array = owned.map(func(id: StringName) -> CardData: return CardDB.get_card(id))
	assert_true(LineupRules.should_offer_loaner(owned_cards, CardDB.get_balance()), "3 cards: rules offer the loaner")
	f = Fx.new(tree)
	b = await f.spawn(Fx.PHONE_NOTCH, "lineup_loaner", owned)
	assert_true(b.is_loaner_offered(), "builder offers the loaner")
	var row: Control = b.get_node("%LoanerRow")
	assert_true(row.is_visible_in_tree(), "loaner row shown")
	assert_true((b.get_node("%LoanerText") as Label).text.contains("can't make a legal lineup"), "says why in words")
	await f.tap_named("%LoanerButton")
	var balance: BalanceConfig = CardDB.get_balance()
	var loaner_ids: Array[StringName] = []
	for c: CardData in balance.loaner_lineup:
		loaner_ids.append(c.id)
	assert_eq(b.get_lineup_ids(), loaner_ids, "one tap fills the loaner lineup")
	assert_eq(b.get_signature_id(), balance.loaner_signature.id, "loaner Signature")
	assert_true(b.is_loaner(), "loaner flag")
	assert_true(b.get_result()["valid"], "loaner lineup is legal without owning it: %s" % [b.get_result()["reasons"]])
	assert_eq((b.get_node("%LineupTitle") as Label).text, "LOANER 5/5", "title says LOANER")
	assert_true((b.get_node("%LoanerButton") as Button).disabled, "USE LOANER off while in use")
	await f.tap_named("%SaveButton")
	var saved: Dictionary = f.collection.get_saved_lineup_ids()
	assert_true(saved.get("loaner", false), "saved as a loaner lineup")
	# Editing it makes it the player's own: ownership counts again, said in words.
	await f.tap_row(0)
	assert_false(b.is_loaner(), "edited loaner is the player's own lineup")
	assert_true(b.get_result()["errors"].has(LineupRules.NOT_OWNED), "unowned loaner cards now flagged")
	assert_true(b.get_reasons_text().contains("You don't own"), "in words")
	f.finish()


func test_duel_button_hands_lineup_to_duel() -> void:
	var old_rival: StringName = DuelControllerScript.next_rival_id
	var old_lineup: Array = DuelControllerScript.next_player_lineup.duplicate()
	var f: RefCounted = Fx.new(tree)
	var b: Control = await f.spawn(Fx.PHONE_SE, "lineup_duel", null,
			{"cards": Fx.VALID_IDS, "signature": &"snow_blind"})
	assert_eq(b.get_lineup_ids(), f.ids(Fx.VALID_IDS), "saved lineup restored on open")
	assert_eq(b.get_signature_id(), &"snow_blind", "saved Signature restored")
	assert_eq(b.get_headline_text(), "SAVED · READY TO DUEL", "restored lineup shows as saved")
	var router: Node = tree.root.get_node("SceneRouter")
	router.last_requested = ""
	var requested: Array = []
	b.duel_requested.connect(func(cards: Array) -> void: requested.append(cards))
	await f.tap_named("%DuelButton")
	assert_eq(requested.size(), 1, "one tap on DUEL")
	assert_eq(router.last_requested, "res://scenes/Duel.tscn", "routes to the duel")
	var handed: Array[StringName] = []
	for c: Variant in DuelControllerScript.next_player_lineup:
		handed.append((c as CardData).id)
	assert_eq(handed, f.ids(Fx.VALID_IDS), "DuelController.next_player_lineup is the lineup")
	assert_eq(DuelControllerScript.next_rival_id, old_rival, "rival choice kept")
	# Invalid lineup: DUEL is off and a direct call explains instead of routing.
	router.last_requested = ""
	await f.tap_row(0)
	assert_true((b.get_node("%DuelButton") as Button).disabled, "DUEL off when invalid")
	assert_false(b.tap_duel(), "no duel with an invalid lineup")
	assert_eq(router.last_requested, "", "no scene change")
	assert_true(b.get_notice_text().begins_with("Not ready to duel yet"), "says why")
	# BACK: one tap to the title.
	await f.tap_named("%BackButton")
	assert_eq(router.last_requested, "res://scenes/Title.tscn", "BACK goes to the title")
	DuelControllerScript.set_next_duel(old_rival, old_lineup)
	f.finish()


func test_one_tap_actions_and_hold_inspect() -> void:
	var f: RefCounted = Fx.new(tree)
	var b: Control = await f.spawn(Fx.PHONE_NOTCH, "lineup_taps")
	# Grid tap toggles: add, then take out.
	await f.tap_card(&"glacier")
	assert_eq(b.get_lineup_ids(), f.ids([&"glacier"]), "tap adds")
	var tag: Control = b.get_collection_button(&"glacier").get_node("Tag")
	assert_true(tag.visible, "IN LINEUP tag on the grid card")
	await f.tap_card(&"glacier")
	assert_eq(b.get_lineup_ids().size(), 0, "tap again takes it out")
	assert_true(b.get_notice_text().begins_with("Took Glacier out."), "says so: %s" % b.get_notice_text())
	assert_false(tag.visible, "tag gone")
	# Empty slot tap explains.
	await f.tap_row(2)
	assert_eq(b.get_notice_text(), "This slot is empty. Tap one of your cards on the left to add it.", "empty slot words")
	# Locked card: tap explains how to earn it, nothing added.
	await f.tap_card(&"long_watch")
	assert_eq(b.get_lineup_ids().size(), 0, "locked card not added")
	assert_true(b.get_notice_text().begins_with("You don't own Long Watch yet."), "locked words: %s" % b.get_notice_text())
	assert_true(b.get_notice_text().contains("To earn it:"), "says how to earn it")
	assert_true((b.get_collection_button(&"long_watch").get_node("Card") as BannerCard).locked, "locked silhouette")
	# CLEAR: one tap.
	for id: StringName in Fx.VALID_IDS:
		await f.tap_card(id)
	await f.tap_named("%ClearButton")
	assert_eq(b.get_lineup_ids().size(), 0, "one tap clears")
	assert_true((b.get_node("%ClearButton") as Button).disabled, "CLEAR off when empty")
	# Hold inspects and the release does not add.
	var inspector: Control = b.get_inspector()
	var gb: Button = b.get_collection_button(&"snow_blind")
	gb.simulate_hold()
	gb.pressed.emit()
	await f.frames()
	assert_true(inspector.is_open(), "hold opens the inspector")
	assert_eq((inspector.get_node("%InspectorNameLabel") as Label).text, "Snow Blind", "inspected card")
	assert_eq(b.get_lineup_ids().size(), 0, "hold release does not add")
	inspector.close()
	# Hold on a lineup row card inspects it too.
	await f.tap_card(&"mayday")
	var rb: Button = b.get_row(0).get_card_button()
	rb.simulate_hold()
	rb.pressed.emit()
	await f.frames()
	assert_true(inspector.is_open(), "hold on a lineup card inspects")
	assert_eq(b.get_lineup_ids().size(), 1, "and does not take it out")
	inspector.close()
	# Hold on a locked card: words, no spoilers.
	var lb: Button = b.get_collection_button(&"city_never_sleeps")
	lb.simulate_hold()
	await f.frames()
	assert_false(inspector.is_open(), "locked card does not open the inspector")
	assert_true(b.get_notice_text().begins_with("City Never Sleeps is locked."), "locked hold words")
	f.finish()


func _expect(b: Control, code: StringName, words: String) -> void:
	var r: Dictionary = b.get_result()
	assert_true((r["errors"] as Array).has(code), "%s expected in %s" % [code, r["errors"]])
	var text: String = b.get_reasons_text()
	assert_true(text.contains(words), "%s shown in words: wanted '%s' in '%s'" % [code, words, text])
	assert_false(r["valid"], "%s: not valid" % code)
	assert_true(b.get_headline_text().begins_with("NOT READY"), "%s headline" % code)
	for bad: String in FORBIDDEN:
		assert_false(text.contains(bad), "%s: reasons show '%s'" % [code, bad])
