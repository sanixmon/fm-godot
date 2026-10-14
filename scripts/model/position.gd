# Source: engine/.../model/Position.kt (PositionGroup, Position, PositionWeights,
# PlayerAttributes.overall). Weights are copied verbatim for sim parity.
class_name Position
extends RefCounted

enum Kind {
	GK,
	CB,
	LB,
	RB,
	DM,
	CM,
	AM,
	LW,
	RW,
	ST,
}

enum Group {
	GOALKEEPER,
	DEFENDER,
	MIDFIELDER,
	ATTACKER,
}

const NAMES: Array = ["GK", "CB", "LB", "RB", "DM", "CM", "AM", "LW", "RW", "ST"]

const GROUPS := {
	Kind.GK: Group.GOALKEEPER,
	Kind.CB: Group.DEFENDER,
	Kind.LB: Group.DEFENDER,
	Kind.RB: Group.DEFENDER,
	Kind.DM: Group.MIDFIELDER,
	Kind.CM: Group.MIDFIELDER,
	Kind.AM: Group.MIDFIELDER,
	Kind.LW: Group.ATTACKER,
	Kind.RW: Group.ATTACKER,
	Kind.ST: Group.ATTACKER,
}

# Attribute.Kind -> weight per position (verbatim from PositionWeights).
const WEIGHTS := {
	Kind.GK: {6: 10, 5: 3, 2: 2, 4: 1},
	Kind.CB: {4: 8, 5: 6, 0: 3, 2: 2},
	Kind.LB: {4: 6, 0: 5, 5: 4, 2: 3, 3: 2},
	Kind.RB: {4: 6, 0: 5, 5: 4, 2: 3, 3: 2},
	Kind.DM: {4: 7, 2: 5, 5: 5, 0: 2, 3: 2},
	Kind.CM: {2: 7, 3: 5, 5: 4, 4: 4, 0: 3, 1: 3},
	Kind.AM: {2: 7, 3: 7, 1: 5, 0: 4, 5: 2},
	Kind.LW: {0: 7, 3: 7, 2: 4, 1: 4, 5: 2},
	Kind.RW: {0: 7, 3: 7, 2: 4, 1: 4, 5: 2},
	Kind.ST: {1: 8, 0: 5, 5: 4, 3: 4, 2: 2},
}


static func group_of(pos: int) -> int:
	return GROUPS[pos]


static func from_string(s: String) -> int:
	var idx: int = NAMES.find(s.strip_edges().to_upper())
	assert(idx >= 0, "Unknown position: %s" % s)
	return idx


static func to_string_value(pos: int) -> String:
	return NAMES[pos]
