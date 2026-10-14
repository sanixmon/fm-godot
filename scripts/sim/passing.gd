# Source: engine/src/main/kotlin/com/footballmanager/simulation/Tactics.kt (Passing enum)
# Parity notes: Kind ordinal matches Kotlin order SHORT=0 MIXED=1 DIRECT=2.
class_name Passing
extends RefCounted

enum Kind { SHORT, MIXED, DIRECT }

const LABELS = {
	Kind.SHORT: "Short",
	Kind.MIXED: "Mixed",
	Kind.DIRECT: "Direct",
}

const POSSESSION_MOD = {
	Kind.SHORT: 1.05,
	Kind.MIXED: 1.0,
	Kind.DIRECT: 0.92,
}

const DIRECTNESS_MOD = {
	Kind.SHORT: 0.90,
	Kind.MIXED: 1.0,
	Kind.DIRECT: 1.15,
}


static func label(kind: int) -> String:
	return str(LABELS.get(kind, "Unknown"))


static func possession_mod(kind: int) -> float:
	return float(POSSESSION_MOD.get(kind, 1.0))


static func directness_mod(kind: int) -> float:
	return float(DIRECTNESS_MOD.get(kind, 1.0))
