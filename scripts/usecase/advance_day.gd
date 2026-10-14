# Source: engine/src/main/kotlin/com/footballmanager/usecase/AdvanceDayUseCase.kt
# Mirrors logic exactly: +1 day, injury countdown (-1/day, cleared at 0),
# natural daily recovery (+12 fitness up to 100).
# Dates are ISO strings; FMDate.add_days(iso, days) -> String is trusted.
# A NEW SeasonState is returned via duplicate() with the changed collections
# assigned (element refs are shared per the SeasonState parity contract).
# Player entities are plain mutable RefCounteds mutated in place -- a deliberate
# mutability difference vs Kotlin data-class immutability.
class_name AdvanceDay
extends RefCounted


func execute(season: SeasonState) -> SeasonState:
	var next_date: String = FMDate.add_days(season.current_date, 1)
	var updated_players: Dictionary = {}
	for player_id in season.players.keys():
		var player: Player = season.players[player_id]
		if player.injury_status != null:
			var rem: int = maxi(player.injury_status.days_remaining - 1, 0)
			if rem <= 0:
				player.injury_status = null
			else:
				player.injury_status.days_remaining = rem
		if player.fitness < 100:
			player.fitness = mini(player.fitness + 12, 100)
		updated_players[player_id] = player
	var nxt: SeasonState = season.duplicate()
	nxt.current_date = next_date
	nxt.players = updated_players
	return nxt
