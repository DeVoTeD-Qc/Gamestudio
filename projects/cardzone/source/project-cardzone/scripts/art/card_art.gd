# card_art.gd
# Purpose: Procedural card art for CardZone (cz16), adapted from CallingCard's CardArt.
#   1) read(card): turns a card Dictionary or Resource (cz05 CardData later; tests/tools/art_samples.gd
#      now) into one normalised view-model Dictionary that CzCard draws from. Aliases are accepted so
#      the future CardData field names and mock dictionaries both work.
#   2) draw_art(ci, rect, info, full, px_per_pt): the art window. One generic gear silhouette in basalt
#      on dune (art-direction.md section 6), a faint type pattern (weapon range ruler, item crate slats,
#      attachment rail teeth), a fictional island stencil code ("RH-03"), and on the inspector card an
#      area backdrop (sea, scrub ridge, the area glyph). Hit and Bounty cards draw their own mark.
#   3) draw_back(ci, rect, px_per_pt): the face-down card back (opponent hand).
# Usage:
#   var info: Dictionary = CzCardArt.read({"id": "CZ-014", "name": "Pump Shotgun", "type": "weapon",
#       "rarity": "U", "cost": 4, "dmg": 3, "rng": 0})
#   CzCardArt.silhouette_for(info) -> &"pump_shotgun"
# Dependencies: CzArtKit, CzIcons
# Author: Technical Artist Agent (cz16)
class_name CzCardArt
extends RefCounted

## Name keyword -> silhouette, checked in order (first match wins).
const ART_KEYWORDS: Array = [
	["sidearm", &"sidearm"], ["smg", &"smg"], ["shotgun", &"pump_shotgun"], ["hunting", &"hunting_rifle"],
	["assault", &"assault_rifle"], ["marksman", &"marksman_rifle"], ["lmg", &"lmg"], ["longshot", &"anti_materiel"],
	[".50", &"anti_materiel"], ["scope", &"long_scope"], ["red-dot", &"red_dot"], ["red dot", &"red_dot"],
	["mag", &"ext_mag"], ["suppressor", &"suppressor"], ["frag", &"frag"], ["smoke", &"smoke"],
	["heavy plate", &"heavy_plate"], ["plate", &"plate_vest"], ["vest", &"plate_vest"], ["phantom", &"phantom_suit"],
	["boot", &"boots"], ["bandage", &"bandage"], ["medkit", &"medkit"], ["crowbar", &"crowbar"],
	["backpack", &"backpack"], ["drone", &"drone"], ["scavenge", &"pouch"], ["dash", &"dash"], ["duck", &"duck"],
]
## Fallback silhouette by type when the name matches nothing.
const TYPE_ART: Dictionary = {&"weapon": &"assault_rifle", &"attachment": &"red_dot", &"item": &"pouch"}
## Keywords bolded in inspector effect text (spec section 6, plus stat words).
const KEYWORDS: Array[String] = ["Move", "Search", "Shoot", "Brace", "Heal", "Pull", "Spent", "Attach",
	"Down", "Adrenaline", "Free draw", "Ignores Cover", "DMG", "RNG"]
## Fallback when no BalanceConfig is reachable: spec §16.4a default for supply_drop_cost.
const DROP_COST_DEFAULT: int = 4
## Area ids, for backdrops and the map.
const AREA_IDS: Array[StringName] = [&"docks", &"farmstead", &"quarry", &"radio_hill", &"motel", &"rail_yard", &"old_town"]


## Plain Dictionary from a Dictionary or an Object (Resource): storage properties, then the object's
## to_dict() on top when it has one (cz05 CardData.to_dict() turns its int enums into names/letters).
static func as_dict(card: Variant) -> Dictionary:
	if card is Dictionary:
		return card
	var d: Dictionary = {}
	if card is Object:
		var o: Object = card
		for p: Dictionary in o.get_property_list():
			if int(p["usage"]) & PROPERTY_USAGE_STORAGE != 0 and not String(p["name"]).begins_with("resource_") \
					and String(p["name"]) != "script":
				d[String(p["name"])] = o.get(p["name"])
		if o.has_method("to_dict"):
			var extra: Variant = o.call("to_dict")
			if extra is Dictionary:
				for key: Variant in extra:
					d[String(key)] = extra[key]
	return d


## First present, non-null field among the aliases.
static func field(d: Dictionary, keys: Array, default: Variant = null) -> Variant:
	for k: String in keys:
		if d.has(k) and d[k] != null:
			return d[k]
		if d.has(StringName(k)) and d[StringName(k)] != null:
			return d[StringName(k)]
	return default


## Integer stat, or -1 when absent / "-" / "–" / null.
static func stat(d: Dictionary, keys: Array) -> int:
	var v: Variant = field(d, keys, null)
	if v == null:
		return -1
	if v is int or v is float:
		return int(v)
	var s: String = str(v).strip_edges()
	if s == "" or s == "-" or s == "–" or not s.is_valid_int():
		return -1
	return s.to_int()


## The normalised view-model CzCard draws from.
static func read(card: Variant) -> Dictionary:
	var d: Dictionary = as_dict(card)
	var info: Dictionary = {}
	var type: StringName = CzArtKit.type_key(field(d, ["type", "card_type", "kind"], "item"))
	info["type"] = type
	# Printed number (CZ-014) first; cz05 CardData keeps its snake_case id in "id" and the number in "code".
	info["id"] = str(field(d, ["code", "id", "card_id"], ""))
	info["name"] = str(field(d, ["name", "display_name", "title"], CzArtKit.TYPE_WORDS.get(type, "CARD")))
	info["short_name"] = str(field(d, ["short_name", "short"], ""))
	var rar_raw: Variant = field(d, ["rarity"], "")
	var starter: bool = bool(field(d, ["starter", "is_starter"], false)) or str(rar_raw).to_lower() == "starter"
	info["rarity"] = &"" if (starter or type == &"hit" or type == &"bounty") else CzArtKit.rarity_key(rar_raw)
	info["starter"] = starter
	info["drop"] = bool(field(d, ["drop", "supply_drop", "is_drop"], false))
	# Cost 0 = never looted (starters, Hit, Bounty): no disc. A supply drop with cost 0 shows the drop cost.
	var cost: int = stat(d, ["cost", "search_cost", "loot_cost"])
	if cost <= 0:
		cost = stat(d, ["drop_cost"]) if info["drop"] else -1
		if info["drop"] and cost <= 0:
			cost = drop_cost()
	info["cost"] = cost
	info["brace"] = stat(d, ["brace", "brace_value"])
	info["dmg"] = stat(d, ["dmg", "damage"])
	info["rng"] = stat(d, ["rng", "range"])
	info["move"] = maxi(0, stat(d, ["move"]))
	info["search"] = maxi(0, stat(d, ["search"]))
	info["heal"] = maxi(0, stat(d, ["heal"]))
	info["pull"] = maxi(0, stat(d, ["pull"]))
	info["blast"] = maxi(0, stat(d, ["blast_dmg", "blast"]))
	var spent: Variant = field(d, ["spent"], false)
	info["spent"] = (spent is bool and spent) or ((spent is int or spent is float) and int(spent) > 0)
	info["ignores_cover"] = bool(field(d, ["ignores_cover"], false))
	info["fires_twice"] = bool(field(d, ["fires_twice", "double_fire"], false)) or int(field(d, ["fires_per_turn", "fires"], 1)) >= 2
	var attach: Variant = field(d, ["attach", "attach_bonus"], null)
	if not (attach is Dictionary):
		attach = {}
		if int(field(d, ["attach_dmg"], 0)) > 0:
			attach["dmg"] = int(d["attach_dmg"])
		if int(field(d, ["attach_rng"], 0)) > 0:
			attach["rng"] = int(d["attach_rng"])
		if int(field(d, ["attach_extra_fire"], 0)) > 0:
			attach["extra_shot"] = true
		if bool(field(d, ["attach_no_brace"], false)):
			attach["no_brace"] = true
	info["attach"] = attach
	info["attach_text"] = str(field(d, ["attach_text"], attach_text(info["attach"])))
	info["effect"] = str(field(d, ["effect", "text", "rules_text"], ""))
	var art: String = str(field(d, ["art", "silhouette", "art_key"], ""))
	info["art"] = StringName(art) if CzIcons.has_silhouette(StringName(art)) else silhouette_for(info)
	info["area"] = StringName(str(field(d, ["area", "where", "home_area"], "")).to_lower().replace(" ", "_"))
	info["stencil"] = str(field(d, ["stencil", "marking"], stencil_code(info["id"], info["name"])))
	return info


## Search cost of a supply drop: CardDB's BalanceConfig.supply_drop_cost (a supply-drop CardData has
## cost 0), else DROP_COST_DEFAULT. A card dictionary may also carry its own "drop_cost".
static func drop_cost() -> int:
	var ml: MainLoop = Engine.get_main_loop()
	if ml is SceneTree:
		var db: Node = (ml as SceneTree).root.get_node_or_null("CardDB")
		if db != null and db.has_method("get_balance"):
			var bal: Object = db.call("get_balance")
			if bal != null and "supply_drop_cost" in bal:
				return int(bal.get("supply_drop_cost"))
	return DROP_COST_DEFAULT


## "+1 DMG" style strip text from an attach dictionary.
static func attach_text(a: Dictionary) -> String:
	if a.is_empty():
		return ""
	var parts: PackedStringArray = []
	if int(a.get("dmg", 0)) != 0:
		parts.append("%+d DMG" % int(a["dmg"]))
	if int(a.get("rng", 0)) != 0:
		parts.append("%+d RNG" % int(a["rng"]))
	if bool(a.get("extra_shot", false)):
		parts.append("FIRES TWICE")
	if bool(a.get("no_brace", false)):
		parts.append("NO BRACE")
	return " · ".join(parts)


static func silhouette_for(info: Dictionary) -> StringName:
	var t: StringName = info.get("type", &"item")
	if t == &"hit" or t == &"bounty":
		return t
	var n: String = (str(info.get("name", "")) + " " + str(info.get("short_name", ""))).to_lower()
	for pair: Array in ART_KEYWORDS:
		if n.contains(pair[0]) and CzIcons.has_silhouette(pair[1]):
			return pair[1]
	return TYPE_ART.get(t, &"pouch")


## Fictional island stencil marking (section 6): "RH-03", "CRATE 7"... stable per card.
static func stencil_code(id: String, name: String) -> String:
	var h: int = absi(hash(id + name))
	if h % 3 == 0:
		return "CRATE %d" % (h % 9 + 1)
	return "RH-%02d" % (h % 40 + 1)


# --- Drawing -----------------------------------------------------------------------------------------
## The art window. rect in local px; k = px per pt (all measures below are in pt).
static func draw_art(ci: CanvasItem, rect: Rect2, info: Dictionary, full: bool, k: float, screen_scale: float = 1.0) -> void:
	var type: StringName = info.get("type", &"item")
	ci.draw_rect(rect, CzArtKit.DUNE)
	if full:
		_draw_backdrop(ci, rect, info, k, screen_scale)
	_draw_type_pattern(ci, rect, type, k)
	var art: StringName = info.get("art", &"")
	var ink: Color = CzArtKit.BASALT
	if type == &"hit" or type == &"bounty":
		var px: float = minf(rect.size.y * 0.78, rect.size.x * 0.6)
		var tex: Texture2D = CzIcons.get_icon(type, px * screen_scale)
		if tex != null:
			var col: Color = CzArtKit.HIT_RED.darkened(0.15) if type == &"hit" else ink
			ci.draw_texture_rect(tex, Rect2(rect.get_center() - Vector2(px, px) * 0.5, Vector2(px, px)), false, col)
		return
	var sil: Texture2D = null
	var scale: float = 0.94 if type == &"weapon" else 0.8
	var avail: Vector2 = rect.size - Vector2(4.0, 4.0) * k
	var w: float = minf(avail.x, avail.y * 96.0 / 40.0) * scale
	var sz := Vector2(w, w * 40.0 / 96.0)
	sil = CzIcons.silhouette(art, w * screen_scale)
	var pos: Vector2 = rect.get_center() - sz * 0.5
	if full:
		pos.y = rect.end.y - sz.y - 10.0 * k  # stands on the ground line of the backdrop
	if sil != null:
		ci.draw_texture_rect(sil, Rect2(pos, sz), false, ink)
	# Stencil marking, bottom-left of the window, in rust (decorative; 8 pt floor for numerals).
	var font: Font = CzArtKit.font_mono()
	var fs: int = int(ceilf((8.0 if not full else 9.0) * k))
	var code: String = str(info.get("stencil", ""))
	if code != "" and full:  # cz-clarity: decorative only, so not on the small cards (read as a stat)
		var base := Vector2(rect.position.x + 3.0 * k, rect.end.y - 3.0 * k)
		ci.draw_string(font, base, code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(CzArtKit.RUST, 0.9))


## Faint type pattern (procedural variation by type): kept at low alpha so the silhouette wins.
static func _draw_type_pattern(ci: CanvasItem, r: Rect2, type: StringName, k: float) -> void:
	var col := Color(CzArtKit.BASALT, 0.13)
	match type:
		&"weapon":
			# Range ruler along the top edge: ticks every 6 pt, long tick every 4th.
			var x: float = r.position.x + 3.0 * k
			var i: int = 0
			while x < r.end.x - 2.0 * k:
				var h: float = (5.0 if i % 4 == 0 else 2.5) * k
				ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + h), col, maxf(1.0, k), false)
				x += 6.0 * k
				i += 1
		&"item":
			# Crate slats: three horizontal planks with stencil gaps.
			for j: int in 3:
				var y: float = r.position.y + r.size.y * (0.22 + 0.28 * float(j))
				ci.draw_line(Vector2(r.position.x, y), Vector2(r.position.x + r.size.x * 0.46, y), col, maxf(1.0, 2.0 * k))
				ci.draw_line(Vector2(r.position.x + r.size.x * 0.54, y), Vector2(r.end.x, y), col, maxf(1.0, 2.0 * k))
		&"attachment":
			# Rail teeth along the bottom.
			var x2: float = r.position.x + 2.0 * k
			while x2 < r.end.x - 3.0 * k:
				ci.draw_rect(Rect2(Vector2(x2, r.end.y - 4.0 * k), Vector2(3.0 * k, 4.0 * k)), col)
				x2 += 6.0 * k
		&"hit":
			# Warning hatch in the corners.
			for j: int in 4:
				var o: float = float(j) * 6.0 * k
				ci.draw_line(Vector2(r.position.x + o, r.position.y), Vector2(r.position.x, r.position.y + o),
						Color(CzArtKit.HIT_RED, 0.18), maxf(1.0, 2.0 * k))
				ci.draw_line(Vector2(r.end.x - o, r.end.y), Vector2(r.end.x, r.end.y - o), Color(CzArtKit.HIT_RED, 0.18), maxf(1.0, 2.0 * k))
		&"bounty":
			ci.draw_arc(r.get_center(), r.size.y * 0.46, 0.0, TAU, 48, col, maxf(1.0, 2.0 * k))


## Inspector backdrop: sea band, scrub ridge, ground line and the home area's glyph, all muted.
static func _draw_backdrop(ci: CanvasItem, r: Rect2, info: Dictionary, k: float, screen_scale: float) -> void:
	var horizon: float = r.position.y + r.size.y * 0.42
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, horizon - r.position.y)), CzArtKit.DUNE.lerp(Color.WHITE, 0.25))
	ci.draw_rect(Rect2(Vector2(r.position.x, horizon - 7.0 * k), Vector2(r.size.x, 7.0 * k)), Color(CzArtKit.SHOAL, 0.45))
	var pts := PackedVector2Array([Vector2(r.position.x, horizon + 2.0 * k)])
	var steps: int = 8
	var seed: int = absi(hash(str(info.get("id", ""))))
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		var bump: float = float((seed >> (i % 16)) % 7) * k
		pts.append(Vector2(r.position.x + r.size.x * t, horizon - 2.0 * k - bump))
	pts.append(Vector2(r.end.x, horizon + 6.0 * k))
	pts.append(Vector2(r.position.x, horizon + 6.0 * k))
	ci.draw_colored_polygon(pts, Color(CzArtKit.SCRUB, 0.55))
	ci.draw_line(Vector2(r.position.x, r.end.y - 10.0 * k), Vector2(r.end.x, r.end.y - 10.0 * k), Color(CzArtKit.BASALT, 0.25), maxf(1.0, k))
	var area: StringName = info.get("area", &"")
	if area in AREA_IDS:
		var gp: float = r.size.y * 0.42
		var g: Texture2D = CzIcons.area_glyph(area, gp * screen_scale)
		if g != null:
			ci.draw_texture_rect(g, Rect2(Vector2(r.end.x - gp - 6.0 * k, horizon - gp + 4.0 * k), Vector2(gp, gp)), false, Color(1, 1, 1, 0.35))


## Face-down card back: ink plate, violet stencil hatch and a safe-zone ring.
static func draw_back(ci: CanvasItem, r: Rect2, k: float, screen_scale: float = 1.0) -> void:
	ci.draw_rect(r, CzArtKit.INK)
	var step: float = 8.0 * k
	var x: float = r.position.x - r.size.y
	while x < r.end.x:
		var a := Vector2(maxf(x, r.position.x), r.position.y + maxf(0.0, r.position.x - x))
		var b := Vector2(minf(x + r.size.y, r.end.x), r.position.y + minf(r.size.y, r.end.x - x))
		ci.draw_line(a, b, Color(CzArtKit.ZONE_DUSK, 0.8), maxf(1.0, 2.0 * k))
		x += step
	var px: float = minf(r.size.x, r.size.y) * 0.55
	var tex: Texture2D = CzIcons.get_icon(&"safe_zone", px * screen_scale)
	if tex != null:
		ci.draw_texture_rect(tex, Rect2(r.get_center() - Vector2(px, px) * 0.5, Vector2(px, px)), false, CzArtKit.ZONE_EDGE)
