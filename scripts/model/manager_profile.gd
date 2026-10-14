# Source: engine/.../model/ManagerProfile.kt.
class_name ManagerProfile
extends RefCounted

var name: String = ""
var nationality: String = "ID"
var club_id: int = 0
var reputation: int = 50
var trophies_won: int = 0
var matches_managed: int = 0
var wins: int = 0
var draws: int = 0
var losses: int = 0


func win_rate_percentage() -> int:
	if matches_managed > 0:
		return int(float(wins) / float(matches_managed) * 100.0)
	return 0


func with_match_result(is_win: bool, is_draw: bool) -> ManagerProfile:
	var m := ManagerProfile.new()
	m.name = name
	m.nationality = nationality
	m.club_id = club_id
	m.reputation = reputation
	m.trophies_won = trophies_won
	m.matches_managed = matches_managed + 1
	m.wins = wins + 1 if is_win else wins
	m.draws = draws + 1 if is_draw else draws
	m.losses = losses if (is_win or is_draw) else losses + 1
	var delta: int = 2 if is_win else (0 if is_draw else -1)
	m.reputation = clampi(reputation + delta, 1, 100)
	return m


func to_dict() -> Dictionary:
	return {
		"name": name,
		"nationality": nationality,
		"clubId": club_id,
		"reputation": reputation,
		"trophiesWon": trophies_won,
		"matchesManaged": matches_managed,
		"wins": wins,
		"draws": draws,
		"losses": losses,
	}


static func from_dict(d: Dictionary) -> ManagerProfile:
	var m := ManagerProfile.new()
	m.name = str(d.get("name", "?"))
	m.nationality = str(d.get("nationality", "ID"))
	m.club_id = int(d.get("clubId", 0))
	m.reputation = int(d.get("reputation", 50))
	m.trophies_won = int(d.get("trophiesWon", 0))
	m.matches_managed = int(d.get("matchesManaged", 0))
	m.wins = int(d.get("wins", 0))
	m.draws = int(d.get("draws", 0))
	m.losses = int(d.get("losses", 0))
	return m
