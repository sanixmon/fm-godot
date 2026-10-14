# Source: engine/.../model/Attributes.kt (PlayerAttributes).
# Missing attributes default to MIN_VALUE; every value is clamped 1..100.
class_name PlayerAttributes
extends RefCounted

var _values: Dictionary = {}


func _init(values: Dictionary = {}) -> void:
	for a: int in Attribute.Kind.values():
		var v: int = int(values.get(a, values.get(Attribute.to_string_value(a), Attribute.MIN_VALUE)))
		_values[a] = clampi(v, Attribute.MIN_VALUE, Attribute.MAX_VALUE)


func get(attr: int) -> int:
	return _values.get(attr, Attribute.MIN_VALUE)


## Weighted-average overall for a position (verbatim PositionWeights math).
func overall(position: int) -> int:
	var weights: Dictionary = Position.WEIGHTS[position]
	var total: int = 0
	var weighted_sum: int = 0
	for attr: int in weights:
		var w: int = weights[attr]
		total += w
		weighted_sum += get(attr) * w
	return clampi(int(round(float(weighted_sum) / float(total))), Attribute.MIN_VALUE, Attribute.MAX_VALUE)


func to_dict() -> Dictionary:
	var out := {}
	for a: int in _values:
		out[Attribute.to_string_value(a)] = _values[a]
	return out


static func from_dict(d: Dictionary) -> PlayerAttributes:
	var values := {}
	for k: String in d:
		values[Attribute.from_string(k)] = int(d[k])
	return PlayerAttributes.new(values)


static func uniform(value: int) -> PlayerAttributes:
	var values := {}
	for a: int in Attribute.Kind.values():
		values[a] = value
	return PlayerAttributes.new(values)
