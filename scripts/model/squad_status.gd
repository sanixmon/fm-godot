# Source: engine/.../model/Player.kt (SquadStatus enum).
class_name SquadStatus
extends RefCounted

enum Kind {
	KEY_PLAYER,
	FIRST_TEAM,
	ROTATION,
	BACKUP,
	YOUTH,
}

const NAMES: Array = ["KEY_PLAYER", "FIRST_TEAM", "ROTATION", "BACKUP", "YOUTH"]


static func from_string(s: String) -> int:
	return NAMES.find(s.strip_edges().to_upper())


static func to_string_value(kind: int) -> String:
	return NAMES[kind]
