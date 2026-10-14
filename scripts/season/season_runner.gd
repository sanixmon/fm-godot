# Source: engine/src/main/kotlin/com/footballmanager/simulation/season/SeasonRunner.kt
#   + engine/src/main/kotlin/com/footballmanager/usecase/ApplyMatchResultToWorldUseCase.kt
#     (world-application logic inlined here; see hook below)
# Parity notes:
# - start() mirrors source incl. defaults and the initial standings rows sorted by
#   the standings comparator. An optional lineups param (present in source) is kept.
# - play_next_matchday() mirrors source exactly: assert not finished; slice the next
#   round's fixtures [start, end); resolve teams by club id; simulate; append results;
#   standings.with_results; next_fixture_index = end; current_date = last fixture date.
# - resolveTeam mirror: players-empty -> base team; squad ids from clubs[clubId].squad
#   else ALL tracked players (source filters by contract.squadStatus, which has no
#   GDScript contract — documented deviation); <11 available -> base team; lineup from
#   state.lineups else Lineup.auto_select(squad, tactics) per contract (source also
#   passes clubId/allowEmergencyGk, which the contracted 2-arg signature omits);
#   missing Player refs are SKIPPED (no EmergencyGoalkeeper contract — deviation);
#   Team.from_lineup(club_id, starters, tactics, substitutes) per contract.
# - Auto-selected lineups are computed but NOT persisted back to state — this mirrors
#   the source dead-store (activeLineups is filled but never copied into state).
# - World application (fitness/morale/form/gate receipts): source delegates to
#   ApplyMatchResultToWorldUseCase. Exact numbers mirrored here: home gate receipts
#   +75000; participants fitness -12 starters / -6 otherwise; resting +12 (cap 100);
#   morale win +6 / loss -4 / draw +1; form by rating (>=7.5:+4, >=7.0:+2, <5.5:-4,
#   <6.2:-2, else 0), rating default 6.5, all clamped 1..100. Participant detection
#   mirrors source (player_stats.minutes_played > 0, else lineup starters fallback).
# - HOOK: set world_applier to a Callable(state, result)->SeasonState to replace the
#   inline application with the full future ApplyMatchResultToWorld port (cards,
#   suspensions, injuries, season stats, manager profile, board objectives need model
#   batches outside this package's contracts and are NOT handled inline).
# - CORRECTION to batch brief: there is no "+18 bench" anywhere in source; resting
#   (non-participating) players recover +12 fitness, participants lose -12/-6.
extends RefCounted
class_name SeasonRunner

const GATE_RECEIPTS: int = 75000
const STARTER_FITNESS_DRAIN: int = 12
const NON_STARTER_FITNESS_DRAIN: int = 6
const REST_FITNESS_RECOVERY: int = 12
const WIN_MORALE_DELTA: int = 6
const LOSS_MORALE_DELTA: int = -4
const DRAW_MORALE_DELTA: int = 1

var engine: MatchEngine
## Optional Callable(state: SeasonState, result: MatchResult) -> SeasonState.
## When valid, it replaces the inline world application (see header).
var world_applier: Callable = Callable()


func _init(p_engine: MatchEngine = null, p_world_applier: Callable = Callable()) -> void:
	engine = p_engine if p_engine != null else MatchEngine.new()
	world_applier = p_world_applier


func start(
	p_league: League,
	p_teams: Array,
	p_start_date: String,
	p_human_club_id = null,
	p_clubs: Dictionary = {},
	p_players: Dictionary = {},
	p_lineups: Dictionary = {}
) -> SeasonState:
	var fixtures: Array[SeasonFixture] = FixtureGenerator.generate(p_teams, p_start_date)
	var teams_typed: Array[Team] = []
	for t in p_teams:
		teams_typed.append(t as Team)
	var rows: Array[StandingEntry] = []
	for t in teams_typed:
		rows.append(StandingEntry.new(t))
	rows.sort_custom(SeasonStandings.compare)
	var no_results: Array[MatchResult] = []
	return SeasonState.new(
		p_league, teams_typed, fixtures, 0, no_results,
		SeasonStandings.new(rows), p_start_date, p_human_club_id,
		p_clubs, p_players, p_lineups
	)


## Plays every fixture of the next matchday and returns the advanced state.
func play_next_matchday(state: SeasonState) -> SeasonState:
	assert(not state.is_finished, "season already finished")
	var start_idx: int = state.next_fixture_index
	var round: int = (state.fixtures[start_idx] as SeasonFixture).round
	var end_idx: int = start_idx
	while end_idx < state.fixtures.size() and (state.fixtures[end_idx] as SeasonFixture).round == round:
		end_idx += 1
	var team_of: Dictionary = {}
	for t in state.teams:
		team_of[(t as Team).club_id] = t
	var matchday_fixtures: Array = state.fixtures.slice(start_idx, end_idx)
	var active_lineups: Dictionary = {}
	var results: Array[MatchResult] = []
	for fx in matchday_fixtures:
		var f: SeasonFixture = fx
		var home_team: Team = _resolve_team(state, team_of, active_lineups, f.home.club_id)
		var away_team: Team = _resolve_team(state, team_of, active_lineups, f.away.club_id)
		results.append(engine.simulate(home_team, away_team) as MatchResult)
	var progressed: SeasonState = state.duplicate()
	for r in results:
		progressed.results.append(r)
	progressed.standings = state.standings.with_results(matchday_fixtures, results)
	progressed.next_fixture_index = end_idx
	progressed.current_date = (matchday_fixtures.back() as SeasonFixture).date
	if not state.players.is_empty():
		for r in results:
			progressed = _apply_match_result(progressed, active_lineups, r)
	return progressed


func _squad_ids(state: SeasonState, club_id: int) -> Array:
	if state.clubs.has(club_id):
		var club: Club = state.clubs[club_id]
		return (club.squad.player_ids as Array).duplicate()
	var ids: Array = []
	for pid in state.players.keys():
		ids.append(pid)
	return ids


func _resolve_team(state: SeasonState, team_of: Dictionary, active_lineups: Dictionary, club_id: int) -> Team:
	var base_team: Team = team_of[club_id]
	if state.players.is_empty():
		return base_team
	var club_player_ids: Array = _squad_ids(state, club_id)
	var squad_players: Array = []
	for pid in club_player_ids:
		if state.players.has(pid):
			squad_players.append(state.players[pid])
	if squad_players.size() < 11:
		return base_team
	var lineup: Lineup = null
	if state.lineups.has(club_id):
		lineup = state.lineups[club_id]
	else:
		lineup = Lineup.auto_select(squad_players, base_team.tactics)
	active_lineups[club_id] = lineup
	var starters: Array = []
	for pid in (lineup.starters as Array):
		if state.players.has(pid):
			starters.append(state.players[pid])
	var subs: Array = []
	for pid in (lineup.substitutes as Array):
		if state.players.has(pid):
			subs.append(state.players[pid])
	return Team.from_lineup(club_id, starters, base_team.tactics, subs)


func _apply_match_result(progressed: SeasonState, active_lineups: Dictionary, result: MatchResult) -> SeasonState:
	if world_applier.is_valid():
		return world_applier.call(progressed, result) as SeasonState
	_apply_gate_receipts(progressed, result)
	_apply_player_condition(progressed, active_lineups, result)
	return progressed


func _apply_gate_receipts(progressed: SeasonState, result: MatchResult) -> void:
	if progressed.clubs.has(result.home_club_id):
		var home_club: Club = progressed.clubs[result.home_club_id]
		home_club.finance.balance = home_club.finance.balance + GATE_RECEIPTS


static func _match_stat(stat: Variant, field: String, fallback: Variant) -> Variant:
	if stat == null:
		return fallback
	if stat is Dictionary:
		return (stat as Dictionary).get(field, fallback)
	return (stat as Object).get(field) if (stat as Object).get(field) != null else fallback


func _apply_player_condition(progressed: SeasonState, active_lineups: Dictionary, result: MatchResult) -> void:
	var home_id: int = result.home_club_id
	var away_id: int = result.away_club_id
	var home_win: bool = result.home_score > result.away_score
	var away_win: bool = result.away_score > result.home_score
	var home_squad: Array = _squad_ids(progressed, home_id)
	var away_squad: Array = _squad_ids(progressed, away_id)
	var seen: Dictionary = {}
	var squad_ids: Array = []
	for pid in home_squad + away_squad:
		if not seen.has(pid):
			seen[pid] = true
			squad_ids.append(pid)
	var stats: Dictionary = result.player_stats
	var ratings: Dictionary = result.player_ratings
	var has_stats: bool = not stats.is_empty()
	for pid in squad_ids:
		if not progressed.players.has(pid):
			continue
		var player: Player = progressed.players[pid]
		var is_home: bool = pid in home_squad
		var won: bool = (is_home and home_win) or (not is_home and away_win)
		var lost: bool = (is_home and away_win) or (not is_home and home_win)
		var stat: Variant = stats.get(pid, stats.get(str(pid), null))
		var participant := false
		var starter := true
		if has_stats:
			participant = stat != null and int(SeasonRunner._match_stat(stat, "minutes_played", 0)) > 0
			starter = bool(SeasonRunner._match_stat(stat, "is_starter", true))
		else:
			var home_starters: Array = _fallback_starters(progressed, active_lineups, home_id, home_squad)
			var away_starters: Array = _fallback_starters(progressed, active_lineups, away_id, away_squad)
			participant = home_starters.has(pid) or away_starters.has(pid)
			starter = true
		if participant:
			var rating: float = float(ratings.get(pid, ratings.get(str(pid), 6.5)))
			var form_delta := 0
			if rating >= 7.5:
				form_delta = 4
			elif rating >= 7.0:
				form_delta = 2
			elif rating < 5.5:
				form_delta = -4
			elif rating < 6.2:
				form_delta = -2
			player.form = clampi(player.form + form_delta, 1, 100)
			var drain: int = STARTER_FITNESS_DRAIN if starter else NON_STARTER_FITNESS_DRAIN
			player.fitness = maxi(1, player.fitness - drain)
			var morale_delta: int = DRAW_MORALE_DELTA
			if won:
				morale_delta = WIN_MORALE_DELTA
			elif lost:
				morale_delta = LOSS_MORALE_DELTA
			player.morale = clampi(player.morale + morale_delta, 1, 100)
		else:
			if player.fitness < 100:
				player.fitness = mini(100, player.fitness + REST_FITNESS_RECOVERY)


func _fallback_starters(state: SeasonState, active_lineups: Dictionary, club_id: int, squad_ids: Array) -> Array:
	if active_lineups.has(club_id):
		return ((active_lineups[club_id] as Lineup).starters as Array).duplicate()
	if state.lineups.has(club_id):
		return ((state.lineups[club_id] as Lineup).starters as Array).duplicate()
	return squad_ids.slice(0, 11)
