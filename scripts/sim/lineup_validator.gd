# Source: engine/src/main/kotlin/com/footballmanager/simulation/LineupValidator.kt
# Parity notes:
# - Mirrors all six Kotlin check groups with identical messages (overlap message
#   prints the overlapping id list, matching Kotlin's Set interpolation).
# - Player objects are untyped params (other batch's Player contract): needs
#   .name, .natural_positions (Array of Position.Kind ints), .is_injured(),
#   .is_suspended(). Position GK = Position.Kind.GK.
# - Kotlin returns a sealed Valid/Invalid; here validate() returns
#   {valid: bool, message: String, errors: Array[String]}.
# - Kotlin requireValid throws IllegalArgumentException; GDScript has no
#   exceptions, so require_valid() calls push_error + assert instead.
class_name LineupValidator
extends RefCounted


# players: Dictionary of player id (int) -> Player.
static func validate(lineup: Lineup, players: Dictionary) -> Dictionary:
	var errors: Array[String] = []

	if lineup.starters.size() != 11:
		errors.append("Lineup must have exactly 11 starters (got %d)" % lineup.starters.size())

	if _unique_count(lineup.starters) != lineup.starters.size():
		errors.append("Starters must be unique players")

	if _unique_count(lineup.substitutes) != lineup.substitutes.size():
		errors.append("Substitutes must be unique players")

	var overlap: Array = _overlap(lineup.starters, lineup.substitutes)
	if not overlap.is_empty():
		errors.append("Players cannot be both starter and substitute: %s" % str(overlap))

	var index: int = 0
	for player_id in lineup.starters:
		var player = _lookup(players, player_id)
		if player == null:
			errors.append("Starter with id %d not found in player map" % int(player_id))
		else:
			if index == 0 and not (Position.Kind.GK in player.natural_positions):
				errors.append("Slot 0 must be occupied by a natural GK (got %s with positions %s)" % [str(player.name), str(player.natural_positions)])
			if player.is_injured():
				errors.append("Injured player %s (id=%d) cannot start" % [str(player.name), int(player_id)])
			if player.is_suspended():
				errors.append("Suspended player %s (id=%d) cannot start" % [str(player.name), int(player_id)])
		index += 1

	for sub_id in lineup.substitutes:
		var sub = _lookup(players, sub_id)
		if sub == null:
			errors.append("Substitute with id %d not found in player map" % int(sub_id))
		else:
			if sub.is_injured():
				errors.append("Injured player %s (id=%d) cannot be on the bench" % [str(sub.name), int(sub_id)])
			if sub.is_suspended():
				errors.append("Suspended player %s (id=%d) cannot be on the bench" % [str(sub.name), int(sub_id)])

	return {
		"valid": errors.is_empty(),
		"message": "; ".join(errors),
		"errors": errors,
	}


static func require_valid(lineup: Lineup, players: Dictionary) -> void:
	var result: Dictionary = validate(lineup, players)
	if not bool(result["valid"]):
		push_error("Invalid lineup: %s" % str(result["message"]))
		assert(false, "Invalid lineup: %s" % str(result["message"]))


static func _unique_count(arr: Array) -> int:
	var seen := {}
	for v in arr:
		seen[v] = true
	return seen.size()


static func _overlap(a: Array, b: Array) -> Array:
	var in_b := {}
	for v in b:
		in_b[v] = true
	var out: Array = []
	for v in a:
		if in_b.has(v):
			out.append(v)
	return out


# Tolerates both int and String dict keys (String keys appear after JSON saves).
static func _lookup(players: Dictionary, player_id: int):
	if players.has(player_id):
		return players[player_id]
	var as_string: String = str(player_id)
	if players.has(as_string):
		return players[as_string]
	return null
