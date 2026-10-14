# Source: engine/src/main/kotlin/com/footballmanager/simulation/MatchEvent.kt (MatchEvent data class)
# Parity notes:
# - type holds a MatchEventType.Kind int; side holds a Side.Kind int.
# - Kotlin nullable playerId/secondaryPlayerId use the -1 sentinel here.
# - to_dict stores null for absent player ids to mirror Kotlin JSON output.
class_name MatchEvent
extends RefCounted

var minute: int = 0
var type: int = MatchEventType.Kind.POSSESSION
var side: int = Side.Kind.HOME
var team_id: int = 0
var player_id: int = -1
var secondary_player_id: int = -1
var description: String = ""


func _init(
	p_minute: int = 0,
	p_type: int = MatchEventType.Kind.POSSESSION,
	p_side: int = Side.Kind.HOME,
	p_team_id: int = 0,
	p_player_id: int = -1,
	p_secondary_player_id: int = -1,
	p_description: String = "",
) -> void:
	minute = p_minute
	type = p_type
	side = p_side
	team_id = p_team_id
	player_id = p_player_id
	secondary_player_id = p_secondary_player_id
	description = p_description


func to_dict() -> Dictionary:
	return {
		"minute": minute,
		"type": type,
		"side": side,
		"team_id": team_id,
		"player_id": null if player_id < 0 else player_id,
		"secondary_player_id": null if secondary_player_id < 0 else secondary_player_id,
		"description": description,
	}


static func _id_from(v) -> int:
	if v == null:
		return -1
	return int(v)


static func from_dict(d: Dictionary) -> MatchEvent:
	return MatchEvent.new(
		int(d.get("minute", 0)),
		int(d.get("type", MatchEventType.Kind.POSSESSION)),
		int(d.get("side", Side.Kind.HOME)),
		int(d.get("team_id", 0)),
		_id_from(d.get("player_id", null)),
		_id_from(d.get("secondary_player_id", null)),
		str(d.get("description", "")),
	)
