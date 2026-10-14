# Source: engine/src/main/kotlin/com/footballmanager/simulation/season/SeasonSimulator.kt
# Parity notes:
# - Whole-season at once: generate fixtures, play each via MatchEngine, compile
#   standings with SeasonStandings.compute. No condition/fitness tracking here
#   (that lives in SeasonRunner + the world-application hook).
# - TRUSTED sibling API: MatchEngine.simulate(home, away) -> MatchResult.
extends RefCounted
class_name SeasonSimulator

var engine: MatchEngine


func _init(p_engine: MatchEngine = null) -> void:
	engine = p_engine if p_engine != null else MatchEngine.new()


func simulate(league: League, teams: Array, start_date: String) -> SeasonResult:
	var fixtures: Array[SeasonFixture] = FixtureGenerator.generate(teams, start_date)
	var results: Array[MatchResult] = []
	for fx in fixtures:
		var f: SeasonFixture = fx
		results.append(engine.simulate(f.home, f.away) as MatchResult)
	var standings: SeasonStandings = SeasonStandings.compute(teams, fixtures, results)
	return SeasonResult.new(league, fixtures, results, standings)
