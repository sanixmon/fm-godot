# Source: engine/src/main/kotlin/com/footballmanager/simulation/season/FixtureGenerator.kt
# Parity notes:
# - Double round-robin via the circle method; first leg rounds 1..(N-1), second leg is
#   leg 1 with home/away reversed at round + rounds_per_leg (so each club visits exactly
#   the opponents it hosted). Odd team count pads with a bye (null) per leg.
# - Home/away alternation by round parity (odd rounds: circle[i] hosts) mirrored.
# - DAYS_PER_ROUND = 7; leg-2 dates = leg-1 date + rounds_per_leg * 7 days.
# - Date arithmetic via TRUSTED FMDate.add_days(iso, days) (ISO strings compare
#   lexicographically). generate() takes Team snapshots (source takes List<Team>).
extends RefCounted
class_name FixtureGenerator

const DAYS_PER_ROUND: int = 7


static func generate(teams: Array, start_date: String) -> Array[SeasonFixture]:
	assert(teams.size() >= 2, "a season needs at least two teams")
	var distinct: Dictionary = {}
	for t in teams:
		distinct[(t as Team).club_id] = true
	assert(distinct.size() == teams.size(), "teams must have distinct club ids")
	# Pad with a null "bye" so the circle method works for odd team counts.
	var padded: Array = teams.duplicate()
	if teams.size() % 2 == 1:
		padded.append(null)
	var rounds_per_leg: int = padded.size() - 1
	var first_leg: Array[SeasonFixture] = _build_leg(padded, start_date)
	var fixtures: Array[SeasonFixture] = []
	fixtures.append_array(first_leg)
	for fx in first_leg:
		var f: SeasonFixture = fx
		fixtures.append(SeasonFixture.new(
			f.round + rounds_per_leg,
			FMDate.add_days(f.date, rounds_per_leg * DAYS_PER_ROUND),
			f.away,
			f.home
		))
	return fixtures


static func _build_leg(padded: Array, start_date: String) -> Array[SeasonFixture]:
	var count: int = padded.size()
	var circle: Array = padded.duplicate()
	var fixtures: Array[SeasonFixture] = []
	for round in range(1, count):
		for i in range(count / 2):
			var first: Team = circle[i]
			var second: Team = circle[count - 1 - i]
			if first == null or second == null:
				continue
			var h: Team = first if round % 2 == 1 else second
			var a: Team = second if round % 2 == 1 else first
			fixtures.append(SeasonFixture.new(
				round,
				FMDate.add_days(start_date, (round - 1) * DAYS_PER_ROUND),
				h,
				a
			))
		_rotate(circle)
	return fixtures


static func _rotate(circle: Array) -> void:
	# Keep the first element fixed; rotate the rest cyclically by one.
	var last: Variant = circle[circle.size() - 1]
	for i in range(circle.size() - 1, 1, -1):
		circle[i] = circle[i - 1]
	circle[1] = last
