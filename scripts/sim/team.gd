# Source: engine/src/main/kotlin/com/footballmanager/simulation/Team.kt
# Parity notes:
# - attack/defense validated to 1..100 (Kotlin MIN/MAX_ATTRIBUTE); violations
#   call push_error + assert (no exceptions in GDScript).
# - effective_attack()/defense() mirror Kotlin: round half-up (Godot round() is
#   half away from zero, identical for non-negative values), clamped 1..100.
# - from_lineup mirrors Team.fromLineup (strength via TeamStrength, i.e. the
#   CalculateTeamStrengthUseCase port, then attaches starters/substitutes).
# - from_squad mirrors Team.fromSquad including emergency-GK handling: a
#   negative first starter id means an EmergencyGoalkeeper (other batch's
#   contract: EmergencyGoalkeeper.create(club_id, id) -> Player) merged into
#   the lookup map; bench ids missing from the map are skipped (mapNotNull).
# - Player objects are untyped (other batch's Player contract).
# - to_dict persists lineup ids + tactics; from_dict rebuilds the Team with the
#   stored attack/defense values (no strength recompute, exact round-trip).
class_name Team
extends RefCounted

const MIN_RATING: int = 1
const MAX_RATING: int = 100

var club_id: int = 0
var attack: int = 1
var defense: int = 1
var tactics: Tactics = null
var starters: Array = []
var substitutes: Array = []


func _init(
	p_club_id: int = 0,
	p_attack: int = 1,
	p_defense: int = 1,
	p_tactics: Tactics = null,
	p_starters: Array = [],
	p_substitutes: Array = [],
) -> void:
	if p_attack < MIN_RATING or p_attack > MAX_RATING:
		push_error("attack out of range: %d" % p_attack)
		assert(false, "attack out of range")
	if p_defense < MIN_RATING or p_defense > MAX_RATING:
		push_error("defense out of range: %d" % p_defense)
		assert(false, "defense out of range")
	club_id = p_club_id
	attack = p_attack
	defense = p_defense
	tactics = p_tactics if p_tactics != null else Tactics.new()
	starters = p_starters.duplicate()
	substitutes = p_substitutes.duplicate()


func effective_attack() -> int:
	return clampi(int(round(float(attack) * tactics.attack_modifier())), MIN_RATING, MAX_RATING)


func effective_defense() -> int:
	return clampi(int(round(float(defense) * tactics.defense_modifier())), MIN_RATING, MAX_RATING)


static func from_lineup(p_club_id: int, p_starters: Array, p_tactics: Tactics = null, p_substitutes: Array = []) -> Team:
	var tactics: Tactics = p_tactics if p_tactics != null else Tactics.new()
	var strength: TeamStrength = TeamStrength.calculate_from_starters(p_starters, tactics)
	return Team.new(p_club_id, strength.attack, strength.defense, tactics, p_starters, p_substitutes)


static func from_squad(p_club_id: int, players: Array, p_tactics: Tactics = null) -> Team:
	var tactics: Tactics = p_tactics if p_tactics != null else Tactics.new()
	var ids: Dictionary = SelectLineup.select(players, tactics, true, p_club_id)
	var starter_ids: Array = ids["starters"]
	var sub_ids: Array = ids["substitutes"]
	var lookup := {}
	for p in players:
		lookup[int(p.id)] = p
	if starter_ids.size() > 0 and int(starter_ids[0]) < 0:
		lookup[int(starter_ids[0])] = EmergencyGoalkeeper.create(p_club_id, int(starter_ids[0]))
	var starters: Array = []
	for pid in starter_ids:
		starters.append(lookup[int(pid)])
	var subs: Array = []
	for pid in sub_ids:
		if lookup.has(int(pid)):
			subs.append(lookup[int(pid)])
	return from_lineup(p_club_id, starters, tactics, subs)


func to_dict() -> Dictionary:
	return {
		"clubId": club_id,
		"attack": attack,
		"defense": defense,
		"tactics": tactics.to_dict(),
		"starterIds": starters.map(func(p) -> int: return int(p.id)),
		"substituteIds": substitutes.map(func(p) -> int: return int(p.id)),
	}


## Rebuilds the team from stored values; `players` maps player id -> Player.
static func from_dict(d: Dictionary, players: Dictionary) -> Team:
	var starters: Array = []
	for pid in d.get("starterIds", []):
		if players.has(int(pid)):
			starters.append(players[int(pid)])
	var subs: Array = []
	for pid in d.get("substituteIds", []):
		if players.has(int(pid)):
			subs.append(players[int(pid)])
	return Team.new(
		int(d.get("clubId", 0)),
		int(d.get("attack", 1)),
		int(d.get("defense", 1)),
		Tactics.from_dict(d.get("tactics", {})),
		starters,
		subs
	)
