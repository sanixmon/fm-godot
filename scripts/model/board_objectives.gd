# Source: engine/.../model/BoardObjectives.kt.
class_name BoardObjectives
extends RefCounted

var club_id: int = 0
var target_league_position: int = 4
var board_confidence: int = 75


func status_description() -> String:
	if board_confidence >= 80:
		return "Delighted"
	if board_confidence >= 65:
		return "Satisfied"
	if board_confidence >= 45:
		return "Under Review"
	return "In Jeopardy"


func with_match_evaluation(current_position: int, is_win: bool, is_loss: bool) -> BoardObjectives:
	var position_delta: int = target_league_position - current_position
	var delta := 0
	if is_win and position_delta >= 0:
		delta = 3
	elif is_win:
		delta = 2
	elif is_loss and position_delta < -2:
		delta = -4
	elif is_loss:
		delta = -2
	var b := BoardObjectives.new()
	b.club_id = club_id
	b.target_league_position = target_league_position
	b.board_confidence = clampi(board_confidence + delta, 0, 100)
	return b


func to_dict() -> Dictionary:
	return {
		"clubId": club_id,
		"targetLeaguePosition": target_league_position,
		"boardConfidence": board_confidence,
	}


static func from_dict(d: Dictionary) -> BoardObjectives:
	var b := BoardObjectives.new()
	b.club_id = int(d.get("clubId", 0))
	b.target_league_position = int(d.get("targetLeaguePosition", 4))
	b.board_confidence = int(d.get("boardConfidence", 75))
	return b
