# coach_tips.gd
# Pattern adapted from Killstreak scripts/ui/tutorial/tutorial_progress.gd (a static record of
#   what the player has seen, read from disk on every call).
# Purpose: The first-match coach's four tips (cz13) and which ones this device has seen
#   (SetupPrefs [coach]). Each tip shows the first time its concept comes up in a match:
#     hold        the first Pack (END TURN opens Pack: choose cards to Hold)
#     brace       the first time the human must Brace
#     down        the first time anyone is Down (a Hit in their next draw)
#     adrenaline  the first time the human has a Hit in hand on their turn
#   due(view, mode) says which unseen tips the situation calls for; the overlay shows them one at
#   a time. SKIP ALL marks every tip seen; reset() (pause menu / title settings) shows them again.
#   Texts follow the rules in force (hold_limit, down_value, adrenaline_mode from the view's
#   balance, passed in as `rules`).
# Dependencies: setup_prefs.gd.
# Author: UI/UX Agent (cz13)
extends RefCounted

const SetupPrefs: GDScript = preload("res://scripts/ui/setup_prefs.gd")
const SECTION: String = "coach"
const TIPS: Array[StringName] = [&"hold", &"brace", &"down", &"adrenaline"]


static func is_seen(tip: StringName) -> bool:
	return bool(SetupPrefs.get_value(SECTION, String(tip), false))


static func mark_seen(tip: StringName) -> void:
	SetupPrefs.set_value(SECTION, String(tip), true)


static func mark_all_seen() -> void:
	for t: StringName in TIPS:
		mark_seen(t)


static func seen_count() -> int:
	return TIPS.filter(func(t: StringName) -> bool: return is_seen(t)).size()


static func reset() -> void:
	SetupPrefs.clear_section(SECTION)


## Unseen tips the situation calls for, in show order. view = the human's MatchController.view(),
## mode = the match screen's mode (&"act", &"pack", &"brace", &"opponent", ...), hand_has_hit = a
## Hit is in the human's hand.
static func due(view: Dictionary, mode: StringName, hand_has_hit: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	if view.is_empty() or not (view.get("match_end", {}) as Dictionary).is_empty():
		return out
	if mode == &"brace" or view.has("brace_prompt"):
		out.append(&"brace")
	if mode == &"pack":
		out.append(&"hold")
	if bool(view.get("me", {}).get("down", false)) or bool(view.get("opponent", {}).get("down", false)):
		out.append(&"down")
	if hand_has_hit and mode in [&"act", &"pack", &"aim"]:
		out.append(&"adrenaline")
	return out.filter(func(t: StringName) -> bool: return not is_seen(t))


## {title, text} for a tip. rules: {hold_limit, down_value, move_only, me_down}.
static func text(tip: StringName, rules: Dictionary = {}) -> Dictionary:
	var limit: int = int(rules.get("hold_limit", 2))
	var down: int = int(rules.get("down_value", 1))
	match tip:
		&"hold":
			return {"title": "KEEP CARDS (HOLD)", "text": ("Tap up to %d card%s in your hand to keep them: they stay on top of your " +
					"deck and start your next hand (a shield card there blocks shots). Everything else goes under your deck. Then END TURN.") % [
					limit, "" if limit == 1 else "s"]}
		&"brace":
			return {"title": "BLOCK THE SHOT (BRACE)", "text": "You've been shot. Your NEXT HAND is open above your hand: tap cards with a " +
					"shield to block (each point stops 1 Hit), or USE SUGGESTED. Blocking cards go to the bottom of your deck."}
		&"down":
			var who: String = "You are" if bool(rules.get("me_down", false)) else "A player is"
			return {"title": "DOWN", "text": ("%s DOWN: a Hit sits in the next hand. Every shot at a Down player deals " +
					"%d less. PATCH UP or Heal puts Hits back on your health.") % [who, down]}
		&"adrenaline":
			var what: String = "MOVE +1" if bool(rules.get("move_only", false)) else "MOVE +1 or SEARCH +1"
			return {"title": "ADRENALINE", "text": ("A Hit in your hand is a free extra card: tap it and play it for %s. " +
					"Or PATCH UP (2 Search) to get the health back.") % what}
	return {"title": "", "text": ""}
