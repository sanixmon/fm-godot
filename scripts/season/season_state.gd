# Source: engine/src/main/kotlin/com/footballmanager/simulation/season/SeasonState.kt
# Parity notes (READ before changing copy semantics):
# - ALL source fields mirrored: league, teams, fixtures, next_fixture_index (=0),
#   results (=[]), standings, current_date, human_club_id (=null), clubs (={}),
#   players (={}), lineups (={}), active_bids (=[]), transfer_history (=[ ]),
#   player_stats (={}), board_objectives (={}), manager_profile (=null).
# - Derived Kotlin val-getters (is_finished, remaining_fixtures, next_matchday) are
#   GDScript property getters, so `state.is_finished` (no call parens) works.
#   next_matchday returns int or null (null once finished).
# - Kotlin data-class copy() semantics: set_lineup/set_tactics/duplicate() RETURN A
#   NEW SeasonState. Collections are duplicated (Array/Dictionary.duplicate());
#   element REFS (Player/Club/Team/...) are SHARED because GDScript RefCounted has
#   no generic clone and Player is contractually mutable. Consequence: mutating a
#   Player's condition via one snapshot is visible from earlier snapshots holding
#   the same ref. Treat states as a linear chain (only keep the latest), same as
#   the Kotlin call sites do.
# - set_tactics: source does `team.copy(tactics = ...)` (keeps base attack/defense).
#   GDScript rebuilds via Team.from_lineup(club_id, starters, tactics, substitutes),
#   which re-derives base strength from the same starters (identical result for
#   from_squad/from_lineup-built teams). If Team ever gains copy()/with_tactics(),
#   prefer that here. Teams with empty starters fall back to in-place tactics
#   assignment (shared ref) since a Team cannot be constructed without players.
# - Serialization: dictionaries with int keys serialize as {str(id): ...}; dates are
#   ISO strings. Nested model from_dict class names (Club/Player/Lineup/TransferBid/
#   TransferRecord/PlayerSeasonStats/BoardObjectives/ManagerProfile) are TRUSTED from
#   sibling batches (same names as the Kotlin model types). from_dict also passes
#   through values that are already live objects (not Dictionaries).
extends RefCounted
class_name SeasonState

var league: League
var teams: Array[Team] = []
var fixtures: Array[SeasonFixture] = []
var next_fixture_index: int = 0
var results: Array[MatchResult] = []
var standings: SeasonStandings
var current_date: String = ""
var human_club_id = null # int or null
var clubs: Dictionary = {} # int club_id -> Club
var players: Dictionary = {} # int player_id -> Player
var lineups: Dictionary = {} # int club_id -> Lineup
var active_bids: Array = [] # Array[TransferBid]
var transfer_history: Array = [] # Array[TransferRecord]
var player_stats: Dictionary = {} # int player_id -> PlayerSeasonStats
var board_objectives: Dictionary = {} # int club_id -> BoardObjectives
var manager_profile: ManagerProfile = null

var is_finished: bool:
	get:
		return next_fixture_index >= fixtures.size()

var remaining_fixtures: int:
	get:
		return fixtures.size() - next_fixture_index

## Round number of the next matchday to play, or null once finished.
var next_matchday: Variant:
	get:
		if next_fixture_index < fixtures.size():
			return (fixtures[next_fixture_index] as SeasonFixture).round
		return null


func _init(
	p_league: League = null,
	p_teams: Array[Team] = [],
	p_fixtures: Array[SeasonFixture] = [],
	p_next_fixture_index: int = 0,
	p_results: Array[MatchResult] = [],
	p_standings: SeasonStandings = null,
	p_current_date: String = "",
	p_human_club_id = null,
	p_clubs: Dictionary = {},
	p_players: Dictionary = {},
	p_lineups: Dictionary = {},
	p_active_bids: Array = [],
	p_transfer_history: Array = [],
	p_player_stats: Dictionary = {},
	p_board_objectives: Dictionary = {},
	p_manager_profile: ManagerProfile = null
) -> void:
	assert(p_next_fixture_index >= 0 and p_next_fixture_index <= p_fixtures.size(), "nextFixtureIndex out of range")
	assert(p_results.size() == p_next_fixture_index, "results (%d) must match played fixtures (%d)" % [p_results.size(), p_next_fixture_index])
	league = p_league
	teams = p_teams
	fixtures = p_fixtures
	next_fixture_index = p_next_fixture_index
	results = p_results
	standings = p_standings
	current_date = p_current_date
	human_club_id = p_human_club_id
	clubs = p_clubs
	players = p_players
	lineups = p_lineups
	active_bids = p_active_bids
	transfer_history = p_transfer_history
	player_stats = p_player_stats
	board_objectives = p_board_objectives
	manager_profile = p_manager_profile


## New state sharing element refs but with duplicated collections.
func duplicate() -> SeasonState:
	return SeasonState.new(
		league,
		teams.duplicate(),
		fixtures.duplicate(),
		next_fixture_index,
		results.duplicate(),
		standings,
		current_date,
		human_club_id,
		clubs.duplicate(),
		players.duplicate(),
		lineups.duplicate(),
		active_bids.duplicate(),
		transfer_history.duplicate(),
		player_stats.duplicate(),
		board_objectives.duplicate(),
		manager_profile
	)


## Returns a copy with [lineup] set for the given club.
func set_lineup(club_id: int, lineup: Lineup) -> SeasonState:
	var nxt: SeasonState = duplicate()
	nxt.lineups[club_id] = lineup
	return nxt


## Returns a copy with [tactics] applied to the given club's team and standing row.
## Returns self unchanged when no team exists for club_id (mirrors `?: return this`).
func set_tactics(club_id: int, tactics: Tactics) -> SeasonState:
	var current: Team = null
	for t in teams:
		if (t as Team).club_id == club_id:
			current = t
			break
	if current == null:
		return self
	var updated: Team
	if (current.starters as Array).is_empty():
		current.tactics = tactics
		updated = current
	else:
		updated = Team.from_lineup(club_id, current.starters, tactics, current.substitutes)
	var nxt: SeasonState = duplicate()
	var new_teams: Array[Team] = []
	for t in teams:
		new_teams.append(updated if (t as Team).club_id == club_id else t)
	nxt.teams = new_teams
	var new_entries: Array[StandingEntry] = []
	for e in standings.entries:
		var entry: StandingEntry = e
		if entry.team.club_id == club_id:
			new_entries.append(StandingEntry.new(updated, entry.played, entry.won, entry.drawn, entry.lost, entry.goals_for, entry.goals_against))
		else:
			new_entries.append(entry)
	nxt.standings = SeasonStandings.new(new_entries)
	return nxt


static func _ser_value(v: Variant) -> Variant:
	if v is Object and (v as Object).has_method("to_dict"):
		return (v as Object).call("to_dict")
	return v


func to_dict() -> Dictionary:
	var teams_arr: Array = []
	for t in teams:
		teams_arr.append((t as Team).to_dict())
	var fx_arr: Array = []
	for f in fixtures:
		fx_arr.append((f as SeasonFixture).to_dict())
	var res_arr: Array = []
	for r in results:
		res_arr.append((r as MatchResult).to_dict())
	var clubs_d: Dictionary = {}
	for k in clubs.keys():
		clubs_d[str(k)] = SeasonState._ser_value(clubs[k])
	var players_d: Dictionary = {}
	for k in players.keys():
		players_d[str(k)] = SeasonState._ser_value(players[k])
	var lineups_d: Dictionary = {}
	for k in lineups.keys():
		lineups_d[str(k)] = SeasonState._ser_value(lineups[k])
	var bids_arr: Array = []
	for b in active_bids:
		bids_arr.append(SeasonState._ser_value(b))
	var hist_arr: Array = []
	for h in transfer_history:
		hist_arr.append(SeasonState._ser_value(h))
	var stats_d: Dictionary = {}
	for k in player_stats.keys():
		stats_d[str(k)] = SeasonState._ser_value(player_stats[k])
	var board_d: Dictionary = {}
	for k in board_objectives.keys():
		board_d[str(k)] = SeasonState._ser_value(board_objectives[k])
	return {
		"league": league.to_dict() if league != null else {},
		"teams": teams_arr,
		"fixtures": fx_arr,
		"next_fixture_index": next_fixture_index,
		"results": res_arr,
		"standings": standings.to_dict() if standings != null else {},
		"current_date": current_date,
		"human_club_id": human_club_id,
		"clubs": clubs_d,
		"players": players_d,
		"lineups": lineups_d,
		"active_bids": bids_arr,
		"transfer_history": hist_arr,
		"player_stats": stats_d,
		"board_objectives": board_d,
		"manager_profile": manager_profile.to_dict() if manager_profile != null else null,
	}


static func from_dict(d: Dictionary) -> SeasonState:
	var lg: League = null
	if d.get("league") is Dictionary and not (d.get("league") as Dictionary).is_empty():
		lg = League.from_dict(d["league"] as Dictionary)
	elif d.get("league") is League:
		lg = d["league"]
	var teams: Array[Team] = []
	for raw in d.get("teams", []):
		if raw is Team:
			teams.append(raw)
		elif raw is Dictionary:
			teams.append(Team.from_dict(raw))
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
	var clubs: Dictionary = {}
	for k in (d.get("clubs", {}) as Dictionary).keys():
		var v: Variant = (d.get("clubs") as Dictionary)[k]
		clubs[int(k)] = Club.from_dict(v) if v is Dictionary else v
	var players: Dictionary = {}
	for k in (d.get("players", {}) as Dictionary).keys():
		var v: Variant = (d.get("players") as Dictionary)[k]
		players[int(k)] = Player.from_dict(v) if v is Dictionary else v
	var lineups: Dictionary = {}
	for k in (d.get("lineups", {}) as Dictionary).keys():
		var v: Variant = (d.get("lineups") as Dictionary)[k]
		lineups[int(k)] = Lineup.from_dict(v) if v is Dictionary else v
	var bids: Array = []
	for raw in d.get("active_bids", []):
		bids.append(TransferBid.from_dict(raw) if raw is Dictionary else raw)
	var hist: Array = []
	for raw in d.get("transfer_history", []):
		hist.append(TransferRecord.from_dict(raw) if raw is Dictionary else raw)
	var stats: Dictionary = {}
	for k in (d.get("player_stats", {}) as Dictionary).keys():
		var v: Variant = (d.get("player_stats") as Dictionary)[k]
		stats[int(k)] = PlayerSeasonStats.from_dict(v) if v is Dictionary else v
	var board: Dictionary = {}
	for k in (d.get("board_objectives", {}) as Dictionary).keys():
		var v: Variant = (d.get("board_objectives") as Dictionary)[k]
		board[int(k)] = BoardObjectives.from_dict(v) if v is Dictionary else v
	var mgr: ManagerProfile = null
	if d.get("manager_profile") is Dictionary:
		mgr = ManagerProfile.from_dict(d["manager_profile"] as Dictionary)
	elif d.get("manager_profile") is ManagerProfile:
		mgr = d["manager_profile"]
	return SeasonState.new(
		lg, teams, fx, int(d.get("next_fixture_index", 0)), res, st,
		str(d.get("current_date", "")), d.get("human_club_id"),
		clubs, players, lineups, bids, hist, stats, board, mgr
	)
