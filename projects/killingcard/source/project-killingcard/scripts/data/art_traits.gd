# art_traits.gd
# Purpose: kc-art-traits (documentation/design/art-traits.md, approved T1-T4): "the chassis gives the
#   numbers, the art gives the trait". Maps an art id to its calling-card FAMILY and the family to a
#   TRAIT, lists the arts of each (chassis, trait) option and names the free default art of every
#   option (fairness rule v2: art can change the trait, never the numbers; every option is free).
#   Family -> trait: Honors (prestige & challenges) Vanguard, Operators (operator bundles, Warzone)
#   Spec Ops, Mastery (weapon mastery) Heavy, Horde (Zombies) Undead, Standard (default / campaign)
#   none. A trait only applies when it is on the chassis' option list (CardData.trait_options);
#   otherwise the art is "plain". Printed cards (Elites, Fields) keep their trait whatever they wear.
#   Art ids:
#     <chassis>                 the chassis' default art: the home option (default trait)
#     <chassis>~<variant>       a public look of the home option (BannerArtDB.VARIANTS: night, dust, flip)
#     <chassis>~<family>        the public placeholder art of an alternate option (OPTION_VARIANTS:
#                               honors, operators, mastery, horde); our own art, no licensed names
#     kc_mw3_*                  a licensed pitch art (git-ignored folder); its family comes from the
#                               pitch manifest's `family` column (tools/build_mw3_pitch_set.py),
#                               an old manifest without it = the home family
#   Data layer only: never loads a texture (BannerArtDB renders; this reads the manifest's text).
#   The rules never read arts: the run layer (RunProgress) and the UI resolve art -> trait and pass
#   the trait on (SideSetup.deck_traits).
# Dependencies: CardData, SynergyRules, BannerArtDB (its licensed folder settings and VARIANTS only).
# Author: Mechanics Developer Agent (kc-art-traits-impl)
class_name ArtTraits
extends RefCounted

const STANDARD: StringName = &"standard"
const HONORS: StringName = &"honors"
const OPERATORS: StringName = &"operators"
const MASTERY: StringName = &"mastery"
const HORDE: StringName = &"horde"
const FAMILIES: Array[StringName] = [STANDARD, HONORS, OPERATORS, MASTERY, HORDE]
## Family -> trait (§1.2).
const FAMILY_TRAIT: Dictionary = {
	STANDARD: &"", HONORS: SynergyRules.VANGUARD, OPERATORS: SynergyRules.SPECOPS,
	MASTERY: SynergyRules.HEAVY, HORDE: SynergyRules.UNDEAD,
}
## Player-facing family names (the public build can't use MW3's mode names).
const FAMILY_NAMES: Dictionary = {
	STANDARD: "Standard", HONORS: "Honors", OPERATORS: "Operators", MASTERY: "Mastery", HORDE: "Horde",
}
## MW3 manifest `section` prefix -> family (§1.2; the pitch tool applies the same table). Longest
## prefix wins; anything else is Standard.
const SECTION_FAMILY: Dictionary = {
	"Prestige Mastery / Multiplayer": HONORS, "Challenges / Multiplayer": HONORS,
	"Challenges / General": HONORS, "Ranked Play / Multiplayer": HONORS,
	"Standard / Store": OPERATORS, "Standard / Battle Pass": OPERATORS,
	"Standard / Armory Unlocks": OPERATORS, "Standard / Events": OPERATORS,
	"Warzone": OPERATORS, "Ranked Play / Warzone": OPERATORS, "Challenges / Warzone": OPERATORS,
	"Weapon Mastery": MASTERY,
	"Challenges / Zombies": HORDE, "Prestige Mastery / Zombies": HORDE, "Zombies": HORDE,
	"Standard / Default": STANDARD, "Standard / Miscellaneous": STANDARD, "Campaign": STANDARD,
}
const SEP: String = "~"
## Public placeholder art of each alternate family (§1.4, our own art): the chassis sprite with a
## family corner emblem and backdrop tint. Never a level camo band (Gilded / Forged / Priceless).
## family -> [subname, tint (alpha = strength), emblem]. Rendering is BannerArtDB's (UI hook).
const OPTION_VARIANTS: Dictionary = {
	HONORS: ["Honor Guard", Color(0.78, 0.62, 0.22, 0.30), &"laurel"],
	OPERATORS: ["Black Tape", Color(0.10, 0.12, 0.16, 0.40), &"tape"],
	MASTERY: ["Field Camo", Color(0.36, 0.42, 0.24, 0.36), &"camo"],
	HORDE: ["Grave Watch", Color(0.30, 0.55, 0.20, 0.38), &"rot"],
	STANDARD: ["Standard Issue", Color(0.0, 0.0, 0.0, 0.0), &""],
}

## Licensed manifest index (id -> {card, family, title}), chassis -> ids; reloaded when the folder
## settings change.
static var _rows: Dictionary = {}
static var _pool: Dictionary = {}
static var _loaded_key: String = "~unloaded"


# =============================================================================
# Family and trait of an art
# =============================================================================

## The family whose arts give trait `t` (&"" = Standard).
static func family_for_trait(t: StringName) -> StringName:
	for f: StringName in FAMILIES:
		if FAMILY_TRAIT[f] == t:
			return f
	return STANDARD


## Family of an MW3 manifest section (longest matching prefix; Standard otherwise).
static func family_for_section(section: String) -> StringName:
	var best: String = ""
	for prefix: String in SECTION_FAMILY:
		if section.begins_with(prefix) and prefix.length() > best.length():
			best = prefix
	return SECTION_FAMILY[best] if best != "" else STANDARD


## The family of the chassis' default art (its default trait's family).
static func home_family(card: CardData) -> StringName:
	return family_for_trait(card.card_trait) if card != null else STANDARD


## Family of `art_id` worn by `card` (see the header for the id forms). &"" art = the default art.
static func family_of(art_id: StringName, card: CardData) -> StringName:
	var home: StringName = home_family(card)
	if art_id == &"" or (card != null and art_id == card.id):
		return home
	var s: String = String(art_id)
	if s.contains(SEP):
		var suffix := StringName(s.get_slice(SEP, 1))
		return suffix if suffix in FAMILIES else home
	var row: Dictionary = licensed_row(art_id)
	if not row.is_empty() and StringName(String(row.get("family", ""))) in FAMILIES:
		return StringName(String(row["family"]))
	return home


## kc-art-traits §1.1: the trait a copy of `card` gets from wearing `art_id`. Printed cards keep
## their trait (art is cosmetic); an art whose family's trait is not an option makes the copy plain.
static func trait_of(art_id: StringName, card: CardData) -> StringName:
	if card == null:
		return &""
	if not card.has_trait_choice():
		return card.card_trait
	var t: StringName = FAMILY_TRAIT.get(family_of(art_id, card), &"")
	return t if card.can_carry(t) else &""


# =============================================================================
# Arts per option
# =============================================================================

## The public placeholder art of option `t` (the chassis id for the default option).
static func public_option_art(card: CardData, t: StringName) -> StringName:
	if card == null:
		return &""
	if t == card.card_trait or not card.has_trait_choice():
		return card.id
	return StringName("%s%s%s" % [card.id, SEP, family_for_trait(t)])


## Every art a copy of `card` can wear: the licensed pool (pitch build) or the chassis id and its
## public looks, plus the public placeholder art of every option no art covers yet.
static func arts_for(card: CardData) -> Array[StringName]:
	var out: Array[StringName] = []
	if card == null:
		return out
	out.append_array(licensed_ids(card.id))
	if out.is_empty():
		out.append(card.id)
		for v: Array in BannerArtDB.VARIANTS:
			out.append(StringName("%s%s%s" % [card.id, SEP, v[0]]))
	if card.has_trait_choice():
		for t: StringName in card.trait_choices():
			if not out.any(func(a: StringName) -> bool: return trait_of(a, card) == t):
				out.append(public_option_art(card, t))
	return out


## The arts of option `t` (same-trait swaps are free among these).
static func arts_with_trait(card: CardData, t: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for a: StringName in arts_for(card):
		if trait_of(a, card) == t:
			out.append(a)
	return out


## The art a new copy of option `t` wears: `equipped` (Codex EQUIP) when it gives that trait, else
## the option's first art (fairness: there always is one, free to everyone).
static func default_art(card: CardData, t: StringName, equipped: StringName = &"") -> StringName:
	if card == null:
		return &""
	if equipped != &"" and belongs(equipped, card) and trait_of(equipped, card) == t:
		return equipped
	var list: Array[StringName] = arts_with_trait(card, t)
	return list[0] if not list.is_empty() else public_option_art(card, t)


## True when `art_id` is an art of `card` (one of arts_for, or a public look of its chassis id).
static func belongs(art_id: StringName, card: CardData) -> bool:
	if card == null or art_id == &"":
		return false
	if art_id in arts_for(card):
		return true
	var s: String = String(art_id)
	return s.contains(SEP) and StringName(s.get_slice(SEP, 0)) == card.id


## UI hook: one row per trait option of `card`, default first:
## {trait, name ("Spec Ops" / "No trait"), family, family_name, default_art, arts: Array[StringName]}.
## Printed cards: one row (their trait, every art). Tactics / Operator / tokens: [].
static func options(card: CardData, equipped: StringName = &"") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if card == null:
		return out
	var choices: Array[StringName] = card.trait_choices()
	if choices.is_empty() and card.is_unit() and card.collectible:
		choices.append(&"")
	for t: StringName in choices:
		var fam: StringName = family_for_trait(t)
		var arts: Array[StringName] = arts_with_trait(card, t) if card.has_trait_choice() else arts_for(card)
		out.append({"trait": t, "name": trait_name(t), "family": fam, "family_name": FAMILY_NAMES[fam],
				"default_art": default_art(card, t, equipped) if card.has_trait_choice() else (equipped if belongs(equipped, card) else card.id),
				"arts": arts})
	return out


## "Spec Ops", or "No trait".
static func trait_name(t: StringName) -> String:
	return String(SynergyRules.TRAIT_NAMES.get(t, "No trait")) if t != &"" else "No trait"


## The art's subname (head naming: name = chassis, subname = art title): a licensed title, our
## option variant's name, a public look's name; "" for the chassis' default art.
static func subname(art_id: StringName) -> String:
	var s: String = String(art_id)
	if art_id == &"":
		return ""
	if s.contains(SEP):
		var suffix: String = s.get_slice(SEP, 1)
		if OPTION_VARIANTS.has(StringName(suffix)):
			return String(OPTION_VARIANTS[StringName(suffix)][0])
		for v: Array in BannerArtDB.VARIANTS:
			if v[0] == suffix:
				return String(v[1])
		return ""
	return String(licensed_row(art_id).get("title", ""))


# =============================================================================
# Licensed manifest (private pitch build; text only)
# =============================================================================

## Licensed art ids of a chassis, manifest order ([] without the folder).
static func licensed_ids(chassis: StringName) -> Array[StringName]:
	_ensure_loaded()
	return (_pool.get(chassis, [] as Array[StringName]) as Array[StringName]).duplicate()


## The manifest row of a licensed art id ({} when unknown or the folder is absent).
static func licensed_row(art_id: StringName) -> Dictionary:
	_ensure_loaded()
	return _rows.get(art_id, {})


static func clear_cache() -> void:
	_rows.clear()
	_pool.clear()
	_loaded_key = "~unloaded"


static func _ensure_loaded() -> void:
	var key: String = "%s|%s" % [BannerArtDB.licensed_enabled, BannerArtDB.licensed_dir]
	if key == _loaded_key:
		return
	_loaded_key = key
	_rows.clear()
	_pool.clear()
	if not BannerArtDB.licensed_enabled:
		return
	var dirs: PackedStringArray = [BannerArtDB.licensed_dir] if BannerArtDB.licensed_dir != "" else BannerArtDB.LICENSED_DIRS
	var path: String = ""
	for d: String in dirs:
		if FileAccess.file_exists(d + BannerArtDB.LICENSED_MANIFEST):
			path = d + BannerArtDB.LICENSED_MANIFEST
			break
	if path == "":
		return
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var header: PackedStringArray = f.get_csv_line()
	for i: int in header.size():
		header[i] = header[i].strip_edges().to_lower()
	while not f.eof_reached():
		var cells: PackedStringArray = f.get_csv_line()
		if cells.size() < 2:
			continue
		var row: Dictionary = {}
		for i: int in mini(cells.size(), header.size()):
			row[header[i]] = cells[i].strip_edges()
		var chassis := StringName(String(row.get("chassis", row.get("card", ""))))
		var id := StringName(String(row.get("id", "")))
		if chassis == &"" or id == &"" or _rows.has(id) or String(row.get("kind", "")) == "operator":
			continue
		_rows[id] = row
		if not _pool.has(chassis):
			_pool[chassis] = [] as Array[StringName]
		(_pool[chassis] as Array[StringName]).append(id)
