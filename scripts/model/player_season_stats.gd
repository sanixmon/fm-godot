# Source: engine/src/main/kotlin/com/footballmanager/model/PlayerSeasonStats.kt
# GDScript port of the PlayerSeasonStats value type.
# Copy semantics preserved: with_match_appearance() returns a NEW instance,
# mirroring Kotlin copy(). Field names are snake_case mirrors of the originals.
class_name PlayerSeasonStats
extends RefCounted

var player_id: int = 0
var appearances: int = 0
var starts: int = 0
var substitute_appearances: int = 0
var goals: int = 0
var assists: int = 0
var clean_sheets: int = 0
var yellow_cards: int = 0
var red_cards: int = 0
var total_rating_points: float = 0.0
var unserved_yellow_cards: int = 0


func average_rating() -> float:
	if appearances <= 0:
		return 0.0
	return total_rating_points / float(appearances)


func with_match_appearance(is_starter: bool, goals_scored: int = 0, assists_made: int = 0, clean_sheet: bool = false, match_rating: float = 6.5, yellow: bool = false, red: bool = false, new_unserved_yellow_cards: int = -1) -> PlayerSeasonStats:
	# Default mirrors Kotlin: unservedYellowCards + (1 if yellow and not red else 0).
	# -1 sentinel: unserved counts are never negative, so -1 unambiguously means "default".
	var unserved: int = new_unserved_yellow_cards
	if unserved < 0:
		unserved = unserved_yellow_cards + (1 if (yellow and not red) else 0)
	var next := PlayerSeasonStats.new()
	next.player_id = player_id
	next.appearances = appearances + 1
	next.starts = starts + (1 if is_starter else 0)
	next.substitute_appearances = substitute_appearances + (0 if is_starter else 1)
	next.goals = goals + goals_scored
	next.assists = assists + assists_made
	next.clean_sheets = clean_sheets + (1 if clean_sheet else 0)
	next.yellow_cards = yellow_cards + (1 if yellow else 0)
	next.red_cards = red_cards + (1 if red else 0)
	next.total_rating_points = total_rating_points + match_rating
	next.unserved_yellow_cards = unserved
	return next


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"appearances": appearances,
		"starts": starts,
		"substitute_appearances": substitute_appearances,
		"goals": goals,
		"assists": assists,
		"clean_sheets": clean_sheets,
		"yellow_cards": yellow_cards,
		"red_cards": red_cards,
		"total_rating_points": total_rating_points,
		"unserved_yellow_cards": unserved_yellow_cards,
	}


static func from_dict(data: Dictionary) -> PlayerSeasonStats:
	var stats := PlayerSeasonStats.new()
	stats.player_id = int(data.get("player_id", 0))
	stats.appearances = int(data.get("appearances", 0))
	stats.starts = int(data.get("starts", 0))
	stats.substitute_appearances = int(data.get("substitute_appearances", 0))
	stats.goals = int(data.get("goals", 0))
	stats.assists = int(data.get("assists", 0))
	stats.clean_sheets = int(data.get("clean_sheets", 0))
	stats.yellow_cards = int(data.get("yellow_cards", 0))
	stats.red_cards = int(data.get("red_cards", 0))
	stats.total_rating_points = float(data.get("total_rating_points", 0.0))
	stats.unserved_yellow_cards = int(data.get("unserved_yellow_cards", 0))
	return stats
