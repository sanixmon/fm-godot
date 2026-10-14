# Source: engine/src/main/kotlin/com/footballmanager/simulation/Tactics.kt (Formation enum)
# Parity notes:
# - Kind ordinal matches Kotlin declaration order (FOUR_FOUR_TWO=0 .. THREE_FIVE_TWO=3).
# - Position slot ints assume Position.Kind ordinals: GK=0 CB=1 LB=2 RB=3 DM=4
#   CM=5 AM=6 LW=7 RW=8 ST=9 (other batch's Position contract).
# - Tactics holds `formation: int` (a Kind value). SLOTS arrays must be duplicated
#   by callers (see slots()) because const Arrays are shared.
class_name Formation
extends RefCounted

enum Kind { FOUR_FOUR_TWO, FOUR_THREE_THREE, FOUR_TWO_THREE_ONE, THREE_FIVE_TWO }

const LABELS = {
	Kind.FOUR_FOUR_TWO: "4-4-2",
	Kind.FOUR_THREE_THREE: "4-3-3",
	Kind.FOUR_TWO_THREE_ONE: "4-2-3-1",
	Kind.THREE_FIVE_TWO: "3-5-2",
}

const ATTACK_MOD = {
	Kind.FOUR_FOUR_TWO: 1.00,
	Kind.FOUR_THREE_THREE: 1.10,
	Kind.FOUR_TWO_THREE_ONE: 1.05,
	Kind.THREE_FIVE_TWO: 1.00,
}

const DEFENSE_MOD = {
	Kind.FOUR_FOUR_TWO: 1.00,
	Kind.FOUR_THREE_THREE: 0.90,
	Kind.FOUR_TWO_THREE_ONE: 0.95,
	Kind.THREE_FIVE_TWO: 1.05,
}

# Kind -> 11 Position.Kind ints, index 0 is always the GK slot.
# Literals used (instead of Position.Kind.X) so this const never depends on
# another script at parse time. Order per position: GK CB LB RB DM CM AM LW RW ST.
const SLOTS = {
	Kind.FOUR_FOUR_TWO: [0, 2, 1, 1, 3, 7, 5, 5, 8, 9, 9],
	Kind.FOUR_THREE_THREE: [0, 2, 1, 1, 3, 4, 5, 6, 7, 9, 8],
	Kind.FOUR_TWO_THREE_ONE: [0, 2, 1, 1, 3, 4, 5, 7, 6, 8, 9],
	Kind.THREE_FIVE_TWO: [0, 1, 1, 1, 2, 4, 5, 6, 3, 9, 9],
}


static func is_valid(kind: int) -> bool:
	return SLOTS.has(kind)


static func label(kind: int) -> String:
	return str(LABELS.get(kind, "Unknown"))


static func attack_mod(kind: int) -> float:
	return float(ATTACK_MOD.get(kind, 1.0))


static func defense_mod(kind: int) -> float:
	return float(DEFENSE_MOD.get(kind, 1.0))


static func slots(kind: int) -> Array:
	var out: Array = []
	for v in SLOTS.get(kind, []):
		out.append(int(v))
	return out
