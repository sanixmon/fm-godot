# Source: engine/src/main/kotlin/com/footballmanager/simulation/Tactics.kt (Mentality enum)
# Parity notes: Kind ordinal matches Kotlin order DEFENSIVE=0 BALANCED=1 ATTACKING=2.
class_name Mentality
extends RefCounted

enum Kind { DEFENSIVE, BALANCED, ATTACKING }

const LABELS = {
	Kind.DEFENSIVE: "Defensive",
	Kind.BALANCED: "Balanced",
	Kind.ATTACKING: "Attacking",
}

const ATTACK_MOD = {
	Kind.DEFENSIVE: 0.85,
	Kind.BALANCED: 1.0,
	Kind.ATTACKING: 1.15,
}

const DEFENSE_MOD = {
	Kind.DEFENSIVE: 1.15,
	Kind.BALANCED: 1.0,
	Kind.ATTACKING: 0.85,
}


static func label(kind: int) -> String:
	return str(LABELS.get(kind, "Unknown"))


static func attack_mod(kind: int) -> float:
	return float(ATTACK_MOD.get(kind, 1.0))


static func defense_mod(kind: int) -> float:
	return float(DEFENSE_MOD.get(kind, 1.0))
