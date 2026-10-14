# Source: engine/.../model/Competition.kt (League).
class_name League
extends Competition


func kind() -> String:
	return "league"


func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["type"] = "league"
	return d


static func from_dict(d: Dictionary) -> League:
	var l := League.new(
		int(d.get("id", 0)),
		str(d.get("name", "?")),
		d.get("clubIds", [])
	)
	return l
