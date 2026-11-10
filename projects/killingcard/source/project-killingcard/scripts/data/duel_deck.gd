# duel_deck.gd
# Purpose: kc-duel-impl (duel-mode.md §2, §5, §6.5; head D1-D5): one Duel deck = a name, a hero (an
#   Operator id), up to 10 picks {card_id, art_id} (each pick = exactly 2 copies; the art gives both
#   copies their trait) and a Doctrine trait (D5). The 4 presets are .tres files under data/duel/presets/
#   (preset = true, read-only); player decks are saved in the profile as to_dict() Dictionaries.
#   Editing methods return "" or a player-facing reason; legality (the red / amber lines) is
#   DuelRules.validate's job, so a deck can be saved while it is still being built.
#   API for the screens: documentation/technical/duel-api.md §1.
# Dependencies: CardData, ArtTraits, SynergyRules, DataValidator (CardDB load check), CardDB (optional).
# Author: Mechanics Developer Agent (kc-duel-impl)
class_name DuelDeck
extends Resource

## Picks per deck and copies per pick (DuelConfig holds the tunable numbers; these are the editing caps).
const MAX_PICKS: int = 10
const NAME_MAX: int = 20
const CARDS_DIR: String = "res://data/cards/%s.tres"
const LOADOUT_DIR: String = "res://data/loadout/%s.tres"

## Preset: spearhead / overwatch / iron_wall / hollow_ranks. Saved deck: deck_<n>. Draft: &"".
@export var id: StringName = &""
@export var display_name: String = ""
## The hero: an Operator (LoadoutItem) id, &"" = not picked yet.
@export var hero_id: StringName = &""
## [{card_id: StringName, art_id: StringName}], one row per card (&"" art = the chassis default art).
@export var picks: Array[Dictionary] = []
## D5: the deck's Doctrine trait (&"" = none).
@export var doctrine_trait: StringName = &""
## Presets: the one-line plan on the deck tile.
@export var plan: String = ""
## The 4 presets: read-only (copy to edit), every card a loaner (D3).
@export var preset: bool = false
var created: int = 0
var edited: int = 0


# =============================================================================
# Editing
# =============================================================================

func add_pick(card_id: StringName, art_id: StringName = &"") -> String:
	if preset:
		return "Preset: copy to edit"
	if has_pick(card_id):
		return "Already in your deck (x2)"
	if picks.size() >= MAX_PICKS:
		return "%d/%d: remove a pick first" % [MAX_PICKS, MAX_PICKS]
	var c: CardData = find_card(card_id)
	if c == null:
		return "Unknown card"
	if art_id != &"" and not ArtTraits.belongs(art_id, c):
		return "That art isn't one of %s's arts" % c.display_name
	picks.append({"card_id": card_id, "art_id": art_id})
	_touch()
	return ""


func remove_pick(card_id: StringName) -> bool:
	if preset:
		return false
	var i: int = pick_index(card_id)
	if i < 0:
		return false
	picks.remove_at(i)
	_touch()
	return true


## Both copies of the pick wear `art_id` (and so its trait). &"" = the default art.
func set_art(card_id: StringName, art_id: StringName) -> String:
	if preset:
		return "Preset: copy to edit"
	var i: int = pick_index(card_id)
	if i < 0:
		return "Not in this deck"
	var c: CardData = find_card(card_id)
	if c != null and art_id != &"" and not ArtTraits.belongs(art_id, c):
		return "That art isn't one of %s's arts" % c.display_name
	picks[i] = {"card_id": card_id, "art_id": art_id}
	_touch()
	return ""


func set_hero(p_hero_id: StringName) -> String:
	if preset:
		return "Preset: copy to edit"
	if p_hero_id != &"" and find_hero(p_hero_id) == null:
		return "Unknown hero"
	hero_id = p_hero_id
	_touch()
	return ""


## D5: &"" clears it.
func set_doctrine(t: StringName) -> String:
	if preset:
		return "Preset: copy to edit"
	if t != &"" and t not in SynergyRules.TRAITS:
		return "Doctrine must be a trait"
	doctrine_trait = t
	_touch()
	return ""


func rename(p_name: String) -> String:
	if preset:
		return "Preset: copy to edit"
	var n: String = p_name.strip_edges()
	if n.is_empty():
		return "Give the deck a name"
	display_name = n.left(NAME_MAX)
	_touch()
	return ""


func has_pick(card_id: StringName) -> bool:
	return pick_index(card_id) >= 0


func pick_index(card_id: StringName) -> int:
	for i: int in picks.size():
		if StringName(picks[i].get("card_id", &"")) == card_id:
			return i
	return -1


func pick_count() -> int:
	return picks.size()


func card_id_at(i: int) -> StringName:
	return StringName(picks[i].get("card_id", &"")) if i >= 0 and i < picks.size() else &""


func art_id_at(i: int) -> StringName:
	return StringName(picks[i].get("art_id", &"")) if i >= 0 and i < picks.size() else &""


## The art both copies of pick i wear (the chassis' default art when none is set).
func resolved_art(i: int) -> StringName:
	var c: CardData = find_card(card_id_at(i))
	if c == null:
		return &""
	var a: StringName = art_id_at(i)
	if a != &"" and ArtTraits.belongs(a, c):
		return a
	return ArtTraits.default_art(c, c.card_trait) if c.has_trait_choice() else c.id


## The trait both copies of pick i carry (&"" = none): the art's trait (art-traits.md).
func trait_of_pick(i: int) -> StringName:
	var c: CardData = find_card(card_id_at(i))
	if c == null:
		return &""
	var a: StringName = art_id_at(i)
	if a == &"" or not ArtTraits.belongs(a, c):
		return c.card_trait
	return ArtTraits.trait_of(a, c)


## An editable deep copy (preset off, no id): COPY and "start from a preset".
func copy() -> DuelDeck:
	var d: DuelDeck = DuelDeck.new()
	d.display_name = display_name
	d.hero_id = hero_id
	for p: Dictionary in picks:
		d.picks.append({"card_id": StringName(p.get("card_id", &"")), "art_id": StringName(p.get("art_id", &""))})
	d.doctrine_trait = doctrine_trait
	d.plan = plan
	return d


func _touch() -> void:
	edited = int(Time.get_unix_time_from_system())


# =============================================================================
# Save format (duel-mode.md §6.5)
# =============================================================================

func to_dict() -> Dictionary:
	var rows: Array = []
	for p: Dictionary in picks:
		rows.append({"card_id": String(p.get("card_id", "")), "art_id": String(p.get("art_id", ""))})
	return {"id": String(id), "name": display_name, "hero_id": String(hero_id), "picks": rows,
			"doctrine_trait": String(doctrine_trait), "created": created, "edited": edited}


## A deck from its save Dictionary. Tolerant: wrong types read as empty; an art that isn't the
## card's falls back to the default art (&""); unknown cards are kept (the validator shows them red).
static func from_dict(d: Variant) -> DuelDeck:
	var deck: DuelDeck = DuelDeck.new()
	if typeof(d) != TYPE_DICTIONARY:
		return deck
	deck.id = StringName(str(d.get("id", "")))
	deck.display_name = str(d.get("name", "")).left(NAME_MAX)
	deck.hero_id = StringName(str(d.get("hero_id", "")))
	var t := StringName(str(d.get("doctrine_trait", "")))
	deck.doctrine_trait = t if t in SynergyRules.TRAITS else &""
	deck.created = int(d.get("created", 0)) if typeof(d.get("created", 0)) in [TYPE_INT, TYPE_FLOAT] else 0
	deck.edited = int(d.get("edited", 0)) if typeof(d.get("edited", 0)) in [TYPE_INT, TYPE_FLOAT] else 0
	var rows: Variant = d.get("picks", [])
	if typeof(rows) == TYPE_ARRAY:
		for r: Variant in rows:
			if typeof(r) != TYPE_DICTIONARY:
				continue
			var cid := StringName(str(r.get("card_id", "")))
			if cid == &"":
				continue
			var aid := StringName(str(r.get("art_id", "")))
			var c: CardData = find_card(cid)
			if c != null and aid != &"" and not ArtTraits.belongs(aid, c):
				aid = &""
			deck.picks.append({"card_id": cid, "art_id": aid})
	return deck


# =============================================================================
# Lookups (CardDB when it runs, else the data files)
# =============================================================================

static func find_card(card_id: StringName) -> CardData:
	if card_id == &"":
		return null
	var db: Node = _db()
	if db != null and db.has_method(&"get_card"):
		var c: CardData = db.get_card(card_id)
		if c != null:
			return c
	var path: String = CARDS_DIR % card_id
	return load(path) as CardData if ResourceLoader.exists(path) else null


static func find_hero(hero: StringName) -> LoadoutItem:
	if hero == &"":
		return null
	var db: Node = _db()
	var item: LoadoutItem = null
	if db != null and db.has_method(&"get_loadout_item"):
		item = db.get_loadout_item(hero)
	if item == null:
		var path: String = LOADOUT_DIR % hero
		item = load(path) as LoadoutItem if ResourceLoader.exists(path) else null
	if item == null or item.slot != DataEnums.LoadoutSlot.PRIMARY:
		return null
	return item


static func _db() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"CardDB") if tree != null and tree.root != null else null


# =============================================================================
# CardDB load check (presets)
# =============================================================================

func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("display_name", display_name)
	if hero_id == &"":
		v.missing("hero_id", "a preset needs a hero")
	elif not v.index.has(String(hero_id)) or not (v.index[String(hero_id)] is LoadoutItem):
		v.broken_reference("hero_id", "hero '%s' is not a loaded LoadoutItem" % hero_id)
	if picks.size() > MAX_PICKS:
		v.out_of_range("picks", "%d picks; at most %d" % [picks.size(), MAX_PICKS])
	var seen: Dictionary = {}
	for i: int in picks.size():
		var cid := StringName(picks[i].get("card_id", &""))
		if not v.index.has(String(cid)) or not (v.index[String(cid)] is CardData):
			v.broken_reference("picks[%d]" % i, "card '%s' is not a loaded CardData" % cid)
			continue
		if seen.has(cid):
			v.invalid("picks[%d]" % i, "'%s' is picked twice (one pick per card)" % cid)
		seen[cid] = true
		var aid := StringName(picks[i].get("art_id", &""))
		if aid != &"" and not ArtTraits.belongs(aid, v.index[String(cid)] as CardData):
			v.invalid("picks[%d]" % i, "art '%s' is not an art of '%s'" % [aid, cid])
	if doctrine_trait != &"" and doctrine_trait not in SynergyRules.TRAITS:
		v.invalid("doctrine_trait", "'%s' is not a trait" % doctrine_trait)
