# Source: engine/.../model/Club.kt (Finance).
class_name Finance
extends RefCounted

var balance: int = 0
var transfer_budget: int = 0
var weekly_wage_budget: int = 0


func _init(bal: int = 0, budget: int = 0, wage_budget: int = 0) -> void:
	balance = bal
	transfer_budget = budget
	weekly_wage_budget = wage_budget


func to_dict() -> Dictionary:
	return {
		"balance": balance,
		"transferBudget": transfer_budget,
		"weeklyWageBudget": weekly_wage_budget,
	}


static func from_dict(d: Dictionary) -> Finance:
	return Finance.new(
		int(d.get("balance", 0)),
		int(d.get("transferBudget", 0)),
		int(d.get("weeklyWageBudget", 0))
	)
