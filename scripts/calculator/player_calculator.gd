# Source: engine/src/main/kotlin/com/footballmanager/calculator/PlayerCalculator.kt
# Parity notes:
# - position is a Position.Kind int (other batch's Position contract).
# - Kotlin roundToInt is half-up; Godot round() is half away from zero, which is
#   identical for the non-negative values used here. Result clamped to 1..100.
# - find_best_position on a player with no natural positions: Kotlin error()
#   throws; here push_error + assert and return -1.
# - Player objects are untyped (other batch's Player contract): needs
#   .overall(pos), .natural_positions, .fitness, .morale.
class_name PlayerCalculator
extends RefCounted

const MIN_RATING: int = 1
const MAX_RATING: int = 100


# Overall rating at `position`, scaled by fitness and morale.
static func calculate_effective_overall(player, position: int) -> int:
	var base: int = player.overall(position)
	var fitness_factor: float = 0.70 + 0.30 * (float(clampi(int(player.fitness), 0, 100)) / 100.0)
	var morale_factor: float = 0.90 + 0.20 * (float(clampi(int(player.morale), 0, 100)) / 100.0)
	return clampi(int(round(float(base) * fitness_factor * morale_factor)), MIN_RATING, MAX_RATING)


# Natural position with the highest attribute-based overall.
static func find_best_position(player) -> int:
	var naturals: Array = player.natural_positions
	if naturals.is_empty():
		push_error("player must have at least one natural position")
		assert(false, "player must have at least one natural position")
		return -1
	var best: int = int(naturals[0])
	var best_rating: int = player.overall(best)
	for pos in naturals.slice(1):
		var rating: int = player.overall(int(pos))
		if rating > best_rating:
			best = int(pos)
			best_rating = rating
	return best


# Overall rating at the player's best natural position.
static func calculate_best_overall(player) -> int:
	return player.overall(find_best_position(player))
