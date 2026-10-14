# Source: engine/.../model/Competition.kt (Cup; currently unused by gameplay).
class_name Cup
extends Competition


func kind() -> String:
	return "cup"


func to_dict() -> Dictionary:
	var d: Dictionary = super.to_dict()
	d["type"] = "cup"
	return d


static func from_dict(d: Dictionary) -> Cup:
	return Cup.new(
		int(d.get("id", 0)),
		str(d.get("name", "?")),
		d.get("clubIds", [])
	)
