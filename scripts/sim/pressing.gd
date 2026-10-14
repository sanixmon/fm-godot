# Source: engine/src/main/kotlin/com/footballmanager/simulation/Tactics.kt (Pressing enum)
# Parity notes: Kind ordinal matches Kotlin order LOW=0 MEDIUM=1 HIGH=2.
class_name Pressing
extends RefCounted

enum Kind { LOW, MEDIUM, HIGH }

const LABELS = {
	Kind.LOW: "Low",
	Kind.MEDIUM: "Medium",
	Kind.HIGH: "High",
}

const BALL_WINNING_MOD = {
	Kind.LOW: 0.90,
	Kind.MEDIUM: 1.0,
	Kind.HIGH: 1.15,
}

const FATIGUE_MULT = {
	Kind.LOW: 0.85,
	Kind.MEDIUM: 1.0,
	Kind.HIGH: 1.25,
}

const COUNTER_VULN = {
	Kind.LOW: 0.90,
	Kind.MEDIUM: 1.0,
	Kind.HIGH: 1.15,
}


static func label(kind: int) -> String:
	return str(LABELS.get(kind, "Unknown"))


static func ball_winning_mod(kind: int) -> float:
	return float(BALL_WINNING_MOD.get(kind, 1.0))


static func fatigue_mult(kind: int) -> float:
	return float(FATIGUE_MULT.get(kind, 1.0))


static func counter_vuln(kind: int) -> float:
	return float(COUNTER_VULN.get(kind, 1.0))
