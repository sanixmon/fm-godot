# Source: engine/.../model/Player.kt (TrainingFocus / TrainingIntensity enums).
class_name TrainingFocus
extends RefCounted

enum Kind {
	BALANCED,
	ATTACKING,
	DEFENDING,
	PHYSICAL,
	TECHNICAL,
	GOALKEEPING,
}

const NAMES: Array = ["BALANCED", "ATTACKING", "DEFENDING", "PHYSICAL", "TECHNICAL", "GOALKEEPING"]


static func from_string(s: String) -> int:
	return NAMES.find(s.strip_edges().to_upper())


static func to_string_value(kind: int) -> String:
	return NAMES[kind]
