# Source: engine/.../model/EmergencyGoalkeeper.kt.
class_name EmergencyGoalkeeper
extends RefCounted


static func create(club_id: int = 0, id: int = 0) -> Player:
	var resolved_id: int = id
	if resolved_id == 0:
		resolved_id = -club_id if club_id != 0 else -9999
	var attrs := {
		Attribute.Kind.GOALKEEPER: 50,
		Attribute.Kind.PHYSICAL: 50,
		Attribute.Kind.PASSING: 40,
		Attribute.Kind.DEFENDING: 40,
		Attribute.Kind.PACE: 40,
		Attribute.Kind.DRIBBLING: 30,
		Attribute.Kind.SHOOTING: 20,
	}
	var p := Player.new(
		resolved_id,
		"Academy Emergency GK",
		17,
		"ID",
		[Position.Kind.GK],
		PlayerAttributes.new(attrs),
		Contract.new(200, "2030-06-30")
	)
	p.potential = 60
	p.form = 50
	return p
