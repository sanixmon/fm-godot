# Source: engine/src/main/kotlin/com/footballmanager/usecase/SelectLineupUseCase.kt
# Parity notes:
# - Calls into other batches' contracts: Player.is_available()/.natural_positions/.id,
#   PlayerCalculator.calculate_effective_overall/best_overall, Position.Kind.GK,
#   EmergencyGoalkeeper.create(club_id, id), LineupValidator.require_valid.
# - Tie-breaks mirror Kotlin exactly: maxWithOrNull(compareBy{...}.thenBy{...})
#   picks the LARGEST id on full ties, so comparisons use strict `>` with
#   `pid > best_id` as the final tie-break (not >=, matching maxWithOrNull
#   first-max-wins semantics is unnecessary here since ids are unique).
# - Kotlin throws IllegalStateException/IllegalArgumentException when no XI can
#   be built; here that becomes push_error + assert and a partial ids dict.
# - Emergency GK id mirrors EmergencyGoalkeeper.create default: -club_id, or
#   -9999 when club_id == 0.
class_name SelectLineup
extends RefCounted


# Returns {starters: Array[int] (11 ids, index 0 = GK), substitutes: Array[int]}.
static func select(players: Array, tactics: Tactics, allow_emergency_gk: bool = true, club_id: int = 0) -> Dictionary:
	var available: Array = []
	for p in players:
		if p.is_available():
			available.append(p)

	var available_gks: Array = []
	for p in available:
		if Position.Kind.GK in p.natural_positions:
			available_gks.append(p)

	var starting_gk = null
	if not available_gks.is_empty():
		var best_eff: int = -1
		var best_id: int = -9223372036854775807
		for p in available_gks:
			var eff: int = PlayerCalculator.calculate_effective_overall(p, Position.Kind.GK)
			if eff > best_eff or (eff == best_eff and int(p.id) > best_id):
				starting_gk = p
				best_eff = eff
				best_id = int(p.id)
	elif allow_emergency_gk:
		var egk_id: int = -club_id if club_id != 0 else -9999
		starting_gk = EmergencyGoalkeeper.create(club_id, egk_id)
		available.append(starting_gk)
	else:
		push_error("No eligible goalkeeper available in squad")
		assert(false, "No eligible goalkeeper available in squad")
		return {"starters": [], "substitutes": []}

	available.erase(starting_gk)
	var selected_ids: Array[int] = [int(starting_gk.id)]

	var outfield_slots: Array = Formation.slots(tactics.formation).slice(1)
	for slot in outfield_slots:
		var slot_int: int = int(slot)
		var best = null
		var best_natural: int = -1
		var best_eff: int = -1
		var best_id: int = -9223372036854775807
		for p in available:
			var natural: int = 1 if slot_int in p.natural_positions else 0
			var eff: int = PlayerCalculator.calculate_effective_overall(p, slot_int)
			var pid: int = int(p.id)
			if natural > best_natural or (natural == best_natural and (eff > best_eff or (eff == best_eff and pid > best_id))):
				best = p
				best_natural = natural
				best_eff = eff
				best_id = pid
		if best == null:
			push_error("Squad has fewer than 11 eligible players (needed 11, only have %d)" % selected_ids.size())
			assert(false, "Squad has fewer than 11 eligible players")
			break
		selected_ids.append(int(best.id))
		available.erase(best)

	# Bench: remaining players sorted by best overall desc, id asc (Kotlin:
	# sortedWith(compareByDescending{bestOverall}.thenBy{id})).
	available.sort_custom(func(a, b) -> bool:
		var oa: int = PlayerCalculator.calculate_best_overall(a)
		var ob: int = PlayerCalculator.calculate_best_overall(b)
		if oa != ob:
			return oa > ob
		return int(a.id) < int(b.id)
	)
	var bench_ids: Array[int] = []
	for p in available:
		bench_ids.append(int(p.id))

	var lookup := {}
	for p in players:
		lookup[int(p.id)] = p
	if int(starting_gk.id) < 0:
		lookup[int(starting_gk.id)] = starting_gk
	LineupValidator.require_valid(Lineup.new(selected_ids, bench_ids), lookup)

	return {"starters": selected_ids, "substitutes": bench_ids}
