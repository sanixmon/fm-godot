# Source: engine/src/main/kotlin/com/footballmanager/usecase/CalculateTeamStrengthUseCase.kt
# (TeamStrength data class + CalculateTeamStrengthUseCase)
# Parity notes:
# - starters[i] is assigned to formation slot i, exactly like starters.zip(slots).
# - attack = round(0.7*avg(ATTACKER) + 0.3*avg(MIDFIELDER));
#   defense = round(0.6*avg(DEFENDER) + 0.2*avg(GOALKEEPER) + 0.2*avg(MIDFIELDER)).
# - Any empty position group averages to 50.0 (Kotlin defaultMidRating).
# - Kotlin roundToInt is half-up; Godot round() is half away from zero, which is
#   identical for the non-negative values used here. Results clamp to 1..100.
# - Position groups via Position.group_of(slot) (other batch's Position contract):
#   GOALKEEPER=0 DEFENDER=1 MIDFIELDER=2 ATTACKER=3.
class_name TeamStrength
extends RefCounted

const DEFAULT_MID_RATING: int = 50
const MIN_RATING: int = 1
const MAX_RATING: int = 100

var attack: int = DEFAULT_MID_RATING
var defense: int = DEFAULT_MID_RATING


func _init(p_attack: int = DEFAULT_MID_RATING, p_defense: int = DEFAULT_MID_RATING) -> void:
	attack = p_attack
	defense = p_defense


static func _average(values: Array) -> float:
	if values.is_empty():
		return float(DEFAULT_MID_RATING)
	var total: float = 0.0
	for v in values:
		total += float(v)
	return total / float(values.size())


static func calculate_from_starters(starters: Array, tactics: Tactics) -> TeamStrength:
	if starters.size() != 11:
		push_error("Starting XI must have exactly 11 players (got %d)" % starters.size())
		assert(false, "Starting XI must have exactly 11 players")
	var slots: Array = Formation.slots(tactics.formation)
	var attacker_ratings: Array = []
	var midfielder_ratings: Array = []
	var defender_ratings: Array = []
	var goalkeeper_ratings: Array = []
	var count: int = mini(starters.size(), slots.size())
	for i in count:
		var slot: int = int(slots[i])
		var rating: int = PlayerCalculator.calculate_effective_overall(starters[i], slot)
		match Position.group_of(slot):
			Position.Group.ATTACKER:
				attacker_ratings.append(rating)
			Position.Group.MIDFIELDER:
				midfielder_ratings.append(rating)
			Position.Group.DEFENDER:
				defender_ratings.append(rating)
			_:
				goalkeeper_ratings.append(rating)
	var attack_value: int = clampi(int(round(0.7 * _average(attacker_ratings) + 0.3 * _average(midfielder_ratings))), MIN_RATING, MAX_RATING)
	var defense_value: int = clampi(int(round(0.6 * _average(defender_ratings) + 0.2 * _average(goalkeeper_ratings) + 0.2 * _average(midfielder_ratings))), MIN_RATING, MAX_RATING)
	return TeamStrength.new(attack_value, defense_value)


static func calculate_from_squad(players: Array, tactics: Tactics) -> TeamStrength:
	var ids: Dictionary = SelectLineup.select(players, tactics)
	var lookup := {}
	for p in players:
		lookup[int(p.id)] = p
	var starter_ids: Array = ids["starters"]
	if starter_ids.size() > 0 and int(starter_ids[0]) < 0:
		lookup[int(starter_ids[0])] = EmergencyGoalkeeper.create(0, int(starter_ids[0]))
	var starters: Array = []
	for pid in starter_ids:
		starters.append(lookup[int(pid)])
	return calculate_from_starters(starters, tactics)


static func build_team(club_id: int, starters: Array, p_tactics: Tactics = null) -> Team:
	var tactics: Tactics = p_tactics if p_tactics != null else Tactics.new()
	var strength: TeamStrength = calculate_from_starters(starters, tactics)
	return Team.new(club_id, strength.attack, strength.defense, tactics)


static func build_team_from_squad(club_id: int, players: Array, p_tactics: Tactics = null) -> Team:
	var tactics: Tactics = p_tactics if p_tactics != null else Tactics.new()
	var strength: TeamStrength = calculate_from_squad(players, tactics)
	return Team.new(club_id, strength.attack, strength.defense, tactics)
