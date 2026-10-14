# Source: engine/src/main/kotlin/com/footballmanager/usecase/ApplyMatchResultToWorldUseCase.kt
# Mirrors logic exactly: 75k home gate receipts; participant vs non-participant
# handling; card/suspension rules (straight red = 2 matches, double yellow = 1,
# 5-yellow accumulation = 1 with carry-over); form deltas (+4/+2/-4/-2 by rating);
# fitness drain (12 starter / 6); morale (+6 win / -4 loss / +1 draw); 14-day match
# injury; suspension/injury countdown for non-participants (-1 match / -7 days);
# +12 resting fitness recovery; manager and board updates for the human club.
# Player/Club entities are mutated in place (deliberate mutability difference vs
# Kotlin immutability); a new SeasonState is returned via duplicate().
# ManagerProfile.with_match_result and BoardObjectives.with_match_evaluation
# return new values (mirroring Kotlin copy semantics).
class_name ApplyMatchResult
extends RefCounted

const GATE_RECEIPTS: int = 75000


func execute(season: SeasonState, match_result: MatchResult) -> SeasonState:
	var home_id: int = match_result.home_club_id
	var away_id: int = match_result.away_club_id
	var home_goals: int = match_result.home_score
	var away_goals: int = match_result.away_score
	var is_home_win: bool = home_goals > away_goals
	var is_away_win: bool = away_goals > home_goals
	var is_draw: bool = home_goals == away_goals

	# 1. Home club gate receipts.
	var updated_clubs: Dictionary = season.clubs.duplicate()
	var home_club: Club = updated_clubs.get(home_id)
	if home_club != null:
		home_club.finance.balance += GATE_RECEIPTS

	var updated_players: Dictionary = season.players.duplicate()
	var updated_stats: Dictionary = season.player_stats.duplicate()

	# 2. Identify club squads.
	var home_squad: Array = (updated_clubs[home_id] as Club).squad.player_ids if updated_clubs.has(home_id) else []
	var away_squad: Array = (updated_clubs[away_id] as Club).squad.player_ids if updated_clubs.has(away_id) else []
	var squad_ids: Dictionary = {}
	for pid in home_squad + away_squad:
		squad_ids[pid] = true

	# 3. Process each player of the participating clubs.
	for player_id in squad_ids.keys():
		var player: Player = updated_players.get(player_id)
		if player == null:
			continue
		var is_home: bool = home_squad.has(player_id)
		var is_win: bool = is_home_win if is_home else is_away_win
		var is_loss: bool = is_away_win if is_home else is_home_win
		var pms: PlayerMatchStats = match_result.player_stats.get(player_id)

		var is_participant: bool
		if not match_result.player_stats.is_empty():
			is_participant = pms != null and pms.minutes_played > 0
		else:
			var home_lineup: Lineup = season.lineups.get(home_id)
			var away_lineup: Lineup = season.lineups.get(away_id)
			var home_starters: Array = home_lineup.starters if home_lineup != null else home_squad.slice(0, 11)
			var away_starters: Array = away_lineup.starters if away_lineup != null else away_squad.slice(0, 11)
			is_participant = home_starters.has(player_id) or away_starters.has(player_id)

		if is_participant:
			var current: PlayerSeasonStats = updated_stats.get(player_id)
			if current == null:
				current = PlayerSeasonStats.new()
				current.player_id = player_id
			var rating: float = float(match_result.player_ratings.get(player_id, 6.5))
			var goals: int = pms.goals if pms != null else 0
			var assists: int = pms.assists if pms != null else 0
			var yellow: bool = pms != null and pms.yellow_cards > 0
			var red: bool = pms != null and pms.red_cards > 0
			var is_starter: bool = pms.is_starter if pms != null else true
			var is_injured: bool = pms.is_injured if pms != null else false

			var yellow_count: int = pms.yellow_cards if pms != null else 0
			var has_double_yellow_red: bool = yellow_count >= 2 or _has_second_yellow_event(match_result.events, player_id)
			var has_straight_red: bool = red and not has_double_yellow_red

			var new_unserved: int = current.unserved_yellow_cards
			var suspension: SuspensionStatus = null
			if has_straight_red:
				suspension = SuspensionStatus.new(2, "Straight red card")
			elif has_double_yellow_red:
				suspension = SuspensionStatus.new(1, "Two yellow cards")
			elif yellow:
				new_unserved += yellow_count if pms != null else 1
				if new_unserved >= 5:
					suspension = SuspensionStatus.new(1, "Yellow card accumulation")
					new_unserved -= 5

			var clean_sheet: bool = _is_defensive_position(player) and ((away_goals == 0) if is_home else (home_goals == 0))
			updated_stats[player_id] = current.with_match_appearance(is_starter, goals, assists, clean_sheet, rating, yellow, red, new_unserved)

			var form_delta: int
			if rating >= 7.5:
				form_delta = 4
			elif rating >= 7.0:
				form_delta = 2
			elif rating < 5.5:
				form_delta = -4
			elif rating < 6.2:
				form_delta = -2
			else:
				form_delta = 0
			player.form = clampi(player.form + form_delta, 1, 100)

			var drain: int = 12 if is_starter else 6
			player.fitness = clampi(player.fitness - drain, 1, 100)
			var morale_delta: int = 6 if is_win else (-4 if is_loss else 1)
			player.morale = clampi(player.morale + morale_delta, 1, 100)

			if is_injured:
				player.injury_status = InjuryStatus.new(14, "Match Injury")
			if suspension != null:
				player.suspension_status = suspension
			updated_players[player_id] = player
		else:
			var resting: Player = player
			if resting.suspension_status != null and resting.suspension_status.matches_remaining > 0:
				var remaining: int = resting.suspension_status.matches_remaining - 1
				if remaining <= 0:
					resting.suspension_status = null
				else:
					resting.suspension_status.matches_remaining = remaining
			if resting.injury_status != null:
				var remaining_days: int = maxi(resting.injury_status.days_remaining - 7, 0)
				if remaining_days <= 0:
					resting.injury_status = null
				else:
					resting.injury_status.days_remaining = remaining_days
			if resting.fitness < 100:
				resting.fitness = mini(resting.fitness + 12, 100)
			updated_players[player_id] = resting

	# 4. Manager profile if human club participated.
	var human_id = season.human_club_id
	var updated_manager: ManagerProfile = season.manager_profile
	if updated_manager != null and (human_id == home_id or human_id == away_id):
		var human_won: bool = (human_id == home_id and is_home_win) or (human_id == away_id and is_away_win)
		updated_manager = updated_manager.with_match_result(human_won, is_draw)

	# 5. Board objectives.
	var updated_board: Dictionary = season.board_objectives.duplicate()
	if human_id != null and (human_id == home_id or human_id == away_id):
		var user_position: int = 4
		var idx: int = 0
		for entry in season.standings.entries:
			idx += 1
			if (entry as StandingEntry).team.club_id == human_id:
				user_position = idx
				break
		var human_won: bool = (human_id == home_id and is_home_win) or (human_id == away_id and is_away_win)
		var human_lost: bool = (human_id == home_id and is_away_win) or (human_id == away_id and is_home_win)
		var current_obj: BoardObjectives = updated_board.get(human_id)
		if current_obj == null:
			current_obj = BoardObjectives.new()
			current_obj.club_id = human_id
			current_obj.target_league_position = 4
		updated_board[human_id] = current_obj.with_match_evaluation(user_position, human_won, human_lost)

	var nxt: SeasonState = season.duplicate()
	nxt.clubs = updated_clubs
	nxt.players = updated_players
	nxt.player_stats = updated_stats
	nxt.board_objectives = updated_board
	nxt.manager_profile = updated_manager
	return nxt


func _has_second_yellow_event(events: Array, player_id: int) -> bool:
	for evt in events:
		var e: MatchEvent = evt
		if e.type == MatchEventType.Kind.RED_CARD and e.player_id == player_id and "second yellow" in e.description.to_lower():
			return true
	return false


static func _is_defensive_position(player: Player) -> bool:
	for p in player.natural_positions:
		var pname: String = Position.to_string_value(int(p))
		if pname.ends_with("B") or pname == "GK":
			return true
	return false
