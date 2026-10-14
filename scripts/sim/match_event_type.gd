# Source: engine/src/main/kotlin/com/footballmanager/simulation/MatchEvent.kt (MatchEventType enum)
# Parity notes: Kind ordinal matches Kotlin order, including the SHOT_SAVED /
# SHOT_MISSED backward-compatibility aliases at the end (12, 13).
class_name MatchEventType
extends RefCounted

enum Kind {
	POSSESSION,
	ATTACK,
	SHOT,
	SHOT_ON_TARGET,
	GOAL,
	SAVE,
	CORNER,
	FOUL,
	YELLOW_CARD,
	RED_CARD,
	INJURY,
	SUBSTITUTION,
	SHOT_SAVED,
	SHOT_MISSED,
}


static func label(kind: int) -> String:
	var names: Array[String] = [
		"Possession", "Attack", "Shot", "Shot on target", "Goal", "Save",
		"Corner", "Foul", "Yellow card", "Red card", "Injury", "Substitution",
		"Shot saved", "Shot missed",
	]
	if kind >= 0 and kind < names.size():
		return names[kind]
	return "Unknown"
