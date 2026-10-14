# Source: engine/.../model/Transfer.kt (TransferListingStatus enum).
class_name TransferListingStatus
extends RefCounted

enum Kind {
	NONE,
	TRANSFER_LISTED,
	LOAN_LISTED,
	NOT_FOR_SALE,
}

const NAMES: Array = ["NONE", "TRANSFER_LISTED", "LOAN_LISTED", "NOT_FOR_SALE"]


static func from_string(s: String) -> int:
	return NAMES.find(s.strip_edges().to_upper())


static func to_string_value(kind: int) -> String:
	return NAMES[kind]
