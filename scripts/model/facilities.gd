# Source: engine/.../model/Club.kt (Facilities).
class_name Facilities
extends RefCounted

var training_level: int = 1
var youth_level: int = 1
var stadium_capacity: int = 0


func _init(training: int = 1, youth: int = 1, stadium: int = 0) -> void:
	training_level = training
	youth_level = youth
	stadium_capacity = stadium


func to_dict() -> Dictionary:
	return {
		"trainingLevel": training_level,
		"youthLevel": youth_level,
		"stadiumCapacity": stadium_capacity,
	}


static func from_dict(d: Dictionary) -> Facilities:
	return Facilities.new(
		int(d.get("trainingLevel", 1)),
		int(d.get("youthLevel", 1)),
		int(d.get("stadiumCapacity", 0))
	)
