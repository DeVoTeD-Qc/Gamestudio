extends SceneTree
func _initialize() -> void:
	var b: BalanceConfig = load("res://data/balance.tres")
	var t: Array[TriptychData] = []
	for f in ["cold_signal", "midnight_run", "open_book"]:
		t.append(load("res://data/triptychs/%s.tres" % f))
	var w: RivalData = load("res://data/rivals/warden.tres")
	var a: RivalData = load("res://data/rivals/archivist.tres")
	var s: WallState = WallState.new_match(w.lineup, w.signature, a.lineup, a.signature, 0, b, RulesOptions.new(), [] as Array[TriptychData])
	var moves := WallRules.legal_moves(s)
	var N := 2000
	var t0 := Time.get_ticks_usec()
	for i in N: s.copy()
	print("copy us ", (Time.get_ticks_usec()-t0)/float(N))
	t0 = Time.get_ticks_usec()
	for i in N:
		var c := s.copy(); WallRules.place(c, 0, moves[i%moves.size()]["card"], moves[i%moves.size()]["slot"])
	print("copy+place us ", (Time.get_ticks_usec()-t0)/float(N))
	t0 = Time.get_ticks_usec()
	for i in N: WallRules.score(s, 0)
	print("score us ", (Time.get_ticks_usec()-t0)/float(N))
	t0 = Time.get_ticks_usec()
	for i in N: WallRules.triptychs_scored(s, 0)
	print("tript us ", (Time.get_ticks_usec()-t0)/float(N))
	t0 = Time.get_ticks_usec()
	for i in N: WallRules.legal_moves(s)
	print("legal us ", (Time.get_ticks_usec()-t0)/float(N))
	var ai := RivalAI.for_rival(w, 1)
	t0 = Time.get_ticks_usec()
	for i in 200: ai.evaluate(s, 0)
	print("eval us ", (Time.get_ticks_usec()-t0)/200.0)
	quit()
