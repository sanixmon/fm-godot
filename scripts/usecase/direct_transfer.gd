# Source: engine/src/main/kotlin/com/footballmanager/usecase/DirectTransferUseCase.kt
# Mirrors logic exactly, including finance split (buyer pays full fee from balance
# and budget; seller gains full fee to balance) and lineup cleanup
# (auto-reselect when >= 11 players remain, else drop the lineup).
# Validation failures use push_error + unchanged return (GDScript has no
# exceptions); Kotlin `require` invariants use assert.
# Club/Finance entities are mutated in place (deliberate mutability difference
# vs Kotlin immutability); a new SeasonState is returned via duplicate().
class_name DirectTransfer
extends RefCounted


class Request extends RefCounted:
	var player_id: int = 0
	var from_club_id: int = 0
	var to_club_id: int = 0
	var transfer_fee: int = 0
	func _init(p_player_id: int = 0, p_from_club_id: int = 0, p_to_club_id: int = 0, p_fee: int = 0) -> void:
		player_id = p_player_id
		from_club_id = p_from_club_id
		to_club_id = p_to_club_id
		transfer_fee = p_fee


func execute(season: SeasonState, request: Request) -> SeasonState:
	var player: Player = season.players.get(request.player_id)
	if player == null:
		push_error("Invalid player ID: %d" % request.player_id)
		return season
	var from_club: Club = season.clubs.get(request.from_club_id)
	if from_club == null:
		push_error("Invalid source club ID: %d" % request.from_club_id)
		return season
	var to_club: Club = season.clubs.get(request.to_club_id)
	if to_club == null:
		push_error("Invalid destination club ID: %d" % request.to_club_id)
		return season

	assert(request.from_club_id != request.to_club_id, "Source and destination clubs must be different")
	if request.from_club_id == request.to_club_id:
		return season
	assert(from_club.squad.player_ids.has(player.id), "Player is not registered to source club")
	if not from_club.squad.player_ids.has(player.id):
		return season
	assert(not to_club.squad.player_ids.has(player.id), "Player is already registered to destination club")
	if to_club.squad.player_ids.has(player.id):
		return season
	assert(request.transfer_fee >= 0, "Transfer fee cannot be negative")
	if request.transfer_fee < 0:
		return season
	assert(to_club.finance.balance >= request.transfer_fee, "Destination club has insufficient balance")
	if to_club.finance.balance < request.transfer_fee:
		return season

	# Update finances.
	to_club.finance.balance -= request.transfer_fee
	to_club.finance.transfer_budget = maxi(to_club.finance.transfer_budget - request.transfer_fee, 0)
	from_club.finance.balance += request.transfer_fee
	from_club.finance.transfer_budget += request.transfer_fee

	# Move player between squads.
	var from_ids: Array = (from_club.squad.player_ids as Array).duplicate()
	from_ids.erase(player.id)
	from_club.squad.player_ids = from_ids
	to_club.squad.player_ids = (to_club.squad.player_ids as Array) + [player.id]

	var updated_clubs: Dictionary = season.clubs.duplicate()
	updated_clubs[from_club.id] = from_club
	updated_clubs[to_club.id] = to_club

	# Clean up fromClub lineup if it contained the transferred player.
	var updated_lineups: Dictionary = season.lineups.duplicate()
	var old_lineup: Lineup = updated_lineups.get(from_club.id)
	if old_lineup != null and (old_lineup.starters.has(player.id) or old_lineup.substitutes.has(player.id)):
		var remaining: Array = []
		for pid in from_ids:
			if season.players.has(pid):
				remaining.append(season.players[pid])
		if remaining.size() >= 11:
			var tactics: Tactics = from_club.default_tactics
			if tactics == null:
				tactics = _team_tactics(season, from_club.id)
			updated_lineups[from_club.id] = Lineup.auto_select(remaining, tactics, true, from_club.id)
		else:
			updated_lineups.erase(from_club.id)

	# Append to transferHistory.
	var next_record_id: int = 1
	for record in season.transfer_history:
		next_record_id = maxi(next_record_id, (record as TransferRecord).id + 1)
	var transfer_record := TransferRecord.new()
	transfer_record.id = next_record_id
	transfer_record.player_id = player.id
	transfer_record.player_name = player.name
	transfer_record.from_club_id = from_club.id
	transfer_record.to_club_id = to_club.id
	transfer_record.fee = request.transfer_fee
	transfer_record.date = season.current_date

	var nxt: SeasonState = season.duplicate()
	nxt.clubs = updated_clubs
	nxt.lineups = updated_lineups
	nxt.transfer_history = (season.transfer_history as Array) + [transfer_record]
	return nxt


func _team_tactics(season: SeasonState, club_id: int) -> Tactics:
	for team in season.teams:
		if (team as Team).club_id == club_id:
			return (team as Team).tactics
	return Tactics.new()
