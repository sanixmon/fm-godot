# Source: engine/src/main/kotlin/com/footballmanager/simulation/season/StandingEntry.kt
# Parity notes:
# - Fields mirror exactly: team/played/won/drawn/lost/goals_for/goals_against.
# - points = won * 3 + drawn; goal_difference = goals_for - goals_against.
# - record() returns a NEW entry (Kotlin data-class copy semantics); team ref shared.
# - Kotlin camelCase goalsFor/goalsAgainst -> snake_case keys for save compat.
extends RefCounted
class_name StandingEntry

var team: Team
var played: int = 0
var won: int = 0
var drawn: int = 0
var lost: int = 0
var goals_for: int = 0
var goals_against: int = 0

var points: int:
	get:
		return won * 3 + drawn

var goal_difference: int:
	get:
		return goals_for - goals_against


func _init(
	p_team: Team = null,
	p_played: int = 0,
	p_won: int = 0,
	p_drawn: int = 0,
	p_lost: int = 0,
	p_goals_for: int = 0,
	p_goals_against: int = 0
) -> void:
	team = p_team
	played = p_played
	won = p_won
	drawn = p_drawn
	lost = p_lost
	goals_for = p_goals_for
	goals_against = p_goals_against


## Returns a new entry reflecting a [scored]-[conceded] result.
func record(scored: int, conceded: int) -> StandingEntry:
	return StandingEntry.new(
		team,
		played + 1,
		won + (1 if scored > conceded else 0),
		drawn + (1 if scored == conceded else 0),
		lost + (1 if scored < conceded else 0),
		goals_for + scored,
		goals_against + conceded
	)


func to_dict() -> Dictionary:
	return {
		"team": team.to_dict() if team != null else {},
		"played": played,
		"won": won,
		"drawn": drawn,
		"lost": lost,
		"goals_for": goals_for,
		"goals_against": goals_against,
	}


static func from_dict(d: Dictionary) -> StandingEntry:
	var t: Team = null
	if d.get("team") is Dictionary and not (d.get("team") as Dictionary).is_empty():
		t = Team.from_dict(d["team"] as Dictionary)
	elif d.get("team") is Team:
		t = d["team"]
	return StandingEntry.new(
		t,
		int(d.get("played", 0)),
		int(d.get("won", 0)),
		int(d.get("drawn", 0)),
		int(d.get("lost", 0)),
		int(d.get("goals_for", 0)),
		int(d.get("goals_against", 0))
	)
