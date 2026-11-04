# match_save_codec.gd
# Purpose: The CardZone match save format (cz08), node-free so tests can drive it directly.
#   A save is the match's replay record (U1: the origin state plus the logged action list) with
#   everything needed to rebuild and check it:
#
#     CARDZONE-MATCH-SAVE schema=1 seq=<save counter> bytes=<body byte count> md5=<md5 of the body>
#     <body: Godot variant text (var_to_str) of a Dictionary>
#
#   body = {
#     schema: 1, saved_at: unix seconds, engine: "4.4.1",
#     balance: BalanceConfig.snapshot() of the match's own config, tunables_hash: String,
#     ai: {level: String, seed: int},          # copied from meta (ai_level, ai_seed)
#     meta: Dictionary,                        # caller's plain data (mode, seats, AI, ...)
#     origin: MatchState.origin, actions: MatchState.actions,
#     summary: {step, round, phase, active, pending_brace, over, fingerprint (md5)},
#   }
#
#   Variant text keeps ints and StringNames exactly (JSON would not). The header line lets a
#   reader tell old, newer and damaged saves apart before parsing the body; the md5 catches
#   truncation and bit rot; seq (one more per save) picks the newest of two copies. Bodies that contain Object(...) are refused (str_to_var could build
#   objects). Resuming replays the actions with a RulesData built from the saved balance
#   snapshot; the result must match the saved tunables hash and state fingerprint, or the save
#   is reported as MISMATCH (content or rules changed since it was written).
#
#   Statuses: OK, NONE (no save), CORRUPT (unreadable or damaged), OLD (older schema or a bare
#   engine save_text), NEWER (written by a newer build), MISMATCH (reads fine but no longer
#   replays to the same match). Anything but OK/NONE means: offer a new match.
# Dependencies: MatchState, SeatState, LoadoutRules, RulesData, BalanceConfig.
# Author: Mechanics Developer Agent
class_name MatchSaveCodec
extends RefCounted

const MAGIC: String = "CARDZONE-MATCH-SAVE"
const SCHEMA_VERSION: int = 1
const ENGINE_VERSION: String = "4.4.1"

const OK: StringName = &"ok"
const NONE: StringName = &"none"
const CORRUPT: StringName = &"corrupt"
const OLD: StringName = &"old"
const NEWER: StringName = &"newer"
const MISMATCH: StringName = &"mismatch"

## Action types that can appear in a match log (undo is never logged).
const LOGGED_TYPES: Array[String] = ["drop", "play", "move", "loot", "shoot", "frag", "attach",
		"patch_up", "ditch", "end_turn", "brace", "concede"]


# === Encode ===============================================================================

## The full save text for a state (see the header for the format).
static func encode(state: MatchState, meta: Dictionary = {}, saved_at: int = -1, seq: int = 0) -> String:
	var clean_meta: Dictionary = plain_data(meta)
	var b: BalanceConfig = state.data.balance
	var body: Dictionary = {
		"schema": SCHEMA_VERSION,
		"saved_at": saved_at if saved_at >= 0 else int(Time.get_unix_time_from_system()),
		"engine": ENGINE_VERSION,
		"balance": b.snapshot(),
		"tunables_hash": b.tunables_hash(),
		"ai": {"level": String(clean_meta.get("ai_level", "")), "seed": int(clean_meta.get("ai_seed", 0))},
		"meta": clean_meta,
		"origin": state.origin,
		"actions": state.actions,
		"summary": summary_of(state),
	}
	return wrap_body(var_to_str(body), SCHEMA_VERSION, seq)


## Header + body. `schema` is exposed so tests can write old and newer saves.
static func wrap_body(body_text: String, schema: int, seq: int = 0) -> String:
	return "%s schema=%d seq=%d bytes=%d md5=%s\n%s" % [MAGIC, schema, seq, body_text.to_utf8_buffer().size(),
			body_text.md5_text(), body_text]


## What the save summary says about the state (also used to compare a resume).
static func summary_of(state: MatchState) -> Dictionary:
	return {
		"step": state.actions.size(),
		"round": state.round_number,
		"phase": String(state.phase),
		"active": state.active,
		"pending_brace": state.pending_brace_seat(),
		"over": state.is_over(),
		"undo_depth": state.undo_stack.size(),
		"fingerprint": state.fingerprint().md5_text(),
	}


## A deep copy keeping only plain data (null, bool, int, float, String, StringName, Vector2,
## Array, Dictionary). Objects, Callables and the like are dropped with a warning.
static func plain_data(v: Variant) -> Variant:
	match typeof(v):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR2, TYPE_VECTOR2I:
			return v
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			var out: Array = []
			for x: Variant in v:
				var c: Variant = plain_data(x)
				if c != null or x == null:
					out.append(c)
			return out
		TYPE_DICTIONARY:
			var d: Dictionary = {}
			for k: Variant in (v as Dictionary).keys():
				var c: Variant = plain_data(v[k])
				if c != null or v[k] == null:
					d[k] = c
			return d
	push_warning("MatchSaveCodec: dropping non-plain meta value of type %s" % type_string(typeof(v)))
	return null


# === Decode ===============================================================================

## Reads the header and body. {status, body: Dictionary, schema: int, seq: int, error: String}.
## status OK means the body parsed and passed the structure checks (not yet replayed).
static func decode(text: String) -> Dictionary:
	if text.strip_edges().is_empty():
		return _fail(CORRUPT, "the save file is empty")
	var nl: int = text.find("\n")
	var header: String = text.substr(0, nl) if nl >= 0 else text
	if not header.begins_with(MAGIC):
		# A bare MatchState.save_text() (the engine's own format, before cz08) counts as old.
		if text.begins_with("{") and not text.contains("Object("):
			var raw: Variant = str_to_var(text)
			if raw is Dictionary and raw.has("origin") and raw.has("actions"):
				return _fail(OLD, "an engine save without the cz08 header", 0)
		return _fail(CORRUPT, "not a CardZone match save (bad header)")
	var fields: Dictionary = {}
	for part: String in header.substr(MAGIC.length()).strip_edges().split(" ", false):
		var kv: PackedStringArray = part.split("=", true, 1)
		if kv.size() == 2:
			fields[kv[0]] = kv[1]
	if not (fields.has("schema") and String(fields["schema"]).is_valid_int()):
		return _fail(CORRUPT, "the header has no schema version")
	var schema: int = int(fields["schema"])
	if schema > SCHEMA_VERSION:
		return _fail(NEWER, "written by a newer version (save schema %d, this build reads %d)" % [schema, SCHEMA_VERSION], schema)
	if schema < SCHEMA_VERSION:
		return _fail(OLD, "an older save format (schema %d, this build reads %d)" % [schema, SCHEMA_VERSION], schema)
	if nl < 0:
		return _fail(CORRUPT, "the save has a header but no body", schema)
	var body_text: String = text.substr(nl + 1)
	var bytes: int = body_text.to_utf8_buffer().size()
	if String(fields.get("bytes", "")) != str(bytes):
		return _fail(CORRUPT, "the save is cut short or padded (%d bytes, header says %s)" % [bytes, fields.get("bytes", "?")], schema)
	if String(fields.get("md5", "")) != body_text.md5_text():
		return _fail(CORRUPT, "the save's checksum does not match (damaged file)", schema)
	if body_text.contains("Object("):
		return _fail(CORRUPT, "the save contains objects", schema)
	var parsed: Variant = str_to_var(body_text)
	if not (parsed is Dictionary):
		return _fail(CORRUPT, "the save body does not parse as a dictionary", schema)
	var body: Dictionary = parsed
	var problem: String = check_body(body)
	if problem != "":
		return _fail(CORRUPT, problem, schema)
	var seq: int = int(fields["seq"]) if String(fields.get("seq", "")).is_valid_int() else 0
	return {"status": OK, "body": body, "schema": schema, "seq": seq, "error": ""}


## Structure check of a parsed body: "" when it is fine, else what is wrong.
static func check_body(body: Dictionary) -> String:
	if typeof(body.get("schema")) != TYPE_INT or int(body["schema"]) != SCHEMA_VERSION:
		return "the body's schema field is missing or wrong"
	for key: String in ["balance", "meta", "origin", "summary", "ai"]:
		if not (body.get(key) is Dictionary):
			return "the save has no %s" % key
	if not (body.get("actions") is Array):
		return "the save has no action list"
	if typeof(body.get("tunables_hash")) != TYPE_STRING:
		return "the save has no tunables hash"
	var problem: String = _check_fields(body["origin"], MatchState.new(), MatchState.FIELDS, "origin")
	if problem != "":
		return problem
	var seats: Variant = (body["origin"] as Dictionary).get("seats")
	if not (seats is Array) or (seats as Array).size() != 2:
		return "origin.seats must hold two seats"
	for i: int in 2:
		if not (seats[i] is Dictionary):
			return "origin.seats[%d] is not a seat" % i
		problem = _check_fields(seats[i], SeatState.new(), SeatState.FIELDS, "origin.seats[%d]" % i)
		if problem != "":
			return problem
	var n: int = 0
	for act: Variant in body["actions"]:
		problem = _check_action(act)
		if problem != "":
			return "action %d: %s" % [n, problem]
		n += 1
	return ""


# === Restore ==============================================================================

## Rebuilds the match from a decoded body on `content` (the game's RulesData; its balance is
## replaced by the saved snapshot). {status: OK | MISMATCH, state: MatchState or null, error}.
static func restore(body: Dictionary, content: RulesData) -> Dictionary:
	if content == null:
		return {"status": MISMATCH, "state": null, "error": "no card data to rebuild the match with"}
	var errors: Array = []
	var overrides: Dictionary = {}
	var snapshot: Dictionary = body["balance"]
	var known: Array[StringName] = BalanceConfig.tunable_keys()
	for key: Variant in snapshot.keys():
		if not known.has(StringName(key)):
			errors.append("tunable %s no longer exists" % key)
		else:
			overrides[StringName(key)] = snapshot[key]
	var data: RulesData = content.with_balance(overrides, errors)
	if not errors.is_empty():
		return {"status": MISMATCH, "state": null, "error": "the saved balance no longer applies: %s" % ", ".join(errors)}
	if data.balance.tunables_hash() != String(body["tunables_hash"]):
		return {"status": MISMATCH, "state": null,
				"error": "the saved balance does not rebuild to the same tunables (hash %s, now %s)" % [
				body["tunables_hash"], data.balance.tunables_hash()]}
	var state: MatchState = LoadoutRules.replay(body["origin"], body["actions"], data, errors)
	if not errors.is_empty():
		return {"status": MISMATCH, "state": null, "error": "the moves no longer replay: %s" % errors[0]}
	if state.actions.size() != (body["actions"] as Array).size():
		return {"status": MISMATCH, "state": null, "error": "the replay stopped early"}
	var want: String = String((body["summary"] as Dictionary).get("fingerprint", ""))
	var got: String = state.fingerprint().md5_text()
	if want != got:
		return {"status": MISMATCH, "state": null,
				"error": "the replay reached a different position (cards or rules changed since the save)"}
	return {"status": OK, "state": state, "error": ""}


## A player-facing line for a status.
static func status_text(status: StringName) -> String:
	match status:
		OK:
			return "Saved match found."
		NONE:
			return "No saved match."
		CORRUPT:
			return "Your saved match was damaged and can't be resumed. A copy was kept; start a new match."
		OLD:
			return "Your saved match is from an older version and can't be resumed. Start a new match."
		NEWER:
			return "Your saved match is from a newer version and can't be resumed here. Start a new match."
		MISMATCH:
			return "The cards or rules changed since your match was saved, so it can't be resumed. Start a new match."
	return "Your saved match can't be resumed. Start a new match."


# === Internals ============================================================================

static func _fail(status: StringName, error: String, schema: int = -1) -> Dictionary:
	return {"status": status, "body": {}, "schema": schema, "seq": -1, "error": error}


## Every field present with the same type as on a fresh object; typed arrays hold the right type.
static func _check_fields(d: Dictionary, template: Object, fields: Array[String], where: String) -> String:
	for f: String in fields:
		if not d.has(f):
			return "%s.%s is missing" % [where, f]
		var want: Variant = template.get(f)
		var got: Variant = d[f]
		if not _same_kind(want, got):
			return "%s.%s has the wrong type (%s)" % [where, f, type_string(typeof(got))]
		if want is Array and (want as Array).is_typed():
			var elem: int = (want as Array).get_typed_builtin()
			for x: Variant in got:
				if not _same_kind_type(elem, typeof(x)):
					return "%s.%s holds a %s" % [where, f, type_string(typeof(x))]
	return ""


static func _same_kind(want: Variant, got: Variant) -> bool:
	return _same_kind_type(typeof(want), typeof(got))


static func _same_kind_type(want: int, got: int) -> bool:
	if want == got:
		return true
	var text: Array[int] = [TYPE_STRING, TYPE_STRING_NAME]
	return want in text and got in text


static func _check_action(act: Variant) -> String:
	if not (act is Dictionary):
		return "not a dictionary"
	var a: Dictionary = act
	if not (String(a.get("type", "")) in LOGGED_TYPES):
		return "unknown type %s" % a.get("type")
	if typeof(a.get("seat")) != TYPE_INT:
		return "no seat"
	for k: Variant in a.keys():
		var v: Variant = a[k]
		match typeof(v):
			TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
				pass
			TYPE_ARRAY:
				for x: Variant in v:
					if typeof(x) != TYPE_INT:
						return "%s holds a %s" % [k, type_string(typeof(x))]
			TYPE_DICTIONARY:
				for x: Variant in (v as Dictionary).values():
					if typeof(x) != TYPE_INT:
						return "%s holds a %s" % [k, type_string(typeof(x))]
			_:
				return "%s has the wrong type" % k
	return ""
