# Source: engine/.../model/Player.kt.
# Parity note: Kotlin data-class immutability is NOT reproduced — Player is a
# mutable RefCounted. Callers mutate fields in place instead of copy().
class_name Player
extends RefCounted

var id: int = 0
var name: String = ""
var age: int = 0
var nationality: String = ""
var natural_positions: Array = []
var attributes: PlayerAttributes = null
var contract: Contract = null
var fitness: int = 100
var morale: int = 50
var potential: int = 75
var form: int = 60
var injury_status: InjuryStatus = null
var suspension_status: SuspensionStatus = null
## Optional external graphics id; -1 means absent (Kotlin: null).
var graphics_id: int = -1
var training_focus: int = TrainingFocus.Kind.BALANCED
var training_intensity: int = TrainingIntensity.Kind.NORMAL


func _init(
	p_id: int = 0,
	p_name: String = "",
	p_age: int = 0,
	p_nationality: String = "",
	p_positions: Array = [],
	p_attributes: PlayerAttributes = null,
	p_contract: Contract = null
) -> void:
	id = p_id
	name = p_name
	age = p_age
	nationality = p_nationality
	natural_positions = p_positions
	attributes = p_attributes
	contract = p_contract
	assert(name != "", "player name must not be blank")
	assert(age > 0, "player age must be positive")
	assert(not natural_positions.is_empty(), "player must have at least one natural position")


func is_injured() -> bool:
	return injury_status != null and injury_status.is_injured()


func is_suspended() -> bool:
	return suspension_status != null and suspension_status.is_suspended()


func is_available() -> bool:
	return not is_injured() and not is_suspended()


func is_emergency() -> bool:
	return id < 0


func overall(position: int) -> int:
	return attributes.overall(position)


func effective_overall(position: int) -> int:
	return PlayerCalculator.calculate_effective_overall(self, position)


func best_position() -> int:
	return PlayerCalculator.find_best_position(self)


func best_overall() -> int:
	return PlayerCalculator.calculate_best_overall(self)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"age": age,
		"nationality": nationality,
		"naturalPositions": natural_positions.map(func(p: int) -> String: return Position.to_string_value(p)),
		"attributes": attributes.to_dict(),
		"contract": contract.to_dict(),
		"fitness": fitness,
		"morale": morale,
		"potential": potential,
		"form": form,
		"injuryStatus": injury_status.to_dict() if injury_status != null else null,
		"suspensionStatus": suspension_status.to_dict() if suspension_status != null else null,
		"graphicsId": graphics_id if graphics_id >= 0 else null,
		"trainingFocus": TrainingFocus.to_string_value(training_focus),
		"trainingIntensity": TrainingIntensity.to_string_value(training_intensity),
	}


static func from_dict(d: Dictionary) -> Player:
	var positions: Array = []
	for s: String in d.get("naturalPositions", []):
		positions.append(Position.from_string(s))
	var p := Player.new(
		int(d.get("id", 0)),
		str(d.get("name", "?")),
		int(d.get("age", 20)),
		str(d.get("nationality", "")),
		positions,
		PlayerAttributes.from_dict(d.get("attributes", {})),
		Contract.from_dict(d.get("contract", {}))
	)
	p.fitness = int(d.get("fitness", 100))
	p.morale = int(d.get("morale", 50))
	p.potential = int(d.get("potential", 75))
	p.form = int(d.get("form", 60))
	if d.get("injuryStatus", null) != null:
		p.injury_status = InjuryStatus.from_dict(d["injuryStatus"])
	if d.get("suspensionStatus", null) != null:
		p.suspension_status = SuspensionStatus.from_dict(d["suspensionStatus"])
	var gid = d.get("graphicsId", null)
	p.graphics_id = int(gid) if gid != null else -1
	p.training_focus = TrainingFocus.from_string(str(d.get("trainingFocus", "BALANCED")))
	p.training_intensity = TrainingIntensity.from_string(str(d.get("trainingIntensity", "NORMAL")))
	return p
