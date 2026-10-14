# Source: engine/src/main/kotlin/com/footballmanager/calculator/TransferValuationCalculator.kt
# Parity notes:
# - listing_status int assumes TransferListingStatus ordinals: NONE=0,
#   TRANSFER_LISTED=1, LOAN_LISTED=2, NOT_FOR_SALE=3.
# - Dates are ISO strings ("YYYY-MM-DD"). player.contract.expires_on is trusted
#   as a String per the cross-batch Contract API.
# - Kotlin default currentDate = expiresOn.minusYears(1) is exactly 12 complete
#   months, so an empty current_date_iso falls back to 12 (0.75 bracket).
# - Month arithmetic mirrors ChronoUnit.MONTHS.between (complete months only):
#   a month counts only if the expiry day-of-month has been reached.
# - Kotlin roundToLong is half-up; int(round()) matches for non-negative values.
class_name TransferValuation
extends RefCounted

const STATUS_NONE: int = 0
const STATUS_TRANSFER_LISTED: int = 1
const STATUS_LOAN_LISTED: int = 2
const STATUS_NOT_FOR_SALE: int = 3


static func calculate_market_value(player, listing_status: int = STATUS_NONE, current_date_iso: String = "") -> int:
	if listing_status == STATUS_NOT_FOR_SALE:
		return 0

	var overall: int = player.best_overall()
	var base_value: int = 0
	if overall < 60:
		base_value = 50000 + ((overall - 1) * 3000)
	elif overall < 70:
		base_value = 250000 + ((overall - 60) * 125000)
	elif overall < 80:
		base_value = 1500000 + ((overall - 70) * 650000)
	elif overall < 90:
		base_value = 8000000 + ((overall - 80) * 2200000)
	else:
		base_value = 30000000 + ((overall - 90) * 5000000)

	var age: int = int(player.age)
	var age_multiplier: float = 1.0
	if age < 21:
		age_multiplier = 1.35
	elif age <= 25:
		age_multiplier = 1.20
	elif age <= 29:
		age_multiplier = 1.00
	elif age <= 33:
		age_multiplier = 0.70
	else:
		age_multiplier = 0.40

	var expiry_iso: String = str(player.contract.expires_on)
	var months_remaining: int = 12
	if current_date_iso != "":
		months_remaining = maxi(_months_between(current_date_iso, expiry_iso), 0)
	var contract_multiplier: float = 1.0
	if months_remaining < 6:
		contract_multiplier = 0.50
	elif months_remaining <= 12:
		contract_multiplier = 0.75
	elif months_remaining <= 36:
		contract_multiplier = 1.00
	else:
		contract_multiplier = 1.15

	var status_multiplier: float = 1.0
	if listing_status == STATUS_TRANSFER_LISTED:
		status_multiplier = 0.80
	elif listing_status == STATUS_LOAN_LISTED:
		status_multiplier = 0.90

	var raw_value: int = int(round(float(base_value) * age_multiplier * contract_multiplier * status_multiplier))
	return maxi(raw_value, 10000)


# Complete months from from_iso to to_iso (mirrors ChronoUnit.MONTHS.between).
static func _months_between(from_iso: String, to_iso: String) -> int:
	var f: Dictionary = _parse_date(from_iso)
	var t: Dictionary = _parse_date(to_iso)
	if f.is_empty() or t.is_empty():
		return 12
	var months: int = (int(t["year"]) - int(f["year"])) * 12 + (int(t["month"]) - int(f["month"]))
	if int(t.get("day", 1)) < int(f.get("day", 1)):
		months -= 1
	return months


static func _parse_date(iso: String) -> Dictionary:
	var d: Dictionary = Time.get_datetime_dict_from_datetime_string(iso)
	if d.is_empty() and not iso.contains("T"):
		d = Time.get_datetime_dict_from_datetime_string(iso + "T00:00:00")
	return d
