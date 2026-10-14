# Source: engine/.../simulation/RandomSource.kt (+ test FakeRandomSource)
# Parity notes:
# - Godot's RandomNumberGenerator is NOT the same PRNG as Kotlin's Random, so
#   identical seeds do NOT reproduce identical Kotlin sequences. Determinism is
#   guaranteed within the Godot build only.
# - next_int(from, until) mirrors Kotlin: `until` is EXCLUSIVE.
class_name FMRandom
extends RefCounted

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


## Uniform value in [0.0, 1.0).
func next_double() -> float:
	return _rng.randf()


## Uniform integer in [from, until). `until` is exclusive (Kotlin parity).
func next_int(from: int, until: int) -> int:
	assert(until > from, "FMRandom.next_int requires until > from")
	return _rng.randi_range(from, until - 1)


## Uniform element of a non-empty array.
func pick(arr: Array):
	assert(not arr.is_empty(), "FMRandom.pick requires a non-empty array")
	return arr[next_int(0, arr.size())]
