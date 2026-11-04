# unlock_goal.gd
# Purpose: How the demo "earns" a locked card (spec §6 "Demo start", §7; plan cc09).
#   A locked CardData points at its goal (CardData.unlock_goal). Rivals and Dossiers are
#   named by id (target_id), not referenced, so goal -> rival -> lineup card -> goal can't loop.
#   One goal = one .tres in res://data/unlocks/.
# Dependencies: DataEnums, RivalData, DossierData, DataValidator.
# Author: Mechanics Developer Agent
class_name UnlockGoal
extends Resource

@export_group("Identity")
## Unique id, lowercase snake_case (e.g. unlock_win_streak_3).
@export var id: StringName = &""
@export var kind: DataEnums.UnlockKind = DataEnums.UnlockKind.WIN_STREAK
## Album text under the silhouette, e.g. "Win 3 duels in a row".
@export var description: String = ""

@export_group("Target")
## WIN_STREAK / CAPTURES_TOTAL / WINS_TOTAL: how many (>= 1).
## BEAT_RIVAL / BEAT_RIVAL_NO_LEGEND: how many qualifying wins against the rival (0 or 1 = once).
## DOSSIER_CLEAR / CIPHER_LOCK: leave 0.
@export_range(0, 999) var target_count: int = 0
## BEAT_RIVAL / BEAT_RIVAL_NO_LEGEND: a RivalData id. DOSSIER_CLEAR: a DossierData id. Others: empty.
@export var target_id: StringName = &""


## Kinds that read target_count. For the rival kinds a count of 0 or 1 means a single win
## (cc09: Long Watch needs 2 Warden wins without a Legend), so older data stays valid.
func needs_count() -> bool:
	return kind in [DataEnums.UnlockKind.WIN_STREAK, DataEnums.UnlockKind.CAPTURES_TOTAL, DataEnums.UnlockKind.WINS_TOTAL,
			DataEnums.UnlockKind.BEAT_RIVAL, DataEnums.UnlockKind.BEAT_RIVAL_NO_LEGEND]


## Rival kinds: the count is optional (0 = once).
func count_optional() -> bool:
	return kind in [DataEnums.UnlockKind.BEAT_RIVAL, DataEnums.UnlockKind.BEAT_RIVAL_NO_LEGEND]


func required_count() -> int:
	return maxi(target_count, 1)


func validate(v: DataValidator) -> void:
	v.require_id(id)
	v.require_text("description", description)
	v.check_line("description", description, 60)
	if not v.check_enum("kind", kind, DataEnums.UnlockKind):
		return
	if needs_count():
		v.check_range("target_count", target_count, 0 if count_optional() else 1, 999)
	elif target_count != 0:
		v.invalid("target_count", "only WIN_STREAK, CAPTURES_TOTAL, WINS_TOTAL, BEAT_RIVAL and BEAT_RIVAL_NO_LEGEND use a count")
	match kind:
		DataEnums.UnlockKind.BEAT_RIVAL, DataEnums.UnlockKind.BEAT_RIVAL_NO_LEGEND:
			v.check_id_ref("target_id", target_id, RivalData)
		DataEnums.UnlockKind.DOSSIER_CLEAR:
			v.check_id_ref("target_id", target_id, DossierData)
		_:
			if not String(target_id).is_empty():
				v.invalid("target_id", "%s doesn't use a target id" % DataEnums.key_of(DataEnums.UnlockKind, kind))
