# Source: engine/src/main/kotlin/com/footballmanager/simulation/season/SeasonResult.kt
# Parity notes:
# - Fields mirror source: league, fixtures (round order), results (aligned by index),
#   standings. champion delegates to standings.champion.
# - TRUSTED sibling APIs: League.to_dict/from_dict, MatchResult.to_dict/from_dict.
extends RefCounted
class_name SeasonResult

var league: League
var fixtures: Array[SeasonFixture] = []
var results: Array[MatchResult] = []
var standings: SeasonStandings

var champion: StandingEntry:
	get:
		return standings.champion


func _init(
	p_league: League = null,
	p_fixtures: Array[SeasonFixture] = [],
	p_results: Array[MatchResult] = [],
	p_standings: SeasonStandings = null
) -> void:
	assert(p_fixtures.size() == p_results.size(), "fixtures and results must be aligned (%d vs %d)" % [p_fixtures.size(), p_results.size()])
	league = p_league
	fixtures = p_fixtures
	results = p_results
	standings = p_standings


func to_dict() -> Dictionary:
	var fx: Array = []
	for f in fixtures:
		fx.append((f as SeasonFixture).to_dict())
	var res: Array = []
	for r in results:
		res.append((r as MatchResult).to_dict())
	return {
		"league": league.to_dict() if league != null else {},
		"fixtures": fx,
		"results": res,
		"standings": standings.to_dict() if standings != null else {},
	}


static func from_dict(d: Dictionary) -> SeasonResult:
	var lg: League = null
	if d.get("league") is Dictionary and not (d.get("league") as Dictionary).is_empty():
		lg = League.from_dict(d["league"] as Dictionary)
	elif d.get("league") is League:
		lg = d["league"]
	var fx: Array[SeasonFixture] = []
	for raw in d.get("fixtures", []):
		if raw is SeasonFixture:
			fx.append(raw)
		elif raw is Dictionary:
			fx.append(SeasonFixture.from_dict(raw))
	var res: Array[MatchResult] = []
	for raw in d.get("results", []):
		if raw is MatchResult:
			res.append(raw)
		elif raw is Dictionary:
			res.append(MatchResult.from_dict(raw))
	var st: SeasonStandings = null
	if d.get("standings") is Dictionary and not (d.get("standings") as Dictionary).is_empty():
		st = SeasonStandings.from_dict(d["standings"] as Dictionary)
	elif d.get("standings") is SeasonStandings:
		st = d["standings"]
	return SeasonResult.new(lg, fx, res, st)
