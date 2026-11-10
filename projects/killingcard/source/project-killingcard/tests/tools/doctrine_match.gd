# doctrine_match.gd
# Purpose: kc-duel-tune what-if for the Doctrine rule, used by duel_sim.gd and run_v2_check.gd (docrule=...).
#   A MatchState whose synergy cache applies a different Doctrine rule; nothing in scripts/ changes.
#   rule "2only": Doctrine adds its +1 only while exactly 1 member of that trait is in play, so it turns on
#     the 2-set early but never completes a 3-set ("one unit of your Doctrine trait turns on its 2-set").
#   rule "3only": Doctrine adds +1 only from 2 real members (it completes the 3-set, never the 2-set).
#   rule "" = the shipped rule (+1 while at least 1 member is in play).
#   The AI planner still values plans with the shipped rule (AiPlanner._synergy_of_plan), a small bias.
# Author: Sr Game Designer Agent (kc-duel-tune)
extends MatchState

var rule: String = ""


func _syn_refresh() -> void:
	var sig: PackedInt32Array = _syn_signature()
	if sig == _syn_sig and _syn_sig.size() > 0:
		return
	_syn_sig = sig
	_syn_units = {}
	for si: int in 2:
		var lines: Array = synergy_lines(si)
		var fields: Array[StringName] = synergy_field_traits(si)
		var doct: StringName = sides[si].setup.doctrine
		if doct != &"" and rule != "":
			var real: int = int(SynergyRules.trait_counts(lines, fields, &"").get(doct, 0))
			if (rule == "2only" and real != 1) or (rule == "3only" and real < 2):
				doct = &""
		var res: Dictionary = SynergyRules.compute(lines, fields, doct)
		for z: int in ZONE_COUNT:
			for i: int in (lines[z] as Array).size():
				_syn_units[int(lines[z][i]["uid"])] = res["zones"][z][i]
		_syn_sides[si] = {"counts": res["counts"], "tiers": res["tiers"], "links": res["links"]}
