# Source: engine/.../model/Transfer.kt (TransferRecord).
class_name TransferRecord
extends RefCounted

var id: int = 0
var player_id: int = 0
var player_name: String = ""
var from_club_id: int = -1
var to_club_id: int = 0
var fee: int = 0
var date: String = ""


func to_dict() -> Dictionary:
	return {
		"id": id,
		"playerId": player_id,
		"playerName": player_name,
		"fromClubId": from_club_id if from_club_id >= 0 else null,
		"toClubId": to_club_id,
		"fee": fee,
		"date": date,
	}


static func from_dict(d: Dictionary) -> TransferRecord:
	var r := TransferRecord.new()
	r.id = int(d.get("id", 0))
	r.player_id = int(d.get("playerId", 0))
	r.player_name = str(d.get("playerName", "?"))
	var fid = d.get("fromClubId", null)
	r.from_club_id = int(fid) if fid != null else -1
	r.to_club_id = int(d.get("toClubId", 0))
	r.fee = int(d.get("fee", 0))
	r.date = str(d.get("date", ""))
	return r
