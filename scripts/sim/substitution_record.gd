# Source: engine/src/main/kotlin/com/footballmanager/simulation/MatchStats.kt (SubstitutionRecord data class)
# Parity notes: field-for-field port; reason defaults to "Tactical" as in Kotlin.
class_name SubstitutionRecord
extends RefCounted

var minute: int = 0
var team_id: int = 0
var player_out_id: int = 0
var player_in_id: int = 0
var reason: String = "Tactical"


func _init(
	p_minute: int = 0,
	p_team_id: int = 0,
	p_player_out_id: int = 0,
	p_player_in_id: int = 0,
	p_reason: String = "Tactical",
) -> void:
	minute = p_minute
	team_id = p_team_id
	player_out_id = p_player_out_id
	player_in_id = p_player_in_id
	reason = p_reason


func to_dict() -> Dictionary:
	return {
		"minute": minute,
		"team_id": team_id,
		"player_out_id": player_out_id,
		"player_in_id": player_in_id,
		"reason": reason,
	}


static func from_dict(d: Dictionary) -> SubstitutionRecord:
	return SubstitutionRecord.new(
		int(d.get("minute", 0)),
		int(d.get("team_id", 0)),
		int(d.get("player_out_id", 0)),
		int(d.get("player_in_id", 0)),
		str(d.get("reason", "Tactical")),
	)
