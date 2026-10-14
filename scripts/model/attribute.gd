# Source: engine/.../model/Attributes.kt (Attribute enum; 1..100 scale).
class_name Attribute
extends RefCounted

enum Kind {
	PACE,
	SHOOTING,
	PASSING,
	DRIBBLING,
	DEFENDING,
	PHYSICAL,
	GOALKEEPER,
}

const NAMES: Array = [
	"PACE",
	"SHOOTING",
	"PASSING",
	"DRIBBLING",
	"DEFENDING",
	"PHYSICAL",
	"GOALKEEPER",
]

const MIN_VALUE: int = 1
const MAX_VALUE: int = 100


static func from_string(s: String) -> int:
	var idx: int = NAMES.find(s.strip_edges().to_upper())
	assert(idx >= 0, "Unknown attribute: %s" % s)
	return idx


static func to_string_value(kind: int) -> String:
	return NAMES[kind]
