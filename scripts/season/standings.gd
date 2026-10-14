# Source: engine/src/main/kotlin/com/footballmanager/simulation/season/Standings.kt
# Parity notes:
# - Container API mirrors source: entries list, champion (entries.first()),
#   with_results(fixtures, results) with the same alignment require.
# - Sort order: points desc -> goal_difference desc -> goals_for desc -> club_id asc
#   (final tiebreak by club id is in source comparator; kept for determinism).
# - compute() mirrors source (fresh entries per team, then fold over results).
extends RefCounted
class_name SeasonStandings

var entries: Array[StandingEntry] = []

var champion: StandingEntry:
	get:
		assert(not entries.is_empty(), "standings have no entries")
		return entries[0]


func _init(p_entries: Array[StandingEntry] = []) -> void:
	entries = p_entries


## Points (desc) -> goal difference (desc) -> goals for (desc) -> club id (asc).
static func compare(a: StandingEntry, b: StandingEntry) -> bool:
	if a.points != b.points:
		return a.points > b.points
	if a.goal_difference != b.goal_difference:
		return a.goal_difference > b.goal_difference
	if a.goals_for != b.goals_for:
		return a.goals_for > b.goals_for
	return a.team.club_id < b.team.club_id


## Applies a single matchday's results to this table, returning the updated table.
func with_results(fixtures: Array, results: Array) -> SeasonStandings:
	assert(fixtures.size() == results.size(), "fixtures and results must be aligned (%d vs %d)" % [fixtures.size(), results.size()])
	var by_club: Dictionary = {}
	for e in entries:
		by_club[(e as StandingEntry).team.club_id] = e
	for i in fixtures.size():
		var fx: SeasonFixture = fixtures[i]
		var res: MatchResult = results[i]
		by_club[fx.home.club_id] = (by_club[fx.home.club_id] as StandingEntry).record(res.home_score, res.away_score)
		by_club[fx.away.club_id] = (by_club[fx.away.club_id] as StandingEntry).record(res.away_score, res.home_score)
	var sorted: Array[StandingEntry] = []
	for v in by_club.values():
		sorted.append(v as StandingEntry)
	sorted.sort_custom(SeasonStandings.compare)
	return SeasonStandings.new(sorted)


static func compute(teams: Array, fixtures: Array, results: Array) -> SeasonStandings:
	assert(fixtures.size() == results.size(), "fixtures and results must be aligned (%d vs %d)" % [fixtures.size(), results.size()])
	var rows: Array[StandingEntry] = []
	for t in teams:
		rows.append(StandingEntry.new(t as Team))
	return SeasonStandings.new(rows).with_results(fixtures, results)


func to_dict() -> Dictionary:
	var rows: Array = []
	for e in entries:
		rows.append((e as StandingEntry).to_dict())
	return {"entries": rows}


static func from_dict(d: Dictionary) -> SeasonStandings:
	var rows: Array[StandingEntry] = []
	for raw in d.get("entries", []):
		if raw is StandingEntry:
			rows.append(raw)
		elif raw is Dictionary:
			rows.append(StandingEntry.from_dict(raw))
	return SeasonStandings.new(rows)
