extends SceneTree
func _initialize() -> void:
	var b: BalanceConfig = load("res://data/balance.tres")
	var t: Array[TriptychData] = []
	for f in ["cold_signal", "midnight_run", "open_book"]:
		t.append(load("res://data/triptychs/%s.tres" % f))
	var w: RivalData = load("res://data/rivals/warden.tres")
	for oid in ["quartermaster", "archivist", "warden"]:
		var o: RivalData = load("res://data/rivals/%s.tres" % oid)
		for first in [0, 1]:
			var s: WallState = WallState.new_match(w.lineup, w.signature, o.lineup, o.signature, first, b, RulesOptions.new(), t)
			var ai := RivalAI.for_rival(w, 7)
			var oa := RivalAI.for_rival(o, 8)
			while not s.is_game_over():
				var me := s.to_move
				var t0 := Time.get_ticks_usec()
				var m: Dictionary = (ai if me == 0 else oa).choose_move(s.copy(), me)
				var dt := Time.get_ticks_usec() - t0
				if me == 0:
					print("%s first=%d placements=%d ms=%.1f nodes=%d" % [oid, first, s.placements, dt/1000.0, ai.last_nodes])
				WallRules.place(s, me, m["card"], m["slot"], m["copy_from"])
	quit()
