extends SceneTree
# Runs only the test files named in the KS_TESTS env var (comma separated).
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	var p := 0
	var f := 0
	for path: String in OS.get_environment("KS_TESTS").split(","):
		var script: GDScript = load(path)
		if script == null:
			print("FAIL load ", path); f += 1; continue
		for m: Dictionary in script.get_script_method_list():
			if not String(m["name"]).begins_with("test_"): continue
			var only: String = OS.get_environment("KS_ONLY")
			if only != "" and not String(m["name"]).contains(only): continue
			var t: RefCounted = script.new()
			t.set("tree", self)
			await t.call(m["name"])
			var fails: Array = t.get("failures")
			if int(t.get("assertions")) == 0: fails.append("no assertions")
			if fails.is_empty():
				p += 1; print("PASS ", m["name"])
			else:
				f += 1; print("FAIL ", m["name"])
				for x in fails: print("   - ", x)
	print("%d passed, %d failed" % [p, f])
	quit()
