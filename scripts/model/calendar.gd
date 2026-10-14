# Source: engine/.../model/Calendar.kt (Fixture + Calendar).
# Named CalendarData to avoid confusion with the season Fixture type
# (SeasonFixture) and any engine Calendar singletons.
class_name CalendarData
extends RefCounted


class ModelFixture:
	var id: int = 0
	var competition_id: int = 0
	var date: String = ""
	var home_club_id: int = 0
	var away_club_id: int = 0


var _fixtures: Array = []


func _init(fixtures: Array = []) -> void:
	_fixtures = fixtures.duplicate()
	_fixtures.sort_custom(func(a, b: ModelFixture) -> bool: return a.date < b.date)


func size() -> int:
	return _fixtures.size()


func fixtures() -> Array:
	return _fixtures.duplicate()


func fixtures_on(date: String) -> Array:
	return _fixtures.filter(func(f: ModelFixture) -> bool: return f.date == date)


func fixtures_for(club_id: int) -> Array:
	return _fixtures.filter(
		func(f: ModelFixture) -> bool: return f.home_club_id == club_id or f.away_club_id == club_id
	)


func next_fixture(club_id: int, from: String):
	for f: ModelFixture in fixtures_for(club_id):
		if f.date >= from:
			return f
	return null


func to_dict() -> Dictionary:
	return {"fixtures": _fixtures.map(func(f: ModelFixture) -> Dictionary: return {
		"id": f.id,
		"competitionId": f.competition_id,
		"date": f.date,
		"homeClubId": f.home_club_id,
		"awayClubId": f.away_club_id,
	})}


static func from_dict(d: Dictionary) -> CalendarData:
	var out: Array = []
	for e: Dictionary in d.get("fixtures", []):
		var f := ModelFixture.new()
		f.id = int(e.get("id", 0))
		f.competition_id = int(e.get("competitionId", 0))
		f.date = str(e.get("date", ""))
		f.home_club_id = int(e.get("homeClubId", 0))
		f.away_club_id = int(e.get("awayClubId", 0))
		out.append(f)
	return CalendarData.new(out)
