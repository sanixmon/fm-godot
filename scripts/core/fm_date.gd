# ISO-8601 calendar-day helpers. Dates are plain "YYYY-MM-DD" strings, which
# compare chronologically with the standard string operators.
class_name FMDate
extends RefCounted


static func add_days(iso: String, days: int) -> String:
	var parts: PackedStringArray = iso.split("-")
	assert(parts.size() == 3, "FMDate needs YYYY-MM-DD, got: %s" % iso)
	var noon := {
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 12,
		"minute": 0,
		"second": 0,
	}
	var shifted_unix: int = int(Time.get_unix_time_from_datetime_dict(noon)) + days * 86400
	var back: Dictionary = Time.get_datetime_dict_from_unix_time(shifted_unix)
	return "%04d-%02d-%02d" % [int(back["year"]), int(back["month"]), int(back["day"])]


static func days_between(from_iso: String, to_iso: String) -> int:
	var a: PackedStringArray = from_iso.split("-")
	var b: PackedStringArray = to_iso.split("-")
	var da := {"year": int(a[0]), "month": int(a[1]), "day": int(a[2]), "hour": 12, "minute": 0, "second": 0}
	var db := {"year": int(b[0]), "month": int(b[1]), "day": int(b[2]), "hour": 12, "minute": 0, "second": 0}
	var diff: int = int(Time.get_unix_time_from_datetime_dict(db)) - int(Time.get_unix_time_from_datetime_dict(da))
	return int(round(diff / 86400.0))
