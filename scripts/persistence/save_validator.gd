# Source: engine/src/main/kotlin/com/footballmanager/serialization/SaveValidator.kt
# Mirrors the six validation rules, adapted to the real Game.to_dict() shape
# (camelCase keys; clubs/players as str(id)->dict maps; finance nested under
# club.finance; squad ids under club.squad.playerIds; season fixtures embed
# Team dicts with clubId; results use home_club_id/away_club_id; competitions
# carry clubIds; there is no save_version/league field in to_dict output).
# Version rule: a present-but-foreign save_version fails; absent (the normal
# Game.to_dict shape) passes. Kotlin `throw` becomes assert (debug) +
# push_error with a false return (release-safe validation path).
class_name SaveValidator
extends RefCounted

const CURRENT_SAVE_VERSION: int = 1


static func validate(data: Dictionary) -> bool:
	var ok: bool = true

	# 1. Version validation (Game.to_dict carries no version; a foreign one must match).
	if data.has("save_version") and int(data.get("save_version", -1)) != CURRENT_SAVE_VERSION:
		push_error("Unsupported save version: %s (expected: %d)" % [str(data.get("save_version")), CURRENT_SAVE_VERSION])
		assert(false, "Unsupported save version")
		ok = false
	if data.has("saveVersion") and int(data.get("saveVersion", -1)) != CURRENT_SAVE_VERSION:
		push_error("Unsupported save version: %s (expected: %d)" % [str(data.get("saveVersion")), CURRENT_SAVE_VERSION])
		assert(false, "Unsupported save version")
		ok = false

	var clubs_map: Dictionary = data.get("clubs", {})
	var players_map: Dictionary = data.get("players", {})

	# 2. Clubs validation.
	var club_ids: Dictionary = {}
	for key in clubs_map.keys():
		var club: Dictionary = clubs_map[key]
		var cid: int = int(club.get("id", key))
		if club_ids.has(cid):
			push_error("Duplicate club ID: %d" % cid)
			assert(false, "Duplicate club ID")
			ok = false
		club_ids[cid] = true
		var finance: Dictionary = club.get("finance", {})
		if int(finance.get("balance", 0)) < 0:
			push_error("Club %s has negative balance: %d" % [str(club.get("name", "?")), int(finance.get("balance", 0))])
			assert(false, "Negative club balance")
			ok = false

	# 3. Players validation.
	var player_ids: Dictionary = {}
	for key in players_map.keys():
		var player: Dictionary = players_map[key]
		var pid: int = int(player.get("id", key))
		if player_ids.has(pid):
			push_error("Duplicate player ID: %d" % pid)
			assert(false, "Duplicate player ID")
			ok = false
		player_ids[pid] = true
		var pname: String = str(player.get("name", "?"))
		if int(player.get("form", 60)) < 1 or int(player.get("form", 60)) > 100:
			push_error("Player %s form out of bounds: %s" % [pname, str(player.get("form"))])
			assert(false, "Player form out of bounds")
			ok = false
		if int(player.get("fitness", 100)) < 0 or int(player.get("fitness", 100)) > 100:
			push_error("Player %s fitness out of bounds: %s" % [pname, str(player.get("fitness"))])
			assert(false, "Player fitness out of bounds")
			ok = false
		if int(player.get("potential", 75)) < 1 or int(player.get("potential", 75)) > 100:
			push_error("Player %s potential out of bounds: %s" % [pname, str(player.get("potential"))])
			assert(false, "Player potential out of bounds")
			ok = false
		for attr_key in (player.get("attributes", {}) as Dictionary).keys():
			var value: int = int((player.get("attributes", {}) as Dictionary)[attr_key])
			if value < 1 or value > 100:
				push_error("Player %s attribute %s out of bounds: %d" % [pname, str(attr_key), value])
				assert(false, "Player attribute out of bounds")
				ok = false
		var injury = player.get("injuryStatus")
		if injury is Dictionary and int((injury as Dictionary).get("daysRemaining", 0)) < 0:
			push_error("Player %s has negative injury days" % pname)
			assert(false, "Negative injury days")
			ok = false
		var susp = player.get("suspensionStatus")
		if susp is Dictionary and int((susp as Dictionary).get("matchesRemaining", 0)) < 0:
			push_error("Player %s has negative suspension matches" % pname)
			assert(false, "Negative suspension matches")
			ok = false

	# 4. Squad registration validation.
	var registered: Dictionary = {}
	for key in clubs_map.keys():
		var club: Dictionary = clubs_map[key]
		var squad: Dictionary = club.get("squad", {})
		for pid in squad.get("playerIds", []):
			var id_int: int = int(pid)
			if not player_ids.has(id_int):
				push_error("Club %s references non-existent player ID %d" % [str(club.get("name", "?")), id_int])
				assert(false, "Squad references non-existent player")
				ok = false
			if registered.has(id_int):
				push_error("Player %d is registered to multiple clubs" % id_int)
				assert(false, "Player registered to multiple clubs")
				ok = false
			registered[id_int] = true

	# 5. Competition club validation.
	for key in (data.get("competitions", {}) as Dictionary).keys():
		var comp: Dictionary = (data.get("competitions", {}) as Dictionary)[key]
		for cid in comp.get("clubIds", []):
			if not club_ids.has(int(cid)):
				push_error("Competition references non-existent club ID %d" % int(cid))
				assert(false, "Competition references non-existent club")
				ok = false

	# 6. Current season validation (if present).
	var season = data.get("currentSeason")
	if season is Dictionary:
		for fixture in (season as Dictionary).get("fixtures", []):
			var home: Dictionary = (fixture as Dictionary).get("home", {})
			var away: Dictionary = (fixture as Dictionary).get("away", {})
			if not club_ids.has(int(home.get("clubId", -1))) or not club_ids.has(int(away.get("clubId", -1))):
				push_error("Fixture references non-existent club")
				assert(false, "Fixture references non-existent club")
				ok = false
		for result in (season as Dictionary).get("results", []):
			if not club_ids.has(int((result as Dictionary).get("home_club_id", -1))) or not club_ids.has(int((result as Dictionary).get("away_club_id", -1))):
				push_error("MatchResult references non-existent club")
				assert(false, "MatchResult references non-existent club")
				ok = false

	return ok
