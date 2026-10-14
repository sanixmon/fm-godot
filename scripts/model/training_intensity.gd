# Source: engine/.../model/Player.kt (TrainingIntensity enum).
class_name TrainingIntensity
extends RefCounted

enum Kind {
	LIGHT,
	NORMAL,
	INTENSIVE,
}

const NAMES: Array = ["LIGHT", "NORMAL", "INTENSIVE"]


static func from_string(s: String) -> int:
	return NAMES.find(s.strip_edges().to_upper())


static func to_string_value(kind: int) -> String:
	return NAMES[kind]
