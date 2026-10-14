# Source: engine/.../model/Game.kt (root save aggregate; entities by id).
class_name Game
extends RefCounted

var game_name: String = ""
var current_date: String = "2026-08-01"
var clubs: Dictionary = {}
var players: Dictionary = {}
var competitions: Dictionary = {}
var calendar = null
var last_season = null
var current_season = null


func club(id: int) -> Club:
	assert(clubs.has(id), "Unknown club id: %d" % id)
	return clubs[id]


func player(id: int):
	assert(players.has(id), "Unknown player id: %d" % id)
	return players[id]


func competition(id: int) -> Competition:
	assert(competitions.has(id), "Unknown competition id: %d" % id)
	return competitions[id]


## Players registered to a club, in squad order.
func squad(club_id: int) -> Array:
	var out: Array = []
	for pid: int in club(club_id).squad.player_ids:
		if players.has(pid):
			out.append(players[pid])
	return out


func to_dict() -> Dictionary:
	var clubs_d := {}
	for id: int in clubs:
		clubs_d[str(id)] = clubs[id].to_dict()
	var players_d := {}
	for id: int in players:
		players_d[str(id)] = players[id].to_dict()
	var comps_d := {}
	for id: int in competitions:
		comps_d[str(id)] = competitions[id].to_dict()
	return {
		"name": game_name,
		"currentDate": current_date,
		"clubs": clubs_d,
		"players": players_d,
		"competitions": comps_d,
		"calendar": calendar.to_dict() if calendar != null else {"fixtures": []},
		"lastSeason": last_season.to_dict() if last_season != null else null,
		"currentSeason": current_season.to_dict() if current_season != null else null,
	}


static func from_dict(d: Dictionary) -> Game:
	var g := Game.new()
	g.game_name = str(d.get("name", "Career"))
	g.current_date = str(d.get("currentDate", "2026-08-01"))
	for k: String in d.get("clubs", {}):
		g.clubs[int(k)] = Club.from_dict(d["clubs"][k])
	for k: String in d.get("players", {}):
		g.players[int(k)] = Player.from_dict(d["players"][k])
	for k: String in d.get("competitions", {}):
		g.competitions[int(k)] = Competition.from_dict(d["competitions"][k])
	g.calendar = CalendarData.from_dict(d.get("calendar", {}))
	if d.get("lastSeason", null) != null:
		g.last_season = SeasonResult.from_dict(d["lastSeason"])
	if d.get("currentSeason", null) != null:
		g.current_season = SeasonState.from_dict(d["currentSeason"])
	return g
