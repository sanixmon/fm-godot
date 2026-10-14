# Source: engine/src/main/kotlin/com/footballmanager/usecase/EvaluateTransferOfferUseCase.kt
# Mirrors logic and thresholds exactly: free agents (selling_club_id == -1
# sentinel) auto-accept; listed players accept at 0.85x / counter at 0.70x market
# value, others at 1.05x / 0.80x. The listing status and current date are passed
# into TransferValuation.calculate_market_value exactly as Kotlin does.
# TransferBid is mutated in place (same rationale as the Player/Club mutability note).
class_name EvaluateTransferOffer
extends RefCounted


class Decision extends RefCounted:
	const ACCEPT: int = 0
	const COUNTER: int = 1
	const REJECT: int = 2
	var kind: int = 0
	var counter_fee: int = 0
	static func accept() -> Decision:
		var d := Decision.new()
		d.kind = ACCEPT
		return d
	static func counter(fee: int) -> Decision:
		var d := Decision.new()
		d.kind = COUNTER
		d.counter_fee = fee
		return d
	static func reject() -> Decision:
		var d := Decision.new()
		d.kind = REJECT
		return d


func execute(bid: TransferBid, player: Player, listing_status: int = TransferListingStatus.Kind.NONE, current_date: String = "") -> Decision:
	if bid.selling_club_id < 0:
		return Decision.accept() # Free agents require no club fee agreement
	var as_of: String = current_date if current_date != "" else bid.date_submitted
	var market_value: int = TransferValuation.calculate_market_value(player, listing_status, as_of)
	var listed: bool = listing_status == TransferListingStatus.Kind.TRANSFER_LISTED
	var min_acceptable_fee: int = int(market_value * (0.85 if listed else 1.05))
	var min_counter_fee: int = int(market_value * (0.70 if listed else 0.80))
	if bid.fee_offered >= min_acceptable_fee:
		return Decision.accept()
	if bid.fee_offered >= min_counter_fee:
		return Decision.counter(min_acceptable_fee)
	return Decision.reject()


func apply_decision_to_bid(bid: TransferBid, decision: Decision) -> TransferBid:
	if decision.kind == Decision.ACCEPT:
		bid.status = BidStatus.Kind.ACCEPTED_BY_CLUB
	elif decision.kind == Decision.COUNTER:
		bid.status = BidStatus.Kind.PENDING
		bid.fee_offered = decision.counter_fee
	else:
		bid.status = BidStatus.Kind.REJECTED_BY_CLUB
	return bid
