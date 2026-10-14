# Deterministic scripted RNG for tests (mirrors test FakeRandomSource).
class_name FMFakeRandom
extends FMRandom

var _doubles: Array = []
var _ints: Array = []
var _di: int = 0
var _ii: int = 0


func _init(doubles: Array = [], ints: Array = []) -> void:
	_doubles = doubles
	_ints = ints


func next_double() -> float:
	if _doubles.is_empty():
		return 0.0
	var v: float = _doubles[_di % _doubles.size()]
	_di += 1
	return v


func next_int(from: int, until: int) -> int:
	if _ints.is_empty():
		return from
	var span: int = maxi(until - from, 1)
	var v: int = from + (int(_ints[_ii % _ints.size()]) % span)
	_ii += 1
	return v
