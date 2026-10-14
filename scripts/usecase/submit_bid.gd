# Source: engine/src/main/kotlin/com/footballmanager/usecase/SubmitTransferBidUseCase.kt
# Mirrors logic exactly: fee must be non-negative and within the buyer's transfer
# budget; free agents (selling_club_id == -1 sentinel, mirroring TransferBid)
# are ACCEPTED_BY_CLUB immediately, otherwise PENDING.
class_name SubmitTransferBid
extends RefCounted


func execute(bid_id: int, buying_club: Club, player: Player, selling_club_id: int, fee_offered: int, current_date: String) -> TransferBid:
	assert(fee_offered >= 0, "Transfer fee offered cannot be negative")
	assert(buying_club.finance.transfer_budget >= fee_offered, "Insufficient transfer budget")
	var bid := TransferBid.new()
	bid.id = bid_id
	bid.player_id = player.id
	bid.buying_club_id = buying_club.id
	bid.selling_club_id = selling_club_id
	bid.fee_offered = fee_offered
	bid.status = BidStatus.Kind.ACCEPTED_BY_CLUB if selling_club_id < 0 else BidStatus.Kind.PENDING
	bid.date_submitted = current_date
	return bid
