# Source: engine/src/main/kotlin/com/footballmanager/simulation/MatchEvent.kt (Side enum)
# Parity notes: Kind ordinal matches Kotlin order HOME=0 AWAY=1.
class_name Side
extends RefCounted

enum Kind { HOME, AWAY }


static func label(kind: int) -> String:
	match kind:
		Kind.HOME:
			return "Home"
		Kind.AWAY:
			return "Away"
	return "Unknown"


static func opposite(kind: int) -> int:
	return Kind.AWAY if kind == Kind.HOME else Kind.HOME
