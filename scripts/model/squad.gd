# Source: engine/.../model/Club.kt (Squad).
class_name Squad
extends RefCounted

var club_id: int = 0
var player_ids: Array = []


func _init(p_club_id: int = 0, p_player_ids: Array = []) -> void:
	club_id = p_club_id
	player_ids = p_player_ids.duplicate()


func size() -> int:
	return player_ids.size()


func contains(player_id: int) -> bool:
	return player_id in player_ids


func to_dict() -> Dictionary:
	return {"clubId": club_id, "playerIds": player_ids.duplicate()}


static func from_dict(d: Dictionary) -> Squad:
	return Squad.new(int(d.get("clubId", 0)), d.get("playerIds", []))
