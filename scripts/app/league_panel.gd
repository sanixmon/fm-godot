# League: full standings table + your-season strip (form + fixtures).
# Zone treatment is neutral (leader + your club); the engine defines no
# continental/relegation rules.
class_name LeaguePanel
extends VBoxContainer


func refresh() -> void:
	for c in get_children():
		c.queue_free()
	var season: SeasonState = AppState.season()
	add_child(FMUI.header("LEAGUE TABLE"))
	add_child(FMUI.row("#  CLUB            P   W  D  L  GF  GA  GD  PTS"))
	for i in season.standings.entries.size():
		var e = season.standings.entries[i]
		var mark := ">>" if e.team.club_id == AppState.human_club_id else "  "
		var gd: int = e.goal_difference
		add_child(FMUI.row("%s%-2d %-14s %2d  %2d %2d %2d  %2d  %2d  %+3d  %3d" % [
			mark, i + 1, AppState.game.club(e.team.club_id).short_name.left(14),
			e.played, e.won, e.drawn, e.lost, e.goals_for, e.goals_against, gd, e.points
		], Color.WHITE if e.team.club_id == AppState.human_club_id else Color("#94A3B8")))
	add_child(FMUI.header("YOUR SEASON"))
	var mine: Array = season.results.filter(
		func(r) -> bool: return r.home_club_id == AppState.human_club_id or r.away_club_id == AppState.human_club_id
	).take_last(5)
	if mine.is_empty():
		add_child(FMUI.row("No matches played yet."))
	else:
		var line := HBoxContainer.new()
		add_child(line)
		for r in mine:
			var home: bool = r.home_club_id == AppState.human_club_id
			var won: bool = (home and r.is_home_win()) or (not home and r.is_away_win())
			line.add_child(FMUI.form_badge(won, r.is_draw()))
	var coming: Array = season.fixtures.filter(
		func(fx) -> bool: return (fx.home.club_id == AppState.human_club_id or fx.away.club_id == AppState.human_club_id) and fx.date >= season.current_date
	).slice(0, 3)
	for fx in coming:
		var home: bool = fx.home.club_id == AppState.human_club_id
		var opp: int = fx.away.club_id if home else fx.home.club_id
		add_child(FMUI.row("%s vs %s • Round %d • %s" % [
			"H" if home else "A", AppState.game.club(opp).short_name, fx.round, fx.date
		]))
	if AppState.game.last_season != null and AppState.game.last_season.champion != null:
		add_child(FMUI.row("Defending champion: %s" % AppState.game.club(AppState.game.last_season.champion.team.club_id).name))
