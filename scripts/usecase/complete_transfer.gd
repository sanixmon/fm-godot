# Source: engine/src/main/kotlin/com/footballmanager/usecase/CompleteTransferUseCase.kt
# Mirrors logic exactly: buyer pays full fee (balance + budget); seller (if any)
# gains full fee to balance but only 80% to transfer budget; player contract
# replaced with offer terms expiring current_date + contract_years; record id =
# bid id. Free-agent sellers use the -1 sentinel (mirroring TransferRecord).
# Dates are ISO strings; _plus_years mirrors LocalDate.plusYears.
# Club/Player/TransferBid are mutated in place (deliberate mutability difference
# vs Kotlin immutability).
class_name CompleteTransfer
extends RefCounted


class Result extends RefCounted:
	var updated_buyer: Club
	var updated_seller = null # Club or null (free agents have no seller)
	var updated_player: Player
	var completed_bid: TransferBid
	var record: TransferRecord
	func _init(buyer: Club, seller, player: Player, bid: TransferBid, transfer_record: TransferRecord) -> void:
		updated_buyer = buyer
		updated_seller = seller
		updated_player = player
		completed_bid = bid
		record = transfer_record


func execute(bid: TransferBid, buyer: Club, seller, player: Player, current_date: String) -> Result:
	var offer: ContractOffer = bid.contract_offer
	assert(offer != null, "Cannot complete transfer without contract offer terms")
	assert(buyer.finance.transfer_budget >= bid.fee_offered, "Buyer cannot afford fee")

	# 1. Buyer finance and squad.
	buyer.finance.transfer_budget -= bid.fee_offered
	buyer.finance.balance -= bid.fee_offered
	if not buyer.squad.player_ids.has(player.id):
		buyer.squad.player_ids = (buyer.squad.player_ids as Array) + [player.id]

	# 2. Seller finance and squad (skipped for free agents).
	if seller != null:
		var sell_share: int = int(bid.fee_offered * 0.80)
		seller.finance.transfer_budget += sell_share
		seller.finance.balance += bid.fee_offered
		var seller_ids: Array = (seller.squad.player_ids as Array).duplicate()
		seller_ids.erase(player.id)
		seller.squad.player_ids = seller_ids

	# 3. Player contract.
	player.contract.weekly_wage = offer.weekly_wage
	player.contract.expires_on = _plus_years(current_date, offer.contract_years)
	player.contract.squad_status = offer.squad_status

	# 4. Record and final bid state.
	var record := TransferRecord.new()
	record.id = bid.id
	record.player_id = player.id
	record.player_name = player.name
	record.from_club_id = seller.id if seller != null else -1
	record.to_club_id = buyer.id
	record.fee = bid.fee_offered
	record.date = current_date
	bid.status = BidStatus.Kind.COMPLETED

	return Result.new(buyer, seller, player, bid, record)


static func _plus_years(iso_date: String, years: int) -> String:
	var parts: PackedStringArray = iso_date.split("-")
	return "%04d-%s-%s" % [int(parts[0]) + years, parts[1], parts[2]]
