# Source: engine/.../model/Player.kt (InjuryStatus).
class_name InjuryStatus
extends RefCounted

var description: String = "Injured"
var days_remaining: int = 0


func _init(days: int = 0, desc: String = "Injured") -> void:
	days_remaining = days
	description = desc


func is_injured() -> bool:
	return days_remaining > 0


func to_dict() -> Dictionary:
	return {"description": description, "daysRemaining": days_remaining}


static func from_dict(d: Dictionary) -> InjuryStatus:
	return InjuryStatus.new(int(d.get("daysRemaining", 0)), str(d.get("description", "Injured")))
