# Source: engine/src/main/kotlin/com/footballmanager/usecase/AiTransferActivityUseCase.kt
# Mirrors logic exactly: needs >= 2 AI clubs; seller = random AI club with > 16
# players; candidate = random of the 3 lowest-rated available non-GK outfielders;
# fee = max(overall * 10k, 50k); buyer = random AI club (not seller) with balance
# >= fee and squad <= 22. Deterministic via FMRandom(seed) (default 42).
# GDScript has no exceptions, so the Kotlin try/catch becomes explicit
# preconditions (buyer must not already hold the player); failures return the
# season unchanged. DirectTransfer is injectable, mirroring the Kotlin constructor.
class_name AiTransferActivity
extends RefCounted


var _direct_transfer: DirectTransfer = null


func _init(direct_transfer: DirectTransfer = null) -> void:
	_direct_transfer = direct_transfer if direct_transfer != null else DirectTransfer.new()


func execute(season: SeasonState, seed: int = 42) -> SeasonState:
	var ai_clubs: Array = []
	for club in season.clubs.values():
		if (club as Club).id != season.human_club_id:
			ai_clubs.append(club)
	if ai_clubs.size() < 2:
		return season

	var rand := FMRandom.new(seed)

	# AI selling club with a surplus squad (> 16 players).
	var surplus: Array = []
	for club in ai_clubs:
		if (club as Club).squad.size() > 16:
			surplus.append(club)
	if surplus.is_empty():
		return season
	var seller: Club = rand.pick(surplus)

	# Non-GK outfield candidate from the seller's depth.
	var candidates: Array = []
	for pid in seller.squad.player_ids:
		if not season.players.has(pid):
			continue
		var p: Player = season.players[pid]
		if not p.natural_positions.has(Position.Kind.GK) and p.is_available():
			candidates.append(p)
	candidates.sort_custom(func(a, b): return (a as Player).best_overall() < (b as Player).best_overall())
	candidates = candidates.slice(0, 3)
	if candidates.is_empty():
		return season
	var candidate: Player = rand.pick(candidates)

	# AI buyer with budget and squad room that does not already hold the player.
	var fee: int = maxi(candidate.best_overall() * 10000, 50000)
	var buyers: Array = []
	for club in ai_clubs:
		var c: Club = club
		if c.id != seller.id and c.finance.balance >= fee and c.squad.size() <= 22 and not c.squad.contains(candidate.id):
			buyers.append(c)
	if buyers.is_empty():
		return season
	var buyer: Club = rand.pick(buyers)

	var request := DirectTransfer.Request.new(candidate.id, seller.id, buyer.id, fee)
	return _direct_transfer.execute(season, request)
