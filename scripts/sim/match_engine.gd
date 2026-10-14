# match_engine.gd
# Godot 4 GDScript port of the Kotlin deterministic 90-minute match engine.
#
# Source: engine/src/main/kotlin/com/footballmanager/simulation/MatchEngine.kt (746 lines)
# Logger interface: engine/src/main/kotlin/com/footballmanager/logging/MatchLogger.kt
# Stats shapes: engine/src/main/kotlin/com/footballmanager/simulation/MatchStats.kt
#
# Parity notes:
# - Mirrors the Kotlin simulate() flow exactly, in order: synthetic XI/bench ->
#   per-minute loop 1..90 (stamina decay, subs home-then-away, possession, chance,
#   foul/card branch, shot branch, injury checks, minutes increment) -> team stats ->
#   combined player stats -> ratings -> MatchResult.
# - Logger: skipped (NoOp equivalent). `verbose: bool` prints goal / red-card /
#   final-score lines via print() when true.
# - Kotlin null player ids map to -1 (per MatchEvent contract defaults).
# - Kotlin `list.random(random)` == arr[rng.next_int(0, arr.size())].
# - Kotlin `require` == assert().
# - RATING PARITY QUIRK: Kotlin returns `(rating * 10).roundToInt() / 10.0.coerceIn(1.0, 10.0)`.
#   `coerceIn` binds to the literal 10.0 (which is unchanged), so the divisor is
#   plain 10.0 and the result is NOT clamped. Reproduced below as
#   `round(rating * 10.0) / 10.0` with no clamp. Do NOT "fix" this.
# - Enum-kind int consts below mirror Kotlin declaration ordinals:
#   Attribute PACE 0..GOALKEEPER 6; Side HOME 0, AWAY 1; MatchEventType
#   POSSESSION 0..SHOT_MISSED 13; Formation 4-4-2 0, 4-3-3 1, 4-2-3-1 2, 3-5-2 3;
#   Mentality DEFENSIVE 0, BALANCED 1, ATTACKING 2; Tempo SLOW 0, NORMAL 1, FAST 2;
#   Pressing LOW 0, MEDIUM 1, HIGH 2; Passing SHORT 0, MIXED 1, DIRECT 2;
#   Position GK 0, CB 1, LB 2, RB 3, DM 4, CM 5, AM 6, LW 7, RW 8, ST 9;
#   PositionGroup GOALKEEPER 0, DEFENDER 1, MIDFIELDER 2, ATTACKER 3.
# - Trusts sibling-batch APIs exactly: FMRandom, Team, Tactics (+Formation.SLOTS),
#   Player, PlayerAttributes, Contract, MatchEvent, PlayerMatchStats, TeamStats,
#   MatchStats, MatchResult, SubstitutionRecord.
class_name MatchEngine
extends RefCounted


# Match constants (mirror MatchEngine companion object).
const MINUTES_PER_MATCH: int = 90
const BASE_CHANCE_PER_MINUTE: float = 0.16
const HOME_ADVANTAGE: float = 1.05
const MAX_SUBS_PER_MATCH: int = 5
const TICKS_PER_MATCH: int = 90
const MINUTES_PER_TICK: int = 1

# Attribute.Kind ints (mirror Attribute declaration order).
const ATTR_PACE: int = 0
const ATTR_SHOOTING: int = 1
const ATTR_PASSING: int = 2
const ATTR_DRIBBLING: int = 3
const ATTR_DEFENDING: int = 4
const ATTR_PHYSICAL: int = 5
const ATTR_GOALKEEPER: int = 6

# Side.Kind ints.
const SIDE_HOME: int = 0
const SIDE_AWAY: int = 1

# MatchEventType.Kind ints (mirror declaration order incl. SHOT_SAVED/SHOT_MISSED).
const EVENT_POSSESSION: int = 0
const EVENT_ATTACK: int = 1
const EVENT_SHOT: int = 2
const EVENT_SHOT_ON_TARGET: int = 3
const EVENT_GOAL: int = 4
const EVENT_SAVE: int = 5
const EVENT_CORNER: int = 6
const EVENT_FOUL: int = 7
const EVENT_YELLOW_CARD: int = 8
const EVENT_RED_CARD: int = 9
const EVENT_INJURY: int = 10
const EVENT_SUBSTITUTION: int = 11
const EVENT_SHOT_SAVED: int = 12
const EVENT_SHOT_MISSED: int = 13

# Position.Kind ints (mirror Position declaration order).
const POS_GK: int = 0
const POS_CB: int = 1
const POS_LB: int = 2
const POS_RB: int = 3
const POS_DM: int = 4
const POS_CM: int = 5
const POS_AM: int = 6
const POS_LW: int = 7
const POS_RW: int = 8
const POS_ST: int = 9

# PositionGroup.Kind ints.
const GROUP_GOALKEEPER: int = 0
const GROUP_DEFENDER: int = 1
const GROUP_MIDFIELDER: int = 2
const GROUP_ATTACKER: int = 3

# Tactics axis Kind ints (mirror Kotlin declaration orders).
const FORMATION_442: int = 0
const FORMATION_433: int = 1
const FORMATION_4231: int = 2
const FORMATION_352: int = 3
const MENTALITY_DEFENSIVE: int = 0
const MENTALITY_BALANCED: int = 1
const MENTALITY_ATTACKING: int = 2
const TEMPO_SLOW: int = 0
const TEMPO_NORMAL: int = 1
const TEMPO_FAST: int = 2
const PRESSING_LOW: int = 0
const PRESSING_MEDIUM: int = 1
const PRESSING_HIGH: int = 2
const PASSING_SHORT: int = 0
const PASSING_MIXED: int = 1
const PASSING_DIRECT: int = 2


var rng: FMRandom
var verbose: bool = false


func _init(p_rng: FMRandom = null) -> void:
	if p_rng == null:
		rng = FMRandom.new()
	else:
		rng = p_rng


static func with_seed(seed: int) -> MatchEngine:
	return MatchEngine.new(FMRandom.new(seed))


static func position_group(pos: int) -> int:
	match pos:
		POS_GK:
			return GROUP_GOALKEEPER
		POS_CB, POS_LB, POS_RB:
			return GROUP_DEFENDER
		POS_DM, POS_CM, POS_AM:
			return GROUP_MIDFIELDER
		_:
			return GROUP_ATTACKER


static func side_name(side: int) -> String:
	if side == SIDE_HOME:
		return "HOME"
	return "AWAY"


func simulate(
	home: Team, away: Team,
	home_starters = null, home_subs = null,
	away_starters = null, away_subs = null
) -> MatchResult:
	assert(home.club_id != away.club_id, "home and away must be different clubs")

	# 1. Resolve starting XIs and benches (override -> team list -> synthetic).
	var home_xi: Array = []
	if home_starters == null or home_starters.is_empty():
		if home.starters.is_empty():
			home_xi = _generate_synthetic_starters(home.club_id, home.effective_attack(), home.effective_defense(), home.tactics)
		else:
			home_xi = home.starters.duplicate()
	else:
		home_xi = home_starters.duplicate()
	var home_bench: Array = []
	if home_subs == null or home_subs.is_empty():
		if home.substitutes.is_empty():
			home_bench = _generate_synthetic_bench(home.club_id, home.effective_attack(), home.effective_defense())
		else:
			home_bench = home.substitutes.duplicate()
	else:
		home_bench = home_subs.duplicate()
	var away_xi: Array = []
	if away_starters == null or away_starters.is_empty():
		if away.starters.is_empty():
			away_xi = _generate_synthetic_starters(away.club_id, away.effective_attack(), away.effective_defense(), away.tactics)
		else:
			away_xi = away.starters.duplicate()
	else:
		away_xi = away_starters.duplicate()
	var away_bench: Array = []
	if away_subs == null or away_subs.is_empty():
		if away.substitutes.is_empty():
			away_bench = _generate_synthetic_bench(away.club_id, away.effective_attack(), away.effective_defense())
		else:
			away_bench = away.substitutes.duplicate()
	else:
		away_bench = away_subs.duplicate()

	# 2. Setup team in-match simulation contexts.
	var home_ctx: TeamMatchContext = TeamMatchContext.new(home, SIDE_HOME, home_xi, home_bench)
	var away_ctx: TeamMatchContext = TeamMatchContext.new(away, SIDE_AWAY, away_xi, away_bench)

	var events: Array = []
	var substitutions: Array = []

	# 3. Minute-by-minute simulation (1..90).
	for minute in range(1, MINUTES_PER_MATCH + 1):
		# A. Update stamina / fatigue.
		home_ctx.decay_stamina()
		away_ctx.decay_stamina()

		# B. Automated substitutions check (home then away).
		_process_substitutions(home_ctx, minute, events, substitutions)
		_process_substitutions(away_ctx, minute, events, substitutions)

		# C. Possession determination.
		var home_power: float = home_ctx.current_attack_power() * HOME_ADVANTAGE * _possession_modifier(home.tactics.passing)
		var away_power: float = away_ctx.current_attack_power() * _possession_modifier(away.tactics.passing)
		var home_possession_prob: float = clampf(home_power / (home_power + away_power), 0.15, 0.85)

		var home_has_ball: bool = rng.next_double() < home_possession_prob
		var attacking_ctx: TeamMatchContext = home_ctx if home_has_ball else away_ctx
		var defending_ctx: TeamMatchContext = away_ctx if home_has_ball else home_ctx

		attacking_ctx.possessions += 1

		# D. Chance generation.
		var mentality_mod: float = 1.0
		match attacking_ctx.team.tactics.mentality:
			MENTALITY_ATTACKING:
				mentality_mod = 1.20
			MENTALITY_DEFENSIVE:
				mentality_mod = 0.80
		var tempo_mod: float = 1.0
		match attacking_ctx.team.tactics.tempo:
			TEMPO_FAST:
				tempo_mod = 1.15
			TEMPO_SLOW:
				tempo_mod = 0.85
		var chance_prob: float = clampf(BASE_CHANCE_PER_MINUTE * mentality_mod * tempo_mod, 0.04, 0.40)

		if rng.next_double() < chance_prob:
			events.append(MatchEvent.new(
				minute, EVENT_ATTACK, attacking_ctx.side, attacking_ctx.team.club_id,
				-1, -1, "Attacking build-up by %s" % side_name(attacking_ctx.side)
			))

			# E. Defending challenge / tackle.
			var foul_base_prob: float = 0.20 * _ball_winning_modifier(defending_ctx.team.tactics.pressing)
			if rng.next_double() < foul_base_prob:
				# Foul committed by defending player.
				var fouling_defender: Player = defending_ctx.pick_defender_for_action(rng)
				if fouling_defender != null:
					defending_ctx.fouls += 1
					defending_ctx.player_stats(fouling_defender.id).fouls += 1
				var foul_pid: int = fouling_defender.id if fouling_defender != null else -1
				var foul_name: String = fouling_defender.name if fouling_defender != null else "Defender"
				events.append(MatchEvent.new(
					minute, EVENT_FOUL, defending_ctx.side, defending_ctx.team.club_id,
					foul_pid, -1, "Foul committed by %s" % foul_name
				))

				# Card checks on foul.
				var card_roll: float = rng.next_double()
				if card_roll < 0.015 and fouling_defender != null:
					# Straight RED CARD.
					defending_ctx.red_cards += 1
					defending_ctx.eject_player(fouling_defender.id)
					var rst: PlayerMatchStats = defending_ctx.player_stats(fouling_defender.id)
					rst.red_cards += 1
					rst.is_red_carded = true
					events.append(MatchEvent.new(
						minute, EVENT_RED_CARD, defending_ctx.side, defending_ctx.team.club_id,
						fouling_defender.id, -1, "Straight RED card shown to %s" % fouling_defender.name
					))
					if verbose:
						print("Minute %d: RED card shown to %s" % [minute, fouling_defender.name])
				elif card_roll < 0.15 and fouling_defender != null:
					# Yellow card (or second yellow -> RED).
					if defending_ctx.yellow_carded.has(fouling_defender.id):
						defending_ctx.red_cards += 1
						defending_ctx.eject_player(fouling_defender.id)
						var srst: PlayerMatchStats = defending_ctx.player_stats(fouling_defender.id)
						srst.yellow_cards += 1
						srst.red_cards += 1
						srst.is_red_carded = true
						events.append(MatchEvent.new(
							minute, EVENT_RED_CARD, defending_ctx.side, defending_ctx.team.club_id,
							fouling_defender.id, -1,
							"Second yellow card! Red card shown to %s" % fouling_defender.name
						))
						if verbose:
							print("Minute %d: Second yellow! Red card shown to %s" % [minute, fouling_defender.name])
					else:
						defending_ctx.yellow_cards += 1
						defending_ctx.yellow_carded[fouling_defender.id] = true
						defending_ctx.player_stats(fouling_defender.id).yellow_cards += 1
						events.append(MatchEvent.new(
							minute, EVENT_YELLOW_CARD, defending_ctx.side, defending_ctx.team.club_id,
							fouling_defender.id, -1, "Yellow card shown to %s" % fouling_defender.name
						))
			else:
				# F. Shot attempt.
				var shooter: Player = attacking_ctx.pick_shooter(rng)
				if shooter != null:
					attacking_ctx.shots += 1
					attacking_ctx.player_stats(shooter.id).shots += 1
					events.append(MatchEvent.new(
						minute, EVENT_SHOT, attacking_ctx.side, attacking_ctx.team.club_id,
						shooter.id, -1, "Shot by %s" % shooter.name
					))

					# Is shot on target?
					var on_target_prob: float = clampf(
						0.50 + (float(shooter.attributes.attr_value(ATTR_SHOOTING)) / 300.0), 0.35, 0.75
					)
					if rng.next_double() < on_target_prob:
						attacking_ctx.shots_on_target += 1
						attacking_ctx.player_stats(shooter.id).shots_on_target += 1
						events.append(MatchEvent.new(
							minute, EVENT_SHOT_ON_TARGET, attacking_ctx.side, attacking_ctx.team.club_id,
							shooter.id, -1, "Shot on target by %s" % shooter.name
						))

						# Goal vs save.
						var gk: Player = defending_ctx.active_goalkeeper()
						var gk_skill: int = defending_ctx.team.defense
						if gk != null:
							gk_skill = gk.attributes.attr_value(ATTR_GOALKEEPER)
						var shoot_skill: int = shooter.attributes.attr_value(ATTR_SHOOTING)
						var goal_prob: float = clampf(0.35 + float(shoot_skill - gk_skill) * 0.005, 0.12, 0.65)
						if rng.next_double() < goal_prob:
							# GOAL!
							attacking_ctx.goals += 1
							attacking_ctx.player_stats(shooter.id).goals += 1
							# Assister (optional).
							var assister: Player = attacking_ctx.pick_assister(shooter.id, rng)
							if assister != null:
								attacking_ctx.player_stats(assister.id).assists += 1
							var assist_pid: int = assister.id if assister != null else -1
							var goal_desc: String = "GOAL! %s" % shooter.name
							if assister != null:
								goal_desc += " (assist: %s)" % assister.name
							events.append(MatchEvent.new(
								minute, EVENT_GOAL, attacking_ctx.side, attacking_ctx.team.club_id,
								shooter.id, assist_pid, goal_desc
							))
							if verbose:
								print("Minute %d: %s" % [minute, goal_desc])
						else:
							# SAVE!
							if gk != null:
								defending_ctx.player_stats(gk.id).saves += 1
							var gk_pid: int = gk.id if gk != null else -1
							var gk_name: String = gk.name if gk != null else "GK"
							events.append(MatchEvent.new(
								minute, EVENT_SAVE, defending_ctx.side, defending_ctx.team.club_id,
								gk_pid, -1, "Save by goalkeeper %s" % gk_name
							))
							events.append(MatchEvent.new(
								minute, EVENT_SHOT_SAVED, attacking_ctx.side, attacking_ctx.team.club_id,
								shooter.id, -1, ""
							))
							# Check for corner.
							if rng.next_double() < 0.35:
								attacking_ctx.corners += 1
								events.append(MatchEvent.new(
									minute, EVENT_CORNER, attacking_ctx.side, attacking_ctx.team.club_id,
									-1, -1, "Corner awarded to %s" % side_name(attacking_ctx.side)
								))
					else:
						# Missed.
						events.append(MatchEvent.new(
							minute, EVENT_SHOT_MISSED, attacking_ctx.side, attacking_ctx.team.club_id,
							shooter.id, -1, "Shot missed by %s" % shooter.name
						))

		# G. In-match injury check.
		_check_in_match_injury(home_ctx, minute, events, substitutions)
		_check_in_match_injury(away_ctx, minute, events, substitutions)

		# H. Increment minutes played for all active players.
		for p in home_ctx.active_players:
			home_ctx.player_stats((p as Player).id).minutes_played += 1
		for p in away_ctx.active_players:
			away_ctx.player_stats((p as Player).id).minutes_played += 1

	# 4. Compile final team and match statistics.
	var home_team_stats: TeamStats = TeamStats.new(
		home_ctx.possessions, home_ctx.shots, home_ctx.shots_on_target, home_ctx.goals,
		home_ctx.corners, home_ctx.fouls, home_ctx.yellow_cards, home_ctx.red_cards
	)
	var away_team_stats: TeamStats = TeamStats.new(
		away_ctx.possessions, away_ctx.shots, away_ctx.shots_on_target, away_ctx.goals,
		away_ctx.corners, away_ctx.fouls, away_ctx.yellow_cards, away_ctx.red_cards
	)
	var match_stats: MatchStats = MatchStats.new(MINUTES_PER_MATCH, home_team_stats, away_team_stats)

	# 5. Combine player match stats.
	var combined_player_stats: Dictionary = {}
	for st in home_ctx.all_player_stats():
		combined_player_stats[(st as PlayerMatchStats).player_id] = st
	for st in away_ctx.all_player_stats():
		combined_player_stats[(st as PlayerMatchStats).player_id] = st

	# 6. Calculate position-aware player ratings (1.0..10.0 scale, see parity note).
	var player_ratings: Dictionary = {}
	var all_participants: Array = home_ctx.all_known_players() + away_ctx.all_known_players()
	var home_ids: Dictionary = home_ctx.all_known_player_ids()
	for participant in all_participants:
		var player: Player = participant as Player
		if not combined_player_stats.has(player.id):
			continue
		var stats: PlayerMatchStats = combined_player_stats[player.id] as PlayerMatchStats
		if stats.minutes_played > 0:
			var is_home: bool = home_ids.has(player.id)
			var goals_conceded: int = away_ctx.goals if is_home else home_ctx.goals
			var team_lost: bool = (home_ctx.goals < away_ctx.goals) if is_home else (away_ctx.goals < home_ctx.goals)
			player_ratings[player.id] = _calculate_rating(player, stats, goals_conceded, team_lost)

	var result: MatchResult = MatchResult.new(
		home.club_id, away.club_id, home_ctx.goals, away_ctx.goals,
		events, match_stats, MINUTES_PER_MATCH,
		combined_player_stats, player_ratings, substitutions
	)

	if verbose:
		print("Match ended: Club #%d %d - %d Club #%d" % [home.club_id, home_ctx.goals, away_ctx.goals, away.club_id])

	return result


func _process_substitutions(
	ctx: TeamMatchContext, minute: int, events: Array, substitutions: Array
) -> void:
	if ctx.substitutions_count >= MAX_SUBS_PER_MATCH or ctx.bench_players.is_empty():
		return

	# 1. Check for injured player needing sub.
	var injured_active: Player = null
	for p in ctx.active_players:
		var pl: Player = p as Player
		if ctx.player_stats(pl.id).is_injured:
			injured_active = pl
			break
	if injured_active != null:
		_execute_substitution(ctx, injured_active, minute, "Injury", events, substitutions)
		return

	# 2. Check for severe fatigue after minute 60.
	if minute >= 60 and ctx.substitutions_count < MAX_SUBS_PER_MATCH:
		var fatigued: Player = null
		for p in ctx.active_players:
			var pl: Player = p as Player
			if ctx.stamina(pl.id) < 35.0 and not pl.natural_positions.has(POS_GK):
				fatigued = pl
				break
		if fatigued != null:
			_execute_substitution(ctx, fatigued, minute, "Fatigue", events, substitutions)
			return

	# 3. Check for tactical underperformance after minute 65.
	if minute >= 65 and ctx.substitutions_count < MAX_SUBS_PER_MATCH:
		var underperforming: Player = null
		for p in ctx.active_players:
			var pl: Player = p as Player
			var pst: PlayerMatchStats = ctx.player_stats(pl.id)
			if (not pl.natural_positions.has(POS_GK) and pst.goals == 0
					and pst.assists == 0 and ctx.stamina(pl.id) < 55.0):
				underperforming = pl
				break
		if underperforming != null and not ctx.bench_players.is_empty():
			_execute_substitution(ctx, underperforming, minute, "Tactical", events, substitutions)


func _execute_substitution(
	ctx: TeamMatchContext, player_out: Player, minute: int, reason: String,
	events: Array, substitutions: Array
) -> bool:
	var candidate_sub: Player = null
	for b in ctx.bench_players:
		var bp: Player = b as Player
		var bst: PlayerMatchStats = ctx.player_stats(bp.id)
		if (not bst.is_injured and not bst.is_red_carded
				and not bst.is_substituted_in and not ctx.subbed_out.has(bp.id)):
			candidate_sub = bp
			break
	if candidate_sub == null:
		return false
	ctx.active_players.erase(player_out)
	ctx.bench_players.erase(candidate_sub)
	ctx.active_players.append(candidate_sub)
	ctx.subbed_out[player_out.id] = true
	ctx.substitutions_count += 1

	ctx.player_stats(player_out.id).is_substituted_out = true
	ctx.player_stats(candidate_sub.id).is_substituted_in = true

	var record: SubstitutionRecord = SubstitutionRecord.new(
		minute, ctx.team.club_id, player_out.id, candidate_sub.id, reason
	)
	substitutions.append(record)
	events.append(MatchEvent.new(
		minute, EVENT_SUBSTITUTION, ctx.side, ctx.team.club_id,
		player_out.id, candidate_sub.id,
		"Substitution (%s): %s OFF, %s ON" % [reason, player_out.name, candidate_sub.name]
	))
	return true


func _check_in_match_injury(
	ctx: TeamMatchContext, minute: int, events: Array, substitutions: Array
) -> void:
	if ctx.active_players.is_empty():
		return
	# ~0.003 chance per team per minute (about 1 injury every ~4 matches across both teams).
	if rng.next_double() < 0.003:
		var injured: Player = ctx.active_players[rng.next_int(0, ctx.active_players.size())] as Player
		ctx.player_stats(injured.id).is_injured = true
		events.append(MatchEvent.new(
			minute, EVENT_INJURY, ctx.side, ctx.team.club_id,
			injured.id, -1, "Injury to %s" % injured.name
		))
		# Immediate substitution if possible, otherwise remove injured player from field.
		var subbed: bool = false
		if ctx.substitutions_count < MAX_SUBS_PER_MATCH and not ctx.bench_players.is_empty():
			subbed = _execute_substitution(ctx, injured, minute, "Injury", events, substitutions)
		if not subbed:
			ctx.active_players.erase(injured)


func _calculate_rating(
	player: Player, stats: PlayerMatchStats, goals_conceded: int, team_lost: bool
) -> float:
	var rating: float = 6.2

	# Goals and assists.
	rating += float(stats.goals) * 1.1
	rating += float(stats.assists) * 0.6

	# Position-specific modifiers.
	var primary_group: int = position_group(player.best_position())
	match primary_group:
		GROUP_GOALKEEPER:
			rating += float(stats.saves) * 0.45
			rating -= float(goals_conceded) * 0.40
			if goals_conceded == 0 and stats.minutes_played >= 45:
				rating += 0.8
		GROUP_DEFENDER:
			rating += float(stats.defensive_contributions) * 0.25
			rating -= float(goals_conceded) * 0.25
			if goals_conceded == 0 and stats.minutes_played >= 45:
				rating += 0.6
			rating += float(stats.passing_contributions) * 0.1
		GROUP_MIDFIELDER:
			rating += float(stats.passing_contributions) * 0.25
			rating += float(stats.attacking_contributions) * 0.25
			rating += float(stats.defensive_contributions) * 0.15
			rating += float(stats.shots_on_target) * 0.2
		GROUP_ATTACKER:
			rating += float(stats.shots_on_target) * 0.35
			rating += float(stats.attacking_contributions) * 0.25
			rating += float(stats.shots) * 0.10

	# Cards and disciplinary penalties.
	if stats.yellow_cards > 0:
		rating -= 0.4 * float(stats.yellow_cards)
	if stats.red_cards > 0:
		rating -= 1.8 * float(stats.red_cards)
	rating -= float(stats.fouls) * 0.1

	# Team loss penalty.
	if team_lost and goals_conceded >= 3:
		rating -= 0.4

	# PARITY (see header): Kotlin divides by `10.0.coerceIn(1.0, 10.0)` which is
	# still 10.0, so there is intentionally NO clamp here. Do NOT add one.
	return round(rating * 10.0) / 10.0


func _possession_modifier(passing: int) -> float:
	match passing:
		PASSING_SHORT:
			return 1.05
		PASSING_DIRECT:
			return 0.92
	return 1.0


func _ball_winning_modifier(pressing: int) -> float:
	match pressing:
		PRESSING_LOW:
			return 0.90
		PRESSING_HIGH:
			return 1.15
	return 1.0


func _generate_synthetic_starters(club_id: int, attack: int, defense: int, tactics: Tactics) -> Array:
	var slots: Array = Formation.SLOTS[tactics.formation]
	var out: Array = []
	var index: int = 0
	for pos in slots:
		var p_id: int = club_id * 1000 + (index + 1)
		out.append(_create_synthetic_player(p_id, "Player %d" % p_id, int(pos), attack, defense))
		index += 1
	return out


func _generate_synthetic_bench(club_id: int, attack: int, defense: int) -> Array:
	var bench_positions: Array = [POS_GK, POS_CB, POS_CM, POS_LW, POS_ST]
	var out: Array = []
	var index: int = 0
	for pos in bench_positions:
		var p_id: int = club_id * 1000 + (12 + index)
		out.append(_create_synthetic_player(p_id, "Sub %d" % p_id, int(pos), attack, defense))
		index += 1
	return out


func _create_synthetic_player(
	p_id: int, player_name: String, position: int, attack: int, defense: int
) -> Player:
	var group: int = position_group(position)
	var quality: int = defense if (group == GROUP_DEFENDER or group == GROUP_GOALKEEPER) else attack
	var attrs: Dictionary = {
		ATTR_PACE: quality,
		ATTR_SHOOTING: (quality + 5 if group == GROUP_ATTACKER else quality - 10),
		ATTR_PASSING: quality,
		ATTR_DRIBBLING: quality,
		ATTR_DEFENDING: (quality + 5 if group == GROUP_DEFENDER else quality - 10),
		ATTR_PHYSICAL: quality,
		ATTR_GOALKEEPER: (quality + 10 if position == POS_GK else 10),
	}
	var attributes: PlayerAttributes = PlayerAttributes.new(attrs)
	var contract: Contract = Contract.new(2000, "2030-06-30")
	return Player.new(p_id, player_name, 24, "ID", [position], attributes, contract)


# In-match tracking context for a single team (mirrors Kotlin TeamMatchContext).
class TeamMatchContext extends RefCounted:
	var team: Team
	var side: int = 0
	var active_players: Array = []
	var bench_players: Array = []
	var possessions: int = 0
	var shots: int = 0
	var shots_on_target: int = 0
	var goals: int = 0
	var corners: int = 0
	var fouls: int = 0
	var yellow_cards: int = 0
	var red_cards: int = 0
	var substitutions_count: int = 0
	var subbed_out: Dictionary = {}
	var yellow_carded: Dictionary = {}
	var stamina_map: Dictionary = {}
	var stats_map: Dictionary = {}

	func _init(p_team: Team, p_side: int, p_active: Array, p_bench: Array) -> void:
		team = p_team
		side = p_side
		active_players = p_active
		bench_players = p_bench
		for p in active_players + bench_players:
			var pl: Player = p as Player
			stamina_map[pl.id] = float(pl.fitness)
		for p in active_players:
			var pl: Player = p as Player
			stats_map[pl.id] = PlayerMatchStats.new(pl.id, team.club_id, true)
		for p in bench_players:
			var pl: Player = p as Player
			stats_map[pl.id] = PlayerMatchStats.new(pl.id, team.club_id, false)

	func stamina(player_id: int) -> float:
		if stamina_map.has(player_id):
			return float(stamina_map[player_id])
		return 100.0

	func decay_stamina() -> void:
		var base: float = 0.35
		if team.tactics.pressing == MatchEngine.PRESSING_HIGH:
			base = 0.45
		elif team.tactics.pressing == MatchEngine.PRESSING_LOW:
			base = 0.25
		var tempo_mult: float = 1.0
		if team.tactics.tempo == MatchEngine.TEMPO_FAST:
			tempo_mult = 1.20
		elif team.tactics.tempo == MatchEngine.TEMPO_SLOW:
			tempo_mult = 0.85
		var rate: float = base * tempo_mult
		for p in active_players:
			var pl: Player = p as Player
			stamina_map[pl.id] = maxf(stamina(pl.id) - rate, 10.0)

	func player_stats(player_id: int) -> PlayerMatchStats:
		if not stats_map.has(player_id):
			stats_map[player_id] = PlayerMatchStats.new(player_id, team.club_id)
		return stats_map[player_id] as PlayerMatchStats

	func all_player_stats() -> Array:
		var out: Array = []
		for key in stats_map:
			out.append(stats_map[key])
		return out

	func all_known_players() -> Array:
		var seen: Dictionary = {}
		var out: Array = []
		for p in active_players + bench_players:
			var pl: Player = p as Player
			if not seen.has(pl.id):
				seen[pl.id] = true
				out.append(pl)
		return out

	func all_known_player_ids() -> Dictionary:
		var out: Dictionary = {}
		for p in all_known_players():
			out[(p as Player).id] = true
		return out

	func eject_player(player_id: int) -> void:
		var kept: Array = []
		for p in active_players:
			if (p as Player).id != player_id:
				kept.append(p)
		active_players = kept

	func current_attack_power() -> float:
		var player_ratio: float = clampf(float(active_players.size()) / 11.0, 0.5, 1.0)
		return float(team.effective_attack()) * player_ratio

	func active_goalkeeper() -> Player:
		for p in active_players:
			var pl: Player = p as Player
			if pl.natural_positions.has(MatchEngine.POS_GK):
				return pl
		if active_players.is_empty():
			return null
		return active_players[0] as Player

	func pick_shooter(p_rng: FMRandom) -> Player:
		if active_players.is_empty():
			return null
		var candidates: Array = []
		for p in active_players:
			if not (p as Player).natural_positions.has(MatchEngine.POS_GK):
				candidates.append(p)
		if candidates.is_empty():
			candidates = active_players.duplicate()
		var weights: Array = []
		for c in candidates:
			var g: int = MatchEngine.position_group((c as Player).best_position())
			if g == MatchEngine.GROUP_ATTACKER:
				weights.append(5)
			elif g == MatchEngine.GROUP_MIDFIELDER:
				weights.append(3)
			else:
				weights.append(1)
		var total: int = 0
		for w in weights:
			total += int(w)
		var roll: int = p_rng.next_int(0, total)
		var idx: int = 0
		for w in weights:
			roll -= int(w)
			if roll < 0:
				return candidates[idx] as Player
			idx += 1
		return candidates[candidates.size() - 1] as Player

	func pick_assister(scorer_id: int, p_rng: FMRandom) -> Player:
		var candidates: Array = []
		for p in active_players:
			var pl: Player = p as Player
			if pl.id != scorer_id and not pl.natural_positions.has(MatchEngine.POS_GK):
				candidates.append(pl)
		if candidates.is_empty() or p_rng.next_double() > 0.65:
			return null
		return candidates[p_rng.next_int(0, candidates.size())] as Player

	func pick_defender_for_action(p_rng: FMRandom) -> Player:
		if active_players.is_empty():
			return null
		var defenders: Array = []
		for p in active_players:
			var g: int = MatchEngine.position_group((p as Player).best_position())
			if g == MatchEngine.GROUP_DEFENDER or g == MatchEngine.GROUP_MIDFIELDER:
				defenders.append(p)
		if not defenders.is_empty():
			return defenders[p_rng.next_int(0, defenders.size())] as Player
		return active_players[p_rng.next_int(0, active_players.size())] as Player
