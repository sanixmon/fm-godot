# Source: engine/src/main/kotlin/com/footballmanager/simulation/MatchStats.kt (MatchStats data class)
# Parity notes:
# - duration_minutes() mirrors the Kotlin durationMinutes getter (alias of ticks).
# - home_possession()/away_possession() mirror the Kotlin share getters,
#   including the 0.5 fallback when no possessions were recorded.
class_name MatchStats
extends RefCounted

var ticks: int = 90
var home: TeamStats = null
var away: TeamStats = null


func _init(p_ticks: int = 90, p_home: TeamStats = null, p_away: TeamStats = null) -> void:
	ticks = p_ticks
	home = p_home if p_home != null else TeamStats.new()
	away = p_away if p_away != null else TeamStats.new()


func duration_minutes() -> int:
	return ticks


func home_possession() -> float:
	var total: int = home.possessions + away.possessions
	if total == 0:
		return 0.5
	return float(home.possessions) / float(total)


func away_possession() -> float:
	var total: int = home.possessions + away.possessions
	if total == 0:
		return 0.5
	return float(away.possessions) / float(total)


func to_dict() -> Dictionary:
	return {
		"ticks": ticks,
		"home": home.to_dict(),
		"away": away.to_dict(),
	}


static func from_dict(d: Dictionary) -> MatchStats:
	return MatchStats.new(
		int(d.get("ticks", 90)),
		TeamStats.from_dict(d.get("home", {})),
		TeamStats.from_dict(d.get("away", {})),
	)
