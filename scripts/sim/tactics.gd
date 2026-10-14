# Source: engine/src/main/kotlin/com/footballmanager/simulation/Tactics.kt (Tactics data class)
# Parity notes: field ints hold Kind values of the sibling enum holder classes.
# Default tactics = FOUR_FOUR_TWO / BALANCED / NORMAL / MEDIUM / MIXED.
class_name Tactics
extends RefCounted

var formation: int = Formation.Kind.FOUR_FOUR_TWO
var mentality: int = Mentality.Kind.BALANCED
var tempo: int = Tempo.Kind.NORMAL
var pressing: int = Pressing.Kind.MEDIUM
var passing: int = Passing.Kind.MIXED


func _init(
	p_formation: int = Formation.Kind.FOUR_FOUR_TWO,
	p_mentality: int = Mentality.Kind.BALANCED,
	p_tempo: int = Tempo.Kind.NORMAL,
	p_pressing: int = Pressing.Kind.MEDIUM,
	p_passing: int = Passing.Kind.MIXED,
) -> void:
	formation = p_formation
	mentality = p_mentality
	tempo = p_tempo
	pressing = p_pressing
	passing = p_passing


# Combined attack modifier (formation x mentality). Mirrors Tactics.attackModifier.
func attack_modifier() -> float:
	return Formation.attack_mod(formation) * Mentality.attack_mod(mentality)


# Combined defense modifier (formation x mentality). Mirrors Tactics.defenseModifier.
func defense_modifier() -> float:
	return Formation.defense_mod(formation) * Mentality.defense_mod(mentality)


func to_dict() -> Dictionary:
	return {
		"formation": formation,
		"mentality": mentality,
		"tempo": tempo,
		"pressing": pressing,
		"passing": passing,
	}


static func from_dict(d: Dictionary) -> Tactics:
	return Tactics.new(
		int(d.get("formation", Formation.Kind.FOUR_FOUR_TWO)),
		int(d.get("mentality", Mentality.Kind.BALANCED)),
		int(d.get("tempo", Tempo.Kind.NORMAL)),
		int(d.get("pressing", Pressing.Kind.MEDIUM)),
		int(d.get("passing", Passing.Kind.MIXED)),
	)
