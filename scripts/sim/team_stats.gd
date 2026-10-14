# Source: engine/src/main/kotlin/com/footballmanager/simulation/MatchStats.kt (TeamStats data class)
# Parity notes: field-for-field port; all counters default to 0.
class_name TeamStats
extends RefCounted

var possessions: int = 0
var shots: int = 0
var shots_on_target: int = 0
var goals: int = 0
var corners: int = 0
var fouls: int = 0
var yellow_cards: int = 0
var red_cards: int = 0


func _init(
	p_possessions: int = 0,
	p_shots: int = 0,
	p_shots_on_target: int = 0,
	p_goals: int = 0,
	p_corners: int = 0,
	p_fouls: int = 0,
	p_yellow_cards: int = 0,
	p_red_cards: int = 0,
) -> void:
	possessions = p_possessions
	shots = p_shots
	shots_on_target = p_shots_on_target
	goals = p_goals
	corners = p_corners
	fouls = p_fouls
	yellow_cards = p_yellow_cards
	red_cards = p_red_cards


func to_dict() -> Dictionary:
	return {
		"possessions": possessions,
		"shots": shots,
		"shots_on_target": shots_on_target,
		"goals": goals,
		"corners": corners,
		"fouls": fouls,
		"yellow_cards": yellow_cards,
		"red_cards": red_cards,
	}


static func from_dict(d: Dictionary) -> TeamStats:
	return TeamStats.new(
		int(d.get("possessions", 0)),
		int(d.get("shots", 0)),
		int(d.get("shots_on_target", 0)),
		int(d.get("goals", 0)),
		int(d.get("corners", 0)),
		int(d.get("fouls", 0)),
		int(d.get("yellow_cards", 0)),
		int(d.get("red_cards", 0)),
	)
