# Source: engine/src/main/kotlin/com/footballmanager/usecase/NegotiateContractUseCase.kt
# Mirrors logic and thresholds exactly: accept at >= 0.90x expected wage,
# demand expected wage at >= 0.75x, else reject.
# TransferBid is mutated in place (same rationale as the Player/Club mutability note).
class_name NegotiateContract
extends RefCounted


class Decision extends RefCounted:
	const ACCEPT: int = 0
	const DEMAND: int = 1
	const REJECT: int = 2
	var kind: int = 0
	var demanded_wage: int = 0
	static func accept() -> Decision:
		var d := Decision.new()
		d.kind = ACCEPT
		return d
	static func demand(wage: int) -> Decision:
		var d := Decision.new()
		d.kind = DEMAND
		d.demanded_wage = wage
		return d
	static func reject() -> Decision:
		var d := Decision.new()
		d.kind = REJECT
		return d


func evaluate(player: Player, offer: ContractOffer) -> Decision:
	var expected_wage: int = WageExpectation.calculate_expected_wage(player, offer.squad_status)
	var min_acceptable_wage: int = int(expected_wage * 0.90)
	var min_counter_wage: int = int(expected_wage * 0.75)
	if offer.weekly_wage >= min_acceptable_wage:
		return Decision.accept()
	if offer.weekly_wage >= min_counter_wage:
		return Decision.demand(expected_wage)
	return Decision.reject()


func apply_offer(bid: TransferBid, offer: ContractOffer, decision: Decision) -> TransferBid:
	if decision.kind == Decision.ACCEPT:
		bid.status = BidStatus.Kind.ACCEPTED_BY_PLAYER
	elif decision.kind == Decision.DEMAND:
		bid.status = BidStatus.Kind.TERMS_OFFERED
	else:
		bid.status = BidStatus.Kind.REJECTED_BY_PLAYER
	bid.contract_offer = offer
	return bid
