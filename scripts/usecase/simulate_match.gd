# Source: engine/src/main/kotlin/com/footballmanager/usecase/SimulateMatchUseCase.kt
# Thin wrapper selecting the MatchEngine random source, then delegating.
# Uses the real sibling APIs: MatchEngine.with_seed(seed) / MatchEngine.new(rng).
class_name SimulateMatch
extends RefCounted


class MatchRequest extends RefCounted:
	var home_team: Team
	var away_team: Team
	var seed = null # int or null; null falls back to random_source, then MatchEngine default
	func _init(home: Team, away: Team, seed_value = null) -> void:
		home_team = home
		away_team = away
		seed = seed_value


var _random_source: FMRandom = null


func _init(random_source: FMRandom = null) -> void:
	_random_source = random_source


func execute(request: MatchRequest) -> MatchResult:
	# Mirrors Kotlin: explicit seed wins, then injected source, then default.
	var engine: MatchEngine
	if request.seed != null:
		engine = MatchEngine.with_seed(int(request.seed))
	elif _random_source != null:
		engine = MatchEngine.new(_random_source)
	else:
		engine = MatchEngine.new()
	return engine.simulate(request.home_team, request.away_team)


# Batch simulation of multiple fixtures in a round or tournament.
func simulate_batch(requests: Array) -> Array:
	var out: Array = []
	for req in requests:
		out.append(execute(req))
	return out
