# Source: engine/src/main/kotlin/com/footballmanager/simulation/MatchResult.kt
# Parity notes:
# - events holds MatchEvent, substitutions holds SubstitutionRecord.
# - player_stats maps player id (int) -> PlayerMatchStats; player_ratings maps
#   player id (int) -> float. to_dict stringifies map keys for JSON save compat;
#   from_dict converts them back to ints.
# - winner() returns a Side.Kind int, or -1 for a draw (Kotlin returns null).
class_name MatchResult
extends RefCounted

var home_club_id: int = 0
var away_club_id: int = 0
var home_score: int = 0
var away_score: int = 0
var events: Array = []
var stats: MatchStats = null
var duration_minutes: int = 90
var player_stats: Dictionary = {}
var player_ratings: Dictionary = {}
var substitutions: Array = []


func _init(
	p_home_club_id: int = 0,
	p_away_club_id: int = 0,
	p_home_score: int = 0,
	p_away_score: int = 0,
	p_events: Array = [],
	p_stats: MatchStats = null,
	p_duration_minutes: int = 90,
	p_player_stats: Dictionary = {},
	p_player_ratings: Dictionary = {},
	p_substitutions: Array = [],
) -> void:
	home_club_id = p_home_club_id
	away_club_id = p_away_club_id
	home_score = p_home_score
	away_score = p_away_score
	events = p_events.duplicate()
	stats = p_stats if p_stats != null else MatchStats.new()
	duration_minutes = p_duration_minutes
	player_stats = p_player_stats.duplicate()
	player_ratings = p_player_ratings.duplicate()
	substitutions = p_substitutions.duplicate()


func is_home_win() -> bool:
	return home_score > away_score


func is_away_win() -> bool:
	return away_score > home_score


func is_draw() -> bool:
	return home_score == away_score


func winner() -> int:
	if home_score > away_score:
		return Side.Kind.HOME
	if away_score > home_score:
		return Side.Kind.AWAY
	return -1


func to_dict() -> Dictionary:
	var events_data: Array = []
	for e in events:
		events_data.append((e as MatchEvent).to_dict())
	var stats_data: Dictionary = {}
	for k in player_stats.keys():
		stats_data[str(k)] = (player_stats[k] as PlayerMatchStats).to_dict()
	var ratings_data: Dictionary = {}
	for k in player_ratings.keys():
		ratings_data[str(k)] = float(player_ratings[k])
	var subs_data: Array = []
	for s in substitutions:
		subs_data.append((s as SubstitutionRecord).to_dict())
	return {
		"home_club_id": home_club_id,
		"away_club_id": away_club_id,
		"home_score": home_score,
		"away_score": away_score,
		"events": events_data,
		"stats": stats.to_dict(),
		"duration_minutes": duration_minutes,
		"player_stats": stats_data,
		"player_ratings": ratings_data,
		"substitutions": subs_data,
	}


static func from_dict(d: Dictionary) -> MatchResult:
	var events_data: Array = []
	for e in d.get("events", []):
		events_data.append(MatchEvent.from_dict(e))
	var stats_map: Dictionary = {}
	for k in (d.get("player_stats", {}) as Dictionary).keys():
		stats_map[int(str(k))] = PlayerMatchStats.from_dict((d["player_stats"] as Dictionary)[k])
	var ratings_map: Dictionary = {}
	for k in (d.get("player_ratings", {}) as Dictionary).keys():
		ratings_map[int(str(k))] = float((d["player_ratings"] as Dictionary)[k])
	var subs_data: Array = []
	for s in d.get("substitutions", []):
		subs_data.append(SubstitutionRecord.from_dict(s))
	return MatchResult.new(
		int(d.get("home_club_id", 0)),
		int(d.get("away_club_id", 0)),
		int(d.get("home_score", 0)),
		int(d.get("away_score", 0)),
		events_data,
		MatchStats.from_dict(d.get("stats", {})),
		int(d.get("duration_minutes", 90)),
		stats_map,
		ratings_map,
		subs_data,
	)
