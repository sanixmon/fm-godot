# Source: engine/src/main/kotlin/com/footballmanager/simulation/MatchStats.kt (PlayerMatchStats data class)
# Parity notes: field-for-field port; ids are 64-bit-safe Godot ints.
class_name PlayerMatchStats
extends RefCounted

var player_id: int = 0
var team_id: int = 0
var minutes_played: int = 0
var is_starter: bool = false
var shots: int = 0
var shots_on_target: int = 0
var goals: int = 0
var assists: int = 0
var saves: int = 0
var fouls: int = 0
var yellow_cards: int = 0
var red_cards: int = 0
var defensive_contributions: int = 0
var passing_contributions: int = 0
var attacking_contributions: int = 0
var is_injured: bool = false
var is_substituted_out: bool = false
var is_substituted_in: bool = false
var is_red_carded: bool = false


func _init(
	p_player_id: int = 0,
	p_team_id: int = 0,
	p_minutes_played: int = 0,
	p_is_starter: bool = false,
	p_shots: int = 0,
	p_shots_on_target: int = 0,
	p_goals: int = 0,
	p_assists: int = 0,
	p_saves: int = 0,
	p_fouls: int = 0,
	p_yellow_cards: int = 0,
	p_red_cards: int = 0,
	p_defensive_contributions: int = 0,
	p_passing_contributions: int = 0,
	p_attacking_contributions: int = 0,
	p_is_injured: bool = false,
	p_is_substituted_out: bool = false,
	p_is_substituted_in: bool = false,
	p_is_red_carded: bool = false,
) -> void:
	player_id = p_player_id
	team_id = p_team_id
	minutes_played = p_minutes_played
	is_starter = p_is_starter
	shots = p_shots
	shots_on_target = p_shots_on_target
	goals = p_goals
	assists = p_assists
	saves = p_saves
	fouls = p_fouls
	yellow_cards = p_yellow_cards
	red_cards = p_red_cards
	defensive_contributions = p_defensive_contributions
	passing_contributions = p_passing_contributions
	attacking_contributions = p_attacking_contributions
	is_injured = p_is_injured
	is_substituted_out = p_is_substituted_out
	is_substituted_in = p_is_substituted_in
	is_red_carded = p_is_red_carded


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"team_id": team_id,
		"minutes_played": minutes_played,
		"is_starter": is_starter,
		"shots": shots,
		"shots_on_target": shots_on_target,
		"goals": goals,
		"assists": assists,
		"saves": saves,
		"fouls": fouls,
		"yellow_cards": yellow_cards,
		"red_cards": red_cards,
		"defensive_contributions": defensive_contributions,
		"passing_contributions": passing_contributions,
		"attacking_contributions": attacking_contributions,
		"is_injured": is_injured,
		"is_substituted_out": is_substituted_out,
		"is_substituted_in": is_substituted_in,
		"is_red_carded": is_red_carded,
	}


static func from_dict(d: Dictionary) -> PlayerMatchStats:
	return PlayerMatchStats.new(
		int(d.get("player_id", 0)),
		int(d.get("team_id", 0)),
		int(d.get("minutes_played", 0)),
		bool(d.get("is_starter", false)),
		int(d.get("shots", 0)),
		int(d.get("shots_on_target", 0)),
		int(d.get("goals", 0)),
		int(d.get("assists", 0)),
		int(d.get("saves", 0)),
		int(d.get("fouls", 0)),
		int(d.get("yellow_cards", 0)),
		int(d.get("red_cards", 0)),
		int(d.get("defensive_contributions", 0)),
		int(d.get("passing_contributions", 0)),
		int(d.get("attacking_contributions", 0)),
		bool(d.get("is_injured", false)),
		bool(d.get("is_substituted_out", false)),
		bool(d.get("is_substituted_in", false)),
		bool(d.get("is_red_carded", false)),
	)
