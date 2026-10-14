# Source: engine/src/main/kotlin/com/footballmanager/calculator/PlayerDevelopmentCalculator.kt
# Parity notes and cross-batch assumptions:
# - Attribute ints assume Attribute ordinals: PACE=0 SHOOTING=1 PASSING=2
#   DRIBBLING=3 DEFENDING=4 PHYSICAL=5 GOALKEEPER=6.
# - TrainingFocus ints assume ordinals: BALANCED=0 ATTACKING=1 DEFENDING=2
#   PHYSICAL=3 TECHNICAL=4 GOALKEEPING=5.
# - TrainingIntensity ints assume ordinals: LIGHT=0 NORMAL=1 INTENSIVE=2.
# - Position ints assume Position.Kind ordinals (GK=0); Position.group_of is NOT
#   needed here because the BALANCED branch is resolved by explicit position id.
# - facilities is flattened to training_level: int (clamped 1..5), since the
#   Facilities class lives in another batch.
# - season_stats accepts null, a Dictionary {appearances, starts}, or an object
#   with .appearances/.starts (duck-typed so either batch shape works).
# - Default RNG seed mirrors Kotlin Random(player.id xor 2026): seed -1 means
#   `player.id ^ 2026`. Seeded runs are deterministic within GDScript but NOT
#   bit-identical to Kotlin (different shuffle/RNG stream).
# - apply_development mutates player.attributes in place via a
#   to_dict/from_dict round-trip (the trusted PlayerAttributes contract) and
#   returns the player. Original dict key style (int vs String) is preserved.
class_name PlayerDevelopmentCalc
extends RefCounted

const MIN_ATTRIBUTE: int = 1
const MAX_ATTRIBUTE: int = 100

const ATTR_PACE: int = 0
const ATTR_SHOOTING: int = 1
const ATTR_PASSING: int = 2
const ATTR_DRIBBLING: int = 3
const ATTR_DEFENDING: int = 4
const ATTR_PHYSICAL: int = 5
const ATTR_GOALKEEPER: int = 6

const ATTR_NAMES: Array[String] = ["PACE", "SHOOTING", "PASSING", "DRIBBLING", "DEFENDING", "PHYSICAL", "GOALKEEPER"]

const FOCUS_BALANCED: int = 0
const FOCUS_ATTACKING: int = 1
const FOCUS_DEFENDING: int = 2
const FOCUS_PHYSICAL: int = 3
const FOCUS_TECHNICAL: int = 4
const FOCUS_GOALKEEPING: int = 5

const INTENSITY_LIGHT: int = 0
const INTENSITY_NORMAL: int = 1
const INTENSITY_INTENSIVE: int = 2

const POS_GK: int = 0
const POS_CB: int = 1
const POS_LB: int = 2
const POS_RB: int = 3
const POS_DM: int = 4
const POS_CM: int = 5
const POS_AM: int = 6


# Returns {attribute int -> delta int}. Mirrors calculateAnnualDevelopment.
static func calculate_annual_development(player, training_level: int = 1, season_stats = null, seed: int = -1) -> Dictionary:
	var deltas := {}
	var current_best: int = player.best_overall()
	var potential_gap: int = maxi(int(player.potential) - current_best, 0)
	var age: int = int(player.age)
	var level: int = clampi(training_level, 1, 5)

	if age < 29:
		# Growth phase.
		var age_multiplier: float = 0.35
		if age <= 20:
			age_multiplier = 1.40
		elif age <= 23:
			age_multiplier = 1.15
		elif age <= 26:
			age_multiplier = 0.70

		var playing_time_multiplier: float = 0.85
		if season_stats != null:
			var apps: int = _stat_value(season_stats, "appearances")
			var starts: int = _stat_value(season_stats, "starts")
			if starts >= 12 or apps >= 14:
				playing_time_multiplier = 1.30
			elif apps >= 6:
				playing_time_multiplier = 1.00
			else:
				playing_time_multiplier = 0.75

		var facility_multiplier: float = 0.80 + float(level - 1) * 0.10

		var intensity_multiplier: float = 1.00
		match int(player.training_intensity):
			INTENSITY_LIGHT:
				intensity_multiplier = 0.70
			INTENSITY_NORMAL:
				intensity_multiplier = 1.00
			INTENSITY_INTENSIVE:
				intensity_multiplier = 1.30

		var growth_raw: float = float(potential_gap) * 0.20 * age_multiplier * playing_time_multiplier * facility_multiplier * intensity_multiplier
		var growth_points: int = int(round(clampf(growth_raw, 0.0, 5.0)))

		var targets: Array[int] = get_target_attributes(int(player.training_focus), player)
		if growth_points > 0 and not targets.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = seed if seed >= 0 else int(player.id) ^ 2026
			var shuffled: Array = Array(targets).duplicate()
			_shuffle(shuffled, rng)
			var points_remaining: int = growth_points
			for attr in shuffled:
				if points_remaining <= 0:
					break
				var current_val: int = player.attributes.attr_value(int(attr))
				if current_val < int(player.potential) and current_val < MAX_ATTRIBUTE:
					deltas[int(attr)] = int(deltas.get(attr, 0)) + 1
					points_remaining -= 1
			if points_remaining > 0 and potential_gap >= 5:
				for attr in shuffled:
					if points_remaining <= 0:
						break
					var current_val: int = player.attributes.attr_value(int(attr)) + int(deltas.get(attr, 0))
					if current_val < int(player.potential) and current_val < MAX_ATTRIBUTE:
						deltas[int(attr)] = int(deltas.get(attr, 0)) + 1
						points_remaining -= 1
	elif age >= 29 and age <= 31:
		# Peak / stabilization phase: slight decay only for light-training 31yos.
		if int(player.training_intensity) == INTENSITY_LIGHT and age >= 31:
			deltas[ATTR_PACE] = -1
	else:
		# Veteran decline phase (age 32+).
		var physical_drop: int = -3
		if age <= 33:
			physical_drop = -1
		elif age <= 35:
			physical_drop = -2
		var soften: int = 0
		if level >= 4 and int(player.training_intensity) == INTENSITY_INTENSIVE:
			soften = 1
		var effective_drop: int = mini(physical_drop + soften, 0)
		deltas[ATTR_PACE] = effective_drop
		deltas[ATTR_PHYSICAL] = effective_drop
		if age >= 35:
			deltas[ATTR_DRIBBLING] = -1
			if PlayerCalculator.find_best_position(player) != POS_GK:
				deltas[ATTR_SHOOTING] = -1

	return deltas


# Applies annual development and returns the (mutated) player. Mirrors applyDevelopment.
static func apply_development(player, training_level: int = 1, season_stats = null, seed: int = -1):
	var deltas: Dictionary = calculate_annual_development(player, training_level, season_stats, seed)
	if deltas.is_empty():
		return player
	var current_map: Dictionary = player.attributes.to_dict()
	var key_by_attr := {}
	for k in current_map.keys():
		key_by_attr[_attr_key_to_int(k)] = k
	for attr in deltas.keys():
		var attr_int: int = int(attr)
		if key_by_attr.has(attr_int):
			var k = key_by_attr[attr_int]
			current_map[k] = clampi(int(current_map[k]) + int(deltas[attr]), MIN_ATTRIBUTE, MAX_ATTRIBUTE)
		else:
			# Unknown key style: fall back to the int id (from_dict must accept it).
			current_map[attr_int] = clampi(int(deltas[attr]), MIN_ATTRIBUTE, MAX_ATTRIBUTE)
	player.attributes = PlayerAttributes.from_dict(current_map)
	return player


# Mirrors getTargetAttributes. CB counts as a "B" defender exactly like Kotlin's
# name.endsWith("B"); LM/RM do not exist in the Position enum so that Kotlin
# branch is dead and CM/AM map to the midfield list.
static func get_target_attributes(focus: int, player) -> Array[int]:
	match focus:
		FOCUS_ATTACKING:
			return [ATTR_SHOOTING, ATTR_DRIBBLING, ATTR_PACE]
		FOCUS_DEFENDING:
			return [ATTR_DEFENDING, ATTR_PHYSICAL, ATTR_PACE]
		FOCUS_PHYSICAL:
			return [ATTR_PHYSICAL, ATTR_PACE]
		FOCUS_TECHNICAL:
			return [ATTR_PASSING, ATTR_DRIBBLING, ATTR_SHOOTING]
		FOCUS_GOALKEEPING:
			return [ATTR_GOALKEEPER, ATTR_PHYSICAL]
		_:
			var best_pos: int = PlayerCalculator.find_best_position(player)
			if best_pos == POS_GK:
				return [ATTR_GOALKEEPER, ATTR_PHYSICAL]
			if best_pos == POS_LB or best_pos == POS_RB or best_pos == POS_CB or best_pos == POS_DM:
				return [ATTR_DEFENDING, ATTR_PHYSICAL, ATTR_PASSING]
			if best_pos == POS_CM or best_pos == POS_AM:
				return [ATTR_PASSING, ATTR_DRIBBLING, ATTR_PACE]
			return [ATTR_SHOOTING, ATTR_PACE, ATTR_DRIBBLING]


static func _stat_value(season_stats, field: String) -> int:
	if season_stats is Dictionary:
		return int((season_stats as Dictionary).get(field, 0))
	return int((season_stats as Object).get(field))


static func _attr_key_to_int(key) -> int:
	if key is int:
		return int(key)
	var idx: int = ATTR_NAMES.find(str(key).to_upper())
	return idx


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
