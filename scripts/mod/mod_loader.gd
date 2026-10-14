# Sources: engine/src/main/kotlin/com/footballmanager/mod/ModData.kt (author-friendly
# JSON schema), engine/src/main/kotlin/com/footballmanager/mod/ModLoader.kt (loader),
# engine/src/main/kotlin/com/footballmanager/mod/PlayerMapper.kt (string-enum parsing).
# Mirrors exactly: mod JSON keys are camelCase as serialized by kotlinx
# (startDate, shortName, graphicsId, transferBudget, weeklyWageBudget); ids are
# auto-assigned in file order (league 1, clubs 1.., players 1..); mod-player
# contracts expire 2030-06-30; formation parsed by label then name, mentality the
# same, both case-insensitive; unknown strings fail fast (push_error + assert +
# null return, since GDScript has no exceptions).
# Positions map to Position.Kind ints via Position.from_string and attributes to
# Attribute.Kind ints via Attribute.from_string (both assert on unknown input,
# matching Kotlin's fail-fast error). Absent ids use the -1 sentinel (mirroring
# Player/Club). (No PlayerRepository layer in Godot: players are returned inside
# the Game.)
class_name ModLoader
extends RefCounted

const FORMATION_NAMES: Array = ["FOUR_FOUR_TWO", "FOUR_THREE_THREE", "FOUR_TWO_THREE_ONE", "THREE_FIVE_TWO"]
const MENTALITY_NAMES: Array = ["DEFENSIVE", "BALANCED", "ATTACKING"]
const DEFAULT_CONTRACT_EXPIRY: String = "2030-06-30"


static func load_from_file(path: String) -> Game:
	if not FileAccess.file_exists(path):
		push_error("ModLoader: file not found: %s" % path)
		assert(false, "Mod file not found")
		return null
	return load_from_json(FileAccess.get_file_as_string(path))


static func load_from_json(text: String) -> Game:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("ModLoader: malformed mod JSON")
		assert(false, "Malformed mod JSON")
		return null
	return load_mod(parsed)


static func load_mod(mod_file: Dictionary) -> Game:
	var failed: bool = false
	var league_id: int = 1
	var next_club_id: int = 1
	var next_player_id: int = 1
	var clubs: Dictionary = {}
	var players: Dictionary = {}

	for mod_club in mod_file.get("clubs", []):
		var club_dict: Dictionary = mod_club
		var club_id: int = next_club_id
		next_club_id += 1
		var player_ids: Array = []
		for mod_player in club_dict.get("players", []):
			var player_id: int = next_player_id
			next_player_id += 1
			var player: Player = _to_player(mod_player, player_id)
			if player == null:
				failed = true
				continue
			players[player_id] = player
			player_ids.append(player_id)
		var formation: int = _parse_formation(str(club_dict.get("formation", "4-4-2")))
		var mentality: int = _parse_mentality(str(club_dict.get("mentality", "Balanced")))
		if formation < 0 or mentality < 0:
			failed = true
			continue
		var finance := Finance.new(
			int(club_dict.get("balance", 50000000)),
			int(club_dict.get("transferBudget", 20000000)),
			int(club_dict.get("weeklyWageBudget", 1000000))
		)
		var club := Club.new(
			club_id,
			str(club_dict.get("name", "")),
			str(club_dict.get("shortName", "")),
			league_id,
			finance,
			Facilities.new(),
			Squad.new(club_id, player_ids)
		)
		club.default_tactics = Tactics.new(formation, mentality)
		var gid = club_dict.get("graphicsId")
		club.graphics_id = int(gid) if gid != null else -1
		clubs[club_id] = club

	if failed:
		return null

	var league_dict: Dictionary = mod_file.get("league", {})
	var league := League.new(league_id, str(league_dict.get("name", "")), clubs.keys())

	var game := Game.new()
	game.game_name = str(mod_file.get("name", ""))
	game.current_date = str(mod_file.get("startDate", ""))
	game.clubs = clubs
	game.players = players
	game.competitions = {league_id: league}
	return game


static func _to_player(mod_player: Dictionary, player_id: int) -> Player:
	var pos: int = Position.from_string(str(mod_player.get("position", "")))
	if pos < 0:
		push_error("ModLoader: unknown position: '%s'" % str(mod_player.get("position", "")))
		assert(false, "Unknown position in mod")
		return null
	var attrs: Dictionary = {}
	for key in (mod_player.get("attributes", {}) as Dictionary).keys():
		var attr: int = Attribute.from_string(str(key))
		if attr < 0:
			push_error("ModLoader: unknown attribute: '%s'" % str(key))
			assert(false, "Unknown attribute in mod")
			return null
		attrs[attr] = int((mod_player.get("attributes", {}) as Dictionary)[key])
	var player := Player.new(
		player_id,
		str(mod_player.get("name", "")),
		int(mod_player.get("age", 20)),
		str(mod_player.get("nationality", "ID")),
		[pos],
		PlayerAttributes.new(attrs),
		Contract.new(0, DEFAULT_CONTRACT_EXPIRY)
	)
	player.potential = int(mod_player.get("potential", 75))
	var gid = mod_player.get("graphicsId")
	player.graphics_id = int(gid) if gid != null else -1
	return player


static func _parse_formation(input: String) -> int:
	var needle: String = input.strip_edges()
	for kind in Formation.Kind.values():
		if str(Formation.LABELS[kind]).nocasecmp_to(needle) == 0:
			return kind
	for i in FORMATION_NAMES.size():
		if FORMATION_NAMES[i].nocasecmp_to(needle) == 0:
			return i
	push_error("ModLoader: unknown formation: '%s'" % input)
	assert(false, "Unknown formation in mod")
	return -1


static func _parse_mentality(input: String) -> int:
	var needle: String = input.strip_edges()
	for kind in Mentality.Kind.values():
		if str(Mentality.LABELS[kind]).nocasecmp_to(needle) == 0:
			return kind
	for i in MENTALITY_NAMES.size():
		if MENTALITY_NAMES[i].nocasecmp_to(needle) == 0:
			return i
	push_error("ModLoader: unknown mentality: '%s'" % input)
	assert(false, "Unknown mentality in mod")
	return -1
