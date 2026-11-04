# test_hotseat_kit.gd
# Purpose: Shared helpers for the cz14 hot-seat tests (test_hotseat_flow.gd, test_hotseat_fairness.gd,
#   test_hotseat_save.gd): the phone-size spawn of Match.tscn in hot-seat mode, the cover tap,
#   a touch loop that plays a whole hot-seat match (both seats through the real UI, covers tapped
#   through), and the fairness checks:
#     - view check (instance level): every view the controller emits belongs to the seat on
#       screen (view.seat == controller.human), every card instance in its private lists (hand,
#       loadout, next draw / hand, Brace prompt) is owned by that seat, and a covered view has no
#       private list and no Brace prompt at all;
#     - screen walk (card level): every node under the match screen (hidden ones too: CzCard info
#       and card_id meta, Label / Button / RichTextLabel text) is searched for the cards the
#       watching seat may not know: the other seat's hand / loadout cards (and their attachments)
#       whose card id never reached the watching seat through its own views or events (P18: a
#       seat may remember public events, never read a private field). While the cover is up the
#       watcher could be either player, so both seats' unknown private cards are forbidden.
#   No test_* methods: the runner finds nothing to run here.
# Author: Mechanics Developer Agent (cz14)
extends "res://tests/test_match_flow_kit.gd"

const HOTSEAT_META: Dictionary = {"mode": "hotseat", "ai_level": "", "ai_seed": 0, "human_seat": 0}

## Every cover that went up: its info.
var covers: Array[Dictionary] = []
## Card ids each seat has legitimately seen (its own views and the events shown to it).
var known: Array = [{}, {}]
var view_checks: int = 0
var walk_checks: int = 0
## Walks where the forbidden set was not empty (the check had something to find).
var walk_armed: int = 0
var leaks: Array[String] = []


## Match.tscn at phone size, hot-seat meta, watchers connected, then the match starts (behind
## its first cover). state == null: a new match from CardDB.
## shell_start: start through the pending SetupLaunch request (MatchShell.begin), as the game does.
func _spawn_hotseat(state: MatchState, resumed: Dictionary = {}, shell_start: bool = false) -> Control:
	_saved_root_size = tree.root.size
	_saved_scale_mode = tree.root.content_scale_mode
	var px: Vector2 = PHONE["pt"] * PHONE["ratio"]
	var logical: Vector2 = ScreenProfile.logical_size(px, ScreenProfile.base_size(px, PHONE["ratio"]))
	tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	tree.root.size = Vector2i(logical)
	await tree.process_frame
	var m: Control = (load(MATCH_SCENE) as PackedScene).instantiate()
	m.auto_start = false
	var k: float = ScreenProfile.points_per_px(px, PHONE["ratio"])
	var insets: Rect2 = PHONE["insets"]
	m.points_per_px_override = k
	m.safe_area_override = Rect2(insets.position / k, logical - insets.position / k - insets.size / k)
	var ctrl: Node = m.get_node("%MatchController")
	ctrl.event_delay = 0.0
	ctrl.opponent_delay = 0.0
	ctrl.meta = HOTSEAT_META.duplicate()
	tree.root.add_child(m)
	for i: int in 3:
		await tree.process_frame
	m.get_cover().arm_ms = 0
	_watch(m)
	if shell_start:
		m.start_live(null)
	elif not resumed.is_empty():
		ctrl.meta = (resumed["meta"] as Dictionary).duplicate(true)  # as start_resumed merges it
		m.start_live(resumed["state"])
	elif state == null:
		MatchStore.clear()
		m.start_live(MatchState.new_match(RulesData.from_card_db(CardDB), DataEnums.Route.A))
	else:
		MatchStore.clear()
		m.start_live(state)
	for i: int in 3:
		await tree.process_frame
	return m


func _watch(m: Control) -> void:
	var ctrl: Node = m.get_controller()
	ctrl.cover_changed.connect(func(up: bool, info: Dictionary) -> void:
		if up:
			covers.append(info)
			_check_screen(m, "cover up for Player %d (%s)" % [int(info["player"]), info["reason"]]))
	ctrl.view_changed.connect(func(v: Dictionary) -> void: _check_view(ctrl, v))
	ctrl.event_shown.connect(func(_t: String, e: Dictionary) -> void: _learn(ctrl.human, e))
	ctrl.playback_finished.connect(func(_s: String, steps: Array, _k: bool) -> void:
		for st: Dictionary in steps:
			_learn(ctrl.human, st.get("event", {})))


## Taps the cover (the whole screen is its tap target). False when no cover was up.
func _tap_cover(m: Control) -> bool:
	var cover: Control = m.get_cover()
	if cover == null or not cover.visible:
		failures.append("no cover to tap (phase %s)" % m.get_controller().phase)
		return false
	await _touch(cover.get_tap_button())
	for i: int in 2:
		await tree.process_frame
	return true


## Plays a hot-seat match to its end, both seats by touch with the kit policy, tapping every
## cover. Checks the screen at every cover and before every decision.
func _play_hotseat(m: Control, max_decisions: int = 1500) -> Dictionary:
	var ctrl: Node = m.get_controller()
	var seen: Dictionary = {}
	var guard: int = 0
	var n: int = 0
	var last_seat: int = -1
	var taps: int = 0
	while ctrl.phase != &"over" and guard < max_decisions:
		var wait: int = 0
		while ctrl.busy and wait < 6000:
			wait += 1
			await tree.process_frame
		if ctrl.phase == &"over":
			break
		if ctrl.is_covered():
			_check_screen(m, "before the tap on the cover for Player %d" % (ctrl.cover_seat + 1))
			if not m.get_cards(&"hand").is_empty() or not m.get_cards(&"next").is_empty():
				leaks.append("cards on screen under the cover: hand %d, next %d" % [m.get_cards(&"hand").size(), m.get_cards(&"next").size()])
			var seat: int = ctrl.cover_seat
			if not await _tap_cover(m):
				break
			taps += 1
			if ctrl.is_covered() or ctrl.human != seat:
				failures.append("the tap did not reveal Player %d" % (seat + 1))
				break
			continue
		if ctrl.human != last_seat:
			last_seat = ctrl.human
			n = 0
		_check_screen(m, "Player %d deciding (%s)" % [ctrl.human + 1, ctrl.phase])
		guard += 1
		var legal: Array[Dictionary] = ctrl.legal()
		if legal.is_empty():
			failures.append("no legal action for Player %d in phase %s" % [ctrl.human + 1, ctrl.phase])
			break
		var a: Dictionary = _pick(ctrl, legal, n)
		n += 1
		var before: int = ctrl.state.actions.size()
		await _do_by_touch(m, a)
		seen[a["type"]] = true
		if ctrl.state.actions.size() == before and ctrl.phase != &"over":
			failures.append("touch did not apply %s for Player %d (notice '%s')" % [a, ctrl.human + 1, m.last_notice])
			break
	return {"decisions": guard, "kinds": seen, "over": ctrl.phase == &"over", "taps": taps}


# --- Fairness checks ----------------------------------------------------------------------------

## Instance-level check of one emitted view.
func _check_view(ctrl: Node, v: Dictionary) -> void:
	if v.is_empty():
		return
	view_checks += 1
	var seat: int = int(v["seat"])
	_learn(seat, v)
	if seat != int(ctrl.human):
		leaks.append("view for seat %d emitted while seat %d is on screen" % [seat, int(ctrl.human)])
	var me: Dictionary = v["me"]
	var lists: Dictionary = {"hand": me["hand"], "loadout": me["loadout"], "next_draw": me["next_draw"],
			"next_hand": me["next_hand"]}
	if bool(v.get("covered", false)):
		if not ctrl.is_covered():
			leaks.append("a covered view without a cover")
		for key: String in lists:
			if not (lists[key] as Array).is_empty():
				leaks.append("covered view has me.%s (%d cards)" % [key, (lists[key] as Array).size()])
		if not (me["held"] as Array).is_empty() or v.has("brace_prompt") or v.has("shot_preview"):
			leaks.append("covered view has held cards, a Brace prompt or a shot preview")
		return
	if ctrl.is_covered():
		leaks.append("a full view of seat %d went out while the cover is up" % seat)
	# Every private card in the view sits in this seat's own hand or loadout right now (looted
	# cards keep the map as their owner, so the zones decide, not state.owners).
	var st: MatchState = ctrl.state
	var mine: Array = st.seats[seat].hand + st.seats[seat].loadout
	var theirs: Array = st.seats[1 - seat].hand + st.seats[1 - seat].loadout
	for key: String in lists:
		for cv: Dictionary in lists[key]:
			if not mine.has(int(cv["id"])) or theirs.has(int(cv["id"])):
				leaks.append("seat %d's view has card %d (%s) outside its own hand / loadout in me.%s" % [seat,
						int(cv["id"]), cv["card"], key])
	var bp: Dictionary = v.get("brace_prompt", {})
	for inst: Variant in (bp.get("eligible", []) as Array) + (bp.get("suggested", []) as Array):
		if not mine.has(int(inst)):
			leaks.append("seat %d's Brace prompt offers card %d, not its own" % [seat, int(inst)])


## Remembers every card id inside a view or event the seat was shown.
func _learn(seat: int, data: Variant) -> void:
	if seat < 0 or seat > 1:
		return
	if data is Dictionary:
		for k: Variant in (data as Dictionary).keys():
			_learn(seat, data[k])
	elif data is Array:
		for x: Variant in data:
			_learn(seat, x)
	elif data is String or data is StringName:
		var id: StringName = StringName(str(data))
		if CardDB.get_card(id) != null:
			(known[seat] as Dictionary)[id] = true


## {card id: display name} the screen must not show now: the unknown private cards of the seat
## not on screen (both seats while the cover is up).
func _forbidden(ctrl: Node) -> Dictionary:
	var st: MatchState = ctrl.state
	var out: Dictionary = {}
	var pairs: Array = []  # [private seat, watching seat]
	if ctrl.is_covered():
		pairs = [[0, 1], [1, 0]]
	else:
		pairs = [[1 - int(ctrl.human), int(ctrl.human)]]
	for p: Array in pairs:
		var owner: int = p[0]
		var watcher: int = p[1]
		var insts: Array = []
		for inst: int in st.seats[owner].hand + st.seats[owner].loadout:
			insts.append(inst)
			for att: int in st.attachments_of(inst):
				insts.append(att)
		for inst: int in insts:
			var id: StringName = st.card_id(inst)
			var c: CardData = CardDB.get_card(id)
			if c == null or c.is_hit() or (known[watcher] as Dictionary).has(id):
				continue
			out[id] = c.display_name
	return out


## Walks every node under the screen for forbidden cards. Records leaks with the node path.
func _check_screen(m: Control, when: String) -> void:
	var ctrl: Node = m.get_controller()
	if ctrl.state == null or ctrl.state.is_over():
		return
	var forbidden: Dictionary = _forbidden(ctrl)
	walk_checks += 1
	if forbidden.is_empty():
		return
	walk_armed += 1
	var names: Array = forbidden.values()
	for n: Node in m.find_children("*", "", true, false):
		var hits: PackedStringArray = []
		if n.has_meta(&"card_id") and forbidden.has(StringName(str(n.get_meta(&"card_id")))):
			hits.append("card_id meta %s" % n.get_meta(&"card_id"))
		if n is CzCard and names.has(str((n as CzCard).info.get("name", ""))):
			hits.append("CzCard %s" % (n as CzCard).info.get("name", ""))
		var text: String = ""
		if n is Label:
			text = (n as Label).text
		elif n is Button:
			text = (n as Button).text
		elif n is RichTextLabel:
			text = (n as RichTextLabel).get_parsed_text()
		if text != "":
			for nm: Variant in names:
				if String(nm) in text:
					hits.append("text '%s' names %s" % [text.left(80), nm])
		if not hits.is_empty():
			leaks.append("%s: %s at %s" % [when, ", ".join(hits), m.get_path_to(n)])


## Every card name on the screen right now (CzCards and text), for positive controls.
func _names_on_screen(m: Control) -> Dictionary:
	var out: Dictionary = {}
	for n: Node in m.find_children("*", "", true, false):
		if n is CzCard:
			out[str((n as CzCard).info.get("name", ""))] = true
	return out
