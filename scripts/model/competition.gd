# Source: engine/.../model/Competition.kt (Competition base + League/Cup dispatch).
class_name Competition
extends RefCounted

var id: int = 0
var name: String = ""
var club_ids: Array = []


func _init(p_id: int = 0, p_name: String = "", p_clubs: Array = []) -> void:
	id = p_id
	name = p_name
	club_ids = p_clubs.duplicate()


func kind() -> String:
	return "competition"


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "clubIds": club_ids.duplicate()}


static func from_dict(d: Dictionary):
	var t: String = str(d.get("type", "league"))
	if t == "cup":
		return Cup.from_dict(d)
	return League.from_dict(d)
