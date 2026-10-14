# Source: engine/.../model/Player.kt (Contract).
class_name Contract
extends RefCounted

var weekly_wage: int = 0
var expires_on: String = "2030-06-30"
var squad_status: int = SquadStatus.Kind.ROTATION


func _init(wage: int = 0, expires: String = "2030-06-30", status: int = SquadStatus.Kind.ROTATION) -> void:
	weekly_wage = wage
	expires_on = expires
	squad_status = status


func to_dict() -> Dictionary:
	return {
		"weeklyWage": weekly_wage,
		"expiresOn": expires_on,
		"squadStatus": SquadStatus.to_string_value(squad_status),
	}


static func from_dict(d: Dictionary) -> Contract:
	return Contract.new(
		int(d.get("weeklyWage", 0)),
		str(d.get("expiresOn", "2030-06-30")),
		SquadStatus.from_string(str(d.get("squadStatus", "ROTATION")))
	)
