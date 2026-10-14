# Source: engine/src/main/kotlin/com/footballmanager/calculator/WageExpectationCalculator.kt
# Parity notes:
# - promised_status int assumes SquadStatus ordinals: KEY_PLAYER=0, FIRST_TEAM=1,
#   ROTATION=2, BACKUP=3, YOUTH=4. Default ROTATION matches the Kotlin default.
# - Kotlin roundToLong is half-up; int(round()) matches for non-negative values.
class_name WageExpectation
extends RefCounted

const STATUS_KEY_PLAYER: int = 0
const STATUS_FIRST_TEAM: int = 1
const STATUS_ROTATION: int = 2
const STATUS_BACKUP: int = 3
const STATUS_YOUTH: int = 4


static func calculate_expected_wage(player, promised_status: int = STATUS_ROTATION) -> int:
	var overall: int = player.best_overall()
	var base_wage: int = 0
	if overall < 60:
		base_wage = 250 + ((overall - 1) * 10)
	elif overall < 70:
		base_wage = 800 + ((overall - 60) * 70)
	elif overall < 80:
		base_wage = 1500 + ((overall - 70) * 650)
	elif overall < 90:
		base_wage = 8000 + ((overall - 80) * 1700)
	else:
		base_wage = 25000 + ((overall - 90) * 5000)

	var status_multiplier: float = 0.90
	match promised_status:
		STATUS_KEY_PLAYER:
			status_multiplier = 1.25
		STATUS_FIRST_TEAM:
			status_multiplier = 1.05
		STATUS_ROTATION:
			status_multiplier = 0.90
		STATUS_BACKUP:
			status_multiplier = 0.70
		STATUS_YOUTH:
			status_multiplier = 0.50

	return maxi(int(round(float(base_wage) * status_multiplier)), 100)
