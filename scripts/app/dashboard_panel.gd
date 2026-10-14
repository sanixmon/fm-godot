# Club command center: next match, last result, attention list, league
# snapshot, squad summary, finances. Panels navigate to their section.
class_name DashboardPanel
extends VBoxContainer

var on_navigate: Callable = Callable()


func refresh() -> void:
	for c in get_children():
		c.queue_free()
	var season: SeasonState = AppState.season()
	var club: Club = AppState.human_club()
	add_child(FMUI.title("%s  —  %s" % [club.name, season.current_date]))
	_add_form_row(season)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.stretch_ratio = 1.25
	cols.add_child(left)
	_add_next_match(left, season, club)
	_add_last_result(left, season)
	_add_attention(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.stretch_ratio = 0.75
	cols.add_child(right)
	_add_league_snapshot(right, season, club)
	_add_squad_summary(right)
	_add_finances(right, club)


func _add_form_row(season: SeasonState) -> void:
	var line := HBoxContainer.new()
	add_child(line)
	var t := Label.new()
	t.text = "FORM  "
	line.add_child(t)
	var mine: Array = season.results.filter(
		func(r) -> bool: return r.home_club_id == AppState.human_club_id or r.away_club_id == AppState.human_club_id
	).slice(-5)
	if mine.is_empty():
		line.add_child(FMUI.row("No matches yet"))
		return
	for r in mine:
		var home: bool = r.home_club_id == AppState.human_club_id
		var won: bool = (home and r.is_home_win()) or (not home and r.is_away_win())
		line.add_child(FMUI.form_badge(won, r.is_draw()))


func _add_next_match(left: VBoxContainer, season: SeasonState, club: Club) -> void:
	left.add_child(FMUI.header("NEXT MATCH"))
	var fx = AppState.next_fixture()
	if fx == null or season.is_finished:
		var done := FMUI.button("SEASON COMPLETE — START NEXT SEASON")
		done.pressed.connect(func() -> void: AppState.roll_over())
		left.add_child(done)
		return
	var home: bool = fx.home.club_id == AppState.human_club_id
	var opp_id: int = fx.away.club_id if home else fx.home.club_id
	left.add_child(FMUI.row("%s vs %s" % [club.name if home else AppState.game.club(opp_id).name, AppState.game.club(opp_id).name if home else club.name], Color.WHITE))
	left.add_child(FMUI.row("%s • %s%s" % ["Home" if home else "Away", fx.date, " • TODAY" if AppState.is_matchday_today() else " • in %dd" % AppState.days_until_next_match()]))
	var open := FMUI.button("OPEN MATCH CENTRE")
	open.pressed.connect(func() -> void: on_navigate.call("match"))
	left.add_child(open)


func _add_last_result(left: VBoxContainer, season: SeasonState) -> void:
	left.add_child(FMUI.header("LAST RESULT"))
	var last = AppState.last_user_result()
	if last == null:
		left.add_child(FMUI.row("No matches played yet this season."))
		return
	var home: bool = last.home_club_id == AppState.human_club_id
	var won: bool = (home and last.is_home_win()) or (not home and last.is_away_win())
	var line := HBoxContainer.new()
	left.add_child(line)
	line.add_child(FMUI.form_badge(won, last.is_draw()))
	var score := Label.new()
	score.text = " %s %d – %d %s" % [
		AppState.game.club(last.home_club_id).name, last.home_score,
		last.away_score, AppState.game.club(last.away_club_id).name
	]
	line.add_child(score)
	for e in last.events.filter(func(ev) -> bool: return ev.type == MatchEventType.Kind.GOAL).slice(0, 3):
		left.add_child(FMUI.row("%d'  %s" % [e.minute, e.description]))


func _add_attention(left: VBoxContainer) -> void:
	var squad: Array = AppState.human_squad()
	var issues: Array = []
	for p in squad:
		if p.is_injured():
			issues.append([p, "Injured (%dd)" % p.injury_status.days_remaining, false])
		elif p.is_suspended():
			issues.append([p, "Suspended (%dm)" % p.suspension_status.matches_remaining, false])
		elif p.fitness < 60:
			issues.append([p, "Fitness %d%%" % p.fitness, false])
	left.add_child(FMUI.header("REQUIRES ATTENTION (%d)" % issues.size() if not issues.is_empty() else "SQUAD STATUS"))
	if issues.is_empty():
		left.add_child(FMUI.row("Squad fully available.", Color("#10B981")))
		return
	for item in issues.slice(0, 5):
		var b := FMUI.button("%s — %s" % [(item[0] as Player).name, item[1]])
		b.pressed.connect(func() -> void: on_navigate.call("squad"))
		left.add_child(b)


func _add_league_snapshot(right: VBoxContainer, season: SeasonState, club: Club) -> void:
	right.add_child(FMUI.header("LEAGUE"))
	var pos := 0
	for i in season.standings.entries.size():
		if season.standings.entries[i].team.club_id == AppState.human_club_id:
			pos = i + 1
	var entry = season.standings.entries[pos - 1] if pos > 0 else null
	right.add_child(FMUI.title("#%d  •  %d pts" % [pos, entry.points if entry != null else 0], 20))
	for i in mini(season.standings.entries.size(), 5):
		var e = season.standings.entries[i]
		var mark := ">> " if e.team.club_id == AppState.human_club_id else ""
		right.add_child(FMUI.row("%s%d. %s  %d" % [mark, i + 1, AppState.game.club(e.team.club_id).short_name, e.points]))
	var table := FMUI.button("Full table")
	table.pressed.connect(func() -> void: on_navigate.call("league"))
	right.add_child(table)


func _add_squad_summary(right: VBoxContainer) -> void:
	right.add_child(FMUI.header("SQUAD"))
	var squad: Array = AppState.human_squad()
	var avail: int = squad.filter(func(p) -> bool: return p.is_available()).size()
	right.add_child(FMUI.row("%d/%d available" % [avail, squad.size()]))
	var go := FMUI.button("Manage squad")
	go.pressed.connect(func() -> void: on_navigate.call("squad"))
	right.add_child(go)


func _add_finances(right: VBoxContainer, club: Club) -> void:
	right.add_child(FMUI.header("FINANCES"))
	right.add_child(FMUI.row("Balance %d" % club.finance.balance, Color.WHITE))
	right.add_child(FMUI.row("Budget %d" % club.finance.transfer_budget, Color("#10B981")))
	var line := HBoxContainer.new()
	right.add_child(line)
	var save_b := FMUI.button("Save")
	save_b.pressed.connect(func() -> void: SaveDialog.show_dialog(self, "save"))
	line.add_child(save_b)
	var load_b := FMUI.button("Load")
	load_b.pressed.connect(func() -> void: SaveDialog.show_dialog(self, "load"))
	line.add_child(load_b)
