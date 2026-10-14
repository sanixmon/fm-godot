# Match centre: pre-match preview, simulation trigger, full-time result with
# timeline, stats and ratings. The engine simulates instantly (no live states).
class_name MatchPanel
extends VBoxContainer

var on_navigate: Callable = Callable()


func refresh() -> void:
	for c in get_children():
		c.queue_free()
	add_child(FMUI.header("MATCH CENTRE"))
	var season: SeasonState = AppState.season()
	var last = AppState.last_user_result()
	if last != null:
		_add_result(last)
	_add_preview(season)
	_add_recent(season)


func _add_result(last) -> void:
	var home_name: String = AppState.game.club(last.home_club_id).name
	var away_name: String = AppState.game.club(last.away_club_id).name
	add_child(FMUI.title("FT: %s %d – %d %s" % [home_name, last.home_score, last.away_score, away_name], 18))
	var st = last.stats
	add_child(FMUI.row("Shots %d – %d   On target %d – %d   Possession %d%% – %d%%   Corners %d – %d" % [
		st.home.shots, st.away.shots, st.home.shots_on_target, st.away.shots_on_target,
		int(round(st.home_possession() * 100.0)), int(round(st.away_possession() * 100.0)),
		st.home.corners, st.away.corners
	]))
	add_child(FMUI.header("KEY EVENTS"))
	for e in last.events:
		if e.type == MatchEventType.Kind.GOAL or e.type == MatchEventType.Kind.RED_CARD or e.type == MatchEventType.Kind.SUBSTITUTION or e.type == MatchEventType.Kind.INJURY:
			add_child(FMUI.row("%d'  %s" % [e.minute, e.description]))
	add_child(FMUI.header("TOP RATINGS"))
	var ranked: Array = last.player_ratings.keys().duplicate()
	ranked.sort_custom(func(a, b) -> bool: return float(last.player_ratings[a]) > float(last.player_ratings[b]))
	for pid in ranked.slice(0, 5):
		if season_has_player(int(pid)):
			add_child(FMUI.row("%s — %.1f" % [AppState.game.player(int(pid)).name, float(last.player_ratings[pid])]))


func season_has_player(pid: int) -> bool:
	return AppState.game.players.has(pid)


func _add_preview(season: SeasonState) -> void:
	var fx = AppState.next_fixture()
	if fx == null or season.is_finished:
		return
	var home: bool = fx.home.club_id == AppState.human_club_id
	var opp_id: int = fx.away.club_id if home else fx.home.club_id
	add_child(FMUI.header("NEXT: ROUND %d" % fx.round))
	add_child(FMUI.row("%s (%s) — %s" % [
		AppState.game.club(opp_id).name, "home" if home else "away", fx.date
	], Color.WHITE))
	if not AppState.validation_error.is_empty():
		add_child(FMUI.row(AppState.validation_error, Color("#EF4444")))
		var fix := FMUI.button("REVIEW LINEUP IN TACTICS")
		fix.pressed.connect(func() -> void: on_navigate.call("tactics"))
		add_child(fix)
	var sim := FMUI.button("SIMULATE MATCHDAY")
	sim.pressed.connect(func() -> void: AppState.advance())
	add_child(sim)


func _add_recent(season: SeasonState) -> void:
	add_child(FMUI.header("RECENT RESULTS"))
	var mine: Array = season.results.filter(
		func(r) -> bool: return r.home_club_id == AppState.human_club_id or r.away_club_id == AppState.human_club_id
	).take_last(5)
	if mine.is_empty():
		add_child(FMUI.row("No matches played yet."))
		return
	for r in mine:
		add_child(FMUI.row("%s %d – %d %s" % [
			AppState.game.club(r.home_club_id).short_name, r.home_score,
			r.away_score, AppState.game.club(r.away_club_id).short_name
		]))
