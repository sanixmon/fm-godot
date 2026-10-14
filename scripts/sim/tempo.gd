# Source: engine/src/main/kotlin/com/footballmanager/simulation/Tactics.kt (Tempo enum)
# Parity notes: Kind ordinal matches Kotlin order SLOW=0 NORMAL=1 FAST=2.
class_name Tempo
extends RefCounted

enum Kind { SLOW, NORMAL, FAST }

const LABELS = {
	Kind.SLOW: "Slow",
	Kind.NORMAL: "Normal",
	Kind.FAST: "Fast",
}

const POSSESSION_MULT = {
	Kind.SLOW: 1.05,
	Kind.NORMAL: 1.0,
	Kind.FAST: 0.95,
}

const FATIGUE_MULT = {
	Kind.SLOW: 0.90,
	Kind.NORMAL: 1.0,
	Kind.FAST: 1.15,
}

const CHANCE_MULT = {
	Kind.SLOW: 0.90,
	Kind.NORMAL: 1.0,
	Kind.FAST: 1.10,
}


static func label(kind: int) -> String:
	return str(LABELS.get(kind, "Unknown"))


static func possession_mult(kind: int) -> float:
	return float(POSSESSION_MULT.get(kind, 1.0))


static func fatigue_mult(kind: int) -> float:
	return float(FATIGUE_MULT.get(kind, 1.0))


static func chance_mult(kind: int) -> float:
	return float(CHANCE_MULT.get(kind, 1.0))
