# Source: engine/src/main/kotlin/com/footballmanager/usecase/PlayerDevelopmentUseCase.kt
# Mirrors logic exactly: per-player training regime updates; squad-wide updates
# keep GOALKEEPING focus for natural goalkeepers unless BALANCED is requested;
# annual development delegates per player to PlayerDevelopmentCalc (which takes
# the club's training_level int and defaults the seed to player.id xor 2026,
# exactly mirroring the Kotlin calculator defaults).
# Players are mutated in place (deliberate mutability difference vs Kotlin
# immutability); a new SeasonState is returned via duplicate().
class_name PlayerDevelopment
extends RefCounted


# Updates an individual player's training regime.
func set_player_training(season: SeasonState, player_id: int, focus: int, intensity: int = TrainingIntensity.Kind.NORMAL) -> SeasonState:
	var player: Player = season.players.get(player_id)
	if player == null:
		return season
	player.training_focus = focus
	player.training_intensity = intensity
	var nxt: SeasonState = season.duplicate()
	nxt.players = season.players.duplicate()
	nxt.players[player_id] = player
	return nxt


# Updates the training focus and intensity for an entire squad.
func set_club_squad_training(season: SeasonState, club_id: int, focus: int, intensity: int = TrainingIntensity.Kind.NORMAL) -> SeasonState:
	var club: Club = season.clubs.get(club_id)
	if club == null:
		return season
	var updated_players: Dictionary = season.players.duplicate()
	for pid in club.squad.player_ids:
		var player: Player = updated_players.get(pid)
		if player == null:
			continue
		# Goalkeepers retain GOALKEEPING focus unless explicitly changed.
		var target_focus: int = focus
		if _is_goalkeeper(player) and focus != TrainingFocus.Kind.BALANCED:
			target_focus = TrainingFocus.Kind.GOALKEEPING
		player.training_focus = target_focus
		player.training_intensity = intensity
		updated_players[pid] = player
	var nxt: SeasonState = season.duplicate()
	nxt.players = updated_players
	return nxt


# Applies annual player development across all clubs and players in the season.
func execute_annual_development(season: SeasonState) -> SeasonState:
	var updated_players: Dictionary = {}
	for player_id in season.players.keys():
		var player: Player = season.players[player_id]
		var training_level: int = 1
		for c in season.clubs.values():
			if (c as Club).squad.contains(player.id):
				training_level = (c as Club).facilities.training_level
				break
		var stats: PlayerSeasonStats = season.player_stats.get(player.id)
		updated_players[player_id] = PlayerDevelopmentCalc.apply_development(player, training_level, stats)
	var nxt: SeasonState = season.duplicate()
	nxt.players = updated_players
	return nxt


static func _is_goalkeeper(player: Player) -> bool:
	return player.natural_positions.has(Position.Kind.GK)
