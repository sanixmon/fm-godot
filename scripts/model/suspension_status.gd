# Source: engine/.../model/Player.kt (SuspensionStatus).
class_name SuspensionStatus
extends RefCounted

var matches_remaining: int = 0
var reason: String = "Suspension"


func _init(matches: int = 0, why: String = "Suspension") -> void:
	matches_remaining = matches
	reason = why


func is_suspended() -> bool:
	return matches_remaining > 0


func to_dict() -> Dictionary:
	return {"matchesRemaining": matches_remaining, "reason": reason}


static func from_dict(d: Dictionary) -> SuspensionStatus:
	return SuspensionStatus.new(int(d.get("matchesRemaining", 0)), str(d.get("reason", "Suspension")))
