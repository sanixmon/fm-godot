# Source: engine/src/main/kotlin/com/footballmanager/usecase/SeasonRolloverUseCase.kt
# Mirrors logic exactly: prize money (4M/2.5M/1.5M/800k/400k, half to transfer
# budget), annual development + age +1, contract rollover (renewal if age<=33 or
# overall>=65 else veteran 1-year extension), fitness/morale reset (100/75),
# 2-player youth intake per club, manager trophy update, fresh fixtures/standings
# (initial all-zero rows, mirroring Standings(entries) construction).
# Dates are ISO strings; comparisons are lexicographic (valid for ISO format).
# Player/Club entities are mutated in place (deliberate mutability difference vs
# Kotlin immutability). Uses the real sibling APIs throughout (Position.WEIGHTS,
# Formation.Kind/Mentality.Kind, PlayerDevelopmentCalc, WageExpectation,
# Team.from_squad, FixtureGenerator.generate, SeasonStandings/StandingEntry).
class_name SeasonRollover
extends RefCounted

# Youth positions CB/CM/ST/GK as Position.Kind ints (1/5/9/0); literals keep this
# const independent of other scripts at parse time.
const YOUTH_POSITIONS: Array = [1, 5, 9, 0]
const YOUTH_FIRST_NAMES: Array = ["Bagas", "Rizky", "Dimas", "Eko", "Fajar", "Ilham", "Wahyu", "Bayu"]
const YOUTH_LAST_NAMES: Array = ["Pratama", "Saputra", "Kusuma", "Hidayat", "Nugroho", "Santoso", "Wijaya"]


class RolloverOutput extends RefCounted:
	var next_season: SeasonState
	var completed_season_result: SeasonResult
	func _init(next: SeasonState, completed: SeasonResult) -> void:
		next_season = next
		completed_season_result = completed


var _random: FMRandom = null


func _init(random: FMRandom = null) -> void:
	# Kotlin default Random(2026). NOTE: FMRandom wraps Godot's PRNG, so the same
	# seed does NOT reproduce Kotlin's sequence; determinism holds within Godot only.
	_random = random if random != null else FMRandom.new(2026)


func execute(current_season: SeasonState) -> SeasonState:
	return execute_with_result(current_season).next_season


func execute_with_result(current_season: SeasonState) -> RolloverOutput:
	assert(current_season.is_finished, "Cannot rollover an unfinished season")

	var completed := SeasonResult.new(
		current_season.league,
		current_season.fixtures,
		current_season.results,
		current_season.standings
	)

	var entries: Array[StandingEntry] = current_season.standings.entries
	var next_year: int = int(current_season.current_date.left(4)) + 1
	var new_start_date: String = "%04d-08-01" % next_year

	# 1. Award prize money.
	var updated_clubs: Dictionary = current_season.clubs.duplicate()
	var rank: int = 0
	for entry in entries:
		rank += 1
		var prize: int
		if rank == 1:
			prize = 4000000
		elif rank == 2:
			prize = 2500000
		elif rank == 3:
			prize = 1500000
		elif rank >= 4 and rank <= 6:
			prize = 800000
		else:
			prize = 400000
		var club: Club = updated_clubs.get(entry.team.club_id)
		if club != null:
			club.finance.balance += prize
			club.finance.transfer_budget += int(prize / 2)

	# 2. Age players, apply annual development, handle expiring contracts.
	var updated_players: Dictionary = {}
	for player_id in current_season.players.keys():
		var player: Player = current_season.players[player_id]
		var training_level: int = 1
		for c in updated_clubs.values():
			if (c as Club).squad.contains(player.id):
				training_level = (c as Club).facilities.training_level
				break
		var season_stats: PlayerSeasonStats = current_season.player_stats.get(player.id)
		var developed: Player = PlayerDevelopmentCalc.apply_development(player, training_level, season_stats)
		var new_age: int = developed.age + 1
		if developed.contract.expires_on <= new_start_date:
			if new_age <= 33 or developed.best_overall() >= 65:
				developed.contract.weekly_wage = WageExpectation.calculate_expected_wage(developed, developed.contract.squad_status)
				developed.contract.expires_on = "%04d-06-30" % (next_year + 2)
			else:
				# Veteran extension (1 year).
				developed.contract.expires_on = "%04d-06-30" % (next_year + 1)
		developed.age = new_age
		developed.fitness = 100
		developed.morale = 75
		developed.injury_status = null
		developed.suspension_status = null
		updated_players[player_id] = developed

	# 3. Youth intake (2 young players per club).
	var max_id: int = 1000
	for key in updated_players.keys():
		max_id = maxi(max_id, int(key))
	var next_player_id: int = max_id + 1
	for club_id in updated_clubs.keys():
		var club: Club = updated_clubs[club_id]
		var new_ids: Array = []
		for _i in 2:
			var pid: int = next_player_id
			next_player_id += 1
			var pos: int = _random.pick(YOUTH_POSITIONS)
			var weights: Dictionary = Position.WEIGHTS[pos]
			var base_quality: int = 55 + _random.next_int(0, 15)
			var attrs: Dictionary = {}
			for attr_idx in Attribute.Kind.values():
				var weight: int = int(weights.get(attr_idx, 0))
				attrs[attr_idx] = clampi(base_quality + (weight - 2) * 4 + _random.next_int(-4, 5), Attribute.MIN_VALUE, Attribute.MAX_VALUE)
			var youth := Player.new(
				pid,
				"%s %s" % [_random.pick(YOUTH_FIRST_NAMES), _random.pick(YOUTH_LAST_NAMES)],
				17,
				"ID",
				[pos],
				PlayerAttributes.new(attrs),
				Contract.new(800, "%04d-06-30" % (next_year + 3))
			)
			youth.potential = clampi(base_quality + 15, 60, 100)
			youth.form = 60
			updated_players[pid] = youth
			new_ids.append(pid)
		club.squad.player_ids = (club.squad.player_ids as Array) + new_ids

	# 4. Update manager trophies if human finished 1st.
	var updated_manager: ManagerProfile = current_season.manager_profile
	if updated_manager != null and not entries.is_empty():
		if entries[0].team.club_id == current_season.human_club_id:
			updated_manager.trophies_won += 1
			updated_manager.reputation = mini(updated_manager.reputation + 10, 100)

	# 5. Fresh fixtures and standings.
	var club_ids: Array = updated_clubs.keys()
	club_ids.sort()
	var teams: Array[Team] = []
	for club_id in club_ids:
		var club: Club = updated_clubs[club_id]
		var squad: Array = []
		for pid in club.squad.player_ids:
			if updated_players.has(pid):
				squad.append(updated_players[pid])
		var tactics: Tactics = club.default_tactics
		if tactics == null:
			tactics = _team_tactics(current_season, club.id)
		teams.append(Team.from_squad(club.id, squad, tactics))
	var fixtures: Array[SeasonFixture] = FixtureGenerator.generate(teams, new_start_date)
	var initial_rows: Array[StandingEntry] = []
	for team in teams:
		initial_rows.append(StandingEntry.new(team))

	var next_state := SeasonState.new()
	next_state.league = current_season.league
	next_state.teams = teams
	next_state.fixtures = fixtures
	next_state.next_fixture_index = 0
	next_state.results = []
	next_state.standings = SeasonStandings.new(initial_rows)
	next_state.current_date = new_start_date
	next_state.human_club_id = current_season.human_club_id
	next_state.clubs = updated_clubs
	next_state.players = updated_players
	next_state.lineups = {}
	next_state.active_bids = []
	next_state.transfer_history = []
	next_state.player_stats = {}
	next_state.board_objectives = current_season.board_objectives
	next_state.manager_profile = updated_manager
	return RolloverOutput.new(next_state, completed)


func _team_tactics(season: SeasonState, club_id: int) -> Tactics:
	for team in season.teams:
		if (team as Team).club_id == club_id:
			return (team as Team).tactics
	return Tactics.new()
