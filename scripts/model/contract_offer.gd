# Source: engine/.../model/Transfer.kt (ContractOffer).
class_name ContractOffer
extends RefCounted

var weekly_wage: int = 0
var contract_years: int = 3
var squad_status: int = SquadStatus.Kind.ROTATION
var signing_bonus: int = 0


func _init(wage: int = 0, years: int = 3, status: int = SquadStatus.Kind.ROTATION, bonus: int = 0) -> void:
	weekly_wage = wage
	contract_years = years
	squad_status = status
	signing_bonus = bonus


func to_dict() -> Dictionary:
	return {
		"weeklyWage": weekly_wage,
		"contractYears": contract_years,
		"squadStatus": SquadStatus.to_string_value(squad_status),
		"signingBonus": signing_bonus,
	}


static func from_dict(d: Dictionary) -> ContractOffer:
	return ContractOffer.new(
		int(d.get("weeklyWage", 0)),
		int(d.get("contractYears", 3)),
		SquadStatus.from_string(str(d.get("squadStatus", "ROTATION"))),
		int(d.get("signingBonus", 0))
	)
