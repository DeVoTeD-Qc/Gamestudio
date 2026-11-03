# tutorial_step.gd
# Purpose: One coach step of the tutorial match (p15), embedded in TutorialScript.steps in play
#   order. A step shows a short coach card, frames a highlight target on the real match UI and
#   waits for one advancing action. With lock_input on, only that action works (the coach
#   overlay blocks taps outside the highlight and the controller refuses other plays).
# Dependencies: DataValidator.
# Author: UI/UX Agent (p15)
class_name TutorialStep
extends Resource

## What ends the step.
const ADVANCE_ON: Array[StringName] = [
	&"next",            # the coach card's NEXT button (or Enter / Space)
	&"place_operator",  # the Operator is placed in `zone`
	&"play_card",       # a hand card with id `card_id` is played to `zone`
	&"use_item",        # loadout item / killstreak `item_id` is queued
	&"ready",           # READY is pressed (the round starts resolving)
	&"round_end",       # the resolved round has finished playing
	&"match_end",       # the match has ended (last step)
]
## What the coach frames. &"auto" picks it from advance_on (Operator / hand card, then the lane;
## the item button; READY).
const HIGHLIGHTS: Array[StringName] = [
	&"auto", &"none", &"operator", &"hand_card", &"lane", &"ready", &"streak", &"killstreak",
	&"minimap", &"score",
]
## Coach text must stay short enough to read on a phone at a glance.
const MAX_TEXT: int = 120
const MAX_TITLE: int = 16

## 1-based, sent as EventBus.tutorial_step(index) when the step starts (p16 logger).
@export var index: int = 0
## Round the step belongs to (checked against the match while it runs).
@export_range(1, 8) var round_number: int = 1
## Short caption in capitals (DEPLOY, STREAK...).
@export var title: String = ""
## One or two short sentences. "{intel}" is replaced by the revealed enemy cards (Recon Drone).
@export_multiline var text: String = ""
@export var advance_on: StringName = &"next"
@export var highlight: StringName = &"auto"
## Card id for play_card / hand_card.
@export var card_id: StringName = &""
## Zone 0 = Left, 1 = Mid, 2 = Right; -1 = none.
@export_range(-1, 2) var zone: int = -1
## Loadout / killstreak id for use_item / killstreak.
@export var item_id: StringName = &""
## Only the advancing action works (taps elsewhere are blocked, other plays refused).
@export var lock_input: bool = false
## Forced earn: put this killstreak in the player's Streak Tray when the step starts, if it is
## not there yet (the scripted firefight normally earns it already).
@export var grant_killstreak: StringName = &""


## Highlight with &"auto" resolved.
func resolved_highlight() -> StringName:
	if highlight != &"auto":
		return highlight
	match advance_on:
		&"place_operator":
			return &"operator"
		&"play_card":
			return &"hand_card"
		&"use_item":
			return &"killstreak"
		&"ready":
			return &"ready"
	return &"none"


func validate(v: DataValidator, prefix: String) -> void:
	v.require_text(prefix + ".text", text)
	if text.length() > MAX_TEXT:
		v.out_of_range(prefix + ".text", "%d characters (max %d, it must read at a glance on a phone)" % [text.length(), MAX_TEXT])
	if title.length() > MAX_TITLE:
		v.out_of_range(prefix + ".title", "%d characters (max %d)" % [title.length(), MAX_TITLE])
	if advance_on not in ADVANCE_ON:
		v.invalid(prefix + ".advance_on", "'%s' is not one of %s" % [advance_on, ", ".join(PackedStringArray(ADVANCE_ON))])
	if highlight not in HIGHLIGHTS:
		v.invalid(prefix + ".highlight", "'%s' is not one of %s" % [highlight, ", ".join(PackedStringArray(HIGHLIGHTS))])
	v.check_range(prefix + ".zone", zone, -1, 2)
	if advance_on in [&"place_operator", &"play_card"] and zone < 0:
		v.missing(prefix + ".zone", "%s needs a zone" % advance_on)
	if (advance_on == &"play_card" or resolved_highlight() == &"hand_card") and card_id == &"":
		v.missing(prefix + ".card_id", "needs the card id to play / highlight")
	if (advance_on == &"use_item" or resolved_highlight() == &"killstreak") and item_id == &"":
		v.missing(prefix + ".item_id", "needs the item id to use / highlight")
	if resolved_highlight() == &"lane" and zone < 0:
		v.missing(prefix + ".zone", "a lane highlight needs a zone")
	if card_id != &"" and not v.index.has(String(card_id)):
		v.broken_reference(prefix + ".card_id", "'%s' is not a loaded card" % card_id)
	for f: String in ["item_id", "grant_killstreak"]:
		var ref: StringName = get(f)
		if ref != &"" and not v.index.has(String(ref)):
			v.broken_reference(prefix + "." + f, "'%s' is not a loaded loadout item" % ref)
