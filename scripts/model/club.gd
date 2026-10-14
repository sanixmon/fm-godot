# Source: engine/.../model/Club.kt (Club).
class_name Club
extends RefCounted

var id: int = 0
var name: String = ""
var short_name: String = ""
var league_id: int = 0
var finance: Finance = null
var facilities: Facilities = null
var squad: Squad = null
var default_tactics = null
var graphics_id: int = -1


func _init(
	p_id: int = 0,
	p_name: String = "",
	p_short: String = "",
	p_league: int = 0,
	p_finance: Finance = null,
	p_facilities: Facilities = null,
	p_squad: Squad = null
) -> void:
	id = p_id
	name = p_name
	short_name = p_short
	league_id = p_league
	finance = p_finance if p_finance != null else Finance.new()
	facilities = p_facilities if p_facilities != null else Facilities.new()
	squad = p_squad if p_squad != null else Squad.new(p_id)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"shortName": short_name,
		"leagueId": league_id,
		"finance": finance.to_dict(),
		"facilities": facilities.to_dict(),
		"squad": squad.to_dict(),
		"defaultTactics": default_tactics.to_dict() if default_tactics != null else null,
		"graphicsId": graphics_id if graphics_id >= 0 else null,
	}


static func from_dict(d: Dictionary) -> Club:
	var c := Club.new(
		int(d.get("id", 0)),
		str(d.get("name", "?")),
		str(d.get("shortName", "?")),
		int(d.get("leagueId", 0)),
		Finance.from_dict(d.get("finance", {})),
		Facilities.from_dict(d.get("facilities", {})),
		Squad.from_dict(d.get("squad", {}))
	)
	if d.get("defaultTactics", null) != null:
		c.default_tactics = Tactics.from_dict(d["defaultTactics"])
	var gid = d.get("graphicsId", null)
	c.graphics_id = int(gid) if gid != null else -1
	return c
