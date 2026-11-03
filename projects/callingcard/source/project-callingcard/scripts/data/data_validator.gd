# data_validator.gd
# Adapted from Killstreak scripts/data/data_validator.gd (issue report and reference checks kept;
#   loadout-slot checks removed; Banner Wall rule codes added).
# Purpose: Collects validation issues for data Resources. CardDB creates one per load,
#   fills `index` with every loaded id and `balance` with the active BalanceConfig, then
#   calls each resource's validate(v). Each issue is a Dictionary
#   {severity, code, file, id, field, message}.
# Dependencies: DataEnums, BalanceConfig.
# Author: Mechanics Developer Agent
class_name DataValidator
extends RefCounted

# Issue codes (tests and the validation report use these).
const LOAD_FAILED: String = "load_failed"            ## File did not load (syntax, missing dependency).
const UNKNOWN_TYPE: String = "unknown_type"          ## .tres is not one of the data classes.
const DUPLICATE_ID: String = "duplicate_id"
const MISSING_FIELD: String = "missing_field"        ## Required field empty / not set.
const OUT_OF_RANGE: String = "out_of_range"          ## Number or list size outside allowed limits.
const INVALID_VALUE: String = "invalid_value"        ## Value that doesn't fit (bad enum, bad id format, contradiction).
const BROKEN_REFERENCE: String = "broken_reference"  ## Reference to a resource that isn't loaded data (or empty slot).
const WRONG_TYPE: String = "wrong_type"              ## Reference to the wrong kind of resource.
const BUDGET_MISMATCH: String = "budget_mismatch"    ## Top + Side + Bottom differs from the Clearance stat budget (spec §3).
const STORE_RULE: String = "store_rule"              ## Anti-pay-to-win rule broken: store card above Clearance 1 or with a trait (spec §3).
const LINEUP_RULE: String = "lineup_rule"            ## Lineup breaks spec §4.2 (size, Clearance cap, Legends, Signature).

## id (String) -> Resource for every loaded data file.
var index: Dictionary = {}
## The active balance config (defaults when data/balance.tres is missing; CardDB reports that).
var balance: BalanceConfig = BalanceConfig.new()
var issues: Array[Dictionary] = []

var _file: String = ""
var _id: String = ""
var _id_regex: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_]*$")


## Sets the file / id that following issues are reported against.
func begin(file: String, id: String) -> void:
	_file = file
	_id = id


func add(code: String, field: String, message: String, severity: String = "error") -> void:
	issues.append({
		"severity": severity, "code": code, "file": _file, "id": _id,
		"field": field, "message": message,
	})


func error_count() -> int:
	return issues.filter(func(i: Dictionary) -> bool: return i["severity"] == "error").size()


static func format_issue(issue: Dictionary) -> String:
	return "%s [%s] %s (%s) %s: %s" % [
		String(issue["severity"]).to_upper(), issue["code"], issue["file"], issue["id"],
		issue["field"], issue["message"],
	]

# --- Issue shorthands ---------------------------------------------------------

func missing(field: String, message: String) -> void:
	add(MISSING_FIELD, field, message)


func out_of_range(field: String, message: String) -> void:
	add(OUT_OF_RANGE, field, message)


func invalid(field: String, message: String) -> void:
	add(INVALID_VALUE, field, message)


func broken_reference(field: String, message: String) -> void:
	add(BROKEN_REFERENCE, field, message)


## A warning: reported and printed, but the data still counts as valid.
func warn(code: String, field: String, message: String) -> void:
	add(code, field, message, "warning")

# --- Field checks -----------------------------------------------------------------

func require_id(id: StringName) -> void:
	if String(id).is_empty():
		missing("id", "id is empty")
	elif _id_regex.search(String(id)) == null:
		invalid("id", "'%s' must be lowercase snake_case (a-z, 0-9, _)" % id)


func require_text(field: String, value: String) -> void:
	if value.strip_edges().is_empty():
		missing(field, "%s is empty" % field)


## Text that must be a single line of at most max_length characters (may be empty).
func check_line(field: String, value: String, max_length: int) -> void:
	if value.length() > max_length:
		out_of_range(field, "%d characters (max %d)" % [value.length(), max_length])
	if value.contains("\n"):
		invalid(field, "must be one line")


func check_range(field: String, value: int, min_value: int, max_value: int) -> void:
	if value < min_value or value > max_value:
		out_of_range(field, "%d is outside %d..%d" % [value, min_value, max_value])


func check_range_f(field: String, value: float, min_value: float, max_value: float) -> void:
	if value < min_value or value > max_value:
		out_of_range(field, "%s is outside %s..%s" % [value, min_value, max_value])


func check_enum(field: String, value: int, enum_dict: Dictionary) -> bool:
	if not enum_dict.values().has(value):
		invalid(field, "%d is not a valid value (allowed: %s)" % [value, ", ".join(PackedStringArray(enum_dict.keys()))])
		return false
	return true

# --- Reference checks --------------------------------------------------------------

## True when ref is set, of class `type` and loaded from the data folder.
func check_ref(field: String, ref: Resource, type: Script, required: bool) -> bool:
	if ref == null:
		if required:
			missing(field, "reference not set")
		return false
	if not is_instance_of(ref, type):
		add(WRONG_TYPE, field, "'%s' is a %s, expected %s" % [ref.resource_path, _type_name(ref), type.get_global_name()])
		return false
	var ref_id: String = String(ref.get("id"))
	if not index.has(ref_id) or index[ref_id] != ref:
		broken_reference(field, "'%s' (%s) is not a loaded data file under the data folder" % [ref_id, ref.resource_path])
		return false
	return true


## Checks every entry; true when the size is in range and every entry is valid.
func check_ref_array(field: String, refs: Array, type: Script, min_count: int, max_count: int) -> bool:
	var ok: bool = true
	if refs.size() < min_count or refs.size() > max_count:
		out_of_range(field, "has %d entries, needs %d..%d" % [refs.size(), min_count, max_count])
		ok = false
	for i: int in refs.size():
		if refs[i] == null:
			broken_reference("%s[%d]" % [field, i], "empty slot")
			ok = false
		elif not check_ref("%s[%d]" % [field, i], refs[i], type, true):
			ok = false
	if has_duplicates(refs):
		invalid(field, "the same entry is listed twice")
		ok = false
	return ok


## An id (not a Resource reference, to avoid .tres reference cycles) that must name loaded data of `type`.
func check_id_ref(field: String, ref_id: StringName, type: Script) -> bool:
	if String(ref_id).is_empty():
		missing(field, "id not set")
		return false
	var res: Resource = index.get(String(ref_id))
	if res == null:
		broken_reference(field, "no loaded data has id '%s'" % ref_id)
		return false
	if not is_instance_of(res, type):
		add(WRONG_TYPE, field, "'%s' is a %s, expected %s" % [ref_id, _type_name(res), type.get_global_name()])
		return false
	return true


func has_duplicates(refs: Array) -> bool:
	var seen: Dictionary = {}
	for r: Variant in refs:
		if r == null:
			continue
		if seen.has(r):
			return true
		seen[r] = true
	return false


func _type_name(res: Resource) -> String:
	var script: Script = res.get_script()
	if script != null and not script.get_global_name().is_empty():
		return script.get_global_name()
	return res.get_class()
