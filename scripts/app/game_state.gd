# Autoload singleton (registered as `AppState` in project.godot).
# Owns the active career: Game aggregate + season progression helpers.
# Mirrors GameViewModel responsibilities without any UI framework coupling.
extends Node

signal career_changed
signal status_changed(message: String)
signal nav_changed

var game: Game = null
var human_club_id: int = 1
var active_section: String = "menu"
var status_message: String = "":
	set(v):
		status_message = v
		status_changed.emit(v)

## Transient UI selection (not saved).
var selected_player_id: int = -1
var selected_starter_id: int = -1
var selected_market_player_id: int = -1
var validation_error: String = ""
var wizard_club_id: int = 1

var _runner: SeasonRunner = SeasonRunner.new()


func has_career() -> bool:
	return game != null and game.current_season != null


func season() -> SeasonState:
	return game.current_season if game != null else null


func human_club() -> Club:
	return game.club(human_club_id)


func goto_section(section: String) -> void:
	active_section = section
	nav_changed.emit()


func human_team() -> Team:
	var s: SeasonState = season()
	for t in s.teams:
		if t.club_id == human_club_id:
			return t
	return Team.from_squad(human_club_id, human_squad(), Tactics.new())


func human_lineup():
	var s: SeasonState = season()
	if s.lineups.has(human_club_id):
		return s.lineups[human_club_id]
	return null


func last_user_result():
	var out = null
	for r in season().results:
		if r.home_club_id == human_club_id or r.away_club_id == human_club_id:
			out = r
	return out


func next_fixture():
	var s: SeasonState = season()
	if s.next_fixture_index < s.fixtures.size():
		return s.fixtures[s.next_fixture_index]
	return null


func is_matchday_today() -> bool:
	var fx = next_fixture()
	return fx != null and fx.date <= season().current_date


func days_until_next_match() -> int:
	var fx = next_fixture()
	if fx == null:
		return 0
	return maxi(FMDate.days_between(season().current_date, fx.date), 0)


func _apply_tactics(mut: Callable) -> void:
	var t: Tactics = human_team().tactics
	var updated := Tactics.new()
	updated.formation = t.formation
	updated.mentality = t.mentality
	updated.tempo = t.tempo
	updated.pressing = t.pressing
	updated.passing = t.passing
	mut.call(updated)
	validation_error = ""
	_commit(season().set_tactics(human_club_id, updated))


func set_formation(kind: int) -> void:
	_apply_tactics(func(t: Tactics) -> void: t.formation = kind)


func set_mentality(kind: int) -> void:
	_apply_tactics(func(t: Tactics) -> void: t.mentality = kind)


func set_tempo(kind: int) -> void:
	_apply_tactics(func(t: Tactics) -> void: t.tempo = kind)


func set_pressing(kind: int) -> void:
	_apply_tactics(func(t: Tactics) -> void: t.pressing = kind)


func set_passing(kind: int) -> void:
	_apply_tactics(func(t: Tactics) -> void: t.passing = kind)


func auto_xi() -> void:
	var lineup: Lineup = Lineup.auto_select(human_squad(), human_team().tactics, true, human_club_id)
	selected_starter_id = -1
	validation_error = ""
	_commit(season().set_lineup(human_club_id, lineup))


## Swap a starter with a bench player. Returns false + sets validation_error
## when the resulting lineup is illegal.
func swap_starter_bench(starter_id: int, bench_id: int) -> bool:
	var current: Lineup = human_lineup()
	if current == null:
		return false
	var starters: Array = current.starters.duplicate()
	var subs: Array = current.substitutes.duplicate()
	var si: int = starters.find(starter_id)
	var bi: int = subs.find(bench_id)
	if si < 0 or bi < 0:
		return false
	starters[si] = bench_id
	subs[bi] = starter_id
	var candidate := Lineup.new(starters, subs)
	var verdict: Dictionary = LineupValidator.validate(candidate, season().players)
	if not verdict.get("valid", false):
		validation_error = str(verdict.get("message", "Illegal lineup"))
		return false
	selected_starter_id = -1
	validation_error = ""
	_commit(season().set_lineup(human_club_id, candidate))
	return true


func set_player_training(player_id: int, focus: int, intensity: int) -> void:
	_commit(PlayerDevelopment.new().set_player_training(season(), player_id, focus, intensity))


func set_club_training(focus: int) -> void:
	_commit(PlayerDevelopment.new().set_club_squad_training(season(), human_club_id, focus))


func human_squad() -> Array:
	return game.squad(human_club_id)


func start_new_career(manager_name: String, nationality: String, club_id: int) -> void:
	var fresh: Game = ModLoader.load_from_file("res://data/laliga.json")
	var league: League = null
	for c in fresh.competitions.values():
		if c is League:
			league = c
			break
	assert(league != null, "Mod has no league competition")
	var teams: Array = []
	for cid in league.club_ids:
		var club: Club = fresh.clubs[int(cid)]
		var tactics: Tactics = club.default_tactics if club.default_tactics != null else Tactics.new()
		teams.append(Team.from_squad(int(cid), fresh.squad(int(cid)), tactics))
	var started: SeasonState = _runner.start(
		league, teams, fresh.current_date, club_id, fresh.clubs, fresh.players
	)
	var profile := ManagerProfile.new()
	profile.name = manager_name
	profile.nationality = nationality
	profile.club_id = club_id
	started.manager_profile = profile
	var objectives := BoardObjectives.new()
	objectives.club_id = club_id
	objectives.target_league_position = 4
	started.board_objectives = {club_id: objectives}
	fresh.current_season = started
	fresh.current_date = started.current_date
	game = fresh
	human_club_id = club_id
	active_section = "dashboard"
	career_changed.emit()


## Single Continue entry point (mirrors advanceSmart).
func advance() -> void:
	var s: SeasonState = season()
	if s == null:
		return
	if s.is_finished:
		roll_over()
		return
	var fx: SeasonFixture = s.fixtures[s.next_fixture_index] if s.next_fixture_index < s.fixtures.size() else null
	if fx != null and fx.date <= s.current_date:
		play_matchday()
	else:
		var next: SeasonState = AdvanceDay.new().execute(s)
		_commit(next)


func play_matchday() -> void:
	var s: SeasonState = season()
	var user_before: int = _user_result_count(s)
	var next: SeasonState = _runner.play_next_matchday(s)
	_commit(next)


func roll_over() -> void:
	var s: SeasonState = season()
	_commit(SeasonRollover.new().execute(s))


func execute_transfer(player_id: int, from_club_id: int, to_club_id: int, fee: int) -> bool:
	var req := DirectTransfer.Request.new(player_id, from_club_id, to_club_id, fee)
	var next: SeasonState = DirectTransfer.new().execute(season(), req)
	_commit(next)
	return true


func save_career(slot: String = "manual") -> void:
	SaveGame.save_game(game, SaveGame.slot_path(slot))
	status_message = "Career saved (%s)" % slot


func load_career(slot: String = "manual") -> void:
	var loaded: Game = SaveGame.load_game(SaveGame.slot_path(slot))
	game = loaded
	if season() != null and season().human_club_id != null:
		human_club_id = int(season().human_club_id)
	active_section = "dashboard"
	career_changed.emit()


func _user_result_count(s: SeasonState) -> int:
	var n := 0
	for r in s.results:
		if r.home_club_id == human_club_id or r.away_club_id == human_club_id:
			n += 1
	return n


func _commit(next: SeasonState) -> void:
	next.manager_profile = season().manager_profile
	next.board_objectives = season().board_objectives
	game.current_season = next
	game.current_date = next.current_date
	game.clubs = next.clubs
	game.players = next.players
	career_changed.emit()
