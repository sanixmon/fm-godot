# Source: engine/src/main/kotlin/com/footballmanager/simulation/Lineup.kt
# Parity notes:
# - starters/substitutes hold player ids (ints; Godot int is 64-bit).
# - Kotlin `require` throws; here violations call push_error + assert (asserts
#   are stripped in release builds, so invalid data can slip through in release).
# - auto_select() delegates to SelectLineup (this batch's SelectLineupUseCase port).
class_name Lineup
extends RefCounted

var starters: Array[int] = []
var substitutes: Array[int] = []


func _init(p_starters: Array = [], p_substitutes: Array = []) -> void:
	var s: Array[int] = []
	for v in p_starters:
		s.append(int(v))
	var b: Array[int] = []
	for v in p_substitutes:
		b.append(int(v))
	if s.size() != 11:
		push_error("Lineup must have exactly 11 starters (got %d)" % s.size())
		assert(false, "Lineup must have exactly 11 starters")
	if _unique_count(s) != 11:
		push_error("Starters must be unique players")
		assert(false, "Starters must be unique players")
	if _unique_count(b) != b.size():
		push_error("Substitutes must be unique players")
		assert(false, "Substitutes must be unique players")
	if not _overlap(s, b).is_empty():
		push_error("Player cannot be both starter and substitute")
		assert(false, "Player cannot be both starter and substitute")
	starters = s
	substitutes = b


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


# Mirrors Lineup.autoSelect.
static func auto_select(players: Array, tactics: Tactics, allow_emergency_gk: bool = true, club_id: int = 0) -> Lineup:
	var ids: Dictionary = SelectLineup.select(players, tactics, allow_emergency_gk, club_id)
	return Lineup.new(ids["starters"], ids["substitutes"])


func to_dict() -> Dictionary:
	return {
		"starters": starters.duplicate(),
		"substitutes": substitutes.duplicate(),
	}


static func from_dict(d: Dictionary) -> Lineup:
	return Lineup.new(d.get("starters", []), d.get("substitutes", []))
