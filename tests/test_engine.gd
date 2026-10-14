# GUT tests (run in the Godot editor with the GUT addon; no Godot binary was
# available at port time, so these have not been executed yet).
extends GutTest


func _uniform_player() -> Player:
	return Player.new(
		1, "Test Striker", 25, "ID", [Position.Kind.ST],
		PlayerAttributes.uniform(70),
		Contract.new(1000, "2030-06-30")
	)


func test_effective_overall_neutral_condition_equals_base() -> void:
	var p := _uniform_player()
	p.fitness = 100
	p.morale = 50
	# ST weights sum to 23; uniform 70 -> base overall exactly 70.
	# fitness factor 1.0, morale factor 0.90 + 0.20 * 0.5 = 1.0.
	assert_eq(p.overall(Position.Kind.ST), 70)
	assert_eq(p.effective_overall(Position.Kind.ST), 70)
	assert_eq(p.best_position(), Position.Kind.ST)
	assert_eq(p.best_overall(), 70)


func test_attributes_clamp_and_default() -> void:
	var attrs := PlayerAttributes.new({Attribute.Kind.PACE: 150})
	assert_eq(attrs.get(Attribute.Kind.PACE), 100)
	assert_eq(attrs.get(Attribute.Kind.SHOOTING), Attribute.MIN_VALUE)


func test_fixture_generation_double_round_robin() -> void:
	var teams: Array = []
	for i in 10:
		teams.append(Team.new(i + 1, 60, 60))
	var fixtures: Array = FixtureGenerator.generate(teams, "2026-08-01")
	assert_eq(fixtures.size(), 90)
	var pairs := {}
	for fx in fixtures:
		var key := "%d-%d" % [fx.home.club_id, fx.away.club_id]
		pairs[key] = int(pairs.get(key, 0)) + 1
	# Every ordered pair meets exactly once (leg 2 swaps venues).
	assert_eq(pairs.size(), 90)
	for key in pairs:
		assert_eq(pairs[key], 1)


func test_match_engine_seeded_determinism() -> void:
	var home := Team.new(1, 65, 60)
	var away := Team.new(2, 62, 63)
	var r1: MatchResult = MatchEngine.with_seed(42).simulate(home, away)
	var r2: MatchResult = MatchEngine.with_seed(42).simulate(home, away)
	assert_eq(r1.home_score, r2.home_score)
	assert_eq(r1.away_score, r2.away_score)
	assert_eq(r1.events.size(), r2.events.size())


func test_mod_loader_sample() -> void:
	var game: Game = ModLoader.load_from_file("res://data/sample-mod.json")
	assert_eq(game.clubs.size(), 3)
	assert_eq(game.players.size(), 6)


func test_direct_transfer_balance_math() -> void:
	var game: Game = SeedData.game()
	var league: League = game.competitions.values()[0]
	var runner := SeasonRunner.new()
	var teams: Array = SeedData.teams(game)
	var season: SeasonState = runner.start(league, teams, game.current_date, 1, game.clubs, game.players)
	var seller_id := 2
	var buyer_id := 1
	var pid: int = (season.clubs[seller_id] as Club).squad.player_ids[0]
	var fee := 1000
	var buyer_before: int = (season.clubs[buyer_id] as Club).finance.balance
	assert_true(buyer_before >= fee, "seed buyer must afford the test fee")
	var req := DirectTransfer.Request.new(pid, seller_id, buyer_id, fee)
	var after: SeasonState = DirectTransfer.new().execute(season, req)
	assert_eq((after.clubs[buyer_id] as Club).finance.balance, buyer_before - fee)
	assert_true((after.clubs[buyer_id] as Club).squad.contains(pid))
	assert_eq(after.transfer_history.size(), season.transfer_history.size() + 1)
