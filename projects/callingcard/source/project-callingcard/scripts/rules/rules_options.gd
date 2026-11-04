# rules_options.gd
# Purpose: Switches for the rules questions QA raised (rules-test-cases.md RQ-01..RQ-20) that are
#   cheap to keep switchable. Defaults are QA's proposed answers. The numeric tuning knobs
#   (bonuses, Signature value, tie winner, chain captures) stay in BalanceConfig.
#   RQ-08 and RQ-09 were decided by the studio head on 2026-11-04 (RQ-08 yes, RQ-09 full score);
#   each stays one flag here, defaulting to that decision.
# Dependencies: none.
# Author: Mechanics Developer Agent
class_name RulesOptions
extends RefCounted

## RQ-08 (decided 2026-11-04: yes): Showcase (store) cards get Set Link with each other like any set.
## false = the Showcase set never gives Set Link (store cards get no bonus of any kind).
var showcase_set_link: bool = true

## RQ-09 (decided 2026-11-04: full score): Clutch's "behind" check uses the full score function (true board:
## face-down cards count with their Signature value, Triptych bonuses included).
## false = the public score the players see: face-down cards count 1, no Triptych bonus.
var clutch_uses_full_score: bool = true

## RQ-02: a Cipher copies the target's printed trait (copying any Cipher card gives no trait).
## false = copy the target's active trait (a Cipher that copied Veteran passes Veteran on).
var cipher_copies_printed_trait: bool = true

## RQ-04: a Cipher holding a copied Ambush loses its spring if the placer no longer controls it
## when their next turn starts. false = it springs for its current controller.
var cancel_spring_if_lost: bool = true


func copy() -> RulesOptions:
	var o: RulesOptions = RulesOptions.new()
	o.showcase_set_link = showcase_set_link
	o.clutch_uses_full_score = clutch_uses_full_score
	o.cipher_copies_printed_trait = cipher_copies_printed_trait
	o.cancel_spring_if_lost = cancel_spring_if_lost
	return o
