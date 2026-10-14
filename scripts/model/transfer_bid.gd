# Source: engine/.../model/Transfer.kt (TransferBid).
class_name TransferBid
extends RefCounted

var id: int = 0
var player_id: int = 0
var buying_club_id: int = 0
var selling_club_id: int = -1
var fee_offered: int = 0
var status: int = BidStatus.Kind.PENDING
var date_submitted: String = ""
var contract_offer: ContractOffer = null


func to_dict() -> Dictionary:
	return {
		"id": id,
		"playerId": player_id,
		"buyingClubId": buying_club_id,
		"sellingClubId": selling_club_id if selling_club_id >= 0 else null,
		"feeOffered": fee_offered,
		"status": BidStatus.to_string_value(status),
		"dateSubmitted": date_submitted,
		"contractOffer": contract_offer.to_dict() if contract_offer != null else null,
	}


static func from_dict(d: Dictionary) -> TransferBid:
	var b := TransferBid.new()
	b.id = int(d.get("id", 0))
	b.player_id = int(d.get("playerId", 0))
	b.buying_club_id = int(d.get("buyingClubId", 0))
	var sid = d.get("sellingClubId", null)
	b.selling_club_id = int(sid) if sid != null else -1
	b.fee_offered = int(d.get("feeOffered", 0))
	b.status = BidStatus.from_string(str(d.get("status", "PENDING")))
	b.date_submitted = str(d.get("dateSubmitted", ""))
	if d.get("contractOffer", null) != null:
		b.contract_offer = ContractOffer.from_dict(d["contractOffer"])
	return b
