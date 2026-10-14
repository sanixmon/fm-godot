# Source: engine/src/main/kotlin/com/footballmanager/simulation/season/Fixture.kt
# Parity notes:
# - Distinct from model/Calendar.kt Fixture (id/competition_id/home_club_id/away_club_id);
#   this season type embeds full Team snapshots (home/away) per source.
# - Kotlin LocalDate -> ISO "YYYY-MM-DD" String; lexicographic == chronological.
# - TRUSTED sibling API: Team.to_dict / Team.from_dict (Team batch).
extends RefCounted
class_name SeasonFixture

var round: int = 1
var date: String = ""
var home: Team
var away: Team


func _init(p_round: int = 1, p_date: String = "", p_home: Team = null, p_away: Team = null) -> void:
	assert(p_round >= 1, "round must be >= 1")
	round = p_round
	date = p_date
	home = p_home
	away = p_away


func to_dict() -> Dictionary:
	return {
		"round": round,
		"date": date,
		"home": home.to_dict() if home != null else {},
		"away": away.to_dict() if away != null else {},
	}


static func from_dict(d: Dictionary) -> SeasonFixture:
	var h: Team = null
	if d.get("home") is Dictionary and not (d.get("home") as Dictionary).is_empty():
		h = Team.from_dict(d["home"] as Dictionary)
	elif d.get("home") is Team:
		h = d["home"]
	var a: Team = null
	if d.get("away") is Dictionary and not (d.get("away") as Dictionary).is_empty():
		a = Team.from_dict(d["away"] as Dictionary)
	elif d.get("away") is Team:
		a = d["away"]
	return SeasonFixture.new(int(d.get("round", 1)), str(d.get("date", "")), h, a)
