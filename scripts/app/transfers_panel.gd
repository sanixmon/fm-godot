# Transfers: market browse + inspector buy, squad sell, completed history.
# Only the direct-transfer workflow has UI; bid/contract negotiation exists in
# the engine but is intentionally not exposed here.
class_name TransfersPanel
extends VBoxContainer

var _tab: String = "market"
var _filter: int = -1


func refresh() -> void:
	for c in get_children():
		c.queue_free()
	add_child(FMUI.header("TRANSFER MARKET"))
	var season: SeasonState = AppState.season()
	add_child(FMUI.row("Balance %d  •  Budget %d" % [
		season.clubs[AppState.human_club_id].finance.balance,
		season.clubs[AppState.human_club_id].finance.transfer_budget
	], Color.WHITE))
	var tabs := HBoxContainer.new()
	add_child(tabs)
	for t in ["market", "sell", "history"]:
		var b := FMUI.button(t.capitalize() + _tab_count(t, season))
		b.toggle_mode = true
		b.button_pressed = _tab == t
		b.toggled.connect(_on_tab.bind(t))
		tabs.add_child(b)
	match _tab:
		"sell":
			_add_sell(season)
		"history":
			_add_history(season)
		_:
			_add_market(season)


func _tab_count(t: String, season: SeasonState) -> String:
	match t:
		"market":
			return " (%d)" % _market(season).size()
		"sell":
			return " (%d)" % AppState.human_squad().size()
		_:
			return " (%d)" % season.transfer_history.size()
	return ""


func _on_tab(pressed: bool, t: String) -> void:
	if pressed:
		_tab = t
		refresh()


func _market(season: SeasonState) -> Array:
	var out: Array = []
	for pid in season.players:
		if _owning_club(season, int(pid)) == AppState.human_club_id:
			continue
		var p = season.players[pid]
		if _filter >= 0 and Position.group_of(p.best_position()) != _filter:
			continue
		out.append(p)
	out.sort_custom(func(a, b) -> bool: return a.best_overall() > b.best_overall())
	return out


func _owning_club(season: SeasonState, player_id: int) -> int:
	for cid in season.clubs:
		if player_id in (season.clubs[cid] as Club).squad.player_ids:
			return int(cid)
	return -1


func _add_market(season: SeasonState) -> void:
	var filters := HBoxContainer.new()
	add_child(filters)
	for opt in [["ALL", -1], ["GK", 0], ["DEF", 1], ["MID", 2], ["ATT", 3]]:
		var b := FMUI.button(str(opt[0]))
		b.toggle_mode = true
		b.button_pressed = _filter == int(opt[1])
		b.toggled.connect(_on_filter.bind(int(opt[1])))
		filters.add_child(b)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(cols)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.stretch_ratio = 0.6
	cols.add_child(list)
	var names := VBoxContainer.new()
	list.add_child(FMUI.scroll_wrap(names))
	for p in _market(season).slice(0, 30):
		var fee: int = int(TransferValuation.calculate_market_value(p) * 0.9)
		var b := FMUI.button("%-18s %s %d OVR %d  %d" % [
			p.name.left(18), Position.to_string_value(p.best_position()),
			p.age, p.best_overall(), fee
		])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_pick_market.bind(int(p.id)))
		names.add_child(b)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.stretch_ratio = 0.4
	cols.add_child(side)
	_add_inspector(side, season)


func _on_filter(pressed: bool, group: int) -> void:
	if pressed:
		_filter = group
		refresh()


func _on_pick_market(player_id: int) -> void:
	AppState.selected_market_player_id = player_id
	refresh()


func _add_inspector(side: VBoxContainer, season: SeasonState) -> void:
	var player = null
	for pid in season.players:
		if int(pid) == AppState.selected_market_player_id:
			player = season.players[pid]
	if player == null:
		side.add_child(FMUI.row("Select a player from the market list."))
		return
	var owner := _owning_club(season, int(player.id))
	var fee: int = int(TransferValuation.calculate_market_value(player) * 0.9)
	var balance: int = season.clubs[AppState.human_club_id].finance.balance
	side.add_child(FMUI.title("%s (%d)" % [player.name, player.best_overall()]))
	side.add_child(FMUI.row("%s • %d yrs • %s" % [player.nationality, player.age, Position.to_string_value(player.best_position())]))
	side.add_child(FMUI.row("Club: %s" % AppState.game.club(owner).name))
	side.add_child(FMUI.row("Wage %d/w • Contract until %s" % [player.contract.weekly_wage, player.contract.expires_on]))
	for a in [Attribute.Kind.PACE, Attribute.Kind.SHOOTING, Attribute.Kind.PASSING, Attribute.Kind.DRIBBLING, Attribute.Kind.DEFENDING, Attribute.Kind.PHYSICAL]:
		side.add_child(FMUI.row("%-10s %3d" % [Attribute.to_string_value(a).capitalize(), player.attributes.get(a)]))
	side.add_child(FMUI.row("Fee %d" % fee, Color("#10B981")))
	side.add_child(FMUI.row("Balance after %d" % (balance - fee)))
	var buy := FMUI.button("EXECUTE TRANSFER" if balance >= fee else "INSUFFICIENT FUNDS")
	buy.disabled = balance < fee
	buy.pressed.connect(_on_buy.bind(int(player.id), owner, fee))
	side.add_child(buy)


func _on_buy(player_id: int, from_club_id: int, fee: int) -> void:
	AppState.execute_transfer(player_id, from_club_id, AppState.human_club_id, fee)


func _add_sell(season: SeasonState) -> void:
	var names := VBoxContainer.new()
	add_child(FMUI.scroll_wrap(names))
	for p in AppState.human_squad():
		var fee: int = int(TransferValuation.calculate_market_value(p) * 0.9)
		var buyer := -1
		for cid in season.clubs:
			if int(cid) != AppState.human_club_id and season.clubs[cid].finance.balance >= fee:
				buyer = int(cid)
				break
		var line := HBoxContainer.new()
		names.add_child(line)
		var label := Label.new()
		label.text = "%s (%d) — %d" % [p.name, p.best_overall(), fee]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		if buyer >= 0:
			var sell := FMUI.button("SELL TO %s" % AppState.game.club(buyer).short_name)
			sell.pressed.connect(_on_sell.bind(int(p.id), buyer, fee))
			line.add_child(sell)
		else:
			line.add_child(FMUI.row("No buyers"))


func _on_sell(player_id: int, buyer_id: int, fee: int) -> void:
	AppState.execute_transfer(player_id, AppState.human_club_id, buyer_id, fee)


func _add_history(season: SeasonState) -> void:
	if season.transfer_history.is_empty():
		add_child(FMUI.row("No completed transfers yet this season."))
		return
	var names := VBoxContainer.new()
	add_child(FMUI.scroll_wrap(names))
	for rec in season.transfer_history:
		var from_name := "Free agent" if rec.from_club_id < 0 else AppState.game.club(rec.from_club_id).name
		names.add_child(FMUI.row("%s: %s → %s (%d)" % [
			rec.player_name, from_name, AppState.game.club(rec.to_club_id).name, rec.fee
		]))
