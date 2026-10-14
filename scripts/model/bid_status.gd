# Source: engine/.../model/Transfer.kt (BidStatus enum).
class_name BidStatus
extends RefCounted

enum Kind {
	PENDING,
	ACCEPTED_BY_CLUB,
	REJECTED_BY_CLUB,
	TERMS_OFFERED,
	ACCEPTED_BY_PLAYER,
	REJECTED_BY_PLAYER,
	COMPLETED,
	CANCELLED,
}

const NAMES: Array = [
	"PENDING",
	"ACCEPTED_BY_CLUB",
	"REJECTED_BY_CLUB",
	"TERMS_OFFERED",
	"ACCEPTED_BY_PLAYER",
	"REJECTED_BY_PLAYER",
	"COMPLETED",
	"CANCELLED",
]


static func from_string(s: String) -> int:
	return NAMES.find(s.strip_edges().to_upper())


static func to_string_value(kind: int) -> String:
	return NAMES[kind]
